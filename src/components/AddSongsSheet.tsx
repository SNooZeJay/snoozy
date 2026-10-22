import Feather from '@expo/vector-icons/Feather';
import { useMemo, useState } from 'react';
import {
  KeyboardAvoidingView,
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import type { Track } from '../types/music';
import { colors, radii, spacing } from '../theme';
import { AppText } from './AppText';

type AddSongsSheetProps = {
  visible: boolean;
  onClose: () => void;
  playlistName: string | null;
  playlistTrackIds: string[];
  tracks: Track[];
  onAdd: (trackId: string) => void;
  onRemove: (trackId: string) => void;
};

export function AddSongsSheet({
  visible,
  onClose,
  playlistName,
  playlistTrackIds,
  tracks,
  onAdd,
  onRemove,
}: AddSongsSheetProps) {
  const insets = useSafeAreaInsets();
  const [filter, setFilter] = useState('');

  const inPlaylist = useMemo(() => new Set(playlistTrackIds), [playlistTrackIds]);

  const visibleTracks = useMemo(() => {
    const q = filter.trim().toLowerCase();
    if (!q) return tracks;
    return tracks.filter((track) =>
      `${track.title} ${track.artist} ${track.album}`.toLowerCase().includes(q),
    );
  }, [filter, tracks]);

  if (!visible || !playlistName) return null;

  return (
    <Modal visible transparent animationType="fade" statusBarTranslucent onRequestClose={onClose}>
      <KeyboardAvoidingView behavior="padding" style={styles.backdrop}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Close add songs"
          onPress={onClose}
          style={StyleSheet.absoluteFill}
        />
        <View
          style={[
            styles.panel,
            { paddingBottom: insets.bottom + spacing.md },
          ]}
        >
          <View style={styles.header}>
            <View style={styles.headerText}>
              <AppText variant="heading" color={colors.ink} numberOfLines={1}>Add songs</AppText>
              <AppText variant="micro" color={colors.inkMuted} numberOfLines={1}>
                {'\u201C'}{playlistName}{'\u201D'} · {playlistTrackIds.length} {playlistTrackIds.length === 1 ? 'track' : 'tracks'}
              </AppText>
            </View>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Close"
              hitSlop={4}
              onPress={onClose}
              style={styles.closeButton}
            >
              <Feather name="x" size={22} color={colors.inkMuted} />
            </Pressable>
          </View>

          <TextInput
            value={filter}
            onChangeText={setFilter}
            placeholder="Filter songs"
            placeholderTextColor={colors.inkFaint}
            style={styles.input}
            returnKeyType="search"
          />

          {tracks.length === 0 ? (
            <AppText variant="body" color={colors.inkMuted}>
              No songs in the library yet. Scan your Music folder first.
            </AppText>
          ) : (
            <ScrollView
              style={styles.list}
              contentContainerStyle={styles.listContent}
              showsVerticalScrollIndicator={false}
            >
              {visibleTracks.map((track) => {
                const added = inPlaylist.has(track.id);
                return (
                  <View key={track.id} style={styles.trackRow}>
                    <View style={styles.trackInfo}>
                      <AppText variant="label" color={colors.ink} numberOfLines={1}>{track.title}</AppText>
                      <AppText variant="micro" color={colors.inkMuted} numberOfLines={1}>{track.artist}</AppText>
                    </View>
                    <Pressable
                      accessibilityRole="button"
                      accessibilityLabel={added ? `Remove ${track.title} from playlist` : `Add ${track.title} to playlist`}
                      hitSlop={8}
                      onPress={() => {
                        if (added) {
                          onRemove(track.id);
                        } else {
                          onAdd(track.id);
                        }
                      }}
                      style={styles.trackAction}
                    >
                      <Feather
                        name={added ? 'check-circle' : 'plus-circle'}
                        size={24}
                        color={added ? colors.accentStrong : colors.inkMuted}
                      />
                    </Pressable>
                  </View>
                );
              })}
              {visibleTracks.length === 0 ? (
                <AppText variant="body" color={colors.inkFaint}>No songs match {'\u201C'}{filter}{'\u201D'}.</AppText>
              ) : null}
            </ScrollView>
          )}
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'flex-end',
  },
  panel: {
    backgroundColor: colors.surfaceRaised,
    borderTopLeftRadius: radii.xl,
    borderTopRightRadius: radii.xl,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.lg,
    maxHeight: '80%',
    gap: spacing.md,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    gap: spacing.sm,
  },
  headerText: { flex: 1, gap: 2 },
  input: {
    minHeight: 44,
    paddingHorizontal: spacing.md,
    borderRadius: radii.md,
    backgroundColor: colors.surface,
    color: colors.ink,
    fontSize: 14,
  },
  list: { flexGrow: 0 },
  listContent: { gap: spacing.xs, paddingBottom: spacing.lg },
  trackRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    padding: spacing.sm,
    borderRadius: radii.md,
    backgroundColor: colors.surface,
    minHeight: 52,
  },
  trackInfo: { flex: 1, gap: 1 },
  trackAction: {
    width: 48,
    height: 48,
    alignItems: 'center',
    justifyContent: 'center',
  },
  closeButton: {
    width: 48,
    height: 48,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
