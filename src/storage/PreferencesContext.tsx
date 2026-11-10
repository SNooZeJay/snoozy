import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import * as Haptics from 'expo-haptics';

import {
  clearPreferences,
  loadPreferences,
  persistPreferences,
  type Preferences,
} from './preferences';

type PreferencesContextValue = {
  preferences: Preferences;
  setHaptics: (enabled: boolean) => void;
  setNotificationsAsked: (asked: boolean) => void;
  resetPreferences: () => void;
  tapFeedback: (kind?: 'selection' | 'light' | 'success') => void;
};

const PreferencesContext = createContext<PreferencesContextValue | null>(null);

function initialPreferences(): Preferences {
  return loadPreferences();
}

export function PreferencesProvider({ children }: { children: ReactNode }) {
  const [preferences, setPreferences] = useState<Preferences>(initialPreferences);

  const update = useCallback(
    (updater: (current: Preferences) => Preferences) => {
      setPreferences((current) => {
        const next = updater(current);
        persistPreferences(next);
        return next;
      });
    },
    [],
  );

  const setHaptics = useCallback(
    (enabled: boolean) => update((current) => ({ ...current, haptics: enabled })),
    [update],
  );

  const setNotificationsAsked = useCallback(
    (asked: boolean) => update((current) => ({ ...current, notificationsAsked: asked })),
    [update],
  );

  const resetPreferences = useCallback(() => {
    clearPreferences();
    const next: Preferences = {
      haptics: true,
      notificationsAsked: false,
    };
    setPreferences(next);
    persistPreferences(next);
  }, []);

  const tapFeedback = useCallback(
    (kind: 'selection' | 'light' | 'success' = 'selection') => {
      if (!preferences.haptics) return;
      try {
        if (kind === 'success') {
          void Haptics.notificationAsync(
            Haptics.NotificationFeedbackType.Success,
          ).catch(() => undefined);
        } else {
          void Haptics.impactAsync(
            kind === 'selection'
              ? Haptics.ImpactFeedbackStyle.Soft
              : Haptics.ImpactFeedbackStyle.Light,
          ).catch(() => undefined);
        }
      } catch {
        // Haptics are a courtesy, never a requirement.
      }
    },
    [preferences.haptics],
  );

  const value = useMemo<PreferencesContextValue>(
    () => ({
      preferences,
      setHaptics,
      setNotificationsAsked,
      resetPreferences,
      tapFeedback,
    }),
    [
      preferences,
      setHaptics,
      setNotificationsAsked,
      resetPreferences,
      tapFeedback,
    ],
  );

  return (
    <PreferencesContext.Provider value={value}>
      {children}
    </PreferencesContext.Provider>
  );
}

export function usePreferences(): PreferencesContextValue {
  const context = useContext(PreferencesContext);
  if (!context) {
    throw new Error('usePreferences must be used inside PreferencesProvider');
  }
  return context;
}
