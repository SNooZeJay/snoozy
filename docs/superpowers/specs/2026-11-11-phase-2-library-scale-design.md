# Phase 2 Spec: Library Scale and Artwork Cache Cap

Date: 2026-11-11
Scope: Snoozy v3.0 Phase 2

## 1. Objective

Ensure large local music libraries (5,000+ tracks) scroll smoothly at 60 fps on detail screens and prevent unbounded disk growth in the extracted artwork cache.

## 2. Virtualized Detail Lists

Replace non-virtualized `Animated.ScrollView` + `.map(...)` track lists with `Animated.FlatList` on:

- `src/app/album.tsx`
- `src/app/artist.tsx`
- `src/app/genre.tsx`
- `src/app/playlist.tsx`

### Layout and Chrome Preservation

- Hero cover art, titles, subtitles, Play/Shuffle action pills, and secondary sections (for example, artist albums) render inside `ListHeaderComponent`.
- Empty states render inside `ListEmptyComponent`.
- `onScroll` from `useCollapsingScroll(false)` attaches directly to `Animated.FlatList` (`scrollEventThrottle={16}`) so `CollapsedBar` continues to crossfade at `scrollY > 44 dp`.
- Track rows sit inside a grouped card surface (`GlasmioGroupedList` geometry: continuous rounded top on the first item, rounded bottom on the last item, and hairline separators between rows) with `initialNumToRender={12}`, `maxToRenderPerBatch={12}`, and `windowSize={7}`.

## 3. Artwork Cache Cap and Orphan Pruning

In `src/storage/audioMetadata.ts`:

- Define `MAX_ARTWORK_CACHE_ENTRIES = 400` (covers 400 unique albums while bounding disk usage).
- Add pure helper `selectArtworkFilesToPrune(files: ArtworkCacheFileEntry[], activeKeys: ReadonlySet<string>, maxEntries?: number): string[]`:
  1. Any file in `artwork/` whose stem (`<cacheKey>` before `.jpg` or `.none`) is not in `activeKeys` is marked for deletion (orphan pruning).
  2. If the remaining active `.jpg` files exceed `maxEntries`, sort by `modificationTime` ascending (oldest first, deterministic tie-breaker by filename) and prune the oldest excess files so at most `maxEntries` `.jpg` files remain.
- Add `pruneArtworkCache(activeKeys: ReadonlySet<string>): Promise<void>` and invoke it at the end of `MusicLibraryContext` scans alongside `pruneMetadataCache`.
