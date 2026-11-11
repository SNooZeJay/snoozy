# Snoozy iOS Native (iOS 27.2 Liquid Glass) Design

Date: 2026-11-12
Status: approved direction, implementation active
Target: `com.snoozy.app` 3.0.0 (build 14) on iPhone 13 mini (`iPhone14,4`, Apple A15 Bionic, iOS 27.2), sideloaded via Sideloadly on Windows

## 1. Decision

Snoozy for iPhone 13 mini ships as a 100% native Swift, SwiftUI, and Metal application in `ios-native/`. Existing work in `android-native/` and the root React Native project remains intact in the repository.

Because the app is sideloaded from a Windows PC using Sideloadly with a free personal Apple ID:

- All capabilities use standard free-provisioning entitlements (`UIBackgroundModes: ["audio"]`, `UIFileSharingEnabled: true`, `LSSupportsOpeningDocumentsInPlace: true`). No paid Apple Developer entitlements (such as Push Notifications, CloudKit, or App Groups) are used.
- The Xcode project is defined declaratively in `ios-native/project.yml` (XcodeGen) and compiled into an unsigned `Snoozy-iOS-Sideloadly.ipa` on a free GitHub Actions macOS runner (`.github/workflows/ios-sideloadly-ipa.yml`). Sideloadly signs the `.ipa` on Windows with the user's Apple ID and installs it onto the iPhone 13 mini.

## 2. Target Hardware and Display Geometry (iPhone 13 mini)

| Property | Value |
| --- | --- |
| Device | iPhone 13 mini (`iPhone14,4`) |
| SoC | Apple A15 Bionic (6-core CPU, 4/5-core GPU) |
| OS | iOS 27.2 (deployment target iOS 17.0 with `#available(iOS 26.0, *)` native glass hooks) |
| Logical viewport | `375 x 812 pt` (@3x scale factor, `1125 x 2436 px`) |
| Safe Area Insets (Portrait) | Top `50 pt` (notch), Bottom `34 pt` (home indicator) |
| Screen horizontal padding | `16 pt` |
| Minimum tap target | `44 x 44 pt` |
| Control height | `48 pt` |
| Floating tab bar height | `62 pt` |
| Floating mini-player height | `64 pt` |

All layouts are compact-width first (`375 pt` width), preventing horizontal text clipping on segmented controls, action rows, and player transport buttons.

## 3. Real iOS 27 Liquid Glass Architecture

On the A15 Bionic GPU, **Full Liquid Glass** is the default mode at 60 fps:

1. **Native iOS 26 / 27 Glass Integration (`#available(iOS 26.0, *)`)**:
   - Uses SwiftUI's native `.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: radius, style: .continuous))` and `GlassEffectContainer` when running on iOS 26.0 and newer (including iOS 27.2) when built with the iOS 26+ SDK.
2. **Real-Time Metal Refraction & Chromatic Dispersion Shader (`LiquidGlassShaders.metal`)**:
   - Uses SwiftUI stitchable Metal shaders (`[[ stitchable ]]`) compiled into the app binary:
     - `liquidGlassLens`: Computes signed-distance-field squircle edge curvature to refract underlying backdrop pixels, applies subtle RGB chromatic dispersion along the rim, and overlays a directional specular sheen that responds to interactive press state and time.
     - `liquidAuraBackdrop`: Renders a smooth, organic multi-stop fluid mesh gradient driven by the active track's extracted artwork palette (`ArtworkPalette`) and user-configurable backdrop intensity.
3. **Multi-Layer Specular Rim & Continuous Squircle Geometry**:
   - Every card, grouped row container, floating tab bar, mini-player, sheet, and button uses continuous superellipse corners (`.continuous`) with dual-stop angular specular borders (`white 42%` top-left to `white 8%` bottom-right, tinted by the active emerald/artwork accent).
4. **User-Tunable Glass & Motion Controls**:
   - Settings exposes `Glass Mode` (`Full Liquid Glass`, `Frosted Material`, `Reduce Transparency`), `Refraction Intensity` (`0%` to `100%`), `Artwork Aura Backdrop` toggle and intensity, `Palette Style` (`Emerald`, `Dynamic Artwork`, `Cyan`, `Violet`, `Rose`, `Amber`), and `Motion Mode` (`Full`, `Reduced`).

## 4. Offline Audio Import and iPhone Files App Integration

Music loading uses two first-class paths with zero iTunes sync required:

1. **iPhone Files App (`On My iPhone > Snoozy`)**:
   - `Info.plist` sets `UIFileSharingEnabled = true` and `LSSupportsOpeningDocumentsInPlace = true`.
   - iOS automatically exposes the app's `Documents` directory in the built-in **Files** app under **On My iPhone > Snoozy**.
   - Users can drop audio files (`.mp3`, `.flac`, `.wav`, `.m4a`, `.aac`, `.alac`, `.ogg`, `.aiff`, `.caf`) and sidecar lyrics (`.lrc`) directly into **On My iPhone > Snoozy** (including nested album/artist subfolders).
   - `AudioScanner` scans `Documents/` recursively on app launch, when returning to foreground, and on manual tap of **Scan**.
2. **In-App File & Folder Picker**:
   - Tapping **Import Files** or **Import Folder** opens `UIDocumentPickerViewController` (`.fileImporter`) for selecting individual audio files or entire music folders from anywhere in the iPhone Files app (iCloud Drive, Downloads, external USB drive, or local storage) and copies them into `Documents/Music/` inside the Snoozy sandbox.

## 5. Module Layout

```
ios-native/
  project.yml
  Snoozy/
    SnoozyApp.swift
    Info.plist
    Resources/
      Fonts/
        BricolageGrotesque-Medium.ttf
        BricolageGrotesque-SemiBold.ttf
        AtkinsonHyperlegible-Regular.ttf
        AtkinsonHyperlegible-Bold.ttf
    Data/
      Models.swift
      SnoozyStore.swift
      AudioScanner.swift
      LyricsEngine.swift
      ArtworkPaletteExtractor.swift
    Playback/
      PlaybackQueueOps.swift
      PlaybackController.swift
    UI/
      Theme/
        SnoozyTheme.swift
      Glass/
        LiquidGlassShaders.metal
        LiquidGlassSurface.swift
      Components/
        SnoozyArtworkView.swift
        SnoozyTrackRowView.swift
        SnoozyMiniPlayerView.swift
        SnoozySheets.swift
      Screens/
        RootScaffoldView.swift
        HomeScreen.swift
        LibraryScreen.swift
        DetailScreens.swift
        PlaylistsScreen.swift
        SearchScreen.swift
        PlayerScreen.swift
        SettingsScreen.swift
  SnoozyTests/
    PlaybackQueueOpsTests.swift
    LyricsEngineTests.swift
```

## 6. Feature Parity Matrix

| Area | Behavior on iPhone 13 mini |
| --- | --- |
| Home | Greeting, library status, `Import Files`, `Import Folder`, `Rescan`, `Recently played` with `Clear`, `Recently added` albums, `Most played` songs, `Shuffle all songs` |
| Library | 5 segments (`Songs`, `Albums`, `Artists`, `Genres`, `Favorites`), sort sheet, 2-column Album grid/list toggle, active track tint, track menu |
| Album / Artist / Genre | Large squircle artwork, `Play` and `Shuffle` buttons, track list, metadata override editor |
| Playlists | Create, rename, delete, 2x2 collage cover, `Play`, `Shuffle`, `Add songs` filter sheet, move up/down reorder, remove |
| Search | Floating Liquid Glass search bar, instant filter across songs, albums, artists, and genres, persisted recent queries |
| Player | Full-screen Liquid Glass player, artwork aura, clickable artist/album links, favorite button, scrubbing seek bar, transport controls, repeat (`off`/`all`/`one`), shuffle, speed (`0.5x`–`2.0x`), queue sheet, synced lyrics sheet, metadata editor |
| Lyrics | Sidecar `.lrc` in `On My iPhone > Snoozy` and embedded ID3/M4A lyrics, active line sync, tap line to seek, per-track offset (`-5.0s` to `+5.0s`) |
| Background Audio | `AVAudioSession` `.playback`, Lock Screen & Control Center `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter` (play, pause, next, previous, scrubbing), Bluetooth/AirPods route handling |
| Persistence | Cold-start restoration of `session.v1` (active track, queue, position, repeat, shuffle, speed) and atomic JSON store persistence |
| Sideloadly Delivery | Unsigned `Snoozy-iOS-Sideloadly.ipa` built via `.github/workflows/ios-sideloadly-ipa.yml` |
