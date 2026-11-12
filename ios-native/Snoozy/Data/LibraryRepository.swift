import Foundation
import SwiftUI
import UIKit

@MainActor
public final class LibraryRepository: ObservableObject {
    public let store: SnoozyStore

    @Published public private(set) var rawTracks: [Track] = []
    @Published public private(set) var tracks: [Track] = []
    @Published public private(set) var tracksById: [String: Track] = [:]
    @Published public private(set) var sortedSongs: [Track] = []
    @Published public private(set) var albums: [Album] = []
    @Published public private(set) var sortedAlbums: [Album] = []
    @Published public private(set) var artistNames: [String] = []
    @Published public private(set) var genreNames: [String] = []
    @Published public private(set) var folderNames: [String] = []
    @Published public private(set) var favoriteTracks: [Track] = []
    @Published public private(set) var recentTracks: [Track] = []
    @Published public private(set) var recentlyPlayedAlbums: [Album] = []
    @Published public private(set) var recentlyAddedAlbums: [Album] = []
    @Published public private(set) var mostPlayedTracks: [PlayedTrackSummary] = []
    @Published public private(set) var playlists: [Playlist] = []
    @Published public private(set) var recents: [String] = []
    @Published public private(set) var favoriteTrackIds: Set<String> = []
    @Published public private(set) var trackOverrides: [String: TrackOverride] = [:]
    @Published public private(set) var albumOverrides: [String: AlbumOverride] = [:]
    @Published public private(set) var artistOverrides: [String: ArtistOverride] = [:]
    @Published public private(set) var playHistory: [PlayHistoryEntry] = []
    @Published public private(set) var listeningSessions: [ListeningSession] = []
    @Published public private(set) var errorLog: [ErrorLogEntry] = []
    @Published public private(set) var recentSearches: [String] = []
    @Published public private(set) var lyricsOffsets: [String: Double] = [:]
    @Published public private(set) var songSort: SongSort = .title
    @Published public private(set) var albumSort: AlbumSort = .title
    @Published public private(set) var preferences: SnoozyPreferences = SnoozyPreferences()
    @Published public private(set) var isScanning: Bool = false
    @Published public var bannerMessage: String? = nil

    public init(store: SnoozyStore) {
        self.store = store
        let loaded = store.load()
        applyPersistedState(loaded)
        if let notice = store.recoveryNotice {
            bannerMessage = notice
        }
    }

    public func fileURL(for track: Track) -> URL {
        store.documentsURL.appendingPathComponent(track.relativePath)
    }

    public func scanLibrary() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        let existingByPath = Dictionary(uniqueKeysWithValues: rawTracks.map { ($0.relativePath, $0) })
        guard let scanned = await AudioScanner.scanDirectory(
            documentsURL: store.documentsURL,
            artworkCacheURL: store.artworkCacheURL,
            existingTracksByPath: existingByPath
        ) else {
            let message = "Could not read your music folder. Existing library was kept."
            bannerMessage = message
            logError(category: "scan", message: message)
            return
        }

        if scanned.isEmpty && !rawTracks.isEmpty {
            let message = "No songs found. Existing library was kept. Check Files and rescan in Settings."
            bannerMessage = message
            logError(category: "scan", message: message)
            return
        }

        let validIds = Set(scanned.map(\.id))

        let updated = store.update { state in
            state.scannedTracks = scanned
            state.recents = state.recents.filter { validIds.contains($0) }
            state.favoriteTrackIds = state.favoriteTrackIds.filter { validIds.contains($0) }
            for idx in state.playlists.indices {
                state.playlists[idx].trackIds = state.playlists[idx].trackIds.filter { validIds.contains($0) }
            }
        }
        applyPersistedState(updated)
    }

    public func deleteTrack(_ track: Track) {
        let fileURL = self.fileURL(for: track)
        try? FileManager.default.removeItem(at: fileURL)
        let lrcURL = fileURL.deletingPathExtension().appendingPathExtension("lrc")
        if FileManager.default.fileExists(atPath: lrcURL.path) {
            try? FileManager.default.removeItem(at: lrcURL)
        }
        let updated = store.update { state in
            state.scannedTracks.removeAll { $0.id == track.id }
            state.recents.removeAll { $0 == track.id }
            state.favoriteTrackIds.removeAll { $0 == track.id }
            state.trackOverrides.removeValue(forKey: track.id)
            for idx in state.playlists.indices {
                state.playlists[idx].trackIds.removeAll { $0 == track.id }
            }
        }
        applyPersistedState(updated)
        bannerMessage = "Deleted \"\(track.title)\" from Snoozy."
    }

    public func importFiles(from urls: [URL]) async {
        let count = AudioScanner.importExternalURLs(urls, into: store.documentsURL)
        await scanLibrary()
        if count > 0 {
            bannerMessage = "Imported \(count) \(count == 1 ? "song" : "songs") into Snoozy."
        } else {
            bannerMessage = "No supported audio files found in selection."
        }
    }

    public func seedShowcaseLibraryIfNeeded() async {
        let seedKey = "snoozy.hasSeededShowcaseLibrary.v1"
        guard !UserDefaults.standard.bool(forKey: seedKey), rawTracks.isEmpty else { return }
        UserDefaults.standard.set(true, forKey: seedKey)
        await createSampleSynthTrack()
    }

    public func createSampleSynthTrack() async {
        struct ShowcaseSpec {
            let fileBase: String
            let title: String
            let artist: String
            let album: String
            let genre: String
            let year: String
            let trackNumber: Int
            let chords: [Double]
            let lrc: String
            let topColor: UIColor
            let bottomColor: UIColor
            let accentColor: UIColor
        }

        let specs: [ShowcaseSpec] = [
            ShowcaseSpec(
                fileBase: "Liquid Glass Prelude",
                title: "Liquid Glass Prelude",
                artist: "Snoozy Audio Lab",
                album: "Prismatic Sessions",
                genre: "Ambient",
                year: "2026",
                trackNumber: 1,
                chords: [220.0, 277.18, 329.63, 415.30, 493.88],
                lrc: """
                [ti:Liquid Glass Prelude]
                [ar:Snoozy Audio Lab]
                [00:00.20]Welcome to Snoozy on iPhone 13 mini
                [00:04.20]Optical Liquid Glass refraction in real time
                [00:08.50]Drop FLAC, MP3, WAV, or M4A songs in the Files app
                [00:13.00]Pure offline playback with zero subscriptions
                """,
                topColor: UIColor(red: 0.04, green: 0.36, blue: 0.28, alpha: 1.0),
                bottomColor: UIColor(red: 0.02, green: 0.08, blue: 0.12, alpha: 1.0),
                accentColor: UIColor(red: 0.16, green: 0.88, blue: 0.64, alpha: 1.0)
            ),
            ShowcaseSpec(
                fileBase: "Emerald Refraction",
                title: "Emerald Refraction",
                artist: "Snoozy Audio Lab",
                album: "Prismatic Sessions",
                genre: "Electronic",
                year: "2026",
                trackNumber: 2,
                chords: [196.0, 246.94, 293.66, 369.99, 440.0],
                lrc: """
                [ti:Emerald Refraction]
                [ar:Snoozy Audio Lab]
                [00:00.20]Specular highlights glide across floating glass
                [00:04.50]Swipe horizontally across the bottom pill to switch tabs
                [00:09.00]Tap the mini-player to open full-screen Now Playing
                [00:13.00]100% local audio engine built for iOS
                """,
                topColor: UIColor(red: 0.06, green: 0.30, blue: 0.44, alpha: 1.0),
                bottomColor: UIColor(red: 0.02, green: 0.06, blue: 0.14, alpha: 1.0),
                accentColor: UIColor(red: 0.22, green: 0.78, blue: 0.94, alpha: 1.0)
            ),
            ShowcaseSpec(
                fileBase: "Midnight Obsidian",
                title: "Midnight Obsidian",
                artist: "Velvet Horizon",
                album: "Nocturne Offline",
                genre: "Chillout",
                year: "2026",
                trackNumber: 1,
                chords: [174.61, 220.0, 261.63, 329.63, 392.0],
                lrc: """
                [ti:Midnight Obsidian]
                [ar:Velvet Horizon]
                [00:00.20]Deep obsidian contrast for late-night listening
                [00:04.50]Synced LRC lyrics scroll smoothly with your music
                [00:09.00]Organize playlists, folders, albums, and favorites
                [00:13.00]Your personal music collection, always offline
                """,
                topColor: UIColor(red: 0.18, green: 0.14, blue: 0.38, alpha: 1.0),
                bottomColor: UIColor(red: 0.03, green: 0.04, blue: 0.09, alpha: 1.0),
                accentColor: UIColor(red: 0.48, green: 0.62, blue: 0.96, alpha: 1.0)
            )
        ]

        var artworkPathsByFileBase: [String: String] = [:]
        for spec in specs {
            let wavURL = store.documentsURL.appendingPathComponent("\(spec.fileBase).wav")
            if !FileManager.default.fileExists(atPath: wavURL.path) {
                if let data = Self.generateStereoChordWav(durationSeconds: 17.0, frequencies: spec.chords) {
                    try? data.write(to: wavURL, options: .atomic)
                }
            }
            let lrcURL = store.documentsURL.appendingPathComponent("\(spec.fileBase).lrc")
            if !FileManager.default.fileExists(atPath: lrcURL.path) {
                try? spec.lrc.data(using: .utf8)?.write(to: lrcURL, options: .atomic)
            }
            let artURL = store.artworkCacheURL.appendingPathComponent("showcase-\(spec.fileBase.lowercased().replacingOccurrences(of: " ", with: "-")).png")
            if !FileManager.default.fileExists(atPath: artURL.path) {
                if let pngData = Self.renderShowcaseCoverPNG(
                    title: spec.album,
                    subtitle: spec.artist,
                    topColor: spec.topColor,
                    bottomColor: spec.bottomColor,
                    accentColor: spec.accentColor
                ) {
                    try? pngData.write(to: artURL, options: .atomic)
                }
            }
            if FileManager.default.fileExists(atPath: artURL.path) {
                artworkPathsByFileBase[spec.fileBase] = artURL.path
            }
        }

        await scanLibrary()

        let updated = store.update { state in
            var seededIds: [String] = []
            for spec in specs {
                let relPath = "\(spec.fileBase).wav"
                guard let track = state.scannedTracks.first(where: { $0.relativePath == relPath }) else { continue }
                seededIds.append(track.id)
                state.trackOverrides[track.id] = TrackOverride(
                    trackId: track.id,
                    title: spec.title,
                    artist: spec.artist,
                    album: spec.album,
                    albumArtist: spec.artist,
                    genre: spec.genre,
                    year: spec.year,
                    trackNumber: spec.trackNumber,
                    descriptionText: "Snoozy Offline Showcase Track",
                    artworkPath: artworkPathsByFileBase[spec.fileBase]
                )
            }
            for id in seededIds.reversed() {
                state.recents = PlaybackQueueOps.pushRecent(current: state.recents, trackId: id)
            }
            if let firstId = seededIds.first, !state.favoriteTrackIds.contains(firstId) {
                state.favoriteTrackIds.insert(firstId, at: 0)
            }
            if state.playlists.isEmpty, !seededIds.isEmpty {
                state.playlists.append(
                    Playlist(
                        id: "playlist-showcase-liquid-glass",
                        name: "Liquid Glass Sessions",
                        trackIds: seededIds,
                        createdAt: Int64(Date().timeIntervalSince1970 * 1000)
                    )
                )
            }
        }
        applyPersistedState(updated)
    }

    public func searchLibrary(query: String) -> LibrarySearchResults {
        Self.filterLibrary(
            query: query,
            sortedSongs: sortedSongs,
            sortedAlbums: sortedAlbums,
            artistNames: artistNames,
            playlists: playlists,
            folderNames: folderNames,
            genreNames: genreNames
        )
    }

    public static func filterLibrary(
        query: String,
        sortedSongs: [Track],
        sortedAlbums: [Album],
        artistNames: [String],
        playlists: [Playlist],
        folderNames: [String] = [],
        genreNames: [String] = []
    ) -> LibrarySearchResults {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return LibrarySearchResults(
                songs: sortedSongs,
                albums: sortedAlbums,
                artists: artistNames,
                playlists: playlists,
                folders: folderNames,
                genres: genreNames
            )
        }

        let tokens = trimmed
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        let matchedSongs = sortedSongs.filter { track in
            let haystack = [
                track.title,
                track.artist,
                track.album,
                track.albumArtist ?? "",
                track.composer ?? "",
                track.genre ?? "",
                track.folderName
            ]
            .joined(separator: " ")
            .lowercased()
            return tokens.allSatisfy { haystack.contains($0) }
        }

        let matchedAlbums = sortedAlbums.filter { album in
            let haystack = "\(album.title) \(album.artist) \(album.year ?? "")".lowercased()
            return tokens.allSatisfy { haystack.contains($0) }
        }

        let matchedArtists = artistNames.filter { name in
            let lower = name.lowercased()
            return tokens.allSatisfy { lower.contains($0) }
        }

        let matchedPlaylists = playlists.filter { playlist in
            let lower = playlist.name.lowercased()
            return tokens.allSatisfy { lower.contains($0) }
        }

        let matchedFolders = folderNames.filter { folder in
            let lower = folder.lowercased()
            return tokens.allSatisfy { lower.contains($0) }
        }

        let matchedGenres = genreNames.filter { genre in
            let lower = genre.lowercased()
            return tokens.allSatisfy { lower.contains($0) }
        }

        return LibrarySearchResults(
            songs: matchedSongs,
            albums: matchedAlbums,
            artists: matchedArtists,
            playlists: matchedPlaylists,
            folders: matchedFolders,
            genres: matchedGenres
        )
    }

    public static func sortTracks(_ tracks: [Track], by songSort: SongSort) -> [Track] {
        switch songSort {
        case .title:
            return tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .artist:
            return tracks.sorted {
                let cmp = $0.artist.localizedCaseInsensitiveCompare($1.artist)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .recentlyAdded:
            return tracks.sorted { $0.addedAt > $1.addedAt }
        case .duration:
            return tracks.sorted { $0.duration > $1.duration }
        }
    }

    public static func sortAlbums(_ albums: [Album], by albumSort: AlbumSort) -> [Album] {
        switch albumSort {
        case .title:
            return albums.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .artist:
            return albums.sorted { $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending }
        case .year:
            return albums.sorted { ($0.year ?? "") > ($1.year ?? "") }
        case .recentlyAdded:
            return albums.sorted { $0.addedAt > $1.addedAt }
        }
    }

    public func tracksForArtist(_ artist: String) -> [Track] {
        tracks.filter { $0.artist.caseInsensitiveCompare(artist) == .orderedSame }
    }

    public func albumsForArtist(_ artist: String) -> [Album] {
        albums.filter { $0.artist.caseInsensitiveCompare(artist) == .orderedSame }
    }

    public func tracksForGenre(_ genre: String) -> [Track] {
        tracks.filter { ($0.genre ?? "").caseInsensitiveCompare(genre) == .orderedSame }
    }

    public func tracksForFolder(_ folder: String) -> [Track] {
        tracks.filter { $0.folderName.caseInsensitiveCompare(folder) == .orderedSame }
    }

    public func setSongSort(_ sort: SongSort) {
        let updated = store.update { $0.songSort = sort }
        applyPersistedState(updated)
    }

    public func setAlbumSort(_ sort: AlbumSort) {
        let updated = store.update { $0.albumSort = sort }
        applyPersistedState(updated)
    }

    public func toggleFavorite(_ trackId: String) {
        let updated = store.update { state in
            if let idx = state.favoriteTrackIds.firstIndex(of: trackId) {
                state.favoriteTrackIds.remove(at: idx)
            } else {
                state.favoriteTrackIds.insert(trackId, at: 0)
            }
        }
        applyPersistedState(updated)
    }

    public func isFavorite(_ trackId: String) -> Bool {
        favoriteTrackIds.contains(trackId)
    }

    @discardableResult
    public func createPlaylist(name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let id = "playlist-\(Int64(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(6).lowercased())"
        let playlist = Playlist(
            id: id,
            name: trimmed,
            trackIds: [],
            createdAt: Int64(Date().timeIntervalSince1970 * 1000)
        )
        let updated = store.update { $0.playlists.insert(playlist, at: 0) }
        applyPersistedState(updated)
        return id
    }

    public func renamePlaylist(id: String, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let updated = store.update { state in
            if let idx = state.playlists.firstIndex(where: { $0.id == id }) {
                state.playlists[idx].name = trimmed
            }
        }
        applyPersistedState(updated)
    }

    public func deletePlaylist(id: String) {
        let updated = store.update { state in
            state.playlists.removeAll { $0.id == id }
        }
        applyPersistedState(updated)
    }

    public func addToPlaylist(playlistId: String, trackId: String) {
        let updated = store.update { state in
            guard let idx = state.playlists.firstIndex(where: { $0.id == playlistId }) else { return }
            if !state.playlists[idx].trackIds.contains(trackId) {
                state.playlists[idx].trackIds.append(trackId)
            }
        }
        applyPersistedState(updated)
    }

    public func removeFromPlaylist(playlistId: String, trackId: String) {
        let updated = store.update { state in
            guard let idx = state.playlists.firstIndex(where: { $0.id == playlistId }) else { return }
            state.playlists[idx].trackIds.removeAll { $0 == trackId }
        }
        applyPersistedState(updated)
    }

    public func movePlaylistTrack(playlistId: String, from: Int, to: Int) {
        let updated = store.update { state in
            guard let idx = state.playlists.firstIndex(where: { $0.id == playlistId }) else { return }
            var ids = state.playlists[idx].trackIds
            guard ids.indices.contains(from), ids.indices.contains(to), from != to else { return }
            let item = ids.remove(at: from)
            ids.insert(item, at: to)
            state.playlists[idx].trackIds = ids
        }
        applyPersistedState(updated)
    }

    public func saveTrackOverride(_ overrideItem: TrackOverride) {
        let updated = store.update { state in
            state.trackOverrides[overrideItem.trackId] = overrideItem
        }
        applyPersistedState(updated)
    }

    public func resetTrackOverride(trackId: String) {
        let updated = store.update { state in
            state.trackOverrides.removeValue(forKey: trackId)
        }
        applyPersistedState(updated)
    }

    public func recordRecent(_ trackId: String) {
        let updated = store.update { state in
            state.recents = PlaybackQueueOps.pushRecent(current: state.recents, trackId: trackId)
        }
        applyPersistedState(updated)
    }

    public func recordPlay(trackId: String, durationListenedMs: Int64) {
        let entry = PlayHistoryEntry(
            id: UUID().uuidString,
            trackId: trackId,
            playedAt: Int64(Date().timeIntervalSince1970 * 1000),
            durationListenedMs: durationListenedMs
        )
        let updated = store.update { state in
            state.recents = PlaybackQueueOps.pushRecent(current: state.recents, trackId: trackId)
            state.playHistory.insert(entry, at: 0)
        }
        applyPersistedState(updated)
    }

    public func recordListeningSession(soundId: String, startedAt: Int64, endedAt: Int64) {
        let elapsedSeconds = max(0, (endedAt - startedAt) / 1000)
        guard elapsedSeconds > 0 else { return }
        let session = ListeningSession(
            id: UUID().uuidString,
            soundId: soundId,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: elapsedSeconds
        )
        let updated = store.update { state in
            state.listeningSessions.insert(session, at: 0)
        }
        applyPersistedState(updated)
    }

    public func clearRecentsAndHistory() {
        let updated = store.update { state in
            state.recents = []
            state.playHistory = []
            state.listeningSessions = []
        }
        applyPersistedState(updated)
    }

    public func addRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let updated = store.update { state in
            state.recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
            state.recentSearches.insert(trimmed, at: 0)
            state.recentSearches = Array(state.recentSearches.prefix(12))
        }
        applyPersistedState(updated)
    }

    public func clearRecentSearches() {
        let updated = store.update { $0.recentSearches = [] }
        applyPersistedState(updated)
    }

    public func lyricsOffset(for trackId: String) -> Double {
        lyricsOffsets[trackId] ?? 0.0
    }

    public func setLyricsOffset(for trackId: String, seconds: Double) {
        let clamped = min(5.0, max(-5.0, (seconds * 10).rounded() / 10.0))
        let updated = store.update { state in
            if abs(clamped) < 0.05 {
                state.lyricsOffsets.removeValue(forKey: trackId)
            } else {
                state.lyricsOffsets[trackId] = clamped
            }
        }
        applyPersistedState(updated)
    }

    public func updatePreferences(_ transform: (inout SnoozyPreferences) -> Void) {
        let updated = store.update { state in
            transform(&state.preferences)
        }
        applyPersistedState(updated)
    }

    public func logError(category: String, message: String, trackId: String? = nil) {
        let entry = ErrorLogEntry(
            id: UUID().uuidString,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000),
            category: category,
            message: message,
            trackId: trackId
        )
        let updated = store.update { state in
            state.errorLog.insert(entry, at: 0)
            state.errorLog = Array(state.errorLog.prefix(100))
        }
        applyPersistedState(updated)
    }

    public func clearErrorLog() {
        let updated = store.update { $0.errorLog = [] }
        applyPersistedState(updated)
    }

    private func applyPersistedState(_ state: PersistedAppState) {
        self.rawTracks = state.scannedTracks
        self.trackOverrides = state.trackOverrides
        self.albumOverrides = state.albumOverrides
        self.artistOverrides = state.artistOverrides
        self.playlists = state.playlists
        self.recents = state.recents
        self.favoriteTrackIds = Set(state.favoriteTrackIds)
        self.playHistory = state.playHistory
        self.listeningSessions = state.listeningSessions
        self.errorLog = state.errorLog
        self.recentSearches = state.recentSearches
        self.lyricsOffsets = state.lyricsOffsets
        self.songSort = state.songSort
        self.albumSort = state.albumSort
        self.preferences = state.preferences

        var resolvedTracks = state.scannedTracks.map { raw -> Track in
            guard let ov = state.trackOverrides[raw.id] else { return raw }
            var copy = raw
            if let t = ov.title, !t.isEmpty { copy.title = t }
            if let ar = ov.artist, !ar.isEmpty { copy.artist = ar }
            if let al = ov.album, !al.isEmpty { copy.album = al }
            if let aa = ov.albumArtist, !aa.isEmpty { copy.albumArtist = aa }
            if let comp = ov.composer, !comp.isEmpty { copy.composer = comp }
            if let g = ov.genre, !g.isEmpty { copy.genre = g }
            if let y = ov.year, !y.isEmpty { copy.year = y }
            if let tn = ov.trackNumber { copy.trackNumber = tn }
            if let dn = ov.discNumber { copy.discNumber = dn }
            if let desc = ov.descriptionText { copy.descriptionText = desc }
            if let art = ov.artworkPath, !art.isEmpty { copy.artworkPath = art }
            return copy
        }
        resolvedTracks = AudioScanner.propagateSharedFolderArtworkAndCompilations(resolvedTracks)
        self.tracks = resolvedTracks
        let byId = Dictionary(uniqueKeysWithValues: resolvedTracks.map { ($0.id, $0) })
        self.tracksById = byId

        let builtAlbums = Self.buildAlbums(from: resolvedTracks, overrides: state.albumOverrides)
        self.albums = builtAlbums
        self.sortedSongs = Self.sortTracks(resolvedTracks, by: state.songSort)
        self.sortedAlbums = Self.sortAlbums(builtAlbums, by: state.albumSort)

        let artistsSet = Set(resolvedTracks.map { $0.artist.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        self.artistNames = artistsSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        let genresSet = Set(resolvedTracks.compactMap { $0.genre?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        self.genreNames = genresSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        let foldersSet = Set(resolvedTracks.map(\.folderName))
        self.folderNames = foldersSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        let favSet = Set(state.favoriteTrackIds)
        self.favoriteTracks = self.sortedSongs.filter { favSet.contains($0.id) }

        let resolvedRecents = Array(state.recents.compactMap { byId[$0] }.prefix(12))
        self.recentTracks = resolvedRecents

        let albumsByKey = Dictionary(uniqueKeysWithValues: builtAlbums.map { ($0.id, $0) })
        var seenAlbumKeys = Set<String>()
        var recentAlb: [Album] = []
        for track in resolvedRecents {
            let key = track.albumKey
            if !seenAlbumKeys.contains(key), let album = albumsByKey[key] {
                seenAlbumKeys.insert(key)
                recentAlb.append(album)
            }
        }
        self.recentlyPlayedAlbums = Array(recentAlb.prefix(10))
        self.recentlyAddedAlbums = Array(builtAlbums.sorted { $0.addedAt > $1.addedAt }.prefix(12))

        var counts: [String: Int] = [:]
        for entry in state.playHistory {
            counts[entry.trackId, default: 0] += 1
        }
        self.mostPlayedTracks = counts
            .compactMap { id, count -> PlayedTrackSummary? in
                guard let track = byId[id], count > 0 else { return nil }
                return PlayedTrackSummary(track: track, plays: count)
            }
            .sorted { $0.plays > $1.plays }
            .prefix(10)
            .map { $0 }
    }

    public static func buildAlbums(
        from tracks: [Track],
        overrides: [String: AlbumOverride]
    ) -> [Album] {
        let grouped = Dictionary(grouping: tracks, by: \.albumKey)
        var built: [Album] = []
        for (key, group) in grouped {
            let sortedGroup = group.sorted { a, b in
                let discA = a.discNumber ?? 1
                let discB = b.discNumber ?? 1
                if discA != discB { return discA < discB }
                switch (a.trackNumber, b.trackNumber) {
                case let (ta?, tb?) where ta != tb: return ta < tb
                case (_?, nil): return true
                case (nil, _?): return false
                default: return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
                }
            }
            guard let first = sortedGroup.first else { continue }
            let ov = overrides[key]
            let title = ov?.title?.isEmpty == false ? ov!.title! : first.album
            let artist = ov?.artist?.isEmpty == false
                ? ov!.artist!
                : (first.albumArtist?.isEmpty == false ? first.albumArtist! : first.artist)
            let artwork = ov?.artworkPath ?? sortedGroup.compactMap(\.artworkPath).first
            let year = sortedGroup.compactMap(\.year).first
            let totalDuration = sortedGroup.reduce(0.0) { $0 + $1.duration }
            let addedAt = sortedGroup.map(\.addedAt).max() ?? 0
            built.append(
                Album(
                    id: key,
                    title: title,
                    artist: artist,
                    year: year,
                    descriptionText: ov?.descriptionText,
                    artworkPath: artwork,
                    trackIds: sortedGroup.map(\.id),
                    duration: totalDuration,
                    addedAt: addedAt
                )
            )
        }
        return built.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private static func generateStereoChordWav(
        durationSeconds: Double,
        frequencies: [Double] = [220.0, 277.18, 329.63, 415.30, 493.88]
    ) -> Data? {
        let sampleRate = 44_100
        let totalSamples = Int(durationSeconds * Double(sampleRate))
        let numChannels: UInt16 = 2
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate * Int(numChannels) * Int(bitsPerSample / 8))
        let blockAlign: UInt16 = numChannels * (bitsPerSample / 8)
        let dataSize = UInt32(totalSamples * Int(blockAlign))

        var data = Data(capacity: 44 + Int(dataSize))
        data.append("RIFF".data(using: .ascii)!)
        var chunkSize = UInt32(36 + dataSize).littleEndian
        data.append(Data(bytes: &chunkSize, count: 4))
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        var subchunk1Size = UInt32(16).littleEndian
        data.append(Data(bytes: &subchunk1Size, count: 4))
        var audioFormat = UInt16(1).littleEndian
        data.append(Data(bytes: &audioFormat, count: 2))
        var channelsLE = numChannels.littleEndian
        data.append(Data(bytes: &channelsLE, count: 2))
        var sampleRateLE = UInt32(sampleRate).littleEndian
        data.append(Data(bytes: &sampleRateLE, count: 4))
        var byteRateLE = byteRate.littleEndian
        data.append(Data(bytes: &byteRateLE, count: 4))
        var blockAlignLE = blockAlign.littleEndian
        data.append(Data(bytes: &blockAlignLE, count: 2))
        var bitsLE = bitsPerSample.littleEndian
        data.append(Data(bytes: &bitsLE, count: 2))
        data.append("data".data(using: .ascii)!)
        var dataSizeLE = dataSize.littleEndian
        data.append(Data(bytes: &dataSizeLE, count: 4))

        let freqs = frequencies.isEmpty ? [220.0, 277.18, 329.63, 415.30, 493.88] : frequencies
        var pcm = [Int16](repeating: 0, count: totalSamples * 2)
        for i in 0..<totalSamples {
            let t = Double(i) / Double(sampleRate)
            let fadeIn = min(1.0, t / 1.2)
            let fadeOut = min(1.0, max(0.0, (durationSeconds - t) / 1.8))
            let env = fadeIn * fadeOut * 0.16
            let lfo = 0.85 + 0.15 * sin(2.0 * .pi * 0.25 * t)

            var left = 0.0
            var right = 0.0
            for (idx, f) in freqs.enumerated() {
                let detune = Double(idx - 2) * 0.35
                left += sin(2.0 * .pi * (f - detune) * t)
                right += sin(2.0 * .pi * (f + detune) * t + 0.4)
            }
            let sampleL = Int16(clamping: Int(left * env * lfo * Double(Int16.max)))
            let sampleR = Int16(clamping: Int(right * env * lfo * Double(Int16.max)))
            pcm[i * 2] = sampleL.littleEndian
            pcm[i * 2 + 1] = sampleR.littleEndian
        }
        pcm.withUnsafeBytePointer { ptr in
            data.append(ptr)
        }
        return data
    }

    private static func renderShowcaseCoverPNG(
        title: String,
        subtitle: String,
        topColor: UIColor,
        bottomColor: UIColor,
        accentColor: UIColor
    ) -> Data? {
        let size = CGSize(width: 512, height: 512)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)
            let colorSpace = CGColorSpaceCreateDeviceRGB()

            if let bgGrad = CGGradient(
                colorsSpace: colorSpace,
                colors: [topColor.cgColor, bottomColor.cgColor] as CFArray,
                locations: [0.0, 1.0]
            ) {
                cg.drawLinearGradient(
                    bgGrad,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            }

            if let orbGrad = CGGradient(
                colorsSpace: colorSpace,
                colors: [accentColor.withAlphaComponent(0.45).cgColor, accentColor.withAlphaComponent(0.0).cgColor] as CFArray,
                locations: [0.0, 1.0]
            ) {
                cg.drawRadialGradient(
                    orbGrad,
                    startCenter: CGPoint(x: size.width * 0.72, y: size.height * 0.28),
                    startRadius: 10,
                    endCenter: CGPoint(x: size.width * 0.72, y: size.height * 0.28),
                    endRadius: size.width * 0.62,
                    options: []
                )
            }

            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.14).cgColor)
            cg.setLineWidth(1.5)
            cg.strokeEllipse(in: CGRect(x: 76, y: 54, width: 360, height: 360))
            cg.strokeEllipse(in: CGRect(x: 116, y: 94, width: 280, height: 280))

            if let brand = SnoozyBrandAssetLoader.loadBrandLogoImage() {
                let logoRect = CGRect(x: 156, y: 110, width: 200, height: 200)
                let clipPath = UIBezierPath(roundedRect: logoRect, cornerRadius: 46)
                cg.saveGState()
                clipPath.addClip()
                brand.draw(in: logoRect)
                cg.restoreGState()
            }

            let titleFont = UIFont(name: "BricolageGrotesque-SemiBold", size: 30) ?? UIFont.systemFont(ofSize: 30, weight: .bold)
            let subFont = UIFont(name: "AtkinsonHyperlegible-Bold", size: 17) ?? UIFont.systemFont(ofSize: 17, weight: .semibold)

            let titleStyle = NSMutableParagraphStyle()
            titleStyle.alignment = .left

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: titleStyle
            ]
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: subFont,
                .foregroundColor: accentColor,
                .paragraphStyle: titleStyle
            ]

            (subtitle.uppercased() as NSString).draw(in: CGRect(x: 36, y: 392, width: rect.width - 72, height: 26), withAttributes: subAttrs)
            (title as NSString).draw(in: CGRect(x: 36, y: 420, width: rect.width - 72, height: 48), withAttributes: titleAttrs)
        }
        return image.pngData()
    }
}

private extension Array where Element == Int16 {
    func withUnsafeBytePointer(_ body: (UnsafeBufferPointer<UInt8>) -> Void) {
        self.withUnsafeBytes { rawBuffer in
            if let base = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) {
                body(UnsafeBufferPointer(start: base, count: rawBuffer.count))
            }
        }
    }
}
