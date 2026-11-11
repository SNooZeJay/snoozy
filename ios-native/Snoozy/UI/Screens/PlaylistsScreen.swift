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

    public var body: some View {
        let byId = Dictionary(uniqueKeysWithValues: repository.tracks.map { ($0.id, $0) })
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Playlists")
                            .font(SnoozyTypography.display(28))
                            .foregroundStyle(theme.ink)
                        Text("\(SnoozyFormat.countLabel(repository.playlists.count, "playlist", "playlists")) · saved on this iPhone")
                            .font(SnoozyTypography.footnote(13))
                            .foregroundStyle(theme.inkMuted)
                    }
                    Spacer()
                    LiquidGlassIconButton(
                        systemImage: "plus",
                        accessibilityLabel: "New playlist",
                        theme: theme,
                        preferences: repository.preferences
                    ) {
                        newPlaylistName = ""
                        showCreateAlert = true
                    }
                }

                if repository.playlists.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 36))
                            .foregroundStyle(theme.inkFaint)
                        Text("No playlists yet")
                            .font(SnoozyTypography.headline(17))
                            .foregroundStyle(theme.ink)
                        Text("Build a set for a walk, a drive, or a quiet evening. Open a playlist to add songs.")
                            .font(SnoozyTypography.footnote(13))
                            .foregroundStyle(theme.inkMuted)
                            .multilineTextAlignment(.center)
                        LiquidGlassButton(
                            title: "Create a playlist",
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
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(repository.playlists) { playlist in
                            let tracks = playlist.trackIds.compactMap { byId[$0] }
                            HStack(spacing: 12) {
                                Button {
                                    onOpenPlaylist(playlist.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        SnoozyPlaylistCollageView(
                                            artworkPaths: tracks.map(\.artworkPath),
                                            size: 48,
                                            cornerRadius: 12,
                                            theme: theme
                                        )
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(playlist.name)
                                                .font(SnoozyTypography.body(15, bold: true))
                                                .foregroundStyle(theme.ink)
                                                .lineLimit(1)
                                            Text(SnoozyFormat.countLabel(tracks.count, "track", "tracks"))
                                                .font(SnoozyTypography.footnote(12))
                                                .foregroundStyle(theme.inkMuted)
                                        }
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Menu {
                                    Button("Rename", systemImage: "pencil") {
                                        renameText = playlist.name
                                        renameTarget = playlist
                                    }
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        deleteTarget = playlist
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(theme.inkMuted)
                                        .frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("Manage \(playlist.name)")
                            }
                            .padding(.leading, 10)
                            .padding(.trailing, 4)
                            .padding(.vertical, 6)
                            .liquidGlassSurface(
                                cornerRadius: 18,
                                glassMode: repository.preferences.glassMode,
                                refractionIntensity: repository.preferences.refractionIntensity * 0.75,
                                tintColor: theme.accent
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, playback.activeTrack != nil ? 168 : 104)
        }
        .alert("New Playlist", isPresented: $showCreateAlert) {
            TextField("Playlist name", text: $newPlaylistName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                _ = repository.createPlaylist(name: newPlaylistName)
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
}

public struct PlaylistDetailScreen: View {
    public let playlistId: String
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors

    @State private var showAddSongsSheet: Bool = false
    @State private var showRenameAlert: Bool = false
    @State private var renameText: String = ""
    @State private var showDeleteAlert: Bool = false
    @Environment(\.dismiss) private var dismiss

    private var playlist: Playlist? {
        repository.playlists.first(where: { $0.id == playlistId })
    }

    private var tracks: [Track] {
        guard let playlist else { return [] }
        let byId = Dictionary(uniqueKeysWithValues: repository.tracks.map { ($0.id, $0) })
        return playlist.trackIds.compactMap { byId[$0] }
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if let playlist {
                    SnoozyPlaylistCollageView(
                        artworkPaths: tracks.map(\.artworkPath),
                        size: 180,
                        cornerRadius: 28,
                        theme: theme
                    )
                    .padding(.top, 8)

                    VStack(spacing: 4) {
                        Text(playlist.name)
                            .font(SnoozyTypography.title(22))
                            .foregroundStyle(theme.ink)
                        let totalDuration = tracks.reduce(0.0) { $0 + $1.duration }
                        Text("\(SnoozyFormat.countLabel(tracks.count, "track", "tracks")) · \(SnoozyFormat.formatDuration(totalDuration))")
                            .font(SnoozyTypography.footnote(13))
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
                        },
                        trailing: AnyView(
                            LiquidGlassButton(
                                title: "Add songs",
                                systemImage: "plus",
                                theme: theme,
                                preferences: repository.preferences
                            ) {
                                showAddSongsSheet = true
                            }
                        )
                    )

                    if tracks.isEmpty {
                        Text("No songs in this playlist yet. Tap Add songs above.")
                            .font(SnoozyTypography.footnote(13))
                            .foregroundStyle(theme.inkMuted)
                            .padding(.top, 16)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                                HStack(spacing: 8) {
                                    Button {
                                        playback.playTrack(track, queue: tracks)
                                    } label: {
                                        HStack(spacing: 10) {
                                            SnoozyArtworkView(artworkPath: track.artworkPath, size: 44, cornerRadius: 10, theme: theme)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(track.title)
                                                    .font(SnoozyTypography.body(14, bold: true))
                                                    .foregroundStyle(playback.activeTrack?.id == track.id ? theme.accent : theme.ink)
                                                    .lineLimit(1)
                                                Text("\(track.artist) · \(track.album)")
                                                    .font(SnoozyTypography.footnote(12))
                                                    .foregroundStyle(theme.inkMuted)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    Menu {
                                        Button("Play next", systemImage: "text.insert") {
                                            playback.playNext(track)
                                        }
                                        Button("Add to queue", systemImage: "text.append") {
                                            playback.addToQueue(track)
                                        }
                                        if index > 0 {
                                            Button("Move up", systemImage: "arrow.up") {
                                                repository.movePlaylistTrack(playlistId: playlist.id, from: index, to: index - 1)
                                            }
                                        }
                                        if index + 1 < tracks.count {
                                            Button("Move down", systemImage: "arrow.down") {
                                                repository.movePlaylistTrack(playlistId: playlist.id, from: index, to: index + 1)
                                            }
                                        }
                                        Button("Remove from playlist", systemImage: "trash", role: .destructive) {
                                            repository.removeFromPlaylist(playlistId: playlist.id, trackId: track.id)
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(theme.inkMuted)
                                            .frame(width: 44, height: 44)
                                    }
                                    .accessibilityLabel("Manage \(track.title) in \(playlist.name)")
                                }
                                .padding(.leading, 10)
                                .padding(.trailing, 4)
                                .padding(.vertical, 6)
                                .liquidGlassSurface(
                                    cornerRadius: 18,
                                    glassMode: repository.preferences.glassMode,
                                    refractionIntensity: repository.preferences.refractionIntensity * 0.75,
                                    tintColor: playback.activeTrack?.id == track.id ? theme.accent : .white
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, playback.activeTrack != nil ? 168 : 104)
        }
        .background(
            LiquidAuraBackgroundView(
                theme: theme,
                palette: playback.activePalette,
                preferences: repository.preferences
            )
        )
        .navigationTitle(playlist?.name ?? "Playlist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let playlist {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        renameText = playlist.name
                        showRenameAlert = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
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
