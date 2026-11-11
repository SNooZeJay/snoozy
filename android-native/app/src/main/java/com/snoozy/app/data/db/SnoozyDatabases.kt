package com.snoozy.app.data.db

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import com.snoozy.app.data.model.AlbumOverride
import com.snoozy.app.data.model.ArtistOverride
import com.snoozy.app.data.model.FavoriteRow
import com.snoozy.app.data.model.ListeningSession
import com.snoozy.app.data.model.PlayHistoryEntry
import com.snoozy.app.data.model.TrackOverride
import java.io.File

/**
 * Reads the five expo-sqlite files in place. Queries are blocking; call from IO.
 */
class SnoozyDatabases(private val context: Context) {
    private val directory = File(context.filesDir, "SQLite")
    private val cacheDirectory = File(context.cacheDir, "snoozy-db")
    private val opened = HashMap<String, SQLiteDatabase?>()

    fun favorites(): List<FavoriteRow> = rows(
        FAVORITES_DB,
        "SELECT identity, title, artist, album, duration, artwork, added_at FROM favorites",
    ) { cursor ->
        FavoriteRow(
            identity = cursor.text("identity"),
            title = cursor.text("title"),
            artist = cursor.text("artist"),
            album = cursor.text("album"),
            duration = cursor.doubleValue("duration"),
            artwork = cursor.nullableText("artwork"),
            addedAt = cursor.longValue("added_at"),
        )
    }

    fun trackOverrides(): List<TrackOverride> = rows(
        METADATA_DB,
        "SELECT track_id, title, artist, album, album_artist, genre, year, track_number, description, artwork_path, updated_at FROM track_overrides",
    ) { cursor ->
        TrackOverride(
            trackId = cursor.text("track_id"),
            title = cursor.nullableText("title"),
            artist = cursor.nullableText("artist"),
            album = cursor.nullableText("album"),
            albumArtist = cursor.nullableText("album_artist"),
            genre = cursor.nullableText("genre"),
            year = cursor.nullableText("year"),
            trackNumber = cursor.nullableText("track_number"),
            description = cursor.nullableText("description"),
            artworkPath = cursor.nullableText("artwork_path"),
            updatedAt = cursor.longValue("updated_at"),
        )
    }

    fun albumOverrides(): List<AlbumOverride> = rows(
        METADATA_DB,
        "SELECT album_key, title, artist, description, artwork_path, updated_at FROM album_overrides",
    ) { cursor ->
        AlbumOverride(
            albumKey = cursor.text("album_key"),
            title = cursor.nullableText("title"),
            artist = cursor.nullableText("artist"),
            description = cursor.nullableText("description"),
            artworkPath = cursor.nullableText("artwork_path"),
            updatedAt = cursor.longValue("updated_at"),
        )
    }

    fun artistOverrides(): List<ArtistOverride> = rows(
        METADATA_DB,
        "SELECT artist_key, name, description, artwork_path, updated_at FROM artist_overrides",
    ) { cursor ->
        ArtistOverride(
            artistKey = cursor.text("artist_key"),
            name = cursor.nullableText("name"),
            description = cursor.nullableText("description"),
            artworkPath = cursor.nullableText("artwork_path"),
            updatedAt = cursor.longValue("updated_at"),
        )
    }

    fun playHistory(): List<PlayHistoryEntry> = rows(
        PLAY_HISTORY_DB,
        "SELECT track_id, played_at, duration_listened_ms FROM play_history ORDER BY played_at DESC",
    ) { cursor ->
        PlayHistoryEntry(
            trackId = cursor.text("track_id"),
            playedAt = cursor.longValue("played_at"),
            durationListenedMs = cursor.longValue("duration_listened_ms"),
        )
    }

    fun listeningSessions(): List<ListeningSession> = rows(
        LIBRARY_DB,
        "SELECT id, sound_id, started_at, ended_at, duration_seconds FROM listening_sessions " +
            "ORDER BY started_at DESC",
    ) { cursor ->
        ListeningSession(
            id = cursor.longValue("id"),
            trackId = cursor.text("sound_id"),
            startedAt = cursor.longValue("started_at"),
            endedAt = cursor.nullableLongValue("ended_at"),
            durationSeconds = cursor.longValue("duration_seconds"),
        )
    }

    fun clearPlayHistory(): Boolean = clearTable(PLAY_HISTORY_DB, "play_history")

    fun clearListeningSessions(): Boolean = clearTable(LIBRARY_DB, "listening_sessions")

    fun recordPlayHistory(
        trackId: String,
        playedAt: Long,
        durationListenedMs: Long,
    ): Boolean {
        if (trackId.isBlank() || durationListenedMs < 0L) return false
        return writeDatabase(PLAY_HISTORY_DB, false) { database ->
            database.execSQL(CREATE_PLAY_HISTORY_SQL)
            val values = ContentValues().apply {
                put("track_id", trackId)
                put("played_at", playedAt)
                put("duration_listened_ms", durationListenedMs)
            }
            database.insert("play_history", null, values) != -1L
        }
    }

    fun startListeningSession(trackId: String, startedAt: Long): Long? {
        if (trackId.isBlank()) return null
        return writeDatabase(LIBRARY_DB, null) { database ->
            database.execSQL(CREATE_LISTENING_SESSIONS_SQL)
            database.execSQL(CREATE_LISTENING_SESSIONS_INDEX_SQL)
            val values = ContentValues().apply {
                put("sound_id", trackId)
                put("started_at", startedAt)
                put("duration_seconds", 0L)
            }
            database.insert("listening_sessions", null, values).takeIf { it > 0L }
        }
    }

    fun finishListeningSession(
        sessionId: Long,
        endedAt: Long,
        durationSeconds: Long,
    ): Boolean {
        if (sessionId <= 0L) return false
        return writeDatabase(LIBRARY_DB, false) { database ->
            database.execSQL(CREATE_LISTENING_SESSIONS_SQL)
            val values = ContentValues().apply {
                put("ended_at", endedAt)
                put("duration_seconds", durationSeconds.coerceAtLeast(0L))
            }
            database.update(
                "listening_sessions",
                values,
                "id = ?",
                arrayOf(sessionId.toString()),
            ) >= 0
        }
    }

    private fun <T> writeDatabase(
        name: String,
        fallback: T,
        block: (SQLiteDatabase) -> T,
    ): T {
        synchronized(opened) { opened.remove(name)?.close() }
        directory.mkdirs()
        val file = File(directory, name)
        return try {
            SQLiteDatabase.openDatabase(
                file.path,
                null,
                SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.CREATE_IF_NECESSARY,
            ).use(block)
        } catch (error: Exception) {
            Log.w(TAG, "Write failed on $name", error)
            fallback
        }
    }

    private fun clearTable(name: String, table: String): Boolean {
        synchronized(opened) { opened.remove(name)?.close() }
        val file = File(directory, name)
        if (!file.exists()) return true
        return try {
            SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READWRITE).use { database ->
                database.delete(table, null, null)
                true
            }
        } catch (error: Exception) {
            Log.w(TAG, "Could not clear $table", error)
            false
        }
    }

    private fun open(name: String): SQLiteDatabase? = synchronized(opened) {
        val cached = opened[name]
        if (cached != null) return@synchronized cached
        val file = File(directory, name)
        if (!file.exists()) return@synchronized null
        val database = try {
            SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY)
        } catch (error: Exception) {
            // A WAL database can need write access to -shm even for reads. Never
            // open the preserved original read-write; read a copy instead.
            Log.w(TAG, "Read-only open failed for $name, reading a copy", error)
            val copy = copyForReading(name, file)
            if (copy == null) {
                null
            } else {
                try {
                    SQLiteDatabase.openDatabase(copy.path, null, SQLiteDatabase.OPEN_READONLY)
                } catch (fallback: Exception) {
                    Log.w(TAG, "Could not open the copy of $name", fallback)
                    null
                }
            }
        }
        opened[name] = database
        database
    }

    private fun copyForReading(name: String, source: File): File? = try {
        cacheDirectory.mkdirs()
        val target = File(cacheDirectory, name)
        source.copyTo(target, overwrite = true)
        for (suffix in listOf("-wal", "-shm")) {
            val part = File(source.path + suffix)
            if (part.exists()) part.copyTo(File(target.path + suffix), overwrite = true)
        }
        target
    } catch (error: Exception) {
        Log.w(TAG, "Could not copy $name for reading", error)
        null
    }

    private fun <T> rows(name: String, sql: String, map: (Cursor) -> T): List<T> {
        val database = open(name) ?: return emptyList()
        return try {
            database.rawQuery(sql, null).use { cursor ->
                buildList { while (cursor.moveToNext()) add(map(cursor)) }
            }
        } catch (error: Exception) {
            Log.w(TAG, "Query failed on $name", error)
            emptyList()
        }
    }

    private fun Cursor.doubleValue(column: String): Double =
        getDouble(getColumnIndexOrThrow(column))

    private fun Cursor.longValue(column: String): Long =
        getLong(getColumnIndexOrThrow(column))

    private fun Cursor.text(column: String): String =
        getString(getColumnIndexOrThrow(column))

    private fun Cursor.nullableText(column: String): String? {
        val index = getColumnIndexOrThrow(column)
        return if (isNull(index)) null else getString(index)
    }

    private fun Cursor.nullableLongValue(column: String): Long? {
        val index = getColumnIndexOrThrow(column)
        return if (isNull(index)) null else getLong(index)
    }

    companion object {
        private const val TAG = "SnoozyData"
        private const val LIBRARY_DB = "snoozy.db"
        private const val FAVORITES_DB = "snoozy_favorites.db"
        private const val METADATA_DB = "snoozy_metadata.db"
        private const val PLAY_HISTORY_DB = "snoozy_playhistory.db"
        private const val CREATE_PLAY_HISTORY_SQL =
            "CREATE TABLE IF NOT EXISTS play_history (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                "track_id TEXT NOT NULL, " +
                "played_at INTEGER NOT NULL, " +
                "duration_listened_ms INTEGER NOT NULL)"
        private const val CREATE_LISTENING_SESSIONS_SQL =
            "CREATE TABLE IF NOT EXISTS listening_sessions (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                "sound_id TEXT NOT NULL, " +
                "started_at INTEGER NOT NULL, " +
                "ended_at INTEGER, " +
                "duration_seconds INTEGER NOT NULL DEFAULT 0)"
        private const val CREATE_LISTENING_SESSIONS_INDEX_SQL =
            "CREATE INDEX IF NOT EXISTS listening_sessions_started_at " +
                "ON listening_sessions (started_at)"
    }
}
