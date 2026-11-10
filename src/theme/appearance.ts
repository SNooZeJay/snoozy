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

  // Keep Cupertino OLED dark system surfaces, while letting the selected seed
  // drive the accent and subtly tint elevated surfaces.
  palette.background = '#000000';
  palette.backgroundDeep = '#000000';
  palette.backgroundRaised = mixHex('#0F1015', tokens.surfaceContainerLow, 0.18);
  palette.surface = mixHex('#1C1C1E', tokens.surfaceContainer, 0.16);
  palette.surfaceRaised = mixHex('#2C2C2E', tokens.surfaceContainerHigh, 0.18);
  palette.surfaceMuted = mixHex('#3A3A3C', tokens.surfaceContainerHighest, 0.18);
  palette.border = 'rgba(255, 255, 255, 0.12)';
  palette.borderStrong = 'rgba(255, 255, 255, 0.22)';
  palette.accent = seed;
  palette.accentStrong = seed;
  palette.accentInk = readableInk(palette.accent);
  palette.iosGreen = '#30D158';
  palette.ember = tokens.tertiary;
  palette.emberSoft = withAlpha(tokens.tertiary, 0.16);
  palette.imageTint = tokens.secondary;
  return palette;
}

function buildLightPalette(tokens: ColorTokens, seed: string): AppPalette {
  // iOS System Grouped Background (#F2F2F7) with pure white (#FFFFFF) inset cards.
  const background = '#F2F2F7';
  const accent = seed;
  return {
    background,
    backgroundDeep: '#E5E5EA',
    backgroundRaised: '#FFFFFF',
    surface: '#FFFFFF',
    surfaceRaised: '#F2F2F7',
    surfaceMuted: '#E5E5EA',
    border: 'rgba(60, 60, 67, 0.14)',
    borderStrong: 'rgba(60, 60, 67, 0.24)',
    ink: '#000000',
    inkMuted: 'rgba(60, 60, 67, 0.62)',
    inkFaint: 'rgba(60, 60, 67, 0.38)',
    accent,
    accentStrong: accent,
    accentInk: readableInk(accent),
    iosGreen: '#34C759',
    ember: '#FF9500',
    emberSoft: 'rgba(255, 149, 0, 0.14)',
    danger: '#FF3B30',
    dangerSoft: 'rgba(255, 59, 48, 0.12)',
    pass: '#34C759',
    fail: '#FF3B30',
    pending: '#FF9500',
    imageTint: tokens.secondary,
    scrim: 'rgba(0, 0, 0, 0.32)',
    white: '#FFFFFF',
    black: '#000000',
    surfaceOld: '#FFFFFF',
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
    : buildLightPalette(tokens, seed);
}

function shadow(
  base: ViewStyle,
  color: string,
): ViewStyle {
  return { ...base, shadowColor: color };
}

export function buildAppGlass(palette: AppPalette, dark: boolean): AppGlass {
  const shadowColor = dark
    ? 'rgba(0, 0, 0, 0.44)'
    : 'rgba(0, 0, 0, 0.10)';
  const cardShadow = shadow(glassShadow.card, shadowColor);
  const floatingShadow = shadow(glassShadow.floating, shadowColor);
  const buttonShadow = shadow(glassShadow.button, shadowColor);

  const base = dark
    ? {
        ...darkGlass,
        tintAccent: withAlpha(palette.accent, 0.16),
        innerGlow: withAlpha(palette.accent, 0.08),
      }
    : {
        tint: 'rgba(255, 255, 255, 0.86)',
        tintStrong: 'rgba(255, 255, 255, 0.92)',
        tintSoft: 'rgba(118, 118, 128, 0.12)',
        tintDeep: 'rgba(242, 242, 247, 0.86)',
        tintAccent: withAlpha(palette.accent, 0.14),
        buttonTint: 'rgba(255, 255, 255, 0.82)',
        fieldTint: 'rgba(118, 118, 128, 0.12)',
        edge: 'rgba(60, 60, 67, 0.12)',
        edgeStrong: 'rgba(60, 60, 67, 0.18)',
        edgeSoft: 'rgba(60, 60, 67, 0.08)',
        highlight: 'rgba(255, 255, 255, 0.85)',
        highlightSoft: 'rgba(255, 255, 255, 0.45)',
        highlightEdge: 'rgba(255, 255, 255, 0.18)',
        shadow: 'rgba(0, 0, 0, 0.08)',
        shadowDeep: 'rgba(0, 0, 0, 0.14)',
        innerGlow: withAlpha(palette.accent, 0.08),
        scrim: 'rgba(0, 0, 0, 0.32)',
      };

  return {
    ...base,
    variants: {
      card: {
        tint: base.tint,
        edge: base.edge,
        radius: 16,
        highlight: true,
        shadow: cardShadow,
      },
      panel: {
        tint: base.tintStrong,
        edge: base.edgeStrong,
        radius: 24,
        highlight: true,
        shadow: floatingShadow,
      },
      row: {
        tint: base.tint,
        edge: base.edgeSoft,
        radius: 14,
        highlight: false,
        shadow: null,
      },
      pill: {
        tint: base.tintStrong,
        edge: base.edgeStrong,
        radius: 999,
        highlight: true,
        shadow: floatingShadow,
      },
      button: {
        tint: base.buttonTint,
        edge: base.edge,
        radius: 22,
        highlight: true,
        shadow: buttonShadow,
      },
      field: {
        tint: base.fieldTint,
        edge: base.edgeSoft,
        radius: 12,
        highlight: false,
        shadow: null,
      },
    },
  };
}
