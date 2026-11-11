package com.snoozy.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.snoozy.app.data.library.libraryStatus
import com.snoozy.app.data.library.recentlyAdded
import com.snoozy.app.data.library.topPlayedTracks
import com.snoozy.app.data.library.tracksForIds
import com.snoozy.app.ui.components.SnoozyEmptyState
import com.snoozy.app.ui.components.SnoozyErrorBanner
import com.snoozy.app.ui.components.SnoozyGridPage
import com.snoozy.app.ui.components.SnoozyGroupedRow
import com.snoozy.app.ui.components.SnoozyIconBadge
import com.snoozy.app.ui.components.SnoozyMediaCard
import com.snoozy.app.ui.components.SnoozyPermissionEmpty
import com.snoozy.app.ui.components.SnoozyScanEmpty
import com.snoozy.app.ui.components.SnoozySectionHeader
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
import io.github.neoruaa.glasmio.ui.GlasmioAlertButtonLayout
import io.github.neoruaa.glasmio.ui.GlasmioAlertButtonRole
import io.github.neoruaa.glasmio.ui.GlasmioAlertButtonSpec
import io.github.neoruaa.glasmio.ui.GlasmioAlertDialog
import io.github.neoruaa.glasmio.ui.GlasmioListRow
import kotlinx.coroutines.launch

@Composable
fun HomeScreen(
    contentPadding: PaddingValues,
    headerEntry: NavHeaderEntry,
    openAlbum: (String) -> Unit,
    openLibraryAlbums: () -> Unit,
) {
    val repository = LocalLibraryRepository.current
    val playbackController = LocalPlaybackController.current
    val state by repository.state.collectAsState()
    val playbackState by playbackController.state.collectAsState()
    val actions = rememberLibraryActions(repository)
    val scope = rememberCoroutineScope()
    var clearOpen by remember { mutableStateOf(false) }

    val recentTracks = remember(state.tracks, state.recents) {
        tracksForIds(state.tracks, state.recents, 10)
    }
    val recentAlbums = remember(state.albums) {
        recentlyAdded(state.albums, 12).filter { it.addedAt > 0 }.take(8)
    }
    val mostPlayed = remember(state.tracks, state.history) {
        topPlayedTracks(state.tracks, state.history, 8)
    }
    val mostPlayedTracks = remember(mostPlayed) { mostPlayed.map { it.track } }

    val title = "Your music"
    val status = libraryStatus(state.hasPermission, state.scanning, state.tracks.size)
    BindHeader(title, status, libraryHeaderActions(actions, state.hasPermission))

    SnoozyGridPage(
        contentPadding = contentPadding,
        headerEntry = headerEntry,
        title = title,
        subtitle = status,
    ) {
        if (state.error != null) {
            item(span = { GridItemSpan(maxLineSpan) }, key = "home-error") {
                SnoozyErrorBanner(state.error.orEmpty()) { repository.clearError() }
            }
        }
        if (playbackState.error != null) {
            item(span = { GridItemSpan(maxLineSpan) }, key = "home-playback-error") {
                SnoozyErrorBanner(playbackState.error.orEmpty()) { playbackController.clearError() }
            }
        }

        when {
            !state.hasPermission -> item(span = { GridItemSpan(maxLineSpan) }, key = "home-permission") {
                SnoozyPermissionEmpty(actions)
            }

            state.tracks.isEmpty() && state.scanning -> item(
                span = { GridItemSpan(maxLineSpan) },
                key = "home-scanning",
            ) {
                SnoozyEmptyState(
                    icon = SnoozyIcons.Retry,
                    title = "Scanning…",
                    message = "Reading audio files on this device. This can take a moment for large libraries.",
                )
            }

            state.tracks.isEmpty() -> item(span = { GridItemSpan(maxLineSpan) }, key = "home-empty") {
                SnoozyScanEmpty(
                    actions = actions,
                    message = "Put MP3, FLAC, or other audio files in your Music folder, then scan. You can also import files with the button above.",
                )
            }

            else -> {
                item(span = { GridItemSpan(maxLineSpan) }, key = "home-recently-played-title") {
                    SnoozySectionHeader(
                        title = "Recently played",
                        actionLabel = if (recentTracks.isNotEmpty()) "Clear" else null,
                        onAction = if (recentTracks.isNotEmpty()) ({ clearOpen = true }) else null,
                    )
                }
                if (recentTracks.isEmpty()) {
                    item(span = { GridItemSpan(maxLineSpan) }, key = "home-recently-played-empty") {
                        Text(
                            text = "Nothing played yet. Play a song and it will appear here.",
                            style = IosTypography.subheadline,
                            color = LocalGlassColors.current.secondaryContent,
                            modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
                        )
                    }
                } else {
                    item(span = { GridItemSpan(maxLineSpan) }, key = "home-recently-played-cards") {
                        SnoozyCardRow {
                            items(recentTracks, key = { it.id }) { track ->
                                SnoozyMediaCard(
                                    title = track.title,
                                    subtitle = track.artist,
                                    artwork = track.artwork,
                                    contentDescription = "Play ${track.title}",
                                    onClick = { playbackController.playTrack(track, recentTracks) },
                                )
                            }
                        }
                    }
                }

                if (recentAlbums.isNotEmpty()) {
                    item(span = { GridItemSpan(maxLineSpan) }, key = "home-recently-added-title") {
                        SnoozySectionHeader(
                            title = "Recently added",
                            actionLabel = "Albums",
                            onAction = openLibraryAlbums,
                        )
                    }
                    item(span = { GridItemSpan(maxLineSpan) }, key = "home-recently-added-cards") {
                        SnoozyCardRow {
                            items(recentAlbums, key = { it.id }) { album ->
                                SnoozyMediaCard(
                                    title = album.title,
                                    subtitle = album.artist,
                                    artwork = album.artwork,
                                    contentDescription = "Open album ${album.title} by ${album.artist}",
                                    onClick = { openAlbum(album.id) },
                                )
                            }
                        }
                    }
                }

                if (mostPlayed.isNotEmpty()) {
                    item(span = { GridItemSpan(maxLineSpan) }, key = "home-most-played-title") {
                        SnoozySectionHeader("Most played")
                    }
                    item(span = { GridItemSpan(maxLineSpan) }, key = "home-most-played-cards") {
                        SnoozyCardRow {
                            items(mostPlayed, key = { it.track.id }) { played ->
                                SnoozyMediaCard(
                                    title = played.track.title,
                                    subtitle = countLabel(played.plays, "play", "plays"),
                                    artwork = played.track.artwork,
                                    contentDescription = "Play ${played.track.title}",
                                    onClick = {
                                        playbackController.playTrack(played.track, mostPlayedTracks)
                                    },
                                )
                            }
                        }
                    }
                }

                item(span = { GridItemSpan(maxLineSpan) }, key = "home-library-title") {
                    SnoozySectionHeader("Library")
                }
                item(span = { GridItemSpan(maxLineSpan) }, key = "home-shuffle-all") {
                    SnoozyGroupedRow(0, 1) {
                        GlasmioListRow(
                            title = "Shuffle all songs",
                            subtitle = "Play a random mix of " +
                                countLabel(state.tracks.size, "track", "tracks"),
                            leading = { SnoozyIconBadge(SnoozyIcons.Shuffle) },
                            trailing = {
                                Icon(
                                    imageVector = SnoozyIcons.Play,
                                    contentDescription = null,
                                    tint = LocalGlassColors.current.secondaryContent,
                                    modifier = Modifier.size(18.dp),
                                )
                            },
                            showDisclosure = false,
                            modifier = Modifier.semantics {
                                contentDescription = "Shuffle all songs"
                            },
                            onClick = {
                                val shuffled = state.tracks.shuffled()
                                if (shuffled.isNotEmpty()) {
                                    playbackController.playTrack(
                                        track = shuffled.first(),
                                        queue = shuffled,
                                        shuffleOverride = true,
                                    )
                                }
                            },
                        )
                    }
                }
            }
        }
    }

    if (clearOpen) {
        GlasmioAlertDialog(
            onDismissRequest = { clearOpen = false },
            title = "Clear recently played?",
            message = "Your play history will be emptied.",
            buttonLayout = GlasmioAlertButtonLayout.SideBySide,
            buttons = listOf(
                GlasmioAlertButtonSpec(
                    label = "Cancel",
                    onClick = { clearOpen = false },
                    role = GlasmioAlertButtonRole.Cancel,
                ),
                GlasmioAlertButtonSpec(
                    label = "Clear",
                    onClick = {
                        clearOpen = false
                        scope.launch { repository.clearRecents() }
                    },
                    role = GlasmioAlertButtonRole.Destructive,
                ),
            ),
        )
    }
}

@Composable
private fun SnoozyCardRow(content: LazyListScope.() -> Unit) {
    LazyRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        contentPadding = PaddingValues(horizontal = 4.dp),
        content = content,
    )
}
