import ImageIO
import SwiftUI
import UIKit

public enum SnoozyIconAppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case automatic = "Default"
    case light = "Light"
    case dark = "Dark"
    case tinted = "Tinted"

    public var id: String { rawValue }
}

public enum SnoozyBrandAssetLoader {
    private static var cachedLogo: UIImage? = nil
    private static var cachedLayers: [Int: UIImage] = [:]

    public static func loadBrandLogoImage() -> UIImage? {
        if let cachedLogo {
            return cachedLogo
        }
        if let named = UIImage(named: "SnoozyBrandLogo") {
            cachedLogo = named
            return named
        }
        if let path = Bundle.main.path(forResource: "SnoozyBrandLogo", ofType: "png"),
           let img = UIImage(contentsOfFile: path) {
            cachedLogo = img
            return img
        }
        if let iconPath = Bundle.main.path(forResource: "AppIcon60x60@3x", ofType: "png"),
           let img = UIImage(contentsOfFile: iconPath) {
            cachedLogo = img
            return img
        }
        return nil
    }

    public static func loadIconLayer(_ index: Int) -> UIImage? {
        if let hit = cachedLayers[index] {
            return hit
        }
        let name = "SnoozyIconLayer\(index)"
        if let named = UIImage(named: name) {
            cachedLayers[index] = named
            return named
        }
        if let path = Bundle.main.path(forResource: "\(name)@3x", ofType: "png") ?? Bundle.main.path(forResource: name, ofType: "png"),
           let img = UIImage(contentsOfFile: path) {
            cachedLayers[index] = img
            return img
        }
        return nil
    }
}

public enum SnoozyArtworkCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 320
        c.totalCostLimit = 64 * 1024 * 1024
        return c
    }()

    public static func loadThumbnail(at path: String, pointSize: CGFloat?) -> UIImage? {
        let bucketPx: Int = {
            guard let pt = pointSize, pt > 0 else { return 640 }
            if pt <= 64 { return 160 }
            if pt <= 180 { return 380 }
            if pt <= 400 { return 720 }
            return 1024
        }()
        let cacheKey = "\(path)#\(bucketPx)" as NSString
        if let hit = cache.object(forKey: cacheKey) {
            return hit
        }

        let fileURL = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: bucketPx
        ]
        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            let uiImage = UIImage(cgImage: cgImage)
            let cost = cgImage.bytesPerRow * cgImage.height
            cache.setObject(uiImage, forKey: cacheKey, cost: cost)
            return uiImage
        }

        if let fallback = UIImage(contentsOfFile: path) {
            cache.setObject(fallback, forKey: cacheKey)
            return fallback
        }
        return nil
    }
}

public struct SnoozyBrandIconView: View {
    public let size: CGFloat
    public var appearanceMode: SnoozyIconAppearanceMode = .automatic
    public var tintColor: Color = Color(red: 0.063, green: 0.725, blue: 0.506)
    @Environment(\.colorScheme) private var systemColorScheme

    public init(
        size: CGFloat = 56,
        appearanceMode: SnoozyIconAppearanceMode = .automatic,
        tintColor: Color = Color(red: 0.063, green: 0.725, blue: 0.506)
    ) {
        self.size = size
        self.appearanceMode = appearanceMode
        self.tintColor = tintColor
    }

    private var effectiveMode: SnoozyIconAppearanceMode {
        if appearanceMode != .automatic {
            return appearanceMode
        }
        return systemColorScheme == .light ? .light : .dark
    }

    public var body: some View {
        let cornerRadius = size * 0.228
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let mode = effectiveMode

        Group {
            if let l0 = SnoozyBrandAssetLoader.loadIconLayer(0),
               let l1 = SnoozyBrandAssetLoader.loadIconLayer(1),
               let l2 = SnoozyBrandAssetLoader.loadIconLayer(2),
               let l3 = SnoozyBrandAssetLoader.loadIconLayer(3) {
                ZStack {
                    // Layer 0: Dynamic Background Chamber (Default/Light, Dark, or Tinted)
                    switch mode {
                    case .light:
                        Image(uiImage: l0)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFill()
                            .overlay(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.16, green: 0.86, blue: 0.64).opacity(0.32),
                                        Color(red: 0.04, green: 0.34, blue: 0.25).opacity(0.18)
                                    ],
                                    startPoint: .topTrailing,
                                    endPoint: .bottomLeading
                                )
                            )
                    case .dark, .automatic:
                        Image(uiImage: l0)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFill()
                            .overlay(Color.black.opacity(0.18))
                    case .tinted:
                        LinearGradient(
                            colors: [
                                Color(white: 0.14),
                                Color(white: 0.04)
                            ],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                        .overlay(tintColor.opacity(0.16))
                    }

                    // Layer 1: Subsurface Caustic & Depth Shadow
                    Image(uiImage: l1)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .saturation(mode == .tinted ? 0.0 : 1.0)
                        .colorMultiply(mode == .tinted ? tintColor : .white)
                        .opacity(mode == .light ? 0.95 : 0.88)

                    // Layer 2: Sculpted 3D Liquid Glass Note Body (preserved original Snoozy silhouette)
                    Image(uiImage: l2)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .saturation(mode == .tinted ? 0.0 : (mode == .light ? 1.10 : 1.0))
                        .brightness(mode == .light ? 0.04 : (mode == .tinted ? 0.08 : 0.0))
                        .colorMultiply(mode == .tinted ? tintColor : .white)
                        .shadow(
                            color: Color.black.opacity(mode == .dark ? 0.42 : 0.26),
                            radius: size * 0.045,
                            x: 0,
                            y: size * 0.025
                        )

                    // Layer 3: Prismatic Specular Highlights & Outer Squircle Glass Rim
                    Image(uiImage: l3)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .saturation(mode == .tinted ? 0.0 : 1.0)
                        .colorMultiply(mode == .tinted ? tintColor.opacity(0.92) : .white)
                        .blendMode(.screen)
                }
            } else if let brandImage = SnoozyBrandAssetLoader.loadBrandLogoImage() {
                Image(uiImage: brandImage)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFill()
            } else {
                ZStack {
                    shape.fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.01, green: 0.04, blue: 0.08),
                                Color(red: 0.03, green: 0.19, blue: 0.15),
                                Color(red: 0.08, green: 0.38, blue: 0.29)
                            ],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.48, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(mode == .light ? 0.62 : 0.46),
                        (mode == .tinted ? tintColor : Color(red: 0.063, green: 0.725, blue: 0.506)).opacity(0.38),
                        Color.white.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: max(0.7, size * 0.016)
            )
        )
        .shadow(color: Color.black.opacity(0.34), radius: max(4, size * 0.14), x: 0, y: max(2, size * 0.07))
        .accessibilityLabel("Snoozy Multi-Layered Liquid Glass icon")
    }
}

public struct SnoozySoundWaveView: View {
    public let isActive: Bool
    public let color: Color
    public let bars: Int
    public let height: CGFloat

    public init(
        isActive: Bool,
        color: Color,
        bars: Int = 4,
        height: CGFloat = 14
    ) {
        self.isActive = isActive
        self.color = color
        self.bars = bars
        self.height = height
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: isActive ? 1.0 / 24.0 : 1.0)) { timeline in
            let t = isActive ? timeline.date.timeIntervalSinceReferenceDate : 0.0
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<bars, id: \.self) { index in
                    let phase = Double(index) * 0.85 + 0.3
                    let wave = isActive ? abs(sin(t * 3.8 + phase)) : 0.25
                    let barHeight = max(3.0, height * CGFloat(0.28 + wave * 0.72))
                    Capsule()
                        .fill(color)
                        .frame(width: 2.4, height: barHeight)
                }
            }
            .frame(height: height)
        }
        .accessibilityHidden(true)
    }
}

public struct SnoozyArtworkView: View {
    public let artworkPath: String?
    public let size: CGFloat?
    public let cornerRadius: CGFloat
    public let theme: SnoozyThemeColors

    public init(
        artworkPath: String?,
        size: CGFloat? = 48,
        cornerRadius: CGFloat = 14,
        theme: SnoozyThemeColors
    ) {
        self.artworkPath = artworkPath
        self.size = size
        self.cornerRadius = cornerRadius
        self.theme = theme
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Group {
            if let path = artworkPath,
               let uiImage = SnoozyArtworkCache.loadThumbnail(at: path, pointSize: size) {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFill()
            } else if let brandImage = SnoozyBrandAssetLoader.loadBrandLogoImage() {
                Image(uiImage: brandImage)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.01, green: 0.04, blue: 0.08),
                            Color(red: 0.04, green: 0.20, blue: 0.16),
                            Color(red: 0.10, green: 0.42, blue: 0.32)
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: (size ?? 120) * 0.40, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    theme.accentInk,
                                    theme.accent
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.38),
                        Color.white.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.8
            )
        )
    }
}

public struct SnoozyPlaylistCollageView: View {
    public let artworkPaths: [String?]
    public let size: CGFloat
    public let cornerRadius: CGFloat
    public let theme: SnoozyThemeColors

    public init(
        artworkPaths: [String?],
        size: CGFloat = 48,
        cornerRadius: CGFloat = 14,
        theme: SnoozyThemeColors
    ) {
        self.artworkPaths = artworkPaths
        self.size = size
        self.cornerRadius = cornerRadius
        self.theme = theme
    }

    public var body: some View {
        let distinct = Array(artworkPaths.compactMap { $0 }.prefix(4))
        if distinct.count < 4 {
            SnoozyArtworkView(
                artworkPath: distinct.first,
                size: size,
                cornerRadius: cornerRadius,
                theme: theme
            )
        } else {
            let cell = (size - 2) / 2
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    SnoozyArtworkView(artworkPath: distinct[0], size: cell, cornerRadius: 4, theme: theme)
                    SnoozyArtworkView(artworkPath: distinct[1], size: cell, cornerRadius: 4, theme: theme)
                }
                HStack(spacing: 2) {
                    SnoozyArtworkView(artworkPath: distinct[2], size: cell, cornerRadius: 4, theme: theme)
                    SnoozyArtworkView(artworkPath: distinct[3], size: cell, cornerRadius: 4, theme: theme)
                }
            }
            .frame(width: size, height: size)
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(Color.white.opacity(0.28), lineWidth: 0.8)
            )
        }
    }
}
