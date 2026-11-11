import ImageIO
import SwiftUI
import UIKit

public enum SnoozyBrandAssetLoader {
    private static var cachedLogo: UIImage? = nil

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
            return 720
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

    public init(size: CGFloat = 56) {
        self.size = size
    }

    public var body: some View {
        let cornerRadius = size * 0.23
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Group {
            if let brandImage = SnoozyBrandAssetLoader.loadBrandLogoImage() {
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
                    Circle()
                        .fill(Color(red: 0.063, green: 0.725, blue: 0.506).opacity(0.32))
                        .frame(width: size * 0.65, height: size * 0.65)
                        .blur(radius: size * 0.14)
                        .offset(x: size * 0.12, y: -size * 0.10)

                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.48, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color(red: 0.65, green: 0.98, blue: 0.86),
                                    Color(red: 0.35, green: 0.85, blue: 0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.black.opacity(0.45), radius: size * 0.08, x: 0, y: size * 0.05)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.46),
                        Color(red: 0.063, green: 0.725, blue: 0.506).opacity(0.35),
                        Color.white.opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.9
            )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
        .accessibilityLabel("Snoozy Emerald Liquid Glass icon")
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
