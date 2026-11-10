package com.snoozy.app.ui.navigation

sealed interface NavKey {
    val route: String
    val title: String
    val pageTitle: String get() = title
    val description: String

    val isRoot: Boolean
        get() = this == Home || this == Search || this == Library || this == Playlists || this == Settings

    data object Home : NavKey {
        override val route = "home"
        override val title = "Home"
        override val pageTitle = "Your music"
        override val description = "The library overview arrives once scanning and the existing stores are wired."
    }

    data object Search : NavKey {
        override val route = "search"
        override val title = "Search"
        override val description = "Search across songs, albums, artists, and genres arrives with the library."
    }

    data object Library : NavKey {
        override val route = "library"
        override val title = "Library"
        override val description = "Songs, albums, artists, genres, and favorites arrive with the library."
    }

    data object Playlists : NavKey {
        override val route = "playlists"
        override val title = "Playlists"
        override val description = "Playlists, favorites, and queue editing arrive with the library."
    }

    data object Settings : NavKey {
        override val route = "settings"
        override val title = "Settings"
        override val description = "Theme, motion, glass, and diagnostics arrive after playback."
    }

    companion object {
        // Lazy: eagerly building this list during companion init can capture the nested
        // object still being class-initialized as null.
        val roots: List<NavKey> get() = listOf(Home, Search, Library, Playlists, Settings)

        fun fromRoute(route: String): NavKey = when (route) {
            Home.route -> Home
            Search.route -> Search
            Library.route -> Library
            Playlists.route -> Playlists
            Settings.route -> Settings
            else -> Home
        }
    }
}
