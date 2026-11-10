import {
  createMMKV,
  type MMKV,
} from 'react-native-mmkv';

export type Preferences = {
  haptics: boolean;
  notificationsAsked: boolean;
};

const STORAGE_ID = 'snoozy.preferences.v1';
const KEYS = {
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

export function loadPreferences(): Preferences {
  const storage = getStore();
  return {
    haptics: storage?.getBoolean(KEYS.haptics) ?? true,
    notificationsAsked: storage?.getBoolean(KEYS.notificationsAsked) ?? false,
  };
}

export function persistPreferences(preferences: Preferences): void {
  const storage = getStore();
  if (!storage) return;
  try {
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
