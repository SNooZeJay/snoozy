import SwiftUI

public struct PlaylistsScreen: View {
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors
    public let onOpenPlaylist: (String) -> Void

    @State private var showCreateAlert: Bool = false
    @State private var newPlaylistName: String = ""
    @State private var renameTarget: Playlist? = nil
    @State private var renameText: String = ""
    @State private var deleteTarget: Playlist? = nil
    @State private var gridMode: Bool = true
    @Environment(\.snoozyLayout) private var layout

    public init(
        repository: LibraryRepository,
        playback: PlaybackController,
        theme: SnoozyThemeColors,
        onOpenPlaylist: @escaping (String) -> Void
    ) {
        self.repository = repository
        self.playback = playback
        self.theme = theme
        self.onOpenPlaylist = onOpenPlaylist
    }

    public var body: some View {
        let byId = repository.tracksById
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    SnoozyBrandIconView(size: layout.brandIconSize)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Playlists")
                            .font(SnoozyTypography.display(layout.headerTitleSize))
                            .foregroundStyle(theme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Text("\(SnoozyFormat.countLabel(repository.playlists.count, "playlist", "playlists")) · saved on this iPhone")
                            .font(SnoozyTypography.footnote(12))
                            .foregroundStyle(theme.inkMuted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    SnoozyGlassEffectContainer(spacing: 6) {
                        HStack(spacing: 6) {
                            if !repository.playlists.isEmpty {
                                LiquidGlassIconButton(
                                    systemImage: gridMode ? "list.bullet" : "square.grid.2x2",
                                    accessibilityLabel: gridMode ? "Show playlist list" : "Show playlist grid",
                                    size: layout.headerButtonSize,
                                    theme: theme,
                                    preferences: repository.preferences
                                ) {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) {
                                        gridMode.toggle()
                                    }
                                }
                            }

                            LiquidGlassIconButton(
                                systemImage: "plus",
                                accessibilityLabel: "New playlist",
                                size: layout.headerButtonSize,
                                theme: theme,
                                preferences: repository.preferences
                            ) {
                                newPlaylistName = ""
                                showCreateAlert = true
                            }
                        }
                    }
                }

                if repository.playlists.isEmpty {
                    emptyPlaylistsCard
                } else if gridMode {
                    playlistsGrid(byId: byId)
                } else {
                    playlistsGroupedList(byId: byId)
                }
            }
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.top, layout.isLandscape ? 8 : 10)
            .padding(.bottom, layout.scrollBottomPadding(hasMiniPlayer: playback.activeTrack != nil))
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("New Playlist", isPresented: $showCreateAlert) {
            TextField("Playlist name", text: $newPlaylistName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                if let createdId = repository.createPlaylist(name: newPlaylistName) {
                    onOpenPlaylist(createdId)
                }
            }
        }
        .alert(
            "Rename Playlist",
            isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )
        ) {
            TextField("Playlist name", text: $renameText)
            Button("Cancel", role: .cancel) { renameTarget = nil }
            Button("Save") {
                if let target = renameTarget {
                    repository.renamePlaylist(id: target.id, name: renameText)
                }
                renameTarget = nil
            }
        }
        .alert(
            "Delete playlist?",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { deleteTarget = nil }
            Button("Delete", role: .destructive) {
                if let target = deleteTarget {
                    repository.deletePlaylist(id: target.id)
                }
                deleteTarget = nil
            }
        } message: {
            Text("\"\(deleteTarget?.name ?? "")\" will be removed. Your songs stay in the library.")
        }
    }

    private var emptyPlaylistsCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note.list")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(theme.accent)
            Text("No Playlists Yet")
                .font(SnoozyTypography.headline(18))
                .foregroundStyle(theme.ink)
            Text("Create personal offline playlists from the songs stored on your iPhone.")
                .font(SnoozyTypography.footnote(13))
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
            LiquidGlassButton(
                title: "New Playlist",
                systemImage: "plus",
                isProminent: true,
                theme: theme,
                preferences: repository.preferences
            ) {
                newPlaylistName = ""
                showCreateAlert = true
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .liquidGlassSurface(
            cornerRadius: 24,
            glassMode: repository.preferences.glassMode,
            refractionIntensity: repository.preferences.refractionIntensity,
            tintColor: theme.accent
        )
    }

    private func playlistsGrid(byId: [String: Track]) -> some View {
        let tileSize = layout.gridTileSize
        return LazyVGrid(columns: layout.gridItems, spacing: 18) {
            ForEach(repository.playlists) { playlist in
                let tracks = playlist.trackIds.compactMap { byId[$0] }
                Button {
                    onOpenPlaylist(playlist.id)
                } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        SnoozyPlaylistCollageView(
                            artworkPaths: tracks.map(\.artworkPath),
                            size: tileSize,
                            cornerRadius: 16,
                            theme: theme
                        )
                        .shadow(color: Color.black.opacity(theme.isDark ? 0.34 : 0.14), radius: 10, x: 0, y: 5)

                        Text(playlist.name)
                            .font(SnoozyTypography.body(14, bold: true))
                            .foregroundStyle(theme.ink)
                            .lineLimit(1)

                        Text(SnoozyFormat.countLabel(tracks.count, "song", "songs"))
                            .font(SnoozyTypography.caption(12))
                            .foregroundStyle(theme.inkMuted)
                            .lineLimit(1)
                    }
                    .frame(width: tileSize, alignment: .leading)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if let first = tracks.first {
                        Button {
                            playback.playTrack(first, queue: tracks, shuffleOverride: false)
                        } label: {
                            Label("Play", systemImage: "play.fill")
                        }
                        Button {
                            let shuffled = tracks.shuffled()
                            if let sFirst = shuffled.first {
                                playback.playTrack(sFirst, queue: shuffled, shuffleOverride: true)
                            }
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                        }
                    }
                    Button {
                        renameText = playlist.name
                        renameTarget = playlist
                    } label: {
                        Label("Rename Playlist…", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deleteTarget = playlist
                    } label: {
                        Label("Delete Playlist", systemImage: "trash")
                    }
                }
            }
        }
    }

    private func playlistsGroupedList(byId: [String: Track]) -> some View {
        SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
            LazyVStack(spacing: 0) {
                ForEach(Array(repository.playlists.enumerated()), id: \.element.id) { index, playlist in
                    let tracks = playlist.trackIds.compactMap { byId[$0] }
                    VStack(spacing: 0) {
                        if index > 0 {
                            Rectangle()
                                .fill(Color.white.opacity(theme.isDark ? 0.08 : 0.14))
                                .frame(height: 0.5)
                                .padding(.leading, 72)
                        }
                        HStack(spacing: 12) {
                            Button {
                                onOpenPlaylist(playlist.id)
                            } label: {
                                HStack(spacing: 12) {
                                    SnoozyPlaylistCollageView(
                                        artworkPaths: tracks.map(\.artworkPath),
                                        size: 48,
                                        cornerRadius: 10,
                                        theme: theme
                                    )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.name)
                                            .font(SnoozyTypography.body(15, bold: true))
                                            .foregroundStyle(theme.ink)
                                            .lineLimit(1)
                                        Text(SnoozyFormat.countLabel(tracks.count, "song", "songs"))
                                            .font(SnoozyTypography.footnote(12))
                                            .foregroundStyle(theme.inkMuted)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Menu {
                                if let first = tracks.first {
                                    Button("Play", systemImage: "play.fill") {
                                        playback.playTrack(first, queue: tracks, shuffleOverride: false)
                                    }
                                    Button("Shuffle", systemImage: "shuffle") {
                                        let shuffled = tracks.shuffled()
                                        if let sFirst = shuffled.first {
                                            playback.playTrack(sFirst, queue: shuffled, shuffleOverride: true)
                                        }
                                    }
                                }
                                Button("Rename", systemImage: "pencil") {
                                    renameText = playlist.name
                                    renameTarget = playlist
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    deleteTarget = playlist
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(theme.inkMuted)
                                    .frame(width: 40, height: 44)
                            }
                            .accessibilityLabel("Manage \(playlist.name)")
                        }
                        .padding(.leading, 12)
                        .padding(.trailing, 8)
                        .padding(.vertical, 7)
                    }
                }
            }
        }
    }
}

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
                                            elevation: .ultraClear
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
