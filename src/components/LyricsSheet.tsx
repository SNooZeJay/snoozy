import { useEffect, useMemo, useRef, useState } from 'react';
import {
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  View,
} from 'react-native';
import { createMMKV } from 'react-native-mmkv';

import { AppText } from './AppText';
import { IconButton } from './IconButton';
import { usePlayer, usePlayerProgress } from '../playback/PlayerContext';
import {
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  type AppTheme,
} from '../theme';
import { resolveLyrics, type LyricsResult } from '../lyrics';

const store = createMMKV({ id: 'snoozy.lyrics.v1' });

type Props = {
  visible: boolean;
  onClose: () => void;
  trackUri: string | null;
  trackTitle: string;
};

export function LyricsSheet({ visible, onClose, trackUri, trackTitle }: Props) {
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  const player = usePlayer();
  const playback = usePlayerProgress();
  const [result, setResult] = useState<LyricsResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [offset, setOffset] = useState(0);
  const scrollRef = useRef<any>(null);

  useEffect(() => {
    if (!visible || !trackUri) return;
    let cancelled = false;
    const handle = setTimeout(() => {
      // Clear the previous track's lyrics before resolving the new file.
      setResult(null);
      setLoading(true);
      const key = `offset:${trackUri}`;
      const saved = store.getNumber(key);
      setOffset(typeof saved === 'number' ? saved : 0);
      void resolveLyrics(trackUri).then((r) => {
        if (cancelled) return;
        setResult(r);
        setLoading(false);
      }).catch(() => {
        if (cancelled) return;
        setResult({ source: 'none', sourceLabel: 'Source: none', synced: false, lines: [] });
        setLoading(false);
      });
    }, 0);
    return () => {
      cancelled = true;
      clearTimeout(handle);
    };
  }, [visible, trackUri]);

  const synced = result?.synced ?? false;
  const progressMs = playback.progress * 1000;

  const activeIndex = useMemo(() => {
    if (!result || !synced) return -1;
    const lines = result.lines;
    let idx = -1;
    for (let i = 0; i < lines.length; i++) {
      const t = lines[i].time;
      if (t === null) continue;
      if (t + offset <= progressMs) idx = i;
      else break;
    }
    return idx;
  }, [result, synced, progressMs, offset]);

  const persistOffset = (v: number) => {
    if (!trackUri) return;
    store.set(`offset:${trackUri}`, v);
  };

  const nudge = (delta: number) => {
    const next = offset + delta;
    setOffset(next);
    persistOffset(next);
  };
  const reset = () => {
    setOffset(0);
    persistOffset(0);
  };

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose} transparent>
      <View style={styles.backdrop}>
        <View style={styles.sheet}>
          <View style={styles.header}>
            <AppText variant="heading" color={palette.ink}>Lyrics</AppText>
            <IconButton name="x" label="Close lyrics" iconSize={20} size={48} onPress={onClose} />
          </View>
          <AppText variant="micro" color={palette.inkFaint} numberOfLines={1}>{trackTitle}</AppText>

          {loading ? (
            <AppText variant="body" color={palette.inkMuted}>Loading…</AppText>
          ) : !result || result.lines.length === 0 ? (
            <View style={styles.empty}>
              <AppText variant="body" color={palette.inkMuted}>No lyrics for this track</AppText>
              <AppText variant="micro" color={palette.inkFaint}>Add a .lrc file next to this song</AppText>
            </View>
          ) : (
            <ScrollView ref={scrollRef} style={styles.scroll} contentContainerStyle={styles.scrollContent}>
              {result.lines.map((line, i) => {
                const isActive = synced && i === activeIndex;
                return (
                  <Pressable
                    key={i}
                    accessibilityRole="button"
                    onPress={() => {
                      if (synced && line.time !== null) {
                        player.seekTo(Math.max(0, (line.time + offset) / 1000));
                      }
                    }}
                    style={[styles.line, isActive && styles.lineActive]}
                  >
                    <AppText variant="body" color={isActive ? palette.accent : palette.inkMuted}>
                      {line.text || ' '}
                    </AppText>
                  </Pressable>
                );
              })}
            </ScrollView>
          )}

          {synced && result && result.lines.length > 0 ? (
            <View style={styles.offsetRow}>
              <Pressable accessibilityRole="button" onPress={() => nudge(-500)} style={styles.offsetBtn}>
                <AppText variant="label" color={palette.ink}>-500ms</AppText>
              </Pressable>
              <Pressable accessibilityRole="button" onPress={reset} style={styles.offsetBtn}>
                <AppText variant="label" color={palette.ink}>Reset</AppText>
              </Pressable>
              <Pressable accessibilityRole="button" onPress={() => nudge(500)} style={styles.offsetBtn}>
                <AppText variant="label" color={palette.ink}>+500ms</AppText>
              </Pressable>
            </View>
          ) : null}

          <AppText variant="micro" color={palette.inkFaint}>{result?.sourceLabel ?? 'Source: none'}</AppText>
        </View>
      </View>
    </Modal>
  );
}

const createStyles = ({ palette, glass }: AppTheme) => ({
  backdrop: {
    flex: 1,
    backgroundColor: palette.scrim,
    justifyContent: 'flex-end' as const,
  },
  sheet: {
    backgroundColor: glass.tintStrong,
    borderTopLeftRadius: radii.xl,
    borderTopRightRadius: radii.xl,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeStrong,
    padding: spacing.lg,
    maxHeight: '80%' as const,
    gap: spacing.sm,
  },
  header: {
    flexDirection: 'row' as const,
    justifyContent: 'space-between' as const,
    alignItems: 'center' as const,
  },
  empty: {
    paddingVertical: spacing.xl,
    alignItems: 'center' as const,
    gap: spacing.xs,
  },
  scroll: { maxHeight: 320 },
  scrollContent: { gap: spacing.xs, paddingVertical: spacing.sm },
  line: { paddingVertical: 4 },
  lineActive: {
    backgroundColor: glass.tintAccent,
    borderRadius: radii.sm,
    paddingHorizontal: spacing.xs,
  },
  offsetRow: {
    flexDirection: 'row' as const,
    justifyContent: 'center' as const,
    gap: spacing.sm,
    paddingVertical: spacing.sm,
  },
  offsetBtn: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    borderRadius: radii.pill,
    backgroundColor: glass.tintSoft,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeSoft,
  },
});
