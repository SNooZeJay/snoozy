import Feather from '@expo/vector-icons/Feather';
import { router } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import {
  Pressable,
  RefreshControl,
  ScrollView,
  StyleSheet,
  View,
} from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring,
} from 'react-native-reanimated';
import { SafeAreaView } from 'react-native-safe-area-context';

import { AppDialog } from '../../components/AppDialog';
import { AppText } from '../../components/AppText';
import { AddToPlaylistSheet } from '../../components/AddToPlaylistSheet';
import { AddSongsSheet } from '../../components/AddSongsSheet';
import { CreatePlaylistSheet } from '../../components/CreatePlaylistSheet';
import { EmptyState } from '../../components/EmptyState';
import { GlassButton } from '../../components/glass/GlassButton';
import { ListGroup } from '../../components/ListGroup';
import { ListRow } from '../../components/ListRow';
import { ScreenHeader } from '../../components/ScreenHeader';
import { SectionHeader } from '../../components/SectionHeader';
import { SwipeableRow, type SwipeAction } from '../../components/SwipeableRow';
import { NoteTile, Thumb } from '../../components/Thumb';
import { useMusicLibrary } from '../../storage/MusicLibraryContext';
import { usePlayer } from '../../playback/PlayerContext';
import { usePreferences } from '../../storage/PreferencesContext';
import type { Track } from '../../types/music';
import {
  layout,
  motion,
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  withAlpha,
  type AppTheme,
} from '../../theme';

const SEGMENTS = ['songs', 'albums', 'artists', 'playlists', 'favorites'] as const;
type Segment = (typeof SEGMENTS)[number];

type SegmentControlProps = {
  active: Segment;
  reducedMotion: boolean;
  onSelect: (segment: Segment) => void;
};

function SegmentControl({ active, reducedMotion, onSelect }: SegmentControlProps) {
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  const thumbX = useSharedValue(0);
  const thumbWidth = useSharedValue(0);
  const measurements = useRef<{ x: number; width: number }[]>([]);
  const activeIndex = SEGMENTS.indexOf(active);

  useEffect(() => {
    const layoutInfo = measurements.current[activeIndex];
    if (!layoutInfo) return;
    thumbX.value = reducedMotion
      ? layoutInfo.x
      : withSpring(layoutInfo.x, motion.springs.standard);
    thumbWidth.value = reducedMotion
      ? layoutInfo.width
      : withSpring(layoutInfo.width, motion.springs.standard);
  }, [activeIndex, reducedMotion, thumbWidth, thumbX]);

  const thumbStyle = useAnimatedStyle(() => ({
    opacity: thumbWidth.value > 0 ? 1 : 0,
    width: thumbWidth.value,
    transform: [{ translateX: thumbX.value }],
  }));

  return (
    <View style={styles.segmentRow}>
      <View style={styles.segmentTrack}>
        <Animated.View
          pointerEvents="none"
          style={[
            styles.segmentThumb,
            { backgroundColor: palette.accent, borderColor: withAlpha(palette.white, 0.18) },
            thumbStyle,
          ]}
        />
        {SEGMENTS.map((segment, index) => {
          const selected = active === segment;
          return (
            <Pressable
              key={segment}
              accessibilityRole="button"
              accessibilityLabel={`Show ${segment}`}
              accessibilityState={{ selected }}
              onPress={() => onSelect(segment)}
              onLayout={(event) => {
                const { x, width } = event.nativeEvent.layout;
                measurements.current[index] = { x, width };
                if (index !== activeIndex) return;
                thumbX.value = reducedMotion
                  ? x
                  : withSpring(x, motion.springs.standard);
                thumbWidth.value = reducedMotion
                  ? width
                  : withSpring(width, motion.springs.standard);
              }}
              style={({ pressed }) => [
                styles.segmentTap,
                pressed && styles.segmentPressed,
              ]}
            >
              <View style={[styles.segment, selected && styles.segmentActive]}>
                <AppText
                  variant="label"
                  color={selected ? palette.accentInk : palette.inkMuted}
                  numberOfLines={1}
                  adjustsFontSizeToFit
                  minimumFontScale={0.78}
                  style={styles.segmentLabel}
                >
                  {segment[0].toUpperCase() + segment.slice(1)}
                </AppText>
              </View>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

type SongRowProps = {
  track: Track;
  queue?: Track[];
  favorite?: boolean;
  onPlay: (track: Track, queue?: Track[]) => void;
  onMenu: (track: Track, queue?: Track[]) => void;
  onFavorite?: (track: Track) => void;
  onAddToPlaylist?: (track: Track) => void;
};

function SongRow({
  track,
  queue,
  favorite = false,
  onPlay,
  onMenu,
  onFavorite,
  onAddToPlaylist,
}: SongRowProps) {
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  const actions: SwipeAction[] = [];
  if (onFavorite) {
    actions.push({
      key: 'favorite',
      label: favorite ? 'Unfavorite' : 'Favorite',
      icon: 'heart',
      iconColor: favorite ? palette.accent : palette.ink,
      backgroundColor: withAlpha(palette.accent, 0.16),
      onPress: () => onFavorite(track),
    });
  }
  if (onAddToPlaylist) {
    actions.push({
      key: 'playlist',
      label: 'Playlist',
      icon: 'plus',
      iconColor: palette.ink,
      backgroundColor: withAlpha(palette.ink, 0.07),
      onPress: () => onAddToPlaylist(track),
    });
  }

  return (
    <SwipeableRow
      actions={actions}
      enabled={actions.length > 0}
      radius={radii.md}
      actionBackgroundColor={palette.backgroundRaised}
      defaultIconColor={palette.ink}
      style={styles.songSwipe}
    >
      <ListRow
        leading={<Thumb track={track} size={44} />}
        title={track.title}
        subtitle={`${track.artist} · ${track.album}`}
        onPress={() => onPlay(track, queue)}
        accessibilityLabel={`Play ${track.title}`}
        accessibilityHint="Swipe left for favorite and playlist actions"
        trailing={(
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={`Manage ${track.title}`}
            onPress={() => onMenu(track, queue)}
            style={({ pressed }) => [styles.rowMenu, { opacity: pressed ? 0.6 : 1 }]}
            hitSlop={4}
          >
            <Feather name="more-horizontal" size={20} color={palette.inkMuted} />
          </Pressable>
        )}
      />
    </SwipeableRow>
  );
}

function BrowseTile({ icon }: { icon: 'disc' | 'user' }) {
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  return (
    <View style={styles.browseTile}>
      <Feather name={icon} size={20} color={palette.accent} />
    </View>
  );
}

export default function LibraryScreen() {
  const library = useMusicLibrary();
  const player = usePlayer();
  const { tapFeedback } = usePreferences();
  const { palette, reducedMotion } = useTheme();
  const styles = useThemedStyles(createStyles);
  const [createSheetOpen, setCreateSheetOpen] = useState(false);
  const [addToSheetTrack, setAddToSheetTrack] = useState<Track | null>(null);
  const [addSongsPlaylistId, setAddSongsPlaylistId] = useState<string | null>(null);
  const [songMenu, setSongMenu] = useState<{ track: Track; queue?: Track[] } | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<{ id: string; name: string } | null>(null);

  const play = (track: Track, queue?: Track[]) => {
    tapFeedback('selection');
    void player.playTrack(track, queue ?? library.displayTracks);
  };

  const statusLine = library.permission === null
    ? 'Checking music access…'
    : library.scanning
      ? 'Scanning…'
      : library.permission !== 'granted'
        ? 'Music access needed'
        : library.lastScanAt
        ? `${library.tracks.length} ${library.tracks.length === 1 ? 'song' : 'songs'} · Updated ${new Date(library.lastScanAt).toLocaleTimeString()}`
        : `${library.tracks.length} ${library.tracks.length === 1 ? 'song' : 'songs'} indexed`;

  const confirmDeletePlaylist = (id: string, name: string) => {
    setDeleteTarget({ id, name });
  };

  const openSongMenu = (track: Track, queue?: Track[]) => {
    setSongMenu({ track, queue });
  };

  const menuFavorite = songMenu
    ? library.favorites.has(songMenu.track.id)
    : false;

  const favoriteTracks = library.displayTracks.filter((track) => library.favorites.has(track.id));
  const addSongsPlaylist = library.playlists.find((playlist) => playlist.id === addSongsPlaylistId) ?? null;
  const addSongsPlaylistTracks = addSongsPlaylist
    ? addSongsPlaylist.trackIds
        .map((id) => library.displayTracksById.get(id))
        .filter((track): track is Track => Boolean(track))
    : [];

  const emptyLibrary =
    library.permission === 'granted'
      ? {
          title: 'No audio found',
          message: 'Put songs in your Music folder, then pull down to scan.',
          action: 'Scan your device',
          onAction: () => {
            tapFeedback('selection');
            void library.scan();
          },
        }
      : {
          title: 'Permission needed',
          message: 'Grant access to audio files to build your library.',
          action: 'Grant access',
          onAction: () => {
            tapFeedback('selection');
            void library.requestAccess();
          },
        };

  return (
    <SafeAreaView style={[styles.safe, { backgroundColor: palette.background }]} edges={['top']}>
      <ScreenHeader
        title="Library"
        subtitle={statusLine}
        action={(
          <GlassButton
            accessibilityRole="button"
            accessibilityLabel="Import songs"
            onPress={() => {
              tapFeedback('selection');
              void library.importFiles();
            }}
            radius={24}
            style={styles.scanButton}
          >
            <Feather name="download" size={20} color={palette.ink} />
          </GlassButton>
        )}
      />

      <SegmentControl
        active={library.tab}
        reducedMotion={reducedMotion}
        onSelect={(segment) => {
          tapFeedback('selection');
          library.setTab(segment);
        }}
      />

      <ScrollView
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl
            refreshing={library.scanning}
            onRefresh={() => {
              tapFeedback('selection');
              void library.scan();
            }}
            tintColor={palette.accent}
            colors={[palette.accent]}
            progressBackgroundColor={palette.surfaceRaised}
          />
        }
      >
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

        {library.tab === 'songs' ? (
          library.displayTracks.length === 0 ? (
            <>
              <EmptyState
                title={emptyLibrary.title}
                message={emptyLibrary.message}
                actionLabel={emptyLibrary.action}
                onAction={emptyLibrary.onAction}
              />
              {library.scanError ? (
                <AppText variant="micro" color={palette.danger} style={styles.scanError}>
                  {library.scanError}
                </AppText>
              ) : null}
            </>
          ) : (
            <>
              <SectionHeader label={`${library.displayTracks.length} songs`} />
              <ListGroup>
                {library.displayTracks.map((track) => (
                  <SongRow
                    key={track.id}
                    track={track}
                    favorite={library.favorites.has(track.id)}
                    onPlay={play}
                    onMenu={openSongMenu}
                    onFavorite={(selected) => {
                      tapFeedback('light');
                      library.toggleFavorite(selected.id);
                    }}
                    onAddToPlaylist={(selected) => {
                      tapFeedback('selection');
                      setAddToSheetTrack(selected);
                    }}
                  />
                ))}
              </ListGroup>
            </>
          )
        ) : null}

        {library.tab === 'albums' ? (
          library.albums.length === 0 ? (
            <EmptyState
              compact
              title="No albums yet"
              message="Albums appear when songs with album tags are indexed."
            />
          ) : (
            <>
              <SectionHeader label="Albums" />
              <ListGroup>
                {library.albums.map((album) => {
                  const count = library.displayTracks.filter((track) => track.album === album).length;
                  return (
                    <ListRow
                      key={album}
                      leading={<BrowseTile icon="disc" />}
                      title={album}
                      subtitle={`${count} ${count === 1 ? 'track' : 'tracks'}`}
                      onPress={() => {
                        tapFeedback('selection');
                        router.push({ pathname: '/album', params: { album } });
                      }}
                      accessibilityLabel={`Open album ${album}`}
                      accessibilityHint="Opens the album track list"
                      trailing={<Feather name="chevron-right" size={18} color={palette.inkFaint} />}
                    />
                  );
                })}
              </ListGroup>
            </>
          )
        ) : null}

        {library.tab === 'artists' ? (
          library.artists.length === 0 ? (
            <EmptyState
              compact
              title="No artists yet"
              message="Artists appear when songs with artist tags are indexed."
            />
          ) : (
            <>
              <SectionHeader label="Artists" />
              <ListGroup>
                {library.artists.map((artist) => {
                  const count = library.displayTracks.filter((track) => track.artist === artist).length;
                  return (
                    <ListRow
                      key={artist}
                      leading={<BrowseTile icon="user" />}
                      title={artist}
                      subtitle={`${count} ${count === 1 ? 'track' : 'tracks'}`}
                      onPress={() => {
                        tapFeedback('selection');
                        router.push({ pathname: '/artist', params: { artist } });
                      }}
                      accessibilityLabel={`Open artist ${artist}`}
                      accessibilityHint="Opens the artist track list"
                      trailing={<Feather name="chevron-right" size={18} color={palette.inkFaint} />}
                    />
                  );
                })}
              </ListGroup>
            </>
          )
        ) : null}

        {library.tab === 'playlists' ? (
          <>
            <SectionHeader
              label="Playlists"
              actionLabel="New playlist"
              onAction={() => {
                tapFeedback('selection');
                setCreateSheetOpen(true);
              }}
            />
            {library.playlists.length === 0 ? (
              <EmptyState
                compact
                title="No playlists yet"
                message="Create one to group songs, then add tracks from any song menu."
              />
            ) : (
              <ListGroup>
                {library.playlists.map((playlist, playlistIndex) => {
                  const playlistTracks = playlist.trackIds
                    .map((id) => library.displayTracksById.get(id))
                    .filter((track): track is Track => Boolean(track));
                  return (
                    <View
                      key={playlist.id}
                      style={[styles.playlistBlock, playlistIndex > 0 && styles.playlistDivider]}
                    >
                      <View style={styles.playlistHeader}>
                        <NoteTile size={40} />
                        <View style={styles.playlistTitle}>
                          <AppText variant="label" color={palette.ink} numberOfLines={1}>
                            {playlist.name}
                          </AppText>
                          <AppText variant="micro" color={palette.inkMuted}>
                            {playlistTracks.length} {playlistTracks.length === 1 ? 'track' : 'tracks'}
                          </AppText>
                        </View>
                        <Pressable
                          accessibilityRole="button"
                          accessibilityLabel={`Add songs to ${playlist.name}`}
                          onPress={() => {
                            tapFeedback('selection');
                            setAddSongsPlaylistId(playlist.id);
                          }}
                          style={({ pressed }) => [styles.playlistAddButton, { opacity: pressed ? 0.7 : 1 }]}
                        >
                          <Feather name="plus" size={14} color={palette.accentInk} />
                          <AppText variant="micro" color={palette.accentInk}>Add</AppText>
                        </Pressable>
                        <Pressable
                          accessibilityRole="button"
                          accessibilityLabel={`More options for ${playlist.name}`}
                          onPress={() => confirmDeletePlaylist(playlist.id, playlist.name)}
                          style={({ pressed }) => [styles.rowMenu, { opacity: pressed ? 0.6 : 1 }]}
                        >
                          <Feather name="more-horizontal" size={20} color={palette.inkMuted} />
                        </Pressable>
                      </View>
                      {playlistTracks.length === 0 ? (
                        <AppText variant="micro" color={palette.inkFaint} style={styles.playlistEmpty}>
                          No songs in this playlist yet.
                        </AppText>
                      ) : (
                        playlistTracks.map((track, trackIndex) => (
                          <View
                            key={track.id}
                            style={[styles.playlistTrackRow, trackIndex > 0 && styles.playlistDivider]}
                          >
                            <Pressable
                              accessibilityRole="button"
                              accessibilityLabel={`Play ${track.title}`}
                              onPress={() => play(track, playlistTracks)}
                              style={({ pressed }) => [styles.playlistTrackMain, pressed && styles.rowPressed]}
                            >
                              <Thumb track={track} size={36} />
                              <View style={styles.rowText}>
                                <AppText variant="label" color={palette.ink} numberOfLines={1}>{track.title}</AppText>
                                <AppText variant="micro" color={palette.inkMuted} numberOfLines={1}>{track.artist}</AppText>
                              </View>
                            </Pressable>
                            <Pressable
                              accessibilityRole="button"
                              accessibilityLabel={`Remove ${track.title} from ${playlist.name}`}
                              onPress={() => {
                                tapFeedback('light');
                                library.removeFromPlaylist(playlist.id, track.id);
                              }}
                              style={styles.rowMenu}
                            >
                              <Feather name="x" size={18} color={palette.inkFaint} />
                            </Pressable>
                          </View>
                        ))
                      )}
                    </View>
                  );
                })}
              </ListGroup>
            )}
          </>
        ) : null}

        {library.tab === 'favorites' ? (
          favoriteTracks.length === 0 ? (
            <EmptyState
              title="No favorites yet"
              message="Open a song’s menu and choose Add favorite."
              actionLabel="Browse songs"
              onAction={() => {
                tapFeedback('selection');
                library.setTab('songs');
              }}
            />
          ) : (
            <>
              <SectionHeader label={`${favoriteTracks.length} favorites`} />
              <ListGroup>
                {favoriteTracks.map((track) => (
                  <SongRow
                    key={track.id}
                    track={track}
                    queue={favoriteTracks}
                    favorite
                    onPlay={play}
                    onMenu={openSongMenu}
                    onFavorite={(selected) => {
                      tapFeedback('light');
                      library.toggleFavorite(selected.id);
                    }}
                    onAddToPlaylist={(selected) => {
                      tapFeedback('selection');
                      setAddToSheetTrack(selected);
                    }}
                  />
                ))}
              </ListGroup>
            </>
          )
        ) : null}
      </ScrollView>

      <CreatePlaylistSheet
        visible={createSheetOpen}
        onClose={() => setCreateSheetOpen(false)}
        onCreate={(name) => {
          tapFeedback('success');
          library.createPlaylist(name);
        }}
      />
      <AddToPlaylistSheet
        visible={addToSheetTrack !== null}
        onClose={() => setAddToSheetTrack(null)}
        trackTitle={addToSheetTrack?.title ?? null}
        playlists={library.playlists}
        onSelectPlaylist={(playlistId) => {
          if (addToSheetTrack) {
            library.addToPlaylist(playlistId, addToSheetTrack.id);
          }
        }}
        onCreatePlaylist={(name) => library.createPlaylist(name)}
      />
      <AddSongsSheet
        visible={addSongsPlaylist !== null}
        onClose={() => setAddSongsPlaylistId(null)}
        playlistName={addSongsPlaylist?.name ?? null}
        playlistTrackIds={addSongsPlaylistTracks.map((track) => track.id)}
        tracks={library.displayTracks}
        onAdd={(trackId) => {
          if (addSongsPlaylist) library.addToPlaylist(addSongsPlaylist.id, trackId);
        }}
        onRemove={(trackId) => {
          if (addSongsPlaylist) library.removeFromPlaylist(addSongsPlaylist.id, trackId);
        }}
      />
      <AppDialog
        visible={songMenu !== null}
        title={songMenu?.track.title ?? ''}
        onClose={() => setSongMenu(null)}
        actions={songMenu ? [
          {
            label: 'Play',
            onPress: () => play(songMenu.track, songMenu.queue),
          },
          {
            label: 'Add to playlist',
            onPress: () => {
              tapFeedback('selection');
              setAddToSheetTrack(songMenu.track);
            },
          },
          {
            label: menuFavorite ? 'Remove favorite' : 'Add favorite',
            onPress: () => {
              tapFeedback('selection');
              library.toggleFavorite(songMenu.track.id);
            },
          },
          { label: 'Cancel', onPress: () => {} },
        ] : []}
      />
      <AppDialog
        visible={deleteTarget !== null}
        title="Delete playlist?"
        message={deleteTarget
          ? `"${deleteTarget.name}" will be removed. Your songs stay in the library.`
          : undefined}
        onClose={() => setDeleteTarget(null)}
        actions={deleteTarget ? [
          {
            label: 'Delete',
            tone: 'danger',
            onPress: () => {
              tapFeedback('light');
              library.deletePlaylist(deleteTarget.id);
            },
          },
          { label: 'Cancel', onPress: () => {} },
        ] : []}
      />
    </SafeAreaView>
  );
}

const createStyles = ({ palette, glass }: AppTheme) => ({
  safe: { flex: 1 },
  scanButton: {
    width: 48,
    height: 48,
    borderRadius: 24,
  },
  segmentRow: {
    flexDirection: 'row' as const,
    paddingHorizontal: layout.screenPadding,
    paddingTop: spacing.sm,
  },
  segmentTrack: {
    flex: 1,
    flexDirection: 'row' as const,
    gap: spacing.xs,
    position: 'relative' as const,
  },
  segmentThumb: {
    position: 'absolute' as const,
    left: 0,
    top: 6,
    height: 36,
    borderRadius: radii.pill,
    borderWidth: 1,
    elevation: 2,
  },
  segmentTap: {
    flex: 1,
    height: 48,
    justifyContent: 'center' as const,
  },
  segmentPressed: {
    opacity: 0.82,
  },
  segment: {
    height: 36,
    justifyContent: 'center' as const,
    alignItems: 'center' as const,
    paddingHorizontal: 2,
    borderRadius: radii.pill,
    backgroundColor: glass.tintSoft,
    borderWidth: 1,
    borderColor: glass.edgeSoft,
  },
  segmentActive: {
    backgroundColor: 'transparent',
    borderColor: 'transparent',
  },
  segmentLabel: {
    textAlign: 'center' as const,
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
    width: 32,
    height: 32,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  },
  scanError: {
    paddingHorizontal: layout.screenPadding,
    textAlign: 'center' as const,
  },
  songSwipe: {
    marginBottom: spacing.xxs,
  },
  rowMenu: {
    width: 44,
    height: 44,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  },
  rowText: { flex: 1, gap: 2 },
  rowPressed: { opacity: 0.7, transform: [{ scale: 0.99 }] },
  browseTile: {
    width: 44,
    height: 44,
    borderRadius: radii.md,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
    backgroundColor: palette.surfaceMuted,
    borderWidth: 1,
    borderColor: palette.border,
  },
  playlistBlock: {
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.xs,
  },
  playlistDivider: {
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: palette.border,
  },
  playlistHeader: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.sm,
    paddingHorizontal: spacing.xs,
  },
  playlistTitle: { flex: 1, gap: 2 },
  playlistAddButton: {
    minHeight: 36,
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: 4,
    paddingHorizontal: spacing.sm,
    borderRadius: radii.pill,
    backgroundColor: palette.accent,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: withAlpha(palette.white, 0.18),
  },
  playlistEmpty: {
    paddingHorizontal: spacing.xs,
    paddingTop: spacing.sm,
  },
  playlistTrackRow: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.xs,
    marginTop: spacing.xs,
  },
  playlistTrackMain: {
    flex: 1,
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.sm,
    paddingVertical: spacing.xs,
    paddingLeft: spacing.xs,
    borderRadius: radii.sm,
  },
});
