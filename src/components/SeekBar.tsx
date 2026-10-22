import { useState } from 'react';
import {
  Pressable,
  StyleSheet,
  View,
  type GestureResponderEvent,
} from 'react-native';

import { colors, fonts } from '../theme';
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
  accentColor = colors.accent,
}: SeekBarProps) {
  const [width, setWidth] = useState(0);
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
          <View style={[styles.fill, { width: `${ratio * 100}%`, backgroundColor: accentColor }]} />
        </View>
        <View
          pointerEvents="none"
          style={[
            styles.thumb,
            {
              left: Math.max(0, Math.min(width - 12, width * ratio - 6)),
              backgroundColor: accentColor,
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

const styles = StyleSheet.create({
  wrap: {
    width: '100%',
  },
  hitArea: {
    height: 30,
    justifyContent: 'center',
  },
  track: {
    height: 4,
    borderRadius: 2,
    backgroundColor: 'rgba(243, 240, 228, 0.15)',
    overflow: 'hidden',
  },
  fill: {
    height: '100%',
    borderRadius: 2,
    backgroundColor: colors.accent,
  },
  thumb: {
    position: 'absolute',
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: colors.accent,
    top: 9,
  },
  times: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 2,
  },
  time: {
    fontFamily: fonts.body,
    fontSize: 12,
    lineHeight: 16,
    color: colors.inkFaint,
    fontVariant: ['tabular-nums'],
  },
});
