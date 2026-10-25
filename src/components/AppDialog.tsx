import { Modal, Pressable, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { AppText } from './AppText';
import { SheetPanel } from './SheetPanel';
import {
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  type AppTheme,
} from '../theme';

export type AppDialogAction = {
  label: string;
  onPress: () => void;
  tone?: 'default' | 'danger';
};

type AppDialogProps = {
  visible: boolean;
  title: string;
  message?: string;
  actions: AppDialogAction[];
  onClose: () => void;
  /** Render over the parent surface instead of opening another native modal. */
  inline?: boolean;
};

export function AppDialog({
  visible,
  title,
  message,
  actions,
  onClose,
  inline = false,
}: AppDialogProps) {
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  const insets = useSafeAreaInsets();

  if (!visible) return null;

  const content = (
    <View
      style={inline ? styles.inlineBackdrop : styles.backdrop}
      accessibilityViewIsModal
    >
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Close dialog"
        onPress={onClose}
        style={StyleSheet.absoluteFill}
      />
      <SheetPanel
        style={[
          styles.panel,
          { paddingBottom: Math.max(insets.bottom, spacing.huge) + spacing.md },
        ]}
      >
        <View style={styles.copy}>
          <AppText variant="heading" color={palette.ink} numberOfLines={2}>
            {title}
          </AppText>
          {message ? (
            <AppText variant="body" color={palette.inkMuted}>
              {message}
            </AppText>
          ) : null}
        </View>
        <View style={styles.actions}>
          {actions.map((action, index) => (
            <Pressable
              key={`${action.label}-${index}`}
              accessibilityRole="button"
              accessibilityLabel={action.label}
              onPress={() => {
                onClose();
                action.onPress();
              }}
              style={({ pressed }) => [
                styles.action,
                index > 0 && styles.actionDivider,
                action.tone === 'danger' && styles.dangerAction,
                pressed && styles.actionPressed,
              ]}
            >
              <AppText
                variant="label"
                color={action.tone === 'danger' ? palette.danger : palette.accent}
              >
                {action.label}
              </AppText>
            </Pressable>
          ))}
        </View>
      </SheetPanel>
    </View>
  );

  if (inline) return content;

  return (
    <Modal
      visible
      transparent
      animationType="fade"
      statusBarTranslucent
      navigationBarTranslucent
      onRequestClose={onClose}
    >
      {content}
    </Modal>
  );
}

const createStyles = ({ palette, glass }: AppTheme) => ({
  backdrop: {
    flex: 1,
    backgroundColor: palette.scrim,
    justifyContent: 'flex-end' as const,
  },
  inlineBackdrop: {
    position: 'absolute' as const,
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
    backgroundColor: palette.scrim,
    justifyContent: 'flex-end' as const,
    zIndex: 1000,
  },
  panel: {
    backgroundColor: palette.surface,
    borderTopLeftRadius: radii.xl,
    borderTopRightRadius: radii.xl,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeStrong,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.lg,
    gap: spacing.md,
  },
  copy: {
    gap: spacing.xs,
  },
  actions: {
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: glass.edgeSoft,
    marginHorizontal: -spacing.lg,
  },
  action: {
    minHeight: 52,
    justifyContent: 'center' as const,
    paddingHorizontal: spacing.lg,
  },
  actionDivider: {
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: glass.edgeSoft,
  },
  actionPressed: {
    opacity: 0.68,
  },
  dangerAction: {
    backgroundColor: palette.dangerSoft,
  },
});
