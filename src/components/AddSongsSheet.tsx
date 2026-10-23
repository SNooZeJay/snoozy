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
import {
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  type AppTheme,
} from '../theme';
import { AppText } from './AppText';
import { SheetPanel } from './SheetPanel';

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
  const { palette, dark } = useTheme();
  const styles = useThemedStyles(createStyles);
  const insets = useSafeAreaInsets();
  const [filter, setFilter] = useState('');

  const close = () => {
    setFilter('');
    onClose();
  };

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
    <Modal visible transparent animationType="fade" statusBarTranslucent onRequestClose={close}>
      <KeyboardAvoidingView behavior="padding" style={styles.backdrop}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Close add songs"
          onPress={close}
          style={StyleSheet.absoluteFill}
        />
        <SheetPanel
          style={[
            styles.panel,
            { paddingBottom: insets.bottom + spacing.md },
          ]}
        >
          <View style={styles.header}>
            <View style={styles.headerText}>
              <AppText variant="heading" color={palette.ink} numberOfLines={1}>Add songs</AppText>
              <AppText variant="micro" color={palette.inkMuted} numberOfLines={1}>
                {'\u201C'}{playlistName}{'\u201D'} · {playlistTrackIds.length} {playlistTrackIds.length === 1 ? 'track' : 'tracks'}
              </AppText>
            </View>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Close"
              hitSlop={4}
              onPress={close}
              style={styles.closeButton}
            >
              <Feather name="x" size={22} color={palette.inkMuted} />
            </Pressable>
          </View>

          <TextInput
            value={filter}
            onChangeText={setFilter}
            placeholder="Filter songs"
            placeholderTextColor={palette.inkFaint}
            keyboardAppearance={dark ? 'dark' : 'light'}
            style={styles.input}
            returnKeyType="search"
          />

          {tracks.length === 0 ? (
            <AppText variant="body" color={palette.inkMuted}>
              No songs in the library yet. Scan your Music folder first.
            </AppText>
          ) : (
            <ScrollView
              style={styles.list}
              contentContainerStyle={styles.listContent}
              showsVerticalScrollIndicator={false}
              keyboardShouldPersistTaps="handled"
            >
              {visibleTracks.map((track) => {
                const added = inPlaylist.has(track.id);
                return (
                  <View key={track.id} style={styles.trackRow}>
                    <View style={styles.trackInfo}>
                      <AppText variant="label" color={palette.ink} numberOfLines={1}>{track.title}</AppText>
                      <AppText variant="micro" color={palette.inkMuted} numberOfLines={1}>{track.artist}</AppText>
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
                        color={added ? palette.accentStrong : palette.inkMuted}
                      />
                    </Pressable>
                  </View>
                );
              })}
              {visibleTracks.length === 0 ? (
                <AppText variant="body" color={palette.inkFaint}>No songs match {'\u201C'}{filter}{'\u201D'}.</AppText>
              ) : null}
            </ScrollView>
          )}
        </SheetPanel>
      </KeyboardAvoidingView>
    </Modal>
  );
}

const createStyles = ({ palette, glass }: AppTheme) => ({
  backdrop: {
    flex: 1,
    backgroundColor: palette.scrim,
    justifyContent: 'flex-end' as const,
  },
  panel: {
    backgroundColor: glass.tintStrong,
    borderTopLeftRadius: radii.xl,
    borderTopRightRadius: radii.xl,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeStrong,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.lg,
    maxHeight: '80%' as const,
    gap: spacing.md,
  },
  header: {
    flexDirection: 'row' as const,
    alignItems: 'flex-start' as const,
    justifyContent: 'space-between' as const,
    gap: spacing.sm,
  },
  headerText: { flex: 1, gap: 2 },
  input: {
    minHeight: 44,
    paddingHorizontal: spacing.md,
    borderRadius: radii.md,
    backgroundColor: glass.fieldTint,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeSoft,
    color: palette.ink,
    fontSize: 14,
  },
  list: { flexGrow: 0 },
  listContent: { gap: spacing.xs, paddingBottom: spacing.lg },
  trackRow: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.sm,
    padding: spacing.sm,
    borderRadius: radii.md,
    backgroundColor: glass.tintSoft,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeSoft,
    minHeight: 52,
  },
  trackInfo: { flex: 1, gap: 1 },
  trackAction: {
    width: 48,
    height: 48,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  },
  closeButton: {
    width: 48,
    height: 48,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  },
});
