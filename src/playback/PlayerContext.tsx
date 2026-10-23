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
  playTrack: (track: Track, queue?: Track[]) => Promise<void>;
  togglePlayback: () => Promise<void>;
  pausePlayback: () => void;
  next: () => Promise<void>;
  previous: () => Promise<void>;
  seekTo: (seconds: number) => void;
  repeatMode: RepeatMode;
  cycleRepeat: () => void;
  shuffle: boolean;
  toggleShuffle: () => void;
  sleepMinutes: number | null;
  sleepEndOfTrack: boolean;
  startSleepTimer: (minutes: number) => void;
  startSleepEndOfTrack: () => void;
  cancelSleepTimer: () => void;
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
}: {
  children: ReactNode;
  fallbackDuration: number;
}) {
  const nativeProgress = useProgress(1);
  const value = useMemo<PlaybackProgressValue>(
    () => ({
      progress: nativeProgress.position,
      duration: nativeProgress.duration || fallbackDuration,
    }),
    [fallbackDuration, nativeProgress.duration, nativeProgress.position],
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
  const [repeatMode, setRepeatModeState] = useState<RepeatMode>(() => (settingsStore.getString('repeatMode') as any) || RepeatMode.Off);
  const [shuffle, setShuffleState] = useState<boolean>(() => settingsStore.getBoolean('shuffle') ?? false);
  const [sleepMinutes, setSleepMinutes] = useState<number | null>(null);
  const [sleepEndOfTrack, setSleepEndOfTrack] = useState<boolean>(false);
  const [playbackRate, setPlaybackRateState] = useState<number>(() => settingsStore.getNumber('playbackRate') ?? 1);
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
      if (!current) return;
      try {
        const pos = TrackPlayer.getProgress().position * 1000;
        if (pos > current.maxPosition) current.maxPosition = pos;
      } catch {
        // The player can be between tracks; skip this sample.
      }
    }, 1000);
    return () => clearInterval(interval);
  }, [playing]);

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
    async (track: Track, queue: Track[] = displayTracks) => {
      setError(null);
      recordRecent(track.id);
      setSelectedId(track.id);
      try {
        await ensurePlayer();
        const items = queue.map((item) => ({
          mediaId: item.id,
          url: item.uri,
          title: item.title,
          artist: item.artist,
          albumTitle: item.album,
          duration: item.duration,
          artworkUrl: item.artwork ?? undefined,
        }));
        const startIndex = Math.max(0, items.findIndex((item) => item.mediaId === track.id));
        TrackPlayer.setMediaItems(items, startIndex);
        TrackPlayer.setRepeatMode(repeatMode);
        TrackPlayer.play();
        await askForNotifications();
        setReady(true);
      } catch (playError) {
        setError(messageFor(playError));
      }
    },
    [askForNotifications, displayTracks, recordRecent, repeatMode],
  );

  const togglePlayback = useCallback(async () => {
    setError(null);
    try {
      await ensurePlayer();
      if (TrackPlayer.isPlaying()) TrackPlayer.pause();
      else TrackPlayer.play();
      await askForNotifications();
      setReady(true);
    } catch (playError) {
      setError(messageFor(playError));
    }
  }, [askForNotifications]);

  const pausePlayback = useCallback(() => {
    try {
      TrackPlayer.pause();
    } catch (pauseError) {
      setError(messageFor(pauseError));
    }
  }, []);

  const next = useCallback(async () => {
    try {
      await ensurePlayer();
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

  const seekTo = useCallback((seconds: number) => {
    try {
      TrackPlayer.seekTo(Math.max(0, seconds));
    } catch (seekError) {
      setError(messageFor(seekError));
    }
  }, []);

  const cycleRepeat = useCallback(() => {
    setRepeatModeState((prev) => {
      const next =
        prev === RepeatMode.Off ? RepeatMode.All :
        prev === RepeatMode.All ? RepeatMode.One : RepeatMode.Off;
      try { TrackPlayer.setRepeatMode(next); } catch { /* ignore */ }
      settingsStore.set('repeatMode', next);
      return next;
    });
  }, []);

  const toggleShuffle = useCallback(() => {
    setShuffleState((prev) => {
      const next = !prev;
      settingsStore.set('shuffle', next);
      return next;
    });
  }, []);

  const startSleepTimer = useCallback((minutes: number) => {
    try {
      TrackPlayer.sleepAfterTime(minutes * 60, { fadeOutSeconds: 20 });
      setSleepMinutes(minutes);
      setSleepEndOfTrack(false);
    } catch { /* ignore */ }
  }, []);

  const startSleepEndOfTrack = useCallback(() => {
    setSleepEndOfTrack(true);
    setSleepMinutes(null);
  }, []);

  const cancelSleepTimer = useCallback(() => {
    try { TrackPlayer.cancelSleepTimer(); } catch { /* ignore */ }
    setSleepMinutes(null);
    setSleepEndOfTrack(false);
  }, []);

  const setPlaybackRate = useCallback((rate: number) => {
    // RNTP V5 does not expose setRate on TrackPlayer; speed control is disabled.
    setPlaybackRateState(rate);
    settingsStore.set('playbackRate', rate);
  }, []);

  useEffect(() => {
    let cancelled = false;
    ensurePlayer()
      .then(() => {
        if (cancelled) return;
        setReady(true);
      })
      .catch((bootError) => {
        if (cancelled) return;
        setError(messageFor(bootError));
      });
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    const sub = TrackPlayer.addEventListener(Event.SleepTimerTriggered as any, () => {
      setSleepMinutes(null);
      setSleepEndOfTrack(false);
    });
    return () => { try { sub.remove(); } catch { /* ignore */ } };
  }, []);

  useEffect(() => {
    if (!playing) {
      void endSession();
      return;
    }
    if (activeTrack) {
      void beginSession(activeTrack);
    }
  }, [activeTrack, beginSession, endSession, playing]);

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
      repeatMode,
      cycleRepeat,
      shuffle,
      toggleShuffle,
      sleepMinutes,
      sleepEndOfTrack,
      startSleepTimer,
      startSleepEndOfTrack,
      cancelSleepTimer,
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
      repeatMode,
      cycleRepeat,
      shuffle,
      toggleShuffle,
      sleepMinutes,
      sleepEndOfTrack,
      startSleepTimer,
      startSleepEndOfTrack,
      cancelSleepTimer,
      playbackRate,
      setPlaybackRate,
    ],
  );

  return (
    <PlayerContext.Provider value={value}>
      <PlaybackProgressProvider fallbackDuration={activeTrack?.duration ?? 0}>
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
