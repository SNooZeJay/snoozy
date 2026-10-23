import { router } from 'expo-router';
import { useEffect, useState } from 'react';
import {
  Alert,
  Pressable,
  ScrollView,
  Share,
  StyleSheet,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { AppText } from '../components/AppText';
import { EmptyState } from '../components/EmptyState';
import { IconButton } from '../components/IconButton';
import { ListGroup } from '../components/ListGroup';
import { MiniPlayer } from '../components/MiniPlayer';
import { ScreenHeader } from '../components/ScreenHeader';
import { getErrorLog, clearErrorLog, type ErrorLogEntry } from '../storage/errorLog';
import {
  layout,
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  type AppTheme,
} from '../theme';

export default function ErrorLogScreen() {
  const { palette, glass } = useTheme();
  const styles = useThemedStyles(createStyles);
  const [entries, setEntries] = useState<ErrorLogEntry[]>([]);
  const [loading, setLoading] = useState(true);

  const load = async () => {
    setLoading(true);
    try {
      setEntries(await getErrorLog());
    } catch {
      setEntries([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    let cancelled = false;
    const handle = setTimeout(() => {
      void (async () => {
        setLoading(true);
        try {
          const next = await getErrorLog();
          if (!cancelled) setEntries(next);
        } catch {
          if (!cancelled) setEntries([]);
        } finally {
          if (!cancelled) setLoading(false);
        }
      })();
    }, 0);
    return () => {
      cancelled = true;
      clearTimeout(handle);
    };
  }, []);

  const handleShare = async () => {
    const text = entries
      .map((entry) => `${new Date(entry.timestamp).toISOString()} [${entry.category}] ${entry.message}`)
      .join('\n');
    await Share.share({ message: text, title: 'Snoozy error log' });
  };

  const handleClear = () => {
    Alert.alert('Clear error log', 'Delete all entries?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Clear',
        style: 'destructive',
        onPress: async () => {
          await clearErrorLog();
          await load();
        },
      },
    ]);
  };

  return (
    <SafeAreaView style={[styles.safe, { backgroundColor: palette.background }]} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <ScreenHeader
          leading={(
            <IconButton
              name="chevron-left"
              label="Back"
              iconSize={22}
              size={44}
              onPress={() => router.back()}
              backgroundColor={glass.tintDeep}
              borderColor={glass.edgeSoft}
            />
          )}
          title="Error log"
          subtitle={loading
            ? 'Loading diagnostics…'
            : `${entries.length} ${entries.length === 1 ? 'entry' : 'entries'} recorded`}
        />

        <View style={styles.actions}>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Share error log"
            onPress={() => void handleShare()}
            style={({ pressed }) => [styles.button, { opacity: pressed ? 0.75 : 1 }]}
          >
            <AppText variant="label" color={palette.accentInk}>Share log</AppText>
          </Pressable>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Clear error log"
            onPress={handleClear}
            style={({ pressed }) => [styles.buttonSecondary, { opacity: pressed ? 0.75 : 1 }]}
          >
            <AppText variant="label" color={palette.danger}>Clear log</AppText>
          </Pressable>
        </View>

        {loading ? (
          <AppText variant="body" color={palette.inkMuted} style={styles.status}>Loading…</AppText>
        ) : entries.length === 0 ? (
          <EmptyState
            compact
            title="No errors recorded"
            message="Anything that goes wrong will appear here."
          />
        ) : (
          <ListGroup>
            {entries.map((entry, index) => (
              <View
                key={entry.id}
                style={[styles.entry, index > 0 && styles.entryDivider]}
              >
                <AppText variant="micro" color={palette.inkFaint}>
                  {new Date(entry.timestamp).toLocaleString()} · {entry.category}
                </AppText>
                <AppText variant="body" color={palette.ink}>{entry.message}</AppText>
                {entry.trackId ? (
                  <AppText variant="micro" color={palette.inkFaint}>
                    track: {entry.trackId}
                  </AppText>
                ) : null}
              </View>
            ))}
          </ListGroup>
        )}
      </ScrollView>
      <MiniPlayer standalone />
    </SafeAreaView>
  );
}

const createStyles = ({ palette, glass }: AppTheme) => ({
  safe: { flex: 1 },
  content: {
    paddingBottom: 150,
    gap: spacing.md,
  },
  actions: {
    flexDirection: 'row' as const,
    gap: spacing.sm,
    marginHorizontal: layout.screenPadding,
  },
  button: {
    minHeight: 44,
    justifyContent: 'center' as const,
    paddingHorizontal: spacing.lg,
    borderRadius: radii.pill,
    backgroundColor: palette.accent,
  },
  buttonSecondary: {
    minHeight: 44,
    justifyContent: 'center' as const,
    paddingHorizontal: spacing.lg,
    borderRadius: radii.pill,
    backgroundColor: glass.tintSoft,
    borderWidth: 1,
    borderColor: glass.edgeSoft,
  },
  status: {
    paddingHorizontal: layout.screenPadding,
  },
  entry: {
    gap: 2,
    padding: spacing.md,
  },
  entryDivider: {
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: palette.border,
  },
});
