/**
 * Shared chrome motion math. Kept free of React and Reanimated imports so the
 * thresholds stay unit-testable; the values are also safe to call in worklets.
 */
export const COLLAPSE_START = 8;
export const COLLAPSE_END = 52;
export const SHEET_DISMISS_DISTANCE = 96;
export const SHEET_DISMISS_VELOCITY = 900;

export function collapseProgress(offset: number): number {
  'worklet';
  if (!Number.isFinite(offset) || offset <= COLLAPSE_START) return 0;
  if (offset >= COLLAPSE_END) return 1;
  return (offset - COLLAPSE_START) / (COLLAPSE_END - COLLAPSE_START);
}

export function shouldDismissSheet(translationY: number, velocityY: number): boolean {
  'worklet';
  return translationY > SHEET_DISMISS_DISTANCE || velocityY > SHEET_DISMISS_VELOCITY;
}
