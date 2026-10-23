import { useMemo } from 'react';
import {
  StyleSheet,
  type ImageStyle,
  type TextStyle,
  type ViewStyle,
} from 'react-native';

import { useTheme, type AppTheme } from './ThemeContext';

type NamedStyles<T> = {
  [P in keyof T]: ViewStyle | TextStyle | ImageStyle;
};

/**
 * Rebuilds a component's StyleSheet only when the active theme changes.
 * Create the factory at module scope so its identity stays stable.
 */
export function useThemedStyles<T extends NamedStyles<T>>(
  create: (theme: AppTheme) => T,
): T {
  const theme = useTheme();
  return useMemo(() => StyleSheet.create(create(theme)), [create, theme]);
}
