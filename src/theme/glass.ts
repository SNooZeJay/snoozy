/**
 * Cupertino Liquid Glass tokens (inspired by Glasmio & iOS 26 materials).
 *
 * Layered translucent acrylic fill, 0.5pt hairline rim, top-left specular
 * reflection, and diffused elevation shadow.
 */
export const glass = {
  tint: 'rgba(28, 28, 30, 0.76)',
  tintStrong: 'rgba(38, 38, 42, 0.88)',
  tintSoft: 'rgba(118, 118, 128, 0.22)',
  tintDeep: 'rgba(18, 18, 20, 0.82)',
  tintAccent: 'rgba(255, 55, 95, 0.16)',
  buttonTint: 'rgba(44, 44, 46, 0.72)',
  fieldTint: 'rgba(118, 118, 128, 0.24)',
  edge: 'rgba(255, 255, 255, 0.14)',
  edgeStrong: 'rgba(255, 255, 255, 0.24)',
  edgeSoft: 'rgba(255, 255, 255, 0.08)',
  highlight: 'rgba(255, 255, 255, 0.16)',
  highlightSoft: 'rgba(255, 255, 255, 0.06)',
  highlightEdge: 'rgba(255, 255, 255, 0.03)',
  shadow: 'rgba(0, 0, 0, 0.28)',
  shadowDeep: 'rgba(0, 0, 0, 0.44)',
  innerGlow: 'rgba(255, 255, 255, 0.06)',
  scrim: 'rgba(0, 0, 0, 0.48)',
} as const;

export const glassShadow = {
  card: {
    shadowColor: glass.shadowDeep,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.2,
    shadowRadius: 16,
    elevation: 4,
  },
  floating: {
    shadowColor: glass.shadowDeep,
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.36,
    shadowRadius: 24,
    elevation: 14,
  },
  button: {
    shadowColor: glass.shadow,
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.18,
    shadowRadius: 8,
    elevation: 3,
  },
} as const;

export const glassVariants = {
  card: {
    tint: glass.tint,
    edge: glass.edge,
    radius: 16,
    highlight: true,
    shadow: glassShadow.card,
  },
  panel: {
    tint: glass.tintStrong,
    edge: glass.edgeStrong,
    radius: 24,
    highlight: true,
    shadow: glassShadow.floating,
  },
  row: {
    tint: glass.tint,
    edge: glass.edgeSoft,
    radius: 14,
    highlight: false,
    shadow: null,
  },
  pill: {
    tint: glass.tintStrong,
    edge: glass.edgeStrong,
    radius: 999,
    highlight: true,
    shadow: glassShadow.floating,
  },
  button: {
    tint: glass.buttonTint,
    edge: glass.edge,
    radius: 22,
    highlight: true,
    shadow: glassShadow.button,
  },
  field: {
    tint: glass.fieldTint,
    edge: glass.edgeSoft,
    radius: 12,
    highlight: false,
    shadow: null,
  },
} as const;

export type GlassVariant = keyof typeof glassVariants;
