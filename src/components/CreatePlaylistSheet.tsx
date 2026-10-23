import Feather from '@expo/vector-icons/Feather';
import { useState } from 'react';
import {
  KeyboardAvoidingView,
  Modal,
  Platform,
  Pressable,
  StyleSheet,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { colors, fonts, glass, radii, spacing } from '../theme';
import { AppText } from './AppText';
import { SheetPanel } from './SheetPanel';

type CreatePlaylistSheetProps = {
  visible: boolean;
  onClose: () => void;
  onCreate: (name: string) => void;
};

export function CreatePlaylistSheet({
  visible,
  onClose,
  onCreate,
}: CreatePlaylistSheetProps) {
  const insets = useSafeAreaInsets();
  const [name, setName] = useState('');

  const close = () => {
    setName('');
    onClose();
  };

  const create = () => {
    const trimmed = name.trim();
    if (!trimmed) return;
    onCreate(trimmed);
    close();
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
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={styles.backdrop}
      >
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Close new playlist"
          onPress={close}
          style={StyleSheet.absoluteFill}
        />
        <SheetPanel style={[styles.sheet, { paddingBottom: insets.bottom + spacing.xl }]}>
          <View style={styles.handle} />
          <View style={styles.headingRow}>
            <View style={styles.headingCopy}>
              <AppText variant="heading" style={styles.title}>New playlist</AppText>
            </View>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Close"
              hitSlop={10}
              onPress={close}
              style={styles.close}
            >
              <Feather name="x" size={24} color={colors.inkMuted} />
            </Pressable>
          </View>
          <TextInput
            value={name}
            onChangeText={setName}
            placeholder="Playlist name"
            placeholderTextColor={colors.inkFaint}
            style={styles.input}
            autoFocus
            returnKeyType="done"
            onSubmitEditing={create}
          />
          <View style={styles.actions}>
            <Pressable
              accessibilityRole="button"
              onPress={close}
              style={({ pressed }) => [styles.cancel, { opacity: pressed ? 0.7 : 1 }]}
            >
              <AppText variant="label" color={colors.inkMuted}>Cancel</AppText>
            </Pressable>
            <Pressable
              accessibilityRole="button"
              onPress={create}
              disabled={!name.trim()}
              style={({ pressed }) => [
                styles.create,
                (!name.trim() || pressed) && { opacity: 0.6 },
              ]}
            >
              <AppText variant="label" color={colors.accentInk}>Create</AppText>
            </Pressable>
          </View>
        </SheetPanel>
      </KeyboardAvoidingView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: colors.scrim,
    justifyContent: 'flex-end',
  },
  sheet: {
    backgroundColor: glass.tintStrong,
    borderTopLeftRadius: radii.xxl,
    borderTopRightRadius: radii.xxl,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeStrong,
    paddingHorizontal: spacing.xxl,
    paddingTop: spacing.sm,
  },
  handle: {
    alignSelf: 'center',
    width: 38,
    height: 4,
    borderRadius: 2,
    backgroundColor: colors.surfaceMuted,
    marginBottom: spacing.xl,
  },
  headingRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
  },
  headingCopy: { gap: spacing.xs },
  title: { marginTop: spacing.xs },
  close: {
    width: 40,
    height: 40,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: -4,
  },
  input: {
    marginTop: spacing.xl,
    height: 52,
    borderRadius: radii.md,
    paddingHorizontal: spacing.lg,
    color: colors.ink,
    fontFamily: fonts.body,
    fontSize: 16,
    backgroundColor: glass.fieldTint,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeSoft,
  },
  actions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    alignItems: 'center',
    gap: spacing.lg,
    marginTop: spacing.xl,
  },
  cancel: {
    minHeight: 48,
    justifyContent: 'center',
    paddingHorizontal: spacing.md,
  },
  create: {
    minHeight: 48,
    justifyContent: 'center',
    paddingHorizontal: spacing.xl,
    borderRadius: radii.pill,
    backgroundColor: colors.accent,
  },
});
