import Feather from '@expo/vector-icons/Feather';
import { router } from 'expo-router';
import { useState } from 'react';
import {
  Pressable,
  ScrollView,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { createMMKV } from 'react-native-mmkv';

import { AppText } from '../../components/AppText';
import { EmptyState } from '../../components/EmptyState';
import { GlassSurface } from '../../components/glass/GlassSurface';
import { ListGroup } from '../../components/ListGroup';
import { ListRow } from '../../components/ListRow';
import { ScreenHeader } from '../../components/ScreenHeader';
import { SectionHeader } from '../../components/SectionHeader';
import { Thumb } from '../../components/Thumb';
import { useMusicLibrary } from '../../storage/MusicLibraryContext';
import { usePlayer } from '../../playback/PlayerContext';
import { usePreferences } from '../../storage/PreferencesContext';
import {
  layout,
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  type AppTheme,
} from '../../theme';

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
  const { palette, dark } = useTheme();
  const styles = useThemedStyles(createStyles);
  const [query, setQuery] = useState('');
  const [recents, setRecents] = useState<string[]>(() => readRecents());

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
    <SafeAreaView style={[styles.safe, { backgroundColor: palette.background }]} edges={['top']}>
      <ScreenHeader
        title="Search"
        subtitle="Songs, artists, and albums on this device"
      />
      <GlassSurface variant="field" style={styles.searchBar}>
        <Feather name="search" size={20} color={palette.inkMuted} />
        <TextInput
          value={query}
          onChangeText={setQuery}
          onSubmitEditing={submit}
          placeholder="Search songs, artists, albums"
          placeholderTextColor={palette.inkFaint}
          selectionColor={palette.accent}
          keyboardAppearance={dark ? 'dark' : 'light'}
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
            <Feather name="x" size={20} color={palette.inkMuted} />
          </Pressable>
        ) : (
          // Decorative filter motif from the reference — not a control, so
          // it is hidden from accessibility and ignores touches.
          <View style={styles.fieldAction} pointerEvents="none" accessibilityElementsHidden>
            <Feather name="sliders" size={20} color={palette.inkFaint} />
          </View>
        )}
      </GlassSurface>

      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        {player.error ? (
          <View style={styles.errorBanner}>
            <Feather name="alert-triangle" size={18} color={palette.danger} />
            <AppText variant="label" color={palette.danger} style={styles.errorText}>
              {player.error}
            </AppText>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Dismiss error"
              hitSlop={8}
              onPress={player.dismissError}
              style={styles.errorClose}
            >
              <Feather name="x" size={18} color={palette.danger} />
            </Pressable>
          </View>
        ) : null}

        {!trimmed ? (
          recents.length > 0 ? (
            <>
              <SectionHeader
                label="Recent searches"
                actionLabel="Clear"
                onAction={() => {
                  tapFeedback('light');
                  clearRecents();
                }}
              />
              <ListGroup>
                {recents.map((recent) => (
                  <ListRow
                    key={recent}
                    leading={<Feather name="clock" size={18} color={palette.inkMuted} />}
                    title={recent}
                    onPress={() => {
                      tapFeedback('selection');
                      setQuery(recent);
                    }}
                    accessibilityLabel={`Search for ${recent}`}
                  />
                ))}
              </ListGroup>
            </>
          ) : (
            <EmptyState
              title="Search your library"
              message="Find a song, artist, or album from the music on this device."
              actionLabel="Browse library"
              onAction={browseLibrary}
            />
          )
        ) : results.length === 0 ? (
          <>
            <SectionHeader label="All songs" />
            <EmptyState
              compact
              title="No matching tracks"
              message={`Nothing matches “${trimmed}”.`}
            />
          </>
        ) : (
          <>
            <SectionHeader label={`All songs · ${results.length}`} />
            <ListGroup>
              {results.map((track) => (
                <ListRow
                  key={track.id}
                  leading={<Thumb track={track} size={44} />}
                  title={track.title}
                  subtitle={`${track.artist} · ${track.album}`}
                  onPress={() => {
                    tapFeedback('selection');
                    rememberQuery(trimmed);
                    void player.playTrack(track, results);
                  }}
                  accessibilityLabel={`Play ${track.title}`}
                  trailing={<Feather name="play" size={18} color={palette.inkMuted} />}
                />
              ))}
            </ListGroup>
          </>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

const createStyles = ({ palette }: AppTheme) => ({
  safe: { flex: 1 },
  searchBar: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.sm,
    marginHorizontal: layout.screenPadding,
    marginTop: spacing.sm,
    paddingHorizontal: spacing.lg,
    height: 52,
    borderRadius: radii.pill,
  },
  input: {
    flex: 1,
    height: '100%' as const,
    color: palette.ink,
    fontSize: 16,
    paddingVertical: 0,
  },
  fieldAction: {
    width: 48,
    height: 48,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  },
  content: {
    paddingTop: spacing.md,
    paddingBottom: layout.tabBarSpace,
    gap: spacing.lg,
  },
  errorBanner: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.sm,
    marginHorizontal: layout.screenPadding,
    padding: spacing.md,
    borderRadius: radii.md,
    backgroundColor: palette.dangerSoft,
    borderWidth: 1,
    borderColor: palette.danger,
  },
  errorText: { flex: 1 },
  errorClose: {
    width: 48,
    height: 48,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  },
});
