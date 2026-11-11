import SwiftUI

public struct HomeScreen: View {
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors
    public let onOpenAlbum: (String) -> Void
    public let onOpenPlaylist: (String) -> Void
    public let onOpenLibraryCategory: (LibraryTab) -> Void
    public let onImportFiles: () -> Void
    public let onImportFolder: () -> Void
    public let onSelectTrackForMenu: (Track) -> Void

    @State private var showClearRecentsAlert: Bool = false

    public init(
        repository: LibraryRepository,
        playback: PlaybackController,
        theme: SnoozyThemeColors,
        onOpenAlbum: @escaping (String) -> Void,
        onOpenPlaylist: @escaping (String) -> Void = { _ in },
        onOpenLibraryCategory: @escaping (LibraryTab) -> Void,
        onImportFiles: @escaping () -> Void,
        onImportFolder: @escaping () -> Void,
        onSelectTrackForMenu: @escaping (Track) -> Void = { _ in }
    ) {
        self.repository = repository
        self.playback = playback
        self.theme = theme
        self.onOpenAlbum = onOpenAlbum
        self.onOpenPlaylist = onOpenPlaylist
        self.onOpenLibraryCategory = onOpenLibraryCategory
        self.onImportFiles = onImportFiles
        self.onImportFolder = onImportFolder
        self.onSelectTrackForMenu = onSelectTrackForMenu
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                headerSection

                if let banner = repository.bannerMessage {
                    bannerRow(text: banner, isError: false) {
                        repository.bannerMessage = nil
                    }
                }
                if let err = playback.playbackError {
                    bannerRow(text: err, isError: true) {
                        playback.playbackError = nil
                    }
                }

                if repository.tracks.isEmpty {
                    emptyLibraryCard
                } else {
                    recentlyPlayedSection
                    recentlyPlayedAlbumsSection
                    recentlyAddedSection
                    mostPlayedSection
                    favoritesSection
                    playlistsSection
                    browseYourMusicSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, playback.activeTrack != nil ? 172 : 108)
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: onImportFiles) {
                    Image(systemName: "doc.badge.plus")
                }
                .accessibilityLabel("Import audio files")

                Button(action: onImportFolder) {
                    Image(systemName: "folder.badge.plus")
                }
                .accessibilityLabel("Import music folder")

                Button {
                    Task { await repository.scanLibrary() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Scan Snoozy folder")
            }
        }
        .alert("Clear recently played?", isPresented: $showClearRecentsAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                repository.clearRecentsAndHistory()
            }
        } message: {
            Text("Your play history and recent songs will be emptied.")
        }
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 10) {
            SnoozyBrandIconView(size: 32)

            Text(
                repository.isScanning
                    ? "Scanning On My iPhone > Snoozy…"
                    : "\(SnoozyFormat.countLabel(repository.tracks.count, "song", "songs")) · \(SnoozyFormat.countLabel(repository.albums.count, "album", "albums")) on this iPhone"
            )
            .font(SnoozyTypography.footnote(13))
            .foregroundStyle(theme.inkMuted)

            Spacer()
        }
    }

    private var emptyLibraryCard: some View {
        VStack(spacing: 14) {
            SnoozyBrandIconView(size: 68)

            Text("Your Personal Offline Music")
                .font(SnoozyTypography.title(21))
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.center)

            Text("Open the iPhone Files app and drop MP3, FLAC, WAV, M4A, or ALAC songs into On My iPhone > Snoozy, or import directly below.")
                .font(SnoozyTypography.body(14))
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)

            SnoozyGlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    LiquidGlassButton(
                        title: "Import Files",
                        systemImage: "doc.badge.plus",
                        isProminent: true,
                        theme: theme,
                        preferences: repository.preferences,
                        action: onImportFiles
                    )
                    LiquidGlassButton(
                        title: "Import Folder",
                        systemImage: "folder.badge.plus",
                        isProminent: false,
                        theme: theme,
                        preferences: repository.preferences,
                        action: onImportFolder
                    )
                }
            }

            Button {
                Task { await repository.createSampleSynthTrack() }
            } label: {
                Text("Generate Demo Synth Track (.WAV + Synced .LRC)")
                    .font(SnoozyTypography.caption(12, bold: true))
                    .foregroundStyle(theme.accent)
                    .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(theme.surface)
        )
    }

    // 1. Recently Played
    private var recentlyPlayedSection: some View {
        let recents = repository.recentTracks
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Recently Played",
                actionTitle: recents.isEmpty ? nil : "Clear",
                action: recents.isEmpty ? nil : { showClearRecentsAlert = true }
            )

            if recents.isEmpty {
                Text("Play any song from your offline library and it will appear here.")
                    .font(SnoozyTypography.footnote(13))
                    .foregroundStyle(theme.inkMuted)
                    .padding(.vertical, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(recents) { track in
                            appleMusicArtworkShelfItem(
                                title: track.title,
                                subtitle: track.artist,
                                artworkPath: track.artworkPath,
                                size: 154
                            ) {
                                playback.playTrack(track, queue: recents)
                            }
                            .contextMenu {
                                Button {
                                    playback.playTrack(track, queue: recents)
                                } label: {
                                    Label("Play", systemImage: "play.fill")
                                }
                                Button {
                                    playback.playNext(track)
                                } label: {
                                    Label("Play Next", systemImage: "text.insert")
                                }
                                Button {
                                    onSelectTrackForMenu(track)
                                } label: {
                                    Label("More Options…", systemImage: "ellipsis.circle")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 2. Recently Played Albums
    @ViewBuilder
    private var recentlyPlayedAlbumsSection: some View {
        let playedAlbums = repository.recentlyPlayedAlbums
        if !playedAlbums.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: "Recently Played Albums",
                    actionTitle: "See All",
                    action: { onOpenLibraryCategory(.albums) }
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(playedAlbums) { album in
                            appleMusicArtworkShelfItem(
                                title: album.title,
                                subtitle: album.artist,
                                artworkPath: album.artworkPath,
                                size: 154
                            ) {
                                onOpenAlbum(album.id)
                            }
                        }
                    }
                }
            }
        }
    }

    // 3. Recently Added (Apple Music 2-column grid preview + See All)
    @ViewBuilder
    private var recentlyAddedSection: some View {
        let recentAlbums = Array(repository.recentlyAddedAlbums.prefix(4))
        if !recentAlbums.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: "Recently Added",
                    actionTitle: "Albums",
                    action: { onOpenLibraryCategory(.albums) }
                )

                let cols = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
                LazyVGrid(columns: cols, spacing: 16) {
                    ForEach(recentAlbums) { album in
                        Button {
                            onOpenAlbum(album.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                SnoozyArtworkView(
                                    artworkPath: album.artworkPath,
                                    size: 164,
                                    cornerRadius: 14,
                                    theme: theme
                                )
                                .shadow(color: Color.black.opacity(0.24), radius: 8, x: 0, y: 4)
                                .frame(maxWidth: .infinity)

                                Text(album.title)
                                    .font(SnoozyTypography.body(14, bold: true))
                                    .foregroundStyle(theme.ink)
                                    .lineLimit(1)
                                Text(album.artist)
                                    .font(SnoozyTypography.footnote(12))
                                    .foregroundStyle(theme.inkMuted)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // 4. Most Played
    @ViewBuilder
    private var mostPlayedSection: some View {
        let mostPlayed = repository.mostPlayedTracks
        if !mostPlayed.isEmpty {
            let queue = mostPlayed.map(\.track)
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: "Most Played", actionTitle: nil, action: nil)

                SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(mostPlayed.prefix(5).enumerated()), id: \.element.id) { index, item in
                            SnoozyTrackRowView(
                                track: item.track,
                                subtitle: "\(item.track.artist) · \(SnoozyFormat.countLabel(item.plays, "play", "plays"))",
                                trackNumberBadge: index + 1,
                                isActive: playback.activeTrack?.id == item.track.id,
                                isFavorite: repository.isFavorite(item.track.id),
                                showTopSeparator: index > 0,
                                isGrouped: true,
                                theme: theme,
                                preferences: repository.preferences,
                                onTap: { playback.playTrack(item.track, queue: queue) },
                                onMenu: { onSelectTrackForMenu(item.track) },
                                onPlayNext: { playback.playNext(item.track) },
                                onAddToQueue: { playback.addToQueue(item.track) },
                                onToggleFavorite: { repository.toggleFavorite(item.track.id) }
                            )
                        }
                    }
                }
            }
        }
    }

    // 5. Favorites
    @ViewBuilder
    private var favoritesSection: some View {
        let favs = repository.favoriteTracks
        if !favs.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: "Favorites",
                    actionTitle: "See All",
                    action: { onOpenLibraryCategory(.favorites) }
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(favs.prefix(10)) { track in
                            appleMusicArtworkShelfItem(
                                title: track.title,
                                subtitle: track.artist,
                                artworkPath: track.artworkPath,
                                size: 144
                            ) {
                                playback.playTrack(track, queue: favs)
                            }
                        }
                    }
                }
            }
        }
    }

    // 6. Playlists
    @ViewBuilder
    private var playlistsSection: some View {
        if !repository.playlists.isEmpty {
            let byId = Dictionary(uniqueKeysWithValues: repository.tracks.map { ($0.id, $0) })
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: "Playlists",
                    actionTitle: "See All",
                    action: { onOpenLibraryCategory(.playlists) }
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(repository.playlists.prefix(8)) { playlist in
                            let tracks = playlist.trackIds.compactMap { byId[$0] }
                            Button {
                                onOpenPlaylist(playlist.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    SnoozyPlaylistCollageView(
                                        artworkPaths: tracks.map(\.artworkPath),
                                        size: 148,
                                        cornerRadius: 14,
                                        theme: theme
                                    )
                                    .shadow(color: Color.black.opacity(0.24), radius: 8, x: 0, y: 4)

                                    Text(playlist.name)
                                        .font(SnoozyTypography.body(14, bold: true))
                                        .foregroundStyle(theme.ink)
                                        .lineLimit(1)
                                    Text(SnoozyFormat.countLabel(tracks.count, "song", "songs"))
                                        .font(SnoozyTypography.footnote(12))
                                        .foregroundStyle(theme.inkMuted)
                                        .lineLimit(1)
                                }
                                .frame(width: 148)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // 7. Browse Your Music (Apple Music style local category rows)
    private var browseYourMusicSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Browse Your Music", actionTitle: nil, action: nil)

            SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                ForEach(Array(LibraryTab.appleMusicCategories.enumerated()), id: \.element.id) { index, category in
                    VStack(spacing: 0) {
                        if index > 0 {
                            Rectangle()
                                .fill(Color.white.opacity(theme.isDark ? 0.08 : 0.14))
                                .frame(height: 0.5)
                                .padding(.leading, 52)
                        }
                        Button {
                            onOpenLibraryCategory(category)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: category.systemImage)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(theme.accent)
                                    .frame(width: 26)
                                Text(category == .songs ? "All Songs" : category.rawValue)
                                    .font(SnoozyTypography.body(17, bold: false))
                                    .foregroundStyle(theme.ink)
                                Spacer()
                                Text(categoryCountText(for: category))
                                    .font(SnoozyTypography.footnote(13))
                                    .foregroundStyle(theme.inkMuted)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(theme.inkFaint)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 50)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Rectangle()
                    .fill(Color.white.opacity(theme.isDark ? 0.08 : 0.14))
                    .frame(height: 0.5)
                    .padding(.leading, 52)

                Button {
                    let shuffled = repository.tracks.shuffled()
                    if let first = shuffled.first {
                        playback.playTrack(first, queue: shuffled, shuffleOverride: true)
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(theme.accent)
                            .frame(width: 26)
                        Text("Shuffle All Songs")
                            .font(SnoozyTypography.body(17, bold: true))
                            .foregroundStyle(theme.accent)
                        Spacer()
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(theme.accent)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Shuffle all songs")
            }
        }
    }

    private func categoryCountText(for category: LibraryTab) -> String {
        switch category {
        case .overview: return ""
        case .playlists: return "\(repository.playlists.count)"
        case .artists: return "\(repository.artistNames.count)"
        case .albums: return "\(repository.albums.count)"
        case .songs: return "\(repository.tracks.count)"
        case .folders: return "\(repository.folderNames.count)"
        case .genres: return "\(repository.genreNames.count)"
        case .favorites: return "\(repository.favoriteTracks.count)"
        }
    }

    private func sectionHeader(title: String, actionTitle: String?, action: (() -> Void)?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            if let action {
                Button(action: action) {
                    HStack(spacing: 5) {
                        Text(title)
                            .font(SnoozyTypography.title(21))
                            .foregroundStyle(theme.ink)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(theme.inkMuted)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text(title)
                    .font(SnoozyTypography.title(21))
                    .foregroundStyle(theme.ink)
            }

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(SnoozyTypography.body(14, bold: true))
                    .foregroundStyle(theme.accent)
            }
        }
    }

    private func appleMusicArtworkShelfItem(
        title: String,
        subtitle: String,
        artworkPath: String?,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                SnoozyArtworkView(
                    artworkPath: artworkPath,
                    size: size,
                    cornerRadius: 14,
                    theme: theme
                )
                .shadow(color: Color.black.opacity(0.24), radius: 8, x: 0, y: 4)

                Text(title)
                    .font(SnoozyTypography.body(14, bold: true))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(SnoozyTypography.footnote(12))
                    .foregroundStyle(theme.inkMuted)
                    .lineLimit(1)
            }
            .frame(width: size)
        }
        .buttonStyle(.plain)
    }

    private func bannerRow(text: String, isError: Bool, onDismiss: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? theme.danger : theme.accent)
            Text(text)
                .font(SnoozyTypography.footnote(13))
                .foregroundStyle(isError ? theme.danger : theme.ink)
                .lineLimit(2)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.inkMuted)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .liquidGlassSurface(
            cornerRadius: 16,
            glassMode: repository.preferences.glassMode,
            refractionIntensity: repository.preferences.refractionIntensity,
            tintColor: isError ? theme.danger : theme.accent
        )
    }
}
