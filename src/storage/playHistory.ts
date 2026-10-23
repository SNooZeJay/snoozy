import * as SQLite from 'expo-sqlite';

export type PlayHistoryEntry = {
  trackId: string;
  playedAt: number;
  durationListenedMs: number;
};

let db: SQLite.SQLiteDatabase | null = null;
async function getDb(): Promise<SQLite.SQLiteDatabase> {
  if (db) return db;
  db = await SQLite.openDatabaseAsync('snoozy_playhistory.db');
  await db.execAsync(`
    CREATE TABLE IF NOT EXISTS play_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      track_id TEXT NOT NULL,
      played_at INTEGER NOT NULL,
      duration_listened_ms INTEGER NOT NULL
    );
  `);
  return db;
}

export async function recordPlay(trackId: string, durationListenedMs: number): Promise<void> {
  if (durationListenedMs < 0) return;
  try {
    const d = await getDb();
    await d.runAsync(
      'INSERT INTO play_history (track_id, played_at, duration_listened_ms) VALUES (?, ?, ?)',
      trackId, Date.now(), Math.round(durationListenedMs),
    );
  } catch {
    // Play history is diagnostic; never surface a storage failure as playback.
  }
}

export async function getRecentDistinct(limit = 20): Promise<PlayHistoryEntry[]> {
  const d = await getDb();
  const rows = await d.getAllAsync<any>(
    `SELECT track_id, played_at, duration_listened_ms FROM play_history
     WHERE id IN (SELECT MAX(id) FROM play_history GROUP BY track_id)
     ORDER BY played_at DESC LIMIT ?`,
    limit,
  );
  return rows.map((r) => ({ trackId: r.track_id, playedAt: r.played_at, durationListenedMs: r.duration_listened_ms }));
}

export async function clearPlayHistory(): Promise<void> {
  const d = await getDb();
  await d.runAsync('DELETE FROM play_history');
}

export async function getAllPlayHistory(): Promise<PlayHistoryEntry[]> {
  const d = await getDb();
  const rows = await d.getAllAsync<any>('SELECT track_id, played_at, duration_listened_ms FROM play_history ORDER BY played_at DESC');
  return rows.map((r) => ({ trackId: r.track_id, playedAt: r.played_at, durationListenedMs: r.duration_listened_ms }));
}