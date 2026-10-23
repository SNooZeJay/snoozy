import Feather from '@expo/vector-icons/Feather';
import { router } from 'expo-router';
import { useState } from 'react';
import {
  Alert,
  Linking,
  Pressable,
  RefreshControl,
  ScrollView,
  StyleSheet,
  View,
} from 'react-native';
import Animated, { FadeIn, FadeInDown } from 'react-native-reanimated';
import { SafeAreaView } from 'react-native-safe-area-context';

import { AppText } from '../../components/AppText';
import { CreatePlaylistSheet } from '../../components/CreatePlaylistSheet';
import { GlassButton } from '../../components/glass/GlassButton';
import { GlassSurface } from '../../components/glass/GlassSurface';
import { MiniPlayer } from '../../components/MiniPlayer';
import { DottedNote, NoteTile, Thumb } from '../../components/Thumb';
import { useMusicLibrary } from '../../storage/MusicLibraryContext';
import { usePlayer } from '../../playback/PlayerContext';
import { usePreferences } from '../../storage/PreferencesContext';
import { staggerEnter } from '../../motion/stagger';
import { colors, glass, layout, radii, spacing, useTheme } from '../../theme';

export default function HomeScreen() {
  const library = useMusicLibrary();
  const player = usePlayer();
  const { tapFeedback } = usePreferences();
  const { reducedMotion } = useTheme();
  const [playlistSheetOpen, setPlaylistSheetOpen] = useState(false);

  // Card entrances: fades stay under reduced motion, the drop-in does not.
  const cardEnter = reducedMotion ? FadeIn.duration(240) : FadeInDown.duration(400);

  const recentTracks = library.recents
    .map((id) => library.displayTracksById.get(id))
    .filter((track): track is NonNullable<typeof track> => Boolean(track));

  const playlistTrackCount = (trackIds: string[]) =>
    trackIds.filter((id) => library.displayTracksById.has(id)).length;

  const confirmClearHistory = () => {
    Alert.alert('Clear recently played?', 'Your play history will be emptied.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Clear',
        style: 'destructive',
        onPress: () => {
          tapFeedback('light');
          library.clearRecentHistory();
        },
      },
    ]);
  };

  const playRecent = (track: NonNullable<(typeof recentTracks)[number]>) => {
    tapFeedback('selection');
    void player.playTrack(track, library.displayTracks);
  };

  const openLibrary = (tab: 'songs' | 'playlists') => {
    tapFeedback('selection');
    library.setTab(tab);
    router.push('/library');
  };

  const confirmDeletePlaylist = (id: string, name: string) => {
    Alert.alert('Delete playlist?', `"${name}" will be removed. Your songs stay in the library.`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: () => {
          tapFeedback('light');
          library.deletePlaylist(id);
        },
      },
    ]);
  };

  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
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
        <View style={styles.header}>
          <View style={styles.headerCopy}>
            <AppText variant="overline" color={colors.accent}>Snoozy</AppText>
            <AppText variant="display" color={colors.ink}>Your music</AppText>
          </View>
          <GlassButton
            accessibilityRole="button"
            accessibilityLabel="Import songs"
            onPress={() => {
              tapFeedback('selection');
              void library.importFiles();
            }}
            radius={24}
            style={styles.circleButton}
          >
            <Feather name="download" size={20} color={colors.ink} />
          </GlassButton>
        </View>

        {player.error ? (
          <Animated.View entering={cardEnter} style={styles.errorBanner}>
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
          </Animated.View>
        ) : null}

        {library.permission === null ? (
          <Animated.View entering={cardEnter} style={styles.emptyCard}>
            <AppText variant="title" color={colors.ink}>Checking library…</AppText>
            <AppText variant="body" color={colors.inkMuted}>
              Looking for audio files on this device.
            </AppText>
          </Animated.View>
        ) : library.permission !== 'granted' ? (
          <Animated.View entering={cardEnter} style={styles.emptyCard}>
            <AppText variant="title" color={colors.ink}>Permission needed</AppText>
            <AppText variant="body" color={colors.inkMuted}>
              Snoozy needs access to audio files on this device to build your library.
            </AppText>
            {library.scanError ? (
              <AppText variant="micro" color={colors.danger}>{library.scanError}</AppText>
            ) : null}
            <Pressable
              accessibilityRole="button"
              onPress={() => {
                tapFeedback('selection');
                if (library.permissionCanAskAgain) {
                  void library.requestAccess();
                } else {
                  void Linking.openSettings();
                }
              }}
              style={({ pressed }) => [styles.primaryButton, { opacity: pressed ? 0.75 : 1 }]}
            >
              <AppText variant="label" color={colors.accentInk}>
                {library.permissionCanAskAgain ? 'Grant access' : 'Open settings'}
              </AppText>
            </Pressable>
          </Animated.View>
        ) : library.scanning ? (
          <Animated.View entering={cardEnter} style={styles.emptyCard}>
            <AppText variant="title" color={colors.ink}>Scanning…</AppText>
            <AppText variant="body" color={colors.inkMuted}>
              {library.tracks.length} songs found so far.
            </AppText>
          </Animated.View>
        ) : library.tracks.length === 0 ? (
          <Animated.View entering={cardEnter} style={styles.emptyCard}>
            <DottedNote size={96} />
            <AppText variant="title" color={colors.ink}>No audio found on this device</AppText>
            <AppText variant="body" color={colors.inkMuted}>
              Put MP3, FLAC, or other audio files in your Music folder, then scan.
              You can also import files with the button above.
            </AppText>
            {library.scanError ? (
              <AppText variant="micro" color={colors.danger}>{library.scanError}</AppText>
            ) : null}
            <Pressable
              accessibilityRole="button"
              onPress={() => {
                tapFeedback('selection');
                void library.scan();
              }}
              style={({ pressed }) => [styles.primaryButton, { opacity: pressed ? 0.75 : 1 }]}
            >
              <AppText variant="label" color={colors.accentInk}>Scan your device</AppText>
            </Pressable>
          </Animated.View>
        ) : null}

        {library.tracks.length > 0 ? (
          <Animated.View entering={cardEnter}>
            <GlassSurface variant="card" style={styles.recentCard}>
            <View style={styles.cardHeader}>
              <AppText variant="heading" color={colors.ink}>Recently</AppText>
              {recentTracks.length > 0 ? (
                <Pressable
                  accessibilityRole="button"
                  accessibilityLabel="Clear recently played"
                  hitSlop={8}
                  onPress={() => {
                    tapFeedback('light');
                    confirmClearHistory();
                  }}
                  style={styles.textAction}
                >
                  <AppText variant="label" color={colors.inkMuted}>Clear</AppText>
                </Pressable>
              ) : null}
            </View>
            {recentTracks.length === 0 ? (
              <View style={styles.recentEmpty}>
                <DottedNote size={64} />
                <AppText variant="body" color={colors.inkMuted}>No tracks played yet.</AppText>
              </View>
            ) : (
              <View style={styles.recentRows}>
                {recentTracks.map((track, index) => (
                  <Animated.View
                    key={track.id}
                    entering={staggerEnter(index, reducedMotion)}
                  >
                    <Pressable
                      accessibilityRole="button"
                      accessibilityLabel={`Play ${track.title}`}
                      onPress={() => playRecent(track)}
                      style={({ pressed }) => [styles.row, pressed && styles.rowPressed]}
                    >
                      <Thumb track={track} size={48} />
                      <View style={styles.rowText}>
                        <AppText variant="label" color={colors.ink} numberOfLines={1}>{track.title}</AppText>
                        <AppText variant="micro" color={colors.inkMuted} numberOfLines={1}>{track.artist}</AppText>
                      </View>
                      <Feather name="play" size={18} color={colors.inkMuted} />
                    </Pressable>
                  </Animated.View>
                ))}
              </View>
            )}
          </GlassSurface>
          </Animated.View>
        ) : null}

        {library.tracks.length > 0 ? (
          <Animated.View entering={cardEnter} style={styles.section}>
            <View style={styles.sectionHeader}>
              <AppText variant="heading" color={colors.ink}>Playlists</AppText>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="New playlist"
                onPress={() => {
                  tapFeedback('selection');
                  setPlaylistSheetOpen(true);
                }}
                style={({ pressed }) => [styles.circleButtonSmall, { opacity: pressed ? 0.7 : 1 }]}
              >
                <Feather name="plus" size={22} color={colors.ink} />
              </Pressable>
            </View>
            {library.playlists.length === 0 ? (
              <View style={styles.noteCard}>
                <DottedNote size={56} />
                <AppText variant="body" color={colors.inkMuted}>
                  No playlists yet. Tap + to create one.
                </AppText>
              </View>
            ) : (
              <View style={styles.list}>
                {library.playlists.map((playlist, index) => (
                  <Animated.View
                    key={playlist.id}
                    entering={staggerEnter(index, reducedMotion)}
                  >
                    <GlassSurface variant="row" radius={radii.lg} style={styles.rowCard}>
                      <Pressable
                        accessibilityRole="button"
                        accessibilityLabel={`Open ${playlist.name} in library`}
                        onPress={() => openLibrary('playlists')}
                        style={({ pressed }) => [styles.rowInner, pressed && styles.rowPressed]}
                      >
                        <NoteTile size={48} />
                        <View style={styles.rowText}>
                          <AppText variant="label" color={colors.ink} numberOfLines={1}>{playlist.name}</AppText>
                          <AppText variant="micro" color={colors.inkMuted}>
                            {playlistTrackCount(playlist.trackIds)}{' '}
                            {playlistTrackCount(playlist.trackIds) === 1 ? 'track' : 'tracks'}
                          </AppText>
                        </View>
                      </Pressable>
                      <Pressable
                        accessibilityRole="button"
                        accessibilityLabel={`Manage ${playlist.name}`}
                        onPress={() => confirmDeletePlaylist(playlist.id, playlist.name)}
                        style={({ pressed }) => [styles.rowMenu, { opacity: pressed ? 0.6 : 1 }]}
                      >
                        <Feather name="more-horizontal" size={20} color={colors.inkMuted} />
                      </Pressable>
                    </GlassSurface>
                  </Animated.View>
                ))}
              </View>
            )}
          </Animated.View>
        ) : null}

        {library.tracks.length > 0 ? (
          <Animated.View entering={cardEnter} style={styles.section}>
            <View style={styles.sectionHeader}>
              <AppText variant="heading" color={colors.ink}>Library</AppText>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="See all songs"
                hitSlop={8}
                onPress={() => openLibrary('songs')}
                style={styles.textAction}
              >
                <AppText variant="label" color={colors.inkMuted}>See all</AppText>
              </Pressable>
            </View>
            <GlassButton
              accessibilityRole="button"
              accessibilityLabel="Browse all songs"
              onPress={() => openLibrary('songs')}
              variant="row"
              radius={radii.md}
              style={styles.browseButton}
            >
              <Feather name="grid" size={18} color={colors.accent} />
              <AppText variant="label" color={colors.ink}>Browse all songs</AppText>
            </GlassButton>
          </Animated.View>
        ) : null}
      </ScrollView>
      <MiniPlayer />
      <CreatePlaylistSheet
        visible={playlistSheetOpen}
        onClose={() => setPlaylistSheetOpen(false)}
        onCreate={(name) => {
          tapFeedback('success');
          library.createPlaylist(name);
        }}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  content: { padding: layout.screenPadding, paddingBottom: layout.tabBarSpace, gap: spacing.xxl },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: spacing.md,
  },
  headerCopy: { flex: 1, gap: spacing.xs },
  circleButton: {
    width: 48,
    height: 48,
    borderRadius: 24,
  },
  circleButtonSmall: {
    width: 48,
    height: 48,
    alignItems: 'center',
    justifyContent: 'center',
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
    padding: spacing.xl,
    borderRadius: radii.xl,
    backgroundColor: glass.tint,
    borderWidth: 1,
    borderColor: glass.edge,
    alignItems: 'flex-start',
  },
  primaryButton: {
    alignSelf: 'flex-start',
    minHeight: 48,
    paddingHorizontal: spacing.xl,
    paddingVertical: spacing.sm,
    borderRadius: radii.pill,
    backgroundColor: colors.accent,
    justifyContent: 'center',
  },
  recentCard: {
    gap: spacing.sm,
    padding: spacing.lg,
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  textAction: {
    minHeight: 48,
    justifyContent: 'center',
    paddingLeft: spacing.md,
  },
  recentEmpty: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.lg,
    paddingVertical: spacing.sm,
  },
  recentRows: { gap: 2 },
  section: { gap: spacing.sm },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  list: { gap: spacing.sm },
  noteCard: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.lg,
    padding: spacing.lg,
    borderRadius: radii.xl,
    backgroundColor: glass.tintSoft,
    borderWidth: 1,
    borderStyle: 'dashed',
    borderColor: glass.edgeStrong,
  },
  rowCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.xs,
  },
  rowInner: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.xs,
    borderRadius: radii.md,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    paddingVertical: spacing.xs,
    borderRadius: radii.md,
  },
  rowPressed: { opacity: 0.7 },
  rowText: { flex: 1, gap: 2 },
  rowMenu: {
    width: 48,
    height: 48,
    alignItems: 'center',
    justifyContent: 'center',
  },
  browseButton: {
    minHeight: 48,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingHorizontal: spacing.lg,
    alignSelf: 'flex-start',
  },
});
