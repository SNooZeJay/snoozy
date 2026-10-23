import { useEffect, useState } from 'react';
import {
  Alert,
  Image,
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  TextInput,
  View,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import * as FileSystem from 'expo-file-system/legacy';


import { AppText } from './AppText';
import { IconButton } from './IconButton';
import { useMusicLibrary } from '../storage/MusicLibraryContext';
import {
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  type AppPalette,
  type AppTheme,
} from '../theme';
import { getTrackOverride, upsertTrackOverride, deleteTrackOverride } from '../storage/metadata';

type Props = {
  visible: boolean;
  onClose: () => void;
  trackId: string | null;
  original: { title: string; artist: string; album: string };
};

const MAX_BYTES = 20 * 1024 * 1024;

export function SongEditSheet({ visible, onClose, trackId, original }: Props) {
  const { palette, dark } = useTheme();
  const styles = useThemedStyles(createStyles);
  const library = useMusicLibrary();
  const [title, setTitle] = useState('');
  const [artist, setArtist] = useState('');
  const [album, setAlbum] = useState('');
  const [albumArtist, setAlbumArtist] = useState('');
  const [genre, setGenre] = useState('');
  const [year, setYear] = useState('');
  const [trackNumber, setTrackNumber] = useState('');
  const [description, setDescription] = useState('');
  const [artworkPath, setArtworkPath] = useState<string | null>(null);
  const [originalArtwork, setOriginalArtwork] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!visible || !trackId) return;
    let cancelled = false;
    const handle = setTimeout(() => {
      setLoading(true);
      setError(null);
      void getTrackOverride(trackId)
        .then((o) => {
          if (cancelled) return;
          setTitle(o?.title ?? '');
          setArtist(o?.artist ?? '');
          setAlbum(o?.album ?? '');
          setAlbumArtist(o?.albumArtist ?? '');
          setGenre(o?.genre ?? '');
          setYear(o?.year ?? '');
          setTrackNumber(o?.trackNumber ?? '');
          setDescription(o?.description ?? '');
          setArtworkPath(o?.artworkPath ?? null);
          setOriginalArtwork(o?.artworkPath ?? null);
          setLoading(false);
        })
        .catch((loadError) => {
          if (cancelled) return;
          setError(loadError instanceof Error ? loadError.message : 'Could not load song details');
          setLoading(false);
        });
    }, 0);
    return () => {
      cancelled = true;
      clearTimeout(handle);
    };
  }, [visible, trackId]);

  const validate = (): string | null => {
    if (title.trim() === '' && original.title.trim() === '') return 'Title cannot be empty';
    if (year.trim() !== '' && !/^\d{4}$/.test(year.trim())) return 'Year must be 4 digits';
    if (trackNumber.trim() !== '' && !/^\d+$/.test(trackNumber.trim())) return 'Track number must be a positive integer';
    if (trackNumber.trim() !== '' && parseInt(trackNumber.trim(), 10) <= 0) return 'Track number must be a positive integer';
    return null;
  };

  const handlePick = async () => {
    setError(null);
    const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!perm.granted) {
      setError('Permission denied');
      return;
    }
    const res = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      quality: 0.9,
    });
    if (res.canceled || !res.assets?.[0]) return;
    const asset = res.assets[0];
    if (asset.fileSize && asset.fileSize > MAX_BYTES) {
      setError('Image is larger than 20 MB');
      return;
    }
    const allowed = ['jpg', 'jpeg', 'png', 'webp'];
    const nameExt = asset.fileName?.split('.').pop()?.toLowerCase();
    const mimeExt = asset.mimeType?.split('/').pop()?.toLowerCase();
    const candidate =
      nameExt && allowed.includes(nameExt)
        ? nameExt
        : mimeExt === 'jpeg'
          ? 'jpg'
          : mimeExt;
    if (!candidate || !allowed.includes(candidate)) {
      setError('Unsupported image type');
      return;
    }
    const ext = candidate;
    if (!FileSystem.documentDirectory) {
      setError('App storage is unavailable');
      return;
    }
    try {
      const dir = `${FileSystem.documentDirectory}artwork/`;
      await FileSystem.makeDirectoryAsync(dir, { intermediates: true });
      const name = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}.${ext === 'jpeg' ? 'jpg' : ext}`;
      const target = `${dir}${name}`;
      await FileSystem.copyAsync({ from: asset.uri, to: target });
      setArtworkPath(target);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to save image');
    }
  };

  const handleSave = async () => {
    const v = validate();
    if (v) { setError(v); return; }
    if (!trackId) return;
    setSaving(true);
    setError(null);
    try {
      await upsertTrackOverride({
        trackId,
        title: title.trim() === '' ? null : title.trim(),
        artist: artist.trim() === '' ? null : artist.trim(),
        album: album.trim() === '' ? null : album.trim(),
        albumArtist: albumArtist.trim() === '' ? null : albumArtist.trim(),
        genre: genre.trim() === '' ? null : genre.trim(),
        year: year.trim() === '' ? null : year.trim(),
        trackNumber: trackNumber.trim() === '' ? null : trackNumber.trim(),
        description: description.trim() === '' ? null : description.trim(),
        artworkPath,
        updatedAt: Date.now(),
      });
      // Delete the replaced file only after the new row is committed; otherwise
      // a failed save would leave the database pointing at a deleted image.
      if (originalArtwork && originalArtwork !== artworkPath) {
        try { await FileSystem.deleteAsync(originalArtwork, { idempotent: true }); } catch { /* ignore */ }
      }
      library.refreshDisplay();
      onClose();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Save failed');
    } finally {
      setSaving(false);
    }
  };

  const handleReset = async () => {
    if (!trackId) return;
    Alert.alert('Reset to original', 'Discard all edits and artwork?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Reset', style: 'destructive', onPress: async () => {
          try {
            await deleteTrackOverride(trackId);
            for (const file of [artworkPath, originalArtwork]) {
              if (!file) continue;
              try { await FileSystem.deleteAsync(file, { idempotent: true }); } catch { /* ignore */ }
            }
            library.refreshDisplay();
            onClose();
          } catch (resetError) {
            setError(resetError instanceof Error ? resetError.message : 'Reset failed');
          }
        },
      },
    ]);
  };

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose} transparent>
      <View style={styles.backdrop}>
        <View style={styles.sheet}>
          <ScrollView
            contentContainerStyle={styles.content}
            keyboardShouldPersistTaps="handled"
            showsVerticalScrollIndicator={false}
          >
            <View style={styles.header}>
              <AppText variant="heading" color={palette.ink}>Edit song</AppText>
              <IconButton name="x" label="Close edit sheet" iconSize={20} size={48} onPress={onClose} />
            </View>
            {loading ? (
              <AppText variant="body" color={palette.inkMuted}>Loading…</AppText>
            ) : (
              <>
                <Field styles={styles} palette={palette} dark={dark} label="Title" value={title} onChange={setTitle} placeholder={original.title} />
                <Field styles={styles} palette={palette} dark={dark} label="Artist" value={artist} onChange={setArtist} placeholder={original.artist} />
                <Field styles={styles} palette={palette} dark={dark} label="Album" value={album} onChange={setAlbum} placeholder={original.album} />
                <Field styles={styles} palette={palette} dark={dark} label="Album artist" value={albumArtist} onChange={setAlbumArtist} placeholder={original.artist} />
                <Field styles={styles} palette={palette} dark={dark} label="Genre" value={genre} onChange={setGenre} />
                <Field styles={styles} palette={palette} dark={dark} label="Year" value={year} onChange={setYear} />
                <Field styles={styles} palette={palette} dark={dark} label="Track number" value={trackNumber} onChange={setTrackNumber} />
                <View style={styles.field}>
                  <AppText variant="overline" color={palette.inkFaint}>Description</AppText>
                  <TextInput
                    value={description}
                    onChangeText={setDescription}
                    placeholder="Description"
                    placeholderTextColor={palette.inkFaint}
                    keyboardAppearance={dark ? 'dark' : 'light'}
                    multiline
                    style={[styles.input, styles.multiline]}
                  />
                </View>
                <View style={styles.artworkRow}>
                  {artworkPath ? (
                    <Image source={{ uri: artworkPath }} style={styles.artworkPreview} />
                  ) : (
                    <View style={[styles.artworkPreview, { backgroundColor: palette.surfaceMuted }]} />
                  )}
                  <View style={styles.artworkActions}>
                    <Pressable accessibilityRole="button" onPress={handlePick} style={styles.button}>
                      <AppText variant="label" color={palette.accentInk}>Choose image</AppText>
                    </Pressable>
                    {artworkPath ? (
                      <Pressable accessibilityRole="button" onPress={() => setArtworkPath(null)} style={styles.buttonSecondary}>
                        <AppText variant="label" color={palette.ink}>Remove</AppText>
                      </Pressable>
                    ) : null}
                  </View>
                </View>
                {error ? <AppText variant="micro" color={palette.danger}>{error}</AppText> : null}
                <View style={styles.actions}>
                  <Pressable accessibilityRole="button" onPress={handleReset} style={styles.buttonSecondary}>
                    <AppText variant="label" color={palette.danger}>Reset to original</AppText>
                  </Pressable>
                  <Pressable accessibilityRole="button" onPress={handleSave} disabled={saving} style={styles.button}>
                    <AppText variant="label" color={palette.accentInk}>{saving ? 'Saving…' : 'Save'}</AppText>
                  </Pressable>
                </View>
              </>
            )}
          </ScrollView>
        </View>
      </View>
    </Modal>
  );
}

function Field({
  label,
  value,
  onChange,
  placeholder,
  styles,
  palette,
  dark,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  styles: ReturnType<typeof createStyles>;
  palette: AppPalette;
  dark: boolean;
}) {
  return (
    <View style={styles.field}>
      <AppText variant="overline" color={palette.inkFaint}>{label}</AppText>
      <TextInput
        value={value}
        onChangeText={onChange}
        placeholder={placeholder ?? label}
        placeholderTextColor={palette.inkFaint}
        keyboardAppearance={dark ? 'dark' : 'light'}
        style={styles.input}
      />
    </View>
  );
}

const createStyles = ({ palette, glass }: AppTheme) => ({
  backdrop: {
    flex: 1,
    backgroundColor: palette.scrim,
    justifyContent: 'flex-end' as const,
  },
  sheet: {
    backgroundColor: glass.tintStrong,
    borderTopLeftRadius: radii.xl,
    borderTopRightRadius: radii.xl,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeStrong,
    padding: spacing.lg,
    maxHeight: '90%' as const,
  },
  content: { gap: spacing.md, paddingBottom: spacing.xl },
  header: {
    flexDirection: 'row' as const,
    justifyContent: 'space-between' as const,
    alignItems: 'center' as const,
  },
  field: { gap: 4 },
  input: {
    backgroundColor: glass.fieldTint,
    borderRadius: radii.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    color: palette.ink,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeSoft,
  },
  multiline: { minHeight: 80, textAlignVertical: 'top' as const },
  artworkRow: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.md,
  },
  artworkPreview: { width: 80, height: 80, borderRadius: radii.lg },
  artworkActions: { gap: spacing.sm },
  button: {
    alignSelf: 'flex-start' as const,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    borderRadius: radii.pill,
    backgroundColor: palette.accent,
  },
  buttonSecondary: {
    alignSelf: 'flex-start' as const,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    borderRadius: radii.pill,
    backgroundColor: glass.tintSoft,
    borderWidth: 1,
    borderColor: glass.edgeSoft,
  },
  actions: {
    flexDirection: 'row' as const,
    justifyContent: 'space-between' as const,
    gap: spacing.md,
    marginTop: spacing.sm,
  },
});
