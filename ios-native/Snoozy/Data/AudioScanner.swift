import AVFoundation
import CryptoKit
import Foundation
import UIKit

public struct FilenameMetadataFallback: Equatable, Sendable {
    public var discNumber: Int?
    public var trackNumber: Int?
    public var artist: String?
    public var title: String

    public init(
        discNumber: Int? = nil,
        trackNumber: Int? = nil,
        artist: String? = nil,
        title: String
    ) {
        self.discNumber = discNumber
        self.trackNumber = trackNumber
        self.artist = artist
        self.title = title
    }
}

public struct FolderHierarchyMetadata: Equatable, Sendable {
    public var artist: String?
    public var album: String?
    public var genre: String?

    public init(artist: String? = nil, album: String? = nil, genre: String? = nil) {
        self.artist = artist
        self.album = album
        self.genre = genre
    }
}

public enum AudioScanner {
    /// Audio extensions natively decoded by iOS CoreAudio / AVAudioPlayer / AVURLAsset.
    public static let supportedExtensions: Set<String> = [
        "mp3", "flac", "wav", "m4a", "aac", "alac", "aiff", "aif", "caf", "mp4"
    ]

    public static let artworkImageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "webp", "heic"
    ]

    /// Priority-ordered basenames for automatic folder cover art detection.
    public static let preferredCoverBasenames: [String] = [
        "cover",
        "folder",
        "album",
        "front",
        "albumart",
        "artwork",
        "albumartsmall",
        "thumb",
        "disc"
    ]

    private static let genericContainerFolders: Set<String> = [
        "documents", "imported", "music", "songs", "audio", "library", "downloads", "files", "snoozy"
    ]

    private static let knownGenreFolderNames: Set<String> = [
        "rock", "pop", "jazz", "classical", "hip-hop", "hip hop", "rap", "electronic",
        "ambient", "r&b", "rnb", "indie", "metal", "folk", "soul", "lo-fi", "lofi",
        "chillout", "chill", "soundtrack", "ost", "acoustic", "blues", "country",
        "dance", "house", "techno", "synthwave", "punk", "reggae", "latin", "k-pop"
    ]

    private static let yearRegex = try! NSRegularExpression(pattern: #"\b(19\d{2}|20\d{2})\b"#)
    private static let discTrackPrefixRegex = try! NSRegularExpression(
        pattern: #"^(?:(\d{1,2})[-.])?(\d{1,3})\s*(?:[-._)]|\s+-\s+|\s+)\s*(.+)$"#
    )

    public static func scanDirectory(
        documentsURL: URL,
        artworkCacheURL: URL,
        existingTracksByPath: [String: Track] = [:]
    ) async -> [Track] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: documentsURL,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .creationDateKey,
                .contentModificationDateKey,
                .fileSizeKey
            ],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var audioURLs: [URL] = []
        while let fileURL = enumerator.nextObject() as? URL {
            let ext = fileURL.pathExtension.lowercased()
            if supportedExtensions.contains(ext) {
                audioURLs.append(fileURL)
            }
        }

        // Pre-resolve folder cover artwork once per directory to avoid redundant disk work
        var cachedFolderArtworkByDirPath: [String: String?] = [:]
        var results: [Track] = []

        for fileURL in audioURLs {
            let dirURL = fileURL.deletingLastPathComponent()
            let dirKey = dirURL.standardizedFileURL.path
            let folderArtworkPath: String?
            if let cached = cachedFolderArtworkByDirPath[dirKey] {
                folderArtworkPath = cached
            } else {
                let detected = resolveFolderArtworkPath(
                    in: dirURL,
                    documentsRootURL: documentsURL,
                    artworkCacheURL: artworkCacheURL,
                    fileManager: fm
                )
                cachedFolderArtworkByDirPath[dirKey] = detected
                folderArtworkPath = detected
            }

            let relPath = relativePath(for: fileURL, baseURL: documentsURL)
            if let track = await extractTrack(
                fileURL: fileURL,
                relativePath: relPath,
                artworkCacheURL: artworkCacheURL,
                folderArtworkPath: folderArtworkPath,
                existing: existingTracksByPath[relPath]
            ) {
                results.append(track)
            }
        }

        // Propagate folder/album artwork across tracks that share the same folder and album title
        results = propagateSharedFolderArtworkAndCompilations(results)

        results.sort {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        return results
    }

    /// Intelligently imports external files and folders into `documentsURL`, preserving nested folder structures
    /// (`Artist/Album/01 - Track.mp3`, `Music/Rock/Song.mp3`) and copying folder cover art (`cover.jpg`, `folder.png`, etc.) and `.lrc` sidecars.
    public static func importExternalURLs(
        _ urls: [URL],
        into documentsURL: URL
    ) -> Int {
        let fm = FileManager.default
        try? fm.createDirectory(at: documentsURL, withIntermediateDirectories: true)

        var importedAudioCount = 0
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped { url.stopAccessingSecurityScopedResource() }
            }

            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                let rootFolderName = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
                let preserveRootContainer = !genericContainerFolders.contains(rootFolderName.lowercased())
                let baseTargetDir = preserveRootContainer
                    ? documentsURL.appendingPathComponent(rootFolderName, isDirectory: true)
                    : documentsURL

                try? fm.createDirectory(at: baseTargetDir, withIntermediateDirectories: true)

                if let subEnum = fm.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey],
                    options: [.skipsHiddenFiles]
                ) {
                    while let childURL = subEnum.nextObject() as? URL {
                        var childIsDir: ObjCBool = false
                        guard fm.fileExists(atPath: childURL.path, isDirectory: &childIsDir), !childIsDir.boolValue else {
                            continue
                        }
                        let ext = childURL.pathExtension.lowercased()
                        let isAudio = supportedExtensions.contains(ext)
                        let isLyrics = (ext == "lrc")
                        let isArtwork = artworkImageExtensions.contains(ext)
                        guard isAudio || isLyrics || isArtwork else { continue }

                        let relSubpath = relativePath(for: childURL, baseURL: url)
                        let destURL = baseTargetDir.appendingPathComponent(relSubpath)
                        let destParent = destURL.deletingLastPathComponent()
                        try? fm.createDirectory(at: destParent, withIntermediateDirectories: true)

                        if copyOrUpdateFile(from: childURL, to: destURL, fileManager: fm), isAudio {
                            importedAudioCount += 1
                        }
                    }
                }
            } else {
                let ext = url.pathExtension.lowercased()
                let isAudio = supportedExtensions.contains(ext)
                let isLyrics = (ext == "lrc")
                let isArtwork = artworkImageExtensions.contains(ext)
                guard isAudio || isLyrics || isArtwork else { continue }

                let destURL = documentsURL.appendingPathComponent(url.lastPathComponent)
                if copyOrUpdateFile(from: url, to: destURL, fileManager: fm), isAudio {
                    importedAudioCount += 1
                }
            }
        }
        return importedAudioCount
    }

    /// Detects the best cover image inside `directoryURL` (`cover.jpg`, `cover.png`, `folder.jpg`, `album.jpg`, `front.jpg`, `AlbumArt.jpg`, etc.).
    public static func detectBestFolderArtworkURL(
        in directoryURL: URL,
        documentsRootURL: URL,
        fileManager: FileManager = .default
    ) -> URL? {
        let dirStandard = directoryURL.standardizedFileURL.path
        let rootStandard = documentsRootURL.standardizedFileURL.path
        let isRootDir = (dirStandard == rootStandard)
        let dirNameLower = directoryURL.lastPathComponent.lowercased()

        guard let items = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let imageURLs = items.filter { url in
            let ext = url.pathExtension.lowercased()
            guard artworkImageExtensions.contains(ext) else { return false }
            let attrs = try? fileManager.attributesOfItem(atPath: url.path)
            let size = (attrs?[.size] as? NSNumber)?.intValue ?? 0
            return size > 256
        }
        guard !imageURLs.isEmpty else { return nil }

        // 1. Exact case-insensitive match against preferred cover basenames (cover, folder, album, front, albumart, artwork...)
        for preferred in preferredCoverBasenames {
            if let exactMatch = imageURLs.first(where: {
                $0.deletingPathExtension().lastPathComponent.lowercased() == preferred
            }) {
                return exactMatch
            }
        }

        // 2. Substring match on cover/front/folder/album/art keywords (only in non-root folders)
        if !isRootDir {
            let keywords = ["cover", "front", "folder", "album", "art"]
            for keyword in keywords {
                if let match = imageURLs.first(where: {
                    $0.deletingPathExtension().lastPathComponent.lowercased().contains(keyword)
                }) {
                    return match
                }
            }

            // 3. If this is a dedicated album subfolder (not a generic container) and has a single valid image, use it
            if !genericContainerFolders.contains(dirNameLower), imageURLs.count == 1 {
                return imageURLs.first
            }
        }

        return nil
    }

    /// Parses track number, disc number, artist, and title from a filename when embedded tags are missing.
    public static func parseFilenameMetadata(_ filenameWithoutExtension: String) -> FilenameMetadataFallback {
        let raw = filenameWithoutExtension
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            return FilenameMetadataFallback(title: "Untitled Track")
        }

        var working = raw
        var discNumber: Int? = nil
        var trackNumber: Int? = nil

        let nsWorking = working as NSString
        if let match = discTrackPrefixRegex.firstMatch(
            in: working,
            range: NSRange(location: 0, length: nsWorking.length)
        ) {
            if match.range(at: 1).location != NSNotFound {
                discNumber = Int(nsWorking.substring(with: match.range(at: 1)))
            }
            if match.range(at: 2).location != NSNotFound {
                let candidateTrack = Int(nsWorking.substring(with: match.range(at: 2)))
                if let candidateTrack, candidateTrack > 0, candidateTrack < 999 {
                    trackNumber = candidateTrack
                }
            }
            if match.range(at: 3).location != NSNotFound {
                let remainder = nsWorking.substring(with: match.range(at: 3))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !remainder.isEmpty {
                    working = remainder
                }
            }
        }

        // Check for "Artist - Title" separator
        let parts = working.components(separatedBy: " - ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if parts.count >= 2 {
            let inferredArtist = parts[0]
            let inferredTitle = parts.dropFirst().joined(separator: " - ")
            return FilenameMetadataFallback(
                discNumber: discNumber,
                trackNumber: trackNumber,
                artist: inferredArtist,
                title: inferredTitle
            )
        }

        return FilenameMetadataFallback(
            discNumber: discNumber,
            trackNumber: trackNumber,
            artist: nil,
            title: working
        )
    }

    /// Infers fallback Artist, Album, and Genre from relative folder paths (`Artist/Album/Track.mp3` or `Music/Rock/Song.mp3`).
    public static func inferFolderHierarchyMetadata(relativePath: String) -> FolderHierarchyMetadata {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        let allSegments = normalized.split(separator: "/").map(String.init)
        guard allSegments.count > 1 else {
            return FolderHierarchyMetadata()
        }

        let dirSegments = Array(allSegments.dropLast()).filter { seg in
            let lower = seg.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return !lower.isEmpty && !genericContainerFolders.contains(lower)
        }
        guard !dirSegments.isEmpty else {
            return FolderHierarchyMetadata()
        }

        if dirSegments.count >= 2 {
            let parent = dirSegments[dirSegments.count - 1]
            let grandparent = dirSegments[dirSegments.count - 2]

            // Handle "Artist / Album / CD1 / Track.mp3"
            if parent.lowercased().hasPrefix("cd") || parent.lowercased().hasPrefix("disc") || parent.lowercased().hasPrefix("disk") {
                let albumSeg = grandparent
                let artistSeg = dirSegments.count >= 3 ? dirSegments[dirSegments.count - 3] : nil
                return FolderHierarchyMetadata(artist: artistSeg, album: albumSeg, genre: nil)
            }

            if knownGenreFolderNames.contains(grandparent.lowercased()) {
                return FolderHierarchyMetadata(artist: nil, album: parent, genre: grandparent)
            }

            return FolderHierarchyMetadata(artist: grandparent, album: parent, genre: nil)
        } else {
            let singleFolder = dirSegments[0]
            if knownGenreFolderNames.contains(singleFolder.lowercased()) {
                return FolderHierarchyMetadata(artist: nil, album: singleFolder, genre: singleFolder)
            }
            // Check "Artist - Album" folder naming convention
            let split = singleFolder.components(separatedBy: " - ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if split.count == 2 {
                return FolderHierarchyMetadata(artist: split[0], album: split[1], genre: nil)
            }
            return FolderHierarchyMetadata(artist: nil, album: singleFolder, genre: nil)
        }
    }

    public static func loadLyrics(for track: Track, documentsURL: URL) async -> ParsedLyrics? {
        let fileURL = documentsURL.appendingPathComponent(track.relativePath)
        let lrcURL = fileURL.deletingPathExtension().appendingPathExtension("lrc")
        if FileManager.default.fileExists(atPath: lrcURL.path),
           let rawLrc = try? String(contentsOf: lrcURL, encoding: .utf8),
           !rawLrc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return LyricsEngine.parseLrc(rawLrc, sourceLabel: "Sidecar .LRC")
        }

        let asset = AVURLAsset(url: fileURL)
        if let rawAssetLyrics = try? await asset.load(.lyrics),
           !rawAssetLyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return LyricsEngine.parseLrc(rawAssetLyrics, sourceLabel: "Embedded Tag")
        }

        if let metadata = try? await asset.load(.metadata) {
            for item in metadata {
                if let key = item.commonKey?.rawValue.lowercased(), key.contains("lyric"),
                   let value = try? await item.load(.stringValue),
                   !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return LyricsEngine.parseLrc(value, sourceLabel: "Embedded ID3")
                }
                if let id = item.identifier?.rawValue.lowercased(),
                   (id.contains("uslt") || id.contains("sylt") || id.contains("lyr")),
                   let value = try? await item.load(.stringValue),
                   !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return LyricsEngine.parseLrc(value, sourceLabel: "Embedded ID3")
                }
            }
        }
        return nil
    }

    private static func copyOrUpdateFile(
        from sourceURL: URL,
        to destURL: URL,
        fileManager: FileManager
    ) -> Bool {
        if fileManager.fileExists(atPath: destURL.path) {
            let srcSize = (try? fileManager.attributesOfItem(atPath: sourceURL.path)[.size] as? NSNumber)?.int64Value ?? -1
            let dstSize = (try? fileManager.attributesOfItem(atPath: destURL.path)[.size] as? NSNumber)?.int64Value ?? -2
            if srcSize > 0 && srcSize == dstSize {
                return true
            }
            try? fileManager.removeItem(at: destURL)
        }
        do {
            try fileManager.copyItem(at: sourceURL, to: destURL)
            return true
        } catch {
            return false
        }
    }

    private static func relativePath(for fileURL: URL, baseURL: URL) -> String {
        let fileStandard = fileURL.standardizedFileURL.path
        let baseStandard = baseURL.standardizedFileURL.path
        if fileStandard.hasPrefix(baseStandard + "/") {
            return String(fileStandard.dropFirst(baseStandard.count + 1))
        }
        return fileURL.lastPathComponent
    }

    public static func stableTrackId(for relativePath: String) -> String {
        let digest = SHA256.hash(data: Data(relativePath.utf8))
        let hex = digest.prefix(10).map { String(format: "%02x", $0) }.joined()
        return "track-\(hex)"
    }

    private static func resolveFolderArtworkPath(
        in directoryURL: URL,
        documentsRootURL: URL,
        artworkCacheURL: URL,
        fileManager: FileManager
    ) -> String? {
        guard let imageURL = detectBestFolderArtworkURL(
            in: directoryURL,
            documentsRootURL: documentsRootURL,
            fileManager: fileManager
        ) else {
            // Check parent folder if current folder is a Disc/CD subfolder (such as "Artist/Album/Disc 1")
            let dirName = directoryURL.lastPathComponent.lowercased()
            if dirName.hasPrefix("cd") || dirName.hasPrefix("disc") || dirName.hasPrefix("disk") {
                let parentURL = directoryURL.deletingLastPathComponent()
                if parentURL.standardizedFileURL.path != documentsRootURL.standardizedFileURL.path,
                   let parentImage = detectBestFolderArtworkURL(
                       in: parentURL,
                       documentsRootURL: documentsRootURL,
                       fileManager: fileManager
                   ) {
                    return cacheFolderArtworkFile(parentImage, cacheDir: artworkCacheURL, fileManager: fileManager)
                }
            }
            return nil
        }
        return cacheFolderArtworkFile(imageURL, cacheDir: artworkCacheURL, fileManager: fileManager)
    }

    private static func cacheFolderArtworkFile(
        _ imageURL: URL,
        cacheDir: URL,
        fileManager: FileManager
    ) -> String? {
        let attrs = try? fileManager.attributesOfItem(atPath: imageURL.path)
        let mtime = Int64(((attrs?[.modificationDate] as? Date) ?? Date(timeIntervalSince1970: 0)).timeIntervalSince1970)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        let fingerprint = "\(imageURL.standardizedFileURL.path)::\(mtime)::\(size)"
        let digest = SHA256.hash(data: Data(fingerprint.utf8))
        let hex = digest.prefix(10).map { String(format: "%02x", $0) }.joined()
        let dest = cacheDir.appendingPathComponent("folderart-\(hex).jpg")
        if fileManager.fileExists(atPath: dest.path) {
            return dest.path
        }
        guard let data = try? Data(contentsOf: imageURL),
              let image = UIImage(data: data),
              let compressed = image.jpegData(compressionQuality: 0.86)
        else {
            return nil
        }
        try? compressed.write(to: dest, options: .atomic)
        return dest.path
    }

    private static func extractTrack(
        fileURL: URL,
        relativePath: String,
        artworkCacheURL: URL,
        folderArtworkPath: String?,
        existing: Track?
    ) async -> Track? {
        let fm = FileManager.default
        let attrs = try? fm.attributesOfItem(atPath: fileURL.path)
        let fileSize = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        guard fileSize > 44 else { return nil }

        let id = existing?.id ?? stableTrackId(for: relativePath)
        let creationDate = (attrs?[.creationDate] as? Date) ?? (attrs?[.modificationDate] as? Date) ?? Date()
        let mtimeSeconds = Int64(((attrs?[.modificationDate] as? Date) ?? creationDate).timeIntervalSince1970)
        let addedAt = existing?.addedAt ?? Int64(creationDate.timeIntervalSince1970 * 1000)

        let asset = AVURLAsset(url: fileURL)
        let cmDuration = (try? await asset.load(.duration)) ?? .zero
        var durationSeconds = cmDuration.isNumeric && cmDuration.seconds > 0 ? cmDuration.seconds : 0.0
        if durationSeconds <= 0 {
            if let audioPlayerProbe = try? AVAudioPlayer(contentsOf: fileURL), audioPlayerProbe.duration > 0 {
                durationSeconds = audioPlayerProbe.duration
            } else {
                // Corrupted or unreadable audio file
                return nil
            }
        }

        // Extract embedded metadata first (Priority 2: Embedded tags)
        var embeddedTitle: String? = nil
        var embeddedArtist: String? = nil
        var embeddedAlbum: String? = nil
        var embeddedAlbumArtist: String? = nil
        var embeddedComposer: String? = nil
        var embeddedGenre: String? = nil
        var embeddedYear: String? = nil
        var embeddedTrackNumber: Int? = nil
        var embeddedDiscNumber: Int? = nil
        var embeddedDescription: String? = nil
        var embeddedArtworkData: Data? = nil

        if let common = try? await asset.load(.commonMetadata) {
            for item in common {
                guard let key = item.commonKey else { continue }
                switch key {
                case .commonKeyTitle:
                    if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        embeddedTitle = val.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                case .commonKeyArtist:
                    if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        embeddedArtist = val.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                case .commonKeyAlbumName:
                    if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        embeddedAlbum = val.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                case .commonKeyCreator, .commonKeyAuthor:
                    if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        embeddedComposer = val.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                case .commonKeyType:
                    if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        embeddedGenre = val.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                case .commonKeyCreationDate:
                    if let val = try? await item.load(.stringValue), let parsedYear = extractFourDigitYear(from: val) {
                        embeddedYear = parsedYear
                    }
                case .commonKeyDescription:
                    if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        embeddedDescription = val.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                case .commonKeyArtwork:
                    if embeddedArtworkData == nil, let data = try? await item.load(.dataValue), !data.isEmpty {
                        embeddedArtworkData = data
                    }
                default:
                    break
                }
            }
        }

        if let allMeta = try? await asset.load(.metadata) {
            for item in allMeta {
                let idStr = item.identifier?.rawValue.lowercased() ?? ""
                let keyStr = (item.key as? String)?.lowercased() ?? ""
                let combinedKey = "\(idStr) \(keyStr)"

                if combinedKey.contains("tpe2") || combinedKey.contains("aart") || combinedKey.contains("albumartist") || combinedKey.contains("album_artist") {
                    if embeddedAlbumArtist == nil, let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        embeddedAlbumArtist = val.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } else if combinedKey.contains("tcom") || combinedKey.contains("©wrt") || combinedKey.contains("composer") {
                    if embeddedComposer == nil, let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        embeddedComposer = val.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } else if combinedKey.contains("tcon") || combinedKey.contains("gnre") || combinedKey.contains("©gen") || combinedKey.contains("genre") {
                    if embeddedGenre == nil, let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        embeddedGenre = val.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } else if combinedKey.contains("tyer") || combinedKey.contains("tdrc") || combinedKey.contains("day") || combinedKey.contains("date") || combinedKey.contains("year") {
                    if embeddedYear == nil, let val = try? await item.load(.stringValue), let parsedYear = extractFourDigitYear(from: val) {
                        embeddedYear = parsedYear
                    }
                } else if combinedKey.contains("trck") || combinedKey.contains("trkn") || combinedKey.contains("tracknumber") {
                    if embeddedTrackNumber == nil {
                        embeddedTrackNumber = await parseTrackOrDiscNumber(from: item)
                    }
                } else if combinedKey.contains("tpos") || combinedKey.contains("disk") || combinedKey.contains("discnumber") {
                    if embeddedDiscNumber == nil {
                        embeddedDiscNumber = await parseTrackOrDiscNumber(from: item)
                    }
                } else if combinedKey.contains("apic") || combinedKey.contains("covr") || combinedKey.contains("picture") {
                    if embeddedArtworkData == nil, let data = try? await item.load(.dataValue), !data.isEmpty {
                        embeddedArtworkData = data
                    }
                }
            }
        }

        // Priority 3: Folder hierarchy fallback (never overwrites valid embedded metadata)
        let folderMeta = inferFolderHierarchyMetadata(relativePath: relativePath)

        // Priority 4: Filename fallback (never overwrites valid embedded or folder metadata)
        let filenameBase = fileURL.deletingPathExtension().lastPathComponent
        let filenameMeta = parseFilenameMetadata(filenameBase)

        let resolvedTitle = embeddedTitle ?? filenameMeta.title
        let resolvedArtist = embeddedArtist ?? folderMeta.artist ?? filenameMeta.artist ?? "Unknown Artist"
        let resolvedAlbum = embeddedAlbum ?? folderMeta.album ?? "Single & Imported"
        let resolvedAlbumArtist = embeddedAlbumArtist ?? folderMeta.artist
        let resolvedGenre = embeddedGenre ?? folderMeta.genre
        let resolvedTrackNumber = embeddedTrackNumber ?? filenameMeta.trackNumber
        let resolvedDiscNumber = embeddedDiscNumber ?? filenameMeta.discNumber

        // Artwork Priority: 1. Embedded audio artwork -> 2. Folder cover artwork (cover.jpg, folder.jpg, album.jpg...)
        let resolvedArtworkPath: String?
        if let data = embeddedArtworkData {
            resolvedArtworkPath = cacheEmbeddedArtworkData(
                data,
                trackId: id,
                mtimeSeconds: mtimeSeconds,
                cacheDir: artworkCacheURL
            ) ?? folderArtworkPath
        } else {
            resolvedArtworkPath = folderArtworkPath
        }

        return Track(
            id: id,
            title: resolvedTitle,
            artist: resolvedArtist,
            album: resolvedAlbum,
            albumArtist: resolvedAlbumArtist,
            composer: embeddedComposer,
            genre: resolvedGenre,
            year: embeddedYear,
            trackNumber: resolvedTrackNumber,
            discNumber: resolvedDiscNumber,
            descriptionText: embeddedDescription,
            duration: durationSeconds,
            relativePath: relativePath,
            artworkPath: resolvedArtworkPath,
            addedAt: addedAt
        )
    }

    /// Propagates shared artwork within an album folder and unifies multi-artist compilation folders under "Various Artists"
    /// when tracks share the same folder and album title without an explicit albumArtist.
    public static func propagateSharedFolderArtworkAndCompilations(_ tracks: [Track]) -> [Track] {
        guard !tracks.isEmpty else { return [] }
        var updated = tracks

        let indicesByFolderAndAlbum = Dictionary(grouping: updated.indices) { idx -> String in
            let t = updated[idx]
            return "\(t.folderName.lowercased())::\(t.album.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
        }

        for (_, indices) in indicesByFolderAndAlbum where indices.count > 1 {
            let sharedArtwork = indices.compactMap { updated[$0].artworkPath }.first
            let distinctArtists = Set(indices.map { updated[$0].artist.lowercased() })
            let hasMissingAlbumArtist = indices.contains {
                updated[$0].albumArtist == nil || updated[$0].albumArtist?.isEmpty == true
            }
            let isInSubfolder = updated[indices[0]].folderName != "Snoozy Root"
            let shouldUnifyAsCompilation = isInSubfolder && distinctArtists.count >= 2 && hasMissingAlbumArtist

            for idx in indices {
                if updated[idx].artworkPath == nil, let sharedArtwork {
                    updated[idx].artworkPath = sharedArtwork
                }
                if shouldUnifyAsCompilation && (updated[idx].albumArtist == nil || updated[idx].albumArtist?.isEmpty == true) {
                    updated[idx].albumArtist = "Various Artists"
                }
            }
        }
        return updated
    }

    private static func extractFourDigitYear(from raw: String) -> String? {
        let ns = raw as NSString
        guard let match = yearRegex.firstMatch(in: raw, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        return ns.substring(with: match.range(at: 1))
    }

    private static func parseTrackOrDiscNumber(from item: AVMetadataItem) async -> Int? {
        if let strVal = try? await item.load(.stringValue) {
            let firstPart = strVal.components(separatedBy: "/").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if let num = Int(firstPart), num > 0 {
                return num
            }
        }
        if let numVal = try? await item.load(.numberValue) {
            let n = numVal.intValue
            if n > 0 {
                return n
            }
        }
        // MP4/M4A 'trkn' and 'disk' atoms store binary uint16 big-endian at bytes 2..3
        if let dataVal = try? await item.load(.dataValue), dataVal.count >= 4 {
            let hi = Int(dataVal[2])
            let lo = Int(dataVal[3])
            let combined = (hi << 8) | lo
            if combined > 0 && combined < 999 {
                return combined
            }
        }
        return nil
    }

    private static func cacheEmbeddedArtworkData(
        _ data: Data,
        trackId: String,
        mtimeSeconds: Int64,
        cacheDir: URL
    ) -> String? {
        let dest = cacheDir.appendingPathComponent("\(trackId)-\(mtimeSeconds).jpg")
        if FileManager.default.fileExists(atPath: dest.path) {
            return dest.path
        }
        if let image = UIImage(data: data),
           let compressed = image.jpegData(compressionQuality: 0.86) {
            try? compressed.write(to: dest, options: .atomic)
            return dest.path
        }
        return nil
    }
}
