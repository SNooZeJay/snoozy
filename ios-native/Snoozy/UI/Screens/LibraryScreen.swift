import SwiftUI

public struct LibraryScreen: View {
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    @Binding public var selectedTab: LibraryTab
    public let theme: SnoozyThemeColors
    public let onOpenAlbum: (String) -> Void
    public let onOpenArtist: (String) -> Void
    public let onOpenGenre: (String) -> Void
    public let onOpenPlaylist: (String) -> Void
    public let onOpenFolder: (String) -> Void
    public let onImportFiles: () -> Void
    public let onSelectTrackForMenu: (Track) -> Void

    @State private var albumGridMode: Bool = true
    @State private var showSongSortDialog: Bool = false
    @State private var showAlbumSortDialog: Bool = false
    @State private var showNewPlaylistAlert: Bool = false
    @State private var newPlaylistName: String = ""
    @State private var searchText: String = ""
    @FocusState private var isSearchFieldFocused: Bool

    public init(
        repository: LibraryRepository,
        playback: PlaybackController,
        selectedTab: Binding<LibraryTab>,
        theme: SnoozyThemeColors,
        onOpenAlbum: @escaping (String) -> Void,
        onOpenArtist: @escaping (String) -> Void,
        onOpenGenre: @escaping (String) -> Void,
        onOpenPlaylist: @escaping (String) -> Void = { _ in },
        onOpenFolder: @escaping (String) -> Void = { _ in },
        onImportFiles: @escaping () -> Void,
        onSelectTrackForMenu: @escaping (Track) -> Void
    ) {
        self.repository = repository
        self.playback = playback
        self._selectedTab = selectedTab
        self.theme = theme
        self.onOpenAlbum = onOpenAlbum
        self.onOpenArtist = onOpenArtist
        self.onOpenGenre = onOpenGenre
        self.onOpenPlaylist = onOpenPlaylist
        self.onOpenFolder = onOpenFolder
        self.onImportFiles = onImportFiles
        self.onSelectTrackForMenu = onSelectTrackForMenu
    }

    private var trimmedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearchActive: Bool {
        !trimmedSearchQuery.isEmpty
    }

    private var searchResults: LibrarySearchResults {
        repository.searchLibrary(query: trimmedSearchQuery)
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                headerRow

                librarySearchBar

                categoryFilterPills

                if isSearchActive {
                    activeLibrarySearchContent
                } else {
                    if selectedTab != .overview {
                        toolbarRow
                    }

                    switch selectedTab {
                    case .overview:
                        appleMusicLibraryOverview
                    case .songs:
                        songsList(songs: repository.sortedSongs)
                    case .albums:
                        albumsContent(albums: repository.sortedAlbums)
                    case .artists:
                        artistsList(names: repository.artistNames)
                    case .playlists:
                        playlistsList(playlists: repository.playlists)
                    case .folders:
                        foldersList(folders: repository.folderNames)
                    case .genres:
                        genresList(genres: repository.genreNames)
                    case .favorites:
                        favoritesList(favs: repository.favoriteTracks)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, playback.activeTrack != nil ? 176 : 112)
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Sort songs by", isPresented: $showSongSortDialog, titleVisibility: .visible) {
            ForEach(SongSort.allCases, id: \.self) { sort in
                Button(sort.label) {
                    repository.setSongSort(sort)
                }
            }
        }
        .confirmationDialog("Sort albums by", isPresented: $showAlbumSortDialog, titleVisibility: .visible) {
            ForEach(AlbumSort.allCases, id: \.self) { sort in
                Button(sort.label) {
                    repository.setAlbumSort(sort)
                }
            }
        }
        .alert("New Playlist", isPresented: $showNewPlaylistAlert) {
            TextField("Playlist name", text: $newPlaylistName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                if let id = repository.createPlaylist(name: newPlaylistName) {
                    onOpenPlaylist(id)
                }
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 10) {
            if selectedTab != .overview {
                LiquidGlassIconButton(
                    systemImage: "chevron.left",
                    accessibilityLabel: "Back to Library Overview",
                    size: 40,
                    theme: theme,
                    preferences: repository.preferences
                ) {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                        selectedTab = .overview
                    }
                }
            } else {
                SnoozyBrandIconView(size: 40)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedTab == .overview ? "Library" : (selectedTab == .songs ? "All Songs" : selectedTab.rawValue))
                    .font(SnoozyTypography.display(30))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)

                Text(countSubtitle)
                    .font(SnoozyTypography.footnote(12))
                    .foregroundStyle(theme.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            SnoozyGlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    if selectedTab == .playlists || selectedTab == .overview {
                        LiquidGlassIconButton(
                            systemImage: "plus",
                            accessibilityLabel: "Create playlist",
                            size: 40,
                            theme: theme,
                            preferences: repository.preferences
                        ) {
                            newPlaylistName = ""
                            showNewPlaylistAlert = true
                        }
                    }

                    LiquidGlassIconButton(
                        systemImage: "doc.badge.plus",
                        accessibilityLabel: "Import songs",
                        size: 40,
                        theme: theme,
                        preferences: repository.preferences,
                        action: onImportFiles
                    )
                }
            }
        }
    }

    private var librarySearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSearchActive ? theme.accent : theme.inkMuted)

            TextField("Search songs, albums, artists, playlists", text: $searchText)
                .font(SnoozyTypography.body(15))
                .foregroundStyle(theme.ink)
                .focused($isSearchFieldFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    isSearchFieldFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.inkMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear library search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .liquidGlassSurface(
            cornerRadius: 22,
            glassMode: repository.preferences.glassMode,
            refractionIntensity: repository.preferences.refractionIntensity,
            tintColor: theme.accent,
            variant: .ultraClear
        )
    }

    @ViewBuilder
    private var activeLibrarySearchContent: some View {
        let results = searchResults
        if results.isEmpty {
            VStack(spacing: 12) {
                emptySectionCard(
                    icon: "magnifyingglass",
                    title: "No Results for \"\(trimmedSearchQuery)\"",
                    message: "Check the spelling or try searching by song title, artist, album, or playlist."
                )
                LiquidGlassButton(
                    title: "Clear Search",
                    systemImage: "xmark.circle",
                    theme: theme,
                    preferences: repository.preferences
                ) {
                    searchText = ""
                    isSearchFieldFocused = false
                }
            }
        } else {
            switch selectedTab {
            case .songs:
                if results.songs.isEmpty {
                    unifiedSearchSections(results: results)
                } else {
                    songsList(songs: results.songs)
                }
            case .albums:
                if results.albums.isEmpty {
                    unifiedSearchSections(results: results)
                } else {
                    albumsContent(albums: results.albums)
                }
            case .artists:
                if results.artists.isEmpty {
                    unifiedSearchSections(results: results)
                } else {
                    artistsList(names: results.artists)
                }
            case .playlists:
                if results.playlists.isEmpty {
                    unifiedSearchSections(results: results)
                } else {
                    playlistsList(playlists: results.playlists)
                }
            case .folders:
                if results.folders.isEmpty {
                    unifiedSearchSections(results: results)
                } else {
                    foldersList(folders: results.folders)
                }
            case .genres:
                if results.genres.isEmpty {
                    unifiedSearchSections(results: results)
                } else {
                    genresList(genres: results.genres)
                }
            case .favorites:
                let matchedFavs = results.songs.filter { repository.isFavorite($0.id) }
                if matchedFavs.isEmpty {
                    unifiedSearchSections(results: results)
                } else {
                    favoritesList(favs: matchedFavs)
                }
            case .overview:
                unifiedSearchSections(results: results)
            }
        }
    }

    private func unifiedSearchSections(results: LibrarySearchResults) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if !results.songs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Songs (\(results.songs.count))")
                        .font(SnoozyTypography.headline(16))
                        .foregroundStyle(theme.ink)
                    songsList(songs: results.songs)
                }
            }

            if !results.albums.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Albums (\(results.albums.count))")
                        .font(SnoozyTypography.headline(16))
                        .foregroundStyle(theme.ink)
                    albumGrid(albums: results.albums)
                }
            }

            if !results.artists.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Artists (\(results.artists.count))")
                        .font(SnoozyTypography.headline(16))
                        .foregroundStyle(theme.ink)
                    artistsList(names: results.artists)
                }
            }

            if !results.playlists.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Playlists (\(results.playlists.count))")
                        .font(SnoozyTypography.headline(16))
                        .foregroundStyle(theme.ink)
                    playlistsList(playlists: results.playlists)
                }
            }
        }
    }

    private var categoryFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            SnoozyGlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(LibraryTab.allCases) { tab in
                        let isSelected = (tab == selectedTab)
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) {
                                selectedTab = tab
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: tab.systemImage)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(tab == .songs ? "All Songs" : tab.rawValue)
                                    .font(SnoozyTypography.caption(12, bold: true))
                            }
                            .foregroundStyle(isSelected ? theme.accentInk : theme.ink)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .liquidGlassSurface(
                                cornerRadius: 17,
                                glassMode: repository.preferences.glassMode,
                                refractionIntensity: repository.preferences.refractionIntensity,
                                tintColor: theme.accent,
                                isProminent: isSelected,
                                variant: .ultraClear
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // Apple Music Library Root Overview: Category List + Recently Added 2-Column Grid
    private var appleMusicLibraryOverview: some View {
        VStack(alignment: .leading, spacing: 24) {
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
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                                selectedTab = category
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: category.systemImage)
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundStyle(theme.accent)
                                    .frame(width: 26)
                                Text(category == .songs ? "Songs" : category.rawValue)
                                    .font(SnoozyTypography.body(18, bold: false))
                                    .foregroundStyle(theme.ink)
                                Spacer()
                                Text(categoryBadgeCount(for: category))
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
            }

            if !repository.recentlyAddedAlbums.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recently Added")
                        .font(SnoozyTypography.title(21))
                        .foregroundStyle(theme.ink)

                    albumGrid(albums: repository.recentlyAddedAlbums)
                }
            }
        }
    }

    private func categoryBadgeCount(for tab: LibraryTab) -> String {
        switch tab {
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

    private var toolbarRow: some View {
        HStack {
            switch selectedTab {
            case .songs:
                SnoozyCollectionActionsRow(
                    playLabel: "Play all songs",
                    shuffleLabel: "Shuffle all songs",
                    isEnabled: !repository.sortedSongs.isEmpty,
                    theme: theme,
                    preferences: repository.preferences,
                    onPlay: {
                        let songs = repository.sortedSongs
                        if let first = songs.first {
                            playback.playTrack(first, queue: songs, shuffleOverride: false)
                        }
                    },
                    onShuffle: {
                        let shuffled = repository.sortedSongs.shuffled()
                        if let first = shuffled.first {
                            playback.playTrack(first, queue: shuffled, shuffleOverride: true)
                        }
                    },
                    trailing: AnyView(
                        LiquidGlassIconButton(
                            systemImage: "arrow.up.arrow.down",
                            accessibilityLabel: "Sort songs (\(repository.songSort.label))",
                            size: 46,
                            theme: theme,
                            preferences: repository.preferences
                        ) {
                            showSongSortDialog = true
                        }
                    )
                )

            case .albums:
                HStack(spacing: 8) {
                    Text("Sorted by \(repository.albumSort.label)")
                        .font(SnoozyTypography.footnote(13))
                        .foregroundStyle(theme.inkMuted)
                    Spacer()
                    LiquidGlassButton(
                        title: "Sort · \(repository.albumSort.label)",
                        systemImage: "arrow.up.arrow.down",
                        theme: theme,
                        preferences: repository.preferences
                    ) {
                        showAlbumSortDialog = true
                    }
                    LiquidGlassIconButton(
                        systemImage: albumGridMode ? "list.bullet" : "square.grid.2x2",
                        accessibilityLabel: albumGridMode ? "Show albums as list" : "Show albums as grid",
                        theme: theme,
                        preferences: repository.preferences
                    ) {
                        albumGridMode.toggle()
                    }
                }

            case .favorites:
                SnoozyCollectionActionsRow(
                    playLabel: "Play favorites",
                    shuffleLabel: "Shuffle favorites",
                    isEnabled: !repository.favoriteTracks.isEmpty,
                    theme: theme,
                    preferences: repository.preferences,
                    onPlay: {
                        let favs = repository.favoriteTracks
                        if let first = favs.first {
                            playback.playTrack(first, queue: favs, shuffleOverride: false)
                        }
                    },
                    onShuffle: {
                        let shuffled = repository.favoriteTracks.shuffled()
                        if let first = shuffled.first {
                            playback.playTrack(first, queue: shuffled, shuffleOverride: true)
                        }
                    }
                )

            default:
                EmptyView()
            }
        }
    }

    private var countSubtitle: String {
        switch selectedTab {
        case .overview:
            return "\(SnoozyFormat.countLabel(repository.tracks.count, "song", "songs")) · Local Library"
        case .songs:
            return "\(SnoozyFormat.countLabel(repository.sortedSongs.count, "song", "songs")) · Sorted by \(repository.songSort.label)"
        case .albums:
            return SnoozyFormat.countLabel(repository.sortedAlbums.count, "album", "albums")
        case .artists:
            return SnoozyFormat.countLabel(repository.artistNames.count, "artist", "artists")
        case .playlists:
            return SnoozyFormat.countLabel(repository.playlists.count, "playlist", "playlists")
        case .folders:
            return SnoozyFormat.countLabel(repository.folderNames.count, "folder", "folders")
        case .genres:
            return SnoozyFormat.countLabel(repository.genreNames.count, "genre", "genres")
        case .favorites:
            return SnoozyFormat.countLabel(repository.favoriteTracks.count, "favorite", "favorites")
        }
    }

    @ViewBuilder
    private func songsList(songs: [Track]) -> some View {
        if songs.isEmpty {
            emptySectionCard(
                icon: "music.note",
                title: "No songs indexed yet",
                message: "Drop audio files into On My iPhone > Snoozy in the Files app, or tap the import button above."
            )
        } else {
            SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, track in
                        SnoozyTrackRowView(
                            track: track,
                            subtitle: "\(track.artist) · \(track.album)",
                            isActive: playback.activeTrack?.id == track.id,
                            isFavorite: repository.isFavorite(track.id),
                            showTopSeparator: index > 0,
                            isGrouped: true,
                            theme: theme,
                            preferences: repository.preferences,
                            onTap: { playback.playTrack(track, queue: songs) },
                            onMenu: { onSelectTrackForMenu(track) },
                            onPlayNext: { playback.playNext(track) },
                            onAddToQueue: { playback.addToQueue(track) },
                            onToggleFavorite: { repository.toggleFavorite(track.id) }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func albumsContent(albums: [Album]) -> some View {
        if albums.isEmpty {
            emptySectionCard(
                icon: "square.stack.fill",
                title: "No albums yet",
                message: "Albums appear automatically as soon as your songs are indexed."
            )
        } else if albumGridMode {
            albumGrid(albums: albums)
        } else {
            SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(albums.enumerated()), id: \.element.id) { index, album in
                        VStack(spacing: 0) {
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.white.opacity(theme.isDark ? 0.09 : 0.14))
                                    .frame(height: 0.5)
                                    .padding(.leading, 74)
                            }
                            Button {
                                onOpenAlbum(album.id)
                            } label: {
                                HStack(spacing: 12) {
                                    SnoozyArtworkView(artworkPath: album.artworkPath, size: 50, cornerRadius: 10, theme: theme)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(album.title)
                                            .font(SnoozyTypography.body(16, bold: true))
                                            .foregroundStyle(theme.ink)
                                            .lineLimit(1)
                                        Text(album.artist)
                                            .font(SnoozyTypography.footnote(13))
                                            .foregroundStyle(theme.inkMuted)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if let year = album.year {
                                        Text(year)
                                            .font(SnoozyTypography.caption(12))
                                            .foregroundStyle(theme.inkFaint)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(theme.inkFaint)
                                }
                                .padding(.horizontal, 12)
                                .frame(minHeight: 64)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func albumGrid(albums: [Album]) -> some View {
        let cols = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
        let tracksById = repository.tracksById
        return LazyVGrid(columns: cols, spacing: 18) {
            ForEach(albums) { album in
                let albumTracks = album.trackIds.compactMap { tracksById[$0] }
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
                .contextMenu {
                    Button {
                        if let first = albumTracks.first {
                            playback.playTrack(first, queue: albumTracks, shuffleOverride: false)
                        }
                    } label: {
                        Label("Play Album", systemImage: "play.fill")
                    }
                    Button {
                        let shuffled = albumTracks.shuffled()
                        if let first = shuffled.first {
                            playback.playTrack(first, queue: shuffled, shuffleOverride: true)
                        }
                    } label: {
                        Label("Shuffle Album", systemImage: "shuffle")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func artistsList(names: [String]) -> some View {
        if names.isEmpty {
            emptySectionCard(
                icon: "music.mic",
                title: "No artists yet",
                message: "Artists appear when songs with artist tags are indexed."
            )
        } else {
            SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(names.enumerated()), id: \.element) { index, name in
                        let artistTracks = repository.tracksForArtist(name)
                        let sampleArtwork = artistTracks.compactMap(\.artworkPath).first
                        VStack(spacing: 0) {
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.white.opacity(theme.isDark ? 0.09 : 0.14))
                                    .frame(height: 0.5)
                                    .padding(.leading, 68)
                            }
                            Button {
                                onOpenArtist(name)
                            } label: {
                                HStack(spacing: 12) {
                                    if let sampleArtwork {
                                        SnoozyArtworkView(
                                            artworkPath: sampleArtwork,
                                            size: 44,
                                            cornerRadius: 22,
                                            theme: theme
                                        )
                                    } else {
                                        Circle()
                                            .fill(theme.accent.opacity(0.18))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Image(systemName: "music.mic")
                                                    .foregroundStyle(theme.accent)
                                            )
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name)
                                            .font(SnoozyTypography.body(16, bold: true))
                                            .foregroundStyle(theme.ink)
                                            .lineLimit(1)
                                        Text(SnoozyFormat.countLabel(artistTracks.count, "song", "songs"))
                                            .font(SnoozyTypography.footnote(12))
                                            .foregroundStyle(theme.inkMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(theme.inkFaint)
                                }
                                .padding(.horizontal, 12)
                                .frame(minHeight: 58)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func playlistsList(playlists: [Playlist]) -> some View {
        let byId = repository.tracksById
        if playlists.isEmpty {
            VStack(spacing: 12) {
                emptySectionCard(
                    icon: "music.note.list",
                    title: "No playlists yet",
                    message: "Create a personal playlist for your local songs."
                )
                LiquidGlassButton(
                    title: "New Playlist",
                    systemImage: "plus",
                    isProminent: true,
                    theme: theme,
                    preferences: repository.preferences
                ) {
                    newPlaylistName = ""
                    showNewPlaylistAlert = true
                }
            }
        } else {
            SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(playlists.enumerated()), id: \.element.id) { index, playlist in
                        let tracks = playlist.trackIds.compactMap { byId[$0] }
                        VStack(spacing: 0) {
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.white.opacity(theme.isDark ? 0.09 : 0.14))
                                    .frame(height: 0.5)
                                    .padding(.leading, 74)
                            }
                            Button {
                                onOpenPlaylist(playlist.id)
                            } label: {
                                HStack(spacing: 12) {
                                    SnoozyPlaylistCollageView(
                                        artworkPaths: tracks.map(\.artworkPath),
                                        size: 50,
                                        cornerRadius: 10,
                                        theme: theme
                                    )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.name)
                                            .font(SnoozyTypography.body(16, bold: true))
                                            .foregroundStyle(theme.ink)
                                            .lineLimit(1)
                                        Text(SnoozyFormat.countLabel(tracks.count, "song", "songs"))
                                            .font(SnoozyTypography.footnote(12))
                                            .foregroundStyle(theme.inkMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(theme.inkFaint)
                                }
                                .padding(.horizontal, 12)
                                .frame(minHeight: 64)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func foldersList(folders: [String]) -> some View {
        if folders.isEmpty {
            emptySectionCard(
                icon: "folder.fill",
                title: "No local folders yet",
                message: "Organize your audio files into folders inside On My iPhone > Snoozy in the iPhone Files app."
            )
        } else {
            SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(folders.enumerated()), id: \.element) { index, folder in
                        let folderTracks = repository.tracksForFolder(folder)
                        VStack(spacing: 0) {
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.white.opacity(theme.isDark ? 0.09 : 0.14))
                                    .frame(height: 0.5)
                                    .padding(.leading, 68)
                            }
                            Button {
                                onOpenFolder(folder)
                            } label: {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(theme.accent.opacity(0.18))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Image(systemName: "folder.fill")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(theme.accent)
                                        )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(folder)
                                            .font(SnoozyTypography.body(16, bold: true))
                                            .foregroundStyle(theme.ink)
                                            .lineLimit(1)
                                        Text("\(SnoozyFormat.countLabel(folderTracks.count, "song", "songs")) · On My iPhone > Snoozy")
                                            .font(SnoozyTypography.footnote(12))
                                            .foregroundStyle(theme.inkMuted)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(theme.inkFaint)
                                }
                                .padding(.horizontal, 12)
                                .frame(minHeight: 60)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func genresList(genres: [String]) -> some View {
        if genres.isEmpty {
            emptySectionCard(
                icon: "guitars.fill",
                title: "No genres yet",
                message: "Genres appear when songs carry a genre tag."
            )
        } else {
            SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(genres.enumerated()), id: \.element) { index, genre in
                        let genreTracks = repository.tracksForGenre(genre)
                        VStack(spacing: 0) {
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.white.opacity(theme.isDark ? 0.09 : 0.14))
                                    .frame(height: 0.5)
                                    .padding(.leading, 66)
                            }
                            Button {
                                onOpenGenre(genre)
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(theme.accent.opacity(0.18))
                                        .frame(width: 42, height: 42)
                                        .overlay(
                                            Image(systemName: "guitars.fill")
                                                .foregroundStyle(theme.accent)
                                        )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(genre)
                                            .font(SnoozyTypography.body(16, bold: true))
                                            .foregroundStyle(theme.ink)
                                            .lineLimit(1)
                                        Text(SnoozyFormat.countLabel(genreTracks.count, "song", "songs"))
                                            .font(SnoozyTypography.footnote(12))
                                            .foregroundStyle(theme.inkMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(theme.inkFaint)
                                }
                                .padding(.horizontal, 12)
                                .frame(minHeight: 58)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func favoritesList(favs: [Track]) -> some View {
        return Group {
            if favs.isEmpty {
                emptySectionCard(
                    icon: "star.fill",
                    title: "No favorites yet",
                    message: "Tap the star icon in Now Playing or a song's context menu to favorite it."
                )
            } else {
                SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(favs.enumerated()), id: \.element.id) { index, track in
                            SnoozyTrackRowView(
                                track: track,
                                subtitle: "\(track.artist) · \(track.album)",
                                isActive: playback.activeTrack?.id == track.id,
                                isFavorite: true,
                                showTopSeparator: index > 0,
                                isGrouped: true,
                                theme: theme,
                                preferences: repository.preferences,
                                onTap: { playback.playTrack(track, queue: favs) },
                                onMenu: { onSelectTrackForMenu(track) },
                                onPlayNext: { playback.playNext(track) },
                                onAddToQueue: { playback.addToQueue(track) },
                                onToggleFavorite: { repository.toggleFavorite(track.id) }
                            )
                        }
                    }
                }
            }
        }
    }

    private func emptySectionCard(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(theme.inkFaint)
            Text(title)
                .font(SnoozyTypography.headline(16))
                .foregroundStyle(theme.ink)
            Text(message)
                .font(SnoozyTypography.footnote(13))
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .liquidGlassSurface(
            cornerRadius: 22,
            glassMode: repository.preferences.glassMode,
            refractionIntensity: repository.preferences.refractionIntensity,
            tintColor: theme.accent
        )
    }
}
