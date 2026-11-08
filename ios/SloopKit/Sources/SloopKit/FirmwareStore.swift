// Downloading Skiff-Lupe and SLOOP-Lupe when they're chosen (2026-11-08): the app carries no GPL firmware, so an App
// Store or TestFlight build is only Lupe's own code. The file comes from Lupe's GitHub release (LupeFirmware.downloadURL),
// is checked against its pinned SHA-256 before anything else sees it, and is kept in Application Support so the next
// install, or a resumed one, needs no internet.
import CryptoKit
import Foundation

/// Fetches a URL's bytes, reporting progress from 0 to 1. Injected, so the tests never touch the network.
public protocol FirmwareTransport: Sendable {
    func fetch(_ url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> Data
}

/// What can go wrong, in words for the person installing. Nothing reaches the FM-1 in any of them.
public enum FirmwareDownloadError: Error, Equatable, CustomStringConvertible {
    case offline
    case server(Int)
    case hashMismatch
    case failed(String)

    public var description: String {
        switch self {
        case .offline:
            "There's no internet connection. Lupe downloads the firmware from GitHub (about 600 KB) before installing it. Connect and try again."
        case .server(let code):
            "GitHub didn't send the file (error \(code)). Nothing was sent to the FM-1. Try again in a moment."
        case .hashMismatch:
            "The downloaded file isn't the one Lupe was tested with, so it was thrown away. Nothing was sent to the FM-1. Try again."
        case .failed(let why):
            "The download didn't finish (\(why)). Nothing was sent to the FM-1. Try again."
        }
    }
}

/// The real transport: URLSession, reading the body as it comes for the progress.
public struct HTTPFirmwareTransport: FirmwareTransport {
    public init() {}

    public func fetch(_ url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> Data {
        let (bytes, response) = try await URLSession.shared.bytes(from: url)
        guard let http = response as? HTTPURLResponse else { throw FirmwareDownloadError.failed("no HTTP response") }
        guard (200..<300).contains(http.statusCode) else { throw FirmwareDownloadError.server(http.statusCode) }
        let total = http.expectedContentLength
        var data = Data()
        if total > 0 { data.reserveCapacity(Int(total)) }
        var chunk = [UInt8]()
        chunk.reserveCapacity(16_384)
        for try await b in bytes {
            chunk.append(b)
            if chunk.count == 16_384 {
                data.append(contentsOf: chunk); chunk.removeAll(keepingCapacity: true)
                if total > 0 { progress(min(1, Double(data.count) / Double(total))) }
            }
        }
        data.append(contentsOf: chunk)
        progress(1)
        return data
    }
}

/// The downloaded firmware: fetched on request, verified, cached.
public final class FirmwareStore: Sendable {
    public let directory: URL
    private let transport: FirmwareTransport

    /// Application Support/Firmware (not in Files: the user doesn't manage these).
    public static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "Firmware")
    }

    public init(directory: URL = FirmwareStore.defaultDirectory, transport: FirmwareTransport = HTTPFirmwareTransport()) {
        self.directory = directory
        self.transport = transport
    }

    private func place(_ f: LupeFirmware) -> URL { directory.appending(path: f.fileName) }

    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    /// The cached file, if it's there and still matches its pin (one that doesn't is deleted).
    public func cachedFile(_ f: LupeFirmware) -> URL? {
        let url = place(f)
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard Self.digest(data) == f.sha256 else { try? FileManager.default.removeItem(at: url); return nil }
        return url
    }

    /// Installable without the internet: in the app, or already downloaded.
    public func isReady(_ f: LupeFirmware) -> Bool { f.isBundled || cachedFile(f) != nil }

    /// The file for `f`: the app's own (stock V15), the cached download, or a new download, verified before it's kept.
    @discardableResult
    public func fetch(_ f: LupeFirmware, progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> URL {
        if f.isBundled, let url = f.localCopy { progress(1); return url }
        if let url = cachedFile(f) { progress(1); return url }
        guard let remote = f.downloadURL else { throw FirmwareDownloadError.failed("no download for \(f.title)") }
        let data: Data
        do {
            data = try await transport.fetch(remote, progress: progress)
        } catch let e as FirmwareDownloadError {
            throw e
        } catch let e as URLError {
            throw Self.offlineCodes.contains(e.code) ? FirmwareDownloadError.offline : FirmwareDownloadError.failed(e.localizedDescription)
        } catch {
            throw FirmwareDownloadError.failed("\(error)")
        }
        guard Self.digest(data) == f.sha256 else { throw FirmwareDownloadError.hashMismatch }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = place(f)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// The parsed package from the app or the cache (nil-free: a file not there yet is `PackageError.missing`).
    public func package(_ f: LupeFirmware) throws -> FirmwarePackage {
        if f.isBundled { return try f.load() }
        guard let url = cachedFile(f), let data = try? Data(contentsOf: url) else { throw PackageError.missing(f.rawValue) }
        return try FirmwarePackage(data: [UInt8](data), pinned: f)
    }

    /// Drops a cached download (a new pin, or the tests).
    public func forget(_ f: LupeFirmware) { try? FileManager.default.removeItem(at: place(f)) }

    static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost,
        .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff,
    ]
}
