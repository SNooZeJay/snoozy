import type { ReactNode } from 'react';
import Animated, { FadeIn, FadeInDown } from 'react-native-reanimated';
import type { StyleProp, ViewStyle } from 'react-native';

import { motion, useTheme } from '../theme';

type SheetPanelProps = {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
};

/**
 * Shared bottom-sheet panel entrance for the fade-backdrop modals. Slide
 * modals already animate natively and should not double-animate.
 */
export function SheetPanel({ children, style }: SheetPanelProps) {
  const { reducedMotion } = useTheme();

  return (
    <Animated.View
      entering={
        reducedMotion
          ? FadeIn.duration(motion.durations.short)
          : FadeInDown.duration(motion.durations.medium)
      }
      style={style}
    >
      {children}
    </Animated.View>
  );
}
