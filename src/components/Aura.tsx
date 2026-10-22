import { useEffect } from 'react';
import {
  StyleSheet,
  View,
} from 'react-native';
import {
  BlurMask,
  Canvas,
  Circle,
  Group,
} from '@shopify/react-native-skia';
import Animated, {
  Easing,
  cancelAnimation,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';

type AuraProps = {
  color: string;
  active: boolean;
  size: number;
};

export function Aura({ color, active, size }: AuraProps) {
  const breath = useSharedValue(0);

  useEffect(() => {
    if (active) {
      breath.value = withRepeat(
        withTiming(1, {
          duration: 5200,
          easing: Easing.inOut(Easing.sin),
        }),
        -1,
        true,
      );
    } else {
      cancelAnimation(breath);
      breath.value = withTiming(0, { duration: 500 });
    }
    return () => cancelAnimation(breath);
  }, [active, breath]);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: 0.96 + breath.value * 0.08 }],
    opacity: 0.7 + breath.value * 0.3,
  }));

  return (
    <Animated.View
      pointerEvents="none"
      style={[styles.wrap, { width: size, height: size }, animatedStyle]}
    >
      <Canvas style={styles.canvas}>
        <Group>
          <Circle
            cx={size / 2}
            cy={size / 2}
            r={size * 0.43}
            color={color}
            opacity={0.26}
          >
            <BlurMask blur={size * 0.16} style="normal" />
          </Circle>
          <Circle
            cx={size / 2}
            cy={size / 2}
            r={size * 0.47}
            color={color}
            opacity={0.12}
          >
            <BlurMask blur={size * 0.08} style="normal" />
          </Circle>
        </Group>
      </Canvas>
      <View
        style={[
          styles.ring,
          {
            width: size * 0.94,
            height: size * 0.94,
            borderRadius: size / 2,
            borderColor: color,
          },
        ]}
      />
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    position: 'absolute',
    alignItems: 'center',
    justifyContent: 'center',
  },
  canvas: {
    flex: 1,
    width: '100%',
    height: '100%',
  },
  ring: {
    position: 'absolute',
    borderWidth: StyleSheet.hairlineWidth,
    opacity: 0.18,
  },
});
