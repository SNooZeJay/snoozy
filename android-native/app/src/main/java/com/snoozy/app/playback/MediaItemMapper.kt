package com.snoozy.app.playback

import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import com.snoozy.app.data.model.Track
import java.io.File

object MediaItemMapper {
    fun resolveFilePath(rawUri: String): String? {
        if (!rawUri.startsWith("file://")) return null
        return rawUri.removePrefix("file://").takeIf { it.isNotEmpty() }
    }

    fun isNumericMediaStoreId(id: String): Boolean =
        id.isNotEmpty() && id.all(Char::isDigit)

    fun mediaStoreContentUriString(id: String): String =
        "content://media/external/audio/media/$id"

    fun playbackUriFor(
        track: Track,
        fileExists: (String) -> Boolean = { File(it).canRead() },
    ): Uri {
        val path = resolveFilePath(track.uri)
        if (path != null) {
            if (fileExists(path)) {
                return Uri.fromFile(File(path))
            }
            if (isNumericMediaStoreId(track.id)) {
                return Uri.parse(mediaStoreContentUriString(track.id))
            }
            return Uri.fromFile(File(path))
        }
        return Uri.parse(track.uri)
    }

    fun artworkUriFor(artwork: String?): Uri? {
        val raw = artwork?.takeIf { it.isNotBlank() } ?: return null
        val path = resolveFilePath(raw)
        return if (path != null) Uri.fromFile(File(path)) else Uri.parse(raw)
    }

    fun mediaItemFor(track: Track): MediaItem {
        val metadata = MediaMetadata.Builder()
            .setTitle(track.title.ifBlank { "Untitled track" })
            .setArtist(track.artist.ifBlank { "Unknown artist" })
            .setAlbumTitle(track.album.ifBlank { "Unknown album" })
            .apply {
                artworkUriFor(track.artwork)?.let(::setArtworkUri)
            }
            .build()

        return MediaItem.Builder()
            .setMediaId(track.id)
            .setUri(playbackUriFor(track))
            .setMediaMetadata(metadata)
            .build()
    }
}
