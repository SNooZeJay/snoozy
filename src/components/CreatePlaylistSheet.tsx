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

import {
  fonts,
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  type AppTheme,
} from '../theme';
import { AppText } from './AppText';
import { SheetPanel } from './SheetPanel';

type CreatePlaylistSheetProps = {
  visible: boolean;
  onClose: () => void;
  onCreate: (name: string) => void;
  title?: string;
  submitLabel?: string;
  initialName?: string;
};

export function CreatePlaylistSheet({
  visible,
  onClose,
  onCreate,
  title = 'New playlist',
  submitLabel = 'Create',
  initialName = '',
}: CreatePlaylistSheetProps) {
  const { palette, dark } = useTheme();
  const styles = useThemedStyles(createStyles);
  const insets = useSafeAreaInsets();
  const [name, setName] = useState(initialName);

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
      onShow={() => setName(initialName)}
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
        <SheetPanel
          onDismiss={close}
          style={[styles.sheet, { paddingBottom: insets.bottom + spacing.xl }]}
        >
          <View style={styles.headingRow}>
            <View style={styles.headingCopy}>
              <AppText variant="heading" color={palette.ink} style={styles.title}>{title}</AppText>
            </View>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Close"
              hitSlop={10}
              onPress={close}
              style={styles.close}
            >
              <Feather name="x" size={24} color={palette.inkMuted} />
            </Pressable>
          </View>
          <TextInput
            value={name}
            onChangeText={setName}
            placeholder="Playlist name"
            placeholderTextColor={palette.inkFaint}
            keyboardAppearance={dark ? 'dark' : 'light'}
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
              <AppText variant="label" color={palette.inkMuted}>Cancel</AppText>
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
              <AppText variant="label" color={palette.accentInk}>{submitLabel}</AppText>
            </Pressable>
          </View>
        </SheetPanel>
      </KeyboardAvoidingView>
    </Modal>
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
    borderTopLeftRadius: radii.xxl,
    borderTopRightRadius: radii.xxl,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeStrong,
    paddingHorizontal: spacing.xxl,
    paddingTop: spacing.sm,
  },
  handle: {
    alignSelf: 'center' as const,
    width: 38,
    height: 4,
    borderRadius: 2,
    backgroundColor: palette.surfaceMuted,
    marginBottom: spacing.xl,
  },
  headingRow: {
    flexDirection: 'row' as const,
    justifyContent: 'space-between' as const,
    alignItems: 'flex-start' as const,
  },
  headingCopy: { gap: spacing.xs },
  title: { marginTop: spacing.xs },
  close: {
    width: 40,
    height: 40,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
    marginTop: -4,
  },
  input: {
    marginTop: spacing.xl,
    height: 52,
    borderRadius: radii.md,
    paddingHorizontal: spacing.lg,
    color: palette.ink,
    fontFamily: fonts.body,
    fontSize: 16,
    backgroundColor: glass.fieldTint,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeSoft,
  },
  actions: {
    flexDirection: 'row' as const,
    justifyContent: 'flex-end' as const,
    alignItems: 'center' as const,
    gap: spacing.lg,
    marginTop: spacing.xl,
  },
  cancel: {
    minHeight: 48,
    justifyContent: 'center' as const,
    paddingHorizontal: spacing.md,
  },
  create: {
    minHeight: 48,
    justifyContent: 'center' as const,
    paddingHorizontal: spacing.xl,
    borderRadius: radii.pill,
    backgroundColor: palette.accent,
  },
});
