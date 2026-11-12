import SwiftUI
import UIKit

public enum RootTab: String, CaseIterable, Identifiable, Sendable {
    case home
    case library
    case playlists
    case search
    case settings

    public var id: String { rawValue }

    public var index: Int {
        switch self {
        case .home: return 0
        case .library: return 1
        case .playlists: return 2
        case .search: return 3
        case .settings: return 4
        }
    }

    public static func from(index: Int) -> RootTab {
        let all = Self.allCases
        guard !all.isEmpty else { return .home }
        let clamped = min(max(0, index), all.count - 1)
        return all[clamped]
    }

    public var label: String {
        switch self {
        case .home: return "Home"
        case .library: return "Library"
        case .playlists: return "Playlists"
        case .search: return "Search"
        case .settings: return "Settings"
        }
    }

    public var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .library: return "square.stack.fill"
        case .playlists: return "music.note.list"
        case .search: return "magnifyingglass"
        case .settings: return "gearshape.fill"
        }
    }
}

public enum RootTabSwipeMath {
    /// Computes the continuous floating indicator position (0 ... tabCount - 1) from a horizontal swipe gesture.
    /// Applies smooth rubber-band resistance when swiping past the first or last tab.
    public static func continuousProgress(
        currentIndex: Int,
        tabCount: Int,
        translationWidth: Double,
        containerWidth: Double
    ) -> Double {
        let safeWidth = max(1.0, containerWidth)
        let maxIdx = Double(max(0, tabCount - 1))
        let delta = -translationWidth / safeWidth
        let raw = Double(currentIndex) + delta
        if raw < 0.0 {
            return raw * 0.22
        } else if raw > maxIdx {
            return maxIdx + (raw - maxIdx) * 0.22
        }
        return raw
    }

    /// Resolves which tab index the navigation should settle into when a horizontal swipe gesture ends.
    /// Returns `currentIndex` if the swipe is incomplete.
    public static func resolveSwipeTargetIndex(
        currentIndex: Int,
        tabCount: Int,
        translationWidth: Double,
        predictedEndTranslationWidth: Double,
        containerWidth: Double
    ) -> Int {
        guard tabCount > 1 else { return 0 }
        let safeWidth = max(1.0, containerWidth)
        let normalizedDrag = -translationWidth / safeWidth
        let normalizedPredicted = -predictedEndTranslationWidth / safeWidth

        let distanceThreshold = 0.26
        let velocityThreshold = 0.46

        var target = currentIndex
        if normalizedDrag >= distanceThreshold || (normalizedDrag > 0.06 && normalizedPredicted >= velocityThreshold) {
            target = currentIndex + 1
        } else if normalizedDrag <= -distanceThreshold || (normalizedDrag < -0.06 && normalizedPredicted <= -velocityThreshold) {
            target = currentIndex - 1
        }
        return min(max(0, target), tabCount - 1)
    }

    /// Maps a horizontal touch location inside the floating Liquid Glass pill to continuous tab index space.
    public static func pillScrubProgress(
        locationX: Double,
        pillWidth: Double,
        tabCount: Int
    ) -> Double {
        guard tabCount > 1 else { return 0.0 }
        let safeWidth = max(1.0, pillWidth)
        let maxIdx = Double(tabCount - 1)
        let raw = (locationX / safeWidth) * Double(tabCount) - 0.5
        if raw < 0.0 {
            return raw * 0.18
        } else if raw > maxIdx {
            return maxIdx + (raw - maxIdx) * 0.18
        }
        return raw
    }
}

public enum NavigationDestination: Hashable {
    case album(String)
    case artist(String)
    case genre(String)
    case playlist(String)
    case folder(String)
}

public struct RootScaffoldView: View {
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    @Environment(\.colorScheme) private var systemColorScheme
    @Namespace private var artworkNamespace

    @State private var selectedTab: RootTab = .home
    @State private var selectedLibraryTab: LibraryTab = .overview
    @State private var navPath = NavigationPath()
    @State private var isTabBarMinimized: Bool = false

    // Instagram-inspired interactive horizontal swipe + pill scrub state
    @State private var horizontalSwipeTranslation: CGFloat = 0.0
    @State private var isHorizontalSwiping: Bool = false
    @State private var pillScrubProgressValue: Double? = nil
    @State private var gestureClassification: SnoozySwipeGestureClassification = .undecided
    @State private var horizontalScrollZones: [String: CGRect] = [:]

    @State private var showFullPlayer: Bool = false
    @State private var menuTrack: Track? = nil
    @State private var playlistTargetTrack: Track? = nil
    @State private var metadataTargetTrack: Track? = nil
    @State private var showFileImporter: Bool = false
    @State private var showFolderImporter: Bool = false

    private var isAnyModalPresented: Bool {
        showFullPlayer
            || menuTrack != nil
            || playlistTargetTrack != nil
            || metadataTargetTrack != nil
            || showFileImporter
            || showFolderImporter
    }

    public init(repository: LibraryRepository, playback: PlaybackController) {
        self.repository = repository
        self.playback = playback
    }

    private var isDarkEffective: Bool {
        switch repository.preferences.themeMode {
        case .dark: return true
        case .light: return false
        case .system: return systemColorScheme == .dark
        }
    }

    private var theme: SnoozyThemeColors {
        SnoozyThemeColors.resolve(
            isDark: isDarkEffective,
            seed: repository.preferences.paletteSeed,
            artworkPalette: playback.activePalette
        )
    }

    private func effectiveIndicatorProgress(screenWidth: CGFloat) -> Double {
        if let pillProgress = pillScrubProgressValue {
            return pillProgress
        }
        if isHorizontalSwiping || abs(horizontalSwipeTranslation) > 0.5 {
            return RootTabSwipeMath.continuousProgress(
                currentIndex: selectedTab.index,
                tabCount: RootTab.allCases.count,
                translationWidth: Double(horizontalSwipeTranslation),
                containerWidth: Double(max(1.0, screenWidth))
            )
        }
        return Double(selectedTab.index)
    }

    private var neighborSwipeTab: RootTab? {
        guard abs(horizontalSwipeTranslation) > 1.0 else { return nil }
        let currentIdx = selectedTab.index
        if horizontalSwipeTranslation < 0, currentIdx + 1 < RootTab.allCases.count {
            return RootTab.from(index: currentIdx + 1)
        } else if horizontalSwipeTranslation > 0, currentIdx - 1 >= 0 {
            return RootTab.from(index: currentIdx - 1)
        }
        return nil
    }

    public var body: some View {
        GeometryReader { proxy in
            let screenWidth = max(1.0, proxy.size.width)
            let screenHeight = max(1.0, proxy.size.height)
            let layout = SnoozyResponsiveLayout(width: screenWidth, height: screenHeight)
            let indicatorProgress = effectiveIndicatorProgress(screenWidth: screenWidth)

            ZStack(alignment: .bottom) {
                LiquidAuraBackgroundView(
                    theme: theme,
                    palette: playback.activePalette,
                    preferences: repository.preferences,
                    audioLevels: playback.audioLevels
                )

                NavigationStack(path: $navPath) {
                    tabContentView(for: selectedTab)
                        .offset(x: navPath.isEmpty ? (horizontalSwipeTranslation * 0.14) : 0)
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            switch destination {
                            case .album(let key):
                                AlbumDetailScreen(
                                    albumKey: key,
                                    repository: repository,
                                    playback: playback,
                                    theme: theme,
                                    onOpenArtist: { navPath.append(NavigationDestination.artist($0)) },
                                    onSelectTrackForMenu: { menuTrack = $0 }
                                )
                            case .artist(let name):
                                ArtistDetailScreen(
                                    artistName: name,
                                    repository: repository,
                                    playback: playback,
                                    theme: theme,
                                    onOpenAlbum: { navPath.append(NavigationDestination.album($0)) },
                                    onSelectTrackForMenu: { menuTrack = $0 }
                                )
                            case .genre(let genre):
                                GenreDetailScreen(
                                    genreName: genre,
                                    repository: repository,
                                    playback: playback,
                                    theme: theme,
                                    onSelectTrackForMenu: { menuTrack = $0 }
                                )
                            case .playlist(let id):
                                PlaylistDetailScreen(
                                    playlistId: id,
                                    repository: repository,
                                    playback: playback,
                                    theme: theme,
                                    onSelectTrackForMenu: { menuTrack = $0 }
                                )
                            case .folder(let folderName):
                                FolderDetailScreen(
                                    folderName: folderName,
                                    repository: repository,
                                    playback: playback,
                                    theme: theme,
                                    onSelectTrackForMenu: { menuTrack = $0 }
                                )
                            }
                        }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12, coordinateSpace: .named(SnoozySwipeGestureGate.rootCoordinateSpaceName))
                        .onChanged { value in
                            let bottomChromeHeight = layout.tabBarPillHeight
                                + (playback.activeTrack != nil ? layout.miniPlayerHeight + 16 : 16)
                                + 20

                            let resolved = SnoozySwipeGestureGate.classify(
                                current: gestureClassification,
                                startLocation: value.startLocation,
                                translation: value.translation,
                                containerSize: CGSize(width: screenWidth, height: screenHeight),
                                bottomChromeHeight: bottomChromeHeight,
                                isAtRootNavigation: navPath.isEmpty,
                                isModalPresented: isAnyModalPresented,
                                horizontalScrollZones: horizontalScrollZones
                            )
                            if gestureClassification != resolved {
                                gestureClassification = resolved
                            }

                            let dx = value.translation.width
                            let dy = value.translation.height

                            switch resolved {
                            case .claimedByChild, .undecided:
                                return

                            case .horizontalTabSwipe:
                                if !isHorizontalSwiping {
                                    isHorizontalSwiping = true
                                    if isTabBarMinimized {
                                        withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                                            isTabBarMinimized = false
                                        }
                                    }
                                }
                                let currentIdx = selectedTab.index
                                let isOverscrollingLeft = (currentIdx == 0 && dx > 0)
                                let isOverscrollingRight = (currentIdx == RootTab.allCases.count - 1 && dx < 0)
                                horizontalSwipeTranslation = (isOverscrollingLeft || isOverscrollingRight) ? (dx * 0.24) : dx

                            case .verticalScroll:
                                if dy < -38 && !isTabBarMinimized {
                                    withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) {
                                        isTabBarMinimized = true
                                    }
                                } else if dy > 30 && isTabBarMinimized {
                                    withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) {
                                        isTabBarMinimized = false
                                    }
                                }
                            }
                        }
                        .onEnded { value in
                            defer {
                                gestureClassification = .undecided
                            }
                            guard isHorizontalSwiping else {
                                if horizontalSwipeTranslation != 0 {
                                    horizontalSwipeTranslation = 0
                                }
                                return
                            }
                            let targetIdx = RootTabSwipeMath.resolveSwipeTargetIndex(
                                currentIndex: selectedTab.index,
                                tabCount: RootTab.allCases.count,
                                translationWidth: Double(value.translation.width),
                                predictedEndTranslationWidth: Double(value.predictedEndTranslation.width),
                                containerWidth: Double(screenWidth)
                            )
                            let nextTab = RootTab.from(index: targetIdx)
                            let didChange = (nextTab != selectedTab)

                            withAnimation(.interpolatingSpring(mass: 1.0, stiffness: 280, damping: 26)) {
                                selectedTab = nextTab
                                horizontalSwipeTranslation = 0.0
                                isHorizontalSwiping = false
                            }

                            if didChange {
                                triggerSelectionHaptic()
                            }
                        }
                )

                bottomChromeContainer(indicatorProgress: indicatorProgress, layout: layout)
                    .frame(maxWidth: layout.bottomChromeMaxWidth)
                    .padding(.horizontal, layout.horizontalPadding)
                    .padding(.bottom, layout.isCompactHeight ? 6 : 8)
            }
            .coordinateSpace(name: SnoozySwipeGestureGate.rootCoordinateSpaceName)
            .onPreferenceChange(SnoozyHorizontalScrollFramesPreferenceKey.self) { frames in
                horizontalScrollZones = frames
            }
            .environment(\.snoozyLayout, layout)
        }
        .tint(theme.accent)
        .preferredColorScheme(
            repository.preferences.themeMode == .system
                ? nil
                : (repository.preferences.themeMode == .dark ? .dark : .light)
        )
        .fullScreenCover(isPresented: $showFullPlayer) {
            PlayerScreen(
                repository: repository,
                playback: playback,
                theme: theme,
                artworkNamespace: artworkNamespace,
                onClose: { showFullPlayer = false },
                onOpenArtist: { artist in
                    navPath.append(NavigationDestination.artist(artist))
                },
                onOpenAlbum: { albumKey in
                    navPath.append(NavigationDestination.album(albumKey))
                }
            )
        }
        .sheet(item: $menuTrack) { track in
            TrackActionsSheetView(
                track: track,
                isFavorite: repository.isFavorite(track.id),
                theme: theme,
                preferences: repository.preferences,
                onPlayNext: { playback.playNext(track) },
                onAddToQueue: { playback.addToQueue(track) },
                onAddToPlaylist: { playlistTargetTrack = track },
                onToggleFavorite: { repository.toggleFavorite(track.id) },
                onEditMetadata: { metadataTargetTrack = track },
                onDeleteTrack: { repository.deleteTrack(track) }
            )
        }
        .sheet(item: $playlistTargetTrack) { track in
            AddToPlaylistSheetView(
                track: track,
                repository: repository,
                theme: theme,
                preferences: repository.preferences
            )
        }
        .sheet(item: $metadataTargetTrack) { track in
            TrackMetadataEditSheetView(
                track: track,
                repository: repository,
                theme: theme,
                preferences: repository.preferences
            )
        }
        .sheet(isPresented: $showFileImporter) {
            AudioDocumentPicker(allowFolders: false) { urls in
                Task { await repository.importFiles(from: urls) }
            }
        }
        .sheet(isPresented: $showFolderImporter) {
            AudioDocumentPicker(allowFolders: true) { urls in
                Task { await repository.importFiles(from: urls) }
            }
        }
    }

    @ViewBuilder
    private func tabContentView(for tab: RootTab) -> some View {
        switch tab {
        case .home:
            HomeScreen(
                repository: repository,
                playback: playback,
                theme: theme,
                onOpenAlbum: { navPath.append(NavigationDestination.album($0)) },
                onOpenPlaylist: { navPath.append(NavigationDestination.playlist($0)) },
                onOpenLibraryCategory: { category in
                    selectedLibraryTab = category
                    withAnimation(.interpolatingSpring(mass: 1.0, stiffness: 265, damping: 26)) {
                        selectedTab = .library
                    }
                },
                onImportFiles: { showFileImporter = true },
                onImportFolder: { showFolderImporter = true },
                onSelectTrackForMenu: { menuTrack = $0 }
            )
        case .library:
            LibraryScreen(
                repository: repository,
                playback: playback,
                selectedTab: $selectedLibraryTab,
                theme: theme,
                onOpenAlbum: { navPath.append(NavigationDestination.album($0)) },
                onOpenArtist: { navPath.append(NavigationDestination.artist($0)) },
                onOpenGenre: { navPath.append(NavigationDestination.genre($0)) },
                onOpenPlaylist: { navPath.append(NavigationDestination.playlist($0)) },
                onOpenFolder: { navPath.append(NavigationDestination.folder($0)) },
                onImportFiles: { showFileImporter = true },
                onSelectTrackForMenu: { menuTrack = $0 }
            )
        case .playlists:
            PlaylistsScreen(
                repository: repository,
                playback: playback,
                theme: theme,
                onOpenPlaylist: { navPath.append(NavigationDestination.playlist($0)) }
            )
        case .search:
            SearchScreen(
                repository: repository,
                playback: playback,
                theme: theme,
                onOpenAlbum: { navPath.append(NavigationDestination.album($0)) },
                onOpenArtist: { navPath.append(NavigationDestination.artist($0)) },
                onOpenGenre: { navPath.append(NavigationDestination.genre($0)) },
                onOpenPlaylist: { navPath.append(NavigationDestination.playlist($0)) },
                onOpenLibraryCategory: { category in
                    selectedLibraryTab = category
                    withAnimation(.interpolatingSpring(mass: 1.0, stiffness: 265, damping: 26)) {
                        selectedTab = .library
                    }
                },
                onSelectTrackForMenu: { menuTrack = $0 }
            )
        case .settings:
            SettingsScreen(
                repository: repository,
                playback: playback,
                theme: theme,
                onImportFiles: { showFileImporter = true },
                onImportFolder: { showFolderImporter = true }
            )
        }
    }

    // WWDC25 Session 284 (1:55): Floating Liquid Glass Tab Bar with Scroll Minimization and Inline Mini-Player Accessory
    private func bottomChromeContainer(indicatorProgress: Double, layout: SnoozyResponsiveLayout) -> some View {
        let progress = playback.durationSeconds > 0
            ? min(1.0, max(0.0, playback.positionSeconds / playback.durationSeconds))
            : 0.0

        return SnoozyGlassEffectContainer(spacing: layout.isCompactHeight ? 6 : 8) {
            if isTabBarMinimized {
                HStack(spacing: 8) {
                    minimizedTabPillButton(size: layout.tabBarPillHeight)

                    if let active = playback.activeTrack {
                        SnoozyMiniPlayerView(
                            track: active,
                            isPlaying: playback.isPlaying,
                            progress: progress,
                            theme: theme,
                            preferences: repository.preferences,
                            artworkNamespace: artworkNamespace,
                            onOpenPlayer: { showFullPlayer = true },
                            onTogglePlay: { playback.togglePlayback() },
                            onNext: { playback.next() },
                            onPrevious: { playback.previous() }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Spacer()
                    }
                }
            } else {
                VStack(spacing: layout.isCompactHeight ? 6 : 8) {
                    if let active = playback.activeTrack {
                        SnoozyMiniPlayerView(
                            track: active,
                            isPlaying: playback.isPlaying,
                            progress: progress,
                            theme: theme,
                            preferences: repository.preferences,
                            artworkNamespace: artworkNamespace,
                            onOpenPlayer: { showFullPlayer = true },
                            onTogglePlay: { playback.togglePlayback() },
                            onNext: { playback.next() },
                            onPrevious: { playback.previous() }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    floatingLiquidGlassTabBar(indicatorProgress: indicatorProgress, layout: layout)
                }
            }
        }
    }

    private func minimizedTabPillButton(size: CGFloat) -> some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                isTabBarMinimized = false
            }
        } label: {
            Image(systemName: selectedTab.systemImage)
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(theme.accent)
                .frame(width: size, height: size)
                .liquidGlassSurface(
                    cornerRadius: size * 0.5,
                    glassMode: repository.preferences.glassMode,
                    refractionIntensity: repository.preferences.refractionIntensity,
                    tintColor: theme.accent,
                    variant: .ultraClear
                )
                .shadow(color: Color.black.opacity(theme.isDark ? 0.36 : 0.14), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(LiquidGlassInteractiveBounceStyle(scale: 0.90))
        .accessibilityLabel("Expand navigation tab bar (\(selectedTab.label))")
    }

    /// Floating pill-shaped Liquid Glass navigation bar with Instagram-inspired icon-only continuous indicator motion.
    private func floatingLiquidGlassTabBar(indicatorProgress: Double, layout: SnoozyResponsiveLayout) -> some View {
        let tabs = RootTab.allCases
        let tabCount = tabs.count
        let horizontalInset: CGFloat = 6.0
        let pillHeight: CGFloat = layout.tabBarPillHeight
        let indicatorHeight: CGFloat = layout.tabBarIndicatorHeight

        return GeometryReader { geo in
            let innerWidth = max(1.0, geo.size.width - horizontalInset * 2.0)
            let slotWidth = innerWidth / CGFloat(max(1, tabCount))

            // Fractional distance between adjacent tabs (0.0 at rest on a tab, 0.5 midway between tabs)
            let fractional = abs(indicatorProgress - indicatorProgress.rounded())
            let dropletStretchWidth = CGFloat(sin(fractional * .pi)) * 10.0
            let dropletScaleY = 1.0 - CGFloat(sin(fractional * .pi)) * 0.045

            let indicatorWidth = max(24.0, slotWidth + dropletStretchWidth)
            let indicatorCenterX = horizontalInset + (CGFloat(indicatorProgress) + 0.5) * slotWidth

            ZStack(alignment: .leading) {
                // 1. Continuous Gliding Physical Liquid Glass Indicator Capsule
                glidingIndicatorCapsule(width: indicatorWidth, height: indicatorHeight)
                    .scaleEffect(x: 1.0, y: dropletScaleY)
                    .position(x: indicatorCenterX, y: pillHeight * 0.5)

                // 2. Icon-Only Interactive Tab Items Synchronized with Gliding Indicator
                HStack(spacing: 0) {
                    ForEach(tabs) { tab in
                        let distance = abs(indicatorProgress - Double(tab.index))
                        let proximity = max(0.0, min(1.0, 1.0 - distance))
                        let isFocused = (proximity > 0.55)

                        Button {
                            selectTabWithSpring(tab)
                        } label: {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 19, weight: isFocused ? .bold : .medium))
                                .scaleEffect(1.0 + CGFloat(proximity) * 0.10)
                                .foregroundStyle(isFocused ? theme.accentInk : theme.ink.opacity(0.64 + 0.28 * proximity))
                                .frame(width: slotWidth, height: pillHeight)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tab.label)
                        .accessibilityAddTraits(isFocused ? .isSelected : [])
                    }
                }
                .padding(.horizontal, horizontalInset)
            }
            .frame(width: geo.size.width, height: pillHeight)
            .contentShape(Capsule())
            .snoozyHorizontalScrollZone(id: "floating-tab-bar-pill")
            .simultaneousGesture(
                DragGesture(minimumDistance: 16)
                    .onChanged { value in
                        guard abs(value.translation.width) > abs(value.translation.height) * 1.25 else { return }
                        let progress = RootTabSwipeMath.pillScrubProgress(
                            locationX: Double(value.location.x - horizontalInset),
                            pillWidth: Double(innerWidth),
                            tabCount: tabCount
                        )
                        pillScrubProgressValue = progress

                        let hoveredTab = RootTab.from(index: Int(progress.rounded()))
                        if hoveredTab != selectedTab || !navPath.isEmpty {
                            if !navPath.isEmpty {
                                navPath = NavigationPath()
                            }
                            if hoveredTab == .library {
                                selectedLibraryTab = .overview
                            }
                            if hoveredTab != selectedTab {
                                selectedTab = hoveredTab
                                triggerSelectionHaptic()
                            }
                        }
                    }
                    .onEnded { value in
                        guard pillScrubProgressValue != nil else { return }
                        let finalProgress = RootTabSwipeMath.pillScrubProgress(
                            locationX: Double(value.location.x - horizontalInset),
                            pillWidth: Double(innerWidth),
                            tabCount: tabCount
                        )
                        let targetTab = RootTab.from(index: Int(finalProgress.rounded()))
                        let didChange = (targetTab != selectedTab) || !navPath.isEmpty

                        withAnimation(.interpolatingSpring(mass: 1.0, stiffness: 280, damping: 26)) {
                            if !navPath.isEmpty {
                                navPath = NavigationPath()
                            }
                            if targetTab == .library && (selectedTab == .library || didChange) {
                                selectedLibraryTab = .overview
                            }
                            selectedTab = targetTab
                            pillScrubProgressValue = nil
                        }
                        if didChange {
                            triggerSelectionHaptic()
                        }
                    }
            )
        }
        .frame(height: pillHeight)
        .liquidGlassSurface(
            cornerRadius: pillHeight * 0.5,
            glassMode: repository.preferences.glassMode,
            refractionIntensity: repository.preferences.refractionIntensity,
            tintColor: theme.accent,
            variant: .ultraClear
        )
        .overlay(
            // Physical top rim specular highlight + subtle bottom reflection
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(theme.isDark ? 0.42 : 0.68),
                            Color.white.opacity(theme.isDark ? 0.08 : 0.18),
                            Color.white.opacity(theme.isDark ? 0.20 : 0.36)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
                .allowsHitTesting(false)
        )
        .shadow(color: Color.black.opacity(theme.isDark ? 0.38 : 0.15), radius: 18, x: 0, y: 8)
        .shadow(color: Color.black.opacity(theme.isDark ? 0.20 : 0.08), radius: 5, x: 0, y: 2)
    }

    private func glidingIndicatorCapsule(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            theme.accent.opacity(theme.isDark ? 0.92 : 0.95),
                            theme.accent.opacity(theme.isDark ? 0.78 : 0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Subtle physical glass top highlight inside the gliding droplet
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.34),
                            Color.white.opacity(0.06),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(1)

            // Crisp continuous specular rim around the active droplet
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.52),
                            Color.white.opacity(0.14)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.85
                )
        }
        .frame(width: width, height: height)
        .shadow(color: theme.accent.opacity(0.24), radius: 7, x: 0, y: 3)
    }

    private func selectTabWithSpring(_ tab: RootTab) {
        let wasInDetailRoute = !navPath.isEmpty
        let wasSameTab = (selectedTab == tab)
        let didNavigate = !wasSameTab || wasInDetailRoute || (tab == .library && selectedLibraryTab != .overview)

        withAnimation(.interpolatingSpring(mass: 1.0, stiffness: 270, damping: 26)) {
            // Always pop any pushed detail routes (Album, Playlist, Artist, Folder, Genre)
            // when tapping any bottom navigation icon so the user reliably lands on the root screen.
            if !navPath.isEmpty {
                navPath = NavigationPath()
            }

            // Tapping the Library icon always returns to the Library's main overview screen.
            if tab == .library {
                selectedLibraryTab = .overview
            }

            selectedTab = tab
            isTabBarMinimized = false
            horizontalSwipeTranslation = 0.0
            isHorizontalSwiping = false
            pillScrubProgressValue = nil
            gestureClassification = .undecided
        }

        if didNavigate {
            triggerSelectionHaptic()
        }
    }

    private func triggerSelectionHaptic() {
        guard repository.preferences.hapticsEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
