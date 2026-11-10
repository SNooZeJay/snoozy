package com.snoozy.app

import android.Manifest
import android.content.res.Configuration
import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import com.snoozy.app.ui.icons.SnoozyIconResolver
import com.snoozy.app.ui.navigation.SnoozyApp
import com.snoozy.app.ui.theme.SnoozyTheme
import io.github.neoruaa.glasmio.icons.GlasmioIconProvider

class MainActivity : ComponentActivity() {
    private val audioPermission = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) (application as SnoozyApplication).container.start()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (!(application as SnoozyApplication).container.repository.hasAudioPermission()) {
            audioPermission.launch(Manifest.permission.READ_MEDIA_AUDIO)
        }
        val dark = (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        val transparent = Color.TRANSPARENT
        enableEdgeToEdge(
            statusBarStyle = if (dark) {
                SystemBarStyle.dark(transparent)
            } else {
                SystemBarStyle.light(transparent, transparent)
            },
            navigationBarStyle = if (dark) {
                SystemBarStyle.dark(transparent)
            } else {
                SystemBarStyle.light(transparent, transparent)
            },
        )
        setContent {
            SnoozyTheme {
                GlasmioIconProvider(resolver = SnoozyIconResolver) {
                    SnoozyApp(onExit = ::finish)
                }
            }
        }
    }
}
