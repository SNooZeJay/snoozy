import SwiftUI

public enum RootTab: String, CaseIterable, Identifiable, Sendable {
    case home
    case search
    case library
    case playlists
    case settings

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .home: return "Home"
        case .search: return "Search"
        case .library: return "Library"
        case .playlists: return "Playlists"
        case .settings: return "Settings"
        }
    }

    public var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .library: return "music.note.house.fill"
        case .playlists: return "music.note.list"
        case .settings: return "gearshape.fill"
        }
    }
}

public enum NavigationDestination: Hashable {
    case album(String)
    case artist(String)
    case genre(String)
    case playlist(String)
}

public struct RootScaffoldView: View {
    @ObservedObject public var repository: LibraryRepository
    @ObservedObject public var playback: PlaybackController
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var selectedTab: RootTab = .home
    @State private var selectedLibraryTab: LibraryTab = .songs
    @State private var navPath = NavigationPath()

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
                        }
                    }
            }

            VStack(spacing: 8) {
                if let active = playback.activeTrack {
                    let progress = playback.durationSeconds > 0
                        ? min(1.0, max(0.0, playback.positionSeconds / playback.durationSeconds))
                        : 0.0
                    SnoozyMiniPlayerView(
                        track: active,
                        isPlaying: playback.isPlaying,
                        progress: progress,
                        theme: theme,
                        preferences: repository.preferences,
                        onOpenPlayer: { showFullPlayer = true },
                        onTogglePlay: { playback.togglePlayback() },
                        onNext: { playback.next() }
                    )
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                floatingLiquidGlassTabBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }
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
                onOpenLibraryAlbums: {
                    selectedLibraryTab = .albums
                    selectedTab = .library
                },
                onImportFiles: { showFileImporter = true },
                onImportFolder: { showFolderImporter = true }
            )
        case .search:
            SearchScreen(
                repository: repository,
                playback: playback,
                theme: theme,
                onOpenAlbum: { navPath.append(NavigationDestination.album($0)) },
                onOpenArtist: { navPath.append(NavigationDestination.artist($0)) },
                onOpenGenre: { navPath.append(NavigationDestination.genre($0)) },
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

    private var floatingLiquidGlassTabBar: some View {
        HStack(spacing: 4) {
            ForEach(RootTab.allCases) { tab in
                let isSelected = (selectedTab == tab)
                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                        if selectedTab == tab {
                            navPath = NavigationPath()
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
                                    .shadow(color: theme.accent.opacity(0.45), radius: 8, x: 0, y: 3)
                            }
                        }
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 62)
        .liquidGlassSurface(
            cornerRadius: 31,
            glassMode: repository.preferences.glassMode,
            refractionIntensity: repository.preferences.refractionIntensity,
            tintColor: theme.accent
        )
    }
}
