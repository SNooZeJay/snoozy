import { Share } from 'react-native';
import * as FileSystem from 'expo-file-system/legacy';

import { getAllTrackOverrides, getAllAlbumOverrides, getAllArtistOverrides } from './metadata';

// We'll keep backup focused on favorites + playlists + track overrides (album/artist partial).

export type BackupData = {
  schemaVersion: number;
  exportedAt: number;
  favorites: { identity: string; title: string; artist: string; album: string; duration: number; artworkBase64: string | null; addedAt: number }[];
  playlists: any[];
  trackOverrides: any[];
};

const SCHEMA_VERSION = 1;

export async function exportBackup(playlists: any[]): Promise<string> {
  const favDb = await (await import('expo-sqlite')).openDatabaseAsync('snoozy_favorites.db');
  const favRows = await favDb.getAllAsync<any>('SELECT * FROM favorites');
  const favorites = [];
  for (const r of favRows) {
    let b64: string | null = null;
    if (r.artwork) {
      try { b64 = await FileSystem.readAsStringAsync(r.artwork, { encoding: 'base64' }); } catch { b64 = null; }
    }
    favorites.push({ identity: r.identity, title: r.title, artist: r.artist, album: r.album, duration: r.duration, artworkBase64: b64, addedAt: r.added_at });
  }
  const trackOverrides = await getAllTrackOverrides();
  const albumOverrides = await getAllAlbumOverrides();
  const artistOverrides = await getAllArtistOverrides();
  const data: any = {
    schemaVersion: SCHEMA_VERSION,
    exportedAt: Date.now(),
    favorites,
    playlists,
    trackOverrides,
    albumOverrides,
    artistOverrides,
  };
  const dir = `${FileSystem.documentDirectory}backup/`;
  await FileSystem.makeDirectoryAsync(dir, { intermediates: true });
  const file = `${dir}snoozy-backup.json`;
  await FileSystem.writeAsStringAsync(file, JSON.stringify(data));
  return file;
}

export async function shareBackup(file: string): Promise<void> {
  await Share.share({ url: file, title: 'Snoozy backup' });
}

export function validateBackup(raw: any): { ok: boolean; message: string; data?: BackupData } {
  if (!raw || typeof raw !== 'object') return { ok: false, message: 'Not a JSON object' };
  if (raw.schemaVersion !== SCHEMA_VERSION) return { ok: false, message: `Unknown schema version: ${raw.schemaVersion}` };
  if (!Array.isArray(raw.favorites) || !Array.isArray(raw.playlists) || !Array.isArray(raw.trackOverrides)) {
    return { ok: false, message: 'Invalid fields' };
  }
  return { ok: true, message: 'OK', data: raw as BackupData };
}