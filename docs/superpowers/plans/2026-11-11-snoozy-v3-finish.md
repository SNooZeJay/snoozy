# Snoozy v3.0 finish roadmap

> This is a program roadmap, not a task-level implementation plan. Before coding each phase, write a detailed task plan with the writing-plans skill under `docs/superpowers/plans/`, based on a short spec under `docs/superpowers/specs/`. One phase at a time.

**Goal:** Ship Snoozy 3.0 as a complete, stable, local-first Android music player: every P0/P1 item in `docs/COVERAGE-v2.3.md` is Done or explicitly accepted, a signed release is verified on the Oppo A55, and the release is documented.

**Tech stack:** Expo SDK 58, React Native 0.88, React 19, TypeScript, Expo Router, `@rntp/player` 5.12.1, Reanimated 4, MMKV, expo-sqlite, Jest (jest-expo).

**Baseline:** branch `release/v1.9`, commit `9a12ed6` (v2.2.0) plus the uncommitted v2.3 work. App version `2.3.0`, versionCode `13`, package `com.snoozy.app`, arm64-v8a.

## Product definition

Snoozy is a local-first Android music player for one person on a phone. It scans on-device audio and plays it with a persistent queue, mini-player, full player, background playback, and a media notification. Users can search, browse albums, artists and genres, favorite tracks, manage playlists, read synced lyrics, and edit metadata. Everything stays offline: no account, no network, no uploads, no tracking. Keep the emerald accent, Bricolage Grotesque and Atkinson Hyperlegible, Feather icons, and the Cupertino/Liquid Glass language.

`PRODUCT.md` is legacy and mentions online resolution later. The current app has no network layer and does not need one.

## Finish line

The app is finished when all of these are true:

- All P0 and P1 rows in `docs/COVERAGE-v2.3.md` are Done or accepted with a written reason.
- A cold start restores the last track, queue, position, shuffle, and repeat, paused.
- A backup round trip restores favorites, playlists, and metadata overrides on a clean install.
- Album, artist, genre, and playlist track lists scale to large libraries without mounting every row.
- Search filters, remembered sort and layout, reduce transparency, and TalkBack behavior are in place.
- The release build installs over the previous version and passes the device checklist.
- `docs/BUILD.md`, `artifacts/README.md`, and the audit record are current.

## Do not rebuild what already exists

The coverage audit is from 2026-10-28 and is stale. Before planning, re-audit and mark these as already done:

- Queue UI with reorder, remove, clear, jump, play next, add to queue, and save as playlist.
- Virtualized Library and Search lists; song and album sorting; album grid and list layouts.
- Grouped search across albums, artists, playlists, and songs, with recent searches.
- Playback speed control in the player, persisted.
- Favorites in SQLite, playlists with rename, delete, add, remove, and reorder, metadata editing.
- Synced lyrics, theme modes, dynamic palette, backdrop intensity, reduced motion, error log.
- Collapsing title bars, shrinking tab bar, sheet drag, player drag-down from v2.3.

## Deliberately out of scope

Do not add these without an explicit user request:

- Sleep timer. It was removed at the user's request; do not bring it back.
- Online streaming, accounts, cloud sync, telemetry, recommendations.
- iOS, tablets, landscape, widgets, Android Auto, Wear, casting, DLNA.
- Podcasts, audiobooks, internet radio.
- EQ, crossfade, gapless, A-B repeat, visualizer, tag writing to audio files.
- Shared-element mini-player-to-player morph, JS 70/30 parallax stack, context menus, two-detent sheets.
- Localization and right-to-left layout.

## Phase 0: Ship v2.3

**Why:** the interaction port is built and statically green, but no APK exists.

**Deliverables:**
- Static gates: `npx tsc --noEmit`, `npx expo lint`, `npx jest --silent`.
- Release build from `C:\s` with JDK 17 and the existing keystore.
- Install with `adb install -r` on serial `9PGE8SQKAM598PBY`; launch; no crash.
- Verify every item in `docs/HANDOFF-v2.3-antigravity.md`.
- Update `docs/BUILD.md`, `artifacts/README.md`, and promote the APK.

**Exit:** v2.3 is installed, verified, and recorded. Any regression is fixed before Phase 1.

## Phase 1: Cold-start continuity

**Why:** after a cold start the app forgets the active track and position. That is the largest P0 gap left. A local player should reopen where the listener left it.

**Deliverables:**
- Persist active track id, queue ids (already stored), queue index, position seconds, shuffle, and repeat.
- Save position on pause, track change, background, and every 5 seconds while playing. Use MMKV.
- On launch, restore the paused session: MiniPlayer shows the track at the saved position, and Play rebuilds the queue at the saved index and seeks.
- Handle deleted tracks, stale ids, and out-of-range positions by clamping or discarding cleanly.
- No autoplay on launch.

**Files:** `src/playback/PlayerContext.tsx`, new `src/playback/session.ts` for pure save/restore/clamp logic, `tests/session.test.ts`.

**Tests:** pure restore selection, index clamping, position clamping, missing-track fallback, empty queue, stale schema.

**Device acceptance:** play to roughly 1:30, swipe the app away, relaunch. MiniPlayer shows the track at 1:30, paused. Play resumes there. Queue order and shuffle/repeat match. A deleted file falls back without a crash.

## Phase 2: Library scale

**Why:** album, artist, genre, and playlist screens still use `ScrollView` plus `map`, so a large artist mounts every row. The audit flags performance as at risk.

**Deliverables:**
- Replace the track list on `album.tsx`, `artist.tsx`, `genre.tsx`, and `playlist.tsx` with `FlatList` or `SectionList`. Keep the header content as `ListHeaderComponent` so the collapsing title bar, hero art, and actions stay intact.
- Memoize rows and actions; set sane `initialNumToRender`, `windowSize`, and `getItemLayout` where rows are fixed height.
- Keep the MiniPlayer and `CollapsedBar` behavior identical.
- Cap the artwork cache and prune orphaned files; never delete art for a track still in the library.
- Validate the scan path with a large library or synthetic fixture.

**Files:** the four screens, `src/components/ListRow.tsx`, `src/components/Thumb.tsx`, `src/storage/MusicLibraryContext.tsx`, `src/storage/metadata.ts`, `src/storage/libraryFingerprint.ts`, tests for any new pure cache logic.

**Device acceptance:** an artist with 500 or more tracks scrolls without blank frames or jank; collapse and back still work; memory does not climb after repeated visits; artwork survives a rescan and an import.

## Phase 3: Backup and restore

**Why:** `src/storage/backup.ts` can export and validate but has no UI and no import. Reinstalling currently loses favorites and playlists. That is a data-loss gap, not a feature request.

**Deliverables:**
- Settings > Data: Export backup and Import backup.
- Export favorites, playlists, track, album, and artist overrides, with schema version and timestamp. No audio files, no secrets, no device paths.
- Import validates first, shows counts, asks for confirmation before replacing data, applies in a transaction, and reports malformed or newer-schema files without partial writes.
- Resolve playlist tracks by id first, then by identity fallback, and skip tracks that no longer exist with a count shown to the user.
- Tighten `BackupData` types; remove `any`.
- Use the installed `expo-document-picker` and React Native `Share`; no new dependency.

**Files:** `src/storage/backup.ts`, `src/storage/FavoritesContext.tsx`, `src/storage/MusicLibraryContext.tsx`, `src/storage/metadata.ts`, `src/app/(tabs)/settings.tsx`, new sheet or dialog for import confirmation, `tests/backup.test.ts`.

**Tests:** valid round trip, schema mismatch, malformed JSON, missing fields, duplicate favorites, missing playlist tracks, empty backup, rollback on a failed write.

**Device acceptance:** export, clear app data or install fresh, import, and confirm favorites, playlists, and edited metadata return. Invalid files show a clear error and change nothing.

## Phase 4: Search and browsing finish

**Why:** search groups results but cannot filter them, and library sort and layout reset on every launch. These are P1 everyday-usability gaps.

**Deliverables:**
- Filter chips above search results: All, Songs, Albums, Artists, Playlists, with result counts. Filters combine with the query and keep recent searches working.
- Persist song sort, album sort, and album layout across launches.
- Keep the search field keyboard behavior, clear action, and empty states intact.
- Add a clear empty state when a filter has no matches.
- No fuzzy matching or new search dependency.

**Files:** `src/app/(tabs)/search.tsx`, `src/app/(tabs)/library.tsx`, `src/storage/preferences.ts`, `src/storage/PreferencesContext.tsx`, pure search/filter helpers if needed, tests.

**Device acceptance:** filter combinations return the right rows; sort and layout survive a cold start; TalkBack announces chip state; text scaling at 200% does not clip the chips.

## Phase 5: Accessibility and comfort

**Why:** motion is now heavy on glass and blur, and some new controls were added after the last accessibility pass. The audit still lists reduce-transparency as missing.

**Deliverables:**
- Settings > Accessibility: Reduce transparency. When on, replace live blur and heavy glass fills with opaque themed surfaces. It must lower GPU cost, not just change opacity.
- Hide the collapsed title bar from TalkBack while it is invisible, and keep its back button reachable when visible.
- Audit every new icon-only control for a label and 48 dp target.
- Check reduced motion for every v2.3 gesture: sheet spring, player drag, tab pill, collapsing bars.
- Check 200% font scaling on Home, Library, Search, Settings, album, artist, playlist, player, queue, and sheets.
- Confirm contrast in both light and dark modes; the color engine already enforces contrast, so fix regressions rather than adding a second theme system.

**Files:** `src/theme/ThemeContext.tsx`, `src/theme/appearance.ts`, `src/components/glass/GlassSurface.tsx`, `src/components/CollapsingHeader.tsx`, `src/app/(tabs)/settings.tsx`, affected screens for font scaling.

**Device acceptance:** TalkBack walkthrough of each tab and the player; reduce transparency measurably reduces blur layers; reduced motion removes spring travel; 200% text keeps primary actions reachable.

## Phase 6: Reliability and test floor

**Why:** most tests cover pure helpers only. Storage failures, restore races, and backup writes are the paths most likely to lose data.

**Deliverables:**
- Unit tests for session restore, backup merge and validation, library sort and filter helpers, and any new cache pruning.
- Storage writes never crash the UI; failures go through `errorLog` with a user-visible message where data is at risk.
- Schema versioning for SQLite and MMKV keys; no destructive migration.
- Device stress: 10 minutes background playback, audio focus loss and regain, Bluetooth route change, permission revoke and regrant, force stop and relaunch, low-storage import failure.
- Record cold and warm start times; do not regress v2.2 numbers.

**Files:** `tests/`, `src/storage/`, `src/playback/`, `src/utils/`; device evidence under `artifacts/device/`.

**Device acceptance:** no unhandled promise rejections or fatal exceptions in logcat during the stress pass; playback and UI recover from every interruption.

## Phase 7: Release 3.0

**Why:** close the milestone with a reproducible artifact and a written record.

**Deliverables:**
- Version `3.0.0`, versionCode `14` unless the user chooses otherwise. Update `app.json` and `package.json`.
- Full device checklist: all tabs, playback, queue, playlists, favorites, lyrics, metadata edit, search filters, backup restore, theme modes, reduce transparency, reduced motion, permission flows, cold start.
- Screenshot set for the record.
- Signed arm64 release, SHA-256, size, install result.
- `docs/BUILD.md` v3.0 section, `artifacts/README.md` canonical entry, and an audit record with evidence and known limits.
- Commit and tag only with user approval.

**Exit:** the v3.0 APK is installed and verified on the A55, and the next person can rebuild it from the written record.

## Working rules

- One phase at a time. Do not start Phase N+1 before Phase N is device-verified.
- Each phase begins with a short spec and a task-level plan; use TDD for pure logic.
- Run `npx tsc --noEmit`, `npx expo lint`, and `npx jest --silent` before every device build.
- Sync the repo to `C:\s`, delete stale bundles, build with JDK 17, install with `-r`.
- Keep changes on the current branch. Commit only at phase boundaries with user approval.
- No new dependency unless the installed stack cannot do the job. Use `npx expo install` when one is required.
- Never hardcode or print keystore values, connection strings, or secrets.
- If a requirement conflicts with the product definition or the out-of-scope list, stop and ask.

## P0/P1 mapping

| Coverage row | Status after this plan |
| --- | --- |
| 1 Library and import | Scan, import, cache held; folders remain accepted out of scope |
| 2 Browsing and organization | Sort, grid, filters, virtualized stack lists |
| 3 Core playback | Restore, queue, speed, background complete; gapless and crossfade accepted out |
| 5 Metadata and artwork | Editing held; file tag writing accepted out |
| 7 Search | Filters and remembered state |
| 8 Interface | Reduce transparency; visualizer and custom tabs accepted out |
| 9 Accessibility | TalkBack, scaling, reduce transparency |
| 10 Playlists and queue | Complete; M3U import accepted out |
| 11 Favorites and history | Favorites and recents held; stats UI accepted out |
| 12 Storage and reliability | Backup round trip, schema versions, tests |
| 20 Performance | Virtualized lists, cache cap, measured start |
| 21 Testing | Added unit and device coverage |

Items not listed as P0/P1 in the audit stay out unless the user asks.
