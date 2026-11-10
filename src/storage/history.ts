import { openDatabaseAsync, type SQLiteDatabase } from 'expo-sqlite';

export type ListeningSession = {
  id: number;
  trackId: string;
  startedAt: number;
  endedAt: number | null;
  durationSeconds: number;
};

type SessionRow = {
  id: number;
  sound_id: string;
  started_at: number;
  ended_at: number | null;
  duration_seconds: number;
};

let databasePromise: Promise<SQLiteDatabase> | null = null;

async function getDatabase(): Promise<SQLiteDatabase> {
  if (!databasePromise) {
    databasePromise = openDatabaseAsync('snoozy.db')
      .then(async (db) => {
        await db.execAsync(`
          PRAGMA journal_mode = WAL;
          CREATE TABLE IF NOT EXISTS listening_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sound_id TEXT NOT NULL,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            duration_seconds INTEGER NOT NULL DEFAULT 0
          );
          CREATE INDEX IF NOT EXISTS listening_sessions_started_at
            ON listening_sessions (started_at);
        `);
        return db;
      })
      .catch((error) => {
        databasePromise = null;
        throw error;
      });
  }
  return databasePromise;
}

export async function startListeningSession(trackId: string): Promise<number | null> {
  try {
    const db = await getDatabase();
    const result = await db.runAsync(
      'INSERT INTO listening_sessions (sound_id, started_at, duration_seconds) VALUES (?, ?, 0)',
      trackId,
      Date.now(),
    );
    return result.lastInsertRowId;
  } catch {
    return null;
  }
}

export async function finishListeningSession(
  sessionId: number | null,
  durationSeconds: number,
): Promise<void> {
  if (!sessionId) return;
  try {
    const db = await getDatabase();
    const safeDuration = Math.max(0, Math.round(durationSeconds));
    await db.runAsync(
      'UPDATE listening_sessions SET ended_at = ?, duration_seconds = ? WHERE id = ?',
      Date.now(),
      safeDuration,
      sessionId,
    );
  } catch {
    // A lost history row must never interrupt playback.
  }
}

export async function getRecentSessions(limit = 12): Promise<ListeningSession[]> {
  try {
    const db = await getDatabase();
    const rows = await db.getAllAsync<SessionRow>(
      `SELECT id, sound_id, started_at, ended_at, duration_seconds
       FROM listening_sessions
       ORDER BY started_at DESC
       LIMIT ?`,
      limit,
    );
    return rows.map((row) => ({
      id: row.id,
      trackId: row.sound_id,
      startedAt: row.started_at,
      endedAt: row.ended_at,
      durationSeconds: row.duration_seconds,
    }));
  } catch {
    return [];
  }
}

export async function clearListeningHistory(): Promise<void> {
  try {
    const db = await getDatabase();
    await db.execAsync('DELETE FROM listening_sessions;');
  } catch {
    // No-op.
  }
}
