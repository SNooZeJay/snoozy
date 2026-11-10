/**
 * Snoozy Cupertino & Liquid Glass visual system.
 *
 * Engineered around Apple's Human Interface Guidelines (HIG):
 * - Deep OLED/system grouped backgrounds (#000000 / #1C1C1E in dark, #F2F2F7 / #FFFFFF in light)
 * - 16pt continuous squircle inset grouped cards with 0.5pt hairline rims
 * - Bold SF-Pro-inspired Large Title hierarchy and clean secondary labels
 * - iOS system green (#30D158) toggles and critically-damped Cupertino springs
 */

export const colors = {
  background: '#000000',
  backgroundDeep: '#000000',
  backgroundRaised: '#0F1015',
  surface: '#1C1C1E',
  surfaceRaised: '#2C2C2E',
  surfaceMuted: '#3A3A3C',
  border: 'rgba(255, 255, 255, 0.12)',
  borderStrong: 'rgba(255, 255, 255, 0.22)',
  ink: '#FFFFFF',
  inkMuted: 'rgba(235, 235, 245, 0.62)',
  inkFaint: 'rgba(235, 235, 245, 0.38)',
  accent: '#10B981',
  accentStrong: '#059669',
  accentInk: '#ECFDF5',
  iosGreen: '#30D158',
  ember: '#FF9F0A',
  emberSoft: 'rgba(255, 159, 10, 0.16)',
  danger: '#FF453A',
  dangerSoft: 'rgba(255, 69, 58, 0.16)',
  pass: '#30D158',
  fail: '#FF453A',
  pending: '#FF9F0A',
  imageTint: '#5E5CE6',
  scrim: 'rgba(0, 0, 0, 0.52)',
  white: '#FFFFFF',
  black: '#000000',
  // Kept for the native diagnostics route, which documents the release gate.
  surfaceOld: '#1C1C1E',
} as const;

export const fonts = {
  display: 'BricolageGrotesque_600SemiBold',
  displayMedium: 'BricolageGrotesque_500Medium',
  body: 'AtkinsonHyperlegible_400Regular',
  bodyBold: 'AtkinsonHyperlegible_700Bold',
} as const;

export const spacing = {
  xxs: 2,
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  xxl: 24,
  xxxl: 32,
  huge: 48,
  screen: 16,
} as const;

export const radii = {
  sm: 8,
  md: 12,
  lg: 16,
  xl: 22,
  xxl: 32,
  pill: 999,
} as const;

export const type = {
  display: {
    fontFamily: fonts.display,
    fontSize: 40,
    lineHeight: 44,
    letterSpacing: -1.1,
  },
  title: {
    fontFamily: fonts.display,
    fontSize: 34,
    lineHeight: 38,
    letterSpacing: -0.8,
  },
  heading: {
    fontFamily: fonts.display,
    fontSize: 20,
    lineHeight: 25,
    letterSpacing: -0.4,
  },
  body: {
    fontFamily: fonts.body,
    fontSize: 16,
    lineHeight: 22,
  },
  bodyBold: {
    fontFamily: fonts.bodyBold,
    fontSize: 16,
    lineHeight: 22,
  },
  label: {
    fontFamily: fonts.bodyBold,
    fontSize: 15,
    lineHeight: 20,
    letterSpacing: -0.15,
  },
  micro: {
    fontFamily: fonts.body,
    fontSize: 13,
    lineHeight: 18,
    letterSpacing: -0.05,
  },
  overline: {
    fontFamily: fonts.bodyBold,
    fontSize: 12,
    lineHeight: 16,
    letterSpacing: 0.6,
    textTransform: 'uppercase' as const,
  },
  // Legacy diagnostics aliases.
  labelLegacy: {
    fontFamily: fonts.bodyBold,
    fontSize: 13,
    lineHeight: 18,
  },
} as const;

export const shadows = {
  card: {
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.24,
    shadowRadius: 18,
    elevation: 6,
  },
  floating: {
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.36,
    shadowRadius: 22,
    elevation: 14,
  },
} as const;

export const layout = {
  screenPadding: 16,
  cardRadius: 16,
  tabBarSpace: 216, // content bottom inset: floating bar (64) + gap (10) + mini (60) + gap + safe area
  tabBarHeight: 62,
  tabBarInset: 10,
  pillGap: 10,
} as const;

export const motion = {
  durations: {
    instant: 0,
    short: 110,
    medium: 240,
    long: 360,
    extraLong: 600,
    screen: 280,
    splash: 420,
  },
  springs: {
    gentle: { damping: 26, stiffness: 220, mass: 0.95 },
    standard: { damping: 26, stiffness: 320, mass: 0.9 },
    bouncy: { damping: 18, stiffness: 340, mass: 0.85 },
    snappy: { damping: 28, stiffness: 440, mass: 0.78 },
  },
  easings: {
    standard: [0.25, 0.1, 0.25, 1] as const,
    decelerate: [0, 0, 0.2, 1] as const,
    accelerate: [0.4, 0, 1, 1] as const,
  },
  stagger: {
    step: 28,
    maxItems: 8,
  },
  reduced: { damping: 45, stiffness: 600, mass: 1 },
} as const;

export const shape = {
  none: 0,
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 22,
  xxl: 32,
  full: 999,
  cover: 18,
} as const;
