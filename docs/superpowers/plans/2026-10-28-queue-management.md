# Queue Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A listener can see, reorder, remove, clear, jump inside, extend, and save the live playback queue.

**Architecture:** The native queue stays the single source of order. `PlayerContext` mirrors it as `queueItems` + `queueIndex`, refreshes after each mutation and on `MediaItemTransition`, and exposes seven actions. Every list operation is a pure helper in `src/playback/queue.ts`; the context only calls the engine. A `QueueSheet` renders the mirror with the house sheet primitives.

**Tech Stack:** Expo SDK 58, React Native 0.88, React 19, `@rntp/player` 5.12.1, Reanimated, TypeScript, Jest (jest-expo).

**Spec:** `docs/superpowers/specs/2026-10-28-queue-management-design.md`

## Global Constraints

- No new dependencies.
- The engine queue is authoritative; never keep a second order that can drift.
- Reuse house primitives: `SheetPanel`, `AppDialog`, `ListRow`, `IconButton`, `EmptyState`, `CoverArt`, `Thumb`, `useThemedStyles`.
- Every dialog stays within the device-verified five-action bound.
- 48 dp minimum targets; every control has an explicit accessibility label.
- Motion uses existing vocabulary only and respects `reducedMotion`.
- Styled gates: `npx tsc --noEmit`, `npx expo lint`, `npx jest`.
- Work stays on `release/v1.9`; changes remain uncommitted until the user asks (host instruction).

## Review Focus

1. **Removing the currently playing item** — playback should continue with the
   next item and the mirror must not point at a stale index. (Device check;
   the engine owns the transition, the mirror only re-reads it.)
2. **Mutations with an empty queue** — play next / add to queue with nothing
   playing must start that track, not throw. (Pinned by `playNext` on an empty
   list and the context's empty-queue branch.)
3. **A queued track deleted from the library** — the sheet still renders it
   from engine metadata, and Save skips ids the library no longer has. (Pinned
   by `filterQueueIds`.)
4. **Rapid control taps** — move/remove/clear pressed twice quickly leave the
   UI matching the engine. (Device check; each action re-reads the engine.)
5. **Long queues** — a 500-item queue scrolls without mounting every row.
   (FlatList; device check.)

---

### Task 1: Queue model helpers

**Files:**
- Create: `src/playback/queue.ts`
- Test: `tests/queue.test.ts`

**Interfaces:**
- Consumes: `Track` from `src/types/music.ts`; `MediaItem` type from `@rntp/player`.
- Produces:
  - `type QueueEntry = { mediaId: string; title: string; artist: string; artwork: string | null }`
  - `mediaItemFor(track: Track): MediaItem`
  - `entryFromMediaItem(item: MediaItem): QueueEntry`
  - `moveItem<T>(items: T[], from: number, to: number): T[]`
  - `removeItemAt<T>(items: T[], index: number): T[]`
  - `appendUnique(ids: string[], id: string): string[]`
  - `playNext(ids: string[], activeIndex: number, id: string): { ids: string[]; index: number }`
  - `filterQueueIds(ids: string[], libraryIds: ReadonlySet<string>): string[]`

- [ ] **Step 1: Write the failing tests**

```ts
// tests/queue.test.ts
import {
  appendUnique,
  entryFromMediaItem,
  filterQueueIds,
  mediaItemFor,
  moveItem,
  playNext,
  removeItemAt,
} from '../src/playback/queue';
import type { Track } from '../src/types/music';

const track: Track = {
  id: 't1', title: 'Nikes', artist: 'Frank Ocean', album: 'Blonde',
  uri: 'file:///Music/Blonde/01 Nikes.mp3', duration: 300, artwork: 'file:///art.jpg',
};

describe('queue entries', () => {
  test('maps a track to a media item with a stable media id', () => {
    expect(mediaItemFor(track)).toEqual({
      mediaId: 't1', url: 'file:///Music/Blonde/01 Nikes.mp3', title: 'Nikes',
      artist: 'Frank Ocean', albumTitle: 'Blonde', duration: 300,
      artworkUrl: 'file:///art.jpg',
    });
  });

  test('falls back when engine metadata is missing', () => {
    expect(entryFromMediaItem({ url: 'file:///x.mp3' })).toEqual({
      mediaId: 'file:///x.mp3', title: 'Untitled track', artist: 'Unknown artist', artwork: null,
    });
  });

  test('keeps only ids the library still has, in order', () => {
    expect(filterQueueIds(['a', 'b', 'c'], new Set(['c', 'a']))).toEqual(['a', 'c']);
  });
});

describe('queue order helpers', () => {
  test('moves an item and leaves out-of-range or same-index calls untouched', () => {
    expect(moveItem(['a', 'b', 'c'], 0, 2)).toEqual(['b', 'c', 'a']);
    expect(moveItem(['a', 'b', 'c'], 2, 0)).toEqual(['c', 'a', 'b']);
    const ids = ['a', 'b'];
    expect(moveItem(ids, 1, 1)).toBe(ids);
    expect(moveItem(ids, -1, 0)).toBe(ids);
    expect(moveItem(ids, 0, 5)).toBe(ids);
  });

  test('removes at an index and no-ops out of range', () => {
    expect(removeItemAt(['a', 'b', 'c'], 1)).toEqual(['a', 'c']);
    const ids = ['a'];
    expect(removeItemAt(ids, 3)).toBe(ids);
  });

  test('appends once and no-ops for an id already queued', () => {
    expect(appendUnique(['a'], 'b')).toEqual(['a', 'b']);
    const ids = ['a'];
    expect(appendUnique(ids, 'a')).toBe(ids);
  });

  test('inserts play-next straight after the active item', () => {
    expect(playNext(['a', 'b', 'c'], 0, 'x')).toEqual({ ids: ['a', 'x', 'b', 'c'], index: 1 });
  });

  test('moves an already-queued track next instead of duplicating it', () => {
    // 'c' is queued last while 'a' plays: it should move, not appear twice.
    expect(playNext(['a', 'b', 'c'], 0, 'c')).toEqual({ ids: ['a', 'c', 'b'], index: 1 });
  });

  test('moves a queued track that sits before the active one', () => {
    // 'a' is queued while 'c' plays: removing it shifts the anchor back one.
    expect(playNext(['a', 'b', 'c'], 2, 'a')).toEqual({ ids: ['b', 'c', 'a'], index: 2 });
  });

  test('no-ops when the active track itself is requested next', () => {
    const ids = ['a', 'b'];
    expect(playNext(ids, 0, 'a')).toEqual({ ids, index: -1 });
  });

  test('starts a queue from empty', () => {
    expect(playNext([], -1, 'x')).toEqual({ ids: ['x'], index: 0 });
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npx jest tests/queue.test.ts`
Expected: FAIL — cannot resolve `../src/playback/queue`.

- [ ] **Step 3: Implement `src/playback/queue.ts`**

Export the interfaces above. `mediaItemFor` mirrors the mapping already in
`playTrack` (mediaId, url, title, artist, albumTitle, duration, artworkUrl).
`entryFromMediaItem` falls back to the url as `mediaId`, `'Untitled track'`,
`'Unknown artist'`, and null artwork when the engine item lacks fields.
`playNext` removes every existing occurrence of the id first (so the returned
`index` always refers to the post-removal list), returns `{ ids, index: -1 }`
when the id is the active item, and inserts after the active item's new
position, or at 0 when nothing is active. `moveItem`/`removeItemAt` return the
same array reference for no-op calls.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npx jest tests/queue.test.ts`
Expected: PASS, 9 tests.

- [ ] **Step 5: Commit** (skipped in this session; commits are deferred to the user)

---

### Task 2: Player context queue mirror and actions

**Files:**
- Modify: `src/playback/PlayerContext.tsx`

**Interfaces:**
- Consumes: everything Task 1 produces.
- Produces (added to `PlayerContextValue`):
  - `queueItems: QueueEntry[]`
  - `queueIndex: number` (`-1` when nothing is queued)
  - `playNext(track: Track): void`
  - `addToQueue(track: Track): void`
  - `removeQueueItem(index: number): void`
  - `moveQueueItem(from: number, to: number): void`
  - `clearQueue(): void`
  - `playQueueItem(index: number): void`

- [ ] **Step 1: Mirror the engine queue**

Add `queueItems`/`queueIndex` state and a `refreshQueue` callback that reads
`TrackPlayer.getQueue().map(entryFromMediaItem)` and
`TrackPlayer.getActiveMediaItemIndex() ?? -1` inside one try/catch (the player
may not be initialised yet; keep the last good value on throw).

- [ ] **Step 2: Refresh on playback changes**

Call `refreshQueue()` after `playTrack`'s `setMediaItems`, and subscribe to
`Event.MediaItemTransition` to refresh on auto-advance. `playTrack` must build
its items with `mediaItemFor` so the mapping lives in one place.

- [ ] **Step 3: Add the seven actions**

- `playNext(track)`: if the queue is empty, `playTrack(track, [track])`;
  otherwise `insertMediaItem(result.index, mediaItemFor(track))` then refresh.
- `addToQueue(track)`: empty-queue branch as above; otherwise
  `insertMediaItem(TrackPlayer.getQueue().length, item)` only when
  `appendUnique` reports a change.
- `removeQueueItem(index)`: `removeMediaItem(index)`, then refresh; when the
  queue becomes empty, clear `queueItems`, set `queueIndex` to -1, and clear
  `selectedId`.
- `moveQueueItem(from, to)`: `moveMediaItem(from, to)`, then refresh.
- `clearQueue()`: confirm-free primitive — `clear()`, empty the mirror, clear
  `selectedId`. (The confirm dialog lives in the sheet.)
- `playQueueItem(index)`: `skipToIndex(index)` + `play()`, then refresh.
- Each wraps its native call in try/catch feeding the existing `setError`
  message path, matching the other transport actions.

- [ ] **Step 4: Verify the static gates**

Run: `npx tsc --noEmit` and `npx jest`
Expected: exit 0; 5 suites / 21 tests pass.

- [ ] **Step 5: Commit** (skipped in this session; commits are deferred to the user)

---

### Task 3: Queue sheet and reachability

**Files:**
- Create: `src/components/QueueSheet.tsx`
- Modify: `src/app/player.tsx`
- Modify: `src/app/(tabs)/library.tsx`

**Interfaces:**
- Consumes: all context interfaces from Task 2; `filterQueueIds` from Task 1.
- Produces: `QueueSheet({ visible, onClose }: { visible: boolean; onClose: () => void })`.

- [ ] **Step 1: Build `QueueSheet`**

Modal + backdrop + `SheetPanel` + `Panel` per `AddSongsSheet`. Header: "Up
next", subtitle `N songs`, actions Save (`save` icon) and Clear (`trash-2`),
close `x`. Body: `FlatList` of `queueItems`; leading shows the 1-based position
plus `CoverArt`; the active row adds a `volume-2` icon, accent title colour,
and `accessibilityState={{ selected: true }}`; trailing `⋯` opens an
`AppDialog` (inline variant) with Play now / Move up / Move down / Remove /
Cancel, omitting unavailable moves. Clear opens a confirm dialog first
("Clear queue?" / "Playback stops…"). Save opens `CreatePlaylistSheet`; on
create: `library.createPlaylist(name)` then `library.addToPlaylist(id,
trackId)` for each of `filterQueueIds(queueItems.map(id => e.mediaId),
new Set(library.displayTracksById.keys()))`, in order, then `tapFeedback('success')`.
Empty queue: `EmptyState` "Nothing queued" / "Songs you play appear here."

- [ ] **Step 2: Open it from the player**

`src/app/player.tsx`: add an `IconButton name="list" label="Queue"` to
`secondaryControls` and render `<QueueSheet>` next to `LyricsSheet`.

- [ ] **Step 3: Reach the queue actions from song menus**

`src/app/(tabs)/library.tsx`: extend the song `AppDialog` to Play next / Add to
queue / Add to playlist / Add-or-Remove favorite / Cancel — `Play` is dropped
because row tap already plays and the dialog stays inside the tested
five-action bound.

- [ ] **Step 4: Verify the static gates and the whole suite**

Run: `npx tsc --noEmit`, `npx expo lint`, `npx jest`
Expected: all exit 0; jest 5 suites / 21 tests.

- [ ] **Step 5: Commit** (skipped in this session; commits are deferred to the user)

---

## Manual device checks (not runnable here)

1. Remove the playing item → next item plays, mirror highlights it.
2. Clear while playing → audio stops, mini-player disappears, sheet shows the
   empty state.
3. Reorder while repeat-one is on → order changes, the same track keeps playing.
4. Save a queue containing a deleted file → playlist gains only existing ids.
5. TalkBack: every row and action announces title + position; reduced motion
   keeps the sheet entrance a fade only.
