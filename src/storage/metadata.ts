import * as SQLite from 'expo-sqlite';

export type TrackOverride = {
  trackId: string;
  title: string | null;
  artist: string | null;
  album: string | null;
  albumArtist: string | null;
  genre: string | null;
  year: string | null;
  trackNumber: string | null;
  description: string | null;
  artworkPath: string | null;
  updatedAt: number;
};

export type AlbumOverride = {
  albumKey: string;
  title: string | null;
  artist: string | null;
  description: string | null;
  artworkPath: string | null;
  updatedAt: number;
};

export type ArtistOverride = {
  artistKey: string;
  name: string | null;
  description: string | null;
  artworkPath: string | null;
  updatedAt: number;
};

let db: SQLite.SQLiteDatabase | null = null;
async function getDb(): Promise<SQLite.SQLiteDatabase> {
  if (db) return db;
  db = await SQLite.openDatabaseAsync('snoozy_metadata.db');
  await db.execAsync(`
    CREATE TABLE IF NOT EXISTS track_overrides (
      track_id TEXT PRIMARY KEY,
      title TEXT,
      artist TEXT,
      album TEXT,
      album_artist TEXT,
      genre TEXT,
      year TEXT,
      track_number TEXT,
      description TEXT,
      artwork_path TEXT,
      updated_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS album_overrides (
      album_key TEXT PRIMARY KEY,
      title TEXT,
      artist TEXT,
      description TEXT,
      artwork_path TEXT,
      updated_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS artist_overrides (
      artist_key TEXT PRIMARY KEY,
      name TEXT,
      description TEXT,
      artwork_path TEXT,
      updated_at INTEGER NOT NULL
    );
  `);
  return db;
}

export async function getTrackOverride(trackId: string): Promise<TrackOverride | null> {
  const d = await getDb();
  const rows = await d.getAllAsync<any>('SELECT * FROM track_overrides WHERE track_id = ?', trackId);
  if (!rows.length) return null;
  const r = rows[0];
  return {
    trackId: r.track_id, title: r.title, artist: r.artist, album: r.album,
    albumArtist: r.album_artist, genre: r.genre, year: r.year, trackNumber: r.track_number,
    description: r.description, artworkPath: r.artwork_path, updatedAt: r.updated_at,
  };
}

export async function upsertTrackOverride(o: TrackOverride): Promise<void> {
  const d = await getDb();
  await d.runAsync(
    `INSERT INTO track_overrides (track_id, title, artist, album, album_artist, genre, year, track_number, description, artwork_path, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(track_id) DO UPDATE SET
       title=excluded.title, artist=excluded.artist, album=excluded.album, album_artist=excluded.album_artist,
       genre=excluded.genre, year=excluded.year, track_number=excluded.track_number, description=excluded.description,
       artwork_path=excluded.artwork_path, updated_at=excluded.updated_at`,
    o.trackId, o.title, o.artist, o.album, o.albumArtist, o.genre, o.year, o.trackNumber, o.description, o.artworkPath, o.updatedAt,
  );
}

export async function deleteTrackOverride(trackId: string): Promise<void> {
  const d = await getDb();
  await d.runAsync('DELETE FROM track_overrides WHERE track_id = ?', trackId);
}

export async function getAlbumOverride(albumKey: string): Promise<AlbumOverride | null> {
  const d = await getDb();
  const rows = await d.getAllAsync<any>('SELECT * FROM album_overrides WHERE album_key = ?', albumKey);
  if (!rows.length) return null;
  const r = rows[0];
  return { albumKey: r.album_key, title: r.title, artist: r.artist, description: r.description, artworkPath: r.artwork_path, updatedAt: r.updated_at };
}

export async function upsertAlbumOverride(o: AlbumOverride): Promise<void> {
  const d = await getDb();
  await d.runAsync(
    `INSERT INTO album_overrides (album_key, title, artist, description, artwork_path, updated_at)
     VALUES (?, ?, ?, ?, ?, ?)
     ON CONFLICT(album_key) DO UPDATE SET title=excluded.title, artist=excluded.artist, description=excluded.description, artwork_path=excluded.artwork_path, updated_at=excluded.updated_at`,
    o.albumKey, o.title, o.artist, o.description, o.artworkPath, o.updatedAt,
  );
}

export async function deleteAlbumOverride(albumKey: string): Promise<void> {
  const d = await getDb();
  await d.runAsync('DELETE FROM album_overrides WHERE album_key = ?', albumKey);
}

export async function getArtistOverride(artistKey: string): Promise<ArtistOverride | null> {
  const d = await getDb();
  const rows = await d.getAllAsync<any>('SELECT * FROM artist_overrides WHERE artist_key = ?', artistKey);
  if (!rows.length) return null;
  const r = rows[0];
  return { artistKey: r.artist_key, name: r.name, description: r.description, artworkPath: r.artwork_path, updatedAt: r.updated_at };
}

export async function upsertArtistOverride(o: ArtistOverride): Promise<void> {
  const d = await getDb();
  await d.runAsync(
    `INSERT INTO artist_overrides (artist_key, name, description, artwork_path, updated_at)
     VALUES (?, ?, ?, ?, ?)
     ON CONFLICT(artist_key) DO UPDATE SET name=excluded.name, description=excluded.description, artwork_path=excluded.artwork_path, updated_at=excluded.updated_at`,
    o.artistKey, o.name, o.description, o.artworkPath, o.updatedAt,
  );
}

export async function deleteArtistOverride(artistKey: string): Promise<void> {
  const d = await getDb();
  await d.runAsync('DELETE FROM artist_overrides WHERE artist_key = ?', artistKey);
}

export async function getAllAlbumOverrides(): Promise<AlbumOverride[]> {
  const d = await getDb();
  const rows = await d.getAllAsync<any>('SELECT * FROM album_overrides');
  return rows.map((r) => ({ albumKey: r.album_key, title: r.title, artist: r.artist, description: r.description, artworkPath: r.artwork_path, updatedAt: r.updated_at }));
}

export async function getAllArtistOverrides(): Promise<ArtistOverride[]> {
  const d = await getDb();
  const rows = await d.getAllAsync<any>('SELECT * FROM artist_overrides');
  return rows.map((r) => ({ artistKey: r.artist_key, name: r.name, description: r.description, artworkPath: r.artwork_path, updatedAt: r.updated_at }));
}

export async function getAllTrackOverrides(): Promise<TrackOverride[]> {
  const d = await getDb();
  const rows = await d.getAllAsync<any>('SELECT * FROM track_overrides');
  return rows.map((r) => ({
    trackId: r.track_id, title: r.title, artist: r.artist, album: r.album,
    albumArtist: r.album_artist, genre: r.genre, year: r.year, trackNumber: r.track_number,
    description: r.description, artworkPath: r.artwork_path, updatedAt: r.updated_at,
  }));
}