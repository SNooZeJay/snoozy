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
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.listSaver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.runtime.toMutableStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.dp
import androidx.navigation3.runtime.NavEntry
import androidx.navigation3.scene.Scene
import com.snoozy.app.data.library.LibraryRepository
import com.snoozy.app.ui.icons.SnoozyIcons
import com.snoozy.app.ui.screens.AlbumScreen
import com.snoozy.app.ui.screens.ArtistScreen
import com.snoozy.app.ui.screens.GenreScreen
import com.snoozy.app.ui.screens.HomeScreen
import com.snoozy.app.ui.screens.LibraryScreen
import com.snoozy.app.ui.screens.LibraryTab
import com.snoozy.app.ui.screens.PlaylistsScreen
import com.snoozy.app.ui.screens.RootPlaceholder
import io.github.neoruaa.glasmio.glass.GlasmioBackdropProvider
import io.github.neoruaa.glasmio.glass.render.backdrops.rememberLayerBackdrop
import io.github.neoruaa.glasmio.icons.SfSymbol
import io.github.neoruaa.glasmio.scaffold.GlasmioHeaderAction
import io.github.neoruaa.glasmio.scaffold.GlasmioHeaderGroup
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
fun SnoozyApp(repository: LibraryRepository, onExit: () -> Unit) {
    val backStack = rememberSaveable(
        saver = listSaver<SnapshotStateList<String>, String>(
            save = { it.toList() },
            restore = { it.toMutableStateList() },
        ),
    ) { mutableStateListOf(NavKey.Home.route) }
    var libraryTab by rememberSaveable { mutableStateOf(LibraryTab.Songs) }

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

    val openAlbum: (String) -> Unit = { albumKey ->
        backStack.add(NavKey.Album(albumKey).route)
    }
    val openArtist: (String) -> Unit = { name ->
        backStack.add(NavKey.Artist(name).route)
    }
    val openGenre: (String) -> Unit = { name ->
        backStack.add(NavKey.Genre(name).route)
    }
    val openPlaylist: (String) -> Unit = { id ->
        backStack.add(NavKey.Playlist(id).route)
    }
    val openLibraryAlbums: () -> Unit = {
        libraryTab = LibraryTab.Albums
        selectTab(NavKey.Library)
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

    CompositionLocalProvider(LocalLibraryRepository provides repository) {
        GlasmioBackdropProvider(navigationBackdrop) {
            GlasmioNavigationScaffold(
                motion = headerMotion,
                header = { entryKey ->
                    val route = entryKey as String
                    val key = NavKey.fromRoute(route)
                    val entry = headerEntry(route)
                    GlasmioHeaderSpec(
                        title = entry.title ?: key.title,
                        subtitle = entry.subtitle,
                        leading = if (key.isRoot) emptyList() else listOf(backGroup(navigateBack)),
                        trailing = if (entry.actions.isEmpty()) {
                            emptyList()
                        } else {
                            listOf(GlasmioHeaderGroup("actions", entry.actions))
                        },
                        scrollState = entry.scroll,
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
                        val entry = headerEntry(route)
                        NavEntry(key = route, contentKey = route) {
                            CompositionLocalProvider(
                                LocalNavHeaderEntry provides entry,
                                LocalLibraryRepository provides repository,
                            ) {
                                Box(Modifier.fillMaxSize()) {
                                    when (key) {
                                        NavKey.Home -> HomeScreen(
                                            contentPadding = headerPadding,
                                            headerEntry = entry,
                                            openAlbum = openAlbum,
                                            openLibraryAlbums = openLibraryAlbums,
                                        )

                                        NavKey.Library -> LibraryScreen(
                                            contentPadding = headerPadding,
                                            headerEntry = entry,
                                            tab = libraryTab,
                                            onTabChange = { libraryTab = it },
                                            onOpenAlbum = openAlbum,
                                            onOpenArtist = openArtist,
                                            onOpenGenre = openGenre,
                                        )

                                        is NavKey.Album -> AlbumScreen(
                                            albumKey = key.albumKey,
                                            contentPadding = headerPadding,
                                            headerEntry = entry,
                                        )

                                        is NavKey.Artist -> ArtistScreen(
                                            name = key.name,
                                            contentPadding = headerPadding,
                                            headerEntry = entry,
                                            onOpenAlbum = openAlbum,
                                        )

                                        is NavKey.Genre -> GenreScreen(
                                            name = key.name,
                                            contentPadding = headerPadding,
                                            headerEntry = entry,
                                            onOpenAlbum = openAlbum,
                                        )

                                        NavKey.Playlists -> PlaylistsScreen(
                                            contentPadding = headerPadding,
                                            headerEntry = entry,
                                            openPlaylist = openPlaylist,
                                        )

                                        else -> RootPlaceholder(
                                            key = key,
                                            contentPadding = headerPadding,
                                            headerEntry = entry,
                                        )
                                    }
                                    GlasmioPageTitle(route)
                                }
                            }
                        }
                    },
                )
            }
        }
    }
}

private fun backGroup(onBack: () -> Unit): GlasmioHeaderGroup = GlasmioHeaderGroup(
    key = "navigation",
    actions = listOf(
        GlasmioHeaderAction(
            key = "navigation.back",
            visualKey = "navigation.back",
            contentDescription = "Back",
            onClick = onBack,
        ) {
            Icon(SnoozyIcons.Back, null, Modifier.size(22.dp))
        },
    ),
)

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
