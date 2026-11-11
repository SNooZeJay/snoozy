import SwiftUI

public struct LibraryScreen: View {
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    @Binding public var selectedTab: LibraryTab
    public let theme: SnoozyThemeColors
    public let onOpenAlbum: (String) -> Void
    public let onOpenArtist: (String) -> Void
    public let onOpenGenre: (String) -> Void
    public let onImportFiles: () -> Void
    public let onSelectTrackForMenu: (Track) -> Void

    @State private var albumGridMode: Bool = true
    @State private var showSongSortDialog: Bool = false
    @State private var showAlbumSortDialog: Bool = false

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Library")
                            .font(SnoozyTypography.display(28))
                            .foregroundStyle(theme.ink)
                        Text(SnoozyFormat.countLabel(repository.tracks.count, "song", "songs"))
                            .font(SnoozyTypography.footnote(13))
                            .foregroundStyle(theme.inkMuted)
                    }
                    Spacer()
                    LiquidGlassIconButton(
                        systemImage: "doc.badge.plus",
                        accessibilityLabel: "Import songs",
                        theme: theme,
                        preferences: repository.preferences,
                        action: onImportFiles
                    )
                }

                segmentedTabs

                toolbarRow

                switch selectedTab {
                case .songs:
                    songsList
                case .albums:
                    albumsContent
                case .artists:
                    artistsList
                case .genres:
                    genresList
                case .favorites:
                    favoritesList
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, playback.activeTrack != nil ? 168 : 104)
        }
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
    }

    private var segmentedTabs: some View {
        HStack(spacing: 2) {
            ForEach(LibraryTab.allCases) { tab in
                let isSelected = (tab == selectedTab)
                Button {
                    withAnimation(.spring(response: 0.27, dampingFraction: 0.78)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(SnoozyTypography.caption(12, bold: true))
                        .foregroundStyle(isSelected ? theme.accentInk : theme.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            Group {
                                if isSelected {
                                    Capsule()
                                        .fill(theme.accent)
                                        .shadow(color: theme.accent.opacity(0.40), radius: 6, x: 0, y: 2)
                                }
                            }
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .frame(height: 44)
        .liquidGlassSurface(
            cornerRadius: 22,
            glassMode: repository.preferences.glassMode,
            refractionIntensity: repository.preferences.refractionIntensity,
            tintColor: theme.accent
        )
    }

    private var toolbarRow: some View {
        HStack {
            Text(countSubtitle)
                .font(SnoozyTypography.footnote(13))
                .foregroundStyle(theme.inkMuted)
            Spacer()
            switch selectedTab {
            case .songs:
                LiquidGlassButton(
                    title: "Sort · \(repository.songSort.label)",
                    systemImage: "arrow.up.arrow.down",
                    theme: theme,
                    preferences: repository.preferences
                ) {
                    showSongSortDialog = true
                }
            case .albums:
                HStack(spacing: 8) {
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
                if !repository.favoriteTracks.isEmpty {
                    LiquidGlassButton(
                        title: "Shuffle",
                        systemImage: "shuffle",
                        theme: theme,
                        preferences: repository.preferences
                    ) {
                        let shuffled = repository.favoriteTracks.shuffled()
                        if let first = shuffled.first {
                            playback.playTrack(first, queue: shuffled, shuffleOverride: true)
                        }
                    }
                }
            default:
                EmptyView()
            }
        }
    }

    private var countSubtitle: String {
        switch selectedTab {
        case .songs:
            return SnoozyFormat.countLabel(repository.sortedSongs.count, "song", "songs")
        case .albums:
            return SnoozyFormat.countLabel(repository.sortedAlbums.count, "album", "albums")
        case .artists:
            return SnoozyFormat.countLabel(repository.artistNames.count, "artist", "artists")
        case .genres:
            return SnoozyFormat.countLabel(repository.genreNames.count, "genre", "genres")
        case .favorites:
            return SnoozyFormat.countLabel(repository.favoriteTracks.count, "favorite", "favorites")
        }
    }

    @ViewBuilder
    private var songsList: some View {
        let songs = repository.sortedSongs
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
                            subtitle: track.artist,
                            isActive: playback.activeTrack?.id == track.id,
                            isFavorite: repository.isFavorite(track.id),
                            showTopSeparator: index > 0,
                            isGrouped: true,
                            theme: theme,
                            preferences: repository.preferences,
                            onTap: {
                                playback.playTrack(track, queue: songs)
                            },
                            onMenu: {
                                onSelectTrackForMenu(track)
                            }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var albumsContent: some View {
        let albums = repository.sortedAlbums
        if albums.isEmpty {
            emptySectionCard(
                icon: "square.stack.3d.up",
                title: "No albums yet",
                message: "Albums appear automatically as soon as your songs are indexed."
            )
        } else if albumGridMode {
            let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(albums) { album in
                    Button {
                        onOpenAlbum(album.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            SnoozyArtworkView(
                                artworkPath: album.artworkPath,
                                size: 150,
                                cornerRadius: 18,
                                theme: theme
                            )
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
                        .padding(10)
                        .liquidGlassSurface(
                            cornerRadius: 22,
                            glassMode: repository.preferences.glassMode,
                            refractionIntensity: repository.preferences.refractionIntensity * 0.8,
                            tintColor: theme.accent
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(albums.enumerated()), id: \.element.id) { index, album in
                        VStack(spacing: 0) {
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.white.opacity(theme.isDark ? 0.10 : 0.14))
                                    .frame(height: 0.5)
                                    .padding(.leading, 70)
                            }
                            Button {
                                onOpenAlbum(album.id)
                            } label: {
                                HStack(spacing: 12) {
                                    SnoozyArtworkView(artworkPath: album.artworkPath, size: 46, cornerRadius: 12, theme: theme)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(album.title)
                                            .font(SnoozyTypography.body(15, bold: true))
                                            .foregroundStyle(theme.ink)
                                            .lineLimit(1)
                                        Text(album.artist)
                                            .font(SnoozyTypography.footnote(12))
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
    private var artistsList: some View {
        let names = repository.artistNames
        if names.isEmpty {
            emptySectionCard(
                icon: "person.fill",
                title: "No artists yet",
                message: "Artists appear when songs with artist tags are indexed."
            )
        } else {
            SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(names.enumerated()), id: \.element) { index, name in
                        VStack(spacing: 0) {
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.white.opacity(theme.isDark ? 0.10 : 0.14))
                                    .frame(height: 0.5)
                                    .padding(.leading, 66)
                            }
                            Button {
                                onOpenArtist(name)
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(theme.accent.opacity(0.20))
                                        .frame(width: 42, height: 42)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .foregroundStyle(theme.accent)
                                        )
                                    Text(name)
                                        .font(SnoozyTypography.body(15, bold: true))
                                        .foregroundStyle(theme.ink)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(theme.inkFaint)
                                }
                                .padding(.horizontal, 12)
                                .frame(minHeight: 56)
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
    private var genresList: some View {
        let genres = repository.genreNames
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
                        VStack(spacing: 0) {
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.white.opacity(theme.isDark ? 0.10 : 0.14))
                                    .frame(height: 0.5)
                                    .padding(.leading, 66)
                            }
                            Button {
                                onOpenGenre(genre)
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(theme.accent.opacity(0.20))
                                        .frame(width: 42, height: 42)
                                        .overlay(
                                            Image(systemName: "guitars.fill")
                                                .foregroundStyle(theme.accent)
                                        )
                                    Text(genre)
                                        .font(SnoozyTypography.body(15, bold: true))
                                        .foregroundStyle(theme.ink)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(theme.inkFaint)
                                }
                                .padding(.horizontal, 12)
                                .frame(minHeight: 56)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var favoritesList: some View {
        let favs = repository.favoriteTracks
        return Group {
            if favs.isEmpty {
                emptySectionCard(
                    icon: "heart",
                    title: "No favorites yet",
                    message: "Tap a song's menu or the heart icon in the player to favorite it."
                )
            } else {
                SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(favs.enumerated()), id: \.element.id) { index, track in
                            SnoozyTrackRowView(
                                track: track,
                                subtitle: track.artist,
                                isActive: playback.activeTrack?.id == track.id,
                                isFavorite: true,
                                showTopSeparator: index > 0,
                                isGrouped: true,
                                theme: theme,
                                preferences: repository.preferences,
                                onTap: {
                                    playback.playTrack(track, queue: favs)
                                },
                                onMenu: {
                                    onSelectTrackForMenu(track)
                                }
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
            cornerRadius: 26,
            glassMode: repository.preferences.glassMode,
            refractionIntensity: repository.preferences.refractionIntensity,
            tintColor: theme.accent
        )
    }
}
