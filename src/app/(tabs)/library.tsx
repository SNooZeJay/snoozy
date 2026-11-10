import Feather from '@expo/vector-icons/Feather';
import { router } from 'expo-router';
import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import {
  Pressable,
  RefreshControl,
  StyleSheet,
  useWindowDimensions,
  View,
} from 'react-native';
import Animated, {
  useAnimatedScrollHandler,
  useAnimatedStyle,
  useSharedValue,
  withSpring,
} from 'react-native-reanimated';
import { SafeAreaView } from 'react-native-safe-area-context';

import { AppDialog } from '../../components/AppDialog';
import { AppText } from '../../components/AppText';
import { AddToPlaylistSheet } from '../../components/AddToPlaylistSheet';
import { CoverArt } from '../../components/Artwork';
import { EmptyState } from '../../components/EmptyState';
import { GlassButton } from '../../components/glass/GlassButton';
import { ListGroup } from '../../components/ListGroup';
import { ListRow } from '../../components/ListRow';
import { ScreenHeader } from '../../components/ScreenHeader';
import { SwipeableRow, type SwipeAction } from '../../components/SwipeableRow';
import { Thumb } from '../../components/Thumb';
import { formatDuration } from '../../utils/format';
import { tabScrollY } from '../../motion/scrollState';
import { useMusicLibrary } from '../../storage/MusicLibraryContext';
import { usePlayer } from '../../playback/PlayerContext';
import { usePreferences } from '../../storage/PreferencesContext';
import type { Album, AlbumSort, LibraryTab, SongSort, Track } from '../../types/music';
import { randomStartIndex } from '../../playback/controls';
import {
  layout,
  motion,
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  withAlpha,
  type AppTheme,
} from '../../theme';

const SEGMENTS: LibraryTab[] = ['songs', 'albums', 'artists', 'genres', 'favorites'];

const SONG_SORT_LABELS: Record<SongSort, string> = {
  title: 'Title',
  artist: 'Artist',
  album: 'Album',
  duration: 'Duration',
};

const ALBUM_SORT_LABELS: Record<AlbumSort, string> = {
  title: 'Title',
  artist: 'Artist',
  year: 'Year',
  tracks: 'Tracks',
};

type SegmentControlProps = {
  active: LibraryTab;
  reducedMotion: boolean;
  onSelect: (segment: LibraryTab) => void;
};

function SegmentControl({ active, reducedMotion, onSelect }: SegmentControlProps) {
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  const thumbX = useSharedValue(0);
  const thumbWidth = useSharedValue(0);
  const measurements = useRef<{ x: number; width: number }[]>([]);
  const activeIndex = SEGMENTS.indexOf(active);

  useEffect(() => {
    const layoutInfo = measurements.current[activeIndex];
    if (!layoutInfo) return;
    thumbX.value = reducedMotion
      ? layoutInfo.x
      : withSpring(layoutInfo.x, motion.springs.standard);
    thumbWidth.value = reducedMotion
      ? layoutInfo.width
      : withSpring(layoutInfo.width, motion.springs.standard);
  }, [activeIndex, reducedMotion, thumbWidth, thumbX]);

  const thumbStyle = useAnimatedStyle(() => ({
    opacity: thumbWidth.value > 0 ? 1 : 0,
    width: thumbWidth.value,
    transform: [{ translateX: thumbX.value }],
  }));

  return (
    <View style={styles.segmentRow}>
      <View style={styles.segmentTrack}>
        <Animated.View
          pointerEvents="none"
          style={[
            styles.segmentThumb,
            {
              backgroundColor: palette.surfaceRaised,
              borderColor: withAlpha(palette.ink, 0.12),
            },
            thumbStyle,
          ]}
        />
        {SEGMENTS.map((segment, index) => {
          const selected = active === segment;
          const isFavorites = segment === 'favorites';
          return (
            <Pressable
              key={segment}
              accessibilityRole="button"
              accessibilityLabel={isFavorites ? 'Show favorites' : `Show ${segment}`}
              accessibilityState={{ selected }}
              onPress={() => onSelect(segment)}
              onLayout={(event) => {
                const { x, width } = event.nativeEvent.layout;
                measurements.current[index] = { x, width };
                if (index !== activeIndex) return;
                thumbX.value = reducedMotion
                  ? x
                  : withSpring(x, motion.springs.standard);
                thumbWidth.value = reducedMotion
                  ? width
                  : withSpring(width, motion.springs.standard);
              }}
              style={({ pressed }) => [
                styles.segmentTap,
                pressed && styles.segmentPressed,
              ]}
            >
              <View style={[styles.segment, selected && styles.segmentActive]}>
                {isFavorites ? (
                  <Feather
                    name="heart"
                    size={15}
                    color={selected ? palette.accent : palette.inkMuted}
                  />
                ) : (
                  <AppText
                    variant="label"
                    color={selected ? palette.ink : palette.inkMuted}
                    numberOfLines={1}
                    adjustsFontSizeToFit
                    minimumFontScale={0.72}
                    style={styles.segmentLabel}
                  >
                    {segment[0].toUpperCase() + segment.slice(1)}
                  </AppText>
                )}
              </View>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

type LibraryToolbarProps = {
  label: string;
  actionLabel?: string;
  onAction?: () => void;
  trailing?: ReactNode;
};

function LibraryToolbar({ label, actionLabel, onAction, trailing }: LibraryToolbarProps) {
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);

  return (
    <View style={styles.toolbar}>
      <AppText variant="overline" color={palette.inkFaint} style={styles.toolbarLabel}>
        {label}
      </AppText>
      <View style={styles.toolbarActions}>
        {actionLabel && onAction ? (
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={actionLabel}
            onPress={onAction}
            hitSlop={8}
            style={({ pressed }) => [styles.toolbarAction, { opacity: pressed ? 0.62 : 1 }]}
          >
            <AppText variant="label" color={palette.inkMuted}>
              {actionLabel}
            </AppText>
          </Pressable>
        ) : null}
        {trailing}
      </View>
    </View>
  );
}

type SongRowProps = {
  track: Track;
  queue: Track[];
  favorite?: boolean;
  active?: boolean;
  onPlay: (track: Track, queue?: Track[]) => void;
  onMenu: (track: Track, queue?: Track[]) => void;
  onFavorite?: (track: Track) => void;
  onAddToPlaylist?: (track: Track) => void;
};

function SongRow({
  track,
  queue,
  favorite = false,
  active = false,
  onPlay,
  onMenu,
  onFavorite,
  onAddToPlaylist,
}: SongRowProps) {
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  const actions: SwipeAction[] = [];
  if (onFavorite) {
    actions.push({
      key: 'favorite',
      label: favorite ? 'Unfavorite' : 'Favorite',
      icon: 'heart',
      iconColor: favorite ? palette.accent : palette.ink,
      backgroundColor: withAlpha(palette.accent, 0.16),
      onPress: () => onFavorite(track),
    });
  }
  if (onAddToPlaylist) {
    actions.push({
      key: 'playlist',
      label: 'Playlist',
      icon: 'plus',
      iconColor: palette.ink,
      backgroundColor: withAlpha(palette.ink, 0.07),
      onPress: () => onAddToPlaylist(track),
    });
  }

  return (
    <SwipeableRow
      actions={actions}
      enabled={actions.length > 0}
      radius={radii.md}
      actionBackgroundColor={palette.backgroundRaised}
      defaultIconColor={palette.ink}
      style={styles.songSwipe}
    >
      <ListRow
        leading={<Thumb track={track} size={44} />}
        title={track.title}
        titleColor={active ? palette.accent : undefined}
        subtitle={`${track.artist} · ${track.album}`}
        onPress={() => onPlay(track, queue)}
        accessibilityLabel={`Play ${track.title}`}
        accessibilityHint="Swipe left for favorite and playlist actions"
        accessibilityState={active ? { selected: true } : undefined}
        trailing={(
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={`Manage ${track.title}`}
            onPress={() => onMenu(track, queue)}
            style={({ pressed }) => [styles.rowMenu, { opacity: pressed ? 0.6 : 1 }]}
            hitSlop={4}
          >
            <Feather name="more-horizontal" size={20} color={palette.inkMuted} />
          </Pressable>
        )}
      />
    </SwipeableRow>
  );
}

function BrowseTile({ icon }: { icon: 'music' | 'user' }) {
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  return (
    <View style={styles.browseTile}>
      <Feather name={icon} size={20} color={palette.accent} />
    </View>
  );
}

type AlbumTileProps = {
  album: Album;
  size: number;
  onPress: () => void;
};

function AlbumTile({ album, size, onPress }: AlbumTileProps) {
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`Open album ${album.title} by ${album.artist}`}
      accessibilityHint="Opens the album track list"
      onPress={onPress}
      style={({ pressed }) => [
        styles.albumTile,
        { width: size },
        pressed && styles.albumTilePressed,
      ]}
    >
      <CoverArt uri={album.artwork} size={size} radius={radii.lg} />
      <AppText variant="label" numberOfLines={1}>{album.title}</AppText>
      <AppText variant="micro" color={palette.inkMuted} numberOfLines={1}>
        {album.artist} · {album.trackIds.length} {album.trackIds.length === 1 ? 'track' : 'tracks'}
      </AppText>
    </Pressable>
  );
}

type LibraryEntry =
  | { kind: 'song'; track: Track; queue: Track[] }
  | { kind: 'album'; album: Album }
  | { kind: 'artist'; name: string }
  | { kind: 'genre'; name: string };

export default function LibraryScreen() {
  const library = useMusicLibrary();
  const player = usePlayer();
  const { tapFeedback } = usePreferences();
  const { palette, reducedMotion } = useTheme();
  const styles = useThemedStyles(createStyles);
  const { width } = useWindowDimensions();
  const onScroll = useAnimatedScrollHandler((event) => {
    tabScrollY.value = event.contentOffset.y;
  });
  const [addToSheetTrack, setAddToSheetTrack] = useState<Track | null>(null);
  const [songMenu, setSongMenu] = useState<{ track: Track; queue?: Track[] } | null>(null);
  const [songSortOpen, setSongSortOpen] = useState(false);
  const [albumSortOpen, setAlbumSortOpen] = useState(false);
  const [albumLayout, setAlbumLayout] = useState<'grid' | 'list'>('grid');

  const albumGridSize = Math.floor(
    (width - layout.screenPadding * 2 - spacing.md) / 2,
  );

  const favoriteTracks = useMemo(
    () => library.displayTracks.filter((track) => library.favorites.has(track.id)),
    [library.displayTracks, library.favorites],
  );

  const artistCounts = useMemo(() => {
    const counts = new Map<string, number>();
    for (const track of library.displayTracks) {
      counts.set(track.artist, (counts.get(track.artist) ?? 0) + 1);
    }
    return counts;
  }, [library.displayTracks]);

  const genreCounts = useMemo(() => {
    const counts = new Map<string, number>();
    for (const track of library.displayTracks) {
      const key = track.genre?.trim().toLowerCase();
      if (!key) continue;
      counts.set(key, (counts.get(key) ?? 0) + 1);
    }
    return counts;
  }, [library.displayTracks]);

  const entries = useMemo<LibraryEntry[]>(() => {
    switch (library.tab) {
      case 'albums':
        return library.albums.map((album) => ({ kind: 'album', album }));
      case 'artists':
        return library.artists.map((name) => ({ kind: 'artist', name }));
      case 'genres':
        return library.genres.map((name) => ({ kind: 'genre', name }));
      case 'favorites':
        return favoriteTracks.map((track) => ({ kind: 'song', track, queue: favoriteTracks }));
      default:
        return library.displayTracks.map((track) => ({
          kind: 'song',
          track,
          queue: library.displayTracks,
        }));
    }
  }, [library.tab, library.albums, library.artists, library.genres, library.displayTracks, favoriteTracks]);

  const play = (track: Track, queue?: Track[]) => {
    tapFeedback('selection');
    void player.playTrack(track, queue ?? library.displayTracks);
  };

  const shuffleList = (list: Track[]) => {
    if (list.length === 0) return;
    tapFeedback('selection');
    const start = list[randomStartIndex(list.length)];
    void player.playTrack(start, list, { shuffle: true });
  };

  const statusLine = library.permission === null
    ? 'Checking music access…'
    : library.scanning
      ? 'Scanning…'
      : library.permission !== 'granted'
        ? 'Music access needed'
        : library.lastScanAt
          ? `${library.tracks.length} ${library.tracks.length === 1 ? 'song' : 'songs'} · Updated ${new Date(library.lastScanAt).toLocaleTimeString()}`
          : `${library.tracks.length} ${library.tracks.length === 1 ? 'song' : 'songs'} indexed`;

  const openSongMenu = (track: Track, queue?: Track[]) => {
    setSongMenu({ track, queue });
  };

  const menuFavorite = songMenu
    ? library.favorites.has(songMenu.track.id)
    : false;

  const scanControl = (
    <RefreshControl
      refreshing={library.scanning}
      onRefresh={() => {
        tapFeedback('selection');
        void library.scan();
      }}
      tintColor={palette.accent}
      colors={[palette.accent]}
      progressBackgroundColor={palette.surfaceRaised}
    />
  );

  const renderEntry = ({ item }: { item: LibraryEntry }) => {
    switch (item.kind) {
      case 'song':
        return (
          <SongRow
            track={item.track}
            queue={item.queue}
            favorite={library.favorites.has(item.track.id)}
            active={player.activeTrack?.id === item.track.id}
            onPlay={play}
            onMenu={openSongMenu}
            onFavorite={(selected) => {
              tapFeedback('light');
              library.toggleFavorite(selected.id);
            }}
            onAddToPlaylist={(selected) => {
              tapFeedback('selection');
              setAddToSheetTrack(selected);
            }}
          />
        );
      case 'album':
        return (
          <ListRow
            leading={<CoverArt uri={item.album.artwork} size={44} radius={radii.md} />}
            title={item.album.title}
            subtitle={`${item.album.artist} · ${item.album.trackIds.length} ${item.album.trackIds.length === 1 ? 'track' : 'tracks'} · ${formatDuration(item.album.duration)}`}
            onPress={() => {
              tapFeedback('selection');
              router.push({ pathname: '/album', params: { albumKey: item.album.id } });
            }}
            accessibilityLabel={`Open album ${item.album.title} by ${item.album.artist}`}
            accessibilityHint="Opens the album track list"
            trailing={<Feather name="chevron-right" size={18} color={palette.inkFaint} />}
          />
        );
      case 'artist':
        return (
          <ListRow
            leading={<BrowseTile icon="user" />}
            title={item.name}
            subtitle={`${artistCounts.get(item.name) ?? 0} ${(artistCounts.get(item.name) ?? 0) === 1 ? 'track' : 'tracks'}`}
            onPress={() => {
              tapFeedback('selection');
              router.push({ pathname: '/artist', params: { artist: item.name } });
            }}
            accessibilityLabel={`Open artist ${item.name}`}
            accessibilityHint="Opens the artist track list"
            trailing={<Feather name="chevron-right" size={18} color={palette.inkFaint} />}
          />
        );
      case 'genre':
        return (
          <ListRow
            leading={<BrowseTile icon="music" />}
            title={item.name}
            subtitle={`${genreCounts.get(item.name.toLowerCase()) ?? 0} ${(genreCounts.get(item.name.toLowerCase()) ?? 0) === 1 ? 'track' : 'tracks'}`}
            onPress={() => {
              tapFeedback('selection');
              router.push({ pathname: '/genre', params: { genre: item.name } });
            }}
            accessibilityLabel={`Open genre ${item.name}`}
            accessibilityHint="Opens the genre track list"
            trailing={<Feather name="chevron-right" size={18} color={palette.inkFaint} />}
          />
        );
    }
  };

  const keyForEntry = (item: LibraryEntry) => {
    switch (item.kind) {
      case 'song':
        return `song-${item.track.id}`;
      case 'album':
        return `album-${item.album.id}`;
      case 'artist':
        return `artist-${item.name}`;
      case 'genre':
        return `genre-${item.name}`;
    }
  };

  const emptyLibrary =
    library.permission === 'granted'
      ? {
          title: 'No audio found',
          message: 'Put songs in your Music folder, then pull down to scan.',
          action: 'Scan your device',
          onAction: () => {
            tapFeedback('selection');
            void library.scan();
          },
        }
      : {
          title: 'Permission needed',
          message: 'Grant access to audio files to build your library.',
          action: 'Grant access',
          onAction: () => {
            tapFeedback('selection');
            void library.requestAccess();
          },
        };

  const emptyState = (() => {
    if (library.tab === 'songs') {
      return (
        <>
          <EmptyState
            title={emptyLibrary.title}
            message={emptyLibrary.message}
            actionLabel={emptyLibrary.action}
            onAction={emptyLibrary.onAction}
          />
          {library.scanError ? (
            <AppText variant="micro" color={palette.danger} style={styles.scanError}>
              {library.scanError}
            </AppText>
          ) : null}
        </>
      );
    }
    if (library.tab === 'albums') {
      return (
        <EmptyState
          compact
          title="No albums yet"
          message="Albums appear as soon as songs are indexed."
        />
      );
    }
    if (library.tab === 'artists') {
      return (
        <EmptyState
          compact
          title="No artists yet"
          message="Artists appear when songs with artist tags are indexed."
        />
      );
    }
    if (library.tab === 'genres') {
      return (
        <EmptyState
          compact
          title="No genres yet"
          message="Genres appear when songs carry a genre tag."
        />
      );
    }
    return (
      <EmptyState
        title="No favorites yet"
        message="Open a song’s menu and choose Add favorite."
        actionLabel="Browse songs"
        onAction={() => {
          tapFeedback('selection');
          library.setTab('songs');
        }}
      />
    );
  })();

  const count = entries.length;
  const countLabel = (() => {
    if (library.tab === 'songs') return `${count} ${count === 1 ? 'song' : 'songs'}`;
    if (library.tab === 'albums') return `${count} ${count === 1 ? 'album' : 'albums'}`;
    if (library.tab === 'artists') return `${count} ${count === 1 ? 'artist' : 'artists'}`;
    if (library.tab === 'genres') return `${count} ${count === 1 ? 'genre' : 'genres'}`;
    return `${count} ${count === 1 ? 'favorite' : 'favorites'}`;
  })();

  const toolbar = (() => {
    if (library.tab === 'songs') {
      return (
        <LibraryToolbar
          label={countLabel}
          actionLabel={`Sort · ${SONG_SORT_LABELS[library.songSort]}`}
          onAction={() => {
            tapFeedback('selection');
            setSongSortOpen(true);
          }}
        />
      );
    }
    if (library.tab === 'albums') {
      return (
        <LibraryToolbar
          label={countLabel}
          actionLabel={`Sort · ${ALBUM_SORT_LABELS[library.albumSort]}`}
          onAction={() => {
            tapFeedback('selection');
            setAlbumSortOpen(true);
          }}
          trailing={(
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={albumLayout === 'grid' ? 'Show albums as a list' : 'Show albums as a grid'}
              onPress={() => {
                tapFeedback('selection');
                setAlbumLayout((current) => (current === 'grid' ? 'list' : 'grid'));
              }}
              hitSlop={8}
              style={({ pressed }) => [styles.toolbarIcon, { opacity: pressed ? 0.6 : 1 }]}
            >
              <Feather
                name={albumLayout === 'grid' ? 'list' : 'grid'}
                size={17}
                color={palette.inkMuted}
              />
            </Pressable>
          )}
        />
      );
    }
    if (library.tab === 'favorites') {
      return (
        <LibraryToolbar
          label={countLabel}
          actionLabel="Shuffle"
          onAction={() => shuffleList(favoriteTracks)}
        />
      );
    }
    return <LibraryToolbar label={countLabel} />;
  })();

  const renderList = () => (
    <ListGroup style={styles.listCard}>
      <Animated.FlatList
        key={library.tab}
        data={entries}
        renderItem={renderEntry}
        keyExtractor={keyForEntry}
        showsVerticalScrollIndicator={false}
        onScroll={onScroll}
        scrollEventThrottle={16}
        refreshControl={scanControl}
        initialNumToRender={14}
        windowSize={9}
        contentContainerStyle={styles.listContent}
      />
    </ListGroup>
  );

  const renderGrid = () => (
    <Animated.FlatList
      key="albums-grid"
      data={library.albums}
      numColumns={2}
      columnWrapperStyle={styles.gridRow}
      contentContainerStyle={styles.gridContent}
      showsVerticalScrollIndicator={false}
      onScroll={onScroll}
      scrollEventThrottle={16}
      refreshControl={scanControl}
      initialNumToRender={8}
      windowSize={7}
      keyExtractor={(album) => album.id}
      renderItem={({ item }) => (
        <AlbumTile
          album={item}
          size={albumGridSize}
          onPress={() => {
            tapFeedback('selection');
            router.push({ pathname: '/album', params: { albumKey: item.id } });
          }}
        />
      )}
    />
  );

  const body = (() => {
    if (library.tab === 'albums' && albumLayout === 'grid' && library.albums.length > 0) {
      return renderGrid();
    }
    if (entries.length === 0) {
      return <View style={styles.emptyWrap}>{emptyState}</View>;
    }
    return renderList();
  })();

  return (
    <SafeAreaView style={[styles.safe, { backgroundColor: palette.background }]} edges={['top']}>
      <ScreenHeader
        title="Library"
        subtitle={statusLine}
        action={(
          <GlassButton
            accessibilityRole="button"
            accessibilityLabel="Import songs"
            onPress={() => {
              tapFeedback('selection');
              void library.importFiles();
            }}
            radius={24}
            style={styles.scanButton}
          >
            <Feather name="download" size={20} color={palette.ink} />
          </GlassButton>
        )}
      />

      <SegmentControl
        active={library.tab}
        reducedMotion={reducedMotion}
        onSelect={(segment) => {
          tapFeedback('selection');
          library.setTab(segment);
        }}
      />

      <View style={styles.body}>
        {toolbar}

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

        {body}
      </View>

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
        title={songMenu?.track.title ?? ''}
        onClose={() => setSongMenu(null)}
        actions={songMenu ? [
          {
            label: 'Play next',
            onPress: () => {
              tapFeedback('selection');
              player.playNext(songMenu.track);
            },
          },
          {
            label: 'Add to queue',
            onPress: () => {
              tapFeedback('selection');
              player.addToQueue(songMenu.track);
            },
          },
          {
            label: 'Add to playlist',
            onPress: () => {
              tapFeedback('selection');
              setAddToSheetTrack(songMenu.track);
            },
          },
          {
            label: menuFavorite ? 'Remove favorite' : 'Add favorite',
            onPress: () => {
              tapFeedback('selection');
              library.toggleFavorite(songMenu.track.id);
            },
          },
          { label: 'Cancel', onPress: () => {} },
        ] : []}
      />
      <AppDialog
        visible={songSortOpen}
        title="Sort songs by"
        onClose={() => setSongSortOpen(false)}
        actions={[
          ...(Object.keys(SONG_SORT_LABELS) as SongSort[]).map((key) => ({
            label: `${SONG_SORT_LABELS[key]}${library.songSort === key ? ' ✓' : ''}`,
            onPress: () => {
              tapFeedback('selection');
              library.setSongSort(key);
            },
          })),
          { label: 'Cancel', onPress: () => {} },
        ]}
      />
      <AppDialog
        visible={albumSortOpen}
        title="Sort albums by"
        onClose={() => setAlbumSortOpen(false)}
        actions={[
          ...(Object.keys(ALBUM_SORT_LABELS) as AlbumSort[]).map((key) => ({
            label: `${ALBUM_SORT_LABELS[key]}${library.albumSort === key ? ' ✓' : ''}`,
            onPress: () => {
              tapFeedback('selection');
              library.setAlbumSort(key);
            },
          })),
          { label: 'Cancel', onPress: () => {} },
        ]}
      />
    </SafeAreaView>
  );
}

const createStyles = ({ palette, glass }: AppTheme) => ({
  safe: { flex: 1 },
  scanButton: {
    width: 48,
    height: 48,
    borderRadius: 24,
  },
  segmentRow: {
    flexDirection: 'row' as const,
    paddingHorizontal: layout.screenPadding,
    paddingTop: spacing.sm,
  },
  segmentTrack: {
    flex: 1,
    flexDirection: 'row' as const,
    padding: 3,
    borderRadius: 11,
    backgroundColor: glass.fieldTint,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeSoft,
    position: 'relative' as const,
  },
  segmentThumb: {
    position: 'absolute' as const,
    left: 0,
    top: 3,
    height: 32,
    borderRadius: 8.5,
    borderWidth: StyleSheet.hairlineWidth,
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.22,
    shadowRadius: 4,
    elevation: 2,
  },
  segmentTap: {
    flex: 1,
    height: 32,
    justifyContent: 'center' as const,
  },
  segmentPressed: {
    opacity: 0.62,
  },
  segment: {
    height: 32,
    justifyContent: 'center' as const,
    alignItems: 'center' as const,
    paddingHorizontal: 3,
    borderRadius: 8.5,
  },
  segmentActive: {
    backgroundColor: 'transparent',
  },
  segmentLabel: {
    textAlign: 'center' as const,
  },
  body: {
    flex: 1,
    paddingTop: spacing.md,
    gap: spacing.sm,
  },
  toolbar: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    justifyContent: 'space-between' as const,
    gap: spacing.md,
    paddingHorizontal: layout.screenPadding,
    minHeight: 32,
  },
  toolbarLabel: {
    flex: 1,
  },
  toolbarActions: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.sm,
  },
  toolbarAction: {
    minHeight: 44,
    justifyContent: 'center' as const,
  },
  toolbarIcon: {
    width: 44,
    height: 44,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  },
  listCard: {
    flex: 1,
  },
  listContent: {
    paddingBottom: layout.tabBarSpace,
  },
  emptyWrap: {
    flex: 1,
    justifyContent: 'center' as const,
    paddingBottom: layout.tabBarSpace,
  },
  errorBanner: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.sm,
    marginHorizontal: layout.screenPadding,
    padding: spacing.md,
    borderRadius: radii.md,
    backgroundColor: palette.dangerSoft,
    borderWidth: 1,
    borderColor: palette.danger,
  },
  errorText: { flex: 1 },
  errorClose: {
    width: 32,
    height: 32,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  },
  scanError: {
    paddingHorizontal: layout.screenPadding,
    textAlign: 'center' as const,
  },
  songSwipe: {
    marginBottom: spacing.xxs,
  },
  rowMenu: {
    width: 44,
    height: 44,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  },
  browseTile: {
    width: 44,
    height: 44,
    borderRadius: radii.md,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
    backgroundColor: palette.surfaceMuted,
    borderWidth: 1,
    borderColor: palette.border,
  },
  albumTile: {
    gap: 6,
    paddingBottom: spacing.md,
  },
  albumTilePressed: {
    opacity: 0.72,
  },
  gridRow: {
    gap: spacing.md,
  },
  gridContent: {
    paddingHorizontal: layout.screenPadding,
    paddingTop: spacing.xs,
    paddingBottom: layout.tabBarSpace,
    gap: spacing.md,
  },
});
