import Feather from '@expo/vector-icons/Feather';
import { LinearGradient } from 'expo-linear-gradient';
import { useEffect, useMemo, useRef, useState } from 'react';
import {
  Image,
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  View,
  type ScrollViewInstance,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { createMMKV } from 'react-native-mmkv';

import { AppText } from './AppText';
import { CoverArt } from './Artwork';
import { IconButton } from './IconButton';
import { usePlayer, usePlayerProgress } from '../playback/PlayerContext';
import {
  fonts,
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  withAlpha,
  type AppTheme,
} from '../theme';
import { resolveLyrics, type LyricsResult } from '../lyrics';
import { activeLyricIndex, displayLyricLines } from '../lyrics/view';

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
  const [loaded, setLoaded] = useState<{ uri: string; result: LyricsResult } | null>(null);
  const [offsetState, setOffsetState] = useState<{ uri: string; value: number } | null>(null);
  const [viewportHeight, setViewportHeight] = useState(0);
  const scrollRef = useRef<ScrollViewInstance>(null);
  const lineOffsets = useRef<number[]>([]);
  const userScrollUntil = useRef(0);

  useEffect(() => {
    if (!visible || !trackUri) return;
    let cancelled = false;
    void resolveLyrics(trackUri)
      .then((next) => {
        if (!cancelled) setLoaded({ uri: trackUri, result: next });
      })
      .catch(() => {
        if (!cancelled) {
          setLoaded({
            uri: trackUri,
            result: { source: 'none', sourceLabel: 'Source: none', synced: false, lines: [] },
          });
        }
      });
    return () => {
      cancelled = true;
    };
  }, [visible, trackUri]);

  useEffect(() => {
    lineOffsets.current = [];
  }, [trackUri]);

  useEffect(() => {
    if (!visible) return;
    userScrollUntil.current = 0;
    scrollRef.current?.scrollTo({ y: 0, animated: false });
  }, [visible, trackUri]);

  const savedOffset = useMemo(() => {
    if (!trackUri) return 0;
    const saved = store.getNumber(`offset:${trackUri}`);
    return typeof saved === 'number' ? saved : 0;
  }, [trackUri]);
  const offset = offsetState?.uri === trackUri ? offsetState.value : savedOffset;
  const result = loaded?.uri === trackUri ? loaded.result : null;
  const loading = visible && Boolean(trackUri) && result === null;
  const lines = useMemo(
    () => (result ? displayLyricLines(result.lines) : []),
    [result],
  );
  const synced = Boolean(result?.synced && lines.some((line) => line.time !== null));
  const progressMs = playback.progress * 1000;
  const activeIndex = useMemo(
    () => (synced ? activeLyricIndex(lines, progressMs, offset) : -1),
    [lines, offset, progressMs, synced],
  );

  useEffect(() => {
    if (!visible || activeIndex < 0 || viewportHeight <= 0) return;
    if (Date.now() < userScrollUntil.current) return;
    const y = lineOffsets.current[activeIndex];
    if (typeof y !== 'number') return;
    scrollRef.current?.scrollTo({
      y: Math.max(0, y - viewportHeight * 0.32),
      animated: true,
    });
  }, [activeIndex, viewportHeight, visible]);

  const persistOffset = (value: number) => {
    if (!trackUri) return;
    setOffsetState({ uri: trackUri, value });
    store.set(`offset:${trackUri}`, value);
  };

  const nudge = (delta: number) => {
    persistOffset(offset + delta);
  };

  const reset = () => {
    persistOffset(0);
  };

  const track = player.activeTrack;
  const title = track?.title ?? trackTitle;
  const artist = track?.artist ?? 'Unknown artist';

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose} statusBarTranslucent>
      <View style={styles.root}>
        {track?.artwork ? (
          <Image
            source={{ uri: track.artwork }}
            blurRadius={36}
            resizeMode="cover"
            style={styles.backdropArtwork}
          />
        ) : null}
        <View style={styles.backdropScrim} />
        <LinearGradient
          pointerEvents="none"
          colors={[withAlpha(palette.backgroundDeep, 0.55), palette.backgroundDeep]}
          locations={[0, 0.72]}
          style={styles.backdropGradient}
        />

        <SafeAreaView style={styles.safe} edges={['top', 'bottom']}>
          <View style={styles.grabberRow} pointerEvents="none">
            <View style={[styles.grabber, { backgroundColor: palette.inkFaint }]} />
          </View>
          <View style={styles.header}>
            <IconButton
              name="chevron-down"
              label="Close lyrics"
              iconSize={22}
              size={48}
              onPress={onClose}
            />
            <AppText variant="overline" color={palette.inkMuted}>Lyrics</AppText>
            <View style={styles.headerSpacer} />
          </View>

          <View style={styles.body}>
            {loading ? (
              <View style={styles.empty}>
                <AppText variant="body" color={palette.inkMuted}>Loading lyrics…</AppText>
              </View>
            ) : lines.length === 0 ? (
              <View style={styles.empty}>
                <Feather name="align-left" size={28} color={palette.inkFaint} />
                <AppText variant="heading" color={palette.ink} style={styles.emptyTitle}>
                  No lyrics for this track
                </AppText>
                <AppText variant="body" color={palette.inkMuted} style={styles.emptyBody}>
                  Add a .lrc file beside the song with the same name.
                </AppText>
              </View>
            ) : (
              <>
                <ScrollView
                  ref={scrollRef}
                  style={styles.scroll}
                  contentContainerStyle={[
                    styles.scrollContent,
                    {
                      paddingTop: Math.max(64, viewportHeight * 0.3),
                      paddingBottom: Math.max(104, viewportHeight * 0.42),
                    },
                  ]}
                  showsVerticalScrollIndicator={false}
                  onLayout={(event) => setViewportHeight(event.nativeEvent.layout.height)}
                  onScrollBeginDrag={() => {
                    userScrollUntil.current = Date.now() + 4000;
                  }}
                  onMomentumScrollBegin={() => {
                    userScrollUntil.current = Date.now() + 4000;
                  }}
                >
                  {lines.map((line, index) => {
                    const isActive = synced && index === activeIndex;
                    const canSeek = synced && line.time !== null;
                    return (
                      <Pressable
                        key={`${line.time ?? 'text'}-${index}`}
                        accessibilityRole={canSeek ? 'button' : undefined}
                        accessibilityLabel={canSeek ? `Play from ${line.text}` : undefined}
                        accessibilityState={canSeek ? { selected: isActive } : undefined}
                        onPress={
                          canSeek
                            ? () => player.seekTo(Math.max(0, (line.time! + offset) / 1000))
                            : undefined
                        }
                        onLayout={(event) => {
                          lineOffsets.current[index] = event.nativeEvent.layout.y;
                          if (index === activeIndex && viewportHeight > 0) {
                            const y = event.nativeEvent.layout.y;
                            requestAnimationFrame(() => {
                              scrollRef.current?.scrollTo({
                                y: Math.max(0, y - viewportHeight * 0.32),
                                animated: false,
                              });
                            });
                          }
                        }}
                        style={({ pressed }) => [
                          styles.line,
                          pressed && canSeek ? styles.linePressed : null,
                        ]}
                      >
                        <AppText
                          style={styles.lineText}
                          color={isActive ? palette.ink : palette.inkMuted}
                        >
                          {line.text}
                        </AppText>
                      </Pressable>
                    );
                  })}
                </ScrollView>
                <LinearGradient
                  pointerEvents="none"
                  colors={[palette.backgroundDeep, 'transparent']}
                  style={styles.fadeTop}
                />
                <LinearGradient
                  pointerEvents="none"
                  colors={['transparent', palette.backgroundDeep]}
                  style={styles.fadeBottom}
                />
              </>
            )}
          </View>

          {synced ? (
            <View style={styles.offsetRow}>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="Shift lyrics earlier by half a second"
                onPress={() => nudge(-500)}
                style={({ pressed }) => [styles.offsetBtn, { opacity: pressed ? 0.7 : 1 }]}
              >
                <AppText variant="label" color={palette.ink}>−0.5s</AppText>
              </Pressable>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="Reset lyric sync"
                onPress={reset}
                style={({ pressed }) => [styles.offsetBtn, { opacity: pressed ? 0.7 : 1 }]}
              >
                <AppText variant="label" color={palette.ink}>Reset</AppText>
              </Pressable>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="Shift lyrics later by half a second"
                onPress={() => nudge(500)}
                style={({ pressed }) => [styles.offsetBtn, { opacity: pressed ? 0.7 : 1 }]}
              >
                <AppText variant="label" color={palette.ink}>+0.5s</AppText>
              </Pressable>
            </View>
          ) : null}

          <View style={styles.nowPlaying}>
            <CoverArt uri={track?.artwork} size={40} radius={12} label={title} icon="music" />
            <View style={styles.nowPlayingText}>
              <AppText variant="label" color={palette.ink} numberOfLines={1}>{title}</AppText>
              <AppText variant="micro" color={palette.inkMuted} numberOfLines={1}>{artist}</AppText>
            </View>
            <IconButton
              name={player.isPlaying ? 'pause' : 'play'}
              label={player.isPlaying ? 'Pause' : 'Play'}
              iconSize={20}
              size={44}
              onPress={() => void player.togglePlayback()}
            />
          </View>

          <AppText variant="micro" color={palette.inkFaint} style={styles.source}>
            {result?.sourceLabel ?? 'Source: none'}
          </AppText>
        </SafeAreaView>
      </View>
    </Modal>
  );
}

const createStyles = ({ palette, glass }: AppTheme) => ({
  root: {
    flex: 1,
    backgroundColor: palette.backgroundDeep,
  },
  backdropArtwork: {
    position: 'absolute' as const,
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    opacity: 0.5,
  },
  backdropScrim: {
    position: 'absolute' as const,
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: withAlpha(palette.backgroundDeep, 0.72),
  },
  backdropGradient: {
    position: 'absolute' as const,
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
  },
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
  header: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    justifyContent: 'space-between' as const,
    paddingHorizontal: spacing.md,
    paddingTop: spacing.sm,
  },
  headerSpacer: { width: 48, height: 48 },
  body: {
    flex: 1,
    overflow: 'hidden' as const,
  },
  scroll: { flex: 1 },
  scrollContent: {
    paddingHorizontal: spacing.xl,
    gap: spacing.xs,
  },
  line: {
    minHeight: 44,
    justifyContent: 'center' as const,
    paddingVertical: spacing.xs,
  },
  linePressed: { opacity: 0.7 },
  lineText: {
    fontFamily: fonts.display,
    fontSize: 26,
    lineHeight: 36,
    letterSpacing: -0.3,
  },
  empty: {
    flex: 1,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
    gap: spacing.sm,
    paddingHorizontal: spacing.xl,
  },
  emptyTitle: { textAlign: 'center' as const },
  emptyBody: { textAlign: 'center' as const, maxWidth: 320 },
  fadeTop: {
    position: 'absolute' as const,
    top: 0,
    left: 0,
    right: 0,
    height: 56,
  },
  fadeBottom: {
    position: 'absolute' as const,
    bottom: 0,
    left: 0,
    right: 0,
    height: 72,
  },
  offsetRow: {
    flexDirection: 'row' as const,
    justifyContent: 'center' as const,
    alignItems: 'center' as const,
    gap: spacing.sm,
    paddingVertical: spacing.xs,
  },
  offsetBtn: {
    minHeight: 44,
    minWidth: 72,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
    paddingHorizontal: spacing.md,
    borderRadius: radii.pill,
    backgroundColor: glass.tintSoft,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeSoft,
  },
  nowPlaying: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.md,
    marginHorizontal: spacing.lg,
    padding: spacing.sm,
    borderRadius: radii.lg,
    backgroundColor: glass.tintSoft,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeSoft,
  },
  nowPlayingText: { flex: 1, gap: spacing.xxs },
  source: {
    textAlign: 'center' as const,
    paddingTop: spacing.xs,
    paddingBottom: spacing.xs,
  },
});
