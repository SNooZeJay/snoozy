import type { ReactNode } from 'react';
import {
  StyleSheet,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';

import { useTheme } from '../theme';

type ListGroupProps = {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
};

/**
 * Glasmio inset grouped card: flat #1C1C1E surface, 26pt continuous corners,
 * no glossy gradient. Glass is reserved for floating chrome.
 */
export function ListGroup({ children, style }: ListGroupProps) {
  const { palette } = useTheme();

  return (
    <View
      style={[
        styles.group,
        { backgroundColor: palette.surface, borderColor: palette.border },
        style,
      ]}
    >
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  group: {
    marginHorizontal: 16,
    borderRadius: 26,
    borderWidth: StyleSheet.hairlineWidth,
    overflow: 'hidden',
  },
});
