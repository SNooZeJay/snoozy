import { useState } from 'react';
import {
  Pressable,
  StyleSheet,
  View,
  type GestureResponderEvent,
} from 'react-native';

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

export function SeekBar({
  progress,
  duration,
  onSeek,
  accentColor,
}: SeekBarProps) {
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  const [width, setWidth] = useState(0);
  const resolvedAccent = accentColor ?? palette.accent;
  const ratio = width > 0 ? Math.min(1, Math.max(0, progress / Math.max(1, duration))) : 0;

  const seekFromEvent = (event: GestureResponderEvent) => {
    if (width <= 0 || duration <= 0) return;
    const x = Math.max(0, Math.min(width, event.nativeEvent.locationX));
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
          <View style={[styles.fill, { width: `${ratio * 100}%`, backgroundColor: resolvedAccent }]} />
        </View>
        <View
          pointerEvents="none"
          style={[
            styles.thumb,
            {
              left: Math.max(0, Math.min(width - 12, width * ratio - 6)),
              backgroundColor: resolvedAccent,
            },
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
    height: '100%' as const,
    borderRadius: 3,
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
