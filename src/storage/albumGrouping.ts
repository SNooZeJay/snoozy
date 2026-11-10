import type { Album, Track } from '../types/music';

const UNKNOWN_ALBUM = 'unknown album';
const UNKNOWN_ARTIST = 'unknown artist';

function clean(value: string | null | undefined): string {
  return value?.trim() ?? '';
}

function normalize(value: string): string {
  return value.replace(/\s+/g, ' ').trim().toLowerCase();
}

export function stableHash(value: string): string {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(36);
}

function decodedPath(uri: string): string {
  try {
    return decodeURIComponent(uri.replace(/^file:\/\//, ''));
  } catch {
    return uri.replace(/^file:\/\//, '');
  }
}

export function folderNameForUri(uri: string): string {
  const parts = decodedPath(uri).split('/').filter(Boolean);
  return parts.length > 1 ? parts[parts.length - 2] : '';
}

export function albumTitleFor(track: Pick<Track, 'album' | 'uri'>): string {
  const album = clean(track.album);
  if (album && normalize(album) !== UNKNOWN_ALBUM) return album;
  return folderNameForUri(track.uri) || 'Unknown album';
}

function artistNameFor(track: Pick<Track, 'albumArtist' | 'artist'>): string {
  const albumArtist = clean(track.albumArtist);
  if (albumArtist && normalize(albumArtist) !== UNKNOWN_ARTIST) return albumArtist;

  const artist = clean(track.artist);
  return artist && normalize(artist) !== UNKNOWN_ARTIST ? artist : '';
}

export function albumKeyFor(
  track: Pick<Track, 'album' | 'albumArtist' | 'artist' | 'uri'>,
): string {
  const title = normalize(albumTitleFor(track));
  const artist = normalize(artistNameFor(track)) || normalize(folderNameForUri(track.uri));
  return `album-${stableHash(`${artist}::${title}`)}`;
}

function leadingNumber(value: string | null | undefined): number | null {
  const match = clean(value).match(/^(\d{1,3})(?:\D|$)/);
  return match ? Number(match[1]) : null;
}

export function trackNumberFor(track: Pick<Track, 'trackNumber' | 'uri'>): number | null {
  const tagged = leadingNumber(track.trackNumber);
  if (tagged !== null) return tagged;

  const filename = decodedPath(track.uri).split('/').pop() ?? '';
  return leadingNumber(filename);
}

export function discNumberFor(track: Pick<Track, 'discNumber' | 'uri'>): number | null {
  const tagged = leadingNumber(track.discNumber);
  if (tagged !== null) return tagged;

  return null;
}

export function sortAlbumTracks(tracks: Track[]): Track[] {
  return [...tracks].sort((left, right) => {
    const discDifference = (discNumberFor(left) ?? 0) - (discNumberFor(right) ?? 0);
    if (discDifference !== 0) return discDifference;

    const leftTrack = trackNumberFor(left);
    const rightTrack = trackNumberFor(right);
    if (leftTrack !== null && rightTrack !== null && leftTrack !== rightTrack) {
      return leftTrack - rightTrack;
    }
    if (leftTrack !== null && rightTrack === null) return -1;
    if (leftTrack === null && rightTrack !== null) return 1;

    return left.title.localeCompare(right.title);
  });
}

export function buildAlbums(tracks: Track[]): Album[] {
  const groups = new Map<string, Track[]>();

  for (const track of tracks) {
    const key = albumKeyFor(track);
    const group = groups.get(key);
    if (group) group.push(track);
    else groups.set(key, [track]);
  }

  return Array.from(groups, ([id, group]) => {
    const ordered = sortAlbumTracks(group);
    const first = ordered[0];
    const artists = group.map(artistNameFor).filter(Boolean);
    const albumArtist = artists[0] ?? 'Unknown artist';
    const year = group.map((track) => clean(track.year)).find(Boolean) ?? null;
    const artwork = group.find((track) => Boolean(track.artwork))?.artwork ?? null;
    const duration = group.reduce(
      (total, track) => total + (Number.isFinite(track.duration) ? track.duration : 0),
      0,
    );

    return {
      id,
      title: albumTitleFor(first),
      artist: albumArtist,
      albumArtist,
      year,
      artwork,
      trackIds: ordered.map((track) => track.id),
      duration,
      addedAt: group.reduce(
        (newest, track) => Math.max(newest, track.addedAt ?? 0),
        0,
      ),
    };
  }).sort((left, right) => (
    left.title.localeCompare(right.title) || left.artist.localeCompare(right.artist)
  ));
}
