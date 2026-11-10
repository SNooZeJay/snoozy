import Feather from '@expo/vector-icons/Feather';
import { LinearGradient } from 'expo-linear-gradient';
import {
  StyleSheet,
} from 'react-native';
import Animated, { FadeIn } from 'react-native-reanimated';

import { motion, shadows, useTheme, withAlpha } from '../theme';
import { ScalePressable } from './ScalePressable';

type PlayButtonProps = {
  playing: boolean;
  onPress: () => void;
  size?: number;
  label?: string;
  tone?: 'accent' | 'ink' | 'glass';
  accentColor?: string;
  accentInk?: string;
};

export function PlayButton({
  playing,
  onPress,
  size = 64,
  label,
  tone = 'accent',
  accentColor,
  accentInk,
}: PlayButtonProps) {
  const { palette, glass, reducedMotion } = useTheme();
  const resolvedAccent = accentColor ?? palette.accent;
  const resolvedInk = accentInk ?? palette.accentInk;
  const backgroundColor =
    tone === 'accent'
      ? resolvedAccent
      : tone === 'ink'
        ? palette.ink
        : glass.buttonTint;
  const iconColor = tone === 'glass' ? palette.ink : resolvedInk;
  const borderColor =
    tone === 'accent'
      ? withAlpha(palette.white, 0.28)
      : tone === 'ink'
        ? palette.borderStrong
        : glass.edgeStrong;

  return (
    <ScalePressable
      accessibilityRole="button"
      accessibilityLabel={label ?? (playing ? 'Pause' : 'Play')}
      accessibilityState={{ selected: playing }}
      onPress={onPress}
      hitSlop={8}
      reducedMotion={reducedMotion}
      scaleTo={0.96}
      style={[
        styles.button,
        shadows.floating,
        {
          width: size,
          height: size,
          borderRadius: size / 2,
          backgroundColor,
          borderColor,
        },
        tone === 'glass' && styles.glass,
      ]}
    >
      <LinearGradient
        pointerEvents="none"
        colors={[glass.highlight, glass.highlightSoft, 'transparent', glass.highlightEdge]}
        locations={[0, 0.34, 0.74, 1]}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={[StyleSheet.absoluteFill, { borderRadius: size / 2 }]}
      />
      {/* Keyed so the glyph cross-fades instead of snapping on toggle. */}
      <Animated.View
        key={playing ? 'pause' : 'play'}
        pointerEvents="none"
        entering={
          reducedMotion ? undefined : FadeIn.duration(motion.durations.medium)
        }
        style={playing ? styles.pauseIcon : styles.playIcon}
      >
        <Feather
          name={playing ? 'pause' : 'play'}
          size={Math.round(size * 0.4)}
          color={iconColor}
        />
      </Animated.View>
    </ScalePressable>
  );
}

const styles = StyleSheet.create({
  button: {
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    overflow: 'hidden',
  },
  glass: {
    borderWidth: StyleSheet.hairlineWidth,
  },
  playIcon: {
    marginLeft: 3,
  },
  pauseIcon: {
    marginLeft: 0,
  },
});
