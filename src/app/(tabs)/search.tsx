import Feather from '@expo/vector-icons/Feather';
import { router } from 'expo-router';
import { useMemo, useState } from 'react';
import {
  Pressable,
  SectionList,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Animated, { useAnimatedScrollHandler } from 'react-native-reanimated';
import { createMMKV } from 'react-native-mmkv';

import { AddToPlaylistSheet } from '../../components/AddToPlaylistSheet';
import { AppDialog } from '../../components/AppDialog';
import { AppText } from '../../components/AppText';
import { CoverArt, PlaylistCover } from '../../components/Artwork';
import { EmptyState } from '../../components/EmptyState';
import { GlassSurface } from '../../components/glass/GlassSurface';
import { ListGroup } from '../../components/ListGroup';
import { ListRow } from '../../components/ListRow';
import { ScreenHeader } from '../../components/ScreenHeader';
import { Thumb } from '../../components/Thumb';
import { useMusicLibrary } from '../../storage/MusicLibraryContext';
import { usePlayer } from '../../playback/PlayerContext';
import { usePreferences } from '../../storage/PreferencesContext';
import { tabScrollY } from '../../motion/scrollState';
import type { Album, Playlist, Track } from '../../types/music';
import {
  layout,
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  type AppTheme,
} from '../../theme';

const recentsStore = createMMKV({ id: 'snoozy.search.v1' });
const RECENTS_KEY = 'recentQueries';
const RECENTS_LIMIT = 5;

function normalizeText(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();
}

function readRecents(): string[] {
  try {
    const raw = recentsStore.getString(RECENTS_KEY);
    const parsed = raw ? (JSON.parse(raw) as string[]) : [];
    return Array.isArray(parsed) ? parsed.filter((q): q is string => typeof q === 'string') : [];
  } catch {
    return [];
  }
}

type SearchEntry =
  | { kind: 'recent'; query: string }
  | { kind: 'album'; album: Album }
  | { kind: 'artist'; name: string; count: number }
  | { kind: 'playlist'; playlist: Playlist; tracks: Track[] }
  | { kind: 'song'; track: Track };

type SearchSection = {
  title: string;
  actionLabel?: string;
  onAction?: () => void;
  data: SearchEntry[];
};

const AnimatedSectionList = Animated.createAnimatedComponent(
  SectionList,
) as unknown as typeof SectionList;

type GroupHeaderProps = {
  label: string;
  actionLabel?: string;
  onAction?: () => void;
};

function GroupHeader({ label, actionLabel, onAction }: GroupHeaderProps) {
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);

  return (
    <View style={styles.groupHeader}>
      <AppText variant="overline" color={palette.inkFaint} style={styles.groupLabel}>
        {label}
      </AppText>
      {actionLabel && onAction ? (
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={actionLabel}
          onPress={onAction}
          hitSlop={8}
          style={({ pressed }) => [styles.groupAction, { opacity: pressed ? 0.62 : 1 }]}
        >
          <AppText variant="label" color={palette.inkMuted}>{actionLabel}</AppText>
        </Pressable>
      ) : null}
    </View>
  );
}

export default function SearchScreen() {
  const library = useMusicLibrary();
  const player = usePlayer();
  const { tapFeedback } = usePreferences();
  const { palette, dark } = useTheme();
  const styles = useThemedStyles(createStyles);
  const onScroll = useAnimatedScrollHandler((event) => {
    tabScrollY.value = event.contentOffset.y;
  });
  const [query, setQuery] = useState('');
  const [recents, setRecents] = useState<string[]>(() => readRecents());
  const [songMenu, setSongMenu] = useState<Track | null>(null);
  const [addToSheetTrack, setAddToSheetTrack] = useState<Track | null>(null);

  const trimmed = query.trim();
  const needle = normalizeText(trimmed);

  const rememberQuery = (value: string) => {
    const q = value.trim();
    if (!q) return;
    const next = [q, ...readRecents().filter((item) => item.toLowerCase() !== q.toLowerCase())].slice(0, RECENTS_LIMIT);
    try {
      recentsStore.set(RECENTS_KEY, JSON.stringify(next));
    } catch {
      // Recents are a nicety; never block search on storage failures.
    }
    setRecents(next);
  };

  const results = useMemo(() => {
    if (!needle) return [];
    return library.displayTracks.filter((track) => {
      const raw = library.tracksById.get(track.id);
      const haystacks = [
        `${track.title} ${track.artist} ${track.album} ${track.albumArtist ?? ''} ${track.genre ?? ''}`,
        raw ? `${raw.title} ${raw.artist} ${raw.album} ${raw.albumArtist ?? ''} ${raw.genre ?? ''}` : '',
      ];
      return haystacks.some((haystack) => normalizeText(haystack).includes(needle));
    });
  }, [library.displayTracks, library.tracksById, needle]);

  const matchingAlbums = useMemo(() => {
    if (!needle) return [];
    return library.albums.filter((album) =>
      normalizeText(`${album.title} ${album.artist} ${album.albumArtist} ${album.year ?? ''}`).includes(needle),
    );
  }, [library.albums, needle]);

  const matchingArtists = useMemo(() => {
    if (!needle) return [];
    return library.artists.filter((artist) => normalizeText(artist).includes(needle));
  }, [library.artists, needle]);

  const matchingPlaylists = useMemo(() => {
    if (!needle) return [];
    return library.playlists.filter((playlist) => normalizeText(playlist.name).includes(needle));
  }, [library.playlists, needle]);

  const artistCounts = useMemo(() => {
    const counts = new Map<string, number>();
    for (const track of library.displayTracks) {
      counts.set(track.artist, (counts.get(track.artist) ?? 0) + 1);
    }
    return counts;
  }, [library.displayTracks]);

  const clearRecents = () => {
    try {
      recentsStore.set(RECENTS_KEY, JSON.stringify([]));
    } catch {
      // ignore
    }
    setRecents([]);
  };

  const sections = useMemo<SearchSection[]>(() => {
    if (!needle) {
      if (recents.length === 0) return [];
      return [{
        title: 'Recent searches',
        actionLabel: 'Clear',
        onAction: clearRecents,
        data: recents.map((recent) => ({ kind: 'recent' as const, query: recent })),
      }];
    }

    const next: SearchSection[] = [];
    if (matchingAlbums.length > 0) {
      next.push({
        title: `Albums · ${matchingAlbums.length}`,
        data: matchingAlbums.map((album) => ({ kind: 'album' as const, album })),
      });
    }
    if (matchingArtists.length > 0) {
      next.push({
        title: `Artists · ${matchingArtists.length}`,
        data: matchingArtists.map((name) => ({
          kind: 'artist' as const,
          name,
          count: artistCounts.get(name) ?? 0,
        })),
      });
    }
    if (matchingPlaylists.length > 0) {
      next.push({
        title: `Playlists · ${matchingPlaylists.length}`,
        data: matchingPlaylists.map((playlist) => ({
          kind: 'playlist' as const,
          playlist,
          tracks: playlist.trackIds
            .map((id) => library.displayTracksById.get(id))
            .filter((track): track is Track => Boolean(track)),
        })),
      });
    }
    if (results.length > 0) {
      next.push({
        title: `Songs · ${results.length}`,
        data: results.map((track) => ({ kind: 'song' as const, track })),
      });
    }
    return next;
  }, [
    needle,
    recents,
    matchingAlbums,
    matchingArtists,
    matchingPlaylists,
    results,
    artistCounts,
    library.displayTracksById,
  ]);

  const browseLibrary = () => {
    tapFeedback('selection');
    library.setTab('songs');
    router.push('/library');
  };

  const menuFavorite = songMenu ? library.favorites.has(songMenu.id) : false;

  const renderEntry = ({ item }: { item: SearchEntry }) => {
    switch (item.kind) {
      case 'recent':
        return (
          <ListRow
            leading={<Feather name="clock" size={18} color={palette.inkMuted} />}
            title={item.query}
            onPress={() => {
              tapFeedback('selection');
              setQuery(item.query);
            }}
            accessibilityLabel={`Search for ${item.query}`}
          />
        );
      case 'album':
        return (
          <ListRow
            leading={<CoverArt uri={item.album.artwork} size={44} radius={radii.md} />}
            title={item.album.title}
            subtitle={`${item.album.artist} · ${item.album.trackIds.length} ${item.album.trackIds.length === 1 ? 'track' : 'tracks'}`}
            onPress={() => {
              tapFeedback('selection');
              rememberQuery(trimmed);
              router.push({ pathname: '/album', params: { albumKey: item.album.id } });
            }}
            accessibilityLabel={`Open album ${item.album.title} by ${item.album.artist}`}
            trailing={<Feather name="chevron-right" size={18} color={palette.inkFaint} />}
          />
        );
      case 'artist':
        return (
          <ListRow
            leading={(
              <View style={styles.artistTile}>
                <Feather name="user" size={18} color={palette.accent} />
              </View>
            )}
            title={item.name}
            subtitle={`${item.count} ${item.count === 1 ? 'track' : 'tracks'}`}
            onPress={() => {
              tapFeedback('selection');
              rememberQuery(trimmed);
              router.push({ pathname: '/artist', params: { artist: item.name } });
            }}
            accessibilityLabel={`Open artist ${item.name}`}
            trailing={<Feather name="chevron-right" size={18} color={palette.inkFaint} />}
          />
        );
      case 'playlist':
        return (
          <ListRow
            leading={(
              <PlaylistCover
                artworks={item.tracks.map((track) => track.artwork)}
                size={44}
                radius={radii.md}
              />
            )}
            title={item.playlist.name}
            subtitle={`${item.tracks.length} ${item.tracks.length === 1 ? 'track' : 'tracks'}`}
            onPress={() => {
              tapFeedback('selection');
              rememberQuery(trimmed);
              router.push({ pathname: '/playlist', params: { id: item.playlist.id } });
            }}
            accessibilityLabel={`Open playlist ${item.playlist.name}`}
            trailing={<Feather name="chevron-right" size={18} color={palette.inkFaint} />}
          />
        );
      case 'song': {
        const active = player.activeTrack?.id === item.track.id;
        return (
          <ListRow
            leading={<Thumb track={item.track} size={44} />}
            title={item.track.title}
            titleColor={active ? palette.accent : undefined}
            subtitle={`${item.track.artist} · ${item.track.album}`}
            onPress={() => {
              tapFeedback('selection');
              rememberQuery(trimmed);
              void player.playTrack(item.track, results);
            }}
            accessibilityLabel={`Play ${item.track.title}`}
            trailing={(
              <Pressable
                accessibilityRole="button"
                accessibilityLabel={`Manage ${item.track.title}`}
                onPress={() => setSongMenu(item.track)}
                style={({ pressed }) => [styles.rowMenu, { opacity: pressed ? 0.6 : 1 }]}
                hitSlop={4}
              >
                <Feather name="more-horizontal" size={20} color={palette.inkMuted} />
              </Pressable>
            )}
          />
        );
      }
    }
  };

  const keyForEntry = (item: SearchEntry) => {
    switch (item.kind) {
      case 'recent':
        return `recent-${item.query}`;
      case 'album':
        return `album-${item.album.id}`;
      case 'artist':
        return `artist-${item.name}`;
      case 'playlist':
        return `playlist-${item.playlist.id}`;
      case 'song':
        return `song-${item.track.id}`;
    }
  };

  const empty = !trimmed
    ? (
      <EmptyState
        title="Search your library"
        message="Find a song, artist, album, genre, or playlist from the music on this device."
        actionLabel="Browse library"
        onAction={browseLibrary}
      />
    )
    : (
      <EmptyState
        compact
        title="No matching music"
        message={`Nothing matches “${trimmed}”.`}
      />
    );

  return (
    <SafeAreaView style={[styles.safe, { backgroundColor: palette.background }]} edges={['top']}>
      <ScreenHeader
        title="Search"
        subtitle="Songs, artists, albums, and playlists on this device"
      />
      <GlassSurface variant="field" style={styles.searchBar}>
        <Feather name="search" size={20} color={palette.inkMuted} />
        <TextInput
          value={query}
          onChangeText={setQuery}
          onSubmitEditing={() => {
            if (!trimmed) return;
            tapFeedback('selection');
            rememberQuery(trimmed);
          }}
          placeholder="Search songs, artists, albums"
          placeholderTextColor={palette.inkFaint}
          selectionColor={palette.accent}
          keyboardAppearance={dark ? 'dark' : 'light'}
          style={styles.input}
          autoCorrect={false}
          returnKeyType="search"
          accessibilityLabel="Search music"
        />
        {query ? (
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Clear search"
            hitSlop={8}
            onPress={() => {
              tapFeedback('light');
              setQuery('');
            }}
            style={styles.fieldAction}
          >
            <Feather name="x" size={20} color={palette.inkMuted} />
          </Pressable>
        ) : null}
      </GlassSurface>

      {player.error ? (
        <View style={styles.errorBanner}>
          <Feather name="alert-triangle" size={18} color={palette.danger} />
          <AppText variant="label" color={palette.danger} style={styles.errorText}>
            {player.error}
          </AppText>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Dismiss error"
            hitSlop={8}
            onPress={player.dismissError}
            style={styles.errorClose}
          >
            <Feather name="x" size={18} color={palette.danger} />
          </Pressable>
        </View>
      ) : null}

      <ListGroup style={styles.listCard}>
        <AnimatedSectionList<SearchEntry, SearchSection>
          sections={sections}
          keyExtractor={keyForEntry}
          renderItem={renderEntry}
          renderSectionHeader={({ section }: { section: SearchSection }) => (
            <GroupHeader
              label={section.title}
              actionLabel={section.actionLabel}
              onAction={section.onAction}
            />
          )}
          ListEmptyComponent={<View style={styles.emptyWrap}>{empty}</View>}
          contentContainerStyle={styles.listContent}
          showsVerticalScrollIndicator={false}
          onScroll={onScroll}
          scrollEventThrottle={16}
          keyboardShouldPersistTaps="handled"
          keyboardDismissMode="on-drag"
          initialNumToRender={14}
          windowSize={9}
        />
      </ListGroup>

      <AddToPlaylistSheet
        visible={addToSheetTrack !== null}
        onClose={() => setAddToSheetTrack(null)}
        trackTitle={addToSheetTrack?.title ?? null}
        playlists={library.playlists}
        onSelectPlaylist={(playlistId) => {
          if (addToSheetTrack) {
            library.addToPlaylist(playlistId, addToSheetTrack.id);
          }
        }}
        onCreatePlaylist={(name) => library.createPlaylist(name)}
      />
      <AppDialog
        visible={songMenu !== null}
        title={songMenu?.title ?? ''}
        onClose={() => setSongMenu(null)}
        actions={songMenu ? [
          {
            label: 'Play next',
            onPress: () => {
              tapFeedback('selection');
              player.playNext(songMenu);
            },
          },
          {
            label: 'Add to queue',
            onPress: () => {
              tapFeedback('selection');
              player.addToQueue(songMenu);
            },
          },
          {
            label: 'Add to playlist',
            onPress: () => {
              tapFeedback('selection');
              setAddToSheetTrack(songMenu);
            },
          },
          {
            label: menuFavorite ? 'Remove favorite' : 'Add favorite',
            onPress: () => {
              tapFeedback('selection');
              library.toggleFavorite(songMenu.id);
            },
          },
          { label: 'Cancel', onPress: () => {} },
        ] : []}
      />
    </SafeAreaView>
  );
}

const createStyles = ({ palette }: AppTheme) => ({
  safe: { flex: 1 },
  searchBar: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.sm,
    marginHorizontal: layout.screenPadding,
    marginTop: spacing.sm,
    paddingHorizontal: spacing.lg,
    height: 52,
    borderRadius: radii.pill,
  },
  input: {
    flex: 1,
    height: '100%' as const,
    color: palette.ink,
    fontSize: 16,
    paddingVertical: 0,
  },
  fieldAction: {
    width: 48,
    height: 48,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  },
  listCard: {
    flex: 1,
    marginTop: spacing.md,
  },
  listContent: {
    flexGrow: 1,
    paddingBottom: layout.tabBarSpace,
  },
  emptyWrap: {
    flex: 1,
    justifyContent: 'center' as const,
  },
  groupHeader: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    justifyContent: 'space-between' as const,
    gap: spacing.md,
    minHeight: 40,
    paddingHorizontal: spacing.sm,
    paddingTop: spacing.xs,
  },
  groupLabel: {
    flex: 1,
  },
  groupAction: {
    minHeight: 44,
    justifyContent: 'center' as const,
    paddingHorizontal: spacing.xs,
  },
  errorBanner: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.sm,
    marginHorizontal: layout.screenPadding,
    marginTop: spacing.sm,
    padding: spacing.md,
    borderRadius: radii.md,
    backgroundColor: palette.dangerSoft,
    borderWidth: 1,
    borderColor: palette.danger,
  },
  errorText: { flex: 1 },
  errorClose: {
    width: 48,
    height: 48,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  },
  artistTile: {
    width: 44,
    height: 44,
    borderRadius: radii.md,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
    backgroundColor: palette.surfaceMuted,
    borderWidth: 1,
    borderColor: palette.border,
  },
  rowMenu: {
    width: 44,
    height: 44,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  },
});
