import { Modal, Pressable, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { AppText } from './AppText';
import { GlassSurface } from './glass/GlassSurface';
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

/**
 * Cupertino Action Sheet (`UIAlertController` style):
 * - Floating translucent 16pt squircle group for title, message, and primary/destructive actions
 * - Separate floating 16pt squircle pill button at the bottom for Cancel
 * - 0.5pt hairline separators and quick opacity compression on tap
 */
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

  const isCancel = (action: AppDialogAction, index: number) =>
    index === actions.length - 1 &&
    action.tone !== 'danger' &&
    action.label.toLowerCase() === 'cancel';

  const cancelAction = actions.find((a, idx) => isCancel(a, idx)) ?? null;
  const primaryActions = cancelAction
    ? actions.slice(0, actions.length - 1)
    : actions;

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
        onDismiss={onClose}
        showGrabber={false}
        style={[
          styles.sheetWrap,
          { paddingBottom: Math.max(insets.bottom, spacing.lg) + spacing.sm },
        ]}
      >
        <GlassSurface variant="panel" radius={radii.lg} style={styles.groupCard}>
          <View style={styles.copy}>
            <AppText variant="label" color={palette.inkMuted} style={styles.centeredText} numberOfLines={2}>
              {title}
            </AppText>
            {message ? (
              <AppText variant="micro" color={palette.inkFaint} style={styles.centeredText}>
                {message}
              </AppText>
            ) : null}
          </View>
          <View style={styles.actions}>
            {primaryActions.map((action, index) => (
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
                  pressed && styles.actionPressed,
                ]}
              >
                <AppText
                  variant="body"
                  color={action.tone === 'danger' ? palette.danger : palette.accent}
                  style={styles.actionLabel}
                >
                  {action.label}
                </AppText>
              </Pressable>
            ))}
          </View>
        </GlassSurface>

        {cancelAction ? (
          <GlassSurface variant="panel" radius={radii.lg} style={styles.cancelCard}>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={cancelAction.label}
              onPress={() => {
                onClose();
                cancelAction.onPress();
              }}
              style={({ pressed }) => [
                styles.action,
                pressed && styles.actionPressed,
              ]}
            >
              <AppText variant="bodyBold" color={palette.accent} style={styles.actionLabel}>
                {cancelAction.label}
              </AppText>
            </Pressable>
          </GlassSurface>
        ) : null}
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
  sheetWrap: {
    paddingHorizontal: spacing.md,
    gap: spacing.sm,
  },
  groupCard: {
    backgroundColor: glass.tintStrong,
    borderColor: glass.edgeStrong,
    overflow: 'hidden' as const,
  },
  cancelCard: {
    backgroundColor: glass.tintStrong,
    borderColor: glass.edgeStrong,
    overflow: 'hidden' as const,
  },
  copy: {
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    gap: 4,
    alignItems: 'center' as const,
  },
  centeredText: {
    textAlign: 'center' as const,
  },
  actions: {
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: glass.edge,
  },
  action: {
    minHeight: 54,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
    paddingHorizontal: spacing.lg,
  },
  actionDivider: {
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: glass.edge,
  },
  actionPressed: {
    opacity: 0.56,
    backgroundColor: glass.tintSoft,
  },
  actionLabel: {
    textAlign: 'center' as const,
  },
});
