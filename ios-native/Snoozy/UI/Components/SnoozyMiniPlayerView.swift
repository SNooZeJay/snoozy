import SwiftUI

public struct SnoozyMiniPlayerView: View {
    public let track: Track
    public let isPlaying: Bool
    public let progress: Double
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    public var artworkNamespace: Namespace.ID? = nil
    public let onOpenPlayer: () -> Void
    public let onTogglePlay: () -> Void
    public let onNext: () -> Void
    public var onPrevious: (() -> Void)? = nil
    @Environment(\.snoozyLayout) private var layout

    public init(
        track: Track,
        isPlaying: Bool,
        progress: Double,
        theme: SnoozyThemeColors,
        preferences: SnoozyPreferences,
        artworkNamespace: Namespace.ID? = nil,
        onOpenPlayer: @escaping () -> Void,
        onTogglePlay: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrevious: (() -> Void)? = nil
    ) {
        self.track = track
        self.isPlaying = isPlaying
        self.progress = progress
        self.theme = theme
        self.preferences = preferences
        self.artworkNamespace = artworkNamespace
        self.onOpenPlayer = onOpenPlayer
        self.onTogglePlay = onTogglePlay
        self.onNext = onNext
        self.onPrevious = onPrevious
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onOpenPlayer) {
                    HStack(spacing: 12) {
                        artworkThumbnail
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
                .buttonStyle(.plain)

                Button(action: onTogglePlay) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(theme.ink)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "Pause" : "Play")

                Button(action: onNext) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(theme.ink)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next track")
            }
            .padding(.leading, 10)
            .padding(.trailing, 8)
            .frame(height: layout.miniPlayerHeight)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 2.0)
                    Capsule()
                        .fill(theme.accent)
                        .frame(width: max(0, min(proxy.size.width, proxy.size.width * progress)), height: 2.0)
                }
            }
            .frame(height: 2.0)
            .padding(.horizontal, 16)
            .padding(.bottom, 3)
        }
        .liquidGlassSurface(
            cornerRadius: 20,
            glassMode: preferences.glassMode,
            refractionIntensity: preferences.refractionIntensity,
            tintColor: theme.accent,
            variant: .ultraClear
        )
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.height < -28 {
                        onOpenPlayer()
                    } else if value.translation.width < -40 {
                        onNext()
                    } else if value.translation.width > 40 {
                        onPrevious?()
                    }
                }
        )
    }

    @ViewBuilder
    private var artworkThumbnail: some View {
        let thumbSize: CGFloat = layout.isCompactWidth ? 38 : 42
        let base = SnoozyArtworkView(
            artworkPath: track.artworkPath,
            size: thumbSize,
            cornerRadius: 9,
            theme: theme
        )
        .shadow(color: Color.black.opacity(0.28), radius: 5, x: 0, y: 2)

        if let ns = artworkNamespace {
            base.matchedGeometryEffect(id: "nowPlayingArtwork-\(track.id)", in: ns)
        } else {
            base
        }
    }
}
