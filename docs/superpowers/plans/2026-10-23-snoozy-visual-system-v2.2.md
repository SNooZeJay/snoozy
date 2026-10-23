# Snoozy v2.2 Visual System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This plan is designed for native execution in the current session because the theme interfaces, shared components, and four tab screens are tightly coupled.

**Goal:** Ship a verified Snoozy 2.2.0 with working app-wide theming, one calm screen hierarchy, a fixed five-segment Library, and flash-free tab switches.

**Architecture:** `ThemeContext` becomes the single source of `AppPalette`/`AppGlass`; `useThemedStyles` converts module-level `StyleSheet` objects into theme-aware memoized factories. Shared header/list/empty-state primitives replace per-screen variants, and one persistent mini-player moves into the tabs layout.

**Tech Stack:** Expo SDK 58, React Native 0.88, React 19, Expo Router, Reanimated, MMKV, Material Color Utilities, TypeScript.

**Spec:** `docs/superpowers/specs/2026-10-23-snoozy-visual-system-v2.2-design.md`

## Global Constraints

- No new dependencies.
- Preserve the existing dark-green glass identity, fonts, four tabs, S mark, wordmark, playback, storage, and navigation behavior.
- Preserve all v1.9–v2.1 fixes.
- Version target: `2.2.0`, Android versionCode `12`.
- No custom native files; native projects remain generated.
- Android has no real backdrop blur; glass stays layered translucency.
- No unit-test runner exists; static gates are `npx tsc --noEmit` and `npx eslint src --no-cache`, followed by release/device verification.
- Every commit is scoped to its task and leaves the tree typechecking.

## Review Focus

1. **Light mode readability** — every tab, sheet, player control, placeholder, and empty state must remain readable after switching to Light or Auto.
2. **Default-dark regression** — the default seed + tonal-spot palette must still read as the current pine/mint Snoozy.
3. **Tab-switch continuity** — no crossfade, no content entrance replay, and exactly one persistent mini-player above the tab bar.
4. **Library five-way fit** — Songs, Albums, Artists, Playlists, and Favorites must all be fully visible and tappable at 360dp width.
5. **Persistence and system chrome** — theme choice must survive force-stop/relaunch, and the status bar/root background must match Light or Dark.

---

### Task 0: Preserve the v1.9–v2.1 checkpoint

**Files:** none.

- [ ] **Step 1: Re-run the current static gates**

Run:
```bash
npx tsc --noEmit
npx eslint src --no-cache
```
Expected: both exit 0.

- [ ] **Step 2: Commit the current checkpoint**

The v1.9–v2.1 work has no intermediate snapshots, so it is preserved as one checkpoint before v2.2 changes. The spec commit is already separate.

```bash
git add -A
git commit -m "feat: checkpoint v1.9-v2.1 glass and stability work"
git status --short
```
Expected: checkpoint commit created; only ignored artifacts remain untracked.

---

### Task 1: Theme foundation

**Files:**
- Create: `src/theme/appearance.ts`
- Create: `src/theme/useThemedStyles.ts`
- Modify: `src/theme/color.ts`
- Modify: `src/theme/index.ts`
- Modify: `src/theme/ThemeContext.tsx`
- Modify: `src/components/AppText.tsx`
- Modify: `src/components/glass/GlassSurface.tsx`
- Modify: `src/app/_layout.tsx`

**Interfaces:**
- Produces: `AppPalette`, `AppGlass`, `AppTheme`, `buildAppPalette`, `buildAppGlass`, `useThemedStyles`.
- `ThemeContextValue` gains `palette: AppPalette`, `glass: AppGlass`.
- `useThemedStyles<T extends StyleSheet.NamedStyles<T>>(create: (theme: AppTheme) => T): T`.
- `AppText` defaults to `theme.palette.ink`.
- `GlassSurface` resolves `theme.glass.variants[variant]`.

- [ ] **Step 1: Add color helpers to `src/theme/color.ts`**

Add exact pure helpers:
```ts
export function withAlpha(hex: string, alpha: number): string;
export function mixHex(a: string, b: string, amount: number): string;
export function readableInk(background: string): '#000000' | '#FFFFFF';
```
`withAlpha` accepts `#RRGGBB`; `mixHex` clamps `amount` to 0–1; invalid input falls back to the first color.

- [ ] **Step 2: Add the semantic palette and glass builders**

In `src/theme/appearance.ts`, define `AppPalette` and `AppGlass` exactly as the spec lists, plus:
```ts
export type AppTheme = ThemeContextValue & {
  palette: AppPalette;
  glass: AppGlass;
};

export function buildAppPalette(
  tokens: ColorTokens,
  dark: boolean,
  seed: string,
  paletteStyle: PaletteStyle,
): AppPalette;

export function buildAppGlass(palette: AppPalette, dark: boolean): AppGlass;
```
Implementation requirements:
- Dark base is the existing `colors` pine/mint palette.
- Default seed + `tonal-spot` dark must preserve the current background, ink, and accent values; other styles/seeds may tint surfaces and accents.
- Light mode derives background, surfaces, borders, ink, accent, and danger from `tokens` with readable contrast.
- `AppGlass` includes a `variants` record for `card`, `panel`, `row`, `pill`, `button`, and `field`.
- Glass shadows reuse existing `glassShadow` geometry with the active theme shadow color.

- [ ] **Step 3: Wire the context and style hook**

Modify `ThemeContext.tsx` to compute:
```ts
const palette = useMemo(
  () => buildAppPalette(tokens, dark, seed, paletteStyle),
  [tokens, dark, seed, paletteStyle],
);
const glass = useMemo(() => buildAppGlass(palette, dark), [palette, dark]);
```
Add both to the context value and memo dependencies. Export `ThemeContextValue` so `AppTheme` can reference it.

Create `src/theme/useThemedStyles.ts`:
```ts
export function useThemedStyles<T extends StyleSheet.NamedStyles<T>>(
  create: (theme: AppTheme) => T,
): T {
  const theme = useTheme();
  return useMemo(() => StyleSheet.create(create(theme)), [theme, create]);
}
```
Export the hook and types from `src/theme/index.ts`.

- [ ] **Step 4: Make `AppText` and `GlassSurface` theme-aware**

`AppText` uses `theme.palette.ink` only when no `color` prop is supplied. `GlassSurface` reads `theme.glass` and uses dynamic variant tint, edge, highlight colors, and shadow color; it must still accept explicit `tint`, `borderColor`, `glowColor`, and `highlight` overrides.

- [ ] **Step 5: Make root system chrome theme-aware**

Restructure `src/app/_layout.tsx` so a child inside `ThemeProvider` reads `palette` and `dark`:
- `SystemUI.setBackgroundColorAsync(palette.background)` whenever the background changes.
- `<StatusBar style={dark ? 'light' : 'dark'} />`.
- Stack `contentStyle` uses `palette.background` / `palette.backgroundDeep`.
- Keep the font-loading boot screen on the static dark background.

- [ ] **Step 6: Verify and commit**

Run:
```bash
npx tsc --noEmit
npx eslint src --no-cache
git add src/theme src/components/AppText.tsx src/components/glass/GlassSurface.tsx src/app/_layout.tsx
git commit -m "feat: add semantic app theming foundation"
```
Expected: both gates pass; no screen has been restructured yet.

---

### Task 2: Migrate shared controls and mini-player

**Files:**
- Modify: `src/components/IconButton.tsx`
- Modify: `src/components/PlayButton.tsx`
- Modify: `src/components/SeekBar.tsx`
- Modify: `src/components/MiniPlayer.tsx`
- Modify: `src/components/SwipeableRow.tsx`
- Modify: `src/components/Thumb.tsx`
- Modify: `src/components/SoundWave.tsx`
- Modify: `src/components/SplashIntro.tsx`
- Modify: `src/components/SectionHeader.tsx`

**Interfaces:**
- `SwipeableRow` gains optional `actionBackgroundColor?: string` and `defaultIconColor?: string`; class internals stay imperative.
- `MiniPlayer` keeps `{ standalone?: boolean }`.
- `SectionHeader` becomes `{ label: string; actionLabel?: string; onAction?: () => void }`.

- [ ] **Step 1: Convert static styles to `useThemedStyles`**

For each functional component, replace `import { colors, glass }` usage with:
```ts
const { palette, glass } = useTheme();
const styles = useThemedStyles(createStyles);
```
and move the module `StyleSheet.create` body into `createStyles(theme)` with `theme.palette` / `theme.glass`. Inline icon and text colors use `palette.*`.

- [ ] **Step 2: Make swipe actions theme-safe**

Pass palette colors into `SwipeableRow` from its parent. Use `actionBackgroundColor` for the rail and `defaultIconColor` for labels/icons. Keep the current 76dp action width, 10px horizontal drag threshold, vertical-scroll priority, and accessible row-menu fallback.

- [ ] **Step 3: Update mini-player**

Keep the 44dp artwork, 48dp play target, artwork shared transition tag, `standalone` behavior, and entrance/exit only while a track first appears. Use `palette` for text/icons/play button; keep `player.palette` for artwork glow.

- [ ] **Step 4: Verify and commit**

Run:
```bash
npx tsc --noEmit
npx eslint src --no-cache
git add src/components
git commit -m "feat: theme shared playback controls"
```
Expected: gates pass; tabs still render their temporary mini-player copies until Task 5.

---

### Task 3: Migrate sheets

**Files:**
- Modify: `src/components/LyricsSheet.tsx`
- Modify: `src/components/SongEditSheet.tsx`
- Modify: `src/components/AddSongsSheet.tsx`
- Modify: `src/components/AddToPlaylistSheet.tsx`
- Modify: `src/components/CreatePlaylistSheet.tsx`

- [ ] **Step 1: Convert sheet styles and controls**

Apply the same `useThemedStyles` conversion to each sheet. Replace `placeholderTextColor`, `selectionColor`, `keyboardAppearance`, switch colors, destructive colors, and icon colors with palette values. Keep all sheet behavior, validation, ordering, and keyboard handling unchanged.

- [ ] **Step 2: Verify and commit**

Run:
```bash
npx tsc --noEmit
npx eslint src --no-cache
git add src/components/*Sheet.tsx
git commit -m "feat: theme bottom sheets"
```
Expected: gates pass; no behavior changes.

---

### Task 4: Add shared layout primitives

**Files:**
- Create: `src/components/ScreenHeader.tsx`
- Create: `src/components/ListGroup.tsx`
- Create: `src/components/ListRow.tsx`
- Create: `src/components/EmptyState.tsx`
- Modify: `src/components/SectionHeader.tsx`

**Interfaces:**
```ts
type ScreenHeaderProps = {
  title: string;
  subtitle?: string;
  eyebrow?: string;
  action?: ReactNode;
};

type ListGroupProps = {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
};

type ListRowProps = {
  leading?: ReactNode;
  title: string;
  subtitle?: string;
  trailing?: ReactNode;
  onPress?: () => void;
  accessibilityLabel: string;
  accessibilityHint?: string;
};

type EmptyStateProps = {
  title: string;
  message: string;
  actionLabel?: string;
  onAction?: () => void;
  compact?: boolean;
};
```

- [ ] **Step 1: Implement the primitives**

- `ScreenHeader` uses `type.title` for every page, optional `overline` eyebrow, `micro` subtitle, 20dp side padding, and a 44dp trailing slot.
- `ListGroup` wraps `GlassSurface variant="card"` with consistent padding, radius, and overflow clipping.
- `ListRow` uses a 48dp minimum height, 44dp leading slot, one-line title, one-line micro subtitle, 44dp trailing slot, and opacity press feedback.
- `EmptyState` uses `DottedNote` at 64 (or 48 when compact), a `heading` title, `body` message, and an optional 48dp primary action.
- `SectionHeader` uses an `overline` label plus optional text action; no display/heading title.

- [ ] **Step 2: Gate and commit**

Run `npx tsc --noEmit` and `npx eslint src --no-cache`.

```bash
git add src/components/ScreenHeader.tsx src/components/ListGroup.tsx src/components/ListRow.tsx src/components/EmptyState.tsx src/components/SectionHeader.tsx
git commit -m "feat: add shared screen layout primitives"
```

---

### Task 5: Remove the flash sources and persist the mini-player

**Files:**
- Modify: `src/app/(tabs)/_layout.tsx`
- Modify: `src/app/(tabs)/index.tsx`
- Modify: `src/app/(tabs)/search.tsx`
- Modify: `src/app/(tabs)/library.tsx`
- Modify: `src/app/(tabs)/settings.tsx`

- [ ] **Step 1: Make tabs immediate**

Set tab options to:
```ts
animation: 'none',
lazy: false,
sceneStyle: { backgroundColor: palette.background },
```
Keep the hidden native tab bar and the floating pill bar. Make the pill bar palette-aware.

- [ ] **Step 2: Hoist one mini-player**

Add `<MiniPlayer />` once inside the tabs layout, after `<Tabs>` and before `<FloatingPillBar />`, with the same bottom offset used today. Remove all four per-screen `<MiniPlayer />` calls and their imports. Keep `MiniPlayer standalone` on album, artist, and error-log.

- [ ] **Step 3: Stop tab-mount entrances**

Remove `FadeIn`/`FadeInDown` header and section wrappers from the four tab screens. Replace `Animated.View` wrappers that exist only for entrance with plain `View`. Keep Reanimated only where motion is interactive (pill, press, sheets, artwork, seek).

- [ ] **Step 4: Verify and commit**

Run:
```bash
npx tsc --noEmit
npx eslint src --no-cache
git add src/app/'(tabs)'
git commit -m "fix: make tab switches immediate and keep one mini-player"
```
Expected: gates pass; screens may still use old static hierarchy but no longer remount a mini-player or replay entrances.

---

### Task 6: Rebuild the Library screen

**Files:**
- Modify: `src/app/(tabs)/library.tsx`

- [ ] **Step 1: Replace the segment control layout**

Remove the horizontal `ScrollView`. Use:
```tsx
<View style={styles.segmentRow}>
  <View style={styles.segmentTrack}>
    {SEGMENTS.map((segment, index) => (
      <Pressable key={segment} style={styles.segmentTap} ...>
        <View style={[styles.segment, selected && styles.segmentActive]}>
          <AppText variant="label" numberOfLines={1} ... />
        </View>
      </Pressable>
    ))}
  </View>
</View>
```
Styles: 48dp tap height, `flex: 1` tap and track, 4dp gap, 36dp active thumb at top 6, 2dp horizontal label padding, and `numberOfLines={1}`. The active thumb keeps the spring/snap behavior.

- [ ] **Step 2: Apply the shared hierarchy**

Use `ScreenHeader` with `title="Library"`, the existing status subtitle, and the import action. Add the segment control below it. Use `SectionHeader`, `ListGroup`, `ListRow`, and `EmptyState` for every tab.

- [ ] **Step 3: Normalize the five content views**

- Songs and Favorites: grouped compact swipeable song rows with 44dp artwork, title, artist/album, overflow menu, and existing favorite/playlist swipe actions.
- Albums and Artists: grouped rows with icon tile, title, track count, chevron.
- Playlists: grouped rows with name, count, add-songs action, and overflow; playlist tracks use compact rows.
- Preserve create-playlist, add-to-playlist, add-songs, remove-song, delete-playlist, favorite, play, and menu behavior.
- Remove all `staggerEnter` wrappers from Library lists.

- [ ] **Step 4: Verify and commit**

Run:
```bash
npx tsc --noEmit
npx eslint src --no-cache
git add 'src/app/(tabs)/library.tsx'
git commit -m "feat: rebuild library hierarchy and five-way segments"
```

---

### Task 7: Rebuild Home

**Files:**
- Modify: `src/app/(tabs)/index.tsx`

- [ ] **Step 1: Apply the shared hierarchy**

Use `ScreenHeader` with “Your music”, a song-count subtitle, and the import action. Replace permission/scanning/empty cards with `EmptyState`. Remove all `cardEnter`/`staggerEnter` wrappers.

- [ ] **Step 2: Normalize sections**

- “Recently played”: `SectionHeader` + clear action + `ListGroup` of `ListRow`s.
- “Playlists”: `SectionHeader` + new-playlist action + grouped playlist rows.
- “Library”: `SectionHeader` + “See all” action + one Browse all songs row.
- Preserve all existing clear-history, play, create-playlist, and navigation behavior.

- [ ] **Step 3: Verify and commit**

Run `npx tsc --noEmit` and `npx eslint src --no-cache`.

```bash
git add 'src/app/(tabs)/index.tsx'
git commit -m "feat: simplify home hierarchy"
```

---

### Task 8: Rebuild Search

**Files:**
- Modify: `src/app/(tabs)/search.tsx`

- [ ] **Step 1: Add the missing page hierarchy**

Add `ScreenHeader title="Search"`. Keep the search field below it with a consistent search icon, clear action, and palette-aware placeholder/selection colors. Remove `cardEnter`/`staggerEnter`.

- [ ] **Step 2: Normalize results**

- Recent searches: `SectionHeader` + clear action + `ListGroup` of `ListRow`s.
- Results: `SectionHeader` “Songs” with count + `ListGroup` of compact rows.
- Empty/no-result states: `EmptyState`.
- Preserve query persistence, submit behavior, result ordering, and local query state.

- [ ] **Step 3: Verify and commit**

Run `npx tsc --noEmit` and `npx eslint src --no-cache`.

```bash
git add 'src/app/(tabs)/search.tsx'
git commit -m "feat: align search hierarchy"
```

---

### Task 9: Rebuild Settings

**Files:**
- Modify: `src/app/(tabs)/settings.tsx`

- [ ] **Step 1: Apply shared sections and header**

Use `ScreenHeader title="Settings"` and consistent `ListGroup` sections for Library, Appearance, Motion, and About. Normalize row heights, icon tiles, chips, switches, and dividers.

- [ ] **Step 2: Keep every existing control live**

- Haptics toggles `setHaptics`.
- Mode, palette style, accent seed, backdrop toggle/intensity, and motion mode call the existing theme context setters.
- Label Backdrop as the player artwork glow and keep its hint/intensity current.
- Error Log and OSS notices remain available.
- Use palette-aware Switch, placeholder, selection, and chip colors.
- Remove the settings-page `FadeIn` entrance.

- [ ] **Step 3: Verify and commit**

Run `npx tsc --noEmit` and `npx eslint src --no-cache`.

```bash
git add 'src/app/(tabs)/settings.tsx'
git commit -m "feat: simplify settings and expose live theming"
```

---

### Task 10: Migrate detail screens and player

**Files:**
- Modify: `src/app/album.tsx`
- Modify: `src/app/artist.tsx`
- Modify: `src/app/error-log.tsx`
- Modify: `src/app/player.tsx`

- [ ] **Step 1: Convert static styles**

Apply `useThemedStyles` and palette values to each screen. Replace static background, text, icon, control, error, and placeholder colors. Keep existing stack transitions, headers, playback behavior, and `MiniPlayer standalone` usage.

- [ ] **Step 2: Normalize detail headers**

Use the same 20dp side padding and title scale as the tabs. Album/artist lists keep their current compact rows and motion. The player keeps its large artwork layout and transport controls.

- [ ] **Step 3: Verify and commit**

Run:
```bash
npx tsc --noEmit
npx eslint src --no-cache
git add src/app/album.tsx src/app/artist.tsx src/app/error-log.tsx src/app/player.tsx
git commit -m "feat: theme and align detail screens"
```

---

### Task 11: Version, docs, and static release gates

**Files:**
- Modify: `app.json`
- Modify: `package.json`
- Modify: `package-lock.json`
- Modify: `src/app/(tabs)/settings.tsx`
- Modify: `docs/BUILD.md`
- Modify: `docs/PLAN-v1.9-v2.1.md`

- [ ] **Step 1: Bump the version**

Set `app.json` to `2.2.0` / Android `versionCode` `12`; set `package.json` and both package-lock version fields to `2.2.0`; update the Settings fallback from `'2.1.0'` to `'2.2.0'`.

- [ ] **Step 2: Record the design and build intent**

Add a v2.2 section to `docs/BUILD.md` describing the visual system, version, build environment, and verification gates. Update the plan checklist so completed v1.9–v2.1 items are marked accurately and v2.2 is linked.

- [ ] **Step 3: Run static gates**

Run:
```bash
npx tsc --noEmit
npx eslint src --no-cache
npx expo-doctor
```
Expected: typecheck/lint pass; expo-doctor only reports the known patch-level Expo mismatches.

- [ ] **Step 4: Commit**

```bash
git add app.json package.json package-lock.json 'src/app/(tabs)/settings.tsx' docs/BUILD.md docs/PLAN-v1.9-v2.1.md
git commit -m "chore: prepare snoozy 2.2.0 release"
```

---

### Task 12: Build and verify the v2.2 release APK

**Files:** generated build outputs only.

- [ ] **Step 1: Sync sources to the build tree**

Sync the working tree to `C:\s` using the established workflow, preserving `C:\s\node_modules` and removing stale JS bundles before the build. Do not copy `.git`, `artifacts`, or generated `android`/`ios` trees over the prebuilt tree.

- [ ] **Step 2: Prebuild and build**

Run the established sequence:
```powershell
cd C:\s
npx expo prebuild --platform android --no-install
$env:JAVA_HOME='C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot'
# load SNOOZY_KEYSTORE_FILE, SNOOZY_KEYSTORE_PASSWORD, SNOOZY_KEY_ALIAS, SNOOZY_KEY_PASSWORD
# from C:\Users\Administrator\.snoozy\keystore.properties
Get-ChildItem C:\s\android\app\src\main\assets -Filter *.bundle -ErrorAction SilentlyContinue | Remove-Item -Force
.\android\gradlew.bat -p C:\s\android assembleRelease -PreactNativeArchitectures=arm64-v8a
```
Expected: `BUILD SUCCESSFUL`; do not use the default JDK 25.

- [ ] **Step 3: Verify the APK**

Run:
```powershell
D:\Android\Sdk\build-tools\37.0.0\apksigner.bat verify --verbose --print-certs <apk>
D:\Android\Sdk\build-tools\37.0.0\aapt.exe dump badging <apk>
D:\Android\Sdk\build-tools\37.0.0\zipalign.exe -c 4 <apk>
```
Confirm versionName `2.2.0`, versionCode `12`, v2 signature `CN=Snoozy Release`, zipalign exit 0, and a bundle containing v2.2 markers. Copy to `artifacts/snoozy-arm64-release-v2.2.apk` and record size/SHA-256.

- [ ] **Step 4: Install**

```bash
adb -s 9PGE8SQKAM598PBY install -r artifacts/snoozy-arm64-release-v2.2.apk
```
Expected: `Success`; existing app data remains.

---

### Task 13: Device verification and defect loop

**Files:** any files required by defects found.

- [ ] **Step 1: Launch and inspect logs**

Clear logcat, force-stop, cold-launch, and capture `Status`, `TotalTime`, `WaitTime`. Confirm `ReactNativeJS: Running "main"` and no fatal exception.

- [ ] **Step 2: Verify theming**

Toggle Light, Dark, and Auto; confirm the Settings selected states and screen colors change. Force-stop/relaunch and confirm persistence. Repeat for palette style and each accent swatch. Check tab bar, status bar, sheets, player, error banner, and empty states in both modes.

- [ ] **Step 3: Verify tab-switch continuity**

Record several tab switches. Confirm:
- no full-screen fade/flash;
- no duplicate mini-player;
- no list entrance replay;
- one continuous mini-player state.
Use `dumpsys gfxinfo com.snoozy.app` and logcat as supporting evidence.

- [ ] **Step 4: Verify Library**

Use `uiautomator dump` to confirm all five segments have bounds fully inside the 720px display. Select each segment, confirm content changes, and exercise songs, albums, artists, playlists, favorites, empty states, swipe actions, and the row menu.

- [ ] **Step 5: Verify playback and sheets**

Play a track; verify mini-player → player artwork continuity, seek, next, previous, repeat, shuffle, lyrics, metadata editing, add-to-playlist, create-playlist, add-songs, and remove-from-playlist. Verify back navigation and reduced motion.

- [ ] **Step 6: Measure startup and frames**

Capture cold and warm launch timings and a short `gfxinfo` sample. Compare against the v2.1 baseline and record results in `docs/BUILD.md`.

- [ ] **Step 7: Fix and repeat**

For each defect, fix the cause, rerun typecheck/lint, rebuild, reinstall, and repeat the affected device check. Do not claim visual success from corrupted captures; use hierarchy bounds, logs, and screen recordings where the device compositor is unreliable.

- [ ] **Step 8: Commit verification fixes**

```bash
git add <changed files>
git commit -m "fix: resolve v2.2 device verification findings"
```

---

### Task 14: Final audit and release report

**Files:**
- Modify: `docs/BUILD.md`
- Modify: `docs/PLAN-v1.9-v2.1.md`
- Create or modify as needed: `docs/AUDIT-v2.2.md`

- [ ] **Step 1: Re-run static gates**

```bash
npx tsc --noEmit
npx eslint src --no-cache
npx expo-doctor
git status --short
```
Expected: typecheck/lint pass; only known doctor patch warnings; no unintended source changes.

- [ ] **Step 2: Record evidence**

Write the artifact path, size, SHA-256, version, signature, zipalign result, startup timings, theme matrix, Library hierarchy bounds, tab-switch verification, and any remaining unverified items. Never claim a visual pass from ghosted captures.

- [ ] **Step 3: Final commit**

```bash
git add docs
git commit -m "docs: record snoozy 2.2 release verification"
```

- [ ] **Step 4: Report**

Summarize what changed, what was verified with evidence, and what remains unverified or limited. Do not claim “perfect” beyond the evidence.

---

## Self-Review

**Spec coverage:** Theme pipeline (Task 1), shared controls (2), sheets (3), primitives (4), navigation/mini-player (5), Library (6), Home (7), Search (8), Settings (9), detail screens (10), release (11–12), device verification (13), final evidence (14).

**Type consistency:** `AppTheme` exposes `palette` and `glass`; `useThemedStyles` consumes `AppTheme`; `SwipeableRow` receives color props from themed parents; `MiniPlayer` keeps its `standalone` prop.

**Review Focus coverage:** light/dark checks in 13; default dark in 1/13; tab flash in 5/13; segment fit in 6/13; persistence/system chrome in 1/13.

**Proportion:** This plan names files, interfaces, commands, and acceptance criteria; it does not transcribe component bodies.
