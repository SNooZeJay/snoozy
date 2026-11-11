package com.snoozy.app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.snoozy.app.data.model.Playlist
import com.snoozy.app.data.model.Track
import com.snoozy.app.ui.format.countLabel
import com.snoozy.app.ui.icons.SnoozyIcons
import io.github.neoruaa.glasmio.core.IosTypography
import io.github.neoruaa.glasmio.core.LocalGlassColors
import io.github.neoruaa.glasmio.glass.GlassEmphasis
import io.github.neoruaa.glasmio.ui.GlasmioBottomSheet
import io.github.neoruaa.glasmio.ui.GlasmioButton
import io.github.neoruaa.glasmio.ui.GlasmioListRow
import io.github.neoruaa.glasmio.ui.GlasmioTextField
import kotlinx.coroutines.launch

@Composable
fun AddToPlaylistSheet(
    track: Track,
    playlists: List<Playlist>,
    onAddToPlaylist: (playlistId: String) -> Unit,
    onCreateAndAdd: suspend (name: String) -> String?,
    onDismiss: () -> Unit,
) {
    val colors = LocalGlassColors.current
    val scope = rememberCoroutineScope()
    var newName by rememberSaveable { mutableStateOf("") }
    var addedPlaylistIds by remember(track.id) { mutableStateOf(emptySet<String>()) }
    val bottomInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

    val submitCreate: () -> Unit = {
        val trimmed = newName.trim()
        if (trimmed.isNotEmpty()) {
            newName = ""
            scope.launch {
                val createdId = onCreateAndAdd(trimmed)
                if (!createdId.isNullOrBlank()) {
                    addedPlaylistIds = addedPlaylistIds + createdId
                }
            }
        }
    }

    GlasmioBottomSheet(
        visible = true,
        fitContent = true,
        onDismissRequest = onDismiss,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 16.dp, end = 16.dp, top = 4.dp, bottom = bottomInset + 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "Add to playlist",
                        style = IosTypography.headline,
                        color = colors.content,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        text = "\u201C${track.title}\u201D",
                        style = IosTypography.footnote,
                        color = colors.secondaryContent,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                SnoozyIconAction(SnoozyIcons.Close, "Close", onDismiss)
            }

            if (playlists.isEmpty()) {
                Text(
                    text = "No playlists yet. Create one below.",
                    style = IosTypography.subheadline,
                    color = colors.secondaryContent,
                    modifier = Modifier.padding(vertical = 8.dp),
                )
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = 280.dp),
                ) {
                    itemsIndexed(playlists, key = { _, playlist -> playlist.id }) { index, playlist ->
                        val isAdded = playlist.id in addedPlaylistIds || track.id in playlist.trackIds
                        val subtitle = if (isAdded) {
                            "Added"
                        } else {
                            countLabel(playlist.trackIds.size, "track", "tracks")
                        }
                        SnoozyGroupedRow(index, playlists.size) {
                            GlasmioListRow(
                                title = playlist.name,
                                subtitle = subtitle,
                                showDisclosure = false,
                                modifier = Modifier.semantics(mergeDescendants = true) {
                                    contentDescription = if (isAdded) {
                                        "Added to ${playlist.name}"
                                    } else {
                                        "Add to ${playlist.name}"
                                    }
                                },
                                onClick = if (isAdded) {
                                    null
                                } else {
                                    {
                                        onAddToPlaylist(playlist.id)
                                        addedPlaylistIds = addedPlaylistIds + playlist.id
                                    }
                                },
                                leading = {
                                    Icon(
                                        imageVector = if (isAdded) SnoozyIcons.Check else SnoozyIcons.Plus,
                                        contentDescription = null,
                                        tint = if (isAdded) colors.accent else colors.secondaryContent,
                                        modifier = Modifier.size(20.dp),
                                    )
                                },
                                showTopSeparator = index > 0,
                            )
                        }
                    }
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                GlasmioTextField(
                    value = newName,
                    onValueChange = { newName = it },
                    modifier = Modifier.weight(1f),
                    placeholder = "New playlist name",
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { submitCreate() }),
                )
                GlasmioButton(
                    onClick = submitCreate,
                    enabled = newName.trim().isNotEmpty(),
                    emphasis = GlassEmphasis.Prominent,
                    modifier = Modifier.heightIn(min = 44.dp),
                ) {
                    Text("Create")
                }
            }
        }
    }
}
