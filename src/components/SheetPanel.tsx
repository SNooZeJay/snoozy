import { type ReactNode } from 'react';
import {
  StyleSheet,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import {
  Gesture,
  GestureDetector,
  GestureHandlerRootView,
} from 'react-native-gesture-handler';
import Animated, {
  FadeIn,
  SlideInDown,
  runOnJS,
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  withTiming,
} from 'react-native-reanimated';

import { shouldDismissSheet } from '../motion/chrome';
import { motion, spacing, useTheme } from '../theme';

type SheetPanelProps = {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
  /** Optional swipe-down dismiss handler; shows the iOS top grabber pill. */
  onDismiss?: () => void;
  /** Show the rounded iOS top grabber handle (defaults to true). */
  showGrabber?: boolean;
};

/**
 * Cupertino modal sheet panel:
 * - Spring-driven slide entrance
 * - Rounded top grabber handle (36x5pt pill) that also carries the dismiss pan
 * - Velocity-aware downward dismissal, so inner scroll views keep their gestures
 */
export function SheetPanel({
  children,
  style,
  onDismiss,
  showGrabber = true,
}: SheetPanelProps) {
  const { palette, reducedMotion } = useTheme();
  const translateY = useSharedValue(0);
  const panelHeight = useSharedValue(0);

  const dismissPan = Gesture.Pan()
    .enabled(Boolean(onDismiss) && !reducedMotion)
    .hitSlop({ top: 0, bottom: spacing.md, left: 60, right: 60 })
    .activeOffsetY(6)
    .failOffsetX([-24, 24])
    .onUpdate((event) => {
      translateY.value = Math.max(0, event.translationY);
    })
    .onEnd((event) => {
      if (onDismiss && shouldDismissSheet(event.translationY, event.velocityY)) {
        translateY.value = withTiming(
          panelHeight.value + 48,
          { duration: 180 },
          (finished) => {
            if (finished) runOnJS(onDismiss)();
          },
        );
        return;
      }
      translateY.value = withSpring(0, motion.springs.standard);
    });

  const dragStyle = useAnimatedStyle(() => ({
    transform: [{ translateY: translateY.value }],
  }));

  const flatStyle = StyleSheet.flatten(style);

  return (
    /* Native Modals open a separate window; they need their own stationary gesture root. */
    <GestureHandlerRootView
      style={[
        styles.gestureRoot,
        flatStyle?.maxHeight !== undefined ? { maxHeight: flatStyle.maxHeight } : null,
      ]}
    >
      <Animated.View
        onLayout={(event) => {
          panelHeight.value = event.nativeEvent.layout.height;
        }}
        entering={
          reducedMotion
            ? FadeIn.duration(motion.durations.short)
            : SlideInDown.springify()
                .damping(motion.springs.standard.damping)
                .stiffness(motion.springs.standard.stiffness)
                .mass(motion.springs.standard.mass)
        }
        style={[style, styles.animatedPanel, dragStyle]}
      >
        {showGrabber ? (
          <GestureDetector gesture={dismissPan}>
            <View style={styles.grabberRow} accessible={false}>
              <View style={[styles.grabber, { backgroundColor: palette.inkFaint }]} />
            </View>
          </GestureDetector>
        ) : null}
        {children}
      </Animated.View>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  gestureRoot: {
    flexGrow: 0,
    flexShrink: 1,
  },
  animatedPanel: {
    flexGrow: 0,
    flexShrink: 1,
    maxHeight: '100%',
  },
  grabberRow: {
    alignItems: 'center',
    paddingTop: spacing.sm,
    paddingBottom: spacing.xs,
  },
  grabber: {
    width: 36,
    height: 5,
    borderRadius: 2.5,
    opacity: 0.55,
  },
});
