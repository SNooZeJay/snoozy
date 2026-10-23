import type { ComponentProps } from 'react';
import { Text } from 'react-native';

import { type, useTheme } from '../theme';

type Variant = keyof typeof type;

type AppTextProps = ComponentProps<typeof Text> & {
  variant?: Variant;
  color?: string;
};

export function AppText({
  variant = 'body',
  color,
  style,
  ...props
}: AppTextProps) {
  const { palette } = useTheme();

  return (
    <Text
      {...props}
      style={[type[variant], { color: color ?? palette.ink }, style]}
    />
  );
}
