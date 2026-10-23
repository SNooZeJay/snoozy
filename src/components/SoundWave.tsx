import { useEffect } from 'react';
import {
  StyleSheet,
  View,
} from 'react-native';
import Animated, {
  Easing,
  cancelAnimation,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';

import { useTheme } from '../theme';

type SoundWaveProps = {
  active: boolean;
  color?: string;
  bars?: number;
  height?: number;
  seed?: number;
};

function Bar({
  active,
  index,
  progress,
  color,
  height,
  seed,
}: {
  active: boolean;
  index: number;
  progress: { value: number };
  color: string;
  height: number;
  seed: number;
}) {
  const restHeight = 0.24 + ((seed + index * 7) % 9) * 0.035;

  const animatedStyle = useAnimatedStyle(() => {
    if (!active) {
      return {
        transform: [{ scaleY: restHeight }],
        opacity: 0.42,
      };
    }
    const phase = index * 0.64 + seed * 0.11;
    const wave = Math.sin(progress.value * Math.PI * 2 + phase);
    return {
      transform: [{ scaleY: 0.28 + Math.abs(wave) * 0.72 }],
      opacity: 0.55 + Math.abs(wave) * 0.45,
    };
  }, [active, index, restHeight, seed]);

  return (
    <Animated.View
      style={[
        styles.bar,
        {
          height,
          backgroundColor: color,
          borderRadius: height / 2,
        },
        animatedStyle,
      ]}
    />
  );
}

export function SoundWave({
  active,
  color,
  bars = 18,
  height = 32,
  seed = 1,
}: SoundWaveProps) {
  const { palette } = useTheme();
  const resolvedColor = color ?? palette.accent;
  const progress = useSharedValue(0);

  useEffect(() => {
    if (active) {
      progress.value = 0;
      progress.value = withRepeat(
        withTiming(1, {
          duration: 2600,
          easing: Easing.linear,
        }),
        -1,
        false,
      );
    } else {
      cancelAnimation(progress);
      progress.value = 0;
    }
    return () => cancelAnimation(progress);
  }, [active, progress]);

  return (
    <View
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
      style={[styles.row, { height }]}
    >
      {Array.from({ length: bars }).map((_, index) => (
        <Bar
          key={index}
          active={active}
          index={index}
          progress={progress}
          color={resolvedColor}
          height={height}
          seed={seed}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
  },
  bar: {
    width: 3,
  },
});
