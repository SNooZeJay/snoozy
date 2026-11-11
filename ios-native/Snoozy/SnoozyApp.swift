import SwiftUI
import UIKit

@main
public struct SnoozyApp: App {
    @StateObject private var repository: LibraryRepository
    @StateObject private var playback: PlaybackController
    @Environment(\.scenePhase) private var scenePhase

    public init() {
        SnoozyFontRegistrar.registerBundledFontsIfNeeded()

        let accentUIColor = UIColor(red: 16.0 / 255.0, green: 185.0 / 255.0, blue: 129.0 / 255.0, alpha: 1.0)
        UINavigationBar.appearance().tintColor = accentUIColor
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = accentUIColor

        let store = SnoozyStore()
        let repo = LibraryRepository(store: store)
        let pb = PlaybackController(repository: repo)
        _repository = StateObject(wrappedValue: repo)
        _playback = StateObject(wrappedValue: pb)
    }

    public var body: some Scene {
        WindowGroup {
            RootScaffoldView(repository: repository, playback: playback)
                .task {
                    await repository.seedShowcaseLibraryIfNeeded()
                    await repository.scanLibrary()
                    playback.restoreColdStartIfNeeded()
                    if playback.activeTrack == nil, let first = repository.recentTracks.first ?? repository.sortedSongs.first {
                        playback.prepareInitialTrackIfNeeded(first, queue: repository.sortedSongs)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await repository.scanLibrary()
                            playback.restoreColdStartIfNeeded()
                        }
                    }
                }
                .onOpenURL { url in
                    Task {
                        await repository.importFiles(from: [url])
                    }
                }
        }
    }
}
