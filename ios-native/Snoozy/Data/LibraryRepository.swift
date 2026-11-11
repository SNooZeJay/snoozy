import Foundation
import SwiftUI

@MainActor
public final class LibraryRepository: ObservableObject {
    public let store: SnoozyStore

    @Published public private(set) var rawTracks: [Track] = []
    @Published public private(set) var tracks: [Track] = []
    @Published public private(set) var albums: [Album] = []
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
    }

    public func fileURL(for track: Track) -> URL {
        store.documentsURL.appendingPathComponent(track.relativePath)
    }

    public func scanLibrary() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        let existingByPath = Dictionary(uniqueKeysWithValues: rawTracks.map { ($0.relativePath, $0) })
        let scanned = await AudioScanner.scanDirectory(
            documentsURL: store.documentsURL,
            artworkCacheURL: store.artworkCacheURL,
            existingTracksByPath: existingByPath
        )

        let updated = store.update { state in
            state.scannedTracks = scanned
        }
        applyPersistedState(updated)
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

    public func createSampleSynthTrack() async {
        let sampleURL = store.documentsURL.appendingPathComponent("Snoozy Liquid Glass Demo.wav")
        if !FileManager.default.fileExists(atPath: sampleURL.path) {
            if let data = Self.generateStereoChordWav(durationSeconds: 18.0) {
                try? data.write(to: sampleURL, options: .atomic)
            }
            let lrcURL = store.documentsURL.appendingPathComponent("Snoozy Liquid Glass Demo.lrc")
            let sampleLrc = """
            [ti:Snoozy Liquid Glass Demo]
            [ar:Snoozy Synth Engine]
            [00:00.20]Welcome to Snoozy on iPhone 13 mini
            [00:04.00]Real-time iOS 27 Liquid Glass refraction
            [00:08.50]Drop your FLAC, MP3, WAV, or M4A files in the Files app
            [00:13.00]Pure offline playback with zero subscriptions
            """
            try? sampleLrc.data(using: .utf8)?.write(to: lrcURL, options: .atomic)
        }
        await scanLibrary()
    }

    public var sortedSongs: [Track] {
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

    public var sortedAlbums: [Album] {
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

    public var artistNames: [String] {
        let names = Set(tracks.map { $0.artist.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    public var genreNames: [String] {
        let names = Set(tracks.compactMap { $0.genre?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    public var folderNames: [String] {
        let names = Set(tracks.map(\.folderName))
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    public var favoriteTracks: [Track] {
        tracks.filter { favoriteTrackIds.contains($0.id) }
    }

    public var recentTracks: [Track] {
        let byId = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        return Array(recents.compactMap { byId[$0] }.prefix(12))
    }

    public var recentlyPlayedAlbums: [Album] {
        let albumsByKey = Dictionary(uniqueKeysWithValues: albums.map { ($0.id, $0) })
        var seen = Set<String>()
        var result: [Album] = []
        for track in recentTracks {
            let key = track.albumKey
            if !seen.contains(key), let album = albumsByKey[key] {
                seen.insert(key)
                result.append(album)
            }
        }
        return Array(result.prefix(10))
    }

    public var recentlyAddedAlbums: [Album] {
        Array(albums.sorted { $0.addedAt > $1.addedAt }.prefix(12))
    }

    public var mostPlayedTracks: [PlayedTrackSummary] {
        let byId = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        var counts: [String: Int] = [:]
        for entry in playHistory {
            counts[entry.trackId, default: 0] += 1
        }
        return counts
            .compactMap { id, count -> PlayedTrackSummary? in
                guard let track = byId[id], count > 0 else { return nil }
                return PlayedTrackSummary(track: track, plays: count)
            }
            .sorted { $0.plays > $1.plays }
            .prefix(10)
            .map { $0 }
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

        let resolvedTracks = state.scannedTracks.map { raw -> Track in
            guard let ov = state.trackOverrides[raw.id] else { return raw }
            var copy = raw
            if let t = ov.title, !t.isEmpty { copy.title = t }
            if let ar = ov.artist, !ar.isEmpty { copy.artist = ar }
            if let al = ov.album, !al.isEmpty { copy.album = al }
            if let aa = ov.albumArtist, !aa.isEmpty { copy.albumArtist = aa }
            if let g = ov.genre, !g.isEmpty { copy.genre = g }
            if let y = ov.year, !y.isEmpty { copy.year = y }
            if let tn = ov.trackNumber { copy.trackNumber = tn }
            if let desc = ov.descriptionText { copy.descriptionText = desc }
            if let art = ov.artworkPath, !art.isEmpty { copy.artworkPath = art }
            return copy
        }
        self.tracks = resolvedTracks
        self.albums = Self.buildAlbums(from: resolvedTracks, overrides: state.albumOverrides)
    }

    private static func buildAlbums(
        from tracks: [Track],
        overrides: [String: AlbumOverride]
    ) -> [Album] {
        let grouped = Dictionary(grouping: tracks, by: \.albumKey)
        var built: [Album] = []
        for (key, group) in grouped {
            let sortedGroup = group.sorted { a, b in
                switch (a.trackNumber, b.trackNumber) {
                case let (ta?, tb?) where ta != tb: return ta < tb
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

    private static func generateStereoChordWav(durationSeconds: Double) -> Data? {
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

        // Warm emerald ambient pad (Fmaj9 / Em7 progression)
        let freqs = [220.0, 277.18, 329.63, 415.30, 493.88]
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
