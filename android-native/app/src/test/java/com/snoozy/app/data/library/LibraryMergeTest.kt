package com.snoozy.app.data.library

import com.snoozy.app.data.model.Track
import org.junit.Assert.assertEquals
import org.junit.Test

class LibraryMergeTest {
    private fun track(id: String, uri: String, title: String) = Track(
        id = id,
        title = title,
        artist = "Artist",
        album = "Album",
        uri = uri,
    )

    @Test
    fun importedTracksWinTheUriDedupe() {
        val imported = track("imported", "file:///files/Music/song.mp3", "Imported title")
        val scanned = track("1000000001", "file:///files/Music/song.mp3", "Scanned title")

        assertEquals(listOf(imported), mergeTracks(listOf(imported), listOf(scanned)))
    }

    @Test
    fun mergeKeepsDistinctTracksAndSortsByTitle() {
        val imported = track("a", "file:///files/Music/a.mp3", "Beta")
        val scanned = listOf(
            track("b", "file:///storage/Music/b.mp3", "Alpha"),
            track("c", "file:///storage/Music/c.mp3", "Gamma"),
        )

        assertEquals(
            listOf("b", "a", "c"),
            mergeTracks(listOf(imported), scanned).map { it.id },
        )
    }

    @Test
    fun mergeHandlesDuplicatesInsideOneSource() {
        val first = track("a", "file:///files/Music/a.mp3", "Alpha")
        val second = track("b", "file:///files/Music/a.mp3", "Beta")

        assertEquals(listOf(first), mergeTracks(emptyList(), listOf(first, second)))
    }
}
