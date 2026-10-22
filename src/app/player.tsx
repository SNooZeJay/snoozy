import { LinearGradient } from 'expo-linear-gradient';
import { router } from 'expo-router';
import { useState } from 'react';

import {
  Image,
  Pressable,
  ScrollView,
  StyleSheet,
  View,
} from 'react-native';
import Animated from 'react-native-reanimated';
import { SafeAreaView } from 'react-native-safe-area-context';

import { AppText } from '../components/AppText';
import { IconButton } from '../components/IconButton';
import { PlayButton } from '../components/PlayButton';
import { LyricsSheet } from '../components/LyricsSheet';
import { SongEditSheet } from '../components/SongEditSheet';
import { SeekBar } from '../components/SeekBar';
import { useMusicLibrary } from '../storage/MusicLibraryContext';
import { usePlayer } from '../playback/PlayerContext';
import { usePreferences } from '../storage/PreferencesContext';
import { colors, radii, spacing } from '../theme';

export default function PlayerScreen() {
  const library = useMusicLibrary();
  const player = usePlayer();
  const { tapFeedback } = usePreferences();
  const [lyricsOpen, setLyricsOpen] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const track = player.activeTrack;

  if (!track) {
    return (
      <SafeAreaView style={styles.safe}>
        <View style={styles.empty}>
          <AppText variant="title" color={colors.ink}>No track selected</AppText>
          <Pressable accessibilityRole="button" onPress={() => router.back()} style={styles.backButton}>
            <AppText variant="label" color={colors.accentInk}>Close</AppText>
          </Pressable>
        </View>
      </SafeAreaView>
    );
  }

  const isFavorite = library.favorites.has(track.id);

  return (
    <View style={styles.root}>
      <LinearGradient
        pointerEvents="none"
        colors={[player.palette.glow, colors.backgroundDeep, colors.backgroundDeep]}
        locations={[0, 0.45, 1]}
        style={StyleSheet.absoluteFill}
      />
      <SafeAreaView edges={['top', 'bottom']} style={styles.safe}>
        <View style={styles.topbar}>
          <IconButton
            name="chevron-down"
            label="Close player"
            iconSize={22}
            size={48}
            onPress={() => router.back()}
            backgroundColor="rgba(7, 17, 13, 0.4)"
            borderColor="rgba(243, 240, 228, 0.14)"
          />
          <View style={styles.topbarTitle}>
            <AppText variant="overline" color={colors.inkMuted}>Now playing</AppText>
          </View>
          <IconButton
            name="heart"
            label={isFavorite ? 'Remove favorite' : 'Add favorite'}
            iconSize={20}
            size={48}
            color={isFavorite ? player.palette.accent : colors.ink}
            backgroundColor="rgba(7, 17, 13, 0.4)"
            borderColor="rgba(243, 240, 228, 0.14)"
            onPress={() => {
              tapFeedback('light');
              library.toggleFavorite(track.id);
            }}
          />
        </View>

        <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
          <View style={styles.artworkShell}>
            <Animated.View sharedTransitionTag="now-playing-artwork" style={styles.artwork}>
              {track.artwork ? (
                <Image source={{ uri: track.artwork }} style={styles.artworkImage} />
              ) : (
                <View style={[styles.artworkFallback, { backgroundColor: player.palette.accent }]}>
                  <AppText variant="display" color={player.palette.accentInk}>{track.title.slice(0, 1).toUpperCase()}</AppText>
                </View>
              )}
            </Animated.View>
          </View>

          <View style={styles.trackInfo}>
            <AppText variant="title" color={colors.ink} numberOfLines={2}>{track.title}</AppText>
            <AppText variant="body" color={colors.inkMuted} numberOfLines={1}>{track.artist}</AppText>
            <AppText variant="micro" color={colors.inkFaint} numberOfLines={1}>{track.album}</AppText>
          </View>

          <SeekBar
            progress={player.progress}
            duration={player.duration}
            onSeek={player.seekTo}
            accentColor={player.palette.accent}
          />

          <View style={styles.controls}>
            <IconButton name="skip-back" label="Previous" iconSize={24} size={52} onPress={() => void player.previous()} />
            <PlayButton
              playing={player.isPlaying}
              onPress={() => void player.togglePlayback()}
              size={76}
              accentColor={player.palette.accent}
              accentInk={player.palette.accentInk}
            />
            <IconButton name="skip-forward" label="Next" iconSize={24} size={52} onPress={() => void player.next()} />
          </View>

          <View style={styles.secondaryControls}>
            <IconButton
              name="music"
              label="Lyrics"
              size={48}
              onPress={() => { tapFeedback('selection'); setLyricsOpen(true); }}
            />
            <IconButton
              name="edit-3"
              label="Edit song"
              size={48}
              onPress={() => { tapFeedback('selection'); setEditOpen(true); }}
            />
          </View>

          {player.error ? (
            <View style={styles.error}>
              <AppText variant="micro" color={colors.danger}>{player.error}</AppText>
            </View>
          ) : null}
        </ScrollView>
      </SafeAreaView>
      <LyricsSheet visible={lyricsOpen} onClose={() => setLyricsOpen(false)} trackUri={track.uri} trackTitle={track.title} />
      <SongEditSheet visible={editOpen} onClose={() => setEditOpen(false)} trackId={track.id} original={{ title: track.title, artist: track.artist, album: track.album }} />
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.backgroundDeep },
  safe: { flex: 1 },
  topbar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.sm,
  },
  topbarTitle: { alignItems: 'center' },
  content: { padding: spacing.lg, gap: spacing.xl, paddingBottom: 40 },
  artworkShell: { alignItems: 'center' },
  artwork: {
    width: 300,
    height: 300,
    borderRadius: radii.xl,
    overflow: 'hidden',
    backgroundColor: colors.surfaceRaised,
  },
  artworkImage: { width: 300, height: 300 },
  artworkFallback: {
    width: 300,
    height: 300,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.surfaceMuted,
  },
  trackInfo: { gap: spacing.xs, alignItems: 'center' },
  controls: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.xl,
  },
  secondaryControls: { flexDirection: 'row', justifyContent: 'center', gap: spacing.lg },
  error: {
    padding: spacing.md,
    borderRadius: radii.md,
    backgroundColor: colors.dangerSoft,
  },
  empty: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: spacing.md },
  backButton: {
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    borderRadius: radii.pill,
    backgroundColor: colors.accent,
  },
});