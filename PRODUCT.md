# Snoozy

## Platform

iOS (native SwiftUI, deployment target iOS 17)

## Product truth

Snoozy is a local-first music player for iPhone. It scans audio files stored in the app's Documents folder, reads embedded metadata and artwork, and plays them with a persistent queue, playlists, favorites, synced lyrics, a mini-player, and a full-screen player. Playback continues in the background with Lock Screen and Control Center controls. The app has no streaming backend and does not send library data off the device.

## Users and context

- One person choosing music on a phone, often with headphones or a car speaker.
- Fast access to recently played tracks, playlists, and search.
- Playback must survive the screen going dark or the app leaving the foreground.
- Controls must be reachable with one thumb and readable at a glance.

## Jobs

1. Find a track quickly by search, recents, or playlists.
2. Play, pause, skip, seek, shuffle, and repeat.
3. Manage playlists and favorites.
4. Control playback from a compact mini-player anywhere in the app.
5. See album artwork and basic track metadata.
6. Keep playback reliable in the background.
7. Import files from the Files app or a folder picker without losing the existing library.

## Capabilities in v1

- Home: greeting, recently played, playlists, quick access to library.
- Search: local track, album, artist, genre, and folder search.
- Library: songs, albums, artists, genres, folders, playlists, and favorites.
- Player: full-screen now-playing view, artwork, seek, skip, shuffle, repeat, favorite, queue, and synced lyrics.
- Mini-player: compact playback controls on every tab.
- Settings: rescan, import, appearance, playback, storage, and error log.
- Native background playback and Lock Screen controls through `AVAudioSession` and `MPNowPlayingInfoCenter`.
- Dynamic color from album artwork.
- Native Liquid Glass through SwiftUI `glassEffect` on iOS 26 and later, with a system material fallback on iOS 17 through iOS 25.

## Content

Local audio files in the app Documents folder: `.mp3`, `.flac`, `.wav`, `.m4a`, `.aac`, `.alac`, `.aiff`, `.aif`, `.caf`, and `.mp4`. Sidecar `.lrc` lyrics and folder cover images are supported. A synthesized demo track is offered only when the library is empty.

## Brand commitments

- Name: Snoozy.
- Logo: a bold letter S.
- Mood: clean, energetic music player, not sleep tech.
- Palette: dark graphite ground, bright accent, high-contrast type.
- Voice: short, direct, and useful.

## Principles

- One-thumb first: primary actions sit low and stay large.
- Fast search and playback start.
- Legible in motion: high contrast, clear hierarchy, no tiny metadata.
- Local and private by default.
- Motion supports playback and navigation, not decoration.
- Never trade existing library data for a visual change.

## Accessibility

- 44 pt minimum touch targets.
- Body text contrast at least 4.5:1.
- Dynamic Type support with wrapping and scalable custom fonts.
- Playback state announced to screen readers.
- Reduce Motion respected.
- Haptics optional.

## Success for this build

An unsigned arm64 IPA builds on GitHub Actions, installs through Sideloadly, scans local music, plays tracks in the background, supports playlists and queue controls, persists preferences, and passes the XCTest suite in CI.
