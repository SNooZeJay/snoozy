package com.snoozy.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
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
