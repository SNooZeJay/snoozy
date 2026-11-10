package com.snoozy.app.data.library

import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import com.snoozy.app.data.db.SnoozyDatabases
import com.snoozy.app.data.mmkv.SnoozyStores
import com.snoozy.app.data.model.Album
import com.snoozy.app.data.model.MetadataCacheEntry
import com.snoozy.app.data.model.Playlist
import com.snoozy.app.data.model.Track
import com.snoozy.app.data.scan.LibraryScanner
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.withContext
import java.io.File
import java.util.UUID

class LibraryRepository(
    private val context: Context,
    private val stores: SnoozyStores,
    private val scanner: LibraryScanner,
    private val databases: SnoozyDatabases,
) {
    data class State(
        val tracks: List<Track> = emptyList(),
        val albums: List<Album> = emptyList(),
        val playlists: List<Playlist> = emptyList(),
        val recents: List<String> = emptyList(),
        val favoriteTrackIds: Set<String> = emptySet(),
        val hasPermission: Boolean = false,
        val scanning: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(initialState())
    val state: StateFlow<State> = _state.asStateFlow()

    fun hasAudioPermission(): Boolean =
        context.checkSelfPermission(android.Manifest.permission.READ_MEDIA_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    suspend fun refresh(scan: Boolean = true): LibraryScanner.Result? = withContext(Dispatchers.IO) {
        val permission = hasAudioPermission()
        _state.update { it.copy(hasPermission = permission, scanning = scan && permission, error = null) }
        try {
            val result = if (scan && permission) scanner.scan() else null
            _state.value = loadedState(permission)
            result
        } catch (error: Exception) {
            Log.w(TAG, "Library refresh failed", error)
            _state.update {
                it.copy(scanning = false, error = error.message ?: "Could not read the music library.")
            }
            null
        }
    }

    suspend fun importDocuments(uris: List<Uri>): Int = withContext(Dispatchers.IO) {
        if (uris.isEmpty()) return@withContext 0
        val imported = stores.importedTracks().toMutableList()
        val metadataCache = stores.metadataCache().toMutableMap()
        var cacheDirty = false
        val musicDirectory = File(context.filesDir, "Music").apply { mkdirs() }
        var added = 0

        for ((index, uri) in uris.withIndex()) {
            val filename = displayName(uri) ?: "audio-${System.currentTimeMillis()}-$index"
            val target = File(musicDirectory, filename)
            try {
                context.contentResolver.openInputStream(uri)?.use { input ->
                    target.outputStream().use { output -> input.copyTo(output) }
                } ?: continue
            } catch (error: Exception) {
                Log.w(TAG, "Import copy failed for $uri", error)
                continue
            }

            val id = "imported-${System.currentTimeMillis()}-$index-${UUID.randomUUID().toString().take(6)}"
            val modified = System.currentTimeMillis()
            val fileUri = "file://${target.absolutePath}"
            val metadata = scanner.readTags(target.absolutePath, filename, "Imported", 0.0)
            if (metadata != null) {
                metadataCache[id] = MetadataCacheEntry(modified.toDouble(), metadata)
                cacheDirty = true
            }
            val albumKey = albumKeyFor(
                album = metadata?.album ?: "Imported",
                albumArtist = metadata?.albumArtist ?: metadata?.artist ?: "Imported",
                artist = metadata?.artist ?: "Imported",
                uri = fileUri,
            )
            val artwork = scanner.resolveAlbumArtwork(
                fileUri,
                artworkCacheKey(albumKey, fileUri, modified),
            )

            imported += Track(
                id = id,
                title = metadata?.title?.takeIf { it.isNotEmpty() }
                    ?: filename.replace(Regex("\\.[^.]+$"), "").trim().ifEmpty { "Imported track" },
                artist = metadata?.artist ?: "Imported",
                album = metadata?.album ?: "Imported",
                albumArtist = metadata?.albumArtist,
                year = metadata?.year,
                genre = metadata?.genre,
                trackNumber = metadata?.trackNumber,
                discNumber = metadata?.discNumber,
                uri = fileUri,
                duration = metadata?.duration ?: 0.0,
                artwork = artwork,
                addedAt = modified,
            )
            added += 1
        }

        stores.saveImportedTracks(imported)
        if (cacheDirty) stores.saveMetadataCache(metadataCache)
        _state.value = loadedState(hasAudioPermission())
        added
    }

    private fun initialState(): State {
        val merged = merge(stores.importedTracks(), stores.scannedSnapshot())
        return State(
            tracks = merged,
            albums = buildAlbums(merged),
            playlists = stores.playlists(),
            recents = stores.recents(),
            hasPermission = hasAudioPermission(),
        )
    }

    private fun loadedState(permission: Boolean): State {
        val merged = merge(stores.importedTracks(), stores.scannedSnapshot())
        val favoriteIdentities = databases.favorites().mapTo(HashSet()) { it.identity }
        return State(
            tracks = merged,
            albums = buildAlbums(merged),
            playlists = stores.playlists(),
            recents = stores.recents(),
            favoriteTrackIds = merged
                .filter { it.uri in favoriteIdentities }
                .mapTo(HashSet()) { it.id },
            hasPermission = permission,
        )
    }

    private fun merge(imported: List<Track>, scanned: List<Track>): List<Track> {
        val seen = HashSet<String>()
        val merged = ArrayList<Track>(imported.size + scanned.size)
        for (track in imported + scanned) {
            if (!seen.add(track.uri)) continue
            merged += track
        }
        return merged.sortedWith { left, right -> compareText(left.title, right.title) }
    }

    private fun displayName(uri: Uri): String? = try {
        context.contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) cursor.getString(0) else null
        }
    } catch (_: Exception) {
        null
    }

    companion object {
        private const val TAG = "SnoozyData"
    }
}
