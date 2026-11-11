# Snoozy Native Glasmio Roadmap

Date: 2026-11-11
Spec: `docs/superpowers/specs/2026-11-11-snoozy-native-glasmio-design.md`

Each phase ends with a build, a device install, a screenshot, and a short verification note in `docs/BUILD.md` or the phase file. A phase does not start until the previous gate passes on the A55.

## Phase 0: Toolchain proof (done)

- Glasmio `0.1.2` consumer built with JDK 25, Gradle 9.6, AGP 9.4.1, compileSdk 37.
- APK installed and launched on the A55.
- Feather icons resolved and rendered (`compose.icons` package).
- Glasmio demo benchmark: full glass unusable, Reduce Transparency acceptable.

Gate: passed. Spike stays in the temp folder as a reference.

## Phase 1: Native skeleton, theme, and navigation shell

- Create `android-native/` with the verified Gradle stack.
- Bundle Bricolage Grotesque and Atkinson Hyperlegible.
- Implement `SnoozyTheme` on `GlasmioTheme` with emerald colors, fonts, and Reduce Transparency default.
- Implement Feather aliases.
- Implement NavKey, root back stack, five tabs, Glasmio scaffold, and placeholder screens.
- Configure the release signing env vars and version 3.0.0 (versionCode 14).
- Build a debuggable `dev` build signed with the release key, install over 2.3.0, confirm data directory survives.

Gate: five tabs switch, header collapses, no crash, screenshots on the A55.

## Phase 2: Data layer and library scan

- MMKV accessors for all seven stores, read-only first.
- SQLite helpers for the five files at `filesDir/SQLite`.
- MediaStore scanner producing the same track ids and `file://` URIs.
- SAF import into `files/Music`.
- Album grouping, sorting, search, stats.
- Unit tests for grouping, sorting, URL identity, and JSON shapes.

Gate: existing playlists, recents, favorites, and overrides load from the real v2.3 data; a fresh scan matches the old snapshot count.

## Phase 3: Library and home screens (3A done, 3B pending)

- Home with status, recently played, recently added, top played.
- Library with Songs, Albums, Artists, Genres, Favorites, sorts, grid and list.
- Album, artist, and genre detail routes. Phase 3A owns these.
- Playlists tab with create, rename, delete, add, remove, reorder. Phase 3B owns this.
- Playlist detail and full import execution. Phase 3B owns these.
- Import picker and permission states. Phase 3A owns these.

Gate: every list opens and scrolls at the performance budget. Playback is Phase 4. Phase 3A passed on the A55 on 11 November 2026; the Phase 3 gate closes after Phase 3B.

## Phase 4: Playback engine

- Media3 ExoPlayer in `MediaSessionService`.
- Queue, repeat, shuffle, speed, audio focus, noisy intent.
- Session persistence compatible with `session.v1` and `queueIds`.
- Notification with artwork and controls.
- Media button, Bluetooth, and lock screen controls.

Gate: playback continues with the screen off for 30 minutes, queue and position restore after force stop, notification actions work.

## Phase 5: Player, queue, and lyrics

- Full player with artwork, metadata links, seek, controls, speed.
- Queue sheet with reorder, remove, clear.
- Lyrics from sidecar LRC and embedded ID3, sync highlight, tap to seek, offset persistence.

Gate: synced lyrics follow playback, offset survives restart, queue edits change playback order.

## Phase 6: Search and metadata editing

- Search across songs, albums, artists, genres with recent queries.
- Track, album, and artist edit sheets writing the existing override tables.
- Artwork picking and display override.
- Favorites write-through to `snoozy_favorites.db`.

Gate: edits appear in every surface after restart, reset restores raw metadata, favorites match the old app.

## Phase 7: Settings, diagnostics, and full glass

- Settings rows for theme, seed, palette style, glass mode, backdrop, motion, haptics, notifications.
- Error log viewer backed by `snoozy_errorlog.db`.
- Diagnostics route with frame stats, database counts, MMKV keys, and Glasmio attribution.
- Full glass opt-in with warning and a one-tap return to Reduce Transparency.

Gate: Reduce Transparency default holds; full glass does not crash; settings persist across restart.

## Phase 8: Release hardening

- Lint, unit tests, macrobenchmark cold start, frame stats.
- ProGuard rules for Media3 and MMKV.
- APK signed with the existing key, version 3.0.0, versionCode 14.
- Install over 2.3.0, verify data, then update `docs/BUILD.md`.
- Archive the React Native app only after all gates pass.

Gate: `adb install -r` over 2.3.0 succeeds, data intact, all parity checks below pass.

## Phase 9: Parity checklist on the A55

- Permission prompt and settings deep link.
- Scan, import, play, pause, seek, next, previous.
- Background, notification, lock screen, headset.
- Repeat off, all, one; shuffle; speed.
- Favorites, playlists, reorder, search, lyrics, metadata edit.
- Theme, accent, motion, glass, error log.
- Portrait lock, no crash in `logcat -b crash`, battery drain under 4% per hour idle with playback stopped.

Gate: signed off with screenshots and a written checklist.

## Phase 10: Archive React Native

- Move the RN app to `archive/react-native-v2.3/` or a tag.
- Keep `docs/BUILD.md` as the single build record.
- Tag `v3.0.0-native`.

Gate: repository builds from a clean clone with the documented commands.
