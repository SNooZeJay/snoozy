package com.snoozy.app.ui.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class NavKeyTest {
    @Test
    fun everyRootResolvesFromItsRoute() {
        assertEquals(NavKey.Home, NavKey.fromRoute(NavKey.Home.route))
        assertEquals(NavKey.Search, NavKey.fromRoute(NavKey.Search.route))
        assertEquals(NavKey.Library, NavKey.fromRoute(NavKey.Library.route))
        assertEquals(NavKey.Playlists, NavKey.fromRoute(NavKey.Playlists.route))
        assertEquals(NavKey.Settings, NavKey.fromRoute(NavKey.Settings.route))
        assertEquals(NavKey.Home, NavKey.fromRoute("unknown"))
        assertEquals(5, NavKey.roots.size)
    }

    @Test
    fun detailRoutesRoundTripAwkwardNames() {
        val names = listOf("Sigur Rós", "AC/DC", "100% #1 ?", "  spaced  ", "五十音")
        for (name in names) {
            assertEquals(NavKey.Album(name), NavKey.fromRoute(NavKey.Album(name).route))
            assertEquals(NavKey.Artist(name), NavKey.fromRoute(NavKey.Artist(name).route))
            assertEquals(NavKey.Genre(name), NavKey.fromRoute(NavKey.Genre(name).route))
        }
    }

    @Test
    fun detailRoutesAreNotRoots() {
        assertFalse(NavKey.Album("a").isRoot)
        assertFalse(NavKey.Artist("a").isRoot)
        assertFalse(NavKey.Genre("a").isRoot)
    }
}
