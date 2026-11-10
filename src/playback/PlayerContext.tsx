import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import {
  AppState,
  PermissionsAndroid,
  Platform,
} from 'react-native';
import {
  Event,
  useActiveMediaItem,
  useIsPlaying,
  useProgress,
} from '@rntp/player';
import { getColors } from 'react-native-image-colors';
import { createMMKV } from 'react-native-mmkv';

import type { Track } from '../types/music';
import {
  defaultPalette,
  paletteFromArtworkColor,
  type ArtworkPalette,
} from '../theme';
import { useMusicLibrary } from '../storage/MusicLibraryContext';
import { recordPlay } from '../storage/playHistory';
import { logError } from '../storage/errorLog';
import {
  finishListeningSession,
  startListeningSession,
} from '../storage/history';

import {
  TrackPlayer,
  ensurePlayer,
  watchPlaybackError,
  RepeatMode,
} from './player';
import { nextRepeatState, type RepeatState } from './controls';
import {
  appendUnique,
  entryFromMediaItem,
  mediaItemFor,
  playNext as insertNextOrder,
  type QueueEntry,
} from './queue';
import {
  clearPlaybackSession,
  loadPlaybackSession,
  resolvePlaybackSession,
  savePlaybackSession,
} from './session';

type Session = {
  id: number | null;
  trackId: string;
  startedAt: number;
};

type PlayerContextValue = {
  ready: boolean;
  error: string | null;
  dismissError: () => void;
  activeTrack: Track | null;
  palette: ArtworkPalette;
  isPlaying: boolean;
  playTrack: (
    track: Track,
    queue?: Track[],
    options?: { shuffle?: boolean; repeatMode?: RepeatMode },
  ) => Promise<void>;
  togglePlayback: () => Promise<void>;
  pausePlayback: () => void;
  next: () => Promise<void>;
  previous: () => Promise<void>;
  seekTo: (seconds: number) => void;
  queueItems: QueueEntry[];
  queueIndex: number;
  playNext: (track: Track) => void;
  addToQueue: (track: Track) => void;
  removeQueueItem: (index: number) => void;
  moveQueueItem: (from: number, to: number) => void;
  clearQueue: () => void;
  playQueueItem: (index: number) => void;
  repeatMode: RepeatMode;
  cycleRepeat: () => void;
  shuffle: boolean;
  toggleShuffle: () => void;
  setShuffle: (enabled: boolean) => void;
  playbackRate: number;
  setPlaybackRate: (rate: number) => void;
};

const PlayerContext = createContext<PlayerContextValue | null>(null);

type PlaybackProgressValue = {
  progress: number;
  duration: number;
};

const PlaybackProgressContext = createContext<PlaybackProgressValue | null>(null);

// MMKV instances hold native handles. Create this once per process rather than
// once per provider render.
const settingsStore = createMMKV({ id: 'snoozy.playback.v1' });

/**
 * Progress is intentionally separate from PlayerContext. Polling every second
 * would otherwise invalidate the whole player context and re-render every
 * consumer (home, library, search, mini-player) once per second.
 */
function PlaybackProgressProvider({
  children,
  fallbackDuration,
  restoredPosition,
}: {
  children: ReactNode;
  fallbackDuration: number;
  restoredPosition: number;
}) {
  const nativeProgress = useProgress(1);
  const value = useMemo<PlaybackProgressValue>(
    () => ({
      progress: nativeProgress.position > 0 ? nativeProgress.position : restoredPosition,
      duration: nativeProgress.duration || fallbackDuration,
    }),
    [fallbackDuration, nativeProgress.duration, nativeProgress.position, restoredPosition],
  );
  return (
    <PlaybackProgressContext.Provider value={value}>
      {children}
    </PlaybackProgressContext.Provider>
  );
}

export function PlayerProvider({ children }: { children: ReactNode }) {
  const library = useMusicLibrary();
  const {
    displayTracks,
    displayTracksById,
    recents,
    recordRecent,
    tracks: libraryTracks,
    tracksById,
  } = library;
  const activeItem = useActiveMediaItem();
  const playing = useIsPlaying();

  const [ready, setReady] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(
    recents[0] ?? libraryTracks[0]?.id ?? null,
  );
  const [extractedPalette, setExtractedPalette] = useState<{
    key: string;
    palette: ArtworkPalette;
  } | null>(null);
  const [repeatMode, setRepeatModeState] = useState<RepeatMode>(() => {
    const savedSession = loadPlaybackSession(settingsStore);
    if (savedSession) return savedSession.repeatMode as RepeatMode;
    const rawRepeat = settingsStore.getString('repeatMode');
    if (rawRepeat === RepeatMode.All || rawRepeat === RepeatMode.One || rawRepeat === RepeatMode.Off) {
      return rawRepeat;
    }
    return RepeatMode.Off;
  });
  const [shuffle, setShuffleState] = useState<boolean>(() => {
    const savedSession = loadPlaybackSession(settingsStore);
    if (savedSession) return savedSession.shuffle;
    return settingsStore.getBoolean('shuffle') ?? false;
  });
  const [playbackRate, setPlaybackRateState] = useState<number>(() => settingsStore.getNumber('playbackRate') ?? 1);
  const [queueItems, setQueueItems] = useState<QueueEntry[]>([]);
  const [queueIndex, setQueueIndex] = useState(-1);
  const [restoredPosition, setRestoredPosition] = useState<number>(() => {
    const savedSession = loadPlaybackSession(settingsStore);
    return savedSession?.positionSeconds ?? 0;
  });
  const restoredPositionRef = useRef<number>(restoredPosition);
  const coldStartRestoredRef = useRef(false);
  const previousMediaIdRef = useRef<string | null>(null);
  const queueItemsRef = useRef<QueueEntry[]>([]);
  const queueIndexRef = useRef<number>(-1);
  const repeatModeRef = useRef<RepeatMode>(repeatMode);
  const shuffleRef = useRef<boolean>(shuffle);
  const sessionRef = useRef<Session | null>(null);
  const listenRef = useRef<{ trackId: string; maxPosition: number; duration: number } | null>(null);
  const askedNotifications = useRef(false);
  const activeTrackIdRef = useRef<string | null>(null);

  const activeTrack = useMemo(() => {
    const id = activeItem?.mediaId ?? selectedId;
    if (!id) return null;
    // Display map carries metadata edits; fall back to raw while it loads.
    return displayTracksById.get(id) ?? tracksById.get(id) ?? null;
  }, [activeItem?.mediaId, displayTracksById, selectedId, tracksById]);

  useEffect(() => {
    activeTrackIdRef.current = activeTrack?.id ?? null;
  }, [activeTrack]);

  useEffect(() => {
    queueItemsRef.current = queueItems;
  }, [queueItems]);

  useEffect(() => {
    queueIndexRef.current = queueIndex;
  }, [queueIndex]);

  useEffect(() => {
    repeatModeRef.current = repeatMode;
  }, [repeatMode]);

  useEffect(() => {
    shuffleRef.current = shuffle;
  }, [shuffle]);

  const persistCurrentSession = useCallback(
    (overrides?: {
      activeTrackId?: string;
      queueIds?: string[];
      queueIndex?: number;
      positionSeconds?: number;
      shuffle?: boolean;
      repeatMode?: RepeatMode;
    }) => {
      try {
        let nativeQueueIds: string[] = [];
        let nativeIndex = -1;
        let nativePosition = 0;
        try {
          nativeQueueIds = TrackPlayer.getQueue()
            .map((item) => item.mediaId ?? '')
            .filter((id) => id.length > 0);
          nativeIndex = TrackPlayer.getActiveMediaItemIndex() ?? -1;
          nativePosition = TrackPlayer.getProgress().position;
        } catch {
          // Player can be uninitialized or between tracks.
        }

        const queueIds =
          overrides?.queueIds ??
          (nativeQueueIds.length > 0
            ? nativeQueueIds
            : queueItemsRef.current.map((entry) => entry.mediaId));
        if (queueIds.length === 0) return;

        const resolvedIndex =
          overrides?.queueIndex ??
          (nativeIndex >= 0 ? nativeIndex : Math.max(0, queueIndexRef.current));
        const activeTrackId =
          overrides?.activeTrackId ??
          activeTrackIdRef.current ??
          queueIds[resolvedIndex] ??
          queueIds[0];
        if (!activeTrackId) return;

        const positionSeconds =
          overrides?.positionSeconds ??
          (nativePosition > 0 ? nativePosition : restoredPositionRef.current);

        savePlaybackSession(settingsStore, {
          activeTrackId,
          queueIds,
          queueIndex: Math.min(queueIds.length - 1, Math.max(0, resolvedIndex)),
          positionSeconds,
          shuffle: overrides?.shuffle ?? shuffleRef.current,
          repeatMode: (overrides?.repeatMode ?? repeatModeRef.current) as RepeatState,
        });
      } catch {
        // Session persistence must never interrupt playback.
      }
    },
    [],
  );

  useEffect(() => {
    let cancelled = false;
    const artwork = activeTrack?.artwork;
    if (!artwork) {
      return () => {
        cancelled = true;
      };
    }

    void getColors(artwork, {
      fallback: defaultPalette.accent,
      cache: true,
      key: artwork,
      pixelSpacing: 5,
    })
      .then((result) => {
        if (cancelled) return;
        const source =
          result.platform === 'android'
            ? result.vibrant || result.lightVibrant || result.dominant
            : result.platform === 'ios'
              ? result.primary
              : result.vibrant || result.dominant;
        setExtractedPalette({
          key: artwork,
          palette: paletteFromArtworkColor(source),
        });
      })
      .catch(() => {
        if (!cancelled) {
          setExtractedPalette({ key: artwork, palette: defaultPalette });
        }
      });

    return () => {
      cancelled = true;
    };
  }, [activeTrack?.artwork]);

  const palette =
    activeTrack?.artwork && extractedPalette?.key === activeTrack.artwork
      ? extractedPalette.palette
      : defaultPalette;

  useEffect(() => {
    const prev = listenRef.current;
    if (prev && prev.trackId !== activeTrack?.id) {
      const threshold = Math.min(30000, (prev.duration || 0) * 1000 * 0.5);
      if (threshold > 0 && prev.maxPosition >= threshold) {
        void recordPlay(prev.trackId, prev.maxPosition);
      }
    }
    if (activeTrack) {
      listenRef.current = { trackId: activeTrack.id, maxPosition: 0, duration: activeTrack.duration || 0 };
    } else {
      listenRef.current = null;
    }
  }, [activeTrack]);

  useEffect(() => {
    if (!playing) return;
    const interval = setInterval(() => {
      const current = listenRef.current;
      try {
        const pos = TrackPlayer.getProgress().position * 1000;
        if (current && pos > current.maxPosition) current.maxPosition = pos;
        if (pos > 0 && restoredPositionRef.current > 0) {
          restoredPositionRef.current = 0;
          setRestoredPosition(0);
        }
      } catch {
        // The player can be between tracks; skip this sample.
      }
    }, 1000);
    const persistInterval = setInterval(() => {
      persistCurrentSession();
    }, 5000);
    return () => {
      clearInterval(interval);
      clearInterval(persistInterval);
    };
  }, [persistCurrentSession, playing]);

  useEffect(() => {
    const subscription = AppState.addEventListener('change', (nextState) => {
      if (nextState === 'background' || nextState === 'inactive') {
        persistCurrentSession();
      }
    });
    return () => {
      subscription.remove();
    };
  }, [persistCurrentSession]);

  const messageFor = (value: unknown) =>
    value instanceof Error ? value.message : String(value ?? 'Playback failed');

  const askForNotifications = useCallback(async () => {
    // no-op guard handled by ref
    if (askedNotifications.current) return;
    askedNotifications.current = true;
    if (Platform.OS !== 'android' || Platform.Version < 33) return;
    try {
      await PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS);
    } catch {
      // Notification permission is optional for local playback.
    }
  }, []);

  // The native queue owns playback order; this mirror only reflects it. It is
  // re-read after every queue edit and on every media-item transition instead
  // of being derived from app state, so it cannot drift from the engine.
  const refreshQueue = useCallback(() => {
    try {
      const entries = TrackPlayer.getQueue().map(entryFromMediaItem);
      const index = TrackPlayer.getActiveMediaItemIndex() ?? -1;
      setQueueItems(entries);
      setQueueIndex(index);
      if (entries.length > 0) {
        settingsStore.set('queueIds', JSON.stringify(entries.map((e) => e.mediaId)));
      }
    } catch {
      // The player can be between sessions; keep the last known queue.
    }
  }, []);

  const beginSession = useCallback(async (track: Track) => {
    if (sessionRef.current?.trackId === track.id) return;
    const previous = sessionRef.current;
    if (previous?.id) {
      const elapsedSeconds = Math.max(0, (Date.now() - previous.startedAt) / 1000);
      await finishListeningSession(previous.id, elapsedSeconds);
    }
    const id = await startListeningSession(track.id);
    sessionRef.current = { id, trackId: track.id, startedAt: Date.now() };
  }, []);

  const endSession = useCallback(async () => {
    const current = sessionRef.current;
    if (!current?.id) {
      sessionRef.current = null;
      return;
    }
    const elapsedSeconds = Math.max(0, (Date.now() - current.startedAt) / 1000);
    await finishListeningSession(current.id, elapsedSeconds);
    sessionRef.current = null;
  }, []);

  const playTrack = useCallback(
    async (
      track: Track,
      queue: Track[] = displayTracks,
      options: { shuffle?: boolean; repeatMode?: RepeatMode } = {},
    ) => {
      setError(null);
      recordRecent(track.id);
      setSelectedId(track.id);
      previousMediaIdRef.current = track.id;
      restoredPositionRef.current = 0;
      setRestoredPosition(0);
      const nextShuffle = options.shuffle ?? shuffle;
      const nextRepeat = options.repeatMode ?? repeatMode;
      try {
        await ensurePlayer();
        const items = queue.map(mediaItemFor);
        const startIndex = Math.max(0, items.findIndex((item) => item.mediaId === track.id));
        TrackPlayer.setMediaItems(items, startIndex);
        TrackPlayer.setRepeatMode(nextRepeat);
        TrackPlayer.setShuffleEnabled(nextShuffle);
        TrackPlayer.play();
        refreshQueue();
        setRepeatModeState(nextRepeat);
        settingsStore.set('repeatMode', nextRepeat);
        setShuffleState(nextShuffle);
        settingsStore.set('shuffle', nextShuffle);
        persistCurrentSession({
          activeTrackId: track.id,
          queueIds: queue.map((item) => item.id),
          queueIndex: startIndex,
          positionSeconds: 0,
          shuffle: nextShuffle,
          repeatMode: nextRepeat,
        });
        await askForNotifications();
        setReady(true);
      } catch (playError) {
        setError(messageFor(playError));
      }
    },
    [askForNotifications, displayTracks, persistCurrentSession, recordRecent, refreshQueue, repeatMode, shuffle],
  );

  const togglePlayback = useCallback(async () => {
    setError(null);
    try {
      await ensurePlayer();
      if (TrackPlayer.isPlaying()) {
        TrackPlayer.pause();
        persistCurrentSession();
      } else if (TrackPlayer.getQueue().length === 0 && activeTrack) {
        const saved = resolvePlaybackSession(
          loadPlaybackSession(settingsStore),
          displayTracksById.size > 0 ? displayTracksById : tracksById,
        );
        if (saved && saved.activeTrack.id === activeTrack.id) {
          const items = saved.queueTracks.map(mediaItemFor);
          TrackPlayer.setMediaItems(items, saved.activeIndex);
          TrackPlayer.setRepeatMode(saved.repeatMode as RepeatMode);
          TrackPlayer.setShuffleEnabled(saved.shuffle);
          if (saved.positionSeconds > 0) {
            TrackPlayer.seekTo(saved.positionSeconds);
          }
          TrackPlayer.play();
          refreshQueue();
          await askForNotifications();
          setReady(true);
          return;
        }
        let restoredQueue: Track[] = [];
        try {
          const raw = settingsStore.getString('queueIds');
          const ids = raw ? (JSON.parse(raw) as unknown) : null;
          if (Array.isArray(ids)) {
            restoredQueue = ids
              .map((id) => (typeof id === 'string' ? displayTracksById.get(id) ?? tracksById.get(id) : undefined))
              .filter((t): t is Track => Boolean(t));
          }
        } catch {
          // Fall back to the full library below.
        }
        if (!restoredQueue.some((t) => t.id === activeTrack.id)) {
          restoredQueue = displayTracks.length > 0 ? displayTracks : [activeTrack];
        }
        await playTrack(activeTrack, restoredQueue);
        return;
      } else {
        if (restoredPositionRef.current > 0) {
          let currentNativePosition = 0;
          try {
            currentNativePosition = TrackPlayer.getProgress().position;
          } catch {
            // ignore
          }
          if (currentNativePosition < 1) {
            TrackPlayer.seekTo(restoredPositionRef.current);
          }
        }
        TrackPlayer.play();
      }
      await askForNotifications();
      setReady(true);
    } catch (playError) {
      setError(messageFor(playError));
    }
  }, [activeTrack, askForNotifications, displayTracks, displayTracksById, persistCurrentSession, playTrack, refreshQueue, tracksById]);

  const pausePlayback = useCallback(() => {
    try {
      TrackPlayer.pause();
      persistCurrentSession();
    } catch (pauseError) {
      setError(messageFor(pauseError));
    }
  }, [persistCurrentSession]);

  const next = useCallback(async () => {
    try {
      await ensurePlayer();
      restoredPositionRef.current = 0;
      setRestoredPosition(0);
      TrackPlayer.skipToNext();
      setReady(true);
    } catch (playError) {
      setError(messageFor(playError));
    }
  }, []);

  const previous = useCallback(async () => {
    try {
      await ensurePlayer();
      let position = 0;
      try {
        position = TrackPlayer.getProgress().position;
      } catch {
        // Fall back to the previous-track behavior if progress is unavailable.
      }
      restoredPositionRef.current = 0;
      setRestoredPosition(0);
      if (position > 3) {
        TrackPlayer.seekTo(0);
      } else {
        TrackPlayer.skipToPrevious();
      }
      setReady(true);
    } catch (playError) {
      setError(messageFor(playError));
    }
  }, []);

  const seekTo = useCallback(
    (seconds: number) => {
      const clamped = Math.max(0, seconds);
      try {
        restoredPositionRef.current = clamped;
        setRestoredPosition(clamped);
        TrackPlayer.seekTo(clamped);
        persistCurrentSession({ positionSeconds: clamped });
      } catch (seekError) {
        setError(messageFor(seekError));
      }
    },
    [persistCurrentSession],
  );

  const currentQueueIds = () => TrackPlayer.getQueue().map((item) => item.mediaId ?? '');

  // "Play next" starts playback when nothing is queued, otherwise moves an
  // already-queued track next instead of duplicating it.
  const playNext = useCallback(
    (track: Track) => {
      try {
        const ids = currentQueueIds();
        if (ids.length === 0) {
          void playTrack(track, [track]);
          return;
        }
        const activeIndex = TrackPlayer.getActiveMediaItemIndex() ?? -1;
        const { index } = insertNextOrder(ids, activeIndex, track.id);
        if (index < 0) return;
        const existing = ids.indexOf(track.id);
        if (existing >= 0) TrackPlayer.removeMediaItem(existing);
        TrackPlayer.insertMediaItem(index, mediaItemFor(track));
        refreshQueue();
        persistCurrentSession();
      } catch (queueError) {
        setError(messageFor(queueError));
      }
    },
    [persistCurrentSession, playTrack, refreshQueue],
  );

  const addToQueue = useCallback(
    (track: Track) => {
      try {
        const ids = currentQueueIds();
        if (ids.length === 0) {
          void playTrack(track, [track]);
          return;
        }
        if (appendUnique(ids, track.id) === ids) return;
        TrackPlayer.insertMediaItem(ids.length, mediaItemFor(track));
        refreshQueue();
        persistCurrentSession();
      } catch (queueError) {
        setError(messageFor(queueError));
      }
    },
    [persistCurrentSession, playTrack, refreshQueue],
  );

  const removeQueueItem = useCallback(
    (index: number) => {
      try {
        TrackPlayer.removeMediaItem(index);
        if (TrackPlayer.getQueue().length === 0) {
          setQueueItems([]);
          setQueueIndex(-1);
          setSelectedId(null);
          clearPlaybackSession(settingsStore);
          return;
        }
        refreshQueue();
        persistCurrentSession();
      } catch (queueError) {
        setError(messageFor(queueError));
      }
    },
    [persistCurrentSession, refreshQueue],
  );

  const moveQueueItem = useCallback(
    (from: number, to: number) => {
      try {
        TrackPlayer.moveMediaItem(from, to);
        refreshQueue();
        persistCurrentSession();
      } catch (queueError) {
        setError(messageFor(queueError));
      }
    },
    [persistCurrentSession, refreshQueue],
  );

  const clearQueue = useCallback(() => {
    try {
      TrackPlayer.clear();
      settingsStore.remove('queueIds');
      clearPlaybackSession(settingsStore);
    } catch (queueError) {
      setError(messageFor(queueError));
    }
    restoredPositionRef.current = 0;
    setRestoredPosition(0);
    setQueueItems([]);
    setQueueIndex(-1);
    setSelectedId(null);
  }, []);

  const playQueueItem = useCallback(
    (index: number) => {
      try {
        restoredPositionRef.current = 0;
        setRestoredPosition(0);
        TrackPlayer.skipToIndex(index);
        TrackPlayer.play();
        refreshQueue();
        persistCurrentSession({ queueIndex: index, positionSeconds: 0 });
      } catch (queueError) {
        setError(messageFor(queueError));
      }
    },
    [persistCurrentSession, refreshQueue],
  );

  const cycleRepeat = useCallback(() => {
    setRepeatModeState((prev) => {
      const next = nextRepeatState(prev as RepeatState) as RepeatMode;
      try { TrackPlayer.setRepeatMode(next); } catch { /* ignore */ }
      settingsStore.set('repeatMode', next);
      persistCurrentSession({ repeatMode: next });
      return next;
    });
  }, [persistCurrentSession]);

  const setShuffle = useCallback(
    (enabled: boolean) => {
      setShuffleState(enabled);
      try { TrackPlayer.setShuffleEnabled(enabled); } catch { /* ignore */ }
      settingsStore.set('shuffle', enabled);
      persistCurrentSession({ shuffle: enabled });
    },
    [persistCurrentSession],
  );

  const toggleShuffle = useCallback(() => {
    setShuffleState((prev) => {
      const next = !prev;
      try { TrackPlayer.setShuffleEnabled(next); } catch { /* ignore */ }
      settingsStore.set('shuffle', next);
      persistCurrentSession({ shuffle: next });
      return next;
    });
  }, [persistCurrentSession]);

  const setPlaybackRate = useCallback((rate: number) => {
    try { TrackPlayer.setPlaybackSpeed(rate); } catch { /* player not ready; applied on boot */ }
    setPlaybackRateState(rate);
    settingsStore.set('playbackRate', rate);
  }, []);

  useEffect(() => {
    if (coldStartRestoredRef.current) return;
    const lookup = displayTracksById.size > 0 ? displayTracksById : tracksById;
    if (lookup.size === 0) {
      if (!library.scanning && library.lastScanAt !== null) {
        coldStartRestoredRef.current = true;
        clearPlaybackSession(settingsStore);
      }
      return;
    }

    let cancelled = false;
    ensurePlayer()
      .then(() => {
        if (cancelled || coldStartRestoredRef.current) return;
        coldStartRestoredRef.current = true;
        setReady(true);
        try {
          TrackPlayer.setPlaybackSpeed(settingsStore.getNumber('playbackRate') ?? 1);
        } catch { /* ignore */ }

        try {
          const existingNativeQueue = TrackPlayer.getQueue();
          if (existingNativeQueue.length > 0) {
            refreshQueue();
            const active = TrackPlayer.getActiveMediaItem();
            if (active?.mediaId) {
              previousMediaIdRef.current = active.mediaId;
              setSelectedId(active.mediaId);
            }
            return;
          }

          const persisted = loadPlaybackSession(settingsStore);
          const resolved = resolvePlaybackSession(persisted, lookup);
          if (!resolved) {
            refreshQueue();
            return;
          }

          const items = resolved.queueTracks.map(mediaItemFor);
          previousMediaIdRef.current = resolved.activeTrack.id;
          restoredPositionRef.current = resolved.positionSeconds;
          setRestoredPosition(resolved.positionSeconds);
          setSelectedId(resolved.activeTrack.id);
          setQueueItems(items.map(entryFromMediaItem));
          setQueueIndex(resolved.activeIndex);
          setRepeatModeState(resolved.repeatMode as RepeatMode);
          setShuffleState(resolved.shuffle);
          settingsStore.set('repeatMode', resolved.repeatMode);
          settingsStore.set('shuffle', resolved.shuffle);
          settingsStore.set('queueIds', JSON.stringify(resolved.queueIds));

          TrackPlayer.setMediaItems(items, resolved.activeIndex);
          TrackPlayer.setRepeatMode(resolved.repeatMode as RepeatMode);
          TrackPlayer.setShuffleEnabled(resolved.shuffle);
          TrackPlayer.pause();
          if (resolved.positionSeconds > 0) {
            TrackPlayer.seekTo(resolved.positionSeconds);
          }

          savePlaybackSession(settingsStore, {
            activeTrackId: resolved.activeTrack.id,
            queueIds: resolved.queueIds,
            queueIndex: resolved.activeIndex,
            positionSeconds: resolved.positionSeconds,
            shuffle: resolved.shuffle,
            repeatMode: resolved.repeatMode,
          });
        } catch {
          // Cold-start session restore is best-effort and must never crash startup.
        }
      })
      .catch((bootError) => {
        if (cancelled) return;
        setError(messageFor(bootError));
      });
    return () => {
      cancelled = true;
    };
  }, [displayTracksById, library.lastScanAt, library.scanning, refreshQueue, tracksById]);

  useEffect(() => {
    const sub = TrackPlayer.addEventListener(Event.MediaItemTransition, () => {
      refreshQueue();
      try {
        const current = TrackPlayer.getActiveMediaItem();
        if (current?.mediaId) {
          const isSameRestoredTrack = previousMediaIdRef.current === current.mediaId;
          previousMediaIdRef.current = current.mediaId;
          setSelectedId(current.mediaId);
          recordRecent(current.mediaId);
          if (!isSameRestoredTrack) {
            restoredPositionRef.current = 0;
            setRestoredPosition(0);
            persistCurrentSession({ activeTrackId: current.mediaId, positionSeconds: 0 });
          } else if (restoredPositionRef.current > 0 && !TrackPlayer.isPlaying()) {
            TrackPlayer.seekTo(restoredPositionRef.current);
          }
        }
      } catch {
        // ignore
      }
    });
    return () => { try { sub.remove(); } catch { /* ignore */ } };
  }, [persistCurrentSession, recordRecent, refreshQueue]);

  useEffect(() => {
    if (!playing) {
      persistCurrentSession();
      void endSession();
      return;
    }
    if (activeTrack) {
      void beginSession(activeTrack);
    }
  }, [activeTrack, beginSession, endSession, persistCurrentSession, playing]);

  useEffect(() => {
    const errorSubscription = watchPlaybackError((message) => {
      setError(message);
      // Persist for the Diagnostics error log; never await/thow from here.
      void logError('playback', message, activeTrackIdRef.current);
    });
    return () => {
      errorSubscription.remove();
    };
  }, []);

  const value = useMemo<PlayerContextValue>(
    () => ({
      ready,
      error,
      dismissError: () => setError(null),
      activeTrack,
      palette,
      isPlaying: playing,
      playTrack,
      togglePlayback,
      pausePlayback,
      next,
      previous,
      seekTo,
      queueItems,
      queueIndex,
      playNext,
      addToQueue,
      removeQueueItem,
      moveQueueItem,
      clearQueue,
      playQueueItem,
      repeatMode,
      cycleRepeat,
      shuffle,
      toggleShuffle,
      setShuffle,
      playbackRate,
      setPlaybackRate,
    }),
    [
      ready,
      error,
      activeTrack,
      palette,
      playing,
      playTrack,
      togglePlayback,
      pausePlayback,
      next,
      previous,
      seekTo,
      queueItems,
      queueIndex,
      playNext,
      addToQueue,
      removeQueueItem,
      moveQueueItem,
      clearQueue,
      playQueueItem,
      repeatMode,
      cycleRepeat,
      shuffle,
      toggleShuffle,
      setShuffle,
      playbackRate,
      setPlaybackRate,
    ],
  );

  return (
    <PlayerContext.Provider value={value}>
      <PlaybackProgressProvider
        fallbackDuration={activeTrack?.duration ?? 0}
        restoredPosition={restoredPosition}
      >
        {children}
      </PlaybackProgressProvider>
    </PlayerContext.Provider>
  );
}

export function usePlayer() {
  const context = useContext(PlayerContext);
  if (!context) throw new Error('usePlayer must be used within PlayerProvider');
  return context;
}

export function usePlayerProgress() {
  const context = useContext(PlaybackProgressContext);
  if (!context) throw new Error('usePlayerProgress must be used within PlayerProvider');
  return context;
}
