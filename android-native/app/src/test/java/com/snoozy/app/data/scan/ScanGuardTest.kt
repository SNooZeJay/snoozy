package com.snoozy.app.data.scan

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ScanGuardTest {
    @Test
    fun emptyScanKeepsAPreservedSnapshot() {
        assertTrue(shouldPreserveSnapshot(rowCount = 0, assetCount = 0, previousSnapshotCount = 37))
    }

    @Test
    fun rowsWithoutUsableAssetsAreTreatedAsAFailure() {
        assertTrue(shouldPreserveSnapshot(rowCount = 5, assetCount = 0, previousSnapshotCount = 0))
    }

    @Test
    fun firstScanOfAnEmptyLibraryMayWrite() {
        assertFalse(shouldPreserveSnapshot(rowCount = 0, assetCount = 0, previousSnapshotCount = 0))
    }

    @Test
    fun aNormalScanWrites() {
        assertFalse(shouldPreserveSnapshot(rowCount = 37, assetCount = 37, previousSnapshotCount = 37))
    }
}
