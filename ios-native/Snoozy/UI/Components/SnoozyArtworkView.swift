import SwiftUI
import UIKit

public struct SnoozyBrandIconView: View {
    public let size: CGFloat

    public init(size: CGFloat = 56) {
        self.size = size
    }

    public var body: some View {
        let cornerRadius = size * 0.225
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Group {
            if let brandImage = UIImage(named: "SnoozyBrandLogo") {
                Image(uiImage: brandImage)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
            } else {
                ZStack {
                    shape.fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.000, green: 0.008, blue: 0.059),
                                Color(red: 0.051, green: 0.184, blue: 0.161),
                                Color(red: 0.133, green: 0.447, blue: 0.357)
                            ],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.46, weight: .bold))
                        .foregroundStyle(Color(red: 0.925, green: 0.992, blue: 0.961))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
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
               let uiImage = UIImage(contentsOfFile: path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else if let brandImage = UIImage(named: "SnoozyBrandLogo") {
                Image(uiImage: brandImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.000, green: 0.008, blue: 0.059),
                            Color(red: 0.051, green: 0.184, blue: 0.161),
                            Color(red: 0.133, green: 0.447, blue: 0.357)
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: (size ?? 120) * 0.38, weight: .bold))
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
                        Color.white.opacity(0.36),
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
