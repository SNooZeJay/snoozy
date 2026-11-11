package com.snoozy.app.ui.components

import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.snoozy.app.ui.icons.SnoozyIcons
import io.github.neoruaa.glasmio.scaffold.GlasmioHeaderAction

@Composable
fun libraryHeaderActions(
    actions: LibraryActions,
    canImport: Boolean,
): List<GlasmioHeaderAction> = remember(actions, canImport) {
    buildList {
        if (canImport) {
            add(
                GlasmioHeaderAction(
                    key = "import",
                    visualKey = "import",
                    contentDescription = "Import songs",
                    onClick = actions.importSongs,
                ) {
                    Icon(SnoozyIcons.Download, null, Modifier.size(20.dp))
                },
            )
        }
        add(
            GlasmioHeaderAction(
                key = "scan",
                visualKey = "scan",
                contentDescription = "Scan library",
                onClick = actions.scan,
            ) {
                Icon(SnoozyIcons.Retry, null, Modifier.size(20.dp))
            },
        )
    }
}
