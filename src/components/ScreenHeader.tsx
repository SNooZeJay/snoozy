import type { ReactNode } from 'react';
import {
  StyleSheet,
  View,
} from 'react-native';

import { layout, spacing, useTheme } from '../theme';
import { AppText } from './AppText';

type ScreenHeaderProps = {
  title: string;
  subtitle?: string;
  eyebrow?: string;
  action?: ReactNode;
};

/**
 * One page-header rhythm for every tab: a calm title, optional context above
 * and below, and a single fixed-size action slot.
 */
export function ScreenHeader({
  title,
  subtitle,
  eyebrow,
  action,
}: ScreenHeaderProps) {
  const { palette } = useTheme();

  return (
    <View style={styles.row}>
      <View style={styles.copy}>
        {eyebrow ? (
          <AppText variant="overline" color={palette.inkFaint}>
            {eyebrow}
          </AppText>
        ) : null}
        <AppText variant="title" accessibilityRole="header">
          {title}
        </AppText>
        {subtitle ? (
          <AppText variant="micro" color={palette.inkMuted}>
            {subtitle}
          </AppText>
        ) : null}
      </View>
      {action ? <View style={styles.action}>{action}</View> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    gap: spacing.md,
    paddingHorizontal: layout.screenPadding,
    paddingTop: spacing.sm,
  },
  copy: {
    flex: 1,
    gap: spacing.xs,
  },
  action: {
    minWidth: 44,
    minHeight: 44,
    alignItems: 'flex-end',
    justifyContent: 'center',
  },
});
