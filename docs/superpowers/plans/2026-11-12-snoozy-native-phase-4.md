# Snoozy Native Phase 4: Playback Engine and Surface Wiring

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the Media3 ExoPlayer playback engine inside `MediaSessionService`, persist and restore `session.v1` and `queueIds` in `snoozy.playback.v1`, record `recents`, `play_history`, and `listening_sessions`, expose media notification and hardware media controls, and wire row playback, collection Play and Shuffle actions, track queue/playlist menus, and the floating MiniPlayer across the app.

**Architecture:** Pure queue, repeat, shuffle, speed, and listen-threshold functions live in `playback/PlaybackQueueOps.kt` with JVM unit tests. `SnoozyDatabases` and `LibraryRepository` gain thread-safe write paths for `play_history`, `listening_sessions`, and `recents`. `PlaybackController` owns the Media3 `ExoPlayer` and `MediaSession` on the main thread, binds `SnoozyPlaybackService` (`MediaSessionService`) so Media3 manages foreground notification and system media controls, throttles position writes to once per 5 seconds plus pause/stop/task-removal flushes, and publishes `StateFlow<State>` and a separate `StateFlow<Progress>`. UI screens consume `LocalPlaybackController` to trigger playback, manage queue and playlist additions, and render `SnoozyMiniPlayer` above the navigation bar.

**Tech Stack:** Kotlin 2.4.21, Compose BOM 2026.09.00, Glasmio 0.1.2, Navigation3 1.2.0, Media3 ExoPlayer and MediaSession 1.11.0, Coil 3.6.3, MMKV 2.4.3, JUnit 4.

**Spec:** `docs/superpowers/specs/2026-11-11-snoozy-native-glasmio-design.md`

## Global Constraints

- Application ID `com.snoozy.app`, version 3.0.0, versionCode 14, minSdk 33, compile and target SDK 37, arm64-v8a only.
- Glasmio 0.1.2 is the UI foundation. Use `GlasmioBottomSheet`, `GlasmioActionSheetContent`, `GlasmioListRow`, `GlasmioTextField`, `GlasmioButton`, `GlasmioIconButton`, and `GlassSurface` before writing custom chrome.
- Reduce Transparency stays the default. Full glass stays opt-in and is out of Phase 4.
- Preserve the emerald accent, Bricolage Grotesque, Atkinson Hyperlegible, Feather icons, 44 dp and 48 dp touch targets, accessible labels, portrait orientation, and reduced motion.
- No SF Pro, no SF Symbols assets, no emojis, no Latin abbreviations, no em dashes.
- No playback control is decorative. Full-screen `Player`, queue sheet, and lyrics sheet belong to Phase 5; favorites write-through belongs to Phase 6. Do not add a dead favorite action to track menus or a dead player navigation click on the MiniPlayer info area in Phase 4.
- Never uninstall the installed app. SQLite files and MMKV stores stay in place.
- Destructive or mutating device verification tests must back up the raw MMKV and SQLite files with `cmd.exe` binary redirection, verify the feature, and restore the preserved user data afterward.
- Every new non-trivial branch or list operation gets a JVM test. Run `gradlew.bat :app:assembleDebug :app:testDebugUnitTest :app:lintDebug` before the device gate.

## Scope

This plan covers:

- Media3 `ExoPlayer` and `MediaSession` in `SnoozyPlaybackService` (`MediaSessionService`).
- Audio focus (`C.USAGE_MEDIA`, `C.AUDIO_CONTENT_TYPE_MUSIC`, `handleAudioFocus = true`) and noisy intent handling (`setHandleAudioBecomingNoisy(true)`).
- Queue operations: `playTrack`, `togglePlayback`, `pause`, `next`, `previous` (restart when position exceeds 3 seconds), `seekTo`, `playNext`, `addToQueue`, `removeQueueItem`, `moveQueueItem`, `clearQueue`, `playQueueItem`.
- Repeat (`off`, `all`, `one`), shuffle, and playback speed (`0.5` to `2.0`) state and persistence in `snoozy.playback.v1`.
- Cold-start restoration and 5-second throttled persistence of `session.v1` and `queueIds` in `snoozy.playback.v1`, plus immediate flushes on pause, stop, media transition, seek, and task removal.
- Play history writes to `snoozy_playhistory.db` (`play_history`), listening session writes to `snoozy.db` (`listening_sessions`), and `recents` writes to `snoozy.music.v1`.
- Media notification with artwork and transport controls, lock screen controls, and hardware media key handling.
- `SnoozyMiniPlayer` above the root navigation bar with artwork, title, artist, Play/Pause, and Next controls.
- Track action sheets (`Play next`, `Add to queue`, `Add to playlist`) and `AddToPlaylistSheet` (select existing playlist or create a new playlist).
- Row playback and collection `Play` and `Shuffle` actions across Home, Library, Album, Artist, Genre, and Playlist screens.

This plan does not cover:

- Full-screen `Player` route, seek scrubbing UI, speed sheet, queue reorder sheet, and synced lyrics sheet (Phase 5).
- Search, metadata override editing, and favorites write-through (Phase 6).
- Settings, diagnostics, and full glass mode (Phase 7).

## React Native Parity References

- Playback context and session lifecycle: `src/playback/PlayerContext.tsx` lines 60 to 930.
- Engine configuration and repeat modes: `src/playback/player.ts` lines 1 to 96.
- Queue helpers: `src/playback/queue.ts` lines 1 to 84.
- Repeat and random start index helpers: `src/playback/controls.ts` lines 1 to 17.
- Session parse, resolve, and save: `src/playback/session.ts` lines 1 to 205 and `android-native/app/src/main/java/com/snoozy/app/data/playback/PlaybackSessionLogic.kt`.
- Play history SQLite writes: `src/storage/playHistory.ts` lines 10 to 35.
- Listening session SQLite writes: `src/storage/history.ts` lines 21 to 78.
- Recents prepend: `src/storage/MusicLibraryContext.tsx` lines 492 to 498.
- MiniPlayer bar: `src/components/MiniPlayer.tsx` lines 44 to 131.
- Add to playlist sheet: `src/components/AddToPlaylistSheet.tsx` lines 34 to 188.
- Home playback cards: `src/app/(tabs)/index.tsx` lines 131 to 147 and 296 to 359.
- Library song row, favorite shuffle, and track menu: `src/app/(tabs)/library.tsx` lines 210 to 276, 387 to 397, 643 to 650, and 764 to 811.
- Album, artist, genre, and playlist Play and Shuffle actions: `src/app/album.tsx` lines 66 to 71 and 114 to 155, `src/app/artist.tsx` lines 46 to 51 and 85 to 140, `src/app/genre.tsx` lines 68 to 84, `src/app/playlist.tsx` lines 57 to 62, 151 to 192, and 260 to 297.

## Review Focus

- Cold-start restore safety: restoring `session.v1` must prepare the queue and seek to the saved position while remaining paused (`playWhenReady = false`), and must not overwrite `session.v1` with an empty queue before library tracks load.
- Corrupt store safety: `recentsForUpdate()` uses the strict MMKV reader so an unreadable store throws `StoreFailureException` instead of overwriting `recents` with an empty list.
- SQLite read-write safety: writing `play_history` or `listening_sessions` closes any cached read-only `SQLiteDatabase` handle for that file first so subsequent reads observe the committed rows.
- File URI playback: `Track.uri` values stored as unencoded `file:///storage/...` paths must convert through `Uri.fromFile(File(path))` when the file exists, with a MediaStore content URI fallback (`content://media/external/audio/media/<id>`) when a numeric MediaStore track path is unreadable.
- Queue deduplication: `addToQueue` is a no-op when the track ID is already in the queue; `playNext` moves an existing non-active track immediately after the active track instead of duplicating it, and is a no-op when the track is already active.
- Progress isolation: 1-second playback position updates emit on `PlaybackController.progress`, not `PlaybackController.state`, so list screens do not recompose every second during playback.

---

### Task 1: Pure Playback Queue, Repeat, Speed, and History Helpers

**Files:**
- Create: `android-native/app/src/main/java/com/snoozy/app/playback/PlaybackQueueOps.kt`
- Test: `android-native/app/src/test/java/com/snoozy/app/playback/PlaybackQueueOpsTest.kt`

**Interfaces:**
- Produces: `enum class RepeatState(val storageValue: String)` with `Off("off")`, `All("all")`, `One("one")`, `fun next(): RepeatState`, and `RepeatState.fromStored(value: String?): RepeatState`.
- Produces: `data class QueueEntry(val mediaId: String, val title: String, val artist: String, val artwork: String?)`.
- Produces: `data class PlayNextMutation(val ids: List<String>, val insertIndex: Int, val removeIndex: Int)`.
- Produces: `object PlaybackQueueOps` with:
  - `randomStartIndex(length: Int, randomDouble: () -> Double = { Random.nextDouble() }): Int`
  - `clampPlaybackSpeed(rate: Double): Float`
  - `shouldRestartOnPrevious(positionMs: Long): Boolean`
  - `appendUnique(ids: List<String>, id: String): List<String>`
  - `playNextOrder(ids: List<String>, activeIndex: Int, id: String): PlayNextMutation`
  - `moveItem(items: List<T>, from: Int, to: Int): List<T>`
  - `removeItemAt(items: List<T>, index: Int): List<T>`
  - `prependRecent(recents: List<String>, trackId: String, limit: Int = 30): List<String>`
  - `shouldRecordPlay(durationSeconds: Double, maxPositionMs: Long): Boolean`
  - `queueEntryFor(track: Track): QueueEntry`

- [ ] **Step 1: Write the failing unit tests**

Create `PlaybackQueueOpsTest.kt` covering repeat state cycling and parsing, random start index bounds, playback speed clamping, previous-track restart threshold, unique queue append, play-next insertion and relocation, move and remove bounds, recents deduplication and cap, and play-history threshold calculation.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `gradlew.bat :app:testDebugUnitTest --tests "com.snoozy.app.playback.PlaybackQueueOpsTest"`

Expected: compilation fails because `PlaybackQueueOps` does not exist.

- [ ] **Step 3: Implement `PlaybackQueueOps.kt`**

Mirror the React Native behavior in `src/playback/controls.ts`, `src/playback/queue.ts`, `src/playback/PlayerContext.tsx`, and `src/storage/MusicLibraryContext.tsx`. Return the input list instance when a list transform is a no-op.

- [ ] **Step 4: Run the tests to verify they pass**

Run the Step 2 command. Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add android-native/app/src/main/java/com/snoozy/app/playback/PlaybackQueueOps.kt android-native/app/src/test/java/com/snoozy/app/playback/PlaybackQueueOpsTest.kt
git commit -m "feat(native): add pure playback queue and control helpers"
```

---

### Task 2: History, Listening Session, and Recents Store Writes

**Files:**
- Modify: `android-native/app/src/main/java/com/snoozy/app/data/mmkv/SnoozyStores.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/data/db/SnoozyDatabases.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/data/library/LibraryRepository.kt`

**Interfaces:**
- Produces: `SnoozyStores.recentsForUpdate(): List<String>`.
- Produces: `SnoozyStores.clearQueueIds(): Boolean`.
- Produces: `SnoozyDatabases.recordPlayHistory(trackId: String, playedAt: Long, durationListenedMs: Long): Boolean`.
- Produces: `SnoozyDatabases.startListeningSession(trackId: String, startedAt: Long): Long?`.
- Produces: `SnoozyDatabases.finishListeningSession(sessionId: Long, endedAt: Long, durationSeconds: Long): Boolean`.
- Produces: `suspend fun LibraryRepository.recordRecent(trackId: String): Boolean`.
- Produces: `suspend fun LibraryRepository.recordPlay(trackId: String, durationListenedMs: Long, playedAt: Long = System.currentTimeMillis()): Boolean`.

- [ ] **Step 1: Add `recentsForUpdate()` and `clearQueueIds()` to `SnoozyStores.kt`**

Use `readListForUpdate(MUSIC, RECENTS, String.serializer())` for `recentsForUpdate()` and `writeStore(PLAYBACK) { it.removeValueForKey(QUEUE_IDS) }` for `clearQueueIds()`.

- [ ] **Step 2: Add SQLite write helpers to `SnoozyDatabases.kt`**

Add `recordPlayHistory`, `startListeningSession`, and `finishListeningSession`. Before opening `PLAY_HISTORY_DB` or `LIBRARY_DB` with `SQLiteDatabase.OPEN_READWRITE | SQLiteDatabase.CREATE_IF_NECESSARY`, evict and close any cached read-only handle from `opened`. Create the table if missing using the exact React Native schema (`play_history` in `snoozy_playhistory.db` and `listening_sessions` in `snoozy.db`), execute the insert or update with `ContentValues`, and return `false` or `null` on failure without throwing.

- [ ] **Step 3: Add `recordRecent` and `recordPlay` to `LibraryRepository.kt`**

Under `mutationMutex` on `Dispatchers.IO`:
- `recordRecent(trackId)` reads `stores.recentsForUpdate()`, transforms with `PlaybackQueueOps.prependRecent(current, trackId)`, writes `stores.saveRecents(next)` when changed, and updates `_state` with the new `recents`.
- `recordPlay(trackId, durationListenedMs, playedAt)` writes `databases.recordPlayHistory(trackId, playedAt, durationListenedMs)`, reloads `databases.playHistory()`, and updates `_state` with the fresh `history`.

- [ ] **Step 4: Run unit tests and assemble debug**

Run: `gradlew.bat :app:testDebugUnitTest :app:assembleDebug`

Expected: build succeeds and all unit tests pass.

- [ ] **Step 5: Commit**

```bash
git add android-native/app/src/main/java/com/snoozy/app/data/mmkv/SnoozyStores.kt android-native/app/src/main/java/com/snoozy/app/data/db/SnoozyDatabases.kt android-native/app/src/main/java/com/snoozy/app/data/library/LibraryRepository.kt
git commit -m "feat(native): add play history, listening session, and recents writes"
```

---

### Task 3: Media3 Dependencies, MediaItem Mapping, Playback Service, and Controller

**Files:**
- Modify: `android-native/app/build.gradle.kts`
- Modify: `android-native/app/src/main/AndroidManifest.xml`
- Create: `android-native/app/src/main/java/com/snoozy/app/playback/MediaItemMapper.kt`
- Create: `android-native/app/src/main/java/com/snoozy/app/playback/PlaybackController.kt`
- Create: `android-native/app/src/main/java/com/snoozy/app/playback/SnoozyPlaybackService.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/AppContainer.kt`
- Test: `android-native/app/src/test/java/com/snoozy/app/playback/MediaItemMapperTest.kt`

**Interfaces:**
- Produces: `object MediaItemMapper` with:
  - `resolveFilePath(rawUri: String): String?`
  - `isNumericMediaStoreId(id: String): Boolean`
  - `mediaStoreContentUriString(id: String): String`
  - `playbackUriFor(track: Track, fileExists: (String) -> Boolean = { File(it).canRead() }): Uri`
  - `mediaItemFor(track: Track): MediaItem`
- Produces: `class PlaybackController(context: Context, stores: SnoozyStores, databases: SnoozyDatabases, repository: LibraryRepository)` with:
  - `data class State(val ready: Boolean = false, val activeTrack: Track? = null, val isPlaying: Boolean = false, val queueItems: List<QueueEntry> = emptyList(), val queueIndex: Int = -1, val repeatMode: RepeatState = RepeatState.Off, val shuffle: Boolean = false, val playbackRate: Float = 1.0f, val error: String? = null)`
  - `data class Progress(val positionSeconds: Double = 0.0, val durationSeconds: Double = 0.0)`
  - `val state: StateFlow<State>`
  - `val progress: StateFlow<Progress>`
  - `fun getOrCreateSession(): MediaSession`
  - `fun onTaskRemoved()`
  - `fun playTrack(track: Track, queue: List<Track> = emptyList(), shuffleOverride: Boolean? = null, repeatOverride: RepeatState? = null)`
  - `fun togglePlayback()`
  - `fun pause()`
  - `fun next()`
  - `fun previous()`
  - `fun seekTo(seconds: Double)`
  - `fun playNext(track: Track)`
  - `fun addToQueue(track: Track)`
  - `fun removeQueueItem(index: Int)`
  - `fun moveQueueItem(from: Int, to: Int)`
  - `fun clearQueue()`
  - `fun playQueueItem(index: Int)`
  - `fun cycleRepeat()`
  - `fun setShuffle(enabled: Boolean)`
  - `fun toggleShuffle()`
  - `fun setPlaybackRate(rate: Double)`
  - `fun clearError()`
- Produces: `class SnoozyPlaybackService : MediaSessionService()`.
- Produces: `AppContainer.playbackController: PlaybackController`.

- [ ] **Step 1: Write the failing `MediaItemMapperTest.kt`**

Test `resolveFilePath`, `isNumericMediaStoreId`, and `mediaStoreContentUriString` on the JVM.

- [ ] **Step 2: Run the test to verify it fails**

Run: `gradlew.bat :app:testDebugUnitTest --tests "com.snoozy.app.playback.MediaItemMapperTest"`

Expected: compilation fails because `MediaItemMapper` does not exist.

- [ ] **Step 3: Add Media3 dependencies, manifest declarations, mapper, service, and controller**

1. In `android-native/app/build.gradle.kts`, add:
   - `implementation("androidx.media3:media3-exoplayer:1.11.0")`
   - `implementation("androidx.media3:media3-session:1.11.0")`
2. In `android-native/app/src/main/AndroidManifest.xml`, add `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permissions and register `.playback.SnoozyPlaybackService` with `android:foregroundServiceType="mediaPlayback"` and `MediaSessionService` intent filter.
3. Implement `MediaItemMapper.kt`, `PlaybackController.kt`, `SnoozyPlaybackService.kt`, and wire `playbackController` in `AppContainer.kt`.

- [ ] **Step 4: Run unit tests, lint, and assemble debug**

Run: `gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug`

Expected: all tests pass, 0 lint errors, APK builds cleanly.

- [ ] **Step 5: Commit**

```bash
git add android-native/app/build.gradle.kts android-native/app/src/main/AndroidManifest.xml android-native/app/src/main/java/com/snoozy/app/AppContainer.kt android-native/app/src/main/java/com/snoozy/app/playback/MediaItemMapper.kt android-native/app/src/main/java/com/snoozy/app/playback/PlaybackController.kt android-native/app/src/main/java/com/snoozy/app/playback/SnoozyPlaybackService.kt android-native/app/src/test/java/com/snoozy/app/playback/MediaItemMapperTest.kt
git commit -m "feat(native): add Media3 playback service and controller"
```

---

### Task 4: MiniPlayer, Track Menus, Add to Playlist Sheet, and Active Row Styling

**Files:**
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/icons/SnoozyIcons.kt`
- Create: `android-native/app/src/main/java/com/snoozy/app/ui/navigation/LocalPlaybackController.kt`
- Create: `android-native/app/src/main/java/com/snoozy/app/ui/components/SnoozyMiniPlayer.kt`
- Create: `android-native/app/src/main/java/com/snoozy/app/ui/components/AddToPlaylistSheet.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/components/PlaylistSheets.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/components/SnoozyRows.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/components/SnoozyPage.kt`

**Interfaces:**
- Produces: `SnoozyIcons.Shuffle`, `SnoozyIcons.Repeat`, `SnoozyIcons.FastForward`.
- Produces: `LocalPlaybackController: ProvidableCompositionLocal<PlaybackController>`.
- Produces: `SnoozyMiniPlayer(track: Track, isPlaying: Boolean, onTogglePlay: () -> Unit, onNext: () -> Unit, modifier: Modifier = Modifier)`.
- Produces: `AddToPlaylistSheet(track: Track, playlists: List<Playlist>, onAddToPlaylist: (playlistId: String) -> Unit, onCreateAndAdd: suspend (name: String) -> String?, onDismiss: () -> Unit)`.
- Produces: `TrackActionsSheet(track: Track, onPlayNext: () -> Unit, onAddToQueue: () -> Unit, onAddToPlaylist: () -> Unit, onDismiss: () -> Unit)`.
- Modifies: `PlaylistTrackActionsSheet` to include `onPlayNext: (() -> Unit)? = null` and `onAddToQueue: (() -> Unit)? = null` above `Move up` and `Move down`.
- Modifies: `SnoozyTrackRow` to accept `active: Boolean = false` and tint `titleColor` with `LocalGlassColors.current.accent` when active.
- Produces: `SnoozyCollectionActions(onPlay: () -> Unit, onShuffle: () -> Unit, playLabel: String, shuffleLabel: String, enabled: Boolean = true, trailing: (@Composable () -> Unit)? = null)`.
- Modifies: `SnoozyGridPage` to add `MiniPlayerBottomSpace` (`76.dp`) when `LocalPlaybackController` has a non-null `activeTrack`.

- [ ] **Step 1: Add icons and `LocalPlaybackController`**

Add `Shuffle`, `Repeat`, and `FastForward` in `SnoozyIcons.kt` (and map `"shuffle"` and `"repeat"` in `SnoozyIconResolver`). Create `LocalPlaybackController.kt` plus `LocalHasActiveTrack = compositionLocalOf { false }` so `SnoozyGridPage` can reserve bottom padding without requiring `LocalPlaybackController` in isolated previews.

- [ ] **Step 2: Create `SnoozyMiniPlayer.kt` and `AddToPlaylistSheet.kt`, and update `PlaylistSheets.kt`, `SnoozyRows.kt`, and `SnoozyPage.kt`**

- `SnoozyMiniPlayer` renders a floating Glasmio card (`64.dp` min height, `20.dp` continuous rounded corners) with `SnoozyArtwork(track.artwork, 44.dp, 12.dp, null)`, single-line title and artist, and two `44.dp` `SnoozyIconAction` buttons (`Pause` or `Play`, and `Next track`).
- `AddToPlaylistSheet` matches `src/components/AddToPlaylistSheet.tsx`: header with `"Add to playlist"`, quoted track title, and `"Close"` button; list of playlists showing `Check` and `"Added"` once tapped (or already containing the track) or `Plus` and track count; bottom create row with `GlasmioTextField` (`"New playlist name"`) and `GlasmioButton` (`"Create"`).
- `TrackActionsSheet` in `PlaylistSheets.kt` offers `"Play next"`, `"Add to queue"`, `"Add to playlist"`, and `"Cancel"`.
- `PlaylistTrackActionsSheet` in `PlaylistSheets.kt` adds `"Play next"` and `"Add to queue"` above `"Move up"`.
- `SnoozyTrackRow` highlights `titleColor` when `active` is true, and `SnoozyCollectionActions` renders the `Play` and `Shuffle` button row for detail screens.

- [ ] **Step 3: Run unit tests, lint, and assemble debug**

Run: `gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug`

Expected: build succeeds with 0 lint errors.

- [ ] **Step 4: Commit**

```bash
git add android-native/app/src/main/java/com/snoozy/app/ui/icons/SnoozyIcons.kt android-native/app/src/main/java/com/snoozy/app/ui/navigation/LocalPlaybackController.kt android-native/app/src/main/java/com/snoozy/app/ui/components/SnoozyMiniPlayer.kt android-native/app/src/main/java/com/snoozy/app/ui/components/AddToPlaylistSheet.kt android-native/app/src/main/java/com/snoozy/app/ui/components/PlaylistSheets.kt android-native/app/src/main/java/com/snoozy/app/ui/components/SnoozyRows.kt android-native/app/src/main/java/com/snoozy/app/ui/components/SnoozyPage.kt
git commit -m "feat(native): add mini player, track action sheets, and add-to-playlist sheet"
```

---

### Task 5: Screen Playback Wiring Across Home, Library, Detail Screens, and Scaffold

**Files:**
- Modify: `android-native/app/src/main/java/com/snoozy/app/MainActivity.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/navigation/SnoozyApp.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/screens/HomeScreen.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/screens/LibraryScreen.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/screens/AlbumScreen.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/screens/ArtistScreen.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/screens/GenreScreen.kt`
- Modify: `android-native/app/src/main/java/com/snoozy/app/ui/screens/PlaylistScreen.kt`

**Interfaces:**
- Modifies: `SnoozyApp(repository: LibraryRepository, playbackController: PlaybackController, onExit: () -> Unit)` to provide `LocalPlaybackController` and `LocalHasActiveTrack`, and stack `SnoozyMiniPlayer` above `GlasmioNavigationBar`.
- Modifies: `HomeScreen`, `LibraryScreen`, `AlbumScreen`, `ArtistScreen`, `GenreScreen`, and `PlaylistScreen` to wire playback, shuffle, and track menus.

- [ ] **Step 1: Wire `MainActivity.kt` and `SnoozyApp.kt`**

- Pass `container.playbackController` from `MainActivity` to `SnoozyApp`.
- Request `POST_NOTIFICATIONS` once when `notificationsAsked()` is false, then persist `savePreferences(stores.haptics(), true)`.
- In `SnoozyApp`, collect `playbackController.state`, provide `LocalPlaybackController` and `LocalHasActiveTrack`, and render `SnoozyMiniPlayer` above `GlasmioNavigationBar` when `activeTrack != null`.

- [ ] **Step 2: Wire Home, Library, Album, Artist, Genre, and Playlist screens**

- `HomeScreen`:
  - Show playback error banner if `playbackState.error != null` with `playbackController.clearError()`.
  - Tapping a `Recently played` card calls `playbackController.playTrack(track, recentTracks)` with `contentDescription = "Play ${track.title}"`.
  - Tapping a `Most played` card calls `playbackController.playTrack(played.track, mostPlayed.map { it.track })` with `contentDescription = "Play ${played.track.title}"`.
  - Add the Home `Library` section (`Shuffle all songs` row that starts shuffled playback of `state.tracks`) matching `src/app/(tabs)/index.tsx` lines 434 to 448.
- `LibraryScreen`:
  - Show playback error banner when `playbackState.error != null`.
  - In `Songs` and `Favorites` tabs, tapping a `SnoozyTrackRow` plays that track with `songs` or `favorites` as the queue; `active = playbackState.activeTrack?.id == track.id`; trailing `SnoozyIconAction(SnoozyIcons.More, "Manage ${track.title}")` opens `TrackActionsSheet` (`Play next`, `Add to queue`, `Add to playlist`).
  - Choosing `Add to playlist` opens `AddToPlaylistSheet` for that track.
  - In `Favorites` tab toolbar, render a `Shuffle` button when `favorites.isNotEmpty()` that starts shuffled playback of `favorites`.
- `AlbumScreen`:
  - Add `SnoozyCollectionActions` (`Play` with `"Play album"` and `Shuffle` with `"Shuffle album"`) below the album artwork.
  - Tapping a track row calls `playbackController.playTrack(track, tracks)` and highlights `active`.
- `ArtistScreen`:
  - Add `SnoozyCollectionActions` (`Play` with `"Play $title"` and `Shuffle` with `"Shuffle $title"`) at the top of the artist content.
  - Tapping a song row calls `playbackController.playTrack(track, tracks)` and highlights `active`.
- `GenreScreen`:
  - Add `SnoozyCollectionActions` (`Play` with `"Play $title"` and `Shuffle` with `"Shuffle $title"`) above the songs section.
  - Tapping a song row calls `playbackController.playTrack(track, tracks)` and highlights `active`.
- `PlaylistScreen`:
  - Replace the lone `Add songs` button in `playlist-actions` with `SnoozyCollectionActions` (`Play` with `"Play playlist"`, `Shuffle` with `"Shuffle playlist"`, both `enabled = tracks.isNotEmpty()`, plus trailing `Add songs` button).
  - Tapping a song row calls `playbackController.playTrack(track, tracks)` and highlights `active`.
  - Wire `onPlayNext` and `onAddToQueue` in `PlaylistTrackActionsSheet`.

- [ ] **Step 3: Run unit tests, lint, and assemble debug**

Run: `gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug`

Expected: all tests pass, 0 lint errors, APK builds cleanly.

- [ ] **Step 4: Commit**

```bash
git add android-native/app/src/main/java/com/snoozy/app/MainActivity.kt android-native/app/src/main/java/com/snoozy/app/ui/navigation/SnoozyApp.kt android-native/app/src/main/java/com/snoozy/app/ui/screens/HomeScreen.kt android-native/app/src/main/java/com/snoozy/app/ui/screens/LibraryScreen.kt android-native/app/src/main/java/com/snoozy/app/ui/screens/AlbumScreen.kt android-native/app/src/main/java/com/snoozy/app/ui/screens/ArtistScreen.kt android-native/app/src/main/java/com/snoozy/app/ui/screens/GenreScreen.kt android-native/app/src/main/java/com/snoozy/app/ui/screens/PlaylistScreen.kt
git commit -m "feat(native): wire playback across home, library, detail screens, and mini player"
```

---

### Task 6: Full Gate, Device Verification on Oppo A55, and Build Records

**Files:**
- Modify: `docs/BUILD.md`
- Modify: `docs/superpowers/plans/2026-11-11-snoozy-native-glasmio-roadmap.md`
- Modify: `docs/superpowers/plans/2026-11-12-snoozy-native-phase-4.md`
- Create: `.superpowers/sdd/2026-11-12-snoozy-native-phase-4/progress.md`

- [ ] **Step 1: Run the full static gate**

Run: `gradlew.bat :app:assembleDebug :app:testDebugUnitTest :app:lintDebug`

Verify 0 test failures, 0 lint errors, and release keystore signature `0b3acae8b73999d871c4f18684e70fc32967fada05967f9d18a463b37fe755ce`.

- [ ] **Step 2: Back up preserved stores and install over the current build**

Back up `snoozy.music.v1`, `snoozy.music.v1.crc`, `snoozy.playback.v1`, `snoozy.playback.v1.crc`, `snoozy_playhistory.db`, and `snoozy.db` (plus `-wal` and `-shm`) via `cmd.exe` binary redirection. Run `adb install -r` without uninstalling.

- [ ] **Step 3: Verify cold-start session restoration, playback, MiniPlayer, menus, notification, background screen-off playback, and force-stop restoration on the Oppo A55**

1. Launch `com.snoozy.app/.MainActivity` and verify cold-start session restoration renders `SnoozyMiniPlayer` with the restored track paused.
2. Start playback from Library Songs, verify `SnoozyMiniPlayer` shows `Pause` and `Next track`, and verify `dumpsys media_session` and `dumpsys notification` show the active `SnoozyPlaybackService` media session and `MediaStyle` notification.
3. Test `Play next`, `Add to queue`, and `Add to playlist` from the Library song menu, and verify `Jayzee test` or a temporary playlist receives the song (and clean up any temporary playlist change).
4. Test `Play` and `Shuffle` on Album, Artist, Genre, and Playlist detail screens.
5. Test hardware media key events (`KEYCODE_MEDIA_PAUSE`, `KEYCODE_MEDIA_PLAY`, `KEYCODE_MEDIA_NEXT`, `KEYCODE_MEDIA_PREVIOUS`) and screen-off background playback (`KEYCODE_SLEEP`).
6. Force-stop `com.snoozy.app`, cold-start, and confirm the newly persisted `session.v1` track, queue, and position restore cleanly.
7. Restore the backed-up MMKV and SQLite files via `cmd.exe` binary redirection, restart, and confirm the preserved 37 tracks, 3 albums, `Jayzee test` playlist (`1 track`), `recents=19`, `playHistory=6`, and `listeningSessions=34` are intact.
8. Confirm `adb logcat -b crash -d` is empty.

- [ ] **Step 4: Update build records and commit**

Update `docs/BUILD.md`, `docs/superpowers/plans/2026-11-11-snoozy-native-glasmio-roadmap.md`, `docs/superpowers/plans/2026-11-12-snoozy-native-phase-4.md`, and `.superpowers/sdd/2026-11-12-snoozy-native-phase-4/progress.md`, then commit.
