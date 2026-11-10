import {
  nextRepeatState,
  randomStartIndex,
} from '../src/playback/controls';

test('cycles repeat off to all to one and back off', () => {
  expect(nextRepeatState('off')).toBe('all');
  expect(nextRepeatState('all')).toBe('one');
  expect(nextRepeatState('one')).toBe('off');
});

test('picks a valid shuffled start track', () => {
  expect(randomStartIndex(0, () => 0.5)).toBe(0);
  expect(randomStartIndex(5, () => 0)).toBe(0);
  expect(randomStartIndex(5, () => 0.999)).toBe(4);
  expect(randomStartIndex(5, () => 1)).toBe(4);
});
