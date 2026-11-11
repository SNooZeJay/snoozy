package com.snoozy.app.ui.components

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.kyant.capsule.ContinuousRoundedRectangle
import com.snoozy.app.data.model.Track
import com.snoozy.app.ui.icons.SnoozyIcons
import io.github.neoruaa.glasmio.core.IosTypography
import io.github.neoruaa.glasmio.core.LocalGlassColors
import io.github.neoruaa.glasmio.ui.glasmioGroupedListBackground

val MiniPlayerBottomSpace = 76.dp

@Composable
fun SnoozyMiniPlayer(
    track: Track,
    isPlaying: Boolean,
    onTogglePlay: () -> Unit,
    onNext: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = LocalGlassColors.current
    val shape = ContinuousRoundedRectangle(20.dp)
    val playPauseLabel = if (isPlaying) "Pause" else "Play"

    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 64.dp)
            .clip(shape)
            .glasmioGroupedListBackground(shape)
            .border(width = 0.75.dp, color = colors.separator, shape = shape)
            .padding(start = 10.dp, end = 6.dp, top = 8.dp, bottom = 8.dp)
            .semantics {
                contentDescription = "Now playing: ${track.title} by ${track.artist}"
            },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SnoozyArtwork(
            uri = track.artwork,
            size = 44.dp,
            corner = 12.dp,
            contentDescription = null,
        )
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                text = track.title.ifBlank { "Untitled track" },
                style = IosTypography.body.copy(fontWeight = FontWeight.SemiBold),
                color = colors.content,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = track.artist.ifBlank { "Unknown artist" },
                style = IosTypography.footnote,
                color = colors.secondaryContent,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            SnoozyIconAction(
                icon = if (isPlaying) SnoozyIcons.Pause else SnoozyIcons.Play,
                label = playPauseLabel,
                onClick = onTogglePlay,
                tint = colors.content,
            )
            SnoozyIconAction(
                icon = SnoozyIcons.Next,
                label = "Next track",
                onClick = onNext,
                tint = colors.content,
            )
        }
    }
}
