import { router } from 'expo-router';
import { useState } from 'react';

import {
  Pressable,
  useWindowDimensions,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, {
  runOnJS,
  useAnimatedScrollHandler,
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  withTiming,
} from 'react-native-reanimated';

import { AppDialog } from '../components/AppDialog';
import { AppText } from '../components/AppText';
import { CrossfadeArtwork } from '../components/CrossfadeArtwork';
import { GlassSurface } from '../components/glass/GlassSurface';
import { IconButton } from '../components/IconButton';
import { PaletteGlow } from '../components/PaletteGlow';
import { PlayButton } from '../components/PlayButton';
import { QueueSheet } from '../components/QueueSheet';
import { LyricsSheet } from '../components/LyricsSheet';
import { SongEditSheet } from '../components/SongEditSheet';
import { SeekBar } from '../components/SeekBar';
import { albumKeyFor } from '../storage/albumGrouping';
import { useMusicLibrary } from '../storage/MusicLibraryContext';
import { usePlayer, usePlayerProgress } from '../playback/PlayerContext';
import { RepeatMode } from '../playback/player';
import { usePreferences } from '../storage/PreferencesContext';
import {
  motion,
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
  const { height: windowHeight } = useWindowDimensions();
  const dismissY = useSharedValue(0);
  const scrollY = useSharedValue(0);
  const [lyricsOpen, setLyricsOpen] = useState(false);
  const [queueOpen, setQueueOpen] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const [speedOpen, setSpeedOpen] = useState(false);
  const track = player.activeTrack;
  const glowOpacity = backdropEnabled
    ? Math.max(0, Math.min(1, backdropIntensity / 100))
    : 0;

  const dismissPan = Gesture.Pan()
    .enabled(!reducedMotion)
    .activeOffsetY(8)
    .failOffsetX([-30, 30])
    .onUpdate((event) => {
      dismissY.value = Math.max(0, event.translationY);
    })
    .onEnd((event) => {
      if (event.translationY > 120 || event.velocityY > 900) {
        dismissY.value = withTiming(windowHeight, { duration: 200 }, (finished) => {
          if (finished) runOnJS(router.back)();
        });
        return;
      }
      dismissY.value = withSpring(0, motion.springs.standard);
    });

  const dismissStyle = useAnimatedStyle(() => ({
    transform: [{ translateY: dismissY.value }],
  }));

  const onScroll = useAnimatedScrollHandler((event) => {
    scrollY.value = event.contentOffset.y;
  });

  const artworkStyle = useAnimatedStyle(() => {
    const progress = Math.min(1, Math.max(0, scrollY.value / 280));
    return {
      transform: [
        { scale: 1 - progress * 0.12 },
        { translateY: -progress * 8 },
      ],
    };
  });

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
  const repeatLabel =
    player.repeatMode === RepeatMode.Off
      ? 'Repeat off. Turn on repeat all'
      : player.repeatMode === RepeatMode.All
        ? 'Repeat all. Turn on repeat one'
        : 'Repeat one song. Turn repeat off';
  const repeatActive = player.repeatMode !== RepeatMode.Off;

  return (
    <View style={[styles.root, { backgroundColor: palette.backgroundDeep }]}>
      <PaletteGlow
        color={player.palette.glow}
        intensity={glowOpacity}
        background={palette.backgroundDeep}
        reducedMotion={reducedMotion}
      />
      <Animated.View style={[styles.safe, dismissStyle]}>
        <SafeAreaView edges={['top', 'bottom']} style={styles.safe}>
          <GestureDetector gesture={dismissPan}>
            <View>
              <View style={styles.grabberRow} pointerEvents="none">
                <View style={[styles.grabber, { backgroundColor: palette.inkFaint }]} />
              </View>
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
            </View>
          </GestureDetector>

        <Animated.ScrollView
          contentContainerStyle={styles.content}
          showsVerticalScrollIndicator={false}
          onScroll={onScroll}
          scrollEventThrottle={16}
        >
          <Animated.View style={[styles.artworkShell, artworkStyle]}>
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
          </Animated.View>

          <View style={styles.trackInfo}>
            <AppText variant="title" color={palette.ink} numberOfLines={2}>{track.title}</AppText>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={`Open artist ${track.artist}`}
              onPress={() => {
                tapFeedback('selection');
                router.push({ pathname: '/artist', params: { artist: track.artist } });
              }}
              hitSlop={6}
            >
              <AppText variant="body" color={palette.inkMuted} numberOfLines={1}>{track.artist}</AppText>
            </Pressable>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={`Open album ${track.album}`}
              onPress={() => {
                tapFeedback('selection');
                router.push({ pathname: '/album', params: { albumKey: albumKeyFor(track) } });
              }}
              hitSlop={6}
            >
              <AppText variant="micro" color={palette.inkFaint} numberOfLines={1}>{track.album}</AppText>
            </Pressable>
          </View>

          <SeekBar
            progress={playback.progress}
            duration={playback.duration}
            onSeek={player.seekTo}
            accentColor={player.palette.accent}
          />

          <View style={styles.controls}>
            <IconButton
              name="shuffle"
              label={player.shuffle ? 'Turn shuffle off' : 'Turn shuffle on'}
              iconSize={20}
              size={48}
              color={player.shuffle ? player.palette.accent : palette.inkMuted}
              backgroundColor={player.shuffle ? glass.tintAccent : undefined}
              borderColor={player.shuffle ? player.palette.accent : undefined}
              onPress={() => {
                tapFeedback('selection');
                player.toggleShuffle();
              }}
            />
            <IconButton name="skip-back" label="Previous" iconSize={24} size={52} onPress={() => void player.previous()} />
            <PlayButton
              playing={player.isPlaying}
              onPress={() => void player.togglePlayback()}
              size={76}
              accentColor={player.palette.accent}
              accentInk={player.palette.accentInk}
            />
            <IconButton name="skip-forward" label="Next" iconSize={24} size={52} onPress={() => void player.next()} />
            <View style={styles.repeatShell}>
              <IconButton
                name="repeat"
                label={repeatLabel}
                iconSize={20}
                size={48}
                color={repeatActive ? player.palette.accent : palette.inkMuted}
                backgroundColor={repeatActive ? glass.tintAccent : undefined}
                borderColor={repeatActive ? player.palette.accent : undefined}
                onPress={() => {
                  tapFeedback('selection');
                  player.cycleRepeat();
                }}
              />
              {player.repeatMode === RepeatMode.One ? (
                <View
                  pointerEvents="none"
                  style={[styles.repeatBadge, { backgroundColor: player.palette.accent }]}
                >
                  <AppText variant="micro" color={player.palette.accentInk} style={styles.repeatBadgeText}>1</AppText>
                </View>
              ) : null}
            </View>
          </View>

          <View style={styles.secondaryControls}>
            <IconButton
              name="align-left"
              label="Lyrics"
              size={48}
              onPress={() => {
                tapFeedback('selection');
                setLyricsOpen(true);
              }}
            />
            <IconButton
              name="list"
              label="Queue"
              size={48}
              onPress={() => {
                tapFeedback('selection');
                setQueueOpen(true);
              }}
            />
            <IconButton
              name="fast-forward"
              label={`Playback speed ${player.playbackRate}x`}
              size={48}
              color={player.playbackRate !== 1 ? player.palette.accent : undefined}
              onPress={() => {
                tapFeedback('selection');
                setSpeedOpen(true);
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
        </Animated.ScrollView>
        </SafeAreaView>
      </Animated.View>
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
      <QueueSheet visible={queueOpen} onClose={() => setQueueOpen(false)} />
      <AppDialog
        visible={speedOpen}
        title="Playback speed"
        message={`Currently ${player.playbackRate}x`}
        onClose={() => setSpeedOpen(false)}
        actions={[
          ...[0.75, 1, 1.25, 1.5].map((rate) => ({
            label: rate === 1 ? 'Normal (1x)' : `${rate}x`,
            onPress: () => player.setPlaybackRate(rate),
          })),
          { label: 'Cancel', onPress: () => {} },
        ]}
      />
    </View>
  );
}

const createStyles = ({ palette }: AppTheme) => ({
  root: { flex: 1 },
  safe: { flex: 1 },
  grabberRow: {
    alignItems: 'center' as const,
    paddingTop: spacing.sm,
  },
  grabber: {
    width: 36,
    height: 5,
    borderRadius: 2.5,
    opacity: 0.55,
  },
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
    justifyContent: 'space-between' as const,
    paddingHorizontal: spacing.xs,
  },
  repeatShell: {
    width: 48,
    height: 48,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  },
  repeatBadge: {
    position: 'absolute' as const,
    top: -1,
    right: -1,
    minWidth: 16,
    height: 16,
    borderRadius: 8,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
    paddingHorizontal: 2,
  },
  repeatBadgeText: {
    fontSize: 9,
    lineHeight: 11,
  },
  secondaryControls: {
    flexDirection: 'row' as const,
    justifyContent: 'center' as const,
    flexWrap: 'wrap' as const,
    gap: spacing.sm,
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
