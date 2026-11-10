import {
  appendUnique,
  entryFromMediaItem,
  filterQueueIds,
  mediaItemFor,
  moveItem,
  playNext,
  removeItemAt,
} from '../src/playback/queue';
import type { Track } from '../src/types/music';

const track: Track = {
  id: 't1',
  title: 'Nikes',
  artist: 'Frank Ocean',
  album: 'Blonde',
  uri: 'file:///Music/Blonde/01 Nikes.mp3',
  duration: 300,
  artwork: 'file:///art.jpg',
};

describe('queue entries', () => {
  test('maps a track to a media item with a stable media id', () => {
    expect(mediaItemFor(track)).toEqual({
      mediaId: 't1',
      url: 'file:///Music/Blonde/01 Nikes.mp3',
      title: 'Nikes',
      artist: 'Frank Ocean',
      albumTitle: 'Blonde',
      duration: 300,
      artworkUrl: 'file:///art.jpg',
    });
  });

  test('falls back when engine metadata is missing', () => {
    expect(entryFromMediaItem({ url: 'file:///x.mp3' })).toEqual({
      mediaId: 'file:///x.mp3',
      title: 'Untitled track',
      artist: 'Unknown artist',
      artwork: null,
    });
  });

  test('keeps only ids the library still has, in order', () => {
    expect(filterQueueIds(['a', 'b', 'c'], new Set(['c', 'a']))).toEqual(['a', 'c']);
  });
});

describe('queue order helpers', () => {
  test('moves an item and leaves out-of-range or same-index calls untouched', () => {
    expect(moveItem(['a', 'b', 'c'], 0, 2)).toEqual(['b', 'c', 'a']);
    expect(moveItem(['a', 'b', 'c'], 2, 0)).toEqual(['c', 'a', 'b']);
    const ids = ['a', 'b'];
    expect(moveItem(ids, 1, 1)).toBe(ids);
    expect(moveItem(ids, -1, 0)).toBe(ids);
    expect(moveItem(ids, 0, 5)).toBe(ids);
  });

  test('removes at an index and no-ops out of range', () => {
    expect(removeItemAt(['a', 'b', 'c'], 1)).toEqual(['a', 'c']);
    const ids = ['a'];
    expect(removeItemAt(ids, 3)).toBe(ids);
  });

  test('appends once and no-ops for an id already queued', () => {
    expect(appendUnique(['a'], 'b')).toEqual(['a', 'b']);
    const ids = ['a'];
    expect(appendUnique(ids, 'a')).toBe(ids);
  });

  test('inserts play-next straight after the active item', () => {
    expect(playNext(['a', 'b', 'c'], 0, 'x')).toEqual({ ids: ['a', 'x', 'b', 'c'], index: 1 });
  });

  test('moves an already-queued track next instead of duplicating it', () => {
    // 'c' is queued last while 'a' plays: it should move, not appear twice.
    expect(playNext(['a', 'b', 'c'], 0, 'c')).toEqual({ ids: ['a', 'c', 'b'], index: 1 });
  });

  test('moves a queued track that sits before the active one', () => {
    // 'a' is queued while 'c' plays: removing it shifts the anchor back one.
    expect(playNext(['a', 'b', 'c'], 2, 'a')).toEqual({ ids: ['b', 'c', 'a'], index: 2 });
  });

  test('no-ops when the active track itself is requested next', () => {
    const ids = ['a', 'b'];
    expect(playNext(ids, 0, 'a')).toEqual({ ids, index: -1 });
  });

  test('starts a queue from empty', () => {
    expect(playNext([], -1, 'x')).toEqual({ ids: ['x'], index: 0 });
  });
});
