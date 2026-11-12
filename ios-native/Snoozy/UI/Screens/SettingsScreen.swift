import SwiftUI

public struct SettingsScreen: View {
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors
    public let onImportFiles: () -> Void
    public let onImportFolder: () -> Void

    @State private var showClearHistoryAlert: Bool = false
    @State private var showErrorLogSheet: Bool = false

    private static let speedChoices: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    public var body: some View {
        let prefs = repository.preferences
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 12) {
                    SnoozyBrandIconView(size: 40)

                    Text("Settings")
                        .font(SnoozyTypography.display(30))
                        .foregroundStyle(theme.ink)

                    Spacer()
                }

                playbackSection(prefs: prefs)
                librarySection(prefs: prefs)
                appearanceSection(prefs: prefs)
                audioAndEffectsSection(prefs: prefs)
                storageSection(prefs: prefs)
                aboutSection(prefs: prefs)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, playback.activeTrack != nil ? 176 : 112)
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Clear Listening History?", isPresented: $showClearHistoryAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                repository.clearRecentsAndHistory()
            }
        } message: {
            Text("Clears recently played songs, play counts, and listening sessions.")
        }
        .sheet(isPresented: $showErrorLogSheet) {
            DiagnosticsLogSheetView(
                repository: repository,
                theme: theme,
                preferences: prefs
            )
        }
    }

    // MARK: - 1. Playback

    private func playbackSection(prefs: SnoozyPreferences) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Playback", icon: "play.circle.fill")

            SnoozyGroupedCard(theme: theme, preferences: prefs) {
                HStack {
                    Text("Playback Speed")
                        .font(SnoozyTypography.body(15, bold: true))
                        .foregroundStyle(theme.ink)
                    Spacer()
                    Menu {
                        ForEach(Self.speedChoices, id: \.self) { rate in
                            Button {
                                playback.setSpeed(rate)
                            } label: {
                                HStack {
                                    Text(String(format: "%.2gx", rate))
                                    if abs(playback.playbackRate - rate) < 0.01 {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(String(format: "%.2gx", playback.playbackRate))
                                .font(SnoozyTypography.body(14, bold: true))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(theme.accent)
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)

                rowDivider

                Toggle(
                    isOn: Binding(
                        get: { playback.shuffle },
                        set: { newValue in
                            if playback.shuffle != newValue {
                                playback.toggleShuffle()
                            }
                        }
                    )
                ) {
                    Text("Shuffle")
                        .font(SnoozyTypography.body(15, bold: true))
                        .foregroundStyle(theme.ink)
                }
                .tint(theme.accent)
                .padding(.horizontal, 16)
                .frame(minHeight: 48)

                rowDivider

                HStack {
                    Text("Repeat")
                        .font(SnoozyTypography.body(15, bold: true))
                        .foregroundStyle(theme.ink)
                    Spacer()
                    Button {
                        playback.cycleRepeat()
                    } label: {
                        Text(playback.repeatMode.label)
                            .font(SnoozyTypography.body(14, bold: true))
                            .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)

                rowDivider

                Toggle(
                    isOn: Binding(
                        get: { prefs.hapticsEnabled },
                        set: { enabled in repository.updatePreferences { $0.hapticsEnabled = enabled } }
                    )
                ) {
                    Text("Haptics")
                        .font(SnoozyTypography.body(15, bold: true))
                        .foregroundStyle(theme.ink)
                }
                .tint(theme.accent)
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
            }
        }
    }

    // MARK: - 2. Library

    private func librarySection(prefs: SnoozyPreferences) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Library", icon: "folder.fill")

            SnoozyGroupedCard(theme: theme, preferences: prefs) {
                HStack(spacing: 8) {
                    LiquidGlassButton(
                        title: "Import Files",
                        systemImage: "doc.badge.plus",
                        isProminent: true,
                        theme: theme,
                        preferences: prefs,
                        action: onImportFiles
                    )
                    LiquidGlassButton(
                        title: "Import Folder",
                        systemImage: "folder.badge.plus",
                        theme: theme,
                        preferences: prefs,
                        action: onImportFolder
                    )
                    LiquidGlassIconButton(
                        systemImage: "arrow.clockwise",
                        accessibilityLabel: "Rescan library",
                        size: 46,
                        theme: theme,
                        preferences: prefs
                    ) {
                        Task { await repository.scanLibrary() }
                    }
                }
                .padding(12)

                rowDivider

                HStack {
                    Text("Sort Songs")
                        .font(SnoozyTypography.body(15, bold: true))
                        .foregroundStyle(theme.ink)
                    Spacer()
                    Menu {
                        ForEach(SongSort.allCases, id: \.self) { sort in
                            Button {
                                repository.setSongSort(sort)
                            } label: {
                                HStack {
                                    Text(sort.label)
                                    if repository.songSort == sort {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(repository.songSort.label)
                                .font(SnoozyTypography.body(14, bold: true))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(theme.accent)
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)

                rowDivider

                HStack {
                    Text("Sort Albums")
                        .font(SnoozyTypography.body(15, bold: true))
                        .foregroundStyle(theme.ink)
                    Spacer()
                    Menu {
                        ForEach(AlbumSort.allCases, id: \.self) { sort in
                            Button {
                                repository.setAlbumSort(sort)
                            } label: {
                                HStack {
                                    Text(sort.label)
                                    if repository.albumSort == sort {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(repository.albumSort.label)
                                .font(SnoozyTypography.body(14, bold: true))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(theme.accent)
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
            }
        }
    }

    // MARK: - 3. Appearance

    private func appearanceSection(prefs: SnoozyPreferences) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Appearance", icon: "paintpalette.fill")

            SnoozyGroupedCard(theme: theme, preferences: prefs) {
                HStack {
                    Text("Theme")
                        .font(SnoozyTypography.body(15, bold: true))
                        .foregroundStyle(theme.ink)
                    Spacer()
                    Picker(
                        "Theme",
                        selection: Binding(
                            get: { prefs.themeMode },
                            set: { mode in repository.updatePreferences { $0.themeMode = mode } }
                        )
                    ) {
                        ForEach(ThemeMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 196)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 50)

                rowDivider

                HStack {
                    Text("Accent Color")
                        .font(SnoozyTypography.body(15, bold: true))
                        .foregroundStyle(theme.ink)
                    Spacer()
                    Menu {
                        ForEach(PaletteSeed.allCases, id: \.self) { seed in
                            Button {
                                repository.updatePreferences { $0.paletteSeed = seed }
                            } label: {
                                HStack {
                                    Text(seed.label)
                                    if prefs.paletteSeed == seed {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(shortPaletteLabel(prefs.paletteSeed))
                                .font(SnoozyTypography.body(14, bold: true))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(theme.accent)
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)

                rowDivider

                HStack {
                    Text("Glass Style")
                        .font(SnoozyTypography.body(15, bold: true))
                        .foregroundStyle(theme.ink)
                    Spacer()
                    Menu {
                        ForEach(GlassMode.allCases, id: \.self) { mode in
                            Button {
                                repository.updatePreferences { $0.glassMode = mode }
                            } label: {
                                HStack {
                                    Text(shortGlassLabel(mode))
                                    if prefs.glassMode == mode {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(shortGlassLabel(prefs.glassMode))
                                .font(SnoozyTypography.body(14, bold: true))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(theme.accent)
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)

                if prefs.glassMode == .liquidGlass {
                    rowDivider

                    VStack(spacing: 6) {
                        HStack {
                            Text("Glass Refraction")
                                .font(SnoozyTypography.body(14, bold: true))
                                .foregroundStyle(theme.ink)
                            Spacer()
                            Text("\(Int((prefs.refractionIntensity * 100).rounded()))%")
                                .font(SnoozyTypography.caption(12, bold: true))
                                .foregroundStyle(theme.accent)
                        }
                        Slider(
                            value: Binding(
                                get: { prefs.refractionIntensity },
                                set: { val in repository.updatePreferences { $0.refractionIntensity = val } }
                            ),
                            in: 0.0...1.0
                        )
                        .tint(theme.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                rowDivider

                Toggle(
                    isOn: Binding(
                        get: { prefs.motionMode == .reduced },
                        set: { reduced in
                            repository.updatePreferences { $0.motionMode = reduced ? .reduced : .full }
                        }
                    )
                ) {
                    Text("Reduce Motion")
                        .font(SnoozyTypography.body(15, bold: true))
                        .foregroundStyle(theme.ink)
                }
                .tint(theme.accent)
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
            }
        }
    }

    // MARK: - 4. Audio & Effects

    private func audioAndEffectsSection(prefs: SnoozyPreferences) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Audio & Effects", icon: "waveform")

            SnoozyGroupedCard(theme: theme, preferences: prefs) {
                Toggle(
                    isOn: Binding(
                        get: { prefs.auraBackdropEnabled },
                        set: { enabled in repository.updatePreferences { $0.auraBackdropEnabled = enabled } }
                    )
                ) {
                    Text("Artwork Aura")
                        .font(SnoozyTypography.body(15, bold: true))
                        .foregroundStyle(theme.ink)
                }
                .tint(theme.accent)
                .padding(.horizontal, 16)
                .frame(minHeight: 48)

                if prefs.auraBackdropEnabled {
                    rowDivider

                    Toggle(
                        isOn: Binding(
                            get: { prefs.audioReactiveAuraEnabled },
                            set: { enabled in repository.updatePreferences { $0.audioReactiveAuraEnabled = enabled } }
                        )
                    ) {
                        Text("Audio-Reactive Visualizer")
                            .font(SnoozyTypography.body(15, bold: true))
                            .foregroundStyle(theme.ink)
                    }
                    .tint(theme.accent)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)

                    rowDivider

                    VStack(spacing: 6) {
                        HStack {
                            Text("Aura Intensity")
                                .font(SnoozyTypography.body(14, bold: true))
                                .foregroundStyle(theme.ink)
                            Spacer()
                            Text("\(Int((prefs.auraBackdropIntensity * 100).rounded()))%")
                                .font(SnoozyTypography.caption(12, bold: true))
                                .foregroundStyle(theme.accent)
                        }
                        Slider(
                            value: Binding(
                                get: { prefs.auraBackdropIntensity },
                                set: { val in repository.updatePreferences { $0.auraBackdropIntensity = val } }
                            ),
                            in: 0.1...1.0
                        )
                        .tint(theme.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    // MARK: - 5. Storage

    private func storageSection(prefs: SnoozyPreferences) -> some View {
        let totalListeningSeconds = repository.listeningSessions.reduce(Int64(0)) { $0 + $1.durationSeconds }
        return VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Storage", icon: "internaldrive.fill")

            SnoozyGroupedCard(theme: theme, preferences: prefs) {
                statRow(label: "Songs", value: "\(repository.tracks.count)", showDivider: false)
                statRow(label: "Albums", value: "\(repository.albums.count)", showDivider: true)
                statRow(label: "Playlists", value: "\(repository.playlists.count)", showDivider: true)
                statRow(label: "Favorites", value: "\(repository.favoriteTrackIds.count)", showDivider: true)
                statRow(label: "Listening Time", value: SnoozyFormat.formatDuration(Double(totalListeningSeconds)), showDivider: true)

                rowDivider

                Button {
                    showClearHistoryAlert = true
                } label: {
                    HStack {
                        Text("Clear Listening History")
                            .font(SnoozyTypography.body(15, bold: true))
                            .foregroundStyle(theme.danger)
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

    // MARK: - 6. About Snoozy

    private func aboutSection(prefs: SnoozyPreferences) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("About Snoozy", icon: "info.circle.fill")

            SnoozyGroupedCard(theme: theme, preferences: prefs) {
                statRow(label: "Version", value: "3.2.0", showDivider: false)
                statRow(label: "Mode", value: "100% Offline Local Player", showDivider: true)

                rowDivider

                Button {
                    showErrorLogSheet = true
                } label: {
                    HStack {
                        Text("Error Log")
                            .font(SnoozyTypography.body(15, bold: true))
                            .foregroundStyle(theme.ink)
                        Spacer()
                        Text("\(repository.errorLog.count)")
                            .font(SnoozyTypography.body(14, bold: true))
                            .foregroundStyle(theme.inkMuted)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.inkFaint)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.accent)
            Text(title)
                .font(SnoozyTypography.headline(15))
                .foregroundStyle(theme.inkMuted)
        }
        .padding(.horizontal, 4)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(theme.isDark ? 0.08 : 0.14))
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

    private func statRow(label: String, value: String, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            if showDivider {
                rowDivider
            }
            HStack {
                Text(label)
                    .font(SnoozyTypography.body(15, bold: false))
                    .foregroundStyle(theme.ink)
                Spacer()
                Text(value)
                    .font(SnoozyTypography.body(14, bold: true))
                    .foregroundStyle(theme.inkMuted)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 46)
        }
    }

    private func shortGlassLabel(_ mode: GlassMode) -> String {
        switch mode {
        case .liquidGlass: return "Liquid Glass"
        case .frosted: return "Frosted"
        case .reduceTransparency: return "Solid"
        }
    }

    private func shortPaletteLabel(_ seed: PaletteSeed) -> String {
        switch seed {
        case .emerald: return "Emerald"
        case .dynamicArtwork: return "Artwork"
        case .cyan: return "Cyan"
        case .violet: return "Violet"
        case .rose: return "Rose"
        case .amber: return "Amber"
        }
    }
}

public struct DiagnosticsLogSheetView: View {
    @ObservedObject public var repository: LibraryRepository
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            Group {
                if repository.errorLog.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(theme.accent)
                        Text("No errors recorded")
                            .font(SnoozyTypography.headline(16))
                            .foregroundStyle(theme.ink)
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(repository.errorLog) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.category)
                                        .font(SnoozyTypography.caption(11, bold: true))
                                        .foregroundStyle(theme.danger)
                                    Text(item.message)
                                        .font(SnoozyTypography.footnote(13))
                                        .foregroundStyle(theme.ink)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .liquidGlassSurface(
                                    cornerRadius: 14,
                                    glassMode: preferences.glassMode,
                                    refractionIntensity: preferences.refractionIntensity * 0.6,
                                    tintColor: theme.danger
                                )
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Error Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !repository.errorLog.isEmpty {
                        Button("Clear") {
                            repository.clearErrorLog()
                        }
                        .foregroundStyle(theme.danger)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.accent)
                }
            }
        }
    }
}
