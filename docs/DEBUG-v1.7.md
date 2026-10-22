# Snoozy v1.7 debug log (code-level findings and fixes)

Statuses: FIXED-ON-DEVICE means verified in the new release build on the Oppo A55 4G. "Code" rows were fixed but still need the on-device check (the section at the bottom lists what ran on the device and what it showed).

## Root-cause fixes

1. **App frozen at v1.0.0.**
   - Root cause: version was hard-coded twice (`src/app/(tabs)/settings.tsx:187` as text, `app.json` `version: 1.0.0`, `versionCode 1`).
   - Fix: `app.json` version 1.7.0 / versionCode 7; `package.json` version 1.7.0; About now prints `Constants.expoConfig?.version` with a `1.7.0` fallback plus the build number (settings.tsx). Version 1.7.0 shown in About on device: FIXED-ON-DEVICE (About screenshot).

2. **Metadata edits were stored but shown nowhere.**
   - Root cause: `resolveTrackDisplay` in `src/storage/display.ts` was exported but never called by any screen; `library.tracks` always held raw scan values. Every list, the player, and the mini-player ignored overrides.
   - Fix: `MusicLibraryContext` now layers overrides onto scan results (`displayTracks`, `displayTracksById`, `refreshDisplay()`); `SongEditSheet` calls `refreshDisplay()` after save and reset; `PlayerContext.activeTrack` reads the display map with a raw fallback; album/artist pages, home rows, and search render display values (search matches both edited and original text).

3. **Playlists could never receive songs.**
   - Root cause: `addToPlaylist`/`removeFromPlaylist` existed in `MusicLibraryContext` but no screen ever exposed them; song rows only had a heart, playlist cards only had delete.
   - Fix: new `AddToPlaylistSheet` (song → playlist chooser with multi-select and inline create) + new `AddSongsSheet` (playlist → song picker with filter, add/remove); song rows carry an add-to-playlist action; playlist cards carry Add songs and per-track remove; empty playlists state names the action.

4. **Stale closure: create-then-add lost the track.**
   - Root cause: `createPlaylist` and `addToPlaylist` each closed over the `playlists` state from the render in progress; when the sheet creates a playlist and immediately adds the track, the second call mapped over the stale array and the new playlist was never included.
   - Fix: a synchronous ref (`playlistsRef`) is updated inside `persistPlaylists` before `setState`; all playlist mutators read through the ref. Any consecutive batch of mutations is now consistent.

5. **No favorites screen at all.**
   - Root cause: the context type already included a `'favorites'` tab (`MusicLibraryContext.tsx:32`) but the Library rendered only 4 tabs; favorites could be toggled but never listed anywhere in the app.
   - Fix: a fifth Library tab renders favorited tracks (display values, plays with the favorites list as queue) with an empty state explaining the heart interaction.

6. **Player showed the clock twice.**
   - Root cause: `SeekBar` renders its own time labels (`SeekBar.tsx:76-79`) and the player screen added a second, identical `timeRow`.
   - Fix: removed the duplicate row in `player.tsx` (SeekBar's labels have tabular numerals and stay).

7. **Lyrics + Edit stacked as two identical pills.**
   - Root cause: `secondaryControls` had no `flexDirection: 'row'`, so the two pill buttons centered vertically and read as repeated buttons.
   - Fix: one horizontal row of two 48 dp icon buttons (musical-notes, pencil) consistent with the transport circles.

8. **App-wide uppercase "micro" text.**
   - Root cause: the `micro` type variant was `textTransform: 'uppercase', letterSpacing: 1.5` at 10 px and was used for body copy, empty states, buttons, counters, and metadata everywhere — one voice shouted everything.
   - Fix: `micro` is now plain sentence-case small text; the uppercase treatment moved to a new `overline` variant used only for form field labels and the top-bar label. All screens inherit the fix.

9. **Search promised recents that did not exist.**
   - Root cause: the empty state rendered "Recent searches will appear here." — nothing stored, showed, or cleared queries.
   - Fix: real recents (last 5, newest first) in `snoozy.search.v1` MMKV; saved on submit, shown as list rows, each re-runnable, with a Clear control; the promise is gone when there is nothing to show.

10. **Orphaned album/artist routes.**
    - Root cause: `album.tsx` and `artist.tsx` existed but nothing navigated to them; the Library used an inconsistent in-tab selection model. Two competing models, one dead.
    - Fix: Library album/artist rows open the routes; both pages rebuilt in the row/empty-state language of the rest of the app (back button is now an icon button, totals line, Play/Shuffle, rescan empty state).

11. **Consistency pass (polish system):**
    - Sheet panels: `surfaceRaised`, top-radius `xl`, `heading`-size titles, icon-button close (CreatePlaylistSheet eyebrow removed).
    - Screens: one screen-header pattern (display title + status where meaningful); duplicate Home/Library status line removed from Home; "SNOOZY" kicker removed.
    - Copy: "1 songs" → "1 song" everywhere (library, settings); placeholder "YYYY"/"—"/"#" removed from form fields labeled Year/Genre/Track number; lyrics sheet "SOURCE: NONE" → sentence-case status line.
    - Scrims unified to `rgba(0,0,0,0.6)` across all sheets.

12. **Defect scan against the v1.7 checklist (the seven classes):**
    - Unhandled promise rejections: `LyricsSheet` resolve call now has a `.catch` (and the moved artwork copy, scan, and DB paths already wrap try/catch).
    - State read before it is loaded: display tracks initialize empty and fill asynchronously — guarded (`cancelled` flags) and no UI reads it before data exists (rows render when loaded).
    - Listeners/timers not removed: all `addEventListener` calls removed in cleanup; the listen-tracking `setInterval` clears; no new listeners were added.
    - Stale closures: playlist mutators fixed via ref; `playTrack` queues resolve from call-site state; `previous()` deliberately depends on fresh position.
    - Results written after unmount: display-merge effect and async loads use `cancelled` flags.
    - Duplicate DB writes: favorites toggle writes once per action; play history records at most once per track transition.
    - Hard-coded colors/radii/durations: screens keep using tokens; remaining rgba literals are scrims (unified value) and the seekbar track tint.

## Local audit rig prepared for device verification
- 12 WAV tracks (`SnoozyTest 01–12.lrc` sidecar on 01, ~2.5 min each, ~30 min queue), artwork PNG, all pushed and visible in MediaStore (12 rows via `content query`).
