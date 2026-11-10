import Feather from '@expo/vector-icons/Feather';
import { router, useLocalSearchParams } from 'expo-router';
import { StyleSheet } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Animated from 'react-native-reanimated';

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
import { usePreferences } from '../storage/PreferencesContext';
import { spacing, useTheme } from '../theme';

export default function GenreScreen() {
  const params = useLocalSearchParams<{ genre?: string }>();
  const genreName = params.genre ?? '';
  const library = useMusicLibrary();
  const player = usePlayer();
  const { tapFeedback } = usePreferences();
  const { palette } = useTheme();
  const { scrollY, onScroll } = useCollapsingScroll(false);

  const key = genreName.trim().toLowerCase();
  const tracks = library.displayTracks.filter(
    (track) => track.genre?.trim().toLowerCase() === key,
  );

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
          title={genreName || 'Genre'}
          subtitle={`${tracks.length} ${tracks.length === 1 ? 'song' : 'songs'}`}
        />

        {tracks.length === 0 ? (
          <EmptyState
            title="No songs for this genre"
            message="Rescan your Music folder if this looks wrong."
            actionLabel="Rescan library"
            onAction={() => {
              tapFeedback('selection');
              void library.scan();
            }}
          />
        ) : (
          <>
            <SectionHeader label="Songs" />
            <ListGroup>
              {tracks.map((track) => (
                <ListRow
                  key={track.id}
                  leading={<Thumb track={track} size={44} />}
                  title={track.title}
                  subtitle={`${track.artist} · ${track.album}`}
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
        title={genreName || 'Genre'}
        scrollY={scrollY}
        left={<IconButton name="chevron-left" label="Back" iconSize={22} onPress={() => router.back()} />}
      />
      <MiniPlayer standalone />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1 },
  content: {
    paddingBottom: 150,
    gap: spacing.md,
  },
});
