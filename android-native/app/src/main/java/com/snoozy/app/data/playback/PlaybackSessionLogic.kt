package com.snoozy.app.data.playback

import com.snoozy.app.data.mmkv.SnoozyJson
import com.snoozy.app.data.model.PlaybackSession
import com.snoozy.app.data.model.Track
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

data class ResolvedPlaybackSession(
    val activeTrack: Track,
    val activeIndex: Int,
    val queueTracks: List<Track>,
    val queueIds: List<String>,
    val positionSeconds: Double,
    val shuffle: Boolean,
    val repeatMode: String,
)

fun parsePlaybackSession(raw: String?): PlaybackSession? {
    if (raw.isNullOrEmpty()) return null
    val parsed = try {
        SnoozyJson.parseToJsonElement(raw) as? JsonObject ?: return null
    } catch (_: Exception) {
        return null
    }

    if (parsed.double("version") != 1.0) return null
    val activeTrackId = parsed.string("activeTrackId")?.takeIf { it.isNotEmpty() } ?: return null
    val queueIds = (parsed["queueIds"] as? JsonArray)
        ?.mapNotNull { element ->
            (element as? JsonPrimitive)?.takeIf { it.isString }?.content?.takeIf { it.isNotEmpty() }
        }
        ?: return null
    if (queueIds.isEmpty()) return null

    val queueIndex = parsed.double("queueIndex")
        ?.takeIf { it.isFinite() && floor(it) == it }
        ?.let { max(0.0, it).toInt() }
        ?: 0
    val positionSeconds = sanitizePosition(parsed.double("positionSeconds"))
    val repeatMode = parsed.string("repeatMode")?.takeIf { it in REPEAT_STATES } ?: "off"

    return PlaybackSession(
        activeTrackId = activeTrackId,
        queueIds = queueIds,
        queueIndex = queueIndex,
        positionSeconds = positionSeconds,
        shuffle = parsed.boolean("shuffle"),
        repeatMode = repeatMode,
        updatedAt = parsed.double("updatedAt")?.takeIf { it.isFinite() }?.toLong() ?: 0L,
    )
}

fun resolvePlaybackSession(
    session: PlaybackSession?,
    tracksById: Map<String, Track>,
): ResolvedPlaybackSession? {
    if (session == null || tracksById.isEmpty()) return null

    val queueTracks = mutableListOf<Track>()
    val queueIds = mutableListOf<String>()
    var activeIndexInFiltered = -1
    var fallbackIndexAfterDeleted = -1

    for ((index, id) in session.queueIds.withIndex()) {
        val track = tracksById[id] ?: continue
        val nextFilteredIndex = queueTracks.size
        queueTracks += track
        queueIds += track.id
        if (track.id == session.activeTrackId && activeIndexInFiltered == -1) {
            activeIndexInFiltered = nextFilteredIndex
        }
        if (index >= session.queueIndex && fallbackIndexAfterDeleted == -1) {
            fallbackIndexAfterDeleted = nextFilteredIndex
        }
    }

    if (queueTracks.isEmpty()) return null

    val activeTrackStillPresent = activeIndexInFiltered != -1
    val resolvedIndex = when {
        activeTrackStillPresent -> activeIndexInFiltered
        fallbackIndexAfterDeleted != -1 -> fallbackIndexAfterDeleted
        else -> queueTracks.size - 1
    }

    val activeTrack = queueTracks.getOrNull(resolvedIndex) ?: return null
    val positionSeconds = if (activeTrackStillPresent) {
        sanitizePosition(session.positionSeconds, activeTrack.duration)
    } else {
        0.0
    }

    return ResolvedPlaybackSession(
        activeTrack = activeTrack,
        activeIndex = resolvedIndex,
        queueTracks = queueTracks,
        queueIds = queueIds,
        positionSeconds = positionSeconds,
        shuffle = session.shuffle,
        repeatMode = session.repeatMode,
    )
}

private fun sanitizePosition(seconds: Double?, maxDuration: Double? = null): Double {
    val numeric = seconds?.takeIf { it.isFinite() } ?: 0.0
    val nonNegative = max(0.0, numeric)
    return if (maxDuration != null && maxDuration.isFinite() && maxDuration > 0) {
        min(nonNegative, maxDuration)
    } else {
        nonNegative
    }
}

private fun JsonObject.string(name: String): String? =
    (this[name] as? JsonPrimitive)?.takeIf { it.isString }?.content

private fun JsonObject.double(name: String): Double? =
    (this[name] as? JsonPrimitive)?.takeIf { !it.isString }?.content?.toDoubleOrNull()

private fun JsonObject.boolean(name: String): Boolean =
    (this[name] as? JsonPrimitive)?.content?.toBooleanStrictOrNull() ?: false

private val REPEAT_STATES = setOf("off", "all", "one")
