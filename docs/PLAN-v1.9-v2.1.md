# SNOOZY v1.9 → v2.0 → v2.1 plan

Baseline: `cfb3c0d` (v1.8.0, versionCode 8)
Branch: `release/v1.9`

## v1.9 — Liquid Glass (version 1.9.0, versionCode 9)

- [ ] Add `src/theme/glass.ts` tokens/config (tint, edge, highlight, shadow, blur substitute).
- [ ] Add `src/components/glass/GlassSurface.tsx` (layered translucent fill + gradient highlight + edge).
- [ ] Apply glass to floating tab bar, mini-player, headers, cards, search field, player controls, sheets, album/artist rows.
- [ ] Squircle/continuous corner treatment where supported; rounded fallback on Android.
- [ ] Switch tab icons to Ionicons only; keep Feather everywhere else.
- [ ] Add accessible swipe actions on existing library song rows (favorite / add to playlist) with menu fallback.
- [ ] Keep colors, fonts, four tabs, S mark, wordmark, and all business logic.
- [ ] Bump version/build to 1.9.0 (9).
- [ ] Typecheck, lint, expo-doctor, release build, device smoke.

## v2.0 — Unified motion (version 2.0.0, versionCode 10)

- [ ] Add easing/spring/stagger/screen-preset tokens.
- [ ] Add `useMotion`, reduced-motion helpers, animated pressable, staggered reveal.
- [ ] Splash-to-home: native splash retained; in-app S/wordmark intro over first frame; no blank/duplicate logo.
- [ ] Tab transition + focus-driven content reveal; pill choreography.
- [ ] Stack presets for album/artist/error-log/player; preserve Android back.
- [ ] Mini-player → player artwork continuity; artwork crossfade; palette interpolation.
- [ ] Capped list stagger; animated add/remove layout transitions.
- [ ] Animated segmented thumb; spring press feedback; smooth seek fill.
- [ ] Sheet content entrance; reduced motion alternatives.
- [ ] Measure cold/warm startup, tab switches, scroll, artwork changes; release build.
- [ ] Device regression for playback, library, metadata, lyrics, persistence, accessibility.

## v2.1 — Final audit

- [ ] Baseline checks: `npx tsc --noEmit`, `npx expo lint`, `npx expo-doctor`.
- [ ] Static audit for crashes, leaks, stale callbacks, persistence, edge cases.
- [ ] Device smoke of every screen/interaction.
- [ ] Fix critical issues, re-run affected checks.
- [ ] Release build and artifact promotion.
- [ ] Final report with evidence, remaining bugs, unverified items.

## Known constraints

- Android has no real backdrop blur; glass is layered translucency, not blur.
- `expo-glass-effect` is iOS-only and is not used on Android.
- No new dependencies.
- v1.1–v1.8 features are the actual baseline; v1.9/v2.0 features do not exist until this plan completes.
