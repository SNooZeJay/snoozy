import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

public struct ArtworkPalette: Equatable, Sendable {
    public let primary: Color
    public let secondary: Color
    public let tertiary: Color

    public static let emeraldDefault = ArtworkPalette(
        primary: Color(red: 0.063, green: 0.725, blue: 0.506),
        secondary: Color(red: 0.020, green: 0.588, blue: 0.412),
        tertiary: Color(red: 0.055, green: 0.455, blue: 0.565)
    )
}

public enum ArtworkPaletteExtractor {
    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    public static func extract(from artworkPath: String?) -> ArtworkPalette {
        guard let path = artworkPath,
              let uiImage = UIImage(contentsOfFile: path),
              let cgImage = uiImage.cgImage
        else {
            return .emeraldDefault
        }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 4, height > 4 else { return .emeraldDefault }

        let ciImage = CIImage(cgImage: cgImage)
        let topRect = CGRect(x: 0, y: CGFloat(height) * 0.5, width: CGFloat(width), height: CGFloat(height) * 0.5)
        let bottomRect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height) * 0.5)
        let centerRect = CGRect(
            x: CGFloat(width) * 0.2,
            y: CGFloat(height) * 0.2,
            width: CGFloat(width) * 0.6,
            height: CGFloat(height) * 0.6
        )

        let c1 = averageColor(in: ciImage, extent: centerRect) ?? UIColor(red: 0.063, green: 0.725, blue: 0.506, alpha: 1)
        let c2 = averageColor(in: ciImage, extent: topRect) ?? UIColor(red: 0.020, green: 0.588, blue: 0.412, alpha: 1)
        let c3 = averageColor(in: ciImage, extent: bottomRect) ?? UIColor(red: 0.055, green: 0.455, blue: 0.565, alpha: 1)

        return ArtworkPalette(
            primary: boostSaturation(c1),
            secondary: boostSaturation(c2),
            tertiary: boostSaturation(c3)
        )
    }

    private static func averageColor(in image: CIImage, extent: CGRect) -> UIColor? {
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: image,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ]),
        let output = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        return UIColor(
            red: CGFloat(bitmap[0]) / 255.0,
            green: CGFloat(bitmap[1]) / 255.0,
            blue: CGFloat(bitmap[2]) / 255.0,
            alpha: 1.0
        )
    }

    private static func boostSaturation(_ color: UIColor) -> Color {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        if color.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            let boostedS = min(1.0, max(0.45, s * 1.35))
            let clampedB = min(0.92, max(0.38, b))
            return Color(UIColor(hue: h, saturation: boostedS, brightness: clampedB, alpha: 1.0))
        }
        return Color(color)
    }
}
