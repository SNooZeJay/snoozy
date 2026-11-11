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

/// Groups multiple Liquid Glass controls so adjacent glass shapes can blend and morph together
/// (WWDC25 Session 284, 19:15: GlassEffectContainer / UIGlassContainerEffect).
public struct SnoozyGlassEffectContainer<Content: View>: View {
    public let spacing: CGFloat
    @ViewBuilder public let content: () -> Content

    public init(spacing: CGFloat = 12, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
        #else
        content()
        #endif
    }
}

/// Interactive Liquid Glass press bounce and luminous lift (WWDC25 Session 284, 17:24 & 19:15).
public struct LiquidGlassInteractiveBounceStyle: ButtonStyle {
    public let scaleOnPress: CGFloat

    public init(scaleOnPress: CGFloat = 1.05) {
        self.scaleOnPress = scaleOnPress
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleOnPress : 1.0)
            .brightness(configuration.isPressed ? 0.08 : 0.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.66), value: configuration.isPressed)
    }
}

/// UIKit UIVisualEffectView bridge that activates native UIGlassEffect on iOS 26/27 when available at runtime,
/// with animated materialization and ultraThinMaterial fallback (WWDC25 Session 284, 19:15).
public struct UIGlassVisualEffectRepresentable: UIViewRepresentable {
    public let cornerRadius: CGFloat
    public let isInteractive: Bool

    public init(cornerRadius: CGFloat = 24, isInteractive: Bool = true) {
        self.cornerRadius = cornerRadius
        self.isInteractive = isInteractive
    }

    public func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: nil)
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true

        let resolvedEffect = Self.makePreferredEffect(isInteractive: isInteractive)
        UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            view.effect = resolvedEffect
        }
        return view
    }

    public func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.layer.cornerRadius = cornerRadius
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
                .overlay(
                    shape.strokeBorder(
                        Color.white.opacity(0.14),
                        lineWidth: 0.75
                    )
                )

        case .frosted:
            content
                .background(
                    ZStack {
                        shape.fill(variant == .ultraClear ? .ultraThinMaterial : .thinMaterial)
                        if isProminent {
                            shape.fill(tintColor.opacity(0.84))
                        } else if variant == .tinted {
                            shape.fill(tintColor.opacity(0.16))
                        } else {
                            shape.fill(tintColor.opacity(0.06))
                        }
                    }
                )
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.36),
                                Color.white.opacity(0.08),
                                tintColor.opacity(0.22)
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
        let tintOpacity: Double = {
            switch variant {
            case .ultraClear: return 0.04 * refractionIntensity
            case .regular: return 0.10 * refractionIntensity
            case .tinted: return 0.22 * refractionIntensity
            case .prominent: return 0.86
            }
        }()

        content
            .background(
                GeometryReader { proxy in
                    ZStack {
                        UIGlassVisualEffectRepresentable(cornerRadius: cornerRadius, isInteractive: true)
                        if isProminent || variant == .prominent {
                            shape.fill(
                                LinearGradient(
                                    colors: [
                                        tintColor.opacity(0.92),
                                        tintColor.opacity(0.74)
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
                                        tintColor.opacity(tintOpacity),
                                        Color.white.opacity(0.03)
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
                                            Color.white.opacity(0.46 * refractionIntensity),
                                            Color.white.opacity(0.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: min(15, proxy.size.height * 0.30))
                                .padding(.horizontal, max(6, cornerRadius * 0.42))
                                .padding(.top, 1.0)
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
                            Color.white.opacity(0.54),
                            tintColor.opacity(0.36),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.40),
                            Color.white.opacity(0.54)
                        ],
                        center: .center
                    ),
                    lineWidth: 0.9
                )
            )
            .shadow(color: Color.black.opacity(0.22), radius: 14, x: 0, y: 7)
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
    public let onEditingChanged: (Bool) -> Void
    public let onCommit: (Double) -> Void

    @State private var isDragging: Bool = false
    @State private var dragStartValue: Double = 0.0
    @State private var overscrollStretch: CGFloat = 0.0

    public init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        neutralValue: Double? = nil,
        tickCount: Int = 0,
        restingHeight: CGFloat = 6,
        activeHeight: CGFloat = 12,
        fillColor: Color = .white,
        trackColor: Color = Color.white.opacity(0.22),
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
        onCommit: @escaping (Double) -> Void = { _ in }
    ) {
        self._value = value
        self.range = range
        self.neutralValue = neutralValue
        self.tickCount = tickCount
        self.restingHeight = restingHeight
        self.activeHeight = activeHeight
        self.fillColor = fillColor
        self.trackColor = trackColor
        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
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
                        if !isDragging {
                            isDragging = true
                            dragStartValue = value
                            onEditingChanged(true)
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
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
                    }
                    .onEnded { gesture in
                        // Preserve horizontal momentum on release (WWDC25 Session 284, 17:24)
                        let momentumDelta = Double((gesture.predictedEndLocation.x - gesture.location.x) / width) * 0.18
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
                        onEditingChanged(false)
                        onCommit(finalValue)
                    }
            )
            .animation(.spring(response: 0.24, dampingFraction: 0.74), value: isDragging)
        }
        .frame(height: max(activeHeight + 10, 22))
    }
}

public struct LiquidAuraBackgroundView: View {
    public let theme: SnoozyThemeColors
    public let palette: ArtworkPalette
    public let preferences: SnoozyPreferences
    public let isImmersivePlayer: Bool

    public init(
        theme: SnoozyThemeColors,
        palette: ArtworkPalette,
        preferences: SnoozyPreferences,
        isImmersivePlayer: Bool = false
    ) {
        self.theme = theme
        self.palette = palette
        self.preferences = preferences
        self.isImmersivePlayer = isImmersivePlayer
    }

    public var body: some View {
        if !preferences.auraBackdropEnabled || preferences.glassMode == .reduceTransparency {
            theme.background.ignoresSafeArea()
        } else {
            let effectiveIntensity = isImmersivePlayer
                ? max(0.72, preferences.auraBackdropIntensity)
                : (preferences.auraBackdropIntensity * 0.36)
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
                                .float(effectiveIntensity),
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
        .buttonStyle(LiquidGlassInteractiveBounceStyle(scaleOnPress: 1.04))
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
        .buttonStyle(LiquidGlassInteractiveBounceStyle(scaleOnPress: 1.08))
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
