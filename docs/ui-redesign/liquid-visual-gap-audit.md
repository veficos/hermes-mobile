# Liquid visual gap audit

2026-09-11 preview difference scope correction: current pixel comparison
against retained goldens differs across x16–373/y16–403, not only the old
material region. Light: 136,285/163,800 pixels, 45,916 with channel delta >10,
maximum 238. Dark: 134,689 pixels, 87,750 above 10, maximum 235.
Source diff in appearance_preview.dart confirms Liquid now includes a new
opaque reading plane, sample composer and explanatory notice, and gives the
header an explicit navigation material role. Consequently the current golden
mismatch includes structural/content/layout changes and cannot be explained
as merely small blur/tint drift. This identifies a concrete contributor, not
a per-pixel causal decomposition or approval of the new appearance. Classic
does not enter the added Liquid-only section. Baselines/tolerances remain
untouched; full-page reference review is still required. Measurements used
tool/inspect_preview_pixels.dart --compare on the retained golden and current
test/failures/preview_liquid_{light,dark}_testImage.png.

Current full regression (2026-09-10): after tool/approval reading-plane
changes, the first full run found 1,646 passes and three failures. The extra
failure was an obsolete normal-mode badge assertion requiring white text,
contradicting the earlier contrast-selection change. Replaced that literal
color assertion with measured foreground/background contrast >=4.5:1.
A second complete run finishes in 1:11 with 1,647 passes and two failures,
only Liquid preview dark (12.59%, 20,628px) and light (2.37%, 3,875px).
Log: /tmp/hermes-liquid-current-regression.log. Full analysis before the
test edit and targeted analysis after it pass. Goldens and tolerances remain
unchanged. Production release remains 6b975544...; this checkpoint changes
tests/docs only and does not constitute visual acceptance.

Inline decision reading-plane alignment (2026-09-10): pending and resolved
Liquid request cards now share the continuous control-radius contour and
opaque content backing. Command text uses opaque codeBg, including inside
the glass sheet; action styling and approval semantics are unchanged.
Request/chat VM files pass 56 tests with new pending/resolved shape and
opacity assertions; five Chromium inline cases pass. Five refreshed review
captures pass and targeted analysis is clean. Release built; HTTP 200 and
local/served main.dart.js match at port 9000:
6b9755441564353a2dab4c961a9ca569b79b5972862bf5790c3b8c722f0ba0bc.
No whole-page optical acceptance, live gateway execution or device timings
are inferred from these fixture results.

Tool reading-plane alignment (2026-09-10): Liquid tool groups now use an
opaque surface/code header with RoundedSuperellipseBorder, matching the
continuous content contour without adding blur. The dismiss control is a
standard semantic IconButton with a verified 44x44 minimum; Classic retains
its existing decoration and compact control. Related chat/detail VM files
pass 34 tests; the additional contour/opacity/tap-size assertions pass both
detail cases. Five Chromium inline approval cases pass after the change,
including 320px/2x layouts. Targeted analysis passes. Release rebuilt and
port 9000 HTTP 200 / served script hash match verified:
ea8e0d1f6d10e9cb7c36dc7e09dae2f8e79dff5e227cfb982adb2a8831585d9d.
This resolves a source-level material inconsistency, not optical acceptance
or the outstanding full-suite golden review.

Combined chat review checkpoint (2026-09-10): the review fixture now includes
completed terminal and read_file results before inline approval. Five VM
capture cases and five Chromium approval cases pass; targeted analysis is
clean. At 320x844 with standard text, geometry checks place the tool summary
inside the viewport above approval, with approval above the composer. At 2x
text only approval visibility is asserted after scrolling; simultaneous tool
visibility is not claimed. Refreshed /tmp/chat-*.png artifacts are not goldens
or optical acceptance. The optional dart:io capture helper does not prevent
ordinary Chrome tests from compiling/running. No production UI change.

Chat review artifacts (2026-09-10): opt-in CHAT_REVIEW_DIR exports actual
ChatScreen before inline approval at 320x844. Five captures/tests pass,
including matching light/dark 1x plus light/dark 2x and opaque light 2x.
Run: flutter test --no-pub --dart-define=CHAT_REVIEW_DIR=/tmp
test/chat_webui_minor_parity_test.dart --plain-name 'Liquid ChatScreen inline approval'.
Files: /tmp/chat-light-1.0-false.png and /tmp/chat-dark-1.0-false.png
(other names follow the same brightness-scale-opaque pattern). The fixture
contains messages, approval and composer, not separate tool-result cards.
PNG decoding confirms both dimensions; analysis passes. These are review
artifacts, not goldens or optical approval. Browser compatibility of the new
opt-in capture import still needs revalidation. No production change.

Streaming/material structural guard (2026-09-10): two new Chrome cases put
StreamingInlineContentRenderer behind a fixed GlassSurface. Across fourteen
42ms fake-clock updates, a 5k-character burst reaches its exact tail while
BackdropFilter count remains one (transparent) or zero (opaque). Both Chrome
cases and all nine VM content-guard cases pass; analysis is clean. This is a
synthetic layer/cadence regression guard, not a full ChatScreen benchmark or
real frame-time, GPU, memory, power or 60fps performance evidence.

Navigation count readability (2026-09-10): HermesBadge now selects the
higher-contrast black/white foreground in every mode, rather than only
explicit high contrast. This affects Classic too. Two direct tests verify
default light/dark numeric contrast >=4.5:1 with the 99+ cap; combined with
AppShell accessibility coverage, 14 tests pass and targeted analysis is
clean. This verifies count readability, not whole-page optical fidelity.

Chromium approval timer resolution (2026-09-10): the chat fake API omitted
savedPrompts/providerQuota, allowing GET /api/v1/prompts and
/api/v1/provider/quota to reach the real browser HTTP client. A fail-fast
MockClient isolated those requests and removed the pending timer; explicit
empty domain responses now cover both. Four Chrome inline approval cases
pass without timer draining, and the full 26-case VM file plus analysis
pass. This resolves the test-fixture network leak, not a production approval
bug or live server validation. No production build was required.

Chromium full-chat gate (2026-09-10): all five long-history ChatScreen
cases pass in Chrome, including Liquid light/dark 320px at 2x text, keyboard
and composer growth. Four inline approval Chrome cases reach their business
assertions but fail finalization with a pending 30-second timer. Explicit
widget/store teardown did not resolve it; the timer source remains unknown.
Do not describe browser approval verification as passing or mask this with
an arbitrary timer drain. No production UI change in this pass.

Whole-repository gate (2026-09-10): flutter analyze --no-pub reports no
issues. A fresh complete flutter test --no-pub run finishes in 1:44 with
1,642 passes and two failures, exclusively preview_liquid_dark/light in
liquid_visual_test.dart (12.59% and 2.37% pixel differences respectively).
The complete log is /tmp/hermes-liquid-regression.log. This supersedes older
full-suite counts. It supports regression stability within existing test
coverage, not whole-app visual acceptance, native fidelity or device frame
budgets. Both visual failures remain open; no goldens were replaced.

Shared-material regression gate after dark-shadow removal (2026-09-10):
liquid_visual, glass_action_group, glass_alert_dialog, glass_dock_layout and
attachment_preview_liquid together report 36 passes / 2 failures. Failures
remain the Liquid light and dark preview goldens. Dark now differs at
20,628/163,800 pixels (12.59%), maximum channel delta 16, 174 pixels above
10; bounds x32–357/y169–293. Removing the shadow materially expands the
golden difference and must receive visual review, even though it aligns
with the written dark hierarchy rule. The previous 2.12% dark difference
is historical, not the current result. No golden update or tolerance change.

Material determinism and dark hierarchy (2026-09-10): rerunning the preview
suite produced byte-identical light/dark test PNGs, so the prior mismatch
is reproducible, not observed capture noise. Inspection found GlassSurface
still applying a dark drop shadow contrary to design-system.md. Dark now
uses its existing edge light without a shadow; light retains its shadow.
Eleven corner/interaction tests pass, then three corner tests pass again
with explicit light/dark shadow assertions. This is a specification alignment,
not proof that either golden mismatch is resolved. Target/reference page
screenshots have been requested for whole-page visual alignment.

Interaction-light hypothesis check (2026-09-10): the preview's two light
painters return to their idle state after selection (one new VM test passes).
Eight existing interaction-light tests also pass, including hover exit,
cancel, reduced motion and foreground preservation. The golden comparison
occurs before the first tap. Together these provide no support for a stale
interaction light causing the initial preview golden mismatch. They do not
identify the actual material-difference cause; goldens remain unchanged.

Active terminal branch evidence (2026-09-10): terminal_liquid_surface_test
now supplies a controlled active session and xterm output, mounts the real
TerminalWorkspace, and verifies TerminalView.backgroundOpacity=1 plus an
opaque backing with no shadow in Liquid light/dark. Both VM cases pass.
This closes the earlier active-branch widget coverage gap, not live PTY
connectivity, keyboard interaction or optical acceptance.

Terminal reading-plane follow-up (2026-09-10): the active terminal's outer
backing now uses the same opaque terminalTheme.background as the terminal
view (backgroundOpacity=1), removing a redundant Liquid .82-alpha backing.
Liquid no longer adds the content frame's extra drop shadow; its existing
border distinguishes output from navigation material. Three terminal
accessibility/visual-token tests and source analysis pass, but the offline
accessibility fixture does not enter the active terminal branch. Thus active
terminal rendering and interactive/optical verification remain outstanding.

Preview golden revalidation (2026-09-10): current liquid_visual_test has
four passes and two failures; both Classic goldens and both opaque/large-text
checks pass. Liquid light differs at 3,875/163,800 pixels (2.37%), maximum
channel delta 5, no delta above 10. Liquid dark differs at 3,472 pixels
(2.12%), maximum delta 15, with 17 pixels above 10. Independent PNG decoding
locates both difference bounds at x32–357/y169–288, the material regions.
This narrows the investigation to rendered material differences, but does
not establish their cause or that the current rendering is preferable.
Goldens are intentionally unchanged; do not claim the visual suite passes
or loosen comparator tolerance on this evidence alone.

Queue touch/layout follow-up (2026-09-10): added a 320x844/2x text queue
scenario. Its cancel action is below the initial clipped status viewport,
but scrolling it into view allows deletion. Liquid queue icon actions now
use standard-density 44px minimum button styles (constraints alone measured
40px under compact density). Four final queue cases pass, including an
actual cancel target-size assertion and the scaled deletion flow. The full
15-case file passed before the final button-style adjustment; only the four
queue cases were rerun after that adjustment. No long-queue performance or
whole-page optical acceptance is claimed.

Queue material follow-up (2026-09-10): Liquid's expanded composer status
queue now uses a keyed GlassSurface with the shared control contour instead
of its old .65 solid rectangle and inner border. Classic keeps the original
decoration; nested material policy and accessibility come from GlassSurface.
Fourteen composer/busy-attachment VM cases pass, including queue insertion,
expansion and deletion in Classic, Liquid and opaque modes. The opaque case
asserts zero BackdropFilters. This is not optical acceptance or proof of
large-text queue controls and long-queue performance.

Approval accessibility matrix (2026-09-10): the full ChatScreen approval
test now covers dark 1x, light/dark 2x, and reduced-transparency light 2x at
320px. All four targeted VM cases pass. Each asserts that Allow once is
hit-testable and above the composer, with one correctly scoped response;
the opaque case additionally asserts zero BackdropFilters. This supersedes
the earlier missing large-text evidence for this specific approval action.
Other choices, live delivery and optical fidelity still require validation.

Chat approval integration evidence (2026-09-10): a new real ChatScreen
fixture at 320x844 in Liquid dark sends a user turn through the composer,
injects an owner-scoped pending request plus transcript interaction, scrolls
to its inline action and taps Allow once while the composer remains mounted.
It verifies exactly one approval.respond with rt-1/chat-approval/once and
an empty pending queue. The targeted VM test passes. This uses a fake gateway
and manually inserted event data, so it does not prove live request delivery,
server execution, large-text approval layout or whole-page optical fidelity.
No production change or new Web build was required in this evidence pass.

Full ChatScreen layout follow-up (2026-09-10): expanded the long-history
fixture to 320px / 2x text in Liquid light and dark. This exposed 146px
turn-marker and 36px tool-header horizontal overflows. Flexible marker text
and bounded, wrapping status chips resolve them without shrinking fonts.
Status chips now grow vertically; this shared change also affects Classic.
Five full-screen VM cases pass through initial bottom settling, keyboard,
emoji insertion and composer growth. The visibility assertion targets a new
trailing answer after tool results, not the introductory paragraph above
them. Approval interaction and whole-page optical fidelity remain unverified
by this fixture.

Artifact filter follow-up (2026-09-10): Liquid replaces gesture-only 34px
filters with focusable TextButton capsules, paired selection colors and
44px minimum height that grows with text scale. Classic keeps its existing
filter rendering. Nine sidebar/artifact-state tests pass; five sidebar
cases were then rerun with Enter-key activation in place of pointer taps.
This confirms keyboard selection styling, not filtering against a populated
artifact dataset or whole-page optical fidelity.

Collapsed sidebar follow-up (2026-09-10): Liquid rail selection now matches
the expanded capsule with paired primaryContainer/onPrimaryContainer colors,
44px targets and selected semantics. The rail scrolls independently while
expansion stays pinned. Five VM cases cover Classic, Liquid, opaque, nested
and 2x text, including reaching Logs and reopening at 240px viewport height.
The initial 32–131px reopening overflow was traced to the transient
HermesLoadingState column. It now centers scrollable content instead of
forcing a full-height column; the regression test no longer enlarges the
viewport before reopening. Sidebar and offline/loading suites pass 51 VM
cases. These tests are not evidence of complete short-window support across
all panels or optical/native fidelity.

Live route identification (2026-09-10): isolated Chromium on port 9000,
390x844, stores the Liquid preference and captures a PNG. Activating Flutter
semantics identifies the current page as Connection configuration (Mobile
Server / Direct Gateway / SSH / Connect), NOT chat or the app shell.
Therefore this live capture cannot validate chat/dock hierarchy. The capture
helper now reports route text alongside the screenshot. Preference storage
alone is not rendered-theme proof. The image viewer still displays anomalous
patterns; independent pixel checks are needed before judging colors. No
production UI changes or visual acceptance in this diagnostic pass.

Sidebar selection/browser follow-up (2026-09-10): Liquid tabs now use
horizontal icon/label capsules with opaque primaryContainer selection and
onPrimaryContainer foreground, filled active icons, scaled tab height and
44px collapse controls. The 2x text fixture exposed a 9px overflow in the
embedded logs header; wrapping title/source layout and a horizontally
scrollable source selector resolve it (this header adjustment also affects
Classic). Five VM and five Chromium cases pass for Classic, Liquid,
reduced transparency, nested material and 2x text. They verify blur counts,
capsule shape/fill, collapse size and mock-log selection. They do not verify
optical fidelity, actual server connectivity, or whole-page visual acceptance.

This is a source-based audit, not visual acceptance. The objective remains
an iOS Liquid Glass-inspired whole-app UI, not merely passing widget tests.

Composer expanded material continuity (2026-09-10): Liquid emoji content
previously sat outside either dock material over the underlapping transcript.
It now expands inside the toolbar's existing GlassActionGroup, sharing its
continuous outer contour, tint and bounded blur. An inset divider replaces
the full-width top rule in Liquid only; Classic retains its separate panel.
Nine VM composer/alignment/chat cases pass. Seven Chromium cases cover
320px light/dark and reduced-transparency combinations plus actual-chat
Classic/light and Liquid/light/dark. The emoji tests assert one group surface
and unchanged BackdropFilter count on expansion (zero for reduced
transparency), with insertion, close and scrolling action reachability.
Analysis and diff checks pass. This verifies material ownership and behavior,
not subjective optical fidelity; whole-page visual review remains open.

## Verified implementation boundaries

Unsampled menu readability (source-only, 2026-09-10): default popup, menu
and dropdown themes no longer use alpha-only fills without a backdrop
filter. They retain an opaque elevated surface, as fallback dialogs do;
glass-aware adaptive menus retain their explicitly sampled materials. Forty
VM theme/adaptive-menu cases pass, including wide glass anchoring and action
selection. This is an interim readable fallback, not completion of the
remaining native-style menu migration. Browser publication remains pending.

Fallback modal Web delivery (2026-09-10): all 32 Chromium theme,
confirmation and adaptive UI cases pass after the continuous fallback
dialog/sheet change. Release Web build succeeds and port 9000 serves it.
This supersedes the source-only publication status below; no new optical
acceptance or golden update is implied.

Fallback modal contours (source-only, 2026-09-10): Liquid dialog and bottom
sheet themes now use continuous shapes while retaining opaque backgrounds,
existing border colors/widths and top-only sheet rounding. Classic retains
rounded rectangles. Thirty-two VM theme/confirmation/adaptive tests pass,
including shape and opacity assertions. Browser rendering and publication
remain pending for this change; it is not native visual acceptance.

Selected segmented contrast audit (2026-09-10): sixteen tests cover four
accents, both brightness modes and high-contrast flags. Each composites
rest/hover/focus/press overlays onto the selected opaque background and
checks foreground contrast >=4.5:1; all pass. This is color arithmetic for
selected segments, not captured pixels, focus-indicator contrast, or
unselected text over arbitrary backdrops. No production change is needed
for these checked color pairs. Whole-app visual acceptance remains open.

Segmented keyboard follow-up (2026-09-10): the 320px/2x LTR and RTL
fixtures now send real Tab/Enter events, assert exactly one segment's state
controller reports focus, and verify Enter selects its label's value. Both
cases pass on VM and Chromium; analyze passes. This closes keyboard
activation coverage for the new overlays, not focus pixel contrast or
whole-page visual acceptance.

Segmented state feedback (source-only, 2026-09-10): Liquid segmented
controls now explicitly resolve hover/focus/press overlays from the matching
selected or unselected foreground at .06/.12/.14 alpha. Disabled overrides
all overlays. Twenty-six VM theme/layout tests pass, including state
precedence in light/dark themes. Actual keyboard focus visibility/pixels and
browser publication remain unverified for this change. No golden update.

Segmented layout Web follow-up (2026-09-10): actual SegmentedButton children
inside GlassSurface are measured at 320px/2x text in both LTR and RTL. All
three targets are >=44x44, remain inside the 16px gutters, and Dark updates
selection. Both cases pass in VM and Chromium. This verifies rendered
geometry, not just ButtonStyle minimumSize; no production change or baseline
update in this pass. It is not whole-page/native visual approval.

Liquid segmented controls (2026-09-10): a Liquid-only segmented button
theme removes duplicate outlines over glass-backed appearance selectors,
uses transparent inactive segments and primaryContainer/onPrimaryContainer
selected states, with 44px minimum targets and disabled-state precedence.
Classic retains defaults. Thirty VM settings/theme tests and 32 Chromium
tests (including new light/dark state assertions) pass. This is a theme
hierarchy change awaiting whole-page visual comparison, not native fidelity.

Shared content Web follow-up (2026-09-10): fourteen Chromium card/AppShell
cases pass after the shared contour change, covering page navigation, RTL
and scaling. Expanded standalone card coverage then passes all four
Classic/Liquid and light/dark combinations in Chromium with shape, fill,
no-blur and activation checks. No production source or visual baseline
changes in this pass; this closes browser behavior coverage, not subjective
whole-page fidelity. Port 9000 remains HTTP 200.

Shared solid content contours (2026-09-10): HermesGlassCard now uses a
continuous border, Material shape and ink response in Liquid. Despite its
historical name this remains a content card: existing fill, border side and
shadow policy are retained and no blur is introduced. Classic remains on
BoxDecoration. Ten focused card/home tests pass; full VM run reports 1587
passes with only the two known Liquid preview golden failures. Log:
/tmp/hermes-content-card-full.log. Analyze passes. Broad source consistency
is not whole-page optical acceptance; no golden baseline is updated.

Home primary content contour (2026-09-10): Liquid Continue Work now uses a
continuous 20px shape and capsule CTA instead of overriding the theme with
a rounded-rectangle button. Its broad accent shadow is removed in Liquid
to separate solid primary content from floating navigation; content and
gradient colors remain unchanged. Classic preserves previous decoration.
Twenty home/AppShell VM tests pass; twelve Chromium AppShell tests pass
including explicit hero shape, absence of shadow, and capsule assertions.
Analyze passes. This is a page hierarchy prototype, not visually accepted
native fidelity; no golden baselines are changed.

Exact preview delta audit (2026-09-10): rerunning liquid_visual_test yields
four passes and the same two Liquid golden failures. Independent RGBA
comparison over 163,800 pixels reports light: 287 changed (0.175%), maximum
channel delta 4, none above 10; dark: 609 changed (0.372%), maximum delta 13,
nine above 10. Both bounding boxes are x32–357/y169–288. Tool command:
`dart run tool/inspect_preview_pixels.dart --compare <actual.png> <golden.png>`.
Log: /tmp/hermes-current-visual.log. These localized sample differences do
not explain or measure whole-app fidelity to the requested design. No
baseline is updated and no subjective approval is inferred from small
numerical error. Analysis passes. Next comparison must use actual pages and
a target reference, not just this Appearance settings sample.

Preview display diagnostic (2026-09-10): independent PNG decoding via
tool/inspect_preview_pixels.dart shows all 23,400 pixels in the top 60 rows
of the current Liquid light failure image are RGBA 242,244,249,255. The
Liquid and Classic light baselines have the same uniform region. Therefore
the pattern shown there in the conversation image viewer is not encoded
in that PNG region. This narrows the display problem without claiming the
entire render is correct. Reliable whole-page viewing and target comparison
remain needed; do not tune global optical tokens from the patterned display.

Unknown upload reduced-motion feedback (2026-09-10): image and file upload
indicators now share a helper. Unknown totals use a static upload icon with
localized semantics when disableAnimations or accessibleNavigation is set;
known image totals retain determinate progress. Twelve VM and twelve
Chromium attachment tests pass, including both accessibility flags and
attachment kinds with no indeterminate spinner. Analyze passes. This closes
the unknown-total motion gap recorded below, not whole-page visual acceptance
or live network cancellation.

Image upload progress/layout (2026-09-10): known upload totals now drive a
determinate image progress ring; ring and percentage clamp to 0–100%. New
fixtures exposed 15px overflow when the percentage row was visible. Image
cards now reserve scaled height for upload/error status text. Eight VM and
eight Chromium attachment cases pass including negative/normal/excess
progress. Analyze passes. Unknown-total reduced-motion handling is still
open; this does not prove real network cancellation or visual acceptance.

File attachment action consistency (2026-09-10): Liquid file cards share
the image attachment's 44px GlassButton/capsule removal treatment. A 44px
reserved content inset and corresponding card-width increase avoid covering
the filename; the attachment strip remains horizontal. Classic retains its
previous width and control. Five VM and five Chromium attachment tests pass,
now checking removal for file as well as image previews at 2x text scaling
and with reduced transparency. Analysis passes. Whole-page visual acceptance
and real-upload cancellation remain outside this evidence.

Uploading image layer order (2026-09-10): image upload progress now paints
below the removal control and ignores pointer hits. Five VM and five
Chromium attachment tests pass, including a visible spinner with reachable
Liquid removal and callback without opening preview. Analyze passes. This
verifies UI layering/callback only, not cancellation of a real upload. The
shared overlay order also applies to Classic; its button styling is unchanged.

Image attachment removal control (2026-09-10): Liquid uses a shared
GlassButton with >=44px target inside the thumbnail, backed by an opaque
surface-colored capsule for image-independent contrast; Classic retains its
previous control. Four VM and four Chromium attachment cases pass, including
2x text, reduced transparency, preview operations and removal callback
without accidentally opening a preview. Analyze passes. No independent blur
or golden update is introduced. Upload-in-progress interaction remains a
separate scenario; whole-page visual acceptance is still open.

Scroll-edge falloff prototype (2026-09-10): the linear two-stop fade now
samples smoothstep at five stops, retaining peak edge alpha while reducing
the slope at the content-side boundary. Sixteen scrim/AppShell VM tests and
analysis pass, including direction, slope shape, click-through, no added
BackdropFilter and reduced-transparency removal. The current preview image
still appears patterned in the image viewer, so no color/optical acceptance
is claimed. This is a source-verified falloff change pending reliable visual
review; no golden baseline is updated.

Header-search browser timer resolved (2026-09-10): _FakeChatApi omitted
savedPrompts and providerQuota, allowing composer initialization to fall
through to HTTP in the browser. Explicit empty domain responses remove the
pending timeout without pumping away the timer or changing production code.
The previously failing targeted Chromium header-search case now passes, and
all 34 VM chat_composer_chips cases pass. This supersedes the pending-timer
limitation in the integration audit below; whole-page golden acceptance is
still unresolved.

Current integration audit (2026-09-10): complete VM run initially reported
1572 passes and three failures. The additional header-search test used
jumpTo without a user gesture, leaving intentional bottom-follow state
enabled; a real history-reading drag before the geometry assertions fixes
the fixture without changing production scrolling. Full rerun reports 1573
passes, with only Liquid light/dark preview goldens failing. Logs:
/tmp/hermes-liquid-current-full.log and
/tmp/hermes-liquid-current-full-fixed.log. Chromium's targeted header-search
run still fails teardown with a pending 30-second timer, even after explicit
page unmount; it is NOT a passing browser regression. Timer ownership needs
investigation. No production source or golden baseline changed in this pass.

Phone navigation selected symbols (2026-09-10): Liquid phone navigation now
uses the same filled active symbols as the tablet rail, restoring outlined
symbols when inactive. The existing keyed target and request-badge subtree
remain in place; Classic is unchanged. Twelve AppShell tests pass both on
VM and Chromium, including new active-home/inactive-home assertions around
tab switching, responsive/RTL/scaling checks and reduced-motion coverage.
Analyze and diff checks pass. This closes a phone/tablet state-language gap,
not native symbol rendering or whole-app optical fidelity.

Attachment contour consistency (2026-09-10): Liquid image/file attachment
cards now use RoundedSuperellipseBorder for both their fill/border and ink
response; non-card attachments use StadiumBorder. Classic decoration remains
unchanged. These are content surfaces, not new backdrop-filter layers. Eight
VM attachment/composer tests and four Chromium preview cases pass, checking
continuous card decoration/ink shapes, .78 transparent versus opaque fill,
no card blur, and preview opening/closing with 2x text scaling. Analyze and
diff checks pass. This does not approve subjective whole-page fidelity or
update golden baselines.

Composer expansion motion (2026-09-10): the shared toolbar material now
resizes over 240ms with easeOutCubic instead of jumping when emoji content
opens or closes. Classic, disableAnimations and accessibleNavigation use a
static wrapper, avoiding both motion and the current Flutter zero-duration
AnimatedSize layout assertion discovered by the new tests. Ten VM and ten
Chromium tests pass, including intermediate expansion/contraction geometry,
immediate accessible sizing, narrow light/dark/opaque insertion controls and
actual-chat final bottom following. Analyze passes. This is not a physical
device frame-time measurement or native spring/material visual acceptance.

Keyboard viewport follow-up (2026-09-10): a synthetic 300px MediaQuery
keyboard inset in actual ChatScreen exposed a 300px bottom-follow gap.
GlassDockLayout now observes depth-zero vertical viewport dimension changes
and invokes the existing non-forcing follow callback; normal scrolling and
nested viewports do not trigger it. Seven VM chat/layout tests pass and all
three actual-chat scenarios pass in Chromium, including the keyboard inset
cycle. Analyze passes. Logs: `/tmp/hermes-dock-keyboard-fixed.log` and
`/tmp/hermes-dock-keyboard-web.log`. This verifies simulated keyboard geometry,
not physical iPhone keyboard animations or live backend streaming.

Actual-chat browser regression (2026-09-10): all three long-history
ChatScreen scenarios pass on Chromium (Classic/light and Liquid/light/dark).
Coverage includes initial true-bottom settling, viewport underlap, final
answer clearance, multiline growth follow, history-reader offset preservation
and header search actions. Log: `/tmp/hermes-dock-chat-web.log`. A subsequent
VM rerun adds an explicit composer-height growth assertion and passes all
three scenarios (`/tmp/hermes-dock-growth-proof.log`). These use fixture
stores, not a live backend or physical iPhone keyboard, and are not screenshot
approval. No production source changed in this pass.

Dock Web pixel evidence (2026-09-10): a 320x500 RepaintBoundary wraps the
actual GlassDockLayout and thick 26px-radius GlassSurface over a red/blue
scrolling list. A text-free center pixel inside the 80px dock changes red
and blue channels by >15 levels after scrolling in transparent mode. The
opaque sequential fallback returns identical pixels and has no backdrop
filter. All four pixel/resize layout tests pass in both the VM renderer and
Chromium (`flutter test --platform chrome`); analyze passes. Browser log:
`/tmp/hermes-dock-pixels-web.log`. This directly verifies sampled backdrop
behavior for this composition, not subjective whole-chat appearance or
native refraction. No production source or golden changed in this pass.

Dock resize follow-up (2026-09-10): actual-chat multiline input tests exposed
a 48px bottom-follow gap when the measured dock grew. GlassDockLayout now
notifies ChatScreen on inset changes, using the existing epoch-aware,
non-forcing bottom-follow scheduler after padding relayout. Light/dark chat
tests verify multiline growth follows when pinned and retains the scroll
offset after the user has dragged into history. Five chat/layout tests and
the subsequent three expanded chat tests pass; analyze passes. Logs:
`/tmp/hermes-dock-grow-fixed.log`, `/tmp/hermes-dock-history.log`. Device
keyboard/streaming and visual acceptance remain open.

Chat bottom underlap implementation (2026-09-10): the previous Column ended
the transcript above the composer, preventing its material from sampling
messages. GlassDockLayout now extends nonempty transparent-Liquid transcripts
under the measured request/status/composer dock. Its height becomes trailing
list padding and offsets the return-to-bottom control. Empty chat, Classic
and opaque accessibility layouts remain sequential. No new blur is introduced.
Three actual-chat tests pass for initial bottom settling and last-answer
clearance, now explicitly asserting that the Liquid viewport extends below
the composer top. Two layout tests cover dock heights 80/160/60 and fallback
geometry. Sixty-five focused interaction tests pass; full suite: 1,566 passed,
only the two known preview golden failures. Analysis passes. Logs:
`/tmp/hermes-dock-overlap.log`, `/tmp/hermes-dock-interactions.log`,
`/tmp/hermes-dock-full.log`. Browser/device material and dynamic streaming
acceptance still required; widget geometry alone does not approve the visuals.

Phone sheet close follow-up (2026-09-10): Liquid titled adaptive menus now
use GlassButton for close, matching the shared capsule/focus/press treatment
without adding a filter. Classic retains IconButton. New real-sheet tests
check >=44px bounds, .92 foreground press scale (1 with reduced motion),
dismissal and exactly one cancellation callback. Thirty-two adaptive-menu
and button-feedback tests pass; log `/tmp/hermes-menu-close.log`. This is
interaction evidence, not whole-page visual acceptance.

Fresh release browser audit (2026-09-10): an isolated Chromium profile loaded
the current port-9000 release with Liquid explicitly selected. At 390x500,
the Connection heading stays at y=17..39 before/after scrolling; the 52px
Connect button moves from y=554..606 to y=416..468. No Runtime exception was
reported. Log: `/tmp/hermes-visual-review-TVCfLF/current-browser.log`. A direct
390x844 browser PNG was also captured at
`/tmp/hermes-visual-review-TVCfLF/connection-liquid.png`. Both this PNG and the
existing preview PNG still appear patterned through the current image viewer,
so neither was used to approve colors or material transparency. This pass
does not demonstrate chat/home/settings fidelity or native iPhone rendering;
the accessible default page is Connection in this clean profile. No production
source or golden baseline was changed in this audit.

Destructive phone-label follow-up (2026-09-10): a new actual-menu test
demonstrated that PopupMenuItem's label theme overrides the inherited error
DefaultTextStyle, leaving enabled destructive labels in the normal color.
Liquid phone entries now resolve their local popup label theme to error for
enabled states and preserve the inherited disabled color. The regression
tests assert the effective Text style and real selection/no-selection results.
All 63 adaptive-menu, menu-entry and selection contrast tests pass; log:
`/tmp/hermes-danger-menu.log`. This does not establish screenshot acceptance.

Phone menu selection follow-up (2026-09-10): Liquid phone sheets now reuse
GlassSelectionRow instead of the legacy 14px decorated selected background.
The outer GlassSurface exclusively owns the continuous-corner sheet clip;
the inner transparent Material no longer imposes a second top-only circular
clip. Classic is unchanged, and destructive-value foreground handling is
retained. Sixty-one adaptive-menu, anchored-menu and selection contrast tests
pass, including the new phone material/selection/callback check. Analyze
passes. Log: `/tmp/hermes-phone-selection.log`. This is source and widget
evidence, not whole-page screenshot or device acceptance.

Shared action silhouette follow-up (2026-09-10): Liquid FilledButton,
OutlinedButton and TextButton defaults now use StadiumBorder; Classic keeps
its 12px rounded rectangle. Explicit per-widget shape overrides remain owned
by those widgets. Four new theme/interaction tests cover both styles and
brightnesses, pressed/focused/disabled shape resolution, 2x text and pointer
activation. Thirteen focused tests pass; full regression records 1,559 passed
and only the two existing Liquid preview golden failures (609 dark / 287 light
pixels). Goldens were not updated. Analyze and release build pass; port 9000
serves matching script hash
`433a256f21048d62c438d95ac7811c607788a2415b3fb735517900e8804000ff`.
Full log: `/tmp/hermes-liquid-action-regression.log`. This improves shared
action consistency but does not establish whole-app visual acceptance.

Composer focus geometry follow-up (2026-09-10): Liquid now paints its
continuous-corner focus ring as foreground decoration. Background shape
decoration implicitly added border padding, shifting the text/send controls
and increasing field height by 2.8px on focus. New 320px-wide tests cover
intermediate animation, focused and unfocused bounds, including accessible
navigation with zero animation duration. This is an interaction-stability
fix, not whole-page visual or native-device acceptance.

- `GlassSurface` uses a bounded Gaussian backdrop blur (sigma 16), static
  diagonal tint, static specular wash, directional edge ring and shadow. No refraction or
  background-dependent material adaptation is implemented.
- Regular tint alpha is .68/.54; thick tint is .82/.72. Whether these values
  look too opaque cannot be decided without trustworthy rendered comparisons.
- `GlassEnvironment` supplies a subtle diagonal accent gradient, not a rich
  moving backdrop. Blur over an almost uniform background can appear solid.
- AppShell's compact scaffold has `extendBody` in Liquid; this does not prove
  that every page scrolls beneath every floating control. Audit per page.
- AppearanceStore defaults to Classic and persists explicit user choices.
  A fresh launch therefore is not evidence of Liquid appearance.
- Current image viewing produces patterned artifacts for a control capture.
  Do not interpret those artifacts as an application rendering defect.

## Next visual implementation gates

### Verified renderer constraint

Installed Flutter is 3.47.1 (framework 6655482ec0, Dart 3.13.1). Its native
`sky_engine/lib/ui/painting.dart` documents and enforces Impeller-only
ImageFilter.shader, with ImageFilter.isShaderFilterSupported as runtime gate.
The installed Web SDK's `lib/ui/painting.dart` unconditionally throws from
ImageFilter.shader and returns false for that capability. Consequently a
single custom backdrop-refraction filter cannot currently serve both targets.

- Native experiment: capability-gated shader filter; first uniform vec2 and
  first sampler are engine-owned input size/texture. Require device validation
  of bounds, clipping, text stability and frame cost before enabling.
- Web: retain sampled blur initially. Matrix filters are supported but provide
  affine magnification, not curved-edge refraction; label them accordingly.
  Screenshot-texture sampling would introduce latency, capture cost and stale
  content risks, especially during streaming. Do not add it to chat by default.
- Keep the current accessibility opaque path and no-per-message-filter rule
  on both targets. The iOS project's deployment target remains 13.0, so an
  iOS version label is not sufficient proof that a rendering API is available.

This rules out blindly enabling ImageFilter.shader in the Web build. It does
not block layout/material hierarchy improvements or establish native support
on any particular device. No shader or runtime capability flag was added.

1. Obtain independently viewable reference and current screenshots for chat,
   home/sessions and settings in light and dark Liquid. Preserve Classic and
   existing preferences. Compare hierarchy, not isolated component counts.
2. Verify content-under-chrome on those pages: scroll through textured content,
   observe backdrop changes, and verify first/last content and hit targets are
   unobscured. Widget bounds alone are insufficient for visual acceptance.
3. Tune regular vs thick materials on the same captured scenes. Keep messages,
   code, terminal and document content solid; do not add per-message filters.
4. Prototype refraction only with measured Web/iPhone support and frame cost.
   Do not substitute a static highlight or an asset for actual backdrop
   distortion, or describe either as native rendering.
5. Validate transitions, keyboard, reduced motion/transparency, inline approvals
   and streaming in the actual app. Record device/browser and measured results.

## Evidence required to finish

File sidebar refresh uses GlassButton in Liquid, replacing the fixed 36px
target with shared >=44px interaction, press and focus feedback. Classic
retains its compact control. Twelve file/button tests pass, including actual
refresh activation at 2x text. No new backdrop filter was introduced.

Disabled selected-menu audit: 32 selection/contrast tests pass across four
accents and both brightness modes. Actual popup tests now verify disabled
selected labels retain the disabled theme color, icons have reduced opacity,
pointer taps do not dismiss the menu, and item InkWell cannot request focus.
No production change was needed: the framework already applies disabled icon
opacity inside the shared selection foreground. This does not measure full
page visual fidelity or screen-reader announcements.

Adaptive-menu constraints now follow their documented PopupMenuButton
meaning: anchored-menu sizing, not phone trigger sizing. Phone sheets keep
their viewport-based bounds. Ten adaptive-menu tests pass, including a 280px
menu-width constraint that must not enlarge the phone trigger, plus actual
selection and >=44px target checks. Static analysis passes.

Sidebar folder flow: its create-folder dialog now uses GlassAlertDialog and
allocates the controller only after an active connection is confirmed. The
actual menu interaction test exposed a 36x36 constraint intended for the
trigger but applied to the entire desktop PopupMenuButton menu, clipping
items and preventing pointer activation. Removing that constraint restores
the pointer flow. Four file accessibility tests pass, including opening and
cancelling the sidebar dialog at 2x text. No backend write is performed.

Sidebar search layout: FileTreePanel's fixed 42px Liquid search height was
replaced by a 44px minimum constraint, allowing larger text to expand the
field. Four file accessibility tests pass, including a real FileTreePanel at
360px width and 2x text with a >=44px clear target and successful clearing.
Static analysis passes. This verifies layout, not subjective glass fidelity.

Latest shared-layout regression: `flutter test --no-pub` passes all 1,472
tests in about 75 seconds after large-text row wrapping, grouped ink-layer
repair and nested action-group material sharing. Log:
`/tmp/hermes-liquid-shared-regression.log`. Localization remains at its
62-candidate baseline; diff whitespace check passes. Port 9000 returns 200.
No production source changed in this verification pass. These checks do not
remove the screenshot/device acceptance gates listed above.

Nested action-group pixel evidence: a 180x120 RepaintBoundary renders an
orange foreground icon on a thick GlassSurface over a red/blue gradient.
Wrapping the icon area in GlassActionGroup produces byte-identical full RGBA
output to the unwrapped control. All four light/dark and normal/reduced
transparency combinations pass, alongside four material-count/hit tests.
This verifies no extra fill/lighting in this composition, not whole-app
visual acceptance or an actual Web/iPhone frame measurement.

Directional-edge follow-up: transparent surfaces replace the uniform border
with a 1px inset gradient ring below foreground content. Opaque accessibility
surfaces keep their solid 1.5px outline. Two raw-pixel painter tests prove
upper-left emphasis, lower-right secondary light and a transparent center in
both themes; the 12 foreground/material tests and 22 theme tests pass.
Liquid preview comparisons changed 0.79% dark / 0.69% light pixels; Classic
and opaque checks pass. New Liquid goldens record this deliberate lighting
change only: the image viewer still shows patterned artifacts, so subjective
visual acceptance is not established. This is static lighting, not refraction.

Additional component evidence: a RepaintBoundary captures raw RGBA pixels
inside a thick GlassSurface while its underlying list moves from red to blue.
Normal Liquid changes red/blue channels by more than 15 levels; reduced
transparency returns identical pixels before/after. Both outputs are opaque
composites. Eight foreground/material tests pass, with analyze/diff checks
clean. This proves live backdrop sampling in the Flutter test renderer for
this isolated composition, not actual-page overlap, Web rendering, refraction
or subjective visual fidelity. No production material parameters changed.

Page-shell follow-up: the same raw-pixel method now tests HermesPageScaffold
with its actual pinned SliverAppBar. Scrolling from red to blue content changes
a text-free point inside the header by >15 red/blue levels; reduced
transparency stays unchanged and the title remains visible. Ten material/pixel
tests pass; analysis clean. This supports the shared scroll-owned-header
architecture, but does not certify feature-page data or browser/device output.

Paired page captures, user/reference-aligned visual review, device performance
measurements, functional regression results, and successful release delivery.
Current test counts and migrated controls prove only their covered behavior.
The goal must remain active until whole-app acceptance has stronger evidence.

Phone navigation palette follow-up (2026-09-09): Liquid now uses the same
opaque primaryContainer/onPrimaryContainer pair as selection rows for the
indicator and selected icon. Labels sit outside the indicator and retain
onSurface; high-contrast inactive controls use onSurfaceVariant instead of
the tertiary palette color. Sixteen theme-state checks cover four accents,
both brightnesses and high contrast on/off (all failed before the change).
The selection contrast, app-shell accessibility and Liquid theme suites pass
78 tests together; static analysis passes. This establishes color-token
consistency and covered navigation behavior, not browser screenshot approval
or native Liquid Glass fidelity.

Responsive navigation follow-up (2026-09-09): tablet Liquid rail now shares
the phone indicator/icon colors and outside-indicator label treatment. Desktop
Liquid destinations replace the legacy 40px/8px-radius accent-bar treatment
with GlassSelectionRow (56px minimum, 18px corners, paired foreground and
background, shared material ink). Expanded labels wrap under text scaling;
collapsed items retain tooltips and accessible labels. Classic is unchanged.
Nine app-shell tests pass, including a new 2x-text selection-row/hit-area
check and existing responsive RTL, short rail and reduced-motion checks.
Static analysis passes. Visual review on a browser and iPhone remains open.

Tablet action follow-up (2026-09-09): Liquid rail search and approval now use
GlassButton on the existing shared rail material, removing the independent
FAB treatment while retaining badge, tooltip, focus and pressed feedback.
Actual tap tests open the palette and RequestSheet; pending approval remains
queued. A new Arabic/2x-text tablet search test exposed a 0.5px overflow in
the palette keyboard-hint footer. Hints now wrap as key/description pairs,
with flexible descriptions. All 26 app-shell, glass-button and palette tests
pass after that fix; static analysis and diff checks pass. This covers the
tested layout and interactions, not complete visual acceptance.

Shared-button selection follow-up (2026-09-09): Liquid GlassButton now uses
primaryContainer/onPrimaryContainer for selected fill/icon, and onSurfaceVariant
for normal foreground. The persistent accent outline is removed in favor of
the filled selection; keyboard focus uses a 2px foreground-colored ring and
disabled selected controls retain a quiet outline. Classic colors are unchanged.
Eight new rendered IconTheme/style checks cover four accents in light/dark
high-contrast themes. All 34 button, action-group and shell tests pass, as do
static analysis and diff checks. Whole-app visual acceptance remains pending.

More-directory search follow-up (2026-09-09): Liquid directory search uses
GlassSearchField and a selected GlassButton toolbar action. Shared search now
supports opt-in autofocus (default remains false). The page owns/disposes its
controller and resets query/text together on close; Classic keeps its existing
field and toolbar styling. A real phone-shell test in Arabic at 2x text covers
open/focus/type/clear/close/reopen and absence of layout exceptions. Fourteen
shell/search tests and static analysis pass. This is an incremental control
migration, not proof of overall Liquid Glass visual fidelity.

Browser evidence revalidation (2026-09-09): a fresh Chromium 1234 headless
capture of a standalone red HTML page with a black heading succeeds (390x844,
5052-byte PNG; /tmp/hermes-control-fresh.png, SHA256
7f4e6dd01cf13580a6821f5c2ae2d1de0f77c20f21416a1d16975a57d38932f3).
Decoding PNG IDAT data and reversing scanline filters independently using
Node/zlib yields 326248 exact red pixels (99.1153%), with center RGB 255,0,0.
The image-view tool instead presents patterned content. This narrows the
problem to the image presentation path for this control, not Chromium's
capture of the control page. It does not prove that Flutter app screenshots
render correctly. Do not retune UI colors against the corrupted preview;
retain original captures for an independently functioning viewer. Browser
capture itself is available at the cached Chromium executable even though
there is no chromium binary on PATH or local Playwright module.

Agent-page scroll architecture (2026-09-09): HermesPageScaffold adds opt-in
scrollBodyBehindHeader for an existing primary scrollable, using NestedScrollView
and a pinned compact glass SliverAppBar in Liquid. AgentScreen enables it only
with status data; loading/error bodies and Classic retain their box layout.
The existing RefreshIndicator/ListView is preserved instead of wrapping it in
an unbounded box scroll view. A connected page test drags content and verifies
the title remains hit-testable near the top; all 62 offline/page-shell/navigation
tests pass, plus static analysis/diff checks. This proves the covered scrolling
structure, not pixel-level backdrop overlap or native visual fidelity.

Correction to the agent scroll entry above: raw-pixel coverage of the nested
header revealed the outer Scaffold still inserted a second AppBar and top
safe area. The earlier title-position check did not detect that duplication.
Both are now disabled when the opt-in nested header is active. The new tests
sample header RGBA before/after red-to-blue scrolling: normal Liquid channels
change by >15, reduced transparency remains identical, and exactly one title
is hit-testable. All 14 material/pixel tests and 62 page/offline/navigation
tests pass; analysis/diff checks pass. This validates the shared nested
composition in Flutter's test renderer, not actual browser/iPhone output.

More-page responsive header follow-up: the directory opts into the same
scroll-owned compact Liquid header at wide widths, retaining its phone large
title and Classic behavior. Pixel coverage now includes large/compact titles
with both nested-list and box-scroll bodies, normal/reduced transparency.
Large headers are fully collapsed before measuring backdrop color. Eighteen
pixel/material tests pass; combined shell/adaptive coverage totals 34 passing
tests, with analysis/diff checks clean. This does not close browser/device
visual acceptance or independently verify every feature page.

Full regression audit (2026-09-09): first current-tree run passed 1515 tests
and failed only the two Liquid preview goldens. Independent raw PNG comparison
located all 1569 changed pixels per image (0.96%) inside x=34..77,y=243..286,
the 44x44 selected preview button. This matches the deliberate shared-button
fill/outline change; all pixels outside that control were unchanged. Updated
Liquid baselines record that implementation change, not subjective approval.
Added preview hit-size assertions; six preview tests pass, followed by all
1517 tests in a fresh full run (/tmp/hermes-liquid-full-verified.log). Static
analysis, diff checks and l10n baseline checks pass. No production-source
changes or rebuild in this audit; existing port 9000 returns HTTP 200.

Agent search controls: Liquid roster search uses GlassSearchField, with an
optional emptyAction preserving the refresh/spinner when no query is entered.
Typing switches to clear; clearing restores roster refresh and retains focus.
The page refresh action uses GlassButton; Classic retains its prior controls.
Fifty search/offline-page tests pass, including actual agent query/clear and
shared empty-action switching. The page test centers its target before tapping
because top-aligned ensureVisible places it beneath the pinned header. Static
analysis and diff checks pass; visual/device acceptance remains outstanding.

Search-clear feedback follow-up: Liquid GlassSearchField uses GlassButton
for clear, matching its optional empty-state action; Classic keeps IconButton.
The callback remains shared so custom-clear and focus behavior do not diverge.
Two new interaction tests cover >=44px targets, press cancellation, Enter
activation exactly once, focus returning to input, reduced-motion scaling and
one backdrop filter. All 63 search/offline/shell tests pass with analysis and
diff checks clean. This is interaction consistency, not visual acceptance.

Home scroll-header migration: phone Liquid Home opts into the verified nested
glass header, preserving its existing RefreshIndicator/ListView and bottom
navigation padding. Wide Home still suppresses its own title in favor of shell
chrome; Classic is unchanged. A real shell test scrolls Home and confirms one
visible title plus reachable settings, reconnect and bottom navigation. All
38 home/shell/material-pixel tests pass, with static analysis/diff checks clean.
The shared material pixel tests support the architecture, not final Home
browser screenshots, frame timing or iPhone visual acceptance.

Home toolbar follow-up: Liquid settings/avatar, reconnect and notification
actions use GlassButton on the shared header, retaining status colors, busy
disablement, badges and route callbacks. Classic still uses IconButton.
The phone shell test checks all three shared controls and >=44px targets;
36 shell/home/button tests pass, plus analysis/diff checks. No extra blur is
introduced by these buttons. Whole-app visual/device acceptance remains open.

Notification-center follow-up: nonempty Liquid lists opt into the shared
nested glass header; empty state retains its bounded layout. Clear uses a
GlassButton but still opens the existing destructive confirmation. A populated
screen test scrolls, opens/cancels confirmation without removing items, then
checks transition to the empty layout. Ten notification/confirmation tests
pass. This establishes covered interactions, not whole-page visual acceptance.

Notification narrow-layout correction: at 320x640 and 2x text, the existing
mark-all-read text action overflowed the toolbar by 109px and made clear
unreachable. Liquid now uses a tooltip-labeled done-all GlassButton, disabled
when unreadCount is zero. The populated-screen test now runs at that size and
scale, marks all read, verifies disablement, opens/cancels clear and checks
empty layout. All ten notification/confirmation tests pass. Classic keeps
its prior text action; this does not establish Classic large-text compliance.

Shared-page dismissal controls: implicit Liquid back/close actions now use
GlassButton with localized Material tooltips and Navigator.maybePop, preserving
fullscreen-dialog close icons and explicit leading widgets. Classic remains
framework-generated. Four route tests cover compact box/nested-list pages
and normal/fullscreen dismissal; 21 route/adaptive/shell tests pass, with
analysis/diff checks clean. This verifies navigation behavior and hit size,
not visual acceptance of every route.

Dismissal safety follow-up: two additional route tests verify that the
implicit glass back action invokes a PopScope rejection exactly once without
leaving unsaved content, and that an explicit leading action is not replaced
or routed through automatic dismissal. All eight back-route/file-edit-guard
tests pass. No production change or rebuild was needed. These tests establish
the covered navigation safety, not broader Liquid Glass visual completion.

Interactive material-light prototype: transparent GlassSurface now draws a
96px radial white light beneath foreground content at pointer hover/down/move
coordinates, removed on exit/up/cancel. A translucent Listener observes input
without a gesture recognizer; only the light overlay rebuilds on movement.
Reduced-motion/accessibility and opaque transparency fallbacks omit the effect.
This is simulated surface lighting, not refraction or device-tilt response.
Thirty-four material/preview/interaction tests pass, including unchanged idle
goldens, existing foreground pixels and tap delivery. Analysis/diff checks
pass. Hover/device performance and subjective intensity still need review.

Nested interaction-light correction: only the outermost GlassSurface owns
pointer lighting, matching backdrop ownership and avoiding stacked radial
highlights on nested controls. A mouse hover/exit and touch-cancel test verifies
one light, one blur and return to the idle painter state. All 35 interaction,
material, action-group and preview tests pass. Static preview goldens remain
unchanged; browser/device performance and visual intensity remain unverified.

Interaction raw-pixel evidence: light/dark RepaintBoundary captures confirm
touch-position pixels brighten, a point beyond the 96px light radius is
unchanged, and an opaque foreground patch inside the radius retains exact
RGBA 18,52,86,255. Cancellation restores the entire captured pixel array to
its idle value. All five interaction tests pass. This supports localized
lighting and foreground ordering in the test renderer, not browser/device
performance or subjective fidelity. No production change or rebuild needed.

Multi-touch light ownership: the first pressed pointer now owns the light
until it ends/cancels. Secondary touches and mouse hover cannot move or clear
that light, avoiding jumps during multi-touch interaction. A two-pointer test
verifies this ownership and cleanup; all 24 interaction/pixel tests pass.
This is pointer-state correctness, not refraction or device-performance proof.

Runtime motion preference: dependency changes now clear active pointer/light
state when disableAnimations or accessibleNavigation becomes true. A live
toggle test starts a touch, suppresses motion, releases while suppressed,
reenables and verifies an idle light plus working subsequent touch. Seven
interaction tests and analysis pass. This avoids stale light state across
accessibility changes; device visual/performance acceptance remains open.

Post-interaction full regression: first run passed 1534 tests with one old
structural assertion failing because the foreground SizedBox now sits inside
the interaction wrapper. The test now verifies its exact 240x80 size, last
paint position in the foreground stack and placement in the material's last
branch. No production code change was needed. A fresh full run passes all
1535 tests (/tmp/hermes-light-full-verified.log); analysis, diff and l10n checks
pass. This covers existing test behavior, not browser performance or visual
fidelity. Port 9000 continues serving the existing release.

Interaction repaint isolation: a paint-counter test found that press, five
moves and cancel repainted unchanged foreground seven extra times (1 -> 8).
The light overlay now owns a RepaintBoundary; the same sequence leaves the
foreground at one paint. Thirty-two interaction/pixel/preview tests pass with
unchanged idle goldens and local-light pixels; analysis/diff checks pass.
This verifies paint invalidation isolation in the test renderer, not GPU
frame timing or layer-memory costs on Web/iPhone.

Fresh browser startup probe: isolated Chromium 1234, 390x844 mobile metrics,
no credentials, navigated to port 9000 and observed for 12 seconds using CDP.
Document title was Hermes Mobile, one flutter-view existed and no
Runtime.exceptionThrown events were observed. Light-DOM canvas count was zero
and body.innerText empty; these do not establish whether Flutter shadow-DOM
rendering completed. No connected-page, Liquid-mode or performance claim is
supported by this probe. Browser closed normally; temporary profile and script
are at /tmp/hermes-browser-audit-tEGPwu. Next browser check must inspect shadow
roots/render completion and use a controlled Liquid fixture before measuring
interaction frames. No production source changed.

Shadow-DOM follow-up: the same isolated browser now seeds the Liquid preference
before startup and recursively inspects shadow roots. It finds one 390x844
canvas with matching viewport bounds; CanvasKit JS/WASM resources are present.
Activating Flutter's accessibility placeholder produces a Connection heading,
Server address/API key textboxes, transport buttons and Connect action in CDP
Accessibility.getFullAXTree. No Runtime.exceptionThrown events were observed.
This resolves the earlier zero light-DOM canvas ambiguity and establishes
connection-page startup/semantic rendering, not authenticated Home/Chat,
visual fidelity, or proof that stored preference affected every surface.
Probe output: /tmp/hermes-browser-audit-tEGPwu/result.log. No production edits.

Connection-page migration: replaces its standalone Scaffold/AppBar with
HermesPageScaffold and opt-in nested header, keeping the existing constrained
Form/SingleChildScrollView. Liquid gains the shared background and scroll-owned
glass title. Four connection tests pass including a 390x844 viewport with 300px
keyboard inset and reachable Connect action, plus OAuth/SSH/localization cases.
This is not evidence of a real authenticated connection or browser keyboard
behavior; prior browser startup evidence predates this migration.

Post-migration browser scroll evidence: isolated Chromium/CDP with Liquid
preference seeded renders the current release's connection page. At 390x844
the form fits, so a wheel event produces no movement (not a scrolling proof).
At 390x500 a wheel event moves the Connect semantic bounds from y=554..590
to y=432..468, inside the viewport, while the Connection heading remains at
y=17..39. No Runtime.exceptionThrown events were observed. This verifies
real-browser scroll geometry with accessibility enabled, not pointer activation,
virtual keyboard behavior, visual fidelity or native GPU performance. Output:
/tmp/hermes-browser-audit-tEGPwu/short-scroll-result.log. No production edits.

Connection primary-action sizing: following the browser-observed 36px visible
button bounds, Liquid Connect now explicitly sets a 52px minimum height and
StadiumBorder while retaining a solid primary fill and existing busy/OAuth
conditions. Four connection tests pass including keyboard visibility and
minimum-size/shape assertions; analysis/diff checks pass. Classic is unchanged.
New browser bounds must be remeasured before claiming browser touch sizing.

Approval-mode sheet: the chat mode picker now uses shared GlassSelectionRow
selection materials and a flexible scroll region beneath its title. RadioGroup
and its returned manual/smart/off values remain unchanged. Two widget tests
cover Classic and Liquid at 320x480 with 2x text, selected-row state and scrolling
to/selecting off. Analysis and diff checks pass. These tests do not establish
authenticated approval execution or native visual fidelity.

Composer emoji panel: Liquid now uses a 48px header with shared GlassButton
close feedback and a responsive grid (up to eight columns, 44px row extent),
instead of squeezing eight columns into narrow screens. Emoji ink corners
follow the softer Liquid geometry; no additional blur is added. Classic
geometry is retained. Ten focused composer tests pass, including light/dark
320px emoji target bounds, insertion and closing, existing alignment and
surface performance checks. This is widget-level evidence, not device GPU
performance or whole-chat visual acceptance.

Connection browser density correction: fresh CDP measurement on the release
found 44px button semantic height despite its 52px style minimum, caused by
desktop adaptive compact density. Liquid Connect now explicitly uses standard
visual density. Four connection tests and analysis pass. Rebuilt Web/CDP at
390x500 verifies 52px height before and after scrolling (y554..606 to
y416..468), with heading unchanged at y17..39 and no Runtime exceptions.
Evidence: /tmp/hermes-browser-audit-tEGPwu/standard-density-bounds.log. Port
9000 serves the matching release hash. This validates browser semantic geometry,
not actual pointer activation, screenshot fidelity or native performance.

Shared-button density follow-up: unlike FilledButton, GlassButton's IconButton
retains a >=44x44 painted Material under a forced compact theme with an 18px
icon. A new regression test measures that Material (not just the outer padded
hit region) and activates near its left edge. All 17 button feedback tests pass.
No shared-button production change is warranted by this evidence; the density
correction above remains scoped to Connect. This is test-renderer evidence,
not browser/iPhone verification of every button placement.

Chat latest-message action: Liquid now uses GlassFloatingAction, a bounded
thick GlassSurface with the shared GlassButton, instead of a Material FAB.
Classic retains its original FAB and hero tag. Existing visibility and scroll
callback code is unchanged. Four component tests cover Classic/Liquid with
normal/reduced transparency, blur count, target height and activation; two
long-chat initial-scroll regressions also pass. Analysis and diff checks pass.
This does not prove visual fidelity or browser frame cost of the floating layer.

Floating-action visibility: the chat scroll action now disables focus and
semantics as soon as it starts hiding, alongside pointer exclusion. Previously
its parent only ignored pointers during opacity changes. Six component tests
pass, including keyboard activation before hiding, no semantic label/input
while hidden, and pointer activation after showing again in both styles.
Analysis/diff checks pass. The added tests verify behavior in Flutter's test
renderer, not a physical screen reader.

2026-09-10 integrated regression: all 1548 tests pass in the current worktree
after approval-mode scrolling, emoji target sizing, Connect density correction
and floating-action visibility changes. Log: /tmp/hermes-liquid-current-full.log.
Localization remains at 62 existing candidates across 37 files; diff check
passes and port 9000 remains available. This run changes no production code
and is not evidence that whole-page visual/native acceptance gates are met.

Chat header action migration: Liquid session tabs, active-session tray, search,
history locator and workspace entry now use shared GlassButton feedback, with
search selected state reflecting the open find panel. Classic retains IconButton.
No per-action blur is added; the header remains the single material plane.
Both long-chat tests pass, with the Liquid test now also activating search,
checking selected state and closing it. This does not verify every header
action against a real backend or establish whole-page visual fidelity.

Chat theme coverage correction: the original Liquid long-chat fixture used
Brightness.dark, not light. It now runs both Liquid brightness modes plus
the existing Classic case. All three pass, including final-message bounds
between header/composer, search open/close, selected state and resolved icon
foreground matching onPrimaryContainer. Log: /tmp/hermes-chat-two-themes.log.
No production source changed and no new build is needed. This verifies
theme wiring and layout in the test renderer, not screenshot visual fidelity.

Chat find controls: previous/next/close now share the Liquid header action
styling, retaining their callbacks and Classic IconButtons. Three chat tests
pass, including >=44px previous/next target heights in both Liquid themes.
Analysis/diff checks pass. Existing tests open/close search but do not establish
correct match navigation for a populated query; that remains a separate gate.

Find-state follow-up: previous/next now disable when there are no matches.
The real chat fixture verifies null callbacks for empty search and, in both
Liquid themes, enters a query with 25 matching messages, advances 1/25 to
2/25 and returns to 1/25 using pointer activation. All three chat cases pass.
This closes the populated-query control/counter gap above, but does not prove
every matched message's final viewport position or browser visual fidelity.

Tablet navigation shape: Liquid NavigationRailTheme now explicitly consumes
the phone NavigationBarTheme indicatorShape, alongside its existing shared
colors. This removes reliance on an independent framework shape default.
Twelve shell accessibility tests pass, including an actual short RTL tablet
rail asserting the shared StadiumBorder and reaching the approval control.
Analysis/diff checks pass. This is theme consistency, not proof of a visible
before/after difference or fluid indicator morphing.

Nested material ownership: GlassSurface now shares its ancestor's tint, edge
lighting and shadow as well as its blur, retaining only its own rounded clip.
Previously nested surfaces continued accumulating opaque tint despite avoiding
extra blur. Pixel comparisons over a red/blue background are identical to the
unwrapped foreground for both themes and reduced-transparency modes. Thirty-eight
focused tests and all 1549 full-suite tests pass; analysis/diff checks pass.
Full log: /tmp/hermes-nested-full.log. This verifies removal of material stacking,
not actual refraction or whole-page visual acceptance.

Nested accessibility follow-up: sharing now checks the nearest ancestor's
enabled/transparency policy. An inner local reduce-transparency override keeps
its opaque fill when its parent remains transparent; same-policy nesting still
shares the material. Thirty-one material/theme tests pass, including local
opaque gradient alpha=1 and one outer blur. Static analysis passes.

Continuous-corner prototype: GlassSurface uses RoundedSuperellipseBorder for
fill, specular decoration, shadow and inset edge paths, and ClipRSuperellipse
for outer/nested clipping. Radius values and transparency are unchanged.
Forty-nine focused tests pass; full regression passes 1548 with two Liquid
preview golden mismatches (dark 609 pixels / .37%, light 287 / .18%). Classic
goldens pass. Golden baselines have NOT been updated: reliable visual review
is still required. Log: /tmp/hermes-superellipse-full.log; diff images are in
test/failures/preview_liquid_*.png. Analysis/build/diff checks pass and port
9000 serves the matching build. This remains an unaccepted visual prototype,
not a claim of native continuous-corner or refraction fidelity.

Post-superellipse Web smoke check: Chromium/CDP on the current release at
390x500 renders the connection page without Runtime exceptions. Header
remains y17..39; Connect remains 52px high and moves to y416..468 after scroll.
Log: /tmp/hermes-browser-audit-tEGPwu/superellipse-browser.log. Installed
CanvasKit path/canvas implementations convert RSuperellipse to a path before
drawing, so this API is implemented on Web (unlike shader backdrop filters).
Important limitation: connection-page glass header has radius zero. This smoke
check does not exercise/visually verify a nonzero-radius glass corner. The two
Liquid golden differences remain unaccepted and unchanged. Browser closed.

Nonzero-corner geometry test: a 120x100 surface with radius 30 uses
ClipRSuperellipse; sampled path containment differs from an equal-radius
RRect and foreground pixels safely inside the continuous corner retain exact
Material red RGBA (244,67,54,255). Test passes after correcting two test
assumptions: expansion direction is not guaranteed and Colors.red is not
pure RGB red. This proves geometry wiring/interior preservation, not edge
highlight alignment, browser nonzero-corner rendering or visual acceptance.
No production changes; existing two golden mismatches remain open.

Continuous-edge isolation: two new light/dark tests rasterize the actual edge
painter at 120x100/radius30. Nonzero alpha exists in the ring; more than 5000
pixels safely inside the inner path or outside the outer path remain clear,
allowing a one-pixel antialias margin. All three continuous-corner tests pass.
This supports edge confinement in the test renderer, not whole-surface browser
clipping alignment or subjective fidelity. No production/golden changes.

Real-browser corner verification: flutter test --platform chrome runs all
three continuous-corner tests successfully in cached Chromium 1234. This
executes the nonzero-radius foreground capture and both edge-painter pixel
checks on Flutter Web, closing the earlier zero-radius-only browser evidence
gap. Log: /tmp/hermes-corner-web-tests.log. It is a Web test harness, not an
authenticated whole-page release capture or performance benchmark. The two
Liquid golden mismatches still require visual review; no baseline updated.

Web backdrop evidence: all 18 glass_foreground_pixels tests pass under
flutter test --platform chrome using Chromium 1234. Eight header cases cover
compact/large titles, direct/nested scrolling, normal/reduced transparency.
Changing the sampled backdrop from red to blue changes the transparent
header channels by >15, while reduced-transparency samples remain equal.
Moving standalone backdrop, hit targets and foreground preservation checks
also pass. Log: /tmp/hermes-backdrop-web-tests.log. This verifies actual Web
test-renderer backdrop response, not authenticated page content, frame timing,
refraction, or subjective visual acceptance. No production/baseline changes.

Web interaction-light evidence: eight tests pass in Chromium via flutter test
--platform chrome, covering foreground repaint isolation, runtime reduced
motion, multi-pointer ownership, localized light pixels in both themes, nested
hover/cancel cleanup and preserved taps. Log: /tmp/hermes-interaction-web.log.
This verifies simulated lighting behavior on the Web test renderer; it does
not measure frame time or establish native refraction/physical-light fidelity.
No production code or visual baseline changed.

Whole ChatScreen Web fixture: three Chromium tests now pass for Classic and
Liquid light/dark, including initial long-history scroll, final-message
header/composer bounds, search toggle/selected colors and 25-match navigation.
The first Web run failed on pending 30-second timers: fake API omitted
savedPrompts/providerQuota and inherited their HTTP implementations. Providing
empty fixture responses removes that external-request path. Log:
/tmp/hermes-chat-web-integration.log. This is full-page widget behavior with
fake data, not authenticated release usage or subjective visual acceptance.

Responsive shell Web verification: all 12 app_shell_accessibility tests pass
in Chromium via flutter test --platform chrome. Coverage includes phone/wide
reduced-motion behavior, desktop/tablet palette entry, short tablet rail and
approval-sheet reachability, Arabic RTL and scaling. Log: /tmp/hermes-shell-web.log.
This extends browser behavior coverage beyond ChatScreen; it does not verify
real approval submission, native frame timing or overall visual fidelity.
No production changes or golden updates in this verification pass.

Action-group corner unification: GlassActionGroup delegates nested material
and clipping to GlassSurface instead of its own ClipRRect shortcut. Nested
groups therefore use continuous corners and the shared local-opacity policy.
Twelve group/corner tests pass, retaining identical parent pixels, one blur/
specular/edge plane and actionable controls. Structural assertions now count
the nested wrapper separately from rendered material. Analysis/diff pass.
Existing unaccepted Liquid preview goldens remain unchanged.

Grouped local-opacity Web regression: local opaque override coverage now
includes GlassActionGroup as well as direct GlassSurface. All ten action-group
tests pass in Chromium, including inherited material pixels, continuous clips,
single rendered material, local alpha=1 fill and action taps. Log:
/tmp/hermes-group-opacity-web.log. No production or golden changes; this
does not replace whole-page visual review.

Selection corner consistency: Liquid GlassSelectionRow now uses a
RoundedSuperellipseBorder for its Material, keeping the existing 18px radius,
colors, minimum size and motion policy. Classic still returns its original
child. Fifty-four selection/contrast/approval-mode tests and static analysis
pass. This extends the unaccepted continuous-corner prototype to selected
rows; it is not a new visual approval or a golden-baseline update.

Request-flow Web coverage: all 28 request_store tests pass in Chromium.
The suite includes Liquid route keyboard/safe-area geometry, wide request
scrolling, RTL, embedded approval scope resolution, explicit deny and clarify
discard confirmation, plus owner-scoped request retention. Log:
/tmp/hermes-request-web.log. Requests use test doubles, not a real gateway.
The embedded approval fixture is not itself Liquid-themed; do not conflate
separate Liquid-route and embedded-flow coverage with full Liquid inline
approval acceptance. No production or golden changes in this pass.

Liquid inline follow-up: the embedded RequestSheet fixture now independently
selects Liquid without switching to a modal route. Chromium passes all 29
request tests, including Classic and Liquid inline Allow Once sending the
expected request id, runtime session id and once choice to the fake gateway,
then clearing pending count. Log: /tmp/hermes-inline-liquid-web.log. This
closes the theme/embedded-fixture gap above, not full transcript integration,
real backend delivery, busy/error behavior or subjective visual acceptance.

Inline Liquid narrow-screen follow-up: the Liquid embedded approval fixture
now runs at 320x640 with 2x text scaling. All 29 request tests pass in Chromium,
including tapping Allow Once and verifying scoped fake-gateway payload and
pending-count removal. Log: /tmp/hermes-inline-large-web.log. No layout fix was
needed for this fixture; real transcript embedding and visual acceptance
remain separate. No production source or baseline changes.

Search focus contour: Liquid GlassSearchField replaces its circular
OutlineInputBorder with a foreground RoundedSuperellipseBorder matching the
glass radius. Focus retains a 2px primary ring; the TextField is retained as
the listenable builder's child. Six search behavior tests and analysis pass.
Classic remains unchanged. This extends the continuous-corner prototype, not
its visual acceptance; existing golden differences remain open.

Search focus Web follow-up: all six search tests pass in Chromium, now
including blur removing the continuous focus ring without changing input
text, alongside keyboard clear and focus preservation. Log:
/tmp/hermes-search-ring-web.log. No production or golden changes; this
verifies focus state behavior, not pixel-level ring contrast or visual fidelity.

Post-search/selection integration: current ChatScreen and AppShell Chromium
suites pass all 15 cases after continuous search focus and selected-row shapes.
Log: /tmp/hermes-current-pages-web.log. Existing assertions cover long-chat
content bounds, search selection/navigation, responsive shell and accessibility
controls. No new whole-page visual comparison or golden approval is implied.
No production changes in this pass; port 9000 remains available.

Composer contour: Liquid input decoration now uses a radius26 continuous
shape for its focused 1.4px accent outline. Its duplicate resting white border
is removed so the shared GlassSurface edge defines the resting contour.
Classic retains its existing decoration. Accessible navigation now suppresses
the decoration animation alongside disableAnimations. Seven composer/chat
tests and analysis pass. This extends the unaccepted corner prototype; it
does not resolve outstanding visual-golden or whole-page fidelity review.

Composer pinned emoji action: the actual long-chat fixture exposed an emoji
toggle outside the 390px viewport, at the end of the horizontally scrolling
configuration row. Liquid now keeps this insertion action at the trailing
edge while configuration controls remain scrollable; Classic is unchanged.
The 320px light/dark fixtures include a crowded configuration row and verify
the toggle remains hit-testable and stationary while that row scrolls, emoji
insertion, 44px targets and closing. VM composer/alignment/chat coverage
passes, as do all five Chromium chat/emoji cases. Actual-chat cases also
verify dock bottom following across emoji expansion/collapse and keyboard
resize. Closing checks grid removal while preserving inserted editor text.
This is a layout/reachability improvement, not native material fidelity or
whole-page visual acceptance; no golden baseline is updated in this pass.
