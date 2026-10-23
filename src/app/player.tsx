import { router } from 'expo-router';
import { useState } from 'react';

import {
  Pressable,
  ScrollView,
  StyleSheet,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { AppText } from '../components/AppText';
import { CrossfadeArtwork } from '../components/CrossfadeArtwork';
import { GlassSurface } from '../components/glass/GlassSurface';
import { IconButton } from '../components/IconButton';
import { PaletteGlow } from '../components/PaletteGlow';
import { PlayButton } from '../components/PlayButton';
import { LyricsSheet } from '../components/LyricsSheet';
import { SongEditSheet } from '../components/SongEditSheet';
import { SeekBar } from '../components/SeekBar';
import { useMusicLibrary } from '../storage/MusicLibraryContext';
import { usePlayer, usePlayerProgress } from '../playback/PlayerContext';
import { usePreferences } from '../storage/PreferencesContext';
import { colors, glass, radii, spacing, useTheme } from '../theme';

export default function PlayerScreen() {
  const library = useMusicLibrary();
  const player = usePlayer();
  const playback = usePlayerProgress();
  const { tapFeedback } = usePreferences();
  const { backdropEnabled, backdropIntensity, reducedMotion } = useTheme();
  const [lyricsOpen, setLyricsOpen] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const track = player.activeTrack;
  const glowOpacity = backdropEnabled
    ? Math.max(0, Math.min(1, backdropIntensity / 100))
    : 0;

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
      <PaletteGlow
        color={player.palette.glow}
        intensity={glowOpacity}
        background={colors.backgroundDeep}
        reducedMotion={reducedMotion}
      />
      <SafeAreaView edges={['top', 'bottom']} style={styles.safe}>
        <View style={styles.topbar}>
          <IconButton
            name="chevron-down"
            label="Close player"
            iconSize={22}
            size={48}
            onPress={() => router.back()}
            backgroundColor={glass.tintDeep}
            borderColor={glass.edge}
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
            backgroundColor={glass.tintDeep}
            borderColor={glass.edge}
            onPress={() => {
              tapFeedback('light');
              library.toggleFavorite(track.id);
            }}
          />
        </View>

        <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
          <View style={styles.artworkShell}>
            <GlassSurface
              variant="card"
              radius={radii.xl + 8}
              borderColor={player.palette.glow}
              glowColor={player.palette.glow}
              style={styles.artworkFrame}
            >
              <CrossfadeArtwork
                uri={track.artwork}
                fallbackText={track.title.slice(0, 1).toUpperCase()}
                fallbackColor={player.palette.accent}
                fallbackInk={player.palette.accentInk}
                fallbackSize={86}
                style={styles.artwork}
                sharedTransitionTag="now-playing-artwork"
                reducedMotion={reducedMotion}
              />
            </GlassSurface>
          </View>

          <View style={styles.trackInfo}>
            <AppText variant="title" color={colors.ink} numberOfLines={2}>{track.title}</AppText>
            <AppText variant="body" color={colors.inkMuted} numberOfLines={1}>{track.artist}</AppText>
            <AppText variant="micro" color={colors.inkFaint} numberOfLines={1}>{track.album}</AppText>
          </View>

          <SeekBar
            progress={playback.progress}
            duration={playback.duration}
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
  artworkFrame: {
    width: '100%',
    maxWidth: 312,
    padding: 6,
  },
  artwork: {
    width: '100%',
    aspectRatio: 1,
    borderRadius: radii.xl,
    overflow: 'hidden',
    backgroundColor: colors.surfaceRaised,
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