import XCTest
@testable import Snoozy

final class SnoozyStoreTests: XCTestCase {
    private var rootURL: URL!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnoozyStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: rootURL)
    }

    private func makeStore() throws -> (SnoozyStore, URL) {
        let support = rootURL.appendingPathComponent("Support", isDirectory: true)
        let documents = rootURL.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        let store = SnoozyStore(
            fileManager: .default,
            supportDirectory: support,
            documentsDirectory: documents
        )
        return (store, support.appendingPathComponent("snoozy-state-v1.json"))
    }

    func testCorruptStateIsBackedUpAndNotOverwritten() throws {
        let (store, storeURL) = try makeStore()
        let corrupt = Data("{ this is not valid json".utf8)
        try corrupt.write(to: storeURL, options: .atomic)

        let loaded = store.load()

        XCTAssertTrue(loaded.playlists.isEmpty)
        XCTAssertNotNil(store.recoveryNotice)

        let backups = try FileManager.default.contentsOfDirectory(
            at: storeURL.deletingLastPathComponent(),
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("snoozy-state-v1.corrupt-") }

        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try Data(contentsOf: backups[0]), corrupt)

        let updated = store.update { state in
            state.playlists = [Playlist(id: "p1", name: "Keep Me", trackIds: [], createdAt: 1)]
        }

        XCTAssertEqual(updated.playlists.count, 1)
        XCTAssertEqual(try Data(contentsOf: backups[0]), corrupt)
    }

    func testUnreadableStateBlocksWritesInsteadOfOverwriting() throws {
        let (store, storeURL) = try makeStore()
        try FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)

        let loaded = store.load()

        XCTAssertTrue(loaded.playlists.isEmpty)
        XCTAssertNotNil(store.recoveryNotice)

        let updated = store.update { state in
            state.playlists = [Playlist(id: "p1", name: "Must Not Persist", trackIds: [], createdAt: 1)]
        }

        XCTAssertTrue(updated.playlists.isEmpty)
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }
}
