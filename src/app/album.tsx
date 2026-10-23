import { useLocalSearchParams, router } from 'expo-router';
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
import type { Track } from '../types/music';
import { colors, glass, radii, spacing, useTheme } from '../theme';

export default function AlbumScreen() {
  const params = useLocalSearchParams<{ album?: string }>();
  const albumName = params.album ?? '';
  const library = useMusicLibrary();
  const player = usePlayer();
  const { tapFeedback } = usePreferences();
  const { reducedMotion } = useTheme();

  const tracks = library.displayTracks.filter((t) => t.album === albumName);
  const totalMinutes = Math.round(tracks.reduce((s, t) => s + (t.duration || 0), 0) / 60);

  const playAll = (shuffled: boolean) => {
    if (tracks.length === 0) return;
    const queue: Track[] = shuffled ? [...tracks].sort(() => Math.random() - 0.5) : tracks;
    tapFeedback('selection');
    void player.playTrack(queue[0], queue);
  };

  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.topRow}>
          <IconButton name="chevron-left" label="Back" onPress={() => router.back()} />
          <AppText variant="title" color={colors.ink} numberOfLines={1} style={styles.topTitle}>
            {albumName || 'Unknown album'}
          </AppText>
        </View>
        {tracks.length === 0 ? (
          <View style={styles.emptyCard}>
            <AppText variant="body" color={colors.inkMuted}>
              No tracks in this album. Rescan your Music folder if this looks wrong.
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
              {tracks.length} {tracks.length === 1 ? 'track' : 'tracks'} · {totalMinutes} min
            </AppText>
            <View style={styles.actions}>
              <Pressable accessibilityRole="button" onPress={() => playAll(false)} style={styles.button}>
                <AppText variant="label" color={colors.accentInk}>Play</AppText>
              </Pressable>
              <Pressable accessibilityRole="button" onPress={() => playAll(true)} style={styles.buttonSecondary}>
                <AppText variant="label" color={colors.ink}>Shuffle</AppText>
              </Pressable>
            </View>
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
                    <AppText variant="micro" color={colors.inkMuted} numberOfLines={1}>{track.artist}</AppText>
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
  actions: { flexDirection: 'row', gap: spacing.sm },
  button: { paddingHorizontal: spacing.lg, paddingVertical: spacing.sm, borderRadius: radii.pill, backgroundColor: colors.accent },
  buttonSecondary: { paddingHorizontal: spacing.lg, paddingVertical: spacing.sm, borderRadius: radii.pill, backgroundColor: glass.tintSoft, borderWidth: 1, borderColor: glass.edgeSoft },
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
