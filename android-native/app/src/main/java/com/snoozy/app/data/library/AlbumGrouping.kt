package com.snoozy.app.data.library

import com.snoozy.app.data.model.Album
import com.snoozy.app.data.model.Track
import java.text.Collator
import java.util.Locale

private const val UNKNOWN_ALBUM = "unknown album"
private const val UNKNOWN_ARTIST = "unknown artist"

// localeCompare orders case-insensitively; Collator matches that better than compareTo.
private val collator = ThreadLocal.withInitial { Collator.getInstance(Locale.getDefault()) }

internal fun compareText(left: String, right: String): Int = collator.get().compare(left, right)

private fun clean(value: String?): String = value?.trim().orEmpty()

private fun normalize(value: String): String =
    value.replace(Regex("\\s+"), " ").trim().lowercase()

fun stableHash(value: String): String {
    var hash = 2166136261L
    for (char in value) {
        hash = hash xor char.code.toLong()
        hash = (hash * 16777619L) and 0xffffffffL
    }
    return hash.toString(36)
}

private fun decodedPath(uri: String): String = filePathFromUri(uri)

fun folderNameForUri(uri: String): String {
    val parts = decodedPath(uri).split('/').filter { it.isNotEmpty() }
    return if (parts.size > 1) parts[parts.size - 2] else ""
}

fun albumTitleFor(track: Track): String = albumTitleFor(track.album, track.uri)

private fun albumTitleFor(album: String?, uri: String): String {
    val cleaned = clean(album)
    if (cleaned.isNotEmpty() && normalize(cleaned) != UNKNOWN_ALBUM) return cleaned
    return folderNameForUri(uri).ifEmpty { "Unknown album" }
}

private fun artistNameFor(track: Track): String =
    artistNameFor(track.albumArtist, track.artist)

private fun artistNameFor(albumArtist: String?, artist: String?): String {
    val cleanedAlbumArtist = clean(albumArtist)
    if (cleanedAlbumArtist.isNotEmpty() && normalize(cleanedAlbumArtist) != UNKNOWN_ARTIST) {
        return cleanedAlbumArtist
    }

    val cleanedArtist = clean(artist)
    return if (cleanedArtist.isNotEmpty() && normalize(cleanedArtist) != UNKNOWN_ARTIST) {
        cleanedArtist
    } else {
        ""
    }
}

fun albumKeyFor(track: Track): String =
    albumKeyFor(track.album, track.albumArtist, track.artist, track.uri)

fun albumKeyFor(
    album: String?,
    albumArtist: String?,
    artist: String?,
    uri: String,
): String {
    val title = normalize(albumTitleFor(album, uri))
    val artist = normalize(artistNameFor(albumArtist, artist))
        .ifEmpty { normalize(folderNameForUri(uri)) }
    return "album-${stableHash("$artist::$title")}"
}

private fun leadingNumber(value: String?): Int? {
    val match = Regex("^(\\d{1,3})(?:\\D|$)").find(clean(value)) ?: return null
    return match.groupValues[1].toIntOrNull()
}

fun trackNumberFor(track: Track): Int? {
    leadingNumber(track.trackNumber)?.let { return it }

    val filename = decodedPath(track.uri).split('/').lastOrNull().orEmpty()
    return leadingNumber(filename)
}

fun discNumberFor(track: Track): Int? = leadingNumber(track.discNumber)

fun sortAlbumTracks(tracks: List<Track>): List<Track> = tracks.sortedWith { left, right ->
    val discDifference = (discNumberFor(left) ?: 0) - (discNumberFor(right) ?: 0)
    if (discDifference != 0) return@sortedWith discDifference

    val leftTrack = trackNumberFor(left)
    val rightTrack = trackNumberFor(right)
    if (leftTrack != null && rightTrack != null && leftTrack != rightTrack) {
        return@sortedWith leftTrack - rightTrack
    }
    if (leftTrack != null && rightTrack == null) return@sortedWith -1
    if (leftTrack == null && rightTrack != null) return@sortedWith 1

    compareText(left.title, right.title)
}

fun buildAlbums(tracks: List<Track>): List<Album> {
    val groups = LinkedHashMap<String, MutableList<Track>>()

    for (track in tracks) {
        groups.getOrPut(albumKeyFor(track)) { mutableListOf() }.add(track)
    }

    return groups.map { (id, group) ->
        val ordered = sortAlbumTracks(group)
        val first = ordered.first()
        val artists = group.map(::artistNameFor).filter { it.isNotEmpty() }
        val albumArtist = artists.firstOrNull() ?: "Unknown artist"
        val year = group.map { clean(it.year) }.firstOrNull { it.isNotEmpty() }
        val artwork = group.firstOrNull { !it.artwork.isNullOrEmpty() }?.artwork
        val duration = group.sumOf { if (it.duration.isFinite()) it.duration else 0.0 }

        Album(
            id = id,
            title = albumTitleFor(first),
            artist = albumArtist,
            albumArtist = albumArtist,
            year = year,
            artwork = artwork,
            trackIds = ordered.map { it.id },
            duration = duration,
            addedAt = group.maxOf { it.addedAt },
        )
    }.sortedWith { left, right ->
        compareText(left.title, right.title).takeIf { it != 0 }
            ?: compareText(left.artist, right.artist)
    }
}
