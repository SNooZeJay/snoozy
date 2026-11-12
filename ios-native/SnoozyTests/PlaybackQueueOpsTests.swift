import XCTest
@testable import Snoozy

final class PlaybackQueueOpsTests: XCTestCase {
    func testPlayNextDeduplicatesAndRelocatesBeforeActive() {
        let result = PlaybackQueueOps.playNextOrder(
            queue: ["a", "b", "c", "d"],
            activeIndex: 2,
            trackId: "a"
        )
        XCTAssertEqual(result.queue, ["b", "c", "a", "d"])
        XCTAssertEqual(result.insertIndex, 2)
        XCTAssertEqual(result.removeIndex, 0)
    }

    func testPlayNextInsertsAfterActiveWhenNew() {
        let result = PlaybackQueueOps.playNextOrder(
            queue: ["a", "b", "c"],
            activeIndex: 0,
            trackId: "x"
        )
        XCTAssertEqual(result.queue, ["a", "x", "b", "c"])
        XCTAssertEqual(result.insertIndex, 1)
        XCTAssertEqual(result.removeIndex, -1)
    }

    func testAppendUniqueSkipsExistingTrack() {
        XCTAssertEqual(PlaybackQueueOps.appendUnique(["a", "b"], "b"), ["a", "b"])
        XCTAssertEqual(PlaybackQueueOps.appendUnique(["a", "b"], "c"), ["a", "b", "c"])
    }

    func testShouldRecordPlayThreshold() {
        XCTAssertFalse(PlaybackQueueOps.shouldRecordPlay(durationSeconds: 120, listenedMs: 25_000))
        XCTAssertTrue(PlaybackQueueOps.shouldRecordPlay(durationSeconds: 120, listenedMs: 30_000))
        XCTAssertTrue(PlaybackQueueOps.shouldRecordPlay(durationSeconds: 20, listenedMs: 10_000))
    }

    func testTrackFolderNameAndAudioFormatBadge() {
        let nestedFlac = Track(
            id: "1",
            title: "Xtal",
            artist: "Aphex Twin",
            album: "Selected Ambient Works 85-92",
            duration: 294,
            relativePath: "Ambient/Aphex Twin/01 - Xtal.flac",
            addedAt: 100
        )
        XCTAssertEqual(nestedFlac.folderName, "Ambient/Aphex Twin")
        XCTAssertEqual(nestedFlac.audioFormatBadge, "FLAC")
        XCTAssertTrue(nestedFlac.isLosslessFormat)

        let rootMp3 = Track(
            id: "2",
            title: "Midnight City",
            artist: "M83",
            album: "Hurry Up, We're Dreaming",
            duration: 243,
            relativePath: "Midnight City.mp3",
            addedAt: 200
        )
        XCTAssertEqual(rootMp3.folderName, "Snoozy Root")
        XCTAssertEqual(rootMp3.audioFormatBadge, "MP3")
        XCTAssertFalse(rootMp3.isLosslessFormat)
    }

    func testFormatRemainingClock() {
        XCTAssertEqual(SnoozyFormat.formatRemainingClock(elapsed: 84, duration: 245), "-2:41")
        XCTAssertEqual(SnoozyFormat.formatRemainingClock(elapsed: 250, duration: 245), "-0:00")
    }

    func testRootTabSwipeMathContinuousProgressAndSettle() {
        // Swiping left (-150 pt on a 300 pt width) from tab 1 moves indicator halfway toward tab 2 (1.5)
        let midProgress = RootTabSwipeMath.continuousProgress(
            currentIndex: 1,
            tabCount: 5,
            translationWidth: -150,
            containerWidth: 300
        )
        XCTAssertEqual(midProgress, 1.5, accuracy: 0.001)

        // Swiping right at index 0 applies rubber-band damping instead of exceeding bounds
        let overscrollLeft = RootTabSwipeMath.continuousProgress(
            currentIndex: 0,
            tabCount: 5,
            translationWidth: 150,
            containerWidth: 300
        )
        XCTAssertLessThan(overscrollLeft, 0.0)
        XCTAssertGreaterThan(overscrollLeft, -0.25)

        // Completed swipe left (> 28% of width) advances to next tab
        let settledNext = RootTabSwipeMath.resolveSwipeTargetIndex(
            currentIndex: 1,
            tabCount: 5,
            translationWidth: -110,
            predictedEndTranslationWidth: -140,
            containerWidth: 300
        )
        XCTAssertEqual(settledNext, 2)

        // Incomplete swipe (< 28% of width and low velocity) returns to original tab
        let incomplete = RootTabSwipeMath.resolveSwipeTargetIndex(
            currentIndex: 2,
            tabCount: 5,
            translationWidth: -40,
            predictedEndTranslationWidth: -60,
            containerWidth: 300
        )
        XCTAssertEqual(incomplete, 2)

        // Pill scrub progress maps touch X across pill width to tab index space
        let pillScrub = RootTabSwipeMath.pillScrubProgress(
            locationX: 150,
            pillWidth: 300,
            tabCount: 5
        )
        XCTAssertEqual(pillScrub, 2.0, accuracy: 0.001)
    }

    func testParseFilenameMetadataFallback() {
        let p1 = AudioScanner.parseFilenameMetadata("01 - Daft Punk - Digital Love")
        XCTAssertEqual(p1.trackNumber, 1)
        XCTAssertNil(p1.discNumber)
        XCTAssertEqual(p1.artist, "Daft Punk")
        XCTAssertEqual(p1.title, "Digital Love")

        let p2 = AudioScanner.parseFilenameMetadata("2-07 - Aphex Twin - Xtal")
        XCTAssertEqual(p2.discNumber, 2)
        XCTAssertEqual(p2.trackNumber, 7)
        XCTAssertEqual(p2.artist, "Aphex Twin")
        XCTAssertEqual(p2.title, "Xtal")

        let p3 = AudioScanner.parseFilenameMetadata("03. Track Three")
        XCTAssertEqual(p3.trackNumber, 3)
        XCTAssertNil(p3.artist)
        XCTAssertEqual(p3.title, "Track Three")
    }

    func testInferFolderHierarchyMetadata() {
        let h1 = AudioScanner.inferFolderHierarchyMetadata(fromRelativePath: "Daft Punk/Discovery/01 - One More Time.mp3")
        XCTAssertEqual(h1.artist, "Daft Punk")
        XCTAssertEqual(h1.album, "Discovery")
        XCTAssertNil(h1.discNumber)

        let h2 = AudioScanner.inferFolderHierarchyMetadata(fromRelativePath: "Music/Rock/01 - Song One.mp3")
        XCTAssertEqual(h2.genre, "Rock")

        let h3 = AudioScanner.inferFolderHierarchyMetadata(fromRelativePath: "Pink Floyd/The Wall/CD2/01 - Hey You.flac")
        XCTAssertEqual(h3.artist, "Pink Floyd")
        XCTAssertEqual(h3.album, "The Wall")
        XCTAssertEqual(h3.discNumber, 2)

        let h4 = AudioScanner.inferFolderHierarchyMetadata(fromRelativePath: "Radiohead - OK Computer/01 - Airbag.m4a")
        XCTAssertEqual(h4.artist, "Radiohead")
        XCTAssertEqual(h4.album, "OK Computer")
    }

    func testMultiDiscAlbumSortingAndCompilationGrouping() {
        let tracks: [Track] = [
            Track(
                id: "d2t1",
                title: "Disc 2 Opening",
                artist: "Artist A",
                album: "Anthology",
                albumArtist: nil,
                trackNumber: 1,
                discNumber: 2,
                duration: 180,
                relativePath: "Anthology/CD2/01 - Disc 2 Opening.flac",
                artworkPath: nil,
                addedAt: 100
            ),
            Track(
                id: "d1t2",
                title: "Disc 1 Second",
                artist: "Artist B",
                album: "Anthology",
                albumArtist: nil,
                trackNumber: 2,
                discNumber: 1,
                duration: 200,
                relativePath: "Anthology/CD1/02 - Disc 1 Second.flac",
                artworkPath: "/tmp/cover.jpg",
                addedAt: 100
            ),
            Track(
                id: "d1t1",
                title: "Disc 1 Opening",
                artist: "Artist C",
                album: "Anthology",
                albumArtist: nil,
                trackNumber: 1,
                discNumber: 1,
                duration: 190,
                relativePath: "Anthology/CD1/01 - Disc 1 Opening.flac",
                artworkPath: nil,
                addedAt: 100
            )
        ]

        let propagated = AudioScanner.propagateSharedFolderArtworkAndCompilations(tracks)
        // Multi-artist album in same folder without albumArtist is unified under "Various Artists"
        XCTAssertEqual(propagated.first?.albumArtist, "Various Artists")
        // Shared artwork propagates to sibling tracks in the same album
        XCTAssertEqual(propagated.first(where: { $0.id == "d1t1" })?.artworkPath, "/tmp/cover.jpg")

        let albums = LibraryRepository.buildAlbums(from: propagated, overrides: [:])
        XCTAssertEqual(albums.count, 1)
        XCTAssertEqual(albums[0].trackIds, ["d1t1", "d1t2", "d2t1"])
    }

    func testLibrarySearchFiltersSongsAlbumsArtistsAndPlaylists() {
        let t1 = Track(
            id: "1",
            title: "Digital Love",
            artist: "Daft Punk",
            album: "Discovery",
            genre: "Electronic",
            duration: 301,
            relativePath: "Daft Punk/Discovery/03 - Digital Love.flac",
            addedAt: 200
        )
        let t2 = Track(
            id: "2",
            title: "Midnight City",
            artist: "M83",
            album: "Hurry Up, We're Dreaming",
            genre: "Synthpop",
            duration: 243,
            relativePath: "M83/Hurry Up/01 - Midnight City.mp3",
            addedAt: 100
        )
        let albums = LibraryRepository.buildAlbums(from: [t1, t2], overrides: [:])
        let playlists = [
            Playlist(id: "p1", name: "Late Night Synth", trackIds: ["1", "2"], createdAt: 100)
        ]

        let results = LibraryRepository.filterLibrary(
            query: "daft disc",
            sortedSongs: [t1, t2],
            sortedAlbums: albums,
            artistNames: ["Daft Punk", "M83"],
            playlists: playlists,
            folderNames: ["Daft Punk/Discovery", "M83/Hurry Up"],
            genreNames: ["Electronic", "Synthpop"]
        )
        XCTAssertEqual(results.songs.map(\.id), ["1"])
        XCTAssertEqual(results.albums.map(\.title), ["Discovery"])
        XCTAssertTrue(results.playlists.isEmpty)
        XCTAssertFalse(results.isEmpty)

        let playlistMatch = LibraryRepository.filterLibrary(
            query: "late synth",
            sortedSongs: [t1, t2],
            sortedAlbums: albums,
            artistNames: ["Daft Punk", "M83"],
            playlists: playlists
        )
        XCTAssertEqual(playlistMatch.playlists.map(\.id), ["p1"])

        let emptyMatch = LibraryRepository.filterLibrary(
            query: "nonexistent track xyz",
            sortedSongs: [t1, t2],
            sortedAlbums: albums,
            artistNames: ["Daft Punk", "M83"],
            playlists: playlists
        )
        XCTAssertTrue(emptyMatch.isEmpty)
        XCTAssertEqual(emptyMatch.totalCount, 0)
    }

    func testAudioReactiveAnalyzerLevelsAndDecay() {
        let active = AudioReactiveAnalyzer.computeLevels(
            averagePowerLeftDb: -8.0,
            averagePowerRightDb: -12.0,
            peakPowerLeftDb: -1.5,
            peakPowerRightDb: -3.0,
            previous: .zero
        )
        XCTAssertGreaterThan(active.bass, 0.15)
        XCTAssertGreaterThan(active.mid, 0.10)
        XCTAssertGreaterThan(active.high, 0.10)
        XCTAssertGreaterThan(active.overall, 0.15)
        XCTAssertLessThanOrEqual(active.bass, 1.0)
        XCTAssertLessThanOrEqual(active.overall, 1.0)

        var decaying = active
        for _ in 0..<25 {
            decaying = AudioReactiveAnalyzer.decayToZero(from: decaying, factor: 0.65)
        }
        XCTAssertEqual(decaying, .zero)
    }

    func testPreferencesBackwardCompatibleDecoding() throws {
        let legacyJSON = """
        {
            "themeMode": "dark",
            "paletteSeed": "emerald",
            "glassMode": "liquidGlass",
            "refractionIntensity": 0.8,
            "auraBackdropEnabled": true,
            "auraBackdropIntensity": 0.7,
            "motionMode": "full",
            "hapticsEnabled": true
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SnoozyPreferences.self, from: legacyJSON)
        XCTAssertTrue(decoded.audioReactiveAuraEnabled)
    }

    func testResponsiveLayoutAcrossIPhoneScreenSizes() {
        // iPhone 13 mini (375 x 812 pt, 5.4-inch display)
        let mini = SnoozyResponsiveLayout(width: 375, height: 812)
        XCTAssertTrue(mini.isCompactWidth)
        XCTAssertFalse(mini.isExpandedWidth)
        XCTAssertFalse(mini.isLandscape)
        XCTAssertEqual(mini.horizontalPadding, 14)
        XCTAssertEqual(mini.gridColumnCount, 2)
        // (375 - 28 - 12) / 2 = 167.5 -> floor 167
        XCTAssertEqual(mini.gridTileSize, 167)
        XCTAssertEqual(mini.tabBarHeight, 52)
        XCTAssertEqual(mini.miniPlayerHeight, 52)

        // iPhone 16 / 15 Pro (393 x 852 pt)
        let standard = SnoozyResponsiveLayout(width: 393, height: 852)
        XCTAssertFalse(standard.isCompactWidth)
        XCTAssertFalse(standard.isExpandedWidth)
        XCTAssertEqual(standard.horizontalPadding, 16)
        XCTAssertEqual(standard.gridColumnCount, 2)
        // (393 - 32 - 14) / 2 = 173.5 -> floor 173
        XCTAssertEqual(standard.gridTileSize, 173)
        XCTAssertEqual(standard.tabBarHeight, 56)

        // iPhone 16 Pro Max (440 x 956 pt)
        let proMax = SnoozyResponsiveLayout(width: 440, height: 956)
        XCTAssertFalse(proMax.isCompactWidth)
        XCTAssertTrue(proMax.isExpandedWidth)
        XCTAssertEqual(proMax.horizontalPadding, 20)
        XCTAssertEqual(proMax.gridColumnCount, 2)
        // (440 - 40 - 16) / 2 = 192
        XCTAssertEqual(proMax.gridTileSize, 192)
        XCTAssertGreaterThan(proMax.gridTileSize, standard.gridTileSize)
        XCTAssertGreaterThan(standard.gridTileSize, mini.gridTileSize)

        // Landscape on iPhone 13 mini (812 x 375 pt)
        let landscape = SnoozyResponsiveLayout(width: 812, height: 375)
        XCTAssertTrue(landscape.isLandscape)
        XCTAssertEqual(landscape.gridColumnCount, 4)
        XCTAssertEqual(landscape.tabBarHeight, 50)
    }
}
