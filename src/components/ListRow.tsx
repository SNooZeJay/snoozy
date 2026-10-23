import type { ReactNode } from 'react';
import {
  Pressable,
  StyleSheet,
  View,
  type AccessibilityRole,
  type AccessibilityState,
} from 'react-native';

import { radii, spacing, useTheme } from '../theme';
import { AppText } from './AppText';

type ListRowProps = {
  leading?: ReactNode;
  title: string;
  subtitle?: string;
  subtitleColor?: string;
  trailing?: ReactNode;
  onPress?: () => void;
  accessibilityLabel: string;
  accessibilityHint?: string;
  accessibilityRole?: AccessibilityRole;
  accessibilityState?: AccessibilityState;
};

/**
 * The compact row used by every list surface. It owns the 48dp rhythm and
 * leaves artwork, icons, and controls to the leading/trailing slots.
 */
export function ListRow({
  leading,
  title,
  subtitle,
  subtitleColor,
  trailing,
  onPress,
  accessibilityLabel,
  accessibilityHint,
  accessibilityRole,
  accessibilityState,
}: ListRowProps) {
  const { palette } = useTheme();

  const content = (
    <>
      {leading ? <View style={styles.leading}>{leading}</View> : null}
      <View style={styles.copy}>
        <AppText variant="label" color={palette.ink} numberOfLines={1}>
          {title}
        </AppText>
        {subtitle ? (
          <AppText variant="micro" color={subtitleColor ?? palette.inkMuted} numberOfLines={1}>
            {subtitle}
          </AppText>
        ) : null}
      </View>
      {trailing ? <View style={styles.trailing}>{trailing}</View> : null}
    </>
  );

  if (!onPress) {
    return <View style={styles.row}>{content}</View>;
  }

  return (
    <Pressable
      accessibilityRole={accessibilityRole ?? 'button'}
      accessibilityLabel={accessibilityLabel}
      accessibilityHint={accessibilityHint}
      accessibilityState={accessibilityState}
      onPress={onPress}
      style={({ pressed }) => [styles.row, { opacity: pressed ? 0.68 : 1 }]}
    >
      {content}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: {
    minHeight: 48,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
    borderRadius: radii.md,
  },
  leading: {
    width: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  copy: {
    flex: 1,
    gap: 1,
  },
  trailing: {
    minWidth: 44,
    alignItems: 'flex-end',
    justifyContent: 'center',
  },
});
