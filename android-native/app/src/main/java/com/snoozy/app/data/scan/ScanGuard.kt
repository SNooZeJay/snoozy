package com.snoozy.app.data.scan

class LibraryScanException(message: String, cause: Throwable? = null) : Exception(message, cause)

/**
 * A failed or empty MediaStore query must not overwrite a preserved snapshot.
 * shortcut: deleting every song also keeps the last snapshot; add an explicit
 * library reset when the app grows one.
 */
internal fun shouldPreserveSnapshot(
    rowCount: Int,
    assetCount: Int,
    previousSnapshotCount: Int,
): Boolean = assetCount == 0 && (rowCount > 0 || previousSnapshotCount > 0)
