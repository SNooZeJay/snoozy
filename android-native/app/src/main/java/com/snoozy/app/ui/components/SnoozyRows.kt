package com.snoozy.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.snoozy.app.data.model.Album
import com.snoozy.app.data.model.Track
import com.snoozy.app.ui.format.formatClock
import com.snoozy.app.ui.icons.SnoozyIcons
import io.github.neoruaa.glasmio.core.IosTypography
import io.github.neoruaa.glasmio.core.LocalGlassColors
import io.github.neoruaa.glasmio.ui.GlasmioListRow
import io.github.neoruaa.glasmio.ui.glasmioGroupedListBackground

/** Grouped-cell material for one virtualized row with correct first and last corners. */
@Composable
fun SnoozyGroupedRow(index: Int, count: Int, content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .glasmioGroupedListBackground(groupedRowShape(groupedRowPosition(index, count))),
    ) {
        content()
    }
}

@Composable
fun SnoozyTrackRow(
    track: Track,
    subtitle: String,
    onClick: (() -> Unit)?,
    showTopSeparator: Boolean = false,
) {
    GlasmioListRow(
        title = track.title,
        subtitle = subtitle,
        detail = formatClock(track.duration),
        leading = { SnoozyArtwork(track.artwork, 44.dp, 10.dp, null) },
        onClick = onClick,
        showTopSeparator = showTopSeparator,
    )
}

@Composable
fun SnoozyAlbumRow(
    album: Album,
    onClick: () -> Unit,
    showTopSeparator: Boolean = false,
) {
    GlasmioListRow(
        title = album.title,
        subtitle = album.artist,
        detail = album.year,
        leading = { SnoozyArtwork(album.artwork, 44.dp, 10.dp, null) },
        onClick = onClick,
        showTopSeparator = showTopSeparator,
    )
}

@Composable
fun SnoozyArtistRow(name: String, onClick: () -> Unit, showTopSeparator: Boolean = false) {
    GlasmioListRow(
        title = name,
        leading = { SnoozyIconBadge(SnoozyIcons.Person) },
        onClick = onClick,
        showTopSeparator = showTopSeparator,
    )
}

@Composable
fun SnoozyGenreRow(name: String, onClick: () -> Unit, showTopSeparator: Boolean = false) {
    GlasmioListRow(
        title = name,
        leading = { SnoozyIconBadge(SnoozyIcons.Layers) },
        onClick = onClick,
        showTopSeparator = showTopSeparator,
    )
}

@Composable
fun SnoozyIconBadge(icon: ImageVector, size: androidx.compose.ui.unit.Dp = 44.dp) {
    val colors = LocalGlassColors.current
    Box(
        modifier = Modifier.size(size).clip(CircleShape).background(colors.elevatedBackground),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = colors.accent,
            modifier = Modifier.size(20.dp),
        )
    }
}

@Composable
fun SnoozyMediaCard(
    title: String,
    subtitle: String,
    artwork: String?,
    contentDescription: String,
    onClick: () -> Unit,
) {
    val colors = LocalGlassColors.current
    Column(
        modifier = Modifier
            .width(148.dp)
            .clickable(role = Role.Button, onClickLabel = contentDescription, onClick = onClick)
            .semantics { this.contentDescription = contentDescription },
    ) {
        SnoozyArtwork(artwork, 148.dp, 20.dp, null)
        Text(
            text = title,
            style = IosTypography.body.copy(fontWeight = FontWeight.SemiBold),
            color = colors.content,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 8.dp),
        )
        Text(
            text = subtitle,
            style = IosTypography.footnote,
            color = colors.secondaryContent,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 2.dp),
        )
    }
}

@Composable
fun SnoozyAlbumTile(album: Album, onClick: () -> Unit) {
    val colors = LocalGlassColors.current
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(
                role = Role.Button,
                onClickLabel = "Open album ${album.title}",
                onClick = onClick,
            )
            .semantics {
                contentDescription = "Open album ${album.title} by ${album.artist}"
            },
    ) {
        SnoozyArtwork(
            uri = album.artwork,
            size = null,
            corner = 18.dp,
            contentDescription = null,
            modifier = Modifier.fillMaxWidth().aspectRatio(1f),
        )
        Text(
            text = album.title,
            style = IosTypography.body.copy(fontWeight = FontWeight.SemiBold),
            color = colors.content,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 8.dp),
        )
        Text(
            text = album.artist,
            style = IosTypography.footnote,
            color = colors.secondaryContent,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 2.dp, bottom = 8.dp),
        )
    }
}
