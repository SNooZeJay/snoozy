import { LinearGradient } from 'expo-linear-gradient';
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
};

/**
 * A glass surface for Android: translucent fill, fine rim, top-left specular
 * sweep, and a soft drop shadow. No live blur; real backdrop blur is not
 * available on this platform without a native module.
 */
export function GlassSurface({
  variant = 'card',
  radius,
  tint,
  borderColor,
  glowColor,
  highlight,
  style,
  children,
  ...rest
}: GlassSurfaceProps) {
  const { glass } = useTheme();
  const config = glass.variants[variant];
  const resolvedRadius = radius ?? config.radius;
  const showHighlight = highlight ?? config.highlight;

  return (
    <View
      {...rest}
      style={[
        styles.base,
        config.shadow,
        {
          borderRadius: resolvedRadius,
          backgroundColor: tint ?? config.tint,
          borderColor: borderColor ?? config.edge,
        },
        style,
      ]}
    >
      {showHighlight ? (
        <LinearGradient
          pointerEvents="none"
          colors={[glass.highlight, glass.highlightSoft, 'transparent', glass.highlightEdge]}
          locations={[0, 0.32, 0.72, 1]}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={[StyleSheet.absoluteFill, { borderRadius: resolvedRadius }]}
        />
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
    borderWidth: 1,
    overflow: 'hidden',
    // Android ignores borderCurve; iOS gets the continuous corner.
    ...(Platform.OS === 'ios' ? { borderCurve: 'continuous' as const } : null),
  },
  glow: {
    position: 'absolute',
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
    opacity: 0.18,
  },
});
