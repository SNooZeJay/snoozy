# Snoozy Native Phase 3: Library and Home Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Home, Library, album, artist, and genre placeholders with working Glasmio screens over the Phase 2 data layer, with persistent sorts, real navigation, artwork, permission, and import paths.

**Architecture:** Pure browse helpers in `data/library/LibraryBrowse.kt` keep sorting and filtering testable on the JVM. `LibraryRepository.State` gains play history and the two persisted sort values. One `SnoozyGridPage` composable owns the lazy grid, collapsing header binding, scroll-edge blur, and page padding for every screen. Coil renders the existing `file://` artwork cache.

**Tech Stack:** Kotlin 2.4.21, Compose BOM 2026.09.00, Glasmio 0.1.2, Navigation3 1.2.0, Coil 3.6.3, JUnit 4.

**Spec:** `docs/superpowers/specs/2026-11-11-snoozy-native-glasmio-design.md`

## Global Constraints

- Application ID `com.snoozy.app`, version 3.0.0, versionCode 14, minSdk 33, compile and target SDK 37, arm64-v8a only.
- Glasmio 0.1.2 is the UI foundation. Use its real list, header, button, alert, and sheet APIs before writing custom chrome.
- Reduce Transparency stays the default. Full glass stays opt-in and is out of Phase 3.
- Preserve emerald accent, Bricolage Grotesque, Atkinson Hyperlegible, Feather icons, 44 dp and 48 dp touch targets, accessible labels, and portrait orientation.
- No SF Pro, no SF Symbols assets, no emojis, no Latin abbreviations, no em dashes.
- Keep portrait orientation and five root tabs. Detail routes are pushed on the same root back stack.
- Do not add play, shuffle, favorite, playlist, or queue controls until the phase that makes them act. Phase 3 rows open an album, artist, or genre; album track rows are not clickable.
- Never uninstall the installed app. SQLite files and MMKV stores stay in place and are read through the Phase 2 accessors.
- The React Native app at the repository root stays untouched until parity.
- Every new non-trivial branch or list operation gets a JVM test. Run `gradlew.bat :app:assembleDebug :app:testDebugUnitTest :app:lintDebug` before the device gate.
- User prompt truncation is a known scope risk. Only the design visible through the `- Scroll behavior` section is approved. Missing sections must be reconciled if supplied later.

## Scope Split

Phase 3A, this plan:

- Home with status, recently played, recently added, most played.
- Library with Songs, Albums, Artists, Genres, Favorites, sorted, grid and list for albums.
- Album, artist, and genre detail routes.
- Coil artwork loader, grouped-row geometry, sort persistence, permission state, import picker, scan action.
- Header collapse and back navigation on every screen.

Phase 3B, separate plan after 3A lands:

- Playlists tab list, create, rename, and delete.
- Playlist detail, add, remove, reorder.
- Full import verification on the device.
- Recents clear, which writes MMKV plus two SQLite files and belongs with the write phase.

The roadmap Phase 3 gate is amended to "every list opens and scrolls at the performance budget" because playback is Phase 4.

## Review Focus

- Artist and genre names with spaces, `/`, `%`, `#`, `?`, or non-ASCII characters: route encoding and detail lookup must round-trip and never fall back to Home. Pinned by `NavKeyTest.detailRoutesRoundTripAwkwardNames`.
- Empty or single-item collections: grouped corners, empty states, and count labels must not crash or show a broken group. Pinned by `GroupedRowsTest` and the screen empty branches.
- Albums with a missing year, artwork, or duration, and duplicate titles: sort must treat the year as zero, show the artwork placeholder, and open the album selected by `albumKeyFor`. Pinned by `LibraryBrowseTest` and device gate.
- Libraries with about one thousand tracks: sorting must run only when tracks or sort change, and lists must stay lazy. Screens call `remember(tracks, sort)`; no non-lazy row loop.
- Stored sort values written by React Native (`title`, `artist`, `album`, `duration`, `year`, `tracks`) or an unknown value: parsing must select the expected order and fall back to Title. Pinned by `LibraryBrowseTest`.

---

### Task 1: Browse, Sort, and Duration Helpers

**Files:**
- Create: `android-native/app/src/main/java/com/snoozy/app/data/library/LibraryBrowse.kt`
- Create: `android-native/app/src/main/java/com/snoozy/app/ui/format/Format.kt`
- Test: `android-native/app/src/test/java/com/snoozy/app/data/library/LibraryBrowseTest.kt`
- Test: `android-native/app/src/test/java/com/snoozy/app/ui/format/FormatTest.kt`

**Interfaces:**
- Produces: `enum class SongSort(val storageValue: String, val label: String)` with `Title`, `Artist`, `Album`, `Duration`, and `SongSort.fromStored(value: String?): SongSort`.
- Produces: `enum class AlbumSort(val storageValue: String, val label: String)` with `Title`, `Artist`, `Year`, `Tracks`, and `AlbumSort.fromStored(value: String?): AlbumSort`.
- Produces: `sortedTracks(tracks: List<Track>, sort: SongSort): List<Track>`.
- Produces: `sortedAlbums(albums: List<Album>, sort: AlbumSort): List<Album>`.
- Produces: `artistNamesOf(tracks: List<Track>): List<String>`.
- Produces: `tracksForArtist(tracks: List<Track>, artist: String): List<Track>`.
- Produces: `tracksForGenre(tracks: List<Track>, genre: String): List<Track>`.
- Produces: `albumsForArtist(albums: List<Album>, tracks: List<Track>, artist: String): List<Album>`.
- Produces: `tracksForIds(tracks: List<Track>, ids: List<String>, limit: Int): List<Track>`.
- Produces: `favoriteTracks(tracks: List<Track>, favoriteIds: Set<String>): List<Track>`.
- Produces: `yearOrZero(value: String?): Int`.
- Produces: `formatDuration(seconds: Double): String`.

- [ ] **Step 1: Write the failing tests**

Cover each assertion below. Use a local `track(id, title, artist, album, duration, genre, year)` fixture and an `album(id, title, artist, year, addedAt, trackIds)` fixture.

```kotlin
assertEquals(SongSort.Title, SongSort.fromStored(null))
assertEquals(SongSort.Duration, SongSort.fromStored("duration"))
assertEquals(SongSort.Title, SongSort.fromStored("bpm"))
assertEquals(AlbumSort.Tracks, AlbumSort.fromStored("tracks"))
assertEquals(AlbumSort.Title, AlbumSort.fromStored(""))

// Title order is case-insensitive: "alpha" before "Beta".
// Artist order is artist, then album, then title.
// Album order is album, then title.
// Duration order is longest first, then title; a non-finite duration counts as zero.
// Year order is newest first and a null or non-numeric year counts as zero.
// Track-count order is most tracks first, then title.
assertEquals(listOf("A", "B"), artistNamesOf(listOf(track(artist = "B"), track(artist = "A"), track(artist = "A"))))
assertEquals(0, yearOrZero(null))
assertEquals(2004, yearOrZero("2004a"))
assertEquals(0, yearOrZero("unknown"))
assertEquals(listOf("2", "1"), tracksForIds(tracks, listOf("2", "missing", "1"), 10).map { it.id })
assertEquals(listOf("1", "2"), tracksForIds(tracks, listOf("1", "2"), 1).map { it.id })
assertEquals(listOf("1"), favoriteTracks(tracks, setOf("1")).map { it.id })
assertEquals(listOf("2"), tracksForArtist(tracks, "Beta").map { it.id })
assertEquals(listOf("2"), tracksForGenre(tracks, " Rock ").map { it.id })
assertEquals(listOf("a"), albumsForArtist(albums, tracks, "Beta").map { it.id })
```

```kotlin
assertEquals("0s", formatDuration(0.0))
assertEquals("59s", formatDuration(59.4))
assertEquals("1 min", formatDuration(59.6))
assertEquals("59 min", formatDuration(3540.0))
assertEquals("1 hr", formatDuration(3599.0))
assertEquals("1 hr 5 min", formatDuration(3900.0))
assertEquals("0s", formatDuration(Double.NaN))
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `gradlew.bat :app:testDebugUnitTest --tests "com.snoozy.app.data.library.LibraryBrowseTest" --tests "com.snoozy.app.ui.format.FormatTest"`

Expected: compilation fails because the helpers do not exist.

- [ ] **Step 3: Implement the helpers**

`LibraryBrowse.kt` mirrors the React Native comparators in `src/storage/MusicLibraryContext.tsx` and `src/storage/libraryStats.ts`:

- Title: `compareText(title)`.
- Artist: `compareText(artist)`, then album, then title.
- Album: `compareText(album)`, then title.
- Duration: finite values only, descending, then title.
- Album year: `yearOrZero` descending, then title.
- Album tracks: `trackIds.size` descending, then title.
- `artistNamesOf` uses exact `track.artist`, distinct, natural order.
- `tracksForGenre` compares `genre?.trim()?.lowercase()` and returns an empty list for a blank genre.
- `tracksForIds` preserves the id order, skips missing ids, and applies `limit.coerceAtLeast(0)`.
- `albumsForArtist` collects `albumKeyFor(track)` for the artist's tracks and filters `albums` by id.

`Format.kt` copies `formatDuration` from `src/utils/format.ts`, including `Math.round` behavior.

- [ ] **Step 4: Run the tests to verify they pass**

Run the Step 2 command. Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add android-native/app/src/main/java/com/snoozy/app/data/library/LibraryBrowse.kt android-native/app/src/main/java/com/snoozy/app/ui/format/Format.kt android-native/app/src/test/java/com/snoozy/app/data/library/LibraryBrowseTest.kt android-native/app/src/test/java/com/snoozy/app/ui/format/FormatTest.kt
git commit -m "feat(native): add library browse and sort helpers"
```

---

### Task 2: Detail Routes and Header Binding

**Files:**
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/navigation/NavKey.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/navigation/NavHeaderEntry.kt`
- Test: `android-native/app/src/test/java/com/snoozy/app/ui/navigation/NavKeyTest.kt`

**Interfaces:**
- Produces: `NavKey.Album(val albumKey: String)`, `NavKey.Artist(val name: String)`, `NavKey.Genre(val name: String)`.
- Produces: `encodeRouteArg(value: String): String` and `decodeRouteArg(value: String): String`.
- Produces: `NavHeaderEntry.title: String?`, `.subtitle: String?`, `.actions: List<GlasmioHeaderAction>`.
- Produces: `LocalNavHeaderEntry` and `BindHeader(title: String, subtitle: String? = null, actions: List<GlasmioHeaderAction> = emptyList())`.

- [ ] **Step 1: Write the failing tests**

```kotlin
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
```

The existing root assertions stay.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `gradlew.bat :app:testDebugUnitTest --tests "com.snoozy.app.ui.navigation.NavKeyTest"`

Expected: compilation fails because the detail keys do not exist.

- [ ] **Step 3: Implement the routes and binding**

- Prefixes are `album/`, `artist/`, `genre/`.
- Encode with `URLEncoder.encode(value, "UTF-8")` and decode with `URLDecoder.decode(value, "UTF-8")` so the JVM tests run without `android.net.Uri`.
- `fromRoute` checks detail prefixes before the root fallback. An unknown route still returns `Home`.
- `NavKey.Album.title` is `"Album"`, `NavKey.Artist.title` is `"Artist"`, `NavKey.Genre.title` is `"Genre"`; screens replace them through `BindHeader`.

- [ ] **Step 4: Run the tests to verify they pass**

Run the Step 2 command. Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add android-native/app/src/main/java/com/snoozy/app/ui/navigation/NavKey.kt android-native/app/src/main/java/com/snoozy/app/ui/navigation/NavHeaderEntry.kt android-native/app/src/test/java/com/snoozy/app/ui/navigation/NavKeyTest.kt
git commit -m "feat(native): add detail routes and header binding"
```

---

### Task 3: Repository History, Sorts, and Artwork Foundation

**Files:**
- Modify: `android-native/app/src/main/java/com/snoozy/app/data/library/LibraryRepository.kt`
- Modify: `android-native/app/build.gradle.kts`
- Create: `android-native/app/src/main/java/com/snoozy/app/ui/components/SnoozyArtwork.kt`
- Create: `android-native/app/src/main/java/com/snoozy/app/ui/components/GroupedRows.kt`
- Test: `android-native/app/src/test/java/com/snoozy/app/ui/components/GroupedRowsTest.kt`

**Interfaces:**
- Produces: `LibraryRepository.State.history: List<PlayHistoryEntry>`, `.songSort: SongSort`, `.albumSort: AlbumSort`.
- Produces: `suspend fun LibraryRepository.setSongSort(sort: SongSort)`, `suspend fun setAlbumSort(sort: AlbumSort)`, `fun clearError()`.
- Produces: `SnoozyArtwork(uri: String?, size: Dp, corner: Dp, contentDescription: String?)`.
- Produces: `enum class GroupedRowPosition { Single, First, Middle, Last }`, `groupedRowPosition(index: Int, count: Int): GroupedRowPosition`, `groupedRowShape(position): Shape`.

- [ ] **Step 1: Write the failing test**

```kotlin
assertEquals(GroupedRowPosition.Single, groupedRowPosition(0, 1))
assertEquals(GroupedRowPosition.First, groupedRowPosition(0, 3))
assertEquals(GroupedRowPosition.Middle, groupedRowPosition(1, 3))
assertEquals(GroupedRowPosition.Last, groupedRowPosition(2, 3))
assertEquals(GroupedRowPosition.Single, groupedRowPosition(0, 0))
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `gradlew.bat :app:testDebugUnitTest --tests "com.snoozy.app.ui.components.GroupedRowsTest"`

Expected: compilation fails because `groupedRowPosition` does not exist.

- [ ] **Step 3: Implement the repository and artwork foundation**

- Add Coil with `implementation("io.coil-kt.coil3:coil-compose:3.6.3")`.
- `loadedState` reads `stores.songSort()`, `stores.albumSort()`, and `databases.playHistory()`. All three run on IO.
- The sort setters write the React Native storage value and update state on IO; a failed write logs a warning and still updates the in-memory value.
- `clearError` resets only `error`.
- `SnoozyArtwork` clips with `ContinuousRoundedRectangle(corner)`, shows the Feather music icon when the uri is null or blank, and otherwise uses `AsyncImage` with `ContentScale.Crop`.
- Grouped rows use 26 dp continuous corners: `Single` all corners, `First` top corners, `Last` bottom corners, `Middle` zero.
- `GroupedRows.kt` also exposes `LazyGridScope.groupedRows(...)`? No. Each screen owns its item loop so keys and click targets stay explicit.

- [ ] **Step 4: Run the test to verify it passes**

Run the Step 2 command. Expected: pass. Then run `gradlew.bat :app:assembleDebug`. Expected: build succeeds with Coil resolved.

- [ ] **Step 5: Commit**

```bash
git add android-native/app/build.gradle.kts android-native/app/src/main/java/com/snoozy/app/data/library/LibraryRepository.kt android-native/app/src/main/java/com/snoozy/app/ui/components/SnoozyArtwork.kt android-native/app/src/main/java/com/snoozy/app/ui/components/GroupedRows.kt android-native/app/src/test/java/com/snoozy/app/ui/components/GroupedRowsTest.kt
git commit -m "feat(native): load history, sorts, and artwork"
```

---

### Task 4: Shared Page Scaffold, Header, and Screen Wiring

**Files:**
- Create: `android-native/app/src/main/java/com/snoozy/app/ui/components/SnoozyPage.kt`
- Create: `android-native/app/src/main/java/com/snoozy/app/ui/navigation/LocalLibraryRepository.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/navigation/SnoozyApp.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/MainActivity.kt`

**Interfaces:**
- Produces: `SnoozyGridPage(contentPadding: PaddingValues, headerEntry: NavHeaderEntry, title: String, subtitle: String?, columns: Int = 1, content: LazyGridScope.() -> Unit)`.
- Produces: `SnoozyLargeTitle(title: String, subtitle: String?, collapseProgress: Float)`.
- Produces: `LocalLibraryRepository: ProvidableCompositionLocal<LibraryRepository>`.
- Consumes: Tasks 1 to 3.

- [ ] **Step 1: Implement the scaffold**

- `SnoozyGridPage` owns `rememberLazyGridState`, `rememberGlasmioHeaderCollapse`, `rememberGlasmioHeaderScrollEdge`, and the `GlasmioHeaderScrollState` SideEffect.
- Bottom padding is `contentPadding.calculateBottomPadding() + NavigationBarSurfaceHeight + 32.dp + navigation bar inset`.
- The grid is `LazyVerticalGrid(GridCells.Fixed(columns))` with the large title as a full-span first item.
- Do not add a non-lazy loop around rows.

- [ ] **Step 2: Wire header and navigation**

- `SnoozyApp` takes `repository: LibraryRepository`.
- Provide `LocalLibraryRepository`.
- Header title is `entry.title ?: key.title`, subtitle is `entry.subtitle`.
- Detail routes get a leading back `GlasmioHeaderAction` using `SnoozyIcons.Back`.
- `entry.actions` renders as one trailing merged group.
- Entry content switches on the key: Home, Library, Album, Artist, Genre; Search, Playlists, Settings keep `RootPlaceholder`.
- Home receives `openAlbum`, `openArtist`, `openGenre`, and `openLibraryAlbums`. Library receives `tab` and `onTabChange`. Detail screens receive `onOpenAlbum` and `onBack`.
- The Library tab selection is `rememberSaveable` in `SnoozyApp` so Home's Albums link and tab switches preserve it.

- [ ] **Step 3: Build**

Run: `gradlew.bat :app:assembleDebug`

Expected: succeeds. The screens do not exist yet, so add temporary stubs only if needed and remove them in Tasks 5 to 8. Prefer implementing Tasks 5 to 8 before the first build if compile order allows.

- [ ] **Step 4: Commit**

```bash
git add android-native/app/src/main/java/com/snoozy/app/ui/components/SnoozyPage.kt android-native/app/src/main/java/com/snoozy/app/ui/navigation/LocalLibraryRepository.kt android-native/app/src/main/java/com/snoozy/app/ui/navigation/SnoozyApp.kt android-native/app/src/main/java/com/snoozy/app/MainActivity.kt
git commit -m "feat(native): add shared page scaffold and navigation"
```

---

### Task 5: Album Detail

**Files:**
- Create: `android-native/app/src/main/java/com/snoozy/app/ui/screens/AlbumScreen.kt`

**Interfaces:**
- Consumes: `NavKey.Album.albumKey`, `LibraryRepository.State.albums`, `.tracks`, `SnoozyGridPage`, `SnoozyArtwork`, `formatDuration`.

- [ ] **Step 1: Implement the screen**

- Resolve the album by id. Fall back to `albumKey` when not found.
- Header title is the album title; subtitle is artist, year, track count, and `formatDuration(duration)` joined by ` · `, skipping blanks.
- Hero artwork is 188 dp with the large corner radius.
- Tracks come from `album.trackIds` mapped through a `remember(state.tracks)` by-id map, preserving album order. Rows are not clickable.
- Missing album shows the shared empty state with a real "Rescan library" action.

- [ ] **Step 2: Build**

Run: `gradlew.bat :app:assembleDebug`. Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add android-native/app/src/main/java/com/snoozy/app/ui/screens/AlbumScreen.kt
git commit -m "feat(native): add album detail screen"
```

---

### Task 6: Artist and Genre Detail

**Files:**
- Create: `android-native/app/src/main/java/com/snoozy/app/ui/screens/ArtistScreen.kt`
- Create: `android-native/app/src/main/java/com/snoozy/app/ui/screens/GenreScreen.kt`

**Interfaces:**
- Consumes: `tracksForArtist`, `albumsForArtist`, `tracksForGenre`, album detail navigation.

- [ ] **Step 1: Implement both screens**

Artist:

- Subtitle is `"N song(s) · M album(s)"`.
- Albums section rows open album detail.
- Songs section rows open album detail.
- Empty state has a real rescan action.

Genre:

- Subtitle is `"N song(s)"`.
- Song rows open album detail.
- Empty state has a real rescan action.

- [ ] **Step 2: Build**

Run: `gradlew.bat :app:assembleDebug`. Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add android-native/app/src/main/java/com/snoozy/app/ui/screens/ArtistScreen.kt android-native/app/src/main/java/com/snoozy/app/ui/screens/GenreScreen.kt
git commit -m "feat(native): add artist and genre detail screens"
```

---

### Task 7: Home

**Files:**
- Create: `android-native/app/src/main/java/com/snoozy/app/ui/screens/HomeScreen.kt`
- Create: `android-native/app/src/main/java/com/snoozy/app/ui/components/SnoozyMediaCard.kt`
- Create: `android-native/app/src/main/java/com/snoozy/app/ui/components/LibraryControls.kt` if permission and import launchers are shared with Library; otherwise keep them in `HomeScreen.kt` and duplicate the two launcher calls in Library.

**Interfaces:**
- Consumes: repository state, `recentlyAdded`, `topPlayedTracks`, `tracksForIds`, `SnoozyGridPage`, `SnoozyMediaCard`.

- [ ] **Step 1: Implement Home**

- Status line: `"Permission needed"`, `"Scanning…"`, `"N songs"`, or `"No songs yet"`.
- Header actions: import (`SnoozyIcons.Download`) when permission is granted, scan (`SnoozyIcons.Retry`) always.
- Permission state: "Grant access" requests `READ_MEDIA_AUDIO`; "Open settings" opens the app details page. Both stay available, so neither is a dead control.
- Import uses `OpenMultipleDocuments` with `audio/*` and calls `repository.importDocuments`.
- Recently played: `tracksForIds(tracks, recents, 10)`, horizontal cards, card opens its album.
- Recently added: `recentlyAdded(albums, 12).filter { addedAt > 0 }.take(8)`, horizontal cards, opens album detail.
- Most played: `topPlayedTracks(tracks, history, 8)`, subtitle `"N play(s)"`, opens album detail.
- Empty sections are omitted. When nothing has been played, show the compact "Nothing played yet" message.
- No play buttons.

- [ ] **Step 2: Build**

Run: `gradlew.bat :app:assembleDebug`. Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add android-native/app/src/main/java/com/snoozy/app/ui/screens/HomeScreen.kt android-native/app/src/main/java/com/snoozy/app/ui/components/SnoozyMediaCard.kt android-native/app/src/main/java/com/snoozy/app/ui/components/LibraryControls.kt
git commit -m "feat(native): add home library overview"
```

---

### Task 8: Library

**Files:**
- Create: `android-native/app/src/main/java/com/snoozy/app/ui/screens/LibraryScreen.kt`

**Interfaces:**
- Consumes: `sortedTracks`, `sortedAlbums`, `artistNamesOf`, `genresOf`, `favoriteTracks`, `SnoozyGridPage`, grouped rows, repository sort setters, `LibraryTab`.

- [ ] **Step 1: Implement the screen**

- `LibraryTab` is a private enum with `Songs`, `Albums`, `Artists`, `Genres`, `Favorites`, each with a label.
- Segments use `GlasmioSegmentedControl` with five items at 32 dp height.
- Count label matches the React Native wording: song(s), album(s), artist(s), genre(s), favorite(s).
- Songs and albums toolbars have a sort button showing `Sort · Title` and a real selection dialog. Use `GlasmioAlertDialog` with the four options and a Cancel action; the current option is checked.
- Albums also have a grid/list toggle icon with an accessibility label.
- Songs: `sortedTracks(tracks, state.songSort)` remembered by tracks and sort.
- Albums list: `sortedAlbums(albums, state.albumSort)`.
- Album grid: two columns, artwork tile, title, artist.
- Artists: `artistNamesOf(tracks)`.
- Genres: `genresOf(tracks)`.
- Favorites: `favoriteTracks(tracks, favoriteTrackIds)`.
- Song, album, and artist rows open their routes. Genre rows open genre detail.
- Empty states match the React Native copy, including the real "Scan your device" or "Grant access" action where applicable.
- Import and scan header actions match Home.

- [ ] **Step 2: Build**

Run: `gradlew.bat :app:assembleDebug`. Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add android-native/app/src/main/java/com/snoozy/app/ui/screens/LibraryScreen.kt
git commit -m "feat(native): add library tabs, sorts, and album grid"
```

---

### Task 9: Gates, Device Verification, and Documentation

**Files:**
- Modify: `docs/BUILD.md`
- Modify: `docs/superpowers/plans/2026-11-11-snoozy-native-glasmio-roadmap.md`
- Create: `.superpowers/sdd/2026-11-11-snoozy-native-phase-3/progress.md`

- [ ] **Step 1: Run the full gate**

```powershell
$env:JAVA_HOME='C:\Program Files\Eclipse Adoptium\jdk-25.0.2.10-hotspot'
$env:ANDROID_HOME='D:\Android\Sdk'
.\gradlew.bat :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
```

Expected: build succeeds, all unit tests pass, lint has zero errors.

- [ ] **Step 2: Install over the current 3.0 build and verify on the A55**

```powershell
adb -s 9PGE8SQKAM598PBY install -r android-native\app\build\outputs\apk\debug\app-debug.apk
```

Verify:

- Home shows `37 songs`, recently played, recently added, most played.
- Library tabs show 37 songs, 2 albums, artist and genre counts that match the React Native app.
- Song sort Title, Artist, Album, Duration each reorder the list and survive an app restart.
- Album sort Title, Artist, Year, Tracks each reorder and survive an app restart.
- Album grid/list toggles.
- Every album, artist, and genre row opens its detail route; back returns to the same list position.
- The large title collapses on scroll and the top bar blur follows.
- Artwork appears for the two known albums and the placeholder appears for albums without art.
- Import picker opens; cancelling returns without a state change.
- Permission screen actions open the system prompt and app settings.
- `adb logcat -b crash -d` is empty for the session.

- [ ] **Step 3: Record evidence and amend the roadmap**

- Append the Phase 3A artifact size, SHA-256, certificate SHA-256, test count, lint count, and device results to `docs/BUILD.md`.
- Change the Phase 3 gate in the roadmap to "every list opens and scrolls at the performance budget", and note the Phase 3B split.
- Record every deferred item in the Phase 3 ledger.

- [ ] **Step 4: Commit**

```bash
git add docs/BUILD.md docs/superpowers/plans/2026-11-11-snoozy-native-glasmio-roadmap.md .superpowers/sdd/2026-11-11-snoozy-native-phase-3/progress.md
git commit -m "docs(native): record phase 3a verification"
```

---

## Self-Review

- Spec coverage: Home, Library, detail routes, sorts, artwork, permission, import, header collapse, and the gate amendment each have a task. Search, playlists, settings, playback, lyrics, edit sheets, and diagnostics remain in later phases by design.
- Deferred on purpose: favorite toggles, playlist writes, queue menus, play and shuffle controls, clear recents, pull-to-refresh gesture, and reduced-motion settings.
- No task defines a type or function another task does not use.
- Every comparator and list filter has a JVM test. UI-only behavior is verified on the device.
