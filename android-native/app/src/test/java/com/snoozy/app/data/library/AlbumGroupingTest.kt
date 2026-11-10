package com.snoozy.app.data.library

import com.snoozy.app.data.model.Track
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AlbumGroupingTest {
    private fun track(
        id: String,
        title: String = "Song $id",
        artist: String = "Artist",
        album: String = "Album",
        albumArtist: String? = null,
        year: String? = null,
        trackNumber: String? = null,
        discNumber: String? = null,
        uri: String = "file:///storage/emulated/0/Music/Album/$id.mp3",
        duration: Double = 0.0,
        artwork: String? = null,
        addedAt: Long = 0L,
    ) = Track(
        id = id,
        title = title,
        artist = artist,
        album = album,
        albumArtist = albumArtist,
        year = year,
        trackNumber = trackNumber,
        discNumber = discNumber,
        uri = uri,
        duration = duration,
        artwork = artwork,
        addedAt = addedAt,
    )

    @Test
    fun stableHashMatchesTheReactNativeFnv1aBase36() {
        assertEquals("ztntfp", stableHash(""))
        assertEquals("m3bicr", stableHash("hello"))
        assertEquals("1x1kle9", stableHash("motion::snoozy"))
    }

    @Test
    fun folderNameDecodesTheUriPath() {
        assertEquals(
            "Album One",
            folderNameForUri("file:///storage/emulated/0/Music/Album%20One/01%20Track.mp3"),
        )
        assertEquals(
            "Album One",
            folderNameForUri("/storage/emulated/0/Music/Album One/01 Track.mp3"),
        )
        assertEquals("", folderNameForUri("track.mp3"))
    }

    @Test
    fun albumTitleFallsBackToTheFolder() {
        assertEquals(
            "Album One",
            albumTitleFor(
                track(
                    id = "a",
                    album = "Unknown Album",
                    uri = "file:///storage/emulated/0/Music/Album One/a.mp3",
                ),
            ),
        )
        assertEquals(
            "Folder",
            albumTitleFor(
                track(
                    id = "b",
                    album = "   ",
                    uri = "file:///storage/emulated/0/Music/Folder/b.mp3",
                ),
            ),
        )
        assertEquals(
            "Unknown album",
            albumTitleFor(track(id = "c", album = "unknown album", uri = "c.mp3")),
        )
    }

    @Test
    fun albumKeyMatchesTheReactNativeAlgorithm() {
        assertEquals(
            "album-tk8chi",
            albumKeyFor(
                track(
                    id = "a",
                    artist = "The Band",
                    album = "Album One",
                    uri = "file:///storage/emulated/0/Music/Other/a.mp3",
                ),
            ),
        )
        assertEquals(
            "album-18wm6r7",
            albumKeyFor(
                track(
                    id = "b",
                    artist = "Unknown artist",
                    album = "Unknown Album",
                    uri = "file:///storage/emulated/0/Music/Album One/b.mp3",
                ),
            ),
        )
        assertEquals(
            "album-1v6ipph",
            albumKeyFor(
                track(
                    id = "c",
                    artist = "Track Artist",
                    albumArtist = "Various Artists",
                    album = "Greatest Hits",
                ),
            ),
        )
    }

    @Test
    fun trackAndDiscNumbersPreferTagsThenFilename() {
        assertEquals(3, trackNumberFor(track(id = "a", trackNumber = "3/12")))
        assertEquals(7, trackNumberFor(track(id = "b", trackNumber = "07 - Title.flac")))
        assertEquals(12, trackNumberFor(track(id = "c", trackNumber = "12")))
        assertNull(trackNumberFor(track(id = "d", trackNumber = "A1")))
        assertEquals(
            4,
            trackNumberFor(
                track(id = "e", uri = "file:///storage/emulated/0/Music/Album/04 Song.mp3"),
            ),
        )
        assertEquals(2, discNumberFor(track(id = "f", discNumber = "2/3")))
        assertNull(discNumberFor(track(id = "g", discNumber = "Disc 1")))
    }

    @Test
    fun albumTracksSortByDiscThenTrackThenTitle() {
        val tracks = listOf(
            track(id = "untagged", title = "Untagged", discNumber = "1"),
            track(id = "third", title = "Third", discNumber = "1", trackNumber = "3"),
            track(id = "second", title = "Second", discNumber = "1", trackNumber = "2"),
            track(id = "disc2", title = "Disc two", discNumber = "2", trackNumber = "1"),
        )

        assertEquals(
            listOf("second", "third", "untagged", "disc2"),
            sortAlbumTracks(tracks).map { it.id },
        )
    }

    @Test
    fun buildAlbumsAggregatesAndSorts() {
        val tracks = listOf(
            track(
                id = "two",
                title = "Two",
                album = "Beta",
                artist = "Band",
                albumArtist = "Various Artists",
                year = "1999",
                trackNumber = "2",
                duration = 30.0,
                artwork = null,
                addedAt = 50L,
            ),
            track(
                id = "one",
                title = "One",
                album = "Beta",
                artist = "Band",
                albumArtist = "Various Artists",
                year = "2001",
                trackNumber = "1",
                duration = 20.0,
                artwork = "file:///art/beta.jpg",
                addedAt = 120L,
            ),
            track(
                id = "apple",
                title = "Apple",
                album = "apple",
                artist = "Solo",
                duration = 10.0,
            ),
            track(
                id = "banana",
                title = "Banana",
                album = "Banana",
                artist = "Duo",
                duration = 5.0,
            ),
        )

        val albums = buildAlbums(tracks)

        assertEquals(listOf("apple", "Banana", "Beta"), albums.map { it.title })
        val beta = albums.last()
        assertEquals("album-489es", beta.id)
        assertEquals("Various Artists", beta.albumArtist)
        assertEquals("1999", beta.year)
        assertEquals("file:///art/beta.jpg", beta.artwork)
        assertEquals(listOf("one", "two"), beta.trackIds)
        assertEquals(50.0, beta.duration, 0.0001)
        assertEquals(120L, beta.addedAt)
    }
}
