import type { ComponentProps, ReactNode } from 'react';
import {
  Pressable,
  StyleSheet,
  View,
  type AccessibilityRole,
  type AccessibilityState,
} from 'react-native';
import Animated from 'react-native-reanimated';

import { radii, spacing, useTheme } from '../theme';
import { AppText } from './AppText';

type ListRowProps = {
  leading?: ReactNode;
  title: string;
  titleColor?: string;
  subtitle?: string;
  subtitleColor?: string;
  trailing?: ReactNode;
  onPress?: () => void;
  accessibilityLabel: string;
  accessibilityHint?: string;
  accessibilityRole?: AccessibilityRole;
  accessibilityState?: AccessibilityState;
  /** List entrance; see `staggerEnter`. Omitted rows render static. */
  entering?: ComponentProps<typeof Animated.View>['entering'];
};

/**
 * Cupertino inset-grouped list row: 52pt comfortable height, SF-style bold
 * primary label + clean secondary label, and quick opacity compression on tap
 * (no Android ripple).
 */
export function ListRow({
  leading,
  title,
  titleColor,
  subtitle,
  subtitleColor,
  trailing,
  onPress,
  accessibilityLabel,
  accessibilityHint,
  accessibilityRole,
  accessibilityState,
  entering,
}: ListRowProps) {
  const { palette } = useTheme();

  const content = (
    <>
      {leading ? <View style={styles.leading}>{leading}</View> : null}
      <View style={styles.copy}>
        <AppText variant="body" color={titleColor ?? palette.ink} numberOfLines={1}>
          {title}
        </AppText>
        {subtitle ? (
          <AppText variant="micro" color={subtitleColor ?? palette.inkMuted} numberOfLines={1}>
            {subtitle}
          </AppText>
        ) : null}
      </View>
      {trailing ? <View style={styles.trailing}>{trailing}</View> : null}
      <View
        pointerEvents="none"
        style={[
          styles.separator,
          {
            left: leading ? 60 : spacing.lg,
            backgroundColor: palette.border,
          },
        ]}
      />
    </>
  );

  const row = onPress ? (
    <Pressable
      accessibilityRole={accessibilityRole ?? 'button'}
      accessibilityLabel={accessibilityLabel}
      accessibilityHint={accessibilityHint}
      accessibilityState={accessibilityState}
      onPress={onPress}
      style={({ pressed }) => [
        styles.row,
        pressed && {
          opacity: 0.72,
          backgroundColor: palette.surfaceRaised,
        },
      ]}
    >
      {content}
    </Pressable>
  ) : (
    <View style={styles.row}>{content}</View>
  );

  if (!entering) return row;
  return <Animated.View entering={entering}>{row}</Animated.View>;
}

const styles = StyleSheet.create({
  row: {
    minHeight: 52,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: radii.md,
  },
  leading: {
    width: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  copy: {
    flex: 1,
    gap: 2,
  },
  trailing: {
    minWidth: 44,
    alignItems: 'flex-end',
    justifyContent: 'center',
  },
  separator: {
    position: 'absolute',
    right: 0,
    bottom: 0,
    height: StyleSheet.hairlineWidth,
  },
});
