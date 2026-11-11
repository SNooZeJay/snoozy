package com.snoozy.app.playback

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MediaItemMapperTest {
    @Test
    fun resolveFilePathExtractsLocalPathFromFileUri() {
        assertEquals(
            "/storage/emulated/0/Download/01 - Track #1.mp3",
            MediaItemMapper.resolveFilePath("file:///storage/emulated/0/Download/01 - Track #1.mp3"),
        )
        assertNull(MediaItemMapper.resolveFilePath("file://"))
        assertNull(MediaItemMapper.resolveFilePath("content://media/external/audio/media/42"))
        assertNull(MediaItemMapper.resolveFilePath(""))
    }

    @Test
    fun isNumericMediaStoreIdIdentifiesMediaStoreRows() {
        assertTrue(MediaItemMapper.isNumericMediaStoreId("1000000142"))
        assertFalse(MediaItemMapper.isNumericMediaStoreId("imported-1794425769545-0-5233ff"))
        assertFalse(MediaItemMapper.isNumericMediaStoreId(""))
        assertFalse(MediaItemMapper.isNumericMediaStoreId("123a"))
    }

    @Test
    fun mediaStoreContentUriStringMatchesAndroidAudioTable() {
        assertEquals(
            "content://media/external/audio/media/1000000142",
            MediaItemMapper.mediaStoreContentUriString("1000000142"),
        )
    }
}
