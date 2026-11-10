package com.snoozy.app.ui.screens

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import io.github.neoruaa.glasmio.core.IosPageHorizontalPadding
import io.github.neoruaa.glasmio.core.IosTypography
import io.github.neoruaa.glasmio.scaffold.GlasmioHeaderScrollState
import io.github.neoruaa.glasmio.scaffold.GlasmioPageBody
import io.github.neoruaa.glasmio.scaffold.rememberGlasmioHeaderCollapse
import io.github.neoruaa.glasmio.scaffold.rememberGlasmioHeaderScrollEdge
import io.github.neoruaa.glasmio.ui.NavigationBarSurfaceHeight
import com.snoozy.app.ui.components.SnoozyEmptyState
import com.snoozy.app.ui.icons.SnoozyIcons
import com.snoozy.app.ui.navigation.NavHeaderEntry
import com.snoozy.app.ui.navigation.NavKey

@Composable
fun RootPlaceholder(
    key: NavKey,
    contentPadding: PaddingValues,
    headerEntry: NavHeaderEntry,
) {
    val listState = rememberLazyListState()
    val collapse = rememberGlasmioHeaderCollapse(listState)
    val currentCollapse = rememberUpdatedState(collapse)
    val scroll = remember { GlasmioHeaderScrollState({ currentCollapse.value }) }
    SideEffect { headerEntry.scroll = scroll }

    val edgeProgress = rememberGlasmioHeaderScrollEdge(listState)
    val navigationInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val padding = PaddingValues(
        start = IosPageHorizontalPadding,
        top = contentPadding.calculateTopPadding(),
        end = IosPageHorizontalPadding,
        bottom = contentPadding.calculateBottomPadding() + NavigationBarSurfaceHeight + 32.dp + navigationInset,
    )

    GlasmioPageBody(contentPadding = padding, topBarBlurProgress = edgeProgress) { bodyPadding ->
        LazyColumn(
            state = listState,
            modifier = Modifier.fillMaxSize(),
            contentPadding = bodyPadding,
        ) {
            item {
                Text(
                    text = key.pageTitle,
                    style = IosTypography.largeTitle,
                    modifier = Modifier.padding(horizontal = 4.dp, vertical = 6.dp),
                )
            }
            item {
                SnoozyEmptyState(
                    icon = iconFor(key),
                    title = emptyTitleFor(key),
                    message = key.description,
                )
            }
        }
    }
}

private fun iconFor(key: NavKey): ImageVector = when (key) {
    NavKey.Home -> SnoozyIcons.Home
    NavKey.Search -> SnoozyIcons.Search
    NavKey.Library -> SnoozyIcons.Library
    NavKey.Playlists -> SnoozyIcons.Playlists
    NavKey.Settings -> SnoozyIcons.Settings
}

private fun emptyTitleFor(key: NavKey): String = when (key) {
    NavKey.Home -> "Your library is safe"
    NavKey.Search -> "Search comes with the library"
    NavKey.Library -> "Library comes next"
    NavKey.Playlists -> "Playlists come next"
    NavKey.Settings -> "Settings come after playback"
}
