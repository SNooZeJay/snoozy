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
import { colors, radii, spacing } from '../theme';
import { getTrackOverride, upsertTrackOverride, deleteTrackOverride } from '../storage/metadata';

type Props = {
  visible: boolean;
  onClose: () => void;
  trackId: string | null;
  original: { title: string; artist: string; album: string };
};

const MAX_BYTES = 20 * 1024 * 1024;

export function SongEditSheet({ visible, onClose, trackId, original }: Props) {
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
      void getTrackOverride(trackId).then((o) => {
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
      });
    }, 0);
    return () => {
      cancelled = true;
      clearTimeout(handle);
    };
  }, [visible, trackId]);

  const validate = (): string | null => {
    if (title.trim() === '' && original.title.trim() === '') return 'Title cannot be empty';
    if (title.trim() !== '' && title.trim().length === 0) return 'Title cannot be empty';
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
    const ext = asset.uri.split('.').pop()?.toLowerCase() || 'jpg';
    if (!['jpg', 'jpeg', 'png', 'webp'].includes(ext)) {
      setError('Unsupported image type');
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
      // remove old artwork file if replaced
      if (originalArtwork && originalArtwork !== artworkPath) {
        try { await FileSystem.deleteAsync(originalArtwork, { idempotent: true }); } catch { /* ignore */ }
      }
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
          if (artworkPath) {
            try { await FileSystem.deleteAsync(artworkPath, { idempotent: true }); } catch { /* ignore */ }
          }
          await deleteTrackOverride(trackId);
          library.refreshDisplay();
          onClose();
        },
      },
    ]);
  };

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose} transparent>
      <View style={styles.backdrop}>
        <View style={styles.sheet}>
          <ScrollView contentContainerStyle={styles.content}>
            <View style={styles.header}>
              <AppText variant="heading" color={colors.ink}>Edit song</AppText>
              <IconButton name="x" label="Close edit sheet" iconSize={20} size={48} onPress={onClose} />
            </View>
            {loading ? (
              <AppText variant="body" color={colors.inkMuted}>Loading…</AppText>
            ) : (
              <>
                <Field label="Title" value={title} onChange={setTitle} placeholder={original.title} />
                <Field label="Artist" value={artist} onChange={setArtist} placeholder={original.artist} />
                <Field label="Album" value={album} onChange={setAlbum} placeholder={original.album} />
                <Field label="Album artist" value={albumArtist} onChange={setAlbumArtist} placeholder={original.artist} />
                <Field label="Genre" value={genre} onChange={setGenre} />
                <Field label="Year" value={year} onChange={setYear} />
                <Field label="Track number" value={trackNumber} onChange={setTrackNumber} />
                <View style={styles.field}>
                  <AppText variant="overline" color={colors.inkFaint}>Description</AppText>
                  <TextInput
                    value={description}
                    onChangeText={setDescription}
                    placeholder="Description"
                    placeholderTextColor={colors.inkFaint}
                    multiline
                    style={[styles.input, styles.multiline]}
                  />
                </View>
                <View style={styles.artworkRow}>
                  {artworkPath ? (
                    <Image source={{ uri: artworkPath }} style={styles.artworkPreview} />
                  ) : (
                    <View style={[styles.artworkPreview, { backgroundColor: colors.surfaceMuted }]} />
                  )}
                  <View style={styles.artworkActions}>
                    <Pressable accessibilityRole="button" onPress={handlePick} style={styles.button}>
                      <AppText variant="label" color={colors.accentInk}>Choose image</AppText>
                    </Pressable>
                    {artworkPath ? (
                      <Pressable accessibilityRole="button" onPress={() => setArtworkPath(null)} style={styles.buttonSecondary}>
                        <AppText variant="label" color={colors.ink}>Remove</AppText>
                      </Pressable>
                    ) : null}
                  </View>
                </View>
                {error ? <AppText variant="micro" color={colors.danger}>{error}</AppText> : null}
                <View style={styles.actions}>
                  <Pressable accessibilityRole="button" onPress={handleReset} style={styles.buttonSecondary}>
                    <AppText variant="label" color={colors.danger}>Reset to original</AppText>
                  </Pressable>
                  <Pressable accessibilityRole="button" onPress={handleSave} disabled={saving} style={styles.button}>
                    <AppText variant="label" color={colors.accentInk}>{saving ? 'Saving…' : 'Save'}</AppText>
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

function Field({ label, value, onChange, placeholder }: { label: string; value: string; onChange: (v: string) => void; placeholder?: string }) {
  return (
    <View style={styles.field}>
      <AppText variant="overline" color={colors.inkFaint}>{label}</AppText>
      <TextInput
        value={value}
        onChangeText={onChange}
        placeholder={placeholder ?? label}
        placeholderTextColor={colors.inkFaint}
        style={styles.input}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  backdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.6)', justifyContent: 'flex-end' },
  sheet: {
    backgroundColor: colors.surfaceRaised,
    borderTopLeftRadius: radii.xl,
    borderTopRightRadius: radii.xl,
    padding: spacing.lg,
    maxHeight: '90%',
  },
  content: { gap: spacing.md, paddingBottom: spacing.xl },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  field: { gap: 4 },
  input: {
    backgroundColor: colors.surfaceMuted,
    borderRadius: radii.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    color: colors.ink,
    borderWidth: 1,
    borderColor: colors.border,
  },
  multiline: { minHeight: 80, textAlignVertical: 'top' },
  artworkRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  artworkPreview: { width: 80, height: 80, borderRadius: radii.lg },
  artworkActions: { gap: spacing.sm },
  button: {
    alignSelf: 'flex-start',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    borderRadius: radii.pill,
    backgroundColor: colors.accent,
  },
  buttonSecondary: {
    alignSelf: 'flex-start',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    borderRadius: radii.pill,
    backgroundColor: colors.surfaceMuted,
    borderWidth: 1,
    borderColor: colors.border,
  },
  actions: { flexDirection: 'row', justifyContent: 'space-between', gap: spacing.md, marginTop: spacing.sm },
});