# Liquid UI delivery — complete scope

Status: in progress. Source of scope: the user's approved P0–P5 optimization
proposal. Component tests do not constitute whole-page or device acceptance.

## P0 — authoritative baseline

- [x] Fresh full test/analyze results, with failures classified.
- [x] Current release hash and HTTP delivery verification.
- [ ] Matched screenshots for chat, bots, tasks, more/settings.
- [ ] Reproduction catalog for pagination jumps, overscroll blanking and
      asynchronous content resize.
      Fixture/manual procedures are now in interaction-reproduction-catalog.md;
      device reproduction recordings and general resize cases remain open.

## P1 — interaction reliability

- [ ] Explicit scrolling lifecycle: initial, following, reading, fetching,
      restoring, explicit return-to-latest; session ownership and cancellation.
- [ ] Ten consecutive real pagination transactions with variable-height rows,
      delayed responses, continued drag, retry, concurrent streaming.
- [ ] Image/tool late resize and window trimming preserve visible content.
- [ ] Session switching ignores stale requests and scroll callbacks.
- [ ] Loading/error/end-of-history feedback remains visible and accessible.
- [ ] Task/more overscroll, filters, view switching and keyboard transitions.

## P2 — shared layout rules

- [ ] Title/collapse, spacing, primary/secondary actions, list rows and cards.
- [ ] Real avatars, cropping, loading/fallback, long names and status badges.
- [ ] Light/dark and 2x typography examples, 44px touch targets.

## P3 — complete page integration

- [ ] Chat: shared reading margins; stable content surfaces; one composer
      material shared by attachments, references and actions.
- [ ] Bots: compact overview; list-first hierarchy; restrained status labels;
      diagnostics without excessive nested cards; preserve all operations.
- [ ] Tasks: coherent search/filter/view controls; readable card hierarchy;
      narrow-screen list and explicit horizontal board navigation.
- [ ] More/settings: deduplicated directory, consistent rows and icons;
      appearance preview; diagnostics and dangerous actions separated.
- [ ] Navigation/overlays: consistent safe-area spacing, title collapse,
      dismissal, keyboard, unsaved-state guards and terminology.

## P4 — materials and motion

- [ ] Distinct navigation, floating-control and overlay material recipes.
- [ ] Calibrate light/dark tint, edge lighting and backdrop continuity using
      reliable whole-page comparisons, not arbitrary alpha edits.
- [ ] Avoid duplicate blur/tint; content remains a stable reading plane.
- [ ] Unified press/selection/page-state motion, reduced-motion fallback.
- [x] Document Web/native limits. True refraction is a separate optional
      feasibility study, not a required unsupported Web rendering promise.
      Evidence: platform-material-contract.md explicitly documents shared
      Flutter rendering, absent refraction, simulated lighting, Web/native
      accessibility differences and outstanding device validation.

## P5 — release acceptance

- [ ] 320/390/430px, tablet and desktop; matched light/dark core pages.
- [ ] 1x/2x text, keyboard/focus, semantics, 4.5:1 normal text contrast.
- [ ] Reduced transparency/motion and native accessibility transitions.
- [ ] Release device measurements: renderer/device/data size, p50/p95 frame
      times and missed 16.7ms budgets during scroll/stream/page merge/overlays.
- [ ] iPhone build and real-device review; availability must be verified.
- [ ] Reviewed visual baselines; never loosen tolerance to conceal failures.
- [ ] Full regression, final build, served-hash check and evidence report.

## Execution notes

Chat transparency overlap fix (explicit user request): disabled transcript
underlap beneath the AppBar and composer while retaining glass controls.
User and assistant bubble backgrounds no longer use .86 alpha. The dock's
non-overlapping layout now observes viewport changes too, preserving bottom
following on keyboard/composer resizing without pulling history readers.
Updated geometry assertions require the transcript viewport between header
and composer, plus opaque mounted bubble colors. 48 related VM tests pass
(/tmp/chat-opacity-regression.log); 11 Chromium history/layout cases pass
(/tmp/chat-opacity-browser2.log). Full analysis passes, diff clean. Final
release builds in 106.1s (/tmp/chat-opacity-build-final.log), local and
port 9000 script hashes match:
271f3e2c5d30eb180e495b456a64e0d07ef31e8caa9de63a346ded3edfb1b4aa.
Retained review galleries are historical and predate this layout change.
This deliberately supersedes the earlier chat-underlap design to address
the reported transparency-induced visual displacement. No iPhone optical
review or full-suite golden approval is inferred from this targeted fix.

Refresh evidence follow-up: renamed the computation harness's 250ms network
check to idle isolation, removed its unexercised routing/debounce claims and
now require zero requests/bytes in that unmounted harness. A new actual
SessionStore test injects two bursts of 30 sessions.changed events, verifies
zero early calls at 249ms, one scoped list request per burst at 250ms, and
retained experts profile. All 25 profile/history VM tests pass
(/tmp/session-burst-full.log); the new Chromium case passes
(/tmp/session-burst-browser.log); full analysis and diff checks pass. This
uses a controlled API and event stream, not live network bytes, navigation,
in-flight coalescing or device frame timings. The profile integration
harness itself was analyzed, not run on a physical device. No production
change or release; larger live/visual/device gates remain open.

Performance evidence correction: chat_session_performance_test previously
hard-coded profile_mode=true and exported zero maxima without availability
metadata despite rendering no chat UI. It now uses a tested report helper
with actual build mode/platform, explicit computation-only/no-live-network
scope and null timing values when engine samples are unavailable. Two new
report tests plus five metrics tests pass (/tmp/performance-evidence-test.log);
full analysis passes (/tmp/performance-evidence-analyze.log), diff clean.
This corrects evidence reporting, not measured device performance. Existing
idle network assertions do not inject navigation and are not routing proof.
Read-only environment check: localhost:8877 health reports backend_running
true, but it is the existing service, not a verified isolated test backend.
No session/prompt/approval was submitted. flutter devices lists Linux only;
xcodebuild and xvfb-run are absent. The smoke integration uses a local fake
backend; neither it nor the microbenchmark closes live backend/iPhone gates.
No production change or new release in this checkpoint.

Task overlay review coverage: task test capture now has a boundary outside
the Navigator and exports filter overview, selected assignee and tenant
picker at 390px light/dark 1x/2x. Capture run passes eight cases, producing
20 PNGs / 10 pairs including 12 previously missing modal images. Source:
/tmp/hermes-task-filter-review-yNApcB; log /tmp/task-filter-review.log.
All 49 task VM cases pass (/tmp/task-filter-review-full.log), eight Chromium
keyboard cases pass (/tmp/task-filter-review-browser.log), full analysis
and diff checks pass. Published /ui-review-task-filters/compare.html returns
200; metadata checker passes. The image viewer again returned encoded data
without reliably inspectable rendering, so no optical judgment or golden
approval is claimed. This is a test/capture change only; production remains
bfeb08ee41d310e3d259bc092f6bc15b2f285ae5c870a729088cdbb973a5df12.

Integration release published: flutter build web --release --no-pub
--no-wasm-dry-run succeeds in 109.7s (/tmp/liquid-integration-build.log).
Local and HTTP port 9000 main.dart.js SHA256 match:
bfeb08ee41d310e3d259bc092f6bc15b2f285ae5c870a729088cdbb973a5df12.
This includes task selected-filter presentation and semantic headings;
their earlier unpublished notes are historical. Fresh review is available
at /ui-review-release/compare.html (HTTP 200), with 28 images / 14 pairs;
older current/baseline galleries are retained, not refreshed. Full analysis
and diff checks pass. Two golden failures, optical review, real backend
composite interactions and iPhone/Safari acceptance remain open.

Current integration checkpoint: full analysis passes
(/tmp/liquid-integration-analyze.log); full VM regression finishes with
2,173 passes and two failures, exclusively preview liquid dark/light
(/tmp/liquid-integration-full.log). No golden or tolerance was changed.
Four current-source AppShell capture cases pass
(/tmp/liquid-integration-capture.log), producing 28 PNGs / 14 matched pairs
in /tmp/hermes-liquid-release-review-ulPU9r. Scenes cover Bots, Bot management
Sheet, More, task list/board and rich chat top/tail at 390px light/dark 1x/2x.
They do not show the task filter sub-sheets or constitute live API/device
evidence. Gallery metadata/filter checks pass; optical approval remains
false. This fresh batch supersedes the older batch for current-source
review, without changing the historical gallery's provenance.

Task filter headings: the outer filter sheet and assignee/tenant pickers
now share localized titleLarge headings marked Semantics(header: true),
without adding a keyboard stop. The current source contains this change
and the selected-row treatment below. Recorded verification: 49 VM cases
in /tmp/task-headings-final.log and eight 390px Classic/Liquid light/dark
1x/2x Chromium cases in /tmp/task-headings-browser.log pass. These cover
keyboard selection/cancellation and filter preservation, not VoiceOver or
optical acceptance. Integration release verification is tracked separately.

Task selected-filter presentation: assignee and tenant pickers now share
_filterChoice using GlassSelectionRow and a trailing check for the active
Liquid value, including All. The row supplies selected semantics and no
independent blur. Classic retains its plain ListTile appearance. Callbacks
use the picker context to pop the selected value. Reopening reviewer now
asserts the selected tile/check branch; all 49 task VM cases pass
(/tmp/task-selected-final.log), eight 390px Classic/Liquid light/dark 1x/2x
Chromium cases pass (/tmp/task-selected-browser.log). Analysis/diff clean
(/tmp/task-selected-analyze.log). Not optical approval or a complete contrast
audit; this presentation change is not yet built/published.

Task nested-filter cancellation: after selecting reviewer, keyboard reopens
that selector then Escape cancels it. Assertions preserve reviewer and the
keyword, keep the outer Sheet visible, restore focus to the assignee row,
and continue into tenant selection. All 49 VM cases pass
(/tmp/task-filter-cancel-final.log); eight 390px Classic/Liquid light/dark
1x/2x Chromium cases pass (/tmp/task-filter-cancel-browser.log). Analysis/
diff clean (/tmp/task-filter-cancel-analyze.log). This is nested modal
cancellation evidence, not native back gestures or VoiceOver. No production
change or rebuild; current release remains unchanged.

Task filter keyboard entry: removed the remaining options/menu taps from
the filter segment. Starting with the active search field, bounded Tab and
Enter now open options, choose filters, choose both nested values, and
Escape closes the Sheet. Existing assertions retain the keyword and show
both chosen filters. All 49 VM cases pass
(/tmp/task-keyboard-entry-final.log), eight 390px Classic/Liquid light/dark
1x/2x Chromium cases pass (/tmp/task-keyboard-entry-browser.log). Analysis/
diff clean (/tmp/task-keyboard-entry-analyze.log). This closes the prior
filter-entry pointer dependency, not keyboard arrival from app launch,
every menu action or screen-reader acceptance. No production change/build.

Nested task-filter keyboard selection: after opening the filter Sheet,
toolbar scenarios now use bounded Tab traversal and Enter for assignee
entry/selection and tenant entry/selection, then Escape the outer Sheet.
Targets must be focused and visible; no programmatic focus or ensureVisible
is used for these four activations. All 49 VM cases pass
(/tmp/task-filter-keys-final.log), all eight 390px Classic/Liquid light/dark
1x/2x cases pass Chromium (/tmp/task-filter-keys-browser.log). Analysis/diff
clean (/tmp/task-filter-keys-analyze.log). The initial options/menu entry
still uses taps; this is not a complete keyboard-only or VoiceOver gate.
No production changes or rebuild.

Task Classic compatibility: toolbar/search/filter route matrix now runs both
Classic and Liquid (40 combinations), using each style's actual TextField.
Liquid-specific unlimited title and glass bulk-bar assertions remain scoped
to Liquid; Classic covers shared search/IME/filter/focus behavior, not that
bulk-bar branch. All 49 VM cases pass (/tmp/task-classic-final.log); eight
390px light/dark 1x/2x style cases pass Chromium
(/tmp/task-classic-browser.log). Analysis/diff clean
(/tmp/task-classic-analyze.log). Optional captures remain Liquid-only so
existing review filenames are not overwritten by Classic. Test names now
use lowercase style prefixes; select 'task toolbar and search' for both.
No production change/build; current task-search release remains unchanged.

Task search release: full regression 2:00, 2,153 passes and only the existing
Liquid preview light/dark golden failures (/tmp/task-search-release-full.log).
Full analysis clean (/tmp/task-search-release-analyze.log). Release build
113.3s (/tmp/task-search-release-build.log); local/9000 main.dart.js SHA256
match 887b49c34a177f5f0e8fed2777355097d0610c466530ae23a4de734911492a4f.
Task Escape/composition/focus changes now published. Historical galleries
restored, baseline comparison HTTP 200 and 14 pairs verified, not recaptured
or approved. Environment recheck still finds Linux only and no xcodebuild;
iPhone/Safari/native IME acceptance remains unverified.

Task filter UI route: the first assignee/tenant setup in toolbar scenarios
now uses actual task-options menu, filter Sheet and nested selection Sheets
instead of store.setFilters. Escape closes the outer filter Sheet; visible
chips and clear action verify state propagation while keeping the keyword.
All 29 VM task cases pass (/tmp/task-filter-ui-final.log); four 390px
light/dark 1x/2x Chromium cases pass (/tmp/task-filter-ui-browser.log).
Analysis/diff clean (/tmp/task-filter-ui-analyze.log). Board choices remain
fixture data, and taps do not prove full keyboard traversal or VoiceOver.
No production change/publication; task-search source batch remains pending.

Task search composition/filter preservation: toolbar scenarios now inject
non-collapsed composition and verify Escape leaves search open, commit text,
set assignee/tenant filters, and verify Escape clears only the keyword.
Enter reopening explicitly checks EditableText focus, then existing bulk
actions still run. All 29 task cases pass (/tmp/task-ime-filter-final.log);
four 390px Liquid light/dark 1x/2x Chromium cases pass
(/tmp/task-ime-filter-browser.log); analysis/diff clean
(/tmp/task-ime-filter-analyze.log). Filter setup and IME are controlled
fixtures, not actual filter-dialog navigation or native IME evidence. No
new production change; preceding task search fix remains unpublished.

Task search keyboard continuity: the real toolbar fixture reproduced Escape
leaving search open (/tmp/task-search-before.log). Task page now handles
Escape outside active composition, clears only the search filter via the
existing toggle behavior, and explicitly transfers focus between field and
trigger. The test closes with Escape and reopens with Enter before existing
bulk actions. All 29 task accessibility cases pass
(/tmp/task-search-final.log), four 390px Liquid light/dark 1x/2x Chromium
cases pass (/tmp/task-search-browser.log). Analysis/diff clean
(/tmp/task-search-analyze.log). Native IME, Classic-specific keyboard and
filter-dialog focus are not established by this run. Source change remains
unpublished; the 9000 search release is unchanged.

Search batch published: full regression finishes in 1:47 with 2,153 passes
and only the two existing Liquid preview golden failures
(/tmp/search-release-full.log). Full analysis clean
(/tmp/search-release-analyze.log); actual AppShell More search/clear/reopen
fixture passes Chromium (/tmp/search-release-shell-browser.log). Release
build completes in 111.0s (/tmp/search-release-build.log); local and 9000
script hashes match cacbb5324ebf176c8e8968f3bbbe47406c0a81c3277af9ff0e5442d69de889b6.
Search Escape, composition guard and explicit focus return are now included.
Both historical galleries restored; baseline compare HTTP 200/14 pairs.
No recapture, optical approval, native IME or Safari acceptance inferred.

More Classic/Liquid compatibility: the directory search matrix now exercises
both visual styles, covering search/filter/empty state, composition Escape,
committed Escape, saved position, and Enter reopening via returned focus.
All 40 VM cases pass (/tmp/more-styles-final.log); all eight 390px
light/dark 1x/2x style cases pass Chromium (/tmp/more-styles-browser.log).
Analysis and diff checks pass (/tmp/more-styles-analyze.log). Optional
capture names distinguish Classic to prevent overwriting Liquid images;
no new images generated here. No additional production change; the search
batch remains unpublished and native/device gates remain open.

More search focus lifecycle: reproduced Enter failing to reopen search after
Escape (/tmp/more-focus-before.log). The page now owns action and field
FocusNodes, focusing the field on open and the trigger on close. GlassButton
accepts an optional external focusNode and forwards it to IconButton. An
initial action-only fix broke input focus on reopening; explicit field focus
resolved that regression. Final layout/button VM run passes 37 cases
(/tmp/more-focus-final2.log); four 390px Chromium cases pass
(/tmp/more-focus-browser2.log), including composition protection and
directory offset retention. Analysis/diff clean
(/tmp/more-focus-analyze2.log). This batch remains unpublished; native IME
and screen-reader acceptance remain open.

More composition guard: simulated non-collapsed IME composition reproduced
the new Escape handler prematurely removing search
(/tmp/more-ime-before.log). MoreScreen now ignores Escape while composition
is active, allowing platform handling; after committed text the existing
Escape close/offset restore still works. All 20 Liquid layout cases pass
(/tmp/more-ime-final.log), four 390px light/dark 1x/2x cases pass Chromium
(/tmp/more-ime-browser.log), analysis/diff pass
(/tmp/more-ime-analyze.log). Mock text-input composition does not prove
native Chinese/Japanese IME event ordering or Safari behavior. Search exit
and this guard remain unpublished; no new release or optical approval.

More search keyboard exit: reproduced Escape leaving the focused search
field open (/tmp/more-escape-before.log). MoreScreen now handles Escape
only while searching, using the existing close/reset and directory-offset
restoration path; other keys propagate. All 20 Liquid directory matrix
cases pass with the Escape/offset assertion (/tmp/more-escape-final.log);
four 390px light/dark 1x/2x Chromium cases pass
(/tmp/more-escape-browser.log). Analysis/diff pass
(/tmp/more-escape-analyze.log). This verifies closing and position retention,
not subsequent focus placement, IME composition, or VoiceOver. The source
change is not yet built/published; current 9000 release remains unchanged.

Recovery batch 2 published: full regression completes in 2:04 with 2,133
passes and only preview_liquid_dark/light golden failures
(/tmp/liquid-recovery2-full.log). Full analysis clean; all 82 request tests
pass Chromium (/tmp/liquid-recovery2-analyze.log,
/tmp/liquid-recovery2-browser.log). Release builds in 116.6s
(/tmp/liquid-recovery2-build.log); local and HTTP main.dart.js hash match:
95b86ebefa6623c030d7861bfc12064d142686ad88a7e737155176f96ee9cc11.
Expiry-before-load and deferred dirty persistence are now published. Both
review galleries restored; baseline compare returns 200 and verifies 14
pairs. Captures are retained from their earlier batch, not regenerated for
this release. Golden approval and real-device/business gates remain open.

Deferred live persistence after unusable recovery: missing, malformed JSON
and invalid pending-shape snapshots each reproduced loss of a live request
received while restore awaited preferences (/tmp/restore-dirty-before.log).
Restore now starts deferred dirty persistence even without a successful
snapshot load; no-live-change snapshots remain untouched. Six new cases
cover both outcomes. All 82 request tests pass (/tmp/restore-dirty-final.log);
three live cases pass Chromium (/tmp/restore-dirty-browser.log). After
null-aware map-entry lint cleanup, seven snapshot cases pass again
(/tmp/restore-dirty-snapshot-final.log), analysis/diff are clean
(/tmp/restore-dirty-analyze.log). Persistence is mocked and checked with a
second RequestStore, not a browser restart. This and expiry-before-load
remain unpublished production changes; the 9000 release is unchanged.

Expiry before recovered row load: reproduced a synchronous expiry event
during restore leaving both the expired and background same-ID requests
actionable (/tmp/restore-expiry-before.log). Recovery now keeps temporary
expiry predicates, applies them after scope resolution and records expired
results before enqueue notification. All 76 request tests pass
(/tmp/restore-expiry-final.log); the new scoped case, including a listener
asserting no transient actionable expired row, passes Chromium
(/tmp/restore-expiry-browser-final.log). Analysis and diff checks pass
(/tmp/restore-expiry-analyze.log). The test uses synchronous mock events and
preferences, not a real browser restart/backend. This fix is not yet built
or published; 9000 remains the preceding integration release.

Bot keyboard route continuation: removed programmatic management focus and
pointer activation from the management/group portion of the directory
matrix. Bounded Tab traversal now reaches management, Enter opens its Sheet,
Escape returns focus, then Enter/Tab/Enter reaches the group editor; Escape
cancels that editor and restores management focus. All 21 VM cases pass
(/tmp/bot-tab-matrix.log); four 390px light/dark 1x/2x Chromium cases pass
(/tmp/bot-tab-browser.log). Analysis and diff checks pass
(/tmp/bot-tab-analyze.log). This establishes reachability and return focus
for this workflow, not optimal Tab order, every action, or VoiceOver.
No production change; the existing 9000 release remains unchanged.

Bot management keyboard checkpoint: existing populated directory scenarios
now explicitly focus the management button, open its sheet with Enter,
dismiss with Escape, and assert focus returns to that button before the
existing group creation flow. All 21 cases pass VM and Chromium, including
20 light/dark x 1x/2x x 320/390/430/768/1280 combinations
(/tmp/bot-keyboard-matrix.log, /tmp/bot-keyboard-browser-all.log). Targeted
analysis and diff checks pass (/tmp/bot-keyboard-analyze.log). The initial
Chrome filter matched nothing because numeric test names omit .0 on Web;
the complete-file run supplies the browser evidence. Programmatic initial
focus does not prove Tab traversal or VoiceOver. No production change or
rebuild; the screenshot tool still did not afford reliable optical review.

Recovery integration published: release build completes in 105.2s
(/tmp/liquid-integration-build.log). Local and port-9000 main.dart.js SHA256
both equal 561eaa725cd653ebd9b4d43565f3f0042d74dd7989d134d4bbf709ad1e1363ce.
The disposed/live-merge/clear/singleflight recovery batch is now included.
Fresh matched captures are available at /ui-review-baseline/compare.html
(HTTP 200, 28 images/14 pairs, unapproved); /ui-review-current preserves
the historical 260-image gallery and must not be mistaken for this baseline.
This publication is for ongoing review, not P5 acceptance.

Current integration and matched review capture: full regression finishes
with 2,126 passes and only the two known Liquid preview golden failures
(/tmp/liquid-integration-current.log); full analysis is clean
(/tmp/liquid-integration-analyze.log), all 75 request cases pass Chromium
(/tmp/liquid-integration-browser.log). Four populated AppShell roundtrip
cases at 390px, light/dark and 1x/2x, pass and generate 28 images from this
worktree in /tmp/hermes-liquid-baseline-rSL8XT. They cover Bot/list Sheet,
tasks list/board, More, and rich chat top/tail. Gallery checking confirms
14 exact-scene pairs; this is metadata/DOM-stub validation, not optical
approval. Logs: /tmp/liquid-baseline-capture.log. Real gateway, Safari,
iPhone and VoiceOver gates remain open; golden baselines are not changed.

Overlapping recovery: restore now shares one in-flight future, preventing a
second call from clearing the exclusions established by clear/clearScope
during the first load. The regression failed before the change
(/tmp/restore-overlap-before.log); all 75 request tests pass afterward
(/tmp/restore-overlap-final.log), and the overlapping case passes Chromium
(/tmp/restore-overlap-browser.log). Targeted analysis is clean
(/tmp/restore-overlap-analyze.log). This closes the overlapping-call gap in
the preceding entry, not expiry-before-load or live backend acceptance.

Clear during recovery: reproduced clearScope/clear being undone by a pending
snapshot load (/tmp/restore-clear-before.log). Recovery now keeps temporary
scope predicates for clears during its async read, applying them after owner
resolution only to recovered rows; unrelated background requests still load.
Two cases pass VM and Chromium (/tmp/restore-clear-final.log,
/tmp/restore-clear-browser.log); all 74 request cases pass, targeted analysis/
diff pass (/tmp/restore-clear-analyze.log). Overlapping restore calls and
expiry of not-yet-loaded rows remain unaudited. No build/publication; current
recovery lifecycle batch remains in the worktree.

Live request/recovery merge: reproduced old persisted command overwriting a
new same-scope gateway command received while restore awaited preferences
(/tmp/request-live-restore-before.log). Recovery enqueue now fills missing
entries without replacing live queue objects, after normal scope resolution;
restored resolutions also no longer overwrite existing results. All 72
request tests pass (/tmp/request-live-restore-final.log); live-command race
passes Chromium (/tmp/request-live-restore-browser.log); targeted analysis/
diff pass (/tmp/request-live-restore-analyze.log). Not a complete audit of
clear/expiry-before-load or overlapping restore calls. This and disposed
restore guard remain unpublished.

Disposed recovery guard: SessionStore constructor starts requests.restore
unawaited, so asynchronous lifecycle overlap is real. A new test starts
restore then disposes immediately; old implementation still repopulated
pending state (/tmp/restore-dispose-before.log). restore now exits when
disposed both before and after awaiting preferences. All 71 request tests
pass (/tmp/restore-dispose-final.log), targeted analysis/diff pass
(/tmp/restore-dispose-analyze.log). No browser rerun or build this round.
Concurrent live-event merge is still an open recovery concern, not assumed
absent based on startup order. This guard remains unpublished.

Recovery/replay integrated release: full regression 2,121 passes with the
same two Liquid preview golden failures in 2:03
(/tmp/recovery-release-full.log). Full analysis/diff pass
(/tmp/recovery-release-analyze.log), all 70 request cases pass Chromium
(/tmp/recovery-release-browser.log). Release build 115.1s
(/tmp/recovery-release-build.log). Local and port-9000 script hashes match:
2aef4968668b87078e59d1c6c1f88ed3ac32319fe22e7c4d5d68872a063180c6.
Active-request replay suppression, deferred recovery persistence and loading
terminal records before pending items are now published. Historical gallery
restored (260 images/125 pairs), checker passes, compare route 200. No new
visual baseline or native/browser-restart acceptance; full objective remains
in progress.

Conflicting recovery snapshot: reproduced pending+expired entries for the
same scope being restored as actionable (/tmp/restore-expired-before.log).
restore now stages pending objects and loads terminal records before enqueue;
existing exact expired replay suppression applies before notification. Test
observes every listener notification, not just final state, to ensure no
transient actionable request. All 70 request tests pass
(/tmp/restore-expired-final.log), new case passes Chromium
(/tmp/restore-expired-browser.log), targeted analysis/diff pass
(/tmp/restore-expired-analyze.log). Uses preferences mock; real restart and
concurrent live-event restore remain unverified. Latest replay/recovery batch
is not built/published.

Request recovery persistence: two successive restore instances reproduced
loss of expired resolutions when the same persisted snapshot also contained
pending rows (/tmp/request-restore-before.log). enqueue during restore wrote
a partial snapshot before resolved rows were loaded. Intermediate writes are
now deferred until restore finishes successfully, then listeners notified.
Missing/invalid snapshot does not trigger an unconditional replacement write.
All 69 request tests pass (/tmp/request-restore-final.log); the two-restore
case passes Chromium (/tmp/request-restore-browser.log); targeted analysis/
diff pass (/tmp/request-restore-analyze.log). Storage uses the preferences
test implementation, not a browser restart/localStorage acceptance test.
Concurrent restore/live-event merging remains unaudited. This and in-flight
replay suppression remain unpublished.

Pending-response replay suppression: reproduced an extra actionable queue
entry when a request is re-emitted during its RPC
(/tmp/request-flight-replay-before.log). enqueue now checks active responses
by exact request id/kind/scope before inserting. Two delayed-response tests
verify no second send, zero pending on success and exactly one retryable
request on failure. All 68 request tests pass
(/tmp/request-flight-replay-final.log); both cases pass Chromium
(/tmp/request-flight-replay-browser.log); targeted analysis/diff pass
(/tmp/request-flight-replay-analyze.log). This covers replays during an active
send, not arbitrary post-success replay or server execution idempotency.
Not yet built/published; latest port-9000 release remains d7da5bd3.

Expiry batch integrated release: full suite finishes in 2:08 with 2,117
passes and only the retained Liquid dark/light preview golden failures
(/tmp/expiry-release-full.log). Full analysis/diff pass
(/tmp/expiry-release-analyze.log); prior current-source Chromium request
suite has 66 passes (/tmp/expiry-replay-browser.log). Release build 113.6s
(/tmp/expiry-release-build.log). Local and port-9000 HTTP script SHA256:
d7da5bd389b4b244c0d5faffc6e878e3ab5e3dce5f30fe1be174e6b34cf12806.
Scoped expiry, persisted terminal labels, in-flight result priority and
bounded expired-replay suppression are now published. Existing gallery
restored: 260 images/125 pairs, static checker passes, compare route 200.
No new image approval, golden update, true backend composite workflow or
device performance/accessibility acceptance. Full objective remains open.

Routed expiry/replay: new routed-event test confirms same session/request ids
on separate owners remain isolated, then reproduced an expired approval
re-entering the queue on request replay (/tmp/expiry-replay-before.log).
enqueue now rejects replay matching an expired resolution's exact scope/kind
key after owner resolution. This is bounded by retained resolution history,
not permanent deduplication. All 66 request cases pass VM and Chromium
(/tmp/expiry-replay-final.log, /tmp/expiry-replay-browser.log); targeted
analysis/diff pass (/tmp/expiry-replay-analyze.log). Expiry batch remains
unpublished pending full integration and build. Device/whole-chat/backend
acceptance gates remain open.

In-flight expiry presentation: two delayed gateway cases reproduced the
submitting card masking an already recorded expiry
(/tmp/expiry-inflight-before.log). RequestSheet now prioritizes expired
resolution over its retained submitting request; late failure does not show
a misleading retry error for an expired request. Both late success/failure
cases assert immediate expired label, absent approval action, retained
terminal display and no requeue/SnackBar. All 65 request tests pass
(/tmp/expiry-inflight-final.log); both cases pass Chromium
(/tmp/expiry-inflight-browser.log); targeted analyze/diff pass
(/tmp/expiry-inflight-analyze.log). Regular failure retry remains covered.
This does not revoke any server-side action. Expiry changes still unpublished;
routed expiry and replay behavior remain to be verified.

Expiry state integration: reproduced unscoped interactive.expire removing
the wrong same-id session request (/tmp/request-expire-before.log). Both
event paths now expire within supplied owner/session scope, retain expired
resolution and invalidate matching active responses. RequestSheet presents
a localized expired label and timer-off icon rather than pending/success;
added five locale strings and regenerated localization. Tests cover same-id
session isolation and an actual expiry event→inline result transition with
no approval actions. All 63 request tests pass (/tmp/request-expire-final.log);
targeted analysis/diff pass (/tmp/request-expire-analyze.log). An initial
nullable-id compile error was corrected before those results. Still pending:
expiry during an in-flight visible submission, routed owner-specific expiry,
replayed request handling and browser/integration checks. Not published.

Approval result/layout integrated release: full regression 2,112 passes and
the same two Liquid preview golden failures in 1:56
(/tmp/approval-layout-release-full.log). Full analysis/diff pass
(/tmp/approval-layout-release-analyze.log). All 61 request and four tool-action
tests pass Chromium (/tmp/approval-layout-release-browser.log); tool cases
cover disclosure/hide/keyboard, not live approval integration. Release build
113.2s (/tmp/approval-layout-release-build.log), local and HTTP SHA256:
88d9adb5b126bb16eec94c8b52a0c9bffb70bbcd7d481452165fb69667fef741.
Localized approval results, distinct denial icon and wrapping title/status
are now published on port 9000. Historical gallery restored (260/125 pairs),
checker passes, compare route 200. No visual baseline changes or device
acceptance. Next workflow gap observed: ChatStore tests stamp expired status
on an interaction, but RequestSheet result rendering must still be audited
against that terminal event and scope, not just successful responses.

Approval narrow-screen result matrix: expanded once/deny/session flow to
zh/en/ar × light/dark at 320px and 2x text (18 cases), checking localized
results, non-success denial icon and text bounds. Initial run passed six
Chinese cases but failed twelve English/Arabic cases: the pending title/status
Row overflowed (English 121px horizontally), also causing excess height
(/tmp/approval-result-matrix.log). Replaced that header Row with a wrapping
layout; all 18 cases pass VM and Chromium
(/tmp/approval-result-matrix-after.log, /tmp/approval-result-matrix-browser.log).
All 61 request cases pass (/tmp/approval-result-matrix-full.log), targeted
analysis/diff pass (/tmp/approval-result-matrix-analyze.log). Result labels
and this header fix remain unpublished. Controlled fixture layout checks
do not imply whole-chat visual or device acceptance.

Resolved approval display: reproduced raw protocol choices (once/deny/session)
instead of localized text in the inline result (/tmp/approval-result-before.log).
Approval results now reuse localized choice labels; deny/declined approvals
use a neutral cancel icon rather than the success check. Three cases exercise
actual click→RPC→resolved-card flow for once/deny/session. All 46 request tests
pass VM (/tmp/approval-result-final.log); these three cases pass Chromium
(/tmp/approval-result-browser.log); targeted analysis/diff pass
(/tmp/approval-result-analyze.log). No new localization keys or backend protocol
changes. This does not establish every backend terminal-status presentation.
Not yet built/published; port 9000 remains the preceding banner release.

Background banner integrated release: semantics inspection found a tappable
focusable node without button role; explicit button semantics now added.
Light/dark assertions cover the label, button/focus flags, tap/focus actions,
contrast and Tab→Enter activation. A test handle cleanup issue was corrected
before verification. All 43 request cases pass Chromium
(/tmp/banner-final-browser.log); full suite 2,094 passes and the two known
Liquid preview golden failures in 1:56 (/tmp/banner-final-full.log). Full
analysis/diff pass (/tmp/banner-final-analyze.log). Release build 110.9s
(/tmp/banner-final-build.log); local and HTTP script SHA256 match:
d3cd44b79d7b6fdc076be6c8a073d88e182b915c62fb518c29f83c29e8fd02c4.
All recent banner target/wrapping/queue/owner/contrast/semantics changes are
now served on port 9000. Existing gallery restored, 260 images/125 pairs,
checker passes and compare route 200. No fresh visual approval or VoiceOver
acceptance claimed; those and real backend composite workflows remain open.

Background banner readability/keyboard: added light/dark composited label
contrast and actual Tab→Enter action checks. Light warning-colored text
failed at 2.833:1 (/tmp/banner-contrast-before.log). Banner now uses an opaque
warning-tinted reading background and palette primary text; orange icon/border
retain status meaning. A mistaken text1 palette field was corrected to text
before successful verification. All 43 request tests pass VM
(/tmp/banner-accessibility-final.log); full analysis/diff pass
(/tmp/banner-release-analyze.log). Browser rerun evidence is in
/tmp/banner-accessibility-browser.log. These checks cover theme-derived
contrast and keyboard activation, not optical review or VoiceOver semantics.
No integration build/publication yet; banner changes remain unpublished.

Background banner owner/session integration: three additional widget cases
use the actual SessionStore owner from resumeSession. Same request/runtime
ids on another connection or another profile must open the foreign request;
dismissing it preserves the foreground request and hides the banner. Resuming
the previously background session also hides the banner without removing its
pending request. All 41 request tests pass VM and Chromium
(/tmp/banner-owner-final.log, /tmp/banner-owner-browser.log); targeted
analysis/diff pass (/tmp/banner-owner-analyze.log). This closes the explicit
owner-collision fixture gap noted below, not real multi-server backend or
full ChatScreen acceptance. No production change this round; the preceding
banner changes still await integration build/publication.

Background request banner: reproduced a 35px touch target at 320px/Arabic
1x, plus forced single-line truncation (/tmp/request-banner-before.log).
Banner now has a minimum 44px target and wrapping labels. Also reproduced
no banner when a foreground request preceded a background one
(/tmp/request-banner-queue-before.log). Selection now filters the queue for
background requests, counts that subset and opens its first entry; session
changes are observed and explicit different owners are treated as background.
Three new cases cover Arabic 1x/2x target/wrapping/tap and foreground-first
queue routing. All 38 request tests pass VM and Chromium
(/tmp/request-banner-final.log, /tmp/request-banner-browser.log); targeted
analysis passes (/tmp/request-banner-analyze.log). Different-owner same-id
behavior still needs an explicit integration case; no native/optical approval
claimed. Banner changes are not yet built/published.

Approval fixes integrated release: full suite finishes in 1:58 with 2,086
passes and only the retained Liquid light/dark preview golden failures
(/tmp/approval-release-full.log). Full analysis passes
(/tmp/approval-release-analyze.log); all 35 request tests pass Chromium
(/tmp/approval-release-browser.log). Release build succeeds in 103.2s
(/tmp/approval-release-build.log). Local and port-9000 HTTP main.dart.js
SHA256 both equal
3c167694b58d9190fc5dbe505f322e181bfe0d8a3dd5fd87ab796f852a995a63.
Confirmation ownership, pending-card/retry presentation and response lifecycle
invalidation are now published. Existing gallery restored with 260 candidates
and 125 pairs; checker passes and compare route HTTP 200. No fresh screenshots,
optical approval, true-backend acceptance or native-device measurements are
implied by this release. Whole-page and device gates remain unfinished.

Request lifecycle cancellation: reproduced clearScope followed by a late
failed approval RPC reviving the closed session's request ahead of an
unrelated background request (/tmp/request-scope-before.log). RequestStore
now tracks active response identities and invalidates them on clearScope,
clear, explicit-id dismiss and dispose. Cancelled response success cannot
record a local resolution; cancelled failure cannot requeue. Ordinary
failure/retry behavior is retained. Both respond paths share _sendAt, also
preserving caller resolution metadata for the FIFO response path. All 35
request tests pass (/tmp/request-lifecycle-final.log), including late-failure
scope isolation and late-success clear/dismiss/dispose cases. Targeted
analysis/diff pass (/tmp/request-lifecycle-analyze.log). This does not cancel
an already-sent server operation and does not establish end-to-end backend
semantics. Latest three approval changes remain unpublished; full integration
and release build are still required.

Approval pending/retry presentation: delayed RPC test reproduced disappearance
of the embedded request card before a response arrived
(/tmp/approval-retry-before.log). RequestStore temporarily removes the request
while sending; RequestSheet now retains its submitted request locally, keeps
the controls disabled and shows a localized Sending live region until the
result is known. Failure restores actionable controls and the pending request;
success shows the resolved card. New test checks delayed state, disabled
duplicate tap, failure SnackBar, retry and final resolution, with exactly two
RPCs for two attempts. All 31 request tests pass
(/tmp/approval-retry-after.log), the retry scenario passes Chromium
(/tmp/approval-retry-browser.log), targeted analysis/diff pass. This is
embedded RequestSheet plus controlled gateway, not full ChatScreen/backend
or a system screen-reader test. Both this and the preceding confirmation
ownership fix remain unpublished pending integration verification/build.

Approval confirmation ownership fix: reproduced a stale Always-Allow dialog
authorizing the next FIFO request after the displayed request was dismissed.
Fail-before log /tmp/approval-confirm-race-before.log records an unintended
approval.respond for request second with choice always. RequestSheet now
checks the exact PendingRequest identity after confirmation; replaced/removed
requests cannot inherit consent. The same guard protects the dismiss
confirmation, and _respond returns early for busy/absent targets. Regression
also confirms fresh consent for second sends exactly one correct RPC. All
30 request tests pass (/tmp/approval-confirm-final.log), the new race case
passes Chromium (/tmp/approval-confirm-browser.log), targeted analyze passes
(/tmp/approval-confirm-analyze.log). These are controlled gateway fixtures,
not real-backend chat approval acceptance. Not yet built/published.

Performance diagnostics integrated release: full regression now reports
2,080 passes and the same two Liquid preview golden failures in 2:01
(/tmp/liquid-current-integration-tests.log). Full analysis passes
(/tmp/liquid-current-integration-analyze.log). Six About performance dialog
cases pass in Chromium, covering en/zh/ar and Classic/Liquid at 2x, including
copy payload and reset/close behavior (/tmp/liquid-current-performance-browser.log).
Clipboard is mocked: browser permission and native clipboard remain unproved.
Release build succeeds in 113.5s (/tmp/liquid-current-integration-build.log);
local and port-9000 HTTP script SHA256 both equal
fc7cf7e0a0e4c4fad51efd9f2a47c0cdbf2893fa1ee5999f9a18b7808d6cef31.
The sample-availability fields and performance-entry localization are now
published. Gallery restored: 260 historical candidates/125 pairs, checker
passes, compare route HTTP 200; no recapture or approval implied. An image
tool attempt again returned image data without a reliably inspectable view;
no golden baseline was updated. Whole-page and real-device gates remain open.

Performance export action verification: six About dialog cases (en/zh/ar,
Classic/Liquid, 2x) now activate Copy and inspect the platform clipboard
message. Export exactly matches the displayed JSON and includes sample
availability/interval ratio fields; copy leaves frame counters and dialog
intact. All six pass (/tmp/performance-copy.log), targeted analysis/diff
pass. This proves application clipboard payload, not browser clipboard
permissions or native OS integration. No production change/build; previous
metric availability/localization changes remain unpublished.

About performance directory consistency: removed hard-coded English title/
subtitle and dialog title, adding en/zh/zh_Hant/ja/ar localization keys and
regenerating localization output. Dialog tests now cover en/zh/ar in
Classic/Liquid at 2x, retaining close/copy reachability and reset checks.
All 11 dialog/metrics cases pass (/tmp/performance-l10n.log); targeted
analysis/diff pass. JSON metric keys remain stable for diagnostics tooling.
Not published; latest metric availability and localization changes still
need integration build. No device performance measurements claimed.

Device/performance evidence clarity: flutter devices currently lists only
Linux; xcodebuild/xcrun/idevice_id are not on PATH. Actual iPhone/Safari gates
remain open. Render snapshot now marks sample availability explicitly and
exports null interval ratio when no frames were sampled, preventing empty
windows being described as zero-cost performance. Existing percentile fields
and numeric benchmark API preserved. Seven metrics/dialog tests pass
(/tmp/metrics-availability.log); targeted analysis/diff checked separately.
This is diagnostic correctness, not a performance measurement. Not built.

Avatar ownership integrated release: fresh full regression finishes in 2:08
with 2,076 passes and only the two retained Liquid preview golden failures
(/tmp/avatar-owner-release-full.log). Full analyze/diff pass. Three avatar
ownership/cache/inflight cases pass in Chromium, process exits 0
(/tmp/avatar-owner-release-browser.log). Release build completes in 111.6s;
local and port-9000 HTTP main.dart.js hash match:
2ddd4f55f7038c839a6612d9c78756e012fc5125188656cd19f4de6fcf42622a.
Gallery restored with unchanged 260 candidates/125 pairs, static checks
pass and compare route HTTP 200. No new optical/capture approval, golden
updates or device acceptance. Avatar race/owner/cache fixes now published.

Avatar inflight isolation: replacing a runtime while get_asset remained
pending blocked the new owner's fetch because single-flight was keyed only
by Bot ID (reproduced expected two calls/actual one in
/tmp/avatar-flight-owner.log). Key now includes runtime instance. Extended
test verifies immediate new fetch, stale completion ignored, another refresh
does not duplicate the still-pending new fetch, and new data eventually
applies. All 24 BotStore tests pass (/tmp/avatar-flight-fixed.log), targeted
analyze/diff pass. Unpublished with prior avatar ownership fixes; full
regression/browser and integration release still pending.

Avatar cache owner isolation: a completed old avatar was reused by a new
runtime under the same connection ID (reproduced in /tmp/avatar-cache-owner.log).
Cache now records runtime identity and refresh discards mismatched cached
images, allowing a new get_asset request. Test verifies old image absent,
second asset request and new-image insertion. Upload/clear completions also
verify their captured runtime before local mutation. All 24 BotStore tests
pass (/tmp/avatar-cache-fixed.log); final targeted analysis/diff pass.
This is controlled ownership/cache evidence, not live image fetch or all
concurrent edit ordering. Unpublished; current release 8190bb02... .

Avatar pending-response owner guard: new test removes a registered runtime
and adds another under the same connection ID before pending get_asset
completes. It reproduced stale image insertion (/tmp/avatar-owner-race.log).
Backfill now captures the runtime instance and rejects completion if it is
no longer the registry's current instance, in addition to revision/disposed
guards. All 23 BotStore tests pass (/tmp/avatar-owner-fixed.log); targeted
analyze/diff pass. Does not prove eviction of images already cached before
replacement or concurrent upload ordering; those remain separate concerns.
Not release-built; 9000 remains 8190bb02... .

Avatar backfill mutation race: a controlled pending profiles.get_asset
response reproduced an old avatar reappearing after clearBotAvatarImage
success (/tmp/avatar-clear-race.log, expected null but old data returned).
Added per-Bot avatar revision: successful upload/clear advances it, and
backfill checks the captured revision plus disposed state before caching or
updating rows. Upload/clear also stop local mutation after disposal. All 22
BotStore tests pass (/tmp/avatar-race-regression.log); targeted analyze/diff
pass. Tests use protocol data, not actual image decoding/live network.
Connection-runtime replacement and multiple concurrent edits need separate
verification; this fix is not a claim that all avatar races are solved.
Not built/published; current release remains 8190bb02... .

Bot decoded-image browser/capture gate: all 20 actual directory portrait
scenarios pass in clean Chromium, exit 0 in 1:04 without intervention
(/tmp/bot-portrait-browser.log). All 20 capture cases also pass
(/tmp/bot-portrait-captures.log), adding standalone populated-image directory
samples to the current source set. Gallery now 260 images/125 exact pairs,
static checks and sampled bots-dark-2.0.png HTTP 200 pass. These scenes are
distinct from shell-bots and remain unapproved. Image data is a generated
flat-color 20x80 PNG, so photographic crop quality/network fetch remain open.
No production change or build; current app remains 8190bb02... .

Populated Bot-directory decoded-image integration: existing AgentScreen
diagnostics scenarios now supply a generated 20x80 PNG in review Bot metadata,
wait for actual RawImage decoding with bounded frame advancement, verify
BoxFit.cover and 44x44 geometry, and compare real avatar/title top alignment.
All 20 cases pass across 320/390/430/768/1280 light/dark 1x/2x
(/tmp/bot-real-portrait.log), retaining management/diagnostics/offline actions.
Targeted analyze/diff pass. Initial test used displayName to locate BotAvatar;
actual name input is profile, so finder corrected to review. No production
change or new screenshots. Browser and optical review of this integrated
image fixture remain outstanding; decoded flat-color test PNG is not approval
of real photographic cropping, network avatar fetch or list loading behavior.

Avatar browser gate revalidated: old PID 3786297 and Chrome 3826734 were
still live after seven hours. CDP 44713 showed bot_row_alignment_test iframe
with no canvas, undefined flutterCanvasKit and a loading Promise; not a
completed test result. Explicit SIGINT cancelled the old runner; both PIDs
then absent. Clean current-source Chrome invocation with explicit executable
passes all six avatar/row cases and exits 0 without intervention
(/tmp/avatar-row-clean-current.log); VM also passes all six
(/tmp/avatar-row-vm-current.log). Tests cover invalid→decoded portrait→
procedural fallback, 20x80 image BoxFit.cover at 44x44, animation accessibility
cycles, and a generic row's 1x/2x leading/title alignment. Row fixture uses a
placeholder leading box, so this is not populated Bot directory real-image
integration, optical approval or device performance evidence. No source UI
change/build. Original intermittent browser initialization cause unresolved.

Home feedback capture gap narrowed: added pending/failure/loaded screenshot
hooks to actual Home-entry integration tests; reused capture-only audio
channel mocks after initial MissingPluginException failures. All 18 corrected
capture cases pass, yielding 45 new whole-route candidates at three widths
and zh/en/ar, 2x. Gallery now 240 images/115 exact pairs, static checks pass;
dark-only failures are not paired with unlike scenes. No production changes,
build, live backend or visual approval; app remains 8190bb02... .

Feedback visual artifacts: six Arabic 320px light/dark 1/2/3x snackbar
captures added from passing error_snackbar_accessibility tests. Gallery
now 195 images/97 exact pairs; feedback category and 3x metadata/filter
support verified. Targeted analysis, script syntax and diff pass; sampled
3x PNG HTTP 200. No production edits/build; not optical approval or a
real Home pending/error scene. See review-capture-catalog.md for commands.

Feedback release integration: build succeeds in 105.0s
(/tmp/feedback-release-build.log), publishing home pending feedback,
session-stat wrapping and large-text error/retry layout plus guard/color.
Local and port-9000 HTTP main.dart.js hashes match:
8190bb02b88e59ecf181cfaa0514d88f5b93c84a5c44ff544d026d1c1c5fbc4a.
Production matches the prior /tmp/feedback-full.log regression (2,073 passes,
two known Liquid golden failures); subsequent changes are keyboard tests/docs.
Gallery reconstructed from existing 189 captures/94 pairs, static checks
pass and comparison URL returns HTTP 200. No new captures this turn: new
pending/error states are not represented or optically approved by that gallery.

Retry keyboard gate: extended the six Arabic 320px light/dark 1x/2x/3x
snackbar cases to reopen the notification, traverse actual Tab focus to its
action and activate with Enter. Checks exactly one new callback, dismissed
snackbar, and focus no longer belonging to it. All six pass in VM and
Chromium (/tmp/error-keyboard.log, /tmp/error-keyboard-browser.log); targeted
analysis/diff pass. This proves keyboard reachability/dismissal, not a
specific focus-return destination or VoiceOver. Production unchanged since
the 2,073-pass/two-golden-failure full regression. Release build now running
under session 84986, log /tmp/feedback-release-build.log; not yet verified.

Shared retry behavior/readability gate: large-text retry callback now has a
single-shot guard, matching standard SnackBarAction's protection while hiding.
Its foreground uses snackbar content color instead of inversePrimary (which
is not guaranteed to match this app's always-dark snackbar backing). Six
new Arabic 320px light/dark 1x/2x/3x tests verify bounds, >=44px height,
duplicate-callback prevention and, for custom large-text action, >=4.5:1
contrast on black/white composited backgrounds. Six VM cases pass; combined
with localized Home recovery all 24 Chromium cases pass without intervention
(/tmp/feedback-browser.log). Full regression completes in 2:09 with 2,073
passes and two unchanged Liquid golden failures (/tmp/feedback-full.log).
Full analysis and diff checks pass. No visual approval or release build;
home pending/stat wrapping/snackbar fixes remain unpublished at this point.

Localized pending/retry layout: moved Home loading feedback below SessionCard
so it no longer replaces metadata badges or competes with the title. Expanded
real home-entry tests to zh/en/ar × 320/390/1280 × light success/dark retry,
all at 2x. This exposed 25px English stat-row overflow in SessionCard and
166px Arabic retry-action overflow in the framework SnackBar action row.
Stat labels now flex/wrap; shared error SnackBar uses a full-width wrapping
retry TextButton below content for text scaling above 1.5x, preserving the
standard action at normal text size. All 18 cases pass after removing the
temporary error dump (/tmp/home-feedback-final.log); targeted analysis/diff
pass. New shared layout needs broader regression/browser/contrast review;
not release-built. Current 9000 remains 07f7eb39... .

Home pending-entry feedback: _opening previously prevented duplicate requests
without rendering any pending state. Added per-entry identity and localized
loading text in that session row, with live-region semantics; error/finally
clears it. Reuses existing secondary text color and does not add an indefinite
animation. Entry/retry cases now assert status presence/semantics and removal
on failure; expanded to 320/390/1280px 2x (light success/dark retry). All 69
AppShell tests pass (/tmp/home-opening-regression.log), targeted analyze/diff
pass. This is VM layout/state evidence; browser, other locales, VoiceOver
and updated screenshots remain unverified for the new label. Not release-built;
9000 remains 07f7eb39... .

Home-entry/list-menu integrated release: full test run completes in 1:48
with 2,053 passes and only the two retained Liquid preview golden failures
(/tmp/home-entry-release-full.log). Full analyze and diff checks pass.
Release builds in 115.5s (/tmp/home-entry-release-build.log), publishing
visible list-entry menus and route-aware desktop chat back navigation.
Local and HTTP-served main.dart.js SHA256 agree on port 9000:
07f7eb39739f010421cf7c8f1a66308f30fd459901e407d3ab481fc637c1c6d9.
Twenty-eight capture cases pass (/tmp/home-entry-release-captures.log),
refreshing populated shell routes and three-pane files. Gallery regenerates
189 images/94 pairs; static checks pass, compare route HTTP 200. Standalone
unchanged approval/appearance samples retain their earlier timestamps.
No visual baseline updates, optical approval, native review or live backend
acceptance. Home retry browser evidence remains the prior four passing cases.

Home-entry recovery completion: delayed entry tests now tap twice while
resume is pending (one RPC only), and dark 390/1280px 2x cases fail the
first resume then activate the actual SnackBar retry. No route opens early;
failed entry leaves no durable session; retry loads history and actual
back navigation returns home. Four VM and four Chromium cases pass
(/tmp/shell-entry-retry.log, /tmp/shell-entry-retry-browser.log); Chromium
exits 0 without intervention. AppShell/chat combined passes 100 tests;
targeted analysis/diff pass. This turn adds tests/evidence, not production
changes. Previous list-menu and desktop-back fixes remain unbuilt; current
9000 app is a53ad42b... . Live transport/device acceptance remains open.

Actual AppShell home-entry coverage found a desktop navigation defect:
ChatScreen suppressed its back affordance at XL widths assuming the shell
remained visible, but Home pushes ChatScreen over the shell. Now a non-embedded
chat on a poppable route exposes ChatPageBackButton regardless of width;
embedded chats do not add a competing back action. New 390/1280px 2x fixtures
use real Home/SessionStore resume and transcript loading through a controlled
API/gateway, waiting on a delayed resume before route entry, verifying loaded
history and returning through the visible button. Initial fixture fixes keep
onboarding dismissed and scroll the session row into the unobscured viewport.
All 65 AppShell cases pass (/tmp/shell-entry-full.log). No live service,
Safari, dark-entry or device performance acceptance; source is not yet built.
This closes direct-push-only coverage for this home entry path, not every
session-list/robot/notification entry path.

File-list menu discoverability: list rows previously exposed entry operations
only through long-press, unlike tree rows. Added a visible IconButton, with
Liquid 44px minimum and Classic compact sizing. Both list/tree menu labels
now identify the entry by name. New populated 1280px/2x case traverses Tab,
opens via Enter, verifies attach action without navigating into the directory,
then Escape dismisses and returns focus to the origin. VM and Chromium both
pass (/tmp/file-list-menu.log, /tmp/file-list-menu-browser.log); browser exits
0 without intervention. Chat/sidebar regression passes 38 cases, followed
by a passing tree keyboard case after shared tooltip naming. This does not
validate actual attachment/download execution or VoiceOver. Not yet built: app
remains a53ad42b...; screenshots predate the added list menu.

File-sidebar integrated release: full regression completes in 1:44 with
2,048 passes and the same two Liquid preview golden failures
(/tmp/liquid-file-integration-full.log); full analyze and diff checks pass.
Release build succeeds in 109.9s (/tmp/liquid-file-integration-build.log),
integrating list folder navigation, Liquid 44px targets and named tree
expand/collapse controls. Local and HTTP port-9000 script hashes match:
a53ad42bfe0529216f1a57192941f02cfbf3df1ab5e141e88e767746d04d26e9.
Four populated three-pane captures pass and refresh their files
(/tmp/liquid-file-integration-captures.log). Gallery regenerates with
189 images/94 exact pairs and passes metadata/filter checks; comparison
route returns HTTP 200. Other unchanged scenes retain earlier timestamps.
No golden approval or device acceptance. Updated liquid-visual-gap-audit.md
documents that current preview differences include newly added reading/
composer content and broad layout changes, not only old material-region drift.

File-tree keyboard/accessibility follow-up: Liquid tree/list rows and tree
controls now retain 44px minimum targets; Classic compact sizing is preserved.
Directory expander lacked an action name, so it now exposes localized
expand/collapse plus folder name through its tooltip. The populated 1280px/2x
ChatScreen fixture traverses actual Tab focus to the expander, collapses with
Enter and expands with Space, checking child visibility and changing labels.
The case passes in VM and Chromium (browser process exits 0 without intervention;
/tmp/file-tree-keyboard-browser.log). Full chat/sidebar regression passes 37
cases (/tmp/file-tree-keyboard-regression.log). Targeted analysis passes after
removing an unnecessary null assertion; diff checks pass. These are specific
file-tree keyboard/target checks, not whole-app focus or VoiceOver acceptance.
Navigation/target/tooltip production changes remain unbuilt; port 9000 retains
the previous f741e07a... release.

Populated workspace integration found/fixed real list navigation defect:
FileTreePanel always called toggleDirectory on folder tap, including list mode.
That fetched children but never changed cwd, leaving folder contents invisible.
It now uses openEntry in list mode and retains toggleDirectory in tree mode
(shared Classic/Liquid behavior). Three-pane fixture supplies a docs directory
and long bilingual filename, taps into it, verifies the child request/name
and sidebar text bounds at light/dark 1x/2x. All four formerly failing cases
pass; complete chat/sidebar files pass 36 cases (/tmp/files-chat-regression.log).
Targeted analyze and diff checks pass. Four refreshed three-pane captures pass
(/tmp/files-pane-captures.log); gallery remains 189/94 pairs with checks passing.
These populated captures now include unbuilt production fix; served app still
f741e07a... until next integration. No optical approval or live filesystem write.

Image browser async-wait repair: verified prior session 69426/PID 815332 was
still waiting in standalone decode test; PNG chunks/CRC and compressed bytes
are valid. Explicitly cancelled that test with SIGINT (not a passing result).
Moved widget mount and precacheImage of the actual provider into one runAsync
zone, with 10s timeout so future decoder stalls cannot wait indefinitely.
This avoids starting image callbacks in fake async and awaiting them outside
it. All five cases now pass in both VM and clean Chromium run
(/tmp/image-zone-vm.log, /tmp/image-zone-browser.log); targeted analysis and
diff pass. Includes actual metadata growth/shrink above historical reader,
decode success and failure. No production code or release change. This closes
the specific image test gate, not end-to-end transport/device acceptance.

Image metadata resize coverage: delayed image success/failure cases now scroll
below the mounted image (anchor y=8, extentBefore>100) before resolution, then
change actual Markdown image dimensions from 240 to 360 to 120. Each resize
asserts rendered Image height and <=2px anchor drift across six frames. Both
cases pass in Chromium, and all five VM cases pass (/tmp/image-provider-vm.log).
The older standalone successful decode browser case failed with its fixed
100ms wait. Replacing it with precacheImage on a separately constructed provider
still failed; the current version waits on the actual rendered Image.provider.
Its browser process is currently active at that case (session 69426, log
/tmp/image-provider-browser.log), not a passed suite. Do not restart without
checking the existing handle. Timeout alone is not established as root cause.
No production change; current gallery/release unaffected. Initial targeted
analysis passed before wait refactor; further diagnosis remains necessary.

Chromium tool-resize gate recovered and cleanly repeated: same original iframe
successfully imports CanvasKit and initializes it both with default loading
and a diagnostic custom instantiateWasm callback. Original bootstrap remains
pending, so the existing iframe was reloaded (no new test process or SDK edit).
Original four cases then pass and both PID 731427/778324 exit. A clean retry
initially fails before browser launch because google-chrome is not on PATH
(/tmp/tool-history-clean-retry.log). Explicit installed executable resolves
that separate environment issue:

CHROME_EXECUTABLE=/home/veficos/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome flutter test --no-pub --platform chrome test/tool_history_resize_test.dart

All four cases pass without reload/intervention; exit 0
(/tmp/tool-history-explicit-chrome.log). Tests cover mounted tool collapse/
restore above the reader plus trimming newer rows, six frames each, at 320px
light/dark 1x/2x with anchor drift <=2px. This closes this specific browser
coverage gap, not real transport/media/session combinations or original
intermittent engine-bootstrap root cause. No production change or rebuild.

Navigation/search integrated release: full regression completes in 1:46 with
2,047 passes / two unchanged Liquid preview golden failures (dark 82.23%,
light 83.20%; /tmp/navigation-release-full.log). Full analyze and diff checks
pass. Release builds in 110.5s (/tmp/navigation-release-build.log), publishing
scrollable XL low-frequency destinations and explicit search aliases. Local
and HTTP-served main.dart.js hashes agree:
f741e07a6765e37917e61636feb4a4a97f86ae3634e4844c6ef96b627f2e488b.
All 24 populated shell captures pass (/tmp/navigation-release-captures.log)
and refresh shell scenes for this navigation revision. Unchanged standalone
approval/preview/three-pane captures retain their earlier timestamps. Gallery
rebuild indexes 189 images / 94 pairs; metadata/filter/pair checks pass,
compare.html returns HTTP 200. No golden updates, optical or device approval.
P4 platform-limit documentation is now checked on its actual written evidence;
other material/device gates remain open.

Live Chromium resize audit: PID 731427 and its Chromium child 778324 remain
alive, with log /tmp/tool-history-browser.log still at suite loading (no test
case started). CDP 46261 shows the expected test iframe on server 46267 and
DDC main started. In iframe context 2, Runtime.getProperties confirms
window.flutterCanvasKitLoaded is pending; flutterCanvasKit is undefined and
no canvas exists. Same-context diagnostic fetch of local Chromium CanvasKit
WASM succeeds (HTTP 200, 5,428,553 bytes) and independent compileStreaming
succeeds. Thus current resource access/compilation works, but the original
engine bootstrap remains pending; root cause not established. Host null-check
warning still exists and is not proven causal. No restart, cancellation,
SDK modification, golden update or claim that resize assertions ran. This
narrows the outstanding browser gate to initialization before test execution,
not a demonstrated production scroll defect. The existing handle must be
revalidated before any future retry; VM evidence is not browser acceptance.

Populated XL status follow-up: tests now provide a long model ID and deep
bilingual workspace path, not placeholders. At 3x the growing status reduced
navigation height to 331px; its fixed settings/about/connection footer caused
184px vertical overflow (localized to app_shell.dart navigation Column in
/tmp/status-populated-details.log). Moved low-frequency destinations into the
navigation scroll extent, keeping the brand/collapse header outside. This
applies to Classic and Liquid XL navigation. All 63 AppShell cases pass
(/tmp/status-populated-fixed.log); three follow-up 1x/2x/3x checks also scroll
to the final connection entry and verify it is hit-testable, alongside complete
status text bounds (/tmp/status-destination.log). Targeted analysis before
the final test assertion and diff checks pass. Not yet rebuilt/captured;
current release and gallery predate this navigation change and search aliases.

More directory discovery: existing explicit bot/file/terminal/appearance
aliases were retained. Added workspace (工作区/工作區/多窗格/panes), Git
(版本控制/version control), and project (项目/專案) mappings without changing
labels/routes or matching algorithm. Three locale tests cover case/whitespace,
multi-term AND, empty search and negative queries; actual Arabic 2x More flow
finds workspace by bilingual query, then Bot, and retains clear/reopen focus.
All four cases pass (/tmp/more-alias-fixed.log). Initial UI assertion matched
both Arabic group and row title; corrected to scope to directory rows, not
weaken product behavior. Targeted analysis before that finder edit passed;
diff check passes. Production aliases are not yet release-built.

Paired visual-review preparation: a renewed direct image attempt still yielded
encoded output rather than reliably inspectable rendering. Added generated
compare.html and pairs.json to the review gallery: 94 exact scene/size/scale
light/dark pairs, without mixing distinct routes. Manifest/HTML references
and unapproved status pass the checker; compare route returns HTTP 200.
No production UI change, visual approval or golden update. This prepares
human/browser review but does not complete P0/P4/P5 visual gates.

2026-09-11 populated three-pane coverage: actual ChatScreen at 1280x844
now sends a first turn through HermesComposer and the controlled session
gateway, then checks session rail, docked right sidebar and composer bounds
at light/dark 1x/2x. Collapsing 280px sidebar to 56px increases composer width;
expanding restores the sidebar while preserving the durable session. All four
cases pass both normal and capture runs (/tmp/three-pane-current.log,
/tmp/three-pane-captures.log); targeted analyze and diff pass. Four new
chat-three-pane-1280-* images bring the fresh gallery to 189. These are real
three-pane ChatScreen fixtures, not AppShell session-entry navigation, live
transport, filled file-tree review or optical approval. No production change
or rebuild; app remains 6896868c... .

2026-09-11 integrated release and clean capture set: full regression finishes
in 1:45 with 2,040 passes / two Liquid preview golden failures (dark 82.23%,
light 83.20%; /tmp/liquid-sep11-full.log). Full analysis and diff checks pass.
Release build succeeds in 113.1s (/tmp/liquid-sep11-build.log); local and
HTTP-served main.dart.js SHA256 agree at port 9000:
6896868c9d2224cd14b25ce1f5ad08a41ae85600a44ac5b58db4ea74d9447223.
This integrates candidate material roles/dark contrast, natural-height status
and home 3x height repair. No golden baseline or tolerance update.
Fresh capture source /tmp/hermes-ui-sep11-APIoI8 contains 185 PNGs, from
29 shell/inline approval cases plus 12 reading preview cases; all pass
(/tmp/liquid-sep11-captures.log, /tmp/liquid-sep11-preview-captures.log).
The ui-review-current gallery indexes only this fresh set; old standalone
and historical plain-chat captures are not mixed into its manifest. Gallery
metadata/filter checks pass and HTTP returns 200. This is same-source
controlled rendering evidence, not optical approval, native device review,
live gateway validation or populated docked multi-pane chat acceptance.

2026-09-11 status natural height and 3x overflow repair: Liquid XL status
uses a minimum height and wrapping entries rather than a fixed-height row;
Classic status retains its existing layout. Status bounds/foreground checks
pass at 1x/2x. An added 3x case exposed 14px vertical overflow: home quick-tool
grid height stopped growing at 2x while labels continued scaling. Removed
that height-growth cap (shared Classic/Liquid home grid); 1x/2x are unchanged.
All three status/shell cases now pass (/tmp/status-3x-fixed.log), retaining
the 3x regression and checking framework exceptions before teardown. This is
not all-page 3x acceptance, long-workspace status coverage or optical approval.
Broader home + AppShell regression passes all 71 cases in 35s
(/tmp/home-status-integrated.log); targeted analysis and diff checks pass.
These production changes remain unbuilt; full integration/release is pending.

P4 desktop status material integration: source audit found XL status bar
still role-less, using legacy glass density and tertiary text. Liquid
now uses navigation role plus palette.text2; Classic is unchanged. Actual
1280px AppShell test verifies role and all status text colors; passes
(/tmp/status-material-role-final.log), targeted analysis/diff pass after
adding the missing test tokens import. This is component integration, not
whole-page optical/contrast approval of the 24px-high status bar. Material
candidate and this integration remain unbuilt; current screenshots predate
the status change.

P4 role differentiation candidate: navigation now .80/.72 sigma12,
control retains .82/.72 sigma16, overlay .90/.84 sigma20. Dark readability
floor and restrained interaction wash remain. All 63 pixel/material/
interaction checks pass (/tmp/material-roles-candidate.log), followed by
14 role cases including explicit hierarchy assertions. All 24 shell
capture roundtrips pass (/tmp/material-roles-captures.log), refreshing
current shell scenes; gallery regenerated (305 images), metadata/filter
checks and targeted analysis/diff pass. Candidate rationale/limits are
in platform-material-contract.md. No optical approval or full P4 checkoff;
legacy role-less surfaces keep prior recipes, and performance on devices
is unverified. Application release remains b8f57324...; shell candidate
captures now differ from that release, other samples retain timestamps.

P4 pressed-state contrast: expanded actual glass pixel sampling from three
points to a 17x7 interior grid, idle and center-pressed, over black/white
for all palettes/roles/brightness. Twelve dark cases failed when pressed
(/tmp/glass-grid-pressed.log); the .08 white interaction wash reduced
secondary text contrast below 4.5 even with the .78 bottom tint floor.
Reduced only dark interaction wash to .03; light remains .14. All 50
grid/interaction/foreground cases pass (/tmp/glass-pressed-fixed.log);
analysis/diff checks pass. Sampling excludes 20px outer contour and tests
one press position, not all possible backgrounds/labels/states. No optical
approval, role differentiation completion or release yet; current served
build and gallery predate these two dark-material corrections.

P4 composited contrast baseline and correction: new tests render actual
GlassSurface over black/white backdrops, sample three interior pixels
(highlight/center/lower tint), and measure palette text/text2 contrast.
Nine dark role/palette cases failed initially, minimum 4.349:1; Graphite,
Moss and Dune secondary text washed out near the bottom over white.
Dark bottom tint now has shared minimum alpha .78 (light unchanged).
All 55 composited/material-role/foreground pixel cases pass
(/tmp/glass-composited-final.log); analysis/diff checks pass. Role test
expectations now account for the dark readability floor. This tests only
sampled interior primary/secondary colors, not every label/state/backdrop
or optical fidelity. Distinct role recipes and visual calibration remain
open. New material change is unbuilt; goldens not updated.
Browser follow-up: four real Chromium menu focus/editor save cases pass
(/tmp/browser-focus-save.log); synthetic browser keyboard events do not
prove OS-reserved shortcuts or native screen-reader behavior.

P3 actual editor loading-shortcut gate: controlled pending read now tests
Ctrl+S and Meta+S on real FileEditorScreen while loading and after read
failure. Both leave writes at zero and source unchanged. Retry then loads
the file; editing and the same shortcut produce exactly one write with
the recovered draft, preventing an inert-shortcut false positive. All 30
editor/tablet cases pass (/tmp/editor-loading-shortcut-full.log), targeted
analysis/diff checks pass. Existing production guards required no change.
This resolves the explicit loading/failure shortcut VM coverage gap, not
browser/OS shortcut interception, screen-reader announcement or P3 entirety.
No application rebuild required.

Integrated rich-text release: full regression finishes in 2:11 with
2,010 passes / two existing Liquid preview golden failures, unchanged
dark 82.22% and light 83.20% (/tmp/rich-integrated-full.log). Full analyze
and diff checks pass. All 29 shell/approval capture scenarios pass
(/tmp/rich-integrated-captures.log), refreshing current rich top/tail,
bot overlays, other shell pages and inline approval. Gallery stays 305
including historical plain-chat images; metadata/filter checks pass.
Release builds in 111.8s (/tmp/rich-integrated-build.log); port 9000
HTTP 200 and local/served script SHA256 match:
b8f57324d8d27dbc57217796468f2c4f7eafd5736c9a99f2c10252f78aa4e7db.
This publishes user heading/emphasis, quote/backdrop contrast, Graphite
bubble color, wide foreground and RTL quote changes. No golden updates
or optical approval. Fresh flutter devices lists Linux only; iPhone,
Safari, VoiceOver, material calibration and remaining P0-P5 gates stay open.

P2 RTL quote direction: Liquid user quote rule and shared assistant
Markdown quote decoration now use logical start/end instead of physical
left/right. Assistant quote end corners mirror in RTL. Shared stylesheet
change also corrects Classic assistant quote direction; user Classic
decoration remains unchanged. Direction-resolved border insets and actual
Arabic user Markdown rendering pass both directions, with 36 total
typography/contrast cases (/tmp/quote-direction.log). Targeted analysis
and diff checks pass. No release, new optical approval or native RTL
accessibility claim; screenshots predate this direction correction.

P2 responsive user-bubble contrast: expanding palette contrast checks to
390/900/1280 exposed 16 wide failures while eight phone combinations
passed (/tmp/wide-user-contrast-before.log). Liquid foreground/quote/link
rules now apply at all widths independently of the phone-only typography
choice; wide heading/body sizes and Classic styling remain unchanged.
All 24 palette/width cases plus typography and actual chat interactions
pass, 61 total (/tmp/wide-user-contrast-final.log); analysis/diff checks
pass. This is opaque user-bubble contrast evidence, not backdrop-glass
contrast, native accessibility or optical approval. Changes remain unbuilt
and current rich-review images predate this wide correction.

P2 user quote contrast repair: inherited Markdown pale-blue quote backing
could not carry the new white user-bubble foreground. Phone Liquid quotes
now retain their bubble background, with a foreground-colored left rule.
Eight palette/brightness checks initially failed; removing quote backing
left Graphite failing at 4.498767:1. Adjusted only Graphite bubbleUser from
#2F6BFF to #2F6AFE in light/dark (also affects Classic); brand/accent unchanged.
All 45 contrast/typography/chat cases now pass
(/tmp/user-quote-contrast-fixed.log); analysis/diff checks pass. Tests
compose quote backing and text alpha against the opaque bubble, not glass.
Other accent backgrounds and general composited-glass contrast remain
outside this evidence. Current gallery/release predate these changes;
no optical acceptance, baseline update or release this checkpoint.

P0 rich-chat whole-route artifacts: populated shell fixture now includes
user H1/bold, quote, list, italic and link plus assistant H2/bold and list.
Captures record initial tail and explicit return to transcript top; the
user heading is asserted hit-testable after scrolling. All 24 six-width/
brightness/scale cases pass (/tmp/rich-chat-shell.log), analysis/diff
checks pass. Adds 48 shell-chat-rich-top/tail images; gallery total 305.
Older plain shell-chat captures remain timestamped historical samples,
not matched current rich-text comparisons. No external links clicked or
live gateway writes. Current rich captures contain unbuilt user Markdown
changes; application release remains 58af6d46... pending integration.
These artifacts enable review, but optical and material calibration gates
remain open.

P2 nested emphasis correction: phone Liquid Markdown strong/em no longer
force body font size over their enclosing heading. User and assistant
rendered RichText spans now verify 22px bold/italic inside H1 and 17px
inside paragraphs. All 10 typography cases pass
(/tmp/heading-inheritance.log); targeted analysis/diff checks pass.
Classic/wide assistant emphasis retains its previous sizing. A fresh
image-view attempt still returned encoded payload instead of a reliably
inspectable image; no optical approval is claimed. Rich-user whole-page
review and release of this and prior user Markdown changes remain pending.

P2 user Markdown hierarchy follow-up: the phone Liquid user bubble had
only migrated paragraph typography while headings/quotes/links still
inherited generic theme styles. It now shares assistant heading sizes,
uses bubble foreground for heading/emphasis/quote/bullet/link text, and
underlines links. Existing decorations and 13px code remain unchanged;
Classic/wide keep their old stylesheet behavior. Shared style assertions
and actual chat interaction cases pass 35 tests
(/tmp/user-markdown-hierarchy.log); targeted analysis and diff checks pass.
No release or refreshed rich-user-message optical comparison yet. This
closes a source-level hierarchy gap, not whole-page visual acceptance.

P0/P5 overlay and keyboard evidence: real AppShell bot roundtrips now open
the existing Manage Bots sheet before continuing navigation, capture it,
and dismiss with Escape. All 24 width/brightness/scale scenarios pass
(/tmp/shell-overlay-review.log), adding 24 shell-bots-sheet PNGs and
refreshing the paired base pages. Gallery total is 257; metadata/filter
checks pass. Shared adaptive menu tests now use actual Tab/Enter/Escape
events without forced focus at 390 and 900px, verify focus identity after
cancellation and reopen via Enter. All 17 menu cases pass
(/tmp/menu-keyboard-suite.log), targeted analysis and diff checks pass.
No production change was needed for these verified paths. This is not
all-route focus restoration, VoiceOver or optical approval. Release stays
58af6d460294e4e45f2ac874b07bcc2c862c02bff32b768f85bb4cdecb367c9f.

Integrated phone-reading release: full regression finishes in 1:43 with
1,980 passes and only two Liquid preview golden failures
(/tmp/reading-integrated-full.log), unchanged dark 82.22% / light 83.20%.
Full analyze is clean (/tmp/reading-integrated-analyze.log). All 29 shell
and inline approval capture scenarios pass, refreshing 120 shell-route
and five standalone chat PNGs after typography changes
(/tmp/reading-integrated-captures.log). Release build succeeds in 110.8s
(/tmp/reading-integrated-build.log). Local and port-9000 main.dart.js match:
58af6d460294e4e45f2ac874b07bcc2c862c02bff32b768f85bb4cdecb367c9f.
Root and regenerated 233-image gallery return HTTP 200; gallery filter/
metadata checks pass. This release includes prior unbuilt editor changes.
No golden update or optical/device acceptance. Old tool-history browser
PID 731427 remains live; this is not a passing browser result. Remaining
P0-P5 gates, including material calibration, stay open.

P2 phone conversation reading density: Liquid below 600px now shares a
17px/1.6 body token between user message paragraphs and assistant Markdown
(including streaming/expanded text). Assistant headings, emphasis, quotes
and bullets follow the phone hierarchy; code and non-conversation Markdown
retain existing density. Inline message editing adopts the same font size.
Classic and wide layouts retain their previous styles. Eight direct style
cases plus actual chat initial/history and inline approval suites total
46 passing tests (/tmp/chat-reading-typography.log). Initial analysis found
an obsolete tokens import; removed it and targeted analysis is clean.
This is a design candidate, not optical approval. Gallery captures predate
this typography change and must be refreshed before comparison. No release
build, golden update, real-device or browser performance claim.

P0 wide populated shell supplement: extended the actual-navigation matrix
to 768, 900 (NavigationRail), and 1280 (XL navigation), light/dark and
1x/2x text. All 24 phone/wide roundtrip cases pass
(/tmp/populated-shell-wide.log). Wide fixtures include five board columns
and exercise horizontal position restoration across list/board and board
identity changes; navigation is activated by visible localized labels.
120 shell-route captures now cover six widths; standalone plus shell
gallery total is 233. Added 900px gallery filter. This supplies populated
wide review artifacts, not optical approval or a true docked three-pane
chat review (chat here is deliberately a pushed route). Matched open
overlays, dense real-data calibration and native/device gates remain open.
No production app changes or release build in this checkpoint.

P0 populated phone review matrix: actual AppShell Bot/More/task-list/board
and pushed ChatScreen routes now capture both 1x and 2x text at 320/390/430
in light/dark. All 12 roundtrip scenarios pass with 60 shell-route PNGs
(/tmp/populated-shell-current.log). Gallery now contains 173 captures and
separates shell-route from standalone scenes with a tested scope filter;
shell chat correctly has no bottom navigation because it is a pushed route.
These controlled offline fixtures are not live gateway or optical acceptance.
Populated wide-shell and open-overlay matched review remain outstanding.
No application release rebuild or golden updates in this checkpoint.

Prior editor localization result verified from existing browser log:
all five phone editor secondary-action language cases pass
(/tmp/editor-menu-languages-chrome.log). This closes that pending browser
run, not general editor or native accessibility acceptance.

P3 actual file editor save feedback: FileEditorScreen save action now has
44px standard-density minimum, an 18px saving indicator with localized
live semantics, and disabled state while loading or after load failure.
The save method also rejects those states so shortcuts cannot bypass
the UI guard. All 24 actual editor/tablet cases pass
(/tmp/editor-save-feedback-final.log), including pending write target
isolation with new size/disabled/live-label assertions. Initial assertion
incorrectly cast byTooltip's RawTooltip to IconButton; fixed the finder,
not the production behavior. Browser/native announcements and explicit
loading-shortcut tests remain open. No release build this checkpoint.

Shared form exception guard: HermesFormPage now resets saving in finally
and shows localized generic feedback when an onSave callback throws,
preserving the draft and allowing retry without exposing raw exceptions.
Eight related VM cases and three Chromium save cases pass
(/tmp/form-save-exception.log, /tmp/form-save-exception-chrome.log);
analysis/diff checks pass. Important scope limit: repository call-site
inspection finds no production page currently using HermesFormPage. This
is shared-component hardening, not an actual editor-route repair or P3
completion. FileEditorScreen already has independent catch/finally and
target-ownership guards. No release rebuild this checkpoint.

Integrated search/board release: full regression completes in 1:48 with
1,945 passes and two Liquid preview golden failures
(/tmp/board-integrated-full.log). Full analysis and diff checks pass.
Forty-nine core task/More capture cases pass, refreshing the review images
after search aliases and board scrollbar/buttons/range changes
(/tmp/board-integrated-captures.log). Release build succeeds in 111.8s
(/tmp/board-integrated-build.log). Local and served port-9000 script match:
14a612a43ed0eb2375d79d6ae11130cc025ce6a803fd09a375bf2f8bcc52c4a7.
Root and regenerated 113-image gallery return HTTP 200; gallery metadata/
filter checks pass. This supersedes prior unbuilt search/board notes.
No visual baselines updated or optical approval inferred. Fresh flutter
devices still lists Linux only; native/Safari evidence and all remaining
P0-P5 gates stay open. Old tool-history Chromium PID 731427 remains live;
no success or restart inferred.

P3 five-column range check: added LTR/RTL real-board cases comparing the
reported range against rendered column-shell intersection at entry, every
next step through the end and a 1600px resize showing all five columns.
Initial inner-list measurement excluded a still-visible shell edge; using
the containing column matches the visible-column contract. Both cases
and the complete 29-case task file pass (/tmp/board-range-suite.log);
analysis is clean after adding braces. No production algorithm change.
Both Chromium cases pass (/tmp/board-range-five-chrome.log).
No new release or full optical/device acceptance in this checkpoint.

P3 board navigation context: replaced repeated board-view caption with a
localized visible-column range and generic previous/next-page tooltips with
previous/next-column labels in all five locales. Range uses the actual
column width, gap, page inset and horizontal viewport; updates coalesce
after layout and also react to widget/metrics changes. Column names stay
in their own headers. All 27 task cases pass (/tmp/board-range.log), then
both RTL/LTR interaction cases pass with explicit localized range and
tooltip assertions (/tmp/board-range-labels.log). Source analysis/diff
checks pass. This does not yet prove range reporting for many-column
boundaries, all localizations, or optical/device acceptance. No release
build; these and prior search/board changes remain unbuilt.

P3 board thumb/RTL interaction: actual mouse drag now locates the painted
thumb via ScrollbarPainter hit testing, then moves it in the physical
LTR/RTL direction. Both variants verify horizontal offset changes without
refresh, previous-button reset, Enter advance and boundary disabling,
content horizontal/vertical gesture isolation and wide-resize fallback.
All 27 task cases pass (/tmp/board-thumb-suite.log); analysis/diff pass.
The initial fixed bottom-minus-5px coordinate missed the thumb and failed
both variants; no production workaround was needed. This is widget pointer
and forced-focus Enter evidence, not Tab traversal or native accessibility
approval. Both Chromium variants pass
(/tmp/board-thumb-chrome.log). No production edit/build this checkpoint.

P3 board navigation bounds: horizontal position and metrics changes now
schedule a coalesced post-layout bounds update. Previous/next actions
disable at their corresponding edge, including when a resize makes every
column fit. All 26 task cases pass (/tmp/board-bounds-final.log), including
Enter advance, previous return, edge-disabled states, refresh isolation
and 320->1280 resize with both buttons disabled. The resize rebuilds the
page/controller; test now reads the newly mounted scrollbar instead of a
detached old instance. Analysis/diff pass. The targeted Chromium case passes
(/tmp/board-bounds-chrome.log). No release build, thumb-drag
or whole-page visual acceptance in this checkpoint.

P3 board non-drag navigation: added 44px standard previous/next buttons
above the horizontal board, moving by the responsive column width plus
gap and clamping to scroll bounds. Arrow visuals follow RTL; standard
button keyboard behavior avoids intercepting text-field arrow keys.
Task suite reports 25 passes and one test-focus lookup error; replacing
the nullable Focus widget parameter lookup with Focus.of at the actual
button icon makes the targeted test pass (/tmp/board-controls-keyboard-fixed.log).
It verifies Enter advances, previous returns to zero, then horizontal/
vertical refresh isolation. Analysis passes. Full rerun, actual thumb
drag, traversal order, RTL interaction and browser checks remain open.
No release build or optical acceptance in this checkpoint.

P3 board horizontal discoverability: a board-keyed stateful surface owns
one horizontal controller and an always-visible interactive bottom
scrollbar/track. Vertical task lists explicitly remain non-primary; only
depth-zero horizontal notifications drive the scrollbar. All 26 task
accessibility cases pass (/tmp/board-scrollbar-verified.log); analysis and
diff checks pass. The strengthened refresh test first failed because its
default wide viewport fitted both columns and could not move horizontally.
At explicit 320px it verifies positive overflow, horizontal movement without
refresh, and vertical refresh (/tmp/board-scrollbar-narrow.log). The earlier
wide Chromium case likewise failed; corrected browser run passes its one
case (/tmp/board-scrollbar-narrow-chrome.log). No release rebuild,
optical approval, thumb-drag or keyboard-navigation acceptance yet.

More search aliases: feature registry now owns explicit alternate names
and token matching over stable ID, localized title/description and aliases.
More consumes that matcher without adding duplicate routes or changing
visibility. Added bot/files/shell/schedule/appearance Chinese/English
aliases; whitespace and case normalization allow mixed queries such as
settings 外观. Twenty actual More width/brightness/scale cases pass including
SHELL and mixed-query filtering plus existing search position restoration
(/tmp/more-search-alias.log). Targeted analysis/diff checks pass. No release
rebuild this checkpoint. Pending chat-switch Chromium session 57422 has
now completed: all five long-history variants pass in 1:09
(/tmp/chat-switch-pending-chrome.log). Real transport/device acceptance
and the separate old tool-history run are not covered by that result.

P1 pending-page session replacement: extended the actual ChatScreen long
history scenarios to start a second page, replace the session while pending,
reuse message IDs, move 600px above the new tail, then complete the old
future. Twelve 16ms samples keep the replacement scroll position within
2px; no loading overlay or old prepend remains. Controlled SessionStore
override rejects stale data by generation, so this isolates screen future/
finalizer ownership rather than proving real transport rejection. Original
eleven cases pass (/tmp/chat-switch-pending.log); five long variants pass
again with an explicit extentAfter >400 guard
(/tmp/chat-switch-pending-final.log). Analysis/diff checks pass. Chromium
session 57422 remains running, with its first case started in
/tmp/chat-switch-pending-chrome.log; no browser result yet. No production
change/build and no full lifecycle acceptance claimed.

Integrated phone-typography/preview release: full VM regression finishes in
1:30 with 1,942 passes / two Liquid preview golden failures
(/tmp/liquid-preview-integrated-tests.log); full analyze passes. Added
opt-in appearance viewport captures and refreshed task bulk overlays in
36 passing capture cases (/tmp/preview-release-captures.log). Capture helper
import remains Chrome-compatible: all twelve preview cases pass in
/tmp/preview-capture-import-chrome.log. Release build succeeds in 108.3s
(/tmp/liquid-preview-release-build.log). Local and port-9000 script hashes
match: b546d9db68656d11abbab0f8161ad1f2c22ea5a94afda78c2c42d561d9d4cdc4.
Root and regenerated 113-image gallery return HTTP 200; gallery filters/
metadata pass their DOM-stub check. This deploys the previous two source
checkpoints, not optical approval or full P0-P5 completion. Goldens unchanged.
Old tool-history Chromium PID 731427 remains live with loading-only log;
it has not been restarted or counted as passing. Device, optical and
remaining interaction/integration requirements stay open.

P3 appearance reading-plane preview: Liquid preview now places localized
opaque sample content and a non-editable composer sample between navigation
and selection controls, with an explicit no-send notice in all five locales.
It does not access stores, send messages or add keyboard focus stops. Classic
preview remains unchanged. Twelve new light/dark, opaque/transparent,
Chinese/English/Arabic 320px/2x cases pass as part of 66 passes / 2 failures
in /tmp/reading-preview-final.log. Only Liquid light/dark goldens fail; their
new composition differences are 83.20% / 82.22%, superseding older pixel
percentages. Baselines/tolerances unchanged. Preview fixtures now use a
scrolling parent matching settings and reveal controls before activation;
initial non-scroll large-text fixtures overflowed and are not passing evidence.
Targeted analysis/diff checks pass. All twelve new cases also pass in
Chromium (/tmp/reading-preview-chrome.log). No release rebuild or optical
acceptance.

P2 phone directory typography: introduced HermesLiquidTypography and applied
17/1.3 title plus 14/1.4 subtitle to shared HermesListRow only in Liquid
viewports below 600px. Phone titles wrap without a one-line cap; Classic
and wide density remain unchanged. Sixteen direct width/style/scale cases
plus actual Bots, More, settings and task-move flows pass 130 VM tests
(/tmp/liquid-phone-rows.log). Targeted analysis and diff check pass. This
is a reading-density implementation, not optical approval or global body
typography completion. Viewer still returns an unreviewable encoded image.
Release has not been rebuilt for these changes. Latest previous task bulk
Chromium log now confirms 24 passes (/tmp/task-bulk-browser-current.log);
this does not resolve the separate tool-history resize browser run.

Integrated destination/feedback release: full regression completes in 1:18
with 1,914 passes and two known Liquid preview golden failures
(/tmp/liquid-destination-full.log). Full analysis/diff checks pass. Release
build succeeds in 113.1s (/tmp/liquid-destination-build.log), publishing
pending feedback, localized grouped destination sheet and content-sized
Classic bulk bar. Port 9000 HTTP 200; local/served main.dart.js hash matches:
303a38d984f31c3d03853737941d0a651bb57e185ca21145b2b34e3dee0b9c8e.
Regenerated the 101-image review gallery from existing current candidates
after build; filter/metadata script checks pass. No golden update or optical
approval. Chromium resize session 35464 was re-polled and still loading;
browser/native/live acceptance and full P0-P5 requirements remain open.

P3/P5 task destination accessibility: added opaque-keyboard variants to
the real-page move flow. All 24 cases pass (/tmp/task-move-keyboard.log),
including Classic/Liquid light/dark 320px/2x, keyboard Enter activation of
the focused destination, exact submitted status, disabled pending controls
and successful completion. Reduce-transparency variants assert zero
BackdropFilters while the target sheet is open. Targeted analysis/diff
check pass. This does not verify native screen-reader output, actual focus
traversal order, browser execution or full accessibility acceptance. No
production change or release in this checkpoint.

P3 task move destination sheet: added semantic heading and snapshot selected
count; destinations use shared grouped mobile rows and localized built-in
status names instead of raw todo/done labels. Original status values remain
the submission contract; custom names are preserved. Ten real-page VM
flows pass at 320px/2x light/dark (/tmp/task-move-sheet-final.log), including
scrolling to a long Chinese custom destination and verifying exact status
submission, plus success/failure/changed-board/disconnect guards. Production
targeted analysis and diff check pass. This shared sheet change affects both
styles; Classic-specific, browser, optical and release validation remain open.

P3 task pending feedback: bulk actions distinguish choosing a destination
from an actual pending request. The latter displays localized Processing
under the selected count in its live semantic region, and disables Clear
as well as Move so clearing is not mistaken for cancelling an in-flight
write. Failure restores both actions and removes Processing; success clears
the bar. Eight real-page controlled move cases assert feedback absence
while choosing, visible pending text above the viewport bottom at 320px/2x,
disabled Clear, and restored state. Combined task coverage passes 34 VM
tests (/tmp/task-bulk-feedback.log); targeted analysis/diff check pass.
Native announcement, browser and release remain pending for this change.

Integrated task/tool release: full regression completes in 1:22 with 1,898
passes and two known Liquid preview golden failures
(/tmp/liquid-task-integrated-tests.log). Full analyze and diff check pass.
Release build succeeds in 108.3s (/tmp/liquid-task-integrated-build.log).
Port 9000 returns HTTP 200 and local/served main.dart.js SHA-256 matches:
df48da504df50a2434547a8f63a24d9ba123cbc6d7448629d6abb0725632e1a0.
Includes separate tool actions, wrapping Liquid summary, task bulk glass
and operation ownership guards. This supersedes earlier unbuilt notes.
The old Chromium resize run remains live (session 35464). Read-only CDP
inspection confirms host and iframe loaded; console contains a host.dart.js
main_closure null-check warning, then DDC starts application main, with no
test results. This is diagnostic evidence, not established root cause or a
browser pass. No goldens changed; optical/device/live integration gates and
updated whole-page captures remain incomplete.

P3 task round-trip ownership: KanbanStore now exposes a monotonically
increasing ownerEpoch for connection rebinding and board selection. Bulk
response application and the target-sheet result check include that epoch,
so A->B->A does not revive old work; stale completion also suppresses an
unrelated failure toast. selectBoard checks ownership after asynchronous
event setup and loading before clearing selection or rolling back. A new
controlled test actually selects another board then the original and
verifies an old successful bulk response cannot clear a newly selected
task with the same ID. Twenty-three store/UI tests pass
(/tmp/task-owner-epoch-final.log); targeted analysis/diff check pass.
Native/browser/live data validation and release remain pending.

P3 task bulk UI flow: eight real KanbanCanonicalScreen routes pass at
320px/2x in light/dark (/tmp/task-move-flow.log). Long press selects a task,
Move opens the actual target-column sheet, and choosing done submits exactly
['1'] / {'status':'done'} once through a controlled API. While response is
pending Move is disabled; success clears the bulk bar, failure retains the
selection and re-enables Move. Changing the API board slug or disconnecting
while the sheet is open produces zero bulk submissions. These verify the
previous UI ownership guards, not live server writes or switch-away-and-back
generation races. Targeted analysis and diff check pass. Browser and native
verification remain pending; no production edit/build in this checkpoint.

P3 task bulk ownership: move snapshots selected IDs and API/board ownership
before its target sheet, refuses reentry while choosing/submitting, and
ignores dismissed-route/disconnected/changed-owner results. Sheet dismissal
uses its own navigator context. Store completion now removes only submitted
successful IDs from selection, preserving unrelated selections made while
waiting. A controlled pending bulk response verifies exact submitted IDs,
partial failure retention and preservation of a newly selected ID. Forty
store/task VM cases pass (/tmp/task-move-guards.log). Initial targeted
analysis found only a braces style warning, corrected afterward. Full UI
move/owner-switch browser coverage, optical/device checks and release remain
pending. This is not live bulk API verification or full P3 completion.

P3 task selection surface: Liquid bulk actions now use the shared control
glass with safe-area/inset spacing; Classic retains BottomAppBar. Selection
count is flexible and a live region, with standard-density 44px-minimum
move/clear buttons. Existing five-width light/dark 1x/2x task cases now
long-press real content, verify selected count and reachable bulk actions,
and clear selection. These checks run after search/view checks because
revealing task content can collapse the page header; earlier combined
ordering caused offscreen toolbar taps, not a verified search regression.
The final test file passes (/tmp/task-bulk-isolated.log). Browser/keyboard,
actual bulk move, optical review and release for this change remain pending.
The earlier tool resize Chromium process remains live but loading (session
35464); no restart or browser pass has been inferred.

P3 tool summary readability: Liquid header now presents the full wrapping
summary in theme bodyMedium/600 above its status chip, instead of squeezing
a 12.5px single-line summary beside status. Classic typography is unchanged.
Four action cases pass with explicit untruncated-summary and action-boundary
checks (/tmp/tool-readable-summary.log). Four mounted-tool resize/trim cases
passed with this header in /tmp/tool-readable-header.log. That combined run
also exposed two obsolete long-chat assertions requiring the introductory
paragraph above tools to remain mounted at the tail. Changed that assertion
to the actual trailing answer; all eleven real-chat cases pass
(/tmp/tool-readable-chat-final.log), retaining tail geometry/composer checks.
Targeted analyze/diff checks pass. Old-header Chromium resize run is still
live but loading (session 35464), not accepted or restarted. New typography
browser/visual review and release remain pending. Full scope stays open.

P2/P3 tool header action boundary: disclosure semantics/InkWell and Hide
are now sibling controls on one opaque header. Both styles use a standard
44px Hide target and a 44px-minimum Restore action; disclosure also has a
44px minimum height. Four new 320px/2x Classic/Liquid light/dark cases verify
separate semantic ancestry, actual Hide/Restore size, keyboard expansion,
pointer hide and keyboard restore to collapsed state. All four pass VM and
Chromium (/tmp/tool-actions-focus.log, /tmp/tool-actions-browser.log).
Twenty combined group/detail/real-chat cases pass (/tmp/tool-actions-final.log).
The final explicit disclosure minimum was then rechecked with four VM cases
(/tmp/tool-actions-minheight.log); targeted analysis/diff checks pass.
No scroll algorithm changed. Native readout, downstream resize/trim races
and visual acceptance remain open; this change is not yet release-built.

Integrated Bot hierarchy/tool/find-overlay release: full VM suite completes
in 1:22 with 1,880 passes and two Liquid preview golden failures, exclusively
light/dark (/tmp/liquid-integrated-current-tests.log). Full analyze and diff
check pass. All 21 Bot directory cases pass Chromium in 1:10
(/tmp/bot-directory-browser.log), including management-to-group-form entry
across five widths and 1x/2x light/dark. Twenty-one capture cases also pass,
refreshing twenty standalone Bot page PNGs (/tmp/bot-directory-current-captures.log).
Release build succeeds in 114.1s (/tmp/liquid-integrated-current-build.log);
port 9000 returns HTTP 200 and local/served main.dart.js SHA-256 matches:
158c943f5b76f3dcf6c5fc86c45ab56b9223d04bd6f22cd7be2249539958f5c0.
This publishes recent tool, find-overlay and directory changes. Goldens
remain unchanged; populated shell captures, optical review, live gateway
flows and iPhone/device performance remain open. Full scope is not complete.

P3 Bot directory action hierarchy: Liquid now shows Create and Manage Bot
in a wrapping primary/secondary action area instead of three stacked phone
buttons. Manage opens the shared sheet with profile management and group
creation; Classic retains direct profile navigation and its group button.
Management uses manage_accounts rather than person_add. Twenty-one VM
directory tests pass (/tmp/bot-directory-final.log), including opening the
management sheet and group form at five widths, both brightnesses and 1x/2x
text. This uncovered two existing group-form problems: Expanded actions
inside the adaptive form Wrap, and an unbounded member-count badge at
320px/2x. Removed the incompatible action wrappers and bounded the badge.
Targeted analysis and diff check pass. Browser/native review, actual profile
navigation/group persistence, updated whole-page captures and release build
remain pending; this does not close P3 or the complete delivery scope.

P3 find/replace keyboard/browser gate: both 320px/2x replace cases pass VM
with a simulated 300px keyboard inset, second field scrolled into reach and
Replace all visible above y500 in the 800px viewport (/tmp/find-keyboard.log).
All 24 editor cases pass Chromium (/tmp/find-keyboard-chrome.log), including
shared find overlay and stale-source protection. Targeted analysis/diff
check pass. No production change this checkpoint; native keyboard/optical
acceptance and actual file-switch races remain open. Release still pending
for recent tool and find-overlay changes.

P3 find/replace overlay: file editor uses shared GlassAlertDialog for its
find/replace form, preserving Classic fallback. Find refuses busy/loading/
binary/confirmation states; returned operations require unchanged path,
load generation and source text, avoiding stale replacement of new content.
Thirty editor/alert VM cases pass (/tmp/find-glass-final.log), including
320px/2x normal replacement and ignoring replacement after source change;
existing wrapped-search checks assert overlay material. Targeted analyze
and diff check pass. Browser/keyboard optical and real file switching
during dialog remain open; source not release-built.

P1 evidence audit / P2 browser gate: five retained long-chat cases pass
Chromium (/tmp/chat-keyboard-browser-final.log), including four Liquid
Enter-key disclosure/state/geometry cases from the previous checkpoint.
Targeted analysis/diff check pass. A new downstream hide/restore experiment
was invalidated by bottom clamping and then offscreen tool unmounting;
removed rather than accepted. Reproduction catalog records required mounted
row/height/non-bottom preconditions. No production scroll change, no claim
of downstream/trim compensation; existing unbuilt tool changes remain so.

P2/P4 tool disclosure semantics: tool-group header now exposes button and
expanded state; rotation uses shared reduced-motion resolution (including
accessible navigation). Four Liquid real-chat variants now expand with
Enter and assert semantic state changes plus the previous geometry guards.
Five long-chat VM cases pass (/tmp/tool-keyboard.log); thirteen related
group/detail/contour VM cases pass (/tmp/tool-keyboard-related.log).
Targeted analysis/diff check pass. Native screen-reader tree/dismiss-child
navigation, Chromium for this keyboard change and release remain pending.
Does not close full accessibility, material or interaction acceptance.

P1/P3 real chat tool toggle: extended long ChatScreen fixtures to position
a real ToolGroupCard while reading, toggle twice, assert actual height
change, group-top stability within 2px, restored height and no tail jump.
Four Liquid variants (390px/1x and 320px/2x, both brightnesses) exercise
toggle; five overall long-chat cases pass VM and Chromium
(/tmp/chat-tool-toggle-fixed.log, /tmp/chat-tool-toggle-chrome.log).
Expansion exposed 3.3px tool-row overflow at 320px/2x. Status now sits below
name/summary inside the flexible column, preserving text space; this also
affects Classic. Thirteen tool-group/detail/contour VM tests pass. Targeted
analysis and diff check pass. No scroll algorithm change; downstream row
anchor, combined media/trim/routed races and optical/device gates remain
open. Source not release-built; old chat captures need refresh.

Integrated avatar release: full regression completes in 1:45 with 1,878
passes and two known Liquid preview golden failures
(/tmp/avatar-integrated-full.log). Full analyze and diff check pass. Release
build succeeds in 109.5s (/tmp/avatar-integrated-build.log). Existing port
9000 server returns HTTP 200 and local/served main.dart.js SHA-256 matches:
4d079eb99818cac843f186fc58346db3f283a66cd02adb945c7989077c90a1c8.
Includes avatar Web picker, discard/busy protection, color preview and
accessible selection buttons, pinned Save and bottom-action motion policy.
Earlier unbuilt avatar notes are historical. No golden replacement, optical
approval, live persistence or device acceptance is inferred. Reproduction
catalog clarifies existing synthetic resize tests versus missing ChatScreen
content/trim integration; all full-scope gates remain authoritative.

P3 avatar keyboard gate: generation prompt is now present in the controlled
fixture. Ten light/dark 320px/2x VM and Chromium routes pass with 300px
simulated keyboard inset: Save bottom <=544, still hit-testable, prompt
bottom above Save. This browser-validates pinned Save. Tests scroll back
before checking lazily mounted preview rather than assuming offscreen
widgets remain mounted. Logs /tmp/avatar-keyboard-pass.log and
/tmp/avatar-keyboard-chrome.log; six shared back cases also pass. Shared
bottom-action AnimatedPadding now resolves reduced-motion policy instead
of unconditionally animating. Targeted analysis/diff check pass. Native
keyboard/motion and generation execution are not proven; release pending.

P2/P3 avatar page primary action: moved Save out of the long options list
into HermesPageScaffold.bottomAction (shared keyboard/safe-area action
region). Ten VM routes now cover light and dark at 320px/2x, assert Save
hit-testable at initial and color-scrolled positions, and preserve picker,
discard and save/retry tests (/tmp/avatar-page.log). Targeted analyze/diff
check pass. Optional UI_REVIEW_DIR captures both initial pages; current
viewer still returns an unreadable image payload, so no optical approval.
Browser, keyboard inset, native and release checks for pinned action remain
open. Source not release-built. Full scope remains in progress.

P3 avatar save verification: five VM and five Chromium editor cases pass
(/tmp/avatar-save.log, /tmp/avatar-save-chrome.log). Controlled appearance
write waits while Back is blocked and Save disabled; failed write retains
red preview, retry writes the exact selected color and exits. This also
browser-validates the preceding keyboard color/preview/target-size changes.
Targeted analysis and diff check pass. The fixture overrides appearance
storage; real owner-scoped persistence and two-stage image/appearance
partial failure remain unverified. No production change this checkpoint;
preceding avatar source changes remain unbuilt, full delivery still open.

P2 avatar controls/preview: the main preview now receives selected color
(previously absent from its metadata). Shape/color swatches use standard
TextButtons with selected semantics, localized category labels and option
index/hex identifiers. Color targets are 48px nominal instead of 40px;
decorative shape avatar semantics are excluded. Three expanded VM picker/
exit cases pass (/tmp/avatar-controls-final3.log), including Enter-key color
selection, red preview metadata, selected-state presence and >=44px actual
target size at 320px/2x. Targeted analysis/diff check pass. Browser, optical
focus/contrast, native screen-reader naming and save flows remain open.
Not release-built; no full-scope completion inferred.

P3 avatar exit protection: appearance changes (shape/color/image) now gate
route back through the shared destructive discard confirmation. Busy
picker/generation/save refuses back; explicit discard and successful save
permit exit after layout. Mutating action callbacks guard busy/confirmation
reentry; shape/color swatches are disabled while busy. Three expanded VM
and Chromium routes pass (/tmp/avatar-exit.log, /tmp/avatar-exit-chrome.log)
at 320px/2x: pending picker back is blocked, cancel/oversize/error restores
controls, changed shape -> Keep editing -> Discard returns to launcher.
Targeted analyze and diff check pass. Save success/failure/partial write,
generation and pet-gallery lifecycle, Classic/dark and optical/device
acceptance remain open. Not release-built; full scope remains in progress.

P2/P3 avatar picker compatibility: removed dart:io path-length access in
BotAvatarEditorScreen in favor of XFile.length (including Web blob support).
Picker open, length check, byte read and normalization now share try/finally
busy ownership with duplicate-entry protection; cancel/error restores controls.
Photo/pet/remove actions now wrap at narrow widths. Three VM and three Chrome
cases pass at 320px/2x (/tmp/avatar-picker.log, /tmp/avatar-picker-chrome.log):
cancel, oversized synthetic blob-path XFile, picker exception. Targeted
analysis and diff check pass. These fake platform cases do not prove actual
browser file selection, successful decoding/persistence or native permissions.
Draft/busy route exit guards, remaining avatar controls and visual acceptance
remain open. Not release-built; port 9000 is the preceding release.

Integrated navigation/wrapped-source/search release: full VM regression
finishes in 1:25 with 1,868 passes and two known Liquid preview failures
(dark 12.59%/20,628px; light 2.37%/3,875px),
/tmp/liquid-current-full.log. Full analyze and diff check pass. Release
build succeeds in 106.8s (/tmp/liquid-current-build.log). Existing server
PID 783870 serves port 9000 HTTP 200; local and served main.dart.js SHA-256:
553b2898515064b2bbf4c17c735942ddd66a21b094268b13222eb35288ae5ea2.
Includes compact editor actions, shared navigation, wrapped gutter and
actual-caret search positioning. Prior unbuilt notes for these are historical.
No visual baseline was changed; whole-page/native/device gates remain open.
Next editor audit found BotAvatarEditorScreen using dart:io File(path).length
on an ImagePicker result, incompatible with Web blob URLs; cross_file XFile
provides a browser length implementation. Fix and user-flow verification
remain pending, alongside draft/busy guards in that route.

P2 editor find geometry: replaced logical-line *22px scrolling with the
mounted EditableTextState.bringIntoView for the selected match, guarded
against disposal/changed selection. Twenty-two editor VM and Chromium
cases pass (/tmp/editor-find.log, /tmp/editor-find-chrome.log). New cases
at 320px/1x and 2x search beyond eighty wrapped source lines, verify exact
selection and actual caret containment in the scroll viewport. This also
browser-validates the preceding wrapped gutter and navigation changes.
Targeted analysis and diff check pass. Search from diff/binary modes,
late session/file ownership and full native/optical acceptance still need
review; source remains unbuilt for release. No full-scope gate is closed.

P2 wrapped source gutter: logical line extents now measure wrapped source
using shared explicit code typography/strut, LTR code direction, current
text scaling and available width including Flutter's caret reservation.
The lazy variable-extent gutter retains logical numbering. Editor reading
backing/padding now live outside InputDecorator: its inherited decoration
reduced actual text width and caused a reproducible one-row discrepancy.
Autocorrect/suggestions are disabled. Twenty editor VM cases pass
(/tmp/wrap-solid.log), including mixed CJK/Latin wrapped lines at 320px
1x/2x measured against RenderEditable caret positions, plus existing
10,000-line lazy mounting/scroll checks. Targeted analysis and diff check
pass. Browser, first-baseline/resize/deep wrapped scroll, optical and device
performance checks remain open; search still uses approximate offsets.
Not release-built. This does not close full P2/P5 acceptance.

P2/P3 standalone file navigation: migrated FileEditorScreen to the shared
HermesPageScaffold without wrapping its editor in another scrolling parent.
The shared scaffold now accepts an optional titleSemanticsLabel across all
title variants; the editor retains its localized unsaved-title announcement.
Confirmed discard explicitly permits route exit after layout. Twenty-four
VM editor/back cases pass (/tmp/editor-nav-tests.log), and all eighteen
editor cases pass Chromium (/tmp/editor-nav-chrome.log), including Classic
and Liquid 320px/2x back -> keep -> back -> discard, and the preceding
compact secondary-action menu. Targeted analysis and diff check pass.
These controlled routes do not establish optical or native back-gesture
acceptance. Current changes are not release-built; full scope remains open.

P2 phone editor action density: below 600px, standalone file editor keeps
Search and Save visible and moves secondary actions into the shared adaptive
menu. Labels, callbacks and disabled states reuse the existing actions;
wide/embedded toolbars are unchanged. Sixteen VM editor cases pass
(/tmp/file-actions.log), including 320px/2x menu -> changes -> menu -> editing.
Targeted analysis clean. Standalone shared-scaffold migration remains pending
to preserve title semantics/back handling; browser, optical and release
checks for the action reorganization are open.

Integrated file-editor release: all fifteen current file-editor cases pass
Chromium (/tmp/file-integrated-chrome.log). Full VM suite ends in 1:22 with
1,861 passes and two known Liquid preview golden failures
(/tmp/file-integrated-tests.log). Full analyze and diff check pass. Web
release builds in 112.9s; HTTP 200 at port 9000 and local/served script
SHA-256 match:
5d4ca5eaa49ec7e90af7479a63d77e333d37cbc1d228f72399632a0c5cfc9575.
Includes busy-save/discard protection, shared conflict surfaces, active
reading palette and scaled/lazy gutter. Earlier unbuilt notes for those
changes are historical. No baseline update or optical/device acceptance;
soft-wrap alignment and remaining full delivery gates stay open.

P2/P5 lazy gutter: removed the full-document-height nested scroll/list from
the line-number column. A single fixed-extent ListView now owns its bounded
viewport and the existing gutter controller. Fifteen VM cases pass
(/tmp/gutter-lazy.log); the 10,000-line/2x fixture asserts fewer than 100
mounted number labels at start and end, reaches label 10000 after editor
scroll, and verifies controller offsets agree within 1px. Targeted analysis
passes. This is short-line layout/virtualization evidence, not wrapped-line
alignment or device performance. Browser/full regression/build remain open.

P2 gutter width: line-number width now measures digit count at the current
text scale with 16px total breathing room and the existing 44px minimum.
Fifteen editor VM tests pass (/tmp/gutter-width.log), including a 10,000-line
fixture at 2x text verifying sufficient five-digit width; targeted analysis
clean. This fixture is layout coverage, not a large-document performance
benchmark or proof that the final line is scroll-accessible. Soft-wrap
alignment and scroll synchronization remain open. Source not release-built.

P2 scaled editor gutter: replaced fixed 20.3px row extent with TextPainter
line metrics using the source style and active TextScaler. Temporary painter
is disposed after measurement. Fourteen file-editor VM cases pass
(/tmp/gutter-scale.log), including actual gutter row-spacing assertions for
three short lines at 1x/2x; targeted analysis clean. This corrects unscaled
gutter pitch, not soft-wrapped logical-line alignment, first-baseline proof,
very large line-number width or scroll-sync acceptance. Those remain open,
as do browser/full regression/release checks for the current source.

P2 file reading palette: editor source and line numbers no longer reference
fixed HermesText/HermesBackground snapshots. They use active palette.text/
text2, with codeBg for editing and surface for the gutter. This shared change
also affects Classic. Twelve file-editor VM cases pass (/tmp/file-palette.log),
including light/dark high-contrast palette assertions; targeted analysis clean.
Token assertions are not composited contrast measurements. Four-palette
optical/browser/full-regression/release checks remain open for this change.

P3 conflict browser/scale gate: wide Liquid Reload and Overwrite now run at
both 1x and 2x text. All ten file-editor cases pass VM and Chromium
(/tmp/conflict-scale.log, /tmp/conflict-browser.log), including narrow
conflict Cancel, shared discard material and busy/failure/retry behavior.
Targeted analysis passes. These use controlled API content, not real
filesystem races; dark/opaque optical review and standalone busy-back remain
open. Production file-editor changes still await full regression/rebuild.

P3 wide file conflict: shared GlassAlertDialog now permits an explicit
Liquid maxWidth (default unchanged at 480). Wide file conflict opts into
688px for its 640px dual-pane content plus padding; Classic still uses
the original AlertDialog path. Fourteen combined file/alert VM cases pass
(/tmp/wide-conflict.log). Two new real-editor tests assert overlay material
and verify Reload adopts external content without writing, while Overwrite
writes the draft exactly once. Targeted analysis clean. Browser, composited
contrast/optical, full regression and deployment checks remain open.

P3 narrow file-conflict layout: full-screen conflict view now uses the shared
HermesPageScaffold navigation and an OverflowBar instead of a rigid bottom
Row/Spacer, preserving the opaque diff panes. Six file-editor VM cases pass
(/tmp/file-conflict-verified.log), including a directly mounted 390px/2x
Liquid editor whose external disk change opens conflict, then Cancel retains
the draft without writing. Fixture initially entered the file preview instead
of editor; direct mount isolates this route. A settle timeout was caused by
the intentional saving spinner while awaiting a conflict choice, so the test
pumps the route transition explicitly. Targeted analysis clean. Reload/overwrite,
wide conflict material, browser/optical and release verification remain open.

P3 file discard material: FileEditorScreen now uses showHermesConfirmDialog
instead of an independent AlertDialog, with shared Liquid overlay material
and destructive action semantics/styling. A real Liquid tablet flow asserts
an overlay-role GlassSurface, retains edits on Keep editing, and switches
files only after Discard. Seven combined tablet/confirmation VM tests pass
(/tmp/file-confirm-final.log), including busy-save/failure recovery; targeted
analysis passes. Browser, full-suite, optical and release checks pending for
this integration. No change to conflict-resolution choices in this pass.

P3 file-save failure recovery: controlled failed write leaves original disk
content unchanged, preserves the draft and visible error, restores Save,
and still asks before switching files. Keeping the draft then retrying
successfully writes it and permits switching without a discard prompt.
All four tablet guard cases pass VM/Chromium (/tmp/file-save-retry.log,
/tmp/file-save-retry-chrome.log); targeted analysis clean. This confirms
the preceding busy-switch fix in Chromium as well as failure recovery.
Tests/docs only this checkpoint; standalone route busy-back, Liquid visual
integration and production rebuild remain open.

P3 file-save ownership guard: FileEditorScreen's discard check now refuses
exit/file replacement while saving or already confirming; save itself
guards re-entry and confirmation. Route canPop also excludes saving even
when content is pristine. Three tablet file-editor VM cases pass
(/tmp/file-save-guard.log), including a controlled pending write: selecting
another file cannot replace the draft, then becomes possible after write
completion with exactly one write. Existing keep/discard and clean switches
pass. Targeted analysis clean. Route-specific busy-back, failure recovery,
browser and release validation remain open; source-only change.

P0 current review refresh: document navigation tests now cover both
brightnesses in Classic/Liquid and optionally capture the real route before
and after a 300px simulated keyboard inset at 320px/2x. Four editor and
twenty standalone More capture cases pass (/tmp/editor-more-captures.log),
producing eight editor and twenty refreshed More PNGs. Targeted analyze
passes. Capture catalog records names, state and stale shell-More limitation.
Tests/docs only: no new deployment needed; optical approval, browser check
of the extended fixture and populated wide-shell coverage remain open.

Integrated editor release gate: fresh full regression finishes in 1:33 with
1,846 passes and two failures, only Liquid preview dark/light (12.59% and
2.37% respectively), /tmp/editor-integrated-tests.log. Full analyze and
diff whitespace checks pass. Release builds in 108.0s
(/tmp/editor-integrated-build.log); port 9000 returns HTTP 200 and served
main.dart.js matches the local SHA-256:
ce1b15e98672479ba2ee8f3017824c1a37203d2dbb84e200eec9d7b851e79e67.
Includes both MCP draft guards and the shared-shell document editor; their
earlier source-only notes are historical. No visual baseline/tolerance was
changed. Optical review, remaining editor/interaction scope and actual
device acceptance remain open. Capture catalog now clarifies chronological
coverage and stale More screenshots rather than treating old PNGs as current.

P3 document narrow-input evidence: both Classic/Liquid route cases now run
at 320x844 with 2x text, verify Copy submits the formatted text to a mocked
platform channel, and verify a simulated 300px keyboard inset keeps the
editor bottom at or above 544px with Done reachable. Both VM and Chromium
cases pass (/tmp/document-layout.log, /tmp/document-layout-chrome.log);
targeted analysis clean. No production change this checkpoint. Actual
clipboard permissions, native keyboard and optical acceptance are not
established by the mock/inset fixture. Previous editor source remains unbuilt.

P3 generated-document editor: DocumentEditorScreen now uses HermesPageScaffold
for shared Liquid navigation and a solid codeBg reading plane. Autocorrect
and suggestions are disabled for source editing. Discard confirmation now
has a re-entry guard and explicit post-layout exit allowance. Two VM route
tests pass in Classic/Liquid (/tmp/document-editor-test.log), exercising
keep-editing, JSON formatting, exact Done result and discard/null result.
Targeted analysis passes. Narrow/large-text, clipboard, browser and release
checks remain open; this is not complete editor or optical acceptance.

P3 structured MCP draft protection: McpServerEditorScreen now tracks all six
text controllers plus transport/auth choices for dirty-state back protection,
with the shared discard surface and duplicate-confirmation guard. Save/import
callbacks are ignored during confirmation; their existing successful-result
paths remain unchanged. Ten VM MCP editor/screen/integration cases pass
(/tmp/mcp-structured-final.log). Five editor cases pass Chromium
(/tmp/mcp-structured-chrome.log), covering structured keep/discard/result and
the preceding JSON-editor guard/validation. Targeted analyze and diff check
pass. Import branches and every individual hidden-field dirty transition
are not exhaustively covered by the new cases. Both MCP changes remain
source-only; no release or full optical/device acceptance is claimed.

P3 MCP JSON draft protection: the real McpConfigEditorScreen previously
discarded edits immediately from Cancel/back. It now tracks controller
changes and asks through the shared confirmation surface, guarding duplicate
confirmation and allowing explicit discard after rebuilding PopScope.
Pristine Cancel remains immediate; valid Save still returns the edited JSON.
Six VM editor/integration cases pass (/tmp/mcp-draft-final.log), including
Classic/Liquid 390x844 at 2x text, keep-editing, system maybePop, discard,
invalid JSON and existing secret-preserving save integration. Targeted
analysis and diff whitespace checks pass. Browser/release validation pending;
the structured MCP server editor and other editor guards remain separate work.

P3 More search reading-position release: opening search from a deep directory
now starts at the field; closing restores the saved directory offset, clamped
to current extents. A PageStorage-key-only attempt failed restoration (0
instead of the saved nonzero offset), so each mode now has its own controller
and explicit post-layout restoration with mounted/client guards. All 20
width/scale/brightness cases pass VM and Chromium, including nonzero offset
restore within 1px (/tmp/more-search-position-final.log,
/tmp/more-position-chrome.log). Another 40 shell/overscroll VM cases pass.
Full analyze and diff whitespace checks pass. Release builds in 103.7s;
port 9000 HTTP 200 and local/served main.dart.js hashes match:
d1b79ee3d91e8d3869f12601feca24f2efe86334827779d52263a1b5868448c7.
This release includes preceding More and frame-diagnostic changes. It does
not close whole-page optical, final full-suite, native or device timing gates.

P3 More directory focus: search mode now removes identity/plugin launchers
from the result viewport, restoring them when search closes. Query reset
restores the full directory. Identity and empty-state text use theme typography;
offline identity no longer labels an unconfirmed session as idle/running.
Twenty width/brightness/text-scale cases verify reachable search, no-match
feedback and close/reset restoration. Sixty combined More/overscroll/shell
VM cases pass (/tmp/more-shell-regression.log); targeted analysis clean.
Chromium passes 27 cases (/tmp/more-search-chrome.log): the 20 More cases
plus two performance-dialog and five metric cases. This also closes the
earlier frame-reset browser-check gap, not device measurement. These source
changes are not release-built; optical/native/full-suite gates remain open.

P5 manual frame interval: Client performance dialog now offers Reset, clearing
rolling frame samples and starting interval_frames/interval_slow_frames while
preserving lifetime/network counters. Dialog closes for scenario execution.
Five metric tests and two real dialog tests pass (/tmp/frame-reset-final.log),
including clickable reset at 390x600/2x text in Classic/Liquid; analysis clean.
Platform contract notes route/diagnostic transition contamination and the
600-frame tail limit. This is manual measurement support, not a scenario
benchmark or real-device result. Source-only; browser check and build pending.

P5 measurement export: ClientPerformanceMetrics now exposes UI/raster p50,
sample count in benchmark counters, and explicitly named lifetime slow-frame
ratio in both counters and diagnostic snapshot. Existing p95/p99 remain
bounded to 600 samples; no new hot-path sorting added. Four metric cases and
two real diagnostic-dialog cases pass (/tmp/frame-export-test.log), targeted
analysis clean. Platform contract distinguishes lifetime ratios, rolling
percentiles, per-scenario delta counters and actual missed presentation
deadlines. This adds reporting capability, not device measurements or a
performance acceptance result. Source-only; not release-built.

Current integrated gate: full suite finishes in 1:21 with 1,838 passes and
2 failures, exclusively Liquid preview dark/light
(/tmp/liquid-integrated-current-tests.log). Full analyze clean; diff whitespace
check is clean with core.whitespace=cr-at-eol (existing CRLF files otherwise
produce trailing-whitespace noise). Web release builds in 108.4s; port 9000
HTTP 200 and local/served main.dart.js SHA-256 match:
1639cdac631bf435383b132989f43a7748ed8a4f5e9e76cd1dd8fd9822f98a06.
Logs: /tmp/liquid-integrated-current-analyze.log and
/tmp/liquid-integrated-current-build.log. Includes stale-diagnostics handling
and board-scoped task reading positions. Earlier source-only caveats for
these changes are historical. No golden update or optical approval.
Environment recheck: Linux, no xcodebuild or idevice_id found on PATH; no
native/device acceptance follows. Full delivery scope remains unfinished.

P3 vertical ownership evidence: the 100-task lazy-list test now records
list and board-column positions, switches views, changes board slug and
returns. Both list and column have verified nonzero positions before slug
replacement; another slug starts at zero and the original restores within
1px. Initial view-switch assertion incorrectly used the offset before
ensureVisible moved the outer page back to the toggle; corrected to the
actual pre-switch position, with a separate nonzero slug-switch check.
All 26 task VM tests pass (/tmp/task-vertical-all.log), extended lazy case
passes Chromium (/tmp/task-vertical-chrome.log), analysis clean. This also
documents that the toggle scrolls out of view; no claim of pinned controls.
Fixture uses direct slug changes, not actual board-switch requests or app
restart. Tests/docs only; prior production changes remain unbuilt.

P3 board ownership: task list PageStorage identity now includes API client
identity and board slug; the board LayoutBuilder has the same scoped parent
key so horizontal and nested column positions do not share another board's
storage path. Six phone-shell cases change slug, verify zero horizontal
offset for the new board, restore the original slug and verify its saved
offset. All six pass Chromium (/tmp/board-scope-chrome.log); 64 combined
VM cases pass (/tmp/board-scope-final.log). The first run found an old
literal list-key finder in the lazy-list test; it now uses the scoped key.
Production/shell analysis clean. Tests mutate the slug directly: actual
board-switch API, client replacement and vertical-list restoration remain
separate acceptance cases. Source-only; no new release or visual approval.

P0/P3 chat route above shell: phone matrix now pushes ChatScreen with a
populated user/assistant pair over the actual AppShell, verifies content
and non-hit-testable underlying navigation, then pops and checks restored
home selection/navigation. Six cases pass VM/Chromium (/tmp/chat-shell.log,
/tmp/chat-shell-chrome.log), all 38 shell VM tests pass, and targeted analysis
is clean. Six opt-in chat captures are catalogued (/tmp/chat-shell-capture.log).
This directly pushes the route from the test and seeds ChatStore; session
selection/resumption, real gateway, streaming/approval and optical acceptance
are not proven. No production edits or release build this checkpoint.

P3 board reading position: task horizontal scroll now has an independent
PageStorageKey. Six actual phone-shell cases drag horizontally, record a
nonzero position, switch list -> board and More -> Tasks, and verify the
board remains selected with position restored within 1 logical pixel. All
six pass VM and Chromium (/tmp/task-board-position.log,
/tmp/task-board-position-chrome.log); combined task/shell regression passes
64 VM cases (/tmp/task-board-regression.log), analysis clean. This covers
local widget/view/tab recreation, not app restart, switching boards or
native gestures. Source-only; no new release or optical acceptance.

P0/P3 task-shell integration: six phone-shell cases now open a populated
task list, switch to board, leave for More and return, asserting content
presence, reachable bottom navigation and no layout exceptions at widths
320/390/430 in light/dark with 2x text. Six VM and six Chromium cases pass
(/tmp/task-shell.log, /tmp/task-shell-chrome.log). Twelve additional list/board
captures were produced (/tmp/task-shell-capture.log); names are catalogued.
All 38 shell VM tests and targeted analysis pass. Fixed local board data is
not live transport evidence. Horizontal traversal, selection persistence,
populated chat/wide routes, optical/native gates remain open. Tests/docs only.

P0/P3 populated shell integration: six phone cases exercise actual bottom
navigation Home -> Bots -> More -> Bots -> Home, widths 320/390/430, light/dark
and 2x text. A fixed BotStore isolates directory content from offline refresh;
the initial real-Store fixture cleared seeded records, so no real cached
offline-directory persistence is inferred. Six VM/Chromium cases pass
(/tmp/populated-shell.log, /tmp/populated-shell-chrome.log), six capture cases
export twelve full-shell candidates (/tmp/populated-shell-capture.log).
All 38 shell VM cases pass (/tmp/shell-current-all.log); analysis clean.
The capture catalog records filenames and limits. No production changes,
optical approval, live transport or populated chat/task shell coverage.

P3 stale diagnostics: a failed refresh previously kept the cached running
badge and diagnostic values visible as if current. Rendering now treats
status as unavailable while _error is present, retaining the Bot directory
and retry notice without reporting stopped/zero values. The existing recovery
test now verifies failure -> healthy -> failure -> healthy, with no stale
running/stopped label during the second failure. All 21 VM page cases and
46 offline cases pass (/tmp/bot-stale-status.log, /tmp/bot-stale-offline.log);
the changed recovery case passes Chromium (/tmp/bot-stale-chrome.log), and
targeted analysis is clean. Source-only; no deployment or optical claim.
Reference screenshots and availability of an actual iPhone/Safari target
have been requested asynchronously for remaining visual/native acceptance.

Current motion/overview release: Web builds in 102.7s
(/tmp/liquid-motion-release.log); port 9000 responds HTTP 200 and local/served
main.dart.js SHA-256 match:
709ca2d1129deac5546b3da18dcfa8974667cea66b4baf96163acece7210e975.
Includes compact Bot overview reflow and status/skeleton/typing motion fixes.
The source-only caveats below for those changes are now historical. Browser
motion checks and full analysis pass; latest whole-suite count predates the
motion edits, and known golden/optical/native/performance gates remain open.

P4 browser motion gate resolved for current source: CDP on the old run 24468
showed flutterCanvasKitLoaded pending before test registration; the same
server served canvaskit.wasm HTTP 200 (5,428,553 bytes). This localizes the
hang to renderer initialization, not a motion assertion; it does not prove
the root cause. That obsolete-source run was explicitly interrupted after
diagnosis, not counted as passed. A current-source Chromium run passes all
four motion cases in /tmp/motion-current-chrome.log, covering typing dots,
skeleton and both status-pulse policies. Full analysis is clean
(/tmp/liquid-motion-analyze.log). These are browser fixture checks, not
native accessibility transitions or release frame-time measurements.

P4 typing indicator lifecycle: delayed forward() previously replaced the
repeat simulation, allowing typing dots to stop after a single cycle. Each
dot now starts a repeating animation after its stagger using a cancellable
Timer; reduced motion/accessibility navigation cancels pending starts and
stops the controller. Disposal cancels the timer, and the scale animation is
retained rather than allocating CurvedAnimation listeners during build.
Tests verify all three dots still change after four seconds, distinct phases,
both policies during pending starts and unmount cleanup. Combined state and
high-contrast regression passes 19 VM cases (/tmp/typing-motion-regression.log);
38 full-chat pagination/approval-related cases pass
(/tmp/typing-chat-integration.log). Targeted analysis clean. Browser run 24468
remains live at loading; CDP confirms its test iframe at port 42147, not a
completed run. No browser, device or release claim for these source changes.

P4 runtime motion policy: status pulse and skeleton controllers previously
continued repeating while their render paths drew static output under reduce
motion. They now stop in didChangeDependencies for disableAnimations OR
accessibleNavigation and resume using the existing controller when allowed.
Three policy cases verify repeated stop/resume, zero transient callbacks in
static mode and stable geometry; combined high-contrast regression passes
18 VM tests (/tmp/motion-state-regression.log). Targeted analysis is clean
(/tmp/motion-state-analyze.log). Chromium run 24468 is still live at loading
(/tmp/status-motion-chrome.log); process and CDP port 42147 were revalidated,
not restarted or counted as passing. That run began before the skeleton
case was added, so final source needs a subsequent browser check even if it
passes. Source not built. The separate typing-dot delayed-forward lifecycle
in hermes_states.dart remains to audit; this is not global motion acceptance.

P2 Bot overview reflow: compact/large-text overview no longer puts an avatar
and scale-down status above the entire title. Avatar now top-aligns with
the title/summary column; status follows within that column and wraps at
the requested text scale, without FittedBox. All 21 page cases pass VM and
Chromium (/tmp/bot-overview-reflow.log, /tmp/bot-overview-chrome.log), including
no scale-down wrapper and status bounds inside the overview. Targeted
analysis clean. A fresh complete suite finishes in 1:28 with 1,828 passes
and 2 failures (/tmp/liquid-current-full.log), only Liquid preview dark
(12.59%, 20,628px) and light (2.37%, 3,875px). A renewed direct screenshot
inspection still yielded no reliably legible image; material tuning and
golden approval remain open. No baseline/tolerance changes. This overview
change is source-only; the release identity below remains deployed.

Current integrated release: Web release build succeeds in 104.7s
(/tmp/liquid-directory-release.log). Port 9000 returns HTTP 200; local and
served main.dart.js SHA-256 match:
0b15fda4db239cc1b857f14a1328ee233a8322fffb661f446b279598edb74a90.
Includes independent Bot diagnostics, creation draft protection and the
previous source-only menu/empty-history changes. Full analysis is clean;
targeted regression results below are not a new complete-suite result.
The known Liquid golden review and whole-page/native gates remain open.

P3 independent Bot directory: AgentScreen no longer replaces the entire page
with diagnostics loading/error states. BotStore records, search and actions
remain mounted while status is pending or unavailable. A compact progress
indicator or retry notice reports the endpoint state; no stopped badge or
invented zero-valued diagnostics is shown without status data. The directory
always uses the pinned-header scroll path and supports short-list refresh.
A controlled pending -> failure -> retry test verifies visible records, an
operable Bot menu during failure, and recovered diagnostics. All 21 actual
page cases pass VM and Chromium (/tmp/bot-independent-status.log,
/tmp/bot-independent-chrome.log). Offline/alignment/create regression passes
53 tests (/tmp/bot-directory-regression.log), and full analysis is clean
(/tmp/liquid-directory-full-analyze.log). This does not prove live directory
delivery or optical/native acceptance.

P3 actual Bot creation guard verified: BotCreateScreen now tracks draft fields
and clone/custom-soul choices, intercepts back for discard confirmation, and
blocks exit while creation is pending. Five tests pass in both VM and Chromium
(/tmp/bot-create-matrix.log, /tmp/bot-create-chrome.log); targeted analysis is
clean (/tmp/bot-create-analyze.log). Both Classic and Liquid exercise actual
toolbar back on pristine and busy forms, a second pending back, disabled
submission, successful route result, and failure retaining input and allowing
cancelled discard. A separate discard/cancel test passes after pumping the
input-triggered PopScope rebuild before sending back. The initial failure was
test scheduling, not evidence of a failed rendered-page guard. These controlled
store tests do not verify live Bot creation, browser reload protection, native
back gestures, other editors or whole-page optical acceptance. Not release-built.

P3 form-save guard: HermesFormPage's PopScope denied pops while saving, but
its callback called _confirmDiscard which returned true during saving and
then popped the route anyway. _confirmDiscard now returns false while saving.
Two route tests hold a Completer, attempt maybePop during save, then verify
success exits and failure retains the page. Combined adaptive UI suites pass
seven VM tests and targeted analysis clean. Search finds no production
HermesFormPage call sites yet: this fixes the shared building block, not the
currently unguarded BotCreateScreen. That integration and duplicate discard
prompt/error handling remain required before claiming form protection done.
Both guard cases pass Chromium (/tmp/form-save-guard-chrome.log). Source not built.

P3 overlay keyboard evidence: all twenty actual Bot-page cases now introduce
a 300px view inset while the long-name Group sheet is open, scroll to its
last action, assert hit-testability and bottom <= 544, then dismiss and reset
the inset. All twenty pass VM and Chromium (/tmp/menu-keyboard-matrix.log,
/tmp/menu-keyboard-chrome.log). This simulates keyboard geometry, not native
keyboard events. A new shared GlassAlertDialog test opens via Enter, checks
focus leaves the trigger, closes via Escape and verifies trigger focus
restoration; all six VM dialog tests pass. No production change or build.
Unsaved-state guards and actual device input/VoiceOver remain open.

History empty-input boundary: reproduced StateError: No element from keys.first
when mounting AnchoredHistoryList without keys. Empty input now clears the
origin/before-origin set and an empty rendered list re-arms initial short-list
positioning. New empty -> 3 rows -> empty -> 4 rows test verifies both ends
are reachable. Eleven list cases pass VM/Chrome (/tmp/empty-history-chrome.log),
45 related full ChatScreen/composer tests pass (/tmp/empty-history-integration.log),
targeted analysis clean. ChatMessageList normally always supplies its history
header key, so this is component resilience, not proof of a production
session-switch crash or stale-request resolution. Source not release-built.

Avatar browser lifecycle resolved: replaced the pending precache-only wait
with a bounded loop advancing real codec time and test frames, asserting a
decoded RawImage rather than merely completing a delay. All four avatar
cases now pass both VM and Chromium (/tmp/avatar-bounded-chrome.log),
including invalid -> valid portrait -> procedural animation, and targeted
analysis is clean. This supports a fixture scheduling problem, not a
production image defect. Superseded live precache run 78749 was explicitly
interrupted after the corrected run passed; it is not counted as a pass.
No production code change, release build or optical/native acceptance.

P2 avatar image lifecycle: new test creates an actual 20x80 PNG, replaces
invalid bytes with that image, checks decoded dimensions/cover fit and stable
44x44 geometry, then removes the image and verifies procedural animation
resumes. Four VM avatar tests pass. Initial Chrome run fails the new case
without a detailed assertion; test precaching previously used a different
Uint8List/provider identity. It now waits on the Image widget's actual
provider; VM remains green, Chrome rerun is live (session 78749,
/tmp/avatar-image-chrome-fixed.log) and not yet accepted. No production
changes or release. Hidden-Bot full interaction matrix passes all twenty
Chrome cases (/tmp/hidden-bots-chrome.log), including the real drag to reveal
controls after dismissing menus. Optical/native gates remain open.

P2 hidden Bot controls: hidden rows already share 44px avatars/top alignment.
Their expand control still used compact density without a tooltip. It now
has a 44x44 minimum standard-density target, localized label and expanded
semantics. Twenty actual page cases now insert a hidden Bot, expand, open its
menu, verify Unhide is offered, close and collapse, then exercise Group/Bot
menus and diagnostics. All pass VM (/tmp/hidden-bot-final.log). Initial
320px/2x failures were offscreen test taps after nested-scroll restoration;
bounded real drags and hit-test assertions now verify reachability instead
of assuming ensureVisible always suffices. Targeted production analysis clean;
no native screen-reader, browser or release claim for this new change.

P1 reverse-inertia coverage: paired-list fixture now prepends twenty old
rows and repeats the timestamped fling on the negative scroll region. Both
directions perform 80 -> 240 -> 60 -> 180 height changes during twelve
inertial frames, comparing a retained row against an unchanged control.
Then explicit animateTo crosses to 1200 while resizing again and follows
each controller's own linear trajectory. All ten VM cases pass; targeted
analysis clean. All ten also pass Chromium (/tmp/reverse-inertia-chrome.log).
This remains a controlled SliverList fixture, not bounce
boundary or actual HTTP/media evidence.
The long-name Bot/Group menu matrix also passes all twenty Chromium cases
(/tmp/group-title-chrome.log), including full wrapping titles and final
action reachability. No new release build in this checkpoint.

P2/P3 action-target identity: actual Group action menu added to all twenty
Bot responsive cases, using a long Chinese group name. Existing menu did not
overflow because _ActionSheetHeader forcibly ellipsized the title to one
line. Titles now wrap naturally and the shared header aligns its icon to
the top; Group menu is scrollable like the Bot menu so full names and final
actions remain reachable. Tests assert unlimited title lines and hit-testable
delete entry without invoking deletion, then close and exercise Bot actions
and diagnostics. All twenty VM cases pass (/tmp/group-readable-title.log);
targeted analysis clean. Test scroll alignment was corrected to keep buttons
below pinned headers. Source only; no Chrome rerun, optical approval or
release build for this change yet.

P0 whole-shell capture increment: AppShell home fixture now spans five widths,
light/dark and 1x/2x text with Chinese labels. Twenty VM cases pass with
actual PNG capture (/tmp/shell-review-matrix.log); targeted analysis clean.
Capture filenames/command and disconnected-data limitations are documented
in review-capture-catalog.md. A renewed direct image-view attempt still did
not yield a reliably readable picture, so no material calibration or golden
approval follows. Full populated core routes, overlays and optical review
remain open. Tests/docs only; existing port-9000 release unchanged.

Integrated Web release: build succeeds in 103.7s; port 9000 responds HTTP 200
and local/served main.dart.js SHA-256 both match
0d3b07874ada3e817d71660d21c4075ecf33eb54985b3ab613fe965beae886a3.
Includes avatar resilience/accessibility, readable offline Bots, scrolling
Bot action menu, and forward/reverse/user-scroll history compensation. Bot
page Chrome matrix passes all twenty cases (/tmp/bot-menu-chrome.log). Build
log: /tmp/liquid-integrated-build.log. New platform-material-contract.md
documents Web/native limits, material calibration and device measurements;
the implementation document now directs current-state readers here rather
than presenting its old hash as current. No optical/native acceptance claim.
Latest full-source regression completes in 1:51 with 1,796 pass / 2 failures,
only preview liquid dark/light (/tmp/liquid-release-full.log). Full analysis
clean (/tmp/liquid-release-analyze.log); goldens/tolerances remain unchanged.
prior historical source-only notes no longer describe deployment identity.

P1 inertia/programmatic ownership evidence: added paired real scroll views
with timestamped simultaneous gestures. After release, verifies active
inertia, grows one cached row by 160px and compares a visible row against
the unchanged list for twelve 16ms frames. Then starts explicit linear
animateTo(1200), shrinks the row, and checks each controller against its own
start-to-target trajectory and final target. Nine VM list tests and targeted
analysis pass. All nine also pass Chromium
(/tmp/inertial-resize-chrome-fixed.log). An initial assertion incorrectly compared absolute offsets
after the lists had acquired different compensated origins; replaced with
the exact per-controller animation trajectory, not a wider tolerance.
No production edits this checkpoint. Reverse-side inertia, bounce physics,
real tool/media timing and whole-screen session races remain separate gates.

P1 user-scroll resize: anchor compensation subtracts the measured scroll
offset travel from the expected row coordinate, allowing a continuing user
gesture while correcting layout displacement. Uses public userScrollDirection
rather than protected ScrollPosition.activity (the initial activity-based
attempt was replaced after analyzer warnings). Reverse fixture now holds a
drag and moves -2px on every frame through three growth/shrink transitions;
expected row travel follows the cumulative gesture. Current combined list,
full ChatScreen pagination/stream and composer suites pass 53 VM tests
(/tmp/user-resize-regression.log); targeted analysis clean. All eight list
cases also pass Chromium (/tmp/user-resize-chrome.log). User scroll
direction can persist into ballistic motion, so inertial resize and animation
ownership still need dedicated checks before release. Source remains unbuilt;
the 1,794/2 full checkpoint predates this compensation change.

Fresh source checkpoint after avatar, Bot-sheet and reverse-history fixes:
full VM regression completes in 1:54 with 1,794 pass / 2 failures, still only
Liquid dark/light preview goldens (/tmp/liquid-latest-full.log). Full analysis
clean (/tmp/liquid-latest-analyze.log). Reverse resize tests now include the
oldest header at minScrollExtent and check five 16ms frames after each height
change; all seven anchored-list cases pass VM and Chromium
(/tmp/reverse-history-chrome.log). This proves the tested top/header case,
not all missing-neighbor or moving-resize cases. No golden/tolerance changes.
Previous Chrome avatar/alignment process remains live; read-only DevTools
inspection shows its second iframe loaded, with no replayed JS exception.
The root cause remains unproven; it has not been restarted or counted passed.
No release build at this checkpoint; port 9000 still serves prior source.

P1 reverse-history resize: viewport anchor extraction now includes reverse
SliverList rows using the next mounted child's layout offset as the far
boundary. It does not read descendant sizes during layout or use estimated
scrollExtent for a missing neighbor. The new reverse fixture prepends twenty
rows, verifies jumpTo(-760) is retained, then grows/shrinks a newer cached row
80 -> 240 -> 60 -> 180 while the reader remains within 1px. Six list tests
pass; combined full ChatScreen/pagination/composer suites pass 51 tests in
41s (/tmp/reverse-resize-regression.log); targeted analysis clean. The original
fixture failed before resize because its target row was no longer mounted,
so that initial failure is not evidence of a measured resize-only drift.
Active-scroll resize, last reverse child without a mounted neighbor, actual
tool/media/session/window-trim combinations and browser/device validation
remain open. No new release build; earlier forward-only notes are historical.

P3 Bot offline/action-sheet integration: removed whole-row 0.5 opacity for
unreachable bots; explicit offline icon/text remain and management actions
retain their normal readability. Expanded the twenty-width/theme/text cases
to transition the actual store offline, verify the row remains undimmed,
open its actual action menu and reach the final delete entry without invoking
it. This exposed existing bottom RenderFlex overflow in all twenty cases
(106px at ordinary text, up to 313px at 2x). The Bot action sheet now scrolls
its contents; all twenty updated VM cases pass and targeted analysis is clean.
The prior browser avatar/alignment run (session 84754) remains live but stuck
loading its second file after three avatar cases passed; no browser-wide pass
or new release is claimed. Whole-shell/menu/device acceptance remains open.

P2/P5 avatar resilience: BotAvatar now observes runtime reduced-animation and
accessible-navigation changes, stops/reuses its ticker across repeated
transitions, and caches source bytes rather than decoding Base64 on animation
frames. Loading and image-codec failure use a fixed-size procedural fallback;
the failed-image fallback intentionally stays static. Five avatar/alignment VM
tests and twenty actual Bot-page responsive cases pass; targeted analysis is
clean. The avatar tests cover repeated accessibility toggles and invalid image
bytes, not successful-image optical review or native accessibility events.
Source only: no release build or port-9000 update in this checkpoint. General
history resize, whole-page material calibration and all outstanding delivery
gates remain in scope.

P1 resize compensation in progress: forward-side cached rows now use sliver
layout offsets to preserve the first fully visible row during stationary
reading. Correction happens before paint and skips active scrolling, viewport
resizing and bottom following. The prior 160px reproduction now passes for
growth/shrink; combined anchored-list/full ChatScreen/composer-search suites
pass 50 tests (/tmp/resize-sliver.log). No descendant size access is used.
Reverse-side older-history rows are not yet compensated, so general resize
acceptance remains open. Source changes are not release-built yet; port 9000
still serves the prior motion release.
Five anchored-list tests also pass Chromium (/tmp/resize-sliver-chrome.log);
targeted analysis clean. Reverse-side handling remains required.


P1 general resize defect reproduced: new anchored_history_list_test case
changes a cached row above the reader from 80 to 240px and expects the same
visible row position. Current list fails this invariant. This is distinct
from fixed-footprint image decode and successful prepend tests. First repair
attempt measured descendant transforms during RenderViewport.performLayout,
triggering Flutter size-access assertions and existing regressions; that
attempt was removed before deployment. The failing regression is retained
without skip or relaxed tolerance. Current source therefore has an additional
known test failure, and general resize preservation is explicitly unfinished.
Port 9000 production remains unchanged. Logs /tmp/history-resize-reproduction.log
and /tmp/history-resize-fixed.log (rejected implementation, not current behavior).


Fresh whole-repository checkpoint: flutter test --no-pub completes in 1:48
with 1,788 pass / 2 failures, only preview liquid dark/light. Full analysis
clean. Log /tmp/liquid-current-full-regression.log. Port 9000 still serves
bc7841860af4414504aa909848436c21496c0b7b0b77c0dbc21fcb4b19637f72.
Added interaction-reproduction-catalog.md with concrete fixture/manual steps
and coverage boundaries. flutter devices reports Linux only; xcodebuild is
not found, so iPhone build/device acceptance remains unavailable here.
No golden changes, no production change, no full-goal completion claim.


Motion release verified: related VM suites pass 28 tests, Chrome button/send
suites pass 20, full analysis clean. Release succeeds in 104.0s; local/9000
SHA-256 matches bc7841860af4414504aa909848436c21496c0b7b0b77c0dbc21fcb4b19637f72.
Logs /tmp/motion-unification.log, /tmp/motion-chrome.log, /tmp/motion-build.log.
Full-suite, optical and native acceptance are still outstanding.


P4 motion categories: introduced HermesGlassMotion press/expansion/curve and
accessibility duration resolver. Liquid send feedback now matches GlassButton
(120ms easeOutCubic instead of 100ms linear); Classic send remains unchanged.
Composer focus/expansion reuse tokens, with existing reduced-motion fallback.
Send tests assert duration/curve alongside target size, reduced animation,
and exactly one send. No claim that all page-route motion is unified.


Task reading-semantics release: all 26 accessibility cases pass both VM and
Chromium; full analysis clean. Release built in 102.7s; local/9000 SHA-256:
fc7be1aac9ab7826593edbb5d57c40f16ad7cc59fa6d00425cfbdbd5ab99f030.
Logs /tmp/task-reading-semantics.log, /tmp/task-semantics-chrome.log and
/tmp/task-semantics-build.log. Full-suite/optical/native gates remain open.


P5 task information parity: task card ExcludeSemantics previously removed
priority, assignee, comment count and progress while its outer label exposed
only title/status. Outer card semantics now include the visible metadata and
percentage value, retaining a single focus node plus tap/long-press/selection.
Added a populated urgent-task check for 12 comments and 3/4 progress = 75%;
updated list/board/selection label expectations. Full analysis clean. This
verifies semantics-tree information, not native VoiceOver pronunciation/order.


P1 delayed inline-image evidence: real Markdown image builder mounted in
AnchoredHistoryList with a controlled image-cache completer. Before completion
RawImage has no decoded image; after a 300ms pending interval, a portrait
40x300 image is supplied (or decode failure reported). Following-row position
is checked every 16ms for ten frames at 0.1px tolerance. Both cases pass VM
and Chromium, and combined image/list VM suites pass 9. This validates the
existing fixed-footprint policy, not actual HTTP, full ChatScreen media
interaction, changed dimension metadata, tool expansion or device performance.
Logs /tmp/delayed-image-anchor.log and /tmp/delayed-image-chrome.log.
No production code changes or build.


Settings wide-title release: corrected 40-case matrix passes Chromium (47s);
release build succeeds (101.5s), local/9000 main.dart.js SHA-256 matches:
05d3c6ceeba7d6f4c2acad5a1429138397fe84e5e7248404721f168d8f8d1c68.
Logs /tmp/settings-responsive-chrome-fixed.log, /tmp/settings-wide-build.log.
No new full-suite or whole-page optical/native acceptance this checkpoint.


P5 settings responsive integration: expanded appearance/language interaction
matrix to widths 320/390/430/768/1280, 1x/2x text, English/Arabic and light/dark.
Each selects Indigo via the real theme card and Traditional Chinese via the
language sheet. Four desktop-2x cases exposed 78px English / 112px Arabic
horizontal overflow in the fixed 300px sidebar title row. Expanded title
constraints allow natural wrapping; all 49 VM settings tests now pass
(/tmp/settings-responsive-fixed.log). Full analysis clean. This is layout
and selection evidence, not optical or native screen-reader acceptance.


P5 feature-page responsive matrix: expanded Bots/Tasks/More to widths
320/390/430/768/1280 at height 844, light/dark, 1x/2x text. Existing task
search/filter/list-board and bot diagnostics interactions run in each size.
All 65 VM tests pass; capture-enabled rerun also passes and produces
width-suffixed review candidates without overwriting other sizes. These are
feature-page fixtures, not complete shell, settings, chat or device gates.
Logs /tmp/responsive-core-matrix.log and /tmp/responsive-core-captures.log.
No production code changed, no optical approval or release build.
Chromium repeats all 65 cases successfully (1:03), including wide diagnostics
and task flows; targeted analysis clean. /tmp/responsive-core-chrome.log.


Task lazy-list release: related screen/detail/store/sheet/overscroll suites
pass 36 tests, Chromium accessibility suite passes 9, full analysis clean.
Release succeeds in 100.2s; local/9000 script SHA-256 matches:
23e6c1a27e87b88a50a4fdf11f134318197f42f42789791f613352b7b8c20e6c.
Logs /tmp/task-lazy-regression.log, /tmp/task-lazy-chrome.log,
/tmp/task-lazy-build.log. No new full-suite or optical/device acceptance.


P3 task list scalability and realistic data: replaced eager ListView children
with ListView.builder, stable task-list PageStorageKey and always-scrollable
refresh physics. The 100-task test now verifies lazy list and board reachability.
Liquid 320px light/dark 1x/2x fixtures include a long bilingual title, long
assignee and comment/priority metadata, exercising both list and board before
search/filter flows. Eight fresh list/board capture candidates generated.
All nine task accessibility tests pass. No optical or frame-time approval is
inferred from lazy-build assertions.


P0 capture coverage: added opt-in actual Bots and Tasks page captures for
320x844 light/dark at 1x/2x text. Bots fixture now includes two realistic
names/descriptions, including a long name. Tasks expands its existing
interaction matrix from 2x only to 1x/2x. Combined capture/interaction run
passes 13 tests (/tmp/core-page-capture.log). Eight PNGs generated under
/tmp/bots-* and /tmp/tasks-*. See review-capture-catalog.md for commands,
fixture limitations and remaining whole-shell/wider-screen coverage. Viewer
output remains illegible, so no optical approval or golden replacement.
Both expanded suites also pass 13 Chromium cases without capture enabled
(/tmp/core-page-chrome.log); targeted analysis clean. No production changes.


P1 moving-merge plus streaming: the real-store ten-page screen fixture now
moves the held pointer by -2px on each of 30 16ms merge frames and verifies
anchor displacement against cumulative gesture travel (2px tolerance). It
also injects session-scoped start/30 delta/complete events into ChatStore's
production event handler during page seven; the final assistant text must
exactly match all 30 deltas. The VM case passes, including page-five retry
and subsequent pagination without bottom return. Transport events are
controlled via attachEvents rather than a live gateway/routed multiplexer;
media late resize, multi-session routed races and device frame performance
are not proved. No production changes or rebuild this checkpoint.
Expanded case passes Chromium (35s); related screen/session/header suites
pass 36 tests and targeted analysis is clean. Logs:
/tmp/history-stream-chrome.log and /tmp/history-stream-regression.log.


History retry release: screen/session/header regression passes 36 tests and
the expanded ten-page case passes Chromium; full analysis clean. Release
build succeeds in 105.8s and local/9000 main.dart.js SHA-256 match:
86d95f2c0a2e8cf8569439d9309da7d67b0c2d36e23b5112b76616f625d3a437.
Logs /tmp/history-retry-regression.log, /tmp/history-retry-chrome.log,
/tmp/history-retry-build.log. No full-suite rerun this checkpoint; the last
complete suite's two unreviewed Liquid golden failures remain open.

P1 failure/retry and held-pointer merge: expanded the real SessionStore +
ChatScreen ten-page fixture with a page-five failure and actual inline retry
tap, plus a page-seven held drag across response application. The initial
failure exposed 12 requests at the same offset from repeated near-top scroll
notifications. ChatScreen now suppresses automatic pagination while
historyError is present; explicit retry retains the viewport-preserving path.
The test verifies exactly two page-five requests (failure/retry), retained
message count on failure, a hit-testable retry at the actual minimum extent,
and another 24px drag after merge moving the anchor by 24px rather than being
cancelled. The expanded VM case passes without changing the 2px tolerance.
This held-pointer case pauses movement during merge; continuous per-frame
movement, stream/media and session-change combinations remain separate gates.


P1 real-store screen pagination: added a 390px Liquid-dark ChatScreen fixture
with the production SessionStore, resume path and API message parsing. Only
API/gateway transports are faked; loadOlderMessages is not overridden. Eleven
ordered API offsets (initial plus ten delayed pages) are verified alongside
loading feedback, message uniqueness, exhaustion and per-16ms visible anchor
positions within 2px after each merge, without bottom return. User drag occurs
while each response is pending; the stationary-anchor check waits for actual
scroll activity to end before releasing the response. An initial page-four
4.7px mismatch disappeared after this correction (no production fix or relaxed
tolerance). This does not cover active-drag merge, concurrent stream/media,
retry at screen level or native performance. Combined screen/profile suites
pass 35 tests; targeted analysis clean. /tmp/real-history-regression.log.
The same ten-page screen case also passes Chromium
(/tmp/real-history-screen-chrome.log). No production changes or rebuild.


Material-role release verified: full regression 1,698 pass / 2 failures,
both existing Liquid preview light/dark goldens; no baselines or tolerances
changed. Chrome role matrix passes 13 tests. Release build succeeds in
110.6s; HTTP 200 and local/9000 main.dart.js SHA-256 match:
2b146daa5916b765d179279bbc2553eb9c0eca8553fe1aebf4699c7bc982daa9.
Logs: /tmp/material-roles-full-test.log, /tmp/material-roles-chrome.log,
/tmp/material-roles-build.log. Whole-page optical, full pagination integration
and native/performance acceptance remain open.

P4 remaining role integration: migrated approval sheets, command palette,
adaptive forms/menus, slash help, appearance preview/selectors, chat queue,
suggestions, header and drawers, and the docked right sidebar. No production
thick:true callsites remain; the XL status strip intentionally retains the
legacy regular density pending optical calibration. Role assignment does not
change existing tint or explicit contours. Eight relevant integration suites
pass 133 tests, full analysis clean. Logs /tmp/material-roles-integration.log;
release and full regression results are recorded below after completion.


P4 semantic material migration: introduced HermesGlassRole and immutable
HermesGlassRecipe for navigation/control/overlay. Migrated primary AppShell
navigation, page headers and sheets, composer, search, action groups, floating
actions, menus and alerts. Explicit radius retains current geometry; legacy
thick callers remain compatible. Initial recipes retain existing thick tint
and blur, while overlay defaults to sheet contour. This is role ownership,
not distinct optically calibrated materials or P4 completion. New role matrix
covers light/dark, transparent/opaque and nested shared-plane rendering;
combined material/theme/control suites pass 67 tests. AppShell, composer
alignment/queue and page-dismiss integration suites pass another 37 tests;
full flutter analyze is clean. Current source changes
are not yet release-built; port 9000 still serves the preceding release.


More/settings release: full regression 1,685 pass / 2 existing Liquid
golden failures (1:14), full analyze clean. Review capture extends More
fixture to four light/dark 1x/2x cases; fixed missing SharedPreferences
mock exposed by runAsync capture, all four pass independently. Artifacts
/tmp/more-{light,dark}-{1.0,2.0}.png are review candidates, not approved
goldens. Full run predates fixture expansion. Release succeeds (109.5s);
local/9000 main.dart.js hash matches:
d302ea7ed02a0e081f859379acffd1f04066f242e7bbeb32a2455e178a9c4858.
Logs /tmp/settings-release-regression.log, /tmp/settings-release-build.log,
/tmp/settings-release-analyze.log and /tmp/more-review-final.log.
Remaining full-page visual/device/performance gates remain open.

P5 settings language matrix: expanded 320px/2x appearance/language flow
to English and Arabic in both Liquid brightness modes. All 13 VM settings
tests pass; all four matrix cases also pass Chromium, including option
selection and non-ellipsis labels. Logs /tmp/settings-matrix.log and
/tmp/settings-matrix-chrome.log. Removed an unnecessary null assertion
reported by analysis. This is interaction/layout evidence, not whole-page
optical or screen-reader device approval. No production changes this
checkpoint; pending More/settings source edits are still not Web-built.

P4 appearance feedback: theme preview selection exposes button/selected
semantics and uses shared feedbackDuration with zero duration under
disableAnimations or accessibleNavigation. A real appearance-page test
verifies reduced-motion duration and selection after tapping Indigo; ten
settings tests pass (/tmp/theme-motion.log), source analysis clean. This
does not prove all app motion or screen-reader behavior on a device.
No new release build in this checkpoint.

P3 settings typography: language sheet labels now wrap and align badges
to the top rather than truncating to one line. Expanded test harness scales
all routes/overlays, not only SettingsHub home, exposing a 64px theme-grid
overflow at 320px/2x. Replaced fixed-aspect grid with width-constrained Wrap
cards that take natural text height. Nine localized settings tests pass,
including opening language sheet at 320px/2x and selecting Traditional
Chinese; targeted analysis clean. /tmp/settings-language-fixed.log.
No release build or full visual acceptance in this checkpoint.

P3 More directory hierarchy: identity card now shows connection state once
as a wrapping status chip alongside runtime state, rather than repeating
connection wording with a competing trailing chip. Avatar and directory
icons align to the top of multi-line content. Two actual MoreScreen cases
pass at 320px/2x Liquid light/dark; targeted source analysis and existing
settings navigation/l10n/overscroll tests pass. /tmp/more-layout-direct.log
and /tmp/more-layout.log. Whole-page optical review and release build
remain open; this does not close settings integration.

Task integration release checkpoint: task screen/accessibility/detail/sheet/
store and page overscroll tests pass 34 cases. Chromium task accessibility
suite passes 7 (including filter clearing, 100-task lazy reachability and
vertical-only refresh). Full analysis clean. Release Web build succeeds
(105.2s), local and port-9000 script SHA-256 match:
b84de28ce99b3a42108c4c543c2e893fe78ffe2cdfc412a7bbebe61d9dd82452.
Logs /tmp/task-release-tests.log, /tmp/task-release-chrome.log,
/tmp/task-release-analyze.log and /tmp/task-release-build.log. No fresh
full test suite or whole-page optical/device acceptance in this checkpoint;
existing Liquid golden failures and remaining P0–P5 gates stay open.

P3 board refresh repair: gesture test reproduced zero refresh calls from
vertical column drag. RefreshIndicator now accepts only vertical
notifications at column depth 1 in board mode (depth 0 in list mode).
The same test now verifies one refresh after vertical drag and no refresh
after horizontal movement. Seven accessibility/interaction tests pass;
targeted analysis clean. Logs /tmp/board-refresh-before.log and
/tmp/board-refresh-final.log. No task release build this checkpoint.

P3 board scalability: replaced eager scrollable Column task contents with
an Expanded ListView.builder per board column. Column titles remain above
the scrolling cards; each column has a storage key and independent scroll
position. A 100-task test proves last row is initially unbuilt and becomes
hit-testable after scrolling. Six accessibility/interaction cases pass,
targeted analysis clean (/tmp/board-lazy-final.log). This is lazy-build and
reachability evidence, not device frame-time or refresh interaction proof.
No task release build yet.

P3 task card hierarchy: title now uses its own wrapping region; status and
priority share a wrapping metadata row, with assignee/comment text below.
Removed duplicated priority from the text summary and fixed title/metadata
line truncation. Taller cards exposed board-column vertical overflow in
320px tests; columns now scroll vertically within the horizontal board.
Five accessibility cases pass after this fix; targeted analysis clean.
Logs /tmp/task-card-hierarchy.log and /tmp/task-card-final.log. Large-data
board performance, column scroll/refresh interaction and optical review
remain open. No task release build yet.

P3 task empty-state integration: distinguish active search/assignee/tenant
no-match from no tasks, using existing localized generic no-match wording.
No-match action clears query and restrictive filters; genuinely empty
state offers new task. Removed fixed half-screen empty-state height and
retained always-scrollable refresh physics. Expanded 320px/2x light/dark
tests exercise no-match display, scrolling to reset, and restored results;
five accessibility cases pass, targeted analysis clean. No release build
at this checkpoint; task-page visual/device acceptance remains open.

P3 visible task filters: active assignee/tenant/archive conditions are now
shown below toolbar/search with a wrapping layout and directly accessible
clear button. Clearing these preserves the independent search query.
Five accessibility cases pass, including actual clear operation at
320px/2x light/dark and visible condition labels; targeted analysis clean.
Logs /tmp/task-filters.log and /tmp/task-filters-verified.log. Empty-result
wording, page optical review and final task build remain open.

P3 task toolbar integration: canonical task screen separates view selection
from its three action controls below 360px available width or >1.5x text,
retaining a single row on wider layouts. Liquid search uses shared
GlassSearchField; Classic retains TextField. Existing screen/accessibility
suite passes 8 cases; expanded accessibility suite passes 5 including
320px/2x Liquid light/dark toolbar geometry and actual query filtering.
Logs /tmp/task-layout.log and /tmp/task-narrow.log. No page optical review,
keyboard/board density acceptance or release build at this checkpoint.

Release checkpoint: added five actual short ChatScreen variants checking
message bounds below app bar/above composer (Classic, Liquid light/dark,
320px 2x). All pass; these verify message visibility, not short-page header
visibility after auto-follow or streaming growth. Fresh full VM run:
1,672 passed / 2 failed, only existing Liquid light/dark preview goldens
(/tmp/hermes-release-regression.log, 1:14). Full analysis clean. Release
Web build succeeds (112.1s), local and port-9000 main.dart.js match:
396e390f0ac57f062ddbc0d8f3223665ebbb13eb84a3768e4ee2ffe17bc4bbb5.
This deploys accumulated anchored-list/header/search changes for review,
not whole-goal acceptance. Remaining visual goldens, actual transport
pagination/stream/media combinations, broader page integration and device
performance gates remain open.

P1 search/header boundary fix: when top padding changes, a reader at the
minimum scroll boundary now receives the inverse padding delta before
layout. Reverse-side padding changes the leading boundary, not the center
origin; readers away from the boundary retain their coordinate. The
previous 103px search-close regression now passes with original 1px
position assertions at both start and middle. Combined composer, boundary
and per-frame long-chat tests: 43 pass (/tmp/search-inset-related.log).
Removed obsolete non-null assertions in the migrated list test. No new
release build or full-suite rerun in this checkpoint; full acceptance
and actual short ChatScreen auto-follow validation remain open.

Current broad gate: full VM run 1,666 pass / 3 fail (1:16), log
/tmp/hermes-current-full.log. Two are existing Liquid preview goldens;
third initially used obsolete ListView lookup. Updating that test to
AnchoredHistoryList and minScrollExtent-relative top navigation exposes
an actual search-toggle position regression: first question returns at
y=91 instead of y=194 after closing search (103px difference). Assertion
is preserved; /tmp/composer-anchor-final.log. Four boundary tests pass
in Chromium with CHROME_EXECUTABLE set to the installed Playwright Chrome
path (/tmp/hermes-anchor-chrome-final.log); initial default browser lookup
failure was tooling only. ChatMessageList now keyed by session epoch to
isolate origin state across sessions; targeted analysis of panel passes.
This key addition was made during the broad run and needs fresh focused
session validation. No new build; search/header coordinate regression
must be resolved before deployment.

P1 short-header layout correction: a dedicated history RenderViewport
performs its first measured layout, then (only when the forward extent
fits and reverse content exists) corrects to the measured minimum and
relayouts before paint. No row-count switch or post-frame visible jump.
All four boundary tests now pass, covering 1/2/4-message headers and ten
prepends plus origin trim/restore. Combined actual ChatScreen pagination
and WebUI parity/approval tests pass; targeted analysis clean. Logs
/tmp/header-render.log and /tmp/header-render-screen.log. Initial tail
following in actual short ChatScreen, subsequent growth, accessibility/RTL
and browser renderer behavior still require verification. No release build
yet; this is not full P1/P5 completion.

Short-header physics experiment: tried a one-shot
ScrollPhysics.adjustPositionForNewDimensions correction to minScrollExtent
when the forward extent fits. Both initial and zero-dimension-guarded
variants still fail all short-header cases; logs /tmp/header-physics.log
and /tmp/header-physics-second.log. Removed the ineffective physics/state
code. Do not infer a working geometry correction from this experiment.
The short-header issue remains unresolved; long-history layout changes
are retained, with no release build this checkpoint.

P1 short-content investigation: expanded header visibility to 2/3/5 total
rows (one header plus 1/2/4 messages). A trial <=2-row ListView fallback
passed the original case but failed 3/5-row cases and would change scroll
coordinates on message growth; removed it rather than ship a row-count
heuristic. Final current-source boundary suite: ten-prepend/trim/restore
case passes, all three short-header cases fail. Targeted analysis passes.
Log /tmp/short-matrix-final.log. Short-content placement needs measured
viewport/content geometry, not a larger arbitrary row cutoff. No production
behavior change retained and no release build in this checkpoint.

P1 trim-boundary correction: retain the origin-side key set when the
original row is trimmed, leaving the center boundary after surviving
older rows rather than resetting it to the oldest row. Ten-prepend test
now passes both removal of the origin/newer rows and restoring those
rows with the retained older row at the same coordinate. Five screen
per-frame pagination cases also pass; targeted analysis is clean. Logs
/tmp/anchor-trim-restore.log and /tmp/anchor-trim-screen.log. Short-history
header test still fails and remains enabled. These tests do not cover
arbitrary removal within the reverse sliver or session replacement with
reused identifiers. No build/release performed.

P1 origin-boundary tests: new anchored_history_list_test verifies ten
50-row variable-height prepends (550 final rows) retain Row 0 on every
sampled frame. Additional boundary assertions fail: after scrolling into
older content, removal of original origin and newer rows loses retained
Row -1; a two-row short transcript does not expose its history header at
initial offset. Logs /tmp/anchor-boundaries.log and
/tmp/anchor-boundaries-final.log. These are list-level layout tests, not
ten network-backed screen pages. Both failures remain enabled. Stable
origin rebasing and initial header placement must be fixed before build/
release; previous single-page passes do not close these requirements.

P1 layout-origin implementation: AnchoredHistoryList now splits timeline
rows around a retained row key using CustomScrollView.center. Older rows
grow in reverse before this origin, leaving existing forward rows at their
prior coordinates. Header/top padding belongs to the reverse side, dock
padding to the forward side. Near-top pagination and proportional message
location now account for minScrollExtent. All five ChatScreen scenarios
pass the unchanged per-frame presence/2px-position gates as well as final
position, loading feedback, keyboard/composer and search assertions.
Log /tmp/anchored-page-final.log. Related inline approval/parity, lifecycle
and viewport tests: 33 pass (/tmp/anchored-related.log); targeted analysis
clean. The retained-origin removal/rebase during window trimming, session
changes, repeated pages and short-history header layout still require
focused validation. Recovery fallback remains for other structural edits.
No release build in this checkpoint; do not claim full P1 acceptance.

P1 intermediate-frame gate supersedes final-position-only pass: tests now
sample anchor presence/position every 16ms for up to 30 recovery frames,
retaining all final-position assertions. All five variants fail continuity
despite correct final coordinates. Classic anchor is absent for five
samples; Liquid normal text also disappears, and 2x text has a missing
sample then y=-258 before returning to y=227. Logs:
/tmp/page-frame-audit.log and /tmp/page-frame-matrix.log. Targeted analysis
passes. This confirms multi-frame reacquisition is not a seamless paging
solution; do not ship or close P1 on the previous five final-state passes.
Next implementation must preserve a layout origin through prepend (e.g.
centered bidirectional slivers) rather than seek across visible frames.
That requires auditing near-top threshold against minScrollExtent, message
locator proportional math, trimming/rebasing, header placement and session
resets; changing only ListView to reverse is not equivalent. No release
build was run, and port 9000 remains on the earlier release.

P1 anchor reacquisition implementation: when first-frame measured anchor
is unavailable, screen now uses mounted message order to approach the
original row (bounded 24 frame attempts), then restores its captured screen
coordinate using actual user motion. Epoch/reading-intent guards cancel
stale recovery. Removed competing second-frame callback; reacquisition
only starts if the initial measurement failed, preventing double correction
in 2x layouts. Five real ChatScreen delayed-session scenarios now pass,
including all three prior failures with unchanged 2px position tolerance.
Targeted analysis passes. Log /tmp/page-reacquire-final.log. This is a
bounded recovery path, not yet proof of seamless intermediate frames,
ten full page screen transactions, media resizing or actual transport.
Source is not yet release-built; port 9000 still serves prior bot-layout
release. Full P1 and final-build gates remain open.

P1 failure narrowed: isolated Classic reproduction now also proves exact
older-0..49 prepend order, u0 at index 50, and no newer-window trimming
before the missing-visible-question failure. Temporary instrumentation
(removed after capture) observed live pixels=80, estimated max extent
20315.45 versus 11076.23 before merge, measured anchor=null, and fallback
target=9319.22. Thus estimated extent compensation is used when the
original render anchor is unavailable; the second-frame lookup does not
recover this question. Evidence: /tmp/page-debug.log and
/tmp/page-order-verified.log. A stable-anchor layout solution remains open;
no production behavior change or successful regression claim here.

P1 page-level reproduction (open failure): ChatScreen's existing five
initial/keyboard/composer scenarios now also trigger actual on-scroll
pagination against a delayed SessionStore override, continue dragging,
capture a visible question and prepend 50 variable-height messages. Final
isolated run: 2 pass (320px/2x Liquid light/dark), 3 fail (normal text
Classic and Liquid light/dark): previously visible question is no longer
mounted after page completion. Log /tmp/chat-page-screen-final.log.
Targeted analysis passes. Failure remains enabled, not skipped or relaxed.
This exposes a restoration/fixture investigation needing completion; it
does not establish the live-network bug's root cause. The override tests
screen orchestration, not the real SessionStore transport path. No release
changes in this checkpoint.

P1 full-page data checkpoint: ProfileApi fixture now optionally returns
complete requested pages with alternating roles and variable text length.
A real SessionStore test starts with 50 records and completes ten delayed
50-record prepends to 550 records, asserting exact request offsets/profile,
single-flight behavior, pre-apply capture timing, ordered unique content,
loading/error state, and no further request at history end. Page five fails
once before retrying the same cursor without mutation or anchor capture.
All 24 session_profile_history tests and targeted analysis pass. This uses
fake transport and deferTrim; it does not verify ChatScreen geometry,
concurrent gestures/streaming, delayed media layout or window trimming.
No production change or release rebuild at this checkpoint.

P3 bot diagnostics integration: removed three nested diagnostic cards in
favor of a single expandable surface with divided service/model/runtime
groups. Gateway facts use the same responsive key/value layout; narrow
widths and large text stack labels above selectable, wrapping values.
Restart remains separated with a minimum 44px standard-density action.
Selectable value PageStorage keys isolate their scroll offsets from the
ExpansionTile expansion boolean (caught by expanded-page regression).
Four real AgentScreen widget cases at 320px, light/dark and 1x/2x text,
plus two bot-row alignment cases pass. This verifies expansion/collapse,
preserved diagnostic fields and no nested cards, not optical acceptance
or live restart execution. Full P3/P5 gates remain open.
Targeted analysis passes. Release Web build completes (105.9s); port 9000
serves the matching main.dart.js SHA-256:
942cd2b2c17e8a0f1789123fae7530e08c965d2559eb22a91652706a19856d31.

P1 delayed store transactions: controlled API gates now verify in-flight
single-flight loading, no beforeApply capture on failure, unchanged retry
offset, capture immediately before successful prepend, and stale response
rejection after newChat. All 23 session_profile_history tests pass. These
exercise the real SessionStore with a fake transport, not ChatScreen
geometry, ten full pages, real network timing or concurrent image layout.
No production source changes or new build in this checkpoint.

P1 return-to-latest checkpoint: reading revision invalidates pending anchor
restores after explicit navigation. The actual floating button also updates
the revision and guards its animation callback by session epoch. Pagination
completion follows the tail only if the user's latest intent still follows
it. Lifecycle/composer/long-chat checks: 42 pass; final button wiring rerun:
8 pass, targeted analysis clean. Real delayed-page integration remains open.

P1 source checkpoint: coordinator now models initial/following/reading/
fetchingOlder/restoringOlder phases. Pagination ignores incidental pinning;
completion stays in reading. Old-session finalizers cannot clear the next
session's pagination flag. Two state tests plus composer/long-chat tests
pass 41 cases; targeted analysis passes. This does not close real ten-page
transaction, delayed media, trim or explicit-return cancellation gates.
Source changes at this checkpoint are not yet Web-built.

Baseline 2026-09-10: full tests finish in 1:41, 1,654 passed / 2 failed.
Only failures: Liquid preview dark 12.59% (20,628px), light 2.37%
(3,875px); no baselines replaced. Log: /tmp/hermes-p0-regression.log.
Full flutter analyze --no-pub passes. Local and served release script match:
24b93031f3e8269f9a55587b1064d35b874a9a9178680df0f8be8fabc062ed20.
flutter devices reports Linux only; iPhone measurement remains unavailable.

Preserve existing worktree edits and user preferences. No implicit commit or
push. Do not mark the overall objective complete until every mandatory gate
has authoritative evidence. Missing device/visual evidence does not prevent
independent implementation work but must remain explicitly open.
