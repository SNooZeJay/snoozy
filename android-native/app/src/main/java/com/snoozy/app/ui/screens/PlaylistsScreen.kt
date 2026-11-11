package com.snoozy.app.ui.screens

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.snoozy.app.data.model.Playlist
import com.snoozy.app.ui.components.PlaylistActionsSheet
import com.snoozy.app.ui.components.PlaylistDeleteDialog
import com.snoozy.app.ui.components.PlaylistNameSheet
import com.snoozy.app.ui.components.SnoozyEmptyState
import com.snoozy.app.ui.components.SnoozyErrorBanner
import com.snoozy.app.ui.components.SnoozyGridPage
import com.snoozy.app.ui.components.SnoozyGroupedRow
import com.snoozy.app.ui.components.SnoozyPlaylistRow
import com.snoozy.app.ui.format.countLabel
import com.snoozy.app.ui.icons.SnoozyIcons
import com.snoozy.app.ui.navigation.BindHeader
import com.snoozy.app.ui.navigation.LocalLibraryRepository
import com.snoozy.app.ui.navigation.NavHeaderEntry
import io.github.neoruaa.glasmio.scaffold.GlasmioHeaderAction
import io.github.neoruaa.glasmio.ui.GlasmioButton
import kotlinx.coroutines.launch

@Composable
fun PlaylistsScreen(
    contentPadding: PaddingValues,
    headerEntry: NavHeaderEntry,
    openPlaylist: (String) -> Unit,
) {
    val repository = LocalLibraryRepository.current
    val state by repository.state.collectAsState()
    val scope = rememberCoroutineScope()

    var createOpen by rememberSaveable { mutableStateOf(false) }
    var renameTarget by remember { mutableStateOf<Playlist?>(null) }
    var manageTarget by remember { mutableStateOf<Playlist?>(null) }
    var deleteTarget by remember { mutableStateOf<Playlist?>(null) }

    val title = "Playlists"
    val subtitle =
        countLabel(state.playlists.size, "playlist", "playlists") + " · saved on this device"
    val actions = remember {
        listOf(
            GlasmioHeaderAction(
                key = "new",
                visualKey = "new",
                contentDescription = "New playlist",
                onClick = { createOpen = true },
            ) {
                Icon(SnoozyIcons.Plus, null, Modifier.size(20.dp))
            },
        )
    }
    BindHeader(title, subtitle, actions)

    val tracksById = remember(state.tracks) { state.tracks.associateBy { it.id } }

    SnoozyGridPage(
        contentPadding = contentPadding,
        headerEntry = headerEntry,
        title = title,
        subtitle = subtitle,
    ) {
        if (state.error != null) {
            item(span = { GridItemSpan(maxLineSpan) }, key = "playlists-error") {
                SnoozyErrorBanner(state.error.orEmpty()) { repository.clearError() }
            }
        }

        if (state.playlists.isEmpty()) {
            item(span = { GridItemSpan(maxLineSpan) }, key = "playlists-empty") {
                SnoozyEmptyState(
                    icon = SnoozyIcons.Playlists,
                    title = "No playlists yet",
                    message = "Build a set for a walk, a drive, or a quiet evening. Open a playlist to add songs.",
                    action = {
                        GlasmioButton(onClick = { createOpen = true }) {
                            Text("Create a playlist")
                        }
                    },
                )
            }
        } else {
            itemsIndexed(
                items = state.playlists,
                key = { _, playlist -> playlist.id },
                span = { _, _ -> GridItemSpan(maxLineSpan) },
            ) { index, playlist ->
                val tracks = playlist.trackIds.mapNotNull(tracksById::get)
                SnoozyGroupedRow(index, state.playlists.size) {
                    SnoozyPlaylistRow(
                        playlist = playlist,
                        trackCount = tracks.size,
                        artworks = tracks.map { it.artwork },
                        onClick = { openPlaylist(playlist.id) },
                        onManage = { manageTarget = playlist },
                        showTopSeparator = index > 0,
                    )
                }
            }
        }
    }

    if (createOpen) {
        PlaylistNameSheet(
            title = "New playlist",
            submitLabel = "Create",
            initialName = "",
            onSubmit = { name -> scope.launch { repository.createPlaylist(name) } },
            onDismiss = { createOpen = false },
        )
    }

    val renaming = renameTarget
    if (renaming != null) {
        PlaylistNameSheet(
            title = "Rename playlist",
            submitLabel = "Save",
            initialName = renaming.name,
            onSubmit = { name -> scope.launch { repository.renamePlaylist(renaming.id, name) } },
            onDismiss = { renameTarget = null },
        )
    }

    val managing = manageTarget
    if (managing != null) {
        PlaylistActionsSheet(
            playlist = managing,
            onRename = {
                manageTarget = null
                renameTarget = managing
            },
            onDelete = {
                manageTarget = null
                deleteTarget = managing
            },
            onDismiss = { manageTarget = null },
        )
    }

    val deleting = deleteTarget
    if (deleting != null) {
        PlaylistDeleteDialog(
            name = deleting.name,
            onConfirm = {
                scope.launch { repository.deletePlaylist(deleting.id) }
                deleteTarget = null
            },
            onDismiss = { deleteTarget = null },
        )
    }
}
