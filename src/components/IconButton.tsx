import Feather from '@expo/vector-icons/Feather';
import type { ComponentProps } from 'react';
import {
  Pressable,
  StyleSheet,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';

import { colors, radii } from '../theme';

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
  backgroundColor = colors.surfaceRaised,
  borderColor = colors.border,
  style,
  disabled = false,
}: IconButtonProps) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled }}
      disabled={disabled}
      onPress={onPress}
      hitSlop={6}
      style={({ pressed }) => [
        styles.button,
        {
          width: size,
          height: size,
          borderRadius: size / 2,
          backgroundColor,
          borderColor,
          opacity: disabled ? 0.35 : pressed ? 0.68 : 1,
        },
        style,
      ]}
    >
      <View pointerEvents="none">
        <Feather name={name} size={iconSize} color={color} />
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: StyleSheet.hairlineWidth,
    borderRadius: radii.pill,
  },
});
