package com.snoozy.app.ui.navigation

import androidx.compose.runtime.ProvidableCompositionLocal
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.staticCompositionLocalOf
import com.snoozy.app.playback.PlaybackController

val LocalPlaybackController: ProvidableCompositionLocal<PlaybackController> =
    staticCompositionLocalOf { error("Missing PlaybackController") }

val LocalHasActiveTrack: ProvidableCompositionLocal<Boolean> =
    compositionLocalOf { false }
