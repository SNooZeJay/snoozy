package com.snoozy.app.data.library

import com.snoozy.app.data.model.Playlist
import com.snoozy.app.data.model.Track
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class PlaylistOpsTest {
    private val original = listOf(
        Playlist(
            id = "p1",
            name = "One",
            trackIds = listOf("a", "b", "c"),
            createdAt = 10L,
        ),
    )

    @Test
    fun playlistIdMatchesTheStoredShape() {
        assertEquals("playlist-123-abc123", PlaylistOps.playlistId(123L, "abc123"))
    }

    @Test
    fun playlistSuffixIsSixBase36Characters() {
        assertEquals("000000", PlaylistOps.playlistSuffix(0L))
        val suffix = PlaylistOps.playlistSuffix(987654321L)
        assertEquals(6, suffix.length)
        assertTrue(suffix.all { it in '0'..'9' || it in 'a'..'z' })
    }

    @Test
    fun blankCreateIsIgnored() {
        assertSame(original, PlaylistOps.create(original, "   ", "p2", 20L))
    }

    @Test
    fun createTrimsAndPrepends() {
        val next = PlaylistOps.create(original, "  Road trip  ", "p2", 20L)
        assertEquals(listOf("p2", "p1"), next.map { it.id })
        assertEquals("Road trip", next.first().name)
        assertEquals(emptyList<String>(), next.first().trackIds)
        assertEquals(20L, next.first().createdAt)
    }

    @Test
    fun renameTrimsAndSetsUpdatedAt() {
        val next = PlaylistOps.rename(original, "p1", "  Night drive ", 30L)
        assertEquals("Night drive", next.single().name)
        assertEquals(30L, next.single().updatedAt)
    }

    @Test
    fun blankRenameIsIgnored() {
        assertSame(original, PlaylistOps.rename(original, "p1", "   ", 30L))
    }

    @Test
    fun renameOfMissingPlaylistIsIgnored() {
        assertSame(original, PlaylistOps.rename(original, "missing", "New", 30L))
    }

    @Test
    fun deleteFiltersThePlaylist() {
        val next = PlaylistOps.delete(original, "p1")
        assertTrue(next.isEmpty())
    }

    @Test
    fun deleteOfMissingPlaylistReturnsTheSameList() {
        assertSame(original, PlaylistOps.delete(original, "missing"))
    }

    @Test
    fun addTrackAppendsOnce() {
        val next = PlaylistOps.addTrack(original, "p1", "d")
        assertEquals(listOf("a", "b", "c", "d"), next.single().trackIds)
        assertSame(next, PlaylistOps.addTrack(next, "p1", "d"))
    }

    @Test
    fun addTrackToMissingPlaylistIsIgnored() {
        assertSame(original, PlaylistOps.addTrack(original, "missing", "d"))
    }

    @Test
    fun removeTrackFiltersEveryOccurrence() {
        val next = PlaylistOps.removeTrack(original, "p1", "b")
        assertEquals(listOf("a", "c"), next.single().trackIds)
    }

    @Test
    fun removeOfMissingTrackIsIgnored() {
        assertSame(original, PlaylistOps.removeTrack(original, "p1", "z"))
    }

    @Test
    fun moveTrackReordersBothDirections() {
        assertEquals(
            listOf("b", "c", "a"),
            PlaylistOps.moveTrack(original, "p1", 0, 2).single().trackIds,
        )
        assertEquals(
            listOf("c", "a", "b"),
            PlaylistOps.moveTrack(original, "p1", 2, 0).single().trackIds,
        )
    }

    @Test
    fun moveTrackOutsideTheListIsIgnored() {
        assertSame(original, PlaylistOps.moveTrack(original, "p1", 0, 3))
        assertSame(original, PlaylistOps.moveTrack(original, "p1", -1, 1))
        assertSame(original, PlaylistOps.moveTrack(original, "p1", 1, 1))
    }

    @Test
    fun filterMatchesTitleArtistAndAlbumCaseInsensitively() {
        val track = Track(
            id = "t1",
            title = "Nikes",
            artist = "Frank Ocean",
            album = "Blonde",
            uri = "file:///music/1.mp3",
        )
        assertTrue(PlaylistOps.matches(track, "  nIk "))
        assertTrue(PlaylistOps.matches(track, "frank"))
        assertTrue(PlaylistOps.matches(track, "blonde"))
        assertTrue(PlaylistOps.matches(track, "   "))
        assertFalse(PlaylistOps.matches(track, "endless"))
    }
}
