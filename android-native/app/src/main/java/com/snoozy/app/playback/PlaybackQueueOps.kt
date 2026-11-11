package com.snoozy.app.playback

import com.snoozy.app.data.model.Track
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.random.Random

enum class RepeatState(val storageValue: String) {
    Off("off"),
    All("all"),
    One("one"),
    ;

    fun next(): RepeatState = when (this) {
        Off -> All
        All -> One
        One -> Off
    }

    companion object {
        fun fromStored(value: String?): RepeatState =
            entries.firstOrNull { it.storageValue == value } ?: Off
    }
}

data class QueueEntry(
    val mediaId: String,
    val title: String,
    val artist: String,
    val artwork: String?,
)

data class PlayNextMutation(
    val ids: List<String>,
    val insertIndex: Int,
    val removeIndex: Int,
)

object PlaybackQueueOps {
    fun randomStartIndex(
        length: Int,
        randomDouble: () -> Double = { Random.nextDouble() },
    ): Int {
        if (length <= 0) return 0
        val index = floor(randomDouble() * length).toInt()
        return min(length - 1, max(0, index))
    }

    fun clampPlaybackSpeed(rate: Double): Float {
        if (!rate.isFinite()) return 1.0f
        return rate.coerceIn(0.5, 2.0).toFloat()
    }

    fun shouldRestartOnPrevious(positionMs: Long): Boolean = positionMs > 3_000L

    fun appendUnique(ids: List<String>, id: String): List<String> {
        if (id.isBlank() || id in ids) return ids
        return ids + id
    }

    fun playNextOrder(ids: List<String>, activeIndex: Int, id: String): PlayNextMutation {
        if (id.isBlank()) return PlayNextMutation(ids, -1, -1)
        val activeId = ids.getOrNull(activeIndex)
        if (activeId == id) return PlayNextMutation(ids, -1, -1)

        val removeIndex = ids.indexOf(id)
        val without = if (removeIndex >= 0) ids.filterNot { it == id } else ids
        val anchor = if (activeId != null) without.indexOf(activeId) else -1
        val insertIndex = if (anchor >= 0) anchor + 1 else 0
        val nextIds = buildList(without.size + 1) {
            addAll(without.subList(0, insertIndex))
            add(id)
            addAll(without.subList(insertIndex, without.size))
        }
        if (nextIds == ids) return PlayNextMutation(ids, -1, -1)
        return PlayNextMutation(nextIds, insertIndex, removeIndex)
    }

    fun <T> moveItem(items: List<T>, from: Int, to: Int): List<T> {
        if (from == to || from !in items.indices || to !in items.indices) return items
        val next = items.toMutableList()
        val moved = next.removeAt(from)
        next.add(to, moved)
        return if (next == items) items else next
    }

    fun <T> removeItemAt(items: List<T>, index: Int): List<T> {
        if (index !in items.indices) return items
        return items.filterIndexed { i, _ -> i != index }
    }

    fun prependRecent(recents: List<String>, trackId: String, limit: Int = 30): List<String> {
        val safeLimit = limit.coerceAtLeast(0)
        if (trackId.isBlank() || safeLimit == 0) return recents
        if (
            recents.firstOrNull() == trackId &&
            recents.count { it == trackId } == 1 &&
            recents.size <= safeLimit
        ) {
            return recents
        }
        return buildList {
            add(trackId)
            for (id in recents) {
                if (id != trackId && size < safeLimit) add(id)
            }
        }
    }

    fun shouldRecordPlay(durationSeconds: Double, maxPositionMs: Long): Boolean {
        val durationMs = if (durationSeconds.isFinite() && durationSeconds > 0.0) {
            durationSeconds * 1000.0
        } else {
            0.0
        }
        val thresholdMs = min(30_000.0, durationMs * 0.5)
        return thresholdMs > 0.0 && maxPositionMs >= thresholdMs
    }

    fun queueEntryFor(track: Track): QueueEntry = QueueEntry(
        mediaId = track.id,
        title = track.title.ifBlank { "Untitled track" },
        artist = track.artist.ifBlank { "Unknown artist" },
        artwork = track.artwork,
    )
}
