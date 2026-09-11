# Liquid material platform contract

This project implements a Flutter visual style inspired by Liquid Glass. It
does not claim exact iOS 26.6.0 rendering or use an unverified native SDK API.
The authoritative unfinished delivery scope is liquid-delivery-plan.md.

## Rendering and accessibility

| Capability | Flutter Web | iOS application |
| --- | --- | --- |
| Material | Bounded backdrop blur, tint, continuous corners and painted highlights | Same Flutter material; not a native glass view |
| Refraction | Not implemented; no promised shader fallback | Not implemented |
| Interaction lighting | Pointer/touch-local simulated highlight | Pointer/touch-local simulated highlight, not device tilt |
| Reduce transparency | Application preference and high-contrast fallback | Application preference OR UIAccessibility system setting through hermes.accessibility |
| Reduce motion | MediaQuery animation/accessibility signals; actual browser propagation requires testing | MediaQuery signals; native runtime transition requires device testing |
| Text and code | Opaque reading plane | Opaque reading plane |

Do not assume Safari exposes every iOS accessibility setting to Flutter Web.
Keep the in-app transparency preference available. Neither desktop Chromium
tests nor a native bridge mock proves Safari behavior or VoiceOver usability.

## Material calibration procedure

Current candidate recipes (not visually approved): navigation .80/.72
top/bottom tint with sigma 12; control .82/.72 with sigma 16; overlay
.90/.84 with sigma 20. Dark lower tint has a .78 minimum for secondary
text contrast; dark interaction wash is .03. These reflect a product
hierarchy, not verified Apple optical parameters. Interior pixel-grid
contrast checks over black/white and center press pass, but cannot decide
whether the result has appropriate whole-page visual weight or real-device
performance. Legacy role-less surfaces retain their recipe except for
the shared dark readability floor and interaction light correction.

1. Use the same populated scene, viewport, font, scroll position, renderer and
   theme before/after. Include a glass header, content passing underneath,
   composer/action group and an open menu. Capture idle and pressed states.
2. Calibrate navigation first for backdrop continuity, controls for legibility
   and affordance, then overlays for foreground priority. Each role has its
   own candidate recipe entry; visual approval remains outstanding.
3. Compare both quiet and visually busy backgrounds in light/dark and all four
   palettes. Measure text contrast on the composited result, including disabled
   actions and badges. Do not lower opacity until contrast is rechecked.
4. Check clipping, nested surfaces and transparent fallback independently.
   One material plane owns blur/tint/highlight; nested children must not
   accumulate additional filters. Content remains opaque in every mode.
5. Approve screenshots only after reliable visual inspection. Record exact
   filenames and findings. A golden mismatch must be explained before updating
   its baseline; unchanged tolerance is not itself proof of correctness.

## Device acceptance record

Current environment recheck: flutter devices reports Linux desktop only;
xcodebuild, xcrun and idevice_id are absent from PATH. No iPhone/Safari
device measurements can be inferred from this environment.

Render JSON now explicitly exports frame_samples_available and
frame_sample_status (unavailable_no_engine_samples when empty), plus
interval_slow_frame_ratio (null with no frames since reset). Existing numeric
percentile fields are preserved for compatibility: their zero values must
not be treated as timings when frame_samples_available is false.

Use Reset in the Client performance dialog to clear frame samples and start
interval_frames/interval_slow_frames counters; lifetime counters and network
metrics are preserved. The dialog closes so a scenario can be exercised,
then reopened for export. Route transitions and reopening the diagnostics
also produce frames: this manual interval is not an automatically isolated
benchmark. Repeated resets are safe and do not remove user data.

The diagnostic render snapshot includes build_p50_ms/raster_p50_ms,
existing p95/p99 and frame_sample_count. Percentiles use the most recent
600 engine timing samples. slow_frame_ratio_lifetime uses slow_frames/frames
since process startup, not the rolling sample count. A slow frame means UI
OR raster exceeded its display-rate budget; it is not a measured count of
missed presentation deadlines. For scenario-specific results, capture
before/after counters and report the delta ratio; do not subtract
percentiles. If a scenario exceeds 600 frames, the percentile is its tail
window only. If no timing samples arrive, report unavailable, not zero-cost
rendering. Engine timings do not replace Safari compositor/device profiling.

For each Web/iOS target record device, OS/browser, renderer, commit/worktree
identity, release script hash, viewport, text scale and populated data size.
Measure p50/p95 frame duration and frames exceeding 16.7ms (60Hz target) during
history pagination, streaming, keyboard transitions and overlay opening.
Report UI/raster timings separately where available; do not label DOM RAF
cadence as Flutter raster time. Test a second refresh-rate target separately.

Verify system accessibility changes while foregrounded and after resuming,
keyboard focus restoration after menus, screen-reader order, action labels,
and touch targets. Record actual device results rather than checking these
off using widget semantics trees. The current Linux environment has not
provided an iPhone build/device acceptance result.

## Delivery policy

Classic remains the default for fresh preferences. Liquid selection and
existing palette/accessibility choices survive upgrade. A successful Web
build and matching HTTP hash prove deployment identity only, not visual or
device acceptance. Optional native/shader experiments require their own
compatibility, fallback and frame-budget evidence before integration.
