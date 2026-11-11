package com.snoozy.app.ui.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.snoozy.app.data.library.PlaylistOps
import com.snoozy.app.data.model.Track
import com.snoozy.app.ui.format.countLabel
import com.snoozy.app.ui.icons.SnoozyIcons
import io.github.neoruaa.glasmio.core.IosTypography
import io.github.neoruaa.glasmio.core.LocalGlassColors
import io.github.neoruaa.glasmio.ui.GlasmioBottomSheet
import io.github.neoruaa.glasmio.ui.GlasmioListRow
import io.github.neoruaa.glasmio.ui.GlasmioTextField

@Composable
fun AddSongsSheet(
    playlistName: String,
    trackIds: Set<String>,
    tracks: List<Track>,
    onAdd: (String) -> Unit,
    onRemove: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    val colors = LocalGlassColors.current
    var filter by rememberSaveable { mutableStateOf("") }
    val visibleTracks = remember(tracks, filter) {
        tracks.filter { PlaylistOps.matches(it, filter) }
    }
    val bottomInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

    GlasmioBottomSheet(
        visible = true,
        onDismissRequest = onDismiss,
    ) {
        Column(Modifier.fillMaxWidth().weight(1f)) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 16.dp, end = 8.dp, top = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text(
                        text = "Add songs",
                        style = IosTypography.headline,
                        color = colors.content,
                    )
                    Text(
                        text = "\u201C$playlistName\u201D \u00B7 " +
                            countLabel(trackIds.size, "track", "tracks"),
                        style = IosTypography.footnote,
                        color = colors.secondaryContent,
                    )
                }
                SnoozyIconAction(SnoozyIcons.Close, "Close", onDismiss)
            }

            GlasmioTextField(
                value = filter,
                onValueChange = { filter = it },
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                placeholder = "Filter songs",
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            )

            when {
                tracks.isEmpty() -> SheetMessage(
                    text = "No songs in the library yet. Scan your Music folder first.",
                )

                visibleTracks.isEmpty() -> SheetMessage(
                    text = "No songs match \u201C$filter\u201D.",
                )

                else -> LazyColumn(
                    modifier = Modifier.fillMaxWidth().weight(1f),
                    contentPadding = PaddingValues(
                        start = 16.dp,
                        end = 16.dp,
                        top = 8.dp,
                        bottom = bottomInset + 24.dp,
                    ),
                ) {
                    itemsIndexed(visibleTracks, key = { _, track -> track.id }) { index, track ->
                        val added = track.id in trackIds
                        val description = if (added) {
                            "Remove ${track.title} from playlist"
                        } else {
                            "Add ${track.title} to playlist"
                        }
                        SnoozyGroupedRow(index, visibleTracks.size) {
                            GlasmioListRow(
                                title = track.title,
                                subtitle = track.artist,
                                modifier = Modifier.semantics(mergeDescendants = true) {
                                    contentDescription = description
                                },
                                onClick = {
                                    if (added) onRemove(track.id) else onAdd(track.id)
                                },
                                trailing = {
                                    Icon(
                                        imageVector = if (added) {
                                            SnoozyIcons.Check
                                        } else {
                                            SnoozyIcons.Plus
                                        },
                                        contentDescription = null,
                                        tint = if (added) colors.accent else colors.tertiaryContent,
                                        modifier = Modifier.size(20.dp),
                                    )
                                },
                                showTopSeparator = index > 0,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SheetMessage(text: String) {
    Text(
        text = text,
        style = IosTypography.subheadline,
        color = LocalGlassColors.current.secondaryContent,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 24.dp),
    )
}
