package com.snoozy.app.ui.format

import kotlin.math.max
import kotlin.math.roundToLong

fun formatDuration(totalSeconds: Double): String {
    val safe = if (totalSeconds.isFinite()) max(0.0, totalSeconds).roundToLong() else 0L
    if (safe < 60) return "${safe}s"
    val minutes = (safe / 60.0).roundToLong()
    if (minutes < 60) return "$minutes min"
    val hours = minutes / 60
    val remainder = minutes % 60
    return if (remainder == 0L) "$hours hr" else "$hours hr $remainder min"
}

fun formatClock(totalSeconds: Double): String {
    val safe = if (totalSeconds.isFinite()) max(0.0, totalSeconds).toInt() else 0
    val minutes = safe / 60
    val seconds = safe % 60
    return "$minutes:${seconds.toString().padStart(2, '0')}"
}

fun countLabel(count: Int, singular: String, plural: String): String =
    "$count ${if (count == 1) singular else plural}"
