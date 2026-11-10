package com.snoozy.app.data.library

import java.net.URLDecoder

fun filePathFromUri(uri: String): String {
    val path = uri.replace(Regex("^file://"), "")
    return try {
        URLDecoder.decode(path.replace("+", "%2B"), "UTF-8")
    } catch (_: IllegalArgumentException) {
        path
    }
}

fun fallbackTitleFromFilename(filename: String): String = filename
    .replace(Regex("\\.[^.]+$"), "")
    .replace(Regex("^\\d{1,3}[\\s._-]+"), "")
    .replace(Regex("[_-]+"), " ")
    .trim()
    .ifEmpty { "Untitled track" }

fun artworkCacheKey(albumKey: String, uri: String, modificationTime: Long): String =
    "$albumKey-${stableHash("$uri:$modificationTime")}"
