# SNOOZY v1.9 → v2.0 → v2.1 plan

Baseline: `cfb3c0d` (v1.8.0, versionCode 8)
Branch: `release/v1.9`

Status: v1.9 and v2.0 are complete and checkpointed in `cdc439c`. The v2.1
device pass found the Library segment clipping and tab-transition flash, so
the v2.1 APK remained provisional. Those findings are addressed by the
v2.2 visual-system pass below. The final audited artifact is `2.2.0` /
versionCode `12`.

## v1.9 — Liquid Glass (version 1.9.0, versionCode 9)

- [x] Add `src/theme/glass.ts` tokens/config (tint, edge, highlight, shadow, blur substitute).
- [x] Add `src/components/glass/GlassSurface.tsx` (layered translucent fill + gradient highlight + edge).
- [x] Apply glass to floating tab bar, mini-player, headers, cards, search field, player controls, sheets, album/artist rows.
- [x] Squircle/continuous corner treatment where supported; rounded fallback on Android.
- [x] Switch tab icons to Ionicons only; keep Feather everywhere else.
- [x] Add accessible swipe actions on existing library song rows (favorite / add to playlist) with menu fallback.
- [x] Keep colors, fonts, four tabs, S mark, wordmark, and all business logic.
- [x] Bump version/build to 1.9.0 (9).
- [x] Typecheck, lint, expo-doctor, release build, device smoke.

## v2.0 — Unified motion (version 2.0.0, versionCode 10)

- [x] Add easing/spring/stagger/screen-preset tokens.
- [x] Add `useMotion`, reduced-motion helpers, animated pressable, staggered reveal.
- [x] Splash-to-home: native splash retained; in-app S/wordmark intro over first frame; no blank/duplicate logo.
- [x] Tab transition + focus-driven content reveal; pill choreography.
- [x] Stack presets for album/artist/error-log/player; preserve Android back.
- [x] Mini-player → player artwork continuity; artwork crossfade; palette interpolation.
- [x] Capped list stagger; animated add/remove layout transitions.
- [x] Animated segmented thumb; spring press feedback; smooth seek fill.
- [x] Sheet content entrance; reduced motion alternatives.
- [x] Measure cold/warm startup, tab switches, scroll, artwork changes; release build.
- [x] Device regression for playback, library, metadata, lyrics, persistence, accessibility.

## v2.1 — Final audit

- [x] Baseline checks: `npx tsc --noEmit`, `npx expo lint`, `npx expo-doctor`.
- [x] Static audit for crashes, leaks, stale callbacks, persistence, edge cases.
- [x] Device smoke of every screen/interaction.
- [x] Fix critical issues, re-run affected checks. The tab crossfade, duplicate
  mini-players, and five-segment Library clipping were fixed in the v2.2 pass.
- [x] Release build and artifact promotion (v2.1 provisional; superseded by v2.2).
- [x] Final report with evidence, remaining bugs, unverified items. The v2.2
  audit is the release report.

## v2.2 — Visual system follow-up

- [x] Semantic palette/glass context and app-wide Light/Dark/Auto, style, accent, backdrop, motion, and haptics controls.
- [x] Shared header, section, list-group, row, and empty-state primitives.
- [x] Immediate tab switches, one hoisted mini-player, and no replaying entrances.
- [x] Five equal Library segments and compact grouped Library/Home/Search/Settings layouts.
- [x] Themed detail screens, player, sheets, and shared controls.
- [x] Signed release build, device verification, and final audit.
- Release: `artifacts/snoozy-arm64-release-v2.2.apk` — 51,870,098 bytes,
  SHA-256 `AED3C60B…C916D10AE`, installed over the existing release.
- Design: [2026-10-23-snoozy-visual-system-v2.2-design.md](superpowers/specs/2026-10-23-snoozy-visual-system-v2.2-design.md)
- Plan: [2026-10-23-snoozy-visual-system-v2.2.md](superpowers/plans/2026-10-23-snoozy-visual-system-v2.2.md)
- Audit: [AUDIT-v2.2.md](AUDIT-v2.2.md)

## Known constraints

- Android has no real backdrop blur; glass is layered translucency, not blur.
- `expo-glass-effect` is iOS-only and is not used on Android.
- No new dependencies.
- v1.1–v1.8 features are the actual baseline; v1.9/v2.0 features do not exist until this plan completes.
