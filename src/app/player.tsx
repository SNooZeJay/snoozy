import { router } from 'expo-router';
import { useState } from 'react';

import {
  Pressable,
  ScrollView,
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
import {
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  type AppTheme,
} from '../theme';

export default function PlayerScreen() {
  const library = useMusicLibrary();
  const player = usePlayer();
  const playback = usePlayerProgress();
  const { tapFeedback } = usePreferences();
  const {
    backdropEnabled,
    backdropIntensity,
    reducedMotion,
    palette,
    glass,
  } = useTheme();
  const styles = useThemedStyles(createStyles);
  const [lyricsOpen, setLyricsOpen] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const track = player.activeTrack;
  const glowOpacity = backdropEnabled
    ? Math.max(0, Math.min(1, backdropIntensity / 100))
    : 0;

  if (!track) {
    return (
      <SafeAreaView style={[styles.safe, { backgroundColor: palette.background }]}>
        <View style={styles.empty}>
          <AppText variant="title" color={palette.ink}>No track selected</AppText>
          <Pressable
            accessibilityRole="button"
            onPress={() => router.back()}
            style={({ pressed }) => [styles.backButton, { opacity: pressed ? 0.75 : 1 }]}
          >
            <AppText variant="label" color={palette.accentInk}>Close</AppText>
          </Pressable>
        </View>
      </SafeAreaView>
    );
  }

  const isFavorite = library.favorites.has(track.id);

  return (
    <View style={[styles.root, { backgroundColor: palette.backgroundDeep }]}>
      <PaletteGlow
        color={player.palette.glow}
        intensity={glowOpacity}
        background={palette.backgroundDeep}
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
            <AppText variant="overline" color={palette.inkMuted}>Now playing</AppText>
          </View>
          <IconButton
            name="heart"
            label={isFavorite ? 'Remove favorite' : 'Add favorite'}
            iconSize={20}
            size={48}
            color={isFavorite ? player.palette.accent : palette.ink}
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
            <AppText variant="title" color={palette.ink} numberOfLines={2}>{track.title}</AppText>
            <AppText variant="body" color={palette.inkMuted} numberOfLines={1}>{track.artist}</AppText>
            <AppText variant="micro" color={palette.inkFaint} numberOfLines={1}>{track.album}</AppText>
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
              onPress={() => {
                tapFeedback('selection');
                setLyricsOpen(true);
              }}
            />
            <IconButton
              name="edit-3"
              label="Edit song"
              size={48}
              onPress={() => {
                tapFeedback('selection');
                setEditOpen(true);
              }}
            />
          </View>

          {player.error ? (
            <View style={styles.error}>
              <AppText variant="micro" color={palette.danger}>{player.error}</AppText>
            </View>
          ) : null}
        </ScrollView>
      </SafeAreaView>
      <LyricsSheet
        visible={lyricsOpen}
        onClose={() => setLyricsOpen(false)}
        trackUri={track.uri}
        trackTitle={track.title}
      />
      <SongEditSheet
        visible={editOpen}
        onClose={() => setEditOpen(false)}
        trackId={track.id}
        original={{ title: track.title, artist: track.artist, album: track.album }}
      />
    </View>
  );
}

const createStyles = ({ palette }: AppTheme) => ({
  root: { flex: 1 },
  safe: { flex: 1 },
  topbar: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    justifyContent: 'space-between' as const,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.sm,
  },
  topbarTitle: { alignItems: 'center' as const },
  content: { padding: spacing.lg, gap: spacing.xl, paddingBottom: 40 },
  artworkShell: { alignItems: 'center' as const },
  artworkFrame: {
    width: '100%' as const,
    maxWidth: 312,
    padding: 6,
  },
  artwork: {
    width: '100%' as const,
    aspectRatio: 1,
    borderRadius: radii.xl,
    overflow: 'hidden' as const,
    backgroundColor: palette.surfaceRaised,
  },
  trackInfo: { gap: spacing.xs, alignItems: 'center' as const },
  controls: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
    gap: spacing.xl,
  },
  secondaryControls: {
    flexDirection: 'row' as const,
    justifyContent: 'center' as const,
    gap: spacing.lg,
  },
  error: {
    padding: spacing.md,
    borderRadius: radii.md,
    backgroundColor: palette.dangerSoft,
  },
  empty: {
    flex: 1,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
    gap: spacing.md,
  },
  backButton: {
    minHeight: 44,
    justifyContent: 'center' as const,
    paddingHorizontal: spacing.lg,
    borderRadius: radii.pill,
    backgroundColor: palette.accent,
  },
});
