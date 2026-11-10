import {
  BlurMask,
  Canvas,
  Group,
  LinearGradient,
  Path,
  RadialGradient,
  RoundedRect,
  Skia,
  vec,
} from '@shopify/react-native-skia';
import { useMemo } from 'react';
import { Platform, StyleSheet, View, type StyleProp, type ViewStyle } from 'react-native';

export type SnoozyBrandIconProps = {
  /** Edge dimension in dp/pt (default 72). */
  size?: number;
  style?: StyleProp<ViewStyle>;
};

function getTiltedOvalPoint(
  cx: number,
  cy: number,
  rx: number,
  ry: number,
  tiltDeg: number,
  deg: number,
) {
  const tiltRad = (tiltDeg * Math.PI) / 180;
  const cosT = Math.cos(tiltRad);
  const sinT = Math.sin(tiltRad);
  const rad = (deg * Math.PI) / 180;
  const ex = rx * Math.cos(rad);
  const ey = ry * Math.sin(rad);
  return {
    x: cx + (ex * cosT - ey * sinT),
    y: cy + (ex * sinT + ey * cosT),
  };
}

function buildUnifiedEighthNotePath(
  size: number,
  inset = 0,
  offsetX = 0,
  offsetY = 0,
) {
  const cx = size * 0.5 + offsetX;
  const cy = size * 0.5 + offsetY;
  const u = size;

  const stemW = u * 0.0335 - inset * 2;
  const leftR = cx - u * 0.041 - inset;
  const leftL = leftR - stemW;
  const rightR = cx + u * 0.1758 - inset;
  const rightL = rightR - stemW;

  const topLeftY = cy - u * 0.18 + inset;
  const topRightY = cy - u * 0.226 + inset;
  const beamH = u * 0.098 - inset * 1.6;

  const slope = (topRightY - topLeftY) / (rightR - leftL);
  const innerTopL = topLeftY + beamH + slope * (leftR - leftL);
  const innerTopR = topLeftY + beamH + slope * (rightL - leftL);

  const headRx = u * 0.068 - inset;
  const headRy = u * 0.054 - inset;
  const tiltDeg = -28;
  const tiltRad = (tiltDeg * Math.PI) / 180;
  const cosT = Math.cos(tiltRad);
  const sinT = Math.sin(tiltRad);

  const maxEx = Math.sqrt(
    Math.pow(headRx * cosT, 2) + Math.pow(headRy * sinT, 2),
  );
  const tangentDeg =
    (Math.atan2(-headRy * sinT, headRx * cosT) * 180) / Math.PI;
  const neckEndDeg = 248;

  const leftHeadCx = leftR - maxEx;
  const leftHeadCy = cy + u * 0.132;
  const rightHeadCx = rightR - maxEx;
  const rightHeadCy = cy + u * 0.086;

  const rTopPt = getTiltedOvalPoint(
    rightHeadCx,
    rightHeadCy,
    headRx,
    headRy,
    tiltDeg,
    tangentDeg,
  );
  const rNeckPt = getTiltedOvalPoint(
    rightHeadCx,
    rightHeadCy,
    headRx,
    headRy,
    tiltDeg,
    neckEndDeg,
  );
  const lTopPt = getTiltedOvalPoint(
    leftHeadCx,
    leftHeadCy,
    headRx,
    headRy,
    tiltDeg,
    tangentDeg,
  );
  const lNeckPt = getTiltedOvalPoint(
    leftHeadCx,
    leftHeadCy,
    headRx,
    headRy,
    tiltDeg,
    neckEndDeg,
  );

  const cornerR = Math.max(1.5, u * 0.018 - inset * 0.45);
  const innerCornerR = Math.max(1.5, u * 0.016 - inset * 0.35);

  const lStemBotY = lNeckPt.y - u * 0.032;
  const rStemBotY = rNeckPt.y - u * 0.032;

  const tlX = leftL + cornerR;
  const tlY = topLeftY + slope * cornerR;
  const trX = rightR - cornerR;
  const trY = topRightY - slope * cornerR;
  const irX = rightL - innerCornerR;
  const irY = innerTopR - slope * innerCornerR;
  const ilX = leftR + innerCornerR;
  const ilY = innerTopL + slope * innerCornerR;

  const segs: string[] = [
    `M ${leftL} ${lStemBotY}`,
    `L ${leftL} ${topLeftY + cornerR}`,
    `C ${leftL} ${topLeftY} ${leftL + cornerR * 0.35} ${topLeftY} ${tlX} ${tlY}`,
    `L ${trX} ${trY}`,
    `C ${rightR - cornerR * 0.25} ${topRightY} ${rightR} ${topRightY + cornerR * 0.25} ${rightR} ${topRightY + cornerR}`,
    `L ${rTopPt.x} ${rTopPt.y}`,
  ];

  const steps = 40;
  for (let i = 1; i <= steps; i += 1) {
    const deg = tangentDeg + ((neckEndDeg - tangentDeg) * i) / steps;
    const pt = getTiltedOvalPoint(
      rightHeadCx,
      rightHeadCy,
      headRx,
      headRy,
      tiltDeg,
      deg,
    );
    segs.push(`L ${pt.x} ${pt.y}`);
  }

  segs.push(
    `C ${rightL + u * 0.012} ${rNeckPt.y - u * 0.014} ${rightL} ${rNeckPt.y - u * 0.022} ${rightL} ${rStemBotY}`,
    `L ${rightL} ${innerTopR + innerCornerR}`,
    `C ${rightL} ${innerTopR} ${rightL - innerCornerR * 0.35} ${innerTopR} ${irX} ${irY}`,
    `L ${ilX} ${ilY}`,
    `C ${leftR + innerCornerR * 0.25} ${innerTopL} ${leftR} ${innerTopL + innerCornerR * 0.25} ${leftR} ${innerTopL + innerCornerR}`,
    `L ${lTopPt.x} ${lTopPt.y}`,
  );

  for (let i = 1; i <= steps; i += 1) {
    const deg = tangentDeg + ((neckEndDeg - tangentDeg) * i) / steps;
    const pt = getTiltedOvalPoint(
      leftHeadCx,
      leftHeadCy,
      headRx,
      headRy,
      tiltDeg,
      deg,
    );
    segs.push(`L ${pt.x} ${pt.y}`);
  }

  segs.push(
    `C ${leftL + u * 0.012} ${lNeckPt.y - u * 0.014} ${leftL} ${lNeckPt.y - u * 0.022} ${leftL} ${lStemBotY}`,
    'Z',
  );

  const path = Skia.Path.MakeFromSVGString(segs.join(' ')) ?? Skia.Path.Make();

  // Diagonal specular reflection fold across the top beam
  const beamSheen =
    Skia.Path.MakeFromSVGString(
      `M ${leftL - u * 0.02} ${topLeftY - u * 0.02} L ${rightR - u * 0.04} ${topRightY - u * 0.02} L ${leftR + u * 0.06} ${innerTopL + u * 0.05} L ${leftL - u * 0.02} ${innerTopL + u * 0.08} Z`,
    ) ?? Skia.Path.Make();

  // Crisp top-left optical specular highlight lines (#ECFDF5)
  const specularHighlight =
    Skia.Path.MakeFromSVGString(
      `M ${leftL + u * 0.018} ${topLeftY + u * 0.006} L ${rightR - u * 0.02} ${topRightY + u * 0.006} M ${leftR + u * 0.012} ${innerTopL - u * 0.002} L ${rightL - u * 0.012} ${innerTopR - u * 0.002}`,
    ) ?? Skia.Path.Make();

  return {
    path,
    beamSheen,
    specularHighlight,
    leftHeadCenter: vec(leftHeadCx - u * 0.004, leftHeadCy + u * 0.006),
    rightHeadCenter: vec(rightHeadCx - u * 0.004, rightHeadCy + u * 0.006),
    leftCrescentCenter: vec(
      leftHeadCx - headRx * 0.36,
      leftHeadCy - headRy * 0.44,
    ),
    rightCrescentCenter: vec(
      rightHeadCx - headRx * 0.36,
      rightHeadCy - headRy * 0.44,
    ),
    headRx,
    headRy,
  };
}

/**
 * Reusable Snoozy Emerald Liquid Glass brand icon component.
 *
 * Recreates the clean, minimalist Apple Icon Composer Liquid Glass eighth-note (♫) icon:
 * 1. Base Layer: Smooth diagonal gradient from dark obsidian (#060907) in bottom-left
 *    to deep forest emerald (#0D2818 / #1B6847) in top-right inside a continuous squircle
 *    container with a 0.5dp translucent #34D399 (15% alpha) border.
 * 2. Foreground: Unified 3D moulded crystal glass eighth note (♫) with soft bottom-left
 *    contact shadow, diagonal beam reflection sheen, deep dark convex lens bulbs inside
 *    the noteheads, #ECFDF5 top-left specular rim reflections, and subtle prismatic dispersion.
 */
export function SnoozyBrandIcon({ size = 72, style }: SnoozyBrandIconProps) {
  const cornerRadius = size * 0.225;

  const geometry = useMemo(() => {
    const shadowNote = buildUnifiedEighthNotePath(
      size,
      0,
      -size * 0.016,
      size * 0.024,
    );
    const outerNote = buildUnifiedEighthNotePath(size, 0, 0, 0);
    const innerNote = buildUnifiedEighthNotePath(size, size * 0.014, 0, 0);
    return {
      shadowNote,
      outerNote,
      innerNote,
    };
  }, [size]);

  return (
    <View
      accessibilityRole="image"
      accessibilityLabel="Snoozy Emerald Liquid Glass icon"
      style={[
        styles.container,
        {
          width: size,
          height: size,
          borderRadius: cornerRadius,
        },
        style,
      ]}
    >
      <Canvas style={{ width: size, height: size }}>
        {/* 1. BASE LAYER: Smooth diagonal gradient (#00020F bottom-left -> #1F6D57 top-right) */}
        <RoundedRect x={0} y={0} width={size} height={size} r={cornerRadius}>
          <LinearGradient
            start={vec(0, size)}
            end={vec(size, 0)}
            colors={['#00020F', '#051118', '#0D2F29', '#195846', '#22725B']}
            positions={[0, 0.26, 0.52, 0.78, 1]}
          />
        </RoundedRect>

        {/* 2. FOREGROUND: 3D Liquid Glass Musical Note (♫) */}
        {/* 2A. Soft bottom-left contact shadow */}
        <Path path={geometry.shadowNote.path} color="rgba(2, 5, 3, 0.52)">
          <BlurMask blur={size * 0.028} style="normal" />
        </Path>

        {/* 2B. Refractive smoky-emerald crystal glass body fill */}
        <Path path={geometry.outerNote.path} style="fill">
          <LinearGradient
            start={vec(size * 0.22, size * 0.18)}
            end={vec(size * 0.78, size * 0.84)}
            colors={[
              'rgba(236, 253, 245, 0.44)',
              'rgba(110, 231, 183, 0.22)',
              'rgba(5, 46, 34, 0.48)',
              'rgba(13, 59, 42, 0.40)',
              'rgba(167, 243, 208, 0.36)',
            ]}
            positions={[0, 0.24, 0.54, 0.8, 1]}
          />
        </Path>

        {/* 2C. Clipped internal optical features (diagonal beam sheen + dark convex lens bulbs) */}
        <Group clip={geometry.outerNote.path}>
          <Path path={geometry.outerNote.beamSheen} style="fill">
            <LinearGradient
              start={vec(size * 0.28, size * 0.24)}
              end={vec(size * 0.56, size * 0.46)}
              colors={['rgba(236, 253, 245, 0.32)', 'rgba(52, 211, 153, 0)']}
            />
          </Path>

          {/* Deep dark convex lens absorption inside the two noteheads */}
          <RoundedRect x={0} y={0} width={size} height={size} r={cornerRadius}>
            <RadialGradient
              c={geometry.outerNote.leftHeadCenter}
              r={geometry.outerNote.headRx * 0.88}
              colors={['rgba(4, 11, 8, 0.84)', 'rgba(7, 31, 22, 0.38)', 'rgba(7, 31, 22, 0)']}
              positions={[0, 0.65, 1]}
            />
          </RoundedRect>
          <RoundedRect x={0} y={0} width={size} height={size} r={cornerRadius}>
            <RadialGradient
              c={geometry.outerNote.rightHeadCenter}
              r={geometry.outerNote.headRx * 0.88}
              colors={['rgba(5, 18, 13, 0.80)', 'rgba(9, 43, 30, 0.36)', 'rgba(9, 43, 30, 0)']}
              positions={[0, 0.65, 1]}
            />
          </RoundedRect>

          {/* Top-left white-mint crescent lens highlight inside each notehead */}
          <RoundedRect x={0} y={0} width={size} height={size} r={cornerRadius}>
            <RadialGradient
              c={geometry.outerNote.leftCrescentCenter}
              r={geometry.outerNote.headRx * 0.52}
              colors={['rgba(236, 253, 245, 0.58)', 'rgba(167, 243, 208, 0)']}
            />
          </RoundedRect>
          <RoundedRect x={0} y={0} width={size} height={size} r={cornerRadius}>
            <RadialGradient
              c={geometry.outerNote.rightCrescentCenter}
              r={geometry.outerNote.headRx * 0.52}
              colors={['rgba(236, 253, 245, 0.58)', 'rgba(167, 243, 208, 0)']}
            />
          </RoundedRect>
        </Group>

        {/* 2D. Inner Bevel Ridge creating the moulded 3D glass channel */}
        <Path
          path={geometry.innerNote.path}
          style="stroke"
          strokeWidth={Math.max(1, size * 0.0055)}
          strokeJoin="round"
        >
          <LinearGradient
            start={vec(size * 0.22, size * 0.2)}
            end={vec(size * 0.78, size * 0.84)}
            colors={[
              'rgba(236, 253, 245, 0.72)',
              'rgba(52, 211, 153, 0.32)',
              'rgba(167, 243, 208, 0.54)',
            ]}
          />
        </Path>

        {/* 2E. Outer Bevel Rim & Top-Left Optical Edge Highlights (#ECFDF5) */}
        <Path
          path={geometry.outerNote.path}
          style="stroke"
          strokeWidth={Math.max(1.2, size * 0.009)}
          strokeJoin="round"
          strokeCap="round"
        >
          <LinearGradient
            start={vec(size * 0.18, size * 0.14)}
            end={vec(size * 0.82, size * 0.86)}
            colors={[
              '#ECFDF5',
              'rgba(167, 243, 208, 0.85)',
              'rgba(110, 231, 183, 0.52)',
              'rgba(236, 253, 245, 0.82)',
            ]}
            positions={[0, 0.34, 0.68, 1]}
          />
        </Path>

        <Path
          path={geometry.outerNote.specularHighlight}
          style="stroke"
          strokeWidth={Math.max(1.2, size * 0.008)}
          strokeCap="round"
          strokeJoin="round"
          color="rgba(236, 253, 245, 0.96)"
        />

        {/* Outer continuous squircle 0.5dp translucent border (#34D399, 15% opacity) */}
        <RoundedRect
          x={0.5}
          y={0.5}
          width={size - 1}
          height={size - 1}
          r={cornerRadius}
          style="stroke"
          strokeWidth={1}
          color="rgba(52, 211, 153, 0.15)"
        />
      </Canvas>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    overflow: 'hidden',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(52, 211, 153, 0.15)',
    backgroundColor: '#080E09',
    ...(Platform.OS === 'ios' ? { borderCurve: 'continuous' as const } : null),
  },
});
