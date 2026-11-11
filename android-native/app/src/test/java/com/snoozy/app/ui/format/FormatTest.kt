package com.snoozy.app.ui.format

import org.junit.Assert.assertEquals
import org.junit.Test

class FormatTest {
    @Test
    fun durationMatchesTheReactNativeFormatter() {
        assertEquals("0s", formatDuration(0.0))
        assertEquals("59s", formatDuration(59.4))
        assertEquals("1 min", formatDuration(59.6))
        assertEquals("59 min", formatDuration(3540.0))
        assertEquals("1 hr", formatDuration(3599.0))
        assertEquals("1 hr 5 min", formatDuration(3900.0))
        assertEquals("0s", formatDuration(Double.NaN))
    }

    @Test
    fun clockUsesWholeSeconds() {
        assertEquals("0:00", formatClock(0.0))
        assertEquals("1:05", formatClock(65.9))
        assertEquals("0:00", formatClock(Double.NaN))
    }

    @Test
    fun countsUseTheSingularOnlyForOne() {
        assertEquals("0 songs", countLabel(0, "song", "songs"))
        assertEquals("1 song", countLabel(1, "song", "songs"))
        assertEquals("2 songs", countLabel(2, "song", "songs"))
    }
}
