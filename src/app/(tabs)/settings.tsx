import Feather from '@expo/vector-icons/Feather';
import { type ComponentProps } from 'react';
import { Platform, Pressable, ScrollView, StyleSheet, Switch, View } from 'react-native';
import Animated, { FadeIn } from 'react-native-reanimated';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';

import Constants from 'expo-constants';

import { AppText } from '../../components/AppText';
import { MiniPlayer } from '../../components/MiniPlayer';
import { useMusicLibrary } from '../../storage/MusicLibraryContext';
import { usePreferences } from '../../storage/PreferencesContext';
import { colors, layout, radii, spacing, useTheme, PRESET_SWATCHES } from '../../theme';

const MODES: { value: 'light' | 'dark' | 'auto'; label: string }[] = [
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
  { value: 'auto', label: 'Auto' },
];
const STYLES: { value: 'classic' | 'tonal-spot' | 'expressive' | 'vibrant' | 'neutral'; label: string }[] = [
  { value: 'classic', label: 'Classic' },
  { value: 'tonal-spot', label: 'Tonal spot' },
  { value: 'expressive', label: 'Expressive' },
  { value: 'vibrant', label: 'Vibrant' },
  { value: 'neutral', label: 'Neutral' },
];
const MOTION: { value: 'system' | 'reduced' | 'full'; label: string }[] = [
  { value: 'system', label: 'Follow system' },
  { value: 'reduced', label: 'Reduced' },
  { value: 'full', label: 'Full' },
];

/**
 * Static OSS manifest: every dependency seeds an audible or visual surface.
 * Licences based on each project's published licence (no trackers here).
 */
const OSS_NOTICES: string[] = [
  'App font Atkinson Hyperlegible — SIL Open Font License',
  'App font Bricolage Grotesque — SIL Open Font License',
  'Tab & transport icon set Feather — MIT (Cole Bemis)',
  'Palette engine @material/material-color-utilities — Apache-2.0',
  'Playback engine @rntp/player — Apache-2.0',
  'Visuals @shopify/react-native-skia — MIT',
  'Colors react-native-image-colors — MIT',
  'Motion react-native-reanimated — MIT',
  'Storage react-native-mmkv, expo-sqlite — MIT',
  'Navigation expo-router, react-native-screens — MIT',
  'Platform Expo SDK, react-native, react — MIT',
];

type FeatherName = ComponentProps<typeof Feather>['name'];

type RowProps = {
  icon: FeatherName;
  label: string;
  hint?: string;
  control?: 'switch' | 'none';
  switchValue?: boolean;
  onSwitchChange?: (v: boolean) => void;
  onPress?: () => void;
};

function SettingRow({ icon: rowIcon, label, hint, control = 'none', switchValue, onSwitchChange, onPress }: RowProps) {
  const content = (
    <>
      <View style={styles.rowIcon}>
        <Feather name={rowIcon} size={20} color={colors.accent} />
      </View>
      <View style={styles.rowText}>
        <AppText variant="label" color={colors.ink}>{label}</AppText>
        {hint ? <AppText variant="micro" color={colors.inkMuted}>{hint}</AppText> : null}
      </View>
      {control === 'switch' ? (
        <View
          pointerEvents="none"
          accessibilityElementsHidden
          importantForAccessibility="no-hide-descendants"
        >
          <Switch
            value={switchValue}
            onValueChange={onSwitchChange}
            trackColor={{ false: colors.surfaceMuted, true: colors.accentStrong }}
            thumbColor={colors.ink}
          />
        </View>
      ) : (
        <Feather name="chevron-right" size={18} color={colors.inkFaint} />
      )}
    </>
  );
  const isSwitch = control === 'switch';
  const handlePress =
    onPress ?? (isSwitch && onSwitchChange ? () => onSwitchChange(!switchValue) : undefined);
  if (!handlePress) {
    return <View style={styles.row}>{content}</View>;
  }
  return (
    <Pressable
      accessibilityRole={isSwitch ? 'switch' : 'button'}
      accessibilityLabel={label}
      accessibilityState={isSwitch ? { checked: !!switchValue } : undefined}
      onPress={handlePress}
      style={({ pressed }) => [styles.row, pressed && styles.rowPressed]}
    >
      {content}
    </Pressable>
  );
}

function ChipRow<T extends string>({
  items,
  value,
  onSelect,
}: {
  items: readonly { value: T; label: string }[];
  value: T;
  onSelect: (v: T) => void;
}) {
  return (
    <View style={styles.chipRowWrap}>
      {items.map((item) => (
        <Pressable
          key={item.value}
          accessibilityRole="button"
          accessibilityState={{ selected: item.value === value }}
          onPress={() => onSelect(item.value)}
          style={[
            styles.chip,
            item.value === value && styles.chipActive,
          ]}
        >
          <AppText variant="label" color={item.value === value ? colors.accentInk : colors.ink}>
            {item.label}
          </AppText>
        </Pressable>
      ))}
    </View>
  );
}

export default function SettingsScreen() {
  const library = useMusicLibrary();
  const { preferences, setHaptics, tapFeedback } = usePreferences();
  const theme = useTheme();
  const androidRelease = (Platform.constants as { Release?: string }).Release;
  const osVersion = `${Platform.OS === 'android' ? 'Android' : Platform.OS} ${
    androidRelease ?? Platform.Version
  }`;

  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <Animated.View entering={FadeIn.duration(240)}>
          <View style={styles.headerRow}>
            <AppText variant="display" color={colors.ink}>Settings</AppText>
          </View>
        </Animated.View>

        <View style={styles.card}>
          <View style={styles.row}>
            <View style={styles.rowIcon}>
              <Feather name="folder" size={20} color={colors.accent} />
            </View>
            <View style={styles.rowText}>
              <AppText variant="label" color={colors.ink}>Library</AppText>
              <AppText variant="micro" color={colors.inkMuted}>
                {library.scanning
                  ? 'Scanning your device…'
                  : `${library.tracks.length} ${library.tracks.length === 1 ? 'track' : 'tracks'} indexed`}
              </AppText>
              {!library.scanning && library.scanError ? (
                <AppText variant="micro" color={colors.danger} numberOfLines={2}>
                  {library.scanError}
                </AppText>
              ) : null}
            </View>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={library.permission === 'granted' ? 'Scan library' : 'Grant library access'}
              onPress={() => {
                tapFeedback('selection');
                if (library.permission === 'granted') {
                  void library.scan();
                } else {
                  void library.requestAccess();
                }
              }}
              style={({ pressed }) => [styles.pillButton, { opacity: pressed ? 0.75 : 1 }]}
            >
              <AppText variant="label" color={colors.accentInk}>
                {library.permission === 'granted' ? 'Scan' : 'Grant'}
              </AppText>
            </Pressable>
          </View>
          <View style={styles.divider} />
          <SettingRow
            icon="radio"
            label="Haptics"
            hint="Feedback on taps"
            control="switch"
            switchValue={preferences.haptics}
            onSwitchChange={(value) => {
              tapFeedback('selection');
              setHaptics(value);
            }}
          />
        </View>

        <View style={styles.card}>
          <AppText variant="label" color={colors.ink}>Appearance</AppText>
          <ChipRow
            items={MODES}
            value={theme.mode}
            onSelect={(m) => { tapFeedback('selection'); theme.setMode(m); }}
          />
          <AppText variant="micro" color={colors.inkFaint}>Palette style</AppText>
          <ChipRow
            items={STYLES}
            value={theme.paletteStyle}
            onSelect={(s) => { tapFeedback('selection'); theme.setPaletteStyle(s); }}
          />
          <AppText variant="micro" color={colors.inkFaint}>Accent swatch</AppText>
          <View style={styles.chipRowWrap}>
            {PRESET_SWATCHES.map((swatch) => (
              <Pressable
                key={swatch}
                accessibilityRole="button"
                accessibilityLabel={`Accent ${swatch}`}
                onPress={() => { tapFeedback('selection'); theme.setSeed(swatch); }}
                style={[styles.swatch, { backgroundColor: swatch }, theme.seed === swatch && styles.swatchActive]}
              />
            ))}
          </View>
          <View style={styles.divider} />
          <SettingRow
            icon="sliders"
            label="Backdrop"
            hint={`Show artwork glow · intensity ${theme.backdropIntensity}`}
            control="switch"
            switchValue={theme.backdropEnabled}
            onSwitchChange={(v) => { tapFeedback('selection'); theme.setBackdropEnabled(v); }}
          />
          <View style={styles.chipRowWrap}>
            {[0, 25, 50, 60, 75, 100].map((v) => (
              <Pressable
                key={v}
                accessibilityRole="button"
                accessibilityLabel={`Backdrop intensity ${v}`}
                onPress={() => { tapFeedback('selection'); theme.setBackdropIntensity(v); }}
                style={[styles.chip, theme.backdropIntensity === v && styles.chipActive]}
              >
                <AppText variant="label" color={theme.backdropIntensity === v ? colors.accentInk : colors.ink}>{v}</AppText>
              </Pressable>
            ))}
          </View>
        </View>

        <View style={styles.card}>
          <AppText variant="label" color={colors.ink}>Motion</AppText>
          <ChipRow
            items={MOTION}
            value={theme.motionMode}
            onSelect={(m) => { tapFeedback('selection'); theme.setMotionMode(m); }}
          />
          <AppText variant="micro" color={colors.inkFaint}>
            Reduced keeps fades and drops slide-springs across tabs and cards.
          </AppText>
        </View>

        <View style={styles.card}>
          <View style={styles.aboutRow}>
            <View style={styles.mark}>
              <AppText variant="display" color={colors.accentInk}>S</AppText>
            </View>
            <View style={styles.rowText}>
              <AppText variant="heading" color={colors.ink}>About Snoozy</AppText>
              <AppText variant="micro" color={colors.inkMuted} style={styles.aboutCopy}>
                A minimal local music player for your library, your way.
              </AppText>
            </View>
          </View>
          <AppText variant="micro" color={colors.inkFaint}>
            Version {Constants.expoConfig?.version ?? '1.8.0'}
            {Constants.expoConfig?.android?.versionCode ? ` (${Constants.expoConfig.android.versionCode})` : ''}
            {' '}· {osVersion} · arm64
          </AppText>
          <View style={styles.divider} />
          <SettingRow
            icon="alert-triangle"
            label="Error log"
            hint="Diagnostics for anything that went wrong"
            onPress={() => router.push('/error-log')}
          />
          <AppText variant="micro" color={colors.inkFaint}>Open-source components:</AppText>
          <View style={styles.ossList}>
            {OSS_NOTICES.map((notice) => (
              <AppText key={notice} variant="micro" color={colors.inkMuted}>
                {notice}
              </AppText>
            ))}
          </View>
        </View>
      </ScrollView>
      <MiniPlayer />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  content: { padding: spacing.lg, gap: spacing.lg, paddingBottom: layout.tabBarSpace },
  headerRow: { gap: spacing.xs },
  card: {
    gap: spacing.md,
    padding: spacing.md,
    borderRadius: radii.xl,
    backgroundColor: colors.surfaceRaised,
    borderWidth: 1,
    borderColor: colors.border,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    minHeight: 52,
    borderRadius: radii.md,
  },
  rowPressed: { opacity: 0.75, transform: [{ scale: 0.99 }] },
  rowIcon: {
    width: 36,
    height: 36,
    borderRadius: radii.sm,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.surfaceMuted,
    borderWidth: 1,
    borderColor: colors.border,
  },
  rowText: { flex: 1, gap: 2 },
  divider: { height: 1, backgroundColor: colors.border },
  pillButton: {
    minHeight: 48,
    justifyContent: 'center',
    paddingHorizontal: spacing.xl,
    borderRadius: radii.pill,
    backgroundColor: colors.accent,
  },
  chipRowWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  chip: {
    minWidth: 48,
    minHeight: 48,
    justifyContent: 'center',
    paddingHorizontal: spacing.md,
    borderRadius: radii.pill,
    backgroundColor: colors.surfaceMuted,
    borderWidth: 1,
    borderColor: colors.border,
  },
  chipActive: {
    backgroundColor: colors.accent,
    borderColor: colors.accent,
  },
  swatch: {
    width: 48,
    height: 48,
    borderRadius: 24,
    borderWidth: 2,
    borderColor: colors.border,
  },
  swatchActive: {
    borderColor: colors.ink,
  },
  aboutRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  mark: {
    width: 52,
    height: 52,
    borderRadius: radii.md,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.accent,
  },
  aboutCopy: { flex: 1 },
  ossList: { gap: spacing.xxs, paddingLeft: spacing.xs },
});
