import Feather from '@expo/vector-icons/Feather';
import { router, useLocalSearchParams } from 'expo-router';
import { Pressable, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Animated from 'react-native-reanimated';

import { AppText } from '../components/AppText';
import { CoverArt } from '../components/Artwork';
import { CollapsedBar, useCollapsingScroll } from '../components/CollapsingHeader';
import { EmptyState } from '../components/EmptyState';
import { IconButton } from '../components/IconButton';
import { ListGroup } from '../components/ListGroup';
import { ListRow } from '../components/ListRow';
import { MiniPlayer } from '../components/MiniPlayer';
import { ScreenHeader } from '../components/ScreenHeader';
import { SectionHeader } from '../components/SectionHeader';
import { Thumb } from '../components/Thumb';
import { useMusicLibrary } from '../storage/MusicLibraryContext';
import { usePlayer } from '../playback/PlayerContext';
import { randomStartIndex } from '../playback/controls';
import { usePreferences } from '../storage/PreferencesContext';
import type { Track } from '../types/music';
import { formatClock, formatDuration } from '../utils/format';
import {
  layout,
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  type AppTheme,
} from '../theme';

export default function AlbumScreen() {
  // `album` is accepted as a fallback for links created before albums had
  // stable keys (title-only lookup).
  const params = useLocalSearchParams<{ albumKey?: string; album?: string }>();
  const albumKey = params.albumKey ?? '';
  const albumName = params.album ?? '';
  const library = useMusicLibrary();
  const player = usePlayer();
  const { tapFeedback } = usePreferences();
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  const { scrollY, onScroll } = useCollapsingScroll(false);

  const album = albumKey
    ? library.albums.find((item) => item.id === albumKey)
    : albumName
      ? library.albums.find((item) => item.title === albumName)
      : undefined;

  const tracks = (album?.trackIds ?? [])
    .map((id) => library.displayTracksById.get(id))
    .filter((track): track is Track => Boolean(track));

  const title = album?.title ?? albumName ?? '';
  const subtitle = album
    ? [
        album.artist,
        album.year,
        `${tracks.length} ${tracks.length === 1 ? 'track' : 'tracks'}`,
        formatDuration(album.duration),
      ].filter(Boolean).join(' · ')
    : '';

  const playAll = (shuffled: boolean) => {
    if (tracks.length === 0) return;
    const start = shuffled ? tracks[randomStartIndex(tracks.length)] : tracks[0];
    tapFeedback('selection');
    void player.playTrack(start, tracks, { shuffle: shuffled });
  };

  return (
    <SafeAreaView style={[styles.safe, { backgroundColor: palette.background }]} edges={['top']}>
      <Animated.ScrollView
        contentContainerStyle={styles.content}
        onScroll={onScroll}
        scrollEventThrottle={16}
      >
        <ScreenHeader
          leading={(
            <IconButton
              name="chevron-left"
              label="Back"
              iconSize={22}
              onPress={() => router.back()}
            />
          )}
          title={title || 'Album'}
          subtitle={subtitle || undefined}
        />

        {!album || tracks.length === 0 ? (
          <EmptyState
            title="No tracks in this album"
            message="Rescan your Music folder if this looks wrong."
            actionLabel="Rescan library"
            onAction={() => {
              tapFeedback('selection');
              void library.scan();
            }}
          />
        ) : (
          <>
            <View style={styles.hero}>
              <CoverArt
                uri={album.artwork}
                size={188}
                radius={radii.xl}
                label={album.title}
              />
            </View>

            <View style={styles.actions}>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="Play album"
                onPress={() => playAll(false)}
                style={({ pressed }) => [styles.playButton, { opacity: pressed ? 0.75 : 1 }]}
              >
                <Feather name="play" size={16} color={palette.accentInk} />
                <AppText variant="label" color={palette.accentInk}>Play</AppText>
              </Pressable>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="Shuffle album"
                onPress={() => playAll(true)}
                style={({ pressed }) => [styles.secondaryButton, { opacity: pressed ? 0.75 : 1 }]}
              >
                <Feather name="shuffle" size={16} color={palette.ink} />
                <AppText variant="label" color={palette.ink}>Shuffle</AppText>
              </Pressable>
            </View>

            <SectionHeader label="Tracks" />
            <ListGroup>
              {tracks.map((track) => (
                <ListRow
                  key={track.id}
                  leading={<Thumb track={track} size={44} />}
                  title={track.title}
                  subtitle={track.artist}
                  onPress={() => {
                    tapFeedback('selection');
                    void player.playTrack(track, tracks);
                  }}
                  accessibilityLabel={`Play ${track.title} by ${track.artist}`}
                  trailing={(
                    <AppText variant="micro" color={palette.inkFaint}>
                      {formatClock(track.duration)}
                    </AppText>
                  )}
                />
              ))}
            </ListGroup>
          </>
        )}
      </Animated.ScrollView>
      <CollapsedBar
        title={title || 'Album'}
        scrollY={scrollY}
        left={<IconButton name="chevron-left" label="Back" iconSize={22} onPress={() => router.back()} />}
      />
      <MiniPlayer standalone />
    </SafeAreaView>
  );
}

const createStyles = ({ palette, glass }: AppTheme) => ({
  safe: { flex: 1 },
  content: {
    paddingBottom: 150,
    gap: spacing.md,
  },
  hero: {
    alignItems: 'center' as const,
    paddingTop: spacing.sm,
    paddingHorizontal: layout.screenPadding,
  },
  actions: {
    flexDirection: 'row' as const,
    gap: spacing.sm,
    paddingHorizontal: layout.screenPadding,
  },
  playButton: {
    minHeight: 44,
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.xs,
    justifyContent: 'center' as const,
    paddingHorizontal: spacing.lg,
    borderRadius: radii.pill,
    backgroundColor: palette.accent,
  },
  secondaryButton: {
    minHeight: 44,
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.xs,
    justifyContent: 'center' as const,
    paddingHorizontal: spacing.lg,
    borderRadius: radii.pill,
    backgroundColor: glass.tintSoft,
    borderWidth: 1,
    borderColor: glass.edgeSoft,
  },
});
