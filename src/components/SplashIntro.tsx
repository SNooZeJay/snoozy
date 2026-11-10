import { useEffect } from 'react';
import { StyleSheet } from 'react-native';
import Animated, {
  Easing,
  runOnJS,
  useAnimatedStyle,
  useSharedValue,
  withTiming,
} from 'react-native-reanimated';

import { motion, useTheme } from '../theme';
import { SnoozyBrandIcon } from './SnoozyBrandIcon';

type SplashIntroProps = {
  onDone: () => void;
};

/**
 * Bridges the native splash into the first app frame. The native splash keeps
 * showing the mark while fonts load; this overlay renders the same mark at the
 * same 152px size, settles it (a small rise, so the handoff has motion instead
 * of a still image), then fades away so the home screen is revealed without a
 * blank frame or a second, differently-sized logo.
 */
export function SplashIntro({ onDone }: SplashIntroProps) {
  const { palette, reducedMotion } = useTheme();
  const opacity = useSharedValue(1);
  const settle = useSharedValue(reducedMotion ? 0 : 1);

  useEffect(() => {
    const delay = reducedMotion ? 220 : motion.durations.splash;
    const fade = reducedMotion ? 140 : 320;
    if (!reducedMotion) {
      settle.value = withTiming(0, {
        duration: motion.durations.extraLong,
        easing: Easing.out(Easing.cubic),
      });
    }
    const timer = setTimeout(() => {
      opacity.value = withTiming(0, { duration: fade }, (finished) => {
        if (finished) runOnJS(onDone)();
      });
    }, delay);
    return () => clearTimeout(timer);
  }, [onDone, opacity, reducedMotion, settle]);

  const fadeStyle = useAnimatedStyle(() => ({ opacity: opacity.value }));
  const markStyle = useAnimatedStyle(() => ({
    transform: [
      { translateY: settle.value * 12 },
      { scale: 1 + settle.value * 0.04 },
    ],
  }));

  return (
    <Animated.View
      pointerEvents="auto"
      style={[styles.overlay, { backgroundColor: palette.background }, fadeStyle]}
    >
      <Animated.View style={[styles.logo, markStyle]}>
        <SnoozyBrandIcon size={152} />
      </Animated.View>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  overlay: {
    position: 'absolute',
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
    zIndex: 200,
    elevation: 200,
    alignItems: 'center',
    justifyContent: 'center',
  },
  logo: {
    width: 152,
    height: 152,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
