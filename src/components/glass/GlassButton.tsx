import { LinearGradient } from 'expo-linear-gradient';
import type { ReactNode } from 'react';
import {
  Platform,
  StyleSheet,
  View,
  type PressableProps,
  type StyleProp,
  type ViewStyle,
} from 'react-native';

import { useTheme } from '../../theme';
import type { GlassVariant } from '../../theme/glass';
import { ScalePressable } from '../ScalePressable';

type GlassButtonProps = Omit<PressableProps, 'children'> & {
  children?: ReactNode;
  variant?: GlassVariant;
  radius?: number;
  tint?: string;
  borderColor?: string;
  glowColor?: string;
  style?: StyleProp<ViewStyle>;
};

/**
 * Glasmio-inspired interactive Liquid Glass button:
 * - Specular refraction sweep + 0.5pt hairline fresnel rim
 * - Quick Cupertino opacity + spring scale compression on press
 */
export function GlassButton({
  variant = 'button',
  radius,
  tint,
  borderColor,
  glowColor,
  style,
  children,
  ...rest
}: GlassButtonProps) {
  const { glass, reducedMotion } = useTheme();
  const config = glass.variants[variant];
  const resolvedRadius = radius ?? config.radius;

  return (
    <ScalePressable
      {...rest}
      reducedMotion={reducedMotion}
      style={[
        styles.base,
        config.shadow,
        {
          borderRadius: resolvedRadius,
          backgroundColor: tint ?? config.tint,
          borderColor: borderColor ?? config.edge,
          opacity: rest.disabled ? 0.5 : 1,
        },
        style,
      ]}
    >
      <LinearGradient
        pointerEvents="none"
        colors={[glass.highlight, glass.highlightSoft, 'transparent', glass.highlightEdge]}
        locations={[0, 0.32, 0.72, 1]}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={[StyleSheet.absoluteFill, { borderRadius: resolvedRadius }]}
      />
      <View
        pointerEvents="none"
        style={[
          styles.fresnelRim,
          {
            borderRadius: Math.max(0, resolvedRadius - 0.5),
            borderColor: glass.innerGlow,
          },
        ]}
      />
      {glowColor ? (
        <LinearGradient
          pointerEvents="none"
          colors={[glowColor, 'transparent']}
          start={{ x: 0.5, y: 1 }}
          end={{ x: 0.5, y: 0 }}
          style={[StyleSheet.absoluteFill, { borderRadius: resolvedRadius, opacity: 0.24 }]}
        />
      ) : null}
      {children}
    </ScalePressable>
  );
}

const styles = StyleSheet.create({
  base: {
    borderWidth: StyleSheet.hairlineWidth,
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
    ...(Platform.OS === 'ios' ? { borderCurve: 'continuous' as const } : null),
  },
  fresnelRim: {
    position: 'absolute',
    top: 0.5,
    right: 0.5,
    bottom: 0.5,
    left: 0.5,
    borderWidth: StyleSheet.hairlineWidth,
  },
});
