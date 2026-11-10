package com.snoozy.app.data.mmkv

import android.content.Context
import android.util.Log
import com.snoozy.app.data.model.MetadataCacheEntry
import com.snoozy.app.data.model.PlaybackSession
import com.snoozy.app.data.model.Playlist
import com.snoozy.app.data.model.Track
import com.snoozy.app.data.playback.parsePlaybackSession
import com.tencent.mmkv.MMKV
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import java.io.File

/**
 * Typed access to the seven react-native-mmkv stores. The directory and IDs match
 * MMKV's defaults under expo, so the files are opened in place.
 */
class SnoozyStores(context: Context) {
    init {
        MMKV.initialize(context, File(context.filesDir, "mmkv").absolutePath)
    }

    private val music = MMKV.mmkvWithID(MUSIC)
    private val playback = MMKV.mmkvWithID(PLAYBACK)
    private val theme = MMKV.mmkvWithID(THEME)
    private val preferences = MMKV.mmkvWithID(PREFERENCES)
    private val search = MMKV.mmkvWithID(SEARCH)
    private val lyrics = MMKV.mmkvWithID(LYRICS)
    private val audio = MMKV.mmkvWithID(AUDIO)

    val storeIds: List<String> = listOf(MUSIC, PLAYBACK, THEME, PREFERENCES, SEARCH, LYRICS, AUDIO)

    fun keyCount(): Int = storeIds.sumOf { MMKV.mmkvWithID(it).allKeys()?.size ?: 0 }

    fun scannedSnapshot(): List<Track> = readList(music, SCANNED_SNAPSHOT, Track.serializer())

    fun saveScannedSnapshot(tracks: List<Track>) =
        writeJson(music, SCANNED_SNAPSHOT, ListSerializer(Track.serializer()), tracks)

    fun importedTracks(): List<Track> = readList(music, IMPORTED, Track.serializer())

    fun saveImportedTracks(tracks: List<Track>) =
        writeJson(music, IMPORTED, ListSerializer(Track.serializer()), tracks)

    fun playlists(): List<Playlist> = readList(music, PLAYLISTS, Playlist.serializer())

    fun savePlaylists(playlists: List<Playlist>) =
        writeJson(music, PLAYLISTS, ListSerializer(Playlist.serializer()), playlists)

    fun recents(): List<String> = readList(music, RECENTS, String.serializer())

    fun saveRecents(ids: List<String>) =
        writeJson(music, RECENTS, ListSerializer(String.serializer()), ids)

    fun songSort(): String? = music.decodeString(SONG_SORT)

    fun saveSongSort(sort: String) {
        music.encode(SONG_SORT, sort)
    }

    fun albumSort(): String? = music.decodeString(ALBUM_SORT)

    fun saveAlbumSort(sort: String) {
        music.encode(ALBUM_SORT, sort)
    }

    fun playbackSession(): PlaybackSession? {
        val raw = playback.decodeString(SESSION) ?: return null
        return parsePlaybackSession(raw)
    }

    fun savePlaybackSession(session: PlaybackSession) =
        playback.encode(SESSION, SnoozyJson.encodeToString(PlaybackSession.serializer(), session))

    fun clearPlaybackSession() {
        playback.removeValueForKey(SESSION)
    }

    fun queueIds(): List<String> = readList(playback, QUEUE_IDS, String.serializer())

    fun saveQueueIds(ids: List<String>) =
        writeJson(playback, QUEUE_IDS, ListSerializer(String.serializer()), ids)

    fun repeatMode(): String? = playback.decodeString(REPEAT_MODE)

    fun saveRepeatMode(mode: String) {
        playback.encode(REPEAT_MODE, mode)
    }

    fun shuffle(): Boolean = playback.decodeBool(SHUFFLE, false)

    fun saveShuffle(enabled: Boolean) {
        playback.encode(SHUFFLE, enabled)
    }

    fun playbackRate(): Double = playback.decodeDouble(PLAYBACK_RATE, 1.0)

    fun savePlaybackRate(rate: Double) {
        playback.encode(PLAYBACK_RATE, rate)
    }

    fun themeMode(): String? = theme.decodeString(THEME_MODE)

    fun paletteStyle(): String? = theme.decodeString(PALETTE_STYLE)

    fun themeSeed(): String? = theme.decodeString(SEED)

    fun backdropEnabled(): Boolean = theme.decodeBool(BACKDROP_ENABLED, true)

    fun backdropIntensity(): Double = theme.decodeDouble(BACKDROP_INTENSITY, 0.6)

    fun motionMode(): String? = theme.decodeString(MOTION_MODE)

    fun haptics(): Boolean = preferences.decodeBool(HAPTICS, true)

    fun notificationsAsked(): Boolean = preferences.decodeBool(NOTIFICATIONS_ASKED, false)

    fun savePreferences(haptics: Boolean, notificationsAsked: Boolean) {
        preferences.encode(HAPTICS, haptics)
        preferences.encode(NOTIFICATIONS_ASKED, notificationsAsked)
    }

    fun searchRecents(): List<String> = readList(search, SEARCH_RECENTS, String.serializer())

    fun saveSearchRecents(queries: List<String>) =
        writeJson(search, SEARCH_RECENTS, ListSerializer(String.serializer()), queries)

    fun lyricsOffset(trackUri: String): Double? {
        val key = "$LYRICS_OFFSET_PREFIX$trackUri"
        return if (lyrics.containsKey(key)) lyrics.decodeDouble(key, 0.0) else null
    }

    fun saveLyricsOffset(trackUri: String, seconds: Double) {
        lyrics.encode("$LYRICS_OFFSET_PREFIX$trackUri", seconds)
    }

    fun metadataCache(): Map<String, MetadataCacheEntry> {
        val raw = audio.decodeString(METADATA_CACHE) ?: return emptyMap()
        return try {
            SnoozyJson.decodeFromString(METADATA_CACHE_SERIALIZER, raw)
        } catch (error: Exception) {
            Log.w(TAG, "Ignoring unreadable embedded metadata cache", error)
            emptyMap()
        }
    }

    fun saveMetadataCache(cache: Map<String, MetadataCacheEntry>) {
        audio.encode(METADATA_CACHE, SnoozyJson.encodeToString(METADATA_CACHE_SERIALIZER, cache))
    }

    fun rawThemeValues(): Map<String, String?> = mapOf(
        THEME_MODE to themeMode(),
        PALETTE_STYLE to paletteStyle(),
        SEED to themeSeed(),
        MOTION_MODE to motionMode(),
    )

    private fun <T> readList(store: MMKV, key: String, serializer: kotlinx.serialization.KSerializer<T>): List<T> {
        val raw = store.decodeString(key) ?: return emptyList()
        return try {
            SnoozyJson.decodeFromString(ListSerializer(serializer), raw)
        } catch (error: Exception) {
            Log.w(TAG, "Ignoring unreadable $key", error)
            emptyList()
        }
    }

    private fun <T> writeJson(
        store: MMKV,
        key: String,
        serializer: kotlinx.serialization.KSerializer<T>,
        value: T,
    ) {
        try {
            store.encode(key, SnoozyJson.encodeToString(serializer, value))
        } catch (error: Exception) {
            Log.w(TAG, "Could not write $key", error)
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

val SnoozyJson = Json {
    encodeDefaults = true
    ignoreUnknownKeys = true
}
