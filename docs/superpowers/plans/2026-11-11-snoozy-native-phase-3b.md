# Snoozy Native Phase 3B: Playlists and History Writes

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Playlists placeholder with a working playlist list and playlist detail that create, rename, delete, add, remove, and reorder songs through the preserved MMKV store, and add the Home clear-history action that writes the preserved SQLite files.

**Architecture:** Pure playlist transforms live in `data/library/PlaylistOps.kt` and are tested on the JVM. `LibraryRepository` owns every write under the existing `mutationMutex`, reads the fresh playlist list before each change, saves the whole list through `SnoozyStores.savePlaylists`, and publishes the new list through `StateFlow`. Recents clear deletes the two history tables through a deliberate read-write path in `SnoozyDatabases`. The screens reuse the Phase 3A grid page, grouped rows, artwork, and Glasmio sheets.

**Tech Stack:** Kotlin 2.4.21, Compose BOM 2026.09.00, Glasmio 0.1.2, Navigation3 1.2.0, Coil 3.6.3, JUnit 4.

**Spec:** `docs/superpowers/specs/2026-11-11-snoozy-native-glasmio-design.md`

## Global Constraints

- Application ID `com.snoozy.app`, version 3.0.0, versionCode 14, minSdk 33, compile and target SDK 37, arm64-v8a only.
- Glasmio 0.1.2 is the UI foundation. Use `GlasmioGridPage` content through `SnoozyGridPage`, `GlasmioListRow`, `GlasmioBottomSheet`, `GlasmioActionSheetContent`, `GlasmioAlertDialog`, `GlasmioTextField`, and `GlasmioButton` before writing custom chrome.
- Reduce Transparency stays the default. Full glass stays opt-in and is out of Phase 3B.
- Preserve the emerald accent, Bricolage Grotesque, Atkinson Hyperlegible, Feather icons, 44 dp and 48 dp touch targets, accessible labels, portrait orientation, and reduced motion.
- No SF Pro, no SF Symbols assets, no emojis, no Latin abbreviations, no em dashes.
- Do not add play, shuffle, favorite, queue, or lyrics controls until the phase that makes them act. The playlist detail action row contains only Add songs in Phase 3B. Play and Shuffle arrive in Phase 4.
- Do not add a Library track menu in Phase 3B. Songs enter a playlist through the playlist detail Add songs sheet.
- Never uninstall the installed app. SQLite files and MMKV stores stay in place.
- Existing MMKV playlists, including `Jayzee test`, must survive every write and every restart.
- Every new branch or list transform gets a JVM test. Run `gradlew.bat :app:assembleDebug :app:testDebugUnitTest :app:lintDebug` before the device gate.
- User prompt truncation is a known scope risk. Only the design visible through the `- Scroll behavior` section is approved. Missing sections must be reconciled if supplied later.

## Scope

This plan covers:

- Playlist create, rename, delete, add song, remove song, and reorder song.
- Playlists root screen and playlist detail screen.
- Playlist name sheet, playlist actions sheet, track actions sheet, delete confirmation, and Add songs sheet.
- Playlist cover mosaics.
- Home clear recently played, including MMKV recents and the two SQLite history tables.
- Full import execution verification on the A55 with a real audio file, followed by restoration of the preserved data.
- The Phase 3 gate and the Phase 3B build record.

This plan does not cover:

- Playback, queue, repeat, shuffle, favorites, lyrics, search, metadata editing, pull-to-refresh, settings, full glass, and the player.
- Library and Home track menus.
- Playlist artwork or description editing. `Playlist.artworkPath` and `Playlist.description` remain read-only legacy fields.

## React Native Parity References

- Playlist writes: `src/storage/MusicLibraryContext.tsx` lines 508 to 584.
- Recents clear: `src/storage/MusicLibraryContext.tsx` lines 500 to 506, `src/storage/playHistory.ts` line 48, `src/storage/history.ts` line 102.
- Playlists screen: `src/app/(tabs)/playlists.tsx`.
- Playlist detail: `src/app/playlist.tsx`.
- Name sheet: `src/components/CreatePlaylistSheet.tsx`.
- Add songs sheet: `src/components/AddSongsSheet.tsx`.
- Playlist cover: `src/components/Artwork.tsx` lines 57 to 120.
- Move helper: `src/playback/queue.ts` lines 42 to 50.
- Home clear entry: `src/app/(tabs)/index.tsx` lines 275 to 281 and 475 to 492.

## Review Focus

- Blank names: create does nothing and returns no id; rename does nothing. The sheet disables the submit button while the trimmed name is empty. Pinned by `PlaylistOpsTest`.
- Missing tracks: playlist counts, detail rows, and reorder indexes use resolved tracks for display but raw `trackIds` for mutation. A stale or removed id must not crash and must not block moving a visible neighbor. Pinned by `PlaylistOpsTest` and the detail screen's id lookup.
- Duplicate adds: adding an existing id is a no-op and does not rewrite the store. Pinned by `PlaylistOpsTest`.
- Reorder bounds: same index, negative index, and index at or past the end return the same list instance. Pinned by `PlaylistOpsTest`.
- Existing data: the `Jayzee test` playlist with id `playlist-1794335417895-z97hxa` and track `1000000142` must remain after create, rename, add, remove, reorder, delete of other playlists, force-stop, and cold start.
- Destructive flows: delete playlist and clear history both ask first, both use the destructive role, and cancel changes nothing.
- No dead controls: the only detail buttons are Add songs and the per-track manage action. Do not render Play, Shuffle, or row playback until Phase 4.
- Persistence: playlist order and contents survive force-stop; the selected root tab may return to Home, which matches the Phase 1 shell.
- Import verification must restore the preserved library. Back up `snoozy.music.v1`, its `.crc`, `snoozy.audio.v1`, its `.crc`, and the `files/Music` directory before importing the test file, then restore and verify 37 tracks, 3 albums, and the original playlist.

---

### Task 1: Pure Playlist Transforms

**Files:**
- Create: `android-native/app/src/main/java/com/snoozy/app/data/library/PlaylistOps.kt`
- Test: `android-native/app/src/test/java/com/snoozy/app/data/library/PlaylistOpsTest.kt`

**Interfaces:**
- Produces: `object PlaylistOps`.
- Produces: `PlaylistOps.playlistId(createdAt: Long, suffix: String): String`.
- Produces: `PlaylistOps.playlistSuffix(value: Long): String`.
- Produces: `PlaylistOps.create(playlists: List<Playlist>, name: String, id: String, createdAt: Long): List<Playlist>`.
- Produces: `PlaylistOps.rename(playlists: List<Playlist>, id: String, name: String, updatedAt: Long): List<Playlist>`.
- Produces: `PlaylistOps.delete(playlists: List<Playlist>, id: String): List<Playlist>`.
- Produces: `PlaylistOps.addTrack(playlists: List<Playlist>, id: String, trackId: String): List<Playlist>`.
- Produces: `PlaylistOps.removeTrack(playlists: List<Playlist>, id: String, trackId: String): List<Playlist>`.
- Produces: `PlaylistOps.moveTrack(playlists: List<Playlist>, id: String, from: Int, to: Int): List<Playlist>`.
- Produces: `PlaylistOps.matches(track: Track, query: String): Boolean`.

Every transform returns the same list instance when it changes nothing. This lets the repository skip the MMKV write. Every transform returns a new list when it changes something.

- [x] **Step 1: Write the failing tests**

Create `PlaylistOpsTest.kt` with this fixture and these cases.

```kotlin
private val original = listOf(
    Playlist(
        id = "p1",
        name = "One",
        trackIds = listOf("a", "b", "c"),
        createdAt = 10L,
    ),
)
```

```kotlin
@Test
fun playlistIdMatchesTheStoredShape() {
    assertEquals("playlist-123-abc123", PlaylistOps.playlistId(123L, "abc123"))
}

@Test
fun playlistSuffixIsSixBase36Characters() {
    assertEquals("000000", PlaylistOps.playlistSuffix(0L))
    val suffix = PlaylistOps.playlistSuffix(987654321L)
    assertEquals(6, suffix.length)
    assertTrue(suffix.all { it in '0'..'9' || it in 'a'..'z' })
}

@Test
fun blankCreateIsIgnored() {
    assertSame(original, PlaylistOps.create(original, "   ", "p2", 20L))
}

@Test
fun createTrimsAndPrepends() {
    val next = PlaylistOps.create(original, "  Road trip  ", "p2", 20L)
    assertEquals(listOf("p2", "p1"), next.map { it.id })
    assertEquals("Road trip", next.first().name)
    assertEquals(emptyList<String>(), next.first().trackIds)
    assertEquals(20L, next.first().createdAt)
}

@Test
fun renameTrimsAndSetsUpdatedAt() {
    val next = PlaylistOps.rename(original, "p1", "  Night drive ", 30L)
    assertEquals("Night drive", next.single().name)
    assertEquals(30L, next.single().updatedAt)
}

@Test
fun blankRenameIsIgnored() {
    assertSame(original, PlaylistOps.rename(original, "p1", "   ", 30L))
}

@Test
fun renameOfMissingPlaylistIsIgnored() {
    assertSame(original, PlaylistOps.rename(original, "missing", "New", 30L))
}

@Test
fun deleteFiltersThePlaylist() {
    val next = PlaylistOps.delete(original, "p1")
    assertTrue(next.isEmpty())
}

@Test
fun deleteOfMissingPlaylistReturnsTheSameList() {
    assertSame(original, PlaylistOps.delete(original, "missing"))
}

@Test
fun addTrackAppendsOnce() {
    val next = PlaylistOps.addTrack(original, "p1", "d")
    assertEquals(listOf("a", "b", "c", "d"), next.single().trackIds)
    assertSame(next, PlaylistOps.addTrack(next, "p1", "d"))
}

@Test
fun addTrackToMissingPlaylistIsIgnored() {
    assertSame(original, PlaylistOps.addTrack(original, "missing", "d"))
}

@Test
fun removeTrackFiltersEveryOccurrence() {
    val next = PlaylistOps.removeTrack(original, "p1", "b")
    assertEquals(listOf("a", "c"), next.single().trackIds)
}

@Test
fun removeOfMissingTrackIsIgnored() {
    assertSame(original, PlaylistOps.removeTrack(original, "p1", "z"))
}

@Test
fun moveTrackReordersBothDirections() {
    assertEquals(
        listOf("b", "c", "a"),
        PlaylistOps.moveTrack(original, "p1", 0, 2).single().trackIds,
    )
    assertEquals(
        listOf("c", "a", "b"),
        PlaylistOps.moveTrack(original, "p1", 2, 0).single().trackIds,
    )
}

@Test
fun moveTrackOutsideTheListIsIgnored() {
    assertSame(original, PlaylistOps.moveTrack(original, "p1", 0, 3))
    assertSame(original, PlaylistOps.moveTrack(original, "p1", -1, 1))
    assertSame(original, PlaylistOps.moveTrack(original, "p1", 1, 1))
}

@Test
fun filterMatchesTitleArtistAndAlbumCaseInsensitively() {
    val track = Track(
        id = "t1",
        title = "Nikes",
        artist = "Frank Ocean",
        album = "Blonde",
        uri = "file:///music/1.mp3",
    )
    assertTrue(PlaylistOps.matches(track, "  nIk "))
    assertTrue(PlaylistOps.matches(track, "frank"))
    assertTrue(PlaylistOps.matches(track, "blonde"))
    assertTrue(PlaylistOps.matches(track, "   "))
    assertFalse(PlaylistOps.matches(track, "endless"))
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `gradlew.bat :app:testDebugUnitTest --tests "com.snoozy.app.data.library.PlaylistOpsTest"`

Expected: compilation fails because `PlaylistOps` does not exist.

- [x] **Step 3: Implement the transforms**

Create `PlaylistOps.kt`. Mirror the React Native behavior exactly.

- `playlistId` returns `"playlist-$createdAt-$suffix"`.
- `playlistSuffix` returns `java.lang.Long.toString(value, 36).takeLast(6).padStart(6, '0')`. The repository passes a positive random value.
- `create` trims the name, returns the input list when the trimmed name is empty, and otherwise prepends a new `Playlist` with empty `trackIds`, the supplied id, and the supplied `createdAt`.
- `rename` trims the name, returns the input list when the trimmed name is empty or the id is absent, and otherwise copies that playlist with the new name and `updatedAt`.
- `delete` filters by id and returns the input list when the size does not change.
- `addTrack` appends only when the id exists and the track id is absent, otherwise returns the input list.
- `removeTrack` filters the track id and returns the input list when the size does not change.
- `moveTrack` copies the id list only when the playlist exists, `from != to`, both indexes are inside the list, and the move changes order. Use the same splice semantics as `src/playback/queue.ts`: remove at `from`, insert at `to`.
- `matches` builds `"${track.title} ${track.artist} ${track.album}"`, lowercases both sides with the locale-invariant `lowercase()`, trims the query, and returns true when the query is empty or contained.

- [x] **Step 4: Run the tests to verify they pass**

Run the Step 2 command. Expected: all cases pass.

- [x] **Step 5: Commit**

```bash
git add android-native/app/src/main/java/com/snoozy/app/data/library/PlaylistOps.kt android-native/app/src/test/java/com/snoozy/app/data/library/PlaylistOpsTest.kt
git commit -m "feat(native): add playlist operations"
```

---

### Task 2: Playlist Writes and Recents Clear

**Files:**
- Modify: `android-native/app/src/main/java/com/snoozy/app/data/mmkv/SnoozyStores.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/data/db/SnoozyDatabases.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/data/library/LibraryRepository.kt`

**Interfaces:**
- Produces: `SnoozyStores.playlistsForUpdate(): List<Playlist>`.
- Produces: `SnoozyDatabases.clearPlayHistory(): Boolean`.
- Produces: `SnoozyDatabases.clearListeningSessions(): Boolean`.
- Produces: `LibraryRepository.createPlaylist(name: String): String?`.
- Produces: `LibraryRepository.renamePlaylist(id: String, name: String): Boolean`.
- Produces: `LibraryRepository.deletePlaylist(id: String): Boolean`.
- Produces: `LibraryRepository.addToPlaylist(id: String, trackId: String): Boolean`.
- Produces: `LibraryRepository.removeFromPlaylist(id: String, trackId: String): Boolean`.
- Produces: `LibraryRepository.movePlaylistTrack(id: String, from: Int, to: Int): Boolean`.
- Produces: `LibraryRepository.clearRecents(): Boolean`.

- [x] **Step 1: Add the strict playlist read**

In `SnoozyStores.kt`, add this next to `playlists()`:

```kotlin
fun playlistsForUpdate(): List<Playlist> =
    readListForUpdate(MUSIC, PLAYLISTS, Playlist.serializer())
```

This uses the existing private strict reader, so a corrupt store raises `StoreFailureException` instead of returning an empty list and overwriting the user's playlists.

- [x] **Step 2: Add the history clear path**

In `SnoozyDatabases.kt`, add:

```kotlin
fun clearPlayHistory(): Boolean = clearTable(PLAY_HISTORY_DB, "play_history")

fun clearListeningSessions(): Boolean = clearTable(LIBRARY_DB, "listening_sessions")

private fun clearTable(name: String, table: String): Boolean {
    synchronized(opened) { opened.remove(name)?.close() }
    val file = File(directory, name)
    if (!file.exists()) return true
    return try {
        SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READWRITE).use { database ->
            database.delete(table, null, null)
            true
        }
    } catch (error: Exception) {
        Log.w(TAG, "Could not clear $table", error)
        false
    }
}
```

Also guard the `opened` map in `open(name)` with `synchronized(opened)` so the clear path and a read cannot touch the map at the same time. Keep the failure behavior of `open`: a failed read-only open still copies the file and opens the copy read-only.

The original React Native behavior deletes rows from `snoozy_playhistory.db` and `snoozy.db`. This is the first deliberate read-write path on the preserved databases. It is limited to those two tables and runs only after the user confirms the clear.

- [x] **Step 3: Add the repository writes**

In `LibraryRepository.kt`, add a private mutation helper and the public methods. All work runs on `Dispatchers.IO` under the existing `mutationMutex`.

```kotlin
private suspend fun mutatePlaylists(
    transform: (List<Playlist>) -> List<Playlist>,
): List<Playlist>? = withContext(Dispatchers.IO) {
    mutationMutex.withLock {
        try {
            val current = stores.playlistsForUpdate()
            val next = transform(current)
            if (next !== current && !stores.savePlaylists(next)) {
                throw StoreFailureException("Could not save playlists.")
            }
            _state.update { it.copy(playlists = next) }
            next
        } catch (error: kotlinx.coroutines.CancellationException) {
            throw error
        } catch (error: Exception) {
            Log.w(TAG, "Playlist write failed", error)
            _state.update { it.copy(error = "Could not save playlist.") }
            null
        }
    }
}
```

Public methods:

```kotlin
suspend fun createPlaylist(name: String): String? {
    if (name.isBlank()) return null
    val now = System.currentTimeMillis()
    val id = PlaylistOps.playlistId(now, PlaylistOps.playlistSuffix(Random.nextLong().ushr(1)))
    return mutatePlaylists { PlaylistOps.create(it, name, id, now) }?.let { id }
}

suspend fun renamePlaylist(id: String, name: String): Boolean =
    mutatePlaylists { PlaylistOps.rename(it, id, name, System.currentTimeMillis()) } != null

suspend fun deletePlaylist(id: String): Boolean =
    mutatePlaylists { PlaylistOps.delete(it, id) } != null

suspend fun addToPlaylist(id: String, trackId: String): Boolean =
    mutatePlaylists { PlaylistOps.addTrack(it, id, trackId) } != null

suspend fun removeFromPlaylist(id: String, trackId: String): Boolean =
    mutatePlaylists { PlaylistOps.removeTrack(it, id, trackId) } != null

suspend fun movePlaylistTrack(id: String, from: Int, to: Int): Boolean =
    mutatePlaylists { PlaylistOps.moveTrack(it, id, from, to) } != null
```

Add `import kotlin.random.Random` and `import com.snoozy.app.data.library.PlaylistOps` only if the latter is not in the same package. `LibraryRepository` is already in `com.snoozy.app.data.library`, so no import is needed for `PlaylistOps`.

Add the recents clear method:

```kotlin
suspend fun clearRecents(): Boolean = withContext(Dispatchers.IO) {
    mutationMutex.withLock {
        val saved = stores.saveRecents(emptyList())
        val historyCleared = databases.clearPlayHistory()
        val sessionsCleared = databases.clearListeningSessions()
        val ok = saved && historyCleared && sessionsCleared
        _state.value = loadedState(hasAudioPermission()).let { loaded ->
            if (ok) loaded else loaded.copy(error = "Could not clear play history.")
        }
        ok
    }
}
```

Do not short-circuit the three clears. React Native clears the MMKV list, play history, and listening sessions independently.

- [x] **Step 4: Build and run the existing tests**

Run: `gradlew.bat :app:assembleDebug :app:testDebugUnitTest`

Expected: `BUILD SUCCESSFUL`, 68 or more tests, zero failures (52 existing plus 16 from Task 1). No new JVM test covers MMKV or Android SQLite; Task 1 covers the transforms and Task 7 covers device persistence.

- [x] **Step 5: Commit**

```bash
git add android-native/app/src/main/java/com/snoozy/app/data/mmkv/SnoozyStores.kt android-native/app/src/main/java/com/snoozy/app/data/db/SnoozyDatabases.kt android-native/app/src/main/java/com/snoozy/app/data/library/LibraryRepository.kt
git commit -m "feat(native): add playlist writes and recents clear"
```

---

### Task 3: Playlist Route, Cover, and Row Controls

**Files:**
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/navigation/NavKey.kt`
- Modify: `android-native/app/src/test/java/com/snoozy/app/ui/navigation/NavKeyTest.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/components/SnoozyArtwork.kt`
- Create: `android-native/app/src/test/java/com/snoozy/app/ui/components/PlaylistCoverTest.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/components/SnoozyRows.kt`

**Interfaces:**
- Produces: `NavKey.Playlist(val playlistId: String)` with route `playlist/<encoded id>`.
- Produces: `distinctArtworkUris(artworks: List<String?>): List<String>`.
- Produces: `SnoozyPlaylistCover(artworks: List<String?>, size: Dp, corner: Dp)`.
- Produces: `SnoozyIconAction(icon: ImageVector, label: String, onClick: () -> Unit, tint: Color = LocalGlassColors.current.secondaryContent)`.
- Produces: `SnoozyPlaylistRow(playlist: Playlist, trackCount: Int, artworks: List<String?>, onClick: () -> Unit, onManage: () -> Unit, showTopSeparator: Boolean = false)`.
- Changes: `SnoozyTrackRow` gains `trailing: (@Composable () -> Unit)? = null`.

- [x] **Step 1: Write the failing route and cover tests**

Add to `NavKeyTest.kt`:

```kotlin
@Test
fun playlistRouteRoundTripsAwkwardIds() {
    val ids = listOf(
        "playlist-1794335417895-z97hxa",
        "playlist-1-abc/def",
        "playlist-2-100% #1 ?",
    )
    for (id in ids) {
        assertEquals(NavKey.Playlist(id), NavKey.fromRoute(NavKey.Playlist(id).route))
    }
}

@Test
fun playlistRouteIsNotARoot() {
    assertFalse(NavKey.Playlist("p1").isRoot)
}
```

Create `PlaylistCoverTest.kt`:

```kotlin
@Test
fun coverKeepsDistinctNonBlankArtworkInOrder() {
    assertEquals(
        listOf("a", "b"),
        distinctArtworkUris(listOf("a", null, "b", "a", " ", "b")),
    )
}

@Test
fun coverTakesAtMostFourArtworks() {
    assertEquals(
        listOf("1", "2", "3", "4"),
        distinctArtworkUris(listOf("1", "2", "3", "4", "5")),
    )
}

@Test
fun coverHandlesNoArtwork() {
    assertEquals(emptyList<String>(), distinctArtworkUris(listOf(null, "", "  ")))
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `gradlew.bat :app:testDebugUnitTest --tests "com.snoozy.app.ui.navigation.NavKeyTest" --tests "com.snoozy.app.ui.components.PlaylistCoverTest"`

Expected: compilation fails because `NavKey.Playlist` and `distinctArtworkUris` do not exist.

- [x] **Step 3: Add the route and cover**

In `NavKey.kt`:

- Add `PLAYLIST_PREFIX = "playlist/"`.
- Add `data class Playlist(val playlistId: String) : NavKey` with `route = "playlist/${encodeRouteArg(playlistId)}"`, `title = "Playlist"`, and `description = "Songs saved to this playlist."`.
- Resolve it in `fromRoute` before the exact root checks.
- Do not add it to `roots`.

In `SnoozyArtwork.kt`:

```kotlin
fun distinctArtworkUris(artworks: List<String?>): List<String> =
    artworks.filterNotNull().filter { it.isNotBlank() }.distinct().take(4)
```

`SnoozyPlaylistCover` behavior:

- Zero artworks: `SnoozyArtwork(null, size, corner, null)`.
- One artwork: `SnoozyArtwork(uri, size, corner, null)`.
- Two to four artworks: a `Box` of `size` clipped with `ContinuousRoundedRectangle(corner)` and filled with `LocalGlassColors.current.elevatedBackground`. Inside, a `Column` with two `Row` cells, gap `max(2.dp, size * 0.012f)`, cell size `(size - gap) / 2`. Each occupied cell renders `SnoozyArtwork(uri, cell, 0.dp, null)` and each empty cell renders the same muted box as the cover background with a centered `SnoozyIcons.Music` at `cell * 0.34f` and `tertiaryContent` tint.

In `SnoozyRows.kt`:

- Add `SnoozyIconAction` as a 44 dp `Box` with `Modifier.clickable(role = Role.Button, onClickLabel = label)`, a centered 20 dp `Icon(contentDescription = label)`, and the supplied tint.
- Add `SnoozyPlaylistRow` using `GlasmioListRow`: title is `playlist.name`, subtitle is `countLabel(trackCount, "track", "tracks")`, leading is `SnoozyPlaylistCover(artworks, 44.dp, 10.dp)`, trailing is `SnoozyIconAction(SnoozyIcons.More, "Manage ${playlist.name}", onManage)`, and `showTopSeparator` is passed through.
- Add the optional `trailing` parameter to `SnoozyTrackRow` and pass it to `GlasmioListRow`.

- [x] **Step 4: Run the tests to verify they pass**

Run the Step 2 command. Expected: all cases pass.

- [x] **Step 5: Commit**

```bash
git add android-native/app/src/main/java/com/snoozy/app/ui/navigation/NavKey.kt android-native/app/src/test/java/com/snoozy/app/ui/navigation/NavKeyTest.kt android-native/app/src/main/java/com/snoozy/app/ui/components/SnoozyArtwork.kt android-native/app/src/test/java/com/snoozy/app/ui/components/PlaylistCoverTest.kt android-native/app/src/main/java/com/snoozy/app/ui/components/SnoozyRows.kt
git commit -m "feat(native): add playlist route cover and rows"
```

---

### Task 4: Playlists Screen and Dialogs

**Files:**
- Create: `android-native/app/src/main/java/com/snoozy/app/ui/components/PlaylistSheets.kt`
- Create: `android-native/app/src/main/java/com/snoozy/app/ui/screens/PlaylistsScreen.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/navigation/SnoozyApp.kt`

**Interfaces:**
- Produces: `PlaylistNameSheet(title: String, submitLabel: String, initialName: String, onSubmit: (String) -> Unit, onDismiss: () -> Unit)`.
- Produces: `PlaylistActionsSheet(playlist: Playlist, onRename: () -> Unit, onDelete: () -> Unit, onDismiss: () -> Unit)`.
- Produces: `PlaylistDeleteDialog(name: String, onConfirm: () -> Unit, onDismiss: () -> Unit)`.
- Produces: `PlaylistsScreen(contentPadding: PaddingValues, headerEntry: NavHeaderEntry, openPlaylist: (String) -> Unit)`.

- [x] **Step 1: Add the shared sheets**

Create `PlaylistSheets.kt` with these three composables.

`PlaylistNameSheet`:

- `GlasmioBottomSheet(visible = true, fitContent = true, onDismissRequest = onDismiss)`.
- `GlasmioActionSheetContent(title)` with `showHandle` left at its default. `GlasmioBottomSheet` already draws the handle.
- `GlasmioAlertFieldGroup` containing `GlasmioAlertTextField` with a local `TextFieldValue`, placeholder `"Playlist name"`, and `keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done)`.
- Request focus on open:

```kotlin
val focusRequester = remember { FocusRequester() }
LaunchedEffect(Unit) { focusRequester.requestFocus() }
GlasmioAlertTextField(
    value = name,
    onValueChange = { name = it },
    placeholder = "Playlist name",
    modifier = Modifier.focusRequester(focusRequester),
    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
    keyboardActions = KeyboardActions(onDone = { submit() }),
)
```

If focus does not land on the A55, remove only the request and the `LaunchedEffect`; keep the field.
- A trailing `Row` with Cancel and the submit button. Cancel is a default `GlasmioButton`. Submit uses `emphasis = GlassEmphasis.Prominent` and `enabled = name.trim().isNotEmpty()`. Cancel calls `onDismiss`; submit calls `onSubmit(name.trim())` and then `onDismiss`.
- Keyboard done calls the same submit path.

`PlaylistActionsSheet`:

- `GlasmioBottomSheet(visible = true, fitContent = true, onDismissRequest = onDismiss)`.
- `GlasmioActionSheetContent(playlist.name, message = "Choose an action")`.
- Rows: `Rename` and `Delete` followed by `Cancel`. All rows set `showDisclosure = false`. Delete sets `titleColor = LocalGlassColors.current.destructive`. Rename and Delete call their callback and then `onDismiss`. Cancel calls `onDismiss`.

`PlaylistDeleteDialog`:

- `GlasmioAlertDialog` with title `"Delete playlist?"`, message `"\"$name\" will be removed. Your songs stay in the library."`, and `buttonLayout = GlasmioAlertButtonLayout.SideBySide`.
- Buttons: `Cancel` with `GlasmioAlertButtonRole.Cancel`, then `Delete` with `GlasmioAlertButtonRole.Destructive`. This avoids the hardcoded iOS blue because neither button uses the `Default` role.
- `onDismissRequest` and Cancel call `onDismiss`. Delete calls `onConfirm`.

- [x] **Step 2: Build the Playlists screen**

Create `PlaylistsScreen.kt`.

State and header:

- Collect `LocalLibraryRepository.current.state`.
- `var createOpen by rememberSaveable { mutableStateOf(false) }`.
- `var renameTarget by remember { mutableStateOf<Playlist?>(null) }`.
- `var manageTarget by remember { mutableStateOf<Playlist?>(null) }`.
- `var deleteTarget by remember { mutableStateOf<Playlist?>(null) }`.
- `val scope = rememberCoroutineScope()`.
- Title `"Playlists"`. Subtitle `countLabel(state.playlists.size, "playlist", "playlists") + " · saved on this device"`.
- Header actions: one `GlasmioHeaderAction` keyed `"new"` with content description `"New playlist"`, a 20 dp `SnoozyIcons.Plus`, and an onClick that sets `createOpen = true`. Call `BindHeader(title, subtitle, actions)`.

Body:

- `SnoozyGridPage(contentPadding, headerEntry, title, subtitle)`.
- If `state.error != null`, render `SnoozyErrorBanner` with `repository.clearError()`.
- Empty list: `SnoozyEmptyState` with `SnoozyIcons.Playlists`, title `"No playlists yet"`, message `"Build a set for a walk, a drive, or a quiet evening. Open a playlist to add songs."`, and a `GlasmioButton` labelled `"Create a playlist"` that opens the create sheet.
- Otherwise `itemsIndexed(state.playlists, key = { _, playlist -> playlist.id }, span = full line)` with `SnoozyGroupedRow(index, count)` around `SnoozyPlaylistRow`.
- Resolve each playlist's tracks with `state.tracks.associateBy { it.id }` and `playlist.trackIds.mapNotNull(byId::get)`. Count and artwork come from the resolved tracks, matching React Native. Pass `onClick = { openPlaylist(playlist.id) }` and `onManage = { manageTarget = playlist }`.

Dialogs:

- `createOpen` renders `PlaylistNameSheet("New playlist", "Create", "")` with `onSubmit` launching `repository.createPlaylist(name)`.
- `renameTarget` renders `PlaylistNameSheet("Rename playlist", "Save", target.name)` with `onSubmit` launching `repository.renamePlaylist(target.id, name)`.
- `manageTarget` renders `PlaylistActionsSheet`. Choose Rename or Delete closes the actions sheet first (`manageTarget = null`), then opens the next sheet or dialog, matching the React Native `AppDialog` close-before-action order. Rename sets `renameTarget = target`; Delete sets `deleteTarget = target`.
- `deleteTarget` renders `PlaylistDeleteDialog` with `onConfirm` launching `repository.deletePlaylist(target.id)`. Clear `deleteTarget` after starting the write.

- [x] **Step 3: Wire the route**

In `SnoozyApp.kt`:

- Import `PlaylistsScreen` and `PlaylistScreen`. `PlaylistScreen` arrives in Task 5; add only `PlaylistsScreen` in this task.
- Add `val openPlaylist: (String) -> Unit = { id -> backStack.add(NavKey.Playlist(id).route) }`.
- Replace the `NavKey.Playlists` placeholder branch with `PlaylistsScreen(headerPadding, entry, openPlaylist)`.
- Leave `NavKey.Playlist` to the existing `else -> RootPlaceholder` branch in this task. Do not add a temporary branch. Task 5 replaces it with the real screen before the device gate.

- [x] **Step 4: Build and check manually**

Run: `gradlew.bat :app:assembleDebug :app:lintDebug`

Expected: `BUILD SUCCESSFUL`, lint has no new errors.

Manual check after install:

- Playlists tab shows the header action, the existing `Jayzee test` row with its cover and `1 track`, and the manage button.
- Create, rename, and delete open the sheets and dialogs with the copy above.
- Cancel on every sheet changes nothing.

- [x] **Step 5: Commit**

```bash
git add android-native/app/src/main/java/com/snoozy/app/ui/components/PlaylistSheets.kt android-native/app/src/main/java/com/snoozy/app/ui/screens/PlaylistsScreen.kt android-native/app/src/main/java/com/snoozy/app/ui/navigation/SnoozyApp.kt
git commit -m "feat(native): add playlists screen"
```

---

### Task 5: Playlist Detail and Add Songs

**Files:**
- Create: `android-native/app/src/main/java/com/snoozy/app/ui/components/AddSongsSheet.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/components/PlaylistSheets.kt`
- Create: `android-native/app/src/main/java/com/snoozy/app/ui/screens/PlaylistScreen.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/navigation/SnoozyApp.kt`

**Interfaces:**
- Produces: `AddSongsSheet(playlistName: String, trackIds: Set<String>, tracks: List<Track>, onAdd: (String) -> Unit, onRemove: (String) -> Unit, onDismiss: () -> Unit)`.
- Produces: `PlaylistTrackActionsSheet(track: Track, canMoveUp: Boolean, canMoveDown: Boolean, onMoveUp: () -> Unit, onMoveDown: () -> Unit, onRemove: () -> Unit, onDismiss: () -> Unit)` in `PlaylistSheets.kt`.
- Produces: `PlaylistScreen(playlistId: String, contentPadding: PaddingValues, headerEntry: NavHeaderEntry, onBack: () -> Unit)`.

- [x] **Step 1: Build the Add songs sheet**

Create `AddSongsSheet.kt`.

- `var filter by rememberSaveable { mutableStateOf("") }`.
- `val visibleTracks = remember(tracks, filter) { tracks.filter { PlaylistOps.matches(it, filter) } }`.
- `GlasmioBottomSheet(visible = true, onDismissRequest = onDismiss)` with a `Column(Modifier.fillMaxWidth().weight(1f))`, following the long-sheet pattern in the Glasmio sample.
- Header row: a column with `"Add songs"` in `IosTypography.headline` and the subtitle `“$playlistName” · ${countLabel(trackIds.size, "track", "tracks")}` in `IosTypography.footnote`, plus `SnoozyIconAction(SnoozyIcons.Close, "Close", onDismiss)`.
- `GlasmioTextField(filter, { filter = it }, placeholder = "Filter songs", keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search))` inside horizontal padding of 16 dp.
- Empty library message: `"No songs in the library yet. Scan your Music folder first."`
- No matches message: `"No songs match “$filter”."`
- Otherwise a `LazyColumn(Modifier.fillMaxWidth().weight(1f))` with `itemsIndexed(visibleTracks, key = { _, track -> track.id })`. Each row is wrapped in `SnoozyGroupedRow(index, visibleTracks.size)` and renders `GlasmioListRow` with the title, artist subtitle, `showTopSeparator = index > 0`, `onClick = { toggle(track.id) }`, and a trailing icon: `SnoozyIcons.Check` tinted `LocalGlassColors.current.accent` when the id is in `trackIds`, otherwise `SnoozyIcons.Plus` tinted `tertiaryContent`. The row content description is `"Add ${track.title} to playlist"` or `"Remove ${track.title} from playlist"`.
- Toggle calls `onRemove` when present and `onAdd` otherwise.
- Add `contentPadding` with 16 dp horizontal and enough bottom space for the navigation bar.

- [x] **Step 2: Build the detail screen**

Create `PlaylistScreen.kt`.

State:

- Collect the repository state.
- `val playlist = state.playlists.firstOrNull { it.id == playlistId }`.
- `val byId = remember(state.tracks) { state.tracks.associateBy { it.id } }`.
- `val tracks = remember(playlist, byId) { playlist?.trackIds?.mapNotNull(byId::get).orEmpty() }`.
- `val totalDuration = tracks.sumOf { it.duration }`.
- `val subtitle = playlist?.let { listOf(countLabel(tracks.size, "track", "tracks"), formatDuration(totalDuration)).joinToString(" · ") }`.
- `BindHeader(playlist?.name ?: "Playlist", subtitle, actions)`.
- Header actions when the playlist exists:
  - Rename: `SnoozyIcons.Edit`, content description `"Rename ${playlist.name}"`, sets `renameOpen = true`.
  - Delete: `SnoozyIcons.Trash`, content description `"Delete ${playlist.name}"`, tinted `LocalGlassColors.current.destructive`, sets `deleteOpen = true`.
- When the playlist is missing, bind only the title `"Playlist"` and no actions.

Missing playlist body:

- `SnoozyGridPage(contentPadding, headerEntry, "Playlist", null)`.
- `SnoozyEmptyState` with `SnoozyIcons.Playlists`, title `"Playlist not found"`, message `"It may have been deleted. Your songs are still in the library."`, and a `GlasmioButton` labelled `"Back to library"` that calls `onBack`.

Existing playlist body:

- `SnoozyGridPage(contentPadding, headerEntry, playlist.name, subtitle)`.
- Error banner when `state.error != null`.
- Centered `SnoozyPlaylistCover(tracks.map { it.artwork }, 188.dp, 32.dp)`.
- Action row with a single `GlasmioButton` labelled `"Add songs"` that opens the Add songs sheet. Do not render Play or Shuffle.
- Empty tracks: `SnoozyEmptyState` with `SnoozyIcons.Music`, title `"No songs yet"`, message `"Add songs from your library to start this playlist."`, and an `"Add songs"` button.
- Otherwise `SnoozySectionHeader("Songs")` and `itemsIndexed(tracks, key = { _, track -> track.id })` with `SnoozyGroupedRow(index, tracks.size)`. Render `SnoozyTrackRow` with subtitle `"${track.artist} · ${track.album}"`, `onClick = null`, the top separator, and a trailing `SnoozyIconAction(SnoozyIcons.More, "Manage ${track.title} in ${playlist.name}")` that sets `songMenu` to the track and index.

Track actions:

- `PlaylistTrackActionsSheet` lives in `PlaylistSheets.kt` and renders `GlasmioBottomSheet(fitContent = true)` with `GlasmioActionSheetContent(track.title, message = "${track.artist} · ${track.album}")`.
- Rows in order: `Move up` when `canMoveUp`, `Move down` when `canMoveDown`, `Remove from playlist` in the destructive color, `Cancel`.
- Move up and Move down compute the target exactly like React Native: `from = playlist.trackIds.indexOf(track.id)`, the neighbor is `tracks[index + direction]`, `to = playlist.trackIds.indexOf(neighbor.id)`, then call `repository.movePlaylistTrack(playlist.id, from, to)` only when both indexes are at least zero.
- Remove calls `repository.removeFromPlaylist(playlist.id, track.id)`.

Add songs:

- `AddSongsSheet(playlist.name, tracks.mapTo(HashSet()) { it.id }, state.tracks, ...)`.
- `onAdd` launches `repository.addToPlaylist(playlist.id, trackId)`.
- `onRemove` launches `repository.removeFromPlaylist(playlist.id, trackId)`.

Rename and delete:

- Rename uses `PlaylistNameSheet("Rename playlist", "Save", playlist.name)` and launches `repository.renamePlaylist`.
- Delete uses `PlaylistDeleteDialog(playlist.name)` and launches `repository.deletePlaylist(playlist.id)`; when it returns true, call `onBack()`.
- The route passes `onBack = navigateBack` so deletion can pop.

- [x] **Step 3: Wire the detail route**

In `SnoozyApp.kt`:

- Import `PlaylistScreen`.
- Replace the temporary `is NavKey.Playlist -> RootPlaceholder(...)` branch with:

```kotlin
is NavKey.Playlist -> PlaylistScreen(
    playlistId = key.playlistId,
    contentPadding = headerPadding,
    headerEntry = entry,
    onBack = navigateBack,
)
```

- Remove the `RootPlaceholder` import only if no other route uses it. Search and Settings still use it, so keep the import.

- [x] **Step 4: Build and check manually**

Run: `gradlew.bat :app:assembleDebug :app:lintDebug`

Expected: `BUILD SUCCESSFUL`, no new lint errors.

Manual check after install:

- Open `Jayzee test`, confirm the cover, `1 track`, the Add songs action, and the song row.
- Add a song, confirm the count grows and the check icon changes.
- Open the track menu and move up, move down, and remove.
- Rename and delete from the header.
- Delete the open playlist from its own header; confirm the app pops back to Playlists and does not crash.

- [x] **Step 5: Commit**

```bash
git add android-native/app/src/main/java/com/snoozy/app/ui/components/AddSongsSheet.kt android-native/app/src/main/java/com/snoozy/app/ui/screens/PlaylistScreen.kt android-native/app/src/main/java/com/snoozy/app/ui/navigation/SnoozyApp.kt
git commit -m "feat(native): add playlist detail and song editing"
```

---

### Task 6: Home Clear History

**Files:**
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/screens/HomeScreen.kt`

**Interfaces:**
- Consumes: `LibraryRepository.clearRecents(): Boolean`.
- Produces: the Home `Clear` section action and confirmation.

- [x] **Step 1: Add the action and dialog**

In `HomeScreen.kt`:

- Add `val scope = rememberCoroutineScope()`.
- Add `var clearOpen by remember { mutableStateOf(false) }`.
- Change the Recently played section header to:

```kotlin
SnoozySectionHeader(
    title = "Recently played",
    actionLabel = if (recentTracks.isNotEmpty()) "Clear" else null,
    onAction = if (recentTracks.isNotEmpty()) ({ clearOpen = true }) else null,
)
```

- After the grid page, when `clearOpen`, render:

```kotlin
GlasmioAlertDialog(
    onDismissRequest = { clearOpen = false },
    title = "Clear recently played?",
    message = "Your play history will be emptied.",
    buttonLayout = GlasmioAlertButtonLayout.SideBySide,
    buttons = listOf(
        GlasmioAlertButtonSpec(
            label = "Cancel",
            onClick = { clearOpen = false },
            role = GlasmioAlertButtonRole.Cancel,
        ),
        GlasmioAlertButtonSpec(
            label = "Clear",
            onClick = {
                clearOpen = false
                scope.launch { repository.clearRecents() }
            },
            role = GlasmioAlertButtonRole.Destructive,
        ),
    ),
)
```

The Cancel and Destructive roles avoid the hardcoded iOS blue and use the theme colors. The confirm is required. Clearing must not run from a single tap.

- [x] **Step 2: Build and inspect**

Run: `gradlew.bat :app:assembleDebug :app:lintDebug`

Expected: `BUILD SUCCESSFUL`, no new lint errors.

- [x] **Step 3: Commit**

```bash
git add android-native/app/src/main/java/com/snoozy/app/ui/screens/HomeScreen.kt
git commit -m "feat(native): add clear recently played"
```

---

### Task 7: Full Gate, Device Verification, and Records

**Files:**
- Modify: `docs/BUILD.md`
- Modify: `docs/superpowers/plans/2026-11-11-snoozy-native-glasmio-roadmap.md`
- Modify: `docs/superpowers/plans/2026-11-11-snoozy-native-phase-3b.md` (tick the boxes)
- Create: `.superpowers/sdd/2026-11-11-snoozy-native-phase-3b/progress.md` (gitignored ledger)

- [x] **Step 1: Run the static gate**

From `android-native` with JDK 25 and `ANDROID_HOME=D:\Android\Sdk`, export the keystore values from `C:\Users\Administrator\.snoozy\keystore.properties`, then run:

```bash
gradlew.bat :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
```

Record: test total, failures, lint errors, warnings, hints, APK bytes, APK SHA-256, and signer certificate SHA-256. The expected certificate is `0b3acae8b73999d871c4f18684e70fc32967fada05967f9d18a463b37fe755ce`.

- [x] **Step 2: Install without uninstalling**

```bash
adb -s 9PGE8SQKAM598PBY install -r android-native/app/build/outputs/apk/debug/app-debug.apk
```

Expected: `Success`. Do not run `adb uninstall`.

- [x] **Step 3: Verify playlists on the A55**

Use `adb shell input tap 504 1450` for the Playlists tab. Wait three to four seconds after each tab switch and confirm with `uiautomator dump`.

- Playlists shows `Jayzee test` with `1 track`, its cover, and a manage button.
- Create `Phase 3B check` with the header plus. Confirm it prepends.
- Rename it to `Phase 3B renamed` through the manage sheet. Confirm the detail header and the list both update.
- Force-stop and cold start. Confirm the renamed playlist is still present in the same position.
- Open it, add `Nikes` and one more track. Confirm the sheet shows a check for added songs and the detail count matches.
- Move the second track up, then down. Confirm the order changes and persists after reopening.
- Remove one track. Confirm the count decreases.
- Delete the playlist from the detail header and confirm. Confirm the app returns to Playlists and `Jayzee test` is untouched.
- Create one more playlist, delete it from the list manage sheet, and cancel one delete to confirm Cancel changes nothing.

- [x] **Step 4: Verify clear history and restore the preserved history**

The clear is destructive to the preserved React Native history. Back it up first, verify the clear, then restore it so the app keeps the original recents, play history, and listening sessions.

Before clearing, stop the app and back up the MMKV recents and the two history databases. Run the binary redirects through `cmd.exe`; PowerShell `>` can corrupt binary output:

```bat
adb -s 9PGE8SQKAM598PBY shell am force-stop com.snoozy.app
adb -s 9PGE8SQKAM598PBY shell run-as com.snoozy.app ls -la files/SQLite
cmd /c "adb -s 9PGE8SQKAM598PBY exec-out run-as com.snoozy.app cat files/mmkv/snoozy.music.v1 > snoozy.music.v1.history"
cmd /c "adb -s 9PGE8SQKAM598PBY exec-out run-as com.snoozy.app cat files/mmkv/snoozy.music.v1.crc > snoozy.music.v1.history.crc"
cmd /c "adb -s 9PGE8SQKAM598PBY exec-out run-as com.snoozy.app cat files/SQLite/snoozy_playhistory.db > snoozy_playhistory.db"
cmd /c "adb -s 9PGE8SQKAM598PBY exec-out run-as com.snoozy.app cat files/SQLite/snoozy.db > snoozy.db"
```

If `ls` shows `-wal` or `-shm` files, back those up the same way and restore them too. Record the original file sizes and the startup counts from `logcat`: recents 19, play history 6, listening sessions 34 at the time of writing. Re-read them from `logcat` rather than assuming these values.

- On Home, tap `Clear` and confirm the dialog copy. Confirm Recently played empties and Most played disappears.
- Force-stop and cold start. Confirm Recently played stays empty and `logcat` shows `playHistory=0 listeningSessions=0 recents=0`.
- Confirm the playlists are unaffected.
- Restore the preserved history: force-stop, push the backups, copy them back through `run-as`, remove any `-wal` or `-shm` files that were not in the backup, and restart.
- Confirm `logcat` shows the original recents, play history, and listening session counts, and that Recently played and Most played return.

- [x] **Step 5: Verify a real import and restore the preserved library**

Before importing, stop the app and back up to a temporary directory outside the repository. Use the same `cmd.exe` binary redirects as Step 4:

```bat
adb -s 9PGE8SQKAM598PBY shell am force-stop com.snoozy.app
cmd /c "adb -s 9PGE8SQKAM598PBY exec-out run-as com.snoozy.app cat files/mmkv/snoozy.music.v1 > snoozy.music.v1"
cmd /c "adb -s 9PGE8SQKAM598PBY exec-out run-as com.snoozy.app cat files/mmkv/snoozy.music.v1.crc > snoozy.music.v1.crc"
cmd /c "adb -s 9PGE8SQKAM598PBY exec-out run-as com.snoozy.app cat files/mmkv/snoozy.audio.v1 > snoozy.audio.v1"
cmd /c "adb -s 9PGE8SQKAM598PBY exec-out run-as com.snoozy.app cat files/mmkv/snoozy.audio.v1.crc > snoozy.audio.v1.crc"
adb -s 9PGE8SQKAM598PBY shell run-as com.snoozy.app ls -la files/Music
```

Create a one-second 440 Hz mono WAV on the host, push it to `/sdcard/Download/snoozy-import-test.wav`, then import it through the header import action and the system picker. Confirm:

- The import action accepts the file.
- Library reports 38 songs.
- The imported track appears under the expected artist, album, and title.
- The copied file exists under `files/Music`.
- `snoozy.audio.v1` gained a metadata cache entry for the imported id.
- No crash appears in `logcat -b crash`.

Restore the preserved state. Push the MMKV backups and copy them back through `run-as`, then delete the exact imported file name; never delete any other file:

```bash
adb -s 9PGE8SQKAM598PBY shell am force-stop com.snoozy.app
adb -s 9PGE8SQKAM598PBY push snoozy.music.v1 /data/local/tmp/snoozy.music.v1
adb -s 9PGE8SQKAM598PBY push snoozy.music.v1.crc /data/local/tmp/snoozy.music.v1.crc
adb -s 9PGE8SQKAM598PBY push snoozy.audio.v1 /data/local/tmp/snoozy.audio.v1
adb -s 9PGE8SQKAM598PBY push snoozy.audio.v1.crc /data/local/tmp/snoozy.audio.v1.crc
adb -s 9PGE8SQKAM598PBY shell run-as com.snoozy.app cp /data/local/tmp/snoozy.music.v1 files/mmkv/snoozy.music.v1
adb -s 9PGE8SQKAM598PBY shell run-as com.snoozy.app cp /data/local/tmp/snoozy.music.v1.crc files/mmkv/snoozy.music.v1.crc
adb -s 9PGE8SQKAM598PBY shell run-as com.snoozy.app cp /data/local/tmp/snoozy.audio.v1 files/mmkv/snoozy.audio.v1
adb -s 9PGE8SQKAM598PBY shell run-as com.snoozy.app cp /data/local/tmp/snoozy.audio.v1.crc files/mmkv/snoozy.audio.v1.crc
adb -s 9PGE8SQKAM598PBY shell run-as com.snoozy.app rm "files/Music/snoozy-import-test.wav"
adb -s 9PGE8SQKAM598PBY shell am start -n com.snoozy.app/.MainActivity
```

If the copied file name was de-duplicated by the import path, delete the exact name reported by the import log or by `ls files/Music`. After restart, confirm 37 songs, 3 albums, the original playlists, the original history counts, and an unchanged snapshot count. Then delete the host backup files.

- [x] **Step 6: Check the crash buffer**

```bash
adb -s 9PGE8SQKAM598PBY logcat -b crash -d -v time
```

Expected: empty, or only entries from before this gate that are clearly identified.

- [x] **Step 7: Write the records**

Add a `Native 3.0 Phase 3B` section to `docs/BUILD.md` with:

- Intent and new files.
- Repository write semantics and the deliberate SQLite read-write exception for the two history tables.
- Static gate results.
- APK size, SHA-256, certificate SHA-256.
- Device verification results, including playlist create, rename, delete, add, remove, reorder, restart persistence, clear history counts, import and restoration, and the crash buffer.
- Defects found and fixed.
- Deferred items.

Amend the roadmap Phase 3 section:

- Mark 3A and 3B done.
- Close the gate as "every list opens and scrolls at the performance budget; playback, row playback, and player controls are Phase 4."
- Note that the Phase 3 gate closed on the A55 on 11 November 2026.

Write the local ledger at `.superpowers/sdd/2026-11-11-snoozy-native-phase-3b/progress.md` with one line per task, the rulings, and the deferred list.

- [x] **Step 8: Commit the records**

```bash
git add docs/BUILD.md docs/superpowers/plans/2026-11-11-snoozy-native-glasmio-roadmap.md docs/superpowers/plans/2026-11-11-snoozy-native-phase-3b.md
git commit -m "docs(native): record phase 3b verification"
```

---

## Definition of Done

- All Task 1, Task 3, and route tests pass.
- `:app:assembleDebug`, `:app:testDebugUnitTest`, and `:app:lintDebug` succeed.
- The signed APK installs over the existing 3.0 install without uninstalling.
- Existing 37 tracks, 3 albums, `Jayzee test`, recents, and history tables are intact before the import test.
- Create, rename, delete, add, remove, and reorder all persist across force-stop.
- Clear history empties MMKV recents, play history, and listening sessions after confirmation, and cancels cleanly. The preserved history is restored afterward and its original counts return.
- The import test adds a real file and the restore returns the library to 37 tracks and the original history counts.
- No crash entries appear during the gate.

## Deferred

- Playback, queue, repeat, shuffle, speed, notification, and the player: Phase 4.
- Play and Shuffle buttons on playlist detail: Phase 4.
- Library and Home track menus, including Add to playlist, favorite, play next, and add to queue: Phase 4.
- Playlist artwork and description editing: not present in 2.3.0.
- Search, lyrics, metadata editing, settings, full glass, and reduced motion setting: later phases.
- Import cleanup UI and a user-facing import error report: later phase.
- APK size reduction, release minification, and asset review: Phase 8.
