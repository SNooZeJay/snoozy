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
    private let fileManager: FileManager
    private let storeURL: URL
    public let documentsURL: URL
    public let artworkCacheURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var cachedState = PersistedAppState()
    private var writesBlocked = false
    public private(set) var recoveryNotice: String?

    public convenience init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let snoozySupport = appSupport.appendingPathComponent("Snoozy", isDirectory: true)
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.init(
            fileManager: fileManager,
            supportDirectory: snoozySupport,
            documentsDirectory: docs
        )
    }

    init(
        fileManager: FileManager = .default,
        supportDirectory: URL,
        documentsDirectory: URL
    ) {
        self.fileManager = fileManager

        let artCache = supportDirectory.appendingPathComponent("ArtworkCache", isDirectory: true)

        try? fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: artCache, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)

        let readmeURL = documentsDirectory.appendingPathComponent("Drop Music Files Here.txt")
        if !fileManager.fileExists(atPath: readmeURL.path) {
            let guide = """
            Snoozy Offline Music Folder (iPhone 13 mini)
            --------------------------------------------
            Drop your MP3, FLAC, WAV, M4A, or ALAC files (and .lrc lyrics files)
            directly into this 'Snoozy' folder in the iPhone Files app, or into any subfolder here.
            Then tap 'Scan' inside Snoozy to index them immediately.
            """
            try? guide.data(using: .utf8)?.write(to: readmeURL, options: .atomic)
        }

        self.storeURL = supportDirectory.appendingPathComponent("snoozy-state-v1.json")
        self.documentsURL = documentsDirectory
        self.artworkCacheURL = artCache

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = enc
        self.decoder = JSONDecoder()
    }

    public func load() -> PersistedAppState {
        lock.lock()
        defer { lock.unlock() }
        let state = loadLocked()
        cachedState = state
        return state
    }

    public func save(_ state: PersistedAppState) {
        lock.lock()
        defer { lock.unlock() }
        guard !writesBlocked else { return }
        guard let data = try? encoder.encode(state) else { return }
        do {
            try data.write(to: storeURL, options: .atomic)
            cachedState = state
        } catch {
            recoveryNotice = "Snoozy could not save changes. Your last saved library is unchanged."
        }
    }

    public func update(_ transform: (inout PersistedAppState) -> Void) -> PersistedAppState {
        lock.lock()
        defer { lock.unlock() }

        var current = loadLocked()
        guard !writesBlocked else { return current }

        transform(&current)
        guard let data = try? encoder.encode(current) else { return current }
        do {
            try data.write(to: storeURL, options: .atomic)
            cachedState = current
        } catch {
            recoveryNotice = "Snoozy could not save changes. Your last saved library is unchanged."
        }
        return current
    }

    private func loadLocked() -> PersistedAppState {
        guard fileManager.fileExists(atPath: storeURL.path) else {
            return PersistedAppState()
        }

        do {
            let data = try Data(contentsOf: storeURL)
            return try decoder.decode(PersistedAppState.self, from: data)
        } catch is DecodingError {
            quarantineCorruptStore()
            return PersistedAppState()
        } catch {
            writesBlocked = true
            recoveryNotice = "Snoozy could not open your saved library. To protect your data, changes are disabled for this session."
            return cachedState
        }
    }

    private func quarantineCorruptStore() {
        let stamp = Int(Date().timeIntervalSince1970)
        var backupURL = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("snoozy-state-v1.corrupt-\(stamp).json")
        var suffix = 1
        while fileManager.fileExists(atPath: backupURL.path) {
            backupURL = storeURL
                .deletingLastPathComponent()
                .appendingPathComponent("snoozy-state-v1.corrupt-\(stamp)-\(suffix).json")
            suffix += 1
        }

        do {
            try fileManager.moveItem(at: storeURL, to: backupURL)
            recoveryNotice = "Snoozy could not read your saved library. The damaged file was preserved and a fresh library was started."
        } catch {
            writesBlocked = true
            recoveryNotice = "Snoozy could not read or preserve your saved library. To protect your data, changes are disabled for this session."
        }
    }
}
