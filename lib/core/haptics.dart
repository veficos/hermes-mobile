/// HermesHaptics: semantic haptic feedback, desktop's `triggerHaptic` intent
/// vocabulary mapped onto Flutter's native `HapticFeedback` primitives.
///
/// Desktop drives a trackpad actuator with custom per-intent waveforms
/// (`src/lib/haptics.ts`); mobile hardware only exposes a handful of coarse
/// patterns, so intents collapse onto the closest of those rather than
/// reproducing the waveforms. `enabled` is a plain static flag rather than a
/// ChangeNotifier lookup so call sites (many of them free functions with no
/// BuildContext, e.g. [showHermesErrorSnackBar]) can fire-and-forget without
/// threading Provider through them — [AppearanceStore] owns persistence and
/// keeps this in sync.
library;

import 'package:flutter/services.dart';

enum HermesHapticIntent {
  /// A destructive/undo-adjacent action (cancel a request, discard a draft).
  cancel,

  /// A lightweight tap — row selection, tab switch, session switch.
  selection,

  /// Sending a message / confirming a form.
  submit,

  /// An operation completed successfully (turn finished, PR created).
  success,

  /// An operation failed and the user is being told about it.
  error,

  /// Something needs attention but isn't a hard failure (needs approval).
  warning,
}

class HermesHaptics {
  HermesHaptics._();

  static bool enabled = true;

  static void fire(HermesHapticIntent intent) {
    if (!enabled) return;
    switch (intent) {
      case HermesHapticIntent.selection:
        HapticFeedback.selectionClick();
      case HermesHapticIntent.submit:
        HapticFeedback.lightImpact();
      case HermesHapticIntent.success:
        HapticFeedback.mediumImpact();
      case HermesHapticIntent.warning:
      case HermesHapticIntent.cancel:
        HapticFeedback.mediumImpact();
      case HermesHapticIntent.error:
        HapticFeedback.heavyImpact();
    }
  }
}
