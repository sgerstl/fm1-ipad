// A frame as a CGImage (Apple platforms): nearest-neighbour scaling is the view's job (.interpolation(.none)).
#if canImport(CoreGraphics)
import CoreGraphics

public extension SkiffScreen {
    static func image(_ rgba: [UInt8]) -> CGImage? {
        let data = rgba.withUnsafeBufferPointer { CFDataCreate(nil, $0.baseAddress, $0.count) }
        guard let data, let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
    func renderImage() -> CGImage? { Self.image(render()) }
}
#endif
