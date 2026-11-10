package com.snoozy.app.data.scan

import android.content.Context
import android.media.MediaMetadataRetriever
import android.provider.MediaStore
import android.util.Log
import com.snoozy.app.data.library.albumKeyFor
import com.snoozy.app.data.library.artworkCacheKey
import com.snoozy.app.data.library.compareText
import com.snoozy.app.data.library.fallbackTitleFromFilename
import com.snoozy.app.data.library.filePathFromUri
import com.snoozy.app.data.mmkv.SnoozyStores
import com.snoozy.app.data.model.MetadataCacheEntry
import com.snoozy.app.data.model.ScannedMetadata
import com.snoozy.app.data.model.Track
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withContext
import java.io.File
import java.util.concurrent.ConcurrentHashMap

/**
 * Mirrors expo-media-library's legacy asset shape and audio metadata cache.
 */
class LibraryScanner(private val context: Context, private val stores: SnoozyStores) {
    data class Result(
        val tracks: List<Track>,
        val fingerprint: String,
        val assetCount: Int,
        val latestModificationTime: Long,
    )

    private data class AudioAsset(
        val id: String,
        val uri: String,
        val filename: String,
        val duration: Double,
        val modificationTime: Long,
        val creationTime: Long?,
        val albumId: Long?,
    )

    private data class ResolvedAsset(
        val asset: AudioAsset,
        val albumTitle: String,
        val metadata: ScannedMetadata?,
    )

    suspend fun scan(): Result = withContext(Dispatchers.IO) {
        val assets = queryAssets()
        val albumTitles = queryAlbumTitles()
        val cache = stores.metadataCache().toMutableMap()
        var cacheDirty = false

        val resolved = mapWithConcurrency(assets, METADATA_CONCURRENCY) { asset ->
            val albumTitle = asset.albumId?.let { albumTitles[it] }.orEmpty()
            val cached = cache[asset.id]
            val metadata = if (cached != null && cached.modified == asset.modificationTime.toDouble()) {
                cached.value
            } else {
                readMetadata(asset, albumTitle)
            }
            ResolvedAsset(asset, albumTitle, metadata)
        }

        for (entry in resolved) {
            val cached = cache[entry.asset.id]
            if (entry.metadata != null &&
                (cached == null || cached.modified != entry.asset.modificationTime.toDouble())
            ) {
                cache[entry.asset.id] =
                    MetadataCacheEntry(entry.asset.modificationTime.toDouble(), entry.metadata)
                cacheDirty = true
            }
        }

        val collected = resolved.map {
            trackFromAsset(it.asset, it.albumTitle, it.metadata)
        }
        val artworkByAlbum = resolveArtwork(collected, assets)
        val withArtwork = collected.map { track ->
            track.copy(artwork = artworkByAlbum[albumKeyFor(track)])
        }

        val retained = assets.mapTo(HashSet()) { it.id }
        if (cache.keys.retainAll(retained)) cacheDirty = true
        if (cacheDirty) stores.saveMetadataCache(cache)

        val latest = assets.maxOfOrNull { it.modificationTime } ?: 0L
        val sorted = withArtwork.sortedWith { left, right -> compareText(left.title, right.title) }
        stores.saveScannedSnapshot(sorted)
        Result(sorted, "${assets.size}:$latest", assets.size, latest)
    }

    private fun queryAssets(): List<AudioAsset> {
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATE_MODIFIED,
            MediaStore.Audio.Media.DATE_TAKEN,
            MediaStore.Audio.Media.ALBUM_ID,
        )
        val assets = mutableListOf<AudioAsset>()
        context.contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            projection,
            null,
            null,
            "${MediaStore.Audio.Media._ID} ASC",
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val nameIndex = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
            val dataIndex = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            val durationIndex = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val modifiedIndex = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED)
            val takenIndex = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_TAKEN)
            val albumIndex = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)

            while (cursor.moveToNext()) {
                val data = cursor.getString(dataIndex) ?: continue
                assets += AudioAsset(
                    id = cursor.getLong(idIndex).toString(),
                    uri = "file://$data",
                    filename = cursor.getString(nameIndex) ?: data.substringAfterLast('/'),
                    duration = cursor.getLong(durationIndex) / 1000.0,
                    modificationTime = cursor.getLong(modifiedIndex) * 1000L,
                    creationTime = if (cursor.isNull(takenIndex)) null else cursor.getLong(takenIndex),
                    albumId = if (cursor.isNull(albumIndex)) null else cursor.getLong(albumIndex),
                )
            }
        }
        return assets
    }

    private fun queryAlbumTitles(): Map<Long, String> {
        val titles = mutableMapOf<Long, String>()
        try {
            context.contentResolver.query(
                MediaStore.Audio.Albums.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.Audio.Albums._ID, MediaStore.Audio.Albums.ALBUM),
                null,
                null,
                null,
            )?.use { cursor ->
                val idIndex = cursor.getColumnIndexOrThrow(MediaStore.Audio.Albums._ID)
                val albumIndex = cursor.getColumnIndexOrThrow(MediaStore.Audio.Albums.ALBUM)
                while (cursor.moveToNext()) {
                    val title = cursor.getString(albumIndex) ?: continue
                    titles[cursor.getLong(idIndex)] = title
                }
            }
        } catch (error: Exception) {
            // Embedded album tags are the primary source; this is only a fallback.
            Log.w(TAG, "Could not read MediaStore albums", error)
        }
        return titles
    }

    private fun readMetadata(asset: AudioAsset, albumTitle: String): ScannedMetadata? =
        readTags(filePathFromUri(asset.uri), asset.filename, albumTitle, asset.duration)

    /** Also used by SAF imports; call from IO. */
    internal fun readTags(
        path: String,
        filename: String,
        albumTitle: String,
        fallbackDuration: Double,
    ): ScannedMetadata? {
        if (!path.startsWith("/")) return null

        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)
            val artist = clean(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST))
                .ifEmpty { "Unknown artist" }
            val tagDuration = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toDoubleOrNull()

            ScannedMetadata(
                title = clean(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE))
                    .ifEmpty { fallbackTitleFromFilename(filename) },
                artist = artist,
                album = clean(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM))
                    .ifEmpty { clean(albumTitle).ifEmpty { "Unknown album" } },
                albumArtist = artist,
                year = clean(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_YEAR))
                    .ifEmpty { null },
                genre = clean(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_GENRE))
                    .ifEmpty { null },
                duration = if (tagDuration != null && tagDuration > 0) {
                    tagDuration / 1000.0
                } else {
                    fallbackDuration.coerceAtLeast(0.0)
                },
            )
        } catch (error: Exception) {
            Log.w(TAG, "Metadata failed for $filename", error)
            null
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
                // Nothing to release.
            }
        }
    }

    private fun trackFromAsset(
        asset: AudioAsset,
        albumTitle: String,
        metadata: ScannedMetadata?,
    ): Track = Track(
        id = asset.id,
        title = metadata?.title?.takeIf { it.isNotEmpty() }
            ?: fallbackTitleFromFilename(asset.filename),
        artist = metadata?.artist?.takeIf { it.isNotEmpty() } ?: "Unknown artist",
        album = metadata?.album?.takeIf { it.isNotEmpty() }
            ?: albumTitle.takeIf { it.isNotEmpty() }
            ?: "Unknown album",
        albumArtist = metadata?.albumArtist,
        year = metadata?.year,
        genre = metadata?.genre,
        trackNumber = metadata?.trackNumber,
        discNumber = metadata?.discNumber,
        uri = asset.uri,
        duration = metadata?.duration ?: asset.duration.coerceAtLeast(0.0),
        artwork = null,
        addedAt = asset.creationTime ?: asset.modificationTime,
    )

    private suspend fun resolveArtwork(
        tracks: List<Track>,
        assets: List<AudioAsset>,
    ): Map<String, String> = coroutineScope {
        val assetsById = assets.associateBy { it.id }
        val groups = LinkedHashMap<String, MutableList<Track>>()
        for (track in tracks) {
            groups.getOrPut(albumKeyFor(track)) { mutableListOf() }.add(track)
        }

        val resolved = ConcurrentHashMap<String, String>()
        val limit = Semaphore(ARTWORK_CONCURRENCY)
        groups.entries.map { (key, group) ->
            async {
                limit.withPermit {
                    // Try a few tracks in case the first file ships without a cover.
                    for (candidate in group.take(3)) {
                        val source = assetsById[candidate.id] ?: continue
                        val artwork = resolveAlbumArtwork(
                            candidate.uri,
                            artworkCacheKey(key, candidate.uri, source.modificationTime),
                        )
                        if (artwork != null) {
                            resolved[key] = artwork
                            break
                        }
                    }
                }
            }
        }.awaitAll()
        resolved
    }

    internal fun resolveAlbumArtwork(uri: String, cacheKey: String): String? {
        val directory = File(context.filesDir, "artwork")
        val target = File(directory, "$cacheKey.jpg")
        if (target.exists()) return "file://${target.absolutePath}"

        // Remember files that have no embedded cover so albums without art stay cheap.
        val missMarker = File(directory, "$cacheKey.none")
        if (missMarker.exists()) return null

        val path = filePathFromUri(uri)
        if (!path.startsWith("/")) return null

        return try {
            val retriever = MediaMetadataRetriever()
            val picture = try {
                retriever.setDataSource(path)
                retriever.embeddedPicture
            } finally {
                retriever.release()
            }
            directory.mkdirs()
            if (picture == null) {
                missMarker.writeText("")
                null
            } else {
                target.writeBytes(picture)
                "file://${target.absolutePath}"
            }
        } catch (error: Exception) {
            Log.w(TAG, "Artwork failed for $uri", error)
            null
        }
    }

    private suspend fun <T, R> mapWithConcurrency(
        items: List<T>,
        limit: Int,
        map: suspend (T) -> R,
    ): List<R> = coroutineScope {
        val semaphore = Semaphore(limit)
        items.map { item ->
            async { semaphore.withPermit { map(item) } }
        }.awaitAll()
    }

    private fun clean(value: String?): String = value?.trim().orEmpty()

    companion object {
        private const val TAG = "SnoozyData"
        private const val METADATA_CONCURRENCY = 4
        private const val ARTWORK_CONCURRENCY = 2
    }
}
