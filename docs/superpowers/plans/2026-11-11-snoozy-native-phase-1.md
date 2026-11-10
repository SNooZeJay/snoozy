# Snoozy Native Phase 1: Skeleton, Theme, Navigation Shell

Date: 2026-11-11
Spec: `docs/superpowers/specs/2026-11-11-snoozy-native-glasmio-design.md`
Roadmap: `docs/superpowers/plans/2026-11-11-snoozy-native-glasmio-roadmap.md`

## Goal

A signed native build with the real Snoozy identity and five working root tabs, installed over 2.3.0 without losing app data.

## Task 1: Project files

Create:

- `android-native/settings.gradle.kts`
- `android-native/build.gradle.kts`
- `android-native/gradle.properties`
- `android-native/gradle/wrapper/*` copied from the Glasmio clone
- `android-native/gradlew`, `gradlew.bat`
- `android-native/app/build.gradle.kts`
- `android-native/app/src/main/AndroidManifest.xml`
- `android-native/.gitignore`

Build config:

- namespace and applicationId `com.snoozy.app`
- compileSdk 37, targetSdk 37, minSdk 33
- versionCode 14, versionName 3.0.0
- NDK ABI filter arm64-v8a
- Compose enabled
- `dev` build type: debuggable, signed with the release key when env vars exist, otherwise debug
- `release` build type: minify, signed with the release key
- dependencies: Glasmio scaffold, activity-compose, Feather icons, JUnit, Compose UI test

Expected: `gradlew.bat :app:assembleDev` produces an APK.

## Task 2: Fonts and launcher resources

- Copy Bricolage Grotesque 600 and 500 and Atkinson Hyperlegible 400 and 700 into `app/src/main/res/font/`.
- Copy the existing Snoozy launcher foreground, background, and monochrome assets into `res/drawable` and wire an adaptive icon.
- Add a splash background color `#080E09` and a window background that avoids a white flash.

Expected: app label "Snoozy", adaptive icon, no missing resource errors.

## Task 3: Theme

Files:

- `ui/theme/SnoozyColors.kt`
- `ui/theme/SnoozyType.kt`
- `ui/theme/SnoozyTheme.kt`

`SnoozyColors` defines the emerald palette from the spec. `SnoozyType` builds a Material3 `Typography` with the bundled fonts and Snoozy tracking values. `SnoozyTheme` wraps `GlasmioTheme(isDark, colorScheme = glasmioColorScheme(isDark, accent), typography, colors = defaultGlassColors(isDark, accent), appearance = GlassAppearance(reduceTransparency = glassMode == Reduced))`.

Dark is the default; the system setting is honored.

Expected: `SnoozyTheme { Text("Snoozy") }` compiles with the bundled fonts.

## Task 4: Feather icons

Files:

- `ui/icons/Feather.kt`

Re-export the icons the app needs as stable `ImageVector` properties, for example `Feather.Home`, `Feather.Library`, `Feather.Search`, `Feather.List`, `Feather.Settings`, `Feather.Play`, `Feather.Pause`, `Feather.SkipBack`, `Feather.SkipForward`, `Feather.Shuffle`, `Feather.Repeat`, `Feather.Heart`, `Feather.MoreHorizontal`, `Feather.Edit3`, `Feather.Music`, `Feather.Headphones`.

Use the verified package `compose.icons`. Do not add a font-based icon fallback.

Expected: an icon renders in the shell.

## Task 5: Navigation shell

Files:

- `ui/navigation/NavKey.kt`
- `ui/navigation/SnoozyNavHost.kt`
- `ui/screens/PlaceholderScreen.kt`
- `MainActivity.kt`

`NavKey` roots: Home, Library, Search, Playlists, Settings. Detail keys are added in later phases.

`SnoozyNavHost` mirrors the Glasmio sample:

- `SnapshotStateList<NavKey>` back stack saved with `listSaver`.
- `GlasmioNavHeaderMotion` with Tab, Push, Pop classification.
- `GlasmioNavigationScaffold` with header specs, page bodies, and `GlasmioTabBar`.
- `GlasmioNavDisplay` with iOS transitions.
- Bottom bar and mini player slot reserved above the tab bar.
- Edge-to-edge with transparent system bars.

Root tabs use Feather icons and accessible labels. Each placeholder screen shows the screen title and a one-line description of the phase that fills it.

Expected: all five tabs switch, the header morphs, back exits from a root.

## Task 6: Signing and install over 2.3.0

- Read signing values from the existing environment variables: `SNOOZY_KEYSTORE_FILE`, `SNOOZY_KEYSTORE_PASSWORD`, `SNOOZY_KEY_ALIAS`, `SNOOZY_KEY_PASSWORD`.
- Build `dev` signed with the release config.
- `adb install -r`.
- Compare `run-as com.snoozy.app ls files` before and after.

Expected: install succeeds over 2.3.0, `files/SQLite`, `files/mmkv`, and `files/Music` still exist.

## Task 7: Verification

- `gradlew.bat :app:assembleDev`
- `gradlew.bat :app:testDebugUnitTest`
- `gradlew.bat :app:lintDebug`
- Install and screenshot each tab.
- `adb shell dumpsys gfxinfo com.snoozy.app framestats` while scrolling Home.
- `adb logcat -b crash` is empty.

Expected: build green, five screenshots, no crash, median frame under 32 ms.

## Out of scope

Playback, scanning, database reads, search logic, player, lyrics, editing, and settings controls. Those are phases 2 through 7.
