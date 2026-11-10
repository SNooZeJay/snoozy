package com.snoozy.app.data.library

import org.junit.Assert.assertEquals
import org.junit.Test

class AudioMetadataTest {
    @Test
    fun filePathDecodesPercentEncodingButKeepsPlus() {
        assertEquals(
            "/storage/emulated/0/Music/Album One/01 Track.mp3",
            filePathFromUri("file:///storage/emulated/0/Music/Album%20One/01%20Track.mp3"),
        )
        assertEquals("/storage/emulated/0/Music/A+B/c.mp3", filePathFromUri("file:///storage/emulated/0/Music/A+B/c.mp3"))
        assertEquals("/storage/emulated/0/Music/%ZZ/c.mp3", filePathFromUri("file:///storage/emulated/0/Music/%ZZ/c.mp3"))
    }

    @Test
    fun fallbackTitleStripsTrackNumbersAndSeparators() {
        assertEquals("A Certain Way", fallbackTitleFromFilename("05. A Certain Way.mp3"))
        assertEquals("Track Name", fallbackTitleFromFilename("01_Track_Name.flac"))
        assertEquals("my song title", fallbackTitleFromFilename("my_song-title.mp3"))
        assertEquals("Title", fallbackTitleFromFilename("07 - Title.flac"))
        assertEquals("12345", fallbackTitleFromFilename("12345.mp3"))
        assertEquals("Untitled track", fallbackTitleFromFilename(""))
    }

    @Test
    fun artworkCacheKeyMatchesTheReactNativeHash() {
        assertEquals(
            "album-hhxvcj-t4tt4s",
            artworkCacheKey(
                "album-hhxvcj",
                "file:///storage/emulated/0/Music/Frank Ocean - Endless (2018)/05. A Certain Way.mp3",
                1700000000000L,
            ),
        )
    }
}
