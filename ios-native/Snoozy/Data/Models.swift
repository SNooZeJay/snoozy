import Foundation

public struct Track: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var artist: String
    public var album: String
    public var albumArtist: String?
    public var composer: String?
    public var genre: String?
    public var year: String?
    public var trackNumber: Int?
    public var discNumber: Int?
    public var descriptionText: String?
    public var duration: Double
    public var relativePath: String
    public var artworkPath: String?
    public var addedAt: Int64

    public init(
        id: String,
        title: String,
        artist: String,
        album: String,
        albumArtist: String? = nil,
        composer: String? = nil,
        genre: String? = nil,
        year: String? = nil,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        descriptionText: String? = nil,
        duration: Double,
        relativePath: String,
        artworkPath: String? = nil,
        addedAt: Int64
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.composer = composer
        self.genre = genre
        self.year = year
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.descriptionText = descriptionText
        self.duration = duration
        self.relativePath = relativePath
        self.artworkPath = artworkPath
        self.addedAt = addedAt
    }

    public var albumKey: String {
        let normalizedTitle = album.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let effectiveArtist = (albumArtist?.isEmpty == false ? albumArtist! : artist)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return "\(normalizedTitle.isEmpty ? "unknown album" : normalizedTitle)::\(effectiveArtist.isEmpty ? "unknown artist" : effectiveArtist)"
    }

    public var folderName: String {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        let parts = normalized.split(separator: "/").map(String.init)
        guard parts.count > 1 else { return "Snoozy Root" }
        return parts.dropLast().joined(separator: "/")
    }

    public var audioFormatBadge: String {
        let ext = (relativePath as NSString).pathExtension.uppercased()
        return ext.isEmpty ? "AUDIO" : ext
    }

    public var isLosslessFormat: Bool {
        switch audioFormatBadge {
        case "FLAC", "WAV", "ALAC", "AIFF", "AIF", "CAF":
            return true
        default:
            return false
        }
    }
}

public struct Album: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var artist: String
    public var year: String?
    public var descriptionText: String?
    public var artworkPath: String?
    public var trackIds: [String]
    public var duration: Double
    public var addedAt: Int64

    public init(
        id: String,
        title: String,
        artist: String,
        year: String? = nil,
        descriptionText: String? = nil,
        artworkPath: String? = nil,
        trackIds: [String],
        duration: Double,
        addedAt: Int64
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.year = year
        self.descriptionText = descriptionText
        self.artworkPath = artworkPath
        self.trackIds = trackIds
        self.duration = duration
        self.addedAt = addedAt
    }
}

public struct Playlist: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var trackIds: [String]
    public var createdAt: Int64

    public init(id: String, name: String, trackIds: [String], createdAt: Int64) {
        self.id = id
        self.name = name
        self.trackIds = trackIds
        self.createdAt = createdAt
    }
}

public struct TrackOverride: Codable, Equatable, Sendable {
    public let trackId: String
    public var title: String?
    public var artist: String?
    public var album: String?
    public var albumArtist: String?
    public var composer: String?
    public var genre: String?
    public var year: String?
    public var trackNumber: Int?
    public var discNumber: Int?
    public var descriptionText: String?
    public var artworkPath: String?
    public var updatedAt: Int64

    public init(
        trackId: String,
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        albumArtist: String? = nil,
        composer: String? = nil,
        genre: String? = nil,
        year: String? = nil,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        descriptionText: String? = nil,
        artworkPath: String? = nil,
        updatedAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.trackId = trackId
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.composer = composer
        self.genre = genre
        self.year = year
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.descriptionText = descriptionText
        self.artworkPath = artworkPath
        self.updatedAt = updatedAt
    }
}

public struct AlbumOverride: Codable, Equatable, Sendable {
    public let albumKey: String
    public var title: String?
    public var artist: String?
    public var descriptionText: String?
    public var artworkPath: String?
    public var updatedAt: Int64
}

public struct ArtistOverride: Codable, Equatable, Sendable {
    public let artistKey: String
    public var name: String?
    public var descriptionText: String?
    public var artworkPath: String?
    public var updatedAt: Int64
}

public struct PlayHistoryEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let trackId: String
    public let playedAt: Int64
    public let durationListenedMs: Int64
}

public struct ListeningSession: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let soundId: String
    public let startedAt: Int64
    public var endedAt: Int64?
    public var durationSeconds: Int64
}

public struct ErrorLogEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let timestamp: Int64
    public let category: String
    public let message: String
    public let trackId: String?
}

public enum RepeatState: String, Codable, CaseIterable, Sendable {
    case off
    case all
    case one

    public func next() -> RepeatState {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }

    public var label: String {
        switch self {
        case .off: return "Repeat off"
        case .all: return "Repeat all"
        case .one: return "Repeat one"
        }
    }
}

public enum SongSort: String, Codable, CaseIterable, Sendable {
    case title
    case artist
    case recentlyAdded
    case duration

    public var label: String {
        switch self {
        case .title: return "Title"
        case .artist: return "Artist"
        case .recentlyAdded: return "Recently added"
        case .duration: return "Duration"
        }
    }
}

public enum AlbumSort: String, Codable, CaseIterable, Sendable {
    case title
    case artist
    case year
    case recentlyAdded

    public var label: String {
        switch self {
        case .title: return "Title"
        case .artist: return "Artist"
        case .year: return "Year"
        case .recentlyAdded: return "Recently added"
        }
    }
}

public enum LibraryTab: String, CaseIterable, Identifiable, Sendable {
    case overview = "Overview"
    case playlists = "Playlists"
    case artists = "Artists"
    case albums = "Albums"
    case songs = "Songs"
    case folders = "Folders"
    case genres = "Genres"
    case favorites = "Favorites"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .playlists: return "music.note.list"
        case .artists: return "music.mic"
        case .albums: return "square.stack.fill"
        case .songs: return "music.note"
        case .folders: return "folder.fill"
        case .genres: return "guitars.fill"
        case .favorites: return "star.fill"
        }
    }

    public static var appleMusicCategories: [LibraryTab] {
        [.playlists, .artists, .albums, .songs, .folders, .genres, .favorites]
    }
}

public enum ThemeMode: String, Codable, CaseIterable, Sendable {
    case system
    case dark
    case light

    public var label: String {
        switch self {
        case .system: return "System"
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }
}

public enum PaletteSeed: String, Codable, CaseIterable, Sendable {
    case emerald
    case dynamicArtwork
    case cyan
    case violet
    case rose
    case amber

    public var label: String {
        switch self {
        case .emerald: return "Emerald (#10B981)"
        case .dynamicArtwork: return "Dynamic Artwork"
        case .cyan: return "Liquid Cyan"
        case .violet: return "Ultraviolet"
        case .rose: return "Neon Rose"
        case .amber: return "Warm Amber"
        }
    }
}

public enum GlassMode: String, Codable, CaseIterable, Sendable {
    case liquidGlass
    case frosted
    case reduceTransparency

    public var label: String {
        switch self {
        case .liquidGlass: return "iOS 27 Liquid Glass"
        case .frosted: return "Frosted Material"
        case .reduceTransparency: return "Reduce Transparency"
        }
    }
}

public enum MotionMode: String, Codable, CaseIterable, Sendable {
    case full
    case reduced

    public var label: String {
        switch self {
        case .full: return "Full Fluid Motion"
        case .reduced: return "Reduced Motion"
        }
    }
}

public struct SnoozyPreferences: Codable, Equatable, Sendable {
    public var themeMode: ThemeMode
    public var paletteSeed: PaletteSeed
    public var glassMode: GlassMode
    public var refractionIntensity: Double
    public var auraBackdropEnabled: Bool
    public var auraBackdropIntensity: Double
    public var audioReactiveAuraEnabled: Bool
    public var motionMode: MotionMode
    public var hapticsEnabled: Bool

    public init(
        themeMode: ThemeMode = .dark,
        paletteSeed: PaletteSeed = .emerald,
        glassMode: GlassMode = .liquidGlass,
        refractionIntensity: Double = 0.82,
        auraBackdropEnabled: Bool = true,
        auraBackdropIntensity: Double = 0.75,
        audioReactiveAuraEnabled: Bool = true,
        motionMode: MotionMode = .full,
        hapticsEnabled: Bool = true
    ) {
        self.themeMode = themeMode
        self.paletteSeed = paletteSeed
        self.glassMode = glassMode
        self.refractionIntensity = refractionIntensity
        self.auraBackdropEnabled = auraBackdropEnabled
        self.auraBackdropIntensity = auraBackdropIntensity
        self.audioReactiveAuraEnabled = audioReactiveAuraEnabled
        self.motionMode = motionMode
        self.hapticsEnabled = hapticsEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case themeMode
        case paletteSeed
        case glassMode
        case refractionIntensity
        case auraBackdropEnabled
        case auraBackdropIntensity
        case audioReactiveAuraEnabled
        case motionMode
        case hapticsEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.themeMode = try container.decodeIfPresent(ThemeMode.self, forKey: .themeMode) ?? .dark
        self.paletteSeed = try container.decodeIfPresent(PaletteSeed.self, forKey: .paletteSeed) ?? .emerald
        self.glassMode = try container.decodeIfPresent(GlassMode.self, forKey: .glassMode) ?? .liquidGlass
        self.refractionIntensity = try container.decodeIfPresent(Double.self, forKey: .refractionIntensity) ?? 0.82
        self.auraBackdropEnabled = try container.decodeIfPresent(Bool.self, forKey: .auraBackdropEnabled) ?? true
        self.auraBackdropIntensity = try container.decodeIfPresent(Double.self, forKey: .auraBackdropIntensity) ?? 0.75
        self.audioReactiveAuraEnabled = try container.decodeIfPresent(Bool.self, forKey: .audioReactiveAuraEnabled) ?? true
        self.motionMode = try container.decodeIfPresent(MotionMode.self, forKey: .motionMode) ?? .full
        self.hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
    }
}

public struct AudioReactiveLevels: Equatable, Sendable {
    public var bass: Double
    public var mid: Double
    public var high: Double
    public var overall: Double

    public static let zero = AudioReactiveLevels(bass: 0.0, mid: 0.0, high: 0.0, overall: 0.0)

    public init(bass: Double = 0.0, mid: Double = 0.0, high: Double = 0.0, overall: Double = 0.0) {
        self.bass = min(1.0, max(0.0, bass))
        self.mid = min(1.0, max(0.0, mid))
        self.high = min(1.0, max(0.0, high))
        self.overall = min(1.0, max(0.0, overall))
    }
}

public enum AudioReactiveAnalyzer {
    /// Converts decibel meter readings (-60 dBFS ... 0 dBFS) and previous envelope state into
    /// smoothed real-time Bass, Mid, High, and Overall visual energy levels (0.0 ... 1.0).
    public static func computeLevels(
        averagePowerLeftDb: Float,
        averagePowerRightDb: Float,
        peakPowerLeftDb: Float,
        peakPowerRightDb: Float,
        previous: AudioReactiveLevels
    ) -> AudioReactiveLevels {
        let avgLeft = normalizeDecibels(averagePowerLeftDb)
        let avgRight = normalizeDecibels(averagePowerRightDb)
        let peakLeft = normalizeDecibels(peakPowerLeftDb)
        let peakRight = normalizeDecibels(peakPowerRightDb)

        let avgMono = (avgLeft + avgRight) * 0.5
        let peakMono = max(peakLeft, peakRight)
        let stereoSpread = abs(avgLeft - avgRight)
        let transientCrest = max(0.0, peakMono - avgMono)

        // Bass responds to deep sustained body energy + low-end punch
        let rawBass = min(1.0, pow(avgMono, 0.85) * 0.82 + peakMono * 0.28)
        // Mid responds to harmonic core energy + stereo width modulation
        let rawMid = min(1.0, avgMono * 0.72 + stereoSpread * 0.65 + transientCrest * 0.25)
        // High responds to crisp transient peaks, crest factor, and stereo shimmer
        let rawHigh = min(1.0, transientCrest * 1.45 + peakMono * 0.35 + stereoSpread * 0.40)
        // Overall represents total perceived loudness
        let rawOverall = min(1.0, avgMono * 0.76 + peakMono * 0.24)

        return AudioReactiveLevels(
            bass: smoothEnvelope(current: previous.bass, target: rawBass, attack: 0.42, release: 0.18),
            mid: smoothEnvelope(current: previous.mid, target: rawMid, attack: 0.36, release: 0.20),
            high: smoothEnvelope(current: previous.high, target: rawHigh, attack: 0.52, release: 0.26),
            overall: smoothEnvelope(current: previous.overall, target: rawOverall, attack: 0.38, release: 0.16)
        )
    }

    public static func decayToZero(from previous: AudioReactiveLevels, factor: Double = 0.72) -> AudioReactiveLevels {
        let clampedFactor = min(0.95, max(0.0, factor))
        let nextBass = previous.bass * clampedFactor
        let nextMid = previous.mid * clampedFactor
        let nextHigh = previous.high * clampedFactor
        let nextOverall = previous.overall * clampedFactor
        if nextOverall < 0.008 && nextBass < 0.008 && nextMid < 0.008 && nextHigh < 0.008 {
            return .zero
        }
        return AudioReactiveLevels(bass: nextBass, mid: nextMid, high: nextHigh, overall: nextOverall)
    }

    public static func normalizeDecibels(_ db: Float) -> Double {
        guard db.isFinite else { return 0.0 }
        let minDb: Float = -54.0
        if db <= minDb { return 0.0 }
        if db >= 0.0 { return 1.0 }
        let linear = Double((db - minDb) / (-minDb))
        return min(1.0, max(0.0, linear * linear))
    }

    private static func smoothEnvelope(current: Double, target: Double, attack: Double, release: Double) -> Double {
        let coeff = target > current ? attack : release
        return min(1.0, max(0.0, current + (target - current) * coeff))
    }
}

public struct LibrarySearchResults: Equatable, Sendable {
    public let songs: [Track]
    public let albums: [Album]
    public let artists: [String]
    public let playlists: [Playlist]
    public let folders: [String]
    public let genres: [String]

    public var isEmpty: Bool {
        songs.isEmpty && albums.isEmpty && artists.isEmpty && playlists.isEmpty && folders.isEmpty && genres.isEmpty
    }

    public var totalCount: Int {
        songs.count + albums.count + artists.count + playlists.count + folders.count + genres.count
    }

    public init(
        songs: [Track] = [],
        albums: [Album] = [],
        artists: [String] = [],
        playlists: [Playlist] = [],
        folders: [String] = [],
        genres: [String] = []
    ) {
        self.songs = songs
        self.albums = albums
        self.artists = artists
        self.playlists = playlists
        self.folders = folders
        self.genres = genres
    }
}

public struct PlaybackSession: Codable, Equatable, Sendable {
    public var version: Int
    public var activeTrackId: String
    public var queueIds: [String]
    public var queueIndex: Int
    public var positionSeconds: Double
    public var shuffle: Bool
    public var repeatMode: RepeatState
    public var playbackRate: Double
    public var updatedAt: Int64

    public init(
        version: Int = 1,
        activeTrackId: String,
        queueIds: [String],
        queueIndex: Int,
        positionSeconds: Double,
        shuffle: Bool,
        repeatMode: RepeatState,
        playbackRate: Double = 1.0,
        updatedAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.version = version
        self.activeTrackId = activeTrackId
        self.queueIds = queueIds
        self.queueIndex = queueIndex
        self.positionSeconds = positionSeconds
        self.shuffle = shuffle
        self.repeatMode = repeatMode
        self.playbackRate = playbackRate
        self.updatedAt = updatedAt
    }
}

public struct QueueEntry: Identifiable, Equatable, Sendable {
    public var id: String { mediaId }
    public let mediaId: String
    public let title: String
    public let artist: String
    public let artworkPath: String?
}

public struct PlayedTrackSummary: Identifiable, Equatable, Sendable {
    public var id: String { track.id }
    public let track: Track
    public let plays: Int
}
