export type Track = {
  id: string;
  title: string;
  artist: string;
  album: string;
  albumArtist?: string | null;
  year?: string | null;
  genre?: string | null;
  trackNumber?: string | null;
  discNumber?: string | null;
  uri: string;
  duration: number;
  artwork?: string | null;
  /** MediaStore creation time (ms), used by Recently added. */
  addedAt?: number;
};

export type Album = {
  id: string;
  title: string;
  artist: string;
  albumArtist: string;
  year: string | null;
  artwork: string | null;
  trackIds: string[];
  duration: number;
  /** Newest track timestamp in the album (ms). */
  addedAt?: number;
};

export type Playlist = {
  id: string;
  name: string;
  trackIds: string[];
  createdAt: number;
  description?: string | null;
  artworkPath?: string | null;
  updatedAt?: number | null;
};

export type LibraryTab = 'songs' | 'albums' | 'artists' | 'genres' | 'favorites';

export type SongSort = 'title' | 'artist' | 'album' | 'duration';
export type AlbumSort = 'title' | 'artist' | 'year' | 'tracks';
