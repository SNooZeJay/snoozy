import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import * as SQLite from 'expo-sqlite';

import type { Track } from '../types/music';

export type FavoriteSort = 'recent' | 'title' | 'artist';

export type FavoriteRow = {
  identity: string; // file uri/path
  title: string;
  artist: string;
  album: string;
  duration: number;
  artwork: string | null;
  addedAt: number;
  available: boolean;
};

type FavoritesContextValue = {
  ready: boolean;
  favorites: FavoriteRow[];
  isFavorite: (identity: string) => boolean;
  addFavorite: (track: Track) => Promise<void>;
  removeFavorite: (identity: string) => Promise<void>;
  toggleFavorite: (track: Track) => Promise<boolean>;
  sort: FavoriteSort;
  setSort: (sort: FavoriteSort) => void;
  refresh: () => Promise<void>;
};

const FavoritesContext = createContext<FavoritesContextValue | null>(null);

let db: SQLite.SQLiteDatabase | null = null;
async function getDb(): Promise<SQLite.SQLiteDatabase> {
  if (db) return db;
  db = await SQLite.openDatabaseAsync('snoozy_favorites.db');
  await db.execAsync(
    `CREATE TABLE IF NOT EXISTS favorites (
      identity TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      artist TEXT NOT NULL,
      album TEXT NOT NULL,
      duration REAL NOT NULL,
      artwork TEXT,
      added_at INTEGER NOT NULL
    );`,
  );
  return db;
}

export function FavoritesProvider({ children }: { children: ReactNode }) {
  const [ready, setReady] = useState(false);
  const [rows, setRows] = useState<FavoriteRow[]>([]);
  const [sort, setSortState] = useState<FavoriteSort>('recent');

  const load = useCallback(async () => {
    try {
      const d = await getDb();
      const result = await d.getAllAsync<{
        identity: string; title: string; artist: string; album: string;
        duration: number; artwork: string | null; added_at: number;
      }>('SELECT * FROM favorites');
      setRows(result.map((r) => ({
        identity: r.identity,
        title: r.title,
        artist: r.artist,
        album: r.album,
        duration: r.duration,
        artwork: r.artwork,
        addedAt: r.added_at,
        available: true,
      })));
    } catch {
      setRows([]);
    } finally {
      setReady(true);
    }
  }, []);

  useEffect(() => {
    const handle = setTimeout(() => {
      void load();
    }, 0);
    return () => clearTimeout(handle);
  }, [load]);

  const isFavorite = useCallback(
    (identity: string) => rows.some((r) => r.identity === identity),
    [rows],
  );

  const addFavorite = useCallback(async (track: Track) => {
    const d = await getDb();
    const now = Date.now();
    await d.runAsync(
      `INSERT INTO favorites (identity, title, artist, album, duration, artwork, added_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(identity) DO UPDATE SET title=excluded.title, artist=excluded.artist, album=excluded.album, duration=excluded.duration, artwork=excluded.artwork`,
      track.uri, track.title, track.artist, track.album, track.duration, (track.artwork ?? null) as any, now,
    );
    await load();
  }, [load]);

  const removeFavorite = useCallback(async (identity: string) => {
    const d = await getDb();
    await d.runAsync('DELETE FROM favorites WHERE identity = ?', identity);
    await load();
  }, [load]);

  const toggleFavorite = useCallback(async (track: Track): Promise<boolean> => {
    try {
      if (rows.some((r) => r.identity === track.uri)) {
        await removeFavorite(track.uri);
        return false;
      }
      await addFavorite(track);
      return true;
    } catch {
      // A failed favorites write must not escape into the UI event handler.
      await load();
      return rows.some((r) => r.identity === track.uri);
    }
  }, [addFavorite, load, removeFavorite, rows]);

  const sorted = useMemo(() => {
    const copy = [...rows];
    if (sort === 'title') copy.sort((a, b) => a.title.localeCompare(b.title));
    else if (sort === 'artist') copy.sort((a, b) => a.artist.localeCompare(b.artist));
    else copy.sort((a, b) => b.addedAt - a.addedAt);
    return copy;
  }, [rows, sort]);

  const setSort = useCallback((s: FavoriteSort) => setSortState(s), []);

  const value = useMemo<FavoritesContextValue>(
    () => ({
      ready,
      favorites: sorted,
      isFavorite,
      addFavorite,
      removeFavorite,
      toggleFavorite,
      sort,
      setSort,
      refresh: load,
    }),
    [ready, sorted, isFavorite, addFavorite, removeFavorite, toggleFavorite, sort, setSort, load],
  );

  return <FavoritesContext.Provider value={value}>{children}</FavoritesContext.Provider>;
}

export function useFavorites(): FavoritesContextValue {
  const ctx = useContext(FavoritesContext);
  if (!ctx) throw new Error('useFavorites must be used within FavoritesProvider');
  return ctx;
}