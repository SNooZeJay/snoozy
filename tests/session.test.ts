import {
  parsePlaybackSession,
  resolvePlaybackSession,
  serializePlaybackSession,
} from '../src/playback/session';
import type { Track } from '../src/types/music';

const t1: Track = {
  id: 't1',
  title: 'Nikes',
  artist: 'Frank Ocean',
  album: 'Blonde',
  uri: 'file:///Music/01.mp3',
  duration: 300,
  artwork: null,
};

const t2: Track = {
  id: 't2',
  title: 'Ivy',
  artist: 'Frank Ocean',
  album: 'Blonde',
  uri: 'file:///Music/02.mp3',
  duration: 249,
  artwork: null,
};

const t3: Track = {
  id: 't3',
  title: 'Pink + White',
  artist: 'Frank Ocean',
  album: 'Blonde',
  uri: 'file:///Music/03.mp3',
  duration: 184,
  artwork: null,
};

describe('playback session persistence and resolution', () => {
  test('round-trips a valid session through JSON and resolves active track and position', () => {
    const raw = serializePlaybackSession({
      activeTrackId: 't2',
      queueIds: ['t1', 't2', 't3'],
      queueIndex: 1,
      positionSeconds: 42.5,
      shuffle: true,
      repeatMode: 'all',
      updatedAt: 1700000000000,
    });

    const parsed = parsePlaybackSession(raw);
    expect(parsed).not.toBeNull();

    const tracksById = new Map<string, Track>([
      ['t1', t1],
      ['t2', t2],
      ['t3', t3],
    ]);

    const resolved = resolvePlaybackSession(parsed, tracksById);
    expect(resolved).toEqual({
      activeTrack: t2,
      activeIndex: 1,
      queueTracks: [t1, t2, t3],
      queueIds: ['t1', 't2', 't3'],
      positionSeconds: 42.5,
      shuffle: true,
      repeatMode: 'all',
    });
  });

  test('advances to the next surviving queued track at 0:00 when the active track was deleted', () => {
    const parsed = parsePlaybackSession(
      serializePlaybackSession({
        activeTrackId: 't2',
        queueIds: ['t1', 't2', 't3'],
        queueIndex: 1,
        positionSeconds: 88,
        shuffle: false,
        repeatMode: 'off',
      }),
    );

    const tracksById = new Map<string, Track>([
      ['t1', t1],
      ['t3', t3],
    ]);

    const resolved = resolvePlaybackSession(parsed, tracksById);
    expect(resolved).toEqual({
      activeTrack: t3,
      activeIndex: 1,
      queueTracks: [t1, t3],
      queueIds: ['t1', 't3'],
      positionSeconds: 0,
      shuffle: false,
      repeatMode: 'off',
    });
  });

  test('falls back to the last surviving track when the deleted active track was at the tail', () => {
    const parsed = parsePlaybackSession(
      serializePlaybackSession({
        activeTrackId: 't3',
        queueIds: ['t1', 't2', 't3'],
        queueIndex: 2,
        positionSeconds: 50,
        shuffle: false,
        repeatMode: 'one',
      }),
    );

    const tracksById = new Map<string, Track>([
      ['t1', t1],
      ['t2', t2],
    ]);

    const resolved = resolvePlaybackSession(parsed, tracksById);
    expect(resolved).toEqual({
      activeTrack: t2,
      activeIndex: 1,
      queueTracks: [t1, t2],
      queueIds: ['t1', 't2'],
      positionSeconds: 0,
      shuffle: false,
      repeatMode: 'one',
    });
  });

  test('returns null when all queued tracks have been deleted', () => {
    const parsed = parsePlaybackSession(
      serializePlaybackSession({
        activeTrackId: 't1',
        queueIds: ['t1', 't2'],
        queueIndex: 0,
        positionSeconds: 15,
        shuffle: false,
        repeatMode: 'off',
      }),
    );

    const resolved = resolvePlaybackSession(parsed, new Map());
    expect(resolved).toBeNull();
  });

  test('clamps negative, non-finite, or over-duration positions safely', () => {
    const tracksById = new Map<string, Track>([['t1', t1]]);

    const overDuration = parsePlaybackSession(
      serializePlaybackSession({
        activeTrackId: 't1',
        queueIds: ['t1'],
        queueIndex: 0,
        positionSeconds: 999,
        shuffle: false,
        repeatMode: 'off',
      }),
    );
    expect(resolvePlaybackSession(overDuration, tracksById)?.positionSeconds).toBe(300);

    const negativePosition = parsePlaybackSession(
      serializePlaybackSession({
        activeTrackId: 't1',
        queueIds: ['t1'],
        queueIndex: 0,
        positionSeconds: -12,
        shuffle: false,
        repeatMode: 'off',
      }),
    );
    expect(resolvePlaybackSession(negativePosition, tracksById)?.positionSeconds).toBe(0);
  });

  test('rejects corrupt JSON, wrong version, and empty queues', () => {
    expect(parsePlaybackSession(null)).toBeNull();
    expect(parsePlaybackSession('')).toBeNull();
    expect(parsePlaybackSession('{not-valid-json')).toBeNull();
    expect(parsePlaybackSession(JSON.stringify({ version: 2, queueIds: ['t1'] }))).toBeNull();
    expect(
      parsePlaybackSession(
        JSON.stringify({
          version: 1,
          activeTrackId: 't1',
          queueIds: [],
          queueIndex: 0,
          positionSeconds: 0,
          shuffle: false,
          repeatMode: 'off',
        }),
      ),
    ).toBeNull();
  });
});
