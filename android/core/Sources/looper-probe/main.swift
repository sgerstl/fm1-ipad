// Gate 2's proof, runnable with adb on the Pixel or an emulator, no app needed (android/scripts/looper-probe.sh).
//
// The process's main thread prepares an ALooper and polls it, standing in for Android's UI thread (whose
// Looper is the same native ALooper underneath). Background threads hop to @MainActor and back: a detached
// task (the cooperative pool) and a raw pthread (the way FM1Link's MIDI handler thread calls into Swift).
// Each side checks where it ran, MainActor.assumeIsolated checks the runtime agrees, and 1,000 round trips
// are timed. Exit 0 and "PASS" on success.
#if os(Android)
import Android
import CAndroid
import Dispatch
import MainLooper

func log(_ s: String) { print(s); fflush(stdout) }
nonisolated(unsafe) var failures = 0
func check(_ ok: Bool, _ what: String) { log((ok ? "ok   " : "FAIL ") + what); if !ok { failures += 1 } }

@MainActor enum Probe {
    static var hops = 0
    /// Runs on the main actor; true when that was the main thread.
    static func hop() -> Bool {
        MainActor.assumeIsolated { hops += 1 }   // traps if the runtime disagrees about isolation
        return MainLooper.isMainThread
    }
}

final class Box { let run: () -> Void; init(_ run: @escaping () -> Void) { self.run = run } }

nonisolated(unsafe) var done = false

_ = ALooper_prepare(0)
let mainLooper = ALooper_forThread()!
// --control: skip the hook. The main actor must then never run, which shows the hook is what drains it.
let control = CommandLine.arguments.contains("--control")
if control {
    log("info control run: MainLooper not installed")
} else {
    do { try MainLooper.install() } catch { log("FAIL install: \(error)"); exit(1) }
    check(MainLooper.isMainThread, "install ran on the main thread (tid \(gettid()))")
}

Task.detached {
    // 1. A detached task to the main actor and back.
    check(!MainLooper.isMainThread, "detached task starts off the main thread")
    let wasMain = await Probe.hop()
    check(wasMain, "@MainActor function ran on the main thread")
    check(!MainLooper.isMainThread, "back off the main thread after the hop")

    // 2. A raw pthread, as the MIDI handler is, using Task { @MainActor in }.
    let fromThread: Bool = await withCheckedContinuation { cont in
        let box = Unmanaged.passRetained(Box { Task { @MainActor in cont.resume(returning: Probe.hop()) } })
        var tid = pthread_t(bitPattern: 0)
        pthread_create(&tid, nil, { arg in
            let b = Unmanaged<Box>.fromOpaque(arg!).takeRetainedValue()
            check(!MainLooper.isMainThread, "raw pthread is off the main thread")
            b.run()
            return nil
        }, box.toOpaque())
    }
    check(fromThread, "Task { @MainActor } from a raw pthread ran on the main thread")

    // 3. DispatchQueue.main.async lands there too.
    let viaDispatch: Bool = await withCheckedContinuation { cont in
        DispatchQueue.main.async { cont.resume(returning: MainLooper.isMainThread) }
    }
    check(viaDispatch, "DispatchQueue.main.async ran on the main thread")

    // 4. What a hop costs.
    let n = 1000, start = ContinuousClock.now
    var allMain = true
    for _ in 0..<n { allMain = await Probe.hop() && allMain }
    let per = (ContinuousClock.now - start) / n
    check(allMain, "all \(n) round trips ran on the main thread")
    log("info one round trip background → main actor → background: \(per)")
    let hops = await Probe.hops
    check(hops == n + 2, "main actor counted \(hops) hops (expected \(n + 2))")
    log("info the Looper drained the main queue \(MainLooper.drainCount) times")
    done = true
    ALooper_wake(mainLooper)
}

// The "UI thread": poll the Looper until the probe finishes or 10 s pass.
let deadline = ContinuousClock.now + .seconds(control ? 3 : 10)
while !done && ContinuousClock.now < deadline {
    _ = ALooper_pollOnce(100, nil, nil, nil)
}
if control {
    log(done ? "FAIL control: the main actor ran without the hook" : "PASS control: without the hook the main actor never ran")
    exit(done ? 1 : 0)
}
if !done { log("FAIL timed out: the main actor never ran (nothing drained the main queue)"); exit(1) }
log(failures == 0 ? "PASS looper-probe" : "FAIL looper-probe: \(failures) check(s) failed")
exit(failures == 0 ? 0 : 1)
#else
print("looper-probe runs on Android only")
#endif
