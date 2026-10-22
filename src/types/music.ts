export type Track = {
  id: string;
  title: string;
  artist: string;
  album: string;
  uri: string;
  duration: number;
  artwork?: string | null;
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

export type LibraryTab = 'songs' | 'albums' | 'artists' | 'playlists';