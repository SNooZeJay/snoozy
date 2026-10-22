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
import { MiniPlayer } from '../components/MiniPlayer';
import { getErrorLog, clearErrorLog, type ErrorLogEntry } from '../storage/errorLog';
import { colors, radii, spacing } from '../theme';

export default function ErrorLogScreen() {
  const [entries, setEntries] = useState<ErrorLogEntry[]>([]);
  const [loading, setLoading] = useState(true);

  const load = async () => {
    setLoading(true);
    setEntries(await getErrorLog());
    setLoading(false);
  };

  useEffect(() => {
    const h = setTimeout(() => { void load(); }, 0);
    return () => clearTimeout(h);
  }, []);

  const handleShare = async () => {
    const text = entries.map((e) => `${new Date(e.timestamp).toISOString()} [${e.category}] ${e.message}`).join('\n');
    await Share.share({ message: text, title: 'Snoozy error log' });
  };

  const handleClear = () => {
    Alert.alert('Clear error log', 'Delete all entries?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Clear', style: 'destructive', onPress: async () => { await clearErrorLog(); await load(); } },
    ]);
  };

  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <AppText variant="display" color={colors.ink}>Error log</AppText>
        <View style={styles.row}>
          <Pressable accessibilityRole="button" onPress={handleShare} style={styles.button}>
            <AppText variant="label" color={colors.accentInk}>Share log</AppText>
          </Pressable>
          <Pressable accessibilityRole="button" onPress={handleClear} style={styles.buttonSecondary}>
            <AppText variant="label" color={colors.danger}>Clear log</AppText>
          </Pressable>
        </View>
        {loading ? (
          <AppText variant="body" color={colors.inkMuted}>Loading…</AppText>
        ) : entries.length === 0 ? (
          <AppText variant="body" color={colors.inkMuted}>No errors recorded.</AppText>
        ) : (
          entries.map((e) => (
            <View key={e.id} style={styles.entry}>
              <AppText variant="micro" color={colors.inkFaint}>{new Date(e.timestamp).toLocaleString()} · {e.category}</AppText>
              <AppText variant="body" color={colors.ink}>{e.message}</AppText>
              {e.trackId ? <AppText variant="micro" color={colors.inkFaint}>track: {e.trackId}</AppText> : null}
            </View>
          ))
        )}
      </ScrollView>
      <MiniPlayer />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  content: { padding: spacing.lg, gap: spacing.md, paddingBottom: 150 },
  row: { flexDirection: 'row', gap: spacing.sm },
  button: { paddingHorizontal: spacing.lg, paddingVertical: spacing.sm, borderRadius: radii.pill, backgroundColor: colors.accent },
  buttonSecondary: { paddingHorizontal: spacing.lg, paddingVertical: spacing.sm, borderRadius: radii.pill, backgroundColor: colors.surfaceMuted, borderWidth: 1, borderColor: colors.border },
  entry: { gap: 2, padding: spacing.md, borderRadius: radii.md, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border },
});