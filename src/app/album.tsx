import Feather from '@expo/vector-icons/Feather';
import { router, useLocalSearchParams } from 'expo-router';
import { Pressable, ScrollView, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { AppText } from '../components/AppText';
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
import { usePreferences } from '../storage/PreferencesContext';
import type { Track } from '../types/music';
import {
  layout,
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  type AppTheme,
} from '../theme';

export default function AlbumScreen() {
  const params = useLocalSearchParams<{ album?: string }>();
  const albumName = params.album ?? '';
  const library = useMusicLibrary();
  const player = usePlayer();
  const { tapFeedback } = usePreferences();
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);

  const tracks = library.displayTracks.filter((track) => track.album === albumName);
  const totalMinutes = Math.round(
    tracks.reduce((sum, track) => sum + (track.duration || 0), 0) / 60,
  );

  const playAll = (shuffled: boolean) => {
    if (tracks.length === 0) return;
    const queue: Track[] = shuffled ? [...tracks].sort(() => Math.random() - 0.5) : tracks;
    tapFeedback('selection');
    void player.playTrack(queue[0], queue);
  };

  return (
    <SafeAreaView style={[styles.safe, { backgroundColor: palette.background }]} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <ScreenHeader
          leading={(
            <IconButton
              name="chevron-left"
              label="Back"
              iconSize={22}
              onPress={() => router.back()}
            />
          )}
          title={albumName || 'Unknown album'}
          subtitle={`${tracks.length} ${tracks.length === 1 ? 'track' : 'tracks'} · ${totalMinutes} min`}
        />

        {tracks.length === 0 ? (
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
            <View style={styles.actions}>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="Play album"
                onPress={() => playAll(false)}
                style={({ pressed }) => [styles.playButton, { opacity: pressed ? 0.75 : 1 }]}
              >
                <AppText variant="label" color={palette.accentInk}>Play</AppText>
              </Pressable>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="Shuffle album"
                onPress={() => playAll(true)}
                style={({ pressed }) => [styles.secondaryButton, { opacity: pressed ? 0.75 : 1 }]}
              >
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
                  accessibilityLabel={`Play ${track.title}`}
                  trailing={<Feather name="play" size={18} color={palette.inkMuted} />}
                />
              ))}
            </ListGroup>
          </>
        )}
      </ScrollView>
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
    marginHorizontal: layout.screenPadding,
  },
  playButton: {
    minHeight: 44,
    justifyContent: 'center' as const,
    paddingHorizontal: spacing.lg,
    borderRadius: radii.pill,
    backgroundColor: palette.accent,
  },
  secondaryButton: {
    minHeight: 44,
    justifyContent: 'center' as const,
    paddingHorizontal: spacing.lg,
    borderRadius: radii.pill,
    backgroundColor: glass.tintSoft,
    borderWidth: 1,
    borderColor: glass.edgeSoft,
  },
});
