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
import { AppState } from 'react-native';
import * as MediaLibrary from 'expo-media-library/legacy';
import * as DocumentPicker from 'expo-document-picker';
import * as FileSystem from 'expo-file-system/legacy';
import { createMMKV } from 'react-native-mmkv';
import { useFavorites } from './FavoritesContext';
import { clearPlayHistory } from './playHistory';
import { clearListeningHistory } from './history';

import type { Album, AlbumSort, LibraryTab, Playlist, SongSort, Track } from '../types/music';
import { albumKeyFor, buildAlbums } from './albumGrouping';
import {
  artworkCacheKey,
  mapWithConcurrency,
  persistMetadataCache,
  pruneMetadataCache,
  readAudioMetadata,
  resolveAlbumArtwork,
} from './audioMetadata';
import { getAllTrackOverrides } from './metadata';
import { libraryFingerprint } from './libraryFingerprint';
import { genresOf, recentlyAdded } from './libraryStats';
import { moveItem } from '../playback/queue';

const AUDIO_PERMISSIONS: MediaLibrary.GranularPermission[] = ['audio'];

type MusicLibraryValue = {
  permission: MediaLibrary.PermissionStatus | null;
  permissionCanAskAgain: boolean;
  scanError: string | null;
  lastScanAt: number | null;
  tracks: Track[];
  albums: Album[];
  artists: string[];
  genres: string[];
  recentlyAddedAlbums: Album[];
  playlists: Playlist[];
  favorites: Set<string>;
  recents: string[];
  query: string;
  tab: LibraryTab;
  songSort: SongSort;
  albumSort: AlbumSort;
  scanning: boolean;
  requestAccess: () => Promise<void>;
  scan: () => Promise<void>;
  importFiles: () => Promise<void>;
  setQuery: (value: string) => void;
  setTab: (value: LibraryTab) => void;
  setSongSort: (value: SongSort) => void;
  setAlbumSort: (value: AlbumSort) => void;
  toggleFavorite: (trackId: string) => void;
  recordRecent: (trackId: string) => void;
  clearRecentHistory: () => void;
  createPlaylist: (name: string) => string;
  renamePlaylist: (playlistId: string, name: string) => void;
  deletePlaylist: (playlistId: string) => void;
  addToPlaylist: (playlistId: string, trackId: string) => void;
  removeFromPlaylist: (playlistId: string, trackId: string) => void;
  movePlaylistTrack: (playlistId: string, from: number, to: number) => void;
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
const SCANNED_KEY = 'scannedSnapshot';
const SONG_SORT_KEY = 'songSort';
const ALBUM_SORT_KEY = 'albumSort';

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

function assetFingerprint(assets: MediaLibrary.Asset[]): string {
  const latest = assets.reduce(
    (newest, asset) => Math.max(newest, asset.modificationTime ?? 0),
    0,
  );
  return libraryFingerprint(assets.length, latest);
}

function trackFromAsset(
  asset: MediaLibrary.Asset,
  albumTitle: string,
  metadata: Awaited<ReturnType<typeof readAudioMetadata>>,
): Track {
  const fallbackTitle = asset.filename
    .replace(/\.[^.]+$/, '')
    .replace(/^\d{1,3}[\s._-]+/, '')
    .replace(/[_-]+/g, ' ')
    .trim();
  return {
    id: asset.id,
    title: metadata?.title || fallbackTitle || 'Untitled track',
    artist: metadata?.artist || 'Unknown artist',
    album: metadata?.album || albumTitle || 'Unknown album',
    albumArtist: metadata?.albumArtist ?? null,
    year: metadata?.year ?? null,
    genre: metadata?.genre ?? null,
    trackNumber: metadata?.trackNumber ?? null,
    discNumber: metadata?.discNumber ?? null,
    uri: asset.uri,
    duration: metadata?.duration ?? Math.max(0, asset.duration || 0),
    artwork: null,
    addedAt: asset.creationTime ?? asset.modificationTime ?? 0,
  };
}

export function MusicLibraryProvider({ children }: { children: ReactNode }) {
  const favoritesCtx = useFavorites();
  const [permission, setPermission] = useState<MediaLibrary.PermissionStatus | null>(null);
  const [permissionCanAskAgain, setPermissionCanAskAgain] = useState(true);
  const [scanError, setScanError] = useState<string | null>(null);
  const [lastScanAt, setLastScanAt] = useState<number | null>(null);
  // Last completed scan, so cold start shows the library immediately while a
  // background rescan verifies it.
  const [scannedTracks, setScannedTracksState] = useState<Track[]>(() => readJson<Track[]>(SCANNED_KEY, []));
  const setScannedTracks = useCallback((next: Track[]) => {
    setScannedTracksState(next);
    try { writeJson(SCANNED_KEY, next); } catch { /* cache only */ }
  }, []);
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
  const [tab, setTab] = useState<LibraryTab>('songs');
  const [songSort, setSongSortState] = useState<SongSort>(
    () => (store.getString(SONG_SORT_KEY) as SongSort | undefined) || 'title',
  );
  const [albumSort, setAlbumSortState] = useState<AlbumSort>(
    () => (store.getString(ALBUM_SORT_KEY) as AlbumSort | undefined) || 'title',
  );
  const setSongSort = useCallback((next: SongSort) => {
    setSongSortState(next);
    try { store.set(SONG_SORT_KEY, next); } catch { /* ignore */ }
  }, []);
  const setAlbumSort = useCallback((next: AlbumSort) => {
    setAlbumSortState(next);
    try { store.set(ALBUM_SORT_KEY, next); } catch { /* ignore */ }
  }, []);
  const [scanning, setScanning] = useState(false);
  const scanningRef = useRef(false);
  const pendingScanRef = useRef(false);
  const scanTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const scanInternalRef = useRef<() => Promise<void>>(async () => {});
  const libraryFingerprintRef = useRef<string | null>(null);

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
      for (const [index, asset] of result.assets.entries()) {
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

        const id = `imported-${Date.now()}-${index}-${Math.random().toString(36).slice(2, 8)}`;
        const modified = Date.now();
        const metadata = await readAudioMetadata(
          { id, uri, filename: asset.name, duration: 0, modificationTime: modified },
          'Imported',
        );
        const albumKey = albumKeyFor({
          album: metadata?.album ?? 'Imported',
          albumArtist: metadata?.albumArtist ?? metadata?.artist ?? 'Imported',
          artist: metadata?.artist ?? 'Imported',
          uri,
        });
        const artwork = await resolveAlbumArtwork(
          uri,
          artworkCacheKey(albumKey, uri, modified),
        );

        next.push({
          id,
          title: metadata?.title || asset.name.replace(/\.[^.]+$/, '').trim() || 'Imported track',
          artist: metadata?.artist ?? 'Imported',
          album: metadata?.album ?? 'Imported',
          albumArtist: metadata?.albumArtist ?? null,
          year: metadata?.year ?? null,
          genre: metadata?.genre ?? null,
          trackNumber: metadata?.trackNumber ?? null,
          discNumber: metadata?.discNumber ?? null,
          uri,
          duration: metadata?.duration ?? 0,
          artwork,
          addedAt: modified,
        });
      }
      persistImported(next);
      persistMetadataCache();
    } catch (error) {
      setScanError(
        error instanceof Error ? error.message : 'Could not import audio files.',
      );
    }
  }, [importedTracks, persistImported]);

  const scanInternal = useCallback(async () => {
    if (scanningRef.current) {
      pendingScanRef.current = true;
      return;
    }
    if (scanTimerRef.current) {
      clearTimeout(scanTimerRef.current);
      scanTimerRef.current = null;
    }
    scanningRef.current = true;
    setScanning(true);
    setScanError(null);
    try {
      const currentPermission = await MediaLibrary.getPermissionsAsync(false, AUDIO_PERMISSIONS);
      setPermission(currentPermission.status);
      setPermissionCanAskAgain(currentPermission.canAskAgain);
      if (currentPermission.status !== 'granted') {
        return;
      }

      const assets: MediaLibrary.Asset[] = [];
      let after: string | undefined;
      do {
        const page = await MediaLibrary.getAssetsAsync({
          mediaType: 'audio',
          first: 500,
          after,
          sortBy: MediaLibrary.SortBy.default,
        });
        assets.push(...page.assets);
        after = page.hasNextPage ? page.endCursor : undefined;
      } while (after);

      // Resolve the MediaStore album titles once, keyed by album ID. The old
      // per-asset lookup treated the ID as a title and frequently fell back to
      // "Unknown album" even when the file had a complete album tag.
      const albumTitles = new Map<string, string>();
      try {
        const albums = await MediaLibrary.getAlbumsAsync({ includeSmartAlbums: false });
        for (const album of albums) albumTitles.set(album.id, album.title);
      } catch {
        // Embedded album tags are the primary source; this is only a fallback.
      }

      const collected = await mapWithConcurrency(assets, 4, async (asset) => {
        const albumTitle = asset.albumId ? albumTitles.get(asset.albumId) ?? '' : '';
        const metadata = await readAudioMetadata(
          {
            id: asset.id,
            uri: asset.uri,
            filename: asset.filename,
            duration: Math.max(0, asset.duration || 0),
            modificationTime: asset.modificationTime ?? 0,
          },
          albumTitle,
        );
        return trackFromAsset(asset, albumTitle, metadata);
      });

      // One cover extraction per album, then share the cached file across its
      // tracks. This avoids decoding the same embedded image on every scan.
      const albumsByKey = new Map<string, Track[]>();
      for (const track of collected) {
        const key = albumKeyFor(track);
        const group = albumsByKey.get(key);
        if (group) group.push(track);
        else albumsByKey.set(key, [track]);
      }
      const assetsById = new Map(assets.map((asset) => [asset.id, asset]));
      await mapWithConcurrency(Array.from(albumsByKey.entries()), 2, async ([key, group]) => {
        // Most albums carry the cover on every track, but try a few tracks in
        // case the first file was saved without embedded art.
        for (const candidate of group.slice(0, 3)) {
          const source = assetsById.get(candidate.id);
          const artwork = await resolveAlbumArtwork(
            candidate.uri,
            artworkCacheKey(key, candidate.uri, source?.modificationTime ?? 0),
          );
          if (!artwork) continue;
          for (const track of group) track.artwork = artwork;
          return;
        }
      });

      pruneMetadataCache(new Set(assets.map((asset) => asset.id)));
      persistMetadataCache();
      libraryFingerprintRef.current = assetFingerprint(assets);
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
      scanningRef.current = false;
      setScanning(false);
      if (pendingScanRef.current) {
        pendingScanRef.current = false;
        scanTimerRef.current = setTimeout(() => {
          void scanInternalRef.current();
        }, 700);
      }
    }
  }, [setScannedTracks]);
  useEffect(() => {
    scanInternalRef.current = scanInternal;
  }, [scanInternal]);

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

  // MediaLibrary's legacy listener only observes images and videos on Android,
  // so poll a cheap MediaStore fingerprint while the app is in the foreground.
  // A multi-file copy produces one debounced rebuild.
  useEffect(() => {
    let disposed = false;
    let checking = false;
    let resumeTimer: ReturnType<typeof setTimeout> | null = null;

    const schedule = (delay: number) => {
      if (scanTimerRef.current) clearTimeout(scanTimerRef.current);
      scanTimerRef.current = setTimeout(() => {
        scanTimerRef.current = null;
        void scanInternal();
      }, delay);
    };

    const checkForChanges = async () => {
      if (disposed || checking || scanningRef.current) return;
      if (AppState.currentState !== 'active') return;
      checking = true;
      try {
        const current = await MediaLibrary.getPermissionsAsync(false, AUDIO_PERMISSIONS);
        if (current.status !== 'granted') return;
        const page = await MediaLibrary.getAssetsAsync({
          mediaType: 'audio',
          first: 1,
          sortBy: MediaLibrary.SortBy.modificationTime,
        });
        const next = libraryFingerprint(
          page.totalCount,
          page.assets[0]?.modificationTime ?? 0,
        );
        if (libraryFingerprintRef.current !== null && libraryFingerprintRef.current !== next) {
          schedule(1200);
        }
      } catch {
        // MediaStore can be busy during a copy; the next tick retries.
      } finally {
        checking = false;
      }
    };

    const poll = setInterval(() => {
      void checkForChanges();
    }, 4000);

    const appStateSubscription = AppState.addEventListener('change', (state) => {
      if (state !== 'active') return;
      if (resumeTimer) clearTimeout(resumeTimer);
      resumeTimer = setTimeout(() => {
        resumeTimer = null;
        void checkForChanges();
      }, 500);
    });

    return () => {
      disposed = true;
      clearInterval(poll);
      if (resumeTimer) clearTimeout(resumeTimer);
      appStateSubscription.remove();
      if (scanTimerRef.current) {
        clearTimeout(scanTimerRef.current);
        scanTimerRef.current = null;
      }
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
    void clearListeningHistory().catch(() => undefined);
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

  const renamePlaylist = useCallback(
    (playlistId: string, name: string) => {
      const trimmed = name.trim();
      if (!trimmed) return;
      persistPlaylists(
        playlistsRef.current.map((playlist) =>
          playlist.id === playlistId
            ? { ...playlist, name: trimmed, updatedAt: Date.now() }
            : playlist,
        ),
      );
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

  const movePlaylistTrack = useCallback(
    (playlistId: string, from: number, to: number) => {
      persistPlaylists(
        playlistsRef.current.map((playlist) =>
          playlist.id === playlistId
            ? { ...playlist, trackIds: moveItem(playlist.trackIds, from, to) }
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
        // Keep the last rendered library until overrides have been reapplied,
        // so a scan never flashes raw tags over the user's edits.
        setDisplayTracks((current) => (current.length === 0 ? tracks : current));
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
                  albumArtist: override.albumArtist ?? track.albumArtist ?? null,
                  year: override.year ?? track.year ?? null,
                  genre: override.genre ?? track.genre ?? null,
                  trackNumber: override.trackNumber ?? track.trackNumber ?? null,
                  discNumber: track.discNumber ?? null,
                  artwork: override.artworkPath ?? track.artwork ?? null,
                }
              : track;
          }),
        );
      } catch {
        // Fall back to the raw scan if the metadata store is unavailable.
        if (!cancelled) setDisplayTracks(tracks);
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

  const sortedDisplayTracks = useMemo(() => {
    const copy = [...displayTracks];
    copy.sort((a, b) => {
      if (songSort === 'artist') {
        return a.artist.localeCompare(b.artist) || a.album.localeCompare(b.album) || a.title.localeCompare(b.title);
      }
      if (songSort === 'album') {
        return a.album.localeCompare(b.album) || a.title.localeCompare(b.title);
      }
      if (songSort === 'duration') {
        return (b.duration || 0) - (a.duration || 0) || a.title.localeCompare(b.title);
      }
      return a.title.localeCompare(b.title);
    });
    return copy;
  }, [displayTracks, songSort]);

  const filteredTracks = useMemo(() => {
    const normalized = query.trim().toLowerCase();
    if (!normalized) return sortedDisplayTracks;
    return sortedDisplayTracks.filter((track) =>
      `${track.title} ${track.artist} ${track.album}`.toLowerCase().includes(normalized),
    );
  }, [sortedDisplayTracks, query]);

  const albums = useMemo(() => {
    const raw = buildAlbums(displayTracks);
    raw.sort((a, b) => {
      if (albumSort === 'artist') {
        return a.artist.localeCompare(b.artist) || a.title.localeCompare(b.title);
      }
      if (albumSort === 'year') {
        const ya = Number.parseInt(a.year ?? '', 10) || 0;
        const yb = Number.parseInt(b.year ?? '', 10) || 0;
        return yb - ya || a.title.localeCompare(b.title);
      }
      if (albumSort === 'tracks') {
        return b.trackIds.length - a.trackIds.length || a.title.localeCompare(b.title);
      }
      return a.title.localeCompare(b.title);
    });
    return raw;
  }, [displayTracks, albumSort]);
  const artists = useMemo(
    () => [...new Set(displayTracks.map((track) => track.artist))].sort(),
    [displayTracks],
  );
  const genres = useMemo(() => genresOf(displayTracks), [displayTracks]);
  const recentlyAddedAlbums = useMemo(() => recentlyAdded(albums, 12), [albums]);

  const value = useMemo<MusicLibraryValue>(
    () => ({
      permission,
      permissionCanAskAgain,
      scanError,
      lastScanAt,
      tracks,
      albums,
      artists,
      genres,
      recentlyAddedAlbums,
      playlists,
      favorites,
      recents,
      query,
      tab,
      songSort,
      albumSort,
      scanning,
      requestAccess,
      scan,
      importFiles,
      setQuery,
      setTab,
      setSongSort,
      setAlbumSort,
      toggleFavorite,
      recordRecent,
      clearRecentHistory,
      createPlaylist,
      renamePlaylist,
      deletePlaylist,
      addToPlaylist,
      removeFromPlaylist,
      movePlaylistTrack,
      tracksById,
      filteredTracks,
      displayTracks: sortedDisplayTracks,
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
      genres,
      recentlyAddedAlbums,
      playlists,
      favorites,
      recents,
      query,
      tab,
      songSort,
      albumSort,
      scanning,
      requestAccess,
      scan,
      importFiles,
      setSongSort,
      setAlbumSort,
      toggleFavorite,
      recordRecent,
      clearRecentHistory,
      createPlaylist,
      renamePlaylist,
      deletePlaylist,
      addToPlaylist,
      removeFromPlaylist,
      movePlaylistTrack,
      tracksById,
      filteredTracks,
      sortedDisplayTracks,
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