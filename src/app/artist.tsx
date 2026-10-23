import { useLocalSearchParams, router } from 'expo-router';
import Feather from '@expo/vector-icons/Feather';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';
import Animated from 'react-native-reanimated';
import { SafeAreaView } from 'react-native-safe-area-context';

import { AppText } from '../components/AppText';
import { IconButton } from '../components/IconButton';
import { MiniPlayer } from '../components/MiniPlayer';
import { useMusicLibrary } from '../storage/MusicLibraryContext';
import { usePlayer } from '../playback/PlayerContext';
import { usePreferences } from '../storage/PreferencesContext';
import { staggerEnter } from '../motion/stagger';
import { colors, glass, radii, spacing, useTheme } from '../theme';

export default function ArtistScreen() {
  const params = useLocalSearchParams<{ artist?: string }>();
  const artistName = params.artist ?? '';
  const library = useMusicLibrary();
  const player = usePlayer();
  const { tapFeedback } = usePreferences();
  const { reducedMotion } = useTheme();

  const tracks = library.displayTracks.filter((t) => t.artist === artistName);
  const albums = [...new Set(tracks.map((t) => t.album))];

  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.topRow}>
          <IconButton name="chevron-left" label="Back" onPress={() => router.back()} />
          <AppText variant="title" color={colors.ink} numberOfLines={1} style={styles.topTitle}>
            {artistName || 'Unknown artist'}
          </AppText>
        </View>
        {tracks.length === 0 ? (
          <View style={styles.emptyCard}>
            <AppText variant="body" color={colors.inkMuted}>
              No songs for this artist. Rescan your Music folder if this looks wrong.
            </AppText>
            <Pressable
              accessibilityRole="button"
              onPress={() => {
                tapFeedback('selection');
                void library.scan();
              }}
              style={({ pressed }) => [styles.button, { opacity: pressed ? 0.75 : 1 }]}
            >
              <AppText variant="label" color={colors.accentInk}>Rescan library</AppText>
            </Pressable>
          </View>
        ) : (
          <>
            <AppText variant="micro" color={colors.inkFaint}>
              {tracks.length} {tracks.length === 1 ? 'song' : 'songs'} · {albums.length} {albums.length === 1 ? 'album' : 'albums'}
            </AppText>
            <AppText variant="heading" color={colors.ink}>Albums</AppText>
            {albums.map((album, index) => (
              <Animated.View
                key={album}
                entering={staggerEnter(index, reducedMotion)}
              >
                <Pressable
                  accessibilityRole="button"
                  onPress={() => {
                    tapFeedback('selection');
                    router.push({ pathname: '/album', params: { album } });
                  }}
                  style={({ pressed }) => [styles.row, pressed && styles.rowPressed]}
                >
                  <View style={styles.artworkFallback}>
                    <Feather name="disc" size={22} color={colors.accentInk} />
                  </View>
                  <AppText variant="label" color={colors.ink} numberOfLines={1}>{album}</AppText>
                </Pressable>
              </Animated.View>
            ))}
            <AppText variant="heading" color={colors.ink}>Songs</AppText>
            {tracks.map((track, index) => (
              <Animated.View
                key={track.id}
                entering={staggerEnter(index, reducedMotion)}
              >
                <Pressable
                  accessibilityRole="button"
                  onPress={() => {
                    tapFeedback('selection');
                    void player.playTrack(track, tracks);
                  }}
                  style={({ pressed }) => [styles.row, pressed && styles.rowPressed]}
                >
                  <View style={styles.artworkFallback}>
                    <AppText variant="label" color={colors.accentInk}>{track.title.slice(0, 1).toUpperCase()}</AppText>
                  </View>
                  <View style={styles.rowText}>
                    <AppText variant="label" color={colors.ink} numberOfLines={1}>{track.title}</AppText>
                    <AppText variant="micro" color={colors.inkMuted} numberOfLines={1}>{track.album}</AppText>
                  </View>
                </Pressable>
              </Animated.View>
            ))}
          </>
        )}
      </ScrollView>
      <MiniPlayer standalone />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  content: { padding: spacing.lg, gap: spacing.md, paddingBottom: 150 },
  topRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  topTitle: { flex: 1 },
  emptyCard: {
    gap: spacing.md,
    padding: spacing.lg,
    borderRadius: radii.lg,
    backgroundColor: glass.tint,
    borderWidth: 1,
    borderColor: glass.edge,
  },
  button: { alignSelf: 'flex-start', paddingHorizontal: spacing.lg, paddingVertical: spacing.sm, borderRadius: radii.pill, backgroundColor: colors.accent },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.sm,
    borderRadius: radii.md,
    backgroundColor: glass.tintSoft,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeSoft,
  },
  rowPressed: { opacity: 0.7, transform: [{ scale: 0.99 }] },
  artworkFallback: {
    width: 48,
    height: 48,
    borderRadius: radii.md,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: glass.tintAccent,
  },
  rowText: { flex: 1, gap: 2 },
});
