import SwiftUI

public struct SettingsScreen: View {
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors
    public let onImportFiles: () -> Void
    public let onImportFolder: () -> Void

    @State private var showClearHistoryAlert: Bool = false
    @State private var showErrorLogSheet: Bool = false

    public var body: some View {
        let prefs = repository.preferences
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("iOS 27 Liquid Glass · iPhone 13 mini edition")
                    .font(SnoozyTypography.footnote(13))
                    .foregroundStyle(theme.inkMuted)

                liquidGlassCard(prefs: prefs)
                appearanceCard(prefs: prefs)
                offlineLibraryCard(prefs: prefs)
                diagnosticsCard(prefs: prefs)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, playback.activeTrack != nil ? 168 : 104)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Clear listening history?", isPresented: $showClearHistoryAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                repository.clearRecentsAndHistory()
            }
        } message: {
            Text("Recently played songs, play counts, and listening sessions will be cleared.")
        }
        .sheet(isPresented: $showErrorLogSheet) {
            DiagnosticsLogSheetView(
                repository: repository,
                theme: theme,
                preferences: prefs
            )
        }
    }

    private func liquidGlassCard(prefs: SnoozyPreferences) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(theme.accent)
                Text("iOS 27 Liquid Glass Engine")
                    .font(SnoozyTypography.headline(17))
                    .foregroundStyle(theme.ink)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Surface Material")
                    .font(SnoozyTypography.caption(12, bold: true))
                    .foregroundStyle(theme.inkMuted)

                Picker(
                    "Surface Material",
                    selection: Binding(
                        get: { prefs.glassMode },
                        set: { mode in repository.updatePreferences { $0.glassMode = mode } }
                    )
                ) {
                    ForEach(GlassMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            if prefs.glassMode == .liquidGlass {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Lens Refraction & Chromatic Dispersion")
                            .font(SnoozyTypography.caption(12, bold: true))
                            .foregroundStyle(theme.inkMuted)
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
            }

            Toggle(
                isOn: Binding(
                    get: { prefs.auraBackdropEnabled },
                    set: { enabled in repository.updatePreferences { $0.auraBackdropEnabled = enabled } }
                )
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dynamic Artwork Aura Backdrop")
                        .font(SnoozyTypography.body(14, bold: true))
                        .foregroundStyle(theme.ink)
                    Text("Real-time Metal fluid mesh tinted by album artwork")
                        .font(SnoozyTypography.footnote(12))
                        .foregroundStyle(theme.inkMuted)
                }
            }
            .tint(theme.accent)

            if prefs.auraBackdropEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Aura Intensity")
                            .font(SnoozyTypography.caption(12, bold: true))
                            .foregroundStyle(theme.inkMuted)
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
            }
        }
        .padding(16)
        .liquidGlassSurface(
            cornerRadius: 24,
            glassMode: prefs.glassMode,
            refractionIntensity: prefs.refractionIntensity,
            tintColor: theme.accent
        )
    }

    private func appearanceCard(prefs: SnoozyPreferences) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "paintpalette.fill")
                    .foregroundStyle(theme.accent)
                Text("Appearance & Motion")
                    .font(SnoozyTypography.headline(17))
                    .foregroundStyle(theme.ink)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Theme Mode")
                    .font(SnoozyTypography.caption(12, bold: true))
                    .foregroundStyle(theme.inkMuted)
                Picker(
                    "Theme Mode",
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
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Accent Palette")
                    .font(SnoozyTypography.caption(12, bold: true))
                    .foregroundStyle(theme.inkMuted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PaletteSeed.allCases, id: \.self) { seed in
                            let selected = (prefs.paletteSeed == seed)
                            Button {
                                repository.updatePreferences { $0.paletteSeed = seed }
                            } label: {
                                Text(seed.label)
                                    .font(SnoozyTypography.caption(12, bold: true))
                                    .foregroundStyle(selected ? theme.accentInk : theme.ink)
                                    .padding(.horizontal, 12)
                                    .frame(height: 34)
                                    .liquidGlassSurface(
                                        cornerRadius: 17,
                                        glassMode: prefs.glassMode,
                                        refractionIntensity: prefs.refractionIntensity,
                                        tintColor: theme.accent,
                                        isProminent: selected
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Motion")
                    .font(SnoozyTypography.caption(12, bold: true))
                    .foregroundStyle(theme.inkMuted)
                Picker(
                    "Motion",
                    selection: Binding(
                        get: { prefs.motionMode },
                        set: { mode in repository.updatePreferences { $0.motionMode = mode } }
                    )
                ) {
                    ForEach(MotionMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Toggle(
                isOn: Binding(
                    get: { prefs.hapticsEnabled },
                    set: { enabled in repository.updatePreferences { $0.hapticsEnabled = enabled } }
                )
            ) {
                Text("Tactile Haptics")
                    .font(SnoozyTypography.body(14, bold: true))
                    .foregroundStyle(theme.ink)
            }
            .tint(theme.accent)
        }
        .padding(16)
        .liquidGlassSurface(
            cornerRadius: 24,
            glassMode: prefs.glassMode,
            refractionIntensity: prefs.refractionIntensity,
            tintColor: theme.accent
        )
    }

    private func offlineLibraryCard(prefs: SnoozyPreferences) -> some View {
        let totalListeningSeconds = repository.listeningSessions.reduce(Int64(0)) { $0 + $1.durationSeconds }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(theme.accent)
                Text("Offline Music Folder (Files App)")
                    .font(SnoozyTypography.headline(17))
                    .foregroundStyle(theme.ink)
            }

            Text("Drop MP3, FLAC, WAV, M4A, ALAC, AAC, AIFF, or OGG files (plus .lrc lyrics) into On My iPhone > Snoozy in the iPhone Files app, or import directly below.")
                .font(SnoozyTypography.footnote(13))
                .foregroundStyle(theme.inkMuted)

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
                LiquidGlassButton(
                    title: "Rescan",
                    systemImage: "arrow.clockwise",
                    theme: theme,
                    preferences: prefs
                ) {
                    Task { await repository.scanLibrary() }
                }
            }

            Divider().overlay(Color.white.opacity(0.12))

            statRow(label: "Indexed Songs", value: "\(repository.tracks.count)")
            statRow(label: "Albums", value: "\(repository.albums.count)")
            statRow(label: "Playlists", value: "\(repository.playlists.count)")
            statRow(label: "Favorites", value: "\(repository.favoriteTrackIds.count)")
            statRow(label: "Recorded Plays", value: "\(repository.playHistory.count)")
            statRow(label: "Listening Time", value: SnoozyFormat.formatDuration(Double(totalListeningSeconds)))

            Button {
                showClearHistoryAlert = true
            } label: {
                Text("Clear Recently Played & Listening History")
                    .font(SnoozyTypography.body(14, bold: true))
                    .foregroundStyle(theme.danger)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .liquidGlassSurface(
            cornerRadius: 24,
            glassMode: prefs.glassMode,
            refractionIntensity: prefs.refractionIntensity,
            tintColor: theme.accent
        )
    }

    private func diagnosticsCard(prefs: SnoozyPreferences) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Diagnostics & Build")
                    .font(SnoozyTypography.headline(16))
                    .foregroundStyle(theme.ink)
                Spacer()
                Button("Error Log (\(repository.errorLog.count))") {
                    showErrorLogSheet = true
                }
                .font(SnoozyTypography.caption(12, bold: true))
                .foregroundStyle(theme.accent)
            }

            Text("Snoozy Native Swift + Metal · Sideloadly Personal Edition · Offline Only (Zero Network Requests)")
                .font(SnoozyTypography.footnote(12))
                .foregroundStyle(theme.inkMuted)
        }
        .padding(16)
        .liquidGlassSurface(
            cornerRadius: 24,
            glassMode: prefs.glassMode,
            refractionIntensity: prefs.refractionIntensity,
            tintColor: theme.accent
        )
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(SnoozyTypography.footnote(13))
                .foregroundStyle(theme.inkMuted)
            Spacer()
            Text(value)
                .font(SnoozyTypography.body(14, bold: true))
                .foregroundStyle(theme.ink)
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
