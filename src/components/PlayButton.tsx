import Feather from '@expo/vector-icons/Feather';
import { LinearGradient } from 'expo-linear-gradient';
import {
  StyleSheet,
  View,
} from 'react-native';

import { colors, glass, shadows, useTheme } from '../theme';
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
  accentColor = colors.accent,
  accentInk = colors.accentInk,
}: PlayButtonProps) {
  const { reducedMotion } = useTheme();
  const backgroundColor =
    tone === 'accent'
      ? accentColor
      : tone === 'ink'
        ? colors.ink
        : 'rgba(7, 17, 13, 0.56)';
  const iconColor = tone === 'glass' ? colors.ink : accentInk;

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
      <View pointerEvents="none" style={playing ? styles.pauseIcon : styles.playIcon}>
        <Feather
          name={playing ? 'pause' : 'play'}
          size={Math.round(size * 0.4)}
          color={iconColor}
        />
      </View>
    </ScalePressable>
  );
}

const styles = StyleSheet.create({
  button: {
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.28)',
    overflow: 'hidden',
  },
  glass: {
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(243, 240, 228, 0.28)',
  },
  playIcon: {
    marginLeft: 3,
  },
  pauseIcon: {
    marginLeft: 0,
  },
});
