import Feather from '@expo/vector-icons/Feather';
import { router } from 'expo-router';
import { useState } from 'react';
import {
  Alert,
  Pressable,
  RefreshControl,
  ScrollView,
  StyleSheet,
  View,
} from 'react-native';
import Animated, { FadeIn, FadeInDown } from 'react-native-reanimated';
import { SafeAreaView } from 'react-native-safe-area-context';

import { AppText } from '../../components/AppText';
import { AddToPlaylistSheet } from '../../components/AddToPlaylistSheet';
import { AddSongsSheet } from '../../components/AddSongsSheet';
import { CreatePlaylistSheet } from '../../components/CreatePlaylistSheet';
import { MiniPlayer } from '../../components/MiniPlayer';
import { DottedNote, Thumb } from '../../components/Thumb';
import { useMusicLibrary } from '../../storage/MusicLibraryContext';
import { usePlayer } from '../../playback/PlayerContext';
import { usePreferences } from '../../storage/PreferencesContext';
import type { Track } from '../../types/music';
import { colors, layout, radii, spacing, useTheme } from '../../theme';

const SEGMENTS = ['songs', 'albums', 'artists', 'playlists', 'favorites'] as const;

type SongRowProps = {
  track: Track;
  queue?: Track[];
  onPlay: (track: Track, queue?: Track[]) => void;
  onMenu: (track: Track, queue?: Track[]) => void;
};

function SongRow({ track, queue, onPlay, onMenu }: SongRowProps) {
  return (
    <View style={styles.rowCard}>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Play ${track.title}`}
        onPress={() => onPlay(track, queue)}
        style={({ pressed }) => [styles.rowInner, pressed && styles.rowPressed]}
      >
        <Thumb track={track} size={48} />
        <View style={styles.rowText}>
          <AppText variant="label" color={colors.ink} numberOfLines={1}>{track.title}</AppText>
          <AppText variant="micro" color={colors.inkMuted} numberOfLines={1}>{track.artist} · {track.album}</AppText>
        </View>
      </Pressable>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Manage ${track.title}`}
        onPress={() => onMenu(track, queue)}
        style={({ pressed }) => [styles.rowMenu, { opacity: pressed ? 0.6 : 1 }]}
        hitSlop={4}
      >
        <Feather name="more-horizontal" size={20} color={colors.inkMuted} />
      </Pressable>
    </View>
  );
}

export default function LibraryScreen() {
  const library = useMusicLibrary();
  const player = usePlayer();
  const { tapFeedback } = usePreferences();
  const { reducedMotion } = useTheme();
  const [createSheetOpen, setCreateSheetOpen] = useState(false);
  const [addToSheetTrack, setAddToSheetTrack] = useState<Track | null>(null);
  const [addSongsPlaylistId, setAddSongsPlaylistId] = useState<string | null>(null);

  // Card entrances: fades stay under reduced motion, the drop-in does not.
  const cardEnter = reducedMotion
    ? FadeIn.duration(240)
    : FadeInDown.duration(400);

  const play = (track: Track, queue?: Track[]) => {
    tapFeedback('selection');
    void player.playTrack(track, queue ?? library.displayTracks);
  };

  const statusLine = library.scanning
    ? 'Scanning…'
    : library.permission !== 'granted'
      ? 'Music access needed'
      : library.lastScanAt
        ? `${library.tracks.length} ${library.tracks.length === 1 ? 'song' : 'songs'} · Updated ${new Date(library.lastScanAt).toLocaleTimeString()}`
        : `${library.tracks.length} ${library.tracks.length === 1 ? 'song' : 'songs'} indexed`;

  const confirmDeletePlaylist = (id: string, name: string) => {
    Alert.alert(
      'Delete playlist?',
      `"${name}" will be removed. Your songs stay in the library.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: () => {
            tapFeedback('light');
            library.deletePlaylist(id);
          },
        },
      ],
    );
  };

  const openSongMenu = (track: Track, queue?: Track[]) => {
    const favorite = library.favorites.has(track.id);
    Alert.alert(track.title, undefined, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Add to playlist',
        onPress: () => setAddToSheetTrack(track),
      },
      {
        text: favorite ? 'Remove favorite' : 'Add favorite',
        onPress: () => library.toggleFavorite(track.id),
      },
      {
        text: 'Play',
        onPress: () => play(track, queue),
      },
    ]);
  };

  const favoriteTracks = library.displayTracks.filter((track) => library.favorites.has(track.id));
  const addSongsPlaylist = library.playlists.find((playlist) => playlist.id === addSongsPlaylistId) ?? null;

  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
      <View style={styles.header}>
        <View style={styles.headerCopy}>
          <AppText variant="display" color={colors.ink}>Library</AppText>
          <AppText variant="micro" color={colors.inkMuted} style={styles.status}>
            {statusLine}
          </AppText>
        </View>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Import songs"
          onPress={() => {
            tapFeedback('selection');
            void library.importFiles();
          }}
          style={({ pressed }) => [styles.scanButton, { opacity: pressed ? 0.7 : 1 }]}
        >
          <Feather name="download" size={20} color={colors.ink} />
        </Pressable>
      </View>

      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.segmentRow}
      >
        {SEGMENTS.map((segment) => (
          <Pressable
            key={segment}
            accessibilityRole="button"
            accessibilityLabel={`Show ${segment}`}
            accessibilityState={{ selected: library.tab === segment }}
            onPress={() => {
              tapFeedback('selection');
              library.setTab(segment);
            }}
            style={({ pressed }) => [styles.segmentTap, { opacity: pressed ? 0.75 : 1 }]}
          >
            <View style={[styles.segment, library.tab === segment && styles.segmentActive]}>
              <AppText
                variant="label"
                color={library.tab === segment ? colors.accentInk : colors.inkMuted}
              >
                {segment[0].toUpperCase() + segment.slice(1)}
              </AppText>
            </View>
          </Pressable>
        ))}
      </ScrollView>

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
            tintColor={colors.accent}
            colors={[colors.accent]}
            progressBackgroundColor={colors.surfaceRaised}
          />
        }
      >
        {player.error ? (
          <View style={styles.errorBanner}>
            <Feather name="alert-triangle" size={18} color={colors.danger} />
            <AppText variant="label" color={colors.danger} style={styles.errorText}>
              {player.error}
            </AppText>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Dismiss error"
              hitSlop={8}
              onPress={player.dismissError}
              style={styles.errorClose}
            >
              <Feather name="x" size={18} color={colors.danger} />
            </Pressable>
          </View>
        ) : null}

        {library.tab === 'songs' ? (
          library.displayTracks.length === 0 ? (
            <Animated.View entering={cardEnter} style={styles.emptyCard}>
              <DottedNote size={64} />
              <AppText variant="title" color={colors.ink}>
                {library.permission === 'granted' ? 'No audio found' : 'Permission needed'}
              </AppText>
              <AppText variant="body" color={colors.inkMuted}>
                {library.permission === 'granted'
                  ? 'Put songs in your Music folder, then pull down to scan.'
                  : 'Grant access to audio files to build your library.'}
              </AppText>
              {library.scanError ? (
                <AppText variant="micro" color={colors.danger}>{library.scanError}</AppText>
              ) : null}
              <Pressable
                accessibilityRole="button"
                onPress={() => {
                  tapFeedback('selection');
                  if (library.permission === 'granted') {
                    void library.scan();
                  } else {
                    void library.requestAccess();
                  }
                }}
                style={({ pressed }) => [styles.primaryButton, { opacity: pressed ? 0.75 : 1 }]}
              >
                <AppText variant="label" color={colors.accentInk}>
                  {library.permission === 'granted' ? 'Scan your device' : 'Grant access'}
                </AppText>
              </Pressable>
            </Animated.View>
          ) : (
            library.displayTracks.map((track) => (
              <SongRow key={track.id} track={track} onPlay={play} onMenu={openSongMenu} />
            ))
          )
        ) : null}

        {library.tab === 'albums' ? (
          library.albums.length === 0 ? (
            <AppText variant="body" color={colors.inkFaint}>No albums found.</AppText>
          ) : (
            library.albums.map((album) => (
              <Pressable
                key={album}
                accessibilityRole="button"
                accessibilityLabel={`Open album ${album}`}
                onPress={() => {
                  tapFeedback('selection');
                  router.push({ pathname: '/album', params: { album } });
                }}
                style={({ pressed }) => [styles.rowCard, styles.rowPlain, pressed && styles.rowPressed]}
              >
                <View style={[styles.albumTile, { width: 48, height: 48 }]}>
                  <Feather name="disc" size={22} color={colors.accentInk} />
                </View>
                <View style={styles.rowText}>
                  <AppText variant="label" color={colors.ink}>{album}</AppText>
                  <AppText variant="micro" color={colors.inkMuted}>
                    {library.displayTracks.filter((track) => track.album === album).length} tracks
                  </AppText>
                </View>
                <Feather name="chevron-right" size={18} color={colors.inkFaint} />
              </Pressable>
            ))
          )
        ) : null}

        {library.tab === 'artists' ? (
          library.artists.length === 0 ? (
            <AppText variant="body" color={colors.inkFaint}>No artists found.</AppText>
          ) : (
            library.artists.map((artist) => (
              <Pressable
                key={artist}
                accessibilityRole="button"
                accessibilityLabel={`Open artist ${artist}`}
                onPress={() => {
                  tapFeedback('selection');
                  router.push({ pathname: '/artist', params: { artist } });
                }}
                style={({ pressed }) => [styles.rowCard, styles.rowPlain, pressed && styles.rowPressed]}
              >
                <View style={[styles.albumTile, { width: 48, height: 48 }]}>
                  <Feather name="user" size={22} color={colors.accentInk} />
                </View>
                <View style={styles.rowText}>
                  <AppText variant="label" color={colors.ink}>{artist}</AppText>
                  <AppText variant="micro" color={colors.inkMuted}>
                    {library.displayTracks.filter((track) => track.artist === artist).length} tracks
                  </AppText>
                </View>
                <Feather name="chevron-right" size={18} color={colors.inkFaint} />
              </Pressable>
            ))
          )
        ) : null}

        {library.tab === 'playlists' ? (
          <View style={styles.playlistSection}>
            <View style={styles.playlistSectionHeader}>
              <AppText variant="heading" color={colors.ink}>Playlists</AppText>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="New playlist"
                onPress={() => {
                  tapFeedback('selection');
                  setCreateSheetOpen(true);
                }}
                style={({ pressed }) => [styles.newPlaylistButton, { opacity: pressed ? 0.7 : 1 }]}
              >
                <Feather name="plus" size={16} color={colors.accentInk} />
                <AppText variant="label" color={colors.accentInk}>New playlist</AppText>
              </Pressable>
            </View>
            {library.playlists.length === 0 ? (
              <View style={styles.noteCard}>
                <DottedNote size={56} />
                <AppText variant="body" color={colors.inkMuted}>
                  No playlists yet. Create one to group your songs.
                </AppText>
              </View>
            ) : (
              library.playlists.map((playlist) => {
                const playlistTracks = playlist.trackIds
                  .map((id) => library.displayTracksById.get(id))
                  .filter((track): track is Track => Boolean(track));
                return (
                  <View key={playlist.id} style={styles.playlistCard}>
                    <View style={styles.playlistHeader}>
                      <View style={styles.playlistTitle}>
                        <AppText variant="heading" color={colors.ink}>{playlist.name}</AppText>
                        <AppText variant="micro" color={colors.inkMuted}>
                          {playlist.trackIds.length} {playlist.trackIds.length === 1 ? 'track' : 'tracks'}
                          {playlist.trackIds.length === 0 ? ' · Empty playlist' : ''}
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
                        <Feather name="plus" size={14} color={colors.accentInk} />
                        <AppText variant="micro" color={colors.accentInk}>Add songs</AppText>
                      </Pressable>
                      <Pressable
                        accessibilityRole="button"
                        accessibilityLabel={`More options for ${playlist.name}`}
                        onPress={() => confirmDeletePlaylist(playlist.id, playlist.name)}
                        style={({ pressed }) => [{ opacity: pressed ? 0.6 : 1 }, styles.rowMenu]}
                      >
                        <Feather name="more-horizontal" size={20} color={colors.inkMuted} />
                      </Pressable>
                    </View>
                    {playlist.trackIds.length === 0 ? (
                      <AppText variant="micro" color={colors.inkFaint}>
                        No songs in this playlist yet.
                      </AppText>
                    ) : (
                      playlistTracks.map((track) => (
                        <View key={track.id} style={styles.playlistTrack}>
                          <Pressable
                            accessibilityRole="button"
                            accessibilityLabel={`Play ${track.title}`}
                            onPress={() => play(track, playlistTracks)}
                            style={({ pressed }) => [styles.playlistTrackMain, pressed && styles.rowPressed]}
                          >
                            <Thumb track={track} size={36} />
                            <View style={styles.rowText}>
                              <AppText variant="label" color={colors.ink} numberOfLines={1}>{track.title}</AppText>
                              <AppText variant="micro" color={colors.inkMuted} numberOfLines={1}>{track.artist}</AppText>
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
                            <Feather name="x" size={18} color={colors.inkFaint} />
                          </Pressable>
                        </View>
                      ))
                    )}
                  </View>
                );
              })
            )}
          </View>
        ) : null}

        {library.tab === 'favorites' ? (
          favoriteTracks.length === 0 ? (
            <View style={styles.emptyCard}>
              <DottedNote size={64} />
              <AppText variant="title" color={colors.ink}>No favorites yet</AppText>
              <AppText variant="body" color={colors.inkMuted}>
                Open a song’s menu and choose Add favorite.
              </AppText>
            </View>
          ) : (
            favoriteTracks.map((track) => (
              <SongRow
                key={track.id}
                track={track}
                queue={favoriteTracks}
                onPlay={play}
                onMenu={openSongMenu}
              />
            ))
          )
        ) : null}
      </ScrollView>
      <MiniPlayer />
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
        playlistTrackIds={addSongsPlaylist?.trackIds ?? []}
        tracks={library.displayTracks}
        onAdd={(trackId) => {
          if (addSongsPlaylist) library.addToPlaylist(addSongsPlaylist.id, trackId);
        }}
        onRemove={(trackId) => {
          if (addSongsPlaylist) library.removeFromPlaylist(addSongsPlaylist.id, trackId);
        }}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: spacing.md,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.lg,
    paddingBottom: spacing.md,
  },
  headerCopy: { flex: 1, gap: spacing.xs },
  status: { color: colors.inkMuted },
  scanButton: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.surfaceRaised,
    borderWidth: 1,
    borderColor: colors.border,
  },
  segmentRow: {
    flexDirection: 'row',
    gap: spacing.xs,
    paddingHorizontal: spacing.lg,
  },
  segmentTap: {
    height: 48,
    justifyContent: 'center',
  },
  segment: {
    height: 34,
    justifyContent: 'center',
    paddingHorizontal: spacing.lg,
    borderRadius: radii.pill,
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.border,
  },
  segmentActive: {
    backgroundColor: colors.accent,
    borderColor: colors.accent,
  },
  content: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
    paddingBottom: layout.tabBarSpace,
    gap: spacing.sm,
  },
  errorBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    padding: spacing.md,
    borderRadius: radii.md,
    backgroundColor: colors.dangerSoft,
    borderWidth: 1,
    borderColor: colors.danger,
  },
  errorText: { flex: 1 },
  errorClose: { width: 32, height: 32, alignItems: 'center', justifyContent: 'center' },
  emptyCard: {
    gap: spacing.md,
    padding: spacing.lg,
    borderRadius: radii.lg,
    backgroundColor: colors.surfaceRaised,
    borderWidth: 1,
    borderColor: colors.border,
    alignItems: 'flex-start',
  },
  primaryButton: {
    alignSelf: 'flex-start',
    minHeight: 48,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    borderRadius: radii.pill,
    backgroundColor: colors.accent,
    justifyContent: 'center',
  },
  rowCard: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: radii.lg,
    backgroundColor: colors.surfaceRaised,
    borderWidth: 1,
    borderColor: colors.border,
    padding: spacing.xs,
  },
  rowPlain: {
    padding: spacing.sm,
  },
  rowInner: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.xs,
    borderRadius: radii.md,
  },
  rowPressed: { opacity: 0.7, transform: [{ scale: 0.99 }] },
  rowMenu: {
    width: 48,
    height: 48,
    alignItems: 'center',
    justifyContent: 'center',
  },
  albumTile: {
    borderRadius: radii.md,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.surfaceMuted,
    borderWidth: 1,
    borderColor: colors.border,
  },
  rowText: { flex: 1, gap: 2 },
  playlistSection: { gap: spacing.md },
  playlistSectionHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  newPlaylistButton: {
    minHeight: 48,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    paddingHorizontal: spacing.md,
    borderRadius: radii.pill,
    backgroundColor: colors.accent,
    justifyContent: 'center',
  },
  noteCard: {
    gap: spacing.md,
    padding: spacing.lg,
    borderRadius: radii.lg,
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderStyle: 'dashed',
    borderColor: colors.borderStrong,
    alignItems: 'flex-start',
  },
  playlistCard: {
    gap: spacing.sm,
    padding: spacing.md,
    borderRadius: radii.lg,
    backgroundColor: colors.surfaceRaised,
    borderWidth: 1,
    borderColor: colors.border,
  },
  playlistHeader: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  playlistTitle: { flex: 1, gap: 2 },
  playlistAddButton: {
    minHeight: 48,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    paddingHorizontal: spacing.sm,
    borderRadius: radii.pill,
    backgroundColor: colors.accent,
    justifyContent: 'center',
  },
  playlistTrack: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    borderTopWidth: 1,
    borderTopColor: colors.border,
    paddingTop: spacing.xs,
  },
  playlistTrackMain: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    paddingVertical: spacing.xs,
    borderRadius: radii.sm,
  },
});
