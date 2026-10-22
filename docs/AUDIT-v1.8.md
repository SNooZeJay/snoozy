# Snoozy v1.8 audit - iOS-style visual redesign (Android)

Date: 2026-10-22
Status: **READY - v1.8 visual redesign verified on device.** Final APK installed and audited. One pre-existing v1.2 limitation is disclosed below (theme settings persist but do not recolor the static screen palette); it was not introduced by v1.8 and is outside the visual-pass scope.

## Scope

Visual-only redesign of the four tabs and shared chrome to the supplied reference: an iOS-style design language on Android (large titles, grouped rounded cards, segmented pills, floating icon-only pill bar, dotted-circle empty states). No new screens, features, data, network, streaming, AI, or native modules. Fonts, wordmark, tab set, and all v1.1-v1.7 behavior are preserved.

## Final artifact

- `artifacts/snoozy-arm64-release.apk` (canonical; promoted after the runtime audit)
- Size **51,803,434 bytes** · SHA-256 `384394C336074CFEB9CE71603E4B2E240E602369BB49987B34CBD16DAB94E7CF`
- Package `com.snoozy.app` · versionName **1.8.0** · versionCode **8** · arm64-v8a only
- APK Signature Scheme v2 `CN=Snoozy Release` · `zipalign -c 4` OK · JS bundle **3,484,584 bytes**
- Build: `gradlew.bat -p C:\s\android assembleRelease -PreactNativeArchitectures=arm64-v8a` -> BUILD SUCCESSFUL in 1m 25s (32 executed tasks, stale bundles deleted)
- Install: `adb install -r` over wireless ADB -> Success; device reports 1.8.0 / code 8
- v1.7 canonical is preserved as `artifacts/snoozy-arm64-release-v1.7.apk` (51,792,122 bytes, SHA-256 `0F6520…DF533`)

## Pre-work (items 1-5)

1. **Reference anatomy** - Home (SNOOZY overline + "Your music", circular top-right action, Recently card, Playlists +, Library browse button), Library (segmented pills, playlist card), Search (rounded field + filter motif, "All songs", dotted empty), Settings (Library row + mint Scan pill, Haptics, About), floating 4-icon bar with mint active squircle. Excluded: "Library sits near" copy, large trash hero, Share button, phone frames.
2. **Token/type audit** - palette kept (`#07110D` background, `#13261C` card, `#D8F2C6` mint). Fonts/type scale frozen: Bricolage Grotesque display/heading, Atkinson Hyperlegible body; display 43, title 30, heading 22, body 16, label 13, micro 12, overline 11. Only `layout` tokens changed.
3. **Icon strategy** - Feather via already-installed `@expo/vector-icons` 15.1.1 (MIT, Cole Bemis), 24 px / 2 px round; zero Ionicons remain. No new packages.
4. **Navigation** - Expo Router `Tabs` rejects a custom `tabBar`; native bar hidden and replaced with an overlay pill bar driven by `usePathname()` + `router.navigate()`.
5. **v1.7 PARTIAL remediation** - rows 13, 25, 26, 28, 29 fixed/verified; row 6 (playback restore) remains open per v1.7.

## tryliner reference study

Taken: one accent per state, content-first gaps, minimal chrome, floating icon-only navigation. Rejected: streaming/API/auth, WebGL, Tailwind, Zustand. No code or assets copied.

## Screen-by-screen changes

| Surface | Path | Change |
| --- | --- | --- |
| Floating bar | `src/app/(tabs)/_layout.tsx` | Native bar hidden; floating pill (h 62, radius 31), four icon-only 48 dp tabs, active tab in a 52x46 mint squircle on the standard spring; reduced motion uses a zero-duration timing snap. |
| Home | `src/app/(tabs)/index.tsx` | SNOOZY overline + "Your music" + circular import action; Recently card with Clear + dotted empty state; Playlists + note tiles; Library "See all" + "Browse all songs"; existing permission/scanning/error cards kept. |
| Library | `src/app/(tabs)/library.tsx` | Segmented pills (34 dp visual in 48 dp target, mint active); playlist cards with "N tracks", Add songs, note tiles, per-row remove X and "..." delete; error banner retained. |
| Search | `src/app/(tabs)/search.tsx` | 52 dp pill field with search glyph, filter motif / clear; "All songs" + count; dotted "No matching tracks."; centered dotted idle state + Browse library; recents kept; error banner retained. |
| Settings | `src/app/(tabs)/settings.tsx` | Grouped cards: Library row + mint Scan pill, Haptics row, Appearance (mode, palette style, swatches, backdrop + intensity), Motion, About (S mark, version/OS/arm64, error log, full OSS list). |
| Shared | `src/components/Thumb.tsx`, `MiniPlayer.tsx`, sheets/player | Thumb/NoteTile/DottedNote with mint letter fallback; MiniPlayer floats above the bar; Feather throughout; 48 dp icon targets. |

## Fonts

Unchanged and verified: Bricolage Grotesque 500/600, Atkinson Hyperlegible 400/700; no hard-coded family outside `tokens.ts`; type scale unchanged.

## Icons

Feather from `@expo/vector-icons` 15.1.1, MIT, Cole Bemis; 24 px / 2 px round; no Ionicons; no new packages.

## Tokens old -> new

`layout` only:

| Token | v1.7 | v1.8 |
| --- | --- | --- |
| `screenPadding` | - (new) | 20 |
| `cardRadius` | - (new) | 28 |
| `tabBarSpace` | 84 | **216** |
| `tabBarHeight` | - (new) | 62 |
| `tabBarInset` | - (new) | 12 |
| `pillGap` | - (new) | 12 |

Colors, spacing, radii, type, motion, shadows unchanged.

## Runtime verification

Device: Oppo CPH2325 (A55 4G), Android 13 (API 33, `Platform.constants.Release` = "13"), 720x1600, density 320. Wireless ADB `192.168.1.9:5555`; USB serial `9PGE8SQKAM598PBY` was unreliable and used only as fallback.

### v1.8 screens (evidence `artifacts/audit/`)

| Shot | What it proves |
| --- | --- |
| `78-v18-home.png` | Home final: recently rows newest-first, mint letter tiles, Playlists +, Library browse, MiniPlayer, pill bar |
| `80-v18-library.png` | Library songs: 14 songs, segmented pills, mint letters, rows |
| `81-v18-settings.png` | Settings grouped cards, Scan pill, Haptics switch row |
| `82-v18-home-empty.png` | Recently Clear -> dotted + "No tracks played yet." |
| `83-v18-settings-about.png` | Version 1.8.0 (8) · Android 13 · arm64; Error log row; OSS list |
| `84-v18-settings-reduced.png`, `85-v18-reduced-home-snap.png` | Reduced active; immediate Home capture shows the pill already snapped |
| `89-v18-library-playlists.png` | Playlists: Jayzee "2 tracks", Add songs, "..." menu, remove X |
| `90-v18-addsongs-kav.png` | Filter "07": one result above the keyboard; sheet controls reachable |
| `91-v18-search-empty.png` | Empty Search with centered Browse library (fix verified) |
| `92-v18-search-results.png` | 12 results above keyboard, clear control |
| `94-v18-search-noresults.png` | "No matching tracks." dotted empty |
| `95-v18-library-error.png`, `97-v18-search-error.png` | Source error banners on Library and Search, dismiss controls |
| `96-v18-player-testtone.png` | Player opens; test tone at 0:05/0:05 |
| `98-v18-settings-scan.png` | Scan triggered; Library Updated time moved 8:12:29 PM -> 8:36:22 PM (later launch rescan 8:50:58 PM) |
| `100-v18-lyrics.png` | Lyrics sheet: Test lines 1-12, no `[ti:]`/`[ar:]` tags |
| `101-v18-edit-saved.png`, `102-v18-home-persist.png`, `103-v18-search-original-persist.png` | Edited title "QA Persist 01" survives cold start; original-title search still finds it |
| `104-v18-errorlog.png` | Playback "Source error" entries persisted in Error log |
| `105-v18-addsongs-singular.png`, `106-v18-playlist-singular.png` | AddSongs header and playlist card show "1 track"; 0 tracks / 2 tracks also verified |
| `107-v18-settings-backdrop.png` | Settings bottom / OSS list incl. Feather MIT |

Before images are v1.7 shots `11-76` (same folder). Shots `86-88` and `93` are retained as the honest light/accent/cleared-search states; see the limitation below.

### v1.7 PARTIAL rows

| Row | Result | Evidence |
| --- | --- | --- |
| 13 Clear recently | **PASS** | Confirm -> dotted "No tracks played yet."; persists empty after navigation/relaunch |
| 25 About OS/licences | **PASS** | "Android 13" (was "Android 33"), version/code, arm64, Error log, full OSS incl. Feather MIT |
| 26 Library/Search errors | **PASS** | Corrupt `test_tone.wav` produced native `Source error`; both banners rendered and recorded in Error log; file restored (MD5 `690fb9c5316a629ec8ccbcd22857f6df`), playback recovered after restart |
| 28 48 dp targets | **PASS (with notes)** | Error close 32 px + `hitSlop` 8 = 48 dp; Haptics/Backdrop rows now whole-row Pressables (604x104 px = 52 dp, toggled by tapping the label); intensity chips `minWidth 48`; Search input 50-52 dp; MiniPlayer info +2 dp hitSlop = 48; tabs `minHeight 48`; segments 48 dp wrapper/34 dp pill; rows min 48. uiautomator clips tab/segment bounds at the nav-bar edge; source sizes are 48 dp. |
| 29 Reduced motion | **PASS** | Reduced chip active; immediate post-tap Home capture shows the pill at target; code uses `withTiming(..., {duration: 0})` and keeps fades |

### Regression reruns

- **Scan:** Updated 8:12:29 PM -> 8:36:22 PM, 14 songs (later relaunch 8:50:58 PM).
- **Plurals:** AddSongs header and playlist card: "0 tracks", "1 track", "2 tracks".
- **Keyboard avoidance:** Add songs filter "07" keeps the single result and controls above the keyboard.
- **Lyrics:** sidecar .lrc shows Test lines 1-12 only.
- **Error log:** Source error entries with timestamps `10/22/2026 8:26:08-8:26:55 PM`.
- **Metadata persistence:** "SnoozyTest 01" -> "QA Persist 01" survived force-stop/relaunch; original-title search matched; Reset restored "SnoozyTest 01".
- **Recently order:** after playing test tone then SnoozyTest 01, Home shows SnoozyTest 01 first (newest-first).

### Frame rate

Raw traces: `artifacts/audit/latency-scroll-v18g.txt`, `latency-tabs-v18g.txt` (`dumpsys SurfaceFlinger --latency`, app layer `com.snoozy.app/com.snoozy.app.MainActivity#601`).

- **List scroll:** 125 frame intervals, median **17.10 ms -> 58.5 fps**, mean 17.1 ms, min 16.83 / max 17.37 ms.
- **Tab/pill switching:** 124 intervals, median **17.11 ms -> 58.5 fps**, mean **18.2 ms -> 54.9 fps**, one 85.49 ms transition spike; 570 frames rendered, gfxinfo 16.49% janky over the 10.5 s run.

### Pre-existing v1.2 theme limitation (disclosed)

- Tapping **Light** persists (`selected=true`) but the tabs stay on the static dark palette (`86-v18-home-light.png`, `87-v18-settings-light.png`).
- Tapping a purple accent persists the seed but the UI stays mint (`88-v18-home-accent-purple.png`).
- Cause: screens/components import the static `colors` object from `src/theme/tokens.ts`; no component consumes `useTheme().tokens` (grep-verified). This was already true before v1.8; the v1.2 report listed dynamic color as partial and untested. Fixing it requires a cross-screen dynamic-style refactor, which is outside this visual-only pass. It is not counted as a v1.8 regression or as working.

## Done / partial / not done

- **Done:** all four tabs and shared chrome restyled; floating icon-only bar; Thumb/NoteTile/DottedNote; Feather migration (0 Ionicons); token additions; v1.7 rows 13/25/26/28/29 verified; scan, plurals, KAV, lyrics, error log, metadata persistence, Recently order rerun; fps measured; signed arm64 APK installed, audited, promoted to canonical.
- **Partial (pre-existing, unchanged):** v1.2 light/accent settings persist but do not recolor screens; album-art thumbs still fall back to letter tiles for scanned tracks (`Track.artwork` is never populated by scan).
- **Not done (out of scope):** v1.2 dynamic-style refactor; row 6 playback restore (open per v1.7).

## Unverified

1. Real album-art thumbnails (no artwork fixtures on device; letter fallback exercised).
2. Full TalkBack pass (labels/roles present; only spot checks).
3. Long-session memory/battery behavior.
4. iOS build (Android-only deliverable).
5. USB-cable stability (wireless ADB used for the audit).
