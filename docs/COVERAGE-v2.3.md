# Snoozy — coverage against the offline-first player spec

Audit date: 2026-10-28
Tree: `9a12ed6` (v2.2.0) plus the uncommitted v2.3 work on `release/v1.9`
Engine: `@rntp/player` 5.12.1 (Media3/ExoPlayer on Android)
Method: read the shipped source, the installed engine typings, and the v2.2
device audit; ran typecheck, lint, and the unit suite. No device pass was
performed for this document.

## Status vocabulary

| Status | Meaning |
| --- | --- |
| Done | Works end-to-end from the app UI |
| Partial | Exists but covers a narrower version of the item, or the data/logic exists without a user-facing path |
| Missing | No implementation |
| Engine-limited | Would require native audio work beyond the current engine |
| Out of scope | Deliberately absent from the Android local-player product |

Priority follows the spec's table: **P0** essential, **P1** everyday usability,
**P2** deeper customization, **P3** optional/high complexity.

## Executive summary

Snoozy is a credible P0 local player: MediaStore scanning with an embedded-tag
cache, album grouping with multi-disc ordering, a persistent queue driven by
RNTP, favorites, playlists, synced lyrics, theming with reduced motion, and a
proper Android media session. It is **not** yet a complete offline-first
player per this list: the queue is invisible, nothing survives a cold start
beyond a title-sorted rescan, and the library has exactly five fixed views
with no sort, filter, or virtualization.

The fastest meaningful gains are not exotic features. They are:

1. **Queue management UI** (P0 §3) — the engine already supports
   `moveMediaItem`, `removeMediaItem`, `insertMediaItem`, `clear`, and
   `skipToIndex`; the app only exposes play/pause/skip.
2. **State restoration** (P0 §3/§12) — the last track comes from `recents[0]`,
   but the queue and position are not restored, and the scanned library is not
   persisted, so cold start begins with an empty list and a full rescan.
3. **List virtualization** (P0 §20) — every list is a `ScrollView` + `map`;
   there is no `FlatList`/`SectionList` anywhere in `src/`.
4. **Sort and filter** (P1 §2/§7) — songs and albums are always title-sorted;
   search is a single ungrouped list over title/artist/album only.
5. **Finish what is built but unreachable** (P1) — sleep-timer methods,
   playback-rate state, backup export/validation, album/artist description
   storage, listening-session summaries, and `SoundWave` have no consumer.

Strong areas worth protecting: the metadata/artwork cache and album grouping;
lyrics (LRC + USLT/SYLT, offset, tap-to-seek); the theme/motion system;
Android background playback, notification, and media-button handling; and the
strictly local, minimal-permission design.

## Coverage matrix

| # | Section | Priority | Status | Headline |
| --- | --- | --- | --- | --- |
| 1 | Library and import | P0/P1 | Partial | MediaStore scan + tag cache; no folders, filters, playlists-in, CUE, or per-format handling |
| 2 | Browsing and organization | P0/P1 | Partial | Five fixed views; no sort, filter, grid, ratings, smart lists |
| 3 | Core playback | P0/P1/P2 | Partial | Transport, shuffle/repeat, background done; no queue UI, restore, gapless, crossfade, A–B |
| 4 | Audio quality | P2 | Missing | No effects layer; engine exposes no EQ/normalization |
| 5 | Metadata and artwork | P1 | Partial | Reads tags, caches art, DB overrides; no tag write, batch, rename, online lookup |
| 6 | Lyrics | P2 | Partial | Synced LRC/ID3 with offset and seek; no online, edit, import/export, karaoke |
| 7 | Search | P0/P1 | Partial | In-memory title/artist/album search + recents; no grouping, fuzzy, filters |
| 8 | Interface and personalization | P1/P2 | Partial | Themes, dynamic color, motion; no AMOLED, visualizer, custom tabs, landscape, i18n |
| 9 | Accessibility | P1 | Partial | Labels, 48 dp, reduced motion; no high-contrast or reduce-transparency options |
| 10 | Playlists and queue | P0/P1 | Partial | Create/delete/add/remove/play/shuffle; no rename/reorder/import or queue surface |
| 11 | Favorites, history, statistics | P1/P2 | Partial | Favorites, recents, play history stored; no stats UI, ratings, counts |
| 12 | Storage and reliability | P0/P1 | Partial | SQLite + MMKV and caches; no migrations, integrity checks, backup UI |
| 13 | System and device | P1/P3 | Partial | Excellent Android media session/background; no widgets, Auto, QS tile, Wear |
| 14 | File management and utilities | P2/P3 | Missing | Diagnostics/about done; no file info, delete, share, rename, export |
| 15 | Permissions and privacy | P0 | Strong | Audio + notifications only, scoped storage, no account, no network |
| 16 | Online integrations | P3 | Out of scope | No network layer; adding one must stay isolated from local playback |
| 17 | Podcasts and audiobooks | P3 | Missing | No separate libraries, chapters, bookmarks, or feeds |
| 18 | Internet radio and casting | P3 | Missing | No stations, casting, or DLNA |
| 19 | Advanced and specialty | P3 | Missing | No smart lists, party mode, multi-library, alarm, plugins |
| 20 | Performance and resources | P0/P1 | At risk | No virtualization or persisted index; unbounded artwork cache; 4 s poll |
| 21 | Testing and maintenance | P1 | Partial | 12 unit tests now green; device checks remain manual |
| 22 | Platform-specific | P1/P3 | Android-only | Media session/service done; iOS/desktop/Auto/Wear absent |

## Section detail

### 1. Library and import

| Feature | Status | Evidence / gap |
| --- | --- | --- |
| Device scan | Done | `expo-media-library/legacy` paged 500 at a time, audio only (`MusicLibraryContext.tsx`) |
| Automatic + manual rescan | Done | Pull-to-refresh, Settings, and a 4 s foreground fingerprint poll with a 1.2 s debounce |
| Folder browsing / include-exclude | Missing | Folder name is only an album-title fallback (`albumGrouping.ts`) |
| Minimum size / duration filters | Missing | No filter state or scan guard |
| Format support | Decoder-limited | No whitelist or probe; MediaStore indexes the file and Media3 decodes it. MP3/M4A/AAC/FLAC/OGG/Opus/WAV/ALAC generally work; WMA/APE/AIFF need per-device verification (Media3 has no APE extractor) |
| Multi-disc albums | Done | `sortAlbumTracks` orders disc before track; unknown track numbers fall back to filename |
| Album artist / compilation grouping | Partial | Album key prefers `albumArtist`; compilation flags and "Various Artists" semantics are not modelled |
| Duplicate track detection | Partial | Library dedupes by file URI and playlists by track id; no tag/fingerprint duplicate detection |
| M3U / M3U8 / PLS import-export | Missing | None |
| CUE sheets | Missing | None |
| Hide / blacklist tracks or folders | Missing | None |
| SD card / removable storage | Partial | MediaStore covers mounted volumes; no explicit volume state or "storage removed" handling |
| Missing/moved/renamed detection | Partial | A rescan drops absent files silently; playlists quietly shrink; no report or repair path |
| Scan progress, cancel, errors | Partial | Spinner + one error string; the track list is published only at scan end, so "N songs found so far" always shows the previous count; no cancel |
| Rescan one folder | Missing | Only whole-library scan |
| Ignore system folders / unsupported files | Done (implicit) | MediaStore's audio media type filters these out |

### 2. Browsing and organization

| Feature | Status | Evidence / gap |
| --- | --- | --- |
| Songs, albums, artists, playlists, favorites | Done | Five segments in `src/app/(tabs)/library.tsx` |
| Album artists, genres, composers, years, folders | Missing | `Track` has `genre`/`year` but they are never browsable; `albumArtist` only feeds album grouping; `display.artists` uses `track.artist` |
| Recently added | Missing | No `dateAdded` field on `Track` |
| Recently played / most played / never played | Partial | "Recently played" from the MMKV recents list; the other two are absent |
| Sort options | Missing | Fixed `title.localeCompare` for songs and albums |
| Filter by genre/year/folder/rating/format | Missing | No filter UI; format and rating are not stored |
| Grid/list views, art grid size | Missing | List rows only |
| Alphabetical fast scroller | Missing | None |
| Favorites and star ratings | Partial | Favorites done; ratings absent |
| Play counts / skip counts | Partial | Plays are recorded (`playHistory.ts`); there is no count read model or UI; skips are not recorded |
| Smart playlists | Missing | None |
| Playlist folders / reordering | Missing | Playlists are a flat MMKV array |
| Pinned items | Missing | None |
| Customizable home sections | Missing | Home is fixed: recently played, playlists, library shortcut |
| Recently modified / random tracks | Missing | No modification-time or shuffle-by-library surface |
| Multi-select / batch actions | Missing | Single-row menus only |

### 3. Core playback

| Feature | Status | Evidence / gap |
| --- | --- | --- |
| Play, pause, seek, next, previous | Done | `PlayerContext` + RNTP; previous restarts after 3 s |
| Shuffle with stable order | Done | Engine shuffle plus persisted flag; album/playlist shuffle picks a random start (`controls.ts`) |
| Repeat off / all / one | Done | Player control, persisted in MMKV |
| Queue reorder / remove / clear | Missing | No UI; engine exposes `getQueue`, `moveMediaItem`, `removeMediaItem`, `clear`, `skipToIndex`. `QueueChangedEvent` is `never`, so a mirror in context is required |
| Play next / add to queue | Missing | `insertMediaItem` exists in the engine, unused |
| Save queue as playlist | Missing | None |
| Restore track, queue, position after restart | Missing | Initial selection is `recents[0]`; queue and position are not persisted |
| Gapless playback | Engine-limited | Only `preload` ("gapless-like"); no true gapless API |
| Crossfade between tracks | Missing | No engine support; would need volume automation or native work |
| Speed control with pitch preservation | Partial | `playbackRate` state is persisted but **never applied**; RNTP exposes `setPlaybackSpeed`, so the code comment claiming otherwise is stale — wire it and verify on device |
| Skip silence | Missing | No engine API; native/manual analysis required |
| A–B repeat | Missing | None |
| Sleep timer | Partial | Context calls `sleepAfterTime(minutes*60, {fadeOutSeconds: 20})`, but **no UI calls it**; the end-of-track flag is set and never acted on (the engine has `sleepAfterMediaItemAtIndex`) |
| Volume fade-out / end-of-track sleep | Partial | Timer fade works when started; end-of-track sleep is a no-op |
| Audio focus / interruptions | Done | RNTP `audioMixing: 'exclusive'` + default focus handling |
| Pause on headphone disconnect | Done | `handleAudioBecomingNoisy: true` |
| Resume on headphone reconnect | Missing | None |
| Background playback | Done | RNTP foreground service, `taskRemovedBehavior: 'continue'`, wake mode local |
| Notification / lock-screen controls | Done | `setCommands` play/pause/seek/next/previous with native handling |
| Wired / Bluetooth media buttons | Done | Native media session handling |
| Playback error recovery | Partial | Errors surface as a banner and in the error log; `retry()` exists but is unused; deleted tracks are not auto-skipped |
| Per-track/album resume, audiobook memory | Missing | Every play starts at 0 |
| Configurable queue behavior / duplicate prevention | Partial | Playlist adds dedupe; queue is rebuilt per play; no user configuration |
| History restoration | Partial | Listening sessions and play history are stored, never restored to the player |

### 4. Audio quality and sound customization

All of equalizer, presets, bass boost, virtualizer, reverb, ReplayGain,
loudness normalization, balance, mono, limiter, per-headphone profiles,
per-track gain, clipping protection, output-device selection, USB DAC,
hi-res output, format/sample-rate/bit-depth info, effects bypass, and
processing status are **Missing** or **Engine-limited**. RNTP 5.12.1 exposes
none of these; `setVolume` is the only audio control. The engine does ship
`OutputDeviceButton`, `CastButton`, and `AirPlayButton` components that are
unused. An EQ/normalization feature needs a native audio-effects module.

### 5. Metadata and album artwork

| Feature | Status | Evidence / gap |
| --- | --- | --- |
| Read embedded tags | Done | `react-native-audio-metadata` with an MMKV cache keyed by modification time (`audioMetadata.ts`) |
| Edit tags in files | Missing | Edits never touch the file |
| Display-only edits in the local DB | Done | `track_overrides` in `snoozy_metadata.db`, layered by `displayTracks` |
| Batch metadata editing | Missing | Single-track sheet only |
| Title…comments fields | Partial | Title, artist, album, album artist, genre, year, track number, description (comments) are editable; **composer and disc number are not** (`SongEditSheet.tsx`, override schema) |
| Embedded artwork extraction | Done | `getArtwork` → `documentDirectory/artwork/`, one cover per album, `.none` markers for misses |
| Custom artwork | Done | Image picker in `SongEditSheet` |
| Folder images as fallback | Missing | Only embedded art is tried |
| Artwork cache | Partial | Persistent files, but no size accounting, eviction, or clear action |
| Online metadata/artwork lookup | Missing | Deliberate for v1 |
| Rename files from templates | Missing | None |
| Track/album/artist/playlist descriptions | Partial | Track description has UI; album/artist override writers exist with **no UI**; playlist has `description`/`artworkPath` fields with no editor |
| Artist photos and biographies | Missing | No UI |
| Encoding repair | Missing | None |
| Missing/inconsistent tag detection | Partial | Fallbacks to filename/folder/artist exist; no report |
| Preview changes before saving | Missing | Save applies immediately |
| Revert app-managed edits | Done | Per-track "Reset to original" |
| File paths / technical file info | Missing | No screen exposes path, bitrate, sample rate, or size |

### 6. Lyrics

| Feature | Status | Evidence / gap |
| --- | --- | --- |
| Embedded USLT | Done (MP3, best effort) | Hand-written ID3 parser (`lyrics/id3.ts`) |
| Embedded SYLT | Done (MP3, best effort) | Same parser, timed lines |
| Local LRC sidecar | Done | `resolveLyrics` reads `<track>.lrc` |
| Sync highlight | Done | `activeLyricIndex` with offset |
| Automatic scrolling | Done | Scrolls the active line into view |
| Tap line to seek | Done | Uses `line.time + offset` |
| Manual timing offset | Done | Persisted per track in MMKV |
| Online lookup + cache | Missing | No network |
| Translation | Missing | None |
| Full-screen lyrics | Partial | Bottom sheet covers most of the player; no dedicated mode |
| Karaoke display | Missing | None |
| Edit/save lyrics | Missing | Read-only |
| Import/export LRC | Missing | None |
| Badly synced lyrics | Partial | Offset is the only remedy |
| Manual search/association | Missing | None |

### 7. Search

| Feature | Status | Evidence / gap |
| --- | --- | --- |
| Local search | Done | In-memory filter over `displayTracks` and raw tags |
| Grouped results | Missing | One "All songs" section |
| Fields | Partial | Title, artist, album only; filename, genre, composer, album artist are not searched |
| Recents | Done | Five entries, clear action |
| Suggestions / fuzzy / accent-insensitive | Missing | Raw `toLowerCase().includes` |
| Search within lyrics | Missing | None |
| Filters and result sort | Missing | None |
| Voice search | Missing | None |
| Offline indexing / partial-index search | Partial | Pure in-memory filter; the scan publishes tracks only when complete, so there is nothing to search mid-scan |
| Shortcuts / quick actions | Partial | Result tap plays; no row actions |

### 8. Interface and personalization

| Feature | Status | Evidence / gap |
| --- | --- | --- |
| Light / dark / auto | Done | Theme context + system scheme |
| AMOLED | Missing | Dark palette is graphite, not pure black |
| Dynamic colors from artwork | Partial | Player palette + backdrop glow derive from artwork; the app theme uses a separate seed |
| Accent colors / palettes | Done | Five swatches, five palette styles |
| Custom fonts | Missing | Bundled Atkinson/Bricolage only |
| Mini-player / full player | Done | Hoisted mini-player; full player screen |
| Expandable queue | Missing | None |
| Swipe actions / long-press menus | Partial | Swipe favorite/add-to-playlist and `⋯` menus; no long-press |
| Configurable gestures | Missing | None |
| Haptics | Done | Toggle in Settings, used throughout |
| Animations / reduced motion | Done | Reanimated presets, system-aware reduced motion |
| Visualizers / spectrum | Missing | `SoundWave` component is unused |
| Customizable tabs / bottom navigation | Missing | Fixed four tabs |
| Blurred backgrounds / gradient backdrops | Partial | Layered translucency (no real Android blur, documented) + artwork glow |
| Adjustable player layouts | Missing | One layout |
| Customizable home sections | Missing | Fixed sections |
| Tablet / foldable / landscape | Missing | `orientation: "portrait"`, `supportsTablet: false` |
| Localization / RTL | Missing | English strings inline; no i18n layer |
| Edge-to-edge / gesture nav | Done | Safe areas; predictive back disabled |
| Custom app icons | Missing | Static adaptive icon |
| Persistent UI preferences | Done | MMKV-backed theme, accent, backdrop, motion, haptics |
| Confirmation dialogs | Done | Shared `AppDialog` for destructive actions |
| Empty / loading / error states | Done | Shared primitives and banners |

### 9. Accessibility

| Feature | Status | Evidence / gap |
| --- | --- | --- |
| Screen-reader labels | Done (broad) | Explicit labels on playback, rows, sheets, dialogs |
| Large text | Partial | RN font scaling is on by default; no layout audit at large scale |
| High contrast / reduce transparency | Missing | No options |
| 48 dp touch targets | Done | Primitives use 44–48 dp; v2.2 device audit measured bounds |
| Reduced motion | Done | Theme motion mode follows the system or is overridden |
| Accessible custom actions for swipe | Partial | Rails are a11y-hidden at rest and a menu provides the same actions |
| Keyboard / focus indicators | Out of scope | Touch-first Android app |
| Accessible playback controls | Done | Labels, state, disabled states |
| System accessibility settings | Partial | Font scaling and reduced motion; no contrast/transparency handling |
| No color-only status | Partial | Icons/labels accompany most states |

### 10. Playlists and queue

| Feature | Status | Evidence / gap |
| --- | --- | --- |
| Create / delete | Done | Sheets + playlist screen |
| Rename / duplicate | Missing | None |
| Add/remove tracks | Done | Row menu, add-songs sheet, playlist screen |
| Add albums/artists/genres/folders | Missing | Track-by-track only |
| Reorder tracks | Missing | No drag or move actions |
| Playlist folders / nesting | Missing | Flat list |
| Smart playlists | Missing | None |
| Import / export playlist files | Missing | None |
| Preserve order | Done | `trackIds` array order is authoritative |
| Missing-entry detection | Partial | Entries are filtered out silently; counts reflect survivors |
| Restore from backups | Missing | `backup.ts` has export/validation but no import path |
| Save / restore queue | Missing | None |
| From history / favorites | Missing | No generator (favorites can be played as a list) |
| Random playlist generation | Missing | None |
| Recently/frequently played playlists | Missing | None |
| Artwork / descriptions | Partial | `Playlist` model has both; UI has a mosaic cover only |
| Counts / total duration | Done | Playlist screen header and subtitle |
| Batch-add from search | Missing | None |
| Shuffle playlist / subset | Done | Whole playlist shuffle |

### 11. Favorites, history, statistics

| Feature | Status | Evidence / gap |
| --- | --- | --- |
| Favorite songs | Done | SQLite `favorites`, URI identity |
| Favorite albums/artists | Missing | None |
| Ratings | Missing | None |
| History with timestamps | Done | `play_history` rows with `played_at` + listened ms |
| Recently played | Done | MMKV recents, 30 entries, shown on Home |
| Most/least played | Missing | Data exists; no query/UI |
| Play/skip counts | Partial | Plays recorded; skips not tracked; nothing displayed |
| Total listening time | Partial | `listening_sessions` has durations; `getNightSummary` is unused |
| Stats by artist/album/genre | Missing | None |
| Daily/weekly/monthly/yearly, year-in-review | Missing | None |
| Clear history | Partial | Clears recents + play history, but **not** `listening_sessions` (`history.ts`) |
| Exclude from statistics | Missing | None |
| Resume unfinished | Missing | None |
| Local-only stats | Done | No network |
| Export history | Missing | None |
| Scrobbling | Missing | None |

### 12. Storage and reliability

| Feature | Status | Evidence / gap |
| --- | --- | --- |
| Local DB for library state | Partial | Playlists/recents/imports in MMKV; overrides, favorites, history, error log in separate SQLite DBs; scanned tracks are **not persisted** |
| Persistence across restarts | Partial | User data persists; the scanned index is rebuilt each launch |
| Schema migrations | Missing | `CREATE TABLE IF NOT EXISTS` only; no version table or migrations |
| Integrity checks | Missing | None |
| Crash recovery | Partial | WAL and guarded writes; no explicit recovery or queue restore |
| Artwork/metadata caching | Done | MMKV tag cache + artwork files |
| Cache size controls / clear temp | Missing | No accounting or clear action |
| Backup/restore | Partial | `exportBackup` and `validateBackup` exist; no UI, no import, no scheduling |
| Settings export/import | Missing | None |
| Interrupted scan | Partial | Debounced pending rescan; no resume or cancellation |
| Corrupted metadata / unreadable files | Done | Per-asset try/catch with safe fallbacks |
| Missing/changed storage location | Partial | Permission recheck + rescan; no repair UX |
| Deleted track detection | Partial | Dropped on rescan; no notice or queue cleanup |
| Duplicate DB entries | Done | URI dedupe; playlist add dedupe |
| Transaction-safe updates | Partial | Single-row upserts; multi-step edits are not in transactions |
| Storage usage monitoring | Missing | None |
| Scheduled backups | Missing | None |
| DB encryption | Missing | Local-only metadata; threat model not documented |
| No account / cloud dependency | Done | None |

### 13. System and device integration

| Feature | Status | Evidence / gap |
| --- | --- | --- |
| Android background service / foreground notification | Done | RNTP service, notification, lock screen |
| Notification permission | Done | Requested on first playback (Android 13+) |
| Runtime audio/storage permission | Done | Granular `audio` permission via MediaLibrary |
| Scoped storage | Done | MediaStore-backed |
| Battery optimization guidance | Missing | None |
| Headphone / Bluetooth media buttons | Done | Native handling |
| System media session | Done | Native session with play/pause/seek/skip |
| Widgets / Quick Settings tile | Missing | Needs native Expo modules |
| Android Auto | Missing | Engine has `setBrowseTree`, unused |
| Car-friendly UI | Missing | None |
| CarPlay / Wear OS / voice assistant | Missing | Out of scope for this Android build |
| Sleep timer / alarm | Partial | Engine timer exists with no UI; end-of-track is a no-op; no alarm |
| Bluetooth output handling | Partial | System routing; no device picker (`OutputDeviceButton` unused) |
| Interruption handling | Done | Focus/exclusive audio |
| Memory/process lifecycle | Partial | Playback survives; UI state is rebuilt |

### 14. File management and utilities

| Feature | Status | Evidence / gap |
| --- | --- | --- |
| Technical file info, path, modification date | Missing | `Track` carries title/artist/album/duration/artwork only |
| Open containing folder | Missing | None |
| Share audio files | Missing | None |
| Delete audio files | Missing | None |
| Rename/move files | Missing | None |
| Ringtone | Missing | None |
| Unsupported/corrupted file detection | Partial | Errors are caught and logged; no scan report |
| Library / storage usage | Missing | None |
| Clear artwork/temp caches | Missing | None |
| Export playlists/settings | Missing | None |
| Diagnostic logs | Done | SQLite error log + screen |
| Share diagnostics | Done | `Share` action on the error log |
| About / OSS licenses / version | Done | Settings |
| Reset settings without deleting music | Partial | `resetPreferences` exists; no UI |
| App lock / privacy screen | Missing | None |

### 15. Permissions, privacy, security

Strong: only `READ_MEDIA_AUDIO`/legacy read plus `POST_NOTIFICATIONS` in
`app.json`; runtime audio permission with rationale and "open settings" on
blocked; scoped storage; no account, no cloud, no network calls; file access
is read-only with edits stored locally; external imports are copied into the
app sandbox; paths are not displayed; history can be cleared.

Partial: revoked-permission handling is limited to scan/foreground rechecks;
malformed-file protections are try/catch around hand-written ID3/LRC parsers
with no size caps or fuzz tests; multi-step metadata writes are not
transactional; DB encryption is absent and the threat model is undocumented.

### 16. Online integrations

None. This satisfies the offline core requirement trivially, but it also means
there is no network abstraction, auth/token store, rate-limit handling, or
service-status UI to build on. Any future lyrics/artwork/scrobble lookup must
be added behind an explicit opt-in and must never gate local playback. The
spec's licensing caveat (remote streams are not offline files) should be
encoded in the data model when that work starts.

### 17. Podcasts and audiobooks

Missing: no separate libraries, chapter parsing, bookmarks, per-book speed,
resume per recording, skip intervals, finished markers, or feeds. The engine
primitives that would help (`setPlaybackSpeed`, `seekBy`,
`sleepAfterMediaItemAtIndex`, `contentType: 'speech'`) are available.

### 18. Internet radio and casting

Missing: no station directory/URL entry, no stream status, no reconnect, no
Chromecast/DLNA. The engine's `isLive` media items, `CastButton`, and
`OutputDeviceButton` are unused building blocks.

### 19. Advanced and specialty

Missing: automatic queue generation, rule-based smart lists, local
recommendations, song recognition, party mode, custom audio profiles,
multi-library, LAN/cloud sync, remote control, voice, alarm, plugins, custom
fields, file-organization tools. Some are feasible later on top of the
statistics/metadata work; plugins are not practical in an Expo app.

### 20. Performance and resource management

| Feature | Status | Evidence / gap |
| --- | --- | --- |
| Fast initial load | At risk | Cold start enumerates all assets and rebuilds the index; tags are cached, but the track list is not persisted |
| Incremental scanning | Partial | Tag reads skip unchanged files by modification time; the asset list is always refetched and every change rebuilds the whole list |
| Background indexing | Missing | Scan requires the app to be running |
| Efficient queries | Done | In-memory maps; one query for all overrides |
| Virtualized long lists | **Missing** | No `FlatList`/`SectionList`; every screen uses `ScrollView` + `map` |
| Lazy artwork / thumbnails | Partial | Files are cached and images are decoded by RN; every row still mounts |
| Bounded memory / eviction | Missing | All tracks, all queue items, and an unbounded artwork cache |
| Battery-efficient polling | Partial | 4 s MediaStore fingerprint only while foreground |
| Large libraries | Untested | Blocking risk from unvirtualized lists |
| Search while scanning | Missing | Results only exist after the scan publishes the list |
| Avoid unnecessary rescans | Done | Fingerprint comparison |
| Low-memory recovery | Missing | No handling |
| Startup/playback restoration | Missing | No queue/position persistence |

### 21. Testing, diagnostics, maintenance

The unit suite is runnable again after this pass: four Jest suites, 12 tests,
covering album grouping/multi-disc order, the library fingerprint, lyric
view/offset, and repeat/shuffle helpers. Everything else is manual or absent:
no format playback matrix, offline-mode tests, large-library tests, playlist
file tests, metadata read/write tests, artwork-cache tests, migration tests,
backup/restore tests, background/audio-focus automation, permission-revocation
tests, storage-removal tests, corrupted-file tests, profiling, automated
accessibility/screen-size checks, or online-service integration tests.
Diagnostics exist (error log + share); crash recovery is untested.

### 22. Platform-specific

Android local playback, background service, media session, notification, and
MediaStore scanning are done. Android Auto, widgets, QS tile, SD-card edge
cases, iOS background audio/CarPlay/Files, macOS/Windows/Linux integration are
absent. `PRODUCT.md` defines the product as Android, so non-Android rows are
out of scope until that changes. Format and audio-effect availability must be
verified per device and engine — the current app has no such verification
matrix.

## Engine capability notes (RNTP 5.12.1)

Available and unused: `setPlaybackSpeed`, `getQueue`, `insertMediaItem(s)`,
`moveMediaItem`, `removeMediaItem(s)`, `clear`, `skipToIndex`, `retry`,
`sleepAfterMediaItemAtIndex`, `getSleepTimer`, `setVolume`, `seekBy`,
`preload`/`clearCache`, `setBrowseTree` (Android Auto/CarPlay),
`OutputDeviceButton`, `CastButton`, `AirPlayButton`.

Not available: equalizer/bass boost/virtualizer/reverb, ReplayGain/loudness
normalization, balance/mono/limiter, gapless configuration, crossfade, skip
silence. `QueueChangedEvent` is typed `never`, so a queue UI must keep its own
mirror refreshed on transitions and mutations.

Licensing note: the installed package header states commercial use requires a
licence (rntp.dev/pricing). Distribution terms should be confirmed before
shipping beyond the current private build.

## Findings from this pass

1. **End-of-track sleep is a no-op.** `startSleepEndOfTrack` sets a flag; no
   code calls `sleepAfterMediaItemAtIndex`. The timed sleep has no UI either.
2. **Playback speed is stored, never applied.** `setPlaybackRate` writes MMKV
   but does not call `TrackPlayer.setPlaybackSpeed`; the "V5 does not expose
   setRate" comment is stale (the API is `setPlaybackSpeed`).
3. **Nothing restores on cold start.** The selected track is `recents[0]`;
   queue, index, and position are lost. Combined with the unpersisted index,
   every launch starts from an empty list.
4. **No list virtualization.** `ScrollView` + `map` on Home, Library, Search,
   Album, Artist, Playlist. This is the largest large-library risk.
5. **Scan progress copy is misleading.** Home renders
   "`${library.tracks.length} songs found so far`" while scanning, but
   `scannedTracks` is only set once at the end, so it always shows 0 (or the
   previous library).
6. **Unreachable building blocks.** `exportBackup`/`validateBackup`,
   `upsertAlbumOverride`/`upsertArtistOverride`, `getNightSummary`,
   `getRecentSessions`, `SoundWave`, `filteredTracks`/`query`, and
   `resetPreferences` (no UI) have no consumers. `preferences.ts` still
   defaults `lastSoundId` to `'rain-on-fir'`, a leftover from the sleep-sound
   origin.
7. **Clear-history inconsistency.** `clearRecentHistory` clears recents and
   `play_history` but leaves `listening_sessions` rows behind.
8. **Two search implementations.** The Search tab filters locally and never
   uses `library.query`/`filteredTracks`.
9. **Artwork cache is append-only.** `.none` markers and JPEGs accumulate with
   no accounting, eviction, or user-facing clear.

## Verification performed

```
npx tsc --noEmit   → exit 0  (tests are now part of the program)
npx expo lint      → exit 0
npx jest           → 4 suites, 12 tests passed
```

The test runner was repaired in this pass: `jest-expo` + Jest 30 were added
as SDK-58-compatible dev dependencies, the `node:test` suites were converted
to Jest, `tests/` was re-included in `tsconfig`, and a `test` script was
added. No device, build, or audio-format verification was run.

## Recommended sequencing

### P0 — finish the core

1. **Queue sheet** (M): mirror the RNTP queue in `PlayerContext`, expose
   play-next/add-to-queue, reorder (move), remove, clear, and "save as
   playlist". Read `getQueue()` on mount and on `MediaItemTransition`.
2. **Restore and persist** (M): persist a compact library snapshot for cold
   start, plus last track, queue, index, and position; hydrate before autoplay.
   Add a real scan progress count and cancel.
3. **Virtualize lists** (M): `FlatList` for songs/search/album/artist/playlist
   with artwork windowing; keep the grouped-row look.
4. **Sort and filter** (M): sort sheet (title/artist/album/date added/duration/
   year) and filters (genre/year/format) with persisted defaults. Requires
   `dateAdded` and `format` on `Track` at scan time.

### P1 — everyday usability

5. **Sleep timer UI** (S) and wire end-of-track to
   `sleepAfterMediaItemAtIndex`; apply playback speed via `setPlaybackSpeed`
   (S) and verify pitch behavior on device.
6. **Playlist operations** (M): rename, duplicate, reorder, missing-entry
   report; M3U/M3U8/PLS import/export; backup import UI using the existing
   validation.
7. **Metadata depth** (M): composer and disc fields, batch edit, album/artist
   description editors, folder-image fallback, artwork cache accounting +
   clear, and a file-info panel.
8. **Search upgrade** (M): grouped results, filename/genre/composer/album
   artist fields, accent-insensitive normalization, and filter chips; fold the
   library query into it.
9. **Stats and home** (M): recently added, most played, play/skip counts,
   listening-time summary, and a year-in-review scaffold; fix clear-history to
   cover sessions.
10. **Personalization/a11y** (M): AMOLED theme, high-contrast and
    reduce-transparency options, landscape/tablet support, and an i18n
    scaffold with RTL.

### P2 — advanced

11. Online lyrics/metadata/art with an explicit opt-in, cache, and offline
    failure states (§16 rules); translation behind the same boundary.
12. Smart playlists as a rule engine over metadata + stats.
13. EQ/ReplayGain: native audio-effects module or engine replacement; document
    device support. Gapless/crossfade needs similar native investment.
14. Podcast/audiobook libraries and chapter/bookmark model, reusing speed,
    seek intervals, and speech content type.

### P3 — optional

Android Auto browse tree, widgets/QS tile, casting, Wear, radio directory,
cloud sync, song recognition. Each is a native or network project and should
not block the P0–P2 path.

## Limits of this audit

- No device run: playback behavior, audio focus, notification, and artwork
  rendering are assessed from code and the v2.2 audit, not re-tested.
- Format support claims are engine/platform expectations, not measured on the
  test device.
- Counts are qualitative; rows group related spec bullets, so a single
  "Missing" can cover several checklist items.
- The uncommitted v2.3 tree is included; anything rewritten before commit will
  shift the affected rows.
