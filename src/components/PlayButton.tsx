import Feather from '@expo/vector-icons/Feather';
import {
  Pressable,
  StyleSheet,
  View,
} from 'react-native';

import { colors, shadows } from '../theme';

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
  const backgroundColor =
    tone === 'accent'
      ? accentColor
      : tone === 'ink'
        ? colors.ink
        : 'rgba(7, 17, 13, 0.56)';
  const iconColor = tone === 'glass' ? colors.ink : accentInk;

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label ?? (playing ? 'Pause' : 'Play')}
      accessibilityState={{ selected: playing }}
      onPress={onPress}
      hitSlop={8}
      style={({ pressed }) => [
        styles.button,
        shadows.floating,
        {
          width: size,
          height: size,
          borderRadius: size / 2,
          backgroundColor,
          opacity: pressed ? 0.82 : 1,
          transform: [{ scale: pressed ? 0.96 : 1 }],
        },
        tone === 'glass' && styles.glass,
      ]}
    >
      <View pointerEvents="none" style={playing ? styles.pauseIcon : styles.playIcon}>
        <Feather
          name={playing ? 'pause' : 'play'}
          size={Math.round(size * 0.4)}
          color={iconColor}
        />
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {
    alignItems: 'center',
    justifyContent: 'center',
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
