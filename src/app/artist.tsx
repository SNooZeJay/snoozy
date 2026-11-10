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
import { albumKeyFor } from '../storage/albumGrouping';
import { useMusicLibrary } from '../storage/MusicLibraryContext';
import { usePlayer } from '../playback/PlayerContext';
import { randomStartIndex } from '../playback/controls';
import { usePreferences } from '../storage/PreferencesContext';
import {
  layout,
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  type AppTheme,
} from '../theme';

export default function ArtistScreen() {
  const params = useLocalSearchParams<{ artist?: string }>();
  const artistName = params.artist ?? '';
  const library = useMusicLibrary();
  const player = usePlayer();
  const { tapFeedback } = usePreferences();
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  const { scrollY, onScroll } = useCollapsingScroll(false);

  const tracks = library.displayTracks.filter((track) => track.artist === artistName);
  const albumIds = new Set(tracks.map(albumKeyFor));
  const albums = library.albums.filter((album) => albumIds.has(album.id));

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
          title={artistName || 'Unknown artist'}
          subtitle={`${tracks.length} ${tracks.length === 1 ? 'song' : 'songs'} · ${albums.length} ${albums.length === 1 ? 'album' : 'albums'}`}
        />

        {tracks.length === 0 ? (
          <EmptyState
            title="No songs for this artist"
            message="Rescan your Music folder if this looks wrong."
            actionLabel="Rescan library"
            onAction={() => {
              tapFeedback('selection');
              void library.scan();
            }}
          />
        ) : (
          <>
            <View style={styles.actions}>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel={`Play ${artistName}`}
                onPress={() => playAll(false)}
                style={({ pressed }) => [styles.playButton, { opacity: pressed ? 0.75 : 1 }]}
              >
                <Feather name="play" size={16} color={palette.accentInk} />
                <AppText variant="label" color={palette.accentInk}>Play</AppText>
              </Pressable>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel={`Shuffle ${artistName}`}
                onPress={() => playAll(true)}
                style={({ pressed }) => [styles.secondaryButton, { opacity: pressed ? 0.75 : 1 }]}
              >
                <Feather name="shuffle" size={16} color={palette.ink} />
                <AppText variant="label" color={palette.ink}>Shuffle</AppText>
              </Pressable>
            </View>

            <SectionHeader label="Albums" />
            <ListGroup>
              {albums.map((album) => (
                <ListRow
                  key={album.id}
                  leading={<CoverArt uri={album.artwork} size={44} radius={radii.md} />}
                  title={album.title}
                  subtitle={`${album.trackIds.length} ${album.trackIds.length === 1 ? 'track' : 'tracks'}${album.year ? ` · ${album.year}` : ''}`}
                  onPress={() => {
                    tapFeedback('selection');
                    router.push({ pathname: '/album', params: { albumKey: album.id } });
                  }}
                  accessibilityLabel={`Open album ${album.title}`}
                  trailing={<Feather name="chevron-right" size={18} color={palette.inkFaint} />}
                />
              ))}
            </ListGroup>

            <SectionHeader label="Songs" />
            <ListGroup>
              {tracks.map((track) => (
                <ListRow
                  key={track.id}
                  leading={<Thumb track={track} size={44} />}
                  title={track.title}
                  subtitle={track.album}
                  onPress={() => {
                    tapFeedback('selection');
                    void player.playTrack(track, tracks);
                  }}
                  accessibilityLabel={`Play ${track.title}`}
                  trailing={<Feather name="play" size={18} color={palette.inkMuted} />}
                />
              ))}
            </ListGroup>
          </>
        )}
      </Animated.ScrollView>
      <CollapsedBar
        title={artistName || 'Unknown artist'}
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
