# Phase 1 Spec: Cold-Start Playback Continuity

Date: 2026-11-11
Scope: Snoozy v3.0 Phase 1

## 1. Objective

Persist the active playback session so that when Snoozy is killed or cold-started, the last active track, queue, queue index, playback position, shuffle state, and repeat mode are restored in a paused state without auto-playing audio.

## 2. Persisted Session Schema

Store under key `session.v1` in `settingsStore` (`src/storage/preferences.ts`):

```ts
export interface PersistedPlaybackSession {
  version: 1;
  activeTrackId: string;
  queueIds: string[];
  queueIndex: number;
  positionSeconds: number;
  shuffle: boolean;
  repeatMode: 'off' | 'queue' | 'track';
  updatedAt: number;
}
```

## 3. Resolution Rules

1. Parse raw JSON safely. Return `null` on missing, malformed, or wrong-version payloads, or when `queueIds` is empty.
2. Filter `queueIds` against the current library `tracksById` map, preserving order. If no valid tracks remain, return `null`.
3. Determine `activeIndex`:
   - If the saved `queueIndex` points to `activeTrackId` and that track still exists, keep it.
   - If `activeTrackId` still exists in the filtered queue, use its index in the filtered queue and preserve `positionSeconds` (clamped to `[0, track.duration]`).
   - If `activeTrackId` was deleted from the device, select the next surviving track at or after `queueIndex` (clamped to `[0, filteredQueue.length - 1]`) and reset `positionSeconds` to `0`.
4. Clamp `positionSeconds` to a finite non-negative number not exceeding `track.duration` (when `track.duration > 0`).

## 4. Runtime Persistence and Restore Behavior

- **Write triggers**:
  - Track change (`PlaybackActiveTrackChanged` or `playTrack` / `skipToIndex`).
  - Queue mutation (`playNext`, `addToQueue`, `removeFromQueue`, `moveQueueItem`, `clearQueue`).
  - Shuffle or repeat mode toggle (`toggleShuffle`, `cycleRepeatMode`).
  - Pause action and `AppState` transition to `background` or `inactive`.
  - Throttled progress checkpoint every 5 seconds while playing.
- **Cold-start restore**:
  - Run once when `ready && !library.isLoading && library.tracks.length > 0`.
  - Skip if `TrackPlayer.getQueue()` is already non-empty (warm service recovery).
  - Otherwise load `session.v1`, resolve against `displayTracksById`, call `TrackPlayer.setMediaItems(items, resolved.activeIndex)`, `TrackPlayer.setRepeatMode(...)`, `TrackPlayer.setShuffleEnabled(...)`, `TrackPlayer.pause()`, and `TrackPlayer.seekTo(resolved.positionSeconds)`.
  - Seed React state (`selectedId`, `queueItems`, `queueIndex`, `shuffleEnabled`, `repeatMode`, and `restoredPosition`) so `MiniPlayer`, `/player`, and `QueueSheet` immediately display the restored track and seek position while paused.
