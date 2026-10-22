# Snoozy v1.3 pre-work report

## 1. Current expo-sqlite schema

- Favorites: `snoozy_favorites.db`, table `favorites` (identity TEXT PK, title, artist, album, duration, artwork, added_at). Created in v1.2 (`src/storage/FavoritesContext.tsx`).
- Metadata overrides: `snoozy_metadata.db` (new in v1.3) with tables `track_overrides`, `album_overrides`, `artist_overrides` (see `src/storage/metadata.ts`).
- Playlists: stored in MMKV (`snoozy.music.v1`, key `playlists`) as JSON, NOT sqlite. v1.3 extends the MMKV `Playlist` type with `description`, `artworkPath`, `updatedAt` (migration is schema-on-read; existing rows default to null).

## 2. Track identity

- Scanned tracks: `MediaLibrary.Asset.id` (stable MediaStore id).
- Imported tracks: `imported-<timestamp>-<rand>`.
- Favorites key by file URI/path.
- Overrides key by `track.id` (same identity as scan/favorites/playlists). Favorites and playlist membership reference `track.id`, never the displayed title, so editing a title does not break membership.
- Album key: `${album}::${albumArtist}` (album + album artist). Artist key: artist name.

## 3. Image picker

- None was installed. Added `expo-image-picker@58.0.10` (Expo SDK 58 compatible, resolved by `npx expo install`).
- Permissions: on Android 13+ uses the system photo picker; no `READ_MEDIA_*` or storage permission required. Verified against package docs (Expo SDK 58).
- No image downscaling library present (`expo-image-manipulator` not installed). Downscaling to 1024 px is NOT implemented; picked images are copied as-is. Reported per spec section 4.
- No other native module added.

## 4. Screen file paths touched (v1.3)

- `src/app/player.tsx` — added Edit button + SongEditSheet.
- `src/components/SongEditSheet.tsx` (new) — song metadata edit + artwork picker.
- `src/storage/metadata.ts` (new) — override tables + CRUD.
- `src/storage/display.ts` (new) — `resolveTrackDisplay` / album / artist.
- `src/types/music.ts` — Playlist type extended (description, artworkPath, updatedAt).
- `src/storage/MusicLibraryContext.tsx` — playlist persistence reads/writes new fields (schema-on-read).
