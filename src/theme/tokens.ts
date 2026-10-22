/**
 * Snoozy visual system.
 *
 * A dark, warm room rather than a black screen: pine ground, milk type,
 * pale lichen for action, and ember only for time. Values are intentionally
 * low-chroma; the artwork supplies the color.
 */

export const colors = {
  background: '#07110D',
  backgroundDeep: '#040B08',
  backgroundRaised: '#0B1A12',
  surface: '#0D1B14',
  surfaceRaised: '#13261C',
  surfaceMuted: '#1A2E22',
  border: 'rgba(232, 242, 224, 0.10)',
  borderStrong: 'rgba(232, 242, 224, 0.18)',
  ink: '#F3F0E4',
  inkMuted: '#B8C6BA',
  inkFaint: '#889A8D',
  accent: '#D8F2C6',
  accentStrong: '#A9DCA8',
  accentInk: '#143019',
  ember: '#EAC77A',
  emberSoft: 'rgba(234, 199, 122, 0.13)',
  danger: '#F0A69C',
  dangerSoft: 'rgba(240, 166, 156, 0.13)',
  pass: '#9EE0B5',
  fail: '#F0A69C',
  pending: '#EAC77A',
  imageTint: '#B7A9DC',
  scrim: 'rgba(4, 11, 8, 0.64)',
  white: '#FFFFFF',
  black: '#000000',
  // Kept for the native diagnostics route, which documents the release gate.
  surfaceOld: '#131A16',
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
  screen: 20,
} as const;

export const radii = {
  sm: 10,
  md: 14,
  lg: 20,
  xl: 28,
  xxl: 36,
  pill: 999,
} as const;

export const type = {
  display: {
    fontFamily: fonts.display,
    fontSize: 43,
    lineHeight: 45,
    letterSpacing: -1.4,
  },
  title: {
    fontFamily: fonts.display,
    fontSize: 30,
    lineHeight: 33,
    letterSpacing: -0.8,
  },
  heading: {
    fontFamily: fonts.display,
    fontSize: 22,
    lineHeight: 26,
    letterSpacing: -0.35,
  },
  body: {
    fontFamily: fonts.body,
    fontSize: 16,
    lineHeight: 24,
  },
  bodyBold: {
    fontFamily: fonts.bodyBold,
    fontSize: 16,
    lineHeight: 24,
  },
  label: {
    fontFamily: fonts.bodyBold,
    fontSize: 13,
    lineHeight: 18,
    letterSpacing: 0.1,
  },
  micro: {
    fontFamily: fonts.body,
    fontSize: 12,
    lineHeight: 16,
    letterSpacing: 0.1,
  },
  overline: {
    fontFamily: fonts.bodyBold,
    fontSize: 11,
    lineHeight: 14,
    letterSpacing: 1.2,
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
    shadowOffset: { width: 0, height: 14 },
    shadowOpacity: 0.32,
    shadowRadius: 24,
    elevation: 10,
  },
  floating: {
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.4,
    shadowRadius: 18,
    elevation: 14,
  },
} as const;

export const layout = {
  screenPadding: 20,
  cardRadius: 28,
  tabBarSpace: 216, // content bottom inset: floating bar (62) + gap (12) + mini (60) + gap + safe area
  tabBarHeight: 62,
  tabBarInset: 12,
  pillGap: 12,
} as const;

export const motion = {
  durations: {
    short: 120,
    medium: 240,
    long: 400,
    extraLong: 700,
  },
  springs: {
    gentle: { damping: 20, stiffness: 180, mass: 1 },
    standard: { damping: 18, stiffness: 260, mass: 1 },
    bouncy: { damping: 12, stiffness: 320, mass: 1 },
    snappy: { damping: 22, stiffness: 400, mass: 0.8 },
  },
  reduced: { damping: 40, stiffness: 600, mass: 1 },
} as const;

export const shape = {
  none: 0,
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 28,
  xxl: 36,
  full: 999,
  cover: 24,
} as const;
