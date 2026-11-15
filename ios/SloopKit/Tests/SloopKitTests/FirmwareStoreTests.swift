#if canImport(CryptoKit)
// Apple-only: not built for Android (android/BRIDGE.md §3).
import Foundation
import Testing
@testable import SloopKit

/// Downloading Skiff-Lupe and SLOOP-Lupe (FirmwareStore.swift) against a strict fake transport: every request it isn't
/// scripted for is recorded in `unanswered` and fails, and each test expects that list empty.
@Suite struct FirmwareStoreTests {
    /// Answers only the URLs it's given; anything else is recorded and refused.
    final class FakeTransport: FirmwareTransport, @unchecked Sendable {
        enum Answer { case data(Data), error(Error) }
        private let lock = NSLock()
        private var answers: [URL: Answer] = [:]
        private(set) var requested: [URL] = []
        private(set) var unanswered: [URL] = []

        func answer(_ url: URL, _ a: Answer) { lock.withLock { answers[url] = a } }

        func fetch(_ url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> Data {
            let a: Answer? = lock.withLock { requested.append(url); return answers[url] }
            switch a {
            case .data(let d)?:
                progress(0.5); progress(1)
                return d
            case .error(let e)?: throw e
            case nil:
                lock.withLock { unanswered.append(url) }
                throw FirmwareDownloadError.failed("not scripted: \(url)")
            }
        }
    }

    static func tempStore(_ t: FakeTransport) -> FirmwareStore {
        let dir = FileManager.default.temporaryDirectory.appending(path: "fwstore-\(UUID().uuidString)")
        return FirmwareStore(directory: dir, transport: t)
    }

    static func real(_ f: LupeFirmware) throws -> Data { try Data(contentsOf: #require(f.localCopy)) }

    final class Progress: @unchecked Sendable {
        private let lock = NSLock(); private var v: [Double] = []
        func add(_ x: Double) { lock.withLock { v.append(x) } }
        var last: Double? { lock.withLock { v.last } }
    }

    @Test func downloadsVerifiesAndKeepsTheFile() async throws {
        let t = FakeTransport(), store = Self.tempStore(t)
        t.answer(LupeFirmware.skiff.downloadURL!, .data(try Self.real(.skiff)))
        #expect(!store.isReady(.skiff))
        let p = Progress()
        let url = try await store.fetch(.skiff) { p.add($0) }
        #expect(url.lastPathComponent == "Skiff-Lupe-2.2.fwsc")
        #expect(p.last == 1)
        #expect(store.isReady(.skiff))
        let pkg = try store.package(.skiff)
        #expect(pkg.product == "FM-1_722")
        #expect(t.requested == [LupeFirmware.skiff.downloadURL!])
        #expect(t.unanswered.isEmpty)
    }

    /// A Debug build's own copies (DebugFirmware/ in the app): installable with no request; a wrong file there is ignored.
    @Test func aDebugBuildsOwnCopyNeedsNoDownload() async throws {
        let base = FileManager.default.temporaryDirectory.appending(path: "fwlocal-\(UUID().uuidString)")
        let rel = base.appending(path: "DebugFirmware")
        try FileManager.default.createDirectory(at: rel, withIntermediateDirectories: true)
        try Self.real(.skiff251).write(to: rel.appending(path: LupeFirmware.skiff251.fileName))
        try Data([1, 2, 3]).write(to: rel.appending(path: LupeFirmware.skiff.fileName))     // fails its pin
        let t = FakeTransport()
        let store = FirmwareStore(directory: base.appending(path: "cache"), transport: t, localReleases: rel)
        #expect(store.isReady(.skiff251))
        #expect(!store.isReady(.skiff))
        let url = try await store.fetch(.skiff251)
        #expect(url.deletingLastPathComponent().lastPathComponent == "DebugFirmware")
        #expect(try store.package(.skiff251).product == "FM-1_725")
        #expect(t.requested.isEmpty)
        _ = try? await store.fetch(.skiff)                          // the bad copy is skipped: it goes to the download
        #expect(t.requested == [LupeFirmware.skiff.downloadURL!])
    }

    @Test func theCachedFileIsUsedWithoutAnotherRequest() async throws {
        let t = FakeTransport(), store = Self.tempStore(t)
        t.answer(LupeFirmware.sloop.downloadURL!, .data(try Self.real(.sloop)))
        try await store.fetch(.sloop)
        try await store.fetch(.sloop)
        _ = try store.package(.sloop)
        #expect(t.requested.count == 1)
        #expect(t.unanswered.isEmpty)
    }

    @Test func aWrongFileIsThrownAwayAndNeverKept() async throws {
        let t = FakeTransport(), store = Self.tempStore(t)
        var bad = try Self.real(.skiff)
        bad[200_000] ^= 0x01
        t.answer(LupeFirmware.skiff.downloadURL!, .data(bad))
        await #expect(throws: FirmwareDownloadError.hashMismatch) { try await store.fetch(.skiff) }
        #expect(!store.isReady(.skiff))
        #expect(throws: PackageError.missing("Skiff-Lupe-2.2")) { try store.package(.skiff) }
        #expect(t.unanswered.isEmpty)
    }

    @Test func offlineSaysSo() async throws {
        let t = FakeTransport(), store = Self.tempStore(t)
        t.answer(LupeFirmware.skiff.downloadURL!, .error(URLError(.notConnectedToInternet)))
        await #expect(throws: FirmwareDownloadError.offline) { try await store.fetch(.skiff) }
        // and a retry once it's back works
        t.answer(LupeFirmware.skiff.downloadURL!, .data(try Self.real(.skiff)))
        try await store.fetch(.skiff)
        #expect(store.isReady(.skiff))
        #expect(t.unanswered.isEmpty)
    }

    @Test func aServerErrorSaysSo() async throws {
        let t = FakeTransport(), store = Self.tempStore(t)
        t.answer(LupeFirmware.sloop.downloadURL!, .error(FirmwareDownloadError.server(404)))
        await #expect(throws: FirmwareDownloadError.server(404)) { try await store.fetch(.sloop) }
        #expect(t.unanswered.isEmpty)
    }

    @Test func aDamagedCacheIsDroppedAndFetchedAgain() async throws {
        let t = FakeTransport(), store = Self.tempStore(t)
        t.answer(LupeFirmware.skiff.downloadURL!, .data(try Self.real(.skiff)))
        let url = try await store.fetch(.skiff)
        try Data([1, 2, 3]).write(to: url)
        #expect(!store.isReady(.skiff))
        try await store.fetch(.skiff)
        #expect(t.requested.count == 2)
        #expect(t.unanswered.isEmpty)
    }

    @Test func stockV15NeedsNoDownload() async throws {
        let t = FakeTransport(), store = Self.tempStore(t)
        #expect(store.isReady(.stock))
        try await store.fetch(.stock)
        _ = try store.package(.stock)
        #expect(t.requested.isEmpty)
        #expect(LupeFirmware.stock.downloadURL == nil)
    }

    @Test func downloadsAreLupesReleaseAssets() {
        #expect(LupeFirmware.skiff.downloadURL?.absoluteString == "https://github.com/sgerstl/fm1-ipad/releases/download/lupe-firmware-1/Skiff-Lupe-2.2.fwsc")
        #expect(LupeFirmware.sloop.downloadURL?.absoluteString == "https://github.com/sgerstl/fm1-ipad/releases/download/lupe-firmware-1/SLOOP-Lupe-2.8.4.fwsc")
    }
}

#endif
