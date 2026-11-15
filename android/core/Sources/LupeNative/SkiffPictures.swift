// The sound panel's pictures drawn by Skiff's own code (decision 46: Android first). Kotlin asks for the picture of the
// page the panel shows; nil means "draw your own" (not connected, another firmware build, a page SkiffDraw doesn't
// draw). See ios/SkiffDraw/Sources/SkiffDrawLink/SkiffPictures.swift.
import CAndroid
import SkiffDraw
import SkiffDrawLink

nonisolated(unsafe) private var skiffPictures: SkiffPictures?

/// The FM-1's picture for `page` (Lupe's page number, as PageState.page), GLO's shared pages in `gloInk` (0xRRGGBB).
/// Returns null, or 8 bytes (width, height as little-endian u16; animated 0/1; draw µs as little-endian u16; 0) then
/// width × height × 4 bytes of RGBA.
@_cdecl("Java_com_scottgerstl_lupe_core_LupeNative_skiffPicture")
public func skiffPicture(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ page: jint, _ gloInk: jint) -> jbyteArray? {
    let bytes: [UInt8]? = MainActor.assumeIsolated {
        guard let core else { return nil }
        let p = skiffPictures ?? SkiffPictures()
        skiffPictures = p
        guard let pic = p.picture(core.session, lupePage: Int(page), gloInk: UInt32(bitPattern: gloInk) & 0xFFFFFF) else { return nil }
        let us = min(65535, p.mirror.screen.lastDrawMicroseconds)
        return [UInt8(pic.width & 255), UInt8(pic.width >> 8), UInt8(pic.height & 255), UInt8(pic.height >> 8),
                pic.animated ? 1 : 0, UInt8(us & 255), UInt8(us >> 8), 0] + pic.rgba
    }
    guard let bytes else { return nil }
    let e = env.pointee!.pointee
    guard let arr = e.NewByteArray(env, jsize(bytes.count)) else { return nil }
    bytes.withUnsafeBufferPointer { b in
        b.withMemoryRebound(to: jbyte.self) { e.SetByteArrayRegion(env, arr, 0, jsize(b.count), $0.baseAddress) }
    }
    return arr
}
