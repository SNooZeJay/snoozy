import { BlurView } from 'expo-blur';
import { LinearGradient } from 'expo-linear-gradient';
import type { ComponentRef, RefObject } from 'react';
import {
  Platform,
  StyleSheet,
  View,
  type StyleProp,
  type ViewStyle,
  type ViewProps,
} from 'react-native';

import { useTheme } from '../../theme';
import type { GlassVariant } from '../../theme/glass';

type GlassSurfaceProps = ViewProps & {
  variant?: GlassVariant;
  radius?: number;
  tint?: string;
  borderColor?: string;
  glowColor?: string;
  highlight?: boolean;
  style?: StyleProp<ViewStyle>;
  /**
   * Android backdrop target. The target must wrap the scrolling content and
   * this surface must render after it, so a floating bar samples live pixels
   * instead of a static fill.
   */
  blurTarget?: GlassBlurTarget;
  blurIntensity?: number;
};

export type GlassBlurTarget = RefObject<ComponentRef<typeof View> | null>;

/**
 * Glasmio-inspired Liquid Glass surface:
 * - Translucent acrylic base fill
 * - Dual-angle specular reflection sweep (top-left primary + bottom-right fresnel counter-sheen)
 * - 0.5pt hairline outer rim + subtle inner refractive rim
 * - Continuous squircle corners
 */
export function GlassSurface({
  variant = 'card',
  radius,
  tint,
  borderColor,
  glowColor,
  highlight,
  style,
  blurTarget,
  blurIntensity = 55,
  children,
  ...rest
}: GlassSurfaceProps) {
  const { dark, glass } = useTheme();
  const config = glass.variants[variant];
  const resolvedRadius = radius ?? config.radius;
  const showHighlight = highlight ?? config.highlight;
  const resolvedTint = tint ?? config.tint;

  return (
    <View
      {...rest}
      style={[
        styles.base,
        config.shadow,
        {
          borderRadius: resolvedRadius,
          backgroundColor: blurTarget ? 'transparent' : resolvedTint,
          borderColor: borderColor ?? config.edge,
        },
        style,
      ]}
    >
      {blurTarget ? (
        <>
          <BlurView
            pointerEvents="none"
            blurTarget={blurTarget}
            blurMethod="dimezisBlurViewSdk31Plus"
            intensity={blurIntensity}
            tint={dark ? 'dark' : 'light'}
            style={StyleSheet.absoluteFill}
          />
          <View
            pointerEvents="none"
            style={[StyleSheet.absoluteFill, { backgroundColor: resolvedTint }]}
          />
        </>
      ) : null}
      {showHighlight ? (
        <>
          <LinearGradient
            pointerEvents="none"
            colors={[glass.highlight, glass.highlightSoft, 'transparent', glass.highlightEdge]}
            locations={[0, 0.28, 0.68, 1]}
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
        </>
      ) : null}
      {glowColor ? (
        <View
          pointerEvents="none"
          style={[
            styles.glow,
            {
              borderRadius: resolvedRadius,
              backgroundColor: glowColor,
            },
          ]}
        />
      ) : null}
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  base: {
    borderWidth: StyleSheet.hairlineWidth,
    overflow: 'hidden',
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
  glow: {
    position: 'absolute',
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
    opacity: 0.16,
  },
});
