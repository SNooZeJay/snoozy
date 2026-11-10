import { libraryFingerprint } from '../src/storage/libraryFingerprint';

test('fingerprint changes when a track is added or edited', () => {
  expect(libraryFingerprint(19, 100)).toBe('19:100');
  expect(libraryFingerprint(19, 100)).not.toBe(libraryFingerprint(20, 100));
  expect(libraryFingerprint(19, 100)).not.toBe(libraryFingerprint(19, 200));
});
