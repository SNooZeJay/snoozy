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
    @State private var playlistGridMode: Bool = true
    @State private var showSongSortDialog: Bool = false
    @State private var showAlbumSortDialog: Bool = false
    @State private var showNewPlaylistAlert: Bool = false
    @State private var newPlaylistName: String = ""
    @State private var renameTarget: Playlist? = nil
    @State private var renameText: String = ""
    @State private var deleteTarget: Playlist? = nil
    @State private var searchText: String = ""
    @FocusState private var isSearchFieldFocused: Bool
    @Environment(\.snoozyLayout) private var layout

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
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.top, layout.isLandscape ? 8 : 10)
            .padding(.bottom, layout.scrollBottomPadding(hasMiniPlayer: playback.activeTrack != nil))
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

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 10) {
            if selectedTab != .overview {
                LiquidGlassIconButton(
                    systemImage: "chevron.left",
                    accessibilityLabel: "Back to Library Overview",
                    size: layout.headerButtonSize,
                    theme: theme,
                    preferences: repository.preferences
                ) {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                        selectedTab = .overview
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedTab == .overview ? "Library" : (selectedTab == .songs ? "All Songs" : selectedTab.rawValue))
                    .font(SnoozyTypography.display(layout.headerTitleSize))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(countSubtitle)
                    .font(SnoozyTypography.footnote(12))
                    .foregroundStyle(theme.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            SnoozyGlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    if selectedTab == .songs || selectedTab == .favorites {
                        LiquidGlassIconButton(
                            systemImage: "arrow.up.arrow.down",
                            accessibilityLabel: "Sort songs (\(repository.songSort.label))",
                            size: layout.headerButtonSize,
                            theme: theme,
                            preferences: repository.preferences
                        ) {
                            showSongSortDialog = true
                        }
                    }

                    if selectedTab == .albums {
                        LiquidGlassIconButton(
                            systemImage: "arrow.up.arrow.down",
                            accessibilityLabel: "Sort albums (\(repository.albumSort.label))",
                            size: layout.headerButtonSize,
                            theme: theme,
                            preferences: repository.preferences
                        ) {
                            showAlbumSortDialog = true
                        }

                        LiquidGlassIconButton(
                            systemImage: albumGridMode ? "list.bullet" : "square.grid.2x2",
                            accessibilityLabel: albumGridMode ? "Show albums as list" : "Show albums as grid",
                            size: layout.headerButtonSize,
                            theme: theme,
                            preferences: repository.preferences
                        ) {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) {
                                albumGridMode.toggle()
                            }
                        }
                    }

                    if selectedTab == .playlists && !repository.playlists.isEmpty {
                        LiquidGlassIconButton(
                            systemImage: playlistGridMode ? "list.bullet" : "square.grid.2x2",
                            accessibilityLabel: playlistGridMode ? "Show playlists as list" : "Show playlists as grid",
                            size: layout.headerButtonSize,
                            theme: theme,
                            preferences: repository.preferences
                        ) {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) {
                                playlistGridMode.toggle()
                            }
                        }
                    }

                    if selectedTab == .playlists || selectedTab == .overview {
                        LiquidGlassIconButton(
                            systemImage: "plus",
                            accessibilityLabel: "Create playlist",
                            size: layout.headerButtonSize,
                            theme: theme,
                            preferences: repository.preferences
                        ) {
                            newPlaylistName = ""
                            showNewPlaylistAlert = true
                        }
                    }

                    if selectedTab == .overview || selectedTab == .artists || selectedTab == .folders || selectedTab == .genres {
                        LiquidGlassIconButton(
                            systemImage: "doc.badge.plus",
                            accessibilityLabel: "Import songs",
                            size: layout.headerButtonSize,
                            theme: theme,
                            preferences: repository.preferences,
                            action: onImportFiles
                        )
                    }
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
        .snoozyHorizontalScrollZone(id: "library-category-pills")
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
                if !repository.sortedSongs.isEmpty {
                    SnoozyCollectionActionsRow(
                        playLabel: "Play all songs",
                        shuffleLabel: "Shuffle all songs",
                        isEnabled: true,
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
                        }
                    )
                }

            case .albums:
                if !repository.sortedAlbums.isEmpty {
                    SnoozyCollectionActionsRow(
                        playLabel: "Play all albums",
                        shuffleLabel: "Shuffle all albums",
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
                        }
                    )
                }

            case .artists, .folders, .genres:
                if !repository.sortedSongs.isEmpty {
                    SnoozyCollectionActionsRow(
                        playLabel: "Play library",
                        shuffleLabel: "Shuffle library",
                        isEnabled: true,
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
                        }
                    )
                }

            case .favorites:
                if !repository.favoriteTracks.isEmpty {
                    SnoozyCollectionActionsRow(
                        playLabel: "Play favorites",
                        shuffleLabel: "Shuffle favorites",
                        isEnabled: true,
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
                }

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
            return "\(SnoozyFormat.countLabel(repository.sortedAlbums.count, "album", "albums")) · Sorted by \(repository.albumSort.label)"
        case .artists:
            return "\(SnoozyFormat.countLabel(repository.artistNames.count, "artist", "artists")) · Local Library"
        case .playlists:
            return "\(SnoozyFormat.countLabel(repository.playlists.count, "playlist", "playlists")) · Saved on this iPhone"
        case .folders:
            return "\(SnoozyFormat.countLabel(repository.folderNames.count, "folder", "folders")) · On My iPhone > Snoozy"
        case .genres:
            return "\(SnoozyFormat.countLabel(repository.genreNames.count, "genre", "genres")) · Local Library"
        case .favorites:
            return "\(SnoozyFormat.countLabel(repository.favoriteTracks.count, "favorite", "favorites")) · Sorted by \(repository.songSort.label)"
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
                title: "No Albums Yet",
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
                                    .padding(.leading, 72)
                            }
                            Button {
                                onOpenAlbum(album.id)
                            } label: {
                                HStack(spacing: 12) {
                                    SnoozyArtworkView(artworkPath: album.artworkPath, size: 48, cornerRadius: 10, theme: theme)
                                    VStack(alignment: .leading, spacing: 3) {
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
                                .frame(minHeight: 62)
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
        let tileSize = layout.gridTileSize
        let tracksById = repository.tracksById
        return LazyVGrid(columns: layout.gridItems, spacing: 18) {
            ForEach(albums) { album in
                let albumTracks = album.trackIds.compactMap { tracksById[$0] }
                Button {
                    onOpenAlbum(album.id)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        SnoozyArtworkView(
                            artworkPath: album.artworkPath,
                            size: tileSize,
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
                    .frame(width: tileSize, alignment: .leading)
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
                title: "No Artists Yet",
                message: "Artists appear automatically when songs with artist metadata or folder names are indexed."
            )
        } else {
            SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(names.enumerated()), id: \.element) { index, name in
                        let artistTracks = repository.tracksForArtist(name)
                        let artistAlbums = repository.albumsForArtist(name)
                        let sampleArtwork = artistTracks.compactMap(\.artworkPath).first
                        VStack(spacing: 0) {
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.white.opacity(theme.isDark ? 0.09 : 0.14))
                                    .frame(height: 0.5)
                                    .padding(.leading, 72)
                            }
                            Button {
                                onOpenArtist(name)
                            } label: {
                                HStack(spacing: 12) {
                                    if let sampleArtwork {
                                        SnoozyArtworkView(
                                            artworkPath: sampleArtwork,
                                            size: 48,
                                            cornerRadius: 24,
                                            theme: theme
                                        )
                                    } else {
                                        Circle()
                                            .fill(theme.accent.opacity(0.16))
                                            .frame(width: 48, height: 48)
                                            .overlay(
                                                Image(systemName: "music.mic")
                                                    .font(.system(size: 18, weight: .semibold))
                                                    .foregroundStyle(theme.accent)
                                            )
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(name)
                                            .font(SnoozyTypography.body(16, bold: true))
                                            .foregroundStyle(theme.ink)
                                            .lineLimit(1)
                                        Text("\(SnoozyFormat.countLabel(artistAlbums.count, "album", "albums")) · \(SnoozyFormat.countLabel(artistTracks.count, "song", "songs"))")
                                            .font(SnoozyTypography.footnote(13))
                                            .foregroundStyle(theme.inkMuted)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(theme.inkFaint)
                                }
                                .padding(.horizontal, 12)
                                .frame(minHeight: 62)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if let first = artistTracks.first {
                                    Button {
                                        playback.playTrack(first, queue: artistTracks, shuffleOverride: false)
                                    } label: {
                                        Label("Play Artist", systemImage: "play.fill")
                                    }
                                    Button {
                                        let shuffled = artistTracks.shuffled()
                                        if let sFirst = shuffled.first {
                                            playback.playTrack(sFirst, queue: shuffled, shuffleOverride: true)
                                        }
                                    } label: {
                                        Label("Shuffle Artist", systemImage: "shuffle")
                                    }
                                }
                            }
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
            VStack(spacing: 14) {
                emptySectionCard(
                    icon: "music.note.list",
                    title: "No Playlists Yet",
                    message: "Create personal offline playlists from the songs stored on your iPhone."
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
        } else if playlistGridMode && !isSearchActive {
            let tileSize = layout.gridTileSize
            LazyVGrid(columns: layout.gridItems, spacing: 18) {
                ForEach(playlists) { playlist in
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
                            .shadow(color: Color.black.opacity(theme.isDark ? 0.30 : 0.14), radius: 10, x: 0, y: 5)

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
                                Label("Play Playlist", systemImage: "play.fill")
                            }
                            Button {
                                let shuffled = tracks.shuffled()
                                if let sFirst = shuffled.first {
                                    playback.playTrack(sFirst, queue: shuffled, shuffleOverride: true)
                                }
                            } label: {
                                Label("Shuffle Playlist", systemImage: "shuffle")
                            }
                        }

                        Divider()

                        Button {
                            renameText = playlist.name
                            renameTarget = playlist
                        } label: {
                            Label("Rename Playlist", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            deleteTarget = playlist
                        } label: {
                            Label("Delete Playlist", systemImage: "trash")
                        }
                    }
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
                                    .padding(.leading, 72)
                            }
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
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(playlist.name)
                                            .font(SnoozyTypography.body(16, bold: true))
                                            .foregroundStyle(theme.ink)
                                            .lineLimit(1)
                                        Text(SnoozyFormat.countLabel(tracks.count, "song", "songs"))
                                            .font(SnoozyTypography.footnote(13))
                                            .foregroundStyle(theme.inkMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(theme.inkFaint)
                                }
                                .padding(.horizontal, 12)
                                .frame(minHeight: 62)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if let first = tracks.first {
                                    Button {
                                        playback.playTrack(first, queue: tracks, shuffleOverride: false)
                                    } label: {
                                        Label("Play Playlist", systemImage: "play.fill")
                                    }
                                    Button {
                                        let shuffled = tracks.shuffled()
                                        if let sFirst = shuffled.first {
                                            playback.playTrack(sFirst, queue: shuffled, shuffleOverride: true)
                                        }
                                    } label: {
                                        Label("Shuffle Playlist", systemImage: "shuffle")
                                    }
                                }

                                Divider()

                                Button {
                                    renameText = playlist.name
                                    renameTarget = playlist
                                } label: {
                                    Label("Rename Playlist", systemImage: "pencil")
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
            }
        }
    }

    @ViewBuilder
    private func foldersList(folders: [String]) -> some View {
        if folders.isEmpty {
            emptySectionCard(
                icon: "folder.fill",
                title: "No Local Folders Yet",
                message: "Organize your audio files into folders inside On My iPhone > Snoozy in the iPhone Files app."
            )
        } else {
            SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(folders.enumerated()), id: \.element) { index, folder in
                        let folderTracks = repository.tracksForFolder(folder)
                        let folderCover = folderTracks.compactMap(\.artworkPath).first
                        VStack(spacing: 0) {
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.white.opacity(theme.isDark ? 0.09 : 0.14))
                                    .frame(height: 0.5)
                                    .padding(.leading, 72)
                            }
                            Button {
                                onOpenFolder(folder)
                            } label: {
                                HStack(spacing: 12) {
                                    if let folderCover {
                                        ZStack(alignment: .bottomTrailing) {
                                            SnoozyArtworkView(
                                                artworkPath: folderCover,
                                                size: 48,
                                                cornerRadius: 10,
                                                theme: theme
                                            )
                                            Circle()
                                                .fill(theme.accent)
                                                .frame(width: 18, height: 18)
                                                .overlay(
                                                    Image(systemName: "folder.fill")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundStyle(theme.accentInk)
                                                )
                                                .offset(x: 3, y: 3)
                                        }
                                    } else {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(theme.accent.opacity(0.16))
                                            .frame(width: 48, height: 48)
                                            .overlay(
                                                Image(systemName: "folder.fill")
                                                    .font(.system(size: 19, weight: .semibold))
                                                    .foregroundStyle(theme.accent)
                                            )
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(folder)
                                            .font(SnoozyTypography.body(16, bold: true))
                                            .foregroundStyle(theme.ink)
                                            .lineLimit(1)
                                        Text("\(SnoozyFormat.countLabel(folderTracks.count, "song", "songs")) · On My iPhone > Snoozy")
                                            .font(SnoozyTypography.footnote(13))
                                            .foregroundStyle(theme.inkMuted)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(theme.inkFaint)
                                }
                                .padding(.horizontal, 12)
                                .frame(minHeight: 62)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if let first = folderTracks.first {
                                    Button {
                                        playback.playTrack(first, queue: folderTracks, shuffleOverride: false)
                                    } label: {
                                        Label("Play Folder", systemImage: "play.fill")
                                    }
                                    Button {
                                        let shuffled = folderTracks.shuffled()
                                        if let sFirst = shuffled.first {
                                            playback.playTrack(sFirst, queue: shuffled, shuffleOverride: true)
                                        }
                                    } label: {
                                        Label("Shuffle Folder", systemImage: "shuffle")
                                    }
                                }
                            }
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
                title: "No Genres Yet",
                message: "Genres appear automatically when songs carry a genre tag."
            )
        } else {
            SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(genres.enumerated()), id: \.element) { index, genre in
                        let genreTracks = repository.tracksForGenre(genre)
                        let sampleArtwork = genreTracks.compactMap(\.artworkPath).first
                        VStack(spacing: 0) {
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.white.opacity(theme.isDark ? 0.09 : 0.14))
                                    .frame(height: 0.5)
                                    .padding(.leading, 72)
                            }
                            Button {
                                onOpenGenre(genre)
                            } label: {
                                HStack(spacing: 12) {
                                    if let sampleArtwork {
                                        SnoozyArtworkView(
                                            artworkPath: sampleArtwork,
                                            size: 48,
                                            cornerRadius: 10,
                                            theme: theme
                                        )
                                    } else {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(theme.accent.opacity(0.16))
                                            .frame(width: 48, height: 48)
                                            .overlay(
                                                Image(systemName: "guitars.fill")
                                                    .font(.system(size: 18, weight: .semibold))
                                                    .foregroundStyle(theme.accent)
                                            )
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(genre)
                                            .font(SnoozyTypography.body(16, bold: true))
                                            .foregroundStyle(theme.ink)
                                            .lineLimit(1)
                                        Text(SnoozyFormat.countLabel(genreTracks.count, "song", "songs"))
                                            .font(SnoozyTypography.footnote(13))
                                            .foregroundStyle(theme.inkMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(theme.inkFaint)
                                }
                                .padding(.horizontal, 12)
                                .frame(minHeight: 62)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if let first = genreTracks.first {
                                    Button {
                                        playback.playTrack(first, queue: genreTracks, shuffleOverride: false)
                                    } label: {
                                        Label("Play Genre", systemImage: "play.fill")
                                    }
                                    Button {
                                        let shuffled = genreTracks.shuffled()
                                        if let sFirst = shuffled.first {
                                            playback.playTrack(sFirst, queue: shuffled, shuffleOverride: true)
                                        }
                                    } label: {
                                        Label("Shuffle Genre", systemImage: "shuffle")
                                    }
                                }
                            }
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
                    title: "No Favorites Yet",
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
        VStack(spacing: 12) {
            Circle()
                .fill(theme.accent.opacity(0.14))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(theme.accent)
                )
            Text(title)
                .font(SnoozyTypography.headline(18))
                .foregroundStyle(theme.ink)
            Text(message)
                .font(SnoozyTypography.footnote(13))
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .liquidGlassSurface(
            cornerRadius: 24,
            glassMode: repository.preferences.glassMode,
            refractionIntensity: repository.preferences.refractionIntensity,
            tintColor: theme.accent
        )
    }
}
