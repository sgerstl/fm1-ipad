// @MainActor on Android (android/BRIDGE.md §3, "the one real risk").
//
// The stock main-actor executor enqueues onto the main dispatch queue, as on iOS. Nothing on Android drains
// that queue: UIKit does it on iOS, CFRunLoop on Linux. libdispatch exposes the queue's wake-up eventfd to
// CoreFoundation (`_dispatch_get_main_queue_port_4CF`) and a drain call (`_dispatch_main_queue_callback_4CF`).
// Registering that fd on the main thread's ALooper makes Android's own main loop drain it, so every existing
// `@MainActor` in SloopKit runs on Android's UI thread, unchanged. Skip's swift-android-native does the same
// (AndroidLooper.swift), going through CFRunLoopRunInMode; this calls the drain directly and reads the fd itself.
//
// Two conditions, both checked by `install()`:
// - It runs on the process's main thread (gettid == getpid), which is Android's UI thread. The Swift runtime's
//   main-actor checks (MainActor.assumeIsolated, isolation assertions) use the same test on Linux and Android.
// - libdispatch was first loaded on that thread too: it binds its main queue to whichever thread initialises
//   it, and the drain crashes ("called from the wrong thread") anywhere else. So `System.loadLibrary` must run
//   on the UI thread (Application.onCreate), before any other thread touches Swift.
#if os(Android)
import Android
import CAndroid

@_silgen_name("_dispatch_get_main_queue_port_4CF")
private func _dispatch_get_main_queue_port_4CF() -> Int32

@_silgen_name("_dispatch_main_queue_callback_4CF")
private func _dispatch_main_queue_callback_4CF(_ msg: UnsafeMutableRawPointer?)

public enum MainLooper {
    public enum Failure: Error, CustomStringConvertible {
        case notMainThread(tid: Int32, pid: Int32)
        case noLooper
        case addFdFailed(Int32)
        public var description: String {
            switch self {
            case let .notMainThread(tid, pid): "MainLooper.install ran on thread \(tid), not the main thread \(pid)"
            case .noLooper: "the main thread has no ALooper (call ALooper_prepare first outside an app)"
            case let .addFdFailed(r): "ALooper_addFd returned \(r)"
            }
        }
    }

    nonisolated(unsafe) private static var installed = false
    nonisolated(unsafe) private static var drains = 0

    /// How many times the Looper has drained the main queue (for the debug screen).
    public static var drainCount: Int { drains }

    /// Hooks the main dispatch queue to the calling thread's ALooper. Call once, on the UI thread, before any
    /// `@MainActor` work. A second call does nothing.
    public static func install() throws {
        if installed { return }
        let tid = gettid(), pid = getpid()
        guard tid == pid else { throw Failure.notMainThread(tid: tid, pid: pid) }
        guard let looper = ALooper_forThread() else { throw Failure.noLooper }
        ALooper_acquire(looper)       // held for the process's life
        let fd = _dispatch_get_main_queue_port_4CF()
        let r = ALooper_addFd(looper, fd, Int32(ALOOPER_POLL_CALLBACK), Int32(ALOOPER_EVENT_INPUT), { fd, _, _ in
            var value: eventfd_t = 0
            _ = eventfd_read(fd, &value)           // clear the wake-up; libdispatch pokes again if work remains
            MainLooper.drains &+= 1
            _dispatch_main_queue_callback_4CF(nil)
            return 1                               // keep listening
        }, nil)
        guard r == 1 else { throw Failure.addFdFailed(r) }
        installed = true
    }

    /// True on the process's main thread: the same test the Swift runtime uses for the main actor.
    public static var isMainThread: Bool { gettid() == getpid() }
}
#endif
