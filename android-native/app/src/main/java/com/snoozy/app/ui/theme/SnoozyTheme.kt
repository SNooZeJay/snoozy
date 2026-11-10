package com.snoozy.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import io.github.neoruaa.glasmio.core.GlassAppearance
import io.github.neoruaa.glasmio.core.GlasmioTheme
import io.github.neoruaa.glasmio.core.defaultGlassColors
import io.github.neoruaa.glasmio.core.glasmioColorScheme

@Composable
fun SnoozyTheme(
    reduceTransparency: Boolean = true,
    content: @Composable () -> Unit,
) {
    val isDark = isSystemInDarkTheme()
    val accent = if (isDark) SnoozyColors.accent else SnoozyColors.accentStrong
    val typography = remember { snoozyTypography() }
    val glassColors = remember(isDark, accent) {
        defaultGlassColors(isDark, accent).copy(destructive = SnoozyColors.danger)
    }

    GlasmioTheme(
        isDark = isDark,
        colorScheme = glasmioColorScheme(isDark, accent),
        typography = typography,
        colors = glassColors,
        appearance = GlassAppearance(reduceTransparency = reduceTransparency),
        content = content,
    )
}
