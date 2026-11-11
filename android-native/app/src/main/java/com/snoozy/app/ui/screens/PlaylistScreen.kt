package com.snoozy.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.snoozy.app.data.model.Track
import com.snoozy.app.ui.components.AddSongsSheet
import com.snoozy.app.ui.components.PlaylistDeleteDialog
import com.snoozy.app.ui.components.PlaylistNameSheet
import com.snoozy.app.ui.components.PlaylistTrackActionsSheet
import com.snoozy.app.ui.components.SnoozyEmptyState
import com.snoozy.app.ui.components.SnoozyErrorBanner
import com.snoozy.app.ui.components.SnoozyGridPage
import com.snoozy.app.ui.components.SnoozyGroupedRow
import com.snoozy.app.ui.components.SnoozyIconAction
import com.snoozy.app.ui.components.SnoozyPlaylistCover
import com.snoozy.app.ui.components.SnoozySectionHeader
import com.snoozy.app.ui.components.SnoozyTrackRow
import com.snoozy.app.ui.format.countLabel
import com.snoozy.app.ui.format.formatDuration
import com.snoozy.app.ui.icons.SnoozyIcons
import com.snoozy.app.ui.navigation.BindHeader
import com.snoozy.app.ui.navigation.LocalLibraryRepository
import com.snoozy.app.ui.navigation.NavHeaderEntry
import io.github.neoruaa.glasmio.core.LocalGlassColors
import io.github.neoruaa.glasmio.scaffold.GlasmioHeaderAction
import io.github.neoruaa.glasmio.ui.GlasmioButton
import kotlinx.coroutines.launch

private data class SongTarget(val track: Track, val index: Int)

@Composable
fun PlaylistScreen(
    playlistId: String,
    contentPadding: PaddingValues,
    headerEntry: NavHeaderEntry,
    onBack: () -> Unit,
) {
    val repository = LocalLibraryRepository.current
    val state by repository.state.collectAsState()
    val scope = rememberCoroutineScope()
    val destructive = LocalGlassColors.current.destructive

    val playlist = state.playlists.firstOrNull { it.id == playlistId }
    val byId = remember(state.tracks) { state.tracks.associateBy { it.id } }
    val tracks = remember(playlist, byId) { playlist?.trackIds?.mapNotNull(byId::get).orEmpty() }
    val totalDuration = tracks.sumOf { it.duration }
    val subtitle = playlist?.let {
        listOf(countLabel(tracks.size, "track", "tracks"), formatDuration(totalDuration))
            .joinToString(" \u00B7 ")
    }

    var addSongsOpen by rememberSaveable { mutableStateOf(false) }
    var renameOpen by rememberSaveable { mutableStateOf(false) }
    var deleteOpen by rememberSaveable { mutableStateOf(false) }
    var songMenu by remember { mutableStateOf<SongTarget?>(null) }

    val actions = remember(playlist, destructive) {
        if (playlist == null) {
            emptyList()
        } else {
            listOf(
                GlasmioHeaderAction(
                    key = "playlist.rename",
                    visualKey = "playlist.rename",
                    contentDescription = "Rename ${playlist.name}",
                    onClick = { renameOpen = true },
                ) {
                    Icon(SnoozyIcons.Edit, null, Modifier.size(20.dp))
                },
                GlasmioHeaderAction(
                    key = "playlist.delete",
                    visualKey = "playlist.delete",
                    contentDescription = "Delete ${playlist.name}",
                    onClick = { deleteOpen = true },
                ) {
                    Icon(SnoozyIcons.Trash, null, Modifier.size(20.dp), tint = destructive)
                },
            )
        }
    }
    BindHeader(playlist?.name ?: "Playlist", subtitle, actions)

    if (playlist == null) {
        SnoozyGridPage(
            contentPadding = contentPadding,
            headerEntry = headerEntry,
            title = "Playlist",
            subtitle = null,
        ) {
            item(span = { GridItemSpan(maxLineSpan) }, key = "playlist-missing") {
                SnoozyEmptyState(
                    icon = SnoozyIcons.Playlists,
                    title = "Playlist not found",
                    message = "It may have been deleted. Your songs are still in the library.",
                    action = {
                        GlasmioButton(onClick = onBack) {
                            Text("Back to library")
                        }
                    },
                )
            }
        }
        return
    }

    SnoozyGridPage(
        contentPadding = contentPadding,
        headerEntry = headerEntry,
        title = playlist.name,
        subtitle = subtitle,
    ) {
        if (state.error != null) {
            item(span = { GridItemSpan(maxLineSpan) }, key = "playlist-error") {
                SnoozyErrorBanner(state.error.orEmpty()) { repository.clearError() }
            }
        }

        item(span = { GridItemSpan(maxLineSpan) }, key = "playlist-cover") {
            Box(
                modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp),
                contentAlignment = Alignment.Center,
            ) {
                SnoozyPlaylistCover(tracks.map { it.artwork }, 188.dp, 32.dp)
            }
        }

        item(span = { GridItemSpan(maxLineSpan) }, key = "playlist-actions") {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
            ) {
                GlasmioButton(onClick = { addSongsOpen = true }) {
                    Text("Add songs")
                }
            }
        }

        if (tracks.isEmpty()) {
            item(span = { GridItemSpan(maxLineSpan) }, key = "playlist-empty") {
                SnoozyEmptyState(
                    icon = SnoozyIcons.Music,
                    title = "No songs yet",
                    message = "Add songs from your library to start this playlist.",
                    action = {
                        GlasmioButton(onClick = { addSongsOpen = true }) {
                            Text("Add songs")
                        }
                    },
                )
            }
        } else {
            item(span = { GridItemSpan(maxLineSpan) }, key = "playlist-songs-title") {
                SnoozySectionHeader("Songs")
            }
            itemsIndexed(
                items = tracks,
                key = { _, track -> track.id },
                span = { _, _ -> GridItemSpan(maxLineSpan) },
            ) { index, track ->
                SnoozyGroupedRow(index, tracks.size) {
                    SnoozyTrackRow(
                        track = track,
                        subtitle = "${track.artist} \u00B7 ${track.album}",
                        onClick = null,
                        showTopSeparator = index > 0,
                        trailing = {
                            SnoozyIconAction(
                                icon = SnoozyIcons.More,
                                label = "Manage ${track.title} in ${playlist.name}",
                                onClick = { songMenu = SongTarget(track, index) },
                            )
                        },
                    )
                }
            }
        }
    }

    if (addSongsOpen) {
        AddSongsSheet(
            playlistName = playlist.name,
            trackIds = tracks.mapTo(HashSet()) { it.id },
            tracks = state.tracks,
            onAdd = { trackId ->
                scope.launch { repository.addToPlaylist(playlist.id, trackId) }
            },
            onRemove = { trackId ->
                scope.launch { repository.removeFromPlaylist(playlist.id, trackId) }
            },
            onDismiss = { addSongsOpen = false },
        )
    }

    if (renameOpen) {
        PlaylistNameSheet(
            title = "Rename playlist",
            submitLabel = "Save",
            initialName = playlist.name,
            onSubmit = { name -> scope.launch { repository.renamePlaylist(playlist.id, name) } },
            onDismiss = { renameOpen = false },
        )
    }

    songMenu?.let { menu ->
        val index = menu.index
        val move = { direction: Int ->
            val neighbor = tracks.getOrNull(index + direction)
            val from = playlist.trackIds.indexOf(menu.track.id)
            val to = neighbor?.let { playlist.trackIds.indexOf(it.id) } ?: -1
            if (from >= 0 && to >= 0) {
                scope.launch { repository.movePlaylistTrack(playlist.id, from, to) }
            }
        }
        PlaylistTrackActionsSheet(
            track = menu.track,
            canMoveUp = index > 0,
            canMoveDown = index < tracks.lastIndex,
            onMoveUp = { move(-1) },
            onMoveDown = { move(1) },
            onRemove = {
                scope.launch { repository.removeFromPlaylist(playlist.id, menu.track.id) }
            },
            onDismiss = { songMenu = null },
        )
    }

    if (deleteOpen) {
        PlaylistDeleteDialog(
            name = playlist.name,
            onConfirm = {
                deleteOpen = false
                scope.launch {
                    if (repository.deletePlaylist(playlist.id)) onBack()
                }
            },
            onDismiss = { deleteOpen = false },
        )
    }
}
