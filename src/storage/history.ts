import { openDatabaseAsync, type SQLiteDatabase } from 'expo-sqlite';

export type ListeningSession = {
  id: number;
  soundId: string;
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

export async function startListeningSession(soundId: string): Promise<number | null> {
  try {
    const db = await getDatabase();
    const result = await db.runAsync(
      'INSERT INTO listening_sessions (sound_id, started_at, duration_seconds) VALUES (?, ?, 0)',
      soundId,
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
    // A lost history row is better than a broken night.
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
      soundId: row.sound_id,
      startedAt: row.started_at,
      endedAt: row.ended_at,
      durationSeconds: row.duration_seconds,
    }));
  } catch {
    return [];
  }
}

export type NightSummary = {
  sessions: number;
  minutes: number;
  lastStartedAt: number | null;
};

export async function getNightSummary(days = 7): Promise<NightSummary> {
  try {
    const db = await getDatabase();
    const since = Date.now() - days * 24 * 60 * 60 * 1000;
    const row = await db.getFirstAsync<{
      sessions: number;
      seconds: number | null;
      last_started_at: number | null;
    }>(
      `SELECT
        COUNT(*) AS sessions,
        SUM(duration_seconds) AS seconds,
        MAX(started_at) AS last_started_at
       FROM listening_sessions
       WHERE started_at >= ?`,
      since,
    );
    return {
      sessions: row?.sessions ?? 0,
      minutes: Math.round((row?.seconds ?? 0) / 60),
      lastStartedAt: row?.last_started_at ?? null,
    };
  } catch {
    return { sessions: 0, minutes: 0, lastStartedAt: null };
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
