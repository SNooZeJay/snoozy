# Snoozy M0 build record

Date: 2026-10-21

## Status

**Release build: PASS.** The signed arm64 release APK was produced and copied
to `artifacts/snoozy-m0-arm64-release.apk`.

**Device acceptance: NOT RUN.** No Android device is enumerated by ADB, so the
install, five on-device smoke checks, startup/memory measurements, and the
10-minute playback gate are unverified. This document records build evidence
only; it is not a claim that the runtime gate passed.

## Deliverable

| Field | Value |
|---|---|
| APK | `artifacts/snoozy-m0-arm64-release.apk` |
| Size | `54,506,031` bytes |
| SHA-256 | `AAE28330F27AC985AE24FF79DA17D1459BB815A95BF0ECCF62CB76A6C3E0434C` |
| Package | `com.snoozy.app` |
| Version | `1.0.0` (versionCode `1`) |
| ABI | `arm64-v8a` only |
| minSdk / targetSdk / compileSdk | `24` / `36` / `37` |
| Signature | APK Signature Scheme v2 verified |
| Signer SHA-1 | `E7:6C:25:3D:80:A9:CB:E0:DE:C6:2F:F1:A1:EF:7F:4E:67:EB:EC:12` |

The APK also passes `zipalign -c -v 4`.

## Project and versions

- Root: `D:\OWN_PROJECTS\SNOOZY`
- Scaffold: `create-expo-app@5.0.0`, blank TypeScript template
- Expo SDK: `58.0.16`
- React Native: `0.88.0`
- React: `19.3.0`
- TypeScript: `6.0.3`
- Router: Expo Router, entry `expo-router/entry`
- New Architecture: enabled
- Native folders: Android only; no `ios/` directory
- Dev client: `expo-dev-client` `58.0.14`
- Android Gradle Plugin: `9.2.1`
- Gradle wrapper: `9.4.1`
- JDK: Eclipse Temurin `17.0.20.101`
- Android build-tools: `37.0.0`
- Android NDK: `27.1.12297006`
- CMake: `3.22.1`

Resolved Expo/native dependency versions:

| Package | Version |
|---|---:|
| expo | 58.0.16 |
| react-native | 0.88.0 |
| react | 19.3.0 |
| @shopify/react-native-skia | 2.14.0 |
| react-native-reanimated | 4.7.1 |
| react-native-worklets | 0.13.0 |
| react-native-mmkv | 4.3.2 |
| expo-sqlite | 58.0.13 |
| react-native-image-colors | 2.6.1 |
| @rntp/player | 5.12.1 |
| expo-router | 58.0.24 |
| expo-dev-client | 58.0.14 |
| expo-asset | 58.0.17 |
| expo-constants | 58.0.12 |
| expo-linking | 58.0.13 |
| expo-system-ui | 58.0.6 |
| react-native-safe-area-context | 5.10.1 |
| react-native-screens | 4.30.0 |

`youtubedl-android` was not installed.

## Build environment

The release build requires:

```text
JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot
ANDROID_HOME=D:\Android\Sdk
ANDROID_SDK_ROOT=D:\Android\Sdk
SNOOZY_KEYSTORE_FILE=C:\Users\Administrator\.snoozy\snoozy-release.jks
SNOOZY_KEYSTORE_PASSWORD=<from keystore.properties>
SNOOZY_KEY_ALIAS=snoozy-release
SNOOZY_KEY_PASSWORD=<from keystore.properties>
```

The successful command was:

```powershell
C:\s\android\gradlew.bat -p C:\s\android assembleRelease `
  -PreactNativeArchitectures=arm64-v8a --no-daemon --console=plain
```

The command reported `BUILD SUCCESSFUL in 26m 4s` with 1017 executable tasks.
The full log is `artifacts/release-build-7.log`.

The build was run from the short-path mirror `C:\s`; the source of truth
remains `D:\OWN_PROJECTS\SNOOZY`. The mirror was created after the final source
changes and the completed APK was copied back to `artifacts/`. Building from
`D:\OWN_PROJECTS\SNOOZY` still exceeds Ninja's legacy Windows path limit for
one generated safe-area codegen directory.

## Windows path-limit workaround

The app uses only Expo Router's native stack, so it does not need
`react-native-gesture-handler` at runtime. Its native project was excluded with
`react-native.config.js`:

```js
module.exports = {
  dependencies: {
    'react-native-gesture-handler': {
      platforms: { android: null },
    },
  },
};
```

This removes the generated C++ path that was the longest build path. The JS
package stays installed for Expo Router's optional exports. The generated
autolinking CMake file was inspected and does not contain gesture-handler.

`plugins/withSnoozyWindowsBuild.js` also sets a short CMake staging directory:

```gradle
externalNativeBuild {
    cmake {
        buildStagingDirectory "C:/b"
    }
}
```

The short-root mirror is still required because even with staging, another
generated safe-area path lands a few characters over the legacy 260-character
limit when the project lives under `D:\OWN_PROJECTS\SNOOZY`.

## Verification performed

Commands run against the copied APK:

- `apksigner verify --verbose --print-certs`
  - v2 signature verified
  - release certificate SHA-1 matches the Snoozy release keystore
- `zipalign -c -v 4`
  - verification successful
- `aapt2 dump badging`
  - package/version/SDK/ABI values match the table above
- `aapt2 dump resources`
  - `raw/assets_smokeloop` points at `res/EL.wav`
- ZIP inspection
  - `assets/index.android.bundle` is present (3,537,600 bytes)
  - 28 `arm64-v8a` native libraries are present
  - `res/EL.wav` is present at 2,646,044 bytes
- merged manifest inspection
  - `POST_NOTIFICATIONS` is declared
  - `com.doublesymmetry.trackplayer.TrackPlayerPlaybackService` is declared
  - foreground service type is `mediaPlayback` (`0x2`)

Source checks:

- `npx tsc --noEmit` passed
- `npx expo lint` passed

These are static/build checks, not runtime results.

## Runtime acceptance gates

| Gate | Status | Evidence |
|---|---|---|
| APK install on Oppo A55 | NOT RUN | `adb devices -l` returned no devices |
| Five core smoke checks | NOT RUN | No device; 0/5 device-verified |
| Skia canvas | NOT RUN | Code and native library are present; no runtime result |
| Reanimated worklet | NOT RUN | Code and native library are present; no runtime result |
| MMKV round trip | NOT RUN | Code and native library are present; no runtime result |
| SQLite query | NOT RUN | Code and native library are present; no runtime result |
| Image color extraction | NOT RUN | Code and native library are present; no runtime result |
| RNTP local-loop playback | NOT RUN | Service, bundle, and WAV are packaged; no runtime result |
| Startup time (`am start -W`) | NOT MEASURED | No device |
| Memory (`dumpsys meminfo`) | NOT MEASURED | No device |
| 10-minute playback gate | NOT RUN | No device |

No startup or memory numbers are reported because none were measured.

## Install when a device is available

```powershell
D:\Android\Sdk\platform-tools\adb.exe install -r `
  D:\OWN_PROJECTS\SNOOZY\artifacts\snoozy-m0-arm64-release.apk
D:\Android\Sdk\platform-tools\adb.exe shell am start -W `
  -n com.snoozy.app/.MainActivity
```

Then verify the five checks on screen, press the playback control, and leave
the app foregrounded for ten minutes. Capture:

```powershell
adb shell dumpsys meminfo com.snoozy.app
adb logcat -d | Select-String 'ReactNativeJS|TrackPlayer|FATAL EXCEPTION'
```

## Keystore

- Path: `C:\Users\Administrator\.snoozy\snoozy-release.jks`
- Alias: `snoozy-release`
- Validity: 2026-10-21 through 2054-03-08
- Certificate SHA-1:
  `E7:6C:25:3D:80:A9:CB:E0:DE:C6:2F:F1:A1:EF:7F:4E:67:EB:EC:12`
- Credentials: `C:\Users\Administrator\.snoozy\keystore.properties`
  (outside the repository)
- No keystore, password, or credential file is tracked by git.

## Model routing

The requested `opencode/glm-5.3-flash` route was unavailable because the
provider returned “Insufficient account funds.” No GLM work was used.

The implementation, UI/playback integration, native build fixes, build, and
static verification recorded here were done with
`opencode/deepseek-v4.1-flash-free` (DeepSeek V4.1 Flash Free). Model
attribution is therefore a routing deviation from the original plan.

## Unverified items

- Installation and launch on the target Oppo A55 4G
- USB debugging authorization and Android/ColorOS compatibility
- All five on-device smoke checks and their UI state
- RNTP playback, notification permission flow, notification controls, and
  background/foreground playback behavior
- Local asset decoding of `res/EL.wav` by ExoPlayer
- Startup time and memory usage
- The 10-minute playback endurance gate
- Any device-specific crash, audio-focus, battery, or thermal behavior
