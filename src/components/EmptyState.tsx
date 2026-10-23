import {
  Pressable,
  StyleSheet,
  View,
} from 'react-native';

import { radii, spacing, useTheme } from '../theme';
import { AppText } from './AppText';
import { DottedNote } from './Thumb';

type EmptyStateProps = {
  title: string;
  message: string;
  actionLabel?: string;
  onAction?: () => void;
  compact?: boolean;
};

export function EmptyState({
  title,
  message,
  actionLabel,
  onAction,
  compact = false,
}: EmptyStateProps) {
  const { palette } = useTheme();
  const noteSize = compact ? 48 : 64;

  return (
    <View style={[styles.wrap, compact && styles.compact]}>
      <DottedNote size={noteSize} />
      <View style={styles.copy}>
        <AppText variant="heading" style={styles.title}>{title}</AppText>
        <AppText variant="body" color={palette.inkMuted} style={styles.message}>
          {message}
        </AppText>
      </View>
      {actionLabel && onAction ? (
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={actionLabel}
          onPress={onAction}
          style={({ pressed }) => [
            styles.action,
            { backgroundColor: palette.accent, opacity: pressed ? 0.8 : 1 },
          ]}
        >
          <AppText variant="label" color={palette.accentInk}>{actionLabel}</AppText>
        </Pressable>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: spacing.xl,
    paddingVertical: spacing.xxxl,
    gap: spacing.lg,
  },
  compact: {
    paddingVertical: spacing.xl,
    gap: spacing.md,
  },
  copy: {
    alignItems: 'center',
    gap: spacing.xs,
    maxWidth: 300,
  },
  title: {
    textAlign: 'center',
  },
  message: {
    textAlign: 'center',
  },
  action: {
    minHeight: 48,
    paddingHorizontal: spacing.xl,
    borderRadius: radii.pill,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
