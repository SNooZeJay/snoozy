import SwiftUI
import UIKit

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
                accentInk: Color(red: 0.925, green: 0.992, blue: 0.961),
                background: Color(red: 0.02, green: 0.03, blue: 0.04),
                groupedBackground: Color(red: 0.04, green: 0.05, blue: 0.07),
                surface: Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.66),
                surfaceRaised: Color(red: 0.17, green: 0.17, blue: 0.19).opacity(0.74),
                ink: .white,
                inkMuted: Color(red: 0.92, green: 0.92, blue: 0.96).opacity(0.66),
                inkFaint: Color(red: 0.92, green: 0.92, blue: 0.96).opacity(0.40),
                danger: Color(red: 1.0, green: 0.271, blue: 0.227),
                ember: Color(red: 1.0, green: 0.624, blue: 0.039),
                isDark: true
            )
        } else {
            return SnoozyThemeColors(
                accent: resolvedAccent,
                accentStrong: resolvedStrong,
                accentInk: .white,
                background: Color(red: 0.949, green: 0.949, blue: 0.969),
                groupedBackground: Color(red: 0.949, green: 0.949, blue: 0.969),
                surface: Color.white.opacity(0.72),
                surfaceRaised: Color.white.opacity(0.86),
                ink: Color(red: 0.06, green: 0.07, blue: 0.09),
                inkMuted: Color(red: 0.24, green: 0.24, blue: 0.26).opacity(0.68),
                inkFaint: Color(red: 0.24, green: 0.24, blue: 0.26).opacity(0.42),
                danger: Color(red: 1.0, green: 0.231, blue: 0.188),
                ember: Color(red: 1.0, green: 0.584, blue: 0.0),
                isDark: false
            )
        }
    }
}

public enum SnoozyTypography {
    public static func display(_ size: CGFloat = 30) -> Font {
        if UIFont(name: "BricolageGrotesque-SemiBold", size: size) != nil {
            return .custom("BricolageGrotesque-SemiBold", size: size)
        }
        return .system(size: size, weight: .bold, design: .rounded)
    }

    public static func title(_ size: CGFloat = 21) -> Font {
        if UIFont(name: "BricolageGrotesque-Medium", size: size) != nil {
            return .custom("BricolageGrotesque-Medium", size: size)
        }
        return .system(size: size, weight: .semibold, design: .rounded)
    }

    public static func headline(_ size: CGFloat = 17) -> Font {
        if UIFont(name: "AtkinsonHyperlegible-Bold", size: size) != nil {
            return .custom("AtkinsonHyperlegible-Bold", size: size)
        }
        return .system(size: size, weight: .semibold)
    }

    public static func body(_ size: CGFloat = 15, bold: Bool = false) -> Font {
        let name = bold ? "AtkinsonHyperlegible-Bold" : "AtkinsonHyperlegible-Regular"
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: bold ? .semibold : .regular)
    }

    public static func footnote(_ size: CGFloat = 13) -> Font {
        if UIFont(name: "AtkinsonHyperlegible-Regular", size: size) != nil {
            return .custom("AtkinsonHyperlegible-Regular", size: size)
        }
        return .system(size: size, weight: .regular)
    }

    public static func caption(_ size: CGFloat = 11, bold: Bool = false) -> Font {
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
