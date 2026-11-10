import Feather from '@expo/vector-icons/Feather';
import { useState } from 'react';
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

import type { Playlist } from '../types/music';
import {
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  type AppTheme,
} from '../theme';
import { AppText } from './AppText';
import { SheetPanel } from './SheetPanel';

type AddToPlaylistSheetProps = {
  visible: boolean;
  onClose: () => void;
  trackTitle: string | null;
  playlists: Playlist[];
  onSelectPlaylist: (playlistId: string) => void;
  onCreatePlaylist: (name: string) => string;
};

export function AddToPlaylistSheet({
  visible,
  onClose,
  trackTitle,
  playlists,
  onSelectPlaylist,
  onCreatePlaylist,
}: AddToPlaylistSheetProps) {
  const { palette, dark } = useTheme();
  const styles = useThemedStyles(createStyles);
  const insets = useSafeAreaInsets();
  const [name, setName] = useState('');
  const [addedTo, setAddedTo] = useState<string[]>([]);

  const close = () => {
    setName('');
    setAddedTo([]);
    onClose();
  };

  const add = (playlist: Playlist) => {
    onSelectPlaylist(playlist.id);
    setAddedTo((prev) => [...prev, playlist.id]);
  };

  const create = () => {
    const trimmed = name.trim();
    if (!trimmed) return;
    const id = onCreatePlaylist(trimmed);
    if (id) onSelectPlaylist(id);
    setName('');
    if (id) setAddedTo((prev) => [...prev, id]);
  };

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      statusBarTranslucent
      onRequestClose={close}
    >
      <KeyboardAvoidingView
        behavior="padding"
        style={styles.backdrop}
      >
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Close add to playlist"
          onPress={close}
          style={StyleSheet.absoluteFill}
        />
        <SheetPanel
          onDismiss={close}
          style={[
            styles.panel,
            { paddingBottom: insets.bottom + spacing.md },
          ]}
        >
          <View style={styles.header}>
            <View style={styles.headerText}>
              <AppText variant="heading" color={palette.ink} numberOfLines={1}>Add to playlist</AppText>
              {trackTitle ? (
                <AppText variant="micro" color={palette.inkMuted} numberOfLines={1}>
                  {'\u201C'}{trackTitle}{'\u201D'}
                </AppText>
              ) : null}
            </View>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Close"
              hitSlop={10}
              onPress={close}
            >
              <Feather name="x" size={22} color={palette.inkMuted} />
            </Pressable>
          </View>

          {playlists.length === 0 ? (
            <AppText variant="body" color={palette.inkMuted}>
              No playlists yet. Create one below.
            </AppText>
          ) : (
            <ScrollView
              style={styles.list}
              contentContainerStyle={styles.listContent}
              showsVerticalScrollIndicator={false}
              keyboardShouldPersistTaps="handled"
            >
              {playlists.map((playlist) => {
                const isAdded = addedTo.includes(playlist.id);
                return (
                  <Pressable
                    key={playlist.id}
                    accessibilityRole="button"
                    accessibilityLabel={`Add to ${playlist.name}`}
                    onPress={() => add(playlist)}
                    disabled={isAdded}
                    style={({ pressed }) => [
                      styles.playlistRow,
                      pressed && { opacity: 0.7 },
                      isAdded && styles.playlistRowDisabled,
                    ]}
                  >
                    <Feather
                      name={isAdded ? 'check-circle' : 'plus'}
                      size={20}
                      color={isAdded ? palette.accentStrong : palette.inkMuted}
                    />
                    <View style={styles.playlistRowText}>
                      <AppText variant="label" color={palette.ink} numberOfLines={1}>
                        {playlist.name}
                      </AppText>
                      <AppText variant="micro" color={palette.inkMuted}>
                        {isAdded
                          ? 'Added'
                          : `${playlist.trackIds.length} ${playlist.trackIds.length === 1 ? 'track' : 'tracks'}`}
                      </AppText>
                    </View>
                  </Pressable>
                );
              })}
            </ScrollView>
          )}

          <View style={styles.createRow}>
            <TextInput
              value={name}
              onChangeText={setName}
              placeholder="New playlist name"
              placeholderTextColor={palette.inkFaint}
              keyboardAppearance={dark ? 'dark' : 'light'}
              style={styles.input}
              returnKeyType="done"
              onSubmitEditing={create}
            />
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Create playlist"
              onPress={create}
              disabled={!name.trim()}
              style={({ pressed }) => [
                styles.createButton,
                { opacity: name.trim() ? (pressed ? 0.75 : 1) : 0.4 },
              ]}
            >
              <Feather name="plus" size={18} color={palette.accentInk} />
              <AppText variant="label" color={palette.accentInk}>Create</AppText>
            </Pressable>
          </View>
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
    maxHeight: '75%' as const,
    gap: spacing.md,
  },
  header: {
    flexDirection: 'row' as const,
    alignItems: 'flex-start' as const,
    justifyContent: 'space-between' as const,
    gap: spacing.sm,
  },
  headerText: { flex: 1, gap: 2 },
  list: { flexGrow: 0 },
  listContent: { gap: spacing.xs, paddingBottom: spacing.sm },
  playlistRow: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.sm,
    padding: spacing.sm,
    borderRadius: radii.md,
    backgroundColor: glass.tintSoft,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeSoft,
    minHeight: 48,
  },
  playlistRowDisabled: { opacity: 0.55 },
  playlistRowText: { flex: 1, gap: 1 },
  createRow: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.sm,
  },
  input: {
    flex: 1,
    minHeight: 44,
    paddingHorizontal: spacing.md,
    borderRadius: radii.md,
    backgroundColor: glass.fieldTint,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeSoft,
    color: palette.ink,
    fontSize: 14,
  },
  createButton: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: 4,
    minHeight: 44,
    paddingHorizontal: spacing.md,
    borderRadius: radii.pill,
    backgroundColor: palette.accent,
  },
});
