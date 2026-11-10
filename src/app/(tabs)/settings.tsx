import Feather from '@expo/vector-icons/Feather';
import Constants from 'expo-constants';
import { router } from 'expo-router';
import type { ComponentProps, ReactNode } from 'react';
import {
  Platform,
  Pressable,
  StyleSheet,
  Switch,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Animated from 'react-native-reanimated';

import { AppText } from '../../components/AppText';
import { CollapsedBar, useCollapsingScroll } from '../../components/CollapsingHeader';
import { ListGroup } from '../../components/ListGroup';
import { ListRow } from '../../components/ListRow';
import { ScreenHeader } from '../../components/ScreenHeader';
import { SectionHeader } from '../../components/SectionHeader';
import { SnoozyBrandIcon } from '../../components/SnoozyBrandIcon';
import { useMusicLibrary } from '../../storage/MusicLibraryContext';
import { usePreferences } from '../../storage/PreferencesContext';
import {
  PRESET_SWATCHES,
  layout,
  radii,
  spacing,
  useTheme,
  useThemedStyles,
  type AppTheme,
} from '../../theme';

const MODES: { value: 'light' | 'dark' | 'auto'; label: string }[] = [
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
  { value: 'auto', label: 'Auto' },
];
const MOTION: { value: 'system' | 'reduced' | 'full'; label: string }[] = [
  { value: 'system', label: 'Follow system' },
  { value: 'reduced', label: 'Reduced' },
  { value: 'full', label: 'Full' },
];

const SWATCH_NAMES: Record<(typeof PRESET_SWATCHES)[number], string> = {
  '#10B981': 'Emerald',
  '#FF375F': 'Rose',
  '#0A84FF': 'Blue',
  '#BF5AF2': 'Violet',
  '#FF9F0A': 'Amber',
};

/**
 * Static OSS manifest: the main open-source projects behind the app.
 * Licences based on each project's published licence (no trackers here).
 */
const OSS_NOTICES: string[] = [
  'App fonts Atkinson Hyperlegible and Bricolage Grotesque (SIL Open Font License)',
  'Icons Feather (MIT)',
  'Palette engine @material/material-color-utilities (Apache-2.0)',
  'Playback engine @rntp/player (Apache-2.0)',
  'Interaction motion ported from Glasmio (Apache-2.0)',
  'Visuals @shopify/react-native-skia and expo-blur (MIT)',
  'Artwork colors react-native-image-colors (MIT)',
  'Motion react-native-reanimated (MIT)',
  'Storage react-native-mmkv and expo-sqlite (MIT)',
  'Navigation expo-router and react-native-screens (MIT)',
  'Platform Expo SDK, React Native, and React (MIT)',
];

type FeatherName = ComponentProps<typeof Feather>['name'];

function RowIcon({ name }: { name: FeatherName }) {
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  return (
    <View style={styles.rowIcon}>
      <Feather name={name} size={20} color={palette.accent} />
    </View>
  );
}

function SwitchRow({
  icon,
  label,
  hint,
  value,
  onChange,
}: {
  icon: FeatherName;
  label: string;
  hint: string;
  value: boolean;
  onChange: (value: boolean) => void;
}) {
  const { palette } = useTheme();

  return (
    <ListRow
      leading={<RowIcon name={icon} />}
      title={label}
      subtitle={hint}
      trailing={(
        <View
          pointerEvents="none"
          accessibilityElementsHidden
          importantForAccessibility="no-hide-descendants"
        >
          <Switch
            value={value}
            onValueChange={onChange}
            trackColor={{ false: palette.surfaceMuted, true: palette.iosGreen }}
            thumbColor={palette.white}
            ios_backgroundColor={palette.surfaceMuted}
          />
        </View>
      )}
      onPress={() => onChange(!value)}
      accessibilityRole="switch"
      accessibilityLabel={label}
      accessibilityState={{ checked: value }}
    />
  );
}

function LibraryRow() {
  const library = useMusicLibrary();
  const { tapFeedback } = usePreferences();
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  const scanning = library.scanning;
  const scanError = !scanning ? library.scanError : null;
  const countLabel = `${library.tracks.length} ${library.tracks.length === 1 ? 'track' : 'tracks'} indexed`;
  const hint = scanning ? 'Scanning your device…' : scanError ?? countLabel;
  const canGrant = library.permission !== 'granted';

  return (
    <ListRow
      leading={<RowIcon name="folder" />}
      title="Library"
      subtitle={hint}
      subtitleColor={scanError ? palette.danger : undefined}
      trailing={(
        <View style={styles.pillButton}>
          <AppText variant="label" color={palette.accentInk}>
            {canGrant ? 'Grant' : 'Scan'}
          </AppText>
        </View>
      )}
      onPress={() => {
        tapFeedback('selection');
        if (canGrant) {
          void library.requestAccess();
        } else {
          void library.scan();
        }
      }}
      accessibilityLabel={canGrant ? 'Grant library access' : 'Scan library'}
      accessibilityHint={scanError ?? undefined}
    />
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
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);

  return (
    <View style={styles.chipRowWrap}>
      {items.map((item) => {
        const selected = item.value === value;
        return (
          <Pressable
            key={item.value}
            accessibilityRole="button"
            accessibilityState={{ selected }}
            onPress={() => onSelect(item.value)}
            style={({ pressed }) => [
              styles.chip,
              selected && styles.chipActive,
              pressed && { opacity: 0.72 },
            ]}
          >
            <AppText variant="label" color={selected ? palette.accentInk : palette.ink}>
              {item.label}
            </AppText>
          </Pressable>
        );
      })}
    </View>
  );
}

function SettingField({ label, children }: { label: string; children: ReactNode }) {
  const { palette } = useTheme();
  const styles = useThemedStyles(createStyles);
  return (
    <View style={styles.field}>
      <AppText variant="micro" color={palette.inkFaint}>
        {label}
      </AppText>
      {children}
    </View>
  );
}

export default function SettingsScreen() {
  const { preferences, setHaptics, tapFeedback } = usePreferences();
  const theme = useTheme();
  const { palette } = theme;
  const styles = useThemedStyles(createStyles);
  const { scrollY, onScroll } = useCollapsingScroll();
  const androidRelease = (Platform.constants as { Release?: string }).Release;
  const osVersion = `${Platform.OS === 'android' ? 'Android' : Platform.OS} ${
    androidRelease ?? Platform.Version
  }`;
  const version = Constants.expoConfig?.version ?? '2.3.0';
  const build = Constants.expoConfig?.android?.versionCode ?? 13;

  return (
    <SafeAreaView style={[styles.safe, { backgroundColor: palette.background }]} edges={['top']}>
      <Animated.ScrollView
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
        onScroll={onScroll}
        scrollEventThrottle={16}
      >
        <ScreenHeader
          title="Settings"
          subtitle="Theme, motion, and library"
        />

        <View style={styles.section}>
          <SectionHeader label="Library" />
          <ListGroup>
            <LibraryRow />
          </ListGroup>
        </View>

        <View style={styles.section}>
          <SectionHeader label="Appearance" />
          <ListGroup style={styles.settingsCard}>
            <SettingField label="Theme">
              <ChipRow
                items={MODES}
                value={theme.mode}
                onSelect={(mode) => {
                  tapFeedback('selection');
                  theme.setMode(mode);
                }}
              />
            </SettingField>

            <SettingField label="Accent color">
              <View style={styles.chipRowWrap}>
                {PRESET_SWATCHES.map((swatch) => {
                  const selected = theme.seed.toLowerCase() === swatch.toLowerCase();
                  return (
                    <Pressable
                      key={swatch}
                      accessibilityRole="button"
                      accessibilityLabel={`${SWATCH_NAMES[swatch]} accent`}
                      accessibilityState={{ selected }}
                      onPress={() => {
                        tapFeedback('selection');
                        theme.setSeed(swatch);
                      }}
                      style={[
                        styles.swatch,
                        { backgroundColor: swatch },
                        selected && styles.swatchActive,
                      ]}
                    />
                  );
                })}
              </View>
            </SettingField>

            <View style={styles.divider} />

            <SwitchRow
              icon="sliders"
              label="Backdrop glow"
              hint={`Artwork color behind playback · ${theme.backdropIntensity}%`}
              value={theme.backdropEnabled}
              onChange={(value) => {
                tapFeedback('selection');
                theme.setBackdropEnabled(value);
              }}
            />

            <SettingField label="Backdrop intensity">
              <View style={styles.chipRowWrap}>
                {[0, 25, 50, 60, 75, 100].map((value) => {
                  const selected = theme.backdropIntensity === value;
                  return (
                    <Pressable
                      key={value}
                      accessibilityRole="button"
                      accessibilityLabel={`Backdrop intensity ${value} percent`}
                      accessibilityState={{ selected }}
                      onPress={() => {
                        tapFeedback('selection');
                        theme.setBackdropIntensity(value);
                      }}
                      style={({ pressed }) => [
                        styles.chip,
                        selected && styles.chipActive,
                        pressed && { opacity: 0.72 },
                      ]}
                    >
                      <AppText variant="label" color={selected ? palette.accentInk : palette.ink}>
                        {value}%
                      </AppText>
                    </Pressable>
                  );
                })}
              </View>
            </SettingField>
          </ListGroup>
        </View>

        <View style={styles.section}>
          <SectionHeader label="Motion" />
          <ListGroup style={styles.settingsCard}>
            <ChipRow
              items={MOTION}
              value={theme.motionMode}
              onSelect={(mode) => {
                tapFeedback('selection');
                theme.setMotionMode(mode);
              }}
            />
            <AppText variant="micro" color={palette.inkFaint}>
              Reduced keeps fades and drops slide-springs across tabs and cards.
            </AppText>
          </ListGroup>
        </View>

        <View style={styles.section}>
          <SectionHeader label="Feedback" />
          <ListGroup>
            <SwitchRow
              icon="radio"
              label="Haptics"
              hint="Feedback on taps"
              value={preferences.haptics}
              onChange={(value) => {
                tapFeedback('selection');
                setHaptics(value);
              }}
            />
          </ListGroup>
        </View>

        <View style={styles.section}>
          <SectionHeader label="About" />
          <ListGroup style={styles.settingsCard}>
            <View style={styles.aboutRow}>
              <SnoozyBrandIcon size={56} />
              <View style={styles.aboutCopy}>
                <AppText variant="heading" color={palette.ink}>About Snoozy</AppText>
                <AppText variant="micro" color={palette.inkMuted}>
                  A minimal local music player for your library, your way.
                </AppText>
              </View>
            </View>

            <AppText variant="micro" color={palette.inkFaint}>
              Version {version} ({build}) · {osVersion} · arm64
            </AppText>

            <View style={styles.divider} />

            <ListRow
              leading={<RowIcon name="alert-triangle" />}
              title="Error log"
              subtitle="Diagnostics for anything that went wrong"
              onPress={() => {
                tapFeedback('selection');
                router.push('/error-log');
              }}
              accessibilityLabel="Open error log"
              accessibilityHint="Shows diagnostics from this device"
              trailing={<Feather name="chevron-right" size={18} color={palette.inkFaint} />}
            />

            <AppText variant="micro" color={palette.inkFaint}>Open-source components:</AppText>
            <View style={styles.ossList}>
              {OSS_NOTICES.map((notice) => (
                <AppText key={notice} variant="micro" color={palette.inkMuted}>
                  {notice}
                </AppText>
              ))}
            </View>
          </ListGroup>
        </View>
      </Animated.ScrollView>

      <CollapsedBar title="Settings" scrollY={scrollY} />
    </SafeAreaView>
  );
}

const createStyles = ({ palette, glass }: AppTheme) => ({
  safe: { flex: 1 },
  content: {
    paddingTop: spacing.lg,
    paddingBottom: layout.tabBarSpace,
    gap: spacing.xl,
  },
  section: {
    gap: spacing.sm,
  },
  settingsCard: {
    padding: spacing.md,
    gap: spacing.md,
  },
  rowIcon: {
    width: 36,
    height: 36,
    borderRadius: radii.sm,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
    backgroundColor: glass.tintSoft,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeSoft,
  },
  pillButton: {
    minHeight: 36,
    justifyContent: 'center' as const,
    paddingHorizontal: spacing.md,
    borderRadius: radii.pill,
    backgroundColor: palette.accent,
  },
  field: {
    gap: spacing.sm,
  },
  chipRowWrap: {
    flexDirection: 'row' as const,
    flexWrap: 'wrap' as const,
    gap: spacing.sm,
  },
  chip: {
    minHeight: 44,
    justifyContent: 'center' as const,
    paddingHorizontal: spacing.md,
    borderRadius: radii.pill,
    backgroundColor: glass.tintSoft,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeSoft,
  },
  chipActive: {
    backgroundColor: palette.accent,
    borderColor: palette.accent,
  },
  swatch: {
    width: 44,
    height: 44,
    borderRadius: 22,
    borderWidth: 2,
    borderColor: palette.border,
  },
  swatchActive: {
    borderWidth: 3,
    borderColor: palette.ink,
  },
  divider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: palette.border,
  },
  aboutRow: {
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    gap: spacing.md,
  },
  markImage: {
    width: 56,
    height: 56,
    borderRadius: 14,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: glass.edgeStrong,
  },
  aboutCopy: { flex: 1, gap: 2 },
  ossList: {
    gap: spacing.xxs,
    paddingLeft: spacing.xs,
  },
});
