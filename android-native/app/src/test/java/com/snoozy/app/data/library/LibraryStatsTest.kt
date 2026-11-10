package com.snoozy.app.data.library

import com.snoozy.app.data.model.Album
import com.snoozy.app.data.model.PlayHistoryEntry
import com.snoozy.app.data.model.Track
import org.junit.Assert.assertEquals
import org.junit.Test

class LibraryStatsTest {
    private fun track(
        id: String,
        title: String = "Song $id",
        genre: String? = null,
    ) = Track(
        id = id,
        title = title,
        artist = "Artist",
        album = "Album",
        genre = genre,
        uri = "file:///storage/emulated/0/Music/$id.mp3",
    )

    private fun album(id: String, title: String, addedAt: Long) = Album(
        id = id,
        title = title,
        artist = "Artist",
        albumArtist = "Artist",
        trackIds = emptyList(),
        addedAt = addedAt,
    )

    @Test
    fun recentlyAddedOrdersByNewestThenTitleAndAppliesLimit() {
        val albums = listOf(
            album("a", "Alpha", 0L),
            album("b", "Beta", 300L),
            album("c", "Charlie", 200L),
        )

        assertEquals(listOf("b", "c", "a"), recentlyAdded(albums, 10).map { it.id })
        assertEquals(listOf("b", "c"), recentlyAdded(albums, 2).map { it.id })
        assertEquals(emptyList<Album>(), recentlyAdded(albums, 0))
        assertEquals(emptyList<Album>(), recentlyAdded(albums, -1))
    }

    @Test
    fun recentlyAddedBreaksTiesByTitle() {
        val albums = listOf(
            album("banana", "Banana", 100L),
            album("apple", "apple", 100L),
        )

        assertEquals(listOf("apple", "banana"), recentlyAdded(albums, 2).map { it.id })
    }

    @Test
    fun genresAreTrimmedDeduplicatedAndSorted() {
        val tracks = listOf(
            track("a", genre = " Rock "),
            track("b", genre = "rock"),
            track("c", genre = "Jazz"),
            track("d", genre = null),
            track("e", genre = "   "),
        )

        assertEquals(listOf("Jazz", "Rock"), genresOf(tracks))
    }

    @Test
    fun topPlayedCountsHistoryAndSkipsMissingTracks() {
        val tracks = listOf(
            track("a", title = "Alpha"),
            track("b", title = "Beta"),
            track("c", title = "Charlie"),
        )
        val history = listOf(
            PlayHistoryEntry("b", 0L, 1L),
            PlayHistoryEntry("b", 0L, 1L),
            PlayHistoryEntry("a", 0L, 1L),
            PlayHistoryEntry("c", 0L, 1L),
            PlayHistoryEntry("missing", 0L, 1L),
        )

        assertEquals(
            listOf("b", "a"),
            topPlayedTracks(tracks, history, 2).map { it.track.id },
        )
        assertEquals(
            listOf(2, 1, 1),
            topPlayedTracks(tracks, history, 10).map { it.plays },
        )
        assertEquals(emptyList<PlayedTrack>(), topPlayedTracks(tracks, history, 0))
    }
}
