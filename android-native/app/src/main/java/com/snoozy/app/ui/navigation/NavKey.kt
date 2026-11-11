package com.snoozy.app.ui.navigation

import java.net.URLDecoder
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

fun encodeRouteArg(value: String): String =
    URLEncoder.encode(value, StandardCharsets.UTF_8)

fun decodeRouteArg(value: String): String =
    URLDecoder.decode(value, StandardCharsets.UTF_8)

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

    data class Album(val albumKey: String) : NavKey {
        override val route = "album/${encodeRouteArg(albumKey)}"
        override val title = "Album"
        override val description = "Tracks on this album."
    }

    data class Artist(val name: String) : NavKey {
        override val route = "artist/${encodeRouteArg(name)}"
        override val title = "Artist"
        override val description = "Songs and albums by this artist."
    }

    data class Genre(val name: String) : NavKey {
        override val route = "genre/${encodeRouteArg(name)}"
        override val title = "Genre"
        override val description = "Songs tagged with this genre."
    }

    companion object {
        private const val ALBUM_PREFIX = "album/"
        private const val ARTIST_PREFIX = "artist/"
        private const val GENRE_PREFIX = "genre/"

        // Lazy: eagerly building this list during companion init can capture the nested
        // object still being class-initialized as null.
        val roots: List<NavKey> get() = listOf(Home, Search, Library, Playlists, Settings)

        fun fromRoute(route: String): NavKey = when {
            route.startsWith(ALBUM_PREFIX) ->
                Album(decodeRouteArg(route.removePrefix(ALBUM_PREFIX)))
            route.startsWith(ARTIST_PREFIX) ->
                Artist(decodeRouteArg(route.removePrefix(ARTIST_PREFIX)))
            route.startsWith(GENRE_PREFIX) ->
                Genre(decodeRouteArg(route.removePrefix(GENRE_PREFIX)))
            route == Home.route -> Home
            route == Search.route -> Search
            route == Library.route -> Library
            route == Playlists.route -> Playlists
            route == Settings.route -> Settings
            else -> Home
        }
    }
}
