import SwiftUI

public struct HomeScreen: View {
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors
    public let onOpenAlbum: (String) -> Void
    public let onOpenLibraryAlbums: () -> Void
    public let onImportFiles: () -> Void
    public let onImportFolder: () -> Void

    @State private var showClearRecentsAlert: Bool = false

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                headerSection

                if let banner = repository.bannerMessage {
                    bannerRow(text: banner, isError: false) {
                        repository.bannerMessage = nil
                    }
                }
                if let err = playback.playbackError {
                    bannerRow(text: err, isError: true) {
                        playback.playbackError = nil
                    }
                }

                if repository.tracks.isEmpty {
                    emptyLibraryCard
                } else {
                    recentlyPlayedSection
                    recentlyAddedAlbumsSection
                    mostPlayedSection
                    quickLibrarySection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, playback.activeTrack != nil ? 168 : 104)
        }
        .alert("Clear recently played?", isPresented: $showClearRecentsAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                repository.clearRecentsAndHistory()
            }
        } message: {
            Text("Your play history and recent songs will be emptied.")
        }
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Your music")
                    .font(SnoozyTypography.display(28))
                    .foregroundStyle(theme.ink)
                Text(repository.isScanning
                     ? "Scanning On My iPhone > Snoozy…"
                     : "\(SnoozyFormat.countLabel(repository.tracks.count, "song", "songs")) · Offline iOS 27 Liquid Glass")
                    .font(SnoozyTypography.footnote(13))
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer()
            LiquidGlassIconButton(
                systemImage: "doc.badge.plus",
                accessibilityLabel: "Import audio files",
                theme: theme,
                preferences: repository.preferences,
                action: onImportFiles
            )
            LiquidGlassIconButton(
                systemImage: "folder.badge.plus",
                accessibilityLabel: "Import music folder",
                theme: theme,
                preferences: repository.preferences,
                action: onImportFolder
            )
            LiquidGlassIconButton(
                systemImage: "arrow.clockwise",
                accessibilityLabel: "Scan Snoozy folder",
                theme: theme,
                preferences: repository.preferences
            ) {
                Task { await repository.scanLibrary() }
            }
        }
    }

    private var emptyLibraryCard: some View {
        VStack(spacing: 14) {
            SnoozyBrandIconView(size: 64)

            Text("Ready for your offline library")
                .font(SnoozyTypography.title(20))
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.center)

            Text("Open the iPhone Files app and drop MP3, FLAC, WAV, M4A, or ALAC songs into On My iPhone > Snoozy, or tap Import Files below.")
                .font(SnoozyTypography.body(14))
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                LiquidGlassButton(
                    title: "Import Files",
                    systemImage: "doc.badge.plus",
                    isProminent: true,
                    theme: theme,
                    preferences: repository.preferences,
                    action: onImportFiles
                )
                LiquidGlassButton(
                    title: "Import Folder",
                    systemImage: "folder.badge.plus",
                    isProminent: false,
                    theme: theme,
                    preferences: repository.preferences,
                    action: onImportFolder
                )
            }

            Button {
                Task { await repository.createSampleSynthTrack() }
            } label: {
                Text("Generate Demo Synth Track (.WAV + Synced .LRC)")
                    .font(SnoozyTypography.caption(12, bold: true))
                    .foregroundStyle(theme.accent)
                    .padding(.top, 4)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .liquidGlassSurface(
            cornerRadius: 26,
            glassMode: repository.preferences.glassMode,
            refractionIntensity: repository.preferences.refractionIntensity,
            tintColor: theme.accent
        )
    }

    private var recentlyPlayedSection: some View {
        let recents = repository.recentTracks
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recently played")
                    .font(SnoozyTypography.headline(17))
                    .foregroundStyle(theme.inkMuted)
                Spacer()
                if !recents.isEmpty {
                    Button("Clear") {
                        showClearRecentsAlert = true
                    }
                    .font(SnoozyTypography.caption(12, bold: true))
                    .foregroundStyle(theme.accent)
                }
            }

            if recents.isEmpty {
                Text("Nothing played yet. Tap a song and it will appear here.")
                    .font(SnoozyTypography.footnote(13))
                    .foregroundStyle(theme.inkMuted)
                    .padding(.vertical, 6)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recents) { track in
                            mediaCard(
                                title: track.title,
                                subtitle: track.artist,
                                artworkPath: track.artworkPath
                            ) {
                                playback.playTrack(track, queue: recents)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentlyAddedAlbumsSection: some View {
        let recentAlbums = Array(repository.albums.sorted { $0.addedAt > $1.addedAt }.prefix(8))
        if !recentAlbums.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Recently added")
                        .font(SnoozyTypography.headline(17))
                        .foregroundStyle(theme.inkMuted)
                    Spacer()
                    Button("Albums", action: onOpenLibraryAlbums)
                        .font(SnoozyTypography.caption(12, bold: true))
                        .foregroundStyle(theme.accent)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recentAlbums) { album in
                            mediaCard(
                                title: album.title,
                                subtitle: album.artist,
                                artworkPath: album.artworkPath
                            ) {
                                onOpenAlbum(album.id)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var mostPlayedSection: some View {
        let mostPlayed = repository.mostPlayedTracks
        if !mostPlayed.isEmpty {
            let queue = mostPlayed.map(\.track)
            VStack(alignment: .leading, spacing: 10) {
                Text("Most played")
                    .font(SnoozyTypography.headline(17))
                    .foregroundStyle(theme.inkMuted)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(mostPlayed) { item in
                            mediaCard(
                                title: item.track.title,
                                subtitle: SnoozyFormat.countLabel(item.plays, "play", "plays"),
                                artworkPath: item.track.artworkPath
                            ) {
                                playback.playTrack(item.track, queue: queue)
                            }
                        }
                    }
                }
            }
        }
    }

    private var quickLibrarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Library")
                .font(SnoozyTypography.headline(17))
                .foregroundStyle(theme.inkMuted)

            Button {
                let shuffled = repository.tracks.shuffled()
                if let first = shuffled.first {
                    playback.playTrack(first, queue: shuffled, shuffleOverride: true)
                }
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(theme.accent.opacity(0.22))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "shuffle")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(theme.accent)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shuffle all songs")
                            .font(SnoozyTypography.body(15, bold: true))
                            .foregroundStyle(theme.ink)
                        Text("Play a random mix of \(SnoozyFormat.countLabel(repository.tracks.count, "track", "tracks"))")
                            .font(SnoozyTypography.footnote(12))
                            .foregroundStyle(theme.inkMuted)
                    }
                    Spacer()
                    Image(systemName: "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(theme.inkMuted)
                }
                .padding(12)
                .liquidGlassSurface(
                    cornerRadius: 20,
                    glassMode: repository.preferences.glassMode,
                    refractionIntensity: repository.preferences.refractionIntensity,
                    tintColor: theme.accent
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Shuffle all songs")
        }
    }

    private func mediaCard(
        title: String,
        subtitle: String,
        artworkPath: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                SnoozyArtworkView(
                    artworkPath: artworkPath,
                    size: 136,
                    cornerRadius: 20,
                    theme: theme
                )
                Text(title)
                    .font(SnoozyTypography.body(14, bold: true))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(SnoozyTypography.footnote(12))
                    .foregroundStyle(theme.inkMuted)
                    .lineLimit(1)
            }
            .frame(width: 136)
            .padding(8)
            .liquidGlassSurface(
                cornerRadius: 24,
                glassMode: repository.preferences.glassMode,
                refractionIntensity: repository.preferences.refractionIntensity * 0.8,
                tintColor: theme.accent
            )
        }
        .buttonStyle(.plain)
    }

    private func bannerRow(text: String, isError: Bool, onDismiss: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? theme.danger : theme.accent)
            Text(text)
                .font(SnoozyTypography.footnote(13))
                .foregroundStyle(isError ? theme.danger : theme.ink)
                .lineLimit(2)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.inkMuted)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .liquidGlassSurface(
            cornerRadius: 16,
            glassMode: repository.preferences.glassMode,
            refractionIntensity: repository.preferences.refractionIntensity,
            tintColor: isError ? theme.danger : theme.accent
        )
    }
}
