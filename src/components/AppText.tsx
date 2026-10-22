import type { ComponentProps } from 'react';
import { Text } from 'react-native';

import { colors, type } from '../theme';

type Variant = keyof typeof type;

type AppTextProps = ComponentProps<typeof Text> & {
  variant?: Variant;
  color?: string;
};

export function AppText({
  variant = 'body',
  color = colors.ink,
  style,
  ...props
}: AppTextProps) {
  return (
    <Text
      {...props}
      style={[type[variant], { color }, style]}
    />
  );
}
