# Glasmio Framework Reverse Engineering and Snoozy Integration Architecture

Date: 2026-11-11
Reference Repository: `https://github.com/NEORUAA/Glasmio`
Target Repository: `D:\OWN_PROJECTS\SNOOZY`

## 1. Complete Glasmio Multi-Module Architecture

Glasmio (`settings.gradle.kts`) consists of six library modules and one sample app:

1. `:glasmio-core` (`io.github.neoruaa.glasmio.core`)
   - `GlassTokens.kt`: Defines `GlassTier` (`FullShader`, `BlurOnly`, `ReducedTransparency`), `GlassStyle` (`Regular`, `Clear`), `GlassEmphasis` (`Regular`, `Prominent`), `GlassAppearance` (`isDark`, `reduceTransparency`, `reduceMotion`, `increasedContrast`, `accent`), `GlassMaterialRecipe` (blur radius, frost factor, saturation, black/white levels, border alpha, inner/outer refraction, inner/outer shadow), `GlassSpring` (`interactiveResponse = 0.27f`, `interactiveDamping = 0.78f`, `morphResponse = 0.34f`, `morphDamping = 0.74f`, `sheetResponse = 0.38f`, `sheetDamping = 0.86f`), `GlassDimensions` (`compactCornerRadius = 16.dp`, `regularCornerRadius = 26.dp`, `sheetCornerRadius = 38.dp`, `controlHeight = 48.dp`, `iconButtonSize = 44.dp`, `bottomBarHeight = 64.dp`, `IosPageHorizontalPadding = 16.dp`), and `GlassTheme`.
   - `GlasmioTypography.kt`: 11-step Cupertino type scale (`largeTitle` 34 sp bold to `caption2` 11 sp) with tracking and line-height tokens.
   - `SwipeBackExclusion.kt`: Gesture exclusion rects for interactive horizontal controls (`GlasmioSlider`, `GlasmioSwitch`, `GlasmioSegmentedControl`).

2. `:glasmio-glass` (`io.github.neoruaa.glasmio.glass`)
   - `GlassSurface.kt`: Multi-pass surface compositor combining backdrop sampling, blur, refraction, inner shadows, container fill, and dual-angle specular border highlights.
   - `render/optics/NativeGlassRefraction.kt` & `GlassSdf.kt`: Recovered iOS 27 QuartzCore `glass_background_sdf_r` transfer functions (`nativeGlassDisplacement` circular lens profile `signedAmount * (1 - sqrt(u * (2 - u)))`, `nativeGlassAberrate` 7-tap spectral dispersion across red/orange/yellow/green/cyan/blue/purple).
   - `render/highlight/HighlightStyle.kt` & `NativeGlassEdges.kt`: Dual-angle cosine ramp (`cos(2 * (angle - lightAngle))`) producing diagonal top-left and bottom-right specular rim reflections.
   - `NativeControlLens.kt` & `NativeControlLensOptics.kt`: Interactive magnifying capsule lens used on switches, sliders, and tab indicators when pressed or dragged.
   - `ProgressiveBackdropBlur.kt`: Variable-radius blur mask for top navigation bars (`GlasmioTopBar`) and bottom bars (`GlasmioTabBar`).
   - `LiquidMenuMorphSurface.kt` & `cpp/liquid_menu_sdf.cpp`: Smooth-union SDF contour morphing between trigger buttons and expanded context menus.

3. `:glasmio-ui` (`io.github.neoruaa.glasmio.ui`)
   - `GlassButtons.kt`: `GlasmioButton` and `GlasmioIconButton` with `Regular` and `Prominent` emphasis, press scale (`0.96f` or lift `1.04f`), and specular stroke.
   - `GlassControls.kt`: `GlasmioSwitch` (`63 x 28 dp` track, `37 x 24 dp` capsule thumb expanding `1.5x` on press with spring `0.27s / 0.625`), `GlasmioSlider` (`6 dp` capsule track, `37 x 24 dp` capsule lens thumb, local drag state), and `GlasmioSegmentedControl` (capsule track with velocity-stretched sliding indicator).
   - `GlassSearchBar.kt`: `GlasmioSearchBar` (`48 dp` capsule morphing from `segmentedControlBackground` to navigation glass on focus with animated trailing circular clear button).
   - `GlasmioTabBar.kt`: Floating capsule tab bar with scroll collapse, sliding lens indicator, and accessory slot.
   - `IosLists.kt`: `GlasmioGroupedList` (`26 dp` continuous corners), `GlasmioListRow` (`52 dp` single-line, `68 dp` subtitle row, inset hairline separator suppressed on top row), `GlasmioSectionTitle`.
   - `IosSheets.kt`, `IosSheetMotion.kt`, `IosSheetMaterial.kt`: `GlasmioBottomSheet` (`38 dp` top corners, `60 x 4 dp` capsule grabber inside `20 dp` top slot, rubber-band overscroll, velocity/displacement snap).
   - `IosAlerts.kt` & `IosAlertMotion.kt`: Centered glass modal dialogs entering from `1.12x` scale with critical damping (`dampingRatio = 1.0f`).
   - `IosMenus.kt` & `IosCascadingMenu.kt`: Morphing glass context menus with cascading submenus.

4. `:glasmio-scaffold` (`io.github.neoruaa.glasmio.scaffold`)
   - `GlasmioNavigationScaffold.kt`, `GlasmioScaffold.kt`, `AppBar.kt`: Coordinate `LiveGlassHost`, collapsible large-title `GlasmioTopBar`, floating search bar transition (`GlasmioSearchTransition`), and bottom tab dock.
   - `HeaderMotion.kt`: Exact damped oscillator (`HeaderTrack`, `HeaderPulse`) with SwiftUI `Spring(duration:bounce:)` integration (`geometry = Spring(0.416s, 0.25)`, `up = Spring(0.292s, 0.5)`).
   - `SheetMotion.kt`: Non-bouncy `Stiffness = 300f` sheet spring and velocity/delta direction resolver.
   - `navigation/IosNavigationMotion.kt` & `IosSwipeBack.kt`: Full-width edge-swipe back transition with parallax underlay dimming.

5. `:glasmio-preference` (`io.github.neoruaa.glasmio.preference`)
   - `Preference.kt` & `PreferenceDialogs.kt`: `GlasmioPreferenceEntry`, `GlasmioSwitchPreference`, `GlasmioListPreference`, `GlasmioEnumListPreference`, `GlasmioEditTextPreference`, and `GlasmioPreferenceGroupTitle` built on `GlasmioGroupedList` rows and glass modal dialogs.

6. `:glasmio-icons` (`io.github.neoruaa.glasmio.icons`)
   - `GlasmioIcons.kt`, `SfSymbol.kt`, `SfSymbolCatalog.kt`: Semantic symbol name resolver (`GlasmioIconResolver`) with Apache-2.0 fallback vector icons (`MaterialGlasmioIconResolver`) and optional host symbol font support.

## 2. Integration Paths for Snoozy

Snoozy (`D:\OWN_PROJECTS\SNOOZY`) is currently an Expo SDK 54 / React Native 0.81 TypeScript application using Expo Router (`src/app/`), `@rntp/player`, `expo-sqlite`, and `react-native-mmkv`.

There are three ways to integrate Glasmio into Snoozy:

1. **Path 1 (React Native / Expo Port of Glasmio Framework)**:
   - Keep Snoozy's existing Expo/React Native architecture (`src/app/`, `AGENTS.md` rules, TypeScript gates) and port Glasmio's module architecture (`glasmio-core` tokens/recipes/springs, `glasmio-glass` multi-layer `GlassSurface` + specular rims + `reduceTransparency`, `glasmio-ui` buttons/switches/sliders/search/lists/sheets/alerts, `glasmio-scaffold` collapsing headers/tab bar, and `glasmio-preference` settings rows) into `src/components/glass/`, `src/theme/`, and `src/motion/`, while completing the Snoozy v3.0 roadmap.
2. **Path 2 (Hybrid Native Android Glasmio Modules + React Native Bridge)**:
   - Include the actual Kotlin `:glasmio-core`, `:glasmio-glass`, `:glasmio-ui`, `:glasmio-scaffold`, `:glasmio-preference`, and `:glasmio-icons` Gradle modules in Snoozy's Android build and expose Glasmio's AGSL shader-backed `GlassSurface` / Compose views to React Native via an Expo native module, while keeping Expo Router and TypeScript screens.
3. **Path 3 (Full Native Kotlin + Jetpack Compose UI using Glasmio Modules)**:
   - Include all six Glasmio Gradle modules directly in Snoozy's Android build and implement Snoozy's screens natively in Kotlin + Jetpack Compose using `GlasmioTheme`, `GlasmioNavigationScaffold`, `GlassSurface`, `GlasmioTabBar`, `GlasmioTopBar`, `GlasmioBottomSheet`, and `GlasmioPreference*`.
