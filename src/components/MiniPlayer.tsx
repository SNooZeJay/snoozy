import Feather from '@expo/vector-icons/Feather';
import { router } from 'expo-router';
import {
  Pressable,
  StyleSheet,
  View,
} from 'react-native';
import Animated, {
  FadeIn,
  FadeInDown,
  FadeOut,
  useAnimatedStyle,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { collapseProgress } from '../motion/chrome';
import { tabScrollY } from '../motion/scrollState';
import { usePlayer } from '../playback/PlayerContext';
import {
  layout,
  motion,
  radii,
  spacing,
  useTheme,
} from '../theme';
import { AppText } from './AppText';
import { CrossfadeArtwork } from './CrossfadeArtwork';
import { GlassSurface, type GlassBlurTarget } from './glass/GlassSurface';
import { ScalePressable } from './ScalePressable';

type MiniPlayerProps = {
  /** Stack screens have no tab bar, so the player sits at the safe-area edge. */
  standalone?: boolean;
  /** Live backdrop for the floating capsule on tab screens. */
  blurTarget?: GlassBlurTarget;
};

/**
 * Glasmio / Apple Music floating Liquid Glass MiniPlayer bar:
 * - Translucent frosted capsule with 0.5pt specular border & artwork glow
 * - 44pt squircle cover art, bold title + secondary artist
 * - Inline Play/Pause and Next controls with Cupertino compression physics
 */
export function MiniPlayer({ standalone = false, blurTarget }: MiniPlayerProps) {
  const { activeTrack, isPlaying, togglePlayback, next, palette: artworkPalette } = usePlayer();
  const { palette, glass, reducedMotion } = useTheme();
  const insets = useSafeAreaInsets();

  const dockStyle = useAnimatedStyle(() => {
    if (standalone) return {};
    const progress = collapseProgress(tabScrollY.value);
    return {
      transform: [{ translateY: progress * 10 }, { scale: 1 - progress * 0.01 }],
    };
  });

  if (!activeTrack) return null;

  const enter = reducedMotion
    ? FadeIn.duration(motion.durations.short)
    : FadeInDown.duration(motion.durations.long);

  return (
    <Animated.View
      entering={enter}
      exiting={FadeOut.duration(motion.durations.short)}
      style={[
        styles.shell,
        {
          bottom: standalone
            ? insets.bottom + spacing.md
            : insets.bottom + layout.tabBarInset + layout.tabBarHeight + layout.pillGap,
        },
        dockStyle,
      ]}
    >
      <GlassSurface
        variant="panel"
        radius={radii.lg}
        borderColor={glass.edgeStrong}
        glowColor={artworkPalette.glow}
        blurTarget={blurTarget}
        blurIntensity={62}
        style={styles.card}
      >
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={`Open player for ${activeTrack.title}`}
          hitSlop={{ top: 2, bottom: 2 }}
          onPress={() => router.push('/player')}
          style={({ pressed }) => [styles.info, { opacity: pressed ? 0.62 : 1 }]}
        >
          <CrossfadeArtwork
            uri={activeTrack.artwork}
            fallbackText={activeTrack.title.slice(0, 1).toUpperCase()}
            fallbackColor={artworkPalette.accent}
            fallbackInk={artworkPalette.accentInk}
            fallbackSize={18}
            style={styles.artwork}
            sharedTransitionTag="now-playing-artwork"
            reducedMotion={reducedMotion}
          />
          <View style={styles.text}>
            <AppText variant="label" color={palette.ink} numberOfLines={1}>{activeTrack.title}</AppText>
            <AppText variant="micro" color={palette.inkMuted} numberOfLines={1}>{activeTrack.artist}</AppText>
          </View>
        </Pressable>
        <View style={styles.controls}>
          <ScalePressable
            accessibilityRole="button"
            accessibilityLabel={isPlaying ? 'Pause' : 'Play'}
            onPress={() => void togglePlayback()}
            reducedMotion={reducedMotion}
            style={styles.controlButton}
          >
            <Feather name={isPlaying ? 'pause' : 'play'} size={21} color={palette.ink} />
          </ScalePressable>
          <ScalePressable
            accessibilityRole="button"
            accessibilityLabel="Next track"
            onPress={() => void next()}
            reducedMotion={reducedMotion}
            style={styles.controlButton}
          >
            <Feather name="fast-forward" size={20} color={palette.ink} />
          </ScalePressable>
        </View>
      </GlassSurface>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  shell: {
    position: 'absolute',
    left: layout.screenPadding,
    right: layout.screenPadding,
  },
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingHorizontal: spacing.sm,
    paddingVertical: 7,
    borderRadius: radii.lg,
  },
  info: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
  },
  artwork: {
    width: 44,
    height: 44,
    borderRadius: radii.sm + 2,
    overflow: 'hidden',
  },
  text: {
    flex: 1,
    gap: 1,
  },
  controls: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
  },
  controlButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
