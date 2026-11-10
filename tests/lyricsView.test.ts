import {
  activeLyricIndex,
  displayLyricLines,
} from '../src/lyrics/view';
import type { LyricLine } from '../src/lyrics/lrc';

describe('lyrics view', () => {
  test('drops blank lyric rows before display', () => {
    const lines: LyricLine[] = [
      { time: null, text: '' },
      { time: 1000, text: 'Poolside convo' },
      { time: 2000, text: '   ' },
      { time: 3000, text: 'Keep a place for me' },
    ];

    expect(displayLyricLines(lines)).toEqual([
      { time: 1000, text: 'Poolside convo' },
      { time: 3000, text: 'Keep a place for me' },
    ]);
  });

  test('finds the active line using the saved sync offset', () => {
    const lines: LyricLine[] = [
      { time: 1000, text: 'one' },
      { time: 5000, text: 'two' },
      { time: 9000, text: 'three' },
    ];

    expect(activeLyricIndex(lines, 0, 0)).toBe(-1);
    expect(activeLyricIndex(lines, 4000, 0)).toBe(0);
    expect(activeLyricIndex(lines, 6000, 1000)).toBe(1);
    expect(activeLyricIndex(lines, 4000, -500)).toBe(0);
  });
});
