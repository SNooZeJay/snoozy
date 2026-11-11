import SwiftUI

public struct LiquidGlassModifier: ViewModifier {
    public let cornerRadius: CGFloat
    public let glassMode: GlassMode
    public let refractionIntensity: Double
    public let tintColor: Color
    public let isProminent: Bool

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        switch glassMode {
        case .reduceTransparency:
            content
                .background(
                    shape.fill(
                        isProminent
                            ? tintColor
                            : Color(UIColor.secondarySystemGroupedBackground)
                    )
                )
                .overlay(
                    shape.strokeBorder(
                        Color.white.opacity(0.14),
                        lineWidth: 0.8
                    )
                )

        case .frosted:
            content
                .background(
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        if isProminent {
                            shape.fill(tintColor.opacity(0.82))
                        } else {
                            shape.fill(tintColor.opacity(0.08))
                        }
                    }
                )
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.38),
                                Color.white.opacity(0.10),
                                tintColor.opacity(0.24)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
                )

        case .liquidGlass:
            content
                .background(
                    GeometryReader { proxy in
                        ZStack {
                            shape.fill(.ultraThinMaterial)
                            if isProminent {
                                shape.fill(
                                    LinearGradient(
                                        colors: [
                                            tintColor.opacity(0.92),
                                            tintColor.opacity(0.72)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            } else {
                                shape.fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.16 * refractionIntensity),
                                            tintColor.opacity(0.10 * refractionIntensity),
                                            Color.white.opacity(0.04)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            }
                            // Top-edge liquid meniscus reflection
                            VStack(spacing: 0) {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.48 * refractionIntensity),
                                                Color.white.opacity(0.0)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(height: min(16, proxy.size.height * 0.32))
                                    .padding(.horizontal, max(6, cornerRadius * 0.45))
                                    .padding(.top, 1.2)
                                Spacer(minLength: 0)
                            }
                        }
                        .clipShape(shape)
                        .layerEffect(
                            ShaderLibrary.liquidGlassLens(
                                .float2(proxy.size),
                                .float(cornerRadius),
                                .float(refractionIntensity),
                                .float(0.0),
                                .color(tintColor)
                            ),
                            maxSampleOffset: CGSize(width: 12, height: 12),
                            isEnabled: refractionIntensity > 0.05
                        )
                    }
                )
                .overlay(
                    shape.strokeBorder(
                        AngularGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                tintColor.opacity(0.38),
                                Color.white.opacity(0.10),
                                Color.white.opacity(0.42),
                                Color.white.opacity(0.55)
                            ],
                            center: .center
                        ),
                        lineWidth: 1.0
                    )
                )
                .shadow(color: Color.black.opacity(0.24), radius: 14, x: 0, y: 8)
        }
    }
}

public extension View {
    func liquidGlassSurface(
        cornerRadius: CGFloat = 24,
        glassMode: GlassMode = .liquidGlass,
        refractionIntensity: Double = 0.82,
        tintColor: Color = Color(red: 0.063, green: 0.725, blue: 0.506),
        isProminent: Bool = false
    ) -> some View {
        modifier(
            LiquidGlassModifier(
                cornerRadius: cornerRadius,
                glassMode: glassMode,
                refractionIntensity: refractionIntensity,
                tintColor: tintColor,
                isProminent: isProminent
            )
        )
    }
}

public struct LiquidAuraBackgroundView: View {
    public let theme: SnoozyThemeColors
    public let palette: ArtworkPalette
    public let preferences: SnoozyPreferences

    public init(
        theme: SnoozyThemeColors,
        palette: ArtworkPalette,
        preferences: SnoozyPreferences
    ) {
        self.theme = theme
        self.palette = palette
        self.preferences = preferences
    }

    public var body: some View {
        if !preferences.auraBackdropEnabled || preferences.glassMode == .reduceTransparency {
            theme.background.ignoresSafeArea()
        } else {
            TimelineView(.animation(minimumInterval: preferences.motionMode == .reduced ? 1.0 : 1.0 / 30.0)) { timeline in
                let elapsed = preferences.motionMode == .reduced
                    ? 0.0
                    : timeline.date.timeIntervalSinceReferenceDate
                GeometryReader { proxy in
                    Rectangle()
                        .fill(theme.background)
                        .colorEffect(
                            ShaderLibrary.liquidAuraBackdrop(
                                .float2(proxy.size),
                                .float(elapsed),
                                .float(preferences.auraBackdropIntensity),
                                .color(palette.primary),
                                .color(palette.secondary),
                                .color(palette.tertiary),
                                .color(theme.background)
                            )
                        )
                }
                .ignoresSafeArea()
            }
        }
    }
}

public struct LiquidGlassButton: View {
    public let title: String
    public let systemImage: String?
    public let isProminent: Bool
    public let isDisabled: Bool
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    public let action: () -> Void

    public init(
        title: String,
        systemImage: String? = nil,
        isProminent: Bool = false,
        isDisabled: Bool = false,
        theme: SnoozyThemeColors,
        preferences: SnoozyPreferences,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isProminent = isProminent
        self.isDisabled = isDisabled
        self.theme = theme
        self.preferences = preferences
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(SnoozyTypography.body(14, bold: true))
                    .lineLimit(1)
            }
            .foregroundStyle(isProminent ? theme.accentInk : theme.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .liquidGlassSurface(
                cornerRadius: 22,
                glassMode: preferences.glassMode,
                refractionIntensity: preferences.refractionIntensity,
                tintColor: theme.accent,
                isProminent: isProminent
            )
            .opacity(isDisabled ? 0.45 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

public struct LiquidGlassIconButton: View {
    public let systemImage: String
    public let accessibilityLabel: String
    public let size: CGFloat
    public let isActive: Bool
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    public let action: () -> Void

    public init(
        systemImage: String,
        accessibilityLabel: String,
        size: CGFloat = 44,
        isActive: Bool = false,
        theme: SnoozyThemeColors,
        preferences: SnoozyPreferences,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.size = size
        self.isActive = isActive
        self.theme = theme
        self.preferences = preferences
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.40, weight: .semibold))
                .foregroundStyle(isActive ? theme.accentInk : theme.ink)
                .frame(width: size, height: size)
                .liquidGlassSurface(
                    cornerRadius: size * 0.5,
                    glassMode: preferences.glassMode,
                    refractionIntensity: preferences.refractionIntensity,
                    tintColor: theme.accent,
                    isProminent: isActive
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
