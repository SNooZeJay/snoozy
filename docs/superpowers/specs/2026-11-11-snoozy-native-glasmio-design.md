# Snoozy Native Glasmio Design

Date: 2026-11-11
Status: approved direction, implementation started
Target: `com.snoozy.app` 3.0.0 (versionCode 14) on Oppo CPH2325 (A55), Android 13 / API 33

## 1. Decision

Snoozy ships as a native Kotlin and Jetpack Compose application built directly on Glasmio `0.1.2`. The React Native application at the repository root stays untouched until native parity is verified on the A55. The native application lives in `android-native/` and keeps the package name, signing key, database files, MMKV stores, and emerald identity.

Glasmio is the UI foundation: theme, typography plumbing, glass materials, scaffold, navigation, lists, sheets, controls, and motion. It is not a visual reference. Snoozy code does not reimplement Glasmio widgets.

## 2. Goals and Acceptance

The release is accepted only when all of these pass on the A55:

- All existing SQLite rows and MMKV keys load without migration loss.
- Scanning, importing, playback, queue, repeat, shuffle, speed, background playback, media notification, and lock screen controls work with real audio.
- Songs, albums, artists, genres, playlists, favorites, search, lyrics, and metadata editing reach parity with the v2.3 React Native app.
- Five root tabs remain: Home, Library, Search, Playlists, Settings.
- Emerald accent `#10B981`, Bricolage Grotesque display type, Atkinson Hyperlegible body type, and Feather icons remain.
- 44 dp icon targets and 48 dp controls remain, with content descriptions on every icon-only control.
- Reduce Transparency is the default. Full glass is an explicit setting with a performance warning.
- Portrait only. No SF Pro fonts or SF Symbols assets ship in the APK.
- Cold start to interactive Home is under 2 seconds. Scroll frame time median stays under 32 ms in Reduce Transparency.
- Release APK is signed with the existing key and installs over 2.3.0 with `adb install -r`.

## 3. Non-goals

- No iOS work.
- No remote streaming, accounts, or cloud sync.
- No new product features beyond v2.3 parity.
- No attempt to make full refraction glass run smoothly on the Helio G35. It is opt-in and may drop frames.

## 4. Toolchain

Verified on this machine with the spike APK installed on the A55:

| Item | Version |
| --- | --- |
| JDK | Temurin 25.0.2 |
| Gradle | 9.6.0 |
| AGP | 9.4.1 with built-in Kotlin and new DSL |
| Kotlin Compose plugin | 2.4.21 |
| Compose BOM | 2026.09.00 |
| Glasmio | `io.github.neoruaa.glasmio:glasmio-scaffold:0.1.2` |
| Feather icons | `br.com.devsrsouza.compose.icons:feather:1.1.1` |
| Navigation3 | 1.2.0, transitively from Glasmio scaffold |
| compileSdk / targetSdk | 37 |
| minSdk | 33 |
| ABI | arm64-v8a only |

Important: the Feather artifact publishes package `compose.icons`, not `br.com.devsrsouza...`. Usage is `FeatherIcons.Home` with imports from `compose.icons.FeatherIcons` and `compose.icons.feathericons.Home`. This is verified by a successful build and rendered icons on the A55.

Glamio scaffold exposes `GlasmioTheme`, `GlasmioNavigationScaffold`, `GlasmioPageBody`, `GlasmioPageTitle`, `GlasmioGroupedList`, `GlasmioListRow`, `GlassSurface`, `GlasmioNavDisplay`, and the backdrop host. The app uses these directly.

## 5. Module Layout

Single Gradle module, `android-native/app`. One module avoids premature boundaries for a 10-screen app.

```
android-native/
  app/src/main/java/com/snoozy/app/
    MainActivity.kt
    SnoozyApplication.kt
    AppContainer.kt
    data/
      db/            SQLite helpers for the five existing files
      mmkv/          typed accessors for the seven existing stores
      library/       MediaStore scan, SAF import, Track, album grouping
      metadata/      overrides, artwork cache, display resolution
      lyrics/        sidecar LRC and ID3 lyric readers
    playback/        controller, queue, session, media session service
    ui/
      theme/         SnoozyColors, SnoozyType, SnoozyTokens, SnoozyTheme
      icons/         Feather aliases and vector wrappers
      components/    rows, headers, empty states, sheets, seek bar
      navigation/    NavKey types, root back stack, header specs
      screens/       home, library, album, artist, genre, playlist, search,
                     player, settings, diagnostics
```

Dependency direction: `ui` depends on `playback` and `data`; `playback` depends on `data`; `data` depends on nothing in `ui`. ViewModels are plain classes with `MutableStateFlow`, created by `AppContainer` and scoped to the activity. No DI framework.

## 6. Glasmio Usage Map

| Snoozy need | Glasmio API |
| --- | --- |
| App theme | `GlasmioTheme(isDark, typography, colors, appearance)` |
| Glass default | `GlassAppearance(reduceTransparency = true)` |
| Full glass opt-in | `GlassAppearance(reduceTransparency = false)` |
| Root and detail navigation | `GlasmioNavigationScaffold` + `GlasmioNavDisplay` + `GlasmioNavHeaderMotion` |
| Collapsing title | `GlasmioHeaderSpec`, `rememberGlasmioHeaderCollapse`, `GlasmioPageTitle` |
| Page body and top blur | `GlasmioPageBody` |
| Lists | `GlasmioGroupedList`, `GlasmioListRow`, `GlasmioSectionTitle` |
| Tab bar | `GlasmioTabBar` (bottom by default, top tabs on wide layouts) |
| Search | `GlasmioFloatingSearch` plus a `GlasmioSearchBar` field |
| Buttons | `GlasmioButton`, `GlasmioIconButton` |
| Sheets | `GlasmioBottomSheet` |
| Alerts | Glasmio alert composables |
| Controls | `GlasmioSwitch`, `GlasmioSlider`, `GlasmioSegmentedControl` |
| Glass cards | `GlassSurface`, `GlasmioCard` |

Snoozy-specific widgets use Glasmio primitives internally and do not draw their own glass.

## 7. Design Tokens

Colors keep the Snoozy palette. Glasmio geometry replaces the old 16 dp cards.

| Token | Value |
| --- | --- |
| accent | `#10B981` |
| accentStrong | `#059669` |
| accentInk | `#ECFDF5` |
| background (dark) | `#000000` |
| grouped background (light) | `#F2F2F7` |
| surface | `#1C1C1E` |
| surfaceRaised | `#2C2C2E` |
| ink | `#FFFFFF` |
| inkMuted | `#EBEBF5` at 62% |
| inkFaint | `#EBEBF5` at 38% |
| danger | `#FF453A` |
| ember | `#FF9F0A` |
| screen padding | 16 dp |
| grouped corner | 26 dp continuous |
| compact corner | 16 dp |
| sheet corner | 38 dp |
| icon button | 44 dp |
| control height | 48 dp |
| tab bar height | 64 dp |

Typography maps Snoozy roles onto Glasmio's type scale:

- Display and title roles use Bricolage Grotesque 600 (500 for medium display).
- Body, label, and caption roles use Atkinson Hyperlegible 400 and 700.
- Letter spacing follows `tokens.ts`: display -1.1, title -0.8, heading -0.4.
- Dynamic type is honored through `GlasmioTheme(dynamicTypeSize = ...)`.

Fonts are bundled in `res/font` from the existing `node_modules/@expo-google-fonts` files and built with `FontFamily` in the app theme. No font is fetched at runtime.

Motion uses Glasmio's springs. `MotionDurationScale == 0` automatically produces reduced motion. The app also maps the Snoozy motion setting: system, reduced, full. Reduced disables header parallax, artwork crossfade, and stagger.

## 8. Navigation

`NavKey` is a sealed interface with `Home`, `Library`, `Search`, `Playlists`, `Settings` as roots, plus `Album(albumKey)`, `Artist(artistKey)`, `Genre(name)`, `Playlist(id)`, `Player`, `Diagnostics`.

A single `SnapshotStateList<NavKey>` back stack follows the Glasmio sample pattern: tab selection clears to `Home` then appends the selected root; detail pushes append; back removes the last entry. `GlasmioNavHeaderMotion` classifies `Tab`, `Push`, and `Pop`.

The header is a single `@Composable (Any) -> GlasmioHeaderSpec` that maps each key to a title, leading back action, trailing actions, and scroll state. Page bodies publish scroll state through a per-entry holder, as the Glasmio sample does.

The player is a full-screen route, not a sheet. Mini player sits above the tab bar and opens `Player`. Queue, lyrics, edit, speed, and add-to-playlist are `GlasmioBottomSheet`s.

## 9. Data Compatibility

The native app opens the existing files in place. No export or import step is required for an install-over update.

SQLite directory: `filesDir/SQLite/` (verified in `expo-sqlite` `SQLiteModule.defaultDatabaseDirectory`).

| File | Table | Primary key / columns |
| --- | --- | --- |
| `snoozy_favorites.db` | `favorites` | `identity` PK, title, artist, album, duration, artwork, added_at |
| `snoozy_metadata.db` | `track_overrides` | `track_id` PK, title, artist, album, album_artist, genre, year, track_number, description, artwork_path, updated_at |
| `snoozy_metadata.db` | `album_overrides` | `album_key` PK, title, artist, description, artwork_path, updated_at |
| `snoozy_metadata.db` | `artist_overrides` | `artist_key` PK, name, description, artwork_path, updated_at |
| `snoozy_playhistory.db` | `play_history` | id autoincrement, track_id, played_at, duration_listened_ms |
| `snoozy_errorlog.db` | `error_log` | id autoincrement, timestamp, category, message, track_id |
| `snoozy.db` | `listening_sessions` | id autoincrement, sound_id, started_at, ended_at, duration_seconds |

MMKV directory: `filesDir/mmkv/` with the default MMKV initialization. Store IDs and keys:

| Store | Keys |
| --- | --- |
| `snoozy.music.v1` | `playlists`, `recents`, `imported`, `scannedSnapshot`, `songSort`, `albumSort` |
| `snoozy.playback.v1` | `session.v1`, `queueIds`, `repeatMode`, `shuffle`, `playbackRate` |
| `snoozy.theme.v1` | `mode`, `paletteStyle`, `seed`, `backdropEnabled`, `backdropIntensity`, `motionMode` |
| `snoozy.preferences.v1` | `haptics`, `notificationsAsked` |
| `snoozy.search.v1` | recent queries |
| `snoozy.lyrics.v1` | `offset:<trackUri>` numbers |
| `snoozy.audio.v1` | `embedded-metadata.v1` JSON cache |

Track identity rules, preserved exactly:

- MediaStore tracks use the MediaStore `_id` as string `id` and a `file://` URI.
- Imported tracks use the existing generated `imported-<timestamp>-<index>-<random>` id and the copied file under `files/Music/`.
- Favorites key on `Track.uri`, not `Track.id`.
- Playlists and queue store `Track.id`.
- The persisted session is `session.v1` with version 1 and fields: activeTrackId, queueIds, queueIndex, positionSeconds, shuffle, repeatMode, updatedAt.

The first native launch must not write to these stores until it has read them successfully. Read-only access is the default for the first run.

## 10. Feature Parity Matrix

| Area | Required behavior |
| --- | --- |
| Home | Greeting, library status, permission and scanning states, recently played, recently added albums, top played, import action |
| Library | Songs, Albums, Artists, Genres, Favorites; sort menus; grid and list albums; shuffle; import; empty states |
| Album | Artwork, title, artist, year, track list, play and shuffle, favorite, edit album |
| Artist | Artwork, name, albums, songs, play and shuffle, edit artist |
| Genre | Songs for genre, play and shuffle |
| Playlists | List, create, rename, delete, add and remove songs, reorder |
| Search | Songs, albums, artists, genres; recent searches; clear; empty state |
| Player | Artwork, title, artist, album links, favorite, seek, previous, play/pause, next, shuffle, repeat off/all/one, speed, lyrics, queue, edit |
| Queue | Current item, reorder, remove, jump, clear |
| Lyrics | Sidecar `.lrc`, embedded ID3 USLT and SYLT, sync highlight, tap to seek, offset, reset |
| Metadata | Track fields from the override table, album and artist description and artwork, save and reset |
| Settings | Theme mode, accent seed, palette style, glass mode, backdrop intensity, motion, haptics, notifications, error log, about, clear recents and history |
| Background | MediaSessionService, notification with artwork and controls, audio focus, noisy intent, Bluetooth and headset buttons |
| Persistence | Queue and position restored after process death; playback state survives reboot where Android allows |

## 11. Playback Architecture

- Media3 `ExoPlayer` in a `MediaSessionService`.
- `MediaSession` with the Snoozy queue as `MediaItem`s.
- Custom `Player.Listener` maps repeat and shuffle to `TrackRepeatState`.
- `PlaybackController` owns queue ordering, persistence, and the UI state flow.
- `AudioAttributes` usage media, content type music, handle audio focus.
- `setHandleAudioBecomingNoisy(true)`.
- Playback speed range 0.5 to 2.0, persisted.
- Position writes are throttled to once per 5 seconds and on pause, stop, and task removal.
- The service uses `MediaStyle` notification with previous, play/pause, next, and artwork.
- Media item media IDs are Snoozy track IDs. A resolver loads the track from the library snapshot and returns its URI.

No playback control is decorative. If a control cannot act, it is disabled with a reason.

## 12. Scanning and Permissions

- `READ_MEDIA_AUDIO` on API 33 and newer; `READ_EXTERNAL_STORAGE` fallback below 33 is unnecessary because minSdk is 33.
- `POST_NOTIFICATIONS` for the media notification on API 33.
- MediaStore query on `Audio.Media.EXTERNAL_CONTENT_URI` with `IS_MUSIC != 0`, ordered by date added.
- Metadata from MediaStore columns plus a best-effort `MediaMetadataRetriever` pass with the existing concurrency cap.
- SAF `OpenMultipleDocuments` for import, copied into `files/Music/` with the same naming rule.
- The scanned snapshot stays in `snoozy.music.v1` so a scan failure never empties the library.
- No permission request loop: one prompt, then a settings deep link when permanently denied.

## 13. Performance Budget

Measured baseline on the A55:

- Glasmio demo full glass: 129 ms median frame, unusable.
- Glasmio demo Reduce Transparency: 20 ms median, about 50 fps.
- Snoozy v2.3 React Native: 40 ms median, 95.5% janky.

Gates for the native app in Reduce Transparency:

- Cold start to Home interactive: below 2 seconds.
- Library scroll of 1,000 tracks: median frame below 32 ms, jank below 10%.
- Player artwork transition: no frame above 100 ms.
- Tab switch: no blank frame, header morph completes within 400 ms.
- APK size below 30 MB for arm64-v8a.

Rules: no full-screen shader while the full glass setting is off, no bitmap decoding on the main thread, artwork cached at 2 sizes, lists keyed by track id, no nested vertical scroll containers.

## 14. Risks

| Risk | Mitigation |
| --- | --- |
| Glasmio API drift from 0.1.2 | Version pinned; source cached in the temp clone; wrapper usage isolated in `ui/components` |
| Feather artifact package mismatch | Verified: package `compose.icons`; usage documented above |
| MediaStore ids differ from Expo ids | Use `_id` string directly; compare against the preserved snapshot before replacing it |
| `file://` URIs unavailable on newer Android | Keep existing snapshot URIs; use content URI fallback for playback only |
| Old MMKV files incompatible with current MMKV | Read with MMKV 2.x first; if a store fails, log and leave it untouched; verify with real app data on the A55 |
| Full glass unusable on G35 | Default Reduce Transparency, warning in the setting, benchmark screen in diagnostics |
| Release signing mismatch | Reuse the existing keystore properties and alias; verify with `apksigner verify --print-certs` against 2.3.0 |

## 15. Verification

Static gates per change:

```bash
cd android-native
gradlew.bat :app:assembleDebug
gradlew.bat :app:testDebugUnitTest
gradlew.bat :app:lintDebug
```

Device gates per phase:

```bash
adb -s 9PGE8SQKAM598PBY install -r app-debug.apk
adb -s 9PGE8SQKAM598PBY shell am start -n com.snoozy.app/.MainActivity
adb -s 9PGE8SQKAM598PBY shell dumpsys gfxinfo com.snoozy.app framestats
```

Data gate before uninstalling the React Native build:

1. Copy `files/SQLite`, `files/mmkv`, and `files/Music` out of the app sandbox with `run-as` or a debug backup.
2. Install the native build over the existing app.
3. Verify row counts and keys match the export.
4. Only then remove the React Native project.
