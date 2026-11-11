import SwiftUI

public enum RootTab: String, CaseIterable, Identifiable, Sendable {
    case home
    case library
    case playlists
    case search
    case settings

    public var id: String { rawValue }

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

    @State private var showFullPlayer: Bool = false
    @State private var menuTrack: Track? = nil
    @State private var playlistTargetTrack: Track? = nil
    @State private var metadataTargetTrack: Track? = nil
    @State private var showFileImporter: Bool = false
    @State private var showFolderImporter: Bool = false

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

    public var body: some View {
        ZStack(alignment: .bottom) {
            LiquidAuraBackgroundView(
                theme: theme,
                palette: playback.activePalette,
                preferences: repository.preferences
            )

            NavigationStack(path: $navPath) {
                currentTabContent
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
                                theme: theme
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
                DragGesture(minimumDistance: 22)
                    .onChanged { value in
                        let dy = value.translation.height
                        let dx = abs(value.translation.width)
                        guard abs(dy) > dx * 1.3 else { return }
                        if dy < -28 && !isTabBarMinimized {
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) {
                                isTabBarMinimized = true
                            }
                        } else if dy > 24 && isTabBarMinimized {
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) {
                                isTabBarMinimized = false
                            }
                        }
                    }
            )

            bottomChromeContainer
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
        }
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
                onEditMetadata: { metadataTargetTrack = track }
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
    private var currentTabContent: some View {
        switch selectedTab {
        case .home:
            HomeScreen(
                repository: repository,
                playback: playback,
                theme: theme,
                onOpenAlbum: { navPath.append(NavigationDestination.album($0)) },
                onOpenPlaylist: { navPath.append(NavigationDestination.playlist($0)) },
                onOpenLibraryCategory: { category in
                    selectedLibraryTab = category
                    selectedTab = .library
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
                    selectedTab = .library
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
    private var bottomChromeContainer: some View {
        let progress = playback.durationSeconds > 0
            ? min(1.0, max(0.0, playback.positionSeconds / playback.durationSeconds))
            : 0.0

        return SnoozyGlassEffectContainer(spacing: 8) {
            if isTabBarMinimized {
                HStack(spacing: 8) {
                    minimizedTabPillButton

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
                VStack(spacing: 8) {
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

                    floatingLiquidGlassTabBar
                }
            }
        }
    }

    private var minimizedTabPillButton: some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                isTabBarMinimized = false
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selectedTab.systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(theme.accent)
                if playback.activeTrack == nil {
                    Text(selectedTab.label)
                        .font(SnoozyTypography.caption(12, bold: true))
                        .foregroundStyle(theme.ink)
                }
            }
            .padding(.horizontal, playback.activeTrack == nil ? 16 : 0)
            .frame(minWidth: 56, minHeight: 56)
            .liquidGlassSurface(
                cornerRadius: 28,
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

    private var floatingLiquidGlassTabBar: some View {
        HStack(spacing: 4) {
            ForEach(RootTab.allCases) { tab in
                let isSelected = (selectedTab == tab)
                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                        if selectedTab == tab {
                            navPath = NavigationPath()
                            if tab == .library {
                                selectedLibraryTab = .overview
                            }
                        } else {
                            selectedTab = tab
                        }
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 17, weight: isSelected ? .bold : .medium))
                        Text(tab.label)
                            .font(SnoozyTypography.caption(10, bold: isSelected))
                    }
                    .foregroundStyle(isSelected ? theme.accentInk : theme.inkMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        Group {
                            if isSelected {
                                Capsule()
                                    .fill(theme.accent)
                                    .shadow(color: theme.accent.opacity(0.42), radius: 8, x: 0, y: 3)
                            }
                        }
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(LiquidGlassInteractiveBounceStyle(scale: 0.92))
                .accessibilityLabel(tab.label)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 60)
        .liquidGlassSurface(
            cornerRadius: 30,
            glassMode: repository.preferences.glassMode,
            refractionIntensity: repository.preferences.refractionIntensity,
            tintColor: theme.accent,
            variant: .ultraClear
        )
        .shadow(color: Color.black.opacity(theme.isDark ? 0.36 : 0.14), radius: 16, x: 0, y: 8)
    }
}
