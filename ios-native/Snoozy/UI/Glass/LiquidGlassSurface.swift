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
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
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
        if #available(iOS 26.0, *) {
            content
                .glassEffect(nativeGlass, in: shape)
                .overlay(specularRim(shape: shape))
                .shadow(
                    color: Color.black.opacity(variant == .ultraClear ? 0.24 : (isProminent ? 0.18 : 0.08)),
                    radius: variant == .ultraClear ? 14 : (isProminent ? 8 : 4),
                    x: 0,
                    y: variant == .ultraClear ? 6 : 2
                )
        } else {
            content
                .background(materialGlassBackground(shape: shape))
                .clipShape(shape)
                .overlay(specularRim(shape: shape))
                .shadow(
                    color: Color.black.opacity(variant == .ultraClear ? 0.24 : (isProminent ? 0.18 : 0.08)),
                    radius: variant == .ultraClear ? 14 : (isProminent ? 8 : 4),
                    x: 0,
                    y: variant == .ultraClear ? 6 : 2
                )
        }
    }

    @available(iOS 26.0, *)
    private var nativeGlass: Glass {
        if isProminent || variant == .prominent || variant == .tinted {
            return .regular.tint(tintColor).interactive()
        }
        return .regular.interactive()
    }

    private func materialGlassBackground(shape: RoundedRectangle) -> some View {
        let clampedRefraction = min(1.0, max(0.0, refractionIntensity))

        return ZStack {
            if isProminent || variant == .prominent {
                // Prominent accent capsule (for example, Play button or active filter pill)
                shape.fill(
                    LinearGradient(
                        colors: [
                            tintColor.opacity(0.95),
                            tintColor.opacity(0.84)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
            } else if variant == .ultraClear {
                // Floating optical surface (used by Main Navigation Bar, Mini Player, and Header Icon Pills)
                shape.fill(.ultraThinMaterial)
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.07 * max(0.4, clampedRefraction)),
                            Color.black.opacity(0.14),
                            tintColor.opacity(0.03 * clampedRefraction)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            } else {
                // Selective inline control surface (Search bar, secondary action buttons, cards)
                shape.fill(Color(UIColor.secondarySystemGroupedBackground).opacity(0.82))
                shape.fill(.ultraThinMaterial.opacity(0.55))
                if variant == .tinted {
                    shape.fill(tintColor.opacity(0.10 * clampedRefraction))
                }
            }
        }
    }

    private func specularRim(shape: RoundedRectangle) -> some View {
        // Crisp, physical 1px-thin neutral specular rim (matches the main navigation bar)
        shape.strokeBorder(
            LinearGradient(
                colors: isProminent
                    ? [
                        Color.white.opacity(0.46),
                        Color.white.opacity(0.12)
                    ]
                    : [
                        Color.white.opacity(variant == .ultraClear ? 0.34 : 0.18),
                        Color.white.opacity(variant == .ultraClear ? 0.07 : 0.05),
                        Color.white.opacity(variant == .ultraClear ? 0.18 : 0.09)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: variant == .ultraClear ? 0.85 : 0.65
        )
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

/// Reference instant for the aura shader clock, so float uniforms keep sub-frame precision.
private let liquidAuraEpoch = Date.timeIntervalSinceReferenceDate

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
            let levels = reactiveActive ? audioLevels : .zero

            let baseIntensity = isImmersivePlayer
                ? max(0.76, preferences.auraBackdropIntensity)
                : min(0.26, preferences.auraBackdropIntensity * 0.28)
            let intensity = isImmersivePlayer
                ? min(1.0, baseIntensity + levels.overall * 0.24)
                : min(0.32, baseIntensity + levels.overall * 0.08)

            if isImmersivePlayer && preferences.motionMode != .reduced {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                    auraField(
                        time: timeline.date.timeIntervalSinceReferenceDate - liquidAuraEpoch,
                        intensity: intensity,
                        levels: levels
                    )
                }
            } else {
                auraField(time: 0.0, intensity: intensity, levels: levels)
            }
        }
    }

    private func auraField(time: Double, intensity: Double, levels: AudioReactiveLevels) -> some View {
        GeometryReader { proxy in
            let w = max(1.0, proxy.size.width)
            let h = max(1.0, proxy.size.height)

            Rectangle()
                .fill(theme.background)
                .frame(width: w, height: h)
                .colorEffect(
                    ShaderLibrary.liquidAuraBackdrop(
                        .float2(Float(w), Float(h)),
                        .float(Float(time)),
                        .float(Float(intensity)),
                        .float(isImmersivePlayer ? 0.36 : 0.42),
                        .float(Float(levels.bass)),
                        .float(Float(levels.mid)),
                        .float(Float(levels.high)),
                        .float(Float(levels.overall)),
                        .color(palette.primary),
                        .color(palette.secondary),
                        .color(palette.tertiary)
                    )
                )
        }
        .ignoresSafeArea()
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
