package com.snoozy.app

import android.content.res.Configuration
import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.snoozy.app.ui.icons.SnoozyIconResolver
import com.snoozy.app.ui.navigation.SnoozyApp
import com.snoozy.app.ui.theme.SnoozyTheme
import io.github.neoruaa.glasmio.icons.GlasmioIconProvider

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
