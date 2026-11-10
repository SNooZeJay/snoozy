import {
  albumKeyFor,
  buildAlbums,
  sortAlbumTracks,
} from '../src/storage/albumGrouping';
import type { Track } from '../src/types/music';

function track(overrides: Partial<Track> & Pick<Track, 'id' | 'title' | 'uri'>): Track {
  return {
    artist: 'Unknown artist',
    album: 'Unknown album',
    duration: 60,
    ...overrides,
  };
}

describe('album grouping', () => {
  test('groups an album, keeps track order, cover, and duration', () => {
    const tracks = [
      track({
        id: 'b',
        title: 'Second',
        artist: 'Frank Ocean',
        album: 'Blonde',
        albumArtist: 'Frank Ocean',
        uri: 'file:///Music/Blonde/02 Second.mp3',
        trackNumber: '2',
        duration: 120,
        artwork: 'file:///art/blonde.jpg',
      }),
      track({
        id: 'a',
        title: 'Nikes',
        artist: 'Frank Ocean',
        album: 'Blonde',
        albumArtist: 'Frank Ocean',
        uri: 'file:///Music/Blonde/01 Nikes.mp3',
        trackNumber: '1',
        duration: 300,
        artwork: null,
      }),
    ];

    const albums = buildAlbums(tracks);

    expect(albums).toHaveLength(1);
    expect(albums[0].title).toBe('Blonde');
    expect(albums[0].artist).toBe('Frank Ocean');
    expect(albums[0].artwork).toBe('file:///art/blonde.jpg');
    expect(albums[0].duration).toBe(420);
    expect(albums[0].trackIds).toEqual(['a', 'b']);
  });

  test('keeps albums with the same title separate by album artist', () => {
    const albums = buildAlbums([
      track({
        id: 'one',
        title: 'Home',
        artist: 'Artist A',
        album: 'Home',
        uri: 'file:///Music/A/Home/01 Home.mp3',
      }),
      track({
        id: 'two',
        title: 'Home',
        artist: 'Artist B',
        album: 'Home',
        uri: 'file:///Music/B/Home/01 Home.mp3',
      }),
    ]);

    expect(albums).toHaveLength(2);
  });

  test('falls back to the track artist when the album artist is unknown', () => {
    const albums = buildAlbums([
      track({
        id: 'one',
        title: 'Nikes',
        artist: 'Frank Ocean',
        albumArtist: 'Unknown artist',
        album: 'Blonde',
        uri: 'file:///Music/Blonde/01 Nikes.mp3',
      }),
    ]);

    expect(albums).toHaveLength(1);
    expect(albums[0].artist).toBe('Frank Ocean');
  });

  test('falls back to the folder name when the album tag is missing', () => {
    const albums = buildAlbums([
      track({
        id: 'one',
        title: 'Track One',
        artist: 'Someone',
        album: 'Unknown album',
        uri: 'file:///storage/emulated/0/Music/Downloaded%20Album/01%20Track.mp3',
      }),
      track({
        id: 'two',
        title: 'Track Two',
        artist: 'Someone',
        album: '',
        uri: 'file:///storage/emulated/0/Music/Downloaded%20Album/02%20Track.mp3',
      }),
    ]);

    expect(albums).toHaveLength(1);
    expect(albums[0].title).toBe('Downloaded Album');
  });

  test('produces a stable album key for normalized names', () => {
    const first = albumKeyFor({
      album: '  Blonde ',
      albumArtist: 'Frank Ocean',
      artist: 'Frank Ocean',
      uri: 'file:///Music/Blonde/01 Nikes.mp3',
    });
    const second = albumKeyFor({
      album: 'blonde',
      albumArtist: 'frank ocean',
      artist: 'Frank Ocean',
      uri: 'file:///Music/Blonde/02 Ivy.mp3',
    });

    expect(first).toBe(second);
  });

  test('sorts unknown track numbers by filename number, then title', () => {
    const tracks = [
      track({
        id: 'three',
        title: 'Untitled',
        uri: 'file:///Music/Album/03 Untitled.mp3',
      }),
      track({
        id: 'one',
        title: 'Untitled',
        uri: 'file:///Music/Album/01 Untitled.mp3',
      }),
      track({
        id: 'two',
        title: 'Untitled',
        uri: 'file:///Music/Album/02 Untitled.mp3',
      }),
    ];

    expect(sortAlbumTracks(tracks).map((item) => item.id)).toEqual([
      'one',
      'two',
      'three',
    ]);
  });

  test('sorts by disc before track', () => {
    const tracks = [
      track({
        id: 'disc-2',
        title: 'Second disc',
        trackNumber: '1',
        discNumber: '2',
        uri: 'file:///Music/Album/d2/01.mp3',
      }),
      track({
        id: 'disc-1',
        title: 'First disc',
        trackNumber: '2',
        discNumber: '1',
        uri: 'file:///Music/Album/d1/02.mp3',
      }),
    ];

    expect(sortAlbumTracks(tracks).map((item) => item.id)).toEqual([
      'disc-1',
      'disc-2',
    ]);
  });
});
