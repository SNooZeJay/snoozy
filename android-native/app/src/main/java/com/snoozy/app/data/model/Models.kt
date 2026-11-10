package com.snoozy.app.data.model

import kotlinx.serialization.Serializable

@Serializable
data class Track(
    val id: String,
    val title: String,
    val artist: String,
    val album: String,
    val albumArtist: String? = null,
    val year: String? = null,
    val genre: String? = null,
    val trackNumber: String? = null,
    val discNumber: String? = null,
    val uri: String,
    val duration: Double = 0.0,
    val artwork: String? = null,
    val addedAt: Long = 0L,
)

@Serializable
data class Album(
    val id: String,
    val title: String,
    val artist: String,
    val albumArtist: String,
    val year: String? = null,
    val artwork: String? = null,
    val trackIds: List<String>,
    val duration: Double = 0.0,
    val addedAt: Long = 0L,
)

@Serializable
data class Playlist(
    val id: String,
    val name: String,
    val trackIds: List<String>,
    val createdAt: Long,
    val description: String? = null,
    val artworkPath: String? = null,
    val updatedAt: Long? = null,
)

@Serializable
data class PlaybackSession(
    val version: Int = 1,
    val activeTrackId: String,
    val queueIds: List<String>,
    val queueIndex: Int,
    val positionSeconds: Double,
    val shuffle: Boolean,
    val repeatMode: String,
    val updatedAt: Long,
)

@Serializable
data class ScannedMetadata(
    val title: String,
    val artist: String,
    val album: String,
    val albumArtist: String,
    val year: String? = null,
    val genre: String? = null,
    val trackNumber: String? = null,
    val discNumber: String? = null,
    val duration: Double = 0.0,
)

@Serializable
data class MetadataCacheEntry(
    val modified: Double,
    val value: ScannedMetadata,
)

data class FavoriteRow(
    val identity: String,
    val title: String,
    val artist: String,
    val album: String,
    val duration: Double,
    val artwork: String?,
    val addedAt: Long,
)

data class TrackOverride(
    val trackId: String,
    val title: String? = null,
    val artist: String? = null,
    val album: String? = null,
    val albumArtist: String? = null,
    val genre: String? = null,
    val year: String? = null,
    val trackNumber: String? = null,
    val description: String? = null,
    val artworkPath: String? = null,
    val updatedAt: Long = 0L,
)

data class AlbumOverride(
    val albumKey: String,
    val title: String? = null,
    val artist: String? = null,
    val description: String? = null,
    val artworkPath: String? = null,
    val updatedAt: Long = 0L,
)

data class ArtistOverride(
    val artistKey: String,
    val name: String? = null,
    val description: String? = null,
    val artworkPath: String? = null,
    val updatedAt: Long = 0L,
)

data class PlayHistoryEntry(
    val trackId: String,
    val playedAt: Long,
    val durationListenedMs: Long,
)

data class ListeningSession(
    val id: Long,
    val trackId: String,
    val startedAt: Long,
    val endedAt: Long?,
    val durationSeconds: Long,
)
