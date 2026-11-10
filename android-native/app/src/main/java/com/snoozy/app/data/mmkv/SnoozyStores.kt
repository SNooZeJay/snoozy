package com.snoozy.app.data.mmkv

import android.content.Context
import android.util.Log
import com.snoozy.app.data.model.MetadataCacheEntry
import com.snoozy.app.data.model.PlaybackSession
import com.snoozy.app.data.model.Playlist
import com.snoozy.app.data.model.Track
import com.snoozy.app.data.playback.parsePlaybackSession
import com.tencent.mmkv.MMKV
import kotlinx.serialization.KSerializer
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import java.io.File

class StoreFailureException(message: String, cause: Throwable? = null) : Exception(message, cause)

/**
 * Typed access to the seven react-native-mmkv stores. The directory and IDs match
 * MMKV's defaults under expo, so the files are opened in place. Each store opens
 * lazily so a corrupt file cannot crash Application.onCreate.
 */
class SnoozyStores(context: Context) {
    private val opened = HashMap<String, Result<MMKV>>()

    init {
        try {
            MMKV.initialize(context, File(context.filesDir, "mmkv").absolutePath)
        } catch (error: Exception) {
            Log.e(TAG, "MMKV initialization failed", error)
        }
    }

    val storeIds: List<String> = listOf(MUSIC, PLAYBACK, THEME, PREFERENCES, SEARCH, LYRICS, AUDIO)

    private fun store(id: String): MMKV? = synchronized(opened) {
        opened.getOrPut(id) {
            try {
                Result.success(MMKV.mmkvWithID(id))
            } catch (error: Exception) {
                Log.e(TAG, "Could not open $id", error)
                Result.failure(error)
            }
        }.getOrNull()
    }

    fun keyCount(): Int = storeIds.sumOf { id ->
        try {
            store(id)?.allKeys()?.size ?: 0
        } catch (error: Exception) {
            Log.w(TAG, "Could not count $id", error)
            0
        }
    }

    fun scannedSnapshot(): List<Track> = readList(MUSIC, SCANNED_SNAPSHOT, Track.serializer())

    fun scannedSnapshotForUpdate(): List<Track> =
        readListForUpdate(MUSIC, SCANNED_SNAPSHOT, Track.serializer())

    fun saveScannedSnapshot(tracks: List<Track>): Boolean =
        writeJson(MUSIC, SCANNED_SNAPSHOT, ListSerializer(Track.serializer()), tracks)

    fun importedTracks(): List<Track> = readList(MUSIC, IMPORTED, Track.serializer())

    fun importedTracksForUpdate(): List<Track> =
        readListForUpdate(MUSIC, IMPORTED, Track.serializer())

    fun saveImportedTracks(tracks: List<Track>): Boolean =
        writeJson(MUSIC, IMPORTED, ListSerializer(Track.serializer()), tracks)

    fun playlists(): List<Playlist> = readList(MUSIC, PLAYLISTS, Playlist.serializer())

    fun savePlaylists(playlists: List<Playlist>): Boolean =
        writeJson(MUSIC, PLAYLISTS, ListSerializer(Playlist.serializer()), playlists)

    fun recents(): List<String> = readList(MUSIC, RECENTS, String.serializer())

    fun saveRecents(ids: List<String>): Boolean =
        writeJson(MUSIC, RECENTS, ListSerializer(String.serializer()), ids)

    fun songSort(): String? = readStore(MUSIC, null) { it.decodeString(SONG_SORT) }

    fun saveSongSort(sort: String): Boolean = writeStore(MUSIC) { it.encode(SONG_SORT, sort) }

    fun albumSort(): String? = readStore(MUSIC, null) { it.decodeString(ALBUM_SORT) }

    fun saveAlbumSort(sort: String): Boolean = writeStore(MUSIC) { it.encode(ALBUM_SORT, sort) }

    fun playbackSession(): PlaybackSession? = readStore(PLAYBACK, null) { store ->
        store.decodeString(SESSION)?.let(::parsePlaybackSession)
    }

    fun savePlaybackSession(session: PlaybackSession): Boolean =
        writeStore(PLAYBACK) {
            it.encode(SESSION, SnoozyJson.encodeToString(PlaybackSession.serializer(), session))
        }

    fun clearPlaybackSession(): Boolean = writeStore(PLAYBACK) { it.removeValueForKey(SESSION) }

    fun queueIds(): List<String> = readList(PLAYBACK, QUEUE_IDS, String.serializer())

    fun saveQueueIds(ids: List<String>): Boolean =
        writeJson(PLAYBACK, QUEUE_IDS, ListSerializer(String.serializer()), ids)

    fun repeatMode(): String? = readStore(PLAYBACK, null) { it.decodeString(REPEAT_MODE) }

    fun saveRepeatMode(mode: String): Boolean = writeStore(PLAYBACK) { it.encode(REPEAT_MODE, mode) }

    fun shuffle(): Boolean = readStore(PLAYBACK, false) { it.decodeBool(SHUFFLE, false) }

    fun saveShuffle(enabled: Boolean): Boolean = writeStore(PLAYBACK) { it.encode(SHUFFLE, enabled) }

    fun playbackRate(): Double = readStore(PLAYBACK, 1.0) { it.decodeDouble(PLAYBACK_RATE, 1.0) }

    fun savePlaybackRate(rate: Double): Boolean =
        writeStore(PLAYBACK) { it.encode(PLAYBACK_RATE, rate) }

    fun themeMode(): String? = readStore(THEME, null) { it.decodeString(THEME_MODE) }

    fun paletteStyle(): String? = readStore(THEME, null) { it.decodeString(PALETTE_STYLE) }

    fun themeSeed(): String? = readStore(THEME, null) { it.decodeString(SEED) }

    fun backdropEnabled(): Boolean = readStore(THEME, true) { it.decodeBool(BACKDROP_ENABLED, true) }

    fun backdropIntensity(): Double =
        readStore(THEME, 60.0) { it.decodeDouble(BACKDROP_INTENSITY, 60.0) }

    fun motionMode(): String? = readStore(THEME, null) { it.decodeString(MOTION_MODE) }

    fun haptics(): Boolean = readStore(PREFERENCES, true) { it.decodeBool(HAPTICS, true) }

    fun notificationsAsked(): Boolean =
        readStore(PREFERENCES, false) { it.decodeBool(NOTIFICATIONS_ASKED, false) }

    fun savePreferences(haptics: Boolean, notificationsAsked: Boolean): Boolean =
        writeStore(PREFERENCES) {
            it.encode(HAPTICS, haptics)
            it.encode(NOTIFICATIONS_ASKED, notificationsAsked)
        }

    fun searchRecents(): List<String> = readList(SEARCH, SEARCH_RECENTS, String.serializer())

    fun saveSearchRecents(queries: List<String>): Boolean =
        writeJson(SEARCH, SEARCH_RECENTS, ListSerializer(String.serializer()), queries)

    fun lyricsOffset(trackUri: String): Double? = readStore(LYRICS, null) { store ->
        val key = "$LYRICS_OFFSET_PREFIX$trackUri"
        if (store.containsKey(key)) store.decodeDouble(key, 0.0) else null
    }

    fun saveLyricsOffset(trackUri: String, seconds: Double): Boolean =
        writeStore(LYRICS) { it.encode("$LYRICS_OFFSET_PREFIX$trackUri", seconds) }

    fun metadataCache(): Map<String, MetadataCacheEntry> = readStore(AUDIO, emptyMap()) { store ->
        val raw = store.decodeString(METADATA_CACHE) ?: return@readStore emptyMap()
        try {
            SnoozyJson.decodeFromString(METADATA_CACHE_SERIALIZER, raw)
        } catch (error: Exception) {
            Log.w(TAG, "Ignoring unreadable embedded metadata cache", error)
            emptyMap()
        }
    }

    fun metadataCacheForUpdate(): Map<String, MetadataCacheEntry> {
        val raw = readStringForUpdate(AUDIO, METADATA_CACHE) ?: return emptyMap()
        return try {
            SnoozyJson.decodeFromString(METADATA_CACHE_SERIALIZER, raw)
        } catch (error: Exception) {
            throw StoreFailureException("Could not decode $METADATA_CACHE", error)
        }
    }

    fun saveMetadataCache(cache: Map<String, MetadataCacheEntry>): Boolean =
        writeJson(AUDIO, METADATA_CACHE, METADATA_CACHE_SERIALIZER, cache)

    fun rawThemeValues(): Map<String, String?> = mapOf(
        THEME_MODE to themeMode(),
        PALETTE_STYLE to paletteStyle(),
        SEED to themeSeed(),
        MOTION_MODE to motionMode(),
    )

    private fun <T> readList(
        id: String,
        key: String,
        serializer: KSerializer<T>,
    ): List<T> = readStore(id, emptyList()) { store -> decodeList(store, key, serializer) }

    private fun <T> readListForUpdate(
        id: String,
        key: String,
        serializer: KSerializer<T>,
    ): List<T> {
        val raw = readStringForUpdate(id, key) ?: return emptyList()
        return try {
            SnoozyJson.decodeFromString(ListSerializer(serializer), raw)
        } catch (error: Exception) {
            throw StoreFailureException("Could not decode $key", error)
        }
    }

    private fun <T> decodeList(store: MMKV, key: String, serializer: KSerializer<T>): List<T> {
        val raw = store.decodeString(key) ?: return emptyList()
        return try {
            SnoozyJson.decodeFromString(ListSerializer(serializer), raw)
        } catch (error: Exception) {
            Log.w(TAG, "Ignoring unreadable $key", error)
            emptyList()
        }
    }

    private fun readStringForUpdate(id: String, key: String): String? {
        val store = store(id) ?: throw StoreFailureException("Store $id is unavailable")
        return try {
            store.decodeString(key)
        } catch (error: Exception) {
            throw StoreFailureException("Could not read $key", error)
        }
    }

    private fun <T> writeJson(
        id: String,
        key: String,
        serializer: KSerializer<T>,
        value: T,
    ): Boolean = writeStore(id) { store ->
        store.encode(key, SnoozyJson.encodeToString(serializer, value))
    }

    private fun <T> readStore(id: String, default: T, block: (MMKV) -> T): T {
        val store = store(id) ?: return default
        return try {
            block(store)
        } catch (error: Exception) {
            Log.w(TAG, "Could not read $id", error)
            default
        }
    }

    private fun writeStore(id: String, block: (MMKV) -> Unit): Boolean {
        val store = store(id) ?: return false
        return try {
            block(store)
            true
        } catch (error: Exception) {
            Log.w(TAG, "Could not write $id", error)
            false
        }
    }

    companion object {
        private const val TAG = "SnoozyData"
        const val MUSIC = "snoozy.music.v1"
        const val PLAYBACK = "snoozy.playback.v1"
        const val THEME = "snoozy.theme.v1"
        const val PREFERENCES = "snoozy.preferences.v1"
        const val SEARCH = "snoozy.search.v1"
        const val LYRICS = "snoozy.lyrics.v1"
        const val AUDIO = "snoozy.audio.v1"

        private const val SCANNED_SNAPSHOT = "scannedSnapshot"
        private const val IMPORTED = "imported"
        private const val PLAYLISTS = "playlists"
        private const val RECENTS = "recents"
        private const val SONG_SORT = "songSort"
        private const val ALBUM_SORT = "albumSort"
        private const val SESSION = "session.v1"
        private const val QUEUE_IDS = "queueIds"
        private const val REPEAT_MODE = "repeatMode"
        private const val SHUFFLE = "shuffle"
        private const val PLAYBACK_RATE = "playbackRate"
        private const val THEME_MODE = "mode"
        private const val PALETTE_STYLE = "paletteStyle"
        private const val SEED = "seed"
        private const val BACKDROP_ENABLED = "backdropEnabled"
        private const val BACKDROP_INTENSITY = "backdropIntensity"
        private const val MOTION_MODE = "motionMode"
        private const val HAPTICS = "haptics"
        private const val NOTIFICATIONS_ASKED = "notificationsAsked"
        private const val SEARCH_RECENTS = "recentQueries"
        private const val LYRICS_OFFSET_PREFIX = "offset:"
        private const val METADATA_CACHE = "embedded-metadata.v1"
        private val METADATA_CACHE_SERIALIZER =
            MapSerializer(String.serializer(), MetadataCacheEntry.serializer())
    }
}
