package com.snoozy.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.max
import coil3.compose.AsyncImage
import com.kyant.capsule.ContinuousRoundedRectangle
import com.snoozy.app.ui.icons.SnoozyIcons
import io.github.neoruaa.glasmio.core.LocalGlassColors

@Composable
fun SnoozyArtwork(
    uri: String?,
    size: Dp?,
    corner: Dp,
    contentDescription: String?,
    modifier: Modifier = Modifier,
) {
    val colors = LocalGlassColors.current
    val sized = if (size != null) modifier.size(size) else modifier
    Box(
        modifier = sized
            .clip(ContinuousRoundedRectangle(corner))
            .background(colors.elevatedBackground),
        contentAlignment = Alignment.Center,
    ) {
        if (uri.isNullOrBlank()) {
            Icon(
                imageVector = SnoozyIcons.Music,
                contentDescription = contentDescription,
                tint = colors.tertiaryContent,
                modifier = Modifier.size(size?.times(0.36f) ?: 48.dp),
            )
        } else {
            AsyncImage(
                model = uri,
                contentDescription = contentDescription,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        }
    }
}

fun distinctArtworkUris(artworks: List<String?>): List<String> =
    artworks.filterNotNull().filter { it.isNotBlank() }.distinct().take(4)

@Composable
fun SnoozyPlaylistCover(artworks: List<String?>, size: Dp, corner: Dp) {
    val uris = distinctArtworkUris(artworks)
    when (uris.size) {
        0 -> SnoozyArtwork(null, size, corner, null)
        1 -> SnoozyArtwork(uris.first(), size, corner, null)
        else -> {
            val colors = LocalGlassColors.current
            val gap = max(2.dp, size * 0.012f)
            val cell = (size - gap) / 2
            Column(
                modifier = Modifier
                    .size(size)
                    .clip(ContinuousRoundedRectangle(corner))
                    .background(colors.elevatedBackground),
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                    PlaylistCoverCell(uris.getOrNull(0), cell)
                    PlaylistCoverCell(uris.getOrNull(1), cell)
                }
                Spacer(Modifier.height(gap))
                Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                    PlaylistCoverCell(uris.getOrNull(2), cell)
                    PlaylistCoverCell(uris.getOrNull(3), cell)
                }
            }
        }
    }
}

@Composable
private fun PlaylistCoverCell(uri: String?, cell: Dp) {
    if (uri == null) {
        val colors = LocalGlassColors.current
        Box(
            modifier = Modifier.size(cell).background(colors.elevatedBackground),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = SnoozyIcons.Music,
                contentDescription = null,
                tint = colors.tertiaryContent,
                modifier = Modifier.size(cell * 0.34f),
            )
        }
    } else {
        SnoozyArtwork(uri, cell, 0.dp, null)
    }
}
