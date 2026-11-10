# Snoozy Native Phase 2: Data Layer and Library Scan

Date: 2026-11-11
Spec: `docs/superpowers/specs/2026-11-11-snoozy-native-glasmio-design.md`
Roadmap: `docs/superpowers/plans/2026-11-11-snoozy-native-glasmio-roadmap.md`

## Goal

Read every existing store in place with no migration, scan MediaStore into the same track identity shape as React Native, and prove on the A55 that the native snapshot, favorites, playlists, recents, overrides, and history match the preserved v2.3 data.

## Compatibility facts

- SQLite lives in `filesDir/SQLite/`, opened directly with `SQLiteDatabase.openDatabase`.
- MMKV lives in `filesDir/mmkv/`; initialize MMKV with that explicit root. Store IDs are `snoozy.music.v1`, `snoozy.playback.v1`, `snoozy.theme.v1`, `snoozy.preferences.v1`, `snoozy.search.v1`, `snoozy.lyrics.v1`, `snoozy.audio.v1`.
- MediaStore identity from expo-media-library legacy: `id` is `_ID` as a string, `uri` is `"file://" + DATA` with no percent-encoding, `filename` is `DISPLAY_NAME`, `modificationTime` is `DATE_MODIFIED * 1000` (ms), `creationTime` is `DATE_TAKEN` (ms), `duration` is `DURATION / 1000` seconds.
- Metadata mapping matches RN: title, artist, album, albumArtist = artist, year, genre; trackNumber and discNumber stay null; duration from tags when positive, otherwise MediaStore.
- Album key is `album-` plus base36 FNV-1a of `"<normalized artist>::<normalized title>"`, with the RN fallbacks for unknown album, folder name, and unknown artist.
- Artwork cache files stay at `filesDir/artwork/<albumKey>-<stableHash(uri:modified)>.jpg` and `.none` misses, so existing files are reused.
- JSON shapes keep the RN field names exactly. Kotlin serialization is configured with `encodeDefaults = true` so `artwork: null` and zeros round-trip like `JSON.stringify`.

## Tasks

1. Add MMKV `2.4.3`, kotlinx-serialization-json `1.12.0`, and the serialization plugin at Kotlin `2.4.21`.
2. Model: `Track`, `Album`, `Playlist`, `FavoriteRow`, `TrackOverride`, `AlbumOverride`, `ArtistOverride`, `PlaybackSession`, `ScannedMetadata`, matching RN fields.
3. `SnoozyStores`: initialize MMKV on the existing directory; typed read/write accessors for every key used by v2.3.
4. `SnoozyDatabases`: open the five SQLite files read-only-first and expose row reads for favorites, overrides, play history, and listening sessions.
5. `AlbumGrouping` and `LibraryStats`: exact ports of `albumGrouping.ts` and `libraryStats.ts`.
6. `LibraryScanner`: MediaStore query, concurrent metadata extraction, metadata cache, album artwork cache, snapshot write, fingerprint.
7. `LibraryRepository`: merges imported and scanned tracks by URI, exposes state, scans on launch when permitted, and imports SAF documents into `files/Music`.
8. `SnoozyApplication` and `AppContainer`: single manual container; debug diagnostics log to logcat tag `SnoozyData`.
9. Unit tests: stable hash, album key, album grouping, sorting, stats, session parse/resolve, JSON round-trip.

## Gate

- `gradlew.bat :app:assembleDebug :app:testDebugUnitTest :app:lintDebug` green.
- Install over the current build; logcat `SnoozyData` shows the preserved snapshot count, runtime scan count, favorites rows, override rows, play history rows, listening sessions, playlists, recents, and a readable session.
- No store is cleared. Existing SQLite and MMKV files remain.
