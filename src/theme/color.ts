import {
  Hct,
  argbFromHex,
  hexFromArgb,
  SchemeTonalSpot,
  SchemeExpressive,
  SchemeVibrant,
  SchemeNeutral,
  SchemeFidelity,
} from '@material/material-color-utilities';

export type PaletteStyle = 'classic' | 'tonal-spot' | 'expressive' | 'vibrant' | 'neutral';
export type ThemeMode = 'light' | 'dark' | 'auto';

export const DEFAULT_SEED = '#10B981';

export type ColorRole =
  | 'primary' | 'onPrimary' | 'primaryContainer' | 'onPrimaryContainer'
  | 'secondary' | 'onSecondary' | 'secondaryContainer' | 'onSecondaryContainer'
  | 'tertiary' | 'onTertiary' | 'tertiaryContainer' | 'onTertiaryContainer'
  | 'error' | 'onError' | 'errorContainer' | 'onErrorContainer'
  | 'background' | 'onBackground'
  | 'surface' | 'onSurface'
  | 'surfaceDim' | 'surfaceBright'
  | 'surfaceContainerLowest' | 'surfaceContainerLow' | 'surfaceContainer'
  | 'surfaceContainerHigh' | 'surfaceContainerHighest'
  | 'surfaceVariant' | 'onSurfaceVariant'
  | 'outline' | 'outlineVariant'
  | 'inverseSurface' | 'inverseOnSurface' | 'inversePrimary'
  | 'scrim' | 'shadow';

export type ColorTokens = Record<ColorRole, string>;

const STYLE_MAP: Record<PaletteStyle, new (hct: Hct, isDark: boolean, contrast: number) => any> = {
  classic: SchemeFidelity,
  'tonal-spot': SchemeTonalSpot,
  expressive: SchemeExpressive,
  vibrant: SchemeVibrant,
  neutral: SchemeNeutral,
};

export function generateColorTokens(seed: string, style: PaletteStyle, dark: boolean, contrastLevel = 0): ColorTokens {
  let hct: Hct;
  try {
    hct = Hct.fromInt(argbFromHex(seed));
  } catch {
    hct = Hct.fromInt(argbFromHex(DEFAULT_SEED));
  }
  const Ctor = STYLE_MAP[style] ?? SchemeTonalSpot;
  const scheme = new Ctor(hct, dark, contrastLevel);
  const roles: ColorRole[] = [
    'primary', 'onPrimary', 'primaryContainer', 'onPrimaryContainer',
    'secondary', 'onSecondary', 'secondaryContainer', 'onSecondaryContainer',
    'tertiary', 'onTertiary', 'tertiaryContainer', 'onTertiaryContainer',
    'error', 'onError', 'errorContainer', 'onErrorContainer',
    'background', 'onBackground',
    'surface', 'onSurface',
    'surfaceDim', 'surfaceBright',
    'surfaceContainerLowest', 'surfaceContainerLow', 'surfaceContainer',
    'surfaceContainerHigh', 'surfaceContainerHighest',
    'surfaceVariant', 'onSurfaceVariant',
    'outline', 'outlineVariant',
    'inverseSurface', 'inverseOnSurface', 'inversePrimary',
    'scrim', 'shadow',
  ];
  const out = {} as ColorTokens;
  for (const role of roles) {
    const value = (scheme as any)[role];
    out[role] = typeof value === 'number' ? hexFromArgb(value) : String(value);
  }
  // Contrast enforcement: ensure on-colors meet 4.5:1 on their containers by nudging tone.
  return enforceContrast(out);
}

// Simple contrast enforcement: if an on-color fails 4.5:1 against its container/background,
// swap to a safer fallback. We approximate by checking luminance contrast.
function relativeLuminance(hex: string): number {
  const c = hex.replace('#', '');
  const r = parseInt(c.slice(0, 2), 16) / 255;
  const g = parseInt(c.slice(2, 4), 16) / 255;
  const b = parseInt(c.slice(4, 6), 16) / 255;
  const toLinear = (v: number) => (v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4));
  return 0.2126 * toLinear(r) + 0.7152 * toLinear(g) + 0.0722 * toLinear(b);
}

function contrastRatio(a: string, b: string): number {
  const la = relativeLuminance(a);
  const lb = relativeLuminance(b);
  const lighter = Math.max(la, lb);
  const darker = Math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

function enforceContrast(tokens: ColorTokens): ColorTokens {
  const pairs: [keyof ColorTokens, keyof ColorTokens, number][] = [
    ['onPrimary', 'primary', 4.5],
    ['onPrimaryContainer', 'primaryContainer', 4.5],
    ['onSecondary', 'secondary', 4.5],
    ['onSecondaryContainer', 'secondaryContainer', 4.5],
    ['onTertiary', 'tertiary', 4.5],
    ['onTertiaryContainer', 'tertiaryContainer', 4.5],
    ['onError', 'error', 4.5],
    ['onErrorContainer', 'errorContainer', 4.5],
    ['onBackground', 'background', 4.5],
    ['onSurface', 'surface', 4.5],
    ['onSurfaceVariant', 'surfaceVariant', 4.5],
    ['inverseOnSurface', 'inverseSurface', 4.5],
  ];
  const out = { ...tokens };
  for (const [onKey, containerKey, min] of pairs) {
    const onColor = out[onKey];
    const container = out[containerKey];
    if (contrastRatio(onColor, container) < min) {
      // Fall back to pure black/white depending on luminance of container.
      out[onKey] = relativeLuminance(container) > 0.5 ? '#000000' : '#FFFFFF';
    }
  }
  // Large text/UI components: 3:1 for outline on surface (approx).
  return out;
}

export function hexToArgb(hex: string): number {
  return argbFromHex(hex);
}

function parseHexRgb(hex: string): [number, number, number] | null {
  const match = hex.trim().match(/^#?([0-9a-f]{6})$/i);
  if (!match) return null;
  return [
    parseInt(match[1].slice(0, 2), 16),
    parseInt(match[1].slice(2, 4), 16),
    parseInt(match[1].slice(4, 6), 16),
  ];
}

export function withAlpha(hex: string, alpha: number): string {
  const rgb = parseHexRgb(hex);
  if (!rgb) return hex;
  const clamped = Math.min(1, Math.max(0, alpha));
  return `rgba(${rgb[0]}, ${rgb[1]}, ${rgb[2]}, ${Number(clamped.toFixed(3))})`;
}

export function mixHex(a: string, b: string, amount: number): string {
  const first = parseHexRgb(a);
  const second = parseHexRgb(b);
  if (!first) return a;
  if (!second) return a;
  const clamped = Math.min(1, Math.max(0, amount));
  return `#${first
    .map((value, index) =>
      Math.round(value + (second[index] - value) * clamped)
        .toString(16)
        .padStart(2, '0'),
    )
    .join('')}`;
}

export function readableInk(background: string): '#000000' | '#FFFFFF' {
  const bg = parseHexRgb(background);
  if (!bg) return '#000000';
  const light = contrastRatio('#FFFFFF', background);
  const dark = contrastRatio('#000000', background);
  return light >= dark ? '#FFFFFF' : '#000000';
}