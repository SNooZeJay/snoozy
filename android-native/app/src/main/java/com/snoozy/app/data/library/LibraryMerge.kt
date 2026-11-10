package com.snoozy.app.data.library

import com.snoozy.app.data.model.Track

/** Imported tracks win the URI dedupe, exactly like the React Native merge. */
fun mergeTracks(imported: List<Track>, scanned: List<Track>): List<Track> {
    val seen = HashSet<String>()
    val merged = ArrayList<Track>(imported.size + scanned.size)
    for (track in imported + scanned) {
        if (seen.add(track.uri)) merged += track
    }
    return merged.sortedWith { left, right -> compareText(left.title, right.title) }
}
