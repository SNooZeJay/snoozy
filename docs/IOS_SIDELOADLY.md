# Snoozy iOS Native Sideloadly Guide

This guide explains how to build the unsigned `Snoozy-iOS-Sideloadly.ipa` for free on GitHub Actions, install it onto your **iPhone 13 mini** (iOS 26 or later) from Windows using **Sideloadly** with your personal free Apple ID, and load your offline music library.

## 1. Architecture Overview

- **Source directory**: `ios-native/`
- **XcodeGen specification**: `ios-native/project.yml`
- **Target hardware**: iPhone 13 mini (`iPhone14,4`, Apple A15 Bionic, `375 x 812 pt` viewport, 60 fps)
- **Liquid Glass engine**: Native SwiftUI `glassEffect` and `GlassEffectContainer` on iOS 26 and later, with a system material fallback on iOS 17 through iOS 25. The album-artwork-tinted aura backdrop (`LiquidAuraBackgroundView`) is drawn in SwiftUI and does not require custom shaders.
- **Offline audio engine**: `AVAudioSession` (`.playback` category for background and screen-locked playback), `AVAudioPlayer` (`0.5x` to `2.0x` rate), `MPNowPlayingInfoCenter`, and `MPRemoteCommandCenter` for Lock Screen, Control Center, and AirPods / Bluetooth controls.
- **Free Apple ID compatibility**: All entitlements in `ios-native/Snoozy/Info.plist` (`UIBackgroundModes: ["audio"]`, `UIFileSharingEnabled: true`, `LSSupportsOpeningDocumentsInPlace: true`) work with a free personal Apple ID via Sideloadly. No paid Apple Developer membership is required.

---

## 2. Build the `.ipa` on GitHub Actions (Free macOS Runner)

Because compiling Swift into an iOS arm64 binary requires the Apple iOS SDK on macOS, this repository includes `.github/workflows/ios-sideloadly-ipa.yml` to compile and package `Snoozy-iOS-Sideloadly.ipa` automatically on GitHub's `macos-26` runner.

### Step-by-Step Build Instructions

1. Create a new repository on GitHub (public repositories receive unlimited free macOS Actions minutes; private repositories include free monthly minutes).
2. In PowerShell inside `D:\OWN_PROJECTS\SNOOZY`, link your GitHub repository and push:
   ```powershell
   git remote add origin https://github.com/<your-username>/<your-repo>.git
   git push -u origin release/v1.9
   ```
   Or run the helper script:
   ```powershell
   .\scripts\build-ios-ipa.ps1 -TriggerGitHub
   ```
3. Open your GitHub repository in the browser and click the **Actions** tab.
4. Select **Build Snoozy iOS Sideloadly IPA** in the left sidebar.
5. Wait roughly 2 to 3 minutes for the workflow run to finish (it runs XcodeGen, builds the `Release` `iphoneos` app with `CODE_SIGNING_ALLOWED=NO`, and packages `Payload/Snoozy.app` into `Snoozy-iOS-Sideloadly.ipa`). Unit tests run in the separate **iOS Unit Tests** workflow.
6. Scroll to the **Artifacts** section at the bottom of the workflow summary page and download **`Snoozy-iOS-Sideloadly-IPA`**, then unzip it to get **`Snoozy-iOS-Sideloadly.ipa`**.

---

## 3. Sideload onto Your iPhone 13 mini with Sideloadly on Windows

### Prerequisites on Windows
- Install **iTunes for Windows** (the direct Win64 installer from Apple, not the Microsoft Store version) and **iCloud for Windows** so Windows has the Apple Mobile Device USB and Wi-Fi drivers.
- Install **Sideloadly** on your Windows PC.

### Prerequisites on iPhone 13 mini (iOS 26 or later)
1. Connect your iPhone 13 mini to your Windows PC with a Lightning cable and tap **Trust This Computer** on the iPhone screen.
2. Enable **Developer Mode**:
   - Open **Settings > Privacy & Security > Developer Mode**.
   - Toggle **Developer Mode** on, restart the iPhone when prompted, and confirm after reboot.

### Sideloading Steps
1. Open **Sideloadly** on Windows.
2. Confirm your **iPhone 13 mini** appears in the **iDevice** field.
3. Enter your personal **Apple ID email** in the **Apple account** field.
4. Drag and drop **`Snoozy-iOS-Sideloadly.ipa`** onto the **IPA** slot on the left side of Sideloadly.
5. Click **Start** (enter your Apple ID password and 2FA code if this is your first time signing with Sideloadly).
6. Once Sideloadly reports **Done**, unlock your iPhone 13 mini and open:
   - **Settings > General > VPN & Device Management**
   - Tap your Apple ID under **Developer App** and tap **Trust**.
7. Launch **Snoozy** from your Home Screen.

> **Tip**: Enable **Wi-Fi Sideloading / Auto-Refresh** inside Sideloadly's daemon tray icon on Windows so Sideloadly refreshes the 7-day free personal signature automatically over your home Wi-Fi whenever your PC is on.

---

## 4. Adding Your Offline Music Library on iPhone 13 mini

Snoozy supports `.mp3`, `.flac`, `.wav`, `.m4a`, `.aac`, `.alac`, `.aiff`, `.aif`, `.caf`, and `.mp4` audio files, plus sidecar `.lrc` synced lyrics files and folder cover images (`cover.jpg`, `folder.jpg`, `front.png`, and so forth).

### Method A: iPhone Files App (`On My iPhone > Snoozy`)
1. Open the built-in **Files** app on your iPhone 13 mini.
2. Tap **Browse > On My iPhone > Snoozy**.
3. Copy or move your audio files or album folders into the **Snoozy** folder.
4. Switch back to **Snoozy**: the app automatically rescans `On My iPhone > Snoozy` when it becomes active (at most once a minute), or you can tap the **Rescan** button on the Home or Settings screen.

### Method B: In-App File or Folder Picker
1. On the **Home**, **Library**, or **Settings** screen in Snoozy, tap **Import Files** (`doc.badge.plus`) or **Import Folder** (`folder.badge.plus`).
2. Select individual audio tracks or an entire music folder from anywhere in the iPhone Files picker (such as Downloads, iCloud Drive, or an external USB drive).
3. Snoozy copies the tracks into its offline `Documents/` storage and indexes their embedded tags, artwork, and `.lrc` files immediately.

### Method C: Instant Built-In Synth Demo Track
- If your library is empty when you first open Snoozy, tap **Generate Demo Synth Track (.WAV + Synced .LRC)** on the Home card to synthesize an offline stereo ambient chord pad (`Snoozy Liquid Glass Demo.wav`) with synced `.lrc` lyrics so you can test the Liquid Glass player, Lock Screen controls, and lyrics syncing immediately.
