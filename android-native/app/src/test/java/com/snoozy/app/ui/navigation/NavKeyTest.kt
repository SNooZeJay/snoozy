package com.snoozy.app.ui.navigation

import org.junit.Assert.assertEquals
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
}
