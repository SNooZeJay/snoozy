# Snoozy v1.7 — full audit report

Date: 2026-10-21/22 · Device: Oppo CPH2325 (A55 4G), Android 13, 720×1600 · adb serial `9PGE8SQKAM598PBY`
APK under audit: `artifacts/snoozy-arm64-release.apk` — versionName **1.7.0**, versionCode **7**, arm64-v8a, V2 signed `CN=Snoozy Release`.
Method: on-device walk-through of every reachable flow, with screenshots in `artifacts/audit/` and `dumpsys` checks for headless states (audio focus, media session, playback advancement). Code inspection used only to establish root causes, never to substitute for device evidence.

A late defect batch (LRC ID tags, playlist-sheet plural, Add-songs keyboard, error-log writer) was fixed after the walk; those rows are re-verified on the rebuilt APK and marked `PASS (rebuilt)`.

The rebuilt APK (51,792,122 bytes, SHA-256 `0F6520…DF533`, same versionName 1.7.0 / versionCode 7, V2 signer unchanged) was installed over the walk build with `adb install -r` (Success) and re-used for every post-fix check. Evidence `11–59` was captured on the walk build; evidence `60–76` on the rebuilt APK. The rebuilt artifact is canonical: `artifacts/snoozy-arm64-release.apk`.

---

## Verdict at a glance

| Status | Count |
|---|---|
| PASS | 16 |
| PASS (rebuilt, re-verified) | 3 |
| PARTIAL | 6 |
| FAIL | 0 |
| NOT IMPLEMENTED (by scope) | 5 |
| NOT TESTED (blocked / no fixture) | 3 |

Counts cover the 33 matrix rows. The four audit-walk defects are fixed and re-verified on the rebuilt APK (evidence `62`, `64`, `65`, `74`, `66–69`, `75`). Everything the user called out — duplicate time rows, the Lyrics/Edit button pair, and the app-wide hierarchy/typography drift — is fixed and verified. The app plays, scans, edits, favorites, builds playlists, records errors, survives the screen being off for 32 minutes, and persists metadata edits across a cold start.

---

## Audit matrix

### Playback

| # | Feature | Status | Evidence / notes |
|---|---|---|---|
| 1 | Scan & library count (v1.1) | **PASS** | 14 tracks after launch scan (`12-library-songs.png`). The 12 pushed WAVs were initially invisible because MediaStore had them `is_pending=1, duration=NULL` — an indexing artefact of `adb push`, not an app bug; `content call scan_volume` re-indexed them (`is_pending=0, duration=150000`). App count and list then matched MediaStore exactly. The Settings **Scan library** button also re-indexes on demand: after restoring a deleted file via adb, tapping it picked the track up and the "Updated" timestamp moved 12:42 → 12:53 (`63-scan-library.png`). |
| 2 | Play / pause / seek / mini / full player (v1.1) | **PASS** | Full player `15-player.png`; seek jump to 1:16 `16-player-seek.png`; mini-player and queue playback `36-queue-03.png`. Seek, transport and progress all behaved. |
| 3 | Next / previous / queue advance (v1.4) | **PASS** | 14-song queue: Next 03→04 (`37-queue-next.png`), Prev within 3 s 04→03 (`38-queue-prev.png`). Prev at >3 s restarts the current track (`17-player-prev.png`) — intended rule. |
| 4 | Queue sheet, drag reorder, player shuffle/repeat (v1.4) | **NOT IMPLEMENTED** | No queue sheet or reorder UI exists; the player has no shuffle/repeat buttons (scope decision). Album page has a working **Shuffle** that starts a randomised album queue (`44-album-shuffle.png`); `PlayerContext.toggleShuffle` exists (`src/playback/PlayerContext.tsx:309`) but no control uses it. *What it would take:* a queue modal reading the native queue + move command (`move`/remove+insert), and two player toggles: shuffle rebuilds the queue from the current list; repeat maps to `RepeatMode.Queue/Track`. |
| 5 | Background playback, screen off ≥30 min (v1.5) | **PASS** | S3 final: SnoozyTest 01 with the full 13-item queue (12 SnoozyTest + test tone) started 23:55:32 (device-local) and the screen was locked. At 00:13 `dumpsys media_session` was `state=3`, active item 8, still advancing. The queue ran to its natural end ~00:27:37 — **32 min 5 s of screen-off playback** — and the final dumpsys (00:27:41) showed `state=1`, active item 13, position 5015/5000 ms (test tone finished). Lock screen at end: `60-s3-lockscreen-end.png`; full timeline in `S3-CHECKPOINT.txt`. Note: the device clock later resynced to network time mid-session, and the status-bar clock renders 12-hour — the evidence here is the self-consistent dumpsys timeline, not wall-clock strings. |
| 6 | Restore after kill / paused state (v1.4) | **PARTIAL** | After `am force-stop` + relaunch the mini-player restores the **last title** (`59-favorites-persist.png`), but playing it fails silently (`state=NONE`) because only the selected id is kept and there is no queue/position restore (`PlayerContext.tsx:90` seeds `selectedId` from recents; no persistence of queue/index/position). *What it would take:* persist queue ids + index + position in MMKV on change; on boot re-resolve ids against the fresh scan and `setQueue` + `skip` + `seek`. |

### Library, metadata, playlists, search

| # | Feature | Status | Evidence / notes |
|---|---|---|---|
| 7 | Favorites add/remove/list/play/persist (v1.2) | **PASS** | Toggle + favorites tab (`14-favorites.png`); playing from favorites uses the favorites list as queue; hearts and entries survive force-stop (`59-favorites-persist.png`). |
| 8 | Metadata edit → live propagation, search by original, reset (v1.3) | **PASS** | Renamed SnoozyTest 01 → “Audit Edit 01”: player title and artwork letter update immediately (`21-player-edited.png`), library/favorites/playlists show the new title (`22-library-edited.png`, `27-playlists.png`), searching the **original** name still finds it (`23-search-original.png`). Reset restores title/artwork everywhere without interrupting playback (`39-edit-reset.png`, `40-reset-player.png`, `41-reset-library.png`). Edit persistence across a cold start was verified on the rebuilt APK: a "Persist" title edit survived `am force-stop` + relaunch in the library and mini-player (`70-edit-saved.png`, `71-edit-persist.png`), and searching the **original** name still found the renamed track (`72-search-original-persist.png`); the title was restored to the original afterwards. |
| 9 | Playlist create / add / add-songs / remove / delete (v1.7) | **PASS (rebuilt)** | Song-row “+” sheet (`25-add-to-playlist.png`) → Jayzee shows **Added** (`26-addto-added.png`); create-then-add from the sheet works (“Audit Run” appears checked/Added, `31`/`32`); playlist card lists tracks with display titles, Add songs, per-track remove, delete (`27-playlists.png`, `33-playlist-created.png`); remove from sheet returns count to 2 (`30-addsongs-removed.png`); delete confirms then removes the card (`34-delete-confirm.png`, `35-playlist-deleted.png`). Defect found: “1 tracks” in the sheet — fixed (`AddToPlaylistSheet.tsx` pluralisation); Add-songs sheet hid behind the keyboard — fixed (KAV). Both re-verified on the rebuilt APK: the sheet shows **1 track** for Solo (`64-playlist-singular.png`) and **2 tracks** for Jayzee with the Add-songs filter field fully visible and usable above the keyboard — “07” typed, one result shown (`65-addsongs-filter-kav.png`); the Add-to-playlist sheet likewise stays above the keyboard with Create reachable (`74-addtoplaylist-kav.png`). Temp playlist Solo created and deleted to restore state. |
| 10 | Album & artist pages (v1.5) | **PASS** | Albums aggregate (`42-albums.png`) → album page with “14 tracks · 33 min”, Play and working Shuffle (`43`, `44`); artists aggregate (`45-artists.png`) → artist page with Albums + Songs (`46-artist-page.png`). |
| 11 | Search: results, edited+original matching, recents (v1.5/v1.7) | **PASS** | Result list and “1 result” (`54-search-12.png`); matches edited **and** original titles (`23-search-original.png`); recents persist newest-first with Clear (`24-search-recents.png`); tapping a recent refills the query and shows results (`47-recent-tap.png`); Clear empties the section (`48-recents-cleared.png`). |
| 12 | Library sort & folder filter (v1.4) | **NOT IMPLEMENTED** | No sort menu and no folder filter in the UI. *What it would take:* add `relativePath` to the scan mapping, then a sort menu (title/artist/album/recent, persisted) and a folder chip filter over that field. |
| 13 | Recently played threshold/order/clear (v1.4) | **PARTIAL** | Home section is wired (`src/app/(tabs)/index.tsx:125`) and history is recorded (`src/storage/playHistory.ts`); entries appear newest-first. Re-verified live on the rebuilt APK (`73-home-recently-played.png`): after the metadata/playback session the list reads SnoozyTest 01 → SnoozyTest 12 → 05 → 04 → 03 → RED 99 → test tone, i.e. genuinely newest-first with real artwork letters. No **Clear** control exists. *What it would take:* one Clear action calling `clearPlayHistory()` with a confirm. |
| 14 | Backup export/import merge/replace (v1.4) | **NOT IMPLEMENTED** | Storage module exists; no screen or file picker. *What it would take:* a Settings entry + SAF save/open, wire the existing merge/replace/validate functions. |

### Lyrics

| # | Feature | Status | Evidence / notes |
|---|---|---|---|
| 15 | `.lrc` sidecar load + sync + offset UI (v1.2) | **PASS (rebuilt)** | Sidecar found automatically; 20 lines shown, offset controls (−500/Reset/+500), source caption “Source: .lrc file” (`18-lyrics.png`). Defect found: `[ti:…]`/`[ar:…]` ID tags rendered as lyric lines (root cause `src/lyrics/lrc.ts:30` — every untimed line pushed as text). Fixed by skipping bracketed ID-tag-only lines; re-verified on the rebuilt APK with the same fixture — the sheet starts on lyric text (“Test line 1…”) and no `[ti:]`/`[ar:]` lines render (`62-lyrics-fixed.png`). |
| 16 | Embedded lyrics USLT / SYLT (v1.2) | **NOT TESTED** | Code paths exist (`src/lyrics/index.ts:50,54`, `id3.ts`), but no test track with embedded lyrics was available; only the sidecar path was exercised. |
| 17 | Lyric offset persistence (v1.2) | **NOT TESTED** | Offset buttons are present; whether the offset survives closing the sheet / changing tracks was not exercised. |

### System integration

| # | Feature | Status | Evidence / notes |
|---|---|---|---|
| 18 | Notification media controls (v1.5) | **PASS** | Media card shows title/artist + prev/pause/next (`49-notification.png`); tapping pause flips the icon and `dumpsys media_session` reports `state=2, speed=0` (`50-notification-paused.png`); resume returns `state=3`. ColourOS marquee-clips the long title in the shade; the lock-screen card renders it fully (system-rendered layout, app metadata correct). |
| 19 | Lock-screen controls (v1.5) | **PASS** | Full card: app label, track, artist, output chip, prev/pause/next while playing (`51-lockscreen.png`); playback advanced 04→09 with the screen off (`52-unlock-state.png`). |
| 20 | Audio focus loss / regain (v1.5) | **PASS** | Video recording (Camera) takes focus: Snoozy `state=3 → 2` (paused) during recording, then `state=3` at the same position after stop — auto-resume works (`53-camera.png` + dumpsys logs). No other music app was used. |
| 21 | Headset unplug / reconnect (v1.5) | **NOT TESTED** | No wired headset available. `handleAudioBecomingNoisy: true` is set (`src/playback/player.ts:17`), but the row cannot be evidenced without hardware. |
| 22 | Sleep timer (v1.5) | **NOT IMPLEMENTED** | Timer state and the `SleepTimerTriggered` listener exist (`PlayerContext.tsx:359`), no UI. *What it would take:* a row in the player offering 15/30/45/60 min and “end of track”, calling the existing setter, plus a small countdown label. |
| 23 | Playback speed UI (v1.5) | **NOT IMPLEMENTED** | RNTP V5 exposes `NativeTrackPlayer.setPlaybackSpeed(speed)` and `PlayerContext` already restores a persisted rate, but there is no control. *What it would take:* one button/row cycling 0.75×/1×/1.25×/1.5× calling `setPlaybackRate`. |
| 24 | Error log: record + share + clear (v1.5) | **PASS (rebuilt)** | Walk-through found the screen but the log could never fill: `logError()` had **zero callers**; the playback error only set UI state (`PlayerContext.tsx:377`). Proven on device: deleting the playing file triggered `state=7, error=Source error`, yet Error log said “No errors recorded.” (`56-error-state.png`, `58-errorlog-empty.png`). Fixed by persisting `PlaybackError` events (category `playback`, track id) in `PlayerContext`. Re-verified on the rebuilt APK end-to-end: the player shows the dismissible banner first (`66-player-error-banner.png`), the entry appears with category, message and track id (`67-errorlog-entry.png`), Share opens the Android sheet carrying the payload (`68-errorlog-share.png`), Clear asks to confirm (`75-errorlog-clear-confirm.png`) and then empties to “No errors recorded.” (`69-errorlog-cleared.png`). The log also kept a second live entry from the restored file's transient error across unrelated screens (writer robustness). |
| 25 | About screen (v1.5) | **PARTIAL** | Shows **Version 1.7.0 · Android · arm64**, **Build 7**, and the palette-engine licence (`13-settings-about.png`, `57-settings-diagnostics.png`). Missing: a full OSS licence list and the Android OS version string. |

### Quality gates

| # | Item | Status | Evidence / notes |
|---|---|---|---|
| 26 | Loading / empty / error states (v1.2 §10) | **PARTIAL** | Empty search and empty recents are designed and readable (`48-recents-cleared.png`), library empty-state copy exists. Playback errors render a dismissible banner on the full player — now evidenced on the rebuilt APK (`66-player-error-banner.png`) — but a source error on Search/Library still surfaces nothing there. Loading states were not captured. |
| 27 | Contrast (v1.2) | **PASS** | Measured against `background #07110D`: ink `#F3F0E4` **16.80:1**, inkMuted **10.80:1**, inkFaint **6.44:1**, accent **15.92:1**, danger **9.72:1**; accentInk on accent **11.89:1**; inkMuted on surfaceRaised **8.95:1**; danger on surfaceMuted **7.30:1**. All body text ≥ AA; tertiary text (inkFaint) is AA for normal text but below AAA. |
| 28 | Touch targets (v1.2) | **PARTIAL** | Primary rows and tabs are ≥48 px; several icon-only controls are 40 px with `hitSlop` 8–10 (playlist add, remove, sheet close). Eyeballed from screenshots; no programmatic hit-area measurement. |
| 29 | Reduced motion (v1.2) | **PARTIAL** | The Motion setting persists (Follow system / Reduced / Full, `57-settings-diagnostics.png`), and `ThemeContext` derives `reducedMotion` (`src/theme/ThemeContext.tsx:98`), but **no component reads it** — animations still run. *What it would take:* gate the Animated calls (player artwork pulse, sheet fades) on `useTheme().reducedMotion`. |
| 30 | Visual consistency (user complaint) | **PASS** | Duplicate time row removed and Lyrics/Edit are now a single icon row (`15-player.png` vs pre-fix `03-player.png`); micro type is sentence case app-wide (11/12/13); uppercase overline is restricted to form labels and “NOW PLAYING”; all sheets share scrim `rgba(0,0,0,0.6)`, `surfaceRaised` panel, heading + icon close (`19`, `25`, `28`). Native Alert dialogs remain platform-styled (`34-delete-confirm.png`, `39-edit-reset.png`) — documented, not themed. |
| 31 | Scope compliance (no network/AI/new native deps) | **PASS** | No network, resolver, streaming or AI code paths; no new native modules; `package.json` unchanged apart from the version. |
| 32 | Gates: `tsc --noEmit`, `expo lint` | **PASS** | tsc exit 0; lint **0 errors**, 9 pre-existing warnings (array-type, exhaustive-deps, duplicate import). Both re-run after the late fixes. |
| 33 | Release build & signing | **PASS** | `assembleRelease` (arm64) `BUILD SUCCESSFUL`; APK 51,792,122 bytes, versionCode 7, V2 signer `CN=Snoozy Release, OU=M0, O=Snoozy`. The rebuilt APK was installed over the on-device walk build with `adb install -r` (Success) and launched without crash; versionName 1.7.0 / build 7 confirmed on device. It is now the canonical release artifact under `artifacts/`. |

---

## Defects found during the audit (and their fate)

| Defect | Root cause | Status |
|---|---|---|
| LRC metadata tags shown as lyrics (`[ti:]`, `[ar:]`) | `src/lyrics/lrc.ts:30` pushed every untimed line as a lyric | Fixed in rebuilt APK; re-verified |
| Add-to-playlist sheet says “1 tracks” | `src/components/AddToPlaylistSheet.tsx:138` hard-coded plural | Fixed; re-verified |
| Add-songs filter hides the whole sheet behind the keyboard | `AddSongsSheet` lacked keyboard avoidance; Android Modal window doesn't resize | Fixed with `KeyboardAvoidingView behavior="padding"`; re-verified |
| Error log can never fill | `logError()` had no callers; playback errors only set transient UI state | Fixed: `PlaybackError` events are persisted with track id; re-verified |
| Restored last track cannot play after a rescan | Only the selected id is restored; queue/position are not persisted; a re-added file gets a new MediaStore id | Documented as PARTIAL with the restore design sketched above |
| “Recent searches” were claimed but absent | Build had no recents store | Implemented and verified (`24`, `47`, `48`) |
| Playlist create→add lost the track | Async `persistPlaylists` raced a stale `playlistsRef` | Fixed with synchronous ref update; verified create-then-add (`32`) |
| Metadata overrides were not displayed anywhere | Scan results rendered directly; display layer absent | Fixed with `displayTracks` layers; verified edit/search/reset (`21`, `23`, `40`) |

Pre-existing v1.7 fixes (duplicate time row, Lyrics/Edit text buttons, uppercase micro labels, sheet unification) are recorded in `docs/DEBUG-v1.7.md` and verified in screenshots 11–21.

---

## Not implemented (by explicit scope) — what it would take

- **Queue sheet + drag reorder** — queue modal + native move/remove-insert; drag library (`react-native-draggable-flatlist`) would be a new dependency, so a long-press “move up/down” menu is the dependency-free route.
- **Player shuffle / repeat buttons** — `toggleShuffle` and `RepeatMode` wiring exist; add two icon toggles and rebuild the queue on shuffle.
- **Sleep timer UI** — state + native event already exist; add the control row and a countdown.
- **Playback speed UI** — one control calling the existing rate setter.
- **Library sort / folder filter** — needs `relativePath` during scan mapping, then a sort menu and folder chip.
- **Backup screen** — storage module exists; needs a SAF picker screen.
- **Recently played Clear** — one button over `clearPlayHistory()`.
- **Reduced-motion behaviour** — read `reducedMotion` in animated components.
- **Full OSS licence list on About** — static list/generator.

## Not tested / partially tested

- **Headset unplug / reconnect** — no wired headset on hand.
- **USLT/SYLT embedded lyrics** — no fixture with embedded lyrics; only the `.lrc` sidecar path was exercised.
- **Lyric offset persistence** — buttons present, persistence untested.
- **Artwork pick (Choose image)** — partially exercised: the system photo picker opens from the edit sheet and the `ExpoCropImageActivity` crop surface is reachable (`76-imagepicker-crop.png`); selection of a test image worked, but the chosen image was a billing screenshot, so crop/back was cancelled and the save/render step is not evidenced. No app state was changed by this.

## Visual evidence index

`artifacts/audit/` — `11` home, `12` library (14 songs), `13` About, `14` favorites, `15` player, `16` seek, `17` prev-restart, `18` lyrics, `19` edit sheet, `20` edit input, `21` player after save, `22` library after save, `23` search by original title, `24` recent searches, `25` add-to-playlist sheet, `26` added state, `27` playlists, `28` add-songs sheet/added, `29` filter, `30` remove/card, `31` create form, `32` created+added, `33` new playlist card, `34` delete confirm, `35` deleted, `36` queue start, `37` next, `38` prev, `39` reset confirm, `40` player after reset, `41` library after reset, `42` albums, `43` album page, `44` album shuffle, `45` artists, `46` artist page, `47` recent tap, `48` recents cleared, `49` notification, `50` notification paused, `51` lock screen, `52` lock-screen advance, `53` camera focus trigger, `54` search 12, `55` stale track ended, `56` source error, `57` settings diagnostics/About, `58` empty error log, `59` favorites after force-stop. Rebuilt-APK evidence: `60` S3 lock screen at natural end, `61` unlock during S3, `62` lyrics after the ID-tag fix, `63` Scan library refreshed, `64` "1 track" plural, `65` Add-songs filter above keyboard ("07" result), `66` player error banner, `67` error-log entry, `68` error-log Share sheet, `69` error log cleared, `70` "Persist" edit saved, `71` "Persist" survives force-stop, `72` original-name search over renamed track, `73` Home recently-played (newest-first), `74` add-to-playlist sheet above keyboard, `75` Clear-error-log confirm, `76` photo-picker crop surface. Plus `S3-CHECKPOINT.txt` (screen-off playback timeline).

## Verdict

v1.7 is shippable for the stated scope: local playback, library, metadata edits, favorites, playlists, search and background/lock-screen controls work and are evidenced. The four audit-walk defects are fixed and re-verified on the rebuilt APK, which also re-passed every affected row (lyrics, pluralisation + keyboard avoidance, scan button, metadata persistence, recently-played ordering, error log round-trip) and the quality gates. The remaining gaps are either explicitly out of scope (with sized work) or blocked by missing hardware/fixtures. The rebuilt APK signed `CN=Snoozy Release` is the release artifact.
