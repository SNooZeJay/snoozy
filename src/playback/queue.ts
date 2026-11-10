import type { MediaItem } from '@rntp/player';

import type { Track } from '../types/music';

/** What the queue sheet needs to render a playing-session item. */
export type QueueEntry = {
  mediaId: string;
  title: string;
  artist: string;
  artwork: string | null;
};

export function mediaItemFor(track: Track): MediaItem {
  return {
    mediaId: track.id,
    url: track.uri,
    title: track.title,
    artist: track.artist,
    albumTitle: track.album,
    duration: track.duration,
    artworkUrl: track.artwork ?? undefined,
  };
}

function urlOf(item: MediaItem): string {
  if (typeof item.url === 'string') return item.url;
  if (typeof item.url === 'number') return String(item.url);
  const uri = item.url?.uri;
  return typeof uri === 'string' ? uri : '';
}

export function entryFromMediaItem(item: MediaItem): QueueEntry {
  const url = urlOf(item);
  return {
    mediaId: item.mediaId ?? (url || 'unknown'),
    title: item.title ?? 'Untitled track',
    artist: item.artist ?? 'Unknown artist',
    artwork: typeof item.artworkUrl === 'string' ? item.artworkUrl : null,
  };
}

/** No-op calls return the same array so callers can skip state updates. */
export function moveItem<T>(items: T[], from: number, to: number): T[] {
  if (from === to) return items;
  if (from < 0 || to < 0 || from >= items.length || to >= items.length) return items;
  const next = [...items];
  const [moved] = next.splice(from, 1);
  next.splice(to, 0, moved);
  return next;
}

export function removeItemAt<T>(items: T[], index: number): T[] {
  if (index < 0 || index >= items.length) return items;
  return [...items.slice(0, index), ...items.slice(index + 1)];
}

export function appendUnique(ids: string[], id: string): string[] {
  return ids.includes(id) ? ids : [...ids, id];
}

/**
 * The list the engine should end up with for play-next, plus the index the
 * id must be inserted at. Returns `index: -1` when the id is already playing.
 */
export function playNext(
  ids: string[],
  activeIndex: number,
  id: string,
): { ids: string[]; index: number } {
  const activeId = activeIndex >= 0 && activeIndex < ids.length ? ids[activeIndex] : null;
  if (activeId === id) return { ids, index: -1 };

  const without = ids.filter((item) => item !== id);
  const anchor = activeId ? without.indexOf(activeId) : -1;
  const index = anchor >= 0 ? anchor + 1 : 0;
  return {
    ids: [...without.slice(0, index), id, ...without.slice(index)],
    index,
  };
}

export function filterQueueIds(ids: string[], libraryIds: ReadonlySet<string>): string[] {
  return ids.filter((id) => libraryIds.has(id));
}
