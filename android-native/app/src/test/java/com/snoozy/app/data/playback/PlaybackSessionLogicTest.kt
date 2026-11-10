package com.snoozy.app.data.playback

import com.snoozy.app.data.model.Track
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PlaybackSessionLogicTest {
    private fun track(id: String, duration: Double = 100.0) = Track(
        id = id,
        title = id,
        artist = "Artist",
        album = "Album",
        uri = "file:///storage/emulated/0/Music/$id.mp3",
        duration = duration,
    )

    @Test
    fun parseRejectsUnusableSessions() {
        assertNull(parsePlaybackSession(null))
        assertNull(parsePlaybackSession(""))
        assertNull(parsePlaybackSession("{"))
        assertNull(parsePlaybackSession("""{"version":2,"activeTrackId":"a","queueIds":["a"]}"""))
        assertNull(parsePlaybackSession("""{"version":1,"activeTrackId":"","queueIds":["a"]}"""))
        assertNull(parsePlaybackSession("""{"version":1,"activeTrackId":"a"}"""))
        assertNull(parsePlaybackSession("""{"version":1,"activeTrackId":"a","queueIds":[]}"""))
    }

    @Test
    fun parseSanitizesInvalidFieldsLikeTheReactNativeOriginal() {
        val session = parsePlaybackSession(
            """
            {
              "version": 1,
              "activeTrackId": "a",
              "queueIds": ["a", "", 7, "b"],
              "queueIndex": 1.5,
              "positionSeconds": -5,
              "shuffle": "false",
              "repeatMode": "bogus"
            }
            """.trimIndent(),
        )

        requireNotNull(session)
        assertEquals(listOf("a", "b"), session.queueIds)
        assertEquals(0, session.queueIndex)
        assertEquals(0.0, session.positionSeconds, 0.0)
        assertEquals(false, session.shuffle)
        assertEquals("off", session.repeatMode)
        assertEquals(0L, session.updatedAt)
    }

    @Test
    fun parseKeepsAValidSession() {
        val session = parsePlaybackSession(
            """
            {
              "version": 1,
              "activeTrackId": "b",
              "queueIds": ["a", "b"],
              "queueIndex": 1,
              "positionSeconds": 12.5,
              "shuffle": true,
              "repeatMode": "all",
              "updatedAt": 1700000000000
            }
            """.trimIndent(),
        )

        requireNotNull(session)
        assertEquals("b", session.activeTrackId)
        assertEquals(1, session.queueIndex)
        assertEquals(12.5, session.positionSeconds, 0.0)
        assertEquals(true, session.shuffle)
        assertEquals("all", session.repeatMode)
        assertEquals(1700000000000L, session.updatedAt)
    }

    @Test
    fun resolveDropsDeletedTracksAndClampsPosition() {
        val session = parsePlaybackSession(
            """{"version":1,"activeTrackId":"b","queueIds":["gone","b","c"],"queueIndex":1,"positionSeconds":500,"shuffle":false,"repeatMode":"off","updatedAt":1}""",
        )
        val tracks = listOf(track("b", 60.0), track("c", 90.0)).associateBy { it.id }

        val resolved = requireNotNull(resolvePlaybackSession(session, tracks))

        assertEquals(listOf("b", "c"), resolved.queueIds)
        assertEquals("b", resolved.activeTrack.id)
        assertEquals(0, resolved.activeIndex)
        assertEquals(60.0, resolved.positionSeconds, 0.0)
    }

    @Test
    fun resolveFallsBackToTheFirstRemainingTrackAtTheQueueIndex() {
        val session = parsePlaybackSession(
            """{"version":1,"activeTrackId":"gone","queueIds":["gone","b","c"],"queueIndex":1,"positionSeconds":30,"shuffle":false,"repeatMode":"one","updatedAt":1}""",
        )
        val tracks = listOf(track("b"), track("c")).associateBy { it.id }

        val resolved = requireNotNull(resolvePlaybackSession(session, tracks))

        assertEquals("b", resolved.activeTrack.id)
        assertEquals(0, resolved.activeIndex)
        assertEquals(0.0, resolved.positionSeconds, 0.0)
        assertEquals("one", resolved.repeatMode)
    }

    @Test
    fun resolveReturnsNullWhenNothingRemains() {
        val session = parsePlaybackSession(
            """{"version":1,"activeTrackId":"gone","queueIds":["gone"],"queueIndex":0,"positionSeconds":30,"shuffle":false,"repeatMode":"off","updatedAt":1}""",
        )

        assertNull(resolvePlaybackSession(session, mapOf("b" to track("b"))))
        assertNull(resolvePlaybackSession(session, emptyMap()))
    }
}
