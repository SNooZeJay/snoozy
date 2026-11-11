import SwiftUI

public struct SnoozyTrackRowView: View {
    public let track: Track
    public let subtitle: String
    public let trackNumberBadge: Int?
    public let isActive: Bool
    public let isFavorite: Bool
    public let showTopSeparator: Bool
    public let isGrouped: Bool
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    public let onTap: () -> Void
    public let onMenu: () -> Void
    public var onPlayNext: (() -> Void)? = nil
    public var onAddToQueue: (() -> Void)? = nil
    public var onToggleFavorite: (() -> Void)? = nil

    public init(
        track: Track,
        subtitle: String,
        trackNumberBadge: Int? = nil,
        isActive: Bool,
        isFavorite: Bool = false,
        showTopSeparator: Bool = false,
        isGrouped: Bool = true,
        theme: SnoozyThemeColors,
        preferences: SnoozyPreferences,
        onTap: @escaping () -> Void,
        onMenu: @escaping () -> Void,
        onPlayNext: (() -> Void)? = nil,
        onAddToQueue: (() -> Void)? = nil,
        onToggleFavorite: (() -> Void)? = nil
    ) {
        self.track = track
        self.subtitle = subtitle
        self.trackNumberBadge = trackNumberBadge
        self.isActive = isActive
        self.isFavorite = isFavorite
        self.showTopSeparator = showTopSeparator
        self.isGrouped = isGrouped
        self.theme = theme
        self.preferences = preferences
        self.onTap = onTap
        self.onMenu = onMenu
        self.onPlayNext = onPlayNext
        self.onAddToQueue = onAddToQueue
        self.onToggleFavorite = onToggleFavorite
    }

    public var body: some View {
        VStack(spacing: 0) {
            if showTopSeparator {
                Rectangle()
                    .fill(Color.white.opacity(theme.isDark ? 0.09 : 0.14))
                    .frame(height: 0.5)
                    .padding(.leading, trackNumberBadge != nil ? 48 : 72)
            }

            HStack(spacing: 12) {
                Button(action: onTap) {
                    HStack(spacing: 12) {
                        if let number = trackNumberBadge {
                            ZStack {
                                if isActive {
                                    SnoozySoundWaveView(
                                        isActive: true,
                                        color: theme.accent,
                                        bars: 3,
                                        height: 12
                                    )
                                } else {
                                    Text("\(number)")
                                        .font(SnoozyTypography.body(14, bold: false))
                                        .foregroundStyle(theme.inkMuted)
                                }
                            }
                            .frame(width: 24, alignment: .center)
                        } else {
                            ZStack(alignment: .bottomTrailing) {
                                SnoozyArtworkView(
                                    artworkPath: track.artworkPath,
                                    size: 48,
                                    cornerRadius: 10,
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
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 5) {
                                if isFavorite {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(theme.accent)
                                }
                                Text(track.title)
                                    .font(SnoozyTypography.body(16, bold: true))
                                    .foregroundStyle(isActive ? theme.accent : theme.ink)
                                    .lineLimit(1)
                            }
                            HStack(spacing: 6) {
                                Text(subtitle)
                                    .font(SnoozyTypography.footnote(13))
                                    .foregroundStyle(theme.inkMuted)
                                    .lineLimit(1)
                                if track.isLosslessFormat {
                                    Text(track.audioFormatBadge)
                                        .font(SnoozyTypography.caption(9, bold: true))
                                        .foregroundStyle(theme.inkMuted)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(
                                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                .fill(Color.white.opacity(theme.isDark ? 0.10 : 0.16))
                                        )
                                }
                            }
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
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.inkMuted)
                        .frame(width: 40, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Options for \(track.title)")
            }
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .frame(minHeight: 62)
        }
        .background(isActive ? theme.accent.opacity(0.08) : Color.clear)
        .contextMenu {
            Button {
                onTap()
            } label: {
                Label("Play", systemImage: "play.fill")
            }
            if let onPlayNext {
                Button {
                    onPlayNext()
                } label: {
                    Label("Play Next", systemImage: "text.insert")
                }
            }
            if let onAddToQueue {
                Button {
                    onAddToQueue()
                } label: {
                    Label("Add to Queue", systemImage: "text.append")
                }
            }
            if let onToggleFavorite {
                Button {
                    onToggleFavorite()
                } label: {
                    Label(
                        isFavorite ? "Remove from Favorites" : "Favorite",
                        systemImage: isFavorite ? "star.slash.fill" : "star.fill"
                    )
                }
            }
            Button {
                onMenu()
            } label: {
                Label("More Options…", systemImage: "ellipsis.circle")
            }
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
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        VStack(spacing: 0) {
            content()
        }
        .background(shape.fill(theme.surface))
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                Color.white.opacity(theme.isDark ? 0.08 : 0.22),
                lineWidth: 0.6
            )
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
        SnoozyGlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: onPlay) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 15, weight: .bold))
                        Text("Play")
                            .font(SnoozyTypography.body(16, bold: true))
                    }
                    .foregroundStyle(theme.accentInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .liquidGlassSurface(
                        cornerRadius: 14,
                        glassMode: preferences.glassMode,
                        refractionIntensity: preferences.refractionIntensity,
                        tintColor: theme.accent,
                        isProminent: true
                    )
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1.0 : 0.45)
                .accessibilityLabel(playLabel)

                Button(action: onShuffle) {
                    HStack(spacing: 8) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 15, weight: .bold))
                        Text("Shuffle")
                            .font(SnoozyTypography.body(16, bold: true))
                    }
                    .foregroundStyle(theme.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .liquidGlassSurface(
                        cornerRadius: 14,
                        glassMode: preferences.glassMode,
                        refractionIntensity: preferences.refractionIntensity,
                        tintColor: theme.accent,
                        isProminent: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1.0 : 0.45)
                .accessibilityLabel(shuffleLabel)

                if let trailing {
                    trailing
                }
            }
        }
    }
}
