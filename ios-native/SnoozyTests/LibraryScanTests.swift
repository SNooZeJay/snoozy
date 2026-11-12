import XCTest
@testable import Snoozy

final class LibraryScanTests: XCTestCase {
    private var rootURL: URL!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibraryScanTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: rootURL)
    }

    @MainActor
    private func makeRepository() throws -> LibraryRepository {
        let support = rootURL.appendingPathComponent("Support", isDirectory: true)
        let documents = rootURL.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        let store = SnoozyStore(
            fileManager: .default,
            supportDirectory: support,
            documentsDirectory: documents
        )
        return LibraryRepository(store: store)
    }

    @MainActor
    func testEmptyScanKeepsExistingLibraryAndPlaylistMembership() async throws {
        let repository = try makeRepository()
        let track = Track(
            id: "track-1",
            title: "Kept Song",
            artist: "Artist",
            album: "Album",
            duration: 180,
            relativePath: "Kept Song.mp3",
            addedAt: 1
        )
        repository.store.update { state in
            state.scannedTracks = [track]
            state.favoriteTrackIds = [track.id]
            state.playlists = [
                Playlist(id: "p1", name: "Keep", trackIds: [track.id], createdAt: 1)
            ]
        }

        await repository.scanLibrary()

        XCTAssertEqual(repository.rawTracks.map(\.id), [track.id])
        XCTAssertEqual(repository.favoriteTrackIds, Set([track.id]))
        XCTAssertEqual(repository.playlists.first?.trackIds, [track.id])
        XCTAssertNotNil(repository.bannerMessage)
    }

    func testImportWithDuplicateNamePreservesExistingFile() throws {
        let documents = rootURL.appendingPathComponent("Documents", isDirectory: true)
        let importFolder = rootURL.appendingPathComponent("Import", isDirectory: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: importFolder, withIntermediateDirectories: true)

        let existing = documents.appendingPathComponent("Same Name.mp3")
        try Data("existing audio".utf8).write(to: existing, options: .atomic)

        let incoming = importFolder.appendingPathComponent("Same Name.mp3")
        try Data("incoming audio".utf8).write(to: incoming, options: .atomic)

        let count = AudioScanner.importExternalURLs([incoming], into: documents)

        XCTAssertEqual(count, 1)
        XCTAssertEqual(try Data(contentsOf: existing), Data("existing audio".utf8))

        let names = try FileManager.default.contentsOfDirectory(
            at: documents,
            includingPropertiesForKeys: nil
        ).map(\.lastPathComponent)

        XCTAssertTrue(names.contains("Same Name (2).mp3"), "Imported duplicate should get a unique name, got \(names)")
    }
}
