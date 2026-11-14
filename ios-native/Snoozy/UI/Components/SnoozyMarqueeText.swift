import SwiftUI

public enum SnoozyMarqueeMath {
    public static func shouldScroll(contentWidth: CGFloat, availableWidth: CGFloat) -> Bool {
        guard contentWidth > 0, availableWidth > 0 else { return false }
        return contentWidth > availableWidth + 0.5
    }

    public static func loopDuration(contentWidth: CGFloat, gap: CGFloat, speed: CGFloat) -> Double? {
        guard contentWidth > 0, speed > 0 else { return nil }
        return Double((contentWidth + gap) / speed)
    }
}

/// One-line text that loops horizontally only when it cannot fit its container.
public struct SnoozyMarqueeText: View {
    private let text: String
    private let font: Font
    private let color: Color
    private let speed: CGFloat
    private let gap: CGFloat

    public init(
        _ text: String,
        font: Font,
        color: Color,
        speed: CGFloat = 30,
        gap: CGFloat = 32
    ) {
        self.text = text
        self.font = font
        self.color = color
        self.speed = speed
        self.gap = gap
    }

    public var body: some View {
        MarqueeLine(text: text, font: font, color: color, speed: speed, gap: gap)
            .id(text)
    }
}

private struct MarqueeLine: View {
    let text: String
    let font: Font
    let color: Color
    let speed: CGFloat
    let gap: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentWidth: CGFloat = 0
    @State private var animate = false
    @State private var delayTask: Task<Void, Never>?

    var body: some View {
        Group {
            if reduceMotion {
                Text(text)
                    .font(font)
                    .foregroundStyle(color)
                    .lineLimit(1)
            } else {
                marqueeBody
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    private var marqueeBody: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .hidden()
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    marqueeContent(availableWidth: proxy.size.width)
                }
            }
    }

    private func marqueeContent(availableWidth: CGFloat) -> some View {
        let overflows = SnoozyMarqueeMath.shouldScroll(
            contentWidth: contentWidth,
            availableWidth: availableWidth
        )

        return HStack(spacing: gap) {
            label
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: SnoozyMarqueeWidthKey.self,
                            value: proxy.size.width
                        )
                    }
                )

            if overflows && !reduceMotion {
                label.accessibilityHidden(true)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(width: availableWidth, alignment: .leading)
        .offset(x: animate && overflows && !reduceMotion ? -(contentWidth + gap) : 0)
        .clipped()
        .onPreferenceChange(SnoozyMarqueeWidthKey.self) { width in
            contentWidth = width
            restart(
                shouldAnimate: SnoozyMarqueeMath.shouldScroll(
                    contentWidth: width,
                    availableWidth: availableWidth
                ),
                width: width
            )
        }
        .onDisappear {
            stop()
        }
    }

    private var label: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func restart(shouldAnimate: Bool, width: CGFloat) {
        stop()
        guard shouldAnimate,
              !reduceMotion,
              let duration = SnoozyMarqueeMath.loopDuration(
                  contentWidth: width,
                  gap: gap,
                  speed: speed
              ) else {
            return
        }

        delayTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }

    private func stop() {
        delayTask?.cancel()
        delayTask = nil
        animate = false
    }
}

private struct SnoozyMarqueeWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
