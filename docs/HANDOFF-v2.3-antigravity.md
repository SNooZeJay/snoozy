# Handoff: finish Snoozy v2.3 interaction port on Antigravity

Written 2026-11-11. Continue from here; this file is the source of truth for the handoff.

## What Snoozy is

Snoozy is a local-first Android music player for one person on a phone. It scans on-device audio and plays it with a persistent queue, a mini-player, a full now-playing screen, background playback, and a media notification. Users can search, browse albums, artists and genres, favorite tracks, manage playlists, read synced lyrics, and edit metadata. Everything stays offline: no account, no network layer, no uploads, no tracking. The UI keeps the emerald accent, Bricolage Grotesque and Atkinson Hyperlegible fonts, Feather icons, and a Cupertino/Liquid Glass look.

Product target: fast one-thumb access to local music, playback that survives the screen going dark or the app leaving the foreground, and no data leaving the device.

Technical target: Android only, portrait, package `com.snoozy.app`, minSdk 24, targetSdk 36, arm64-v8a release, verified on the Oppo A55 (Android 13, 720x1600 at 320 dpi).

Note: `PRODUCT.md` is legacy and mentions possible future online resolution. The current app has no network layer and must stay that way.

## Goal

Port Glasmio's iOS 27 interaction model into Snoozy, keep Snoozy's emerald identity and Bricolage/Atkinson fonts, then build, install, and verify on the connected Oppo A55. Behavior and motion matter more than static visual cloning. The result must be smoother and more stable than the Glasmio demo, especially on this phone.

## Repository and build tree

- Repo: `D:\OWN_PROJECTS\SNOOZY`
- Git baseline: `9a12ed6` (v2.2.0). All v2.3 work is uncommitted on `release/v1.9`.
- Build tree: `C:\s` (JS root plus the generated native project at `C:\s\android`).
- Build-tree sources are already synced, including the latest fixes. Edit only the repo, then sync; never edit both copies.
- App: `com.snoozy.app`, version `2.3.0`, versionCode `13`, arm64-v8a only.
- Device: Oppo CPH2325 (A55), Android 13 / API 33, 720x1600 at 320 dpi, serial `9PGE8SQKAM598PBY`.
- Installed app is an earlier v2.3.0 build (versionCode 13). Install over it with `-r` to keep data.

## What is already done

- `react-native-gesture-handler` 3.4.0 added as a direct dependency and linked.
- Shared motion math in `src/motion/chrome.ts` with unit tests in `tests/chromeMotion.test.ts`.
- Global scroll driver in `src/motion/scrollState.ts` (`tabScrollY`, `resetTabScroll`).
- `src/components/CollapsingHeader.tsx` with `useCollapsingScroll` and `CollapsedBar`.
- Collapsing title bars on Home, Playlists, Settings, Album, Artist, Genre, Playlist.
- Library and Search report scroll offset through animated lists, so the tab bar shrinks there too.
- Tab bar shrinks 62 to 52, labels fade, selection pill recenters, MiniPlayer docks with the same value.
- `SheetPanel` rewritten with a gesture-handler grabber pan, velocity-aware dismissal and spring snap-back. It wraps its content in a nested `GestureHandlerRootView` so the pan works inside React Native `Modal`.
- Player drags down from the header to dismiss and scales/parallaxes artwork on scroll.
- `GestureHandlerRootView` added at the app root.
- Glasmio attribution added to the Settings OSS list.
- Last static pass: `npx tsc --noEmit` clean, `npx expo lint` clean, Jest 7 suites / 34 tests passing, `npx expo-doctor` 19/20 with only pre-existing SDK patch-version warnings.

## What is not done

1. No release APK has been built since the gesture-root and attribution fixes.
2. No install or device verification for this build.
3. `docs/BUILD.md` has no v2.3 entry.
4. `artifacts/README.md` still names v1.8 as canonical, and no `snoozy-arm64-release-v2.3.apk` exists.

## Do first

Create a checkpoint commit or a git worktree before editing, so the uncommitted v2.3 tree cannot be lost. Do not commit unless the user asks.

## Build

Run static gates in the repo:

```powershell
cd D:\OWN_PROJECTS\SNOOZY
npx tsc --noEmit
npx expo lint
npx jest --silent
```

Sync repo to the build tree and delete stale JS bundles:

```powershell
robocopy "D:\OWN_PROJECTS\SNOOZY\src" "C:\s\src" /MIR /NFL /NDL /NJH /NJS /NP
robocopy "D:\OWN_PROJECTS\SNOOZY\assets" "C:\s\assets" /MIR /NFL /NDL /NJH /NJS /NP
Copy-Item "D:\OWN_PROJECTS\SNOOZY\app.json" "C:\s\app.json" -Force
Copy-Item "D:\OWN_PROJECTS\SNOOZY\package.json" "C:\s\package.json" -Force
Get-ChildItem "C:\s\android\app\build" -Recurse -Filter *.bundle -ErrorAction SilentlyContinue | Remove-Item -Force
Remove-Item "C:\s\android\app\build\outputs\apk\release\app-release.apk" -Force -ErrorAction SilentlyContinue
```

Build with JDK 17 and the existing release keystore. The values stay in `C:\Users\Administrator\.snoozy\keystore.properties`; never print or commit them.

```powershell
$jdk = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot'
$env:JAVA_HOME = $jdk
$env:Path = "$jdk\bin;$env:Path"
$props = @{}
Get-Content 'C:\Users\Administrator\.snoozy\keystore.properties' | ForEach-Object {
  $line = $_.Trim()
  if (-not $line -or $line.StartsWith('#')) { return }
  $idx = $line.IndexOf('=')
  if ($idx -lt 1) { return }
  $props[$line.Substring(0, $idx).Trim()] = $line.Substring($idx + 1).Trim()
}
$env:SNOOZY_KEYSTORE_FILE = $props['storeFile']
$env:SNOOZY_KEYSTORE_PASSWORD = $props['storePassword']
$env:SNOOZY_KEY_ALIAS = $props['keyAlias']
$env:SNOOZY_KEY_PASSWORD = $props['keyPassword']
cmd /c "C:\s\android\gradlew.bat -p C:\s\android assembleRelease -PreactNativeArchitectures=arm64-v8a --no-daemon"
```

Expect `BUILD SUCCESSFUL`. Output: `C:\s\android\app\build\outputs\apk\release\app-release.apk`. If the build fails, read the Gradle error before changing code.

## Install and verify on the phone

```powershell
adb devices
adb -s 9PGE8SQKAM598PBY install -r "C:\s\android\app\build\outputs\apk\release\app-release.apk"
adb -s 9PGE8SQKAM598PBY shell am force-stop com.snoozy.app
adb -s 9PGE8SQKAM598PBY shell monkey -p com.snoozy.app -c android.intent.category.LAUNCHER 1
```

Check for crashes:

```powershell
adb -s 9PGE8SQKAM598PBY logcat -d -t 400 | Select-String -Pattern 'FATAL EXCEPTION|AndroidRuntime|ReactNativeJS'
```

Verification checklist:

- Home: scroll about 300 px. The large header scrolls away, a compact title bar fades in, the tab bar shrinks, labels fade, the pill stays centered, and the MiniPlayer docks down. Scroll back up and confirm everything reverses.
- Switch through all five tabs. Each scrolls, the bar collapses, and switching tabs resets it.
- Open an album, an artist, a genre, and a playlist. Scroll each; the compact bar with a working back button fades in.
- Play a track. Open the full player. Drag down from the header or grabber: the player follows and dismisses past the threshold, otherwise springs back. Scroll the player content and confirm the artwork scales down without jank.
- Open the queue sheet or an add-to-playlist sheet. Drag the grabber down: the sheet follows the finger and dismisses on distance or flick, otherwise springs back. Confirm the queue list still scrolls inside its 78% max height.
- Confirm no frame drops during list flings. Do not add blur during scrolling.
- Confirm TalkBack labels and 44/48 dp targets are intact. The compact bar title is duplicated for screen readers when invisible; if TalkBack reads it, add `importantForAccessibility="no-hide-descendants"` while inactive.
- Capture screenshots for the record.

## Finish the records

- Copy the APK to `D:\OWN_PROJECTS\SNOOZY\artifacts\snoozy-arm64-release-v2.3.apk`.
- Record size and SHA-256 (`Get-FileHash -Algorithm SHA256`).
- Rewrite the canonical entry in `artifacts/README.md` (it is stale and has broken characters; write clean ASCII).
- Add a v2.3 section at the top of `docs/BUILD.md` with intent, static gates, build result, artifact details, install result, and what was verified on device.
- Update the OSS notices only if another library was added.

## Constraints and known risks

- Keep the current Argon baseline. Remove regressions; do not revert to pre-Argon.
- Keep Bricolage Grotesque and Atkinson Hyperlegible. Keep the emerald accent.
- Keep all real features working: scanning, playback, metadata editing, favorites, playlists, lyrics, queue, search. No mock controls.
- Keep offline local-first behavior, portrait Android layout, Feather icons, reduced-motion support, contrast, and accessible labels.
- Stability budget: no blur during list flings, no per-frame JS state, no bitmap capture, at most one live backdrop surface animating.
- Deferred on purpose: shared-element mini-player morph, JS 70/30 parallax stack, context menus, two-detent sheets. Do not claim them as shipped.
- `borderCurve: 'continuous'` is iOS-only in RN 0.88; Android corners are circular.
- `SheetPanel` now has an intermediate `GestureHandlerRootView` with `flexGrow: 0` and `flexShrink: 1`. The queue sheet layout is the one place to inspect for clipped content.
- `tabScrollY` resets on route change, so returning to a previously scrolled tab may show the bar expanded for a frame. This is accepted.
- Do not run `npx expo prebuild --clean` in `C:\s`; the native project is already generated and signed.
- Do not trust memorized Expo APIs. Read the versioned docs for SDK 58 per `AGENTS.md`.

## Reference material

- Glasmio source clone: `C:\Users\Administrator\AppData\Local\Temp\opencode\Glasmio`
- Sheet constants: `glasmio-scaffold\src\main\java\io\github\neoruaa\glasmio\scaffold\SheetMotion.kt`
- Geometry: `docs/design-reference.md` in that clone
- Glasmio is Apache-2.0. Attribution is already in Settings.
- `docs/COVERAGE-v2.3.md` is an older audit and does not describe the current UI. Do not treat it as current.
- `PRODUCT.md` is legacy. `DESIGN.md` does not exist.
