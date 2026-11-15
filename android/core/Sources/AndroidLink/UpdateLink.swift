// The firmware installer's ports on Android (SloopKit's UpdatePorts, which CoreMIDI gives the iPad). Android's MIDI
// service lets one client have a device, and Kotlin's FM1Link opens the one FM-1 there is, so there is one port at a
// time: the device that is open now, under its USB name. When the FM-1 restarts into its update loader it leaves
// and comes back as another device ("Felucca Update"); FM1Link opens that one by the same name filter, and the
// installer, which polls `inputNames`, finds it.
//
// The installer writes (UPGRADE, and the answers to the device's read requests), so its link is not behind the
// read-only guard: an install is its own explicit confirm in the app. Nothing but the installer uses this link.
import Foundation
import SloopKit

extension LinkGate: UpdatePorts {
    public func inputNames() -> [String] { deviceName.map { [$0] } ?? [] }

    public func open(_ name: String) throws -> UpdateLink {
        guard let t = transport, deviceName == name else { throw UpdateLinkError.gone(name) }
        return GateUpdateLink(t)
    }
}

public enum UpdateLinkError: Error, CustomStringConvertible {
    case gone(String)
    public var description: String { switch self { case .gone(let n): "\(n) is no longer connected" } }
}

/// One connection's frames, for the installer: the same bytes Kotlin hands the gate, assembled into SysEx frames.
final class GateUpdateLink: UpdateLink, @unchecked Sendable {
    private let transport: AndroidTransport
    private let queue = FrameQueue()
    private var pump: Task<Void, Never>?

    init(_ t: AndroidTransport) {
        transport = t
        let q = queue
        pump = Task.detached { for await f in t.frames { q.put(f) } }
    }

    func send(_ frame: [UInt8]) -> Bool {
        guard !transport.isFinished else { return false }
        transport.send(frame)
        return true
    }
    func read(timeout: Duration) async -> [UInt8]? { await queue.read(timeout: timeout) }
    func drain() { queue.drain() }
    var lost: Bool { transport.isFinished }
    func close() { pump?.cancel(); pump = nil }
}
