# Hermes Liquid implementation

Status: in progress. This is a selectable Flutter visual style inspired by
Apple Liquid Glass, not a claim of native iOS 26.6 SDK rendering.

## Current checkpoint — 2026-09-10

The sections below are chronological implementation notes, not a current
release checklist. Their older `source only` / `not yet Web-built` labels
must not be read as the present deployment state. Current evidence is recorded
in `liquid-delivery-plan.md`; the hash and counts below are historical.
Platform guarantees and calibration procedure: `platform-material-contract.md`.

- Published on port 9000: shared blur/tint/lighting, nested material sharing,
  continuous-corner prototype, navigation and chat-control migrations.
- Latest verified release script SHA-256:
  `6b9755441564353a2dab4c961a9ca569b79b5972862bf5790c3b8c722f0ba0bc`.
- Chromium test coverage now includes nonzero corners, moving backdrop pixels,
  interaction light, full ChatScreen fixtures and responsive AppShell fixtures.
  These are behavior/rendering checks, not visual-fidelity approval.
- Continuous corners remain a visual prototype. Two Liquid preview goldens
  differed on the last full run and have not been accepted or overwritten.
- Actual refraction and device-tilt lighting are not implemented. Current
  pointer light is simulated; Flutter Web does not support ImageFilter.shader
  in this installed SDK. No iPhone frame-time or visual acceptance is claimed.
- Existing user appearance preferences remain intact; Classic remains the
  default for a fresh profile.

Next visual checkpoint: obtain a reliably viewable current/target pair for
chat, sessions/home and settings, in light and dark Liquid. Identify whether
the dominant gap is material opacity, layout/hierarchy or motion before
retuning global tokens. Do not substitute further component-count migrations
or passing tests for this whole-page comparison. Continue safe implementation
where source evidence identifies a concrete discrepancy.

## Current acceptance gates (not chronological notes)

1. **Whole-page visual alignment — open.** Capture chat with messages, tools,
   approval and composer; home/sessions; and appearance settings, at matched
   phone dimensions in light and dark. Compare against an identified target,
   not the settings material sample alone. Review hierarchy, glass tint,
   backdrop visibility, edge treatment, spacing and motion together. Target
   screenshots have been requested; existing image-viewer output has not
   provided reliable optical review. Do not retune tokens from its artifacts.
2. **Golden reconciliation — open.** Last full VM run: 1,647 passes, two
   Liquid preview failures (dark 12.59%, light 2.37%). These are intentional
   pending-review gates, not accepted changes. Update a baseline only after
   the rendering is reviewed; never relax tolerance merely to pass. Later
   focused tests do not constitute a newer full-suite result.
3. **Web interaction — partially verified.** Five full-chat Chrome cases
   cover long history, keyboard and composer growth; five approval cases
   cover scoped responses and 2x text. The test-only HTTP leak was fixed.
   Live event delivery and server execution are not verified by fake gateways.
4. **Performance — open.** Stable blur counts and streaming cadence have
   synthetic Chrome coverage. Capture real frame timings on representative
   devices during scrolling, streaming, keyboard changes and overlays, and
   report renderer/device/build mode, p50/p95 and missed-frame counts. No
   current evidence proves the 16.7ms/60Hz target.
5. **Native behavior — open.** The iOS reduce-transparency bridge exists in
   AppDelegate.swift but needs an iOS build and device transition check.
   Pointer highlights are not optical refraction or device-tilt lighting;
   neither native feature is currently implemented or claimed for Web.
6. **Delivery — verified for current source build.** Port 9000 serves the
   release hash above; existing preferences remain untouched. Fresh profiles
   still require choosing Liquid explicitly. No commit/push is implied by
   this UI checkpoint.

Priority: resolve whole-page visual alignment first, then reconcile goldens
and measure device performance. Component fixes remain appropriate when a
concrete defect is reproduced, but cannot close the visual acceptance gate.

## Appearance page header integration (source only)

Standalone Appearance now uses HermesPageScaffold with scrollable content and
760px max content width instead of a separate opaque Scaffold/AppBar. Liquid
therefore uses the shared pinned scroll-owned glass header. Embedded wide
appearance is unchanged. Settings suite: 8 passed including opening Liquid
Appearance, scrolling, pinned visible title and back navigation; preceding
combined settings/theme regression: 30 passed. Analysis and diff checks pass.
Actual backdrop visual review and Web publication remain outstanding.

## Glass control focus follow-up (source only)

Liquid GlassButton now resolves a 2px accent outline while focused and enabled,
distinct from the existing selected border. Resting appearance and Classic
remain unchanged. A Tab/Enter test confirms focus state, ring width, no
resting outline and exactly one activation. Button/preview suites: 13 passed,
existing goldens unchanged; analysis and diff checks clean. Not yet Web-built.
Disabled-state follow-up: selected disabled Liquid controls use a neutral
1px outline, taking precedence over focused styling. A test resolves combined
disabled/focused state and confirms no pressed scaling or callback. Combined
button/preview tests: 14 passed; analysis clean. No Web rebuild yet.

## Latest font/preview delivery

Font editor and preview accessibility changes below are now published,
superseding their source-only labels. Settings-font, glass-alert, preview and
theme suites: 34 passed; analyze and diff checks clean. Release Web build
succeeded; port 9000 HTTP 200, served/built script SHA-256 both
`f09ee64dc35f810ff5f2e122c3d0cf73a1d741dc74a97f3a5308d4ae2c33d874`.
No real font configuration or appearance preference was overwritten. This
was a focused regression run, not a new full-suite or visual acceptance run.

## Terminal font editor material (source only)

Settings font editor now uses GlassAlertDialog. Suggestions, preview, reset,
cancel/save and server identity checks are untouched; Classic still receives
AlertDialog. A shared-editor test verifies editing and action return with
20 rows and a 300px phone keyboard, with Save visibly above the keyboard.
This is component coverage, not an end-to-end font-save UI test. Web
publication and actual visual/device acceptance remain outstanding.
SettingsScreen integration follow-up passes: a fake config starts at Menlo,
opening the font editor produces one blur, selecting Consolas updates input,
Reset clears it, and Cancel leaves the original setting displayed. This test
does not save to a real server. Static analysis and diff checks pass; save
success/failure and connection-switch UI cases remain unverified here.

## Appearance preview accessibility (source only)

Liquid preview backdrop now follows the material's opacity policy: solid
background under reduced transparency/high contrast, instead of a decorative
gradient. Two new tests cover those modes at 320px and 2× text, no blur,
opaque background and working selection controls. Six preview tests pass,
including four unchanged existing goldens. Analysis and diff checks clean.
This is not yet Web-built and does not establish full-page visual fidelity.

## Latest forms/confirmation delivery

This delivery supersedes the source-only labels below for query-scroll reset,
shared confirmations and adaptive form geometry. Full tests: 1,424 passed
(`/tmp/hermes-forms-release-regression.log`); analyze clean; l10n unchanged at
62 candidates. Release Web build succeeded, port 9000 HTTP 200, served/built
script SHA-256 `cd5ca096a0c1092554f31e4cc446d19c1ac0fdd79603a1ff3cd98239586fa7d9`.
AppearanceStore still defaults to Classic; Liquid must be selected in
appearance settings. Existing preferences were not overwritten. Visual
fidelity and native-device acceptance remain incomplete.

## Adaptive form geometry follow-up (source only)

Liquid phone forms delegate IME avoidance to showMobileSheet, keeping the
keyboard gap outside the sampled material. Classic retains interior animated
padding; accessibleNavigation now also suppresses that animation. Wide Liquid
dialogs explicitly disable native elevation/tint/shape to avoid duplicate
chrome around GlassSurface. Theme suite: 22 passed, including phone 390×844
with 300px keyboard, glass bottom <=532, no interior keyboard padding, editing
and saved result. Analysis and diff checks pass. Not yet Web-built.
The phone test now uses 2× text and 20 content rows, scrolls to the final row
after text-entry positioning settles, and verifies Save remains actionable.
Theme suite remains 22 passed. An initial visibility failure was caused by
overlapping text-field auto-scroll and test scrolling; no layout change was
needed after waiting for the editing frame sequence to settle.

## Shared confirmation dialogs (source only)

showHermesConfirmDialog now uses GlassAlertDialog: Liquid shares one rounded
glass alert surface, Classic retains AlertDialog, and routes remain centered.
Existing HermesButton variants and bool outcomes are unchanged. Two tests
exercise confirmation, cancellation, barrier dismissal and destructive variant
in both styles. Combined confirmation/alert/settings-navigation: 7 passed;
analysis and diff checks clean. No real destructive action was performed.
This change is not yet Web-built; terminal font editor is still unchanged.

## Composer suggestion surfaces (published)

Query-scroll follow-up (source only): completion owns a non-persisting scroll
controller, disposed with ChatScreen. Query refresh resets offset to zero.
The 12-file/2× text test now edits the query after reaching the bottom,
verifies the first result is visible, wraps upward and inserts the last file.
Chat suite 25 passed; analysis and diff checks clean. Not yet Web-built.

Latest delivery supersedes the source-only notes in this section: reference
and emoji selection/scroll changes are Web-built and served on port 9000.
HTTP 200; served and built main.dart.js SHA-256 both
`a2f50d94a57a8d9400acd38530a39550c134a148d0af2d6e618e5cfbd9b7ab3f`.
Control screenshot viewing was rechecked and still appears patterned; this
is not usable visual acceptance evidence. No visual parameters were tuned
from that artifact. Latest focused suite is 25 passed, not a new full run.

Subsequent source-only follow-up: reference and emoji rows now use the shared
rounded selection surface and selected foreground, with the current-row key
also driving keyboard scroll tracking. Reference icons match the selected
foreground. Reference logic tests (6) and chat suite (23) pass, including a
new emoji row/material/insertion test; analysis is clean. Long reference/emoji
scroll integration still needs dedicated coverage. This follow-up is not in
the published build below.
Emoji keyboard follow-up: a 2× text test queries the real catalog with :ha,
walks and wraps its result rows, asserts selected-row visibility, then presses
Enter and verifies insertion and panel dismissal. Chat suite: 24 passed;
analysis and diff checks clean. This verifies emoji integration, not long
file-reference scrolling or actual device gestures. No new Web build yet.
Reference keyboard follow-up: the real complete.path request path is exercised
with a 12-file gateway fixture at 2× text scale. Each arrow-selected filename
remains visible; Enter inserts the last file's canonical @file: wire text and
dismisses the panel. Chat suite now has 25 passing tests; static analysis and
diff checks pass. This supersedes the missing long-reference integration
coverage note above, but does not establish large-directory performance or
native gesture/visual acceptance. This follow-up is source-only.

Autocomplete, active recommendations and cron suggestions now share a scoped
24px-radius thick GlassSurface in Liquid. Classic retains HermesGlassCard;
message content and suggestion dispatch are unchanged. Two ChatScreen tests
verify the slash suggestion panel has one blur in normal Liquid and none in
reduced transparency. Combined slash/prompts/quota and suggestion tests: 36
passed; static analysis and diff checks clean.
Cron follow-up: Liquid separates body copy from an OverflowBar action area,
with 12px padding and bodyMedium text. Classic layout is unchanged. A 390px
phone/2× text ChatScreen test verifies actionable create/ignore controls, no
overflow, dismissal and draft preservation. Slash/prompts/quota suite: 21
passed. Other row styling and actual visual acceptance remain to be reviewed.
Slash rows now use GlassSelectionRow with an inset rounded selection fill;
selected title, metadata and icon use onPrimaryContainer, and the inner
ListTile does not paint a second selected background. Existing Liquid tests
assert exactly one selected row and the title foreground. The 21-test suite
and analysis pass. Other completion types still need row-style review.
Keyboard follow-up: slash selection now scrolls its keyed row into view after
arrow navigation, with motion disabled for accessibility preferences. The
completion body uses a scroll view/Column so offscreen keyed rows remain
available for ensureVisible; large-result eager layout cost needs profiling.
A 12-result test walks every row and wraps to the first, checking visibility.
Slash/prompts/quota suite: 22 passed; analysis clean. Reference/emoji keyboard
scroll tracking is not yet included.

Delivery: full regression 1,418 passed (`/tmp/hermes-suggestions-regression.log`),
static analysis clean, localization unchanged at 62 existing candidates.
Release Web build succeeded; port 9000 HTTP 200 and served/built script hash:
`4fc2ce426767bf75af7eb3efbf65cc61993916fb00cc3c0be3f231dda224de81`.

## Composer primary action follow-up (published)

Liquid send/stop/steer control now has a 44×44 resting size and 20px icon
(Classic retains 32px/16px). Liquid pointer feedback scales to .92; both
disableAnimations and accessibleNavigation suppress scaling and its duration.
The existing callback dispatch is unchanged. Two focused tests verify resting
size, normal/reduced-animation pointer feedback and single send dispatch.
Follow-up moves InkWell outside the visual transform, retaining the full
44px hit region during compression. InkWell highlight state drives feedback
instead of pointer-only listeners. Tests now include accessibleNavigation
and assert the gesture target is outside the scaled subtree with unchanged
bounds. Combined composer regression: 37 passed; analysis and diff checks clean.
This change is included in the delivery recorded below.

Attachment follow-up (published): Liquid preview keeps solid content and
adds an inset 24px-radius glass filename/close toolbar in a clipped 28px
dialog. File fallback content scrolls independently. The 2× text test exposed
fixed-height attachment-card overflow; Liquid card height now adds space
based on scaled text. Two tests cover long paths, short viewport, both
transparency modes, scrolling, dismissal and preservation of the attachment.
Combined preview/send/composer tests: 39 passed. Image zoom visual acceptance
and actual-device performance remain outstanding.

Image-path coverage now also verifies InteractiveViewer is retained with its
5× maximum scale, has no descendant blur, and closes without removing the
attachment. Preview/send/existing visual regression: 11 passed; analyze clean.
Release Web build succeeded; port 9000 HTTP 200, served/built script SHA-256:
`460e0ca644d59d8684418cc908c30c94cd0788bd6891da689cf451e2a6826a07`.

## Handoff platform picker follow-up (published)

Liquid handoff platform selection now uses showMobileSheet's shared glass
material, rounded selection rows and a bounded scrolling list with a fixed
title/close control. Classic still uses SimpleDialog. Platform filtering and
the pre-handoff session identity guard remain at the caller; the request,
progress and cancellation implementation is extracted without changing its
operations. Two picker tests cover 20 platforms, last-row selection, dismissal,
390×600 with safe areas and 2× text, normal/reduced transparency. Combined
picker, handoff flow and composer status tests: 8 passed. Actual visual/device
acceptance remains outstanding.

The empty-platform and progress alerts now share GlassAlertDialog: one
28px-radius thick material, transparent borderless route chrome, scrollable
title/content and separate action area. Classic retains AlertDialog. Four
additional tests cover both styles/transparency modes, 2× text, long Liquid
content, scrolling, explicit cancellation, and blocked barrier/system-back
dismissal. Combined alert/picker/flow/composer coverage: 12 passed; static
analysis and diff checks passed.

Delivery verification: full regression 1,407 passed, log
`/tmp/hermes-liquid-handoff-regression.log`; analyze clean; localization
unchanged (62 existing candidates, baseline 62). Release Web build succeeded.
Port 9000 returned HTTP 200; served/built main.dart.js SHA-256 matched:
`d80a302aac6ae36464849bc62699cdb955bb71f7106940ab904e3c8ca65227da`.
This publishes both the platform picker and glass alerts described above.

## Slash-command help follow-up (published)

Liquid command help now uses one 28px-radius GlassSurface inside transparent
dialog chrome, bounded to 480×560 with 12px horizontal exterior margins.
The title and close action stay outside the scrolling command list; route
constraints reduce its height on short screens. Classic keeps AlertDialog.
Four widget tests pass, covering both styles and transparency settings;
Liquid uses a 390×600 viewport, top/bottom safe areas, and 2× text scale,
checking bounds, overflow, blur count, scrolling and dismissal. Actual visual
inspection remains outstanding. Combined help, palette, adaptive-menu and
existing visual-golden regression: 25 tests passed. Release Web build
succeeded; port 9000 returned HTTP 200 and served/built main.dart.js matched:
`ae7c8b1f0c6bee65c3be020096d88707167c2916568c998fa19c4d28324b5bc4`.

## Current delivery verification — September 9, 18:13 UTC

- Full `flutter test --no-pub --reporter expanded`: 1,370 passed.
  Log: `/tmp/hermes-liquid-current-regression.log`.
- `flutter analyze --no-pub`: no issues.
- Localization check: 62 existing candidates, baseline 62; no regression.
- Release Web build succeeded; port 9000 returned HTTP 200.
- Served and built `main.dart.js` SHA-256 both:
  `9aabec04c8b3f511e3121bcb42f7cb9095c7fbbf124af06dd9a1248d4dbb0635`.
- Includes stationary wide glass menus, pre-route safe-area height capture,
  context popover, and consistent accessible-navigation button feedback.
  The unreviewed directional-rim experiment is not included.
- Existing preview goldens pass without replacing baselines in this check.
  Tests do not establish actual-page visual fidelity or real-device performance;
  image inspection remains unreliable and user screenshots/reference requested.

## Subsequent wide-menu integration — September 9

Phone search follow-up (source only): Liquid command palette now shares the
rounded glass surface on phone, with 12px exterior spacing and keyboard
avoidance outside the material. It shrink-wraps short results rather than
forcing full-screen height. Classic retains full-screen behavior. The overlay
suite passes 8 tests, including 390 × 844, 47px top safe area, 300px keyboard,
normal/reduced transparency, exact lateral bounds, search and close actions.
Follow-up: the phone cases now run at 2× text scale, assert no overflow,
and verify the close control and filtered result remain hit-testable. Liquid
search explicitly disables inherited form fill and enabled outline so the
field shares its parent glass material; a primary underline retains visible
keyboard focus. The keyboard action is Search. Overlay suite: 8 passed;
AppShell accessibility, adaptive menu, and existing visual goldens: 17 passed.
Analysis and diff whitespace checks passed. These checks do not establish
actual-page visual fidelity or native-device acceptance.
This phone-search follow-up is now included in a successful release Web build;
port 9000 returned HTTP 200 and its served script matched the build SHA-256:
`524de382df7c162a5ea68a41b7b92e11cec6116e0343989ff3d59ac07fe91625`.

Latest delivery, 18:55 UTC: full suite 1,395 passed
(`/tmp/hermes-liquid-contrast-release.log`), analysis clean, localization
unchanged at 62. Release build succeeded; port 9000 HTTP 200, served/built
script SHA-256 `6cd2121600b263127c92a977ea9172b2f7018495fe7967919f944059c17cadc1`.
Includes rounded palette rows, corrected Liquid container foregrounds and
selected free-model labels. Earlier source-only notes for these changes
are superseded. Visual fidelity/native-device acceptance remains incomplete.

Model pricing follow-up (source only): selected Liquid free/discount labels
use onPrimaryContainer rather than their independent tertiary color. Paid
prices already inherit ListTile foreground. Unselected and Classic labels
retain their previous styling. Model/selection contrast suites passed 18
tests, including a real selected-model Free label color assertion.

Contrast correction (source only): measured all four Liquid light themes'
primaryContainer/onPrimaryContainer pairs at roughly 1.29:1 because the
theme reused the accent-button foreground. Liquid now retains generated
container foreground colors for primary/secondary containers; Classic keeps
its previous overrides. Eight primary-container contrast tests (four palettes
times two brightness modes) meet 4.5:1. Contrast, palette overlay and existing
preview suites passed 18 tests; analysis passed. This is token-pair evidence,
not a complete composited-image or all-control contrast audit.

Selected palette-row foreground now uses onPrimaryContainer for title,
subtitle and leading icon in Liquid, matching its primaryContainer fill.
Classic/unselected colors remain unchanged. The 6-test overlay suite passes
with explicit selected-title color assertions in normal and reduced
transparency. This verifies token pairing, not all-palette contrast ratios.
Not yet in served build.

Palette-row follow-up (source only): Liquid result rows now share
GlassSelectionRow's 18px rounded selected fill, exterior row spacing and
56px minimum height. Classic keeps its edge-to-edge highlight. No per-row
blur is introduced. Combined shell/overlay tests passed 10; the extended
6-test overlay suite asserts row count, exactly one selection and minimum
height, while retaining keyboard traversal and asynchronous session opening.
Actual-page visual review remains outstanding.

Latest delivery, 18:43 UTC: full suite 1,379 passed (log
`/tmp/hermes-liquid-latest-tests.log`), analysis clean, localization baseline
unchanged at 62. Release Web build succeeded, port 9000 HTTP 200, served and
built script SHA-256:
`d3963d181c61ea5bea7f251ba70cd7287e8695afcf3b732a1fb2d74d0d066718`.
Includes the desktop toolbar, palette glass/keyboard avoidance/navigation,
and Flutter accessibility-state changes. Subsequent source-only notes below
are historical relative to this build. UIKit bridge compilation/device
validation and actual-page visual fidelity are still outstanding.

Keyboard navigation follow-up: palette arrow keys now ensure the selected
row is visible after layout. The bounded search result set is built as a
shrink-wrapped Column in a scroll viewport, allowing actual row geometry
instead of assumed fixed heights (at the cost of eager construction).
The overlay suite passes 6 tests including traversal to the last result
and wraparound to the first above a 300px keyboard in both transparency
modes. Combined shell/overlay tests passed 10. This affects Classic too;
large-catalog performance remains to be profiled. Not yet in served build.

Palette navigation coverage: both Classic and Liquid now run the delayed
session-resume lifecycle test at 1000 × 700. Liquid asserts its glass panel
is mounted before selection; after overlay unmount and asynchronous resume
completion, ChatScreen is pushed and exactly the target session is resumed.
All 6 overlay tests pass. This uses a fake SessionStore, not a live backend;
error-path coverage remains Classic-only.

Palette keyboard follow-up (source only): Liquid desktop applies keyboard
avoidance outside its glass, leaving 24px bottom spacing and 12px lateral
spacing. The overlay suite passes 5 tests including 1000 × 700 with a
300px keyboard, an unresized host, searchable/hit-testable session result,
and normal/reduced-transparency material. Existing lifecycle tests still
exercise Classic; full Liquid selection/routing coverage remains open.

Command-palette follow-up (source only): desktop Liquid now uses a shared
28px GlassSurface with transparent Material, replacing its legacy card.
Classic and mobile retain their prior surface. The actual-shell search test
asserts one backdrop inside the palette and successful open/Escape dismissal;
all 4 shell tests and analysis pass. Search result selection, keyboard/IME
constraints and opaque fallback still need palette-specific integration tests.

XL toolbar follow-up (source only): Liquid replaces the 48px solid top
strip with a 56px glass panel, 28px corners and 12px top/side exterior
spacing, inside SafeArea. Search becomes a 44px-high rounded control.
Classic and action callbacks are unchanged. Shell/mobile/responsive tests
passed 6 tests; extended shell assertions passed all 3 tests including
exact toolbar bounds in Arabic at 1.6x text. Analysis passed. Actual-page
visual comparison and toolbar-action interaction coverage remain open.
Subsequent actual-shell coverage verifies the toolbar search hit target is
at least 44px high, opens CommandPaletteStore's overlay, and Escape closes
it with the trigger still hit-testable (1280px, Arabic RTL, 1.6x text). All
4 shell tests pass. Notification/approval toolbar actions are not covered
by this new search test. CommandPalette still uses legacy HermesGlassCard;
its material should be reviewed next rather than assuming toolbar work
already modernized the overlay.

Native accessibility follow-up (source only): iOS AppDelegate exposes
UIAccessibility.isReduceTransparencyEnabled and its change notification
through hermes.accessibility. AppearanceStore queries on startup/resume
and combines system state with the persisted app preference using OR; main
passes the effective value into both themes. Missing/older bridges fall back
without changing preferences. Mock-channel plus theme suite: 22 passed;
analysis passed. Swift compilation, real notifications and lifecycle timing
still require Xcode/device validation. Web does not register this bridge.
Subsequent revision guards prevent delayed startup/resume snapshots from
overwriting newer notifications, and malformed notifications are ignored.
Mock-channel/theme coverage now passes 23 tests including an explicitly
delayed false snapshot arriving after a true system event. Native validation
remains outstanding; these changes are not in the served Web build.
The bridge fixture now mounts a ListenableBuilder, themed MaterialApp and
real GlassSurface: simulated system changes remove/restore BackdropFilter,
while the persisted local override keeps it absent. All 3 bridge tests pass.
This proves Flutter material propagation in the fixture, not the production
root wiring end-to-end or actual UIKit notification delivery.

Delivery update: the wide-navigation and menu changes described below are
now included in a successful release Web build. Port 9000 returned HTTP 200;
built and served script SHA-256 both equal
`d56a61fc0bbb33ab138e1f7e478d01961fd2832cec7d2145676d50279eaab399`.
The final targeted shell/menu/responsive/preview run passed 19 tests and
analysis passed. The earlier “not yet built” notes below are historical.

Wide navigation follow-up (not yet built): Liquid tablet rail and XL side
navigation now sit in safe-area-aware floating glass with 12px exterior
spacing and 28px corners. Their adjacent full-height divider is omitted;
Classic retains its original structure. Responsive/mobile/accessibility
suites passed 5 tests; the extended shell suite passed 2 tests including
explicit panel bounds at 900/1280 widths in Arabic with 1.6x text. Static
analysis passed. Actual-page visual review remains outstanding.
Liquid tablet NavigationRail now enables its native internal scrolling when
height is constrained. The shell suite passes 3 tests including 900 × 320,
2x text, Arabic RTL and a hit-testable final destination after scrolling;
900 × 480 is also covered in the style/layout matrix. Pending-request
coverage was added: its IconButton is hit-testable in the short layout.
Liquid pins it below the scrolling destinations. Testing the inner Badge
icon itself was not a valid button-hit-target assertion and was replaced
with the enclosing IconButton. Approval-response routing is not tested here.

After the 18:13 build, adaptive menus also cap their internal glass viewport
to the caller's `constraints.maxHeight`. The 30-item test now exercises a
240px cap alongside top/bottom safe areas; pointer and keyboard traversal
preserve that exact panel height and can select the last item. All 8 adaptive
menu tests passed. This subsequent change is not yet in the served build.
The follow-up also preserves PopupMenuTheme position and inner padding,
with explicit widget values taking precedence over theme values and Liquid
defaults used last. The adaptive suite passes 9 tests including themed
`over` positioning with zero offset and 18px inner padding.

Shared material experiment: a directional rim was implemented and passed
foreground/interaction checks, but changed 1.17% of each Liquid preview
(dark 1,917 pixels, light 1,912 pixels). Both Classic previews passed.
Image inspection remained unreliable, so the unreviewed rim was withdrawn
without replacing golden baselines. Existing specular treatment is retained;
the added hit-target/transparency regression coverage remains. A reliable
actual-page visual review is required before further material tuning.

Liquid adaptive menus now use one GlassMenuEntry material on wide layouts,
with transparent native route chrome, six-pixel inner spacing and an outline
below the trigger. The default anchor intentionally no longer centres the
selected row on the trigger; selection is highlighted inside the panel.
Explicit caller positions/offsets and Classic menu behavior are retained.
The original entries retain checked state, disabled actions and callbacks.

Focused adaptive-menu, glass-menu and chat minor-parity tests passed 31 tests;
an additional long-menu test then passed with the full 8-test adaptive suite.
Coverage includes edge containment, disabled items, selection, Escape,
scrolling to action 30 in a 900 × 600 viewport, reduced-transparency material,
and a real ChatScreen fixture invoking session.compress from the glass context
popover. These are interaction/layout checks, not visual acceptance.

The subsequent stationary-menu update bounds the material to the viewport
(accounting for MediaQuery padding/insets and the native eight-pixel route
margin) and scrolls entries inside it. Short menus still shrink-wrap. The
three focused suites now pass 32 tests. The 30-item test checks unchanged
glass bounds through pointer scrolling and 29 ArrowDown transitions, with
the final item visible and selectable by Enter; static analysis also passes.
The long-menu fixture additionally passed with 47px top and 34px bottom
safe areas: bounds stay within y=55..558 in a 600px viewport. Available
height is captured before opening the route because Flutter strips safe-area
padding from the descendant MediaQuery.
Native-device visual/performance review and unusual display-feature/custom
route constraints remain unverified.

## Historical verification — September 9, 17:40 UTC

- Full `flutter test --no-pub --reporter expanded`: 1,357 passed.
- `flutter analyze --no-pub`: no issues.
- Localization check: no regression, 62 existing candidates (baseline 62).
- `flutter build web --release --no-pub --no-wasm-dry-run`: succeeded.
- Port 9000 returned HTTP 200; served `main.dart.js` matched the build SHA-256:
  `e3273f1c0de82fc4801a036dfbed5c50be80a739ff96f9ab2b028d9377225212`.
- This build includes keyboard-safe Liquid menus, shared selection rows,
  page/chat environments, phone chat header underlap with opaque fallback,
  conversation search and button press feedback. Tests/build delivery
  do not prove full visual or native-device
  acceptance; remaining requirements below still apply.

## September 9: scroll-owned compact headers

Subsequent changes connect default shared pages and both phone/wide chat
Scaffolds to `GlassEnvironment`. Standalone pages own the background; nested
pages reuse the outer field. Explicit page backgrounds remain authoritative,
and accessibility fallbacks keep an opaque base. Liquid phone chats with
messages now extend beneath the compact app bar when search, voice errors
and recovery banners are absent. The list owns the matching top scroll inset.
Wide chat and banner/search states retain the non-overlapping layout.
Reduced transparency and system/app high contrast also disable phone
underlap: opaque headers must not consume readable transcript area. Actual
ChatScreen tests cover reduced transparency and system high contrast.

Liquid conversation search uses GlassSearchField with keyboard submission,
clear action and focus outline; Classic keeps its original field. Search
result counting and navigation callbacks remain unchanged.
Below 600px of available width, Liquid search separates its full-width input
from the result navigation row. A real ChatScreen test at 390 × 844, 47px
top safe area, 2x text and 300px keyboard inset verifies input width, clear
behavior and a reachable next-result button above the keyboard. The full
chat composer fixture suite passed 34 tests after this addition. This
two-row layout is included in the 17:40 Web build noted above.

A real ChatScreen fixture with 20 messages verifies first-message visibility
at the top, scrolling behind the header, and restoration after opening and
closing search at the top. It passed with zero and 47px top safe areas.
The fixture also checks that a 600px mid-history scroll offset and a message's
screen position are restored after opening/closing search with a 47px safe
area. Existing history locator, streaming visibility, scroll controller and
performance guard suites passed 14 tests. Those existing suites are not
Liquid-underlap-specific: streaming and pagination underlap still need
specific coverage. This is layout evidence, not visual acceptance.
The long-history test additionally runs Liquid dark at 390 × 844 with 25
variable-height turns and tool calls: it reaches the final scroll extent
without a drag, with the last answer between the app bar and composer.
The test's existing real-device frame-scheduling caveat still applies.

Model, workspace, profile and reasoning selectors share `GlassSelectionRow`
for rounded selected fills and minimum 56px rows. The profile/reasoning
layout retains wrapping captions. Model refresh/edit controls use GlassButton
only in Liquid. Its icon scales on press without shrinking the hit target;
reduced motion and accessible navigation disable this scale feedback.

Liquid compact pages using `HermesPageScaffold(scrollable: true)` now place
their pinned header inside the scroll view. Content starts below the header
and passes behind its bounded backdrop when scrolled. This applies to the
credentials and provider configuration pages; non-scrollable pages and
Classic retain their existing layout. No per-row filters were introduced.

The focused theme and responsive shell suite passed 18 tests, including
content crossing the header, stationary titles, working header actions and
last-row reachability. These are layout/interaction checks, not visual
acceptance or device performance evidence. Earlier verification counts below
are historical, not a certification of the current complete worktree.

## Implemented foundation

Shared Liquid sheets, phone action menus and phone/tablet request routes now
leave 12px exterior space around the glass outline. Request routes own
keyboard avoidance outside the material; wide Dialog already handles its
own view insets. Non-embedded Liquid request content scrolls when constrained,
fixing long-text overflow with 2x text and an open keyboard. The request suite
passed 26 tests, including phone long content, wide short-content shrink wrap
and wide long-content scrolling to the close action. These route updates are
included in the 17:40 Web build recorded above.
Subsequent request-route safety work (not in that build) enables top/side
safe-area avoidance and places the bottom system padding outside the glass.
The request suite now passes 27 tests. Phone long-content cases verify exact
bottom positioning both with a 34px gesture inset and no keyboard, and with
a 300px keyboard and zero remaining bottom padding; both also use 47px top
and 20px side safe areas with 2x text.
Shared sheets and phone menus now also place the bottom safe area outside
their glass. Shared sheets remove that padding from the content context only
when `useSafeArea` is true. Two route tests verify both the outer panel edge
and the builder's received padding, including the opt-out case; the theme
suite passes 21 tests. These changes are not in the 17:40 Web build.

- Shared material parameters are centralized in HermesGlassTokens. Translucent
  light/dark surfaces use restrained shadows; opaque surfaces omit shadows.
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

## Historical verification (superseded by subsequent checks)

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

### Screenshot evidence limitation (September 9)

The current image-viewing path displays patterned artifacts even for the
plain HTML control capture `/tmp/hermes-browser-control.png`. Independent
PNG decompression and scanline unfiltering found a 390 × 844 RGB image with
325,295 pure-white pixels out of 329,160 (~98.8%); background samples at
(0,0), (100,400), and (300,800) are white. A JPEG conversion using FFmpeg
also appeared patterned in the image viewer. This does not establish which
part of the viewing path is faulty, but the displayed artifact is not usable
evidence of an app rendering defect. Do not tune Flutter rendering to it or
claim full-page visual acceptance from these captures. Obtain independently
viewable screenshots before evaluating visual fidelity.

Phone adaptive menus now keep keyboard padding outside their Liquid surface;
the whole material boundary remains above the IME, including in RTL with
2x text. The five-test adaptive menu suite and static analysis passed.

Liquid reasoning options now use borderless rows within the shared sheet,
a rounded selected fill and checkmark, and a wrapping selected caption.
Two tests cover selection in dark mode with RTL, 2x text, and both normal
and reduced transparency. Classic retains its existing outlined rows.

### Remaining acceptance work

- Validate light/dark visual references and component states with screenshots.
- Extend content beneath floating navigation with correct scroll padding and
  edge scrims; avoid blur sampling only an empty scaffold background.
- Migrate large-title headers, wide navigation, anchored popovers, model and
  workspace selectors and feature-specific toolbars.
- Review home, sessions, tasks, agents, settings, files, Git, terminal and
  previews against the shared visual hierarchy.
- Add grouped glass controls, press/morph feedback and reduced-motion behavior.
- Validate the implemented iOS reduced-transparency bridge with Xcode and
  hardware. AppDelegate publishes UIKit changes through hermes.accessibility;
  AppearanceStore combines system state with the app preference and main.dart
  uses that effective value. Dart mocks do not verify native compilation.
- Validate keyboard, back gestures, inline approvals and streaming on device.
- Profile Web and iPhone rendering before considering enhanced refraction.
- Add interactive component showcase, goldens and integration coverage.
- Run full analyze/tests/l10n and release builds, then publish updated Web.

### Keybind settings follow-up

Standalone keyboard-shortcut settings now use HermesPageScaffold with a
scroll-owned pinned Liquid header and a 760px content limit. A non-scrolling
Column gives the page ownership of scrolling; embedded settings retain their
ListView. Shortcut capture uses GlassAlertDialog while Classic retains the
standard AlertDialog. Four focused widget tests pass across both styles and
both embedding modes at 390px width, RTL and 2x text, including capture and
persistence of Ctrl+K. The 15 shared alert/foreground-pixel tests, static
analysis and diff whitespace check also pass. This is layout and interaction
evidence, not full-page visual fidelity or native iPhone acceptance.

### Anchored menu selection follow-up

Wide Liquid popup items now share GlassSelectionRow with sheet selectors:
18px clipped corners, inset selection and selected-state semantics, without
per-row backdrop filters. Dividers/custom entries remain unchanged. The
11 menu/adaptive-menu tests pass, including long-menu scrolling, disabled
items, keyboard navigation, RTL, 2x text and reduced transparency. Selection
semantics are explicitly checked; static analysis passes. Full-page visual
acceptance remains outstanding.

### Motion accessibility follow-up

Motion follow-up: wide navigation now respects accessibleNavigation as well
as disableAnimations. Shared Liquid selection rows use the 120ms feedback
token and zero duration for either accessibility flag. Two shell interaction
tests verify immediate collapse/expansion; four row tests cover all flag
combinations, selected fill and no additional blur. The eight shell/menu
tests pass. This does not certify platform-wide transition behavior.

### MCP request form follow-up

MCP request configuration now uses GlassAlertDialog: Liquid gets the shared
bounded material, scrollable form and fixed actions; Classic keeps AlertDialog.
The 28 request-store/sheet tests pass, including a 12-secret-field form at
390px width, 2x text and 300px keyboard inset. The last field is reachable,
cancel remains above the keyboard, cancellation issues no install call and
preserves the pending request. This does not establish backend install or
native keyboard acceptance.

## Invariants

About page-shell follow-up: standalone About now uses HermesPageScaffold
with a scroll-owned Liquid header and 760px content limit. Its body is a
Column owned by the page scroll view; embedded About keeps its ListView.
Eleven About/settings tests pass, including the pinned-header branch and
large-text performance-dialog interaction. Analysis passes. This establishes
the page architecture, not actual browser backdrop pixels or visual fidelity.

Search interaction correction: the previous focus-preservation test did not
assert focus after clearing. Adding that assertion reproduced a failure in
both styles after search submission. GlassSearchField now owns a fallback
FocusNode and refocuses after clear, preserving external node ownership and
custom clear callbacks. Three tests pass, including no duplicate onChanged
for custom clear; analysis passes. Native keyboard behavior remains unverified.

Large-text grouped rows now remove title/subtitle line caps when the scaled
14px reference exceeds 18px, allowing the enclosing settings scroll view to
own the increased height. Normal-size rows remain compact. Fifteen adaptive
UI/settings/About tests pass, including LTR/RTL 2x-text wrapping and tapping.
The installed Flutter Divider already uses directional start/end margins;
no manual RTL inversion was added. Analysis passes.

Nested action-group follow-up: GlassActionGroup inside GlassSurface now
shares its parent tint, lighting and shadow, retaining only rounded clipping.
Standalone groups retain the full glass material. This avoids multiplying
thick fills while preserving separate surfaces elsewhere. Four tests cover
nested/standalone and reduced transparency, one material/highlight layer and
44px actionable controls. Thirteen group/preview/composer tests pass with
unchanged preview goldens; analysis passes. Actual-page visual review remains
required before treating this as sufficient material fidelity.

About/interaction follow-up: performance snapshots use GlassAlertDialog.
Actual About-page tests uncovered a framework warning: grouped ListTiles
painted ink below the group's opaque decoration. HermesGroupedList now
provides a transparent Material inside that decoration, without extra blur
or palette changes. Sixteen About/settings/preview tests pass, including
large-text snapshot close/copy reachability and unchanged preview goldens.
Copy reachability is tested, not system clipboard delivery. Analysis passes.

Short-viewport correction: the file create-type chooser reproduced a 24px
RenderFlex overflow at 390x400, 2x text and a 200px keyboard inset. Replacing
its non-scrolling Column with a shrink-wrapped ListView fixes the regression
and keeps scrolling inside the shared glass panel. The seven file tests pass
with this new viewport transition; analysis passes.

Phone navigation follow-up: Liquid NavigationBar uses the 120ms shared
feedback duration; disableAnimations or accessibleNavigation sets duration
to zero. Classic retains the framework default unless accessibility opts
out. Eight shell tests pass, including phone destination switching with
normal and accessible navigation; static analysis passes. This is not a
visual or native-device acceptance result.

File actions follow-up: create-file, create-folder and rename dialogs use
GlassAlertDialog; the create-type chooser uses showMobileSheet. Delete
confirmation already used the shared confirmation surface. Seven file-page
tests pass, including new file/folder dialog tests with 2x text and a 300px
keyboard inset, plus picker and unsaved-editor guards. Name validation and
write calls are unchanged; new tests exercise cancellation, not backend writes.

Selected foreground follow-up: GlassSelectionRow now provides matching
onPrimaryContainer defaults for text, icons, selected ListTiles and popup
labels. Explicit child styles remain authoritative; disabled popup labels
retain their inherited disabled style. Tests no longer manually assign
ListTile selectedColor, and actual opened-menu tests cover all four accents
in both brightness modes. The 30 contrast/menu/motion tests and static
analysis pass. This is color-policy evidence, not screenshot acceptance.

### Whole-suite verification after shared-material changes

The current worktree passed `flutter test --no-pub`: 1,448 tests in about
88 seconds (log: `/tmp/hermes-liquid-current-regression.log`). This includes
the directional edge, menu selection, reduced-motion navigation, shortcut
settings and MCP request form changes. Localization check reports no new
regressions (62 existing candidates, baseline 62), and diff whitespace check
passes. Port 9000 returns HTTP 200; no production source changed during this
verification pass, so the previously published release remains current.
These results cover automated behavior, not full-page visual fidelity,
native refraction, physical iPhone rendering or device performance.

Classic remains available. Conversation text, code, diff and terminal content
remain readable solid surfaces. No new per-message backdrop filters.
Approval ownership, draft preservation and streaming revisions are unchanged.
Native iPhone performance and gesture results require macOS/Xcode and hardware;
Flutter widget tests alone cannot certify them.
