package com.snoozy.app.ui.navigation

import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.listSaver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.runtime.toMutableStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.dp
import androidx.navigation3.runtime.NavEntry
import androidx.navigation3.scene.Scene
import com.snoozy.app.ui.screens.RootPlaceholder
import io.github.neoruaa.glasmio.glass.render.backdrops.rememberLayerBackdrop
import io.github.neoruaa.glasmio.icons.SfSymbol
import io.github.neoruaa.glasmio.scaffold.GlasmioHeaderSpec
import io.github.neoruaa.glasmio.scaffold.GlasmioNavigationOperation
import io.github.neoruaa.glasmio.scaffold.GlasmioNavigationScaffold
import io.github.neoruaa.glasmio.scaffold.GlasmioPageTitle
import io.github.neoruaa.glasmio.scaffold.navigation.GlasmioNavDisplay
import io.github.neoruaa.glasmio.scaffold.navigation.GlasmioNavHeaderMotion
import io.github.neoruaa.glasmio.scaffold.navigation.iosTransitionSpec
import io.github.neoruaa.glasmio.ui.CompactBottomControlSize
import io.github.neoruaa.glasmio.ui.GlasmioNavigationBar
import io.github.neoruaa.glasmio.ui.GlasmioTabItem

@Composable
fun SnoozyApp(onExit: () -> Unit) {
    val backStack = rememberSaveable(
        saver = listSaver<SnapshotStateList<String>, String>(
            save = { it.toList() },
            restore = { it.toMutableStateList() },
        ),
    ) { mutableStateListOf(NavKey.Home.route) }

    val headerEntries = remember { mutableMapOf<String, NavHeaderEntry>() }
    fun headerEntry(route: String): NavHeaderEntry = headerEntries.getOrPut(route) { NavHeaderEntry() }

    val headerMotion = remember {
        GlasmioNavHeaderMotion(backStack.last()) { from, to, pop ->
            val fromKey = NavKey.fromRoute(from as String)
            val toKey = NavKey.fromRoute(to as String)
            when {
                fromKey.isRoot && toKey.isRoot -> GlasmioNavigationOperation.Tab
                pop -> GlasmioNavigationOperation.Pop
                else -> GlasmioNavigationOperation.Push
            }
        }
    }

    val navigationBackdrop = rememberLayerBackdrop()
    val currentKey = NavKey.fromRoute(backStack.last())
    val selectedRoot = backStack.asReversed()
        .map(NavKey::fromRoute)
        .firstOrNull { it.isRoot } ?: NavKey.Home
    val compactProgress = remember { mutableStateOf(0f) }

    val navigateBack: () -> Unit = {
        if (backStack.size > 1) {
            backStack.removeAt(backStack.lastIndex)
        } else {
            onExit()
        }
    }

    val selectTab: (NavKey) -> Unit = { tab ->
        if (selectedRoot != tab || currentKey != tab) {
            backStack.clear()
            backStack.add(NavKey.Home.route)
            if (tab != NavKey.Home) backStack.add(tab.route)
        }
    }

    SideEffect {
        val frame = headerMotion.frame.value
        val active = buildSet {
            addAll(backStack)
            (frame.fromEntryKey as? String)?.let(::add)
            (frame.toEntryKey as? String)?.let(::add)
        }
        headerEntries.keys.retainAll(active)
    }

    GlasmioNavigationScaffold(
        motion = headerMotion,
        header = { entryKey ->
            val route = entryKey as String
            val key = NavKey.fromRoute(route)
            GlasmioHeaderSpec(
                title = key.title,
                scrollState = headerEntry(route).scroll,
            )
        },
        contentBackdrop = navigationBackdrop,
        bottomBar = {
            GlasmioNavigationBar(
                items = tabItems(selectedRoot),
                selectedKey = selectedRoot,
                onSelected = selectTab,
                onExpand = {},
                compactProgress = compactProgress,
                compactSize = CompactBottomControlSize,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .padding(bottom = 8.dp)
                    .navigationBarsPadding(),
            )
        },
    ) { headerPadding ->
        val layoutDirection = LocalLayoutDirection.current
        val density = LocalDensity.current.density
        GlasmioNavDisplay(
            motion = headerMotion,
            backStack = backStack,
            modifier = Modifier.fillMaxSize(),
            onBack = navigateBack,
            transitionSpec = {
                if (isRootTab()) {
                    fadeIn() togetherWith fadeOut()
                } else {
                    iosTransitionSpec<String>(layoutDirection, density).invoke(this)
                }
            },
            popTransitionSpec = {
                if (isRootTab()) {
                    fadeIn() togetherWith fadeOut()
                } else {
                    iosTransitionSpec<String>(layoutDirection, density).invoke(this)
                }
            },
            entryProvider = { route ->
                val key = NavKey.fromRoute(route)
                NavEntry(key = route, contentKey = route) {
                    Box(Modifier.fillMaxSize()) {
                        RootPlaceholder(
                            key = key,
                            contentPadding = headerPadding,
                            headerEntry = headerEntry(route),
                        )
                        GlasmioPageTitle(route)
                    }
                }
            },
        )
    }
}

@Composable
private fun tabItems(selected: NavKey): List<GlasmioTabItem<NavKey>> = listOf(
    GlasmioTabItem(
        key = NavKey.Home,
        label = "Home",
        symbol = if (selected == NavKey.Home) SfSymbol.HouseFilled else SfSymbol.House,
    ),
    GlasmioTabItem(NavKey.Search, "Search", SfSymbol.Search),
    GlasmioTabItem(NavKey.Library, "Library", SfSymbol.Layers),
    GlasmioTabItem(NavKey.Playlists, "Playlists", SfSymbol.MusicNoteList),
    GlasmioTabItem(NavKey.Settings, "Settings", SfSymbol.Settings),
)

private fun Scene<String>.lastRoute(): String? = entries.lastOrNull()?.contentKey as? String

private fun AnimatedContentTransitionScope<Scene<String>>.isRootTab(): Boolean =
    initialState.lastRoute()?.let(NavKey::fromRoute)?.isRoot == true &&
        targetState.lastRoute()?.let(NavKey::fromRoute)?.isRoot == true
