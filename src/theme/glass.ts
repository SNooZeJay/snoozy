/**
 * Liquid Glass tokens.
 *
 * Android cannot render a live backdrop blur without a native module, so the
 * glass is built from layered translucency, a diagonal specular highlight, a
 * fine rim, and a soft shadow. The result reads as glass over the pine ground
 * while staying cheap enough for the A55.
 */
export const glass = {
  tint: 'rgba(19, 38, 28, 0.72)',
  tintStrong: 'rgba(27, 52, 39, 0.84)',
  tintSoft: 'rgba(13, 27, 20, 0.58)',
  tintDeep: 'rgba(7, 17, 13, 0.72)',
  tintAccent: 'rgba(216, 242, 198, 0.12)',
  buttonTint: 'rgba(27, 52, 39, 0.62)',
  fieldTint: 'rgba(13, 27, 20, 0.66)',
  edge: 'rgba(232, 242, 224, 0.16)',
  edgeStrong: 'rgba(243, 240, 228, 0.26)',
  edgeSoft: 'rgba(232, 242, 224, 0.10)',
  highlight: 'rgba(255, 255, 255, 0.13)',
  highlightSoft: 'rgba(255, 255, 255, 0.06)',
  highlightEdge: 'rgba(255, 255, 255, 0.03)',
  shadow: 'rgba(0, 0, 0, 0.34)',
  shadowDeep: 'rgba(0, 0, 0, 0.46)',
  innerGlow: 'rgba(216, 242, 198, 0.06)',
  scrim: 'rgba(4, 11, 8, 0.58)',
} as const;

export const glassShadow = {
  card: {
    shadowColor: glass.shadowDeep,
    shadowOffset: { width: 0, height: 14 },
    shadowOpacity: 0.28,
    shadowRadius: 26,
    elevation: 8,
  },
  floating: {
    shadowColor: glass.shadowDeep,
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.42,
    shadowRadius: 22,
    elevation: 16,
  },
  button: {
    shadowColor: glass.shadow,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.22,
    shadowRadius: 10,
    elevation: 4,
  },
} as const;

export const glassVariants = {
  card: {
    tint: glass.tint,
    edge: glass.edge,
    radius: 28,
    highlight: true,
    shadow: glassShadow.card,
  },
  panel: {
    tint: glass.tintStrong,
    edge: glass.edgeStrong,
    radius: 28,
    highlight: true,
    shadow: glassShadow.card,
  },
  row: {
    tint: glass.tint,
    edge: glass.edgeSoft,
    radius: 20,
    highlight: false,
    shadow: null,
  },
  pill: {
    tint: glass.tintStrong,
    edge: glass.edge,
    radius: 999,
    highlight: true,
    shadow: glassShadow.floating,
  },
  button: {
    tint: glass.buttonTint,
    edge: glass.edge,
    radius: 24,
    highlight: true,
    shadow: glassShadow.button,
  },
  field: {
    tint: glass.fieldTint,
    edge: glass.edge,
    radius: 999,
    highlight: true,
    shadow: glassShadow.button,
  },
} as const;

export type GlassVariant = keyof typeof glassVariants;
