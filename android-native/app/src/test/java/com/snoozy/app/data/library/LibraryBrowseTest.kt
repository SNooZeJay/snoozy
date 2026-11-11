package com.snoozy.app.data.library

import com.snoozy.app.data.model.Album
import com.snoozy.app.data.model.Track
import org.junit.Assert.assertEquals
import org.junit.Test

class LibraryBrowseTest {
    private fun track(
        id: String,
        title: String = "Song $id",
        artist: String = "Artist",
        album: String = "Album",
        duration: Double = 0.0,
        genre: String? = null,
    ) = Track(
        id = id,
        title = title,
        artist = artist,
        album = album,
        genre = genre,
        uri = "file:///storage/emulated/0/Music/$id.mp3",
        duration = duration,
    )

    private fun album(
        id: String,
        title: String,
        artist: String = "Artist",
        year: String? = null,
        trackIds: List<String> = emptyList(),
    ) = Album(
        id = id,
        title = title,
        artist = artist,
        albumArtist = artist,
        year = year,
        trackIds = trackIds,
    )

    @Test
    fun storedSortValuesMatchReactNativeAndFallBackToTitle() {
        assertEquals(SongSort.Title, SongSort.fromStored(null))
        assertEquals(SongSort.Artist, SongSort.fromStored("artist"))
        assertEquals(SongSort.Duration, SongSort.fromStored("duration"))
        assertEquals(SongSort.Title, SongSort.fromStored("bpm"))
        assertEquals(AlbumSort.Tracks, AlbumSort.fromStored("tracks"))
        assertEquals(AlbumSort.Year, AlbumSort.fromStored("year"))
        assertEquals(AlbumSort.Title, AlbumSort.fromStored(""))
    }

    @Test
    fun titleSortIsCaseInsensitive() {
        val tracks = listOf(
            track("1", title = "beta"),
            track("2", title = "Alpha"),
            track("3", title = "Gamma"),
        )
        assertEquals(listOf("2", "1", "3"), sortedTracks(tracks, SongSort.Title).map { it.id })
    }

    @Test
    fun artistSortUsesAlbumThenTitle() {
        val tracks = listOf(
            track("1", title = "A", artist = "Alpha", album = "Zed"),
            track("2", title = "B", artist = "Alpha", album = "Beta"),
            track("3", title = "C", artist = "Beta", album = "Alpha"),
        )
        assertEquals(listOf("2", "1", "3"), sortedTracks(tracks, SongSort.Artist).map { it.id })
    }

    @Test
    fun albumSortUsesTitleWithinAlbum() {
        val tracks = listOf(
            track("1", title = "Zed", album = "Alpha"),
            track("2", title = "Beta", album = "Alpha"),
            track("3", title = "Alpha", album = "Beta"),
        )
        assertEquals(listOf("2", "1", "3"), sortedTracks(tracks, SongSort.Album).map { it.id })
    }

    @Test
    fun durationSortIsLongestFirstAndTreatsNonFiniteAsZero() {
        val tracks = listOf(
            track("1", title = "A", duration = 10.0),
            track("2", title = "B", duration = 200.0),
            track("3", title = "A", duration = 200.0),
            track("4", title = "Z", duration = Double.NaN),
        )
        assertEquals(
            listOf("3", "2", "1", "4"),
            sortedTracks(tracks, SongSort.Duration).map { it.id },
        )
    }

    @Test
    fun albumSortsCoverTitleArtistYearAndTrackCount() {
        val albums = listOf(
            album("a", "Beta", artist = "Zed", year = "1999", trackIds = listOf("1", "2")),
            album("b", "Alpha", artist = "Zed", year = null, trackIds = listOf("1", "2", "3")),
            album("c", "Gamma", artist = "Alpha", year = "2004", trackIds = listOf("1")),
        )
        assertEquals(
            listOf("b", "a", "c"),
            sortedAlbums(albums, AlbumSort.Title).map { it.id },
        )
        assertEquals(
            listOf("c", "b", "a"),
            sortedAlbums(albums, AlbumSort.Artist).map { it.id },
        )
        assertEquals(
            listOf("c", "a", "b"),
            sortedAlbums(albums, AlbumSort.Year).map { it.id },
        )
        assertEquals(
            listOf("b", "a", "c"),
            sortedAlbums(albums, AlbumSort.Tracks).map { it.id },
        )
    }

    @Test
    fun yearParsingMatchesParseInt() {
        assertEquals(0, yearOrZero(null))
        assertEquals(2004, yearOrZero("2004a"))
        assertEquals(2004, yearOrZero(" 2004 "))
        assertEquals(0, yearOrZero("unknown"))
    }

    @Test
    fun artistNamesAreDistinctAndNaturallySorted() {
        val tracks = listOf(
            track("1", artist = "B"),
            track("2", artist = "A"),
            track("3", artist = "A"),
        )
        assertEquals(listOf("A", "B"), artistNamesOf(tracks))
    }

    @Test
    fun artistAndGenreFiltersMatchReactNative() {
        val tracks = listOf(
            track("1", artist = "Alpha", genre = "Rock"),
            track("2", artist = "Beta", genre = " Rock "),
            track("3", artist = "Beta", genre = null),
        )
        assertEquals(listOf("2", "3"), tracksForArtist(tracks, "Beta").map { it.id })
        assertEquals(listOf("1", "2"), tracksForGenre(tracks, " rock ").map { it.id })
        assertEquals(emptyList<String>(), tracksForGenre(tracks, "   "))
    }

    @Test
    fun albumsForArtistUsesAlbumKeysFromTheArtistTracks() {
        val beta = track("1", artist = "Beta", album = "Record One")
        val alpha = track("2", artist = "Alpha", album = "Record Two")
        val albums = buildAlbums(listOf(beta, alpha))
        assertEquals(
            listOf("Record One"),
            albumsForArtist(albums, listOf(beta, alpha), "Beta").map { it.title },
        )
    }

    @Test
    fun tracksForIdsPreservesRequestedOrderAndAppliesLimit() {
        val tracks = listOf(track("1"), track("2"))
        assertEquals(
            listOf("2", "1"),
            tracksForIds(tracks, listOf("2", "missing", "1"), 10).map { it.id },
        )
        assertEquals(listOf("2"), tracksForIds(tracks, listOf("2", "1"), 1).map { it.id })
    }

    @Test
    fun favoritesKeepTheDisplayOrder() {
        val tracks = listOf(track("1"), track("2"), track("3"))
        assertEquals(listOf("1", "3"), favoriteTracks(tracks, setOf("3", "1")).map { it.id })
    }

    @Test
    fun statusLineMatchesTheReactNativeCopy() {
        assertEquals("Permission needed", libraryStatus(false, false, 0))
        assertEquals("Scanning…", libraryStatus(true, true, 37))
        assertEquals("No songs yet", libraryStatus(true, false, 0))
        assertEquals("1 song", libraryStatus(true, false, 1))
        assertEquals("37 songs", libraryStatus(true, false, 37))
    }
}
