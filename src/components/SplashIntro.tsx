import { useEffect } from 'react';
import { Image, StyleSheet } from 'react-native';
import Animated, {
  runOnJS,
  useAnimatedStyle,
  useSharedValue,
  withTiming,
} from 'react-native-reanimated';

import { colors, motion, useTheme } from '../theme';

type SplashIntroProps = {
  onDone: () => void;
};

/**
 * Bridges the native splash into the first app frame. The native splash keeps
 * showing the S while fonts load; this overlay renders the same S at the same
 * 180px size, then fades away so the home screen is revealed without a blank
 * frame or a second, differently-sized logo.
 */
export function SplashIntro({ onDone }: SplashIntroProps) {
  const { reducedMotion } = useTheme();
  const opacity = useSharedValue(1);

  useEffect(() => {
    const delay = reducedMotion ? 220 : motion.durations.splash;
    const fade = reducedMotion ? 140 : 320;
    const timer = setTimeout(() => {
      opacity.value = withTiming(0, { duration: fade }, (finished) => {
        if (finished) runOnJS(onDone)();
      });
    }, delay);
    return () => clearTimeout(timer);
  }, [onDone, opacity, reducedMotion]);

  const fadeStyle = useAnimatedStyle(() => ({ opacity: opacity.value }));

  return (
    <Animated.View pointerEvents="auto" style={[styles.overlay, fadeStyle]}>
      <Image
        source={require('../../assets/splash-icon.png')}
        style={styles.logo}
        resizeMode="contain"
        accessibilityIgnoresInvertColors
      />
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
    backgroundColor: colors.background,
  },
  logo: {
    width: 180,
    height: 180,
  },
});
