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
        _ = store.update { state in
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
        albumArtist: String? = nil,
        trackNumber: Int = 1,
        duration: Double = 100
    ) -> Track {
        Track(
            id: id,
            title: title,
            artist: artist,
            album: album,
            albumArtist: albumArtist,
            trackNumber: trackNumber,
            duration: duration,
            relativePath: "\(title).mp3",
            addedAt: 1
        )
    }

    @MainActor
    func testAlbumEditPropagatesToEveryTrackAndRegroupsAlbum() throws {
        let repository = try makeRepository(tracks: [
            makeTrack(id: "t1", title: "One", artist: "Artist A", albumArtist: "Various Artists", trackNumber: 1),
            makeTrack(id: "t2", title: "Two", artist: "Artist B", albumArtist: "Various Artists", trackNumber: 2)
        ])
        let album = try XCTUnwrap(repository.albums.first)

        _ = repository.updateAlbum(
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
    func testArtistRenameUpdatesAlbumArtistAndMigratesAlbumOverride() throws {
        let repository = try makeRepository(tracks: [
            makeTrack(id: "t1", title: "One", artist: "Track Artist", album: "Shared", albumArtist: "Old Name"),
            makeTrack(id: "t2", title: "Two", artist: "Other Artist", album: "Shared", albumArtist: "Old Name")
        ])
        let album = try XCTUnwrap(repository.albums.first)
        _ = repository.updateAlbum(
            album: album,
            title: "Shared",
            artist: "Old Name",
            year: "2001",
            genre: "Rock",
            artworkPath: "/tmp/album.jpg"
        )
        let oldKey = LibraryRepository.albumKey(title: "Shared", artist: "Old Name")
        let newKey = LibraryRepository.albumKey(title: "Shared", artist: "New Name")

        repository.updateArtist(name: "Old Name", newName: "New Name", artworkPath: "/tmp/artist.jpg")

        XCTAssertNil(repository.albumOverrides[oldKey])
        XCTAssertEqual(repository.albumOverrides[newKey]?.year, "2001")
        XCTAssertEqual(repository.albumOverrides[newKey]?.artworkPath, "/tmp/album.jpg")

        let renamed = try XCTUnwrap(repository.albums.first { $0.id == newKey })
        XCTAssertEqual(renamed.artist, "New Name")
        XCTAssertEqual(renamed.artworkPath, "/tmp/album.jpg")
        XCTAssertTrue(repository.tracks.allSatisfy { $0.albumArtist == "New Name" })
        XCTAssertEqual(repository.albumsForArtist("New Name").count, 1)
        XCTAssertEqual(repository.tracksForArtist("Track Artist").count, 1)
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
            prefs.librarySectionOrder = ["Genres", "Songs", "Playlists"]
            prefs.hiddenLibrarySections = ["Artists"]
        }

        let tabs = repository.librarySections
        XCTAssertEqual(Array(tabs.prefix(3)), [.genres, .songs, .playlists])
        XCTAssertFalse(tabs.contains(.artists))
        XCTAssertTrue(tabs.contains(.albums))
        XCTAssertTrue(tabs.contains(.favorites))
    }

    @MainActor
    func testPlaylistSortKeepsUnresolvedTrackIds() throws {
        let first = makeTrack(id: "t1", title: "Alpha")
        let second = makeTrack(id: "t2", title: "Zulu")
        let playlist = Playlist(id: "p1", name: "Mix", trackIds: [second.id, "missing-file", first.id], createdAt: 1)
        let repository = try makeRepository(tracks: [first, second], playlists: [playlist])

        repository.sortPlaylist(id: "p1", by: .title)

        XCTAssertEqual(repository.playlists.first { $0.id == "p1" }?.trackIds, [first.id, second.id, "missing-file"])
    }

    @MainActor
    func testArtistSortOptions() throws {
        let repository = try makeRepository(tracks: [
            makeTrack(id: "a1", title: "One", artist: "Artist A", album: "A Album"),
            makeTrack(id: "a2", title: "Two", artist: "Artist A", album: "A Album"),
            makeTrack(id: "a3", title: "Three", artist: "Artist A", album: "A Album"),
            makeTrack(id: "b1", title: "Four", artist: "Artist B", album: "B One"),
            makeTrack(id: "b2", title: "Five", artist: "Artist B", album: "B Two")
        ])

        repository.setArtistSort(.name)
        XCTAssertEqual(repository.sortedArtistNames, ["Artist A", "Artist B"])

        repository.setArtistSort(.albumCount)
        XCTAssertEqual(repository.sortedArtistNames, ["Artist B", "Artist A"])

        repository.setArtistSort(.songCount)
        XCTAssertEqual(repository.sortedArtistNames, ["Artist A", "Artist B"])
    }

    @MainActor
    func testPlaylistListSortPersists() throws {
        let track = makeTrack(id: "t1", title: "One")
        let second = makeTrack(id: "t2", title: "Two")
        let third = makeTrack(id: "t3", title: "Three")
        let playlists = [
            Playlist(id: "p1", name: "Zulu", trackIds: [track.id, second.id, third.id], createdAt: 1),
            Playlist(id: "p2", name: "Alpha", trackIds: [track.id], createdAt: 2),
            Playlist(id: "p3", name: "Mike", trackIds: [second.id, third.id], createdAt: 3)
        ]
        let support = rootURL.appendingPathComponent("Support", isDirectory: true)
        let documents = rootURL.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        let makeStore = {
            SnoozyStore(fileManager: .default, supportDirectory: support, documentsDirectory: documents)
        }
        let store = makeStore()
        _ = store.update { state in
            state.scannedTracks = [track, second, third]
            state.playlists = playlists
        }
        let repository = LibraryRepository(store: store)

        XCTAssertEqual(repository.sortedPlaylists.map(\.id), ["p1", "p2", "p3"])
        repository.setPlaylistListSort(.name)
        XCTAssertEqual(repository.sortedPlaylists.map(\.id), ["p2", "p3", "p1"])
        repository.setPlaylistListSort(.songCount)
        XCTAssertEqual(repository.sortedPlaylists.map(\.id), ["p1", "p3", "p2"])

        repository.setPlaylistListSort(.name)
        let reopened = LibraryRepository(store: makeStore())
        XCTAssertEqual(reopened.playlistListSort, .name)
        XCTAssertEqual(reopened.sortedPlaylists.map(\.id), ["p2", "p3", "p1"])
        XCTAssertEqual(reopened.tracks.count, 3)
    }

    func testStateWithoutNewSortKeysKeepsLibraryData() throws {
        let json = Data(#"""
        {
          "playlists": [{"id":"p1","name":"Keep Me","trackIds":["t1"],"createdAt":1}],
          "favoriteTrackIds": ["t1"],
          "recents": ["t1"],
          "songSort": "artist"
        }
        """#.utf8)

        let state = try JSONDecoder().decode(PersistedAppState.self, from: json)

        XCTAssertEqual(state.playlists.first?.name, "Keep Me")
        XCTAssertEqual(state.favoriteTrackIds, ["t1"])
        XCTAssertEqual(state.recents, ["t1"])
        XCTAssertEqual(state.songSort, .artist)
        XCTAssertEqual(state.albumSort, .title)
        XCTAssertEqual(state.artistSort, .name)
        XCTAssertEqual(state.playlistListSort, .manual)
        XCTAssertTrue(state.trackOverrides.isEmpty)
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
