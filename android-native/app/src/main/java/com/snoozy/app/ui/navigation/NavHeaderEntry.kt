package com.snoozy.app.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import io.github.neoruaa.glasmio.scaffold.GlasmioHeaderAction
import io.github.neoruaa.glasmio.scaffold.GlasmioHeaderScrollState

class NavHeaderEntry {
    var scroll by mutableStateOf<GlasmioHeaderScrollState?>(null)
    var title by mutableStateOf<String?>(null)
    var subtitle by mutableStateOf<String?>(null)
    var actions by mutableStateOf<List<GlasmioHeaderAction>>(emptyList())
}

val LocalNavHeaderEntry = staticCompositionLocalOf<NavHeaderEntry> {
    error("Missing NavHeaderEntry")
}

/** Binds the shared top bar to the page that is currently composed for this entry. */
@Composable
fun BindHeader(
    title: String,
    subtitle: String? = null,
    actions: List<GlasmioHeaderAction> = emptyList(),
) {
    val entry = LocalNavHeaderEntry.current
    SideEffect {
        entry.title = title
        entry.subtitle = subtitle
        entry.actions = actions
    }
}
