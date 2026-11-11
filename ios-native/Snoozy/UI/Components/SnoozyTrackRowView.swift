import SwiftUI

public struct SnoozyTrackRowView: View {
    public let track: Track
    public let subtitle: String
    public let isActive: Bool
    public let isFavorite: Bool
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    public let onTap: () -> Void
    public let onMenu: () -> Void

    public init(
        track: Track,
        subtitle: String,
        isActive: Bool,
        isFavorite: Bool = false,
        theme: SnoozyThemeColors,
        preferences: SnoozyPreferences,
        onTap: @escaping () -> Void,
        onMenu: @escaping () -> Void
    ) {
        self.track = track
        self.subtitle = subtitle
        self.isActive = isActive
        self.isFavorite = isFavorite
        self.theme = theme
        self.preferences = preferences
        self.onTap = onTap
        self.onMenu = onMenu
    }

    public var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        SnoozyArtworkView(
                            artworkPath: track.artworkPath,
                            size: 46,
                            cornerRadius: 12,
                            theme: theme
                        )
                        if isActive {
                            Circle()
                                .fill(theme.accent)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Image(systemName: "waveform")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(theme.accentInk)
                                )
                                .offset(x: 3, y: 3)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Text(track.title)
                                .font(SnoozyTypography.body(15, bold: true))
                                .foregroundStyle(isActive ? theme.accent : theme.ink)
                                .lineLimit(1)
                            if isFavorite {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.accent)
                            }
                        }
                        Text(subtitle)
                            .font(SnoozyTypography.footnote(13))
                            .foregroundStyle(theme.inkMuted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Text(SnoozyFormat.formatClock(track.duration))
                        .font(SnoozyTypography.caption(12))
                        .foregroundStyle(theme.inkFaint)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onMenu) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.inkMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Manage \(track.title)")
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 6)
        .liquidGlassSurface(
            cornerRadius: 18,
            glassMode: preferences.glassMode,
            refractionIntensity: preferences.refractionIntensity * 0.75,
            tintColor: isActive ? theme.accent : Color.white,
            isProminent: false
        )
    }
}

public struct SnoozyCollectionActionsRow: View {
    public let playLabel: String
    public let shuffleLabel: String
    public let isEnabled: Bool
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    public let onPlay: () -> Void
    public let onShuffle: () -> Void
    public let trailing: AnyView?

    public init(
        playLabel: String = "Play",
        shuffleLabel: String = "Shuffle",
        isEnabled: Bool = true,
        theme: SnoozyThemeColors,
        preferences: SnoozyPreferences,
        onPlay: @escaping () -> Void,
        onShuffle: @escaping () -> Void,
        trailing: AnyView? = nil
    ) {
        self.playLabel = playLabel
        self.shuffleLabel = shuffleLabel
        self.isEnabled = isEnabled
        self.theme = theme
        self.preferences = preferences
        self.onPlay = onPlay
        self.onShuffle = onShuffle
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: 10) {
            LiquidGlassButton(
                title: "Play",
                systemImage: "play.fill",
                isProminent: true,
                isDisabled: !isEnabled,
                theme: theme,
                preferences: preferences,
                action: onPlay
            )
            .accessibilityLabel(playLabel)

            LiquidGlassButton(
                title: "Shuffle",
                systemImage: "shuffle",
                isProminent: false,
                isDisabled: !isEnabled,
                theme: theme,
                preferences: preferences,
                action: onShuffle
            )
            .accessibilityLabel(shuffleLabel)

            if let trailing {
                trailing
            }
        }
    }
}
