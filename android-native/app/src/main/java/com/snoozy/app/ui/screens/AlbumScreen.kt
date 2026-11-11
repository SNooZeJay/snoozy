package com.snoozy.app.ui.screens

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.snoozy.app.data.library.LibraryRepository
import com.snoozy.app.ui.components.SnoozyArtwork
import com.snoozy.app.ui.components.SnoozyEmptyState
import com.snoozy.app.ui.components.SnoozyGridPage
import com.snoozy.app.ui.components.SnoozyGroupedRow
import com.snoozy.app.ui.components.SnoozySectionHeader
import com.snoozy.app.ui.components.SnoozyTrackRow
import com.snoozy.app.ui.components.rememberLibraryActions
import com.snoozy.app.ui.format.countLabel
import com.snoozy.app.ui.format.formatDuration
import com.snoozy.app.ui.icons.SnoozyIcons
import com.snoozy.app.ui.navigation.BindHeader
import com.snoozy.app.ui.navigation.LocalLibraryRepository
import com.snoozy.app.ui.navigation.NavHeaderEntry
import androidx.compose.material3.Text
import io.github.neoruaa.glasmio.ui.GlasmioButton

@Composable
fun AlbumScreen(
    albumKey: String,
    contentPadding: PaddingValues,
    headerEntry: NavHeaderEntry,
) {
    val repository = LocalLibraryRepository.current
    val state by repository.state.collectAsState()
    val actions = rememberLibraryActions(repository)

    val album = remember(state.albums, albumKey) {
        state.albums.firstOrNull { it.id == albumKey }
    }
    val tracks = remember(state.tracks, album) {
        val byId = state.tracks.associateBy { it.id }
        album?.trackIds?.mapNotNull { byId[it] }.orEmpty()
    }

    val title = album?.title ?: "Album"
    val subtitle = album?.let {
        listOfNotNull(
            it.artist.takeIf(String::isNotBlank),
            it.year?.takeIf(String::isNotBlank),
            countLabel(tracks.size, "track", "tracks"),
            formatDuration(it.duration),
        ).joinToString(" · ")
    }
    BindHeader(title, subtitle)

    SnoozyGridPage(
        contentPadding = contentPadding,
        headerEntry = headerEntry,
        title = title,
        subtitle = subtitle,
    ) {
        if (album == null || tracks.isEmpty()) {
            item(span = { GridItemSpan(maxLineSpan) }, key = "album-empty") {
                SnoozyEmptyState(
                    icon = SnoozyIcons.Music,
                    title = "No tracks in this album",
                    message = "Rescan your Music folder if this looks wrong.",
                    action = {
                        GlasmioButton(onClick = actions.scan) { Text("Rescan library") }
                    },
                )
            }
        } else {
            item(span = { GridItemSpan(maxLineSpan) }, key = "album-artwork") {
                Box(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    SnoozyArtwork(
                        uri = album.artwork,
                        size = 188.dp,
                        corner = 32.dp,
                        contentDescription = album.title,
                    )
                }
            }
            item(span = { GridItemSpan(maxLineSpan) }, key = "album-tracks-title") {
                SnoozySectionHeader("Tracks")
            }
            itemsIndexed(
                items = tracks,
                key = { _, track -> track.id },
                span = { _, _ -> GridItemSpan(maxLineSpan) },
            ) { index, track ->
                SnoozyGroupedRow(index, tracks.size) {
                    SnoozyTrackRow(
                        track = track,
                        subtitle = track.artist,
                        onClick = null,
                        showTopSeparator = index > 0,
                    )
                }
            }
        }
    }
}
