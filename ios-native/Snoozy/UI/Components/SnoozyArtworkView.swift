import SwiftUI
import UIKit

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
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            theme.accent.opacity(0.32),
                            theme.accentStrong.opacity(0.16),
                            Color.black.opacity(0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: (size ?? 120) * 0.36, weight: .semibold))
                        .foregroundStyle(theme.accent)
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
