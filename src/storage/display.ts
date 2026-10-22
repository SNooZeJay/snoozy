import type { Track } from '../types/music';
import { getTrackOverride, getAlbumOverride, getArtistOverride } from './metadata';

export type TrackDisplay = {
  title: string;
  artist: string;
  album: string;
  albumArtist: string;
  genre: string;
  year: string;
  trackNumber: string;
  description: string;
  artwork: string | null;
};

export async function resolveTrackDisplay(track: Track): Promise<TrackDisplay> {
  const o = await getTrackOverride(track.id);
  const fallbackTitle = track.title || track.uri.split('/').pop()?.replace(/\.[^.]+$/, '') || 'Untitled';
  return {
    title: o?.title ?? fallbackTitle,
    artist: o?.artist ?? (track.artist || 'Unknown artist'),
    album: o?.album ?? (track.album || 'Unknown album'),
    albumArtist: o?.albumArtist ?? (track.artist || 'Unknown artist'),
    genre: o?.genre ?? '',
    year: o?.year ?? '',
    trackNumber: o?.trackNumber ?? '',
    description: o?.description ?? '',
    artwork: o?.artworkPath ?? track.artwork ?? null,
  };
}

export async function resolveAlbumDisplay(albumKey: string, fallbackTitle: string, fallbackArtist: string, fallbackArtwork: string | null) {
  const o = await getAlbumOverride(albumKey);
  return {
    title: o?.title ?? (fallbackTitle || 'Unknown album'),
    artist: o?.artist ?? (fallbackArtist || 'Unknown artist'),
    description: o?.description ?? '',
    artwork: o?.artworkPath ?? fallbackArtwork,
  };
}

export async function resolveArtistDisplay(artistKey: string, fallbackName: string, fallbackArtwork: string | null) {
  const o = await getArtistOverride(artistKey);
  return {
    name: o?.name ?? (fallbackName || 'Unknown artist'),
    description: o?.description ?? '',
    artwork: o?.artworkPath ?? fallbackArtwork,
  };
}