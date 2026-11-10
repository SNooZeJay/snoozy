package com.snoozy.app.data.diagnostics

import android.util.Log
import com.snoozy.app.data.db.SnoozyDatabases
import com.snoozy.app.data.mmkv.SnoozyStores
import com.snoozy.app.data.scan.LibraryScanner

/** One-shot parity check against the data preserved from React Native. */
object DataDiagnostics {
    fun log(
        stores: SnoozyStores,
        databases: SnoozyDatabases,
        preservedSnapshotCount: Int,
        scan: LibraryScanner.Result?,
    ) {
        val playlists = stores.playlists()
        val recents = stores.recents()
        val imported = stores.importedTracks()
        val session = stores.playbackSession()

        Log.i(TAG, "preserved snapshot tracks=$preservedSnapshotCount")
        Log.i(
            TAG,
            "scan " + (scan?.let {
                "tracks=${it.tracks.size} assets=${it.assetCount} latest=${it.latestModificationTime} fingerprint=${it.fingerprint}"
            } ?: "skipped (no audio permission or failed)"),
        )
        Log.i(
            TAG,
            "snapshot after scan=${stores.scannedSnapshot().size} imported=${imported.size} mmkvKeys=${stores.keyCount()}",
        )
        Log.i(
            TAG,
            "favorites=${databases.favorites().size} trackOverrides=${databases.trackOverrides().size} " +
                "albumOverrides=${databases.albumOverrides().size} artistOverrides=${databases.artistOverrides().size}",
        )
        Log.i(
            TAG,
            "playHistory=${databases.playHistory().size} listeningSessions=${databases.listeningSessions().size}",
        )
        Log.i(
            TAG,
            "playlists=${playlists.size} playlistTracks=${playlists.sumOf { it.trackIds.size }} recents=${recents.size}",
        )
        Log.i(
            TAG,
            "session=" + (session?.let {
                "readable(active=${it.activeTrackId}, queue=${it.queueIds.size}, repeat=${it.repeatMode})"
            } ?: "none"),
        )
    }

    private const val TAG = "SnoozyData"
}
