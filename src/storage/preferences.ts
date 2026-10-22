import {
  createMMKV,
  type MMKV,
} from 'react-native-mmkv';

export type Preferences = {
  favoriteIds: string[];
  recentIds: string[];
  lastSoundId: string;
  haptics: boolean;
  notificationsAsked: boolean;
};

const STORAGE_ID = 'snoozy.preferences.v1';
const KEYS = {
  favorites: 'favoriteIds',
  recents: 'recentIds',
  lastSound: 'lastSoundId',
  haptics: 'haptics',
  notificationsAsked: 'notificationsAsked',
} as const;

let store: MMKV | null | undefined;

function getStore(): MMKV | null {
  if (store !== undefined) return store;
  try {
    store = createMMKV({ id: STORAGE_ID });
  } catch {
    store = null;
  }
  return store;
}

function readFavorites(): string[] {
  try {
    const raw = getStore()?.getString(KEYS.favorites);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown;
    return Array.isArray(parsed)
      ? parsed.filter((value): value is string => typeof value === 'string').slice(0, 12)
      : [];
  } catch {
    return [];
  }
}

function readRecents(): string[] {
  try {
    const raw = getStore()?.getString(KEYS.recents);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown;
    return Array.isArray(parsed)
      ? parsed.filter((value): value is string => typeof value === 'string').slice(0, 5)
      : [];
  } catch {
    return [];
  }
}

export function loadPreferences(): Preferences {
  const storage = getStore();
  return {
    favoriteIds: readFavorites(),
    recentIds: readRecents(),
    lastSoundId: storage?.getString(KEYS.lastSound) ?? 'rain-on-fir',
    haptics: storage?.getBoolean(KEYS.haptics) ?? true,
    notificationsAsked: storage?.getBoolean(KEYS.notificationsAsked) ?? false,
  };
}

export function persistPreferences(preferences: Preferences): void {
  const storage = getStore();
  if (!storage) return;
  try {
    storage.set(KEYS.favorites, JSON.stringify(preferences.favoriteIds));
    storage.set(KEYS.recents, JSON.stringify(preferences.recentIds));
    storage.set(KEYS.lastSound, preferences.lastSoundId);
    storage.set(KEYS.haptics, preferences.haptics);
    storage.set(KEYS.notificationsAsked, preferences.notificationsAsked);
  } catch {
    // A failed preference write must never stop playback.
  }
}

export function clearPreferences(): void {
  try {
    getStore()?.clearAll();
  } catch {
    // Ignore storage teardown failures.
  }
}

export function storageIsAvailable(): boolean {
  return getStore() !== null;
}
