package com.snoozy.app.ui.icons

import androidx.compose.ui.graphics.vector.ImageVector
import compose.icons.FeatherIcons
import compose.icons.feathericons.Activity
import compose.icons.feathericons.AlertTriangle
import compose.icons.feathericons.BookOpen
import compose.icons.feathericons.Check
import compose.icons.feathericons.ChevronLeft
import compose.icons.feathericons.Clock
import compose.icons.feathericons.Cloud
import compose.icons.feathericons.Compass
import compose.icons.feathericons.Download
import compose.icons.feathericons.Edit3
import compose.icons.feathericons.FastForward
import compose.icons.feathericons.Grid
import compose.icons.feathericons.Heart
import compose.icons.feathericons.Home
import compose.icons.feathericons.Info
import compose.icons.feathericons.Layers
import compose.icons.feathericons.List
import compose.icons.feathericons.Mic
import compose.icons.feathericons.MoreHorizontal
import compose.icons.feathericons.Music
import compose.icons.feathericons.Pause
import compose.icons.feathericons.Play
import compose.icons.feathericons.Plus
import compose.icons.feathericons.Repeat
import compose.icons.feathericons.RotateCw
import compose.icons.feathericons.Search
import compose.icons.feathericons.Settings
import compose.icons.feathericons.Shuffle
import compose.icons.feathericons.SkipBack
import compose.icons.feathericons.SkipForward
import compose.icons.feathericons.Star
import compose.icons.feathericons.Trash2
import compose.icons.feathericons.User
import compose.icons.feathericons.X
import io.github.neoruaa.glasmio.icons.GlasmioIconResolver

object SnoozyIcons {
    val Home: ImageVector = FeatherIcons.Home
    val Search: ImageVector = FeatherIcons.Search
    val Library: ImageVector = FeatherIcons.LibraryOrBookOpen
    val Playlists: ImageVector = FeatherIcons.List
    val Settings: ImageVector = FeatherIcons.Settings
    val Music: ImageVector = FeatherIcons.Music
    val Back: ImageVector = FeatherIcons.ChevronLeft
    val Heart: ImageVector = FeatherIcons.Heart
    val More: ImageVector = FeatherIcons.MoreHorizontal
    val Close: ImageVector = FeatherIcons.X
    val Warning: ImageVector = FeatherIcons.AlertTriangle
    val Retry: ImageVector = FeatherIcons.RotateCw
    val Info: ImageVector = FeatherIcons.Info
    val Play: ImageVector = FeatherIcons.Play
    val Pause: ImageVector = FeatherIcons.Pause
    val Next: ImageVector = FeatherIcons.SkipForward
    val Previous: ImageVector = FeatherIcons.SkipBack
    val Shuffle: ImageVector = FeatherIcons.Shuffle
    val Repeat: ImageVector = FeatherIcons.Repeat
    val FastForward: ImageVector = FeatherIcons.FastForward
    val Star: ImageVector = FeatherIcons.Star
    val Clock: ImageVector = FeatherIcons.Clock
    val Activity: ImageVector = FeatherIcons.Activity
    val Microphone: ImageVector = FeatherIcons.Mic
    val Compass: ImageVector = FeatherIcons.Compass
    val Person: ImageVector = FeatherIcons.User
    val Download: ImageVector = FeatherIcons.Download
    val Cloud: ImageVector = FeatherIcons.Cloud
    val Layers: ImageVector = FeatherIcons.Layers
    val Plus: ImageVector = FeatherIcons.Plus
    val Check: ImageVector = FeatherIcons.Check
    val Trash: ImageVector = FeatherIcons.Trash2
    val Edit: ImageVector = FeatherIcons.Edit3
    val Grid: ImageVector = FeatherIcons.Grid
}

private val FeatherIcons.LibraryOrBookOpen: ImageVector
    get() = BookOpen

/** Maps Glasmio's semantic system names onto Feather so no SF Symbol asset ships. */
object SnoozyIconResolver : GlasmioIconResolver {
    override fun resolve(systemName: String): ImageVector? = when {
        systemName.startsWith("house") -> SnoozyIcons.Home
        systemName.startsWith("magnifyingglass") -> SnoozyIcons.Search
        systemName.startsWith("square.3.layers") || systemName.startsWith("square.stack") -> SnoozyIcons.Library
        systemName.startsWith("music.note.list") -> SnoozyIcons.Playlists
        systemName.startsWith("music.note") || systemName == "waveform" -> SnoozyIcons.Music
        systemName.startsWith("gear") -> SnoozyIcons.Settings
        systemName.startsWith("chevron.left") || systemName.startsWith("chevron.backward") -> SnoozyIcons.Back
        systemName.startsWith("heart") -> SnoozyIcons.Heart
        systemName.startsWith("ellipsis") -> SnoozyIcons.More
        systemName.startsWith("xmark") -> SnoozyIcons.Close
        systemName.startsWith("exclamationmark") -> SnoozyIcons.Warning
        systemName.startsWith("arrow.clockwise") || systemName.startsWith("arrow.triangle") -> SnoozyIcons.Retry
        systemName.startsWith("info") -> SnoozyIcons.Info
        systemName.startsWith("play") -> SnoozyIcons.Play
        systemName.startsWith("pause") -> SnoozyIcons.Pause
        systemName.startsWith("forward") -> SnoozyIcons.Next
        systemName.startsWith("backward") -> SnoozyIcons.Previous
        systemName.startsWith("shuffle") -> SnoozyIcons.Shuffle
        systemName.startsWith("repeat") -> SnoozyIcons.Repeat
        systemName.startsWith("star") -> SnoozyIcons.Star
        systemName.startsWith("clock") -> SnoozyIcons.Clock
        systemName.startsWith("mic") -> SnoozyIcons.Microphone
        systemName.startsWith("safari") -> SnoozyIcons.Compass
        systemName.startsWith("person") -> SnoozyIcons.Person
        systemName.startsWith("arrow.down") -> SnoozyIcons.Download
        systemName.startsWith("icloud") || systemName.startsWith("cloud") -> SnoozyIcons.Cloud
        systemName.startsWith("plus") -> SnoozyIcons.Plus
        systemName.startsWith("checkmark") -> SnoozyIcons.Check
        systemName.startsWith("trash") -> SnoozyIcons.Trash
        systemName.startsWith("pencil") -> SnoozyIcons.Edit
        else -> null
    }
}
