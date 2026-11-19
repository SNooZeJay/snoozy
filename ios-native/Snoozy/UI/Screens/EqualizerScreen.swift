import SwiftUI

public struct EqualizerScreen: View {
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors
    @Environment(\.dismiss) private var dismiss

    @State private var enabled: Bool
    @State private var gains: [Double]
    @State private var preamp: Double
    @State private var customPresets: [EqualizerPreset]
    @State private var pendingAction: PresetAction? = nil
    @State private var presetName: String = ""
    @State private var showNameAlert: Bool = false
    @State private var pendingDeleteId: String? = nil

    private enum PresetAction: Equatable {
        case save
        case rename(String)

        var title: String {
            switch self {
            case .save: return "Save Preset"
            case .rename: return "Rename Preset"
            }
        }
    }

    public init(
        repository: LibraryRepository,
        playback: PlaybackController,
        theme: SnoozyThemeColors
    ) {
        self.repository = repository
        self.playback = playback
        self.theme = theme
        let prefs = repository.preferences
        _enabled = State(initialValue: prefs.equalizerEnabled)
        _gains = State(initialValue: EqualizerLogic.sanitizedGains(prefs.equalizerBandGains))
        _preamp = State(initialValue: EqualizerLogic.sanitizedPreamp(prefs.equalizerPreampDb))
        _customPresets = State(initialValue: prefs.equalizerCustomPresets)
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Ten parametric bands from 31 Hz to 16 kHz. Changes apply to playback immediately and are saved when you finish dragging.")
                        .font(SnoozyTypography.footnote(13))
                        .foregroundStyle(theme.inkMuted)
                        .padding(.horizontal, 4)

                    equalizerToggleCard
                    bandsCard
                    preampCard
                    presetsCard

                    LiquidGlassButton(
                        title: "Reset Equalizer",
                        systemImage: "arrow.counterclockwise",
                        expandsFullWidth: true,
                        theme: theme,
                        preferences: repository.preferences,
                        action: { reset() }
                    )
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Equalizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        persist()
                        dismiss()
                    }
                    .font(SnoozyTypography.body(15, bold: true))
                    .foregroundStyle(theme.accent)
                }
            }
            .alert(pendingAction?.title ?? "Save Preset", isPresented: $showNameAlert) {
                TextField("Preset name", text: $presetName)
                Button("Save") { commitPresetName() }
                Button("Cancel", role: .cancel) { pendingAction = nil }
            } message: {
                Text("The current band gains are stored as a custom preset.")
            }
            .alert("Delete Preset?", isPresented: Binding(
                get: { pendingDeleteId != nil },
                set: { if !$0 { pendingDeleteId = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let id = pendingDeleteId {
                        customPresets = EqualizerLogic.deleting(customPresets, id: id)
                        persist()
                    }
                    pendingDeleteId = nil
                }
                Button("Cancel", role: .cancel) { pendingDeleteId = nil }
            } message: {
                Text("This custom preset will be removed. Your current gains stay unchanged.")
            }
        }
    }

    // MARK: - Cards

    private var equalizerToggleCard: some View {
        SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
            Toggle(
                isOn: Binding(
                    get: { enabled },
                    set: { newValue in
                        enabled = newValue
                        playback.previewEqualizer(enabled: newValue, gainsDb: gains, preampDb: preamp)
                        persist()
                    }
                )
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Equalizer")
                        .font(SnoozyTypography.body(15, bold: true))
                        .foregroundStyle(theme.ink)
                    Text("Bypasses all bands and the preamp when off.")
                        .font(SnoozyTypography.caption(11))
                        .foregroundStyle(theme.inkMuted)
                }
            }
            .tint(theme.accent)
            .padding(.horizontal, 16)
            .frame(minHeight: 58)
        }
    }

    private var bandsCard: some View {
        SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(0..<EqualizerBands.count, id: \.self) { index in
                    VStack(spacing: 6) {
                        Text(gainText(gains[index]))
                            .font(SnoozyTypography.caption(10, bold: true))
                            .foregroundStyle(gains[index] == 0 ? theme.inkFaint : theme.accent)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        EqualizerBandSlider(
                            gain: Binding(
                                get: { gains[index] },
                                set: { value in
                                    gains[index] = value
                                    applyPreview()
                                }
                            ),
                            theme: theme,
                            label: EqualizerBands.labels[index],
                            isEnabled: enabled,
                            onEditingEnded: { persist() }
                        )

                        Text(EqualizerBands.labels[index])
                            .font(SnoozyTypography.caption(10, bold: true))
                            .foregroundStyle(theme.inkMuted)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 14)
        }
    }

    private var preampCard: some View {
        SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
            VStack(spacing: 8) {
                HStack {
                    Text("Preamp")
                        .font(SnoozyTypography.body(15, bold: true))
                        .foregroundStyle(theme.ink)
                    Spacer()
                    Text(preampText)
                        .font(SnoozyTypography.caption(12, bold: true))
                        .foregroundStyle(theme.accent)
                        .monospacedDigit()
                }

                Slider(
                    value: Binding(
                        get: { preamp },
                        set: { value in
                            preamp = value
                            applyPreview()
                        }
                    ),
                    in: EqualizerBands.minPreampDb...EqualizerBands.maxPreampDb,
                    step: 0.5,
                    onEditingChanged: { editing in
                        if !editing { persist() }
                    }
                )
                .tint(theme.accent)
                .accessibilityLabel("Preamp")
                .accessibilityValue(preampText)

                HStack {
                    Text("Band boosts are offset automatically; the limiter catches peaks.")
                        .font(SnoozyTypography.caption(11))
                        .foregroundStyle(theme.inkMuted)
                    Spacer()
                    Text("\(String(format: "%+.1f", effectivePreamp)) dB")
                        .font(SnoozyTypography.caption(11, bold: true))
                        .foregroundStyle(theme.inkFaint)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var presetsCard: some View {
        SnoozyGroupedCard(theme: theme, preferences: repository.preferences) {
            Menu {
                Section("Built-in") {
                    ForEach(EqualizerPreset.builtInPresets) { preset in
                        presetButton(preset)
                    }
                }
                if !customPresets.isEmpty {
                    Section("Custom") {
                        ForEach(customPresets) { preset in
                            presetButton(preset)
                        }
                    }
                }
            } label: {
                HStack {
                    Text("Preset")
                        .font(SnoozyTypography.body(15, bold: true))
                        .foregroundStyle(theme.ink)
                    Spacer()
                    Text(matchedPreset?.name ?? "Custom")
                        .font(SnoozyTypography.body(14, bold: true))
                        .foregroundStyle(theme.accent)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 50)
                .contentShape(Rectangle())
            }

            rowDivider

            Button {
                presetName = matchedPreset?.isBuiltIn == false ? (matchedPreset?.name ?? "") : ""
                pendingAction = .save
                showNameAlert = true
            } label: {
                HStack {
                    Text("Save as Custom Preset")
                        .font(SnoozyTypography.body(15, bold: true))
                        .foregroundStyle(theme.ink)
                    Spacer()
                    Image(systemName: "plus.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let custom = matchedCustomPreset {
                rowDivider

                Button {
                    presetName = custom.name
                    pendingAction = .rename(custom.id)
                    showNameAlert = true
                } label: {
                    HStack {
                        Text("Rename \"\(custom.name)\"")
                            .font(SnoozyTypography.body(15, bold: true))
                            .foregroundStyle(theme.ink)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.accent)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                rowDivider

                Button {
                    pendingDeleteId = custom.id
                } label: {
                    HStack {
                        Text("Delete \"\(custom.name)\"")
                            .font(SnoozyTypography.body(15, bold: true))
                            .foregroundStyle(theme.danger)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.danger)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func presetButton(_ preset: EqualizerPreset) -> some View {
        Button {
            gains = EqualizerLogic.sanitizedGains(preset.gainsDb)
            applyPreview()
            persist()
        } label: {
            HStack {
                Text(preset.name)
                if matchedPreset?.id == preset.id {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    // MARK: - State helpers

    private var matchedPreset: EqualizerPreset? {
        EqualizerLogic.preset(
            matching: gains,
            in: EqualizerPreset.builtInPresets + customPresets
        )
    }

    private var matchedCustomPreset: EqualizerPreset? {
        guard let matchedPreset, !matchedPreset.isBuiltIn else { return nil }
        return matchedPreset
    }

    private var effectivePreamp: Double {
        EqualizerLogic.effectivePreampDb(userPreampDb: preamp, gainsDb: gains)
    }

    private var preampText: String {
        String(format: "%+.1f dB", preamp)
    }

    private func gainText(_ gain: Double) -> String {
        String(format: "%+.1f", gain)
    }

    private func applyPreview() {
        playback.previewEqualizer(enabled: enabled, gainsDb: gains, preampDb: preamp)
    }

    private func persist() {
        repository.updatePreferences { prefs in
            prefs.equalizerEnabled = enabled
            prefs.equalizerBandGains = EqualizerLogic.sanitizedGains(gains)
            prefs.equalizerPreampDb = EqualizerLogic.sanitizedPreamp(preamp)
            prefs.equalizerCustomPresets = customPresets
        }
    }

    private func commitPresetName() {
        switch pendingAction {
        case .some(.save):
            customPresets = EqualizerLogic.upsertingPreset(
                customPresets,
                name: presetName,
                gainsDb: gains
            )
        case .some(.rename(let id)):
            customPresets = EqualizerLogic.renaming(customPresets, id: id, to: presetName)
        case .none:
            break
        }
        pendingAction = nil
        persist()
    }

    private func reset() {
        gains = EqualizerLogic.sanitizedGains([])
        preamp = 0.0
        applyPreview()
        persist()
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(theme.isDark ? 0.08 : 0.14))
            .frame(height: 0.5)
            .padding(.leading, 16)
    }
}

private struct EqualizerBandSlider: View {
    @Binding var gain: Double
    let theme: SnoozyThemeColors
    let label: String
    let isEnabled: Bool
    let onEditingEnded: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let height = max(1, proxy.size.height)
            let usable = max(1, height / 2 - 10)
            let fraction = CGFloat(gain / EqualizerBands.maxGainDb)
            let thumbY = height / 2 - fraction * usable

            ZStack {
                Capsule()
                    .fill(Color.white.opacity(theme.isDark ? 0.10 : 0.18))
                    .frame(width: 3)

                Rectangle()
                    .fill(theme.inkFaint.opacity(0.35))
                    .frame(width: 12, height: 1)

                Capsule()
                    .fill(theme.accent)
                    .frame(width: 3, height: max(0, abs(fraction) * usable))
                    .offset(y: fraction >= 0 ? -abs(fraction) * usable / 2 : abs(fraction) * usable / 2)

                Circle()
                    .fill(theme.accent)
                    .frame(width: 16, height: 16)
                    .shadow(color: theme.accent.opacity(0.45), radius: 4)
                    .position(x: proxy.size.width / 2, y: thumbY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let normalized = 1 - min(1, max(0, value.location.y / height))
                        gain = Double(normalized * 2 - 1) * EqualizerBands.maxGainDb
                    }
                    .onEnded { _ in onEditingEnded() }
            )
            .opacity(isEnabled ? 1.0 : 0.45)
        }
        .frame(width: 30, height: 150)
        .accessibilityElement()
        .accessibilityLabel("\(label) hertz band gain")
        .accessibilityValue(Text(String(format: "%+.1f decibels", gain)))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                gain = min(EqualizerBands.maxGainDb, gain + 1)
                onEditingEnded()
            case .decrement:
                gain = max(EqualizerBands.minGainDb, gain - 1)
                onEditingEnded()
            @unknown default:
                break
            }
        }
    }
}
