// The FM-1 over Android's MIDI service (android/BRIDGE.md §1). Kotlin's FM1Link owns the USB device and
// hands bytes across JNI; this is the iPad's MIDITransport minus CoreMIDI. Nothing here is Android-only,
// so the Mac tests exercise it directly.
import Foundation
import SloopKit

/// One open connection to the FM-1. Bytes arrive in arbitrary chunks on the MIDI handler's thread;
/// `SysExAssembler` turns them into frames, notes and clock exactly as on the iPad.
public final class AndroidTransport: SysExTransport, @unchecked Sendable {
    public let frames: AsyncStream<[UInt8]>
    private let sink: AsyncStream<[UInt8]>.Continuation
    public let notes: AsyncStream<NoteEvent>
    private let noteSink: AsyncStream<NoteEvent>.Continuation
    public let clock: AsyncStream<ClockEvent>
    private let clockSink: AsyncStream<ClockEvent>.Continuation

    private let out: @Sendable ([UInt8]) -> Void
    private var assembler = SysExAssembler()
    private let lock = NSLock()
    private var finished = false

    /// `send` writes one frame to the FM-1's input port (Kotlin splits it at the port's maximum message size).
    public init(send: @escaping @Sendable ([UInt8]) -> Void) {
        out = send
        // The same buffering as MIDITransport.
        (frames, sink) = AsyncStream.makeStream(of: [UInt8].self, bufferingPolicy: .unbounded)
        (notes, noteSink) = AsyncStream.makeStream(of: NoteEvent.self, bufferingPolicy: .bufferingNewest(128))
        (clock, clockSink) = AsyncStream.makeStream(of: ClockEvent.self, bufferingPolicy: .bufferingNewest(512))
    }

    deinit { finish() }

    public var isFinished: Bool { lock.withLock { finished } }

    /// A chunk from the FM-1's output port. Any thread; never blocks for long.
    public func receive(_ bytes: UnsafeRawBufferPointer) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        let out = assembler.feed(bytes)
        let notes = assembler.drainNotes()
        let ticks = assembler.drainClock()
        lock.unlock()
        for f in out { sink.yield(f) }
        for n in notes { noteSink.yield(n) }
        for c in ticks { clockSink.yield(c) }
    }

    public func receive(_ bytes: [UInt8]) {
        bytes.withUnsafeBytes { receive($0) }
    }

    public func send(_ frame: [UInt8]) {
        guard !isFinished else { return }
        out(frame)
    }

    /// The FM-1 went away: the streams finish, and Session goes back to asking its factory.
    public func finish() {
        lock.lock(); defer { lock.unlock() }
        guard !finished else { return }
        finished = true
        sink.finish()
        noteSink.finish()
        clockSink.finish()
    }
}

/// What Kotlin's FM1Link reports, turned into the factory `Session(transport:)` calls once a second.
///
/// `opened()` makes a fresh transport; the factory hands it out once; bytes go to it; `lost()` finishes it.
/// The factory never blocks and returns nil until FM1Link has the ports open.
public final class LinkGate: @unchecked Sendable {
    public enum State: String, Sendable { case none, opening, open }

    private let lock = NSLock()
    private let sender: @Sendable ([UInt8]) -> Void
    private var current: AndroidTransport?
    private var handedOut = false
    private var _state: State = .none
    /// The open device's USB name, as Android gives it ("Hügelton Instruments Felucca", "Felucca Update", "FM-1").
    private var _name: String?
    /// The installer has the FM-1 to itself (UpdateLink.swift): the Session's factory gets nothing.
    private var held = false

    private var _readOnly = true
    private let onBlocked: @Sendable ([UInt8]) -> Void

    /// `onBlocked` hears each frame the read-only guard dropped.
    public init(send: @escaping @Sendable ([UInt8]) -> Void, onBlocked: @escaping @Sendable ([UInt8]) -> Void = { _ in }) {
        sender = send; self.onBlocked = onBlocked
    }

    public var state: State { lock.withLock { _state } }

    /// Only reads reach the FM-1 (ReadOnlyGuard). On by default: the phone build writes nothing until someone
    /// turns writes on (the debug screen's switch). Takes effect for the next connection handed out.
    public var readOnly: Bool {
        get { lock.withLock { _readOnly } }
        set { lock.withLock { _readOnly = newValue } }
    }

    /// FM1Link found the FM-1 and asked Android to open it.
    public func opening() { lock.withLock { if _state == .none { _state = .opening } } }

    /// Both ports are open: a new connection, not yet handed to Session. `name` is the device's USB name; nil (the
    /// tests, the raw debug mode) counts as the FM-1 running an editor firmware.
    @discardableResult
    public func opened(name: String? = nil) -> AndroidTransport {
        let t = AndroidTransport(send: sender)
        let old: AndroidTransport? = lock.withLock {
            let o = current
            current = t; handedOut = false; _state = .open; _name = name
            return o
        }
        old?.finish()
        return t
    }

    /// The FM-1 went away (unplugged, or the ports failed).
    public func lost() {
        let old: AndroidTransport? = lock.withLock {
            let o = current
            current = nil; handedOut = false; _state = .none; _name = nil
            return o
        }
        old?.finish()
    }

    /// The open device's USB name, nil when nothing is open.
    public var deviceName: String? { lock.withLock { _state == .open ? _name : nil } }

    /// A device the editor's Session may talk to: one running a Felucca-family firmware. The update loader ("Felucca
    /// Update") and a stock FM-1 (any other name the installer's filter takes) answer none of the editor's questions;
    /// they are the installer's to ask (UpdateLink.swift).
    public static func isEditorDevice(name: String?) -> Bool {
        guard let n = name?.lowercased() else { return true }
        return n.contains("felucca") && !n.contains("update")
    }

    /// The installer takes the FM-1 (true) or gives it back (false). Taking it finishes the Session's connection (the
    /// Session sees the FM-1 gone and waits); the ports stay open, and a fresh connection over them is the
    /// installer's, or the Session's again after it's given back.
    public func hold(_ on: Bool) {
        let old: AndroidTransport? = lock.withLock {
            guard held != on else { return nil }
            held = on
            let o = current
            if _state == .open { current = AndroidTransport(send: sender); handedOut = false }
            return o
        }
        old?.finish()
    }

    /// Bytes from the output port. Dropped when nothing is open.
    public func bytes(_ buf: UnsafeRawBufferPointer) {
        let t = lock.withLock { current }
        t?.receive(buf)
    }

    /// The transport, if open and not handed out yet. The current one, while open, so a direct caller (the
    /// debug screen) can still read it.
    public var transport: AndroidTransport? { lock.withLock { current } }

    /// `Session(transport:)`'s factory: the open connection once, then nil until the next `opened()`.
    public func makeTransport() -> SysExTransport? {
        lock.withLock {
            guard !held, Self.isEditorDevice(name: _name), let t = current, !handedOut, !t.isFinished else { return nil }
            handedOut = true
            return _readOnly ? GuardedTransport(t, onBlocked: onBlocked) : t
        }
    }
}
