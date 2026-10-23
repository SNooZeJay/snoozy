import Feather from '@expo/vector-icons/Feather';
import { router } from 'expo-router';
import { useState } from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  TextInput,
  View,
} from 'react-native';
import Animated, { FadeIn, FadeInDown } from 'react-native-reanimated';
import { SafeAreaView } from 'react-native-safe-area-context';
import { createMMKV } from 'react-native-mmkv';

import { AppText } from '../../components/AppText';
import { GlassButton } from '../../components/glass/GlassButton';
import { GlassSurface } from '../../components/glass/GlassSurface';
import { DottedNote, Thumb } from '../../components/Thumb';
import { useMusicLibrary } from '../../storage/MusicLibraryContext';
import { usePlayer } from '../../playback/PlayerContext';
import { usePreferences } from '../../storage/PreferencesContext';
import { staggerEnter } from '../../motion/stagger';
import { colors, layout, radii, spacing, useTheme } from '../../theme';

const recentsStore = createMMKV({ id: 'snoozy.search.v1' });
const RECENTS_KEY = 'recentQueries';
const RECENTS_LIMIT = 5;

function readRecents(): string[] {
  try {
    const raw = recentsStore.getString(RECENTS_KEY);
    const parsed = raw ? (JSON.parse(raw) as string[]) : [];
    return Array.isArray(parsed) ? parsed.filter((q): q is string => typeof q === 'string') : [];
  } catch {
    return [];
  }
}

export default function SearchScreen() {
  const library = useMusicLibrary();
  const player = usePlayer();
  const { tapFeedback } = usePreferences();
  const { reducedMotion } = useTheme();
  const [query, setQuery] = useState('');
  const [recents, setRecents] = useState<string[]>(() => readRecents());

  // Card entrances: fades stay under reduced motion, the drop-in does not.
  const cardEnter = reducedMotion
    ? FadeIn.duration(240)
    : FadeInDown.duration(400);

  const trimmed = query.trim();

  // Persist a query when it is submitted or exercised, newest first.
  const rememberQuery = (value: string) => {
    const q = value.trim();
    if (!q) return;
    const next = [q, ...readRecents().filter((item) => item.toLowerCase() !== q.toLowerCase())].slice(0, RECENTS_LIMIT);
    try {
      recentsStore.set(RECENTS_KEY, JSON.stringify(next));
    } catch {
      // Recents are a nicety; never block search on storage failures.
    }
    setRecents(next);
  };

  const results = trimmed
    ? library.displayTracks.filter((track) => {
        const raw = library.tracksById.get(track.id);
        const haystacks = [
          `${track.title} ${track.artist} ${track.album}`,
          raw ? `${raw.title} ${raw.artist} ${raw.album}` : '',
        ];
        return haystacks.some((haystack) => haystack.toLowerCase().includes(trimmed.toLowerCase()));
      })
    : [];

  const submit = () => {
    if (!trimmed) return;
    tapFeedback('selection');
    rememberQuery(trimmed);
  };

  const clearRecents = () => {
    try {
      recentsStore.set(RECENTS_KEY, JSON.stringify([]));
    } catch {
      // ignore
    }
    setRecents([]);
  };

  const browseLibrary = () => {
    tapFeedback('selection');
    library.setTab('songs');
    router.push('/library');
  };

  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
      <GlassSurface variant="field" style={styles.searchBar}>
        <Feather name="search" size={20} color={colors.inkMuted} />
        <TextInput
          value={query}
          onChangeText={setQuery}
          onSubmitEditing={submit}
          placeholder="Search songs, artists, albums"
          placeholderTextColor={colors.inkFaint}
          style={styles.input}
          autoCorrect={false}
          returnKeyType="search"
        />
        {query ? (
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Clear search"
            hitSlop={8}
            onPress={() => {
              tapFeedback('light');
              setQuery('');
            }}
            style={styles.fieldAction}
          >
            <Feather name="x" size={20} color={colors.inkMuted} />
          </Pressable>
        ) : (
          // Decorative filter motif from the reference — not a control, so
          // it is hidden from accessibility and ignores touches.
          <View style={styles.fieldAction} pointerEvents="none" accessibilityElementsHidden>
            <Feather name="sliders" size={20} color={colors.inkFaint} />
          </View>
        )}
      </GlassSurface>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        {player.error ? (
          <View style={styles.errorBanner}>
            <Feather name="alert-triangle" size={18} color={colors.danger} />
            <AppText variant="label" color={colors.danger} style={styles.errorText}>
              {player.error}
            </AppText>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Dismiss error"
              hitSlop={8}
              onPress={player.dismissError}
              style={styles.errorClose}
            >
              <Feather name="x" size={18} color={colors.danger} />
            </Pressable>
          </View>
        ) : null}

        {!trimmed ? (
          recents.length > 0 ? (
            <Animated.View entering={cardEnter} style={styles.prompt}>
              <View style={styles.sectionHeader}>
                <AppText variant="heading" color={colors.ink}>Recent searches</AppText>
                <Pressable
                  accessibilityRole="button"
                  accessibilityLabel="Clear recent searches"
                  hitSlop={8}
                  onPress={() => {
                    tapFeedback('light');
                    clearRecents();
                  }}
                  style={styles.seeAll}
                >
                  <AppText variant="label" color={colors.inkMuted}>Clear</AppText>
                  <Feather name="x" size={14} color={colors.inkMuted} />
                </Pressable>
              </View>
              <GlassSurface variant="card" style={styles.recentCard}>
                {recents.map((recent) => (
                  <Pressable
                    key={recent}
                    accessibilityRole="button"
                    accessibilityLabel={`Search for ${recent}`}
                    onPress={() => {
                      tapFeedback('selection');
                      setQuery(recent);
                    }}
                    style={({ pressed }) => [styles.rowInner, pressed && styles.rowPressed]}
                  >
                    <Feather name="clock" size={18} color={colors.inkMuted} />
                    <AppText variant="body" color={colors.ink} numberOfLines={1} style={styles.rowText}>
                      {recent}
                    </AppText>
                  </Pressable>
                ))}
              </GlassSurface>
            </Animated.View>
          ) : (
            <Animated.View entering={cardEnter} style={styles.emptyPrompt}>
              <DottedNote size={96} />
              <AppText variant="title" color={colors.ink}>Search your library</AppText>
              <AppText variant="body" color={colors.inkMuted} style={styles.emptyCopy}>
                Find a song, artist, or album from the music on this device.
              </AppText>
              <Pressable
                accessibilityRole="button"
                onPress={browseLibrary}
                style={({ pressed }) => [styles.primaryButton, styles.emptyButton, { opacity: pressed ? 0.75 : 1 }]}
              >
                <AppText variant="label" color={colors.accentInk}>Browse library</AppText>
              </Pressable>
            </Animated.View>
          )
        ) : results.length === 0 ? (
          <View style={styles.resultsBlock}>
            <AppText variant="heading" color={colors.ink}>All songs</AppText>
            <View style={styles.emptyPrompt}>
              <DottedNote size={88} />
              <AppText variant="body" color={colors.inkMuted}>No matching tracks.</AppText>
            </View>
          </View>
        ) : (
          <View style={styles.resultsBlock}>
            <View style={styles.resultsHeader}>
              <AppText variant="heading" color={colors.ink}>All songs</AppText>
              <AppText variant="micro" color={colors.inkMuted}>
                {results.length} {results.length === 1 ? 'result' : 'results'}
              </AppText>
            </View>
            {results.map((track, index) => (
              <Animated.View
                key={track.id}
                entering={staggerEnter(index, reducedMotion)}
              >
                <GlassButton
                  accessibilityRole="button"
                  accessibilityLabel={`Play ${track.title}`}
                  onPress={() => {
                    tapFeedback('selection');
                    rememberQuery(trimmed);
                    void player.playTrack(track, results);
                  }}
                  variant="row"
                  radius={radii.lg}
                  style={styles.rowCard}
                >
                  <Thumb track={track} size={48} />
                  <View style={styles.rowText}>
                    <AppText variant="label" color={colors.ink} numberOfLines={1}>{track.title}</AppText>
                    <AppText variant="micro" color={colors.inkMuted} numberOfLines={1}>
                      {track.artist} · {track.album}
                    </AppText>
                  </View>
                  <Feather name="play" size={18} color={colors.inkMuted} />
                </GlassButton>
              </Animated.View>
            ))}
          </View>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  searchBar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    margin: spacing.lg,
    paddingHorizontal: spacing.lg,
    height: 52,
    borderRadius: radii.pill,
  },
  input: { flex: 1, height: '100%', color: colors.ink, fontSize: 16, paddingVertical: 0 },
  fieldAction: {
    width: 48,
    height: 48,
    alignItems: 'center',
    justifyContent: 'center',
  },
  content: { paddingHorizontal: spacing.lg, paddingBottom: layout.tabBarSpace, gap: spacing.md },
  errorBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    padding: spacing.md,
    borderRadius: radii.md,
    backgroundColor: colors.dangerSoft,
    borderWidth: 1,
    borderColor: colors.danger,
  },
  errorText: { flex: 1 },
  errorClose: { width: 48, height: 48, alignItems: 'center', justifyContent: 'center' },
  prompt: { gap: spacing.md, paddingTop: spacing.xl, alignItems: 'flex-start' },
  emptyPrompt: {
    flexDirection: 'column',
    alignItems: 'center',
    gap: spacing.md,
    paddingTop: spacing.xxl,
    paddingBottom: spacing.xxl,
  },
  emptyButton: { alignSelf: 'center' },
  emptyCopy: { textAlign: 'center' },
  resultsBlock: { gap: spacing.md },
  resultsHeader: {
    flexDirection: 'row',
    alignItems: 'baseline',
    justifyContent: 'space-between',
  },
  sectionHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', alignSelf: 'stretch' },
  seeAll: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    minHeight: 48,
    paddingLeft: spacing.md,
    justifyContent: 'center',
  },
  recentCard: {
    padding: spacing.xs,
    alignSelf: 'stretch',
    gap: 2,
  },
  rowInner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.sm,
    borderRadius: radii.md,
  },
  rowPressed: { opacity: 0.7, transform: [{ scale: 0.99 }] },
  rowCard: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'flex-start',
    gap: spacing.md,
    padding: spacing.xs,
    paddingLeft: spacing.sm,
    paddingRight: spacing.md,
  },
  primaryButton: {
    alignSelf: 'flex-start',
    minHeight: 48,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    borderRadius: radii.pill,
    backgroundColor: colors.accent,
    justifyContent: 'center',
  },
  rowText: { flex: 1, gap: 2 },
});
