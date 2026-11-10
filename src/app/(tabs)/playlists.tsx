import Feather from '@expo/vector-icons/Feather';
import { router } from 'expo-router';
import { useState } from 'react';
import {
  Pressable,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Animated from 'react-native-reanimated';

import { AppDialog } from '../../components/AppDialog';
import { CollapsedBar, useCollapsingScroll } from '../../components/CollapsingHeader';
import { CreatePlaylistSheet } from '../../components/CreatePlaylistSheet';
import { EmptyState } from '../../components/EmptyState';
import { IconButton } from '../../components/IconButton';
import { ListGroup } from '../../components/ListGroup';
import { ListRow } from '../../components/ListRow';
import { PlaylistCover } from '../../components/Artwork';
import { ScreenHeader } from '../../components/ScreenHeader';
import { useMusicLibrary } from '../../storage/MusicLibraryContext';
import { usePreferences } from '../../storage/PreferencesContext';
import type { Playlist, Track } from '../../types/music';
import {
  layout,
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  type AppTheme,
} from '../../theme';

export default function PlaylistsScreen() {
  const library = useMusicLibrary();
  const { tapFeedback } = usePreferences();
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  const { scrollY, onScroll } = useCollapsingScroll();
  const [createOpen, setCreateOpen] = useState(false);
  const [menuTarget, setMenuTarget] = useState<Playlist | null>(null);
  const [renameTarget, setRenameTarget] = useState<Playlist | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<Playlist | null>(null);

  const tracksFor = (playlist: Playlist): Track[] =>
    playlist.trackIds
      .map((id) => library.displayTracksById.get(id))
      .filter((track): track is Track => Boolean(track));

  const count = library.playlists.length;

  return (
    <SafeAreaView style={[styles.safe, { backgroundColor: palette.background }]} edges={['top']}>
      <Animated.ScrollView
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
        onScroll={onScroll}
        scrollEventThrottle={16}
      >
        <ScreenHeader
          title="Playlists"
          subtitle={`${count} ${count === 1 ? 'playlist' : 'playlists'} · saved on this device`}
          action={(
            <IconButton
              name="plus"
              label="New playlist"
              iconSize={20}
              onPress={() => {
                tapFeedback('selection');
                setCreateOpen(true);
              }}
            />
          )}
        />

        {count === 0 ? (
          <EmptyState
            title="No playlists yet"
            message="Build a set for a walk, a drive, or a quiet evening. Add songs from any track menu."
            actionLabel="Create a playlist"
            onAction={() => {
              tapFeedback('selection');
              setCreateOpen(true);
            }}
          />
        ) : (
          <ListGroup>
            {library.playlists.map((playlist) => {
              const tracks = tracksFor(playlist);
              const trackCount = tracks.length;
              return (
                <ListRow
                  key={playlist.id}
                  leading={(
                    <PlaylistCover
                      artworks={tracks.map((track) => track.artwork)}
                      size={44}
                      radius={radii.md}
                    />
                  )}
                  title={playlist.name}
                  subtitle={`${trackCount} ${trackCount === 1 ? 'track' : 'tracks'}`}
                  onPress={() => {
                    tapFeedback('selection');
                    router.push({ pathname: '/playlist', params: { id: playlist.id } });
                  }}
                  accessibilityLabel={`Open playlist ${playlist.name}`}
                  trailing={(
                    <Pressable
                      accessibilityRole="button"
                      accessibilityLabel={`Manage ${playlist.name}`}
                      hitSlop={8}
                      onPress={() => {
                        tapFeedback('selection');
                        setMenuTarget(playlist);
                      }}
                      style={({ pressed }) => [styles.rowMenu, { opacity: pressed ? 0.6 : 1 }]}
                    >
                      <Feather name="more-horizontal" size={20} color={palette.inkMuted} />
                    </Pressable>
                  )}
                />
              );
            })}
          </ListGroup>
        )}
      </Animated.ScrollView>

      <CollapsedBar title="Playlists" scrollY={scrollY} />

      <CreatePlaylistSheet
        visible={createOpen}
        onClose={() => setCreateOpen(false)}
        onCreate={(name) => {
          tapFeedback('success');
          library.createPlaylist(name);
        }}
      />

      <CreatePlaylistSheet
        visible={renameTarget !== null}
        onClose={() => setRenameTarget(null)}
        title="Rename playlist"
        initialName={renameTarget?.name ?? ''}
        onCreate={(name) => {
          if (!renameTarget) return;
          tapFeedback('success');
          library.renamePlaylist(renameTarget.id, name);
          setRenameTarget(null);
        }}
      />

      <AppDialog
        visible={menuTarget !== null}
        title={menuTarget?.name ?? 'Playlist'}
        message="Choose an action"
        onClose={() => setMenuTarget(null)}
        actions={[
          {
            label: 'Rename',
            onPress: () => {
              setRenameTarget(menuTarget);
            },
          },
          {
            label: 'Delete',
            tone: 'danger',
            onPress: () => {
              setDeleteTarget(menuTarget);
            },
          },
          { label: 'Cancel', onPress: () => undefined },
        ]}
      />

      <AppDialog
        visible={deleteTarget !== null}
        title="Delete playlist?"
        message={deleteTarget
          ? `"${deleteTarget.name}" will be removed. Your songs stay in the library.`
          : undefined}
        onClose={() => setDeleteTarget(null)}
        actions={[
          {
            label: 'Delete',
            tone: 'danger',
            onPress: () => {
              if (!deleteTarget) return;
              tapFeedback('success');
              library.deletePlaylist(deleteTarget.id);
              setDeleteTarget(null);
            },
          },
          { label: 'Cancel', onPress: () => undefined },
        ]}
      />

      <View
        accessibilityElementsHidden
        importantForAccessibility="no-hide-descendants"
        style={styles.footerSpace}
      />
    </SafeAreaView>
  );
}

const createStyles = ({ glass }: AppTheme) => ({
  safe: { flex: 1 },
  content: {
    paddingTop: spacing.lg,
    paddingBottom: layout.tabBarSpace,
    gap: spacing.lg,
  },
  rowMenu: {
    width: 44,
    height: 44,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
    borderRadius: radii.pill,
  },
  footerSpace: {
    height: 1,
    backgroundColor: glass.tintSoft,
  },
});
