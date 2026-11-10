import type { Album, Track } from '../types/music';

/** A track with its total plays from the on-device play history. */
export type PlayedTrack = {
  track: Track;
  plays: number;
};

type PlayEntry = {
  trackId: string;
};

/** Albums ordered by their newest track, with undated albums last. */
export function recentlyAdded(albums: Album[], limit: number): Album[] {
  return [...albums]
    .sort(
      (left, right) =>
        (right.addedAt ?? 0) - (left.addedAt ?? 0) ||
        left.title.localeCompare(right.title),
    )
    .slice(0, Math.max(0, limit));
}

/** Distinct, trimmed genre names in display order. */
export function genresOf(tracks: Track[]): string[] {
  const seen = new Map<string, string>();
  for (const track of tracks) {
    const genre = track.genre?.trim();
    if (!genre) continue;
    const key = genre.toLowerCase();
    if (!seen.has(key)) seen.set(key, genre);
  }
  return [...seen.values()].sort((left, right) => left.localeCompare(right));
}

/** Aggregates play history into the most-played tracks that still exist. */
export function topPlayedTracks(
  tracks: Track[],
  history: PlayEntry[],
  limit: number,
): PlayedTrack[] {
  const counts = new Map<string, number>();
  for (const entry of history) {
    counts.set(entry.trackId, (counts.get(entry.trackId) ?? 0) + 1);
  }

  const byId = new Map(tracks.map((track) => [track.id, track]));
  return [...counts.entries()]
    .map(([id, plays]) => ({ track: byId.get(id), plays }))
    .filter((entry): entry is PlayedTrack => Boolean(entry.track))
    .sort(
      (left, right) =>
        right.plays - left.plays ||
        left.track.title.localeCompare(right.track.title),
    )
    .slice(0, Math.max(0, limit));
}
