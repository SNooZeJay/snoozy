import Feather from '@expo/vector-icons/Feather';
import { useState } from 'react';
import {
  FlatList,
  Modal,
  Pressable,
  StyleSheet,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { AppDialog, type AppDialogAction } from './AppDialog';
import { AppText } from './AppText';
import { CoverArt } from './Artwork';
import { CreatePlaylistSheet } from './CreatePlaylistSheet';
import { IconButton } from './IconButton';
import { SheetPanel } from './SheetPanel';
import { usePlayer } from '../playback/PlayerContext';
import { filterQueueIds, type QueueEntry } from '../playback/queue';
import { useMusicLibrary } from '../storage/MusicLibraryContext';
import { usePreferences } from '../storage/PreferencesContext';
import {
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  type AppTheme,
} from '../theme';

type QueueSheetProps = {
  visible: boolean;
  onClose: () => void;
};

/**
 * Live playback queue. The native player owns the order; this sheet renders
 * the context mirror and every action goes through the engine.
 */
export function QueueSheet({ visible, onClose }: QueueSheetProps) {
  const player = usePlayer();
  const library = useMusicLibrary();
  const { tapFeedback } = usePreferences();
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  const insets = useSafeAreaInsets();
  const [menuIndex, setMenuIndex] = useState<number | null>(null);
  const [clearOpen, setClearOpen] = useState(false);
  const [saveOpen, setSaveOpen] = useState(false);

  const items = player.queueItems;
  const count = items.length;
  const menuEntry = menuIndex !== null && menuIndex < count ? items[menuIndex] : null;

  const close = () => {
    setMenuIndex(null);
    setClearOpen(false);
    onClose();
  };

  const saveQueue = (name: string) => {
    const playlistId = library.createPlaylist(name);
    if (!playlistId) return;
    const allowed = new Set(library.displayTracksById.keys());
    for (const trackId of filterQueueIds(items.map((item) => item.mediaId), allowed)) {
      library.addToPlaylist(playlistId, trackId);
    }
    tapFeedback('success');
  };

  const menuActions: AppDialogAction[] =
    menuEntry && menuIndex !== null
      ? [
          {
            label: 'Play now',
            onPress: () => {
              tapFeedback('selection');
              player.playQueueItem(menuIndex);
            },
          },
          ...(menuIndex > 0
            ? [{ label: 'Move up', onPress: () => player.moveQueueItem(menuIndex, menuIndex - 1) }]
            : []),
          ...(menuIndex < count - 1
            ? [{ label: 'Move down', onPress: () => player.moveQueueItem(menuIndex, menuIndex + 1) }]
            : []),
          {
            label: 'Remove',
            tone: 'danger' as const,
            onPress: () => {
              tapFeedback('light');
              player.removeQueueItem(menuIndex);
            },
          },
          { label: 'Cancel', onPress: () => {} },
        ]
      : [];

  const renderRow = ({ item, index }: { item: QueueEntry; index: number }) => {
    const active = index === player.queueIndex;
    return (
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`${item.title}, by ${item.artist}, ${index + 1} of ${count}${active ? ', playing' : ''}`}
        accessibilityState={{ selected: active }}
        onPress={() => {
          tapFeedback('selection');
          player.playQueueItem(index);
        }}
        style={({ pressed }) => [
          styles.row,
          active && styles.rowActive,
          { opacity: pressed ? 0.7 : 1 },
        ]}
      >
        <View style={styles.position}>
          {active ? (
            <Feather name="volume-2" size={13} color={palette.accent} />
          ) : (
            <AppText variant="micro" color={palette.inkFaint}>
              {index + 1}
            </AppText>
          )}
        </View>
        <CoverArt uri={item.artwork} size={40} radius={radii.sm} icon="music" />
        <View style={styles.copy}>
          <AppText
            variant="label"
            color={active ? palette.accent : palette.ink}
            numberOfLines={1}
          >
            {item.title}
          </AppText>
          <AppText variant="micro" color={palette.inkMuted} numberOfLines={1}>
            {item.artist}
          </AppText>
        </View>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={`Options for ${item.title}, ${index + 1} of ${count}`}
          hitSlop={4}
          onPress={() => {
            tapFeedback('light');
            setMenuIndex(index);
          }}
          style={styles.rowMenu}
        >
          <Feather name="more-horizontal" size={20} color={palette.inkMuted} />
        </Pressable>
      </Pressable>
    );
  };

  return (
    <>
      <Modal
        visible={visible && !saveOpen}
        transparent
        animationType="fade"
        statusBarTranslucent
        onRequestClose={close}
      >
        <View style={styles.backdrop}>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Close queue"
            onPress={close}
            style={StyleSheet.absoluteFill}
          />
          <SheetPanel
            onDismiss={close}
            style={[styles.panel, { paddingBottom: insets.bottom + spacing.md }]}
          >
            <View style={styles.header}>
              <View style={styles.headerCopy}>
                <AppText variant="heading" color={palette.ink}>Up next</AppText>
                <AppText variant="micro" color={palette.inkMuted}>
                  {count === 0
                    ? 'Nothing queued'
                    : `${count} ${count === 1 ? 'song' : 'songs'}${player.queueIndex >= 0 ? ` · playing ${player.queueIndex + 1}` : ''}`}
                </AppText>
              </View>
              <View style={styles.headerActions}>
                <IconButton
                  name="save"
                  label="Save queue as playlist"
                  size={44}
                  iconSize={18}
                  disabled={count === 0}
                  onPress={() => {
                    tapFeedback('selection');
                    setSaveOpen(true);
                  }}
                />
                <IconButton
                  name="trash-2"
                  label="Clear queue"
                  size={44}
                  iconSize={18}
                  disabled={count === 0}
                  onPress={() => {
                    tapFeedback('selection');
                    setClearOpen(true);
                  }}
                />
                <IconButton
                  name="x"
                  label="Close queue"
                  size={44}
                  iconSize={20}
                  onPress={close}
                />
              </View>
            </View>

            {count === 0 ? (
              <View style={styles.empty}>
                <AppText variant="heading" color={palette.ink}>Nothing queued</AppText>
                <AppText variant="body" color={palette.inkMuted} style={styles.emptyCopy}>
                  Songs you play show up here. Use a song’s menu to play next or add to the queue.
                </AppText>
              </View>
            ) : (
              <FlatList
                data={items}
                keyExtractor={(item, index) => `${item.mediaId}-${index}`}
                renderItem={renderRow}
                style={styles.list}
                contentContainerStyle={styles.listContent}
                showsVerticalScrollIndicator={false}
              />
            )}

            <AppDialog
              inline
              visible={menuEntry !== null}
              title={menuEntry?.title ?? ''}
              message={menuEntry ? `${menuEntry.artist} · ${(menuIndex ?? 0) + 1} of ${count}` : undefined}
              onClose={() => setMenuIndex(null)}
              actions={menuActions}
            />
            <AppDialog
              inline
              visible={clearOpen}
              title="Clear queue?"
              message="Playback stops and the queue is emptied. Your library and playlists are untouched."
              onClose={() => setClearOpen(false)}
              actions={[
                {
                  label: 'Clear',
                  tone: 'danger',
                  onPress: () => {
                    tapFeedback('light');
                    player.clearQueue();
                  },
                },
                { label: 'Cancel', onPress: () => {} },
              ]}
            />
          </SheetPanel>
        </View>
      </Modal>

      <CreatePlaylistSheet
        visible={saveOpen}
        onClose={() => setSaveOpen(false)}
        onCreate={saveQueue}
      />
    </>
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
    maxHeight: '78%' as const,
    gap: spacing.md,
  },
  header: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    justifyContent: 'space-between' as const,
    gap: spacing.sm,
  },
  headerCopy: { flex: 1, gap: 2 },
  headerActions: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.xs,
  },
  list: { flexGrow: 0 },
  listContent: { gap: spacing.xxs, paddingBottom: spacing.lg },
  row: {
    minHeight: 56,
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.sm,
    paddingHorizontal: spacing.xs,
    paddingVertical: spacing.xs,
    borderRadius: radii.md,
  },
  rowActive: {
    backgroundColor: glass.tintAccent,
  },
  position: {
    width: 20,
    alignItems: 'center' as const,
  },
  copy: { flex: 1, gap: 1 },
  rowMenu: {
    width: 44,
    height: 44,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  },
  empty: {
    alignItems: 'center' as const,
    gap: spacing.xs,
    paddingVertical: spacing.xxl,
    paddingHorizontal: spacing.lg,
  },
  emptyCopy: {
    textAlign: 'center' as const,
  },
});
