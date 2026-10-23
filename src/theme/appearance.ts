import type { ViewStyle } from 'react-native';

import {
  DEFAULT_SEED,
  mixHex,
  readableInk,
  withAlpha,
  type ColorTokens,
  type PaletteStyle,
} from './color';
import { glass as darkGlass, glassShadow, type GlassVariant } from './glass';
import { colors } from './tokens';

export type AppPalette = {
  -readonly [K in keyof typeof colors]: string;
};

export type AppGlassVariant = {
  tint: string;
  edge: string;
  radius: number;
  highlight: boolean;
  shadow: ViewStyle | null;
};

export type AppGlass = {
  tint: string;
  tintStrong: string;
  tintSoft: string;
  tintDeep: string;
  tintAccent: string;
  buttonTint: string;
  fieldTint: string;
  edge: string;
  edgeStrong: string;
  edgeSoft: string;
  highlight: string;
  highlightSoft: string;
  highlightEdge: string;
  shadow: string;
  shadowDeep: string;
  innerGlow: string;
  scrim: string;
  variants: Record<GlassVariant, AppGlassVariant>;
};

const DEFAULT_DARK: AppPalette = { ...colors };

function isDefaultDark(seed: string, paletteStyle: PaletteStyle): boolean {
  return (
    seed.toLowerCase() === DEFAULT_SEED.toLowerCase() &&
    paletteStyle === 'tonal-spot'
  );
}

function buildDarkPalette(
  tokens: ColorTokens,
  seed: string,
  paletteStyle: PaletteStyle,
): AppPalette {
  const palette: AppPalette = { ...DEFAULT_DARK };
  if (isDefaultDark(seed, paletteStyle)) return palette;

  // Keep the pine ground and readable ink, but let the selected seed/style
  // tint surfaces and drive the accent. This preserves the Snoozy identity
  // while making palette choices visibly different.
  palette.background = mixHex(DEFAULT_DARK.background, tokens.background, 0.3);
  palette.backgroundDeep = mixHex(DEFAULT_DARK.backgroundDeep, tokens.background, 0.24);
  palette.backgroundRaised = mixHex(
    DEFAULT_DARK.backgroundRaised,
    tokens.surfaceContainerLow,
    0.32,
  );
  palette.surface = mixHex(DEFAULT_DARK.surface, tokens.surfaceContainer, 0.32);
  palette.surfaceRaised = mixHex(
    DEFAULT_DARK.surfaceRaised,
    tokens.surfaceContainerHigh,
    0.32,
  );
  palette.surfaceMuted = mixHex(
    DEFAULT_DARK.surfaceMuted,
    tokens.surfaceContainerHighest,
    0.32,
  );
  palette.border = withAlpha(tokens.outlineVariant, 0.22);
  palette.borderStrong = withAlpha(tokens.outline, 0.3);
  palette.accent = tokens.primary;
  palette.accentStrong = tokens.primary;
  palette.accentInk = readableInk(palette.accent);
  palette.ember = tokens.tertiary;
  palette.emberSoft = withAlpha(tokens.tertiary, 0.13);
  palette.imageTint = tokens.secondary;
  return palette;
}

function buildLightPalette(tokens: ColorTokens): AppPalette {
  const background = tokens.background;
  return {
    background,
    backgroundDeep: mixHex(background, '#000000', 0.05),
    backgroundRaised: tokens.surfaceContainerLow,
    surface: tokens.surfaceContainer,
    surfaceRaised: tokens.surfaceContainerHigh,
    surfaceMuted: tokens.surfaceContainerHighest,
    border: withAlpha(tokens.outlineVariant, 0.65),
    borderStrong: withAlpha(tokens.outline, 0.75),
    ink: tokens.onBackground,
    inkMuted: tokens.onSurfaceVariant,
    inkFaint: mixHex(tokens.onSurfaceVariant, background, 0.35),
    accent: tokens.primary,
    accentStrong: tokens.primary,
    accentInk: tokens.onPrimary,
    ember: tokens.tertiary,
    emberSoft: withAlpha(tokens.tertiary, 0.14),
    danger: tokens.error,
    dangerSoft: withAlpha(tokens.error, 0.14),
    pass: tokens.primary,
    fail: tokens.error,
    pending: tokens.tertiary,
    imageTint: tokens.secondary,
    scrim: withAlpha(tokens.scrim, 0.32),
    white: '#FFFFFF',
    black: '#000000',
    surfaceOld: tokens.surfaceContainerHigh,
  };
}

export function buildAppPalette(
  tokens: ColorTokens,
  dark: boolean,
  seed: string,
  paletteStyle: PaletteStyle,
): AppPalette {
  return dark
    ? buildDarkPalette(tokens, seed, paletteStyle)
    : buildLightPalette(tokens);
}

function shadow(
  base: ViewStyle,
  color: string,
): ViewStyle {
  return { ...base, shadowColor: color };
}

export function buildAppGlass(palette: AppPalette, dark: boolean): AppGlass {
  const shadowColor = dark
    ? 'rgba(0, 0, 0, 0.42)'
    : 'rgba(12, 25, 18, 0.16)';
  const cardShadow = shadow(glassShadow.card, shadowColor);
  const floatingShadow = shadow(glassShadow.floating, shadowColor);
  const buttonShadow = shadow(glassShadow.button, shadowColor);

  const base = dark
    ? {
        ...darkGlass,
        tintAccent: withAlpha(palette.accent, 0.12),
        innerGlow: withAlpha(palette.accent, 0.06),
      }
    : {
        tint: withAlpha(palette.surface, 0.72),
        tintStrong: withAlpha(palette.surface, 0.86),
        tintSoft: withAlpha(palette.surface, 0.55),
        tintDeep: withAlpha(palette.backgroundDeep, 0.74),
        tintAccent: withAlpha(palette.accent, 0.14),
        buttonTint: withAlpha(palette.surface, 0.68),
        fieldTint: withAlpha(palette.surface, 0.78),
        edge: withAlpha(palette.ink, 0.12),
        edgeStrong: withAlpha(palette.ink, 0.2),
        edgeSoft: withAlpha(palette.ink, 0.08),
        highlight: 'rgba(255, 255, 255, 0.72)',
        highlightSoft: 'rgba(255, 255, 255, 0.35)',
        highlightEdge: 'rgba(255, 255, 255, 0.1)',
        shadow: 'rgba(12, 25, 18, 0.14)',
        shadowDeep: 'rgba(12, 25, 18, 0.2)',
        innerGlow: withAlpha(palette.accent, 0.08),
        scrim: 'rgba(7, 17, 13, 0.32)',
      };

  return {
    ...base,
    variants: {
      card: {
        tint: base.tint,
        edge: base.edge,
        radius: 28,
        highlight: true,
        shadow: cardShadow,
      },
      panel: {
        tint: base.tintStrong,
        edge: base.edgeStrong,
        radius: 28,
        highlight: true,
        shadow: cardShadow,
      },
      row: {
        tint: base.tint,
        edge: base.edgeSoft,
        radius: 20,
        highlight: false,
        shadow: null,
      },
      pill: {
        tint: base.tintStrong,
        edge: base.edge,
        radius: 999,
        highlight: true,
        shadow: floatingShadow,
      },
      button: {
        tint: base.buttonTint,
        edge: base.edge,
        radius: 24,
        highlight: true,
        shadow: buttonShadow,
      },
      field: {
        tint: base.fieldTint,
        edge: base.edge,
        radius: 999,
        highlight: true,
        shadow: buttonShadow,
      },
    },
  };
}
