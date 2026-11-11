import SwiftUI

public enum LocalSearchScope: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case songs = "Songs"
    case artists = "Artists"
    case albums = "Albums"
    case playlists = "Playlists"
    case genres = "Genres"

    public var id: String { rawValue }
}

public struct SearchScreen: View {
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors
    public let onOpenAlbum: (String) -> Void
    public let onOpenArtist: (String) -> Void
    public let onOpenGenre: (String) -> Void
    public let onOpenPlaylist: (String) -> Void
    public let onOpenLibraryCategory: (LibraryTab) -> Void
    public let onSelectTrackForMenu: (Track) -> Void

    @State private var query: String = ""
    @State private var selectedScope: LocalSearchScope = .all

    public init(
        repository: LibraryRepository,
        playback: PlaybackController,
        theme: SnoozyThemeColors,
        onOpenAlbum: @escaping (String) -> Void,
        onOpenArtist: @escaping (String) -> Void,
        onOpenGenre: @escaping (String) -> Void,
        onOpenPlaylist: @escaping (String) -> Void = { _ in },
        onOpenLibraryCategory: @escaping (LibraryTab) -> Void = { _ in },
        onSelectTrackForMenu: @escaping (Track) -> Void
    ) {
        self.repository = repository
        self.playback = playback
        self.theme = theme
        self.onOpenAlbum = onOpenAlbum
        self.onOpenArtist = onOpenArtist
        self.onOpenGenre = onOpenGenre
        self.onOpenPlaylist = onOpenPlaylist
        self.onOpenLibraryCategory = onOpenLibraryCategory
        self.onSelectTrackForMenu = onSelectTrackForMenu
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var matchingSongs: [Track] {
        let q = trimmedQuery.lowercased()
        guard !q.isEmpty else { return [] }
        return repository.sortedSongs.filter {
            $0.title.lowercased().contains(q) ||
            $0.artist.lowercased().contains(q) ||
            $0.album.lowercased().contains(q) ||
            $0.folderName.lowercased().contains(q)
        }
    }

    private var matchingAlbums: [Album] {
        let q = trimmedQuery.lowercased()
        guard !q.isEmpty else { return [] }
        return repository.sortedAlbums.filter {
            $0.title.lowercased().contains(q) ||
            $0.artist.lowercased().contains(q)
        }
    }

    private var matchingArtists: [String] {
        let q = trimmedQuery.lowercased()
        guard !q.isEmpty else { return [] }
        return repository.artistNames.filter { $0.lowercased().contains(q) }
    }

    private var matchingPlaylists: [Playlist] {
        let q = trimmedQuery.lowercased()
        guard !q.isEmpty else { return [] }
        return repository.playlists.filter { $0.name.lowercased().contains(q) }
    }

    private var matchingGenres: [String] {
        let q = trimmedQuery.lowercased()
        guard !q.isEmpty else { return [] }
        return repository.genreNames.filter { $0.lowercased().contains(q) }
    }

    private var hasAnyMatches: Bool {
        !matchingSongs.isEmpty ||
        !matchingAlbums.isEmpty ||
        !matchingArtists.isEmpty ||
        !matchingPlaylists.isEmpty ||
        !matchingGenres.isEmpty
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if !trimmedQuery.isEmpty {
                    scopeFilterRow
                }

                if trimmedQuery.isEmpty {
                    recentSearchesView
                    browseLocalCategoriesSection
                } else if !hasAnyMatches {
                    emptySearchResultsView
                } else {
                    searchResultsContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, playback.activeTrack != nil ? 172 : 108)
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Your Local Songs, Artists, Albums, Playlists"
        )
        .onSubmit(of: .search) {
            if !trimmedQuery.isEmpty {
                repository.addRecentSearch(trimmedQuery)
            }
        }
    }

    private var scopeFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            SnoozyGlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(LocalSearchScope.allCases) { scope in
                        let isSelected = (selectedScope == scope)
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) {
                                selectedScope = scope
                            }
                        } label: {
                            Text(scope.rawValue)
                                .font(SnoozyTypography.caption(12, bold: true))
                                .foregroundStyle(isSelected ? theme.accentInk : theme.ink)
                                .padding(.horizontal, 14)
                                .frame(height: 34)
                                .background(
                                    Group {
                                        if isSelected {
                                            Capsule().fill(theme.accent)
                                        }
                                    }
                                )
                                .liquidGlassSurface(
                                    cornerRadius: 17,
                                    glassMode: repository.preferences.glassMode,
                                    refractionIntensity: repository.preferences.refractionIntensity * 0.7,
                                    tintColor: isSelected ? theme.accent : .white,
                                    variant: .ultraClear
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var searchResultsContent: some View {
        let byId = Dictionary(uniqueKeysWithValues: repository.tracks.map { ($0.id, $0) })

        if (selectedScope == .all || selectedScope == .songs) && !matchingSongs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Songs (\(matchingSongs.count))")
                    .font(SnoozyTypography.title(19))
                    .foregroundStyle(theme.ink)

                SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(matchingSongs.enumerated()), id: \.element.id) { index, track in
                            SnoozyTrackRowView(
                                track: track,
                                subtitle: "\(track.artist) · \(track.album)",
                                isActive: playback.activeTrack?.id == track.id,
                                isFavorite: repository.isFavorite(track.id),
                                showTopSeparator: index > 0,
                                isGrouped: true,
                                theme: theme,
                                preferences: repository.preferences,
                                onTap: {
                                    repository.addRecentSearch(trimmedQuery)
                                    playback.playTrack(track, queue: matchingSongs)
                                },
                                onMenu: {
                                    onSelectTrackForMenu(track)
                                },
                                onPlayNext: {
                                    playback.playNext(track)
                                },
                                onAddToQueue: {
                                    playback.addToQueue(track)
                                },
                                onToggleFavorite: {
                                    repository.toggleFavorite(track.id)
                                }
                            )
                        }
                    }
                }
            }
        }

        if (selectedScope == .all || selectedScope == .artists) && !matchingArtists.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Artists (\(matchingArtists.count))")
                    .font(SnoozyTypography.title(19))
                    .foregroundStyle(theme.ink)

                SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(matchingArtists.enumerated()), id: \.element) { index, artist in
                            let artistTracks = repository.tracksForArtist(artist)
                            VStack(spacing: 0) {
                                if index > 0 {
                                    Rectangle()
                                        .fill(Color.white.opacity(theme.isDark ? 0.08 : 0.14))
                                        .frame(height: 0.5)
                                        .padding(.leading, 68)
                                }
                                Button {
                                    repository.addRecentSearch(trimmedQuery)
                                    onOpenArtist(artist)
                                } label: {
                                    HStack(spacing: 12) {
                                        SnoozyArtworkView(
                                            artworkPath: artistTracks.first?.artworkPath,
                                            size: 46,
                                            cornerRadius: 23,
                                            theme: theme
                                        )
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(artist)
                                                .font(SnoozyTypography.body(15, bold: true))
                                                .foregroundStyle(theme.ink)
                                                .lineLimit(1)
                                            Text("Artist · \(SnoozyFormat.countLabel(artistTracks.count, "song", "songs"))")
                                                .font(SnoozyTypography.footnote(12))
                                                .foregroundStyle(theme.inkMuted)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(theme.inkFaint)
                                    }
                                    .padding(.horizontal, 14)
                                    .frame(height: 60)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }

        if (selectedScope == .all || selectedScope == .albums) && !matchingAlbums.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Albums (\(matchingAlbums.count))")
                    .font(SnoozyTypography.title(19))
                    .foregroundStyle(theme.ink)

                SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(matchingAlbums.enumerated()), id: \.element.id) { index, album in
                            VStack(spacing: 0) {
                                if index > 0 {
                                    Rectangle()
                                        .fill(Color.white.opacity(theme.isDark ? 0.08 : 0.14))
                                        .frame(height: 0.5)
                                        .padding(.leading, 68)
                                }
                                Button {
                                    repository.addRecentSearch(trimmedQuery)
                                    onOpenAlbum(album.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        SnoozyArtworkView(
                                            artworkPath: album.artworkPath,
                                            size: 46,
                                            cornerRadius: 8,
                                            theme: theme
                                        )
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(album.title)
                                                .font(SnoozyTypography.body(15, bold: true))
                                                .foregroundStyle(theme.ink)
                                                .lineLimit(1)
                                            Text("Album · \(album.artist)")
                                                .font(SnoozyTypography.footnote(12))
                                                .foregroundStyle(theme.inkMuted)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(theme.inkFaint)
                                    }
                                    .padding(.horizontal, 14)
                                    .frame(height: 60)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }

        if (selectedScope == .all || selectedScope == .playlists) && !matchingPlaylists.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Playlists (\(matchingPlaylists.count))")
                    .font(SnoozyTypography.title(19))
                    .foregroundStyle(theme.ink)

                SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(matchingPlaylists.enumerated()), id: \.element.id) { index, playlist in
                            let pTracks = playlist.trackIds.compactMap { byId[$0] }
                            VStack(spacing: 0) {
                                if index > 0 {
                                    Rectangle()
                                        .fill(Color.white.opacity(theme.isDark ? 0.08 : 0.14))
                                        .frame(height: 0.5)
                                        .padding(.leading, 68)
                                }
                                Button {
                                    repository.addRecentSearch(trimmedQuery)
                                    onOpenPlaylist(playlist.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        SnoozyPlaylistCollageView(
                                            artworkPaths: pTracks.map(\.artworkPath),
                                            size: 46,
                                            cornerRadius: 8,
                                            theme: theme
                                        )
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(playlist.name)
                                                .font(SnoozyTypography.body(15, bold: true))
                                                .foregroundStyle(theme.ink)
                                                .lineLimit(1)
                                            Text("Playlist · \(SnoozyFormat.countLabel(pTracks.count, "song", "songs"))")
                                                .font(SnoozyTypography.footnote(12))
                                                .foregroundStyle(theme.inkMuted)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(theme.inkFaint)
                                    }
                                    .padding(.horizontal, 14)
                                    .frame(height: 60)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }

        if (selectedScope == .all || selectedScope == .genres) && !matchingGenres.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Genres (\(matchingGenres.count))")
                    .font(SnoozyTypography.title(19))
                    .foregroundStyle(theme.ink)

                SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(matchingGenres.enumerated()), id: \.element) { index, genre in
                            VStack(spacing: 0) {
                                if index > 0 {
                                    Rectangle()
                                        .fill(Color.white.opacity(theme.isDark ? 0.08 : 0.14))
                                        .frame(height: 0.5)
                                        .padding(.leading, 54)
                                }
                                Button {
                                    repository.addRecentSearch(trimmedQuery)
                                    onOpenGenre(genre)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "guitars.fill")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(theme.accent)
                                            .frame(width: 28)
                                        Text(genre)
                                            .font(SnoozyTypography.body(15, bold: true))
                                            .foregroundStyle(theme.ink)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(theme.inkFaint)
                                    }
                                    .padding(.horizontal, 14)
                                    .frame(height: 52)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptySearchResultsView: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(theme.inkFaint)
            Text("No Local Matches for \"\(trimmedQuery)\"")
                .font(SnoozyTypography.headline(17))
                .foregroundStyle(theme.ink)
            Text("Check the spelling or try searching by song title, artist, album, playlist, or folder.")
                .font(SnoozyTypography.footnote(13))
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }

    @ViewBuilder
    private var recentSearchesView: some View {
        if !repository.recentSearches.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Recent Searches")
                        .font(SnoozyTypography.title(19))
                        .foregroundStyle(theme.ink)
                    Spacer()
                    Button("Clear") {
                        repository.clearRecentSearches()
                    }
                    .font(SnoozyTypography.caption(13, bold: true))
                    .foregroundStyle(theme.accent)
                }

                SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(repository.recentSearches.enumerated()), id: \.element) { index, term in
                            VStack(spacing: 0) {
                                if index > 0 {
                                    Rectangle()
                                        .fill(Color.white.opacity(theme.isDark ? 0.08 : 0.14))
                                        .frame(height: 0.5)
                                        .padding(.leading, 48)
                                }
                                Button {
                                    query = term
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(theme.accent)
                                            .frame(width: 22)
                                        Text(term)
                                            .font(SnoozyTypography.body(15))
                                            .foregroundStyle(theme.ink)
                                        Spacer()
                                        Image(systemName: "arrow.up.left")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(theme.inkFaint)
                                    }
                                    .padding(.horizontal, 14)
                                    .frame(height: 48)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var browseLocalCategoriesSection: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        return VStack(alignment: .leading, spacing: 12) {
            Text("Browse Local Library")
                .font(SnoozyTypography.title(19))
                .foregroundStyle(theme.ink)

            LazyVGrid(columns: columns, spacing: 12) {
                localCategoryTile(
                    title: "Favorites",
                    subtitle: SnoozyFormat.countLabel(repository.favoriteTracks.count, "song", "songs"),
                    icon: "star.fill",
                    gradient: [Color(red: 0.12, green: 0.56, blue: 0.38), Color(red: 0.04, green: 0.28, blue: 0.19)],
                    artworkPath: repository.favoriteTracks.first?.artworkPath
                ) {
                    onOpenLibraryCategory(.favorites)
                }

                localCategoryTile(
                    title: "All Songs",
                    subtitle: SnoozyFormat.countLabel(repository.tracks.count, "song", "songs"),
                    icon: "music.note",
                    gradient: [Color(red: 0.14, green: 0.42, blue: 0.54), Color(red: 0.06, green: 0.20, blue: 0.30)],
                    artworkPath: repository.sortedSongs.first?.artworkPath
                ) {
                    onOpenLibraryCategory(.songs)
                }

                localCategoryTile(
                    title: "Albums",
                    subtitle: SnoozyFormat.countLabel(repository.albums.count, "album", "albums"),
                    icon: "square.stack.fill",
                    gradient: [Color(red: 0.26, green: 0.34, blue: 0.58), Color(red: 0.11, green: 0.15, blue: 0.32)],
                    artworkPath: repository.recentlyAddedAlbums.first?.artworkPath
                ) {
                    onOpenLibraryCategory(.albums)
                }

                localCategoryTile(
                    title: "Folders",
                    subtitle: SnoozyFormat.countLabel(repository.folderNames.count, "folder", "folders"),
                    icon: "folder.fill",
                    gradient: [Color(red: 0.22, green: 0.46, blue: 0.36), Color(red: 0.08, green: 0.22, blue: 0.17)],
                    artworkPath: repository.recentlyAdded.first?.artworkPath
                ) {
                    onOpenLibraryCategory(.folders)
                }

                ForEach(repository.genreNames.prefix(6), id: \.self) { genre in
                    let gTracks = repository.tracksForGenre(genre)
                    localCategoryTile(
                        title: genre,
                        subtitle: SnoozyFormat.countLabel(gTracks.count, "song", "songs"),
                        icon: "guitars.fill",
                        gradient: [Color(red: 0.18, green: 0.38, blue: 0.44), Color(red: 0.07, green: 0.18, blue: 0.22)],
                        artworkPath: gTracks.first?.artworkPath
                    ) {
                        onOpenGenre(genre)
                    }
                }
            }
        }
    }

    private func localCategoryTile(
        title: String,
        subtitle: String,
        icon: String,
        gradient: [Color],
        artworkPath: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                HStack {
                    Spacer()
                    VStack {
                        if let artworkPath {
                            SnoozyArtworkView(
                                artworkPath: artworkPath,
                                size: 54,
                                cornerRadius: 10,
                                theme: theme
                            )
                            .rotationEffect(.degrees(10))
                            .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
                            .offset(x: 6, y: 6)
                        } else {
                            Image(systemName: icon)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.24))
                                .padding(10)
                        }
                        Spacer()
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SnoozyTypography.body(15, bold: true))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(SnoozyTypography.caption(11, bold: true))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .lineLimit(1)
                }
                .padding(12)
            }
            .frame(height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }
}
