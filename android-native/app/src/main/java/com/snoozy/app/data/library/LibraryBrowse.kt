package com.snoozy.app.data.library

import com.snoozy.app.data.model.Album
import com.snoozy.app.data.model.Track

enum class SongSort(val storageValue: String, val label: String) {
    Title("title", "Title"),
    Artist("artist", "Artist"),
    Album("album", "Album"),
    Duration("duration", "Duration");

    companion object {
        fun fromStored(value: String?): SongSort =
            entries.firstOrNull { it.storageValue == value } ?: Title
    }
}

enum class AlbumSort(val storageValue: String, val label: String) {
    Title("title", "Title"),
    Artist("artist", "Artist"),
    Year("year", "Year"),
    Tracks("tracks", "Tracks");

    companion object {
        fun fromStored(value: String?): AlbumSort =
            entries.firstOrNull { it.storageValue == value } ?: Title
    }
}

private fun finiteDuration(track: Track): Double =
    if (track.duration.isFinite()) track.duration else 0.0

fun sortedTracks(tracks: List<Track>, sort: SongSort): List<Track> = tracks.sortedWith { left, right ->
    when (sort) {
        SongSort.Title -> compareText(left.title, right.title)
        SongSort.Artist -> compareText(left.artist, right.artist)
            .takeIf { it != 0 }
            ?: compareText(left.album, right.album).takeIf { it != 0 }
            ?: compareText(left.title, right.title)
        SongSort.Album -> compareText(left.album, right.album)
            .takeIf { it != 0 }
            ?: compareText(left.title, right.title)
        SongSort.Duration -> finiteDuration(right).compareTo(finiteDuration(left))
            .takeIf { it != 0 }
            ?: compareText(left.title, right.title)
    }
}

/** Mirrors parseInt in the React Native album comparator: leading number or zero. */
fun yearOrZero(value: String?): Int =
    Regex("^\\s*([+-]?\\d+)").find(value.orEmpty())
        ?.groupValues?.get(1)?.toIntOrNull() ?: 0

fun sortedAlbums(albums: List<Album>, sort: AlbumSort): List<Album> = albums.sortedWith { left, right ->
    when (sort) {
        AlbumSort.Title -> compareText(left.title, right.title)
        AlbumSort.Artist -> compareText(left.artist, right.artist)
            .takeIf { it != 0 }
            ?: compareText(left.title, right.title)
        AlbumSort.Year -> yearOrZero(right.year).compareTo(yearOrZero(left.year))
            .takeIf { it != 0 }
            ?: compareText(left.title, right.title)
        AlbumSort.Tracks -> right.trackIds.size.compareTo(left.trackIds.size)
            .takeIf { it != 0 }
            ?: compareText(left.title, right.title)
    }
}

/** Distinct artist tags in the order React Native produces, without album-artist fallback. */
fun artistNamesOf(tracks: List<Track>): List<String> =
    tracks.map { it.artist }.distinct().sorted()

fun tracksForArtist(tracks: List<Track>, artist: String): List<Track> =
    tracks.filter { it.artist == artist }

fun tracksForGenre(tracks: List<Track>, genre: String): List<Track> {
    val wanted = genre.trim().lowercase()
    if (wanted.isEmpty()) return emptyList()
    return tracks.filter { it.genre?.trim()?.lowercase() == wanted }
}

fun albumsForArtist(
    albums: List<Album>,
    tracks: List<Track>,
    artist: String,
): List<Album> {
    val ids = tracksForArtist(tracks, artist).mapTo(HashSet()) { albumKeyFor(it) }
    return albums.filter { it.id in ids }
}

fun tracksForIds(tracks: List<Track>, ids: List<String>, limit: Int): List<Track> {
    val byId = tracks.associateBy { it.id }
    return ids.mapNotNull { byId[it] }.take(limit.coerceAtLeast(0))
}

fun favoriteTracks(tracks: List<Track>, favoriteIds: Set<String>): List<Track> =
    tracks.filter { it.id in favoriteIds }

fun libraryStatus(hasPermission: Boolean, scanning: Boolean, trackCount: Int): String = when {
    !hasPermission -> "Permission needed"
    scanning -> "Scanning…"
    trackCount == 0 -> "No songs yet"
    trackCount == 1 -> "1 song"
    else -> "$trackCount songs"
}
