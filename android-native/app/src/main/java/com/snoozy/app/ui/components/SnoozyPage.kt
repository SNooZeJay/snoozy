package com.snoozy.app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridScope
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.blur
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import io.github.neoruaa.glasmio.core.IosPageHorizontalPadding
import io.github.neoruaa.glasmio.core.IosTypography
import io.github.neoruaa.glasmio.core.LocalGlassColors
import io.github.neoruaa.glasmio.glass.GlasmioBackdropHost
import io.github.neoruaa.glasmio.scaffold.GlasmioHeaderScrollState
import io.github.neoruaa.glasmio.scaffold.GlasmioPageBody
import io.github.neoruaa.glasmio.scaffold.rememberGlasmioHeaderCollapse
import io.github.neoruaa.glasmio.scaffold.rememberGlasmioHeaderScrollEdge
import io.github.neoruaa.glasmio.ui.GlasmioButton
import io.github.neoruaa.glasmio.ui.GlasmioButtonSize
import io.github.neoruaa.glasmio.ui.NavigationBarSurfaceHeight
import com.snoozy.app.ui.navigation.NavHeaderEntry

/**
 * A Glasmio page body plus one lazy grid. Single column pages and the two column
 * album grid share the same collapsing title and scroll edge behavior.
 */
@Composable
fun SnoozyGridPage(
    contentPadding: PaddingValues,
    headerEntry: NavHeaderEntry,
    title: String,
    subtitle: String?,
    columns: Int = 1,
    content: LazyGridScope.() -> Unit,
) {
    val gridState = rememberLazyGridState()
    val collapse = rememberGlasmioHeaderCollapse(gridState)
    val currentCollapse = rememberUpdatedState(collapse)
    val scroll = remember { GlasmioHeaderScrollState({ currentCollapse.value }) }
    SideEffect { headerEntry.scroll = scroll }

    val edgeProgress = rememberGlasmioHeaderScrollEdge(gridState)
    val navigationInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val padding = PaddingValues(
        start = IosPageHorizontalPadding,
        top = contentPadding.calculateTopPadding(),
        end = IosPageHorizontalPadding,
        bottom = contentPadding.calculateBottomPadding() + NavigationBarSurfaceHeight + 32.dp + navigationInset,
    )

    GlasmioPageBody(contentPadding = padding, topBarBlurProgress = edgeProgress) { bodyPadding ->
        GlasmioBackdropHost(
            modifier = Modifier.fillMaxSize(),
            sampledContent = {
                Box(
                    Modifier
                        .fillMaxSize()
                        .background(LocalGlassColors.current.groupedBackground),
                )
            },
        ) {
            LazyVerticalGrid(
                columns = GridCells.Fixed(columns),
                state = gridState,
                modifier = Modifier.fillMaxWidth(),
                contentPadding = bodyPadding,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item(span = { GridItemSpan(maxLineSpan) }, key = "snoozy-page-title") {
                    SnoozyLargeTitle(title, subtitle, collapse)
                }
                content()
            }
        }
    }
}

@Composable
fun SnoozyLargeTitle(title: String, subtitle: String?, collapseProgress: Float) {
    Column(
        modifier = Modifier.fillMaxWidth()
            .graphicsLayer {
                alpha = 1f - collapseProgress
                scaleX = 1f - 0.04f * collapseProgress
                scaleY = scaleX
                transformOrigin = TransformOrigin(0f, 0.5f)
            }
            .blur(6.dp * collapseProgress)
            .offset(y = (-10).dp)
            .padding(horizontal = 4.dp, vertical = 6.dp),
    ) {
        Text(
            text = title,
            style = IosTypography.largeTitle,
            fontWeight = FontWeight.Bold,
        )
        if (!subtitle.isNullOrBlank()) {
            Text(
                text = subtitle,
                style = IosTypography.subheadline,
                color = LocalGlassColors.current.secondaryContent,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}

@Composable
fun SnoozySectionHeader(
    title: String,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(start = 4.dp, top = 20.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            style = IosTypography.body.copy(fontWeight = FontWeight.SemiBold),
            color = LocalGlassColors.current.secondaryContent,
            modifier = Modifier.weight(1f),
        )
        if (actionLabel != null && onAction != null) {
            GlasmioButton(
                onClick = onAction,
                size = GlasmioButtonSize.Small,
                modifier = Modifier.heightIn(min = 44.dp),
            ) {
                Text(actionLabel)
            }
        }
    }
}
