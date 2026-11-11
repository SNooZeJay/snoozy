import SwiftUI

public struct SnoozyMiniPlayerView: View {
    public let track: Track
    public let isPlaying: Bool
    public let progress: Double
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    public let onOpenPlayer: () -> Void
    public let onTogglePlay: () -> Void
    public let onNext: () -> Void

    public init(
        track: Track,
        isPlaying: Bool,
        progress: Double,
        theme: SnoozyThemeColors,
        preferences: SnoozyPreferences,
        onOpenPlayer: @escaping () -> Void,
        onTogglePlay: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) {
        self.track = track
        self.isPlaying = isPlaying
        self.progress = progress
        self.theme = theme
        self.preferences = preferences
        self.onOpenPlayer = onOpenPlayer
        self.onTogglePlay = onTogglePlay
        self.onNext = onNext
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: onOpenPlayer) {
                    HStack(spacing: 10) {
                        SnoozyArtworkView(
                            artworkPath: track.artworkPath,
                            size: 44,
                            cornerRadius: 12,
                            theme: theme
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(SnoozyTypography.body(14, bold: true))
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
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(theme.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "Pause" : "Play")

                Button(action: onNext) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next track")
            }
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .padding(.vertical, 8)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 2.5)
                    Capsule()
                        .fill(theme.accent)
                        .frame(width: max(0, min(proxy.size.width, proxy.size.width * progress)), height: 2.5)
                }
            }
            .frame(height: 2.5)
            .padding(.horizontal, 14)
            .padding(.bottom, 4)
        }
        .liquidGlassSurface(
            cornerRadius: 22,
            glassMode: preferences.glassMode,
            refractionIntensity: preferences.refractionIntensity,
            tintColor: theme.accent
        )
    }
}
