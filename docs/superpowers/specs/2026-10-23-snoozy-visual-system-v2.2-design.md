# Snoozy v2.2 visual system and behavior reset

Status: Draft for review
Date: 2026-10-23
Branch: `release/v1.9`
Baseline: `cfb3c0d` (v1.8.0), with the v1.9–v2.1 work currently uncommitted

## Problem

The v2.1 device pass exposed four related problems that cannot be fixed as isolated style tweaks:

1. **Appearance settings do not change the app.** `ThemeContext` generates
   light/dark palettes and stores mode, palette style, accent seed, backdrop,
   and motion preferences, but screens and components import the static
   `colors` and `glass` objects. Only the artwork glow on the player currently
   reacts to a theme preference.
2. **Tab changes visibly flash.** The tab navigator crossfades between screens,
   tab content mounts with `FadeIn`/`FadeInDown`, and every tab renders its own
   `MiniPlayer`. Switching tabs remounts the mini-player and restarts its
   entrance animation.
3. **Library hierarchy is broken.** Five content-sized segments overflow the
   viewport, so Favorites is clipped. Every song is a separate heavy glass card,
   while albums, artists, playlists, and favorites use different row patterns.
4. **Visual hierarchy is inconsistent.** Home, Search, Library, and Settings use
   different header sizes, spacing, card treatments, section labels, and empty
   states. Search has no page title; other pages use oversized display type.

The result feels unreliable even where the underlying playback, storage, and
navigation behavior works.

## Goals

- Make every Appearance control affect the whole app immediately and persist it.
- Establish one calm, compact visual hierarchy across the four tabs.
- Make tab switching immediate and flash-free while keeping useful motion.
- Rebuild the Library screen around a readable five-way control and consistent
  music rows.
- Keep the existing dark-green glass identity, fonts, four tabs, S mark,
  wordmark, playback engine, data model, navigation, and dependency set.
- Leave the app in a verified release state.

## Non-goals

- No new product features, dependencies, or playback behavior.
- No replacement of Expo Router, React Native, Reanimated, or MMKV.
- No real Android backdrop blur. Glass remains layered translucency.
- No redesign of the player's core transport/artwork experience.
- No new cloud, sync, account, or sharing features.

## Design principles

1. **One hierarchy:** page title, section label, content. The same sizes and
   spacing appear on every tab.
2. **Music first:** controls and metadata are quiet; artwork, title, and playback
   state carry the emphasis.
3. **One surface language:** cards and rows share padding, radius, border, and
   shadow rules. Not every element floats.
4. **Motion explains state:** tab pill, press feedback, sheets, artwork changes,
   and swipe actions animate. Decorative mount fades do not run on tab switches.
5. **Theme is semantic:** screens consume roles such as `background`, `ink`,
   `accent`, and `border`, never hard-coded hex values.

## Architecture

### 1. Theme source of truth

`ThemeContext` becomes the only source of visual values for React components.

It exposes:

```ts
type AppPalette = {
  background: string;
  backgroundDeep: string;
  backgroundRaised: string;
  surface: string;
  surfaceRaised: string;
  surfaceMuted: string;
  border: string;
  borderStrong: string;
  ink: string;
  inkMuted: string;
  inkFaint: string;
  accent: string;
  accentStrong: string;
  accentInk: string;
  ember: string;
  emberSoft: string;
  danger: string;
  dangerSoft: string;
  pass: string;
  fail: string;
  pending: string;
  imageTint: string;
  scrim: string;
  white: string;
  black: string;
};

type AppGlass = {
  tint: string;
  tintStrong: string;
  tintSoft: string;
  tintDeep: string;
  tintAccent: string;
  buttonTint: string;
  fieldTint: string;
  edge: string;
  edgeStrong: string;
  edgeSoft: string;
  highlight: string;
  highlightSoft: string;
  highlightEdge: string;
  shadow: string;
  shadowDeep: string;
  innerGlow: string;
  scrim: string;
};

type AppTheme = ThemeContextValue & {
  palette: AppPalette;
  glass: AppGlass;
};
```

- `buildAppPalette(tokens, dark, seed, paletteStyle)` converts the existing
  Material color tokens into the semantic palette.
- **Dark mode** keeps the current pine ground, ink, and glass identity as its
  base. Accent, surface tinting, and glows come from the selected seed/style.
  The default seed + tonal-spot style must remain visually equivalent to the
  current app.
- **Light mode** uses the generated light background, surface containers,
  on-colors, outline, primary, and error roles, then derives the same semantic
  roles. Glass becomes translucent white with dark edges and softer shadows.
- **Palette style and accent seed** change the accent, secondary glow, and
  surface tint. Default dark remains the reference identity.
- `useThemedStyles(factory)` memoizes a `StyleSheet` against the active theme.
  Screens and components stop importing static `colors`/`glass` values.
- `AppText` uses `palette.ink` by default. Explicit colors use palette roles.
- `GlassSurface` resolves its variant from the active `AppGlass`.
- `StatusBar`, `SystemUI` background, stack backgrounds, tab backgrounds,
  refresh controls, sheets, icons, and switches all follow the palette.
- `colors`, `glass`, and `glassVariants` remain exported as the default dark
  fallback for non-React utilities, but no rendered screen consumes them
  directly after this change.

### 2. Shared layout primitives

Add a small shared set in `src/components/`:

- `ScreenHeader`: one page title size (`title`), optional subtitle/eyebrow, and
  one trailing action slot. Same top/side padding on all four tabs.
- `SectionHeader`: uppercase overline label plus optional text action. Replaces
  the current mix of heading/micro labels.
- `EmptyState`: one compact icon/art, title, message, optional action. Used by
  Home, Search, Library, Favorites, and error/permission states.
- `ListGroup`: a glass card that groups rows with consistent padding and
  separators.
- `ListRow`: a pressable row with leading artwork/icon, title, subtitle,
  optional trailing control, 48dp minimum touch target, and consistent pressed
  state. Swipeable song rows keep their existing menu fallback.

All tabs use `layout.screenPadding` (20), one title size, one section spacing
scale, and one card radius/padding rule. Display-scale type remains available
for the player/artwork context but is not used for tab page titles.

### 3. Navigation, mini-player, and motion

- Set the tab navigator animation to `none`; tab switching is immediate.
- Keep all four tab screens mounted (`lazy: false`) and set the tab scene
  background to the active palette background.
- Remove `FadeIn`/`FadeInDown` mount animations from tab headers and tab
  content. Content appears in its final position on every visit.
- **Hoist one `MiniPlayer` into the tabs layout**, above the floating tab bar.
  Remove the four per-screen mini-players. This prevents remount/entrance flash
  on every tab switch and keeps one continuous mini-player.
- Keep stack screen transitions (`slide_from_right` for detail, modal for
  player), the floating tab pill spring, press scaling, sheet entrances, seek
  fill, artwork crossfade, and swipe action motion.
- Honor `reducedMotion`: snaps instead of springs/slides, fades only where a
  transition still needs one, no decorative movement.
- Stack detail screens continue to use `MiniPlayer standalone` where there is
  no tab bar.

### 4. Screen hierarchy

#### Home

- `ScreenHeader`: “Your music”, song count subtitle, import action.
- Permission/scanning/empty states use `EmptyState`, not bespoke cards.
- “Recently played” section with `SectionHeader`, clear action, and a
  `ListGroup` of compact rows.
- “Playlists” section with `SectionHeader`, new-playlist action, and grouped
  playlist rows.
- “Library” section with a single Browse all songs row.
- Remove repeated display headings and decorative entrance wrappers.

#### Search

- Add the missing `ScreenHeader` (“Search”).
- Search field below the header, consistent height and radius.
- “Recent searches” with clear action in a `ListGroup`.
- Results under a “Songs” section header with a count and grouped rows.
- Empty/no-result states use `EmptyState`.

#### Library

- `ScreenHeader`: “Library”, status subtitle (track count/scan/permission), and
  import action.
- A full-width five-segment control:
  - five equal `flex: 1` segments in one row, no horizontal scrolling;
  - 48dp touch height, readable 13px labels, active pill/thumb;
  - Favorites must be fully visible at 360dp width;
  - reduced motion snaps the thumb.
- Content is grouped by tab:
  - Songs: one grouped list of compact swipeable rows. Artwork 44, title,
    artist/album, overflow menu. Favorite/playlist swipe actions remain.
  - Favorites: the same grouped song list.
  - Albums: grouped album rows with icon tile, title, track count, chevron.
  - Artists: grouped artist rows with the same pattern.
  - Playlists: grouped playlist rows with name, count, add-songs action, and
    overflow menu; playlist tracks remain compact rows.
- One shared empty state per tab, with the correct scan/permission action.
- Scroll content uses the existing bottom space token so the persistent
  mini-player never covers the last row.
- Section changes keep scroll position stable and do not replay entrance
  animations.

#### Settings

- `ScreenHeader`: “Settings”, with version/subtitle context.
- Sections: Library, Appearance, Motion, About.
- Appearance controls become live:
  - Light / Dark / Auto;
  - palette style;
  - accent swatch;
  - Backdrop enabled/intensity, labeled as the player artwork glow.
- Motion controls and Haptics remain and use dynamic colors.
- Setting rows use one 56dp pattern, consistent icon tile, hint text, switch,
  and chevron.
- Error Log and open-source notices remain available; notices stay compact and
  use the same type scale.
- Changes apply immediately without a reload.

### 5. Detail screens and sheets

Album, artist, player, error log, and all sheets are migrated to the active
palette/glass. Their existing behavior and transitions stay intact. The player
keeps its large artwork and transport controls; only colors and minor spacing
normalization change.

## Data flow and persistence

- `ThemeContext` remains the persistence owner for mode, palette style, seed,
  backdrop, and motion.
- `PreferencesContext` remains the persistence owner for haptics and playback
  preferences.
- `PlayerContext` keeps its per-artwork palette; it is separate from the app
  theme and must remain readable on both themes.
- Theme changes re-render consumers; no app reload, navigation reset, or data
  migration is required.
- All theme reads are synchronous from MMKV at startup; no loading flash.

## Error handling

- Invalid persisted theme values fall back to current defaults (`dark`,
  `tonal-spot`, default seed, backdrop on/60, motion system).
- Theme changes cannot throw into the UI; color parsing already falls back to
  the default seed.
- Screens keep existing permission, scan, playback, and storage error states.
- If a light-mode contrast pair fails, palette construction falls back to a
  high-contrast on-color rather than rendering unreadable text.

## Verification

Static:

- `npx tsc --noEmit`
- `npx eslint src --no-cache`
- `npx expo-doctor`
- No new dependency or config changes beyond the version bump.

Device:

- Release APK built with the existing signed setup, installed over v2.1 data.
- Toggle Light, Dark, and Auto; confirm the whole app, status bar, tab bar,
  sheets, and controls change. Force-stop/relaunch to confirm persistence.
- Change palette style and each accent swatch; confirm visible changes.
- Toggle Haptics, Backdrop, and Motion; confirm behavior.
- Screen-record tab switches; verify no fade/remount flash and one continuous
  mini-player.
- Verify all five Library segments are within the display bounds and selectable.
- Exercise Songs, Favorites, Albums, Artists, and Playlists.
- Play a track; verify mini-player → player artwork continuity, seek, next,
  previous, repeat, shuffle, lyrics, edit metadata, add-to-playlist, and swipe
  favorite/playlist actions.
- Verify back navigation and reduced-motion behavior.
- Measure cold/warm startup and tab-switch frame behavior; compare against the
  v2.1 baseline.
- Use UI hierarchy/logs where display capture ghosting makes screenshots
  unreliable; never claim visual success from a corrupted capture.

## Acceptance criteria

- No Appearance control is a no-op.
- Default dark theme remains recognizably Snoozy.
- All five Library segments fit at 360dp width without horizontal scrolling.
- Tab switching shows no full-screen flash, no duplicate mini-player, and no
  content entrance replay.
- All four tabs share the same title/header/section/card/row language.
- One persistent mini-player appears above the tab bar on all tabs.
- Typecheck, lint, release build, install, and the device smoke matrix pass.
- v1.9–v2.1 playback, storage, metadata, lyrics, and navigation behavior is
  preserved.

## Release

- Version: `2.2.0`, Android versionCode `12`.
- Artifact: `artifacts/snoozy-arm64-release-v2.2.apk`.
- Existing v1.9–v2.1 work is checkpointed before the v2.2 implementation
  because no intermediate snapshots exist to split it safely.
- v2.2 implementation, build evidence, and audit notes are committed separately.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Theme refactor touches nearly every component | Build and typecheck the theme foundation first, then migrate screens in small groups. |
| Light mode contrast or glass readability | Derive from contrast-enforced Material roles; visually inspect every tab and sheet; tune semantic mapping centrally. |
| Default dark look shifts | Treat current dark palette as the base and verify the default seed/style against it before migrating screens. |
| Removing mount animations makes screens feel abrupt | Keep tab-pill, press, sheet, and artwork motion; instant screen swaps are the intended calm behavior. |
| Device capture ghosting hides visual defects | Use hierarchy bounds, logs, screen recording, and pixel sampling; repeat captures after a full redraw. |
| No automated test suite exists | Use typecheck/lint as static gates, then a scripted device smoke matrix with saved evidence. |
