# Snoozy v2.2 audit — visual system and release

Audit window: 2026-10-23 → 2026-10-25
Status: **PASS for the release scope, with the limits listed at the end.**

The signed `2.2.0` / `12` APK was built, installed over the existing app without
losing data, and checked on the Oppo CPH2325 test device. The checks covered the
theme matrix, Library hierarchy, persistent mini-player, themed dialogs, hidden
swipe rails, playback transport, and settings persistence.

## Final artifact

- `artifacts/snoozy-arm64-release-v2.2.apk`
- Size **51,870,098 bytes**
- SHA-256 **AED3C60B539EA609C94DF28CC6B6DD6226EC706F162FF9DB2C06E21C916D10AE**
- Package `com.snoozy.app` · versionName **2.2.0** · versionCode **12** ·
  ABI `arm64-v8a` only
- APK Signature Scheme v2 verified:
  `CN=Snoozy Release, OU=M0, O=Snoozy, L=Local, ST=Local, C=US` · RSA 2048
- `zipalign -c 4`: `Verification successful`
- JS bundle: **3,545,384 chars**; includes `Close dialog`, `no-hide-descendants`,
  and the v2.2 theme markers
- Build: `assembleRelease -PreactNativeArchitectures=arm64-v8a` →
  `BUILD SUCCESSFUL in 2m 1s`; 1017 actionable tasks, 32 executed,
  985 up-to-date
- Device install: `adb install -r` → `Success`

## What changed

| Area | File | Result |
| --- | --- | --- |
| Themed dialogs | `src/components/AppDialog.tsx` | Opaque `palette.surface` panel, five action slots fit above the usable window, navigation-bar safe, scrim and danger styling. Replaces every native `Alert.alert`. |
| Swipe actions | `src/components/SwipeableRow.tsx` | Action rails are transparent, pointer-inert, and accessibility-hidden at rest; they appear only for the open row. |
| Library | `src/app/(tabs)/library.tsx` | Five equal segments, compact grouped rows, themed menus/playlist flows, themed delete dialog. |
| Home | `src/app/(tabs)/index.tsx` | Themed clear-history and delete-playlist dialogs, shared hierarchy. |
| Error Log | `src/app/error-log.tsx` | Themed clear-log confirmation. |
| Song editor | `src/components/SongEditSheet.tsx` | Inline Reset confirmation, no native alert. |

No new dependencies were added. The green glass identity, fonts, S mark,
four tabs, playback model, storage, and navigation behavior are unchanged.

## Device and builds

- Device: Oppo CPH2325, Android 13, 720×1600 at density 320.
- Test transport: wireless ADB `192.168.1.9:5555`; the connection re-enumerated
  several times and was reconnected between checks. Screen recording was denied
  by the device (`/system/bin/screenrecord` → `Permission denied`), so hierarchy
  dumps, logs, and bounds are the primary evidence. Intermittently ghosted
  screenshots were not treated as proof of a visual pass.
- Cold launch (clean install/relaunch): `Status: ok`, `LaunchState: COLD`,
  `TotalTime 1597`, `WaitTime 1604`; a later cold launch measured `1650`/`1656`.
  `ReactNativeJS: Running "main"` appeared and there was no fatal exception.
- Build log: `C:\Users\Administrator\AppData\Local\Temp\opencode\build-v2.2-dialogfix.log`.
- Signing values stayed in the private keystore properties. A debug-signed APK
  produced during the investigation was discarded and never promoted.

## Theme matrix

| Check | Evidence | Result |
| --- | --- | --- |
| Light mode | Inspected Home, Library, row menu, player, lyrics, edit sheet, Error Log, and dialogs. Four-action dialog actions were fully visible after the surface/nav fixes. | Readable; no clipped action labels |
| Dark mode | Same surfaces after restoring the intended defaults. | Readable; scrim and surfaces distinct |
| Auto mode | Selected Auto; system `cmd uimode night no` produced a light screen (average brightness 234.9), `cmd uimode night yes` produced a dark screen (38.4), and returning to light produced 239.1. | Auto follows the system |
| Auto persistence | Force-stop/cold relaunch with Auto selected; Settings still reported Auto selected and the light system mode was followed. | Persisted |
| Restored defaults | Dark, Tonal spot, green `#B8F0B0`, backdrop on at 60%, motion Follow system, haptics on. Verified selected/checked states and rechecked after a cold launch. | Persisted |

Average brightness was sampled from full-screen captures on a fixed grid. It is
used only to distinguish light from dark; it is not a replacement for visual
review.

## Mini-player and tabs

Every tab was checked after switching:

| Tab | Mini-player nodes | Player bounds | Track |
| --- | ---: | --- | --- |
| Home | 1 | `[42,1286][558,1374]` | `SnoozyTest 02` |
| Search | 1 | `[42,1286][558,1374]` | `SnoozyTest 02` |
| Library | 1 | `[42,1286][558,1374]` | `SnoozyTest 02` |
| Settings | 1 | `[42,1286][558,1374]` | `SnoozyTest 02` |

The mini-player remained a single hoisted node with the same bounds and track
across all four tabs. The tab bar itself is outside the scroll content and keeps
one selected tab.

`dumpsys gfxinfo` after scripted tab switches:

- Rapid pass: 12 frames, 11 janky (91.67%), 50th percentile 73 ms.
- Slower pass: 10 frames, 9 janky (90%), 50th percentile 73 ms.

These numbers reflect the test device's frame pacing during scripted changes,
not a claim of 60 fps. The hierarchy and persistence checks are the correctness
evidence; no duplicate mini-player or remounted tab content was observed.

## Library

Five-segment bounds (fully inside the 720 px display):

| Segment | Bounds |
| --- | --- |
| Songs | `[40,210][162,306]` |
| Albums | `[170,210][291,306]` |
| Artists | `[299,210][421,306]` |
| Playlists | `[429,210][550,306]` |
| Favorites | `[558,210][680,306]` |

Verified flows:

- Songs, Albums, Artists, Playlists, and Favorites switch without clipping.
- Row menu opens; favorite/unfavorite, Add to playlist, and playlist selection
  work.
- Swipe Playlist and swipe Unfavorite rails work only on the row being swiped.
- Create playlist, add song, remove song, and delete playlist (themed dialog)
  all completed.
- Temporary playlist `AuditTemp` and test playlist `SnoozyTest 01` were created
  and removed; the favorites state for `SnoozyTest 01` was restored.
- At rest the SwipeableRow hierarchy exposed **0** action nodes; with one row
  open it exposed **2**, matching the two actions for that row.

## Playback and sheets

- Row tap played `SnoozyTest 01`; the player opened from the mini-player.
- Pause showed `Play`; resume showed `Pause`.
- Seek at 50% produced `Playback position, 1:15 of 2:30`.
- Next advanced to `SnoozyTest 03`; Previous returned to `SnoozyTest 02`.
- Player artwork, lyrics, and the edit sheet rendered; seek, play/pause, next,
  and previous controls had correct accessibility labels and bounds.
- The player’s repeat/shuffle controls are not exposed in this revision; album
  shuffle remains available. This is pre-existing behavior, not a v2.2 change.

`RED 99` is a stale test-library row and reports `0:00 of 0:00`; transport checks
used only `SnoozyTest 01–03`.

## Dialogs and accessibility

- The native clear-log dialog exposed these nodes while visible:
  `Clear error log`, `Delete all entries?`, `Clear`, and `Cancel`, all inside
  the usable 720×1496 window.
- Four-action dialogs were checked in Light and Dark after the opaque-surface
  and bottom-inset fix; every action was fully visible and tappable.
- The inline Reset confirmation inside `SongEditSheet` rendered visibly with
  title, message, `Reset`, and `Cancel`.
- UIAutomator did not expose the inline Reset dialog nodes while it was visible.
  This may be a dump/accessibility artifact of the surrounding sheet Modal; it
  is recorded as an open verification limit rather than claimed as verified
  accessibility.
- The backdrop `Close dialog` button and each action have explicit
  accessibility roles/labels. The swipe rails are marked inaccessible at rest.

## Static gates and install

```
npx tsc --noEmit        → exit 0
npx eslint src --no-cache → exit 0
npx expo-doctor         → 19/20 checks; only patch-version mismatches
```

`expo-doctor` reports patch-level mismatches for the Expo SDK packages; no
structural or config check failed. The APK was installed with `adb install -r`
over the existing release install; app data was retained.

## Remaining limits

1. `screenrecord` is blocked on the device, and captures are intermittently
   ghosted. Hierarchy bounds, `gfxinfo`, and logs are authoritative.
2. Scripted tab switches showed janky frames on the low-end test device. No
   frame-accurate 60 fps claim is made.
3. The inline Reset dialog is visually correct but its nodes were not exposed by
   UIAutomator in the tested state.
4. `RED 99` remains an unplayable legacy test row. It is not used for release
   checks and is not part of the app source.
5. The player repeat/shuffle controls are absent from this player revision;
   album shuffle is available separately. This predates v2.2.
6. A warm-start measurement was not recovered after wireless ADB dropped; the
   cold-start measurements and bundle/install evidence are recorded above.

## Release conclusion

The v2.2 visual system is installed and behaves as intended for the release
scope. The signed artifact above is the release candidate promoted for this
audit; no debug-signed APK is used.
