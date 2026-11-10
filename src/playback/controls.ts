export type RepeatState = 'off' | 'all' | 'one';

export function nextRepeatState(current: RepeatState): RepeatState {
  if (current === 'off') return 'all';
  if (current === 'all') return 'one';
  return 'off';
}

/** Picks the first track when shuffle starts, with a testable random source. */
export function randomStartIndex(
  length: number,
  random: () => number = Math.random,
): number {
  if (length <= 0) return 0;
  const index = Math.floor(random() * length);
  return Math.min(length - 1, Math.max(0, index));
}
