package com.snoozy.app.ui.components

import org.junit.Assert.assertEquals
import org.junit.Test

class GroupedRowsTest {
    @Test
    fun cornersFollowTheRowPosition() {
        assertEquals(GroupedRowPosition.Single, groupedRowPosition(0, 1))
        assertEquals(GroupedRowPosition.First, groupedRowPosition(0, 3))
        assertEquals(GroupedRowPosition.Middle, groupedRowPosition(1, 3))
        assertEquals(GroupedRowPosition.Last, groupedRowPosition(2, 3))
        assertEquals(GroupedRowPosition.Single, groupedRowPosition(0, 0))
    }
}
