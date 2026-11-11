package com.snoozy.app.ui.navigation

import com.snoozy.app.data.library.LibraryRepository
import androidx.compose.runtime.staticCompositionLocalOf

val LocalLibraryRepository = staticCompositionLocalOf<LibraryRepository> {
    error("Missing LibraryRepository")
}
