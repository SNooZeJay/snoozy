import * as FileSystem from 'expo-file-system/legacy';
import { createMMKV } from 'react-native-mmkv';
import { getArtwork, getMetadata } from 'react-native-audio-metadata';

import { stableHash } from './albumGrouping';

export type AudioAsset = {
  id: string;
  uri: string;
  filename: string;
  duration: number;
  modificationTime: number;
};

export type ScannedMetadata = {
  title: string;
  artist: string;
  album: string;
  albumArtist: string;
  year: string | null;
  genre: string | null;
  trackNumber: string | null;
  discNumber: string | null;
  duration: number;
};

type CacheEntry = {
  modified: number;
  value: ScannedMetadata;
};

type MetadataCache = Record<string, CacheEntry>;

const store = createMMKV({ id: 'snoozy.audio.v1' });
const CACHE_KEY = 'embedded-metadata.v1';
const ARTWORK_DIR = 'artwork/';

let cache: MetadataCache | null = null;
let cacheDirty = false;

function readCache(): MetadataCache {
  if (cache) return cache;
  try {
    const raw = store.getString(CACHE_KEY);
    cache = raw ? (JSON.parse(raw) as MetadataCache) : {};
  } catch {
    cache = {};
  }
  return cache;
}

export function persistMetadataCache(): void {
  if (!cache || !cacheDirty) return;
  try {
    store.set(CACHE_KEY, JSON.stringify(cache));
    cacheDirty = false;
  } catch {
    // Metadata cache is an optimization; the scan remains valid without it.
  }
}

export function pruneMetadataCache(assetIds: Set<string>): void {
  const next = readCache();
  for (const id of Object.keys(next)) {
    if (!assetIds.has(id)) {
      delete next[id];
      cacheDirty = true;
    }
  }
  cache = next;
}

export function filePathFromUri(uri: string): string {
  try {
    return decodeURIComponent(uri.replace(/^file:\/\//, ''));
  } catch {
    return uri.replace(/^file:\/\//, '');
  }
}

export function fallbackTitleFromFilename(filename: string): string {
  return filename
    .replace(/\.[^.]+$/, '')
    .replace(/^\d{1,3}[\s._-]+/, '')
    .replace(/[_-]+/g, ' ')
    .trim() || 'Untitled track';
}

function clean(value: string | undefined | null): string {
  return value?.trim() ?? '';
}

function metadataFromTags(
  tags: Awaited<ReturnType<typeof getMetadata>>,
  asset: AudioAsset,
  albumTitle: string,
): ScannedMetadata {
  const artist = clean(tags.artist) || 'Unknown artist';
  return {
    title: clean(tags.title) || fallbackTitleFromFilename(asset.filename),
    artist,
    album: clean(tags.album) || clean(albumTitle) || 'Unknown album',
    albumArtist: artist,
    year: clean(tags.year) || null,
    genre: clean(tags.genre) || null,
    trackNumber: null,
    discNumber: null,
    duration: typeof tags.duration === 'number' && tags.duration > 0
      ? tags.duration / 1000
      : Math.max(0, asset.duration || 0),
  };
}

export async function readAudioMetadata(
  asset: AudioAsset,
  albumTitle: string,
): Promise<ScannedMetadata | null> {
  const cacheValue = readCache()[asset.id];
  if (cacheValue && cacheValue.modified === asset.modificationTime) {
    return cacheValue.value;
  }

  const path = filePathFromUri(asset.uri);
  if (!path.startsWith('/')) return null;

  try {
    const tags = await getMetadata(path);
    const value = metadataFromTags(tags, asset, albumTitle);
    readCache()[asset.id] = { modified: asset.modificationTime, value };
    cacheDirty = true;
    return value;
  } catch {
    return null;
  }
}

function artworkDirectory(): string | null {
  return FileSystem.documentDirectory
    ? `${FileSystem.documentDirectory}${ARTWORK_DIR}`
    : null;
}

export async function resolveAlbumArtwork(
  uri: string,
  cacheKey: string,
): Promise<string | null> {
  const directory = artworkDirectory();
  if (!directory) return null;

  const target = `${directory}${cacheKey}.jpg`;
  try {
    const info = await FileSystem.getInfoAsync(target);
    if (info.exists) return target;
  } catch {
    // Fall through and extract again.
  }

  // Remember files that have no embedded cover. Re-extracting every scan is
  // expensive for albums that simply ship without artwork.
  const missMarker = `${directory}${cacheKey}.none`;
  try {
    const marker = await FileSystem.getInfoAsync(missMarker);
    if (marker.exists) return null;
  } catch {
    // Fall through and try extraction.
  }

  const path = filePathFromUri(uri);
  if (!path.startsWith('/')) return null;

  try {
    const dataUri = await getArtwork(path);
    await FileSystem.makeDirectoryAsync(directory, { intermediates: true });
    if (!dataUri) {
      await FileSystem.writeAsStringAsync(missMarker, '');
      return null;
    }

    const base64 = dataUri.includes(',') ? dataUri.slice(dataUri.indexOf(',') + 1) : dataUri;
    await FileSystem.writeAsStringAsync(target, base64, {
      encoding: FileSystem.EncodingType.Base64,
    });
    return target;
  } catch {
    return null;
  }
}

export function artworkCacheKey(albumKey: string, uri: string, modificationTime: number): string {
  return `${albumKey}-${stableHash(`${uri}:${modificationTime}`)}`;
}

export async function mapWithConcurrency<T, R>(
  items: T[],
  limit: number,
  mapper: (item: T, index: number) => Promise<R>,
): Promise<R[]> {
  const results = new Array<R>(items.length);
  let nextIndex = 0;

  async function worker() {
    while (nextIndex < items.length) {
      const index = nextIndex;
      nextIndex += 1;
      results[index] = await mapper(items[index], index);
    }
  }

  const workers = Array.from(
    { length: Math.min(Math.max(1, limit), items.length) },
    () => worker(),
  );
  await Promise.all(workers);
  return results;
}
