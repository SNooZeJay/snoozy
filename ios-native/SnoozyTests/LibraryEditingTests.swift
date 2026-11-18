import XCTest
@testable import Snoozy

final class LibraryEditingTests: XCTestCase {
    private var rootURL: URL!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibraryEditingTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: rootURL)
    }

    @MainActor
    private func makeRepository(tracks: [Track], playlists: [Playlist] = []) throws -> LibraryRepository {
        let support = rootURL.appendingPathComponent("Support", isDirectory: true)
        let documents = rootURL.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        let store = SnoozyStore(
            fileManager: .default,
            supportDirectory: support,
            documentsDirectory: documents
        )
        store.update { state in
            state.scannedTracks = tracks
            state.playlists = playlists
        }
        return LibraryRepository(store: store)
    }

    private func makeTrack(
        id: String,
        title: String,
        artist: String = "Artist",
        album: String = "Album",
        trackNumber: Int = 1,
        duration: Double = 100
    ) -> Track {
        Track(
            id: id,
            title: title,
            artist: artist,
            album: album,
            trackNumber: trackNumber,
            duration: duration,
            relativePath: "\(title).mp3",
            addedAt: 1
        )
    }

    @MainActor
    func testAlbumEditPropagatesToEveryTrackAndRegroupsAlbum() throws {
        let repository = try makeRepository(tracks: [
            makeTrack(id: "t1", title: "One", artist: "Artist A", trackNumber: 1),
            makeTrack(id: "t2", title: "Two", artist: "Artist B", trackNumber: 2)
        ])
        let album = try XCTUnwrap(repository.albums.first)

        repository.updateAlbum(
            album: album,
            title: "Renamed Album",
            artist: "Various Artists",
            year: "1999",
            genre: "Electronic",
            artworkPath: "/tmp/album-cover.jpg"
        )

        XCTAssertEqual(repository.tracks.count, 2)
        for track in repository.tracks {
            XCTAssertEqual(track.album, "Renamed Album")
            XCTAssertEqual(track.albumArtist, "Various Artists")
            XCTAssertEqual(track.year, "1999")
            XCTAssertEqual(track.genre, "Electronic")
            XCTAssertEqual(track.artworkPath, "/tmp/album-cover.jpg")
        }

        let expectedKey = LibraryRepository.albumKey(title: "Renamed Album", artist: "Various Artists")
        let renamed = try XCTUnwrap(repository.albums.first)
        XCTAssertEqual(renamed.id, expectedKey)
        XCTAssertEqual(renamed.title, "Renamed Album")
        XCTAssertEqual(renamed.artist, "Various Artists")
        XCTAssertEqual(renamed.year, "1999")
        XCTAssertEqual(renamed.artworkPath, "/tmp/album-cover.jpg")
        XCTAssertTrue(repository.albumOverrides[album.id] == nil)
    }

    @MainActor
    func testArtistRenameRewritesTracksAndStoresArtwork() throws {
        let repository = try makeRepository(tracks: [
            makeTrack(id: "t1", title: "One", artist: "Old Name"),
            makeTrack(id: "t2", title: "Two", artist: "Other Artist")
        ])

        repository.updateArtist(name: "Old Name", newName: "New Name", artworkPath: "/tmp/artist.jpg")

        XCTAssertEqual(repository.tracksForArtist("New Name").count, 1)
        XCTAssertTrue(repository.tracksForArtist("Old Name").isEmpty)
        XCTAssertTrue(repository.artistNames.contains("New Name"))
        XCTAssertFalse(repository.artistNames.contains("Old Name"))
        XCTAssertEqual(repository.artistOverrideArtwork(for: "New Name"), "/tmp/artist.jpg")
        XCTAssertEqual(repository.tracksForArtist("Other Artist").count, 1)
    }

    @MainActor
    func testPlaylistDetailsDuplicateSortAndBulkRemove() throws {
        let first = makeTrack(id: "t1", title: "Alpha", artist: "A", album: "First", duration: 90)
        let second = makeTrack(id: "t2", title: "Zulu", artist: "Z", album: "Second", duration: 200)
        let original = Playlist(
            id: "p1",
            name: "Mix",
            trackIds: [second.id, first.id],
            createdAt: 1
        )
        let repository = try makeRepository(tracks: [first, second], playlists: [original])

        repository.updatePlaylist(
            id: "p1",
            name: "Road Trip",
            descriptionText: "Night drive",
            artworkPath: "/tmp/playlist.jpg"
        )
        let updated = try XCTUnwrap(repository.playlists.first { $0.id == "p1" })
        XCTAssertEqual(updated.name, "Road Trip")
        XCTAssertEqual(updated.descriptionText, "Night drive")
        XCTAssertEqual(updated.artworkPath, "/tmp/playlist.jpg")

        repository.sortPlaylist(id: "p1", by: .title)
        XCTAssertEqual(repository.playlists.first { $0.id == "p1" }?.trackIds, [first.id, second.id])

        let copyID = try XCTUnwrap(repository.duplicatePlaylist(id: "p1"))
        let copy = try XCTUnwrap(repository.playlists.first { $0.id == copyID })
        XCTAssertEqual(copy.name, "Road Trip Copy")
        XCTAssertEqual(copy.trackIds, [first.id, second.id])
        XCTAssertEqual(copy.descriptionText, "Night drive")
        XCTAssertEqual(copy.artworkPath, "/tmp/playlist.jpg")

        repository.removeTracksFromPlaylist(playlistId: "p1", trackIds: [first.id])
        XCTAssertEqual(repository.playlists.first { $0.id == "p1" }?.trackIds, [second.id])
        XCTAssertEqual(repository.tracks.count, 2)
    }

    @MainActor
    func testLibrarySectionVisibilityAndOrder() throws {
        let repository = try makeRepository(tracks: [makeTrack(id: "t1", title: "One")])

        repository.updatePreferences { prefs in
            prefs.librarySectionOrder = ["genres", "songs", "playlists"]
            prefs.hiddenLibrarySections = ["artists"]
        }

        let tabs = repository.librarySections
        XCTAssertEqual(Array(tabs.prefix(3)), [.genres, .songs, .playlists])
        XCTAssertFalse(tabs.contains(.artists))
        XCTAssertTrue(tabs.contains(.albums))
        XCTAssertTrue(tabs.contains(.favorites))
    }

    func testLegacyPlaylistAndOverridesDecodeWithMissingOptionalFields() throws {
        let playlistJSON = Data(#"{"id":"p1","name":"Old","trackIds":["a"],"createdAt":1}"#.utf8)
        let playlist = try JSONDecoder().decode(Playlist.self, from: playlistJSON)
        XCTAssertNil(playlist.descriptionText)
        XCTAssertNil(playlist.artworkPath)

        let albumJSON = Data(#"{"albumKey":"a::b","title":"Old","updatedAt":1}"#.utf8)
        let albumOverride = try JSONDecoder().decode(AlbumOverride.self, from: albumJSON)
        XCTAssertNil(albumOverride.year)
        XCTAssertNil(albumOverride.genre)

        let artistJSON = Data(#"{"artistKey":"Old","updatedAt":1}"#.utf8)
        let artistOverride = try JSONDecoder().decode(ArtistOverride.self, from: artistJSON)
        XCTAssertNil(artistOverride.artworkPath)

        let trackJSON = Data(#"{"trackId":"t1","title":"Old","updatedAt":1}"#.utf8)
        let trackOverride = try JSONDecoder().decode(TrackOverride.self, from: trackJSON)
        XCTAssertNil(trackOverride.lyrics)
    }

    func testLegacyPreferencesDecodeWithLibraryDefaults() throws {
        let json = Data(#"{"themeMode":"dark","paletteSeed":"emerald","glassMode":"liquidGlass","refractionIntensity":0.82,"auraBackdropEnabled":true,"auraBackdropIntensity":0.75,"audioReactiveAuraEnabled":true,"motionMode":"full","hapticsEnabled":true}"#.utf8)
        let preferences = try JSONDecoder().decode(SnoozyPreferences.self, from: json)
        XCTAssertEqual(preferences.albumLayout, .grid)
        XCTAssertEqual(preferences.playlistLayout, .grid)
        XCTAssertTrue(preferences.hiddenLibrarySections.isEmpty)
        XCTAssertTrue(preferences.librarySectionOrder.isEmpty)
    }
}
