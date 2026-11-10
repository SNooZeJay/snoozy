# Phase 2 Plan: Library Scale and Artwork Cache Cap

Date: 2026-11-11
Spec: `docs/superpowers/specs/2026-11-11-phase-2-library-scale-design.md`

## Tasks

1. **Red (Failing Unit Tests for Artwork Cache Pruning)**:
   - Create `tests/artworkCache.test.ts` testing `selectArtworkFilesToPrune`:
     - Deletes orphaned `.jpg` and `.none` files not in `activeKeys`.
     - Preserves active files when count is within `maxEntries`.
     - Evicts oldest `.jpg` files when active `.jpg` count exceeds `maxEntries`.
   - Run `npx jest tests/artworkCache.test.ts` and confirm failure before implementation.

2. **Green (Implement Artwork Cache Pruning)**:
   - Implement `selectArtworkFilesToPrune` and `pruneArtworkCache` in `src/storage/audioMetadata.ts` and wire `pruneArtworkCache` into `src/storage/MusicLibraryContext.tsx`.
   - Re-run `npx jest tests/artworkCache.test.ts` and confirm pass.

3. **Virtualize Detail Screens**:
   - Convert `src/app/album.tsx`, `src/app/artist.tsx`, `src/app/genre.tsx`, and `src/app/playlist.tsx` from `Animated.ScrollView` to `Animated.FlatList` while preserving `CollapsedBar`, hero headers, action buttons, and grouped row styling.

4. **Static Gates & Device Verification**:
   - Run `npx tsc --noEmit`, `npx expo lint`, and `npx jest --silent`.
   - Sync to `C:\s`, build signed release APK, install on `9PGE8SQKAM598PBY` via `adb install -r`, and verify Album, Artist, Genre, and Playlist scrolling and compact header transitions on the phone.
