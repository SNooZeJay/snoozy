package com.snoozy.app.playback

import com.snoozy.app.data.model.Track
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class PlaybackQueueOpsTest {
    @Test
    fun repeatStateCyclesAndParsesStoredValues() {
        assertEquals(RepeatState.All, RepeatState.Off.next())
        assertEquals(RepeatState.One, RepeatState.All.next())
        assertEquals(RepeatState.Off, RepeatState.One.next())

        assertEquals(RepeatState.Off, RepeatState.fromStored(null))
        assertEquals(RepeatState.Off, RepeatState.fromStored(""))
        assertEquals(RepeatState.Off, RepeatState.fromStored("unknown"))
        assertEquals(RepeatState.Off, RepeatState.fromStored("off"))
        assertEquals(RepeatState.All, RepeatState.fromStored("all"))
        assertEquals(RepeatState.One, RepeatState.fromStored("one"))
    }

    @Test
    fun randomStartIndexStaysWithinBounds() {
        assertEquals(0, PlaybackQueueOps.randomStartIndex(0) { 0.9 })
        assertEquals(0, PlaybackQueueOps.randomStartIndex(-3) { 0.5 })
        assertEquals(0, PlaybackQueueOps.randomStartIndex(5) { 0.0 })
        assertEquals(2, PlaybackQueueOps.randomStartIndex(5) { 0.5 })
        assertEquals(4, PlaybackQueueOps.randomStartIndex(5) { 0.999 })
        assertEquals(4, PlaybackQueueOps.randomStartIndex(5) { 1.5 })
        assertEquals(0, PlaybackQueueOps.randomStartIndex(5) { -0.5 })
    }

    @Test
    fun clampPlaybackSpeedEnforcesRangeAndFiniteDefault() {
        assertEquals(1.0f, PlaybackQueueOps.clampPlaybackSpeed(Double.NaN), 0.0001f)
        assertEquals(1.0f, PlaybackQueueOps.clampPlaybackSpeed(Double.POSITIVE_INFINITY), 0.0001f)
        assertEquals(0.5f, PlaybackQueueOps.clampPlaybackSpeed(0.1), 0.0001f)
        assertEquals(0.5f, PlaybackQueueOps.clampPlaybackSpeed(0.5), 0.0001f)
        assertEquals(1.25f, PlaybackQueueOps.clampPlaybackSpeed(1.25), 0.0001f)
        assertEquals(2.0f, PlaybackQueueOps.clampPlaybackSpeed(2.0), 0.0001f)
        assertEquals(2.0f, PlaybackQueueOps.clampPlaybackSpeed(3.5), 0.0001f)
    }

    @Test
    fun shouldRestartOnPreviousUsesThreeSecondThreshold() {
        assertFalse(PlaybackQueueOps.shouldRestartOnPrevious(0L))
        assertFalse(PlaybackQueueOps.shouldRestartOnPrevious(3_000L))
        assertTrue(PlaybackQueueOps.shouldRestartOnPrevious(3_001L))
    }

    @Test
    fun appendUniqueAppendsOnceAndReturnsSameInstanceWhenPresent() {
        val original = listOf("a", "b")
        assertSame(original, PlaybackQueueOps.appendUnique(original, "a"))
        assertSame(original, PlaybackQueueOps.appendUnique(original, "   "))
        val appended = PlaybackQueueOps.appendUnique(original, "c")
        assertEquals(listOf("a", "b", "c"), appended)
        assertSame(appended, PlaybackQueueOps.appendUnique(appended, "c"))
    }

    @Test
    fun playNextInsertsAfterActiveOrRelocatesExistingNonActiveTrack() {
        val queue = listOf("a", "b", "c", "d")

        val activeNoOp = PlaybackQueueOps.playNextOrder(queue, 1, "b")
        assertSame(queue, activeNoOp.ids)
        assertEquals(-1, activeNoOp.insertIndex)
        assertEquals(-1, activeNoOp.removeIndex)

        val insertedNew = PlaybackQueueOps.playNextOrder(queue, 1, "e")
        assertEquals(listOf("a", "b", "e", "c", "d"), insertedNew.ids)
        assertEquals(2, insertedNew.insertIndex)
        assertEquals(-1, insertedNew.removeIndex)

        val movedFromAfter = PlaybackQueueOps.playNextOrder(queue, 0, "c")
        assertEquals(listOf("a", "c", "b", "d"), movedFromAfter.ids)
        assertEquals(1, movedFromAfter.insertIndex)
        assertEquals(2, movedFromAfter.removeIndex)

        val movedFromBefore = PlaybackQueueOps.playNextOrder(queue, 2, "a")
        assertEquals(listOf("b", "c", "a", "d"), movedFromBefore.ids)
        assertEquals(2, movedFromBefore.insertIndex)
        assertEquals(0, movedFromBefore.removeIndex)

        val unanchored = PlaybackQueueOps.playNextOrder(queue, -1, "e")
        assertEquals(listOf("e", "a", "b", "c", "d"), unanchored.ids)
        assertEquals(0, unanchored.insertIndex)
        assertEquals(-1, unanchored.removeIndex)
    }

    @Test
    fun moveAndRemoveItemRespectBoundsAndReturnSameListOnNoOp() {
        val items = listOf("a", "b", "c")
        assertSame(items, PlaybackQueueOps.moveItem(items, 1, 1))
        assertSame(items, PlaybackQueueOps.moveItem(items, -1, 1))
        assertSame(items, PlaybackQueueOps.moveItem(items, 0, 3))
        assertEquals(listOf("b", "c", "a"), PlaybackQueueOps.moveItem(items, 0, 2))
        assertEquals(listOf("c", "a", "b"), PlaybackQueueOps.moveItem(items, 2, 0))

        assertSame(items, PlaybackQueueOps.removeItemAt(items, -1))
        assertSame(items, PlaybackQueueOps.removeItemAt(items, 3))
        assertEquals(listOf("a", "c"), PlaybackQueueOps.removeItemAt(items, 1))
    }

    @Test
    fun prependRecentDeduplicatesCapsAtLimitAndPreservesInstanceWhenAlreadyHead() {
        val current = listOf("t1", "t2", "t3")
        assertSame(current, PlaybackQueueOps.prependRecent(current, "t1", limit = 30))
        assertSame(current, PlaybackQueueOps.prependRecent(current, "  ", limit = 30))

        val moved = PlaybackQueueOps.prependRecent(current, "t3", limit = 30)
        assertEquals(listOf("t3", "t1", "t2"), moved)

        val capped = PlaybackQueueOps.prependRecent(listOf("a", "b", "c"), "d", limit = 3)
        assertEquals(listOf("d", "a", "b"), capped)
    }

    @Test
    fun shouldRecordPlayRequiresHalfDurationOrThirtySeconds() {
        assertFalse(PlaybackQueueOps.shouldRecordPlay(0.0, 50_000L))
        assertFalse(PlaybackQueueOps.shouldRecordPlay(Double.NaN, 50_000L))
        assertFalse(PlaybackQueueOps.shouldRecordPlay(20.0, 9_999L))
        assertTrue(PlaybackQueueOps.shouldRecordPlay(20.0, 10_000L))
        assertFalse(PlaybackQueueOps.shouldRecordPlay(120.0, 29_999L))
        assertTrue(PlaybackQueueOps.shouldRecordPlay(120.0, 30_000L))
    }

    @Test
    fun queueEntryForMapsTrackFields() {
        val track = Track(
            id = "101",
            title = "Nikes",
            artist = "Frank Ocean",
            album = "Blonde",
            uri = "file:///storage/emulated/0/Music/Nikes.mp3",
            artwork = "file:///data/user/0/com.snoozy.app/files/artwork/blonde.jpg",
        )
        assertEquals(
            QueueEntry(
                mediaId = "101",
                title = "Nikes",
                artist = "Frank Ocean",
                artwork = "file:///data/user/0/com.snoozy.app/files/artwork/blonde.jpg",
            ),
            PlaybackQueueOps.queueEntryFor(track),
        )
    }
}
