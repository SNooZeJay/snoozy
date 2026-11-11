import AVFoundation
import CryptoKit
import Foundation
import UIKit

public enum AudioScanner {
    public static let supportedExtensions: Set<String> = [
        "mp3", "flac", "wav", "m4a", "aac", "alac", "ogg", "opus", "aiff", "aif", "caf"
    ]

    public static func scanDirectory(
        documentsURL: URL,
        artworkCacheURL: URL,
        existingTracksByPath: [String: Track] = [:]
    ) async -> [Track] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: documentsURL,
            includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey],
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

        var results: [Track] = []
        for fileURL in audioURLs {
            let relPath = relativePath(for: fileURL, baseURL: documentsURL)
            let track = await extractTrack(
                fileURL: fileURL,
                relativePath: relPath,
                artworkCacheURL: artworkCacheURL,
                existing: existingTracksByPath[relPath]
            )
            results.append(track)
        }

        results.sort {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        return results
    }

    public static func importExternalURLs(
        _ urls: [URL],
        into documentsURL: URL
    ) -> Int {
        let fm = FileManager.default
        let importedDir = documentsURL.appendingPathComponent("Imported", isDirectory: true)
        try? fm.createDirectory(at: importedDir, withIntermediateDirectories: true)

        var copiedCount = 0
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped { url.stopAccessingSecurityScopedResource() }
            }

            var isDir: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                if let subEnum = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                    while let childURL = subEnum.nextObject() as? URL {
                        let ext = childURL.pathExtension.lowercased()
                        if supportedExtensions.contains(ext) || ext == "lrc" {
                            if copySingleFile(childURL, toDirectory: importedDir, fileManager: fm) {
                                if supportedExtensions.contains(ext) {
                                    copiedCount += 1
                                }
                            }
                        }
                    }
                }
            } else {
                let ext = url.pathExtension.lowercased()
                if supportedExtensions.contains(ext) || ext == "lrc" {
                    if copySingleFile(url, toDirectory: importedDir, fileManager: fm) {
                        if supportedExtensions.contains(ext) {
                            copiedCount += 1
                        }
                    }
                }
            }
        }
        return copiedCount
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

    private static func copySingleFile(
        _ sourceURL: URL,
        toDirectory targetDir: URL,
        fileManager: FileManager
    ) -> Bool {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension
        var destURL = targetDir.appendingPathComponent(sourceURL.lastPathComponent)
        var counter = 1
        while fileManager.fileExists(atPath: destURL.path) {
            let candidateName = "\(baseName) (\(counter)).\(ext)"
            destURL = targetDir.appendingPathComponent(candidateName)
            counter += 1
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

    private static func stableTrackId(for relativePath: String) -> String {
        let digest = SHA256.hash(data: Data(relativePath.utf8))
        let hex = digest.prefix(10).map { String(format: "%02x", $0) }.joined()
        return "track-\(hex)"
    }

    private static func extractTrack(
        fileURL: URL,
        relativePath: String,
        artworkCacheURL: URL,
        existing: Track?
    ) async -> Track {
        let id = existing?.id ?? stableTrackId(for: relativePath)
        let fallbackTitle = fileURL.deletingPathExtension().lastPathComponent
        let parentFolder = fileURL.deletingLastPathComponent().lastPathComponent
        let fallbackAlbum = (parentFolder == "Documents" || parentFolder == "Imported" || parentFolder == "Music")
            ? "Single & Imported"
            : parentFolder

        let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let creationDate = (attrs?[.creationDate] as? Date) ?? (attrs?[.modificationDate] as? Date) ?? Date()
        let addedAt = existing?.addedAt ?? Int64(creationDate.timeIntervalSince1970 * 1000)

        let asset = AVURLAsset(url: fileURL)
        let cmDuration = (try? await asset.load(.duration)) ?? .zero
        let durationSeconds = cmDuration.isNumeric && cmDuration.seconds > 0 ? cmDuration.seconds : 0.0

        var title = fallbackTitle
        var artist = "Unknown Artist"
        var album = fallbackAlbum
        var albumArtist: String? = nil
        var genre: String? = nil
        var year: String? = nil
        var trackNumber: Int? = nil
        var artworkPath: String? = existing?.artworkPath

        if let common = try? await asset.load(.commonMetadata) {
            for item in common {
                guard let key = item.commonKey else { continue }
                switch key {
                case .commonKeyTitle:
                    if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        title = val.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                case .commonKeyArtist:
                    if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        artist = val.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                case .commonKeyAlbumName:
                    if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        album = val.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                case .commonKeyType:
                    if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        genre = val.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                case .commonKeyCreationDate:
                    if let val = try? await item.load(.stringValue), val.count >= 4 {
                        year = String(val.prefix(4))
                    }
                case .commonKeyArtwork:
                    if let data = try? await item.load(.dataValue), !data.isEmpty {
                        artworkPath = cacheArtworkData(data, trackId: id, cacheDir: artworkCacheURL)
                    }
                default:
                    break
                }
            }
        }

        if let allMeta = try? await asset.load(.metadata) {
            for item in allMeta {
                let idStr = item.identifier?.rawValue.lowercased() ?? ""
                if idStr.contains("tpe2") || idStr.contains("aart") {
                    if let val = try? await item.load(.stringValue), !val.isEmpty {
                        albumArtist = val
                    }
                } else if idStr.contains("tcon") || idStr.contains("gnre") {
                    if genre == nil, let val = try? await item.load(.stringValue), !val.isEmpty {
                        genre = val
                    }
                } else if idStr.contains("tyer") || idStr.contains("tdrc") || idStr.contains("day") {
                    if year == nil, let val = try? await item.load(.stringValue), val.count >= 4 {
                        year = String(val.prefix(4))
                    }
                } else if idStr.contains("trck") || idStr.contains("trkn") {
                    if trackNumber == nil, let val = try? await item.load(.stringValue) {
                        let digits = val.components(separatedBy: "/").first?.trimmingCharacters(in: .whitespaces) ?? ""
                        trackNumber = Int(digits)
                    }
                }
            }
        }

        return Track(
            id: id,
            title: title,
            artist: artist,
            album: album,
            albumArtist: albumArtist,
            genre: genre,
            year: year,
            trackNumber: trackNumber,
            descriptionText: nil,
            duration: durationSeconds,
            relativePath: relativePath,
            artworkPath: artworkPath,
            addedAt: addedAt
        )
    }

    private static func cacheArtworkData(_ data: Data, trackId: String, cacheDir: URL) -> String? {
        let dest = cacheDir.appendingPathComponent("\(trackId).jpg")
        if FileManager.default.fileExists(atPath: dest.path) {
            return dest.path
        }
        if let image = UIImage(data: data),
           let compressed = image.jpegData(compressionQuality: 0.85) {
            try? compressed.write(to: dest, options: .atomic)
            return dest.path
        }
        return nil
    }
}
