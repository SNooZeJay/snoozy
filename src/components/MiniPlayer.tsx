import Feather from '@expo/vector-icons/Feather';
import { router } from 'expo-router';
import {
  Image,
  Pressable,
  StyleSheet,
  View,
} from 'react-native';
import Animated from 'react-native-reanimated';

import { usePlayer } from '../playback/PlayerContext';
import { colors, layout, radii, spacing } from '../theme';
import { AppText } from './AppText';

export function MiniPlayer() {
  const { activeTrack, isPlaying, togglePlayback, palette } = usePlayer();

  if (!activeTrack) return null;

  return (
    <View style={styles.shell}>
      <View style={[styles.card, { borderColor: palette.glow }]}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={`Open player for ${activeTrack.title}`}
          hitSlop={{ top: 2, bottom: 2 }}
          onPress={() => router.push('/player')}
          style={({ pressed }) => [styles.info, { opacity: pressed ? 0.75 : 1 }]}
        >
          <Animated.View sharedTransitionTag="now-playing-artwork" style={styles.artwork}>
            {activeTrack.artwork ? (
              <Image source={{ uri: activeTrack.artwork }} style={styles.artworkImage} />
            ) : (
              <View style={[styles.artworkFallback, { backgroundColor: palette.accent }]}>
                <AppText variant="title" color={palette.accentInk}>{activeTrack.title.slice(0, 1).toUpperCase()}</AppText>
              </View>
            )}
          </Animated.View>
          <View style={styles.text}>
            <AppText variant="label" color={colors.ink} numberOfLines={1}>{activeTrack.title}</AppText>
            <AppText variant="micro" color={colors.inkMuted} numberOfLines={1}>{activeTrack.artist}</AppText>
          </View>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={isPlaying ? 'Pause' : 'Play'}
          onPress={() => void togglePlayback()}
          style={({ pressed }) => [styles.playButton, { opacity: pressed ? 0.7 : 1 }]}
        >
          <Feather name={isPlaying ? 'pause' : 'play'} size={20} color={colors.ink} />
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  shell: {
    position: 'absolute',
    left: spacing.md,
    right: spacing.md,
    // Floats above the pill bottom bar (inset + bar height + gap).
    bottom: layout.tabBarInset + layout.tabBarHeight + layout.pillGap,
  },
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.sm,
    borderRadius: radii.lg,
    backgroundColor: colors.surfaceRaised,
    borderWidth: 1,
    borderColor: colors.border,
  },
  info: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  artwork: { width: 44, height: 44, borderRadius: radii.md, overflow: 'hidden' },
  artworkImage: { width: 44, height: 44 },
  artworkFallback: {
    width: 44,
    height: 44,
    borderRadius: radii.md,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.surfaceMuted,
  },
  text: { flex: 1, gap: 2 },
  playButton: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.surface,
  },
});