import Feather from '@expo/vector-icons/Feather';
import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { Pressable, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Animated from 'react-native-reanimated';

import { AddSongsSheet } from '../components/AddSongsSheet';
import { AppDialog } from '../components/AppDialog';
import { AppText } from '../components/AppText';
import { PlaylistCover } from '../components/Artwork';
import { CollapsedBar, useCollapsingScroll } from '../components/CollapsingHeader';
import { CreatePlaylistSheet } from '../components/CreatePlaylistSheet';
import { EmptyState } from '../components/EmptyState';
import { IconButton } from '../components/IconButton';
import { ListGroup } from '../components/ListGroup';
import { ListRow } from '../components/ListRow';
import { MiniPlayer } from '../components/MiniPlayer';
import { ScreenHeader } from '../components/ScreenHeader';
import { SectionHeader } from '../components/SectionHeader';
import { Thumb } from '../components/Thumb';
import { formatDuration } from '../utils/format';
import { useMusicLibrary } from '../storage/MusicLibraryContext';
import { usePlayer } from '../playback/PlayerContext';
import { randomStartIndex } from '../playback/controls';
import { usePreferences } from '../storage/PreferencesContext';
import type { Track } from '../types/music';
import {
  layout,
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  type AppTheme,
} from '../theme';

export default function PlaylistScreen() {
  const params = useLocalSearchParams<{ id?: string }>();
  const playlistId = params.id ?? '';
  const library = useMusicLibrary();
  const player = usePlayer();
  const { tapFeedback } = usePreferences();
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  const { scrollY, onScroll } = useCollapsingScroll(false);
  const [addSongsOpen, setAddSongsOpen] = useState(false);
  const [renameOpen, setRenameOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [songMenu, setSongMenu] = useState<{ track: Track; index: number } | null>(null);

  const playlist = library.playlists.find((item) => item.id === playlistId) ?? null;
  const tracks = (playlist?.trackIds ?? [])
    .map((id) => library.displayTracksById.get(id))
    .filter((track): track is Track => Boolean(track));
  const totalDuration = tracks.reduce((sum, track) => sum + (track.duration || 0), 0);

  const playAll = (shuffled: boolean) => {
    if (tracks.length === 0) return;
    const start = shuffled ? tracks[randomStartIndex(tracks.length)] : tracks[0];
    tapFeedback('selection');
    void player.playTrack(start, tracks, { shuffle: shuffled });
  };

  const moveSong = (direction: -1 | 1) => {
    if (!songMenu || !playlist) return;
    const neighbor = tracks[songMenu.index + direction];
    if (!neighbor) return;
    const from = playlist.trackIds.indexOf(songMenu.track.id);
    const to = playlist.trackIds.indexOf(neighbor.id);
    if (from < 0 || to < 0) return;
    tapFeedback('selection');
    library.movePlaylistTrack(playlist.id, from, to);
  };

  if (!playlist) {
    return (
      <SafeAreaView style={[styles.safe, { backgroundColor: palette.background }]} edges={['top']}>
        <ScreenHeader
          leading={(
            <IconButton
              name="chevron-left"
              label="Back"
              iconSize={22}
              onPress={() => router.back()}
            />
          )}
          title="Playlist"
        />
        <EmptyState
          title="Playlist not found"
          message="It may have been deleted. Your songs are still in the library."
          actionLabel="Back to library"
          onAction={() => router.back()}
        />
        <MiniPlayer standalone />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={[styles.safe, { backgroundColor: palette.background }]} edges={['top']}>
      <Animated.ScrollView
        contentContainerStyle={styles.content}
        onScroll={onScroll}
        scrollEventThrottle={16}
      >
        <ScreenHeader
          leading={(
            <IconButton
              name="chevron-left"
              label="Back"
              iconSize={22}
              onPress={() => router.back()}
            />
          )}
          title={playlist.name}
          subtitle={`${tracks.length} ${tracks.length === 1 ? 'track' : 'tracks'} · ${formatDuration(totalDuration)}`}
          action={(
            <View style={styles.headerActions}>
              <IconButton
                name="edit-2"
                label={`Rename ${playlist.name}`}
                iconSize={18}
                onPress={() => {
                  tapFeedback('selection');
                  setRenameOpen(true);
                }}
              />
              <IconButton
                name="trash-2"
                label={`Delete ${playlist.name}`}
                iconSize={20}
                color={palette.danger}
                onPress={() => {
                  tapFeedback('selection');
                  setDeleteOpen(true);
                }}
              />
            </View>
          )}
        />

        <View style={styles.hero}>
          <PlaylistCover
            artworks={tracks.map((track) => track.artwork)}
            size={188}
            radius={radii.xl}
          />
        </View>

        <View style={styles.actions}>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Play playlist"
            accessibilityState={{ disabled: tracks.length === 0 }}
            disabled={tracks.length === 0}
            onPress={() => playAll(false)}
            style={({ pressed }) => [
              styles.playButton,
              { opacity: tracks.length === 0 ? 0.4 : pressed ? 0.75 : 1 },
            ]}
          >
            <Feather name="play" size={16} color={palette.accentInk} />
            <AppText variant="label" color={palette.accentInk}>Play</AppText>
          </Pressable>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Shuffle playlist"
            accessibilityState={{ disabled: tracks.length === 0 }}
            disabled={tracks.length === 0}
            onPress={() => playAll(true)}
            style={({ pressed }) => [
              styles.secondaryButton,
              { opacity: tracks.length === 0 ? 0.4 : pressed ? 0.75 : 1 },
            ]}
          >
            <Feather name="shuffle" size={16} color={palette.ink} />
            <AppText variant="label" color={palette.ink}>Shuffle</AppText>
          </Pressable>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Add songs to playlist"
            onPress={() => {
              tapFeedback('selection');
              setAddSongsOpen(true);
            }}
            style={({ pressed }) => [styles.secondaryButton, { opacity: pressed ? 0.75 : 1 }]}
          >
            <Feather name="plus" size={16} color={palette.ink} />
            <AppText variant="label" color={palette.ink}>Add</AppText>
          </Pressable>
        </View>

        {tracks.length === 0 ? (
          <EmptyState
            title="No songs yet"
            message="Add songs from your library to start this playlist."
            actionLabel="Add songs"
            onAction={() => {
              tapFeedback('selection');
              setAddSongsOpen(true);
            }}
          />
        ) : (
          <>
            <SectionHeader label="Songs" />
            <ListGroup>
              {tracks.map((track, index) => (
                <ListRow
                  key={track.id}
                  leading={<Thumb track={track} size={44} />}
                  title={track.title}
                  subtitle={`${track.artist} · ${track.album}`}
                  onPress={() => {
                    tapFeedback('selection');
                    void player.playTrack(track, tracks);
                  }}
                  accessibilityLabel={`Play ${track.title}`}
                  trailing={(
                    <Pressable
                      accessibilityRole="button"
                      accessibilityLabel={`Manage ${track.title} in ${playlist.name}`}
                      onPress={() => {
                        tapFeedback('selection');
                        setSongMenu({ track, index });
                      }}
                      style={({ pressed }) => [styles.rowMenu, { opacity: pressed ? 0.6 : 1 }]}
                      hitSlop={4}
                    >
                      <Feather name="more-horizontal" size={20} color={palette.inkMuted} />
                    </Pressable>
                  )}
                />
              ))}
            </ListGroup>
          </>
        )}
      </Animated.ScrollView>

      <CollapsedBar
        title={playlist.name}
        scrollY={scrollY}
        left={<IconButton name="chevron-left" label="Back" iconSize={22} onPress={() => router.back()} />}
      />

      <AddSongsSheet
        visible={addSongsOpen}
        onClose={() => setAddSongsOpen(false)}
        playlistName={playlist.name}
        playlistTrackIds={tracks.map((track) => track.id)}
        tracks={library.displayTracks}
        onAdd={(trackId) => {
          library.addToPlaylist(playlist.id, trackId);
        }}
        onRemove={(trackId) => {
          library.removeFromPlaylist(playlist.id, trackId);
        }}
      />
      <AppDialog
        visible={songMenu !== null}
        title={songMenu?.track.title ?? ''}
        message={songMenu ? `${songMenu.track.artist} · ${songMenu.track.album}` : undefined}
        onClose={() => setSongMenu(null)}
        actions={songMenu ? [
          {
            label: 'Play next',
            onPress: () => {
              tapFeedback('selection');
              player.playNext(songMenu.track);
            },
          },
          {
            label: 'Add to queue',
            onPress: () => {
              tapFeedback('selection');
              player.addToQueue(songMenu.track);
            },
          },
          ...(songMenu.index > 0 ? [{
            label: 'Move up',
            onPress: () => moveSong(-1),
          }] : []),
          ...(songMenu.index < tracks.length - 1 ? [{
            label: 'Move down',
            onPress: () => moveSong(1),
          }] : []),
          {
            label: 'Remove from playlist',
            tone: 'danger' as const,
            onPress: () => {
              tapFeedback('light');
              library.removeFromPlaylist(playlist.id, songMenu.track.id);
            },
          },
          { label: 'Cancel', onPress: () => {} },
        ] : []}
      />
      <AppDialog
        visible={deleteOpen}
        title="Delete playlist?"
        message={`"${playlist.name}" will be removed. Your songs stay in the library.`}
        onClose={() => setDeleteOpen(false)}
        actions={[
          {
            label: 'Delete',
            tone: 'danger',
            onPress: () => {
              tapFeedback('light');
              library.deletePlaylist(playlist.id);
              router.back();
            },
          },
          { label: 'Cancel', onPress: () => {} },
        ]}
      />
      <CreatePlaylistSheet
        visible={renameOpen}
        onClose={() => setRenameOpen(false)}
        title="Rename playlist"
        submitLabel="Save"
        initialName={playlist.name}
        onCreate={(name) => {
          tapFeedback('success');
          library.renamePlaylist(playlist.id, name);
        }}
      />
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
  hero: {
    alignItems: 'center' as const,
    paddingTop: spacing.sm,
    paddingHorizontal: layout.screenPadding,
  },
  headerActions: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.xs,
  },
  actions: {
    flexDirection: 'row' as const,
    gap: spacing.sm,
    paddingHorizontal: layout.screenPadding,
  },
  playButton: {
    minHeight: 44,
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.xs,
    justifyContent: 'center' as const,
    paddingHorizontal: spacing.lg,
    borderRadius: radii.pill,
    backgroundColor: palette.accent,
  },
  secondaryButton: {
    minHeight: 44,
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.xs,
    justifyContent: 'center' as const,
    paddingHorizontal: spacing.lg,
    borderRadius: radii.pill,
    backgroundColor: glass.tintSoft,
    borderWidth: 1,
    borderColor: glass.edgeSoft,
  },
  rowMenu: {
    width: 44,
    height: 44,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  },
});
