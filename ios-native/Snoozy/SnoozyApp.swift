import SwiftUI

@main
public struct SnoozyApp: App {
    @StateObject private var repository: LibraryRepository
    @StateObject private var playback: PlaybackController
    @Environment(\.scenePhase) private var scenePhase

    public init() {
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
                    await repository.scanLibrary()
                    playback.restoreColdStartIfNeeded()
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
