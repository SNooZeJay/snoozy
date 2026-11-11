package com.snoozy.app.ui.screens

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.unit.dp
import com.snoozy.app.data.library.albumKeyFor
import com.snoozy.app.data.library.albumsForArtist
import com.snoozy.app.data.library.tracksForArtist
import com.snoozy.app.ui.components.SnoozyAlbumRow
import com.snoozy.app.ui.components.SnoozyEmptyState
import com.snoozy.app.ui.components.SnoozyGridPage
import com.snoozy.app.ui.components.SnoozyGroupedRow
import com.snoozy.app.ui.components.SnoozySectionHeader
import com.snoozy.app.ui.components.SnoozyTrackRow
import com.snoozy.app.ui.components.rememberLibraryActions
import com.snoozy.app.ui.format.countLabel
import com.snoozy.app.ui.icons.SnoozyIcons
import com.snoozy.app.ui.navigation.BindHeader
import com.snoozy.app.ui.navigation.LocalLibraryRepository
import com.snoozy.app.ui.navigation.NavHeaderEntry
import io.github.neoruaa.glasmio.ui.GlasmioButton

@Composable
fun ArtistScreen(
    name: String,
    contentPadding: PaddingValues,
    headerEntry: NavHeaderEntry,
    onOpenAlbum: (String) -> Unit,
) {
    val repository = LocalLibraryRepository.current
    val state by repository.state.collectAsState()
    val actions = rememberLibraryActions(repository)

    val title = name.ifBlank { "Unknown artist" }
    val tracks = remember(state.tracks, name) { tracksForArtist(state.tracks, name) }
    val albums = remember(state.albums, state.tracks, name) {
        albumsForArtist(state.albums, state.tracks, name)
    }
    val subtitle = "${countLabel(tracks.size, "song", "songs")} · " +
        countLabel(albums.size, "album", "albums")
    BindHeader(title, subtitle)

    SnoozyGridPage(
        contentPadding = contentPadding,
        headerEntry = headerEntry,
        title = title,
        subtitle = subtitle,
    ) {
        if (tracks.isEmpty()) {
            item(span = { GridItemSpan(maxLineSpan) }, key = "artist-empty") {
                SnoozyEmptyState(
                    icon = SnoozyIcons.Person,
                    title = "No songs for this artist",
                    message = "Rescan your Music folder if this looks wrong.",
                    action = {
                        GlasmioButton(onClick = actions.scan) { Text("Rescan library") }
                    },
                )
            }
        } else {
            if (albums.isNotEmpty()) {
                item(span = { GridItemSpan(maxLineSpan) }, key = "artist-albums-title") {
                    SnoozySectionHeader("Albums")
                }
                itemsIndexed(
                    items = albums,
                    key = { _, album -> "artist-album-${album.id}" },
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

            item(span = { GridItemSpan(maxLineSpan) }, key = "artist-songs-title") {
                SnoozySectionHeader("Songs")
            }
            itemsIndexed(
                items = tracks,
                key = { _, track -> "artist-song-${track.id}" },
                span = { _, _ -> GridItemSpan(maxLineSpan) },
            ) { index, track ->
                SnoozyGroupedRow(index, tracks.size) {
                    SnoozyTrackRow(
                        track = track,
                        subtitle = track.album,
                        onClick = { onOpenAlbum(albumKeyFor(track)) },
                        showTopSeparator = index > 0,
                    )
                }
            }
        }
    }
}
