# Liquid interaction reproduction and evidence catalog

This catalog separates verified fixture behavior from manual/device gates.
Do not interpret a regression fixture as proof that every original symptom
can still be reproduced or that every related case has been fixed.

## History pagination and return-to-bottom

Setup: real ChatScreen + SessionStore, Liquid dark, 390×844, 550 variable-height
API messages. Initial page loads 50; delay each of ten earlier responses.

1. Scroll within 160 logical pixels of the history start.
2. Continue dragging while loading. Verify visible loading feedback.
3. Release a page while reading; compare the same row on every frame.
4. On page five fail once, then tap the inline retry at the history start.
5. On page seven keep moving the pointer during merge and inject 30 scoped
   streaming deltas; verify reading follows gesture travel rather than tail.

Current automated evidence: `test/chat_initial_scroll_settle_test.dart`, test
name prefix `real SessionStore`; VM and Chromium previously pass. It asserts
offset sequence, unique rows, no bottom return, 2px anchor tolerance, retry
single-flight and complete streamed text. Transport remains controlled.

Bug actually reproduced: failure state allowed near-top notifications to
repeat the same API request 12 times. Current ChatScreen blocks automatic
pagination while historyError is present and preserves explicit retry.

Not a bug: the earlier 4.7px fixed-anchor mismatch occurred during remaining
scroll inertia. A stationary assertion now waits for isScrollingNotifier=false;
the moving-merge assertion separately accounts for gesture displacement.

Still required: live gateway/routed session races, real-device gestures,
large-window trimming combined with media/tool changes, and short-history
header visibility through automatic following and later growth.

## Overscroll blank upper half

Manual reproduction: open Tasks and More in both styles; pull downward at
the first item, release, switch tabs and repeat while opening/closing keyboard
where applicable. On Tasks also test vertical column refresh versus horizontal
board navigation. Record full-screen video, OS, renderer and viewport.

Evidence: `test/page_overscroll_test.dart` checks shared large-title scaffold
under Android theme with no stretching/glowing indicator, one refresh and
visible content after pull. `test/kanban_accessibility_test.dart` exercises
actual task vertical refresh without horizontal refresh. The scaffold fixture
is not actual MoreScreen, and neither proves Safari rubber-band behavior.

## Asynchronous content changes

Image fixture: `test/chat/inline_image_layout_test.dart`, prefix `delayed image`.
Mount real image builder in AnchoredHistoryList, keep decode pending 300ms,
then supply a 40×300 image or a failure. Check following row each 16ms.
Existing reserved geometry keeps it within 0.1px in VM/Chromium.

This covers unknown-dimension fixed previews only. It does not prove general
height compensation. Pending reproductions must include a visible tool group
expanding/collapsing, dimensions added to an already-mounted image, content
above the visible anchor resizing, and a window trim during those changes.
Record the identity and viewport-relative Y of the reading row, not merely
scrollbar percentage or final scroll offset.

Downstream-hide experiment: targeting turn 24 in the existing long fixture
produced a 38px difference at 390px/1x but was bottom-constrained, not a
valid isolated history-anchor assertion. Moving to turn 22 appeared stable;
an added actual-height guard then showed the prior tool group was unmounted.
The experiment was removed rather than counted as compensation evidence.
Next fixture must keep both the resized tool row and downstream reading row
mounted, assert non-bottom position and actual changed height before claiming
success. Logs /tmp/chat-downstream-row.log, /tmp/chat-downstream-final.log.

Real ChatScreen tool toggle: long-history Liquid variants now toggle an
actual ToolGroupCard at 390px/1x and 320px/2x in light/dark. VM/Chromium
verify changed height, stable group top within 2px, restored height on
second toggle and no return to bottom. This does not establish stability
of a downstream reading row or combined media/trim changes. The expansion
exposed and fixed tool-row status overflow; older screenshots are stale.

Coverage clarification: anchored_history_list_test.dart separately exercises
synthetic cached-row height changes above the reader, reverse-history
reading/top/dragging, and inertial comparison against an unchanged list.
These are layout-level height-compensation tests, not real tool expansion
or image metadata updates in ChatScreen. Their presence narrows the next
work to real-content integration and combined trimming/resize scenarios;
do not repeat the synthetic checks as if no compensation evidence existed.

## Re-run fixture gates

Mounted real-tool/downstream fixture: tool_history_resize_test.dart now
mounts ToolGroupCard inside AnchoredHistoryList at 320px, light/dark and
1x/2x. It expands the actual card, positions the next text row at y=8,
asserts the tool remains mounted above it and the reader is not at either
boundary, then hides through ToolDismissStore. Six frames assert actual
height loss >20px and reader stability within 2px. Restore is combined with
trimming the newer tail from 35 to 25 rows; six more frames assert actual
height gain, retained mounted tool and reader stability away from bottom.
Four new plus eleven existing anchor VM cases pass
(/tmp/tool-history-final.log); targeted analyze/diff check pass.
This is actual tool/list integration, not full ChatScreen or a gateway race.
Initial positioning with the tool still the leading visible content moved
the downstream row by 188px at 1x when hiding; that is a different anchor
policy case, not evidence of failure to preserve the top reading row.
Chromium run remains live at this checkpoint (session 35464, process 731427;
/tmp/tool-history-browser.log), still loading, so no browser pass is claimed.

```sh
flutter test --no-pub test/chat_initial_scroll_settle_test.dart test/session_profile_history_test.dart test/page_overscroll_test.dart test/kanban_accessibility_test.dart test/chat/inline_image_layout_test.dart test/transcript_viewport_anchor_test.dart
```

For browser evidence repeat relevant cases with `--platform chrome` and a
valid `CHROME_EXECUTABLE`. These runs do not provide release frame timings.

## Home-to-chat recovery regression

`flutter test --no-pub test/app_shell_accessibility_test.dart --plain-name 'Liquid home session entry'`
exercises actual AppShell/Home entry at 390 and 1280px, 2x text. Light cases
hold resume pending and tap the row again: exactly one resume request is made
and no ChatScreen is pushed early. Dark cases additionally reject that resume,
verify the home route and absent durable session, then tap the visible SnackBar
retry action before completing a second resume. Both routes load transcript
messages through SessionStore, enter ChatScreen, and use the actual back button
to return home. All four cases pass in VM and Chromium
(/tmp/shell-entry-retry.log, /tmp/shell-entry-retry-browser.log); browser exits
0 without intervention. Combined AppShell/chat regression passes 100 cases
(/tmp/shell-entry-retry-regression.log); targeted analyze and diff checks pass.

The API/gateway are controlled, fail-fast fixtures; this is application-route
integration, not a live backend or native-device result. The entry row is
scrolled into the unobscured viewport before tapping. Initial XL coverage
exposed and fixed a missing back affordance on pushed desktop chat routes.
