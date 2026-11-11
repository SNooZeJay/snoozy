# Snoozy build record

## Native 3.0 Phase 3B (3.0.0, versionCode 14) - playlists, history clear, and import verified on device

- Intent: replace the Playlists placeholder with a working playlist list and playlist detail screen supporting create, rename, delete, add song, remove song, and reorder song over the preserved MMKV store, add the Home clear-history action, and verify full SAF audio import and restoration on the A55.
- New and modified files: `data/library/PlaylistOps.kt`, `data/library/PlaylistOpsTest.kt`, `data/mmkv/SnoozyStores.kt`, `data/db/SnoozyDatabases.kt`, `data/library/LibraryRepository.kt`, `ui/navigation/NavKey.kt`, `ui/navigation/NavKeyTest.kt`, `ui/navigation/SnoozyApp.kt`, `ui/components/SnoozyArtwork.kt`, `ui/components/PlaylistCoverTest.kt`, `ui/components/SnoozyRows.kt`, `ui/components/PlaylistSheets.kt`, `ui/components/AddSongsSheet.kt`, `ui/screens/PlaylistsScreen.kt`, `ui/screens/PlaylistScreen.kt`, and `ui/screens/HomeScreen.kt`.
- Repository write semantics and SQLite read-write exception: `LibraryRepository` serializes every playlist write on `Dispatchers.IO` under `mutationMutex`, reads the fresh list through the strict `SnoozyStores.playlistsForUpdate()` helper so a corrupt store raises `StoreFailureException` instead of overwriting existing playlists, skips the MMKV write when `PlaylistOps` returns the same list instance, writes through `SnoozyStores.savePlaylists`, and updates `StateFlow`. `LibraryRepository.clearRecents()` clears the MMKV `recents.v1` list and invokes `SnoozyDatabases.clearPlayHistory()` and `SnoozyDatabases.clearListeningSessions()` without short-circuiting. Those two methods close any cached read-only handle under `synchronized(opened)` and open `snoozy_playhistory.db` (`play_history`) and `snoozy.db` (`listening_sessions`) with `SQLiteDatabase.OPEN_READWRITE` to delete rows after user confirmation. All other database reads remain read-only.
- Static gates: `gradlew.bat :app:assembleDebug :app:testDebugUnitTest :app:lintDebug` with JDK 25 and `ANDROID_HOME=D:\Android\Sdk`: `BUILD SUCCESSFUL`. Unit tests: 73 tests, 0 failures (including 16 `PlaylistOpsTest` cases, 3 `PlaylistCoverTest` cases, and 2 playlist `NavKeyTest` cases). Lint: 0 errors, 6 warnings, 1 hint.
- Artifact: `android-native/app/build/outputs/apk/debug/app-debug.apk`, `78,229,911` bytes, SHA-256 `4625794524A4048C4239910CAB7C05DC0F95E078FB7F46F57B604A71868D15B5`. Signed with the existing release certificate, SHA-256 `0b3acae8b73999d871c4f18684e70fc32967fada05967f9d18a463b37fe755ce`.
- Device verification on Oppo A55 (`CPH2325`, Android 13, `9PGE8SQKAM598PBY` / wireless ADB `192.168.1.9:45485`): `adb install -r` succeeded (`Success`) over the existing 3.0 install without uninstalling.
  - Playlists: verified existing `Jayzee test` (`1 track`) with its cover and manage button. Created `Phase 3B check` from the header plus action and confirmed it prepended at the top of the list (`0 tracks`). Renamed it to `Phase 3B renamed` through the manage sheet (`Save` button) and confirmed the list and detail header updated. Force-stopped and cold-started the app and confirmed `Phase 3B renamed` remained first above `Jayzee test`.
  - Playlist detail and song editing: opened `Phase 3B renamed`, opened `Add songs`, added `Alabama` and filtered for `Nikes` to add it. Confirmed added rows switched to the check state (`Remove ... from playlist`) and detail updated to `2 tracks · 7 min`. Moved `Nikes` up (`Nikes`, `Alabama`), moved it down (`Alabama`, `Nikes`), then moved `Nikes` up again, force-stopped, cold-started, and reopened the playlist to confirm the `Nikes`, `Alabama` order persisted. Removed `Alabama` (`1 track · 5 min`), deleted `Phase 3B renamed` from the detail header action, and confirmed navigation returned to Playlists with `Jayzee test` (`1 track`) untouched. Also verified list-level manage delete and confirmed `Cancel` in the delete dialog left playlists unchanged.
  - Clear history and restoration: backed up `snoozy.music.v1` (`131,072` bytes), `snoozy.music.v1.crc` (`4,096` bytes), `snoozy_playhistory.db` (`12,288` bytes), `snoozy.db` (`4,096` bytes), `snoozy.db-shm` (`32,768` bytes), and `snoozy.db-wal` (`622,152` bytes) through `cmd.exe` binary redirection. Verified startup counts in `logcat` (`recents=19`, `playHistory=6`, `listeningSessions=34`). Tapped `Clear` on Home, verified dialog copy (`Clear recently played?` / `Your play history will be emptied.`), confirmed `Cancel` left Home unchanged, then confirmed `Clear`. Verified `Recently played` emptied (`Nothing played yet. Play a song and it will appear here.`), `Clear` action hid, and `Most played` disappeared. Force-stopped and cold-started; verified `logcat` reported `playHistory=0 listeningSessions=0` and `playlists=1 playlistTracks=1 recents=0`, with `Jayzee test` untouched. Restored all backup files, restarted, and confirmed `logcat` reported `playHistory=6 listeningSessions=34` and `recents=19` and both Home sections returned.
  - Real import and restoration: backed up `snoozy.music.v1`, `snoozy.music.v1.crc`, `snoozy.audio.v1` (`131,072` bytes), and `snoozy.audio.v1.crc` (`4,096` bytes) via `cmd.exe` binary redirection (`files/Music` did not exist prior to import). Generated a 1-second 440 Hz mono PCM WAV (`88,244` bytes), pushed it to `/sdcard/Download/snoozy-import-test.wav`, and imported it through the header `Import songs` action and system document picker. Confirmed Home and Library reported `38 songs`, the copied file existed at `files/Music/snoozy-import-test.wav` (`88,244` bytes), the track (`imported-1794425769545-0-5233ff`) rendered in Library Songs as `snoozy import test` / `Unknown artist` / `0:01` (`album`: `Imported`), and `snoozy.audio.v1` gained the metadata cache entry for the imported id. Restored the MMKV backups, deleted `files/Music/snoozy-import-test.wav`, restarted, and confirmed `preserved snapshot tracks=37`, `37 songs`, `3 albums`, `1 playlist` (`Jayzee test`), `recents=19`, `playHistory=6`, and `listeningSessions=34`. Deleted the temporary host backup files afterward.
  - Crash buffer: `adb logcat -b crash -d -v time` was completely empty throughout and at the end of the gate.
- Defects found and fixed: none during the Phase 3B gate.
- Deferred items: playback, queue, repeat, shuffle, speed, notification, and the player (Phase 4); Play and Shuffle buttons on playlist detail (Phase 4); Library and Home track menus including Add to playlist, favorite, play next, and add to queue (Phase 4); playlist artwork and description editing (not present in 2.3.0); search, lyrics, metadata editing, settings, full glass, and reduced motion setting (later phases); import cleanup UI and user-facing import error report (later phase); APK size reduction, release minification, and asset review (Phase 8).

## Native 3.0 Phase 3A (3.0.0, versionCode 14) - home and library verified on device

- Intent: replace the Home, Library, album, artist, and genre placeholders with working Glasmio screens over the Phase 2 data layer. Sorts persist through the existing MMKV stores, every row opens a real route, and playback controls stay out until Phase 4.
- New code: `data/library/LibraryBrowse.kt`, `ui/format/Format.kt`, `ui/components/SnoozyPage.kt`, `SnoozyArtwork.kt`, `SnoozyRows.kt`, `GroupedRows.kt`, `LibraryActions.kt`, `SnoozyBanners.kt`, `SnoozyHeaderActions.kt`, `SnoozyLibraryEmpty.kt`, `ui/navigation/LocalLibraryRepository.kt`, and `ui/screens/HomeScreen.kt`, `LibraryScreen.kt`, `AlbumScreen.kt`, `ArtistScreen.kt`, `GenreScreen.kt`.
- Data: `LibraryRepository.State` now carries play history, song sort, and album sort. Sort setters write the React Native storage values. Unchanged fields keep the Phase 2 JSON shapes and MediaStore identity.
- Glasmio: one `SnoozyGridPage` owns the lazy grid, header collapse binding, scroll-edge blur, and bottom inset for every screen. Page content is hosted by `GlasmioBackdropHost`, and `SnoozyApp` wraps the scaffold in `GlasmioBackdropProvider(navigationBackdrop)` so modal sheets receive `LocalBlurBackdrop`. The sort selector uses `GlasmioBottomSheet`, `GlasmioActionSheetContent`, and `GlasmioListRow` with an emerald `SnoozyIcons.Check`; `GlasmioAlertDialog` was dropped because its default button tint is a hardcoded iOS blue.
- Static gates: `gradlew.bat :app:assembleDebug :app:testDebugUnitTest :app:lintDebug` with JDK 25 and `ANDROID_HOME=D:\Android\Sdk`: `BUILD SUCCESSFUL`. Unit tests: 52 tests, 0 failures. Lint: 0 errors, 6 warnings, 1 hint.
- Artifact: `android-native/app/build/outputs/apk/debug/app-debug.apk`, `78,424,442` bytes, SHA-256 `3E8D3E09F2C580C631F269FCDF91D2D281F2395FBBCFE171DDAF3A2B8B4CE5D0`. Signed with the existing release certificate, SHA-256 `0b3acae8b73999d871c4f18684e70fc32967fada05967f9d18a463b37fe755ce`.
- Device verification on Oppo A55 (`CPH2325`, Android 13, `9PGE8SQKAM598PBY`): `adb install -r` succeeded over the existing 3.0 install and the `READ_MEDIA_AUDIO` grant carried over.
  - Home reported `37 songs` with real Recently played and Most played cards (Ivy, Mine, Mitsubishi Sony; Mine at 2 plays). Recently added stayed hidden because every track in the preserved snapshot has `addedAt` `0`: Expo writes `DATE_TAKEN` through `putLong`, so React Native also stored `0` and its Home applies the same `addedAt > 0` filter. No data change was made.
  - Library reported 37 songs, 3 albums (Blonde, Endless, RED 99), 2 artists (Ciarán, Frank Ocean), 2 genres (Pop, R&B/Soul), and 0 favorites with the empty state and a working Browse songs action.
  - Song sorts Title, Artist, Album, and Duration each reordered the list, and Duration survived a force-stop and cold start. Album sorts Title, Artist, Year, and Tracks each reordered, and Tracks survived a force-stop and cold start. Both were restored to Title afterward.
  - The album grid/list toggle rendered two columns and grouped list rows with years. Blonde and Endless detail routes, the Ciarán artist route, and the Pop genre route all opened with real track lists; back restored the previous Library scroll position.
  - Scrolling Library replaced the large title with the compact header and followed with the blur progress. Album detail used the same collapse.
  - The import header action opened the system document picker; cancelling returned to the Library with no state change.
  - Permission: Music and audio was denied in system settings, the next launch showed the system request, and Allow restored all 37 songs. The in-app permission state exposes Grant access and Open settings callbacks.
  - No entries in `logcat -b crash` after the fix pass.
- Defects found and fixed during the gate: page content needed a `GlasmioBackdropHost` for the segment control, and the modal sort sheet needed the app-level `LocalBlurBackdrop` provider. The first sheet run also showed a duplicate drag handle and disclosure chevrons on action rows; both were removed.
- Not yet done: playlists and playlist detail, playlist CRUD, add/remove/reorder, full import execution, recents clear, favorite toggles, queue menus, play and shuffle controls, pull-to-refresh, reduced-motion setting, and full glass. These stay in Phase 3B and later phases. The APK is still about 78 MB; release minification and asset review remain in Phase 8.

## Native 3.0 Phase 2 (3.0.0, versionCode 14) - data layer verified on device

- Intent: read the existing expo-sqlite and react-native-mmkv data in place, scan MediaStore with the expo-media-library identity and caching rules, and add a library repository plus startup diagnostics. No migration, no store clearing, and no UI changes beyond the Phase 1 shell.
- New code: `data/model/Models.kt`, `data/mmkv/SnoozyStores.kt`, `data/mmkv/SnoozyJson.kt`, `data/db/SnoozyDatabases.kt`, `data/library/AlbumGrouping.kt`, `data/library/LibraryStats.kt`, `data/library/AudioMetadata.kt`, `data/library/LibraryMerge.kt`, `data/library/LibraryRepository.kt`, `data/scan/LibraryScanner.kt`, `data/scan/ScanGuard.kt`, `data/playback/PlaybackSessionLogic.kt`, `data/diagnostics/DataDiagnostics.kt`, `AppContainer.kt`, and `SnoozyApplication.kt`.
- Compatibility: MediaStore `_ID` string id, `file://` plus unencoded `DATA` path, `DATE_MODIFIED * 1000` ms, `DATE_TAKEN` added-at, `DURATION / 1000` seconds. The default asset order is `_ID DESC`, matching expo-media-library. Album key is `album-` plus FNV-1a base36 of `<normalized artist>::<normalized title>` with the React Native fallbacks. Artwork stays at `filesDir/artwork/<albumKey>-<stableHash(uri:modified)>.jpg` with `.none` misses. JSON keeps the React Native field names and `encodeDefaults = true`. MMKV opens `filesDir/mmkv` explicitly and uses the seven existing store ids.
- Failure safety: `ScanGuard` aborts a scan that returns no usable assets while a snapshot exists; null or failed MediaStore queries throw; MMKV opens lazily and caches failures; update reads and writes are strict; imports copy to a temporary file and only count after the imported store is written; SQLite falls back to a read-only copy in `cacheDir/snoozy-db` instead of opening the preserved database read-write.
- Static gates: `gradlew.bat :app:assembleDebug :app:testDebugUnitTest :app:lintDebug` with JDK 25: `BUILD SUCCESSFUL`. Unit tests: 33 tests, 0 failures across album grouping, library stats, audio metadata, playback session logic, navigation, scan guard, merge, and JSON round trips. Lint: 0 errors, 6 warnings, 1 hint.
- Artifact: `android-native/app/build/outputs/apk/debug/app-debug.apk`, `76,442,949` bytes, SHA-256 `E487FA141A234D3D4B40292ADEFEBEFADCB3D1F339C0FE731CF1B127E5A01A68`. Signed with the same 2.3.0 release certificate, SHA-256 `0b3acae8b73999d871c4f18684e70fc32967fada05967f9d18a463b37fe755ce`.
- Device verification on Oppo A55 (`CPH2325`, Android 13, `9PGE8SQKAM598PBY`): `adb install -r` succeeded over the Phase 1 build, and the 2.3.0 `READ_MEDIA_AUDIO` grant carried over.
  - Warm scan: logcat tag `SnoozyData` reported preserved `37`, scan `37` tracks and `37` assets, snapshot after scan `37`, imported `0`, and `15` MMKV keys. Reading the snapshot from the live MMKV region (the `.crc` `actualSize` boundary, not the last text occurrence in the append-only file) gave `37` tracks in the same order as the React Native backup with **0 field differences** across `uri`, `title`, `artist`, `album`, `albumArtist`, `year`, `genre`, `trackNumber`, `discNumber`, `duration`, `artwork`, and `addedAt`. Artwork resolves to `album-hhxvcj-35ylmk.jpg` and `album-zcp9rt-1t0waag.jpg`, matching 2.3.0.
  - Cold metadata cache: moved `snoozy.audio.v1` aside, launched, and rescanned all `37` files from embedded tags. The rebuilt cache has `37` entries with **0 value differences** and the snapshot again has **0 field differences**. The preserved `snoozy.audio.v1` and `.crc` were restored afterward.
  - Existing data: playlists `1` with `1` track, recents `19`, play history `6`, listening sessions `34`, and a readable `session.v1` with a 10-track queue whose active track exists in the snapshot.
  - SQLite counts confirmed independently against pulled files: favorites `0`, track overrides `0`, album overrides `0`, artist overrides `0`, play history `6`, listening sessions `34`. SHA-256 of all five database files, plus `snoozy.db-wal` and `snoozy.db-shm`, is unchanged before and after, so the read-only open did not modify them.
  - The duplicate artwork files left by the earlier `_ID ASC` experiment were deleted; only the React Native referenced covers and one `.none` marker remain. No entries in `logcat -b crash`.
- Note: MMKV files are append-only and can retain stale records beyond the live `actualSize` stored in the `.crc` metadata. Text-searching the raw file for the last key returns stale data. Compare values through `MMKV` or within the `.crc` size boundary.
- Not yet verified: no list UI consumes the repository yet; header collapse and scrolling stay gated in Phase 3.

## Native 3.0 Phase 1 (3.0.0, versionCode 14) - shell verified on device

- Intent: first native Kotlin and Jetpack Compose build on Glasmio `0.1.2`: Snoozy theme, bundled fonts, Feather icon mapping, and the five root tabs with collapsed headers. The React Native 2.3.0 app is untouched at the repository root.
- Location: `android-native/`, package `com.snoozy.app`, `versionCode` 14, `versionName` 3.0.0, minSdk 33, compile/targetSdk 37, `arm64-v8a` only.
- Toolchain: JDK 25 (`C:\Program Files\Eclipse Adoptium\jdk-25.0.2.10-hotspot`), Gradle 9.6.0, AGP 9.4.1 with built-in Kotlin, Kotlin Compose plugin 2.4.21, Compose BOM 2026.09.00, Glasmio `io.github.neoruaa.glasmio:glasmio-scaffold:0.1.2`, Feather `br.com.devsrsouza.compose.icons:feather:1.1.1` (package `compose.icons`).
- Defaults: Reduce Transparency enabled, dark system appearance, emerald `#10B981`, Bricolage Grotesque headings, Atkinson Hyperlegible body, Feather icons mapped onto Glasmio `SfSymbol` names so no SF Symbol asset ships.
- Static gates: `gradlew.bat :app:assembleDebug :app:testDebugUnitTest :app:lintDebug` with JDK 25 and `ANDROID_HOME=D:\Android\Sdk`: `BUILD SUCCESSFUL in 1m 19s`. Unit tests: 1 test, 0 failures (`NavKeyTest`). Lint: no blocking issues.
- Debug APK is signed with the existing release key: certificate SHA-256 `0b3acae8b73999d871c4f18684e70fc32967fada05967f9d18a463b37fe755ce`, identical to the 2.3.0 release certificate.
- Artifact: `android-native/app/build/outputs/apk/debug/app-debug.apk`, `74,536,107` bytes, SHA-256 `B660E65915B6923A6E01855D991403D1AC87C06B39849945E902D4532CFA1F43`.
- Device verification on Oppo A55 (`CPH2325`, Android 13, `9PGE8SQKAM598PBY`):
  - `adb install -r` over 2.3.0 (versionCode 13) succeeded with `Success`.
  - Home, Search, Library, Playlists, and Settings all open from the tab bar; the selected tab moves and the header morphs.
  - Header title fades out at rest and appears during the tab morph, matching Glasmio's transition behavior.
  - No entries in `logcat -b crash`. Cold start reported `TotalTime: 5782` ms while the process was cold and the device was charging.
  - Existing data verified through `run-as`: `files/SQLite` still holds `snoozy.db`, `snoozy_errorlog.db`, `snoozy_favorites.db`, `snoozy_metadata.db`, and `snoozy_playhistory.db`; `files/mmkv` still holds all seven stores with their `.crc` files; `files/artwork` still holds the cached album art.
  - `files/Music` does not exist and `snoozy.music.v1` contains no `imported-*` ids or `files/Music/` paths, so there were no imported files to preserve on this device.
- Defect found and fixed during the gate: `NavKey.roots` was built eagerly in the companion initializer and captured `NavKey.Home` as null while that object was still class-initializing, which crashed every launch. The list is now lazy and `fromRoute` uses a `when`; `NavKeyTest` covers route resolution.
- Not yet verified: header collapse under scroll (the placeholder pages have no scrollable content). It is gated in Phase 3 with the real lists.

## v2.3 (2.3.0, versionCode 13) - released and verified

- Intent: port the Glasmio interaction motion layer into Snoozy's Reanimated and Gesture Handler architecture (`src/motion/chrome.ts`, `src/motion/scrollState.ts`, `src/components/CollapsingHeader.tsx`, `src/components/SheetPanel.tsx`), adding collapsing compact title bars across tabs and stack screens, tab-bar shrink with docked mini-player travel, header drag-to-dismiss and scroll-scaled artwork on the full player, and grabber drag-to-dismiss on bottom sheets.
- App version `2.3.0`; Android `versionCode` `13`; package `com.snoozy.app`.
- Design and execution references: `docs/HANDOFF-v2.3-antigravity.md`.
- Static gates: `npx tsc --noEmit` (0 errors), `npx expo lint` (0 errors), `npx jest --silent` (7 suites, 34 tests passed).
- Native autolinking fix: removed the stale Android autolinking block in `react-native.config.js`, aligned `react-native-gesture-handler` at `3.4.0`, and cleared cached autolinking artifacts in `C:\s\android\build\generated\autolinking` so `RNGestureHandlerModule` and `RNGestureHandlerRootViewComponentDescriptor` link into the release binary.
- Post-verification UI and accessibility fixes:
  - Added `useSafeAreaInsets().top` padding and height adjustment to `CollapsedBar` in `src/components/CollapsingHeader.tsx` so compact headers sit below the Android status bar, and added `importantForAccessibility` / `accessibilityElementsHidden` when inactive.
  - Placed `GestureHandlerRootView` outside the translated `Animated.View` in `src/components/SheetPanel.tsx` so drag coordinates remain stationary and `FlatList` scrolling inside `QueueSheet` works cleanly within its 78% max height.
- Release command: sync `D:\OWN_PROJECTS\SNOOZY\src` and `app.json` to `C:\s`, delete stale `*.bundle` files, export `SNOOZY_KEYSTORE_*` from `C:\Users\Administrator\.snoozy\keystore.properties`, and run `gradlew.bat -p C:\s\android :app:assembleRelease -PreactNativeArchitectures=arm64-v8a` with JDK 17 (`C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot`).
- Build result: JS bundle pass `Android Bundled 29788ms` (2171 modules); signed release pass `BUILD SUCCESSFUL in 1m 37s`.
- Artifact: `artifacts/snoozy-arm64-release-v2.3.apk`
  - Size: `54,683,139` bytes
  - SHA-256: `BB5368BA36F225DCA3D6B6E56E2ED2FF0FCE15BE63689ED0870625C29F32622C`
  - Manifest: `com.snoozy.app`, version `2.3.0`, versionCode `13`, SDK 24-36, native code `arm64-v8a` only.
- Device verification on Oppo A55 (`CPH2325`, Android 13, `9PGE8SQKAM598PBY`): installed over `com.snoozy.app` with `adb install -r` (`Success`). Verified Home, Search, Library, Playlists, and Settings scroll/reverse, compact title bars on Album, Artist, Genre, and Playlist screens with working back buttons, full Player artwork scroll scale and header drag-to-dismiss (snap-back below 120 dp and dismiss above threshold), `QueueSheet` and `AddToPlaylistSheet` grabber drag-to-dismiss and list scrolling, Glasmio Apache-2.0 attribution in Settings, and zero crashes in `logcat -b crash`. Evidence stored under `artifacts/audit/v2.3/`.

## v2.2 (2.2.0, versionCode 12) — released and audited

- Intent: complete the v2.1 visual reset with a live semantic theme, shared
  layout primitives, immediate tab switches, one persistent mini-player above
  the tab bar, five equal Library segments, and compact grouped rows.
- App version `2.2.0`; Android `versionCode` `12`; package `com.snoozy.app`.
  `userInterfaceStyle` is `automatic` so Light, Dark, and Auto can all work.
- Design and execution references:
  `docs/superpowers/specs/2026-10-23-snoozy-visual-system-v2.2-design.md` and
  `docs/superpowers/plans/2026-10-23-snoozy-visual-system-v2.2.md`.
- Runtime audit: `docs/AUDIT-v2.2.md`.
- Build environment: sync the JS tree to `C:\s`, prebuild Android with
  `npx expo prebuild --platform android --no-install`, use JDK 17
  (`C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot`), and build
  `arm64-v8a` only with the existing release keystore.
- Static gates: `npx tsc --noEmit`, `npx eslint src --no-cache`, and
  `npx expo-doctor`. At the package bump, typecheck and lint passed;
  expo-doctor passed 19/20 checks with only the known patch-level mismatches
  for `expo`, `expo-asset`, `expo-constants`, `expo-linking`, `expo-router`,
  `expo-splash-screen`, and `expo-status-bar`. Unrelated findings block the
  build.
- Release command:
  `gradlew.bat -p C:\s\android assembleRelease -PreactNativeArchitectures=arm64-v8a`
  after removing stale `*.bundle` files. Export the four
  `SNOOZY_KEYSTORE_*` environment variables from the private
  `C:\Users\Administrator\.snoozy\keystore.properties` before invoking
  Gradle; otherwise the generated APK is debug-signed. Stop any existing
  Gradle daemon or build with `--no-daemon` so the signing environment is
  inherited.
- Build result (2026-10-23, final post-verification fixes): JS bundle pass
  `Android Bundled 34389ms` (1741 modules); signed release pass
  `BUILD SUCCESSFUL in 2m 1s`, 1017 actionable tasks (32 executed, 985
  up-to-date). The extra module is `AppDialog`. Final build log:
  `C:\Users\Administrator\AppData\Local\Temp\opencode\build-v2.2-dialogfix.log`.
- Artifact: `artifacts/snoozy-arm64-release-v2.2.apk`
  - Size: `51,870,098` bytes
  - SHA-256: `AED3C60B539EA609C94DF28CC6B6DD6226EC706F162FF9DB2C06E21C916D10AE`
  - Manifest: `com.snoozy.app`, version `2.2.0`, versionCode `12`, SDK 24–36,
    native code `arm64-v8a` only.
  - Signature: APK Signature Scheme v2 verified; certificate
    `CN=Snoozy Release, OU=M0, O=Snoozy, L=Local, ST=Local, C=US`; RSA 2048.
  - `zipalign -c 4`: `Verification successful`.
  - JS bundle: `3,545,384` chars; contains the post-fix markers
    `Close dialog` and `no-hide-descendants` as well as the v2.2 markers
    (`Backdrop glow`, `Palette style`, `Accent swatch`, `Theme, motion, and
    library`, `2.2.0`).
- Superseded pre-fix artifact (numbers retained for traceability):
  `51,866,290` bytes; SHA-256
  `13F6DA0FE328A56EB643D896989A58F75CC4602E26AA75047FCE44FF8539ACCD`;
  1740 modules. The final artifact above is promoted over it.
- Install: `adb install -r` of the signed final APK reported `Success` over
  the existing release install at `2.2.0` / `12`.
- Device: Oppo CPH2325, Android 13, 720×1600 at density 320. USB ADB
  re-enumerated when the screen slept, so wireless ADB at
  `192.168.1.9:5555` is the primary test transport.
- Runtime theme matrix, tab-continuity, Library-bounds, playback, dialogs,
  swipe rails, and frame evidence are recorded in `docs/AUDIT-v2.2.md`.
- The provisional v2.1 APK is superseded by this release.

## v1.8 (final, canonical)

- APK: `artifacts/snoozy-arm64-release.apk` (canonical; v1.7 preserved as `snoozy-arm64-release-v1.7.apk`).
- Size: `51,803,434` bytes
- SHA-256: `384394C336074CFEB9CE71603E4B2E240E602369BB49987B34CBD16DAB94E7CF`
- Package: `com.snoozy.app`; version `1.8.0` (versionCode `8`); ABI `arm64-v8a` only.
- Signature: APK Signature Scheme v2 verified (`CN=Snoozy Release`); `zipalign -c 4` successful.
- Command: sync repo -> `C:\s`, delete stale `*.bundle` under `C:\s\android\app\build`, then
  `gradlew.bat -p C:\s\android assembleRelease -PreactNativeArchitectures=arm64-v8a`.
- Result: BUILD SUCCESSFUL in 1m 25s (32 executed tasks); JS bundle `3,484,584` bytes with the v1.8 strings verified.
- TypeScript 0 errors; lint 0 errors (4 pre-existing `PlayerContext` warnings).
- Installed on device with `adb install -r` over wireless ADB (Success); versionName 1.8.0 / build 8 confirmed.
- Runtime audit passed: screenshots `78-107`, v1.7 rows 13/25/26/28/29, regression reruns, fps traces. See `docs/AUDIT-v1.8.md`.
- **Build-tree layout:** the JS project root is `C:\s` (package.json, app.json, src, assets). The native project is `C:\s\android`. Sync sources to `C:\s\src` and `C:\s\app.json` - NOT into `C:\s\android\src`.
- **Stale-bundle pitfall:** Gradle can keep/restore an old `index.android.bundle`. Always delete `*.bundle` under `C:\s\android\app\build` before building and confirm a new marker string inside the APK bundle before packaging.
- **Device note:** USB ADB on this handset repeatedly re-enumerated/offline; the audit used wireless ADB at `192.168.1.9:5555` (`adb connect`, reconnect after drops).

## v1.7

## Final artifact (rebuilt after the audit's defect fixes — canonical)

- APK: `artifacts/snoozy-arm64-release.apk`
- Size: `51,792,122` bytes
- SHA-256: `0F65200829F63FAC746078542CF530FA5528A10F6AF8471DC1423652BD0DF533`
- Package: `com.snoozy.app`
- Version: `1.7.0` (versionCode `7`)
- ABI: `arm64-v8a` only
- minSdk / targetSdk / compileSdk: `24` / `36` / `37`
- Signature: APK Signature Scheme v2 verified (CN=Snoozy Release)
- zipalign: successful
- Installed on device with `adb install -r` (Success); versionName 1.7.0 / build 7 confirmed on device.

## Rebuild (defect-fix batch)

- Command: incremental `gradlew.bat assembleRelease -PreactNativeArchitectures=arm64-v8a` (sync `src/` + `assets/` from the repo into the build tree first).
- Result: BUILD SUCCESSFUL in 2m 27s (32 executed tasks).
- TypeScript: `npx tsc --noEmit` passed (0 errors) after the fixes.
- Lint: `npx expo lint` passed (0 errors, 9 pre-existing warnings).
- This APK is the audit's `PASS (rebuilt)` artifact — see `docs/AUDIT-v1.7.md` evidence 60–76.

## Original audit-walk build (superseded)

- Size: `51,791,742` bytes
- SHA-256: `EAE2CF231E155105C4644D11A3A172D29EC0B7A4F219587D16745B829AE3156A`
- Command: `npx expo prebuild --platform android --clean --no-install` then `gradlew assembleRelease -PreactNativeArchitectures=arm64-v8a`
- Result: BUILD SUCCESSFUL in 17m 51s (1017 actionable tasks).

## Verification

- Static verification: tsc + lint + signed release build pass.
- Device verification on Oppo A55 4G (Android 13): install, launch, and the full runtime audit are recorded in `docs/AUDIT-v1.7.md`.
