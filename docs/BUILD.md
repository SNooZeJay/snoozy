# Snoozy build record

## v2.2 (2.2.0, versionCode 12) — released and audited

- Intent: complete the v2.1 visual reset with a live semantic theme, shared
  layout primitives, immediate tab switches, one persistent mini-player above
  the tab bar, five equal Library segments, and compact grouped rows.
- App version `2.2.0`; Android `versionCode` `12`; package `com.snoozy.app`.
  `userInterfaceStyle` is `automatic` so Light, Dark, and Auto can all work.
- Design and execution references:
  `docs/superpowers/specs/2026-10-23-snoozy-visual-system-v2.2-design.md` and
  `docs/superpowers/plans/2026-10-23-snoozy-visual-system-v2.2.md`.
- Runtime audit: `docs/AUDIT-v2.2.md`.
- Build environment: sync the JS tree to `C:\s`, prebuild Android with
  `npx expo prebuild --platform android --no-install`, use JDK 17
  (`C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot`), and build
  `arm64-v8a` only with the existing release keystore.
- Static gates: `npx tsc --noEmit`, `npx eslint src --no-cache`, and
  `npx expo-doctor`. At the package bump, typecheck and lint passed;
  expo-doctor passed 19/20 checks with only the known patch-level mismatches
  for `expo`, `expo-asset`, `expo-constants`, `expo-linking`, `expo-router`,
  `expo-splash-screen`, and `expo-status-bar`. Unrelated findings block the
  build.
- Release command:
  `gradlew.bat -p C:\s\android assembleRelease -PreactNativeArchitectures=arm64-v8a`
  after removing stale `*.bundle` files. Export the four
  `SNOOZY_KEYSTORE_*` environment variables from the private
  `C:\Users\Administrator\.snoozy\keystore.properties` before invoking
  Gradle; otherwise the generated APK is debug-signed. Stop any existing
  Gradle daemon or build with `--no-daemon` so the signing environment is
  inherited.
- Build result (2026-10-23, final post-verification fixes): JS bundle pass
  `Android Bundled 34389ms` (1741 modules); signed release pass
  `BUILD SUCCESSFUL in 2m 1s`, 1017 actionable tasks (32 executed, 985
  up-to-date). The extra module is `AppDialog`. Final build log:
  `C:\Users\Administrator\AppData\Local\Temp\opencode\build-v2.2-dialogfix.log`.
- Artifact: `artifacts/snoozy-arm64-release-v2.2.apk`
  - Size: `51,870,098` bytes
  - SHA-256: `AED3C60B539EA609C94DF28CC6B6DD6226EC706F162FF9DB2C06E21C916D10AE`
  - Manifest: `com.snoozy.app`, version `2.2.0`, versionCode `12`, SDK 24–36,
    native code `arm64-v8a` only.
  - Signature: APK Signature Scheme v2 verified; certificate
    `CN=Snoozy Release, OU=M0, O=Snoozy, L=Local, ST=Local, C=US`; RSA 2048.
  - `zipalign -c 4`: `Verification successful`.
  - JS bundle: `3,545,384` chars; contains the post-fix markers
    `Close dialog` and `no-hide-descendants` as well as the v2.2 markers
    (`Backdrop glow`, `Palette style`, `Accent swatch`, `Theme, motion, and
    library`, `2.2.0`).
- Superseded pre-fix artifact (numbers retained for traceability):
  `51,866,290` bytes; SHA-256
  `13F6DA0FE328A56EB643D896989A58F75CC4602E26AA75047FCE44FF8539ACCD`;
  1740 modules. The final artifact above is promoted over it.
- Install: `adb install -r` of the signed final APK reported `Success` over
  the existing release install at `2.2.0` / `12`.
- Device: Oppo CPH2325, Android 13, 720×1600 at density 320. USB ADB
  re-enumerated when the screen slept, so wireless ADB at
  `192.168.1.9:5555` is the primary test transport.
- Runtime theme matrix, tab-continuity, Library-bounds, playback, dialogs,
  swipe rails, and frame evidence are recorded in `docs/AUDIT-v2.2.md`.
- The provisional v2.1 APK is superseded by this release.

## v1.8 (final, canonical)

- APK: `artifacts/snoozy-arm64-release.apk` (canonical; v1.7 preserved as `snoozy-arm64-release-v1.7.apk`).
- Size: `51,803,434` bytes
- SHA-256: `384394C336074CFEB9CE71603E4B2E240E602369BB49987B34CBD16DAB94E7CF`
- Package: `com.snoozy.app`; version `1.8.0` (versionCode `8`); ABI `arm64-v8a` only.
- Signature: APK Signature Scheme v2 verified (`CN=Snoozy Release`); `zipalign -c 4` successful.
- Command: sync repo -> `C:\s`, delete stale `*.bundle` under `C:\s\android\app\build`, then
  `gradlew.bat -p C:\s\android assembleRelease -PreactNativeArchitectures=arm64-v8a`.
- Result: BUILD SUCCESSFUL in 1m 25s (32 executed tasks); JS bundle `3,484,584` bytes with the v1.8 strings verified.
- TypeScript 0 errors; lint 0 errors (4 pre-existing `PlayerContext` warnings).
- Installed on device with `adb install -r` over wireless ADB (Success); versionName 1.8.0 / build 8 confirmed.
- Runtime audit passed: screenshots `78-107`, v1.7 rows 13/25/26/28/29, regression reruns, fps traces. See `docs/AUDIT-v1.8.md`.
- **Build-tree layout:** the JS project root is `C:\s` (package.json, app.json, src, assets). The native project is `C:\s\android`. Sync sources to `C:\s\src` and `C:\s\app.json` - NOT into `C:\s\android\src`.
- **Stale-bundle pitfall:** Gradle can keep/restore an old `index.android.bundle`. Always delete `*.bundle` under `C:\s\android\app\build` before building and confirm a new marker string inside the APK bundle before packaging.
- **Device note:** USB ADB on this handset repeatedly re-enumerated/offline; the audit used wireless ADB at `192.168.1.9:5555` (`adb connect`, reconnect after drops).

## v1.7

## Final artifact (rebuilt after the audit's defect fixes — canonical)

- APK: `artifacts/snoozy-arm64-release.apk`
- Size: `51,792,122` bytes
- SHA-256: `0F65200829F63FAC746078542CF530FA5528A10F6AF8471DC1423652BD0DF533`
- Package: `com.snoozy.app`
- Version: `1.7.0` (versionCode `7`)
- ABI: `arm64-v8a` only
- minSdk / targetSdk / compileSdk: `24` / `36` / `37`
- Signature: APK Signature Scheme v2 verified (CN=Snoozy Release)
- zipalign: successful
- Installed on device with `adb install -r` (Success); versionName 1.7.0 / build 7 confirmed on device.

## Rebuild (defect-fix batch)

- Command: incremental `gradlew.bat assembleRelease -PreactNativeArchitectures=arm64-v8a` (sync `src/` + `assets/` from the repo into the build tree first).
- Result: BUILD SUCCESSFUL in 2m 27s (32 executed tasks).
- TypeScript: `npx tsc --noEmit` passed (0 errors) after the fixes.
- Lint: `npx expo lint` passed (0 errors, 9 pre-existing warnings).
- This APK is the audit's `PASS (rebuilt)` artifact — see `docs/AUDIT-v1.7.md` evidence 60–76.

## Original audit-walk build (superseded)

- Size: `51,791,742` bytes
- SHA-256: `EAE2CF231E155105C4644D11A3A172D29EC0B7A4F219587D16745B829AE3156A`
- Command: `npx expo prebuild --platform android --clean --no-install` then `gradlew assembleRelease -PreactNativeArchitectures=arm64-v8a`
- Result: BUILD SUCCESSFUL in 17m 51s (1017 actionable tasks).

## Verification

- Static verification: tsc + lint + signed release build pass.
- Device verification on Oppo A55 4G (Android 13): install, launch, and the full runtime audit are recorded in `docs/AUDIT-v1.7.md`.
