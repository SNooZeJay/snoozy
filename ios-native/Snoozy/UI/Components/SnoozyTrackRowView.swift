import SwiftUI

public struct SnoozyTrackRowView: View {
    public let track: Track
    public let subtitle: String
    public let isActive: Bool
    public let isFavorite: Bool
    public let showTopSeparator: Bool
    public let isGrouped: Bool
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    public let onTap: () -> Void
    public let onMenu: () -> Void

    public init(
        track: Track,
        subtitle: String,
        isActive: Bool,
        isFavorite: Bool = false,
        showTopSeparator: Bool = false,
        isGrouped: Bool = true,
        theme: SnoozyThemeColors,
        preferences: SnoozyPreferences,
        onTap: @escaping () -> Void,
        onMenu: @escaping () -> Void
    ) {
        self.track = track
        self.subtitle = subtitle
        self.isActive = isActive
        self.isFavorite = isFavorite
        self.showTopSeparator = showTopSeparator
        self.isGrouped = isGrouped
        self.theme = theme
        self.preferences = preferences
        self.onTap = onTap
        self.onMenu = onMenu
    }

    public var body: some View {
        VStack(spacing: 0) {
            if showTopSeparator {
                Rectangle()
                    .fill(Color.white.opacity(theme.isDark ? 0.10 : 0.14))
                    .frame(height: 0.5)
                    .padding(.leading, 68)
            }

            HStack(spacing: 12) {
                Button(action: onTap) {
                    HStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            SnoozyArtworkView(
                                artworkPath: track.artworkPath,
                                size: 44,
                                cornerRadius: 11,
                                theme: theme
                            )
                            if isActive {
                                Circle()
                                    .fill(theme.accent)
                                    .frame(width: 18, height: 18)
                                    .overlay(
                                        SnoozySoundWaveView(
                                            isActive: true,
                                            color: theme.accentInk,
                                            bars: 3,
                                            height: 9
                                        )
                                    )
                                    .offset(x: 3, y: 3)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
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
            .frame(minHeight: 60)
        }
        .modifier(
            GroupedOrStandaloneRowModifier(
                isGrouped: isGrouped,
                isActive: isActive,
                theme: theme,
                preferences: preferences
            )
        )
    }
}

private struct GroupedOrStandaloneRowModifier: ViewModifier {
    let isGrouped: Bool
    let isActive: Bool
    let theme: SnoozyThemeColors
    let preferences: SnoozyPreferences

    func body(content: Content) -> some View {
        if isGrouped {
            content
                .background(isActive ? theme.accent.opacity(0.10) : Color.clear)
        } else {
            content
                .liquidGlassSurface(
                    cornerRadius: 18,
                    glassMode: preferences.glassMode,
                    refractionIntensity: preferences.refractionIntensity * 0.75,
                    tintColor: isActive ? theme.accent : Color.white,
                    isProminent: false
                )
        }
    }
}

public struct SnoozyGroupedCard<Content: View>: View {
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    @ViewBuilder public let content: () -> Content

    public init(
        theme: SnoozyThemeColors,
        preferences: SnoozyPreferences,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.theme = theme
        self.preferences = preferences
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .liquidGlassSurface(
            cornerRadius: 26,
            glassMode: preferences.glassMode,
            refractionIntensity: preferences.refractionIntensity * 0.82,
            tintColor: theme.accent
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
