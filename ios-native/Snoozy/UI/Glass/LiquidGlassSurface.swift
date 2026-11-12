import AVKit
import MediaPlayer
import SwiftUI
import UIKit

public enum LiquidGlassVariant: Sendable {
    case ultraClear
    case regular
    case tinted
    case prominent
}

/// Groups multiple Liquid Glass controls so adjacent glass shapes share optical styling
/// (WWDC25 Session 284, 19:15: GlassEffectContainer / UIGlassContainerEffect).
public struct SnoozyGlassEffectContainer<Content: View>: View {
    public let spacing: CGFloat
    @ViewBuilder public let content: () -> Content

    public init(spacing: CGFloat = 12, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        content()
    }
}

/// Interactive Liquid Glass press bounce and luminous lift (WWDC25 Session 284, 17:24 & 19:15).
public struct LiquidGlassInteractiveBounceStyle: ButtonStyle {
    public let scaleOnPress: CGFloat

    public init(scale: CGFloat = 0.94) {
        self.scaleOnPress = scale
    }

    public init(scaleOnPress: CGFloat) {
        self.scaleOnPress = scaleOnPress
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleOnPress : 1.0)
            .brightness(configuration.isPressed ? 0.06 : 0.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.70), value: configuration.isPressed)
    }
}

/// UIKit UIVisualEffectView bridge that activates native UIGlassEffect when available at runtime,
/// with real-time systemUltraThinMaterial backdrop blur fallback.
public struct UIGlassVisualEffectRepresentable: UIViewRepresentable {
    public let cornerRadius: CGFloat
    public let isInteractive: Bool

    public init(cornerRadius: CGFloat = 24, isInteractive: Bool = true) {
        self.cornerRadius = cornerRadius
        self.isInteractive = isInteractive
    }

    public func makeUIView(context: Context) -> UIVisualEffectView {
        let effect = Self.makePreferredEffect(isInteractive: isInteractive)
        let view = UIVisualEffectView(effect: effect)
        view.backgroundColor = .clear
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }

    public func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.layer.cornerRadius = cornerRadius
        uiView.layer.cornerCurve = .continuous
        uiView.clipsToBounds = true
    }

    private static func makePreferredEffect(isInteractive: Bool) -> UIVisualEffect {
        if let glassClass = NSClassFromString("UIGlassEffect") as? NSObject.Type {
            let instance = glassClass.init()
            if isInteractive, instance.responds(to: NSSelectorFromString("setInteractive:")) {
                instance.setValue(true, forKey: "interactive")
            }
            if let visualEffect = instance as? UIVisualEffect {
                return visualEffect
            }
        }
        return UIBlurEffect(style: .systemUltraThinMaterial)
    }
}

public struct LiquidGlassModifier: ViewModifier {
    public let cornerRadius: CGFloat
    public let glassMode: GlassMode
    public let refractionIntensity: Double
    public let tintColor: Color
    public let isProminent: Bool
    public let variant: LiquidGlassVariant

    public init(
        cornerRadius: CGFloat,
        glassMode: GlassMode,
        refractionIntensity: Double,
        tintColor: Color,
        isProminent: Bool,
        variant: LiquidGlassVariant = .regular
    ) {
        self.cornerRadius = cornerRadius
        self.glassMode = glassMode
        self.refractionIntensity = refractionIntensity
        self.tintColor = tintColor
        self.isProminent = isProminent
        self.variant = isProminent ? .prominent : variant
    }

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
                .clipShape(shape)
                .overlay(
                    shape.strokeBorder(
                        Color.white.opacity(0.16),
                        lineWidth: 0.8
                    )
                )

        case .frosted:
            content
                .background(
                    ZStack {
                        shape.fill(variant == .ultraClear ? .ultraThinMaterial : .thinMaterial)
                        if isProminent {
                            shape.fill(tintColor.opacity(0.86))
                        } else if variant == .tinted {
                            shape.fill(tintColor.opacity(0.16))
                        } else {
                            shape.fill(tintColor.opacity(0.06))
                        }
                    }
                )
                .clipShape(shape)
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.38),
                                Color.white.opacity(0.08),
                                tintColor.opacity(0.24)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.85
                    )
                )

        case .liquidGlass:
            liquidGlassBody(content: content, shape: shape)
        }
    }

    @ViewBuilder
    private func liquidGlassBody(content: Content, shape: RoundedRectangle) -> some View {
        let clampedRefraction = min(1.0, max(0.0, refractionIntensity))
        let tintOpacity: Double = {
            switch variant {
            case .ultraClear: return 0.06 * clampedRefraction
            case .regular: return 0.13 * clampedRefraction
            case .tinted: return 0.24 * clampedRefraction
            case .prominent: return 0.88
            }
        }()

        content
            .background(
                ZStack {
                    // 1. Real-time translucent backdrop blur (UIGlassEffect / ultraThinMaterial)
                    shape.fill(.ultraThinMaterial)

                    // 2. Optical refractive lens tint & chromatic dispersion wash
                    if isProminent || variant == .prominent {
                        shape.fill(
                            LinearGradient(
                                colors: [
                                    tintColor.opacity(0.94),
                                    tintColor.opacity(0.76)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    } else {
                        shape.fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.16 * clampedRefraction),
                                    tintColor.opacity(tintOpacity),
                                    Color(red: 0.04, green: 0.68, blue: 0.82).opacity(0.06 * clampedRefraction),
                                    Color.white.opacity(0.04 * clampedRefraction)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }

                    // 3. Top-edge curved liquid meniscus specular reflection
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isProminent ? 0.36 : (0.34 * max(0.35, clampedRefraction))),
                                Color.white.opacity(0.06 * clampedRefraction),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 18)
                        Spacer(minLength: 0)
                    }
                }
                .clipShape(shape)
            )
            .clipShape(shape)
            .overlay(
                // 4. Prismatic specular edge reflection rim
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isProminent ? 0.62 : (0.48 * max(0.4, clampedRefraction))),
                            tintColor.opacity(0.38 * max(0.4, clampedRefraction)),
                            Color.white.opacity(0.10),
                            Color(red: 0.15, green: 0.85, blue: 0.72).opacity(0.28 * clampedRefraction)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.95
                )
            )
            .shadow(color: Color.black.opacity(0.26), radius: 14, x: 0, y: 7)
    }
}

public extension View {
    func liquidGlassSurface(
        cornerRadius: CGFloat = 24,
        glassMode: GlassMode = .liquidGlass,
        refractionIntensity: Double = 0.82,
        tintColor: Color = Color(red: 0.063, green: 0.725, blue: 0.506),
        isProminent: Bool = false,
        variant: LiquidGlassVariant = .regular
    ) -> some View {
        modifier(
            LiquidGlassModifier(
                cornerRadius: cornerRadius,
                glassMode: glassMode,
                refractionIntensity: refractionIntensity,
                tintColor: tintColor,
                isProminent: isProminent,
                variant: variant
            )
        )
    }
}

/// Thumbless Liquid Glass Slider with rubber-band stretching, momentum preservation,
/// optional tick marks, and optional neutral-value anchor (WWDC25 Session 284, 17:24).
public struct LiquidGlassThumblessSlider: View {
    @Binding public var value: Double
    public let range: ClosedRange<Double>
    public let neutralValue: Double?
    public let tickCount: Int
    public let restingHeight: CGFloat
    public let activeHeight: CGFloat
    public let fillColor: Color
    public let trackColor: Color
    public let enableMomentum: Bool
    public let onEditingChanged: (Bool, Double) -> Void

    @State private var isDragging: Bool = false
    @State private var dragStartValue: Double = 0.0
    @State private var overscrollStretch: CGFloat = 0.0

    public init(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        neutralValue: Double? = nil,
        tickCount: Int = 0,
        restingHeight: CGFloat = 6,
        activeHeight: CGFloat = 12,
        fillColor: Color = .white,
        trackColor: Color = Color.white.opacity(0.22),
        enableMomentum: Bool = true,
        onEditingChanged: @escaping (Bool, Double) -> Void = { _, _ in }
    ) {
        self._value = value
        self.range = range
        self.neutralValue = neutralValue
        self.tickCount = tickCount
        self.restingHeight = restingHeight
        self.activeHeight = activeHeight
        self.fillColor = fillColor
        self.trackColor = trackColor
        self.enableMomentum = enableMomentum
        self.onEditingChanged = onEditingChanged
    }

    private var span: Double {
        max(0.0001, range.upperBound - range.lowerBound)
    }

    private var normalizedValue: Double {
        min(1.0, max(0.0, (value - range.lowerBound) / span))
    }

    public var body: some View {
        GeometryReader { geo in
            let width = max(1.0, geo.size.width)
            let barHeight = isDragging ? activeHeight : restingHeight
            let stretchMagnitude = min(18.0, abs(overscrollStretch))
            let scaleX = 1.0 + (stretchMagnitude / width) * 0.45
            let scaleY = max(0.76, 1.0 - (stretchMagnitude / 90.0))
            let anchor: UnitPoint = overscrollStretch < 0 ? .trailing : .leading

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)
                    .frame(height: barHeight)

                if tickCount > 1 {
                    HStack(spacing: 0) {
                        ForEach(0..<tickCount, id: \.self) { idx in
                            Circle()
                                .fill(Color.white.opacity(0.35))
                                .frame(width: 3, height: 3)
                            if idx < tickCount - 1 {
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                }

                if let neutral = neutralValue {
                    let neutralNorm = min(1.0, max(0.0, (neutral - range.lowerBound) / span))
                    let startNorm = min(neutralNorm, normalizedValue)
                    let endNorm = max(neutralNorm, normalizedValue)
                    let fillWidth = max(barHeight * 0.5, CGFloat(endNorm - startNorm) * width)
                    Capsule()
                        .fill(fillColor)
                        .frame(width: fillWidth, height: barHeight)
                        .offset(x: CGFloat(startNorm) * width)
                } else {
                    Capsule()
                        .fill(fillColor)
                        .frame(
                            width: max(barHeight * 0.5, width * CGFloat(normalizedValue)),
                            height: barHeight
                        )
                }
            }
            .scaleEffect(x: scaleX, y: scaleY, anchor: anchor)
            .offset(x: overscrollStretch * 0.25)
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let rawFraction = Double(gesture.location.x / width)
                        if rawFraction < 0.0 {
                            overscrollStretch = max(-24.0, CGFloat(rawFraction) * 32.0)
                        } else if rawFraction > 1.0 {
                            overscrollStretch = min(24.0, CGFloat(rawFraction - 1.0) * 32.0)
                        } else {
                            overscrollStretch = 0.0
                        }
                        let clampedFraction = min(1.0, max(0.0, rawFraction))
                        var candidate = range.lowerBound + clampedFraction * span
                        if tickCount > 1 {
                            let step = span / Double(tickCount - 1)
                            candidate = (candidate / step).rounded() * step
                        }
                        value = candidate
                        if !isDragging {
                            isDragging = true
                            dragStartValue = candidate
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                        onEditingChanged(true, candidate)
                    }
                    .onEnded { gesture in
                        let momentumDelta = enableMomentum
                            ? Double((gesture.predictedEndLocation.x - gesture.location.x) / width) * 0.18
                            : 0.0
                        let finalFraction = min(1.0, max(0.0, Double(gesture.location.x / width) + momentumDelta))
                        var finalValue = range.lowerBound + finalFraction * span
                        if tickCount > 1 {
                            let step = span / Double(tickCount - 1)
                            finalValue = (finalValue / step).rounded() * step
                        }
                        value = finalValue
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                            isDragging = false
                            overscrollStretch = 0.0
                        }
                        onEditingChanged(false, finalValue)
                    }
            )
            .animation(.spring(response: 0.24, dampingFraction: 0.74), value: isDragging)
        }
        .frame(height: max(activeHeight + 10, 22))
    }
}

/// Hardware-accelerated native SwiftUI Aurora Mesh backdrop that breathes with the active track's artwork palette
/// and reacts smoothly to real-time audio characteristics (Bass, Mid, High, and Overall energy).
public struct LiquidAuraBackgroundView: View {
    public let theme: SnoozyThemeColors
    public let palette: ArtworkPalette
    public let preferences: SnoozyPreferences
    public let isImmersivePlayer: Bool
    public let audioLevels: AudioReactiveLevels

    public init(
        theme: SnoozyThemeColors,
        palette: ArtworkPalette,
        preferences: SnoozyPreferences,
        isImmersivePlayer: Bool = false,
        audioLevels: AudioReactiveLevels = .zero
    ) {
        self.theme = theme
        self.palette = palette
        self.preferences = preferences
        self.isImmersivePlayer = isImmersivePlayer
        self.audioLevels = audioLevels
    }

    public var body: some View {
        if !preferences.auraBackdropEnabled || preferences.glassMode == .reduceTransparency {
            theme.background.ignoresSafeArea()
        } else {
            let reactiveActive = preferences.audioReactiveAuraEnabled && preferences.motionMode != .reduced
            let bass = reactiveActive ? audioLevels.bass : 0.0
            let mid = reactiveActive ? audioLevels.mid : 0.0
            let high = reactiveActive ? audioLevels.high : 0.0
            let overall = reactiveActive ? audioLevels.overall : 0.0

            let baseIntensity = isImmersivePlayer
                ? max(0.78, preferences.auraBackdropIntensity)
                : max(0.48, preferences.auraBackdropIntensity * 0.68)
            let effectiveIntensity = min(1.0, baseIntensity + overall * 0.24)

            TimelineView(.animation(minimumInterval: preferences.motionMode == .reduced ? 2.0 : 1.0 / 24.0)) { timeline in
                let t = preferences.motionMode == .reduced
                    ? 0.0
                    : timeline.date.timeIntervalSinceReferenceDate

                GeometryReader { proxy in
                    let w = max(1.0, proxy.size.width)
                    let h = max(1.0, proxy.size.height)

                    ZStack {
                        theme.background

                        // Orb 1: Primary Bass-Reactive Artwork Aura (expands and brightens with low frequencies)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        palette.primary.opacity(min(0.92, (0.52 + bass * 0.28) * effectiveIntensity)),
                                        palette.primary.opacity(min(0.48, (0.16 + bass * 0.14) * effectiveIntensity)),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 8,
                                    endRadius: w * CGFloat(0.78 + bass * 0.18)
                                )
                            )
                            .frame(width: w * 1.35, height: w * 1.35)
                            .scaleEffect(1.0 + CGFloat(bass * 0.24))
                            .offset(
                                x: -w * 0.24 + CGFloat(cos(t * 0.34)) * CGFloat(28.0 + bass * 22.0),
                                y: -h * 0.26 + CGFloat(sin(t * 0.40)) * CGFloat(24.0 + bass * 18.0)
                            )

                        // Orb 2: Secondary Mid-Frequency Fluid Wave Aura (subtle waves and fluid motion)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        palette.secondary.opacity(min(0.88, (0.44 + mid * 0.26) * effectiveIntensity)),
                                        theme.accent.opacity(min(0.46, (0.18 + mid * 0.14) * effectiveIntensity)),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: w * CGFloat(0.72 + mid * 0.16)
                                )
                            )
                            .frame(width: w * 1.25, height: w * 1.25)
                            .scaleEffect(x: 1.0 + CGFloat(mid * 0.18), y: 1.0 + CGFloat(bass * 0.10))
                            .offset(
                                x: w * 0.28 + CGFloat(sin(t * 0.29 + mid * 1.3)) * CGFloat(26.0 + mid * 28.0),
                                y: h * 0.04 + CGFloat(cos(t * 0.33 + mid * 1.1)) * CGFloat(30.0 + mid * 24.0)
                            )

                        // Orb 3: Tertiary Deep Aura & Overall Energy Expansion (illuminates floating Liquid Glass pill)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        palette.tertiary.opacity(min(0.86, (0.48 + overall * 0.24) * effectiveIntensity)),
                                        theme.accentStrong.opacity(min(0.45, (0.22 + bass * 0.14) * effectiveIntensity)),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 8,
                                    endRadius: w * CGFloat(0.75 + overall * 0.15)
                                )
                            )
                            .frame(width: w * 1.30, height: w * 1.30)
                            .scaleEffect(1.0 + CGFloat(overall * 0.16))
                            .offset(
                                x: CGFloat(sin(t * 0.24 + 1.2)) * CGFloat(32.0 + mid * 20.0),
                                y: h * 0.36 + CGFloat(cos(t * 0.35)) * CGFloat(20.0 + bass * 16.0)
                            )

                        // Orb 4: High-Frequency Specular Shimmer Highlight (finer visual details on treble/transients)
                        if high > 0.02 || isImmersivePlayer {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.white.opacity(min(0.34, (0.06 + high * 0.26) * effectiveIntensity)),
                                            palette.primary.opacity(min(0.42, (0.08 + high * 0.24) * effectiveIntensity)),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 4,
                                        endRadius: w * CGFloat(0.46 + high * 0.18)
                                    )
                                )
                                .frame(width: w * 0.92, height: w * 0.92)
                                .scaleEffect(0.92 + CGFloat(high * 0.28))
                                .offset(
                                    x: CGFloat(cos(t * 0.52 + high * 1.6)) * CGFloat(36.0 + high * 24.0),
                                    y: -h * 0.08 + CGFloat(sin(t * 0.48 + mid * 1.2)) * CGFloat(28.0 + high * 20.0)
                                )
                        }
                    }
                    .frame(width: w, height: h)
                    .clipped()
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
    public let expandsFullWidth: Bool
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    public let action: () -> Void

    public init(
        title: String,
        systemImage: String? = nil,
        isProminent: Bool = false,
        isDisabled: Bool = false,
        expandsFullWidth: Bool = false,
        theme: SnoozyThemeColors,
        preferences: SnoozyPreferences,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isProminent = isProminent
        self.isDisabled = isDisabled
        self.expandsFullWidth = expandsFullWidth
        self.theme = theme
        self.preferences = preferences
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .bold))
                }
                Text(title)
                    .font(SnoozyTypography.body(14, bold: true))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(isProminent ? theme.accentInk : theme.ink)
            .padding(.horizontal, expandsFullWidth ? 12 : 16)
            .frame(maxWidth: expandsFullWidth ? .infinity : nil)
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
        .buttonStyle(LiquidGlassInteractiveBounceStyle(scaleOnPress: 0.96))
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
        size: CGFloat = 42,
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
                .font(.system(size: size * 0.40, weight: .bold))
                .foregroundStyle(isActive ? theme.accentInk : theme.accent)
                .frame(width: size, height: size)
                .liquidGlassSurface(
                    cornerRadius: size * 0.5,
                    glassMode: preferences.glassMode,
                    refractionIntensity: preferences.refractionIntensity,
                    tintColor: theme.accent,
                    isProminent: isActive,
                    variant: .ultraClear
                )
        }
        .buttonStyle(LiquidGlassInteractiveBounceStyle(scaleOnPress: 0.92))
        .accessibilityLabel(accessibilityLabel)
    }
}

public struct AudioRoutePickerRepresentable: UIViewRepresentable {
    public let tintColor: UIColor
    public let activeTintColor: UIColor

    public init(tintColor: UIColor, activeTintColor: UIColor) {
        self.tintColor = tintColor
        self.activeTintColor = activeTintColor
    }

    public func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.backgroundColor = .clear
        picker.tintColor = tintColor
        picker.activeTintColor = activeTintColor
        picker.prioritizesVideoDevices = false
        return picker
    }

    public func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = tintColor
        uiView.activeTintColor = activeTintColor
    }
}
