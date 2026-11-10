package com.snoozy.app.data.library

import com.snoozy.app.data.model.Album
import com.snoozy.app.data.model.PlayHistoryEntry
import com.snoozy.app.data.model.Track

data class PlayedTrack(val track: Track, val plays: Int)

/** Albums ordered by their newest track, with undated albums last. */
fun recentlyAdded(albums: List<Album>, limit: Int): List<Album> = albums
    .sortedWith { left, right ->
        right.addedAt.compareTo(left.addedAt).takeIf { it != 0 }
            ?: compareText(left.title, right.title)
    }
    .take(limit.coerceAtLeast(0))

/** Distinct, trimmed genre names in display order. */
fun genresOf(tracks: List<Track>): List<String> {
    val seen = LinkedHashMap<String, String>()
    for (track in tracks) {
        val genre = track.genre?.trim().orEmpty()
        if (genre.isEmpty()) continue
        seen.putIfAbsent(genre.lowercase(), genre)
    }
    return seen.values.sortedWith { left, right -> compareText(left, right) }
}

/** Aggregates play history into the most-played tracks that still exist. */
fun topPlayedTracks(
    tracks: List<Track>,
    history: List<PlayHistoryEntry>,
    limit: Int,
): List<PlayedTrack> {
    val counts = LinkedHashMap<String, Int>()
    for (entry in history) {
        counts[entry.trackId] = (counts[entry.trackId] ?: 0) + 1
    }

    val byId = tracks.associateBy { it.id }
    return counts.mapNotNull { (id, plays) ->
        byId[id]?.let { PlayedTrack(it, plays) }
    }.sortedWith { left, right ->
        right.plays.compareTo(left.plays).takeIf { it != 0 }
            ?: compareText(left.track.title, right.track.title)
    }.take(limit.coerceAtLeast(0))
}
