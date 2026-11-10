# Phase 1 Plan: Cold-Start Playback Continuity

Date: 2026-11-11
Spec: `docs/superpowers/specs/2026-11-11-phase-1-cold-start-continuity-design.md`

## Tasks

1. **Red (Failing Unit Tests)**:
   - Create `tests/session.test.ts` covering serialization, parsing, valid session resolution, deleted active track fallback to next valid track at `0:00`, all tracks deleted returning `null`, corrupt JSON / invalid version handling, and position clamping (`NaN`, negative, and `> duration`).
   - Run `npx jest tests/session.test.ts` and confirm failure before `src/playback/session.ts` exists.

2. **Green (Pure Session Module)**:
   - Implement `src/playback/session.ts` with `SESSION_STORAGE_KEY`, `serializePlaybackSession`, `parsePlaybackSession`, `resolvePlaybackSession`, `savePlaybackSession`, `loadPlaybackSession`, and `clearPlaybackSession`.
   - Re-run `npx jest tests/session.test.ts` and confirm all tests pass.

3. **Integration (`src/playback/PlayerContext.tsx`)**:
   - Restore warm or cold session on startup after `ready && !library.isLoading`.
   - Maintain `restoredPosition` in `PlaybackProgressProvider` so paused cold-start sessions display their restored seek position immediately before playback starts, and update `restoredPosition` when `seekTo` is called while paused.
   - Persist session on track change, queue change, shuffle/repeat toggle, pause, `AppState` background/inactive, and every 5 seconds during active playback.

4. **Static Gates & Device Verification**:
   - Run `npx tsc --noEmit`, `npx expo lint`, and `npx jest --silent`.
   - Sync to `C:\s`, build signed release APK, install on `9PGE8SQKAM598PBY` via `adb install -r`.
   - Play a track past `0:30`, queue two additional tracks, enable shuffle and repeat, force-stop `com.snoozy.app`, relaunch, and verify paused restoration on the phone.
