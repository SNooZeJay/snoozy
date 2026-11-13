import SwiftUI

public struct PlaylistDetailScreen: View {
    public let playlistId: String
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors
    public var onSelectTrackForMenu: ((Track) -> Void)? = nil

    @State private var showAddSongsSheet: Bool = false
    @State private var showRenameAlert: Bool = false
    @State private var renameText: String = ""
    @State private var showDeleteAlert: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.snoozyLayout) private var layout

    public init(
        playlistId: String,
        repository: LibraryRepository,
        playback: PlaybackController,
        theme: SnoozyThemeColors,
        onSelectTrackForMenu: ((Track) -> Void)? = nil
    ) {
        self.playlistId = playlistId
        self.repository = repository
        self.playback = playback
        self.theme = theme
        self.onSelectTrackForMenu = onSelectTrackForMenu
    }

    private var playlist: Playlist? {
        repository.playlists.first(where: { $0.id == playlistId })
    }

    private var tracks: [Track] {
        guard let playlist else { return [] }
        let byId = repository.tracksById
        return playlist.trackIds.compactMap { byId[$0] }
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                HStack(spacing: 10) {
                    LiquidGlassIconButton(
                        systemImage: "chevron.left",
                        accessibilityLabel: "Back",
                        size: layout.headerButtonSize,
                        theme: theme,
                        preferences: repository.preferences
                    ) {
                        dismiss()
                    }

                    Spacer()

                    if let playlist {
                        SnoozyGlassEffectContainer(spacing: 8) {
                            HStack(spacing: 8) {
                                LiquidGlassIconButton(
                                    systemImage: "plus",
                                    accessibilityLabel: "Add songs",
                                    size: layout.headerButtonSize,
                                    theme: theme,
                                    preferences: repository.preferences
                                ) {
                                    showAddSongsSheet = true
                                }

                                Menu {
                                    Button("Rename Playlist", systemImage: "pencil") {
                                        renameText = playlist.name
                                        showRenameAlert = true
                                    }
                                    Button("Delete Playlist", systemImage: "trash", role: .destructive) {
                                        showDeleteAlert = true
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: max(15, layout.headerButtonSize * 0.42), weight: .semibold))
                                        .foregroundStyle(theme.ink)
                                        .frame(width: layout.headerButtonSize, height: layout.headerButtonSize)
                                        .liquidGlassSurface(
                                            cornerRadius: layout.headerButtonSize * 0.5,
                                            glassMode: repository.preferences.glassMode,
                                            refractionIntensity: repository.preferences.refractionIntensity,
                                            tintColor: theme.accent,
                                            variant: .ultraClear
                                        )
                                }
                                .accessibilityLabel("Playlist options")
                            }
                        }
                    }
                }
                .padding(.top, layout.isLandscape ? 8 : 10)

                if let playlist {
                    SnoozyPlaylistCollageView(
                        artworkPaths: tracks.map(\.artworkPath),
                        size: layout.detailHeroArtworkSize,
                        cornerRadius: 20,
                        theme: theme
                    )
                    .shadow(color: Color.black.opacity(theme.isDark ? 0.45 : 0.18), radius: 22, x: 0, y: 12)
                    .padding(.top, 2)

                    VStack(spacing: 5) {
                        Text(playlist.name)
                            .font(SnoozyTypography.title(22))
                            .foregroundStyle(theme.ink)
                            .multilineTextAlignment(.center)

                        Text("Snoozy Local Playlist")
                            .font(SnoozyTypography.body(14, bold: true))
                            .foregroundStyle(theme.accent)

                        let totalDuration = tracks.reduce(0.0) { $0 + $1.duration }
                        Text("\(SnoozyFormat.countLabel(tracks.count, "song", "songs")) · \(SnoozyFormat.formatDuration(totalDuration))")
                            .font(SnoozyTypography.caption(12, bold: true))
                            .foregroundStyle(theme.inkMuted)
                    }

                    SnoozyCollectionActionsRow(
                        playLabel: "Play playlist",
                        shuffleLabel: "Shuffle playlist",
                        isEnabled: !tracks.isEmpty,
                        theme: theme,
                        preferences: repository.preferences,
                        onPlay: {
                            if let first = tracks.first {
                                playback.playTrack(first, queue: tracks, shuffleOverride: false)
                            }
                        },
                        onShuffle: {
                            let shuffled = tracks.shuffled()
                            if let first = shuffled.first {
                                playback.playTrack(first, queue: shuffled, shuffleOverride: true)
                            }
                        }
                    )

                    LiquidGlassButton(
                        title: "Add Songs to Playlist",
                        systemImage: "plus",
                        theme: theme,
                        preferences: repository.preferences
                    ) {
                        showAddSongsSheet = true
                    }

                    if tracks.isEmpty {
                        Text("No songs in this playlist yet. Tap Add Songs to Playlist above.")
                            .font(SnoozyTypography.footnote(13))
                            .foregroundStyle(theme.inkMuted)
                            .padding(.top, 16)
                    } else {
                        SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                                    SnoozyTrackRowView(
                                        track: track,
                                        subtitle: "\(track.artist) · \(track.album)",
                                        isActive: playback.activeTrack?.id == track.id,
                                        isFavorite: repository.isFavorite(track.id),
                                        showTopSeparator: index > 0,
                                        isGrouped: true,
                                        theme: theme,
                                        preferences: repository.preferences,
                                        onTap: { playback.playTrack(track, queue: tracks) },
                                        onMenu: {
                                            if let onSelectTrackForMenu {
                                                onSelectTrackForMenu(track)
                                            }
                                        },
                                        onPlayNext: { playback.playNext(track) },
                                        onAddToQueue: { playback.addToQueue(track) },
                                        onToggleFavorite: { repository.toggleFavorite(track.id) }
                                    )
                                    .contextMenu {
                                        Button("Play Next", systemImage: "text.insert") {
                                            playback.playNext(track)
                                        }
                                        Button("Add to Queue", systemImage: "text.append") {
                                            playback.addToQueue(track)
                                        }
                                        if index > 0 {
                                            Button("Move Up", systemImage: "arrow.up") {
                                                repository.movePlaylistTrack(playlistId: playlist.id, from: index, to: index - 1)
                                            }
                                        }
                                        if index + 1 < tracks.count {
                                            Button("Move Down", systemImage: "arrow.down") {
                                                repository.movePlaylistTrack(playlistId: playlist.id, from: index, to: index + 1)
                                            }
                                        }
                                        Button("Remove from Playlist", systemImage: "trash", role: .destructive) {
                                            repository.removeFromPlaylist(playlistId: playlist.id, trackId: track.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.bottom, layout.scrollBottomPadding(hasMiniPlayer: playback.activeTrack != nil))
        }
        .background(
            LiquidAuraBackgroundView(
                theme: theme,
                palette: playback.activePalette,
                preferences: repository.preferences,
                audioLevels: playback.audioLevels
            )
        )
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAddSongsSheet) {
            AddSongsToPlaylistSheetView(
                playlistId: playlistId,
                repository: repository,
                theme: theme,
                preferences: repository.preferences
            )
        }
        .alert("Rename playlist", isPresented: $showRenameAlert) {
            TextField("Playlist name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                repository.renamePlaylist(id: playlistId, name: renameText)
            }
        }
        .alert("Delete playlist?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                repository.deletePlaylist(id: playlistId)
                dismiss()
            }
        }
    }
}
