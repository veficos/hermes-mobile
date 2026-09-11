# Core-page review capture catalog

These are reproducible review candidates, not approved golden baselines.
The current image viewer does not provide a legible rendering; optical
approval must remain open until the PNGs can be reliably inspected.

## Generate

Current task filter supplement: /tmp/hermes-task-filter-review-yNApcB
contains 20 images / 10 pairs at 390px light/dark 1x/2x: list, board,
filter overview, selected assignee and tenant picker. The 12 filter images
use a RepaintBoundary above MaterialApp's Navigator via builder, so modal
routes and barriers are included rather than capturing only the home page.
Run: flutter test --no-pub --dart-define=UI_REVIEW_DIR=CAPTURE_DIR
test/kanban_accessibility_test.dart --plain-name 'width=390'. Create the
directory first. Eight Classic/Liquid cases pass in /tmp/task-filter-review.log;
eight Chromium keyboard cases pass in /tmp/task-filter-review-browser.log
without capture enabled. Analysis passes. These are standalone controlled
scenes, not AppShell or live API captures. Published separately at
/ui-review-task-filters/compare.html (HTTP 200). Metadata checks pass;
all images remain unapproved. No production code changed in this supplement.

Latest core route batch: /tmp/hermes-liquid-release-review-ulPU9r contains
28 images / 14 pairs, from /tmp/liquid-integration-capture.log (four cases
pass), at /ui-review-release/compare.html. This is the refreshed source batch
for the bfeb08ee41d310e3d259bc092f6bc15b2f285ae5c870a729088cdbb973a5df12
release, not the older baseline batch below. Visual approval remains open.

Matched 390px review batch: /tmp/hermes-liquid-baseline-rSL8XT contains
28 populated AppShell images (14 light/dark pairs), captured together with
1x/2x text. Source run: /tmp/liquid-baseline-capture.log. Selection:
`flutter test --no-pub --dart-define=SHELL_REVIEW_DIR=CAPTURE_DIR
test/app_shell_accessibility_test.dart --plain-name
'Liquid populated shell Bot More roundtrip 390'`. Create CAPTURE_DIR first.
The subset includes Bots, its management Sheet, Tasks list/board, More and
rich Chat top/tail. Published separately at /ui-review-baseline/compare.html;
the 260-image /ui-review-current gallery remains historical. Rebuilding the
Web app does not recapture these images: record their originating batch,
not the latest served script hash, when reviewing them. All remain unapproved.

Bot portrait integration samples: 20 standalone bots-{brightness}-{scale}
[-width].png now include the decoded non-square metadata image in the real
directory. Capture run /tmp/bot-portrait-captures.log and independent Chromium
run /tmp/bot-portrait-browser.log each pass all 20 cases. Gallery now
260 images/125 pairs; exact-scene/static checks and sample HTTP fetch pass.
These do not replace shell-bots samples and are not photographic optical
approval or network avatar-fetch evidence.

Home entry states: ENTRY_REVIEW_DIR with the 'Liquid home session entry'
selection in app_shell_accessibility_test.dart exports 45 new shell-feedback
images: pending and loaded for zh/en/ar × 320/390/1280 × light/dark at 2x,
plus failed on the nine dark retry paths. Actual AppShell/Home and resumed
ChatScreen are captured, using controlled API/gateway data, not live service.
Initial capture run failed on native audio plugin initialization in runAsync;
the new capture flag now activates the existing capture-only channel mocks.
All 18 capture cases pass (/tmp/home-entry-state-captures-fixed.log).
Gallery now indexes 240 images/115 exact pairs; nine dark failure images
remain intentionally unpaired. Static checks and sampled failure PNG HTTP
200 pass. These add whole-route context, not optical/VoiceOver approval.


Error-feedback review addition: error_snackbar_accessibility_test.dart now
exports six feedback-error-ar-320-{light,dark}-{1.0,2.0,3.0}.png via
UI_REVIEW_DIR. Capture boundary includes Navigator/Scaffold and snackbar;
the underlying page is a controlled Open-button fixture, not real Home.
Six capture tests pass (/tmp/error-feedback-captures.log), targeted analysis
passes. Gallery accepts feedback as its own page category and correctly
classifies 3x (previous parser classified every non-2x image as 1x). Added
1/2/3 filter checks. Gallery now indexes 195 images/97 pairs; static checks
and sampled 3x image HTTP 200 pass. No optical approval; pending Home status
screenshots still outstanding. Production release remains 8190bb02... .

Latest home-entry/list-menu release: 28 capture cases refresh populated
shell routes and three-pane files (/tmp/home-entry-release-captures.log).
189 images/94 exact pairs remain indexed and static checks pass. Served
release/local script hash:
07f7eb39739f010421cf7c8f1a66308f30fd459901e407d3ab481fc637c1c6d9.
Compare route HTTP 200. Unchanged standalone approval/appearance samples
retain earlier timestamps; this is not all-scene optical approval.

Latest file-sidebar integration: four populated three-pane files refreshed
after 44px target and expander-label changes; capture cases pass in
/tmp/liquid-file-integration-captures.log. Gallery remains 189 images/94 pairs,
with other unchanged samples retaining prior timestamps. Port 9000 serves
a53ad42bfe0529216f1a57192941f02cfbf3df1ab5e141e88e767746d04d26e9
(local/HTTP hash matched); gallery checks pass, compare route HTTP 200.
These are review candidates, not optical approval or a fresh all-scene capture.

Latest navigation revision: all 24 populated AppShell capture scenarios were
refreshed after moving XL footer destinations into the scrollable directory.
Gallery remains 189 images / 94 pairs; unchanged standalone samples keep their
timestamps. Released app hash is now
f741e07a6765e37917e61636feb4a4a97f86ae3634e4844c6ef96b627f2e488b.
Capture log: /tmp/navigation-release-captures.log. No visual approval.

Paired review entry: ui-review-current/compare.html now lays out exact-scene
light/dark counterparts side by side, with source filename/timestamp and
links to full-size PNGs. pairs.json contains 94 matched pairs from the 189
current images; unmatched samples are retained in the main gallery. Generator
requires equal dimensions and matching scene/scale filenames. Checker verifies
pair membership, dimensions, HTML references and approved=false. These are
static structure checks, not browser layout or optical approval. Direct image
inspection again returned encoded payload, so no optical conclusion was made.

Three-pane supplement: current gallery now has 189 images, adding four
chat-three-pane-1280-{dark,light}-{1.0,2.0}.png. These show actual ChatScreen
after a composer-submitted controlled turn, with session rail and docked
workspace sidebar. Test also collapses/expands the sidebar and verifies
composer bounds and retained session. Sidebar file content is not populated;
not live gateway or AppShell session-entry evidence. Capture log:
/tmp/three-pane-captures.log (four passing cases).

2026-09-11 latest gallery supersedes historical counts below: 185 fresh
images from /tmp/hermes-ui-sep11-APIoI8 are indexed at
http://localhost:9000/ui-review-current/. Shell/inline approval capture
selection passes 29 cases, reading preview passes 12. This set includes
six-width shell routes, rich chat top/tail, management sheets, tasks, More,
inline approval and standalone reading previews. It excludes old standalone
directory captures and historical plain chat from the manifest. Capture
source and released app include the latest candidate material/status changes;
app hash 6896868c9d2224cd14b25ce1f5ad08a41ae85600a44ac5b58db4ea74d9447223.
No optical approval; screenshots remain controlled VM rendering, not Safari
or iPhone screenshots. Rebuild the gallery with build_ui_review.mjs using
this source directory, then run check_ui_review.mjs against the destination.

Latest preview/typography refresh: Bots and More candidates were refreshed
after Liquid phone row typography. Task bulk candidates have now also been
refreshed, and twelve appearance-{light,dark}-2.0-{zh,en,ar}-{true,false}.png
samples added by appearance_reading_preview_test.dart. The appearance
captures use a named viewport RepaintBoundary at 320x844 before selection;
they show the initial scroll position, not the entire potentially taller
2x preview, nor the full settings page. Together the capture run passes
36 cases (/tmp/preview-release-captures.log). The gallery generator accepts
appearance images and offers a page filter for them. These additions do
not constitute optical approval. Regenerate the gallery after release build.


Current core-page review gallery: 67 VM core-page tests and five chat approval
tests pass (/tmp/current-core-captures.log, /tmp/current-chat-captures.log).
85 fresh PNGs are in /tmp/hermes-ui-review-gQctnu. The new reusable command

node tool/build_ui_review.mjs /tmp/hermes-ui-review-gQctnu build/web/ui-review-current

copies the candidates and generates a manifest plus a self-contained HTML
gallery at http://localhost:9000/ui-review-current/ (HTTP 200 verified).
The gallery is temporary build output; rerun this command after a clean
release build. Source tool syntax check and diff check pass. The manifest
explicitly records approved=false. Current image tool still returns encoded
payload rather than a reliably viewable image, so no optical acceptance is
claimed. Gallery does not include task bulk/move overlays or full app shell.

Use an existing output directory (for example `/tmp`):

```sh
flutter test --no-pub --dart-define=UI_REVIEW_DIR=/tmp test/agent_diagnostics_test.dart test/kanban_accessibility_test.dart test/more_layout_test.dart
flutter test --no-pub --dart-define=CHAT_REVIEW_DIR=/tmp test/chat_webui_minor_parity_test.dart --plain-name 'Liquid ChatScreen inline approval'
```

## Coverage

Task bulk state gallery: task_bulk_move_flow_test.dart now wraps the entire
Navigator child in a capture boundary, including its destination sheet.
UI_REVIEW_DIR exports tasks-bulk-{classic,liquid}-{light,dark}-2.0-
{selected,destination,pending,failed}.png: sixteen 320x844 controlled-state
captures. Twenty move flows pass (/tmp/task-bulk-captures-fixed.log).
Classic coverage exposed fixed BottomAppBar height clipping 2x text; it now
uses a content-sized opaque Material/SafeArea. Targeted analysis/diff pass.
The existing gallery now contains 101 captures; destination PNG HTTP 200
verified. These add overlay review candidates, not optical or native approval.
Production changes are not yet release-built; gallery is newer than app JS.

Bot hierarchy refresh: all twenty standalone bots-{light,dark}-{scale}
captures across 320/390/430/768/1280 have been regenerated after the
Create/Manage action consolidation. Twenty-one capture tests pass in
/tmp/bot-directory-current-captures.log; sampled 320px files decode as
320x844 PNGs. These depict the initial directory before management opens.
They do not refresh shell-bots, show the management sheet, or constitute
optical acceptance. Twenty-one Chromium directory interaction tests pass
separately in /tmp/bot-directory-browser.log.

Avatar editor initial page: UI_REVIEW_DIR with avatar_editor_picker_test.dart
now includes an available generation prompt; earlier screenshots without
the prompt are stale and must be regenerated before comparison.
exports avatar-editor-{light,dark}-320-2x.png (English, procedural preview,
no image-generation service, pinned Save, 320x844). Ten VM cases pass in
/tmp/avatar-page.log. These are initial-route candidates, not keyboard,
selected-image or overlay captures; viewer did not permit optical review.

Current-source refresh: 24 VM capture cases pass
(/tmp/editor-more-captures.log), regenerating all twenty standalone More
page candidates and eight document-editor images. Document filenames:
`document-{classic,liquid}-{light,dark}-2.0.png` and
`document-keyboard-{classic,liquid}-{light,dark}-2.0.png`. The editor is
320x844, English, 2x text, formatted JSON; keyboard variants simulate a
300px view inset, not the OS keyboard graphics. Run with UI_REVIEW_DIR and
test/document_editor_navigation_test.dart. More is captured before search;
existing shell-more images have NOT been refreshed by this command.
File headers verify sampled dimensions; no optical approval is inferred.

Current scope clarification: the chronological notes below describe additions
at different checkpoints. Populated phone-shell fixtures now include Bots,
More, Tasks list/board and a directly pushed ChatScreen at 320/390/430 with
2x text. Older statements that populated chat/tasks are absent apply only
to their earlier checkpoint. Populated wide-shell routes, live session entry,
and optical review remain missing. More source has since changed its title,
offline identity and search layout; older More PNGs must be regenerated
before using them as evidence of current rendering.

Populated phone-shell cases also push a real ChatScreen route above AppShell
with one user/assistant message pair and disconnected stores. Files:
shell-chat-{320,390,430}-{light,dark}-2.0.png. Six capture cases pass. The
test checks that the underlying navigation is not hit-testable while chat
is open and restores on pop. This is explicit test route navigation, not
the real session-list/open/resume flow, live streaming or inline approval.

The same six populated phone-shell cases now also visit Tasks, switch list
to board, leave for More and return to Tasks. A locally populated KanbanStore
supplies one named task and an empty completed column. Additional files:
shell-tasks-{list,board}-{320,390,430}-{light,dark}-2.0.png. All six VM capture
cases pass. This adds task content and bottom navigation to the review set,
not real API writes, horizontal board traversal, viewport anchoring or optical
acceptance. Populated chat and wide-shell core-route captures remain open.

Populated phone-shell candidates now cover actual navigation Home -> Bots ->
More -> Bots -> Home at 320/390/430px, light/dark, 2x text. The Bot directory
uses a fixed test Store with one named Bot; status remains disconnected.
Run the shell command below with --plain-name 'Liquid populated shell'.
Files: shell-bots-{320,390,430}-{light,dark}-2.0.png and
shell-more-{320,390,430}-{light,dark}-2.0.png. Six VM cases export twelve
captures. These include bottom navigation; they do not cover live cached
Bot refresh, populated chat/tasks, menus, keyboard or optical acceptance.

Whole-shell home candidates are now available using:

```sh
flutter test --no-pub --dart-define=SHELL_REVIEW_DIR=/tmp test/app_shell_accessibility_test.dart --plain-name 'Liquid whole shell'
```

Files: `shell-home-{320,390,430,768,1280}-{light,dark}-{1.0,2.0}.png`.
These twenty cases mount the actual AppShell and home route with Chinese
labels, controlled disconnected stores and no populated history. They include
responsive application navigation, but not OS chrome, keyboard, route
switching, populated chat/tasks/Bots or an open overlay. All twenty VM capture
cases pass; optical review is still open. Do not substitute these empty-home
captures for populated core-page integration.

Bots, Tasks and More now run at widths 320/390/430/768/1280, all at height
844, in light/dark and 1x/2x text. The 320px filenames below stay compatible;
other widths append `-390`, `-430`, `-768` or `-1280` before `.png`.
Example: `tasks-board-dark-2.0-768.png`. Wide captures still mount feature
pages, not the responsive AppShell; their results cannot prove shell navigation
or tablet/desktop multi-pane behavior.

| Page | Files | Data/state | Viewport |
| --- | --- | --- | --- |
| Bots | `bots-{light,dark}-{1.0,2.0}.png` | Two named bots, long description/name, running service, diagnostics collapsed | 320×844 |
| Tasks | `tasks-{light,dark}-{1.0,2.0}.png` | Three tasks, long bilingual title, assignee, priority and comments; list before search | 320×844 |
| Task board | `tasks-board-{light,dark}-{1.0,2.0}.png` | Same populated fixture after switching to board | 320×844 |
| More | `more-{light,dark}-{1.0,2.0}.png` | Identity/directory fixture | 320×844 |
| Chat | `chat-{light,dark}-{1.0,2.0}-false.png` | Tools, inline approval and composer; scroll placement varies with text scale | 320×844 |

Bots/tasks use the actual feature screens with controlled stores/transports.
Their boundaries do not include AppShell bottom navigation or OS chrome.
Bot avatars exercise local fallback, not remote image loading. Task board
captures show the initial horizontal position, not all columns. These limitations prevent claiming the
matched whole-application screenshot gate is complete.

## Review procedure

1. Generate pairs in one run with the same Flutter version and renderer.
2. Confirm dimensions, capture state and fonts before comparing optical values.
3. Inspect navigation/content separation, clipping, readability and action
   visibility; record findings with the filename and reproduction state.
4. Repeat at 390/430px and tablet/desktop, including shell navigation, keyboard,
   populated boards, diagnostics, menus and settings appearance states.
5. Only after human-readable review, approve new baselines where warranted.
   Never change a comparator tolerance merely to suppress a mismatch.
# Current populated phone review supplement

Latest rich-text integration: 29 capture cases refreshed current rich
chat top/tail, shell pages/overlays and inline approval after contrast and
RTL corrections. Current release now includes these changes:
b8f57324d8d27dbc57217796468f2c4f7eafd5736c9a99f2c10252f78aa4e7db.
Earlier rich-image versus release mismatch notes are superseded. Gallery
remains 305; old plain-chat images retain their historical timestamps.
No optical approval or golden replacement.

Rich chat supplement: 48 shell-chat-rich-top/tail images show real pushed
ChatScreen with user heading/quote/list/link and assistant heading/list,
at six widths, light/dark and 1x/2x. All 24 roundtrips pass in
/tmp/rich-chat-shell.log, including visible user heading after scrolling
to top. Total gallery: 305. Plain shell-chat images are older historical
samples; rich images include unbuilt user Markdown changes and are not
pixel-matched to current served app. No optical approval.

Manage Bots overlay supplement: 24 shell-bots-sheet captures now accompany
the six-width, light/dark, 1x/2x base-page matrix. Actual Manage Bots opens
the existing sheet, Escape dismisses it, and the roundtrip continues.
All 24 scenarios pass (/tmp/shell-overlay-review.log); gallery has 257
images. Select bots + shell-route to view base and open-sheet scenes.
This closes the absence of this matched overlay artifact, not optical
approval or coverage of every application sheet.

Reading typography refresh: all 120 shell-route and five inline-approval
chat captures regenerated after the 17px phone conversation change;
29 scenarios pass (/tmp/reading-integrated-captures.log). Gallery remains
233 images; other standalone captures retain their own timestamps.
Current served release hash:
58af6d460294e4e45f2ac874b07bcc2c862c02bff32b768f85bb4cdecb367c9f.
These are pending review, not approved visual baselines.

Latest extension: populated navigation captures now include 768/900/1280
in both brightness and text scales, bringing shell-route artifacts to 120
and total gallery to 233. All 24 roundtrips pass in
/tmp/populated-shell-wide.log. 900 uses NavigationRail and 1280 XL
navigation. Five board columns provide actual overflow on wide layouts.
Earlier statements below that wide-shell artifacts are missing are
superseded; wide optical review and docked multi-pane chat remain open.

The current ui-review-current gallery adds 60 shell-route captures from
12 actual AppShell roundtrips (320/390/430, light/dark, 1x/2x). Select
“真实应用导航／路由” to distinguish these from standalone samples. Bots,
More, task list and board include the application navigation; shell chat
is a pushed route and intentionally does not include bottom navigation.
All data is controlled/offline. Ordinary chat samples do not include the
approval fixture present in separate standalone chat captures. No optical
approval is implied. Wide populated shell and matched open overlays remain
missing. Source: /tmp/hermes-ui-review-gQctnu; test log:
/tmp/populated-shell-current.log. Gallery total: 173 PNGs.
