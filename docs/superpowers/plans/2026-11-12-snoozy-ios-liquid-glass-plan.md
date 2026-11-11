# Snoozy iOS Native (iOS 27.2 Liquid Glass) Implementation Plan

> **For agentic workers:** REQUIRED: Use `subagent-driven-development` or `executing-plans` to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete native Swift, SwiftUI, and Metal offline music player (`ios-native/`) for iPhone 13 mini on iOS 27.2 with real Liquid Glass refraction, iPhone Files app (`On My iPhone > Snoozy`) + in-app file/folder import, background audio + Lock Screen controls, full Snoozy v3.0 feature parity, and an automated GitHub Actions `.ipa` build pipeline for Sideloadly on Windows.

**Architecture:** Single-module XcodeGen SwiftUI + Metal application (`ios-native/Snoozy`) with pure-Swift domain helpers (`PlaybackQueueOps`, `LyricsEngine`, `Models`), atomic JSON persistence (`SnoozyStore`), `AVURLAsset` file scanner (`AudioScanner`), `AVAudioPlayer`/`AVAudioSession`/`MPNowPlayingInfoCenter` playback engine (`PlaybackController`), stitchable Metal Liquid Glass shaders (`LiquidGlassShaders.metal`), and compact-first (`375 pt`) SwiftUI screens.

**Tech Stack:** Swift 6 / Swift 5.10, SwiftUI, Metal (`[[ stitchable ]]` shaders), AVFoundation, MediaPlayer, CoreImage, UniformTypeIdentifiers, XcodeGen, GitHub Actions (`macos-15` runner producing unsigned `Snoozy-iOS-Sideloadly.ipa`).

---

### Task 1: XcodeGen Project Spec, Info.plist, Bundled Fonts, and GitHub Actions Sideloadly IPA Pipeline

**Files:**
- Create: `ios-native/project.yml`
- Create: `ios-native/Snoozy/Info.plist`
- Create: `ios-native/Snoozy/Resources/Fonts/` (copy Bricolage Grotesque & Atkinson Hyperlegible TTFs)
- Create: `.github/workflows/ios-sideloadly-ipa.yml`
- Create: `scripts/build-ios-ipa.ps1`

- [x] **Step 1: Copy bundled fonts and create `ios-native/project.yml` and `ios-native/Snoozy/Info.plist`**
- [x] **Step 2: Create `.github/workflows/ios-sideloadly-ipa.yml` and `scripts/build-ios-ipa.ps1` for unsigned Sideloadly `.ipa` generation**

---

### Task 2: Domain Models, Pure Playback Queue & Lyrics Engines, and Persistent Store

**Files:**
- Create: `ios-native/Snoozy/Data/Models.swift`
- Create: `ios-native/Snoozy/Playback/PlaybackQueueOps.swift`
- Create: `ios-native/Snoozy/Data/LyricsEngine.swift`
- Create: `ios-native/Snoozy/Data/SnoozyStore.swift`
- Create: `ios-native/SnoozyTests/PlaybackQueueOpsTests.swift`
- Create: `ios-native/SnoozyTests/LyricsEngineTests.swift`

- [x] **Step 1: Create `Models.swift`, `PlaybackQueueOps.swift`, and `LyricsEngine.swift` with unit tests**
- [x] **Step 2: Create `SnoozyStore.swift` for playlists, favorites, recents, metadata overrides, play history, listening sessions, lyrics offsets, preferences, and `session.v1`**

---

### Task 3: Offline Audio Scanner (iPhone Files App + In-App Picker) & Artwork Palette Extractor

**Files:**
- Create: `ios-native/Snoozy/Data/AudioScanner.swift`
- Create: `ios-native/Snoozy/Data/ArtworkPaletteExtractor.swift`
- Create: `ios-native/Snoozy/Data/LibraryRepository.swift`

- [x] **Step 1: Implement `AudioScanner.swift` scanning `Documents/` (`On My iPhone > Snoozy`) and importing files/folders via security-scoped URLs**
- [x] **Step 2: Implement `ArtworkPaletteExtractor.swift` and `LibraryRepository.swift` combining raw tracks with metadata overrides, albums, artists, genres, favorites, and stats**

---

### Task 4: Native iOS Playback Engine (`AVAudioSession`, `AVAudioPlayer`, Lock Screen `MPNowPlayingInfoCenter`)

**Files:**
- Create: `ios-native/Snoozy/Playback/PlaybackController.swift`

- [x] **Step 1: Implement `PlaybackController.swift` with background audio session, interruption/route-change handling, gapless queue progression, repeat/shuffle/speed (`0.5x` to `2.0x`), cold-start `session.v1` restore, and Lock Screen / Control Center remote commands**

---

### Task 5: iOS 27 Liquid Glass Engine (Metal Shaders, Specular Squircle Surfaces, and Theme)

**Files:**
- Create: `ios-native/Snoozy/UI/Glass/LiquidGlassShaders.metal`
- Create: `ios-native/Snoozy/UI/Theme/SnoozyTheme.swift`
- Create: `ios-native/Snoozy/UI/Glass/LiquidGlassSurface.swift`
- Create: `ios-native/Snoozy/UI/Components/SnoozyArtworkView.swift`
- Create: `ios-native/Snoozy/UI/Components/SnoozyTrackRowView.swift`

- [x] **Step 1: Write `LiquidGlassShaders.metal` (`liquidGlassLens` refraction + chromatic dispersion + specular sheen, and `liquidAuraBackdrop` fluid mesh shader)**
- [x] **Step 2: Implement `SnoozyTheme.swift`, `LiquidGlassSurface.swift` (with Metal lens refraction + Frosted / Reduce Transparency modes), `SnoozyArtworkView.swift`, and `SnoozyTrackRowView.swift`**

---

### Task 6: Screens, Floating Liquid Glass Tab Bar, MiniPlayer, Full Player, and Sheets

**Files:**
- Create: `ios-native/Snoozy/UI/Components/SnoozyMiniPlayerView.swift`
- Create: `ios-native/Snoozy/UI/Components/SnoozySheets.swift`
- Create: `ios-native/Snoozy/UI/Screens/HomeScreen.swift`
- Create: `ios-native/Snoozy/UI/Screens/LibraryScreen.swift`
- Create: `ios-native/Snoozy/UI/Screens/DetailScreens.swift`
- Create: `ios-native/Snoozy/UI/Screens/PlaylistsScreen.swift`
- Create: `ios-native/Snoozy/UI/Screens/SearchScreen.swift`
- Create: `ios-native/Snoozy/UI/Screens/PlayerScreen.swift`
- Create: `ios-native/Snoozy/UI/Screens/SettingsScreen.swift`
- Create: `ios-native/Snoozy/UI/Screens/RootScaffoldView.swift`
- Create: `ios-native/Snoozy/SnoozyApp.swift`

- [x] **Step 1: Implement `SnoozyMiniPlayerView.swift` and `SnoozySheets.swift` (Track actions, Add to playlist, Add songs, Queue reorder/remove/clear, Synced Lyrics with offset, Speed picker, Metadata override editor, File & Folder importers)**
- [x] **Step 2: Implement `HomeScreen`, `LibraryScreen`, `DetailScreens` (`Album`, `Artist`, `Genre`), `PlaylistsScreen`, `SearchScreen`, `PlayerScreen`, `SettingsScreen`, `RootScaffoldView`, and `SnoozyApp`**
- [x] **Step 3: Document Sideloadly installation & usage in `docs/IOS_SIDELOADLY.md` and commit**
