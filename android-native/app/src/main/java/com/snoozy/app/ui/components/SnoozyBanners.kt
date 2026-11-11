package com.snoozy.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import com.kyant.capsule.ContinuousRoundedRectangle
import com.snoozy.app.ui.icons.SnoozyIcons
import io.github.neoruaa.glasmio.core.IosTypography
import io.github.neoruaa.glasmio.core.LocalGlassColors

@Composable
fun SnoozyErrorBanner(message: String, onDismiss: () -> Unit) {
    val colors = LocalGlassColors.current
    Row(
        modifier = Modifier.fillMaxWidth()
            .padding(top = 8.dp)
            .clip(ContinuousRoundedRectangle(16.dp))
            .background(colors.elevatedBackground)
            .padding(start = 12.dp, top = 8.dp, bottom = 8.dp, end = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = SnoozyIcons.Warning,
            contentDescription = null,
            tint = colors.destructive,
            modifier = Modifier.size(18.dp),
        )
        Text(
            text = message,
            style = IosTypography.subheadline,
            color = colors.destructive,
            modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
        )
        Box(
            modifier = Modifier
                .size(44.dp)
                .clickable(
                    role = Role.Button,
                    onClickLabel = "Dismiss error",
                    onClick = onDismiss,
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = SnoozyIcons.Close,
                contentDescription = null,
                tint = colors.destructive,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}
