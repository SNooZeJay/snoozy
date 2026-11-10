package com.snoozy.app.data.mmkv

import com.snoozy.app.data.model.Album
import com.snoozy.app.data.model.MetadataCacheEntry
import com.snoozy.app.data.model.PlaybackSession
import com.snoozy.app.data.model.Playlist
import com.snoozy.app.data.model.ScannedMetadata
import com.snoozy.app.data.model.Track
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SnoozyJsonTest {
    @Test
    fun trackRoundTripsWithEveryReactNativeField() {
        val track = Track(
            id = "1000000403",
            title = "A Certain Way",
            artist = "Frank Ocean",
            album = "Endless",
            albumArtist = "Frank Ocean",
            year = "2016",
            genre = "R&B/Soul",
            trackNumber = null,
            discNumber = null,
            uri = "file:///storage/emulated/0/Music/Endless/05. A Certain Way.mp3",
            duration = 11.154,
            artwork = "file:///data/user/0/com.snoozy.app/files/artwork/album-hhxvcj-35ylmk.jpg",
            addedAt = 0L,
        )

        val raw = SnoozyJson.encodeToString(Track.serializer(), track)

        assertEquals(track, SnoozyJson.decodeFromString(Track.serializer(), raw))
        val keys = (SnoozyJson.parseToJsonElement(raw) as JsonObject).keys
        assertEquals(
            setOf(
                "id", "title", "artist", "album", "albumArtist", "year", "genre",
                "trackNumber", "discNumber", "uri", "duration", "artwork", "addedAt",
            ),
            keys,
        )
        assertTrue(raw.contains("\"albumArtist\":\"Frank Ocean\""))
        assertTrue(raw.contains("\"trackNumber\":null"))
        assertTrue(raw.contains("\"addedAt\":0"))
    }

    @Test
    fun playlistAndAlbumRoundTrip() {
        val playlist = Playlist(
            id = "playlist-1794335417895-z97hxa",
            name = "Jayzee test",
            trackIds = listOf("1000000142"),
            createdAt = 1794335417895L,
        )
        assertEquals(
            playlist,
            SnoozyJson.decodeFromString(Playlist.serializer(), SnoozyJson.encodeToString(playlist)),
        )

        val album = Album(
            id = "album-hhxvcj",
            title = "Endless",
            artist = "Frank Ocean",
            albumArtist = "Frank Ocean",
            year = "2016",
            artwork = "file:///art.jpg",
            trackIds = listOf("a", "b"),
            duration = 95.712,
            addedAt = 0L,
        )
        assertEquals(
            album,
            SnoozyJson.decodeFromString(Album.serializer(), SnoozyJson.encodeToString(album)),
        )
    }

    @Test
    fun playbackSessionRoundTrips() {
        val session = PlaybackSession(
            activeTrackId = "1000000421",
            queueIds = List(10) { "10000004$it" },
            queueIndex = 3,
            positionSeconds = 42.5,
            shuffle = false,
            repeatMode = "all",
            updatedAt = 1700000000000L,
        )
        val raw = SnoozyJson.encodeToString(PlaybackSession.serializer(), session)

        assertTrue(raw.contains("\"version\":1"))
        assertEquals(session, SnoozyJson.decodeFromString(PlaybackSession.serializer(), raw))
    }

    @Test
    fun metadataCacheRoundTripsInTheReactNativeShape() {
        val cache = mapOf(
            "1000000403" to MetadataCacheEntry(
                modified = 1700000000000.0,
                value = ScannedMetadata(
                    title = "A Certain Way",
                    artist = "Frank Ocean",
                    album = "Endless",
                    albumArtist = "Frank Ocean",
                    year = "2016",
                    genre = "R&B/Soul",
                    duration = 11.154,
                ),
            ),
        )
        val serializer = MapSerializer(String.serializer(), MetadataCacheEntry.serializer())
        val raw = SnoozyJson.encodeToString(serializer, cache)

        assertEquals(cache, SnoozyJson.decodeFromString(serializer, raw))
        val entry = (SnoozyJson.parseToJsonElement(raw) as JsonObject)["1000000403"] as JsonObject
        assertEquals(setOf("modified", "value"), entry.keys)
    }

    @Test
    fun unknownKeysAreIgnoredSoOlderBuildsKeepReading() {
        val raw = """{"id":"a","title":"T","artist":"A","album":"B","uri":"file:///a.mp3","future":true}"""
        val track = Json { ignoreUnknownKeys = true }.decodeFromString(Track.serializer(), raw)

        assertEquals("a", track.id)
        assertEquals(0L, track.addedAt)
    }
}
