package com.snoozy.app.data.db

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

    private fun open(name: String): SQLiteDatabase? {
        opened[name]?.let { return it }
        val file = File(directory, name)
        if (!file.exists()) return null
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
        return database
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
    }
}
