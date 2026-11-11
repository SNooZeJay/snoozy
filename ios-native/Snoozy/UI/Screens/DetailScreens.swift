import SwiftUI

public struct DetailScreensMarker {}

public struct AlbumDetailScreen: View {
    public let albumKey: String
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors
    public let onSelectTrackForMenu: (Track) -> Void

    private var album: Album? {
        repository.albums.first(where: { $0.id == albumKey })
    }

    private var tracks: [Track] {
        guard let album else { return [] }
        let byId = Dictionary(uniqueKeysWithValues: repository.tracks.map { ($0.id, $0) })
        return album.trackIds.compactMap { byId[$0] }
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if let album {
                    SnoozyArtworkView(
                        artworkPath: album.artworkPath,
                        size: 184,
                        cornerRadius: 28,
                        theme: theme
                    )
                    .padding(.top, 8)

                    VStack(spacing: 4) {
                        Text(album.title)
                            .font(SnoozyTypography.title(22))
                            .foregroundStyle(theme.ink)
                            .multilineTextAlignment(.center)
                        Text(
                            [
                                album.artist,
                                album.year,
                                SnoozyFormat.countLabel(tracks.count, "track", "tracks"),
                                SnoozyFormat.formatDuration(album.duration)
                            ]
                            .compactMap { $0 }
                            .joined(separator: " · ")
                        )
                        .font(SnoozyTypography.footnote(13))
                        .foregroundStyle(theme.inkMuted)
                        .multilineTextAlignment(.center)
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

                    SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                                SnoozyTrackRowView(
                                    track: track,
                                    subtitle: track.artist,
                                    isActive: playback.activeTrack?.id == track.id,
                                    isFavorite: repository.isFavorite(track.id),
                                    showTopSeparator: index > 0,
                                    isGrouped: true,
                                    theme: theme,
                                    preferences: repository.preferences,
                                    onTap: { playback.playTrack(track, queue: tracks) },
                                    onMenu: { onSelectTrackForMenu(track) }
                                )
                            }
                        }
                    }
                } else {
                    Text("Album not found")
                        .font(SnoozyTypography.headline(17))
                        .foregroundStyle(theme.inkMuted)
                        .padding(.top, 48)
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
        .navigationTitle(album?.title ?? "Album")
        .navigationBarTitleDisplayMode(.inline)
    }
}

public struct ArtistDetailScreen: View {
    public let artistName: String
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors
    public let onOpenAlbum: (String) -> Void
    public let onSelectTrackForMenu: (Track) -> Void

    private var tracks: [Track] {
        repository.tracksForArtist(artistName)
    }

    private var albums: [Album] {
        repository.albumsForArtist(artistName)
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(artistName)
                        .font(SnoozyTypography.display(26))
                        .foregroundStyle(theme.ink)
                    Text("\(SnoozyFormat.countLabel(tracks.count, "song", "songs")) · \(SnoozyFormat.countLabel(albums.count, "album", "albums"))")
                        .font(SnoozyTypography.footnote(13))
                        .foregroundStyle(theme.inkMuted)
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
                        .font(SnoozyTypography.headline(16))
                        .foregroundStyle(theme.inkMuted)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(albums) { album in
                                Button {
                                    onOpenAlbum(album.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        SnoozyArtworkView(artworkPath: album.artworkPath, size: 128, cornerRadius: 18, theme: theme)
                                        Text(album.title)
                                            .font(SnoozyTypography.body(14, bold: true))
                                            .foregroundStyle(theme.ink)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 128)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Text("Songs")
                    .font(SnoozyTypography.headline(16))
                    .foregroundStyle(theme.inkMuted)

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
                                onMenu: { onSelectTrackForMenu(track) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, playback.activeTrack != nil ? 168 : 104)
        }
        .background(
            LiquidAuraBackgroundView(
                theme: theme,
                palette: playback.activePalette,
                preferences: repository.preferences
            )
        )
        .navigationTitle(artistName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

public struct GenreDetailScreen: View {
    public let genreName: String
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors
    public let onSelectTrackForMenu: (Track) -> Void

    private var tracks: [Track] {
        repository.tracksForGenre(genreName)
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(genreName)
                        .font(SnoozyTypography.display(26))
                        .foregroundStyle(theme.ink)
                    Text(SnoozyFormat.countLabel(tracks.count, "song", "songs"))
                        .font(SnoozyTypography.footnote(13))
                        .foregroundStyle(theme.inkMuted)
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
                                subtitle: track.artist,
                                isActive: playback.activeTrack?.id == track.id,
                                isFavorite: repository.isFavorite(track.id),
                                showTopSeparator: index > 0,
                                isGrouped: true,
                                theme: theme,
                                preferences: repository.preferences,
                                onTap: { playback.playTrack(track, queue: tracks) },
                                onMenu: { onSelectTrackForMenu(track) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, playback.activeTrack != nil ? 168 : 104)
        }
        .background(
            LiquidAuraBackgroundView(
                theme: theme,
                palette: playback.activePalette,
                preferences: repository.preferences
            )
        )
        .navigationTitle(genreName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
