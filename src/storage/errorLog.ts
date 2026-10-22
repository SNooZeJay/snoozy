import * as SQLite from 'expo-sqlite';

export type ErrorLogEntry = {
  id: number;
  timestamp: number;
  category: string;
  message: string;
  trackId: string | null;
};

let db: SQLite.SQLiteDatabase | null = null;
async function getDb(): Promise<SQLite.SQLiteDatabase> {
  if (db) return db;
  db = await SQLite.openDatabaseAsync('snoozy_errorlog.db');
  await db.execAsync(`
    CREATE TABLE IF NOT EXISTS error_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      timestamp INTEGER NOT NULL,
      category TEXT NOT NULL,
      message TEXT NOT NULL,
      track_id TEXT
    );
  `);
  return db;
}

export async function logError(category: string, message: string, trackId?: string | null): Promise<void> {
  try {
    const d = await getDb();
    await d.runAsync(
      'INSERT INTO error_log (timestamp, category, message, track_id) VALUES (?, ?, ?, ?)',
      Date.now(), category, message.slice(0, 500), trackId ?? null,
    );
    // cap at 500
    await d.runAsync(
      'DELETE FROM error_log WHERE id NOT IN (SELECT id FROM error_log ORDER BY id DESC LIMIT 500)',
    );
  } catch {
    // never throw from logging
  }
}

export async function getErrorLog(): Promise<ErrorLogEntry[]> {
  const d = await getDb();
  const rows = await d.getAllAsync<any>('SELECT * FROM error_log ORDER BY id DESC');
  return rows.map((r) => ({ id: r.id, timestamp: r.timestamp, category: r.category, message: r.message, trackId: r.track_id }));
}

export async function clearErrorLog(): Promise<void> {
  const d = await getDb();
  await d.runAsync('DELETE FROM error_log');
}