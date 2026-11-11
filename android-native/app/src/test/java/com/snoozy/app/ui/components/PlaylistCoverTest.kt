package com.snoozy.app.ui.components

import org.junit.Assert.assertEquals
import org.junit.Test

class PlaylistCoverTest {
    @Test
    fun coverKeepsDistinctNonBlankArtworkInOrder() {
        assertEquals(
            listOf("a", "b"),
            distinctArtworkUris(listOf("a", null, "b", "a", " ", "b")),
        )
    }

    @Test
    fun coverTakesAtMostFourArtworks() {
        assertEquals(
            listOf("1", "2", "3", "4"),
            distinctArtworkUris(listOf("1", "2", "3", "4", "5")),
        )
    }

    @Test
    fun coverHandlesNoArtwork() {
        assertEquals(emptyList<String>(), distinctArtworkUris(listOf(null, "", "  ")))
    }
}
