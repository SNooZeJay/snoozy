import type { Track } from '../types/music';
import type { RepeatState } from './controls';

export const SESSION_STORAGE_KEY = 'session.v1';

export interface PersistedPlaybackSession {
  version: 1;
  activeTrackId: string;
  queueIds: string[];
  queueIndex: number;
  positionSeconds: number;
  shuffle: boolean;
  repeatMode: RepeatState;
  updatedAt: number;
}

export interface PlaybackSessionInput {
  activeTrackId: string;
  queueIds: string[];
  queueIndex: number;
  positionSeconds: number;
  shuffle: boolean;
  repeatMode: RepeatState;
  updatedAt?: number;
}

export interface ResolvedPlaybackSession {
  activeTrack: Track;
  activeIndex: number;
  queueTracks: Track[];
  queueIds: string[];
  positionSeconds: number;
  shuffle: boolean;
  repeatMode: RepeatState;
}

export interface SessionKeyValueStore {
  getString(key: string): string | undefined;
  set(key: string, value: string): void;
  remove(key: string): boolean;
}

function isValidRepeatState(value: unknown): value is RepeatState {
  return value === 'off' || value === 'all' || value === 'one';
}

function sanitizePosition(seconds: unknown, maxDuration?: number): number {
  const numeric = typeof seconds === 'number' && Number.isFinite(seconds) ? seconds : 0;
  const nonNegative = Math.max(0, numeric);
  if (typeof maxDuration === 'number' && Number.isFinite(maxDuration) && maxDuration > 0) {
    return Math.min(nonNegative, maxDuration);
  }
  return nonNegative;
}

export function serializePlaybackSession(input: PlaybackSessionInput): string {
  const payload: PersistedPlaybackSession = {
    version: 1,
    activeTrackId: input.activeTrackId,
    queueIds: input.queueIds.filter((id) => typeof id === 'string' && id.length > 0),
    queueIndex: Number.isInteger(input.queueIndex) ? Math.max(0, input.queueIndex) : 0,
    positionSeconds: sanitizePosition(input.positionSeconds),
    shuffle: Boolean(input.shuffle),
    repeatMode: isValidRepeatState(input.repeatMode) ? input.repeatMode : 'off',
    updatedAt: typeof input.updatedAt === 'number' && Number.isFinite(input.updatedAt)
      ? input.updatedAt
      : Date.now(),
  };
  return JSON.stringify(payload);
}

export function parsePlaybackSession(raw: string | null | undefined): PersistedPlaybackSession | null {
  if (!raw || typeof raw !== 'string') return null;
  try {
    const parsed = JSON.parse(raw) as Record<string, unknown> | null;
    if (!parsed || typeof parsed !== 'object') return null;
    if (parsed.version !== 1) return null;
    if (typeof parsed.activeTrackId !== 'string' || parsed.activeTrackId.length === 0) {
      return null;
    }
    if (!Array.isArray(parsed.queueIds)) return null;
    const queueIds = parsed.queueIds.filter(
      (id): id is string => typeof id === 'string' && id.length > 0,
    );
    if (queueIds.length === 0) return null;
    const queueIndex =
      typeof parsed.queueIndex === 'number' && Number.isInteger(parsed.queueIndex)
        ? Math.max(0, parsed.queueIndex)
        : 0;
    const positionSeconds = sanitizePosition(parsed.positionSeconds);
    const shuffle = Boolean(parsed.shuffle);
    const repeatMode: RepeatState = isValidRepeatState(parsed.repeatMode)
      ? parsed.repeatMode
      : 'off';
    const updatedAt =
      typeof parsed.updatedAt === 'number' && Number.isFinite(parsed.updatedAt)
        ? parsed.updatedAt
        : 0;

    return {
      version: 1,
      activeTrackId: parsed.activeTrackId,
      queueIds,
      queueIndex,
      positionSeconds,
      shuffle,
      repeatMode,
      updatedAt,
    };
  } catch {
    return null;
  }
}

export function resolvePlaybackSession(
  session: PersistedPlaybackSession | null,
  tracksById: ReadonlyMap<string, Track>,
): ResolvedPlaybackSession | null {
  if (!session || tracksById.size === 0) return null;

  const queueTracks: Track[] = [];
  const queueIds: string[] = [];
  let activeIndexInFiltered = -1;
  let fallbackIndexAfterDeleted = -1;

  for (let i = 0; i < session.queueIds.length; i += 1) {
    const id = session.queueIds[i];
    const track = tracksById.get(id);
    if (!track) continue;
    const nextFilteredIndex = queueTracks.length;
    queueTracks.push(track);
    queueIds.push(track.id);
    if (track.id === session.activeTrackId && activeIndexInFiltered === -1) {
      activeIndexInFiltered = nextFilteredIndex;
    }
    if (i >= session.queueIndex && fallbackIndexAfterDeleted === -1) {
      fallbackIndexAfterDeleted = nextFilteredIndex;
    }
  }

  if (queueTracks.length === 0) return null;

  const activeTrackStillPresent = activeIndexInFiltered !== -1;
  const resolvedIndex = activeTrackStillPresent
    ? activeIndexInFiltered
    : fallbackIndexAfterDeleted !== -1
      ? fallbackIndexAfterDeleted
      : queueTracks.length - 1;

  const activeTrack = queueTracks[resolvedIndex];
  if (!activeTrack) return null;

  const positionSeconds = activeTrackStillPresent
    ? sanitizePosition(session.positionSeconds, activeTrack.duration)
    : 0;

  return {
    activeTrack,
    activeIndex: resolvedIndex,
    queueTracks,
    queueIds,
    positionSeconds,
    shuffle: session.shuffle,
    repeatMode: session.repeatMode,
  };
}

export function savePlaybackSession(
  store: SessionKeyValueStore | null | undefined,
  input: PlaybackSessionInput,
): void {
  if (!store || !input.activeTrackId || input.queueIds.length === 0) return;
  try {
    store.set(SESSION_STORAGE_KEY, serializePlaybackSession(input));
  } catch {
    // Storage failures must never interrupt playback.
  }
}

export function loadPlaybackSession(
  store: SessionKeyValueStore | null | undefined,
): PersistedPlaybackSession | null {
  if (!store) return null;
  try {
    return parsePlaybackSession(store.getString(SESSION_STORAGE_KEY));
  } catch {
    return null;
  }
}

export function clearPlaybackSession(store: SessionKeyValueStore | null | undefined): void {
  if (!store) return;
  try {
    store.remove(SESSION_STORAGE_KEY);
  } catch {
    // Ignore storage removal errors.
  }
}
