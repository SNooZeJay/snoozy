package com.snoozy.app.ui.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.snoozy.app.ui.icons.SnoozyIcons
import io.github.neoruaa.glasmio.glass.GlassEmphasis
import io.github.neoruaa.glasmio.ui.GlasmioButton

@Composable
fun SnoozyPermissionEmpty(actions: LibraryActions) {
    SnoozyEmptyState(
        icon = SnoozyIcons.Library,
        title = "Permission needed",
        message = "Snoozy needs access to audio files on this device to build your library.",
        action = {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                GlasmioButton(
                    onClick = actions.requestPermission,
                    emphasis = GlassEmphasis.Prominent,
                ) {
                    Text("Grant access")
                }
                Spacer(Modifier.height(8.dp))
                GlasmioButton(onClick = actions.openSettings) {
                    Text("Open settings")
                }
            }
        },
    )
}

@Composable
fun SnoozyScanEmpty(actions: LibraryActions, message: String) {
    SnoozyEmptyState(
        icon = SnoozyIcons.Music,
        title = "No audio found",
        message = message,
        action = {
            GlasmioButton(onClick = actions.scan) { Text("Scan your device") }
        },
    )
}
