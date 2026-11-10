import Feather from '@expo/vector-icons/Feather';
import { router, useFocusEffect } from 'expo-router';
import { useCallback, useMemo, useState, type ReactNode } from 'react';
import {
  Linking,
  Pressable,
  RefreshControl,
  ScrollView,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Animated from 'react-native-reanimated';

import { AppDialog } from '../../components/AppDialog';
import { AppText } from '../../components/AppText';
import { CollapsedBar, useCollapsingScroll } from '../../components/CollapsingHeader';
import { CoverArt, PlaylistCover } from '../../components/Artwork';
import { EmptyState } from '../../components/EmptyState';
import { GlassButton } from '../../components/glass/GlassButton';
import { ListGroup } from '../../components/ListGroup';
import { ListRow } from '../../components/ListRow';
import { ScreenHeader } from '../../components/ScreenHeader';
import { SectionHeader } from '../../components/SectionHeader';
import { useMusicLibrary } from '../../storage/MusicLibraryContext';
import { usePlayer } from '../../playback/PlayerContext';
import { randomStartIndex } from '../../playback/controls';
import { usePreferences } from '../../storage/PreferencesContext';
import { getAllPlayHistory, type PlayHistoryEntry } from '../../storage/playHistory';
import { topPlayedTracks } from '../../storage/libraryStats';
import type { LibraryTab, Playlist, Track } from '../../types/music';
import {
  layout,
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  type AppTheme,
} from '../../theme';

const CARD_SIZE = 136;

function BrowseTile({ icon = 'grid' }: { icon?: 'grid' | 'shuffle' | 'disc' | 'heart' }) {
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  return (
    <View style={styles.browseTile}>
      <Feather name={icon} size={18} color={palette.accent} />
    </View>
  );
}

type MediaCardProps = {
  cover: ReactNode;
  title: string;
  subtitle?: string;
  onPress: () => void;
  accessibilityLabel: string;
};

function MediaCard({ cover, title, subtitle, onPress, accessibilityLabel }: MediaCardProps) {
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
      onPress={onPress}
      style={({ pressed }) => [styles.card, pressed && styles.cardPressed]}
    >
      {cover}
      <AppText variant="label" numberOfLines={1}>{title}</AppText>
      {subtitle ? (
        <AppText variant="micro" color={palette.inkMuted} numberOfLines={1}>
          {subtitle}
        </AppText>
      ) : null}
    </Pressable>
  );
}

export default function HomeScreen() {
  const library = useMusicLibrary();
  const player = usePlayer();
  const { tapFeedback } = usePreferences();
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  const { scrollY, onScroll } = useCollapsingScroll();
  const [clearHistoryOpen, setClearHistoryOpen] = useState(false);
  const [playHistory, setPlayHistory] = useState<PlayHistoryEntry[]>([]);

  useFocusEffect(
    useCallback(() => {
      let active = true;
      getAllPlayHistory()
        .then((rows) => {
          if (active) setPlayHistory(rows);
        })
        .catch(() => undefined);
      return () => {
        active = false;
      };
    }, []),
  );

  const recentTracks = library.recents
    .map((id) => library.displayTracksById.get(id))
    .filter((track): track is Track => Boolean(track))
    .slice(0, 10);

  const favoriteTracks = useMemo(
    () => library.displayTracks.filter((track) => library.favorites.has(track.id)),
    [library.displayTracks, library.favorites],
  );

  const mostPlayed = useMemo(
    () => topPlayedTracks(library.displayTracks, playHistory, 8),
    [library.displayTracks, playHistory],
  );

  const recentAlbums = useMemo(
    () => library.recentlyAddedAlbums.filter((album) => (album.addedAt ?? 0) > 0).slice(0, 8),
    [library.recentlyAddedAlbums],
  );

  const playlistTracks = (playlist: Playlist): Track[] =>
    playlist.trackIds
      .map((id) => library.displayTracksById.get(id))
      .filter((track): track is Track => Boolean(track));

  const playTrack = (track: Track, queue: Track[]) => {
    tapFeedback('selection');
    void player.playTrack(track, queue);
  };

  const openLibrary = (tab: LibraryTab) => {
    tapFeedback('selection');
    library.setTab(tab);
    router.push('/library');
  };

  const shuffleAll = () => {
    if (library.displayTracks.length === 0) return;
    tapFeedback('selection');
    const start = library.displayTracks[randomStartIndex(library.displayTracks.length)];
    void player.playTrack(start, library.displayTracks, { shuffle: true });
  };

  const statusLine =
    library.permission === null
      ? 'Checking music access…'
      : library.scanning
        ? 'Scanning…'
        : library.tracks.length > 0
          ? `${library.tracks.length} ${library.tracks.length === 1 ? 'song' : 'songs'}`
          : 'No songs yet';

  const hasLibrary = library.tracks.length > 0;

  return (
    <SafeAreaView style={[styles.safe, { backgroundColor: palette.background }]} edges={['top']}>
      <Animated.ScrollView
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
        onScroll={onScroll}
        scrollEventThrottle={16}
        refreshControl={
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
        }
      >
        <ScreenHeader
          eyebrow="Snoozy"
          title="Your music"
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
              style={styles.circleButton}
            >
              <Feather name="download" size={20} color={palette.ink} />
            </GlassButton>
          )}
        />

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

        {library.permission === null ? (
          <EmptyState
            compact
            title="Checking library…"
            message="Looking for audio files on this device."
          />
        ) : library.permission !== 'granted' ? (
          <>
            <EmptyState
              compact
              title="Permission needed"
              message="Snoozy needs access to audio files on this device to build your library."
              actionLabel={library.permissionCanAskAgain ? 'Grant access' : 'Open settings'}
              onAction={() => {
                tapFeedback('selection');
                if (library.permissionCanAskAgain) {
                  void library.requestAccess();
                } else {
                  void Linking.openSettings();
                }
              }}
            />
            {library.scanError ? (
              <AppText variant="micro" color={palette.danger} style={styles.scanError}>
                {library.scanError}
              </AppText>
            ) : null}
          </>
        ) : library.scanning ? (
          <EmptyState
            compact
            title="Scanning…"
            message="Reading audio files on this device. This can take a moment for large libraries."
          />
        ) : library.tracks.length === 0 ? (
          <>
            <EmptyState
              title="No audio found on this device"
              message="Put MP3, FLAC, or other audio files in your Music folder, then scan. You can also import files with the button above."
              actionLabel="Scan your device"
              onAction={() => {
                tapFeedback('selection');
                void library.scan();
              }}
            />
            {library.scanError ? (
              <AppText variant="micro" color={palette.danger} style={styles.scanError}>
                {library.scanError}
              </AppText>
            ) : null}
          </>
        ) : null}

        {hasLibrary ? (
          <>
            <View style={styles.section}>
              <SectionHeader
                label="Recently played"
                actionLabel={recentTracks.length > 0 ? 'Clear' : undefined}
                onAction={recentTracks.length > 0
                  ? () => {
                      tapFeedback('light');
                      setClearHistoryOpen(true);
                    }
                  : undefined}
              />
              {recentTracks.length === 0 ? (
                <EmptyState
                  compact
                  title="Nothing played yet"
                  message="Play a song and it will appear here."
                />
              ) : (
                <ScrollView
                  horizontal
                  showsHorizontalScrollIndicator={false}
                  contentContainerStyle={styles.cardRow}
                >
                  {recentTracks.map((track) => (
                    <MediaCard
                      key={track.id}
                      cover={<CoverArt uri={track.artwork} size={CARD_SIZE} radius={radii.lg} />}
                      title={track.title}
                      subtitle={track.artist}
                      onPress={() => playTrack(track, recentTracks)}
                      accessibilityLabel={`Play ${track.title}`}
                    />
                  ))}
                </ScrollView>
              )}
            </View>

            {recentAlbums.length > 0 ? (
              <View style={styles.section}>
                <SectionHeader
                  label="Recently added"
                  actionLabel="Albums"
                  onAction={() => openLibrary('albums')}
                />
                <ScrollView
                  horizontal
                  showsHorizontalScrollIndicator={false}
                  contentContainerStyle={styles.cardRow}
                >
                  {recentAlbums.map((album) => (
                    <MediaCard
                      key={album.id}
                      cover={<CoverArt uri={album.artwork} size={CARD_SIZE} radius={radii.lg} />}
                      title={album.title}
                      subtitle={album.artist}
                      onPress={() => {
                        tapFeedback('selection');
                        router.push({ pathname: '/album', params: { albumKey: album.id } });
                      }}
                      accessibilityLabel={`Open album ${album.title} by ${album.artist}`}
                    />
                  ))}
                </ScrollView>
              </View>
            ) : null}

            {mostPlayed.length > 0 ? (
              <View style={styles.section}>
                <SectionHeader label="Most played" />
                <ScrollView
                  horizontal
                  showsHorizontalScrollIndicator={false}
                  contentContainerStyle={styles.cardRow}
                >
                  {mostPlayed.map(({ track, plays }) => (
                    <MediaCard
                      key={track.id}
                      cover={<CoverArt uri={track.artwork} size={CARD_SIZE} radius={radii.lg} />}
                      title={track.title}
                      subtitle={`${plays} ${plays === 1 ? 'play' : 'plays'}`}
                      onPress={() => playTrack(track, mostPlayed.map((entry) => entry.track))}
                      accessibilityLabel={`Play ${track.title}`}
                    />
                  ))}
                </ScrollView>
              </View>
            ) : null}

            {favoriteTracks.length > 0 ? (
              <View style={styles.section}>
                <SectionHeader
                  label="Favorites"
                  actionLabel="See all"
                  onAction={() => openLibrary('favorites')}
                />
                <ScrollView
                  horizontal
                  showsHorizontalScrollIndicator={false}
                  contentContainerStyle={styles.cardRow}
                >
                  {favoriteTracks.slice(0, 8).map((track) => (
                    <MediaCard
                      key={track.id}
                      cover={<CoverArt uri={track.artwork} size={CARD_SIZE} radius={radii.lg} />}
                      title={track.title}
                      subtitle={track.artist}
                      onPress={() => playTrack(track, favoriteTracks)}
                      accessibilityLabel={`Play ${track.title}`}
                    />
                  ))}
                </ScrollView>
              </View>
            ) : null}

            <View style={styles.section}>
              <SectionHeader
                label="Playlists"
                actionLabel="See all"
                onAction={() => {
                  tapFeedback('selection');
                  router.push('/playlists');
                }}
              />
              {library.playlists.length === 0 ? (
                <EmptyState
                  compact
                  title="No playlists yet"
                  message="Build a set for a walk, a drive, or a quiet evening in Playlists."
                />
              ) : (
                <ScrollView
                  horizontal
                  showsHorizontalScrollIndicator={false}
                  contentContainerStyle={styles.cardRow}
                >
                  {library.playlists.slice(0, 8).map((playlist) => {
                    const tracks = playlistTracks(playlist);
                    return (
                      <MediaCard
                        key={playlist.id}
                        cover={(
                          <PlaylistCover
                            artworks={tracks.map((track) => track.artwork)}
                            size={CARD_SIZE}
                            radius={radii.lg}
                          />
                        )}
                        title={playlist.name}
                        subtitle={`${tracks.length} ${tracks.length === 1 ? 'track' : 'tracks'}`}
                        onPress={() => {
                          tapFeedback('selection');
                          router.push({ pathname: '/playlist', params: { id: playlist.id } });
                        }}
                        accessibilityLabel={`Open playlist ${playlist.name}`}
                      />
                    );
                  })}
                </ScrollView>
              )}
            </View>

            <View style={styles.section}>
              <SectionHeader
                label="Library"
                actionLabel="See all"
                onAction={() => openLibrary('songs')}
              />
              <ListGroup>
                <ListRow
                  leading={<BrowseTile icon="shuffle" />}
                  title="Shuffle all songs"
                  subtitle={`Play a random mix of ${library.tracks.length} ${library.tracks.length === 1 ? 'track' : 'tracks'}`}
                  onPress={shuffleAll}
                  accessibilityLabel="Shuffle all songs"
                  trailing={<Feather name="play" size={18} color={palette.inkMuted} />}
                />
                <ListRow
                  leading={<BrowseTile icon="grid" />}
                  title="Browse all songs"
                  subtitle={`${library.tracks.length} ${library.tracks.length === 1 ? 'track' : 'tracks'} · ${library.albums.length} ${library.albums.length === 1 ? 'album' : 'albums'}`}
                  onPress={() => openLibrary('songs')}
                  accessibilityLabel="Browse all songs"
                  trailing={<Feather name="chevron-right" size={18} color={palette.inkFaint} />}
                />
                {library.genres.length > 0 ? (
                  <ListRow
                    leading={<BrowseTile icon="disc" />}
                    title="Genres"
                    subtitle={`${library.genres.length} ${library.genres.length === 1 ? 'genre' : 'genres'} in your library`}
                    onPress={() => openLibrary('genres')}
                    accessibilityLabel="Browse genres"
                    trailing={<Feather name="chevron-right" size={18} color={palette.inkFaint} />}
                  />
                ) : null}
              </ListGroup>
            </View>
          </>
        ) : null}
      </Animated.ScrollView>

      <CollapsedBar title="Your music" scrollY={scrollY} />

      <AppDialog
        visible={clearHistoryOpen}
        title="Clear recently played?"
        message="Your play history will be emptied."
        onClose={() => setClearHistoryOpen(false)}
        actions={[
          {
            label: 'Clear',
            tone: 'danger',
            onPress: () => {
              tapFeedback('light');
              library.clearRecentHistory();
              setPlayHistory([]);
            },
          },
          { label: 'Cancel', onPress: () => {} },
        ]}
      />
    </SafeAreaView>
  );
}

const createStyles = ({ palette }: AppTheme) => ({
  safe: { flex: 1 },
  content: {
    paddingTop: spacing.lg,
    paddingBottom: layout.tabBarSpace,
  },
  section: {
    gap: spacing.sm,
    marginTop: spacing.xxl,
  },
  cardRow: {
    gap: spacing.md,
    paddingHorizontal: layout.screenPadding,
    paddingBottom: spacing.xs,
  },
  card: {
    width: CARD_SIZE,
    gap: 5,
  },
  cardPressed: {
    opacity: 0.72,
  },
  circleButton: {
    width: 48,
    height: 48,
    borderRadius: 24,
  },
  errorBanner: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.sm,
    marginHorizontal: layout.screenPadding,
    marginTop: spacing.md,
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
    marginTop: spacing.sm,
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
});
