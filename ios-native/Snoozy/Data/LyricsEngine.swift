import Foundation

public struct LyricLine: Identifiable, Equatable, Sendable {
    public let id: Int
    public let timeSeconds: Double?
    public let text: String

    public init(id: Int, timeSeconds: Double?, text: String) {
        self.id = id
        self.timeSeconds = timeSeconds
        self.text = text
    }
}

public struct ParsedLyrics: Equatable, Sendable {
    public let lines: [LyricLine]
    public let isSynced: Bool
    public let sourceLabel: String

    public init(lines: [LyricLine], isSynced: Bool, sourceLabel: String) {
        self.lines = lines
        self.isSynced = isSynced
        self.sourceLabel = sourceLabel
    }
}

public enum LyricsEngine {
    private static let timestampPattern = try! NSRegularExpression(
        pattern: #"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]"#
    )

    public static func parseLrc(_ raw: String, sourceLabel: String = "LRC") -> ParsedLyrics {
        let normalized = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var timedEntries: [(Double, String)] = []
        var plainLines: [String] = []

        for rawLine in normalized.components(separatedBy: "\n") {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if isMetadataHeader(trimmed) { continue }

            let nsLine = trimmed as NSString
            let matches = timestampPattern.matches(
                in: trimmed,
                range: NSRange(location: 0, length: nsLine.length)
            )
            if matches.isEmpty {
                plainLines.append(trimmed)
                continue
            }

            let lastMatchEnd = matches.last!.range.location + matches.last!.range.length
            let lyricText = nsLine.substring(from: lastMatchEnd)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            for match in matches {
                let minStr = nsLine.substring(with: match.range(at: 1))
                let secStr = nsLine.substring(with: match.range(at: 2))
                let fracRange = match.range(at: 3)
                let fracStr = fracRange.location != NSNotFound
                    ? nsLine.substring(with: fracRange)
                    : "0"

                let minutes = Double(minStr) ?? 0
                let seconds = Double(secStr) ?? 0
                let fraction: Double
                switch fracStr.count {
                case 1: fraction = (Double(fracStr) ?? 0) / 10.0
                case 2: fraction = (Double(fracStr) ?? 0) / 100.0
                default: fraction = (Double(fracStr) ?? 0) / 1000.0
                }
                let totalSeconds = minutes * 60.0 + seconds + fraction
                timedEntries.append((totalSeconds, lyricText.isEmpty ? "•••" : lyricText))
            }
        }

        if !timedEntries.isEmpty {
            timedEntries.sort { $0.0 < $1.0 }
            let lines = timedEntries.enumerated().map { idx, pair in
                LyricLine(id: idx, timeSeconds: pair.0, text: pair.1)
            }
            return ParsedLyrics(lines: lines, isSynced: true, sourceLabel: sourceLabel)
        }

        let unsynced = plainLines.enumerated().map { idx, text in
            LyricLine(id: idx, timeSeconds: nil, text: text)
        }
        return ParsedLyrics(lines: unsynced, isSynced: false, sourceLabel: sourceLabel)
    }

    public static func activeLineIndex(
        lyrics: ParsedLyrics,
        positionSeconds: Double,
        offsetSeconds: Double = 0.0
    ) -> Int? {
        guard lyrics.isSynced, !lyrics.lines.isEmpty else { return nil }
        let effectiveTime = max(0.0, positionSeconds - offsetSeconds)
        var currentIndex: Int? = nil
        for (idx, line) in lyrics.lines.enumerated() {
            guard let t = line.timeSeconds else { continue }
            if effectiveTime + 0.08 >= t {
                currentIndex = idx
            } else {
                break
            }
        }
        return currentIndex
    }

    private static func isMetadataHeader(_ line: String) -> Bool {
        let lower = line.lowercased()
        let prefixes = ["[ar:", "[ti:", "[al:", "[by:", "[offset:", "[length:", "[re:", "[ve:"]
        return prefixes.contains { lower.hasPrefix($0) }
    }
}
