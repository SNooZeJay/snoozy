# Snoozy M0 release report

Date: 2026-10-21

## Bottom line

The signed Android release APK is built and statically validated. It is ready
to sideload onto the Oppo A55, but the device acceptance gate has **not** been
run because ADB sees no connected device.

**Status: build complete; runtime verification blocked.**

## Deliverable

`artifacts/snoozy-m0-arm64-release.apk`

| Field | Value |
|---|---|
| Package | `com.snoozy.app` |
| Version | `1.0.0` (versionCode `1`) |
| Size | `54,506,031` bytes |
| SHA-256 | `AAE28330F27AC985AE24FF79DA17D1459BB815A95BF0ECCF62CB76A6C3E0434C` |
| ABI | `arm64-v8a` |
| minSdk | `24` |
| targetSdk | `36` |
| Signature | APK Signature Scheme v2 |
| Signer SHA-1 | `E7:6C:25:3D:80:A9:CB:E0:DE:C6:2F:F1:A1:EF:7F:4E:67:EB:EC:12` |

Install command:

```powershell
D:\Android\Sdk\platform-tools\adb.exe install -r `
  D:\OWN_PROJECTS\SNOOZY\artifacts\snoozy-m0-arm64-release.apk
```

## Versions

- Expo `58.0.16`
- React Native `0.88.0`
- React `19.3.0`
- TypeScript `6.0.3`
- New Architecture enabled
- Expo Router `58.0.24`
- Skia `2.14.0`
- Reanimated `4.7.1`
- Worklets `0.13.0`
- MMKV `4.3.2`
- expo-sqlite `58.0.13`
- image-colors `2.6.1`
- RNTP `5.12.1`
- AGP `9.2.1`
- Gradle `9.4.1`
- JDK `17.0.20.101`
- Android build-tools `37.0.0`
- NDK `27.1.12297006`
- CMake `3.22.1`

## Acceptance matrix

| Requirement | Result | Evidence |
|---|---|---|
| Signed release APK | PASS | v2 signature verified; zipalign successful |
| Package/version/ABI | PASS | `aapt2` badging: `com.snoozy.app`, 1.0.0, arm64-v8a |
| JS bundle in APK | PASS | `assets/index.android.bundle`, 3,537,600 bytes |
| Five native modules linked | PASS (static) | 28 arm64 libraries including Skia, Reanimated, Worklets, MMKV, SQLite, image-colors |
| RNTP service/manifest | PASS (static) | service declared; foreground type `mediaPlayback` |
| Local playback asset | PASS (static) | `raw/assets_smokeloop` -> `res/EL.wav`, 2,646,044 bytes |
| TypeScript | PASS | `npx tsc --noEmit` |
| Lint | PASS | `npx expo lint` |
| Install on device | NOT RUN | no ADB device |
| Five device smoke checks | NOT RUN | 0/5 device-verified |
| RNTP playback on device | NOT RUN | no runtime result |
| Startup time | NOT MEASURED | no device |
| Memory | NOT MEASURED | no device |
| 10-minute playback gate | NOT RUN | no device |

Static checks prove the code and native artifacts are packaged. They do not
prove runtime behavior.

## What the app contains

`src/app/index.tsx` is a dark M0 diagnostics screen with:

- A Skia GPU canvas check
- A Reanimated UI-thread timing check
- An MMKV read/write check
- An expo-sqlite query check
- A react-native-image-colors extraction check
- RNTP playback controls using a bundled 30-second WAV loop
- A visible ten-minute playback gate

The five checks are implemented; their runtime results remain unknown until
the APK is launched on a device.

## Startup, memory, and ten-minute playback

No numbers are reported.

- `am start -W` was not run.
- `dumpsys meminfo com.snoozy.app` was not run.
- The ten-minute endurance gate was not run.

`adb devices -l` returned an empty device list. No USB Android/Oppo device was
detected either. There is no connected device to install to or measure.

## Unverified items

- Installation and first launch on the Oppo A55 4G
- ColorOS/Android compatibility and USB debugging authorization
- All five smoke checks on device
- RNTP playback, audio decoding, notification permission, media notification,
  and foreground/background behavior
- Startup time
- Memory usage
- Ten-minute playback endurance
- Battery, thermal, and audio-focus behavior

Do not treat M0 as device-accepted until these are run.

## Model routing

The requested `opencode/glm-5.3-flash` route was unavailable; the provider
returned “Insufficient account funds.” No GLM work was used.

Final UI/playback integration, native build fixes, release build, and static
verification were done with `opencode/deepseek-v4.1-flash-free` (DeepSeek V4.1
Flash Free). This is a recorded routing deviation from the original plan.

## Reproducing the build

See `docs/M0-build.md` for the full build record. The release build must be run
from a short path on Windows (the successful build used `C:\s`) with JDK 17,
Android SDK `D:\Android\Sdk`, and the `SNOOZY_*` signing environment variables.
The generated `android/` directory is not the source of truth; it is created by
`npx expo prebuild --platform android`.
