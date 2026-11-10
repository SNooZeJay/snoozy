# Snoozy queue management — design

Date: 2026-10-28
Status: approved by directive ("finish the app"), built in the same session.
Source requirements: the user's offline-first player feature list, §3 (queue
reordering/removal/clearing, play next, add to queue, save queue as playlist)
and §10 (playlist from queue). Audit context: `docs/COVERAGE-v2.3.md`.

## Intent

Playback order exists only inside the native player. A listener can skip
forward but cannot see what is next, reorder it, drop a bad pick, or turn the
current queue into a playlist. This change gives the live playback session a
queue surface and the two missing menu actions, with no new dependencies.

## Goals

- See the queue in playback order with the currently playing item marked.
- Reorder (move up / move down), remove, and clear the queue.
- Jump to any queued item.
- Play next and add to queue from song menus.
- Save the queue as a playlist, in order.

## Non-goals

- A durable "Up next" that survives restarts: restore of queue and position is
  its own P0 slice (`docs/COVERAGE-v2.3.md`, P0 item 2).
- Editing or adding to the queue while nothing is playing.
- Drag-to-reorder (needs a direct gesture dependency; row actions work today).
- Per-item queue artwork beyond what the engine already carries.

## Anti-goals

- A second source of queue truth that can drift from the engine.
- A full-screen queue route that hides the player and adds a stack entry.
- New animation vocabulary, or motion that ignores reduced-motion settings.

## Approaches considered

1. **App-owned durable queue** — Snoozy owns the list, persists it, and Syncs
   the engine to it. Correct end state, but it is the restore feature's core:
   cold-start ordering, library-not-loaded races, and migration of the
   existing `playTrack` path. Too large for this slice.
2. **Live-session mirror of the engine queue** *(chosen)* — the engine keeps
   the authoritative order; the app mirrors `{items, index}` and refreshes
   after every mutation and on `MediaItemTransition`. Smallest change that
   fully solves the visible problem, and it composes with approach 1 later
   because the UI reads only the mirror.
3. **Full-screen queue route with drag reorder** — rejected: a new route
   separates the queue from playback, and drag needs `react-native-gesture-handler`
   as a direct dependency (today it is only transitive) or hand-rolled work.

## Decisions taken

- Queue sheet opened from the player screen; row tap jumps to that item;
  `⋯` opens the tested five-action dialog bound (Play now / Move up / Move
  down / Remove / Cancel), with unavailable moves omitted.
- `Clear` and `Remove` are confirmed through the shared `AppDialog`; clearing
  stops playback and empties the mini-player, so the copy says so.
- Library song menu gains `Play next` and `Add to queue`; the now-redundant
  `Play` action is dropped to stay at five dialog actions (row tap plays).
- `Play next` moves an already-queued track instead of duplicating it;
  `Add to queue` no-ops when the track is queued. (Spec: prevent accidental
  duplicate queue entries.)
- Save-as-playlist reuses `CreatePlaylistSheet` and the existing
  `createPlaylist`/`addToPlaylist` context API; missing library files are
  filtered out of the saved playlist.
- Row numbers are kept: a queue is a real sequence, so position is
  information, and the playing row is marked by icon + weight, not colour
  alone.

## Constraints

- No new dependencies; Expo SDK 58, RNTP 5.12.1, house components only.
- Motion stays inside the existing vocabulary (`SheetPanel` entrance,
  reduced-motion aware).
- 48 dp targets, explicit accessibility labels, undefined-safe for a missing
  active track.
- Offline only; no network touching queue state.

## Left to the builder

Exact spacing/typography tokens, sheet height, copy voice, and the FlatList
window settings — follow the surrounding sheets (`AddSongsSheet`,
`CreatePlaylistSheet`) and the theme tokens.
