package com.snoozy.app.ui.navigation

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import io.github.neoruaa.glasmio.scaffold.GlasmioHeaderScrollState

class NavHeaderEntry {
    var scroll by mutableStateOf<GlasmioHeaderScrollState?>(null)
}
