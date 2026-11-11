import SwiftUI

public struct SearchScreen: View {
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors
    public let onOpenAlbum: (String) -> Void
    public let onOpenArtist: (String) -> Void
    public let onOpenGenre: (String) -> Void
    public let onSelectTrackForMenu: (Track) -> Void

    @State private var query: String = ""

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var matchingSongs: [Track] {
        let q = trimmedQuery.lowercased()
        guard !q.isEmpty else { return [] }
        return repository.sortedSongs.filter {
            $0.title.lowercased().contains(q) ||
            $0.artist.lowercased().contains(q) ||
            $0.album.lowercased().contains(q)
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

    private var matchingGenres: [String] {
        let q = trimmedQuery.lowercased()
        guard !q.isEmpty else { return [] }
        return repository.genreNames.filter { $0.lowercased().contains(q) }
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Search")
                    .font(SnoozyTypography.display(28))
                    .foregroundStyle(theme.ink)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(theme.accent)
                    TextField("Songs, albums, artists, genres", text: $query)
                        .font(SnoozyTypography.body(15))
                        .foregroundStyle(theme.ink)
                        .submitLabel(.search)
                        .onSubmit {
                            if !trimmedQuery.isEmpty {
                                repository.addRecentSearch(trimmedQuery)
                            }
                        }
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(theme.inkMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .liquidGlassSurface(
                    cornerRadius: 24,
                    glassMode: repository.preferences.glassMode,
                    refractionIntensity: repository.preferences.refractionIntensity,
                    tintColor: theme.accent
                )

                if trimmedQuery.isEmpty {
                    recentSearchesView
                } else if matchingSongs.isEmpty && matchingAlbums.isEmpty && matchingArtists.isEmpty && matchingGenres.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(theme.inkFaint)
                        Text("No matches for \"\(trimmedQuery)\"")
                            .font(SnoozyTypography.headline(16))
                            .foregroundStyle(theme.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                } else {
                    if !matchingSongs.isEmpty {
                        Text("Songs (\(matchingSongs.count))")
                            .font(SnoozyTypography.headline(16))
                            .foregroundStyle(theme.inkMuted)
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
                                        }
                                    )
                                }
                            }
                        }
                    }

                    if !matchingAlbums.isEmpty {
                        Text("Albums (\(matchingAlbums.count))")
                            .font(SnoozyTypography.headline(16))
                            .foregroundStyle(theme.inkMuted)
                        ForEach(matchingAlbums) { album in
                            Button {
                                repository.addRecentSearch(trimmedQuery)
                                onOpenAlbum(album.id)
                            } label: {
                                HStack(spacing: 12) {
                                    SnoozyArtworkView(artworkPath: album.artworkPath, size: 44, cornerRadius: 10, theme: theme)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(album.title)
                                            .font(SnoozyTypography.body(15, bold: true))
                                            .foregroundStyle(theme.ink)
                                        Text(album.artist)
                                            .font(SnoozyTypography.footnote(12))
                                            .foregroundStyle(theme.inkMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(theme.inkFaint)
                                }
                                .padding(10)
                                .liquidGlassSurface(
                                    cornerRadius: 16,
                                    glassMode: repository.preferences.glassMode,
                                    refractionIntensity: repository.preferences.refractionIntensity * 0.7,
                                    tintColor: theme.accent
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !matchingArtists.isEmpty {
                        Text("Artists (\(matchingArtists.count))")
                            .font(SnoozyTypography.headline(16))
                            .foregroundStyle(theme.inkMuted)
                        ForEach(matchingArtists, id: \.self) { artist in
                            Button {
                                repository.addRecentSearch(trimmedQuery)
                                onOpenArtist(artist)
                            } label: {
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(theme.accent)
                                    Text(artist)
                                        .font(SnoozyTypography.body(15, bold: true))
                                        .foregroundStyle(theme.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(theme.inkFaint)
                                }
                                .padding(12)
                                .liquidGlassSurface(
                                    cornerRadius: 16,
                                    glassMode: repository.preferences.glassMode,
                                    refractionIntensity: repository.preferences.refractionIntensity * 0.7,
                                    tintColor: theme.accent
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !matchingGenres.isEmpty {
                        Text("Genres (\(matchingGenres.count))")
                            .font(SnoozyTypography.headline(16))
                            .foregroundStyle(theme.inkMuted)
                        ForEach(matchingGenres, id: \.self) { genre in
                            Button {
                                repository.addRecentSearch(trimmedQuery)
                                onOpenGenre(genre)
                            } label: {
                                HStack {
                                    Image(systemName: "guitars.fill")
                                        .foregroundStyle(theme.accent)
                                    Text(genre)
                                        .font(SnoozyTypography.body(15, bold: true))
                                        .foregroundStyle(theme.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(theme.inkFaint)
                                }
                                .padding(12)
                                .liquidGlassSurface(
                                    cornerRadius: 16,
                                    glassMode: repository.preferences.glassMode,
                                    refractionIntensity: repository.preferences.refractionIntensity * 0.7,
                                    tintColor: theme.accent
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, playback.activeTrack != nil ? 168 : 104)
        }
    }

    @ViewBuilder
    private var recentSearchesView: some View {
        if !repository.recentSearches.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Recent searches")
                        .font(SnoozyTypography.headline(16))
                        .foregroundStyle(theme.inkMuted)
                    Spacer()
                    Button("Clear") {
                        repository.clearRecentSearches()
                    }
                    .font(SnoozyTypography.caption(12, bold: true))
                    .foregroundStyle(theme.accent)
                }

                ForEach(repository.recentSearches, id: \.self) { term in
                    Button {
                        query = term
                    } label: {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(theme.inkMuted)
                            Text(term)
                                .font(SnoozyTypography.body(15))
                                .foregroundStyle(theme.ink)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .foregroundStyle(theme.inkFaint)
                        }
                        .padding(12)
                        .liquidGlassSurface(
                            cornerRadius: 16,
                            glassMode: repository.preferences.glassMode,
                            refractionIntensity: repository.preferences.refractionIntensity * 0.7,
                            tintColor: theme.accent
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
