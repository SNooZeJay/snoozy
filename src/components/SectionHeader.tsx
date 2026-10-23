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
  title?: string;
  actionLabel?: string;
  onAction?: () => void;
};

export function SectionHeader({
  label,
  title,
  actionLabel,
  onAction,
}: SectionHeaderProps) {
  const { palette } = useTheme();
  return (
    <View style={styles.row}>
      <View style={styles.copy}>
        <AppText variant="micro" color={palette.inkFaint}>
          {label}
        </AppText>
        {title ? (
          <AppText variant="heading" style={styles.title}>
            {title}
          </AppText>
        ) : null}
      </View>
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
    alignItems: 'flex-end',
    justifyContent: 'space-between',
    gap: spacing.md,
  },
  copy: {
    flex: 1,
    gap: spacing.xs,
  },
  title: {
    marginTop: 2,
  },
  action: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    minHeight: 32,
    paddingLeft: spacing.md,
  },
});
