import Feather from '@expo/vector-icons/Feather';
import { LinearGradient } from 'expo-linear-gradient';
import type { ComponentProps } from 'react';
import {
  StyleSheet,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';

import { colors, glass, radii, useTheme } from '../theme';
import { ScalePressable } from './ScalePressable';

type IconName = ComponentProps<typeof Feather>['name'];

type IconButtonProps = {
  name: IconName;
  label: string;
  onPress: () => void;
  size?: number;
  iconSize?: number;
  color?: string;
  backgroundColor?: string;
  borderColor?: string;
  style?: StyleProp<ViewStyle>;
  disabled?: boolean;
};

export function IconButton({
  name,
  label,
  onPress,
  size = 48,
  iconSize = 20,
  color = colors.ink,
  backgroundColor = glass.buttonTint,
  borderColor = glass.edge,
  style,
  disabled = false,
}: IconButtonProps) {
  const { reducedMotion } = useTheme();

  return (
    <ScalePressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled }}
      disabled={disabled}
      onPress={onPress}
      hitSlop={6}
      reducedMotion={reducedMotion}
      style={[
        styles.button,
        {
          width: size,
          height: size,
          borderRadius: size / 2,
          backgroundColor,
          borderColor,
          opacity: disabled ? 0.35 : 1,
        },
        style,
      ]}
    >
      <LinearGradient
        pointerEvents="none"
        colors={[glass.highlight, 'transparent', glass.highlightEdge]}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={[StyleSheet.absoluteFill, { borderRadius: size / 2 }]}
      />
      <View pointerEvents="none">
        <Feather name={name} size={iconSize} color={color} />
      </View>
    </ScalePressable>
  );
}

const styles = StyleSheet.create({
  button: {
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: StyleSheet.hairlineWidth,
    borderRadius: radii.pill,
    overflow: 'hidden',
  },
});
