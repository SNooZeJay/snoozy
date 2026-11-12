import CoreText
import SwiftUI
import UIKit

public enum SnoozyFontRegistrar {
    private static var didRegister: Bool = false

    public static func registerBundledFontsIfNeeded() {
        guard !didRegister else { return }
        didRegister = true

        let fontFileNames = [
            "atkinson_hyperlegible_400",
            "atkinson_hyperlegible_700",
            "bricolage_grotesque_500",
            "bricolage_grotesque_600"
        ]

        for name in fontFileNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            } else if let subUrl = Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") {
                CTFontManagerRegisterFontsForURL(subUrl as CFURL, .process, nil)
            }
        }

        if let resourceURL = Bundle.main.resourceURL,
           let enumerator = FileManager.default.enumerator(at: resourceURL, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator where fileURL.pathExtension.lowercased() == "ttf" {
                CTFontManagerRegisterFontsForURL(fileURL as CFURL, .process, nil)
            }
        }
    }
}

public struct SnoozyThemeColors: Sendable {
    public let accent: Color
    public let accentStrong: Color
    public let accentInk: Color
    public let background: Color
    public let groupedBackground: Color
    public let surface: Color
    public let surfaceRaised: Color
    public let ink: Color
    public let inkMuted: Color
    public let inkFaint: Color
    public let danger: Color
    public let ember: Color
    public let isDark: Bool

    public static func resolve(
        isDark: Bool,
        seed: PaletteSeed,
        artworkPalette: ArtworkPalette
    ) -> SnoozyThemeColors {
        let resolvedAccent: Color
        let resolvedStrong: Color
        switch seed {
        case .emerald:
            resolvedAccent = Color(red: 0.063, green: 0.725, blue: 0.506) // #10B981
            resolvedStrong = Color(red: 0.020, green: 0.588, blue: 0.412) // #059669
        case .dynamicArtwork:
            resolvedAccent = artworkPalette.primary
            resolvedStrong = artworkPalette.secondary
        case .cyan:
            resolvedAccent = Color(red: 0.024, green: 0.714, blue: 0.831)
            resolvedStrong = Color(red: 0.031, green: 0.569, blue: 0.698)
        case .violet:
            resolvedAccent = Color(red: 0.545, green: 0.361, blue: 0.965)
            resolvedStrong = Color(red: 0.424, green: 0.227, blue: 0.851)
        case .rose:
            resolvedAccent = Color(red: 0.957, green: 0.247, blue: 0.369)
            resolvedStrong = Color(red: 0.882, green: 0.114, blue: 0.282)
        case .amber:
            resolvedAccent = Color(red: 0.961, green: 0.620, blue: 0.043)
            resolvedStrong = Color(red: 0.851, green: 0.467, blue: 0.024)
        }

        if isDark {
            return SnoozyThemeColors(
                accent: resolvedAccent,
                accentStrong: resolvedStrong,
                accentInk: Color(red: 0.94, green: 1.0, blue: 0.97),
                background: Color(red: 0.024, green: 0.039, blue: 0.055),
                groupedBackground: Color(red: 0.039, green: 0.063, blue: 0.086),
                surface: Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.68),
                surfaceRaised: Color(red: 0.12, green: 0.17, blue: 0.21).opacity(0.78),
                ink: .white,
                inkMuted: Color(red: 0.88, green: 0.93, blue: 0.95).opacity(0.72),
                inkFaint: Color(red: 0.88, green: 0.93, blue: 0.95).opacity(0.45),
                danger: Color(red: 1.0, green: 0.271, blue: 0.227),
                ember: Color(red: 1.0, green: 0.624, blue: 0.039),
                isDark: true
            )
        } else {
            return SnoozyThemeColors(
                accent: resolvedAccent,
                accentStrong: resolvedStrong,
                accentInk: .white,
                background: Color(red: 0.941, green: 0.965, blue: 0.957),
                groupedBackground: Color(red: 0.918, green: 0.949, blue: 0.941),
                surface: Color.white.opacity(0.76),
                surfaceRaised: Color.white.opacity(0.88),
                ink: Color(red: 0.04, green: 0.08, blue: 0.10),
                inkMuted: Color(red: 0.18, green: 0.25, blue: 0.28).opacity(0.72),
                inkFaint: Color(red: 0.18, green: 0.25, blue: 0.28).opacity(0.46),
                danger: Color(red: 1.0, green: 0.231, blue: 0.188),
                ember: Color(red: 1.0, green: 0.584, blue: 0.0),
                isDark: false
            )
        }
    }
}

public enum SnoozyTypography {
    public static func display(_ size: CGFloat = 30) -> Font {
        SnoozyFontRegistrar.registerBundledFontsIfNeeded()
        if UIFont(name: "BricolageGrotesque-SemiBold", size: size) != nil {
            return .custom("BricolageGrotesque-SemiBold", size: size)
        }
        return .system(size: size, weight: .bold, design: .rounded)
    }

    public static func title(_ size: CGFloat = 21) -> Font {
        SnoozyFontRegistrar.registerBundledFontsIfNeeded()
        if UIFont(name: "BricolageGrotesque-Medium", size: size) != nil {
            return .custom("BricolageGrotesque-Medium", size: size)
        }
        return .system(size: size, weight: .semibold, design: .rounded)
    }

    public static func headline(_ size: CGFloat = 17) -> Font {
        SnoozyFontRegistrar.registerBundledFontsIfNeeded()
        if UIFont(name: "AtkinsonHyperlegible-Bold", size: size) != nil {
            return .custom("AtkinsonHyperlegible-Bold", size: size)
        }
        return .system(size: size, weight: .semibold)
    }

    public static func body(_ size: CGFloat = 15, bold: Bool = false) -> Font {
        SnoozyFontRegistrar.registerBundledFontsIfNeeded()
        let name = bold ? "AtkinsonHyperlegible-Bold" : "AtkinsonHyperlegible-Regular"
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: bold ? .semibold : .regular)
    }

    public static func footnote(_ size: CGFloat = 13) -> Font {
        SnoozyFontRegistrar.registerBundledFontsIfNeeded()
        if UIFont(name: "AtkinsonHyperlegible-Regular", size: size) != nil {
            return .custom("AtkinsonHyperlegible-Regular", size: size)
        }
        return .system(size: size, weight: .regular)
    }

    public static func caption(_ size: CGFloat = 11, bold: Bool = false) -> Font {
        SnoozyFontRegistrar.registerBundledFontsIfNeeded()
        let name = bold ? "AtkinsonHyperlegible-Bold" : "AtkinsonHyperlegible-Regular"
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: bold ? .semibold : .medium)
    }
}

public enum SnoozyFormat {
    public static func formatClock(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }

    public static func formatRemainingClock(elapsed: Double, duration: Double) -> String {
        let remaining = max(0.0, (duration.isFinite ? duration : 0.0) - (elapsed.isFinite ? elapsed : 0.0))
        return "-\(formatClock(remaining))"
    }

    public static func formatDuration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0 min" }
        let totalMins = max(1, Int((seconds / 60.0).rounded()))
        if totalMins >= 60 {
            let hrs = totalMins / 60
            let rem = totalMins % 60
            return rem > 0 ? "\(hrs) hr \(rem) min" : "\(hrs) hr"
        }
        return "\(totalMins) min"
    }

    public static func countLabel(_ count: Int, _ singular: String, _ plural: String) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }
}

/// Adaptive iPhone layout metrics spanning compact screens (iPhone 13 mini, 375x812pt),
/// standard screens (iPhone 14/15/16, 390-393pt), Pro (402pt), Plus/Pro Max (430-440pt), and landscape.
public struct SnoozyResponsiveLayout: Equatable, Sendable {
    public let containerWidth: CGFloat
    public let containerHeight: CGFloat
    public let isLandscape: Bool
    public let isCompactWidth: Bool
    public let isCompactHeight: Bool
    public let isExpandedWidth: Bool

    public let horizontalPadding: CGFloat
    public let sectionSpacing: CGFloat
    public let headerTitleSize: CGFloat
    public let sectionTitleSize: CGFloat
    public let brandIconSize: CGFloat
    public let headerButtonSize: CGFloat
    public let shelfItemSize: CGFloat
    public let gridColumnCount: Int
    public let gridSpacing: CGFloat
    public let gridTileSize: CGFloat
    public let detailHeroArtworkSize: CGFloat
    public let tabBarPillHeight: CGFloat
    public let tabBarIndicatorHeight: CGFloat
    public let miniPlayerHeight: CGFloat
    public let bottomChromeMaxWidth: CGFloat

    public init(width: CGFloat = 393, height: CGFloat = 852) {
        let safeW = max(320, width)
        let safeH = max(320, height)
        let landscape = safeW > safeH
        let compactW = !landscape && safeW <= 380
        let compactH = safeH <= 760
        let expandedW = !landscape && safeW >= 420

        self.containerWidth = safeW
        self.containerHeight = safeH
        self.isLandscape = landscape
        self.isCompactWidth = compactW
        self.isCompactHeight = compactH
        self.isExpandedWidth = expandedW

        let hPad: CGFloat = compactW ? 14 : (expandedW || landscape ? 20 : 16)
        self.horizontalPadding = hPad
        self.sectionSpacing = compactW ? 20 : (expandedW ? 26 : 24)
        self.headerTitleSize = compactW ? 26 : (expandedW ? 32 : 30)
        self.sectionTitleSize = compactW ? 19 : (expandedW ? 22 : 21)
        self.brandIconSize = compactW ? 38 : (expandedW ? 44 : 40)
        self.headerButtonSize = compactW ? 36 : (expandedW ? 42 : 40)
        self.shelfItemSize = compactW ? 138 : (expandedW ? 164 : (landscape ? 142 : 152))

        let cols = landscape ? (safeW >= 740 ? 4 : 3) : 2
        let gSpace: CGFloat = compactW ? 12 : (expandedW ? 16 : 14)
        let contentW = max(240, safeW - hPad * 2)
        let tile = floor((contentW - gSpace * CGFloat(cols - 1)) / CGFloat(cols))

        self.gridColumnCount = cols
        self.gridSpacing = gSpace
        self.gridTileSize = max(128, tile)
        self.detailHeroArtworkSize = landscape ? 176 : (compactW ? 194 : (expandedW ? 242 : 220))
        self.tabBarPillHeight = landscape ? 50 : (compactW ? 52 : (expandedW ? 58 : 56))
        self.tabBarIndicatorHeight = landscape ? 38 : (compactW ? 40 : (expandedW ? 46 : 44))
        self.miniPlayerHeight = landscape ? 50 : (compactW ? 52 : (expandedW ? 58 : 56))
        self.bottomChromeMaxWidth = landscape ? 460 : 500
    }

    public var gridItems: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: gridColumnCount)
    }

    public func scrollBottomPadding(hasActiveTrack: Bool) -> CGFloat {
        if hasActiveTrack {
            return tabBarPillHeight + miniPlayerHeight + (isCompactHeight ? 32 : 42)
        }
        return tabBarPillHeight + (isCompactHeight ? 24 : 32)
    }

    public var nowPlayingArtworkSize: CGFloat {
        if isLandscape {
            return min(containerHeight * 0.58, containerWidth * 0.34)
        }
        let maxByWidth = containerWidth - horizontalPadding * 2 - 12
        let heightRatio: CGFloat = containerHeight <= 700 ? 0.34 : (containerHeight <= 820 ? 0.38 : 0.42)
        let maxByHeight = containerHeight * heightRatio
        return max(188, min(352, min(maxByWidth, maxByHeight)))
    }

    public var nowPlayingSectionSpacing: CGFloat {
        if isLandscape { return 10 }
        if containerHeight <= 700 { return 10 }
        if containerHeight <= 820 { return 13 }
        return 17
    }

    public var nowPlayingPlayButtonSize: CGFloat {
        if isLandscape || containerHeight <= 700 { return 58 }
        if containerHeight <= 820 { return 64 }
        return 72
    }

    public var nowPlayingPlayIconSize: CGFloat {
        if isLandscape || containerHeight <= 700 { return 34 }
        if containerHeight <= 820 { return 38 }
        return 42
    }

    public var nowPlayingSkipButtonSize: CGFloat {
        if isLandscape || containerHeight <= 700 { return 48 }
        if containerHeight <= 820 { return 52 }
        return 56
    }

    public var nowPlayingSkipIconSize: CGFloat {
        if isLandscape || containerHeight <= 700 { return 25 }
        if containerHeight <= 820 { return 27 }
        return 30
    }
}

private struct SnoozyResponsiveLayoutKey: EnvironmentKey {
    static let defaultValue = SnoozyResponsiveLayout()
}

public extension EnvironmentValues {
    var snoozyLayout: SnoozyResponsiveLayout {
        get { self[SnoozyResponsiveLayoutKey.self] }
        set { self[SnoozyResponsiveLayoutKey.self] = newValue }
    }
}
