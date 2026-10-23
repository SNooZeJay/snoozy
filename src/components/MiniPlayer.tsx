import Feather from '@expo/vector-icons/Feather';
import { router } from 'expo-router';
import {
  Pressable,
  StyleSheet,
  View,
} from 'react-native';
import Animated, { FadeIn, FadeInDown, FadeOut } from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

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
import { GlassSurface } from './glass/GlassSurface';
import { ScalePressable } from './ScalePressable';

type MiniPlayerProps = {
  /** Stack screens have no tab bar, so the player sits at the safe-area edge. */
  standalone?: boolean;
};

export function MiniPlayer({ standalone = false }: MiniPlayerProps) {
  const { activeTrack, isPlaying, togglePlayback, palette: artworkPalette } = usePlayer();
  const { palette, glass, reducedMotion } = useTheme();
  const insets = useSafeAreaInsets();

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
      ]}
    >
      <GlassSurface
        variant="card"
        radius={radii.lg}
        borderColor={artworkPalette.glow}
        glowColor={artworkPalette.glow}
        style={styles.card}
      >
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={`Open player for ${activeTrack.title}`}
          hitSlop={{ top: 2, bottom: 2 }}
          onPress={() => router.push('/player')}
          style={({ pressed }) => [styles.info, { opacity: pressed ? 0.75 : 1 }]}
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
        <ScalePressable
          accessibilityRole="button"
          accessibilityLabel={isPlaying ? 'Pause' : 'Play'}
          onPress={() => void togglePlayback()}
          reducedMotion={reducedMotion}
          style={[
            styles.playButton,
            {
              backgroundColor: glass.buttonTint,
              borderColor: glass.edge,
            },
          ]}
        >
          <Feather name={isPlaying ? 'pause' : 'play'} size={20} color={palette.ink} />
        </ScalePressable>
      </GlassSurface>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  shell: {
    position: 'absolute',
    left: spacing.md,
    right: spacing.md,
  },
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.sm,
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
    borderRadius: radii.md,
    overflow: 'hidden',
  },
  text: {
    flex: 1,
    gap: 2,
  },
  playButton: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: StyleSheet.hairlineWidth,
  },
});
