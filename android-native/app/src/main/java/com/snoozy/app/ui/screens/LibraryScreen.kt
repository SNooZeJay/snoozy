package com.snoozy.app.ui.screens

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.snoozy.app.data.library.AlbumSort
import com.snoozy.app.data.library.SongSort
import com.snoozy.app.data.library.artistNamesOf
import com.snoozy.app.data.library.favoriteTracks
import com.snoozy.app.data.library.genresOf
import com.snoozy.app.data.library.libraryStatus
import com.snoozy.app.data.library.sortedAlbums
import com.snoozy.app.data.library.sortedTracks
import com.snoozy.app.data.model.Track
import com.snoozy.app.ui.components.AddToPlaylistSheet
import com.snoozy.app.ui.components.SnoozyAlbumRow
import com.snoozy.app.ui.components.SnoozyAlbumTile
import com.snoozy.app.ui.components.SnoozyArtistRow
import com.snoozy.app.ui.components.SnoozyEmptyState
import com.snoozy.app.ui.components.SnoozyErrorBanner
import com.snoozy.app.ui.components.SnoozyGenreRow
import com.snoozy.app.ui.components.SnoozyGridPage
import com.snoozy.app.ui.components.SnoozyGroupedRow
import com.snoozy.app.ui.components.SnoozyIconAction
import com.snoozy.app.ui.components.SnoozyPermissionEmpty
import com.snoozy.app.ui.components.SnoozyScanEmpty
import com.snoozy.app.ui.components.SnoozyTrackRow
import com.snoozy.app.ui.components.TrackActionsSheet
import com.snoozy.app.ui.components.libraryHeaderActions
import com.snoozy.app.ui.components.rememberLibraryActions
import com.snoozy.app.ui.format.countLabel
import com.snoozy.app.ui.icons.SnoozyIcons
import com.snoozy.app.ui.navigation.BindHeader
import com.snoozy.app.ui.navigation.LocalLibraryRepository
import com.snoozy.app.ui.navigation.LocalPlaybackController
import com.snoozy.app.ui.navigation.NavHeaderEntry
import io.github.neoruaa.glasmio.core.IosTypography
import io.github.neoruaa.glasmio.core.LocalGlassColors
import io.github.neoruaa.glasmio.ui.GlasmioActionSheetContent
import io.github.neoruaa.glasmio.ui.GlasmioBottomSheet
import io.github.neoruaa.glasmio.ui.GlasmioButton
import io.github.neoruaa.glasmio.ui.GlasmioButtonSize
import io.github.neoruaa.glasmio.ui.GlasmioIconButton
import io.github.neoruaa.glasmio.ui.GlasmioListRow
import io.github.neoruaa.glasmio.ui.GlasmioSegmentedControl
import kotlinx.coroutines.launch

enum class LibraryTab(val label: String) {
    Songs("Songs"),
    Albums("Albums"),
    Artists("Artists"),
    Genres("Genres"),
    Favorites("Favorites"),
}

@Composable
fun LibraryScreen(
    contentPadding: PaddingValues,
    headerEntry: NavHeaderEntry,
    tab: LibraryTab,
    onTabChange: (LibraryTab) -> Unit,
    onOpenAlbum: (String) -> Unit,
    onOpenArtist: (String) -> Unit,
    onOpenGenre: (String) -> Unit,
) {
    val repository = LocalLibraryRepository.current
    val playbackController = LocalPlaybackController.current
    val state by repository.state.collectAsState()
    val playbackState by playbackController.state.collectAsState()
    val actions = rememberLibraryActions(repository)
    val scope = rememberCoroutineScope()

    var albumGrid by rememberSaveable { mutableStateOf(true) }
    var songSortOpen by remember { mutableStateOf(false) }
    var albumSortOpen by remember { mutableStateOf(false) }
    var menuTrack by remember { mutableStateOf<Track?>(null) }
    var playlistPickerTrack by remember { mutableStateOf<Track?>(null) }

    val songs = remember(state.tracks, state.songSort) {
        sortedTracks(state.tracks, state.songSort)
    }
    val albums = remember(state.albums, state.albumSort) {
        sortedAlbums(state.albums, state.albumSort)
    }
    val artists = remember(state.tracks) { artistNamesOf(state.tracks) }
    val genres = remember(state.tracks) { genresOf(state.tracks) }
    val favorites = remember(state.tracks, state.favoriteTrackIds) {
        favoriteTracks(state.tracks, state.favoriteTrackIds)
    }

    val count = when (tab) {
        LibraryTab.Songs -> songs.size
        LibraryTab.Albums -> albums.size
        LibraryTab.Artists -> artists.size
        LibraryTab.Genres -> genres.size
        LibraryTab.Favorites -> favorites.size
    }
    val countText = when (tab) {
        LibraryTab.Songs -> countLabel(count, "song", "songs")
        LibraryTab.Albums -> countLabel(count, "album", "albums")
        LibraryTab.Artists -> countLabel(count, "artist", "artists")
        LibraryTab.Genres -> countLabel(count, "genre", "genres")
        LibraryTab.Favorites -> countLabel(count, "favorite", "favorites")
    }

    val status = libraryStatus(state.hasPermission, state.scanning, state.tracks.size)
    BindHeader("Library", status, libraryHeaderActions(actions, state.hasPermission))

    key(tab, albumGrid) {
        SnoozyGridPage(
            contentPadding = contentPadding,
            headerEntry = headerEntry,
            title = "Library",
            subtitle = status,
            columns = if (tab == LibraryTab.Albums && albumGrid) 2 else 1,
        ) {
            item(span = { GridItemSpan(maxLineSpan) }, key = "library-segments") {
                GlasmioSegmentedControl(
                    items = LibraryTab.entries.map { it to it.label },
                    selected = tab,
                    onSelected = onTabChange,
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                    height = 44.dp,
                )
            }

            item(span = { GridItemSpan(maxLineSpan) }, key = "library-toolbar") {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = countText,
                        style = IosTypography.subheadline,
                        color = LocalGlassColors.current.secondaryContent,
                        modifier = Modifier.weight(1f),
                    )
                    when (tab) {
                        LibraryTab.Songs -> SortButton(
                            label = "Sort · ${state.songSort.label}",
                            onClick = { songSortOpen = true },
                        )

                        LibraryTab.Albums -> {
                            SortButton(
                                label = "Sort · ${state.albumSort.label}",
                                onClick = { albumSortOpen = true },
                            )
                            Spacer(Modifier.width(8.dp))
                            val layoutLabel = if (albumGrid) {
                                "Show albums as a list"
                            } else {
                                "Show albums as a grid"
                            }
                            GlasmioIconButton(
                                onClick = { albumGrid = !albumGrid },
                                modifier = Modifier.semantics {
                                    contentDescription = layoutLabel
                                },
                                size = 44.dp,
                            ) {
                                Icon(
                                    imageVector = if (albumGrid) SnoozyIcons.Playlists else SnoozyIcons.Grid,
                                    contentDescription = null,
                                    modifier = Modifier.size(20.dp),
                                )
                            }
                        }

                        LibraryTab.Favorites -> if (favorites.isNotEmpty()) {
                            GlasmioButton(
                                onClick = {
                                    val shuffled = favorites.shuffled()
                                    if (shuffled.isNotEmpty()) {
                                        playbackController.playTrack(
                                            track = shuffled.first(),
                                            queue = shuffled,
                                            shuffleOverride = true,
                                        )
                                    }
                                },
                                size = GlasmioButtonSize.Medium,
                                modifier = Modifier.heightIn(min = 44.dp).semantics {
                                    contentDescription = "Shuffle favorites"
                                },
                            ) {
                                Icon(
                                    imageVector = SnoozyIcons.Shuffle,
                                    contentDescription = null,
                                    modifier = Modifier.size(16.dp),
                                )
                                Text(text = "Shuffle", modifier = Modifier.padding(start = 6.dp))
                            }
                        }

                        else -> Unit
                    }
                }
            }

            if (state.error != null) {
                item(span = { GridItemSpan(maxLineSpan) }, key = "library-error") {
                    SnoozyErrorBanner(state.error.orEmpty()) { repository.clearError() }
                }
            }
            if (playbackState.error != null) {
                item(span = { GridItemSpan(maxLineSpan) }, key = "library-playback-error") {
                    SnoozyErrorBanner(playbackState.error.orEmpty()) { playbackController.clearError() }
                }
            }

            when (tab) {
                LibraryTab.Songs -> {
                    if (songs.isEmpty()) {
                        item(span = { GridItemSpan(maxLineSpan) }, key = "library-songs-empty") {
                            if (state.hasPermission) {
                                SnoozyScanEmpty(
                                    actions = actions,
                                    message = "Put songs in your Music folder, then scan your device.",
                                )
                            } else {
                                SnoozyPermissionEmpty(actions)
                            }
                        }
                    } else {
                        itemsIndexed(
                            items = songs,
                            key = { _, track -> "library-song-${track.id}" },
                            span = { _, _ -> GridItemSpan(maxLineSpan) },
                        ) { index, track ->
                            SnoozyGroupedRow(index, songs.size) {
                                SnoozyTrackRow(
                                    track = track,
                                    subtitle = track.artist,
                                    active = playbackState.activeTrack?.id == track.id,
                                    onClick = { playbackController.playTrack(track, songs) },
                                    showTopSeparator = index > 0,
                                    trailing = {
                                        SnoozyIconAction(
                                            icon = SnoozyIcons.More,
                                            label = "Manage ${track.title}",
                                            onClick = { menuTrack = track },
                                        )
                                    },
                                )
                            }
                        }
                    }
                }

                LibraryTab.Albums -> {
                    if (albums.isEmpty()) {
                        item(span = { GridItemSpan(maxLineSpan) }, key = "library-albums-empty") {
                            SnoozyEmptyState(
                                icon = SnoozyIcons.Music,
                                title = "No albums yet",
                                message = "Albums appear as soon as songs are indexed.",
                            )
                        }
                    } else if (albumGrid) {
                        items(albums, key = { it.id }) { album ->
                            SnoozyAlbumTile(album = album, onClick = { onOpenAlbum(album.id) })
                        }
                    } else {
                        itemsIndexed(
                            items = albums,
                            key = { _, album -> "library-album-${album.id}" },
                            span = { _, _ -> GridItemSpan(maxLineSpan) },
                        ) { index, album ->
                            SnoozyGroupedRow(index, albums.size) {
                                SnoozyAlbumRow(
                                    album = album,
                                    onClick = { onOpenAlbum(album.id) },
                                    showTopSeparator = index > 0,
                                )
                            }
                        }
                    }
                }

                LibraryTab.Artists -> {
                    if (artists.isEmpty()) {
                        item(span = { GridItemSpan(maxLineSpan) }, key = "library-artists-empty") {
                            SnoozyEmptyState(
                                icon = SnoozyIcons.Person,
                                title = "No artists yet",
                                message = "Artists appear when songs with artist tags are indexed.",
                            )
                        }
                    } else {
                        itemsIndexed(
                            items = artists,
                            key = { _, name -> "library-artist-$name" },
                            span = { _, _ -> GridItemSpan(maxLineSpan) },
                        ) { index, name ->
                            SnoozyGroupedRow(index, artists.size) {
                                SnoozyArtistRow(
                                    name = name,
                                    onClick = { onOpenArtist(name) },
                                    showTopSeparator = index > 0,
                                )
                            }
                        }
                    }
                }

                LibraryTab.Genres -> {
                    if (genres.isEmpty()) {
                        item(span = { GridItemSpan(maxLineSpan) }, key = "library-genres-empty") {
                            SnoozyEmptyState(
                                icon = SnoozyIcons.Layers,
                                title = "No genres yet",
                                message = "Genres appear when songs carry a genre tag.",
                            )
                        }
                    } else {
                        itemsIndexed(
                            items = genres,
                            key = { _, name -> "library-genre-$name" },
                            span = { _, _ -> GridItemSpan(maxLineSpan) },
                        ) { index, name ->
                            SnoozyGroupedRow(index, genres.size) {
                                SnoozyGenreRow(
                                    name = name,
                                    onClick = { onOpenGenre(name) },
                                    showTopSeparator = index > 0,
                                )
                            }
                        }
                    }
                }

                LibraryTab.Favorites -> {
                    if (favorites.isEmpty()) {
                        item(span = { GridItemSpan(maxLineSpan) }, key = "library-favorites-empty") {
                            SnoozyEmptyState(
                                icon = SnoozyIcons.Heart,
                                title = "No favorites yet",
                                message = "Open a song's menu and choose Add favorite.",
                                action = {
                                    GlasmioButton(onClick = { onTabChange(LibraryTab.Songs) }) {
                                        Text("Browse songs")
                                    }
                                },
                            )
                        }
                    } else {
                        itemsIndexed(
                            items = favorites,
                            key = { _, track -> "library-favorite-${track.id}" },
                            span = { _, _ -> GridItemSpan(maxLineSpan) },
                        ) { index, track ->
                            SnoozyGroupedRow(index, favorites.size) {
                                SnoozyTrackRow(
                                    track = track,
                                    subtitle = track.artist,
                                    active = playbackState.activeTrack?.id == track.id,
                                    onClick = { playbackController.playTrack(track, favorites) },
                                    showTopSeparator = index > 0,
                                    trailing = {
                                        SnoozyIconAction(
                                            icon = SnoozyIcons.More,
                                            label = "Manage ${track.title}",
                                            onClick = { menuTrack = track },
                                        )
                                    },
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    menuTrack?.let { selectedTrack ->
        TrackActionsSheet(
            track = selectedTrack,
            onPlayNext = { playbackController.playNext(selectedTrack) },
            onAddToQueue = { playbackController.addToQueue(selectedTrack) },
            onAddToPlaylist = { playlistPickerTrack = selectedTrack },
            onDismiss = { menuTrack = null },
        )
    }

    playlistPickerTrack?.let { selectedTrack ->
        AddToPlaylistSheet(
            track = selectedTrack,
            playlists = state.playlists,
            onAddToPlaylist = { playlistId ->
                scope.launch { repository.addToPlaylist(playlistId, selectedTrack.id) }
            },
            onCreateAndAdd = { name ->
                val createdId = repository.createPlaylist(name)
                if (!createdId.isNullOrBlank()) {
                    repository.addToPlaylist(createdId, selectedTrack.id)
                }
                createdId
            },
            onDismiss = { playlistPickerTrack = null },
        )
    }

    if (songSortOpen) {
        SortSheet(
            title = "Sort songs by",
            options = SongSort.entries,
            selected = state.songSort,
            label = { it.label },
            onSelect = { sort ->
                scope.launch { repository.setSongSort(sort) }
                songSortOpen = false
            },
            onDismiss = { songSortOpen = false },
        )
    }

    if (albumSortOpen) {
        SortSheet(
            title = "Sort albums by",
            options = AlbumSort.entries,
            selected = state.albumSort,
            label = { it.label },
            onSelect = { sort ->
                scope.launch { repository.setAlbumSort(sort) }
                albumSortOpen = false
            },
            onDismiss = { albumSortOpen = false },
        )
    }
}

@Composable
private fun SortButton(label: String, onClick: () -> Unit) {
    GlasmioButton(
        onClick = onClick,
        size = GlasmioButtonSize.Medium,
        modifier = Modifier.heightIn(min = 44.dp),
    ) {
        Text(label)
    }
}

@Composable
private fun <T> SortSheet(
    title: String,
    options: List<T>,
    selected: T,
    label: (T) -> String,
    onSelect: (T) -> Unit,
    onDismiss: () -> Unit,
) {
    GlasmioBottomSheet(
        visible = true,
        fitContent = true,
        onDismissRequest = onDismiss,
    ) {
        GlasmioActionSheetContent(title) {
            options.forEachIndexed { index, option ->
                GlasmioListRow(
                    title = label(option),
                    showTopSeparator = index > 0,
                    showDisclosure = false,
                    onClick = { onSelect(option) },
                    trailing = if (option == selected) {
                        {
                            Icon(
                                imageVector = SnoozyIcons.Check,
                                contentDescription = "Selected",
                                modifier = Modifier.size(20.dp),
                                tint = LocalGlassColors.current.accent,
                            )
                        }
                    } else {
                        null
                    },
                )
            }
            GlasmioListRow("Cancel", showDisclosure = false, onClick = onDismiss)
        }
    }
}
