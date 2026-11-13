// The JNI surface between Kotlin and Swift (android/BRIDGE.md §1–2), written by hand.
//
// Kotlin → Swift: `com.scottgerstl.lupe.core.LupeNative`'s `external fun`s, exported here with @_cdecl.
// Swift → Kotlin: the static methods `send`, `onState` and `onDebug` on the same class, looked up once in
// JNI_OnLoad (which runs inside System.loadLibrary, so FindClass sees the app's class loader).
//
// System.loadLibrary("LupeNative") must run on the UI thread (BRIDGE.md §3); `nativeInit` then hooks the
// main actor to the UI thread's Looper.
#if os(Android)
import Android
import AndroidLink
import CAndroid
import Foundation
import MainLooper
import PhoneCore
import SloopKit

// MARK: - The JVM

nonisolated(unsafe) private var jvm: UnsafeMutablePointer<JavaVM?>?
nonisolated(unsafe) private var nativeClass: jclass?
nonisolated(unsafe) private var sendMethod: jmethodID?
nonisolated(unsafe) private var onStateMethod: jmethodID?
nonisolated(unsafe) private var onDebugMethod: jmethodID?

private let className = "com/scottgerstl/lupe/core/LupeNative"

@_cdecl("JNI_OnLoad")
public func JNI_OnLoad(_ vm: UnsafeMutablePointer<JavaVM?>, _ reserved: UnsafeMutableRawPointer?) -> jint {
    jvm = vm
    guard let env = currentEnv() else { return JNI_ERR }
    let fns = env.pointee!.pointee
    guard let local = fns.FindClass(env, className) else { return JNI_ERR }
    nativeClass = fns.NewGlobalRef(env, local)
    fns.DeleteLocalRef(env, local)
    sendMethod = fns.GetStaticMethodID(env, nativeClass, "send", "([B)V")
    onStateMethod = fns.GetStaticMethodID(env, nativeClass, "onState", "(Ljava/lang/String;Ljava/lang/String;)V")
    onDebugMethod = fns.GetStaticMethodID(env, nativeClass, "onDebug", "(Ljava/lang/String;)V")
    guard sendMethod != nil, onStateMethod != nil, onDebugMethod != nil else { return JNI_ERR }
    return JNI_VERSION_1_6
}

/// The calling thread's JNIEnv, attaching it to the JVM first if Swift made the thread (the cooperative pool).
/// Attached pool threads stay attached; they live as long as the process.
private func currentEnv() -> UnsafeMutablePointer<JNIEnv?>? {
    guard let vm = jvm, let invoke = vm.pointee?.pointee else { return nil }
    var raw: UnsafeMutableRawPointer?
    if invoke.GetEnv(vm, &raw, JNI_VERSION_1_6) == JNI_OK, let raw {
        return raw.assumingMemoryBound(to: JNIEnv?.self)
    }
    var env: UnsafeMutablePointer<JNIEnv?>?
    guard invoke.AttachCurrentThread(vm, &env, nil) == JNI_OK else { return nil }
    return env
}

private func withJString<R>(_ env: UnsafeMutablePointer<JNIEnv?>, _ s: String, _ body: (jstring?) -> R) -> R {
    let fns = env.pointee!.pointee
    let j = fns.NewStringUTF(env, s)
    defer { if let j { fns.DeleteLocalRef(env, j) } }
    return body(j)
}

private func string(_ env: UnsafeMutablePointer<JNIEnv?>, _ j: jstring?) -> String {
    guard let j else { return "" }
    let fns = env.pointee!.pointee
    guard let chars = fns.GetStringUTFChars(env, j, nil) else { return "" }
    defer { fns.ReleaseStringUTFChars(env, j, chars) }
    return String(cString: chars)
}

/// Clears a pending Java exception so one bad call doesn't poison the thread; logs it.
private func clearException(_ env: UnsafeMutablePointer<JNIEnv?>, _ what: String) {
    let fns = env.pointee!.pointee
    if fns.ExceptionCheck(env) != 0 {
        fns.ExceptionDescribe(env)
        fns.ExceptionClear(env)
        _ = lupe_log(Int32(ANDROID_LOG_ERROR.rawValue), "Java exception in \(what)")
    }
}

// MARK: - Swift → Kotlin

/// One frame to the FM-1's input port (FM1Link.send). Any thread.
private func javaSend(_ frame: [UInt8]) {
    guard let env = currentEnv(), let cls = nativeClass, let m = sendMethod else { return }
    let fns = env.pointee!.pointee
    guard let arr = fns.NewByteArray(env, jsize(frame.count)) else { return }
    frame.withUnsafeBufferPointer { b in
        b.baseAddress!.withMemoryRebound(to: jbyte.self, capacity: frame.count) {
            fns.SetByteArrayRegion(env, arr, 0, jsize(frame.count), $0)
        }
    }
    withUnsafePointer(to: jvalue(l: arr)) { fns.CallStaticVoidMethodA(env, cls, m, $0) }
    clearException(env, "send")
    fns.DeleteLocalRef(env, arr)
}

/// A line for the debug screen and logcat ("Lupe" tag).
func debug(_ line: String) {
    _ = lupe_log(Int32(ANDROID_LOG_INFO.rawValue), line)
    guard let env = currentEnv(), let cls = nativeClass, let m = onDebugMethod else { return }
    withJString(env, line) { j in
        withUnsafePointer(to: jvalue(l: j)) { env.pointee!.pointee.CallStaticVoidMethodA(env, cls, m, $0) }
    }
    clearException(env, "onDebug")
}

/// One ViewState area as JSON (BRIDGE.md §2). Used from gate 5.
func publish(area: String, json: String) {
    _ = __android_log_write(Int32(ANDROID_LOG_DEBUG.rawValue), "LupeState", "\(area) \(json)")
    guard let env = currentEnv(), let cls = nativeClass, let m = onStateMethod else { return }
    withJString(env, area) { a in
        withJString(env, json) { j in
            let args = [jvalue(l: a), jvalue(l: j)]
            args.withUnsafeBufferPointer { env.pointee!.pointee.CallStaticVoidMethodA(env, cls, m, $0.baseAddress) }
        }
    }
    clearException(env, "onState")
}

// MARK: - The link

/// The one connection gate for the app's life: FM1Link's reports in, Session's factory out. Read-only until
/// Kotlin says otherwise (setReadOnly); every frame the guard drops is reported.
let gate = LinkGate(send: { javaSend($0) }, onBlocked: { debug("read-only: blocked " + ReadOnlyGuard.describe($0)) })

/// How the app runs the link: `session` (PhoneCore over DeviceSession, the real app) or `raw` (gate 3's debug
/// mode: no Session; Swift reads the frames itself and prints them).
nonisolated(unsafe) private var rawMode = false
nonisolated(unsafe) private var core: PhoneCore?

/// Gate 3's debug mode: Swift reads the frames itself and prints them (no Session yet).
nonisolated(unsafe) private var rawReader: Task<Void, Never>?

private func hex(_ b: [UInt8], limit: Int = 48) -> String {
    let s = b.prefix(limit).map { String(format: "%02X", $0) }.joined(separator: " ")
    return b.count > limit ? s + " … (\(b.count) bytes)" : s
}

private func describeReply(_ frame: [UInt8]) -> String {
    guard let (cmd, body) = Frame.decode(frame) else { return "non-Lupe SysEx: \(hex(frame))" }
    guard cmd == Cmd.info else { return "reply cmd \(cmd): \(hex(frame))" }
    if let s = SkiffInfo(body) {
        let fw = s.firmware.map { "\($0)" } ?? "unknown release"
        return "INFO: \"\(s.version)\" (\(fw)), \(s.trackCount) tracks, \(s.engines.count) engines, " +
            "supported by Lupe: \(s.isSupported ? "yes" : "NO")"
    }
    if let d = try? DeviceInfo(body) { return "INFO (not Skiff): \"\(d.version)\" protocol \(d.protocolVersion)" }
    return "INFO, undecodable: \(hex(frame))"
}

private func startRawReader(_ t: AndroidTransport) {
    rawReader?.cancel()
    rawReader = Task.detached {
        for await f in t.frames { debug("← " + describeReply(f) + "  [" + hex(f, limit: 24) + "]") }
        debug("frames stream finished (the FM-1 went away)")
    }
}

// MARK: - Kotlin → Swift

/// Hooks the main actor to the UI thread's Looper. Returns "" or what went wrong.
@_cdecl("Java_com_scottgerstl_lupe_core_LupeNative_nativeInit")
public func nativeInit(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?) -> jstring? {
    var problem = ""
    do { try MainLooper.install() } catch { problem = "\(error)" }
    return env.pointee!.pointee.NewStringUTF(env, problem)
}

@_cdecl("Java_com_scottgerstl_lupe_core_LupeNative_onOpening")
public func onOpening(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?) { gate.opening() }

/// Starts the link in `raw` or `session` mode (once, on the UI thread, after nativeInit). Session mode builds
/// PhoneCore, which publishes the ViewState areas through LupeNative.onState.
@_cdecl("Java_com_scottgerstl_lupe_core_LupeNative_startCore")
public func startCore(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ raw: jboolean) {
    rawMode = raw != 0
    debug("link mode: \(rawMode ? "raw bytes (no Session)" : "session"), read-only: \(gate.readOnly)")
    guard !rawMode, core == nil else { return }
    MainActor.assumeIsolated {
        let c = PhoneCore(session: DeviceSession(transport: { gate.makeTransport() }),
                          publish: { area, json in publish(area: area, json: json) },
                          log: { debug($0) })
        core = c
        c.start()
    }
}

/// Lets writes through (false) or keeps the link read-only (true). For the next connection.
@_cdecl("Java_com_scottgerstl_lupe_core_LupeNative_setReadOnly")
public func setReadOnly(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ on: jboolean) {
    gate.readOnly = on != 0
    debug("read-only: \(on != 0 ? "on" : "OFF: writes reach the FM-1 from the next connection")")
}

/// One intent from Compose as JSON (BRIDGE.md §2). Called on the UI thread.
@_cdecl("Java_com_scottgerstl_lupe_core_LupeNative_intent")
public func intent(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ json: jstring?) {
    let text = string(env, json)
    MainActor.assumeIsolated {
        guard let core else { debug("intent with no core running: \(text)"); return }
        core.handle(json: text)
    }
}

@_cdecl("Java_com_scottgerstl_lupe_core_LupeNative_onOpened")
public func onOpened(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?) {
    let t = gate.opened()
    if rawMode { startRawReader(t) }
}

@_cdecl("Java_com_scottgerstl_lupe_core_LupeNative_onLost")
public func onLost(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?) { gate.lost() }

/// A chunk from the FM-1's output port, on FM1Link's MIDI thread. Copied straight into the assembler.
@_cdecl("Java_com_scottgerstl_lupe_core_LupeNative_onBytes")
public func onBytes(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ bytes: jbyteArray?,
                    _ offset: jint, _ count: jint, _ timestamp: jlong) {
    guard let bytes, count > 0 else { return }
    let fns = env.pointee!.pointee
    guard let p = fns.GetPrimitiveArrayCritical(env, bytes, nil) else { return }
    gate.bytes(UnsafeRawBufferPointer(start: p + Int(offset), count: Int(count)))
    fns.ReleasePrimitiveArrayCritical(env, bytes, p, JNI_ABORT)
}

/// Debug: sends Skiff's version request (INFO, cmd 1) on the open connection.
@_cdecl("Java_com_scottgerstl_lupe_core_LupeNative_requestVersion")
public func requestVersion(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?) {
    guard rawMode else { debug("version request is for raw mode; in session mode Session sends INFO itself"); return }
    guard let t = gate.transport else { debug("no FM-1 open: nothing sent"); return }
    let f = Frame.encode(Cmd.info)
    debug("→ INFO request [\(hex(f))]")
    t.send(f)
}

/// Debug: gate 2 again, inside the app. Hops from a background task to @MainActor and back, reports via onDebug.
@_cdecl("Java_com_scottgerstl_lupe_core_LupeNative_mainActorCheck")
public func mainActorCheck(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?) {
    Task.detached {
        let offBefore = !MainLooper.isMainThread
        let n = 200, start = ContinuousClock.now
        var allMain = true
        for _ in 0..<n {
            allMain = await MainActor.run { MainActor.assumeIsolated { MainLooper.isMainThread } } && allMain
        }
        let per = (ContinuousClock.now - start) / n
        let offAfter = !MainLooper.isMainThread
        let ok = offBefore && allMain && offAfter
        debug("main actor: \(ok ? "OK" : "FAILED"). \(n) hops from a background task, each ran on the UI thread: " +
              "\(allMain), round trip \(per.formatted(.units(allowed: [.microseconds], width: .narrow)))")
    }
}
#endif
