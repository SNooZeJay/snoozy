package com.snoozy.app.data.library

import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import com.snoozy.app.data.db.SnoozyDatabases
import com.snoozy.app.data.mmkv.SnoozyStores
import com.snoozy.app.data.mmkv.StoreFailureException
import com.snoozy.app.data.model.Album
import com.snoozy.app.data.model.MetadataCacheEntry
import com.snoozy.app.data.model.PlayHistoryEntry
import com.snoozy.app.data.model.Playlist
import com.snoozy.app.data.model.Track
import com.snoozy.app.data.scan.LibraryScanner
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.File
import java.util.UUID
import kotlin.random.Random

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
        val history: List<PlayHistoryEntry> = emptyList(),
        val favoriteTrackIds: Set<String> = emptySet(),
        val songSort: SongSort = SongSort.Title,
        val albumSort: AlbumSort = AlbumSort.Title,
        val hasPermission: Boolean = false,
        val scanning: Boolean = false,
        val error: String? = null,
    )

    private val mutationMutex = Mutex()
    private val _state = MutableStateFlow(State(hasPermission = hasAudioPermission()))
    val state: StateFlow<State> = _state.asStateFlow()

    fun hasAudioPermission(): Boolean =
        context.checkSelfPermission(android.Manifest.permission.READ_MEDIA_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    suspend fun refresh(scan: Boolean = true): LibraryScanner.Result? = withContext(Dispatchers.IO) {
        mutationMutex.withLock {
            val permission = hasAudioPermission()
            _state.update {
                it.copy(hasPermission = permission, scanning = scan && permission, error = null)
            }
            try {
                val result = if (scan && permission) scanner.scan() else null
                _state.value = loadedState(permission)
                result
            } catch (error: Exception) {
                Log.w(TAG, "Library refresh failed", error)
                _state.update {
                    it.copy(
                        scanning = false,
                        error = error.message ?: "Could not read the music library.",
                    )
                }
                null
            }
        }
    }

    suspend fun importDocuments(uris: List<Uri>): Int = withContext(Dispatchers.IO) {
        mutationMutex.withLock {
            if (uris.isEmpty()) return@withLock 0
            val imported = stores.importedTracksForUpdate().toMutableList()
            val metadataCache = stores.metadataCacheForUpdate().toMutableMap()
            var cacheDirty = false
            val musicDirectory = File(context.filesDir, "Music").apply { mkdirs() }
            val copiedFiles = mutableListOf<File>()
            var added = 0

            for ((index, uri) in uris.withIndex()) {
                val filename = safeImportName(displayName(uri), index)
                val target = copyImport(uri, musicDirectory, filename) ?: continue
                copiedFiles += target

                val id =
                    "imported-${System.currentTimeMillis()}-$index-${UUID.randomUUID().toString().take(6)}"
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
                        ?: filename.replace(Regex("\\.[^.]+$"), "").trim()
                            .ifEmpty { "Imported track" },
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

            if (!stores.saveImportedTracks(imported)) {
                copiedFiles.forEach { it.delete() }
                throw StoreFailureException("Could not save imported tracks.")
            }
            if (cacheDirty) stores.saveMetadataCache(metadataCache)
            _state.value = loadedState(hasAudioPermission())
            added
        }
    }

    private fun loadedState(permission: Boolean): State {
        val merged = mergeTracks(stores.importedTracks(), stores.scannedSnapshot())
        val favoriteIdentities = databases.favorites().mapTo(HashSet()) { it.identity }
        return State(
            tracks = merged,
            albums = buildAlbums(merged),
            playlists = stores.playlists(),
            recents = stores.recents(),
            history = databases.playHistory(),
            favoriteTrackIds = merged
                .filter { it.uri in favoriteIdentities }
                .mapTo(HashSet()) { it.id },
            songSort = SongSort.fromStored(stores.songSort()),
            albumSort = AlbumSort.fromStored(stores.albumSort()),
            hasPermission = permission,
        )
    }

    private suspend fun mutatePlaylists(
        transform: (List<Playlist>) -> List<Playlist>,
    ): List<Playlist>? = withContext(Dispatchers.IO) {
        mutationMutex.withLock {
            try {
                val current = stores.playlistsForUpdate()
                val next = transform(current)
                if (next !== current && !stores.savePlaylists(next)) {
                    throw StoreFailureException("Could not save playlists.")
                }
                _state.update { it.copy(playlists = next) }
                next
            } catch (error: kotlinx.coroutines.CancellationException) {
                throw error
            } catch (error: Exception) {
                Log.w(TAG, "Playlist write failed", error)
                _state.update { it.copy(error = "Could not save playlist.") }
                null
            }
        }
    }

    suspend fun createPlaylist(name: String): String? {
        if (name.isBlank()) return null
        val now = System.currentTimeMillis()
        val id = PlaylistOps.playlistId(now, PlaylistOps.playlistSuffix(Random.nextLong().ushr(1)))
        return mutatePlaylists { PlaylistOps.create(it, name, id, now) }?.let { id }
    }

    suspend fun renamePlaylist(id: String, name: String): Boolean =
        mutatePlaylists { PlaylistOps.rename(it, id, name, System.currentTimeMillis()) } != null

    suspend fun deletePlaylist(id: String): Boolean =
        mutatePlaylists { PlaylistOps.delete(it, id) } != null

    suspend fun addToPlaylist(id: String, trackId: String): Boolean =
        mutatePlaylists { PlaylistOps.addTrack(it, id, trackId) } != null

    suspend fun removeFromPlaylist(id: String, trackId: String): Boolean =
        mutatePlaylists { PlaylistOps.removeTrack(it, id, trackId) } != null

    suspend fun movePlaylistTrack(id: String, from: Int, to: Int): Boolean =
        mutatePlaylists { PlaylistOps.moveTrack(it, id, from, to) } != null

    suspend fun clearRecents(): Boolean = withContext(Dispatchers.IO) {
        mutationMutex.withLock {
            val saved = stores.saveRecents(emptyList())
            val historyCleared = databases.clearPlayHistory()
            val sessionsCleared = databases.clearListeningSessions()
            val ok = saved && historyCleared && sessionsCleared
            _state.value = loadedState(hasAudioPermission()).let { loaded ->
                if (ok) loaded else loaded.copy(error = "Could not clear play history.")
            }
            ok
        }
    }

    suspend fun setSongSort(sort: SongSort) = withContext(Dispatchers.IO) {
        if (!stores.saveSongSort(sort.storageValue)) {
            Log.w(TAG, "Could not persist song sort")
        }
        _state.update { it.copy(songSort = sort) }
    }

    suspend fun setAlbumSort(sort: AlbumSort) = withContext(Dispatchers.IO) {
        if (!stores.saveAlbumSort(sort.storageValue)) {
            Log.w(TAG, "Could not persist album sort")
        }
        _state.update { it.copy(albumSort = sort) }
    }

    fun clearError() {
        _state.update { it.copy(error = null) }
    }

    private fun copyImport(uri: Uri, directory: File, filename: String): File? {
        val target = uniqueTarget(directory, filename)
        val temp = File.createTempFile("import-", ".part", directory)
        return try {
            context.contentResolver.openInputStream(uri)?.use { input ->
                temp.outputStream().use { output -> input.copyTo(output) }
            } ?: return null
            if (temp.renameTo(target)) target else null
        } catch (error: Exception) {
            Log.w(TAG, "Import copy failed for $uri", error)
            null
        } finally {
            if (temp.exists()) temp.delete()
        }
    }

    private fun safeImportName(raw: String?, index: Int): String {
        val name = raw?.let { File(it).name }?.trim().orEmpty()
        return if (name.isEmpty() || name == "." || name == "..") {
            "audio-${System.currentTimeMillis()}-$index"
        } else {
            name
        }
    }

    private fun uniqueTarget(directory: File, filename: String): File {
        val direct = File(directory, filename)
        if (!direct.exists()) return direct

        val dot = filename.lastIndexOf('.')
        val base = if (dot > 0) filename.substring(0, dot) else filename
        val extension = if (dot > 0) filename.substring(dot) else ""
        var counter = 1
        while (true) {
            val candidate = File(directory, "$base ($counter)$extension")
            if (!candidate.exists()) return candidate
            counter += 1
        }
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
