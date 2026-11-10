import type { LyricLine } from './lrc';

export function displayLyricLines(lines: LyricLine[]): LyricLine[] {
  return lines.filter((line) => line.text.trim().length > 0);
}

export function activeLyricIndex(
  lines: LyricLine[],
  progressMs: number,
  offsetMs: number,
): number {
  let active = -1;
  for (let i = 0; i < lines.length; i++) {
    const time = lines[i].time;
    if (time === null) continue;
    if (time + offsetMs <= progressMs) active = i;
    else break;
  }
  return active;
}
