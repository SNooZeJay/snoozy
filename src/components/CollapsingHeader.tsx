import { useState, type ReactNode } from 'react';
import { StyleSheet, View } from 'react-native';
import Animated, {
  runOnJS,
  useAnimatedReaction,
  useAnimatedScrollHandler,
  useAnimatedStyle,
  useSharedValue,
  type SharedValue,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { collapseProgress } from '../motion/chrome';
import { tabScrollY } from '../motion/scrollState';
import { spacing, useTheme } from '../theme';
import { AppText } from './AppText';

/**
 * Scroll driver for the compact title bar. The large header stays in the
 * scroll content; this only tracks how far it has travelled.
 */
export function useCollapsingScroll(reportToTabBar = true) {
  const scrollY = useSharedValue(0);
  const onScroll = useAnimatedScrollHandler((event) => {
    scrollY.value = event.contentOffset.y;
    if (reportToTabBar) tabScrollY.value = event.contentOffset.y;
  });

  return { scrollY, onScroll };
}

type CollapsedBarProps = {
  title: string;
  scrollY: SharedValue<number>;
  /** Optional back action for stack screens. */
  left?: ReactNode;
};

/**
 * Fixed inline title that fades in as the large header scrolls away.
 * It is display-only unless a left action is supplied, so it never steals
 * touches from the content while hidden.
 */
export function CollapsedBar({ title, scrollY, left }: CollapsedBarProps) {
  const { dark, palette } = useTheme();
  const insets = useSafeAreaInsets();
  const [active, setActive] = useState(false);

  useAnimatedReaction(
    () => collapseProgress(scrollY.value) > 0.65,
    (compact, previous) => {
      if (compact !== previous) runOnJS(setActive)(compact);
    },
    [],
  );

  const animated = useAnimatedStyle(() => {
    const progress = collapseProgress(scrollY.value);
    return {
      opacity: progress,
      transform: [{ translateY: (1 - progress) * -6 }],
    };
  });

  return (
    <Animated.View
      pointerEvents={active ? 'box-none' : 'none'}
      importantForAccessibility={active ? 'auto' : 'no-hide-descendants'}
      accessibilityElementsHidden={!active}
      style={[
        styles.bar,
        {
          paddingTop: insets.top,
          height: insets.top + 48,
          backgroundColor: dark ? 'rgba(12, 12, 14, 0.88)' : 'rgba(248, 248, 250, 0.92)',
          borderBottomColor: dark ? 'rgba(255, 255, 255, 0.12)' : 'rgba(0, 0, 0, 0.1)',
        },
        animated,
      ]}
    >
      {left ? (
        <View style={[styles.left, { top: insets.top }]} pointerEvents="box-none">
          {left}
        </View>
      ) : null}
      <AppText variant="label" numberOfLines={1} style={[styles.title, { color: palette.ink }]}>
        {title}
      </AppText>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  bar: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 48,
    alignItems: 'center',
    justifyContent: 'center',
    borderBottomWidth: StyleSheet.hairlineWidth,
    zIndex: 10,
  },
  left: {
    position: 'absolute',
    left: spacing.sm,
    height: 48,
    justifyContent: 'center',
  },
  title: {
    fontSize: 16,
    lineHeight: 21,
    paddingHorizontal: 56,
    textAlign: 'center',
  },
});
