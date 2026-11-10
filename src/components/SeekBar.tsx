import { useEffect, useRef, useState } from 'react';
import {
  Pressable,
  StyleSheet,
  View,
  type GestureResponderEvent,
} from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withTiming,
} from 'react-native-reanimated';

import {
  fonts,
  useTheme,
  useThemedStyles,
  withAlpha,
  type AppTheme,
} from '../theme';
import { formatClock } from '../utils/format';
import { AppText } from './AppText';

type SeekBarProps = {
  progress: number;
  duration: number;
  onSeek: (seconds: number) => void;
  accentColor?: string;
};

/**
 * Progress arrives once per second, so the fill and thumb tween across that
 * second instead of jumping: the playhead reads as continuous motion. A seek
 * backwards, a new track, or reduced motion snaps instead.
 */
const GLIDE_MS = 1000;

export function SeekBar({
  progress,
  duration,
  onSeek,
  accentColor,
}: SeekBarProps) {
  const { palette, reducedMotion } = useTheme();
  const styles = useThemedStyles(createStyles);
  const [width, setWidth] = useState(0);
  const resolvedAccent = accentColor ?? palette.accent;
  const ratio = width > 0 ? Math.min(1, Math.max(0, progress / Math.max(1, duration))) : 0;
  const glide = useSharedValue(0);
  const lastDuration = useRef(duration);
  // A tap must land the playhead immediately, so its value is consumed by the
  // next effect run (which the seek itself triggers) instead of a glide.
  const pendingSeek = useRef<number | null>(null);

  useEffect(() => {
    const trackChanged = duration !== lastDuration.current;
    const seeked = pendingSeek.current !== null;
    lastDuration.current = duration;
    pendingSeek.current = null;
    if (trackChanged || seeked || reducedMotion || ratio < glide.value) {
      glide.value = ratio;
      return;
    }
    glide.value = withTiming(ratio, {
      duration: GLIDE_MS,
      easing: Easing.linear,
    });
  }, [duration, glide, ratio, reducedMotion]);

  const fillStyle = useAnimatedStyle(() => ({
    transform: [{ scaleX: glide.value }],
  }));

  const thumbStyle = useAnimatedStyle(() => ({
    transform: [
      {
        translateX: Math.max(
          0,
          Math.min(Math.max(width - 12, 0), width * glide.value - 6),
        ),
      },
    ],
  }));

  const seekFromEvent = (event: GestureResponderEvent) => {
    if (width <= 0 || duration <= 0) return;
    const x = Math.max(0, Math.min(width, event.nativeEvent.locationX));
    pendingSeek.current = x / width;
    onSeek((x / width) * duration);
  };

  const nudge = (seconds: number) => {
    onSeek(Math.max(0, Math.min(duration, progress + seconds)));
  };

  return (
    <View style={styles.wrap}>
      <Pressable
        accessibilityRole="adjustable"
        accessibilityLabel="Playback position"
        accessibilityValue={{
          min: 0,
          max: Math.round(duration),
          now: Math.round(progress),
          text: `${formatClock(progress)} of ${formatClock(duration)}`,
        }}
        accessibilityActions={[
          { name: 'increment', label: 'Forward five seconds' },
          { name: 'decrement', label: 'Back five seconds' },
        ]}
        onAccessibilityAction={(event) => {
          if (event.nativeEvent.actionName === 'increment') nudge(5);
          if (event.nativeEvent.actionName === 'decrement') nudge(-5);
        }}
        onLayout={(event) => setWidth(event.nativeEvent.layout.width)}
        onPress={seekFromEvent}
        style={styles.hitArea}
      >
        <View style={styles.track}>
          <View style={styles.trackHighlight} pointerEvents="none" />
          <Animated.View
            pointerEvents="none"
            style={[
              styles.fill,
              { backgroundColor: resolvedAccent },
              fillStyle,
            ]}
          />
        </View>
        <Animated.View
          pointerEvents="none"
          style={[
            styles.thumb,
            {
              backgroundColor: resolvedAccent,
            },
            thumbStyle,
          ]}
        />
      </Pressable>
      <View style={styles.times}>
        <AppText style={styles.time}>{formatClock(progress)}</AppText>
        <AppText style={styles.time}>{formatClock(duration)}</AppText>
      </View>
    </View>
  );
}

const createStyles = ({ palette, glass }: AppTheme) => ({
  wrap: {
    width: '100%' as const,
  },
  hitArea: {
    height: 30,
    justifyContent: 'center' as const,
  },
  track: {
    height: 6,
    borderRadius: 3,
    backgroundColor: glass.tintSoft,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeSoft,
    overflow: 'hidden' as const,
  },
  trackHighlight: {
    position: 'absolute' as const,
    left: 0,
    right: 0,
    top: 0,
    height: 1,
    backgroundColor: withAlpha(palette.white, 0.16),
  },
  fill: {
    position: 'absolute' as const,
    left: 0,
    top: 0,
    bottom: 0,
    width: '100%' as const,
    borderRadius: 3,
    transformOrigin: 'left center' as const,
    backgroundColor: palette.accent,
  },
  thumb: {
    position: 'absolute' as const,
    width: 14,
    height: 14,
    borderRadius: 7,
    backgroundColor: palette.accent,
    borderWidth: 2,
    borderColor: withAlpha(palette.white, 0.46),
    top: 8,
    left: 0,
    shadowColor: palette.black,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
    elevation: 3,
  },
  times: {
    flexDirection: 'row' as const,
    justifyContent: 'space-between' as const,
    marginTop: 2,
  },
  time: {
    fontFamily: fonts.body,
    fontSize: 12,
    lineHeight: 16,
    color: palette.inkFaint,
    fontVariant: ['tabular-nums'] as const,
  },
});
