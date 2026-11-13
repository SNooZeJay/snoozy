import SwiftUI
import UIKit

public struct SnoozyMiniPlayerView: View {
    public let track: Track
    public let isPlaying: Bool
    public let progress: Double
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    public let isFavorite: Bool
    public var artworkNamespace: Namespace.ID? = nil
    public let onOpenPlayer: () -> Void
    public let onTogglePlay: () -> Void
    public let onToggleFavorite: () -> Void
    public let onNext: () -> Void
    public var onPrevious: (() -> Void)? = nil
    @Environment(\.snoozyLayout) private var layout

    public init(
        track: Track,
        isPlaying: Bool,
        progress: Double,
        theme: SnoozyThemeColors,
        preferences: SnoozyPreferences,
        isFavorite: Bool,
        artworkNamespace: Namespace.ID? = nil,
        onOpenPlayer: @escaping () -> Void,
        onTogglePlay: @escaping () -> Void,
        onToggleFavorite: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrevious: (() -> Void)? = nil
    ) {
        self.track = track
        self.isPlaying = isPlaying
        self.progress = progress
        self.theme = theme
        self.preferences = preferences
        self.isFavorite = isFavorite
        self.artworkNamespace = artworkNamespace
        self.onOpenPlayer = onOpenPlayer
        self.onTogglePlay = onTogglePlay
        self.onToggleFavorite = onToggleFavorite
        self.onNext = onNext
        self.onPrevious = onPrevious
    }

    public var body: some View {
        let pillHeight = layout.miniPlayerHeight
        let thumbSize = max(34, pillHeight - 14)
        let containerRadius = pillHeight * 0.30

        ZStack(alignment: .bottom) {
            HStack(spacing: 11) {
                Button(action: onOpenPlayer) {
                    HStack(spacing: 11) {
                        artworkThumbnail(size: thumbSize)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(SnoozyTypography.body(15, bold: true))
                                .foregroundStyle(theme.ink)
                                .lineLimit(1)
                            Text(track.artist)
                                .font(SnoozyTypography.footnote(12))
                                .foregroundStyle(theme.inkMuted)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(LiquidGlassInteractiveBounceStyle(scale: 0.98))

                HStack(spacing: 2) {
                    ZStack {
                        AudioRoutePickerRepresentable(
                            tintColor: UIColor(theme.ink.opacity(0.88)),
                            activeTintColor: UIColor(theme.accent)
                        )
                        .frame(width: 40, height: pillHeight)
                    }
                    .accessibilityLabel("Audio output")

                    controlDivider

                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isFavorite ? theme.accent : theme.ink.opacity(0.88))
                            .frame(width: 40, height: pillHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(LiquidGlassInteractiveBounceStyle(scale: 0.88))
                    .accessibilityLabel(isFavorite ? "Remove from Favorites" : "Add to Favorites")

                    controlDivider

                    Button(action: onTogglePlay) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(theme.ink)
                            .frame(width: 40, height: pillHeight)
                            .contentShape(Rectangle())
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(LiquidGlassInteractiveBounceStyle(scale: 0.88))
                    .accessibilityLabel(isPlaying ? "Pause" : "Play")

                    Button(action: onNext) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(theme.ink.opacity(0.88))
                            .frame(width: 40, height: pillHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(LiquidGlassInteractiveBounceStyle(scale: 0.88))
                    .accessibilityLabel("Next track")
                }
            }
            .padding(.leading, 7)
            .padding(.trailing, 8)
            .frame(height: pillHeight)

            // Subtle integrated playback progress hairline inside the bottom of the container
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(theme.isDark ? 0.10 : 0.16))
                        .frame(height: 2.0)
                    Capsule()
                        .fill(theme.accent)
                        .frame(
                            width: max(0, min(proxy.size.width, proxy.size.width * progress)),
                            height: 2.0
                        )
                }
            }
            .frame(height: 2.0)
            .padding(.horizontal, pillHeight * 0.48)
            .padding(.bottom, 2.5)
            .allowsHitTesting(false)
        }
        .frame(height: pillHeight)
        .liquidGlassSurface(
            cornerRadius: containerRadius,
            glassMode: preferences.glassMode,
            refractionIntensity: preferences.refractionIntensity,
            tintColor: theme.accent,
            variant: .ultraClear
        )
        .overlay(
            // Identical physical top rim specular highlight + subtle bottom reflection as the main navigation bar
            RoundedRectangle(cornerRadius: containerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(theme.isDark ? 0.42 : 0.68),
                            Color.white.opacity(theme.isDark ? 0.08 : 0.18),
                            Color.white.opacity(theme.isDark ? 0.20 : 0.36)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
                .allowsHitTesting(false)
        )
        .shadow(color: Color.black.opacity(theme.isDark ? 0.38 : 0.15), radius: 18, x: 0, y: 8)
        .shadow(color: Color.black.opacity(theme.isDark ? 0.20 : 0.08), radius: 5, x: 0, y: 2)
        .snoozyHorizontalScrollZone(id: "mini-player-pill")
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.height < -28 && abs(value.translation.height) > abs(value.translation.width) {
                        onOpenPlayer()
                    } else if value.translation.width < -44 && abs(value.translation.width) > abs(value.translation.height) * 1.4 {
                        onNext()
                    } else if value.translation.width > 44 && abs(value.translation.width) > abs(value.translation.height) * 1.4 {
                        onPrevious?()
                    }
                }
        )
    }

    @ViewBuilder
    private func artworkThumbnail(size: CGFloat) -> some View {
        let radius = size * 0.30
        let base = SnoozyArtworkView(
            artworkPath: track.artworkPath,
            size: size,
            cornerRadius: radius,
            theme: theme
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 5, x: 0, y: 2)

        if let ns = artworkNamespace {
            base.matchedGeometryEffect(id: "nowPlayingArtwork-\(track.id)", in: ns)
        } else {
            base
        }
    }

    private var controlDivider: some View {
        Rectangle()
            .fill(theme.ink.opacity(theme.isDark ? 0.18 : 0.14))
            .frame(width: 0.5, height: 18)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
