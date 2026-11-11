import SwiftUI

public struct PlayerScreen: View {
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors
    public let onClose: () -> Void
    public let onOpenArtist: (String) -> Void
    public let onOpenAlbum: (String) -> Void

    @State private var isScrubbing: Bool = false
    @State private var scrubPosition: Double = 0.0
    @State private var showQueueSheet: Bool = false
    @State private var showLyricsSheet: Bool = false
    @State private var showAddToPlaylistSheet: Bool = false
    @State private var showMetadataSheet: Bool = false

    private static let speedChoices: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    public var body: some View {
        ZStack {
            LiquidAuraBackgroundView(
                theme: theme,
                palette: playback.activePalette,
                preferences: repository.preferences
            )

            if let track = playback.activeTrack {
                playerContent(for: track)
                    .sheet(isPresented: $showQueueSheet) {
                        QueueSheetView(
                            playback: playback,
                            theme: theme,
                            preferences: repository.preferences
                        )
                    }
                    .sheet(isPresented: $showLyricsSheet) {
                        LyricsSheetView(
                            track: track,
                            repository: repository,
                            playback: playback,
                            theme: theme,
                            preferences: repository.preferences
                        )
                    }
                    .sheet(isPresented: $showAddToPlaylistSheet) {
                        AddToPlaylistSheetView(
                            track: track,
                            repository: repository,
                            theme: theme,
                            preferences: repository.preferences
                        )
                    }
                    .sheet(isPresented: $showMetadataSheet) {
                        TrackMetadataEditSheetView(
                            track: track,
                            repository: repository,
                            theme: theme,
                            preferences: repository.preferences
                        )
                    }
            } else {
                emptyPlayerView
            }
        }
    }

    private func playerContent(for track: Track) -> some View {
        let isFav = repository.isFavorite(track.id)
        let totalDuration = max(1.0, max(playback.durationSeconds, track.duration))
        let displayPos = isScrubbing ? scrubPosition : min(playback.positionSeconds, totalDuration)

        return VStack(spacing: 16) {
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            HStack {
                LiquidGlassIconButton(
                    systemImage: "chevron.down",
                    accessibilityLabel: "Minimize player",
                    size: 40,
                    theme: theme,
                    preferences: repository.preferences,
                    action: onClose
                )

                Spacer()

                VStack(spacing: 2) {
                    Text("NOW PLAYING")
                        .font(SnoozyTypography.caption(10, bold: true))
                        .foregroundStyle(theme.inkFaint)
                    Text(track.album)
                        .font(SnoozyTypography.footnote(13))
                        .foregroundStyle(theme.inkMuted)
                        .lineLimit(1)
                }

                Spacer()

                LiquidGlassIconButton(
                    systemImage: "slider.horizontal.3",
                    accessibilityLabel: "Edit song metadata",
                    size: 40,
                    theme: theme,
                    preferences: repository.preferences
                ) {
                    showMetadataSheet = true
                }
            }

            Spacer(minLength: 2)

            SnoozyArtworkView(
                artworkPath: track.artworkPath,
                size: 276,
                cornerRadius: 34,
                theme: theme
            )
            .scaleEffect(playback.isPlaying ? 1.0 : 0.94)
            .animation(.spring(response: 0.38, dampingFraction: 0.76), value: playback.isPlaying)

            Spacer(minLength: 2)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(SnoozyTypography.title(22))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Button {
                            onClose()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                onOpenArtist(track.artist)
                            }
                        } label: {
                            Text(track.artist)
                                .font(SnoozyTypography.body(15, bold: true))
                                .foregroundStyle(theme.accent)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)

                        Text("·")
                            .foregroundStyle(theme.inkFaint)

                        Button {
                            onClose()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                onOpenAlbum(track.albumKey)
                            }
                        } label: {
                            Text(track.album)
                                .font(SnoozyTypography.footnote(13))
                                .foregroundStyle(theme.inkMuted)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                LiquidGlassIconButton(
                    systemImage: isFav ? "heart.fill" : "heart",
                    accessibilityLabel: isFav ? "Remove from Favorites" : "Add to Favorites",
                    size: 44,
                    isActive: isFav,
                    theme: theme,
                    preferences: repository.preferences
                ) {
                    repository.toggleFavorite(track.id)
                }
            }

            if let lyrics = playback.activeLyrics,
               let activeIdx = LyricsEngine.activeLineIndex(
                   lyrics: lyrics,
                   positionSeconds: playback.positionSeconds,
                   offsetSeconds: repository.lyricsOffset(for: track.id)
               ),
               lyrics.lines.indices.contains(activeIdx) {
                Button {
                    showLyricsSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.accent)
                        Text(lyrics.lines[activeIdx].text)
                            .font(SnoozyTypography.footnote(13))
                            .foregroundStyle(theme.ink)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .liquidGlassSurface(
                        cornerRadius: 14,
                        glassMode: repository.preferences.glassMode,
                        refractionIntensity: repository.preferences.refractionIntensity * 0.7,
                        tintColor: theme.accent
                    )
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { displayPos },
                        set: { newVal in
                            isScrubbing = true
                            scrubPosition = newVal
                        }
                    ),
                    in: 0...totalDuration,
                    onEditingChanged: { editing in
                        isScrubbing = editing
                        if !editing {
                            playback.seek(to: scrubPosition)
                        }
                    }
                )
                .tint(theme.accent)

                HStack {
                    Text(SnoozyFormat.formatClock(displayPos))
                        .font(SnoozyTypography.caption(11, bold: true))
                        .foregroundStyle(theme.inkMuted)
                    Spacer()
                    Text(SnoozyFormat.formatClock(totalDuration))
                        .font(SnoozyTypography.caption(11, bold: true))
                        .foregroundStyle(theme.inkMuted)
                }
            }

            HStack(spacing: 18) {
                LiquidGlassIconButton(
                    systemImage: "shuffle",
                    accessibilityLabel: playback.shuffle ? "Disable shuffle" : "Enable shuffle",
                    size: 44,
                    isActive: playback.shuffle,
                    theme: theme,
                    preferences: repository.preferences
                ) {
                    playback.toggleShuffle()
                }

                LiquidGlassIconButton(
                    systemImage: "backward.fill",
                    accessibilityLabel: "Previous track",
                    size: 50,
                    theme: theme,
                    preferences: repository.preferences
                ) {
                    playback.previous()
                }

                Button {
                    playback.togglePlayback()
                } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(theme.accentInk)
                        .frame(width: 68, height: 68)
                        .liquidGlassSurface(
                            cornerRadius: 34,
                            glassMode: repository.preferences.glassMode,
                            refractionIntensity: repository.preferences.refractionIntensity,
                            tintColor: theme.accent,
                            isProminent: true
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(playback.isPlaying ? "Pause" : "Play")

                LiquidGlassIconButton(
                    systemImage: "forward.fill",
                    accessibilityLabel: "Next track",
                    size: 50,
                    theme: theme,
                    preferences: repository.preferences
                ) {
                    playback.next()
                }

                LiquidGlassIconButton(
                    systemImage: playback.repeatMode == .one ? "repeat.1" : "repeat",
                    accessibilityLabel: playback.repeatMode.label,
                    size: 44,
                    isActive: playback.repeatMode != .off,
                    theme: theme,
                    preferences: repository.preferences
                ) {
                    playback.cycleRepeat()
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                Menu {
                    ForEach(Self.speedChoices, id: \.self) { rate in
                        Button {
                            playback.setSpeed(rate)
                        } label: {
                            HStack {
                                Text(String(format: "%.2gx", rate))
                                if abs(playback.playbackRate - rate) < 0.01 {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    bottomActionPill(
                        icon: "gauge.with.dots.needle.50percent",
                        title: String(format: "%.2gx", playback.playbackRate),
                        isActive: abs(playback.playbackRate - 1.0) > 0.01
                    )
                }

                Button {
                    showLyricsSheet = true
                } label: {
                    bottomActionPill(
                        icon: "quote.bubble",
                        title: "Lyrics",
                        isActive: playback.activeLyrics != nil
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showQueueSheet = true
                } label: {
                    bottomActionPill(
                        icon: "list.bullet",
                        title: "Queue (\(playback.queueTracks.count))",
                        isActive: false
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showAddToPlaylistSheet = true
                } label: {
                    bottomActionPill(
                        icon: "text.badge.plus",
                        title: "Playlist",
                        isActive: false
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
    }

    private func bottomActionPill(icon: String, title: String, isActive: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(SnoozyTypography.caption(12, bold: true))
                .lineLimit(1)
        }
        .foregroundStyle(isActive ? theme.accent : theme.ink)
        .padding(.horizontal, 10)
        .frame(height: 36)
        .frame(maxWidth: .infinity)
        .liquidGlassSurface(
            cornerRadius: 18,
            glassMode: repository.preferences.glassMode,
            refractionIntensity: repository.preferences.refractionIntensity * 0.75,
            tintColor: theme.accent
        )
    }

    private var emptyPlayerView: some View {
        VStack(spacing: 14) {
            Text("Nothing playing")
                .font(SnoozyTypography.title(20))
                .foregroundStyle(theme.ink)
            LiquidGlassButton(
                title: "Close",
                systemImage: "xmark",
                theme: theme,
                preferences: repository.preferences,
                action: onClose
            )
        }
    }
}
