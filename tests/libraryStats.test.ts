import { buildAlbums } from '../src/storage/albumGrouping';
import {
  genresOf,
  recentlyAdded,
  topPlayedTracks,
} from '../src/storage/libraryStats';
import type { Track } from '../src/types/music';

function track(overrides: Partial<Track> & Pick<Track, 'id' | 'title' | 'uri'>): Track {
  return {
    artist: 'Unknown artist',
    album: 'Unknown album',
    duration: 60,
    ...overrides,
  };
}

describe('recentlyAdded', () => {
  test('orders albums by their newest track and respects the limit', () => {
    const albums = buildAlbums([
      track({ id: 'a1', title: 'Old', album: 'Old', uri: 'file:///a1.mp3', addedAt: 10 }),
      track({ id: 'b1', title: 'New', album: 'New', uri: 'file:///b1.mp3', addedAt: 300 }),
      track({ id: 'c1', title: 'Mid', album: 'Mid', uri: 'file:///c1.mp3', addedAt: 100 }),
    ]);

    expect(recentlyAdded(albums, 2).map((album) => album.title)).toEqual(['New', 'Mid']);
  });

  test('keeps albums without a timestamp after dated albums', () => {
    const albums = buildAlbums([
      track({ id: 'x', title: 'Unknown', album: 'Unknown', uri: 'file:///x.mp3' }),
      track({ id: 'y', title: 'Known', album: 'Known', uri: 'file:///y.mp3', addedAt: 5 }),
    ]);

    expect(recentlyAdded(albums, 5).map((album) => album.title)).toEqual(['Known', 'Unknown']);
  });
});

describe('genresOf', () => {
  test('trims, deduplicates case-insensitively, and sorts', () => {
    const genres = genresOf([
      track({ id: '1', title: 'One', uri: 'file:///1.mp3', genre: ' Rock ' }),
      track({ id: '2', title: 'Two', uri: 'file:///2.mp3', genre: 'rock' }),
      track({ id: '3', title: 'Three', uri: 'file:///3.mp3', genre: 'Jazz' }),
      track({ id: '4', title: 'Four', uri: 'file:///4.mp3', genre: null }),
    ]);

    expect(genres).toEqual(['Jazz', 'Rock']);
  });
});

describe('topPlayedTracks', () => {
  test('aggregates plays, ignores unknown ids, and caps the result', () => {
    const tracks = [
      track({ id: 'a', title: 'Alpha', uri: 'file:///a.mp3' }),
      track({ id: 'b', title: 'Beta', uri: 'file:///b.mp3' }),
      track({ id: 'c', title: 'Gamma', uri: 'file:///c.mp3' }),
    ];
    const history = [
      { trackId: 'a', playedAt: 1, durationListenedMs: 1000 },
      { trackId: 'a', playedAt: 2, durationListenedMs: 1000 },
      { trackId: 'b', playedAt: 3, durationListenedMs: 1000 },
      { trackId: 'b', playedAt: 4, durationListenedMs: 1000 },
      { trackId: 'missing', playedAt: 5, durationListenedMs: 1000 },
    ];

    expect(topPlayedTracks(tracks, history, 2)).toEqual([
      { track: tracks[0], plays: 2 },
      { track: tracks[1], plays: 2 },
    ]);
    expect(topPlayedTracks(tracks, history, 3)).toHaveLength(2);
  });
});
