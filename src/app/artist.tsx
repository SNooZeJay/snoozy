import Feather from '@expo/vector-icons/Feather';
import { router, useLocalSearchParams } from 'expo-router';
import { ScrollView, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

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
import {
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

  const tracks = library.displayTracks.filter((track) => track.artist === artistName);
  const albums = [...new Set(tracks.map((track) => track.album))];

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
            <SectionHeader label="Albums" />
            <ListGroup>
              {albums.map((album) => (
                <ListRow
                  key={album}
                  leading={(
                    <View style={styles.albumTile}>
                      <Feather name="disc" size={20} color={palette.accent} />
                    </View>
                  )}
                  title={album}
                  onPress={() => {
                    tapFeedback('selection');
                    router.push({ pathname: '/album', params: { album } });
                  }}
                  accessibilityLabel={`Open album ${album}`}
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
      </ScrollView>
      <MiniPlayer standalone />
    </SafeAreaView>
  );
}

const createStyles = ({ palette }: AppTheme) => ({
  safe: { flex: 1 },
  content: {
    paddingBottom: 150,
    gap: spacing.md,
  },
  albumTile: {
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
