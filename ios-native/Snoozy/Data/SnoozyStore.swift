import Foundation

public struct PersistedAppState: Codable, Sendable {
    public var scannedTracks: [Track]
    public var playlists: [Playlist]
    public var recents: [String]
    public var favoriteTrackIds: [String]
    public var trackOverrides: [String: TrackOverride]
    public var albumOverrides: [String: AlbumOverride]
    public var artistOverrides: [String: ArtistOverride]
    public var playHistory: [PlayHistoryEntry]
    public var listeningSessions: [ListeningSession]
    public var errorLog: [ErrorLogEntry]
    public var recentSearches: [String]
    public var lyricsOffsets: [String: Double]
    public var songSort: SongSort
    public var albumSort: AlbumSort
    public var preferences: SnoozyPreferences
    public var playbackSession: PlaybackSession?

    public init(
        scannedTracks: [Track] = [],
        playlists: [Playlist] = [],
        recents: [String] = [],
        favoriteTrackIds: [String] = [],
        trackOverrides: [String: TrackOverride] = [:],
        albumOverrides: [String: AlbumOverride] = [:],
        artistOverrides: [String: ArtistOverride] = [:],
        playHistory: [PlayHistoryEntry] = [],
        listeningSessions: [ListeningSession] = [],
        errorLog: [ErrorLogEntry] = [],
        recentSearches: [String] = [],
        lyricsOffsets: [String: Double] = [:],
        songSort: SongSort = .title,
        albumSort: AlbumSort = .title,
        preferences: SnoozyPreferences = SnoozyPreferences(),
        playbackSession: PlaybackSession? = nil
    ) {
        self.scannedTracks = scannedTracks
        self.playlists = playlists
        self.recents = recents
        self.favoriteTrackIds = favoriteTrackIds
        self.trackOverrides = trackOverrides
        self.albumOverrides = albumOverrides
        self.artistOverrides = artistOverrides
        self.playHistory = playHistory
        self.listeningSessions = listeningSessions
        self.errorLog = errorLog
        self.recentSearches = recentSearches
        self.lyricsOffsets = lyricsOffsets
        self.songSort = songSort
        self.albumSort = albumSort
        self.preferences = preferences
        self.playbackSession = playbackSession
    }
}

public final class SnoozyStore: @unchecked Sendable {
    private let lock = NSLock()
    private let storeURL: URL
    public let documentsURL: URL
    public let artworkCacheURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let snoozySupport = appSupport.appendingPathComponent("Snoozy", isDirectory: true)
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let artCache = snoozySupport.appendingPathComponent("ArtworkCache", isDirectory: true)

        try? fileManager.createDirectory(at: snoozySupport, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: artCache, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: docs, withIntermediateDirectories: true)

        let readmeURL = docs.appendingPathComponent("Drop Music Files Here.txt")
        if !fileManager.fileExists(atPath: readmeURL.path) {
            let guide = """
            Snoozy Offline Music Folder (iPhone 13 mini)
            --------------------------------------------
            Drop your MP3, FLAC, WAV, M4A, ALAC, AAC, AIFF, or OGG files (and .lrc lyrics files)
            directly into this 'Snoozy' folder in the iPhone Files app, or into any subfolder here.
            Then tap 'Scan' inside Snoozy to index them immediately.
            """
            try? guide.data(using: .utf8)?.write(to: readmeURL, options: .atomic)
        }

        self.storeURL = snoozySupport.appendingPathComponent("snoozy-state-v1.json")
        self.documentsURL = docs
        self.artworkCacheURL = artCache

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = enc
        self.decoder = JSONDecoder()
    }

    public func load() -> PersistedAppState {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? decoder.decode(PersistedAppState.self, from: data)
        else {
            return PersistedAppState()
        }
        return decoded
    }

    public func save(_ state: PersistedAppState) {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    public func update(_ transform: (inout PersistedAppState) -> Void) -> PersistedAppState {
        lock.lock()
        defer { lock.unlock() }
        var current: PersistedAppState
        if let data = try? Data(contentsOf: storeURL),
           let decoded = try? decoder.decode(PersistedAppState.self, from: data) {
            current = decoded
        } else {
            current = PersistedAppState()
        }
        transform(&current)
        if let data = try? encoder.encode(current) {
            try? data.write(to: storeURL, options: .atomic)
        }
        return current
    }
}
