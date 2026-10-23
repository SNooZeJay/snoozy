import Feather from '@expo/vector-icons/Feather';
import {
  Pressable,
  StyleSheet,
  View,
} from 'react-native';

import { spacing, useTheme } from '../theme';
import { AppText } from './AppText';

type SectionHeaderProps = {
  label: string;
  actionLabel?: string;
  onAction?: () => void;
};

/**
 * A small overline label for a run of rows. The action is deliberately quiet;
 * page-level actions belong in ScreenHeader.
 */
export function SectionHeader({
  label,
  actionLabel,
  onAction,
}: SectionHeaderProps) {
  const { palette } = useTheme();

  return (
    <View style={styles.row}>
      <AppText variant="overline" color={palette.inkFaint} style={styles.label}>
        {label}
      </AppText>
      {actionLabel && onAction ? (
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={actionLabel}
          onPress={onAction}
          hitSlop={8}
          style={({ pressed }) => [styles.action, { opacity: pressed ? 0.62 : 1 }]}
        >
          <AppText variant="label" color={palette.inkMuted}>
            {actionLabel}
          </AppText>
          <Feather name="arrow-right" size={14} color={palette.inkMuted} />
        </Pressable>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: spacing.md,
    paddingHorizontal: spacing.screen,
    minHeight: 24,
  },
  label: {
    flex: 1,
  },
  action: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    minHeight: 32,
    paddingLeft: spacing.md,
  },
});
