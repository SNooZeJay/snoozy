# Snoozy

## Platform

Android

## Product truth

Snoozy is a mobile music player named Snoozy. It is a Spotify-like local and online music player: browse a library, search tracks, manage playlists, play with a persistent queue, and control playback from a mini-player and notifications. The first build focuses on local device audio and a clean Material-style music UI; online resolution can be added through a backend or public API later.

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

## Capabilities in v1

- Home: greeting, recently played, playlists, quick access to library.
- Search: local track, album, and artist search.
- Library: songs, albums, artists, playlists, and favorites.
- Player: full-screen now-playing view, artwork, seek, skip, shuffle, repeat, favorite, queue.
- Mini-player: compact playback controls on every tab.
- Settings: library scan, permissions, preferences, about.
- Native background playback and notification controls (RNTP).
- Dynamic color from album artwork.

## Content

Local audio files from the device media library. Bundled demo tracks may be included for first-run testing. No bundled ambient loops are the product.

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
- Local and private by default where possible.
- Motion supports playback and navigation, not decoration.

## Accessibility

- 48 dp minimum touch targets; 44 dp for secondary icon buttons.
- Body text contrast at least 4.5:1.
- Dynamic type support with wrapping.
- Playback state announced to screen readers.
- Haptics optional.

## Success for this build

A signed arm64 APK installs on the Oppo A55 4G, scans local music, plays tracks in the background, supports playlists and queue controls, persists preferences, and passes TypeScript, lint, and a release build.
