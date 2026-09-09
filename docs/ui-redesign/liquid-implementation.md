# Hermes Liquid implementation

Status: in progress. This is a selectable Flutter visual style inspired by
Apple Liquid Glass, not a claim of native iOS 26.6 SDK rendering.

## Implemented foundation

- Shared material parameters are centralized in HermesGlassTokens; dark and
  opaque surfaces use borders rather than shadows.
- Wide adaptive form dialogs use bounded glass, scrollable editing content
  and wrapping actions. Phone form inset animation respects reduced motion.
- Model/workspace/profile phone selectors inherit the shared sheet material;
  anchored wide selectors and feature-specific surfaces still need review.

- Classic/Liquid selection is independent of the existing accent palettes.
- Style and reduced transparency are persisted by AppearanceStore.
- GlassSurface clips backdrop blur, applies tint and a highlight border, and
  falls back to opaque surfaces for app/system high contrast.
- Phone navigation, chat composer, chat header, shared compact page headers
  and phone action menus consume the style.
- Sheet/dialog corner treatments adapt without changing request routing.
- Appearance labels exist in all five locales.
- Composer selectors use shared glass action-group material with accessible
  44px icon-button targets, selected states and reduced-animation timing.
- Nested GlassSurface widgets reuse the ancestor backdrop instead of adding
  another blur pass. Content tint and clipping remain local.
- GlassSurface adds a restrained directional specular wash only for translucent
  states; opaque/high-contrast surfaces remain visually deterministic.
- A repository audit confirms BackdropFilter is limited to shared navigation,
  chat chrome and request surfaces; conversation content has no per-message
  blur layers.

## Current verification

- Web release build completed successfully after adding the interactive
  AppearancePreview in settings. This is not yet a full visual acceptance.
- Latest analysis passed; theme/menu/responsive-shell targeted suite: 11 passed.
- Full Flutter regression suite passed 1,314 tests after the menu assertions and
  appearance goldens were added.
- Localization check remains at the existing 62-candidate baseline.
- Wide native popup menus retain their standard interaction and now use Liquid
  radii/shadow rules; full bounded backdrop rendering is still outstanding.
- Theme-level `MenuStyle` now applies Liquid translucent tint, larger control
  radius and zero elevation for dark/high-contrast/reduced-transparency states;
  the native anchored popup remains the interaction and positioning authority.
- Added four appearance-preview golden baselines (Classic/Liquid × light/dark)
  plus interaction assertions; theme tests now assert concrete popup radius,
  alpha and opaque fallback values.
- Phone AppShell extends the body behind the floating Liquid navigation. Home's
  scrollable content adds Liquid-only bottom extent so its final row can be
  brought above the navigation; Classic keeps the previous non-overlapping
  safe-area behavior. A dedicated widget test covers the final-row invariant.

- Large-title sliver headers now use the shared glass material and edge fade.
- Approval detail dialogs/sheets consume glass without changing dismissal or
  response rules. Phone navigation owns its exterior bottom safe area.
- Responsive shell coverage runs both styles at phone/tablet/desktop widths
  in Arabic with increased text scaling; the latest focused shell suite passed.

- Static analysis passes after shared controls were added.
- Targeted theme, composer alignment, mobile shell, adaptive UI, request store
  and model picker suites have passed; the complete Flutter suite has also
  passed 1,309 tests.
- New coverage exercises nested-blur sharing, actual control activation and
  a long Liquid sheet with keyboard insets, RTL and 2x text scaling.
- These checks are not a substitute for visual or device performance review.

## Required remaining work

- Validate light/dark visual references and component states with screenshots.
- Extend content beneath floating navigation with correct scroll padding and
  edge scrims; avoid blur sampling only an empty scaffold background.
- Migrate large-title headers, wide navigation, anchored popovers, model and
  workspace selectors and feature-specific toolbars.
- Review home, sessions, tasks, agents, settings, files, Git, terminal and
  previews against the shared visual hierarchy.
- Add grouped glass controls, press/morph feedback and reduced-motion behavior.
- Connect native reduced-transparency changes where supported; current switch
  is an app preference, not an automatic native accessibility bridge.
- Validate keyboard, back gestures, inline approvals and streaming on device.
- Profile Web and iPhone rendering before considering enhanced refraction.
- Add interactive component showcase, goldens and integration coverage.
- Run full analyze/tests/l10n and release builds, then publish updated Web.

## Invariants

Classic remains available. Conversation text, code, diff and terminal content
remain readable solid surfaces. No new per-message backdrop filters.
Approval ownership, draft preservation and streaming revisions are unchanged.
Native iPhone performance and gesture results require macOS/Xcode and hardware;
Flutter widget tests alone cannot certify them.
