import SwiftUI

public struct AlbumDetailScreen: View {
    public let albumKey: String
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors
    public var onOpenArtist: ((String) -> Void)? = nil
    public let onSelectTrackForMenu: (Track) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.snoozyLayout) private var layout

    public init(
        albumKey: String,
        repository: LibraryRepository,
        playback: PlaybackController,
        theme: SnoozyThemeColors,
        onOpenArtist: ((String) -> Void)? = nil,
        onSelectTrackForMenu: @escaping (Track) -> Void
    ) {
        self.albumKey = albumKey
        self.repository = repository
        self.playback = playback
        self.theme = theme
        self.onOpenArtist = onOpenArtist
        self.onSelectTrackForMenu = onSelectTrackForMenu
    }

    private var album: Album? {
        repository.albums.first(where: { $0.id == albumKey })
    }

    private var tracks: [Track] {
        guard let album else { return [] }
        let byId = repository.tracksById
        return album.trackIds.compactMap { byId[$0] }
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
                }
                .padding(.top, layout.isLandscape ? 8 : 10)

                if let album {
                    // Apple Music Centered Large Album Artwork
                    SnoozyArtworkView(
                        artworkPath: album.artworkPath,
                        size: layout.detailHeroArtworkSize,
                        cornerRadius: 18,
                        theme: theme
                    )
                    .shadow(color: Color.black.opacity(0.38), radius: 18, x: 0, y: 10)
                    .padding(.top, 2)

                    // Apple Music Album Title + Tappable Accent Artist + Metadata Overline
                    VStack(spacing: 5) {
                        Text(album.title)
                            .font(SnoozyTypography.title(22))
                            .foregroundStyle(theme.ink)
                            .multilineTextAlignment(.center)

                        if let onOpenArtist {
                            Button {
                                onOpenArtist(album.artist)
                            } label: {
                                Text(album.artist)
                                    .font(SnoozyTypography.body(17, bold: true))
                                    .foregroundStyle(theme.accent)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text(album.artist)
                                .font(SnoozyTypography.body(17, bold: true))
                                .foregroundStyle(theme.accent)
                        }

                        let hasLossless = tracks.contains(where: \.isLosslessFormat)
                        let metaParts = [
                            tracks.first?.genre?.uppercased(),
                            album.year,
                            hasLossless ? "LOSSLESS" : nil
                        ].compactMap { $0 }

                        if !metaParts.isEmpty {
                            Text(metaParts.joined(separator: " · "))
                                .font(SnoozyTypography.caption(11, bold: true))
                                .foregroundStyle(theme.inkMuted)
                        }
                    }

                    SnoozyCollectionActionsRow(
                        playLabel: "Play album",
                        shuffleLabel: "Shuffle album",
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

                    // Numbered Apple Music Album Track List
                    SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                                SnoozyTrackRowView(
                                    track: track,
                                    subtitle: track.artist,
                                    trackNumberBadge: track.trackNumber ?? (index + 1),
                                    isActive: playback.activeTrack?.id == track.id,
                                    isFavorite: repository.isFavorite(track.id),
                                    showTopSeparator: index > 0,
                                    isGrouped: true,
                                    theme: theme,
                                    preferences: repository.preferences,
                                    onTap: { playback.playTrack(track, queue: tracks) },
                                    onMenu: { onSelectTrackForMenu(track) },
                                    onPlayNext: { playback.playNext(track) },
                                    onAddToQueue: { playback.addToQueue(track) },
                                    onToggleFavorite: { repository.toggleFavorite(track.id) }
                                )
                            }
                        }
                    }

                    // Apple Music Album Footer
                    VStack(alignment: .leading, spacing: 3) {
                        if let year = album.year {
                            Text("Released \(year)")
                        }
                        Text("\(SnoozyFormat.countLabel(tracks.count, "song", "songs")), \(SnoozyFormat.formatDuration(album.duration))")
                    }
                    .font(SnoozyTypography.footnote(13))
                    .foregroundStyle(theme.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                } else {
                    Text("Album not found")
                        .font(SnoozyTypography.headline(17))
                        .foregroundStyle(theme.inkMuted)
                        .padding(.top, 48)
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
    }
}

public struct ArtistDetailScreen: View {
    public let artistName: String
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors
    public let onOpenAlbum: (String) -> Void
    public let onSelectTrackForMenu: (Track) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.snoozyLayout) private var layout

    private var tracks: [Track] {
        repository.tracksForArtist(artistName)
    }

    private var albums: [Album] {
        repository.albumsForArtist(artistName)
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
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
                }

                HStack(spacing: 16) {
                    SnoozyArtworkView(
                        artworkPath: tracks.compactMap(\.artworkPath).first,
                        size: 76,
                        cornerRadius: 38,
                        theme: theme
                    )
                    .shadow(color: Color.black.opacity(0.28), radius: 10, x: 0, y: 5)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(artistName)
                            .font(SnoozyTypography.display(26))
                            .foregroundStyle(theme.ink)
                            .lineLimit(2)
                        Text("\(SnoozyFormat.countLabel(tracks.count, "song", "songs")) · \(SnoozyFormat.countLabel(albums.count, "album", "albums"))")
                            .font(SnoozyTypography.footnote(13))
                            .foregroundStyle(theme.inkMuted)
                    }
                    Spacer()
                }

                SnoozyCollectionActionsRow(
                    playLabel: "Play \(artistName)",
                    shuffleLabel: "Shuffle \(artistName)",
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

                if !albums.isEmpty {
                    Text("Albums")
                        .font(SnoozyTypography.title(layout.sectionTitleSize))
                        .foregroundStyle(theme.ink)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(albums) { album in
                                Button {
                                    onOpenAlbum(album.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        SnoozyArtworkView(artworkPath: album.artworkPath, size: layout.shelfItemSize, cornerRadius: 14, theme: theme)
                                            .shadow(color: Color.black.opacity(0.24), radius: 8, x: 0, y: 4)
                                        Text(album.title)
                                            .font(SnoozyTypography.body(14, bold: true))
                                            .foregroundStyle(theme.ink)
                                            .lineLimit(1)
                                        if let year = album.year {
                                            Text(year)
                                                .font(SnoozyTypography.footnote(12))
                                                .foregroundStyle(theme.inkMuted)
                                        }
                                    }
                                    .frame(width: layout.shelfItemSize)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .snoozyHorizontalScrollZone(id: "artist-albums-shelf")
                }

                Text("Songs")
                    .font(SnoozyTypography.title(layout.sectionTitleSize))
                    .foregroundStyle(theme.ink)

                SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            SnoozyTrackRowView(
                                track: track,
                                subtitle: track.album,
                                isActive: playback.activeTrack?.id == track.id,
                                isFavorite: repository.isFavorite(track.id),
                                showTopSeparator: index > 0,
                                isGrouped: true,
                                theme: theme,
                                preferences: repository.preferences,
                                onTap: { playback.playTrack(track, queue: tracks) },
                                onMenu: { onSelectTrackForMenu(track) },
                                onPlayNext: { playback.playNext(track) },
                                onAddToQueue: { playback.addToQueue(track) },
                                onToggleFavorite: { repository.toggleFavorite(track.id) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.top, layout.isLandscape ? 8 : 10)
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
    }
}

public struct GenreDetailScreen: View {
    public let genreName: String
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors
    public let onSelectTrackForMenu: (Track) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.snoozyLayout) private var layout

    private var tracks: [Track] {
        repository.tracksForGenre(genreName)
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
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
                }

                HStack(spacing: 16) {
                    SnoozyPlaylistCollageView(
                        artworkPaths: tracks.map(\.artworkPath),
                        size: 76,
                        cornerRadius: 18,
                        theme: theme
                    )
                    .shadow(color: Color.black.opacity(0.26), radius: 10, x: 0, y: 5)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(genreName)
                            .font(SnoozyTypography.display(26))
                            .foregroundStyle(theme.ink)
                            .lineLimit(2)
                        Text("\(SnoozyFormat.countLabel(tracks.count, "song", "songs")) · Local Genre")
                            .font(SnoozyTypography.footnote(13))
                            .foregroundStyle(theme.inkMuted)
                    }
                    Spacer()
                }

                SnoozyCollectionActionsRow(
                    playLabel: "Play \(genreName)",
                    shuffleLabel: "Shuffle \(genreName)",
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
                                onMenu: { onSelectTrackForMenu(track) },
                                onPlayNext: { playback.playNext(track) },
                                onAddToQueue: { playback.addToQueue(track) },
                                onToggleFavorite: { repository.toggleFavorite(track.id) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.top, layout.isLandscape ? 8 : 10)
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
    }
}

public struct FolderDetailScreen: View {
    public let folderName: String
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors
    public let onSelectTrackForMenu: (Track) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.snoozyLayout) private var layout

    private var tracks: [Track] {
        repository.tracksForFolder(folderName)
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
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
                }

                HStack(spacing: 16) {
                    ZStack(alignment: .bottomTrailing) {
                        SnoozyArtworkView(
                            artworkPath: tracks.compactMap(\.artworkPath).first,
                            size: 76,
                            cornerRadius: 18,
                            theme: theme,
                            placeholderSymbol: "folder.fill"
                        )
                        .shadow(color: Color.black.opacity(0.26), radius: 10, x: 0, y: 5)

                        Circle()
                            .fill(theme.accent)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white)
                            )
                            .offset(x: 3, y: 3)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(folderName)
                            .font(SnoozyTypography.display(26))
                            .foregroundStyle(theme.ink)
                            .lineLimit(2)
                        Text("\(SnoozyFormat.countLabel(tracks.count, "song", "songs")) · On My iPhone > Snoozy")
                            .font(SnoozyTypography.footnote(13))
                            .foregroundStyle(theme.inkMuted)
                    }
                    Spacer()
                }

                SnoozyCollectionActionsRow(
                    playLabel: "Play folder",
                    shuffleLabel: "Shuffle folder",
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
                                onMenu: { onSelectTrackForMenu(track) },
                                onPlayNext: { playback.playNext(track) },
                                onAddToQueue: { playback.addToQueue(track) },
                                onToggleFavorite: { repository.toggleFavorite(track.id) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.top, layout.isLandscape ? 8 : 10)
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
    }
}
