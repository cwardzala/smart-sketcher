import Foundation
import CoreGraphics

enum ImageProcessor {
    /// Resize and convert any AppImage to a flat RGB565 byte buffer (160×128, row-major).
    static func toRGB565(_ source: AppImage) -> Data? {
        let w = 160, h = 128
        var rgba = [UInt8](repeating: 0, count: w * h * 4)

        guard let ctx = CGContext(
            data: &rgba,
            width: w, height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // White background so transparent pixels don't become black.
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        // Aspect-fit the source into 160×128, centred.
        guard let cgImage = source.cgImage else { return nil }
        let srcW = Double(cgImage.width), srcH = Double(cgImage.height)
        let scale = min(Double(w) / srcW, Double(h) / srcH)
        let fitW = srcW * scale, fitH = srcH * scale
        let destRect = CGRect(
            x: (Double(w) - fitW) / 2,
            y: (Double(h) - fitH) / 2,
            width: fitW, height: fitH
        )
        ctx.draw(cgImage, in: destRect)

        var out = [UInt8](repeating: 0, count: w * h * 2)
        for i in 0 ..< w * h {
            let r = rgba[i * 4], g = rgba[i * 4 + 1], b = rgba[i * 4 + 2]
            out[i * 2]     = (r & 0xf8) | (g >> 5)
            out[i * 2 + 1] = ((g & 0x1c) << 3) | (b >> 3)
        }
        return Data(out)
    }
}
