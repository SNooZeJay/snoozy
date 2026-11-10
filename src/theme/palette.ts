import { colors } from './tokens';

export type ArtworkPalette = {
  accent: string;
  accentStrong: string;
  accentInk: string;
  glow: string;
};

export const defaultPalette: ArtworkPalette = {
  accent: colors.accent,
  accentStrong: colors.accentStrong,
  accentInk: colors.accentInk,
  glow: 'rgba(255, 55, 95, 0.22)',
};

function parseHex(value: string): [number, number, number] | null {
  const match = value.trim().match(/^#?([0-9a-f]{6})$/i);
  if (!match) return null;
  const hex = match[1];
  return [
    parseInt(hex.slice(0, 2), 16),
    parseInt(hex.slice(2, 4), 16),
    parseInt(hex.slice(4, 6), 16),
  ];
}

function toHex(rgb: [number, number, number]) {
  return `#${rgb.map((value) => Math.round(value).toString(16).padStart(2, '0')).join('')}`;
}

function mix(
  from: [number, number, number],
  to: [number, number, number],
  amount: number,
): [number, number, number] {
  const clamp = Math.min(1, Math.max(0, amount));
  return [
    from[0] + (to[0] - from[0]) * clamp,
    from[1] + (to[1] - from[1]) * clamp,
    from[2] + (to[2] - from[2]) * clamp,
  ];
}

function luminance(rgb: [number, number, number]) {
  const channel = (value: number) => {
    const normalized = value / 255;
    return normalized <= 0.03928
      ? normalized / 12.92
      : ((normalized + 0.055) / 1.055) ** 2.4;
  };
  return 0.2126 * channel(rgb[0]) + 0.7152 * channel(rgb[1]) + 0.0722 * channel(rgb[2]);
}

function contrast(a: [number, number, number], b: [number, number, number]) {
  const first = luminance(a);
  const second = luminance(b);
  return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05);
}

export function paletteFromArtworkColor(source?: string | null): ArtworkPalette {
  const parsed = source ? parseHex(source) : null;
  if (!parsed) return defaultPalette;

  const white: [number, number, number] = [255, 255, 255];
  const dark: [number, number, number] = [7, 17, 13];
  const light: [number, number, number] = [243, 240, 228];
  const accentRgb = mix(parsed, white, 0.45);
  const accentStrongRgb = mix(parsed, white, 0.18);
  const accentInk = contrast(accentRgb, dark) >= contrast(accentRgb, light) ? dark : light;

  return {
    accent: toHex(accentRgb),
    accentStrong: toHex(accentStrongRgb),
    accentInk: toHex(accentInk),
    glow: `rgba(${Math.round(accentRgb[0])}, ${Math.round(accentRgb[1])}, ${Math.round(accentRgb[2])}, 0.22)`,
  };
}
