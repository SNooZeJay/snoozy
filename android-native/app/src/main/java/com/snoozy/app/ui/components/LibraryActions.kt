package com.snoozy.app.ui.components

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.platform.LocalContext
import com.snoozy.app.data.library.LibraryRepository
import kotlinx.coroutines.launch

class LibraryActions(
    val requestPermission: () -> Unit,
    val openSettings: () -> Unit,
    val importSongs: () -> Unit,
    val scan: () -> Unit,
)

/** Permission, settings, import, and scan callbacks shared by Home and Library. */
@Composable
fun rememberLibraryActions(repository: LibraryRepository): LibraryActions {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) scope.launch { repository.refresh() }
    }
    val importLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenMultipleDocuments(),
    ) { uris ->
        if (uris.isNotEmpty()) scope.launch { repository.importDocuments(uris) }
    }

    return remember(repository, context, scope) {
        LibraryActions(
            requestPermission = {
                permissionLauncher.launch(Manifest.permission.READ_MEDIA_AUDIO)
            },
            openSettings = {
                context.startActivity(
                    Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", context.packageName, null),
                    ),
                )
            },
            importSongs = { importLauncher.launch(arrayOf("audio/*")) },
            scan = { scope.launch { repository.refresh(scan = true) } },
        )
    }
}
