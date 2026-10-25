import Feather from '@expo/vector-icons/Feather';
import { router } from 'expo-router';
import { useState } from 'react';
import {
  Linking,
  Pressable,
  RefreshControl,
  ScrollView,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { AppDialog } from '../../components/AppDialog';
import { AppText } from '../../components/AppText';
import { CreatePlaylistSheet } from '../../components/CreatePlaylistSheet';
import { EmptyState } from '../../components/EmptyState';
import { GlassButton } from '../../components/glass/GlassButton';
import { ListGroup } from '../../components/ListGroup';
import { ListRow } from '../../components/ListRow';
import { ScreenHeader } from '../../components/ScreenHeader';
import { SectionHeader } from '../../components/SectionHeader';
import { NoteTile, Thumb } from '../../components/Thumb';
import { useMusicLibrary } from '../../storage/MusicLibraryContext';
import { usePlayer } from '../../playback/PlayerContext';
import { usePreferences } from '../../storage/PreferencesContext';
import {
  layout,
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  type AppTheme,
} from '../../theme';

function BrowseTile() {
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  return (
    <View style={styles.browseTile}>
      <Feather name="grid" size={18} color={palette.accent} />
    </View>
  );
}

export default function HomeScreen() {
  const library = useMusicLibrary();
  const player = usePlayer();
  const { tapFeedback } = usePreferences();
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  const [playlistSheetOpen, setPlaylistSheetOpen] = useState(false);
  const [clearHistoryOpen, setClearHistoryOpen] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<{ id: string; name: string } | null>(null);

  const recentTracks = library.recents
    .map((id) => library.displayTracksById.get(id))
    .filter((track): track is NonNullable<typeof track> => Boolean(track));

  const playlistTrackCount = (trackIds: string[]) =>
    trackIds.filter((id) => library.displayTracksById.has(id)).length;

  const confirmClearHistory = () => {
    setClearHistoryOpen(true);
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
    setDeleteTarget({ id, name });
  };

  const statusLine =
    library.permission === null
      ? 'Checking music access…'
      : library.scanning
        ? 'Scanning…'
        : library.tracks.length > 0
          ? `${library.tracks.length} ${library.tracks.length === 1 ? 'song' : 'songs'}`
          : 'No songs yet';

  return (
    <SafeAreaView style={[styles.safe, { backgroundColor: palette.background }]} edges={['top']}>
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
        <ScreenHeader
          eyebrow="Snoozy"
          title="Your music"
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
              style={styles.circleButton}
            >
              <Feather name="download" size={20} color={palette.ink} />
            </GlassButton>
          )}
        />

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

        {library.permission === null ? (
          <EmptyState
            compact
            title="Checking library…"
            message="Looking for audio files on this device."
          />
        ) : library.permission !== 'granted' ? (
          <>
            <EmptyState
              compact
              title="Permission needed"
              message="Snoozy needs access to audio files on this device to build your library."
              actionLabel={library.permissionCanAskAgain ? 'Grant access' : 'Open settings'}
              onAction={() => {
                tapFeedback('selection');
                if (library.permissionCanAskAgain) {
                  void library.requestAccess();
                } else {
                  void Linking.openSettings();
                }
              }}
            />
            {library.scanError ? (
              <AppText variant="micro" color={palette.danger} style={styles.scanError}>
                {library.scanError}
              </AppText>
            ) : null}
          </>
        ) : library.scanning ? (
          <EmptyState
            compact
            title="Scanning…"
            message={`${library.tracks.length} songs found so far.`}
          />
        ) : library.tracks.length === 0 ? (
          <>
            <EmptyState
              title="No audio found on this device"
              message="Put MP3, FLAC, or other audio files in your Music folder, then scan. You can also import files with the button above."
              actionLabel="Scan your device"
              onAction={() => {
                tapFeedback('selection');
                void library.scan();
              }}
            />
            {library.scanError ? (
              <AppText variant="micro" color={palette.danger} style={styles.scanError}>
                {library.scanError}
              </AppText>
            ) : null}
          </>
        ) : null}

        {library.tracks.length > 0 ? (
          <>
            <SectionHeader
              label="Recently played"
              actionLabel={recentTracks.length > 0 ? 'Clear' : undefined}
              onAction={recentTracks.length > 0
                ? () => {
                    tapFeedback('light');
                    confirmClearHistory();
                  }
                : undefined}
            />
            {recentTracks.length === 0 ? (
              <EmptyState
                compact
                title="Nothing played yet"
                message="Play a song and it will appear here."
              />
            ) : (
              <ListGroup>
                {recentTracks.map((track) => (
                  <ListRow
                    key={track.id}
                    leading={<Thumb track={track} size={44} />}
                    title={track.title}
                    subtitle={track.artist}
                    onPress={() => playRecent(track)}
                    accessibilityLabel={`Play ${track.title}`}
                    trailing={<Feather name="play" size={18} color={palette.inkMuted} />}
                  />
                ))}
              </ListGroup>
            )}
          </>
        ) : null}

        {library.tracks.length > 0 ? (
          <>
            <SectionHeader
              label="Playlists"
              actionLabel="New"
              onAction={() => {
                tapFeedback('selection');
                setPlaylistSheetOpen(true);
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
                {library.playlists.map((playlist) => {
                  const count = playlistTrackCount(playlist.trackIds);
                  return (
                    <ListRow
                      key={playlist.id}
                      leading={<NoteTile size={44} />}
                      title={playlist.name}
                      subtitle={`${count} ${count === 1 ? 'track' : 'tracks'}`}
                      onPress={() => openLibrary('playlists')}
                      accessibilityLabel={`Open ${playlist.name} in library`}
                      trailing={(
                        <Pressable
                          accessibilityRole="button"
                          accessibilityLabel={`Manage ${playlist.name}`}
                          onPress={() => confirmDeletePlaylist(playlist.id, playlist.name)}
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
          </>
        ) : null}

        {library.tracks.length > 0 ? (
          <>
            <SectionHeader
              label="Library"
              actionLabel="See all"
              onAction={() => openLibrary('songs')}
            />
            <ListGroup>
              <ListRow
                leading={<BrowseTile />}
                title="Browse all songs"
                subtitle={`${library.tracks.length} ${library.tracks.length === 1 ? 'track' : 'tracks'}`}
                onPress={() => openLibrary('songs')}
                accessibilityLabel="Browse all songs"
                trailing={<Feather name="chevron-right" size={18} color={palette.inkFaint} />}
              />
            </ListGroup>
          </>
        ) : null}
      </ScrollView>

      <CreatePlaylistSheet
        visible={playlistSheetOpen}
        onClose={() => setPlaylistSheetOpen(false)}
        onCreate={(name) => {
          tapFeedback('success');
          library.createPlaylist(name);
        }}
      />
      <AppDialog
        visible={clearHistoryOpen}
        title="Clear recently played?"
        message="Your play history will be emptied."
        onClose={() => setClearHistoryOpen(false)}
        actions={[
          {
            label: 'Clear',
            tone: 'danger',
            onPress: () => {
              tapFeedback('light');
              library.clearRecentHistory();
            },
          },
          { label: 'Cancel', onPress: () => {} },
        ]}
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

const createStyles = ({ palette }: AppTheme) => ({
  safe: { flex: 1 },
  content: {
    paddingTop: spacing.lg,
    paddingBottom: layout.tabBarSpace,
    gap: spacing.xxl,
  },
  circleButton: {
    width: 48,
    height: 48,
    borderRadius: 24,
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
  rowMenu: {
    width: 44,
    height: 44,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  },
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
});
