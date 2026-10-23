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
import * as MediaLibrary from 'expo-media-library/legacy';
import * as DocumentPicker from 'expo-document-picker';
import * as FileSystem from 'expo-file-system/legacy';
import { createMMKV } from 'react-native-mmkv';
import { useFavorites } from './FavoritesContext';
import { clearPlayHistory } from './playHistory';

import type { Playlist, Track } from '../types/music';
import { getAllTrackOverrides } from './metadata';

const AUDIO_PERMISSIONS: MediaLibrary.GranularPermission[] = ['audio'];

type MusicLibraryValue = {
  permission: MediaLibrary.PermissionStatus | null;
  permissionCanAskAgain: boolean;
  scanError: string | null;
  lastScanAt: number | null;
  tracks: Track[];
  albums: string[];
  artists: string[];
  playlists: Playlist[];
  favorites: Set<string>;
  recents: string[];
  query: string;
  tab: 'songs' | 'albums' | 'artists' | 'playlists' | 'favorites';
  scanning: boolean;
  requestAccess: () => Promise<void>;
  scan: () => Promise<void>;
  importFiles: () => Promise<void>;
  setQuery: (value: string) => void;
  setTab: (value: 'songs' | 'albums' | 'artists' | 'playlists' | 'favorites') => void;
  toggleFavorite: (trackId: string) => void;
  recordRecent: (trackId: string) => void;
  clearRecentHistory: () => void;
  createPlaylist: (name: string) => string;
  deletePlaylist: (playlistId: string) => void;
  addToPlaylist: (playlistId: string, trackId: string) => void;
  removeFromPlaylist: (playlistId: string, trackId: string) => void;
  tracksById: Map<string, Track>;
  filteredTracks: Track[];
  displayTracks: Track[];
  displayTracksById: Map<string, Track>;
  refreshDisplay: () => void;
};

const MusicLibraryContext = createContext<MusicLibraryValue | null>(null);

const store = createMMKV({ id: 'snoozy.music.v1' });
const PLAYLISTS_KEY = 'playlists';
const RECENTS_KEY = 'recents';
const IMPORTED_KEY = 'imported';

function readJson<T>(key: string, fallback: T): T {
  try {
    const raw = store.getString(key);
    return raw ? (JSON.parse(raw) as T) : fallback;
  } catch {
    return fallback;
  }
}

function writeJson(key: string, value: unknown) {
  store.set(key, JSON.stringify(value));
}

function trackFromAsset(asset: MediaLibrary.Asset, albumTitle: string): Track {
  const fallbackTitle = asset.filename.replace(/\.[^.]+$/, '').replace(/[_-]+/g, ' ').trim();
  return {
    id: asset.id,
    title: fallbackTitle || 'Untitled track',
    artist: 'Unknown artist',
    album: albumTitle || 'Unknown album',
    uri: asset.uri,
    duration: Math.max(0, asset.duration || 0),
    artwork: null,
  };
}

export function MusicLibraryProvider({ children }: { children: ReactNode }) {
  const favoritesCtx = useFavorites();
  const [permission, setPermission] = useState<MediaLibrary.PermissionStatus | null>(null);
  const [permissionCanAskAgain, setPermissionCanAskAgain] = useState(true);
  const [scanError, setScanError] = useState<string | null>(null);
  const [lastScanAt, setLastScanAt] = useState<number | null>(null);
  const [scannedTracks, setScannedTracks] = useState<Track[]>([]);
  const [importedTracks, setImportedTracks] = useState<Track[]>(() => readJson<Track[]>(IMPORTED_KEY, []));
  const [playlists, setPlaylists] = useState<Playlist[]>(() => readJson<Playlist[]>(PLAYLISTS_KEY, []));
  const [recents, setRecents] = useState<string[]>(() => readJson<string[]>(RECENTS_KEY, []));
  const favorites = useMemo(() => {
    const ids = new Set<string>();
    const favIdentities = new Set(favoritesCtx.favorites.map((f) => f.identity));
    for (const t of [...scannedTracks, ...importedTracks]) {
      if (favIdentities.has(t.uri)) ids.add(t.id);
    }
    return ids;
  }, [favoritesCtx.favorites, scannedTracks, importedTracks]);
  const [query, setQuery] = useState('');
  const [tab, setTab] = useState<'songs' | 'albums' | 'artists' | 'playlists' | 'favorites'>('songs');
  const [scanning, setScanning] = useState(false);

  // Ref keeps consecutive synchronous playlist mutations consistent
  // (create -> add-to must not read a stale state closure).
  const playlistsRef = useRef(playlists);
  const persistPlaylists = useCallback((next: Playlist[]) => {
    playlistsRef.current = next;
    setPlaylists(next);
    writeJson(PLAYLISTS_KEY, next);
  }, []);

  const persistRecents = useCallback((next: string[]) => {
    setRecents(next);
    writeJson(RECENTS_KEY, next);
  }, []);

  const persistImported = useCallback((next: Track[]) => {
    setImportedTracks(next);
    writeJson(IMPORTED_KEY, next);
  }, []);

  const importFiles = useCallback(async () => {
    try {
      const result = await DocumentPicker.getDocumentAsync({
        type: 'audio/*',
        multiple: true,
        copyToCacheDirectory: true,
      });
      if (result.canceled || !result.assets?.length) return;
      const next = [...importedTracks];
      for (const asset of result.assets) {
        let uri = asset.uri;
        try {
          if (FileSystem.documentDirectory) {
            const dir = `${FileSystem.documentDirectory}Music/`;
            await FileSystem.makeDirectoryAsync(dir, { intermediates: true });
            const target = `${dir}${asset.name}`;
            await FileSystem.copyAsync({ from: uri, to: target });
            uri = target;
          }
        } catch {
          // Fall back to the picker URI if copying is unavailable.
        }
        next.push({
          id: `imported-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
          title: asset.name.replace(/\.[^.]+$/, '').trim() || 'Imported track',
          artist: 'Imported',
          album: 'Imported',
          uri,
          duration: 0,
          artwork: null,
        });
      }
      persistImported(next);
    } catch (error) {
      setScanError(
        error instanceof Error ? error.message : 'Could not import audio files.',
      );
    }
  }, [importedTracks, persistImported]);

  const scanInternal = useCallback(async () => {
    setScanning(true);
    setScanError(null);
    try {
      const currentPermission = await MediaLibrary.getPermissionsAsync(false, AUDIO_PERMISSIONS);
      setPermission(currentPermission.status);
      setPermissionCanAskAgain(currentPermission.canAskAgain);
      if (currentPermission.status !== 'granted') {
        return;
      }

      const collected: Track[] = [];
      // Album titles are shared across pages; resolve each album once per scan.
      const albumCache = new Map<string, string>();
      let after: string | undefined;
      do {
        const page = await MediaLibrary.getAssetsAsync({
          mediaType: 'audio',
          first: 500,
          after,
          sortBy: MediaLibrary.SortBy.default,
        });
        for (const asset of page.assets) {
          let albumTitle = 'Unknown album';
          if (asset.albumId) {
            if (!albumCache.has(asset.albumId)) {
              try {
                const album = await MediaLibrary.getAlbumAsync(asset.albumId);
                albumCache.set(asset.albumId, album.title || 'Unknown album');
              } catch {
                albumCache.set(asset.albumId, 'Unknown album');
              }
            }
            albumTitle = albumCache.get(asset.albumId) || albumTitle;
          }
          collected.push(trackFromAsset(asset, albumTitle));
        }
        after = page.hasNextPage ? page.endCursor : undefined;
      } while (after);

      collected.sort((a, b) => a.title.localeCompare(b.title));
      setScannedTracks(collected);
      setLastScanAt(Date.now());
    } catch (error) {
      setScanError(
        error instanceof Error
          ? error.message
          : 'Could not read the music library on this device.',
      );
    } finally {
      setScanning(false);
    }
  }, []);

  const requestAccess = useCallback(async () => {
    try {
      const result = await MediaLibrary.requestPermissionsAsync(false, AUDIO_PERMISSIONS);
      setPermission(result.status);
      setPermissionCanAskAgain(result.canAskAgain);
      if (result.status === 'granted') {
        await scanInternal();
      }
    } catch (error) {
      setScanError(
        error instanceof Error
          ? error.message
          : 'Could not request music access on this device.',
      );
    }
  }, [scanInternal]);
  const scan = useCallback(async () => {
    await scanInternal();
  }, [scanInternal]);

  useEffect(() => {
    let mounted = true;
    void (async () => {
      try {
        const current = await MediaLibrary.getPermissionsAsync(false, AUDIO_PERMISSIONS);
        if (!mounted) return;
        setPermission(current.status);
        setPermissionCanAskAgain(current.canAskAgain);
        if (current.status === 'granted') {
          await scanInternal();
        }
      } catch (error) {
        if (!mounted) return;
        setScanError(
          error instanceof Error
            ? error.message
            : 'Could not check music access on this device.',
        );
      }
    })();
    return () => {
      mounted = false;
    };
  }, [scanInternal]);

  // toggleFavorite defined after tracksById below.

  const recordRecent = useCallback(
    (trackId: string) => {
      const next = [trackId, ...recents.filter((id) => id !== trackId)].slice(0, 30);
      persistRecents(next);
    },
    [recents, persistRecents],
  );

  // v1.7 audit row 13: Home "Recently played" gets a Clear. Poured-off wrapper
  // around the two existing stores — the visible MMKV list and the play history.
  const clearRecentHistory = useCallback(() => {
    persistRecents([]);
    void clearPlayHistory().catch(() => undefined);
  }, [persistRecents]);

  const createPlaylist = useCallback(
    (name: string) => {
      const trimmed = name.trim();
      if (!trimmed) return '';
      const id = `playlist-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
      const playlist: Playlist = {
        id,
        name: trimmed,
        trackIds: [],
        createdAt: Date.now(),
      };
      persistPlaylists([playlist, ...playlistsRef.current]);
      return id;
    },
    [persistPlaylists],
  );

  const deletePlaylist = useCallback(
    (playlistId: string) => {
      persistPlaylists(playlistsRef.current.filter((playlist) => playlist.id !== playlistId));
    },
    [persistPlaylists],
  );

  const addToPlaylist = useCallback(
    (playlistId: string, trackId: string) => {
      persistPlaylists(
        playlistsRef.current.map((playlist) =>
          playlist.id === playlistId && !playlist.trackIds.includes(trackId)
            ? { ...playlist, trackIds: [...playlist.trackIds, trackId] }
            : playlist,
        ),
      );
    },
    [persistPlaylists],
  );

  const removeFromPlaylist = useCallback(
    (playlistId: string, trackId: string) => {
      persistPlaylists(
        playlistsRef.current.map((playlist) =>
          playlist.id === playlistId
            ? { ...playlist, trackIds: playlist.trackIds.filter((id) => id !== trackId) }
            : playlist,
        ),
      );
    },
    [persistPlaylists],
  );

  const tracks = useMemo(() => {
    const seen = new Set<string>();
    const merged: Track[] = [];
    for (const track of [...importedTracks, ...scannedTracks]) {
      if (seen.has(track.uri)) continue;
      seen.add(track.uri);
      merged.push(track);
    }
    return merged.sort((a, b) => a.title.localeCompare(b.title));
  }, [importedTracks, scannedTracks]);

  const tracksById = useMemo(() => new Map(tracks.map((track) => [track.id, track])), [tracks]);

  // Optional on-device overrides (snoozy_metadata.db) layered onto the raw scan.
  // Every list, the player, and search read displayTracks; toggleFavorite and
  // file-level identity still bind to the raw uri via tracksById.
  const [displayVersion, setDisplayVersion] = useState(0);
  const refreshDisplay = useCallback(() => setDisplayVersion((v) => v + 1), []);
  const [displayTracks, setDisplayTracks] = useState<Track[]>([]);
  const previousTracksRef = useRef<Track[] | null>(null);
  useEffect(() => {
    let cancelled = false;
    const apply = async () => {
      if (tracks.length === 0) {
        previousTracksRef.current = tracks;
        setDisplayTracks([]);
        return;
      }

      // Show the raw scan immediately, then layer metadata overrides in one
      // query. This avoids both a blank library and one SQLite round-trip per
      // track. Overrides are re-applied after an edit (displayVersion) without
      // briefly flashing the raw titles.
      if (previousTracksRef.current !== tracks) {
        previousTracksRef.current = tracks;
        setDisplayTracks(tracks);
      }

      try {
        const overrides = await getAllTrackOverrides();
        if (cancelled) return;
        const byId = new Map(overrides.map((override) => [override.trackId, override]));
        setDisplayTracks(
          tracks.map((track) => {
            const override = byId.get(track.id);
            return override
              ? {
                  ...track,
                  title: override.title ?? track.title,
                  artist: override.artist ?? track.artist,
                  album: override.album ?? track.album,
                  artwork: override.artworkPath ?? track.artwork ?? null,
                }
              : track;
          }),
        );
      } catch {
        // Keep the raw scan if the metadata store is unavailable.
      }
    };
    void apply();
    return () => {
      cancelled = true;
    };
  }, [tracks, displayVersion]);
  const displayTracksById = useMemo(() => new Map(displayTracks.map((track) => [track.id, track])), [displayTracks]);

  const toggleFavorite = useCallback(
    (trackId: string) => {
      const track = tracksById.get(trackId);
      if (!track) return;
      void favoritesCtx.toggleFavorite(track);
    },
    [tracksById, favoritesCtx],
  );

  const filteredTracks = useMemo(() => {
    const normalized = query.trim().toLowerCase();
    if (!normalized) return displayTracks;
    return displayTracks.filter((track) =>
      `${track.title} ${track.artist} ${track.album}`.toLowerCase().includes(normalized),
    );
  }, [displayTracks, query]);

  const albums = useMemo(
    () => [...new Set(displayTracks.map((track) => track.album))].sort(),
    [displayTracks],
  );
  const artists = useMemo(
    () => [...new Set(displayTracks.map((track) => track.artist))].sort(),
    [displayTracks],
  );

  const value = useMemo<MusicLibraryValue>(
    () => ({
      permission,
      permissionCanAskAgain,
      scanError,
      lastScanAt,
      tracks,
      albums,
      artists,
      playlists,
      favorites,
      recents,
      query,
      tab,
      scanning,
      requestAccess,
      scan,
      importFiles,
      setQuery,
      setTab,
      toggleFavorite,
      recordRecent,
      clearRecentHistory,
      createPlaylist,
      deletePlaylist,
      addToPlaylist,
      removeFromPlaylist,
      tracksById,
      filteredTracks,
      displayTracks,
      displayTracksById,
      refreshDisplay,
    }),
    [
      permission,
      permissionCanAskAgain,
      scanError,
      lastScanAt,
      tracks,
      albums,
      artists,
      playlists,
      favorites,
      recents,
      query,
      tab,
      scanning,
      requestAccess,
      scan,
      importFiles,
      toggleFavorite,
      recordRecent,
      clearRecentHistory,
      createPlaylist,
      deletePlaylist,
      addToPlaylist,
      removeFromPlaylist,
      tracksById,
      filteredTracks,
      displayTracks,
      displayTracksById,
      refreshDisplay,
    ],
  );

  return <MusicLibraryContext.Provider value={value}>{children}</MusicLibraryContext.Provider>;
}

export function useMusicLibrary() {
  const context = useContext(MusicLibraryContext);
  if (!context) throw new Error('useMusicLibrary must be used within MusicLibraryProvider');
  return context;
}