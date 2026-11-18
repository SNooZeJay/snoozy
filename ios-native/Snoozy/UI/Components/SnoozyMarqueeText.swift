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

    /// Horizontal travel after `elapsed` seconds, wrapping cleanly at the loop boundary.
    public static func loopOffset(
        elapsed: Double,
        contentWidth: CGFloat,
        gap: CGFloat,
        speed: CGFloat
    ) -> CGFloat {
        guard elapsed > 0,
              let duration = loopDuration(contentWidth: contentWidth, gap: gap, speed: speed),
              duration > 0 else {
            return 0
        }
        return CGFloat(elapsed.truncatingRemainder(dividingBy: duration) * Double(speed))
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
    @State private var startedAt = Date()

    private static let startDelay: Double = 1.2

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

        return Group {
            if overflows {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    scrollingRow(availableWidth: availableWidth, date: timeline.date)
                }
            } else {
                HStack(spacing: gap) {
                    label
                }
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: availableWidth, alignment: .leading)
                .clipped()
            }
        }
        .onPreferenceChange(SnoozyMarqueeWidthKey.self) { width in
            guard abs(width - contentWidth) > 0.5 else { return }
            contentWidth = width
            startedAt = Date()
        }
    }

    private func scrollingRow(availableWidth: CGFloat, date: Date) -> some View {
        let elapsed = max(0, date.timeIntervalSince(startedAt) - Self.startDelay)
        let offset = SnoozyMarqueeMath.loopOffset(
            elapsed: elapsed,
            contentWidth: contentWidth,
            gap: gap,
            speed: speed
        )

        return HStack(spacing: gap) {
            label
            label.accessibilityHidden(true)
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(width: availableWidth, alignment: .leading)
        .offset(x: -offset)
        .clipped()
    }

    private var label: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: SnoozyMarqueeWidthKey.self,
                        value: proxy.size.width
                    )
                }
            )
    }
}

private struct SnoozyMarqueeWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
