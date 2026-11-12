import SwiftUI
import UIKit

public enum NowPlayingViewMode: String, Sendable {
    case artwork
    case lyrics
    case queue
}

public struct PlayerScreen: View {
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    public let theme: SnoozyThemeColors
    public var artworkNamespace: Namespace.ID? = nil
    public let onClose: () -> Void
    public let onOpenArtist: (String) -> Void
    public let onOpenAlbum: (String) -> Void

    @State private var mode: NowPlayingViewMode = .artwork
    @State private var isScrubbing: Bool = false
    @State private var scrubPosition: Double = 0.0
    @State private var dragOffsetY: CGFloat = 0.0
    @State private var showAddToPlaylistSheet: Bool = false
    @State private var showMetadataSheet: Bool = false
    @State private var showTrackInfoSheet: Bool = false

    private static let speedChoices: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    public init(
        repository: LibraryRepository,
        playback: PlaybackController,
        theme: SnoozyThemeColors,
        artworkNamespace: Namespace.ID? = nil,
        onClose: @escaping () -> Void,
        onOpenArtist: @escaping (String) -> Void,
        onOpenAlbum: @escaping (String) -> Void
    ) {
        self.repository = repository
        self.playback = playback
        self.theme = theme
        self.artworkNamespace = artworkNamespace
        self.onClose = onClose
        self.onOpenArtist = onOpenArtist
        self.onOpenAlbum = onOpenAlbum
    }

    public var body: some View {
        GeometryReader { proxy in
            let layout = SnoozyResponsiveLayout(width: proxy.size.width, height: proxy.size.height)
            ZStack {
                LiquidAuraBackgroundView(
                    theme: theme,
                    palette: playback.activePalette,
                    preferences: repository.preferences,
                    isImmersivePlayer: true,
                    audioLevels: playback.audioLevels
                )

                // Subtle dark vignette for Apple Music contrast legibility
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.18),
                        Color.black.opacity(0.32),
                        Color.black.opacity(0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if let track = playback.activeTrack {
                    nowPlayingLayout(for: track, layout: layout)
                        .offset(y: max(0, dragOffsetY))
                        .gesture(
                            DragGesture(minimumDistance: 20)
                                .onChanged { value in
                                    if value.translation.height > 0 && !isScrubbing {
                                        dragOffsetY = value.translation.height * 0.65
                                    }
                                }
                                .onEnded { value in
                                    if value.translation.height > 110 || value.predictedEndTranslation.height > 180 {
                                        dragOffsetY = 0
                                        onClose()
                                    } else {
                                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                            dragOffsetY = 0
                                        }
                                    }
                                }
                        )
                        .sheet(isPresented: $showAddToPlaylistSheet) {
                            AddToPlaylistSheetView(
                                track: track,
                                repository: repository,
                                theme: theme,
                                preferences: repository.preferences
                            )
                        }
                        .sheet(isPresented: $showMetadataSheet) {
                            TrackMetadataEditSheetView(
                                track: track,
                                repository: repository,
                                theme: theme,
                                preferences: repository.preferences
                            )
                        }
                        .sheet(isPresented: $showTrackInfoSheet) {
                            TrackInfoSheetView(
                                track: track,
                                theme: theme,
                                preferences: repository.preferences,
                                onEditMetadata: {
                                    showTrackInfoSheet = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                        showMetadataSheet = true
                                    }
                                }
                            )
                        }
                } else {
                    emptyPlayerView
                }
            }
            .environment(\.snoozyLayout, layout)
        }
    }

    @ViewBuilder
    private func nowPlayingLayout(for track: Track, layout: SnoozyResponsiveLayout) -> some View {
        let isFav = repository.isFavorite(track.id)
        let totalDuration = max(1.0, max(playback.durationSeconds, track.duration))
        let displayPos = isScrubbing ? scrubPosition : min(playback.positionSeconds, totalDuration)
        let progressFraction = min(1.0, max(0.0, displayPos / totalDuration))
        let vSpacing = layout.nowPlayingSectionSpacing

        if layout.isLandscape {
            VStack(spacing: 6) {
                Button(action: onClose) {
                    Capsule()
                        .fill(Color.white.opacity(0.38))
                        .frame(width: 36, height: 4)
                        .padding(.top, 6)
                        .padding(.bottom, 4)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss Now Playing")

                HStack(alignment: .center, spacing: 24) {
                    VStack(spacing: 12) {
                        artworkModeView(for: track, isFav: isFav, layout: layout)
                    }
                    .frame(maxWidth: layout.containerWidth * 0.44)

                    VStack(spacing: 12) {
                        if mode == .lyrics {
                            inlineLyricsView(for: track)
                        } else if mode == .queue {
                            inlineQueueView(for: track)
                        } else {
                            Spacer(minLength: 4)
                        }

                        progressSection(
                            for: track,
                            displayPos: displayPos,
                            totalDuration: totalDuration,
                            progressFraction: progressFraction
                        )

                        transportControlsRow(layout: layout)

                        volumeSection

                        bottomChromeRow(for: track)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: mode)
        } else {
            VStack(spacing: 0) {
                // Top grabber capsule
                Button(action: onClose) {
                    Capsule()
                        .fill(Color.white.opacity(0.38))
                        .frame(width: 38, height: 5)
                        .padding(.top, layout.isCompactHeight ? 6 : 10)
                        .padding(.bottom, layout.isCompactHeight ? 8 : 12)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss Now Playing")

                switch mode {
                case .artwork:
                    artworkModeView(for: track, isFav: isFav, layout: layout)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))

                case .lyrics:
                    compactTrackHeader(for: track, isFav: isFav)
                        .padding(.bottom, 8)
                    inlineLyricsView(for: track)
                        .transition(.opacity)

                case .queue:
                    compactTrackHeader(for: track, isFav: isFav)
                        .padding(.bottom, 8)
                    inlineQueueView(for: track)
                        .transition(.opacity)
                }

                Spacer(minLength: layout.isCompactHeight ? 6 : 10)

                // Apple Music Progress Bar + Elapsed / Quality Badge / Remaining Time
                progressSection(
                    for: track,
                    displayPos: displayPos,
                    totalDuration: totalDuration,
                    progressFraction: progressFraction
                )
                .padding(.bottom, vSpacing)

                // Primary Apple Music Transport Controls
                transportControlsRow(layout: layout)
                    .padding(.bottom, vSpacing)

                // WWDC25 Session 284 (17:24) Thumbless Volume Slider with Rubber-Band Stretching
                volumeSection
                    .padding(.bottom, vSpacing)

                // Bottom Liquid Glass Chrome Row: Lyrics, Audio Output (AVRoutePickerView), Speed, Queue
                bottomChromeRow(for: track)
                    .padding(.bottom, layout.isCompactHeight ? 6 : 10)
            }
            .padding(.horizontal, layout.isCompactWidth ? 18 : 24)
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: mode)
        }
    }

    @ViewBuilder
    private func artworkModeView(for track: Track, isFav: Bool, layout: SnoozyResponsiveLayout) -> some View {
        let artSize = layout.nowPlayingArtworkSize
        VStack(spacing: layout.isCompactHeight ? 14 : 20) {
            if !layout.isLandscape {
                Spacer(minLength: 2)
            }

            // Responsive centered Apple Music artwork with play/pause spring scale and audio-reactive depth shadow
            let reactiveBass = (repository.preferences.audioReactiveAuraEnabled && playback.isPlaying)
                ? playback.audioLevels.bass
                : 0.0
            ZStack {
                let artView = SnoozyArtworkView(
                    artworkPath: track.artworkPath,
                    size: artSize,
                    cornerRadius: max(16, artSize * 0.065),
                    theme: theme
                )
                .shadow(
                    color: playback.activePalette.primary.opacity(playback.isPlaying ? min(0.76, 0.46 + reactiveBass * 0.28) : 0.16),
                    radius: playback.isPlaying ? (26 + CGFloat(reactiveBass * 18.0)) : 10,
                    x: 0,
                    y: playback.isPlaying ? 14 : 6
                )
                .shadow(
                    color: Color.black.opacity(playback.isPlaying ? 0.50 : 0.26),
                    radius: playback.isPlaying ? 20 : 8,
                    x: 0,
                    y: playback.isPlaying ? 10 : 4
                )
                .scaleEffect(playback.isPlaying ? (1.0 + CGFloat(reactiveBass * 0.025)) : 0.86)
                .animation(.spring(response: 0.44, dampingFraction: 0.74), value: playback.isPlaying)
                .id(track.id)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))

                if let ns = artworkNamespace {
                    artView.matchedGeometryEffect(id: "nowPlayingArtwork-\(track.id)", in: ns)
                } else {
                    artView
                }
            }
            .frame(maxWidth: .infinity)

            if !layout.isLandscape {
                Spacer(minLength: 2)
            }

            // Apple Music Song Information Row: Left-aligned Title + Artist, Right-aligned Favorite + More Menu
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(SnoozyTypography.title(layout.isCompactWidth ? 20 : 22))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: 6) {
                        Button {
                            onClose()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                onOpenArtist(track.artist)
                            }
                        } label: {
                            Text(track.artist)
                                .font(SnoozyTypography.body(16, bold: false))
                                .foregroundStyle(Color.white.opacity(0.78))
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)

                        if !track.album.isEmpty {
                            Text("·")
                                .foregroundStyle(Color.white.opacity(0.45))

                            Button {
                                onClose()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    onOpenAlbum(track.albumKey)
                                }
                            } label: {
                                Text(track.album)
                                    .font(SnoozyTypography.body(15, bold: false))
                                    .foregroundStyle(Color.white.opacity(0.62))
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: 4)

                SnoozyGlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        Button {
                            repository.toggleFavorite(track.id)
                        } label: {
                            Image(systemName: isFav ? "star.fill" : "star")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(isFav ? theme.accent : .white)
                                .frame(width: 36, height: 36)
                                .liquidGlassSurface(
                                    cornerRadius: 18,
                                    glassMode: repository.preferences.glassMode,
                                    refractionIntensity: repository.preferences.refractionIntensity,
                                    tintColor: isFav ? theme.accent : .white,
                                    variant: .ultraClear
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isFav ? "Remove from Favorites" : "Favorite")

                        overflowMenuButton(for: track, isFav: isFav)
                    }
                }
            }
        }
    }

    private func compactTrackHeader(for track: Track, isFav: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) {
                    mode = .artwork
                }
            } label: {
                HStack(spacing: 12) {
                    SnoozyArtworkView(
                        artworkPath: track.artworkPath,
                        size: 50,
                        cornerRadius: 10,
                        theme: theme
                    )
                    .shadow(color: Color.black.opacity(0.32), radius: 6, x: 0, y: 3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(SnoozyTypography.body(16, bold: true))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("\(track.artist) · \(track.album)")
                            .font(SnoozyTypography.footnote(13))
                            .foregroundStyle(Color.white.opacity(0.68))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                repository.toggleFavorite(track.id)
            } label: {
                Image(systemName: isFav ? "star.fill" : "star")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isFav ? theme.accent : .white)
                    .frame(width: 34, height: 34)
                    .liquidGlassSurface(
                        cornerRadius: 17,
                        glassMode: repository.preferences.glassMode,
                        refractionIntensity: repository.preferences.refractionIntensity,
                        tintColor: isFav ? theme.accent : .white,
                        variant: .ultraClear
                    )
            }
            .buttonStyle(.plain)

            overflowMenuButton(for: track, isFav: isFav)
        }
    }

    private func overflowMenuButton(for track: Track, isFav: Bool) -> some View {
        Menu {
            Section(track.title) {
                Button {
                    showTrackInfoSheet = true
                } label: {
                    Label("Track Information", systemImage: "info.circle")
                }
                Button {
                    showAddToPlaylistSheet = true
                } label: {
                    Label("Add to a Playlist…", systemImage: "music.note.list")
                }
                Button {
                    repository.toggleFavorite(track.id)
                } label: {
                    Label(
                        isFav ? "Undo Favorite" : "Favorite",
                        systemImage: isFav ? "star.slash" : "star.fill"
                    )
                }
            }

            Section("Navigation") {
                Button {
                    onClose()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onOpenAlbum(track.albumKey)
                    }
                } label: {
                    Label("Go to Album", systemImage: "square.stack")
                }
                Button {
                    onClose()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onOpenArtist(track.artist)
                    }
                } label: {
                    Label("Go to Artist", systemImage: "music.mic")
                }
            }

            Section("Playback & Tags") {
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
                    Label(
                        "Playback Speed (\(String(format: "%.2gx", playback.playbackRate)))",
                        systemImage: "gauge.with.dots.needle.50percent"
                    )
                }

                Button {
                    showMetadataSheet = true
                } label: {
                    Label("Edit Song Metadata…", systemImage: "slider.horizontal.3")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .liquidGlassSurface(
                    cornerRadius: 18,
                    glassMode: repository.preferences.glassMode,
                    refractionIntensity: repository.preferences.refractionIntensity,
                    tintColor: .white,
                    variant: .ultraClear
                )
        }
        .accessibilityLabel("More options")
    }

    private func inlineLyricsView(for track: Track) -> some View {
        let offset = repository.lyricsOffset(for: track.id)
        let activeIdx = playback.activeLyrics.flatMap {
            LyricsEngine.activeLineIndex(
                lyrics: $0,
                positionSeconds: playback.positionSeconds,
                offsetSeconds: offset
            )
        }

        return VStack(spacing: 10) {
            lyricsSyncOffsetControls(for: track, offset: offset)

            if let lyrics = playback.activeLyrics, !lyrics.lines.isEmpty {
                lyricsScrollContent(lyrics: lyrics, activeIdx: activeIdx, offset: offset)
            } else {
                emptyLyricsView
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func lyricsSyncOffsetControls(for track: Track, offset: Double) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.accent)
                Text(String(format: "Sync %+.1fs", offset))
                    .font(SnoozyTypography.caption(11, bold: true))
                    .foregroundStyle(Color.white.opacity(0.75))
                Spacer()
                Button("-0.5s") {
                    repository.setLyricsOffset(for: track.id, seconds: offset - 0.5)
                }
                .font(SnoozyTypography.caption(11, bold: true))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .liquidGlassSurface(cornerRadius: 10, glassMode: repository.preferences.glassMode, tintColor: .white, variant: .ultraClear)

                Button("+0.5s") {
                    repository.setLyricsOffset(for: track.id, seconds: offset + 0.5)
                }
                .font(SnoozyTypography.caption(11, bold: true))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .liquidGlassSurface(cornerRadius: 10, glassMode: repository.preferences.glassMode, tintColor: .white, variant: .ultraClear)

                if abs(offset) >= 0.05 {
                    Button("Reset") {
                        repository.setLyricsOffset(for: track.id, seconds: 0.0)
                    }
                    .font(SnoozyTypography.caption(11, bold: true))
                    .foregroundStyle(theme.accent)
                }
            }

            LiquidGlassThumblessSlider(
                value: Binding(
                    get: { offset },
                    set: { repository.setLyricsOffset(for: track.id, seconds: ($0 * 2.0).rounded() / 2.0) }
                ),
                range: -5.0...5.0,
                neutralValue: 0.0,
                tickCount: 21,
                restingHeight: 5,
                activeHeight: 11,
                fillColor: theme.accent,
                trackColor: Color.white.opacity(0.18),
                enableMomentum: false
            )
        }
    }

    private func lyricsScrollContent(lyrics: ParsedLyrics, activeIdx: Int?, offset: Double) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(lyrics.lines) { line in
                        lyricsLineButton(
                            line: line,
                            isCurrent: activeIdx == line.id,
                            isSynchronized: lyrics.isSynced,
                            offset: offset
                        )
                    }
                }
                .padding(.vertical, 24)
            }
            .onChange(of: activeIdx) { _, newIdx in
                if let newIdx {
                    withAnimation(.spring(response: 0.40, dampingFraction: 0.82)) {
                        proxy.scrollTo(newIdx, anchor: .center)
                    }
                }
            }
        }
    }

    private func lyricsLineButton(
        line: LyricLine,
        isCurrent: Bool,
        isSynchronized: Bool,
        offset: Double
    ) -> some View {
        let fontSize: CGFloat = isCurrent ? 25.0 : 20.0
        let textColor: Color = isCurrent ? .white : Color.white.opacity(0.38)
        let blurRadius: CGFloat = (isCurrent || !isSynchronized) ? 0.0 : 0.4
        let scale: CGFloat = isCurrent ? 1.0 : 0.96

        return Button {
            if let t = line.timeSeconds {
                playback.seek(to: max(0.0, t + offset))
            }
        } label: {
            Text(line.text)
                .font(SnoozyTypography.display(fontSize))
                .foregroundStyle(textColor)
                .blur(radius: blurRadius)
                .scaleEffect(scale, anchor: .leading)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .animation(.spring(response: 0.34, dampingFraction: 0.80), value: isCurrent)
        }
        .buttonStyle(.plain)
        .id(line.id)
    }

    private var emptyLyricsView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "quote.bubble")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.45))
            Text("No Local Lyrics Available")
                .font(SnoozyTypography.headline(17))
                .foregroundStyle(.white)
            Text("Place a matching .lrc file next to this song in On My iPhone > Snoozy or embed USLT/SYLT tags.")
                .font(SnoozyTypography.footnote(13))
                .foregroundStyle(Color.white.opacity(0.66))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
            Spacer()
        }
    }

    private func inlineQueueView(for track: Track) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Apple Music Queue Mode Shuffle & Repeat Liquid Glass Pill Toggles
            SnoozyGlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        playback.toggleShuffle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 13, weight: .bold))
                            Text("Shuffle")
                                .font(SnoozyTypography.caption(12, bold: true))
                        }
                        .foregroundStyle(playback.shuffle ? theme.accentInk : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .liquidGlassSurface(
                            cornerRadius: 18,
                            glassMode: repository.preferences.glassMode,
                            refractionIntensity: repository.preferences.refractionIntensity,
                            tintColor: playback.shuffle ? theme.accent : .white,
                            isProminent: playback.shuffle,
                            variant: .ultraClear
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        playback.cycleRepeat()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: playback.repeatMode == .one ? "repeat.1" : "repeat")
                                .font(.system(size: 13, weight: .bold))
                            Text(playback.repeatMode.label)
                                .font(SnoozyTypography.caption(12, bold: true))
                        }
                        .foregroundStyle(playback.repeatMode != .off ? theme.accentInk : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .liquidGlassSurface(
                            cornerRadius: 18,
                            glassMode: repository.preferences.glassMode,
                            refractionIntensity: repository.preferences.refractionIntensity,
                            tintColor: playback.repeatMode != .off ? theme.accent : .white,
                            isProminent: playback.repeatMode != .off,
                            variant: .ultraClear
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Playing Next")
                        .font(SnoozyTypography.headline(17))
                        .foregroundStyle(.white)
                    Text("\(SnoozyFormat.countLabel(playback.queueTracks.count, "song", "songs")) in local queue")
                        .font(SnoozyTypography.caption(12))
                        .foregroundStyle(Color.white.opacity(0.62))
                }
                Spacer()
                if playback.queueTracks.count > 1 {
                    Button("Clear") {
                        playback.clearQueue()
                        onClose()
                    }
                    .font(SnoozyTypography.caption(13, bold: true))
                    .foregroundStyle(theme.accent)
                }
            }

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    ForEach(Array(playback.queueTracks.enumerated()), id: \.element.id) { index, item in
                        let isCurrent = (index == playback.queueIndex)
                        HStack(spacing: 10) {
                            Button {
                                playback.playQueueItem(at: index)
                            } label: {
                                HStack(spacing: 10) {
                                    SnoozyArtworkView(
                                        artworkPath: item.artworkPath,
                                        size: 44,
                                        cornerRadius: 9,
                                        theme: theme
                                    )
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 5) {
                                            if isCurrent {
                                                SnoozySoundWaveView(
                                                    isActive: playback.isPlaying,
                                                    color: theme.accent,
                                                    bars: 3,
                                                    height: 11
                                                )
                                            }
                                            Text(item.title)
                                                .font(SnoozyTypography.body(15, bold: true))
                                                .foregroundStyle(isCurrent ? theme.accent : .white)
                                                .lineLimit(1)
                                        }
                                        Text(item.artist)
                                            .font(SnoozyTypography.footnote(12))
                                            .foregroundStyle(Color.white.opacity(0.65))
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 4)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if index > 0 {
                                Button {
                                    playback.moveQueueItem(from: index, to: index - 1)
                                } label: {
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.65))
                                        .frame(width: 30, height: 34)
                                }
                                .buttonStyle(.plain)
                            }

                            if index + 1 < playback.queueTracks.count {
                                Button {
                                    playback.moveQueueItem(from: index, to: index + 1)
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.65))
                                        .frame(width: 30, height: 34)
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                playback.removeQueueItem(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.55))
                                    .frame(width: 32, height: 34)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isCurrent ? Color.white.opacity(0.14) : Color.white.opacity(0.05))
                        )
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func progressSection(
        for track: Track,
        displayPos: Double,
        totalDuration: Double,
        progressFraction: Double
    ) -> some View {
        VStack(spacing: 6) {
            // WWDC25 Session 284 (17:24) Thumbless Progress Indicator with Rubber-Band Stretching & Momentum
            LiquidGlassThumblessSlider(
                value: Binding(
                    get: { displayPos },
                    set: { scrubPosition = $0 }
                ),
                range: 0.0...totalDuration,
                restingHeight: 6,
                activeHeight: 13,
                fillColor: .white,
                trackColor: Color.white.opacity(0.22),
                enableMomentum: true,
                onEditingChanged: { editing, finalValue in
                    isScrubbing = editing
                    if editing {
                        scrubPosition = finalValue
                    } else {
                        playback.seek(to: finalValue)
                    }
                }
            )

            HStack {
                Text(SnoozyFormat.formatClock(displayPos))
                    .font(SnoozyTypography.caption(11, bold: true))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .monospacedDigit()

                Spacer()

                // Apple Music Lossless / Format Pill Badge
                Button {
                    showTrackInfoSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.system(size: 9, weight: .bold))
                        Text(track.isLosslessFormat ? "LOSSLESS · \(track.audioFormatBadge)" : track.audioFormatBadge)
                            .font(SnoozyTypography.caption(9, bold: true))
                    }
                    .foregroundStyle(Color.white.opacity(0.82))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.14))
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                Text(SnoozyFormat.formatRemainingClock(elapsed: displayPos, duration: totalDuration))
                    .font(SnoozyTypography.caption(11, bold: true))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .monospacedDigit()
            }
        }
    }

    private func transportControlsRow(layout: SnoozyResponsiveLayout) -> some View {
        HStack(spacing: 0) {
            Button {
                playback.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(playback.shuffle ? theme.accent : Color.white.opacity(0.62))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(LiquidGlassInteractiveBounceStyle(scale: 0.88))
            .accessibilityLabel(playback.shuffle ? "Disable shuffle" : "Enable shuffle")

            Spacer()

            Button {
                playback.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: layout.nowPlayingSkipIconSize, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: layout.nowPlayingSkipButtonSize, height: layout.nowPlayingSkipButtonSize)
            }
            .buttonStyle(LiquidGlassInteractiveBounceStyle(scale: 0.86))
            .accessibilityLabel("Previous track")

            Spacer()

            Button {
                playback.togglePlayback()
            } label: {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: layout.nowPlayingPlayIconSize, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: layout.nowPlayingPlayButtonSize, height: layout.nowPlayingPlayButtonSize)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(LiquidGlassInteractiveBounceStyle(scale: 0.86))
            .accessibilityLabel(playback.isPlaying ? "Pause" : "Play")

            Spacer()

            Button {
                playback.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: layout.nowPlayingSkipIconSize, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: layout.nowPlayingSkipButtonSize, height: layout.nowPlayingSkipButtonSize)
            }
            .buttonStyle(LiquidGlassInteractiveBounceStyle(scale: 0.86))
            .accessibilityLabel("Next track")

            Spacer()

            Button {
                playback.cycleRepeat()
            } label: {
                Image(systemName: playback.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(playback.repeatMode != .off ? theme.accent : Color.white.opacity(0.62))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(LiquidGlassInteractiveBounceStyle(scale: 0.88))
            .accessibilityLabel(playback.repeatMode.label)
        }
    }

    private var volumeSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.56))

            LiquidGlassThumblessSlider(
                value: Binding(
                    get: { playback.volume },
                    set: { playback.setVolume($0) }
                ),
                range: 0.0...1.0,
                restingHeight: 5,
                activeHeight: 11,
                fillColor: Color.white.opacity(0.86),
                trackColor: Color.white.opacity(0.20),
                enableMomentum: true
            )

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.56))
        }
    }

    private func bottomChromeRow(for track: Track) -> some View {
        SnoozyGlassEffectContainer(spacing: 24) {
            HStack {
                // 1. Lyrics Toggle
                Button {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) {
                        mode = (mode == .lyrics) ? .artwork : .lyrics
                    }
                } label: {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(mode == .lyrics ? theme.accentInk : Color.white.opacity(0.78))
                        .frame(width: 44, height: 36)
                        .background(
                            Group {
                                if mode == .lyrics {
                                    Capsule().fill(theme.accent)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Lyrics")

                Spacer()

                // 2. Native iOS Audio Output (AirPlay / Bluetooth Route Picker)
                ZStack {
                    AudioRoutePickerRepresentable(
                        tintColor: UIColor.white.withAlphaComponent(0.78),
                        activeTintColor: UIColor(theme.accent)
                    )
                    .frame(width: 44, height: 36)
                }
                .accessibilityLabel("Audio output")

                Spacer()

                // 3. Playback Speed Quick Menu
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
                    Text(String(format: "%.2gx", playback.playbackRate))
                        .font(SnoozyTypography.caption(12, bold: true))
                        .foregroundStyle(abs(playback.playbackRate - 1.0) > 0.01 ? theme.accent : Color.white.opacity(0.75))
                        .frame(width: 44, height: 36)
                }
                .accessibilityLabel("Playback speed")

                Spacer()

                // 4. Queue Toggle (with active badge when shuffle/repeat is on)
                Button {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) {
                        mode = (mode == .queue) ? .artwork : .queue
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(mode == .queue ? theme.accentInk : Color.white.opacity(0.78))
                            .frame(width: 44, height: 36)
                            .background(
                                Group {
                                    if mode == .queue {
                                        Capsule().fill(theme.accent)
                                    }
                                }
                            )
                        if playback.shuffle || playback.repeatMode != .off {
                            Circle()
                                .fill(mode == .queue ? .white : theme.accent)
                                .frame(width: 6, height: 6)
                                .offset(x: -6, y: 5)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Up Next Queue")
            }
            .padding(.horizontal, 12)
        }
    }

    private var emptyPlayerView: some View {
        VStack(spacing: 14) {
            Text("Nothing playing")
                .font(SnoozyTypography.title(20))
                .foregroundStyle(theme.ink)
            LiquidGlassButton(
                title: "Close",
                systemImage: "xmark",
                theme: theme,
                preferences: repository.preferences,
                action: onClose
            )
        }
    }
}

public struct TrackInfoSheetView: View {
    public let track: Track
    public let theme: SnoozyThemeColors
    public let preferences: SnoozyPreferences
    public let onEditMetadata: () -> Void
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 14) {
                        SnoozyArtworkView(
                            artworkPath: track.artworkPath,
                            size: 68,
                            cornerRadius: 14,
                            theme: theme
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(track.title)
                                .font(SnoozyTypography.headline(18))
                                .foregroundStyle(theme.ink)
                            Text(track.artist)
                                .font(SnoozyTypography.body(14, bold: true))
                                .foregroundStyle(theme.accent)
                            Text(track.album)
                                .font(SnoozyTypography.footnote(13))
                                .foregroundStyle(theme.inkMuted)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(theme.surface)
                    )

                    SnoozyGroupedCard(theme: theme, preferences: preferences) {
                        infoRow(label: "Format", value: track.isLosslessFormat ? "Lossless (\(track.audioFormatBadge))" : track.audioFormatBadge, showSeparator: false)
                        infoRow(label: "Duration", value: SnoozyFormat.formatClock(track.duration), showSeparator: true)
                        infoRow(label: "Folder", value: track.folderName, showSeparator: true)
                        infoRow(label: "File Path", value: track.relativePath, showSeparator: true)
                        if let albumArtist = track.albumArtist, !albumArtist.isEmpty {
                            infoRow(label: "Album Artist", value: albumArtist, showSeparator: true)
                        }
                        if let composer = track.composer, !composer.isEmpty {
                            infoRow(label: "Composer", value: composer, showSeparator: true)
                        }
                        if let genre = track.genre, !genre.isEmpty {
                            infoRow(label: "Genre", value: genre, showSeparator: true)
                        }
                        if let year = track.year, !year.isEmpty {
                            infoRow(label: "Year", value: year, showSeparator: true)
                        }
                        if let discNum = track.discNumber {
                            infoRow(label: "Disc Number", value: "\(discNum)", showSeparator: true)
                        }
                        if let trackNum = track.trackNumber {
                            infoRow(label: "Track Number", value: "\(trackNum)", showSeparator: true)
                        }
                    }

                    LiquidGlassButton(
                        title: "Edit Song Metadata",
                        systemImage: "slider.horizontal.3",
                        isProminent: true,
                        theme: theme,
                        preferences: preferences,
                        action: onEditMetadata
                    )
                }
                .padding(16)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Track Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }

    private func infoRow(label: String, value: String, showSeparator: Bool) -> some View {
        VStack(spacing: 0) {
            if showSeparator {
                Rectangle()
                    .fill(Color.white.opacity(theme.isDark ? 0.08 : 0.14))
                    .frame(height: 0.5)
                    .padding(.leading, 16)
            }
            HStack {
                Text(label)
                    .font(SnoozyTypography.footnote(13))
                    .foregroundStyle(theme.inkMuted)
                Spacer()
                Text(value)
                    .font(SnoozyTypography.body(14, bold: true))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
        }
    }
}
