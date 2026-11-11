package com.snoozy.app.data.library

import com.snoozy.app.data.model.Playlist
import com.snoozy.app.data.model.Track

/** Transforms return the input list when nothing changes so the repository can skip the MMKV write. */
object PlaylistOps {
    fun playlistId(createdAt: Long, suffix: String): String = "playlist-$createdAt-$suffix"

    fun playlistSuffix(value: Long): String =
        java.lang.Long.toString(value, 36).takeLast(6).padStart(6, '0')

    fun create(playlists: List<Playlist>, name: String, id: String, createdAt: Long): List<Playlist> {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return playlists
        val playlist = Playlist(id = id, name = trimmed, trackIds = emptyList(), createdAt = createdAt)
        return listOf(playlist) + playlists
    }

    fun rename(playlists: List<Playlist>, id: String, name: String, updatedAt: Long): List<Playlist> {
        val trimmed = name.trim()
        if (trimmed.isEmpty() || playlists.none { it.id == id }) return playlists
        return playlists.map { if (it.id == id) it.copy(name = trimmed, updatedAt = updatedAt) else it }
    }

    fun delete(playlists: List<Playlist>, id: String): List<Playlist> {
        val next = playlists.filter { it.id != id }
        return if (next.size == playlists.size) playlists else next
    }

    fun addTrack(playlists: List<Playlist>, id: String, trackId: String): List<Playlist> {
        val playlist = playlists.firstOrNull { it.id == id } ?: return playlists
        if (trackId in playlist.trackIds) return playlists
        return playlists.map {
            if (it.id == id) it.copy(trackIds = it.trackIds + trackId) else it
        }
    }

    fun removeTrack(playlists: List<Playlist>, id: String, trackId: String): List<Playlist> {
        val playlist = playlists.firstOrNull { it.id == id } ?: return playlists
        val trackIds = playlist.trackIds.filterNot { it == trackId }
        if (trackIds.size == playlist.trackIds.size) return playlists
        return playlists.map { if (it.id == id) it.copy(trackIds = trackIds) else it }
    }

    fun moveTrack(playlists: List<Playlist>, id: String, from: Int, to: Int): List<Playlist> {
        val playlist = playlists.firstOrNull { it.id == id } ?: return playlists
        if (from == to) return playlists
        if (from !in playlist.trackIds.indices || to !in playlist.trackIds.indices) return playlists
        val trackIds = playlist.trackIds.toMutableList()
        trackIds.add(to, trackIds.removeAt(from))
        if (trackIds == playlist.trackIds) return playlists
        return playlists.map { if (it.id == id) it.copy(trackIds = trackIds) else it }
    }

    fun matches(track: Track, query: String): Boolean {
        val needle = query.trim().lowercase()
        if (needle.isEmpty()) return true
        val haystack = "${track.title} ${track.artist} ${track.album}".lowercase()
        return needle in haystack
    }
}
