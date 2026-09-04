// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonCopyFailed => 'Could not copy to the clipboard';

  @override
  String get commonClipboardReadFailed => 'Could not read the clipboard';

  @override
  String petGenerateReferenceFailed(String error) {
    return 'Could not add the reference image: $error';
  }

  @override
  String petSelectFailed(String error) {
    return 'Could not select pet: $error';
  }

  @override
  String terminalSshNamed(String host) {
    return 'SSH $host';
  }

  @override
  String get deepLinkUnsupported => 'Unsupported Hermes link';

  @override
  String get deepLinkMcpNameInvalid => 'Invalid MCP name format';

  @override
  String get deepLinkMcpConfigMissing => 'MCP link is missing configuration';

  @override
  String get deepLinkMcpConfigTooLarge => 'MCP configuration exceeds 32 KiB';

  @override
  String get deepLinkMcpEncodingInvalid => 'Invalid MCP configuration encoding';

  @override
  String get deepLinkMcpJsonInvalid => 'MCP configuration is not valid JSON';

  @override
  String get deepLinkMcpObjectRequired => 'MCP configuration must be an object';

  @override
  String get deepLinkMcpUrlCommandConflict =>
      'MCP configuration cannot contain both a URL and a command';

  @override
  String get deepLinkMcpHttpOnly => 'MCP URL must use HTTP or HTTPS';

  @override
  String get deepLinkMcpEndpointMissing =>
      'MCP configuration is missing a URL or command';

  @override
  String get terminalConnectionClosed => 'Terminal connection is closed';

  @override
  String terminalRequestFailed(String error) {
    return 'Could not send terminal request: $error';
  }

  @override
  String get terminalGenericError => 'Terminal error';

  @override
  String get botUntitledTask => 'Untitled task';

  @override
  String botMemberPaused(String name) {
    return '$name is paused. Mention this member or send resume to continue.';
  }

  @override
  String get botGroupRoundCapReached =>
      'This round of discussion reached its limit. Send a new message to continue.';

  @override
  String get botGroupMessageCapReached =>
      'This conversation reached its message limit. Send a new message to continue.';

  @override
  String get botRoutineFieldsRequired =>
      'Task name, instruction, and schedule are required';

  @override
  String get botRoutineNulForbidden =>
      'Task name, instruction, and schedule cannot contain NUL';

  @override
  String get pluginLoadActionReadOnly =>
      'Plugin view.load_action must be read-only';

  @override
  String get pluginMethodMissing => 'Plugin action is missing method';

  @override
  String get pluginPathInvalid => 'Plugin action path is invalid';

  @override
  String pluginMethodUnsupported(String method) {
    return 'Plugin REST method is unsupported: $method';
  }

  @override
  String get pluginUrlInvalid => 'Plugin action URL is invalid';

  @override
  String get pluginUrlSchemeUnsupported =>
      'Plugin action URL scheme is unsupported';

  @override
  String get pluginLinkOpenFailed => 'Could not open link';

  @override
  String get pluginNotificationFieldsMissing =>
      'Plugin notification action is missing title or message';

  @override
  String get pluginNotificationUnavailable =>
      'Notifications are unavailable in this host';

  @override
  String pluginActionUnsupported(String kind) {
    return 'Plugin action is unsupported on mobile: $kind';
  }

  @override
  String get kanbanTaskAlreadyRunning => 'Task is already running';

  @override
  String get gatewayUnavailable => 'Hermes backend Gateway is unavailable';

  @override
  String get filesDirectoryMissing => 'Directory does not exist';

  @override
  String get filesFolderFallback =>
      'This platform cannot list local folders; select multiple files instead';

  @override
  String get billingCreditsExhausted => 'Balance or credit limit exhausted';

  @override
  String workspacePaneLimit(int count) {
    return 'Up to $count panes can be open in the workspace';
  }

  @override
  String get projectMissing => 'Project does not exist or was deleted';

  @override
  String updateHttpError(int status) {
    return 'Update service returned HTTP $status';
  }

  @override
  String get chatCompactingThread => 'Summarizing thread';

  @override
  String get chatModelChanged => 'Model changed';

  @override
  String get chatTurnContinued => 'Interrupted turn continued';

  @override
  String get chatPersonalityChanged => 'Personality changed';

  @override
  String get chatDelegationCompleted => 'Background agent work completed';

  @override
  String chatDelegationCountCompleted(int count) {
    return '$count background agent tasks completed';
  }

  @override
  String get chatHermesNotification => 'Hermes notification';

  @override
  String get chatBrowserTask => 'Browser task';

  @override
  String get chatPreviewRestart => 'Preview service restart';

  @override
  String chatPreparingTool(String name) {
    return 'Preparing $name';
  }

  @override
  String get chatMoaAggregating => '◇ Aggregating multi-model results...';

  @override
  String get chatMoaCollaboration => 'Multi-model collaboration';

  @override
  String get chatCurrentGoal => 'Current goal';

  @override
  String get chatCodeReview => 'Code review';

  @override
  String get chatHermesRunFailed => 'Hermes run failed';

  @override
  String get chatPlanItem => 'Plan item';

  @override
  String get chatAssistantReplyFailed => 'Assistant reply failed';

  @override
  String get terminalServerNotConfigured => 'Server is not configured';

  @override
  String terminalLimitReached(int count) {
    return 'Up to $count terminals can be open at once. Close a session first.';
  }

  @override
  String terminalNumbered(int number) {
    return 'Terminal $number';
  }

  @override
  String get terminalSnapshotStart =>
      '-- Read-only output snapshot from the previous session --';

  @override
  String get terminalSnapshotEnd => '-- Snapshot ended; restoring terminal --';

  @override
  String get terminalSshHostRequired => 'SSH host is required';

  @override
  String get terminalRestartingShell => '-- Restarting shell... --';

  @override
  String get terminalOpenedNewShell =>
      '-- Could not restore the original shell; opened a new shell --';

  @override
  String get terminalPtyIdMissing =>
      'The server did not return a PTY session ID';

  @override
  String terminalShellExited(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'other': ' (code $code)',
      'empty': '',
    });
    return '-- Shell exited$_temp0 · Tap Restart to continue --';
  }

  @override
  String get terminalReconnecting =>
      'Terminal connection interrupted. Reconnecting...';

  @override
  String get terminalRestoringShell =>
      '-- Connection interrupted; restoring or reopening shell... --';

  @override
  String get terminalConnectionRestored => '-- Terminal connection restored --';

  @override
  String get terminalConnectionRestoreFailed =>
      '-- Could not restore terminal connection --';

  @override
  String get terminalReconnected =>
      'Terminal reconnected; a new shell may have been opened';

  @override
  String get terminalReconnectFailed =>
      'Could not reconnect the terminal. Create a new terminal manually.';

  @override
  String get sessionChooseHandoffPlatform => 'Choose a handoff platform';

  @override
  String sessionHandoffTargetFailed(String target) {
    return 'Handoff to $target failed';
  }

  @override
  String get sessionHandoffTimeout => 'Handoff timed out. Try again.';

  @override
  String get sessionNoActive => 'No active session';

  @override
  String sessionLoadMoreFailed(String error) {
    return 'Could not load more sessions: $error';
  }

  @override
  String get sessionOfflineTranscript =>
      'Offline mode: showing the cached transcript';

  @override
  String sessionTranscriptRefreshFailed(String error) {
    return 'Could not refresh transcript: $error';
  }

  @override
  String sessionOlderMessagesFailed(String error) {
    return 'Could not load older messages: $error';
  }

  @override
  String sessionListLoadFailed(String error) {
    return 'Could not load sessions: $error';
  }

  @override
  String get sessionProfileSwitching =>
      'The profile is switching. Try again shortly.';

  @override
  String get sessionSubagentReadOnly => 'Subagent sessions are read-only';

  @override
  String get sessionChangedRetry => 'The session changed. Try again shortly.';

  @override
  String sessionConnectionUnknown(String id) {
    return 'The session connection is unknown: $id';
  }

  @override
  String sessionConnectionUnavailable(String id) {
    return 'The session connection is unavailable: $id';
  }

  @override
  String get sessionUnsavedTitle =>
      'The session has not been saved, so a title cannot be generated';

  @override
  String get sessionShareLinkMissing =>
      'The server did not return a share link';

  @override
  String sessionBatchDeletePartial(int deleted, int failed) {
    return 'Deleted $deleted; $failed failed';
  }

  @override
  String get sessionCouldNotCreate => 'Could not create a session';

  @override
  String get sessionUserMessageMissing =>
      'Could not find the corresponding user message';

  @override
  String get sessionRestoreMessageMissing =>
      'Could not find the user message to restore';

  @override
  String get sessionBranchMessageMissing =>
      'Could not find the message to branch from';

  @override
  String get sessionHistoryPositionMissing =>
      'This message has no history position. Refresh the session and try again.';

  @override
  String get sessionRuntimeIdMissing =>
      'Hermes did not return a runtime session ID';

  @override
  String get aboutLicenses => 'Open source licenses';

  @override
  String get aboutLicensesDescription =>
      'View licenses for third-party software used by the app';

  @override
  String get aboutProductDescription => 'The mobile client for Hermes Agent';

  @override
  String get aboutProductInfo => 'Product information';

  @override
  String get aboutTitle => 'About Hermes';

  @override
  String get appTitle => 'Hermes Mobile';

  @override
  String get appearanceHaptics => 'Haptic feedback';

  @override
  String get appearanceHapticsDesc =>
      'Vibrate on send, errors, and completed tasks';

  @override
  String get appearanceHighContrast => 'High contrast';

  @override
  String get appearanceHighContrastDesc => 'Increase text and border contrast';

  @override
  String get appearanceKeepAwake => 'Keep screen awake';

  @override
  String get appearanceKeepAwakeDesc =>
      'Prevent the screen from sleeping while a chat is open';

  @override
  String get appearanceModeDark => 'Dark';

  @override
  String get appearanceModeLight => 'Light';

  @override
  String get appearanceModeSystem => 'System';

  @override
  String get appearanceThemeColor => 'Theme color';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get approvalRequests => 'Approval requests';

  @override
  String get backendConnected => 'Backend connected';

  @override
  String get backendDisconnected => 'Backend disconnected';

  @override
  String get billingAccountBalance => 'Account balance';

  @override
  String get billingAccountTab => 'Account';

  @override
  String get billingAmountUsd => 'Amount (USD)';

  @override
  String get billingAutoReload => 'Auto reload';

  @override
  String get billingAutoReloadDescription =>
      'Add credits when the balance falls below the threshold';

  @override
  String get billingAutoReloadDisabled => 'Auto reload disabled';

  @override
  String get billingAutoReloadEnabled => 'Auto reload enabled';

  @override
  String get billingAutoReloadUpdateFailed => 'Could not update auto reload';

  @override
  String get billingAvailableCredits => 'Available credits';

  @override
  String get billingCancelAtPeriodEnd => 'Cancel subscription at period end';

  @override
  String get billingCancelAtPeriodEndDescription =>
      'Current plan benefits remain available until the end of this period.';

  @override
  String get billingCancelAtPeriodEndQuestion =>
      'Cancel at the end of the period?';

  @override
  String get billingCancelFailed => 'Could not cancel subscription';

  @override
  String get billingChargeCompleted => 'Credit purchase completed';

  @override
  String get billingChargeForbidden =>
      'This account cannot purchase credits from the app';

  @override
  String get billingChargeIncomplete => 'Credit purchase incomplete';

  @override
  String get billingConfirmCancellation => 'Confirm cancellation';

  @override
  String get billingConfirmPurchase => 'Confirm purchase';

  @override
  String get billingConfirmUpgrade => 'Confirm the plan upgrade.';

  @override
  String billingCreditsPerMonth(Object credits) {
    return '$credits credits/month';
  }

  @override
  String get billingCurrent => 'Current';

  @override
  String get billingDowngrade => 'Downgrade';

  @override
  String get billingDowngradePeriodEnd =>
      'The downgrade takes effect at the end of the current period.';

  @override
  String get billingGatewayMissing => 'Not connected to the Hermes gateway';

  @override
  String get billingInvalidReloadValues =>
      'Enter a valid threshold and reload amount';

  @override
  String get billingLoading => 'Loading billing status...';

  @override
  String get billingLoadingPlans => 'Loading plan catalog...';

  @override
  String get billingLoggedIn => 'Signed in';

  @override
  String get billingLoggedOut => 'Signed out';

  @override
  String get billingManageInPortal => 'Manage in Portal';

  @override
  String billingMaximumCharge(Object amount) {
    return 'Maximum \$$amount';
  }

  @override
  String billingMinimumCharge(Object amount) {
    return 'Minimum \$$amount';
  }

  @override
  String get billingMonthlySpendingCap => 'Monthly remote spending cap';

  @override
  String get billingNoActivePlan => 'No active plan';

  @override
  String get billingNoPlans => 'No plan catalog available';

  @override
  String get billingNoUsageData => 'No usage data available';

  @override
  String get billingNoUsageDescription =>
      'The gateway has not returned a Remote Spending usage model.';

  @override
  String get billingNotConnected => 'Not connected to Hermes';

  @override
  String get billingNotProvided => 'Not provided';

  @override
  String get billingNotSet => 'Not set';

  @override
  String get billingOpenPortal => 'Open Portal';

  @override
  String get billingOpenVerification => 'Open verification page';

  @override
  String get billingPaymentIncomplete => 'Payment incomplete';

  @override
  String get billingPaymentMethod => 'Payment method';

  @override
  String get billingPaymentTimeout =>
      'Payment status timed out. Check the result in Portal.';

  @override
  String get billingPending => 'Pending';

  @override
  String billingPendingCancellation(Object date) {
    return 'Cancels on $date';
  }

  @override
  String billingPendingDowngrade(Object date, Object name) {
    return 'Downgrades to $name on $date';
  }

  @override
  String billingPerMonth(Object price) {
    return '$price/month';
  }

  @override
  String get billingPeriodEnd => 'the end of the period';

  @override
  String get billingPlanAlreadyActive => 'This plan is already active.';

  @override
  String billingPlanChangeEffectiveAt(Object date) {
    return 'The plan change takes effect on $date.';
  }

  @override
  String get billingPlanChangeFailed => 'Could not change plan';

  @override
  String get billingPlanChangeForbidden => 'This account cannot change plans';

  @override
  String get billingPlanChangePeriodEnd =>
      'The plan change takes effect at the end of the current period.';

  @override
  String get billingPlanChangeUnavailable =>
      'This change is currently unavailable.';

  @override
  String get billingPlanCredits => 'Plan credits';

  @override
  String get billingPlansTab => 'Plans';

  @override
  String get billingPortalMissing =>
      'The server did not provide a billing Portal URL';

  @override
  String get billingPortalOpenFailed => 'Could not open the billing Portal';

  @override
  String get billingPurchaseCredits => 'Purchase credits';

  @override
  String get billingReloadAboveMaximum =>
      'The reload amount exceeds the server maximum';

  @override
  String get billingReloadBelowMinimum =>
      'The reload amount is below the server minimum';

  @override
  String get billingReloadTo => 'Reload to';

  @override
  String billingRemaining(Object amount) {
    return '$amount remaining';
  }

  @override
  String billingRenews(Object date) {
    return 'Renews $date';
  }

  @override
  String get billingResumeFailed => 'Could not undo the pending change';

  @override
  String get billingSaveAutoReload => 'Save auto reload';

  @override
  String billingSpentThisMonth(Object amount) {
    return 'Spent this month: $amount';
  }

  @override
  String billingSwitchPlan(Object name) {
    return 'Switch to $name?';
  }

  @override
  String get billingTitle => 'Billing';

  @override
  String get billingTopupCredits => 'Purchased credits';

  @override
  String get billingTriggerThreshold => 'Trigger threshold';

  @override
  String get billingUnavailableForAccount => 'Unavailable for this account';

  @override
  String billingUpgradeAmount(Object amount) {
    return 'The upgrade takes effect immediately. Amount due now: \$$amount.';
  }

  @override
  String get billingUpgradeChargeNow =>
      'The upgrade takes effect immediately and incurs a charge.';

  @override
  String get billingUsageTab => 'Usage';

  @override
  String billingUsedOf(Object spent, Object total) {
    return 'Used $spent of $total';
  }

  @override
  String billingVerificationFailed(Object error) {
    return 'Verification failed: $error';
  }

  @override
  String get billingVerificationIncomplete =>
      'Verification is not complete. Try again shortly.';

  @override
  String get billingVerificationInstructions =>
      'Complete verification in your browser to allow remote spending actions from this device.';

  @override
  String get billingVerificationRequired => 'Additional verification required';

  @override
  String get billingVerificationStarting => 'Starting verification...';

  @override
  String get billingVerificationSucceeded =>
      'Verification succeeded. You can continue.';

  @override
  String get billingVerifyAndContinue => 'Verify and continue';

  @override
  String get billingViewSubscriptionInPortal =>
      'View your subscription in Portal.';

  @override
  String get chatAbsoluteServerPath => 'Use an absolute path on the server';

  @override
  String get chatAddImage => 'Add image';

  @override
  String chatAddImageFailed(String error) {
    return 'Could not add image: $error';
  }

  @override
  String chatAddedToQueue(int count) {
    return 'Added to queue ($count pending)';
  }

  @override
  String get chatAllDates => 'All dates';

  @override
  String get chatAllHistoryShown => 'All history is shown';

  @override
  String get chatApprovalManual => 'Manual';

  @override
  String get chatApprovalManualDescription => 'Confirm every step';

  @override
  String get chatApprovalMode => 'Approval mode';

  @override
  String chatApprovalModeFailed(String error) {
    return 'Could not set approval mode: $error';
  }

  @override
  String chatApprovalModeSet(String mode) {
    return 'Approval mode set to $mode';
  }

  @override
  String get chatApprovalOff => 'Off';

  @override
  String get chatApprovalOffDescription => 'Run without confirmation';

  @override
  String get chatApprovalSmart => 'Smart';

  @override
  String get chatApprovalSmartDescription => 'Ask only for risky actions';

  @override
  String get chatApprovalsUsage => 'Usage: /approvals manual|smart|off';

  @override
  String chatArtifactVersions(int count) {
    return 'All versions ($count)';
  }

  @override
  String get chatAssistant => 'Assistant';

  @override
  String get chatAttach => 'Attach';

  @override
  String get chatAttachFiles => 'Attach files';

  @override
  String get chatAttachLink => 'Attach link';

  @override
  String chatAttachmentUploadFailed(String error) {
    return 'Could not upload attachment: $error';
  }

  @override
  String get chatAutoRetried => 'Automatically retried';

  @override
  String get chatBackToNewerMessages => 'Back to newer messages';

  @override
  String get chatBackToWorkspace => 'Back to workspace';

  @override
  String get chatBackgroundAgentRunning =>
      'Background agent running · this turn will continue when it finishes';

  @override
  String chatBackgroundAgentsRunning(int count) {
    return '$count background agents running · the turn will continue when they finish';
  }

  @override
  String chatBackgroundCount(int count) {
    return '$count background tasks';
  }

  @override
  String get chatBackgroundPrompt => 'Background task prompt';

  @override
  String chatBackgroundSubmitFailed(String error) {
    return 'Could not submit background task: $error';
  }

  @override
  String get chatBackgroundSubmitted => 'Background task submitted';

  @override
  String chatBackgroundSubmittedWithId(String id) {
    return 'Background task submitted ($id)';
  }

  @override
  String chatBackgroundTaskCompleted(String label) {
    return '$label completed';
  }

  @override
  String chatBackgroundTaskFailed(String label) {
    return '$label failed';
  }

  @override
  String get chatBasicToolsets => 'Basic toolsets';

  @override
  String get chatBranch => 'Branch';

  @override
  String chatBranchChanges(String branch, int changedFiles) {
    return '$branch · $changedFiles changed files';
  }

  @override
  String get chatBranchCreated => 'Branch session created';

  @override
  String chatBranchCreatedWithId(String id) {
    return 'Branch session created ($id)';
  }

  @override
  String chatBranchFailed(String error) {
    return 'Could not create branch: $error';
  }

  @override
  String get chatBranchInNewSession => 'Branch in new session';

  @override
  String get chatBranchedHere => 'Branched from here';

  @override
  String chatBranchedWithId(String id) {
    return 'Branched from here ($id)';
  }

  @override
  String chatBranchesLoadFailed(String error) {
    return 'Could not load branches: $error';
  }

  @override
  String get chatBrowseArtifactsDescription =>
      'Browse artifacts generated in this session';

  @override
  String get chatBrowseFiles => 'Browse file manager';

  @override
  String get chatBrowseFilesDescription =>
      'Locate and select a directory in file manager';

  @override
  String get chatCancelKeyboardHint => 'Cancel (Esc)';

  @override
  String get chatCatalogEmpty => 'No servers available';

  @override
  String get chatChangeWorkspace => 'Change workspace';

  @override
  String get chatChangeWorkspaceDescription =>
      'The AI will read and modify files in the selected server directory';

  @override
  String get chatClosePreview => 'Close preview';

  @override
  String get chatCollapseStatusDetails => 'Collapse details';

  @override
  String get chatCollapseSubsessions => 'collapse subsessions';

  @override
  String get chatCommandCompletedNoOutput => 'Command completed with no output';

  @override
  String get chatCommandExecutionFailed => 'Command execution failed';

  @override
  String chatCommandFailed(String error) {
    return 'Command failed: $error';
  }

  @override
  String get chatCommandMessageQueued => 'Message queued';

  @override
  String get chatCommandNoFillContent => 'Nothing to fill in';

  @override
  String get chatCommandNoSendableContent => 'Nothing to send';

  @override
  String get chatCommandQueued => 'Command queued';

  @override
  String get chatCommandSearchHint => 'Try a different search';

  @override
  String get chatCommandSearchFailed =>
      'Couldn\'t load commands — check your connection';

  @override
  String get chatCommandStarting => 'Command starting';

  @override
  String get chatCompositeToolsets => 'Composite toolsets';

  @override
  String get chatCompressContext => 'Compress';

  @override
  String chatCompressionFailed(String error) {
    return 'Could not compress context: $error';
  }

  @override
  String get chatCompressionRequested => 'Context compression requested';

  @override
  String get chatConfigureProvider => 'Configure provider';

  @override
  String get chatConnecting => 'Connecting';

  @override
  String get chatConnectionFailed => 'Connection failed';

  @override
  String get chatContentFilled => 'Content filled in';

  @override
  String get chatContextUsage => 'Context usage';

  @override
  String chatContextUsagePercent(int percent) {
    return 'Context usage $percent%';
  }

  @override
  String get chatCopyAsMarkdown => 'Copy as Markdown';

  @override
  String get chatCopyDiagnostics => 'Copy diagnostics';

  @override
  String get chatCopySessionId => 'Copy session ID';

  @override
  String get chatCopySessionLink => 'Copy session link';

  @override
  String get chatCopyText => 'Copy text';

  @override
  String get chatCreateScheduledTask => 'Create scheduled task';

  @override
  String chatCronSuggestion(String phrase) {
    return 'Detected a schedule: $phrase';
  }

  @override
  String get chatCurrentSessionArtifacts => 'Artifacts in this session';

  @override
  String get chatCurrentSessionToolsets => 'current session toolsets';

  @override
  String get chatCurrentlyActive => 'Currently active';

  @override
  String chatDeletePromptFailed(String error) {
    return 'Could not delete prompt: $error';
  }

  @override
  String get chatDeliveryUncertain => 'Delivery uncertain';

  @override
  String get chatDiagnosticsCopied => 'Diagnostics copied';

  @override
  String chatDiagnosticsError(String error) {
    return 'Error: $error';
  }

  @override
  String chatDiagnosticsModel(String provider, String model) {
    return 'Model: $provider / $model';
  }

  @override
  String chatDiagnosticsTime(String time) {
    return 'Time: $time';
  }

  @override
  String get chatDiagnosticsTitle => 'Diagnostics';

  @override
  String chatEditFailed(String error) {
    return 'Could not edit: $error';
  }

  @override
  String get chatEditMessageHint => 'Edit message...';

  @override
  String get chatEditMessageKeyboardHint =>
      'Edit message... (Enter to send, Shift+Enter for a new line)';

  @override
  String get chatEmptyDescription =>
      'Streaming replies, tool calls, approvals, and clarifications, with full desktop parity.';

  @override
  String get chatEmptyTitle => 'Start a conversation with Hermes';

  @override
  String get chatEnterOtherDirectory => 'Enter another directory';

  @override
  String get chatEnterWorkspacePath => 'Enter workspace path';

  @override
  String get chatErrorAuth => 'Authentication error';

  @override
  String get chatErrorBilling => 'Billing error';

  @override
  String get chatErrorNetwork => 'Network error';

  @override
  String get chatErrorProvider => 'Provider error';

  @override
  String get chatErrorRateLimit => 'Rate limited';

  @override
  String get chatErrorReply => 'Reply error';

  @override
  String get chatExecuting => 'Executing…';

  @override
  String chatExecutionFailed(String error) {
    return 'Execution failed: $error';
  }

  @override
  String get chatExpandStatusDetails => 'Expand details';

  @override
  String get chatExpandSubsessions => 'expand subsessions';

  @override
  String chatFileTooLarge(int maxMb, String name) {
    return '$name exceeds the $maxMb MB limit';
  }

  @override
  String get chatFillRetry => 'Retry';

  @override
  String get chatFindHint => 'Find in this conversation';

  @override
  String get chatFindInConversation => 'Find in conversation';

  @override
  String chatFolderFilesAttached(int attached, int skipped) {
    return 'Attached $attached files ($skipped skipped)';
  }

  @override
  String get chatFolderPickerUnavailable =>
      'Folder selection is not available on this platform';

  @override
  String chatForwardedToCommand(String target) {
    return 'Forwarded to $target';
  }

  @override
  String get chatGlobalCliToolsets => 'global cli toolsets';

  @override
  String get chatGlobalToolsetsDescription =>
      'Global CLI toolset switches; changes apply immediately';

  @override
  String get chatGoals => 'Goals';

  @override
  String chatHandingOffTo(String name) {
    return 'Handing off to $name';
  }

  @override
  String get chatHandoff => 'Handoff';

  @override
  String get chatHandoffCompleted => 'Completed';

  @override
  String chatHandoffCompletedTo(String name) {
    return 'Session handed off to $name';
  }

  @override
  String chatHandoffFailed(String error) {
    return 'Handoff failed: $error';
  }

  @override
  String get chatHandoffFailedStatus => 'Failed';

  @override
  String get chatHandoffGatewayRunning => 'Running';

  @override
  String chatHandoffPlatformsFailed(String error) {
    return 'Could not load handoff platforms: $error';
  }

  @override
  String get chatHandoffTimeout => 'Handoff timed out';

  @override
  String get chatHandoffToPlatform => 'Hand off to platform';

  @override
  String get chatHandoffWaiting => 'Waiting';

  @override
  String get chatHideStatus => 'Hide';

  @override
  String get chatHistoryLocator => 'history locator';

  @override
  String chatHomeChannel(String name) {
    return 'Home channel: $name';
  }

  @override
  String get chatHomeChannelNotSet => 'Home channel not set';

  @override
  String get chatHtmlPreview => 'HTML preview';

  @override
  String get chatInflightRecovered => 'Recovered an in-progress reply';

  @override
  String get chatInsufficientQuota => 'Insufficient quota';

  @override
  String get chatInvalidCommandAlias => 'Invalid command alias';

  @override
  String get chatJumpToTopic => 'Jump to topic';

  @override
  String get chatLast24Hours => 'Last 24 hours';

  @override
  String get chatLast7Days => 'Last 7 days';

  @override
  String get chatLastTurnRetried => 'Last turn retried';

  @override
  String get chatLastTurnUndone => 'Last turn undone';

  @override
  String get chatLoadFailed => 'Load failed';

  @override
  String get chatLoadOlderMessagesHint => 'Scroll up to load older messages';

  @override
  String get chatLoadingCommands => 'Loading commands…';

  @override
  String get chatLocalCommands => 'Local commands';

  @override
  String get chatLocateTopic => 'Locate topic';

  @override
  String get chatLongPressCodingStatus =>
      'Long-press the coding status to switch branch or start a worktree';

  @override
  String get chatMarkMessage => 'Mark message';

  @override
  String get chatMarkdownCopied => 'Copied as Markdown';

  @override
  String get chatMarkedOnly => 'Marked only';

  @override
  String chatMessageCount(int count) {
    return '$count messages';
  }

  @override
  String get chatModel => 'Model';

  @override
  String get chatModelSwitchDeferred =>
      'Model switch will take effect next turn';

  @override
  String chatModelSwitchFailed(String error) {
    return 'Could not switch model: $error';
  }

  @override
  String chatModelsLoadFailed(String error) {
    return 'Could not load models: $error';
  }

  @override
  String chatMonthDay(int month, int day) {
    return '$month/$day';
  }

  @override
  String get chatMyMessages => 'My messages';

  @override
  String get chatNewSessionOpened => 'New session opened';

  @override
  String get chatNewWorktreeDescription => 'Create a new git worktree';

  @override
  String get chatNoActiveTurnQueued => 'No active turn — queued instead';

  @override
  String get chatNoConfigurableToolsets =>
      'The backend has no configurable toolsets';

  @override
  String get chatNoContextData => 'No context data';

  @override
  String get chatNoHandoffPlatforms => 'No handoff platforms';

  @override
  String get chatNoHandoffPlatformsDescription =>
      'No platforms are connected for handoff yet';

  @override
  String get chatNoMatchingCommands => 'No matching commands';

  @override
  String get chatNoMatchingMessages => 'No matching messages';

  @override
  String get chatNoProfiles => 'The backend has no profiles to switch to';

  @override
  String get chatNoQueuedMessages => 'No queued messages';

  @override
  String get chatNoRetryMessage => 'No message to retry';

  @override
  String get chatNoSavedPrompts => 'No saved prompts yet';

  @override
  String get chatNoSessions => 'No sessions';

  @override
  String get chatNoText => 'No text content';

  @override
  String get chatNoUploadableFolderFiles =>
      'No uploadable files in this folder';

  @override
  String get chatNotConfigured => 'Not configured';

  @override
  String get chatNotConnected => 'Not connected';

  @override
  String get chatOlderMessagesLoadFailed =>
      'Could not load older messages; tap to retry';

  @override
  String chatPendingRequests(String kind, int count) {
    return '$kind (+$count pending)';
  }

  @override
  String chatPlanProgress(int completed, int total) {
    return '$completed/$total completed';
  }

  @override
  String chatPreviewCount(int count) {
    return '$count previews';
  }

  @override
  String chatProfileSwitchFailed(String error) {
    return 'Could not switch profile: $error';
  }

  @override
  String chatProfileSwitched(String profile) {
    return 'Switched to “$profile”';
  }

  @override
  String chatProfilesLoadFailed(String error) {
    return 'Could not load profiles: $error';
  }

  @override
  String get chatPromptSaved => 'Prompt saved';

  @override
  String get chatProvider => 'Provider';

  @override
  String get chatQueue => 'Queue';

  @override
  String chatQueueFailed(String error) {
    return 'Could not queue: $error';
  }

  @override
  String get chatQueuePaused => 'Paused';

  @override
  String chatQueueSummary(String label, int count, String expandLabel) {
    return '$label · $count · $expandLabel';
  }

  @override
  String get chatQueueUsage => 'Enter something to queue';

  @override
  String get chatQueued => 'Queued';

  @override
  String get chatQueuedMessageUpdated => 'Queued message updated';

  @override
  String chatQueuedMinutesAgo(int minutes) {
    return 'Queued $minutes min ago';
  }

  @override
  String chatQueuedSecondsAgo(int seconds) {
    return 'Queued $seconds sec ago';
  }

  @override
  String get chatReasoningEffort => 'reasoning effort';

  @override
  String get chatReasoningEffortDescription =>
      'Update the backend reasoning effort setting';

  @override
  String chatReasoningEffortSet(String value) {
    return 'Reasoning effort set to $value';
  }

  @override
  String chatReasoningEffortSetFailed(String error) {
    return 'Could not set reasoning effort: $error';
  }

  @override
  String get chatReconnecting => 'Reconnecting';

  @override
  String get chatRegenerate => 'Regenerate';

  @override
  String chatRegenerateFailed(String error) {
    return 'Could not regenerate: $error';
  }

  @override
  String get chatRegenerateTitle => 'Regenerate title';

  @override
  String chatRegenerateTitleFailed(String error) {
    return 'Could not regenerate title: $error';
  }

  @override
  String get chatRename => 'Rename';

  @override
  String get chatRenameSession => 'Rename session';

  @override
  String get chatRequestApproval => 'Approval';

  @override
  String get chatRequestMcpConfig => 'MCP setup';

  @override
  String get chatRequestPassword => 'Password';

  @override
  String get chatRequestQuestion => 'Question';

  @override
  String get chatRequestSecret => 'Secret';

  @override
  String get chatRequestTerminalInput => 'Terminal input';

  @override
  String get chatRestoreAndRerun => 'Restore and rerun';

  @override
  String chatRestoreFailed(String error) {
    return 'Could not restore: $error';
  }

  @override
  String get chatRestoreToMessage => 'Restore to this message';

  @override
  String get chatRestoreToMessageTitle => 'Restore to this message?';

  @override
  String get chatRestoreVersionTitle => 'Restore this version?';

  @override
  String chatRetryFailed(String error) {
    return 'Retry failed: $error';
  }

  @override
  String get chatRunInBackground => 'Run in background';

  @override
  String get chatSaveCurrentInput => 'Save current input';

  @override
  String chatSavePromptFailed(String error) {
    return 'Could not save prompt: $error';
  }

  @override
  String get chatSavedPrompts => 'Saved prompts';

  @override
  String chatSavedPromptsLoadFailed(String error) {
    return 'Could not load saved prompts: $error';
  }

  @override
  String get chatScrollToBottom => 'Scroll to bottom';

  @override
  String get chatSearchLoadedHistory => 'Search loaded history';

  @override
  String chatSelectFilesFailed(String error) {
    return 'Could not select files: $error';
  }

  @override
  String get chatSelectFolder => 'Select folder';

  @override
  String chatSelectFolderFailed(String error) {
    return 'Could not select folder: $error';
  }

  @override
  String get chatSelectProfile => 'select profile';

  @override
  String get chatSelectProfileDescription =>
      'Choose the profile used for home data and future launches';

  @override
  String get chatSendDiagnostics => 'Send diagnostics';

  @override
  String get chatSendEdit => 'send edit';

  @override
  String get chatSendEditAndRerun => 'Send edit and rerun';

  @override
  String get chatSendEditTitle => 'Send edited message?';

  @override
  String chatSendFailed(String error) {
    return 'Could not send: $error';
  }

  @override
  String get chatSendNow => 'Send now';

  @override
  String get chatSendQueue => 'Send queue';

  @override
  String chatSendQueueCount(int count) {
    return 'Send queue ($count)';
  }

  @override
  String get chatServerCatalog => 'Server catalog';

  @override
  String get chatServerDirectory => 'server directory';

  @override
  String get chatServerDirectoryHelp =>
      'The directory must exist and be accessible to the server account';

  @override
  String get chatServerNotConnected => 'Server not connected';

  @override
  String get chatSessionCleared => 'Session cleared';

  @override
  String get chatSessionIdCopied => 'Session ID copied';

  @override
  String get chatSessionInfo => 'Session info';

  @override
  String get chatSessionMenu => 'Session menu';

  @override
  String get chatSessionShareLinkCopied => 'Session share link copied';

  @override
  String get chatSessionToolsetsDescription =>
      'Session toolsets (only affect this session)';

  @override
  String get chatSessions => 'Sessions';

  @override
  String get chatSetAsNext => 'Queue next';

  @override
  String chatSetTitleFailed(String error) {
    return 'Could not set title: $error';
  }

  @override
  String chatShareLinkFailed(String error) {
    return 'Could not get share link: $error';
  }

  @override
  String get chatShareUrlMissing => 'No share link was returned';

  @override
  String get chatSkillsCenter => 'Skills center';

  @override
  String get chatSlashCommands => 'Slash commands';

  @override
  String get chatStartSessionBeforeWorkspace =>
      'Start a session before changing workspace';

  @override
  String get chatStarterDebugIssue => 'Help me debug';

  @override
  String get chatStarterDebugIssuePrompt =>
      'I ran into a problem. Help me outline a debugging approach first.';

  @override
  String get chatStarterExplainProject => 'Explain this project';

  @override
  String get chatStarterExplainProjectPrompt =>
      'Give me a quick overview of this project\'s structure, core features, and how to run it.';

  @override
  String get chatStarterReviewChanges => 'Review current changes';

  @override
  String get chatStarterReviewChangesPrompt =>
      'Review the current workspace changes, identify potential issues, and suggest improvements.';

  @override
  String get chatSteerCurrentTurn => 'Steer current turn';

  @override
  String get chatSteerHint => 'Steering message';

  @override
  String get chatSteerInjected => 'Steering message injected';

  @override
  String get chatSteerMessage => 'Steer';

  @override
  String chatSteerNowFailed(String error) {
    return 'Could not steer now: $error';
  }

  @override
  String get chatSteerQueued => 'Steering message queued';

  @override
  String get chatSteerUsage => 'Enter something to steer with';

  @override
  String get chatStopProcess => 'Stop';

  @override
  String chatStopProcessFailed(String error) {
    return 'Could not stop process: $error';
  }

  @override
  String chatSubagentCount(int count) {
    return '$count subagents';
  }

  @override
  String get chatTextSnippet => 'Text snippet';

  @override
  String get chatTextSnippetHint => 'Paste or type text';

  @override
  String get chatTitle => 'Hermes Chat';

  @override
  String chatTitleSet(String title) {
    return 'Title set to “$title”';
  }

  @override
  String get chatTitleUnchanged => 'Title unchanged';

  @override
  String chatTitleUpdated(String title) {
    return 'Title updated to “$title”';
  }

  @override
  String get chatToday => 'today';

  @override
  String get chatToolConfiguration => 'tool configuration';

  @override
  String chatToolCount(int count) {
    return '$count tools';
  }

  @override
  String get chatToolStatusMessage => 'Tool status message';

  @override
  String chatToolsetCounts(String sessionCount, String globalCount) {
    return 'Session: $sessionCount · Global: $globalCount';
  }

  @override
  String chatToolsetToggleFailed(String name, String error) {
    return 'Could not toggle $name: $error';
  }

  @override
  String chatToolsetsEnabled(String globalCount) {
    return '$globalCount toolsets enabled';
  }

  @override
  String get chatToolsetsExplanation =>
      'Current session toolsets are registered and usable by Hermes Agent in this session.\nGlobal CLI toolsets are configured globally and may not all be loaded in this session.';

  @override
  String get chatToolsetsLoadFailed => 'toolsets load failed';

  @override
  String chatTopicNumber(int index) {
    return 'Topic $index';
  }

  @override
  String chatTopicRailSemantics(int count) {
    return '$count topics';
  }

  @override
  String get chatTranscriptLoadFailed => 'Could not load chat history';

  @override
  String get chatTruncateWarning =>
      'This will delete all subsequent messages and cannot be undone';

  @override
  String chatUndoFailed(String error) {
    return 'Could not undo: $error';
  }

  @override
  String get chatUnknownCommandResult => 'Unknown command result';

  @override
  String get chatUnknownTime => 'Unknown time';

  @override
  String get chatUnmarkMessage => 'Unmark message';

  @override
  String get chatUntitled => 'Untitled session';

  @override
  String get chatUntitledSession => 'Untitled session';

  @override
  String get chatVersion => 'Version';

  @override
  String chatVersionCount(int count) {
    return '$count versions';
  }

  @override
  String chatVersionLoadFailed(String error) {
    return 'Could not load versions: $error';
  }

  @override
  String chatVersionNumber(int index) {
    return 'Version $index';
  }

  @override
  String get chatViewBilling => 'View billing';

  @override
  String get chatViewCleared => 'View cleared';

  @override
  String get chatWakeServiceUnavailable => 'Wake word service unavailable';

  @override
  String chatWakeVoiceFailed(String error) {
    return 'Wake word failed: $error';
  }

  @override
  String chatWarning(String warning) {
    return 'Warning: $warning';
  }

  @override
  String get chatWorkingDirectory => 'Working directory';

  @override
  String get chatWorkspace => 'Workspace';

  @override
  String get chatWorkspaceFiles => 'workspace files';

  @override
  String chatWorkspaceSwitchFailed(String error) {
    return 'Could not change workspace: $error';
  }

  @override
  String chatWorkspaceSwitched(String name) {
    return 'Workspace changed to $name';
  }

  @override
  String get chatYesterday => 'yesterday';

  @override
  String get chatYoloDisabled => 'YOLO mode disabled';

  @override
  String get chatYoloEnabled => 'YOLO mode enabled';

  @override
  String get chatYoloMode => 'YOLO mode';

  @override
  String chatYoloToggleFailed(String error) {
    return 'Could not toggle YOLO mode: $error';
  }

  @override
  String get appSessionCompletedTitle => 'Session completed';

  @override
  String get appSessionCompletedBody =>
      'A background session completed. Tap to view the result.';

  @override
  String appOpenNotificationFailed(Object error) {
    return 'Could not open the notification session: $error';
  }

  @override
  String get deepLinkPluginInstallTitle => 'Install Hermes plugin';

  @override
  String get deepLinkPluginInstallPrompt =>
      'This link requests installation of a backend plugin from:';

  @override
  String get deepLinkLegacyPluginWarning =>
      'This is a legacy Desktop plugin link. Mobile installs only its backend Agent capabilities.';

  @override
  String get deepLinkEnableAfterInstall => 'Enable after installation';

  @override
  String get deepLinkForceReinstall => 'Force reinstall';

  @override
  String get deepLinkInstall => 'Install';

  @override
  String deepLinkPluginInstalling(Object identifier) {
    return 'Installing $identifier...';
  }

  @override
  String get deepLinkPluginInstalled => 'Plugin installed';

  @override
  String deepLinkPluginInstallFailed(Object error) {
    return 'Plugin installation failed: $error';
  }

  @override
  String get deepLinkMcpAddTitle => 'Add MCP server';

  @override
  String get deepLinkMcpServerName => 'Server name';

  @override
  String get deepLinkMcpNameFormatError =>
      'Use 1-64 letters, numbers, periods, underscores, or hyphens';

  @override
  String get deepLinkMcpNameConflict =>
      'That name already exists. Choose another name.';

  @override
  String get deepLinkMcpCommandWarning =>
      'This configuration runs a local command on the Hermes backend. Continue only if you trust the source.';

  @override
  String get deepLinkConfigPreview => 'Configuration preview';

  @override
  String deepLinkMcpAdded(Object name) {
    return 'MCP server $name added';
  }

  @override
  String deepLinkMcpAddFailed(Object error) {
    return 'Could not add MCP server: $error';
  }

  @override
  String get commonAdd => 'Add';

  @override
  String get commonAll => 'All';

  @override
  String get commonAuthorize => 'Authorize';

  @override
  String get commonBack => 'Back';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonCancelAll => 'Cancel all';

  @override
  String get commonClose => 'Close';

  @override
  String get commonCollapse => 'Collapse';

  @override
  String get commonCompleted => 'Completed';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonConnected => 'Connected';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonCopied => 'Copied';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonDefault => 'Default';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonDisconnect => 'Disconnect';

  @override
  String get commonDisconnected => 'Disconnected';

  @override
  String get commonDone => 'Done';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonErrorTitle => 'Something went wrong';

  @override
  String get commonAuthenticationFailed =>
      'Authentication failed. Check the API key.';

  @override
  String get commonExpand => 'Expand';

  @override
  String get commonFile => 'File';

  @override
  String get commonFolder => 'Folder';

  @override
  String get commonGotIt => 'Got it';

  @override
  String get commonHide => 'Hide';

  @override
  String get commonIdle => 'Idle';

  @override
  String get commonIgnore => 'Ignore';

  @override
  String get commonLater => 'Later';

  @override
  String get commonListSeparator => ', ';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonManage => 'Manage';

  @override
  String get commonMore => 'More';

  @override
  String get commonName => 'Name';

  @override
  String get commonNew => 'New';

  @override
  String get commonNext => 'Next';

  @override
  String get commonNoMatches => 'No matches';

  @override
  String get commonNotifications => 'Notifications';

  @override
  String get commonOffline => 'Offline';

  @override
  String get commonOnline => 'Online';

  @override
  String get commonOperationFailed => 'The operation failed. Try again.';

  @override
  String get commonNetworkFailed =>
      'Unable to reach the server. Check the network and server status.';

  @override
  String get commonOpen => 'Open';

  @override
  String get commonPrevious => 'Previous';

  @override
  String get commonProcessing => 'Processing...';

  @override
  String get commonReauthorize => 'Reauthorize';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonReload => 'Reload';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonRestart => 'Restart';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonRun => 'Run';

  @override
  String get commonRunning => 'Running';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonSelect => 'Select';

  @override
  String get commonSend => 'Send';

  @override
  String get commonStop => 'Stop';

  @override
  String get commonSubmit => 'Submit';

  @override
  String get commonSwitch => 'Switch';

  @override
  String get commonTitle => 'Title';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonUnknownError => 'Unknown error';

  @override
  String get commonViewAll => 'View all';

  @override
  String get configAppliesToProfile => 'Applies to profile';

  @override
  String get configConnectionLabel => 'Connection';

  @override
  String get configCurrentProfile => 'the current profile';

  @override
  String get configDefaultProcessProfile => 'Default / process profile';

  @override
  String configDeleteFailed(String error) {
    return 'Could not remove override: $error';
  }

  @override
  String get configFullJson => 'Full JSON';

  @override
  String configInvalidFieldValue(String path, String error) {
    return 'Invalid value for $path: $error';
  }

  @override
  String configInvalidJson(String error) {
    return 'Invalid JSON: $error';
  }

  @override
  String get configListJsonError => 'Value must be a JSON array';

  @override
  String get configLoading => 'Loading configuration and schema...';

  @override
  String get configNoMatches => 'No matching fields';

  @override
  String get configObjectJsonError => 'Value must be a JSON object';

  @override
  String get configRemoveOverride =>
      'Remove override and use the default value';

  @override
  String get configRestore => 'Restore';

  @override
  String get configRestoreDefaults => 'Restore defaults';

  @override
  String configRestoreDefaultsDescription(String profile) {
    return 'This applies to $profile. Existing custom values will be replaced by defaults.';
  }

  @override
  String get configRestoreDefaultsQuestion =>
      'Restore the default Hermes configuration?';

  @override
  String configSaveFailed(String error) {
    return 'Could not save: $error';
  }

  @override
  String get providerEndpointValidationFailed => 'Endpoint validation failed';

  @override
  String get kanbanMoveSelected => 'Move selected tasks';

  @override
  String get kanbanClearSelection => 'Clear task selection';

  @override
  String get configSearchHint => 'Search configuration fields...';

  @override
  String configServerDidNotDelete(String path) {
    return 'The server did not remove $path';
  }

  @override
  String get configServerMismatch =>
      'The server returned content that differs from the submitted full configuration';

  @override
  String configServerRejected(String path) {
    return 'The server did not accept $path; the server value has been restored.';
  }

  @override
  String get configTitle => 'Models & chat';

  @override
  String get configTopLevelObject =>
      'The top-level JSON value must be an object';

  @override
  String get configUseDefault => 'Default';

  @override
  String get connectAction => 'Connect';

  @override
  String get connectAddHeader => 'Add request header';

  @override
  String get connectAllowPublicHttp => 'Allow public cleartext HTTP';

  @override
  String get connectAllowPublicHttpWarning =>
      'Use only on a trusted network where HTTPS is unavailable; tokens may be intercepted';

  @override
  String get connectApiKey => 'API key';

  @override
  String get connectConfiguration => 'Connection configuration';

  @override
  String get connectConnecting => 'Connecting…';

  @override
  String get connectCredentialRequired => 'Enter an access credential';

  @override
  String get connectDeleteHeader => 'Delete request header';

  @override
  String get connectDeleteProfile => 'Delete configuration';

  @override
  String get connectDiscoverCloud => 'Discover an agent from Hermes Cloud';

  @override
  String get connectExtraHeaders => 'Additional request headers';

  @override
  String get connectHeaderManaged => 'Managed by Hermes';

  @override
  String get connectHeaderName => 'Header name';

  @override
  String get connectHeaderNameInvalid => 'Invalid name';

  @override
  String get connectHeaderValue => 'Value';

  @override
  String get connectHeaderValueRequired => 'Enter a value';

  @override
  String get connectHeadersDescription =>
      'Optional access-proxy headers. Values are stored in secure system storage.';

  @override
  String get connectHideKey => 'Hide key';

  @override
  String get connectHidePassphrase => 'Hide passphrase';

  @override
  String get connectHidePassword => 'Hide password';

  @override
  String get connectHidePrivateKey => 'Hide private key';

  @override
  String get connectHideValue => 'Hide value';

  @override
  String get connectHttpsRequired =>
      'Public connections require HTTPS unless insecure transport is explicitly allowed';

  @override
  String get connectNativeCleartextRestricted =>
      'Release builds allow cleartext only for localhost or .local companion names. Use HTTPS or a .local hostname.';

  @override
  String get connectNotSignedIn => 'Not signed in';

  @override
  String get connectOauthSignedIn => 'Signed in with OAuth';

  @override
  String get connectPkceUnavailable =>
      'This gateway does not support native_pkce sign-in. Update Hermes or use a token.';

  @override
  String get connectPort => 'Port';

  @override
  String get connectPrivateKey => 'OpenSSH / PEM private key';

  @override
  String get connectPrivateKeyPassphrase => 'Private key passphrase (optional)';

  @override
  String get connectProfileName => 'Configuration name (defaults to host name)';

  @override
  String get connectProfileNameInvalid => 'Invalid profile name';

  @override
  String get connectRemoteHermesPath => 'Remote Hermes path (auto-detect)';

  @override
  String get connectRemoteProfile => 'Remote profile (optional)';

  @override
  String get connectSaveProfile => 'Save as a server configuration';

  @override
  String get connectSaveProfileDescription =>
      'Switch to it from the saved list next time';

  @override
  String get connectSavedBackends => 'Saved backends';

  @override
  String get connectServerAddress => 'Server address';

  @override
  String get connectServerInvalid => 'Enter a valid HTTP(S) address';

  @override
  String get connectServerRequired => 'Enter a server address';

  @override
  String get connectShowKey => 'Show key';

  @override
  String get connectShowPassphrase => 'Show passphrase';

  @override
  String get connectShowPassword => 'Show password';

  @override
  String get connectShowPrivateKey => 'Show private key';

  @override
  String get connectShowValue => 'Show value';

  @override
  String get connectSignIn => 'Sign in';

  @override
  String get connectSignInAgain => 'Sign in again';

  @override
  String get connectSshCredentialRequired => 'Enter a private key or password';

  @override
  String get connectSshHost => 'SSH host';

  @override
  String get connectSshHostRequired => 'Enter an SSH host';

  @override
  String get connectSshPassword => 'SSH password (optional)';

  @override
  String get connectSshUser => 'SSH user';

  @override
  String get connectSshUserRequired => 'Enter an SSH user';

  @override
  String get connectTitle => 'Connection';

  @override
  String get connectUnableServer => 'Could not connect to the server';

  @override
  String get connectValidationFailed =>
      'Connection validation failed. Check the server address and API key.';

  @override
  String get connectValidationNetworkFailed =>
      'Connection validation failed. Check the server address, API key, and network.';

  @override
  String dateMonthDay(int month, int day) {
    return '$month/$day';
  }

  @override
  String get dateToday => 'Today';

  @override
  String get dateYesterday => 'Yesterday';

  @override
  String get discordCommunityTitle => 'Join the Discord community';

  @override
  String get featureAbout => 'About';

  @override
  String get featureAboutDesc => 'Version information';

  @override
  String get featureAgent => 'Bots';

  @override
  String get featureAgentDesc => 'Bots, group chats and runtime status';

  @override
  String get featureArtifacts => 'Artifacts';

  @override
  String get featureArtifactsDesc => 'Session outputs';

  @override
  String get featureBilling => 'Billing';

  @override
  String get featureBillingDesc => 'Usage, plans and invoices';

  @override
  String get featureCommandCenter => 'Command center';

  @override
  String get featureCommandCenterDesc => 'Live status and logs';

  @override
  String get featureConnection => 'Connection';

  @override
  String get featureConnectionDesc => 'Multiple backend profiles';

  @override
  String get featureCredentials => 'Credentials';

  @override
  String get featureCredentialsDesc => 'Third-party accounts and keys';

  @override
  String get featureCron => 'Scheduled tasks';

  @override
  String get featureCronDesc => 'Cron automation';

  @override
  String get featureFiles => 'Files';

  @override
  String get featureFilesDesc => 'Browse the working directory';

  @override
  String get featureGit => 'Git';

  @override
  String get featureGitDesc => 'Changes, commits and branches';

  @override
  String get featureGlobalSearchDesc => 'Search commands, sessions and pages';

  @override
  String get featureInsights => 'Insights';

  @override
  String get featureInsightsDesc => 'Usage and cost trends';

  @override
  String get featureMcp => 'MCP';

  @override
  String get featureMcpDesc => 'MCP server configuration';

  @override
  String get featureMemory => 'Memory';

  @override
  String get featureMemoryDesc => 'Long-term memory management';

  @override
  String get featureMessaging => 'Messaging';

  @override
  String get featureMessagingDesc => 'Telegram, Discord and more';

  @override
  String get featureNotificationsDesc => 'Notification center';

  @override
  String get featurePet => 'Pet';

  @override
  String get featurePetDesc => 'Companion and collection';

  @override
  String get featurePlugins => 'Plugins';

  @override
  String get featurePluginsDesc => 'Plugin management';

  @override
  String get featureProfiles => 'Profiles';

  @override
  String get featureProfilesDesc => 'Model execution profiles';

  @override
  String get featureProjects => 'Projects';

  @override
  String get featureProjectsDesc => 'Group sessions across projects';

  @override
  String get featureSettings => 'Settings';

  @override
  String get featureSettingsDesc => 'Appearance and preferences';

  @override
  String get featureSkills => 'Skills';

  @override
  String get featureSkillsDesc => 'Skill hub';

  @override
  String get featureStarmap => 'Knowledge starmap';

  @override
  String get featureStarmapDesc => 'Keyword knowledge graph';

  @override
  String get featureSubagents => 'Subagents';

  @override
  String get featureSubagentsDesc => 'Background agent activity';

  @override
  String get featureTerminal => 'Terminal';

  @override
  String get featureTerminalDesc => 'Interactive command line';

  @override
  String get featureTools => 'Toolsets';

  @override
  String get featureToolsDesc => 'Tools and keys';

  @override
  String get featureWebhooks => 'Webhooks';

  @override
  String get featureWebhooksDesc => 'Event delivery';

  @override
  String gitAgentShipFailed(Object error) {
    return 'Agent Ship failed: $error';
  }

  @override
  String get gitAgentShipPrompt =>
      'Review the current changes, commit them with a clear conventional commit message, push the branch, and open a pull request.';

  @override
  String get gitAgentShipQuestion =>
      'Have the Agent commit and push changes, then create a PR?';

  @override
  String get gitAgentShipSent => 'Sent the commit-and-create-PR task to Hermes';

  @override
  String get gitAuthor => 'Author';

  @override
  String gitAuthorMeta(Object author) {
    return 'Author: $author';
  }

  @override
  String get gitBaseBranch => 'Base branch';

  @override
  String gitBranchMeta(Object branch) {
    return 'Branch: $branch';
  }

  @override
  String get gitBranchesTab => 'Branches';

  @override
  String get gitChangeDirectory => 'Change directory';

  @override
  String get gitChangedFiles => 'Changed files';

  @override
  String get gitChangedFilesLabel => 'Changed files:';

  @override
  String get gitChangesTab => 'Changes';

  @override
  String get gitCommit => 'Commit';

  @override
  String get gitCommitChanges => 'Commit changes';

  @override
  String get gitCommitDetails => 'Commit details';

  @override
  String gitCommitFailed(Object error) {
    return 'Commit failed: $error';
  }

  @override
  String get gitCommitMessage => 'Commit message';

  @override
  String get gitCommitsTab => 'Commits';

  @override
  String get gitCreatePr => 'Create PR';

  @override
  String gitCreatePrFailed(Object error) {
    return 'Could not create PR: $error';
  }

  @override
  String get gitCreatePrQuestion =>
      'Create or open a pull request for the current branch with GitHub CLI?';

  @override
  String gitCreateWorktreeFailed(Object error) {
    return 'Could not create worktree: $error';
  }

  @override
  String get gitCurrent => 'Current';

  @override
  String gitDeleteWorktreeDescription(Object path) {
    return 'This deletes the working directory $path and its uncommitted changes. It cannot be recovered.';
  }

  @override
  String gitDeleteWorktreeFailed(Object error) {
    return 'Could not delete worktree: $error';
  }

  @override
  String get gitDeleteWorktreeQuestion => 'Delete worktree?';

  @override
  String get gitDetachedHead => '(detached HEAD)';

  @override
  String gitDiffLoadFailed(Object error) {
    return 'Could not load diff: $error';
  }

  @override
  String get gitEndOfLog => '— End of log —';

  @override
  String get gitForceDelete => 'Force delete';

  @override
  String get gitForceDeleteWorktreeQuestion =>
      'Force delete and discard these changes?';

  @override
  String get gitGenerateCommitMessage => 'Generate commit message';

  @override
  String gitGenerateMessageFailed(Object error) {
    return 'Could not generate commit message: $error';
  }

  @override
  String get gitGithubCliUnavailable =>
      'GitHub CLI is not installed or signed in on the backend';

  @override
  String gitHoursAgo(Object count) {
    return '$count hr ago';
  }

  @override
  String get gitJustNow => 'just now';

  @override
  String gitLoadMore(Object loaded, Object total) {
    return 'Load more ($loaded/$total)';
  }

  @override
  String get gitLoadingBranches => 'Loading branches...';

  @override
  String get gitLoadingLog => 'Loading commit log...';

  @override
  String get gitLoadingStatus => 'Loading repository status...';

  @override
  String get gitLocalBranches => 'Local branches';

  @override
  String gitLogLoadFailed(Object error) {
    return 'Could not load commit log: $error';
  }

  @override
  String get gitMainWorktree => 'Main';

  @override
  String gitMinutesAgo(Object count) {
    return '$count min ago';
  }

  @override
  String get gitNewWorktree => 'New worktree';

  @override
  String get gitNoAdditionalWorktrees => 'No additional worktrees';

  @override
  String get gitNoBranches => 'No branches available';

  @override
  String get gitNoBranchesDescription =>
      'Select a Git repository and try again.';

  @override
  String get gitNoCommits => 'No commits';

  @override
  String get gitNoCommitsDescription =>
      'This repository has no commits, or no commits match the current filters';

  @override
  String get gitNoDiff => 'No diff';

  @override
  String get gitNoDiffDescription => 'This file does not differ from HEAD';

  @override
  String get gitNoMatchingBranches => 'No matching branches';

  @override
  String get gitNoStashes => 'No stashes';

  @override
  String get gitNoVisibleRemotes => 'No visible remotes';

  @override
  String get gitNotRepository => 'Not a Git repository';

  @override
  String gitNotRepositoryDescription(Object path) {
    return '$path\n\nUse the button below to change directory';
  }

  @override
  String get gitOpenInNewSession => 'Open in new session';

  @override
  String gitOpenPr(Object number) {
    return 'Open PR #$number';
  }

  @override
  String gitOpenedInNewSession(Object path) {
    return 'Opened $path in a new session';
  }

  @override
  String get gitParent => 'parent';

  @override
  String get gitPrCreated => 'PR created';

  @override
  String gitPrNumber(Object number) {
    return 'Number: #$number';
  }

  @override
  String get gitPushAfterCommit => 'Push after commit';

  @override
  String gitPushAction(Object count) {
    return 'Push $count commit(s)';
  }

  @override
  String get gitPushSucceeded => 'Pushed to remote';

  @override
  String gitPushFailed(Object error) {
    return 'Push failed: $error';
  }

  @override
  String get gitRecentRepositories => 'Recent repositories';

  @override
  String get gitRemotes => 'Remotes';

  @override
  String get gitRemotesAndStashes => 'Remotes and stashes';

  @override
  String get gitRepositoryDirectory => 'Repository directory';

  @override
  String get gitRevert => 'Revert';

  @override
  String get gitRevertAll => 'Revert all';

  @override
  String get gitRevertAllDescription =>
      'This discards all uncommitted working-tree changes and cannot be undone.';

  @override
  String get gitRevertAllQuestion => 'Revert all changes?';

  @override
  String gitRevertFailed(Object error) {
    return 'Revert failed: $error';
  }

  @override
  String get gitRevertFile => 'Revert this file';

  @override
  String gitRevertFileDescription(Object file) {
    return 'This discards uncommitted changes to “$file” and cannot be undone.';
  }

  @override
  String get gitRevertFileQuestion => 'Revert this file?';

  @override
  String get gitSearchBranches => 'Search branches...';

  @override
  String get gitSearchCommits => 'Search commit messages';

  @override
  String get gitSelectFileForDiff => 'Select a file to view its diff';

  @override
  String get gitSelectFileForDiffDescription =>
      'Select a changed file on the left to view its diff here';

  @override
  String get gitServerRepositoryPath => 'Repository path on server';

  @override
  String get gitStage => 'Stage';

  @override
  String gitStageFailed(Object error) {
    return 'Staging operation failed: $error';
  }

  @override
  String gitStagedChanges(Object added, Object removed) {
    return 'Staged · +$added −$removed';
  }

  @override
  String get gitStashes => 'Stashes';

  @override
  String get gitSwitch => 'Switch';

  @override
  String get gitSwitchBranch => 'Switch branch';

  @override
  String gitSwitchBranchFailed(Object error) {
    return 'Could not switch branch: $error';
  }

  @override
  String get gitUnknownAuthor => 'Unknown';

  @override
  String get gitUnstage => 'Unstage';

  @override
  String get gitWorkingTreeClean => 'Working tree clean; no changes';

  @override
  String get gitWorktreeHasChanges => 'The worktree has uncommitted changes';

  @override
  String get gitWorktreeNameHint => 'For example, feature-login';

  @override
  String get gitWorktrees => 'Worktrees';

  @override
  String get globalSearch => 'Global search';

  @override
  String get groupConfiguration => 'Configuration';

  @override
  String get groupIntegrations => 'Integrations';

  @override
  String get groupIntelligence => 'Intelligence';

  @override
  String get groupSystem => 'System';

  @override
  String get groupWorkspace => 'Workspace';

  @override
  String get helpAndFeedbackTitle => 'Help and feedback';

  @override
  String get homeAllFeatures => 'All features';

  @override
  String get homeAttentionDetail =>
      'The agent may be waiting for your confirmation';

  @override
  String homeBackendSummary(String model, String profile) {
    return 'Backend connected · $model · Profile: $profile';
  }

  @override
  String homeContinueSession(String title) {
    return 'Continue “$title”';
  }

  @override
  String get homeContinueWork => 'Continue your work';

  @override
  String get homeCurrentWork => 'Current work';

  @override
  String get homeDefaultProfile => 'Default';

  @override
  String get homeDragToReorder => 'Drag to reorder';

  @override
  String get homeEditQuickTools => 'Edit quick tools';

  @override
  String get homeLastVisibleTool => 'Last tool shown on Home';

  @override
  String get homeLoadingRecent => 'Loading recent work…';

  @override
  String get homeMoreTools => 'More tools';

  @override
  String homeNeedsAttention(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items need attention',
      one: '1 item needs attention',
    );
    return '$_temp0';
  }

  @override
  String get homeNoWorkDescription =>
      'Describe a goal above to start your first task';

  @override
  String get homeNoWorkTitle => 'No work history yet';

  @override
  String homeProfileTooltip(String profile) {
    return 'Profile: $profile';
  }

  @override
  String get homeQuickTools => 'Quick tools';

  @override
  String get homeQuickToolsDescription =>
      'The first 5 tools appear on Home. The rest are available under More.';

  @override
  String get homeReadyTitle => 'Hermes is ready';

  @override
  String get homeRecentSessions => 'Recent sessions';

  @override
  String get homeRestoreDefaults => 'Restore defaults';

  @override
  String get homeStartNewSession => 'Start new session';

  @override
  String get homeSwitchProfile => 'Switch profile';

  @override
  String get homeToolKnowledge => 'Knowledge';

  @override
  String get homeViewAttentionSessions => 'View pending sessions';

  @override
  String get homeViewSession => 'View session';

  @override
  String homeWorkingDetail(String model) {
    return 'Processing the current task · $model';
  }

  @override
  String get homeWorkingTitle => 'Hermes is working';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get languageDescription => 'Choose the language used by Hermes Mobile';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => 'Japanese';

  @override
  String get languageSimplifiedChinese => 'Simplified Chinese';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageTraditionalChinese => 'Traditional Chinese';

  @override
  String get legalPrivacy => 'Privacy policy';

  @override
  String get legalTerms => 'Terms of service';

  @override
  String get legalTitle => 'Legal and licenses';

  @override
  String get modelAllFollowMain => 'Make all follow main model';

  @override
  String get modelApply => 'Apply';

  @override
  String modelAuxiliarySaveFailed(String error) {
    return 'Could not save auxiliary model: $error';
  }

  @override
  String get modelAuxiliaryTitle => 'Auxiliary models';

  @override
  String get modelAuxiliaryUnavailable =>
      'This Hermes backend does not provide auxiliary model configuration.';

  @override
  String get modelChoose => 'Choose model';

  @override
  String get modelConfirmSelection => 'Confirm model selection';

  @override
  String get modelCreate => 'Create';

  @override
  String get modelCurrent => 'In use';

  @override
  String get modelDefaultTitle => 'Default model';

  @override
  String get modelExpensiveWarning =>
      'This model may incur higher costs. Continue?';

  @override
  String get modelFallbackHint =>
      'fallback_providers (one provider:model per line)';

  @override
  String get modelFallbackTitle => 'Fallback models';

  @override
  String get modelFollowMain => 'Follow main model';

  @override
  String get modelLabel => 'Model';

  @override
  String get modelMoaAddReference => 'Add reference model';

  @override
  String get modelMoaAggregator => 'Aggregator';

  @override
  String get modelMoaAggregatorMaxTokens => 'Aggregator output limit';

  @override
  String get modelMoaAggregatorModel => 'Aggregator model';

  @override
  String modelMoaAggregatorSummary(String provider, String model) {
    return 'Aggregator: $provider · $model';
  }

  @override
  String get modelMoaAggregatorTemperature => 'Aggregator temperature';

  @override
  String get modelMoaCompleteModels => 'Complete all model selections';

  @override
  String get modelMoaCreatePreset => 'Create MoA preset';

  @override
  String get modelMoaCreateTooltip => 'Create preset';

  @override
  String get modelMoaDefaultPreset => 'Default preset';

  @override
  String get modelMoaDegradedLoud => 'Report degradation';

  @override
  String get modelMoaDegradedPolicy => 'Degraded policy';

  @override
  String get modelMoaDegradedSilent => 'Silent degradation';

  @override
  String get modelMoaDeleteTooltip => 'Delete preset';

  @override
  String get modelMoaDescription =>
      'Reference models answer in parallel and the aggregator produces the final result';

  @override
  String get modelMoaEditConfiguration => 'Edit configuration';

  @override
  String modelMoaEditTitle(String name) {
    return 'Edit $name';
  }

  @override
  String get modelMoaEnablePreset => 'Enable preset';

  @override
  String get modelMoaFanoutCadence => 'Fanout cadence';

  @override
  String get modelMoaFanoutHint => 'user_turn / per_iteration / every_n:2';

  @override
  String get modelMoaNoEditable => 'There are no editable MoA presets.';

  @override
  String get modelMoaPresetLabel => 'Preset';

  @override
  String modelMoaReferenceCount(int count) {
    return '$count reference models';
  }

  @override
  String get modelMoaReferenceMaxTokens => 'Reference output limit';

  @override
  String get modelMoaReferenceModels => 'Reference models';

  @override
  String modelMoaReferenceNumber(int index) {
    return 'Reference $index';
  }

  @override
  String get modelMoaReferenceTemperature => 'Reference temperature';

  @override
  String get modelMoaReferenceTimeout => 'Reference timeout (seconds)';

  @override
  String get modelMoaRuntimeParameters => 'Runtime parameters';

  @override
  String get modelMoaSaveConfiguration => 'Save configuration';

  @override
  String modelMoaSaveFailed(String error) {
    return 'Could not save MoA configuration: $error';
  }

  @override
  String get modelMoaSetDefault => 'Set as default';

  @override
  String get modelMoaUnavailable =>
      'This Hermes backend does not provide MoA configuration.';

  @override
  String get modelNoAvailable => 'No models available';

  @override
  String get modelPresetName => 'Name';

  @override
  String get modelProvider => 'Provider';

  @override
  String get modelProviderNotFound =>
      'Could not find the provider for this model';

  @override
  String modelRecommended(String model) {
    return 'Recommended: $model';
  }

  @override
  String get modelRemove => 'Remove';

  @override
  String get modelSwitchDeferred =>
      'Model switch queued and will apply after the current turn';

  @override
  String modelSwitchFailed(String error) {
    return 'Could not switch model: $error';
  }

  @override
  String modelSwitchSucceeded(String model) {
    return 'Switched to $model';
  }

  @override
  String get moreCloseSearch => 'Close directory search';

  @override
  String get moreNoMatches => 'No matching features';

  @override
  String get moreSearchDirectory => 'Search directory';

  @override
  String get moreSearchHint => 'Search features';

  @override
  String moreStatus(String connection, String agent) {
    return '$connection · Agent $agent';
  }

  @override
  String get navHome => 'Home';

  @override
  String get navMore => 'More';

  @override
  String get navSessions => 'Sessions';

  @override
  String get navTasks => 'Tasks';

  @override
  String get notificationClear => 'Clear';

  @override
  String get notificationClearConfirmTitle => 'Clear all notifications?';

  @override
  String get notificationClearConfirmBody =>
      'This removes every notification from this list. It can\'t be undone.';

  @override
  String get notificationEmptyDescription =>
      'Agent completions, approvals, and errors appear here';

  @override
  String get notificationEmptyTitle => 'No notifications';

  @override
  String get notificationMarkAllRead => 'Mark all read';

  @override
  String notificationOpenFailed(String error) {
    return 'Could not open session: $error';
  }

  @override
  String get notificationOpenSession => 'View session';

  @override
  String get notificationTitle => 'Notifications';

  @override
  String get paletteHint => 'Search pages, sessions, and commands…';

  @override
  String get paletteHintClose => 'Close';

  @override
  String get paletteHintNavigate => 'Navigate';

  @override
  String get paletteHintOpen => 'Open';

  @override
  String get paletteKanban => 'Kanban';

  @override
  String get paletteKindAction => 'Action';

  @override
  String get paletteKindCommand => 'Command';

  @override
  String get paletteKindPage => 'Page';

  @override
  String get paletteKindSession => 'Session';

  @override
  String get paletteNewSessionDesc => 'Start a new conversation';

  @override
  String get paletteNoResults => 'No matching results';

  @override
  String get paletteReconnect => 'Reconnect';

  @override
  String get paletteReconnectDesc => 'Reconnect to the server';

  @override
  String get paletteVoiceInput => 'Voice input';

  @override
  String get paletteVoiceInputDesc => 'Start voice dictation';

  @override
  String pluginActionFailed(String title, String error) {
    return '$title failed: $error';
  }

  @override
  String get pluginFieldInvalidNumber => 'Enter a valid number';

  @override
  String pluginFieldMaximum(num value) {
    return 'Maximum value: $value';
  }

  @override
  String pluginFieldMinimum(num value) {
    return 'Minimum value: $value';
  }

  @override
  String get pluginFieldRequired => 'This field is required';

  @override
  String pluginItemFallback(int index) {
    return 'Item $index';
  }

  @override
  String get pluginNoItems => 'No items';

  @override
  String get pluginResultCopied => 'Result copied';

  @override
  String get pluginResultCopy => 'Copy result';

  @override
  String get pluginResultOpenLink => 'Open link';

  @override
  String get pluginSubmit => 'Submit';

  @override
  String previewActionSendFailed(String error) {
    return 'Could not send preview action: $error';
  }

  @override
  String previewActionSent(String prompt) {
    return 'Preview action sent: $prompt';
  }

  @override
  String get previewBack => 'Back';

  @override
  String get previewClearConsole => 'Clear console';

  @override
  String get previewCloseConsole => 'Close console';

  @override
  String get previewConsoleTitle => 'Console';

  @override
  String get previewEmpty => 'Open a link in chat or select an HTML file';

  @override
  String previewFailed(String error) {
    return 'Preview failed: $error';
  }

  @override
  String get previewForward => 'Forward';

  @override
  String get previewNoLogs => 'No logs';

  @override
  String get previewOpenBrowser => 'Open in browser';

  @override
  String get previewOpenConsole => 'Open console';

  @override
  String previewOpenSessionFailed(String error) {
    return 'Could not open session: $error';
  }

  @override
  String get previewRefresh => 'Refresh preview';

  @override
  String get previewRunJavascript => 'Run JavaScript';

  @override
  String get previewRunScript => 'Run script';

  @override
  String get previewTitle => 'Preview';

  @override
  String get previewUnsupportedWebView =>
      'Embedded WebView is unavailable on this platform. Open it in your browser.';

  @override
  String get projectBrowseFiles => 'Browse the project directory';

  @override
  String get projectDetailTitle => 'Project details';

  @override
  String projectFolderCount(int count) {
    return '$count folders';
  }

  @override
  String get projectGitDescription => 'View repository status and changes';

  @override
  String get projectGlobalMemoryDescription => 'Profile memory (global view)';

  @override
  String get projectGlobalStarmapDescription => 'Knowledge graph (global view)';

  @override
  String get projectGlobalSubagentsDescription =>
      'Subagent activity across sessions';

  @override
  String get projectGlobalWebhooksDescription =>
      'Webhook configuration (global view)';

  @override
  String get projectLoadingSessions => 'Loading sessions...';

  @override
  String get projectModulesTitle => 'Modules';

  @override
  String get projectNoKanbanBoard => 'This project has no linked board';

  @override
  String get projectNoSessions => 'No related sessions';

  @override
  String get projectNoSessionsDescription =>
      'Sessions started inside this project appear here';

  @override
  String projectResumeFailed(String error) {
    return 'Could not resume session: $error';
  }

  @override
  String projectSessionCount(int count) {
    return '$count sessions';
  }

  @override
  String get projectSessionsTitle => 'Sessions';

  @override
  String get projectTasksDescription => 'Open a board linked to this project';

  @override
  String get projectTasksTitle => 'Tasks and boards';

  @override
  String get projectUnavailable => 'Unavailable';

  @override
  String get projectUntitled => 'Untitled project';

  @override
  String get providerActiveDefault => 'Active / default';

  @override
  String get providerAddEndpointTitle => 'New custom endpoint';

  @override
  String get providerCustomEndpointJson => 'Custom endpoint JSON';

  @override
  String get providerCustomEndpointsSection => 'Custom endpoints';

  @override
  String get providerDeviceAuthorization => 'Device authorization';

  @override
  String get providerEditEndpointTitle => 'Edit custom endpoint';

  @override
  String get providerEndpointApiKey => 'API key';

  @override
  String get providerEndpointBaseUrl => 'Base URL';

  @override
  String get providerEndpointDefaultModel => 'Default model';

  @override
  String get providerEndpointDiscoverModels => 'Auto-discover models';

  @override
  String get providerEndpointFallback => 'Endpoint';

  @override
  String get providerEndpointModelsList => 'Available models (one per line)';

  @override
  String get providerEndpointName => 'Name';

  @override
  String get providerEndpointNameRequired => 'Enter a name';

  @override
  String get providerEndpointUrlRequired => 'Enter a base URL';

  @override
  String providerEnterDeviceCode(String code) {
    return 'Enter this verification code in your browser: $code';
  }

  @override
  String providerActionFailed(String error) {
    return 'Action failed: $error';
  }

  @override
  String get providerEnvironmentSection => 'Environment';

  @override
  String get providerEnvironmentVariableName => 'Environment variable name';

  @override
  String get providerEnvironmentVariableValue => 'Environment variable value';

  @override
  String providerMissingKeys(String keys) {
    return 'Missing: $keys';
  }

  @override
  String providerModelTitle(String provider) {
    return '$provider model';
  }

  @override
  String get providerNoConfiguration => 'No configuration';

  @override
  String get providerNotSet => 'Not set';

  @override
  String get providerOauthSection => 'Provider OAuth';

  @override
  String get providerPasteOauthCode => 'Paste OAuth code';

  @override
  String get providerProfileLabel => 'Profile';

  @override
  String providerRevealFailed(String error) {
    return 'Couldn\'t read value: $error';
  }

  @override
  String get providerRevealValue => 'Reveal';

  @override
  String get providerRevealedValueTitle => 'Saved value';

  @override
  String providerRunSetupDescription(String provider, String command) {
    return '$provider needs to run: $command';
  }

  @override
  String get providerRunSetupQuestion => 'Run provider setup?';

  @override
  String get providerSetActive => 'Set active';

  @override
  String providerSetEnvironmentVariable(String key) {
    return 'Set $key';
  }

  @override
  String providerToolsCount(int count) {
    return '$count tools';
  }

  @override
  String providerToolsetProviderTitle(String toolset) {
    return '$toolset provider';
  }

  @override
  String get providerToolsetProvidersSection => 'Toolset providers';

  @override
  String get pushEnabled => 'Remote notifications';

  @override
  String get pushEnabledDescription =>
      'Register this installation with the active Hermes server';

  @override
  String get pushOsPermissionDenied => 'System notifications are blocked';

  @override
  String get pushOsPermissionDeniedDescription =>
      'Remote notifications are enabled in Hermes, but the OS is blocking them, so nothing will actually be delivered. Enable notifications for Hermes Mobile in your device\'s system settings.';

  @override
  String get pushNoProviders =>
      'APNs or FCM credentials are not configured on the server';

  @override
  String get pushNotRegistered => 'Not registered';

  @override
  String get pushProviders => 'Delivery providers';

  @override
  String get pushRefresh => 'Refresh push status';

  @override
  String get pushRegistered =>
      'Registered for the active connection and profile';

  @override
  String get pushRegistration => 'Device registration';

  @override
  String get pushSendTest => 'Send test notification';

  @override
  String get pushSettingsDescription =>
      'Receive completions and approval requests when Hermes Mobile is closed.';

  @override
  String get pushSettingsTitle => 'Remote notifications';

  @override
  String get pushTestDelivered => 'Test notification delivered';

  @override
  String pushTestFailed(String error) {
    return 'Could not send test notification: $error';
  }

  @override
  String get pushTestNotDelivered =>
      'No provider delivered the test notification';

  @override
  String get reportIssueTitle => 'Report an issue on GitHub';

  @override
  String get sendDiagnosticsSubtitle =>
      'Upload redacted logs to help us debug an issue';

  @override
  String get sendDiagnosticsTitle => 'Send diagnostics';

  @override
  String get sessionActions => 'Session actions';

  @override
  String get sessionAllTags => 'All tags';

  @override
  String get sessionArchiveView => 'Archive view';

  @override
  String get sessionArchiveViewDescription => 'Show archived sessions only';

  @override
  String sessionBatchDeleteDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The $count selected sessions will be permanently deleted. This cannot be undone.',
      one:
          'The selected session will be permanently deleted. This cannot be undone.',
    );
    return '$_temp0';
  }

  @override
  String get sessionBatchDeleteTitle => 'Delete sessions?';

  @override
  String get sessionCancelSelection => 'Cancel selection';

  @override
  String get sessionClearAll => 'Clear all';

  @override
  String get sessionClearFilters => 'Clear filters';

  @override
  String get sessionClearSearch => 'Clear search';

  @override
  String get sessionCollapseChildren => 'Collapse child sessions';

  @override
  String get sessionConfirmDelete => 'Delete permanently';

  @override
  String get sessionContinueLast => 'Continue last session';

  @override
  String get sessionDeepSearchHint =>
      'Search session titles and message history';

  @override
  String get sessionDeepSearchTitle => 'Search chat history';

  @override
  String sessionDeleteDescription(String title) {
    return '“$title” will be permanently deleted.';
  }

  @override
  String sessionDeleteFailed(String error) {
    return 'Could not delete sessions: $error';
  }

  @override
  String get sessionDeleteSelected => 'Delete selected';

  @override
  String get sessionDeleteTitle => 'Delete session?';

  @override
  String sessionDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deleted $count sessions',
      one: 'Deleted 1 session',
    );
    return '$_temp0';
  }

  @override
  String sessionDurationDaysHours(int days, int hours) {
    return '${days}d ${hours}h';
  }

  @override
  String sessionDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String sessionDurationMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String get sessionEmptyDescription =>
      'Start a new session to chat with Hermes';

  @override
  String get sessionEmptyTitle => 'No sessions yet';

  @override
  String get sessionExpandChildren => 'Expand child sessions';

  @override
  String get sessionFilterAll => 'All';

  @override
  String get sessionFilterApproval => 'Needs approval';

  @override
  String get sessionFilterByTag => 'Filter by tag';

  @override
  String get sessionFilterCompleted => 'Completed';

  @override
  String get sessionFilterTitle => 'Filter sessions';

  @override
  String get sessionGroupArchived => 'Archived';

  @override
  String get sessionGroupByProject => 'Group by project';

  @override
  String get sessionGroupByTime => 'Group by time';

  @override
  String get sessionGroupLast7Days => 'Last 7 days';

  @override
  String get sessionGroupOlder => 'Older';

  @override
  String get sessionGroupPinned => 'Pinned';

  @override
  String get sessionGroupRunning => 'Running';

  @override
  String sessionHandoff(String state) {
    return 'Handoff $state';
  }

  @override
  String get sessionHistoryArchive => 'History archive';

  @override
  String get sessionLoadMore => 'Load more sessions';

  @override
  String get sessionManage => 'Manage sessions';

  @override
  String sessionMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0';
  }

  @override
  String get sessionNew => 'New session';

  @override
  String get sessionNoMatchesDescription =>
      'Adjust the search or status filters';

  @override
  String get sessionNoMatchesTitle => 'No matching sessions';

  @override
  String get sessionNoProjectsDescription =>
      'Sessions started in Git repositories are grouped into projects automatically';

  @override
  String get sessionNoProjectsTitle => 'No projects';

  @override
  String sessionOpenCopyFailed(String error) {
    return 'Could not open the copy: $error';
  }

  @override
  String get sessionPrClosed => 'Closed';

  @override
  String get sessionPrDraft => 'Draft';

  @override
  String get sessionPrMerged => 'Merged';

  @override
  String get sessionPrNone => 'No PR';

  @override
  String get sessionPrOpen => 'Open';

  @override
  String get sessionProjectBack => 'Back to projects';

  @override
  String get sessionProjectEnter => 'Open';

  @override
  String get sessionProjectNoSessions => 'No sessions in this project';

  @override
  String sessionProjectSessionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0';
  }

  @override
  String get sessionProjectUnavailable => 'Project unavailable';

  @override
  String get sessionPullRequests => 'Pull requests';

  @override
  String sessionResumeFailed(String error) {
    return 'Could not restore the session: $error';
  }

  @override
  String sessionResumeLastFailed(String error) {
    return 'Could not restore the last session: $error';
  }

  @override
  String sessionResumeSubagentFailed(String error) {
    return 'Could not restore the subagent session: $error';
  }

  @override
  String sessionSearchFailed(String error) {
    return 'Search failed: $error';
  }

  @override
  String get sessionSearchMessages => 'Search message content';

  @override
  String get sessionSearchNoFilteredResults =>
      'No results match the current filters';

  @override
  String get sessionSearchPrompt =>
      'Enter keywords to search all session history';

  @override
  String sessionSearchResultCount(int total, int visible) {
    return 'Found $total sessions, showing $visible';
  }

  @override
  String get sessionSearchTitleHint => 'Search session titles…';

  @override
  String get sessionSelectAll => 'Select all';

  @override
  String get sessionSelectDescription =>
      'Open a session from the list to continue working';

  @override
  String get sessionSelectMultiple => 'Select multiple';

  @override
  String get sessionSelectSessions => 'Select sessions';

  @override
  String get sessionSelectTitle => 'Select a session';

  @override
  String sessionSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get sessionServerNotConnected => 'Server not connected';

  @override
  String get sessionSortActivity => 'Recent activity';

  @override
  String get sessionSortCreated => 'Date created';

  @override
  String get sessionSortTitle => 'Sort by';

  @override
  String get sessionSortTokens => 'Token usage';

  @override
  String get sessionStatusAttention => 'Needs attention';

  @override
  String get sessionStatusIdle => 'Idle';

  @override
  String get sessionStatusWorking => 'Working';

  @override
  String get sessionTimeAll => 'All time';

  @override
  String get sessionTitle => 'Sessions';

  @override
  String sessionToolCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tools',
      one: '1 tool',
    );
    return '$_temp0';
  }

  @override
  String get sessionUntitled => 'Untitled session';

  @override
  String sessionWithinDays(int count) {
    return 'Within $count days';
  }

  @override
  String get settingsAppearanceDesc =>
      'Display mode, theme color, and contrast';

  @override
  String get settingsBackHome => 'Back to Home';

  @override
  String get settingsBackendConfigSummary => 'Backend configuration summary';

  @override
  String get settingsBackendConfigSummaryDesc => 'Key configuration values';

  @override
  String get settingsBackendConnectionSection => 'Backend and connection';

  @override
  String settingsBackendRestartFailed(String error) {
    return 'Could not restart backend: $error';
  }

  @override
  String get settingsBackendRestarted => 'Backend restarted';

  @override
  String get settingsCapabilitiesDesc => 'MCP, knowledge, skills, and plugins';

  @override
  String get settingsCapabilitiesTitle => 'Capability management';

  @override
  String get settingsChangeConnection => 'Change connection';

  @override
  String get settingsChangeConnectionDesc =>
      'Edit the server address and API key';

  @override
  String get settingsChangeConnectionQuestion => 'Change connection?';

  @override
  String get settingsChangeConnectionWarning =>
      'The current server connection will be cleared so you can enter a new server address and API key.';

  @override
  String get settingsGroupModels => 'Models and capabilities';

  @override
  String get settingsGroupPersonalization => 'Personalization';

  @override
  String get settingsModelDesc =>
      'Models, conversations, memory context, and keys';

  @override
  String get settingsModelTitle => 'Models and conversations';

  @override
  String get settingsProvidersDesc =>
      'Environment, custom endpoints, OAuth, and toolset providers';

  @override
  String get settingsProvidersTitle => 'Providers and runtime';

  @override
  String get settingsRestartBackend => 'Restart Hermes backend';

  @override
  String get settingsRestartBackendDesc =>
      'Interrupt current work and restart the server process';

  @override
  String get settingsRestartBackendQuestion => 'Restart the Hermes backend?';

  @override
  String get settingsRestartBackendWarning =>
      'Running sessions on the server will be interrupted.';

  @override
  String get settingsSystemConnectionDesc =>
      'Connection, security, terminal, and backend';

  @override
  String get settingsSystemConnectionTitle => 'System and connection';

  @override
  String get settingsTerminalSection => 'Terminal';

  @override
  String get taskAll => 'All';

  @override
  String taskAssigneeFilter(String value) {
    return 'Assignee: $value';
  }

  @override
  String get taskAutoDecompose => 'Automatically decompose tasks';

  @override
  String get taskAutoGenerate => 'Generate automatically';

  @override
  String get taskBoardView => 'Board';

  @override
  String taskBulkFailed(int count) {
    return 'Could not update $count tasks';
  }

  @override
  String get taskClearFilters => 'Clear filters';

  @override
  String get taskCloseSearch => 'Close search';

  @override
  String taskCommentCount(int count) {
    return '$count comments';
  }

  @override
  String get taskConnectBackend => 'Connect to the backend to view tasks';

  @override
  String get taskDefault => 'Default';

  @override
  String get taskDefaultAssignee => 'Default assignee';

  @override
  String get taskFilter => 'Filters';

  @override
  String get taskListView => 'List';

  @override
  String get taskNew => 'New task';

  @override
  String get taskNoDescription => 'No description';

  @override
  String get taskOptions => 'Task options';

  @override
  String get taskOrchestration => 'Orchestration';

  @override
  String get taskOrchestratorProfile => 'Orchestrator profile';

  @override
  String get taskPriorityHigh => 'High';

  @override
  String taskPriorityMeta(String priority) {
    return 'Priority: $priority';
  }

  @override
  String get taskPriorityNormal => 'Normal';

  @override
  String get taskPriorityUrgent => 'Urgent';

  @override
  String taskProfileDescription(String name) {
    return 'Description for $name';
  }

  @override
  String get taskProfileDescriptions => 'Profile descriptions';

  @override
  String get taskSearch => 'Search tasks';

  @override
  String taskSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get taskShowArchived => 'Show archived';

  @override
  String get taskStatusArchived => 'Archived';

  @override
  String get taskStatusBlocked => 'Blocked';

  @override
  String get taskStatusDone => 'Done';

  @override
  String get taskStatusReady => 'Ready';

  @override
  String get taskStatusReview => 'Review';

  @override
  String get taskStatusRunning => 'Running';

  @override
  String get taskStatusScheduled => 'Scheduled';

  @override
  String get taskStatusTodo => 'To do';

  @override
  String get taskStatusTriage => 'Triage';

  @override
  String get taskSwitchBoard => 'Switch board';

  @override
  String taskTenantFilter(String value) {
    return 'Tenant: $value';
  }

  @override
  String get taskTitle => 'Tasks';

  @override
  String get taskUnassigned => 'Unassigned';

  @override
  String get taskWeeklyDelivery => 'Weekly delivery';

  @override
  String get terminalDefaultMonospace => 'Default monospace font';

  @override
  String get terminalFontHint =>
      'Leave empty to use the default monospace font';

  @override
  String get terminalFontPreview => 'Preview  ~/project  git:main  >';

  @override
  String terminalFontSaveFailed(String error) {
    return 'Could not save terminal font: $error';
  }

  @override
  String get terminalFontSaved => 'Terminal font saved';

  @override
  String get terminalFontTitle => 'Terminal font';

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String get updateAppVersion => 'App version';

  @override
  String updateAvailableTitle(String version) {
    return 'Update available: $version';
  }

  @override
  String get updateCheck => 'Check for updates';

  @override
  String get updateCheckDescription =>
      'Check the mobile release manifest for a new version';

  @override
  String get updateCheckFailed => 'Update check failed';

  @override
  String updateCheckUnavailable(String error) {
    return 'Temporarily unavailable: $error';
  }

  @override
  String get updateCurrent => 'You are using the latest version';

  @override
  String updateFound(String version) {
    return 'Version $version is available';
  }

  @override
  String get updateGoToUpdate => 'Update';

  @override
  String updateMinimumVersion(String minimumVersion) {
    return 'Minimum compatible version: $minimumVersion';
  }

  @override
  String get updateNewVersionPublished => 'A new version has been released';

  @override
  String get updateReleaseNotes => 'Release notes';

  @override
  String updateRequiredDefault(String currentVersion, String minimumVersion) {
    return 'Version $currentVersion is below the minimum compatible version $minimumVersion. Update to continue.';
  }

  @override
  String get updateRequiredTitle => 'Hermes Mobile update required';

  @override
  String get updateSectionTitle => 'Updates';

  @override
  String get updateUnsupportedTitle => 'This version is no longer supported';

  @override
  String updateVersionBuild(String version, String build) {
    return 'v$version · build $build';
  }

  @override
  String get workspaceAddPaneTooltip => 'Open pane';

  @override
  String get workspaceApplyLayoutTooltip => 'Apply layout';

  @override
  String get workspaceCloseAllAction => 'Close all';

  @override
  String get workspaceCloseAllDescription =>
      'This only closes the mobile workspace. Sessions and plugin data will not be deleted.';

  @override
  String get workspaceCloseAllQuestion => 'Close all panes?';

  @override
  String get workspaceCloseAllTooltip => 'Close all panes';

  @override
  String get workspaceEmptyDescription =>
      'Open content from a session menu or plugin pane entry';

  @override
  String get workspaceEmptyTitle => 'Workspace is empty';

  @override
  String get workspaceLayoutDefault => 'Default';

  @override
  String get workspaceLayoutFocus => 'Focus';

  @override
  String get workspaceLayoutQuad => 'Quad';

  @override
  String get workspaceLayoutTerminalDeck => 'Terminal deck';

  @override
  String get workspaceLayoutTooltip => 'Adjust pane layout';

  @override
  String get workspaceMergeTabs => 'Merge as tabs';

  @override
  String get workspaceMoveBottom => 'Move down';

  @override
  String get workspaceMoveLeft => 'Move left';

  @override
  String get workspaceMoveRight => 'Move right';

  @override
  String get workspaceMoveTop => 'Move up';

  @override
  String workspaceOpenPluginFailed(String error) {
    return 'Could not open plugin pane: $error';
  }

  @override
  String workspaceOpenSessionFailed(String error) {
    return 'Could not open workspace: $error';
  }

  @override
  String get workspacePaneFiles => 'Files';

  @override
  String get workspacePaneLogs => 'Logs';

  @override
  String get workspacePanePreview => 'Preview';

  @override
  String get workspacePaneReview => 'Review';

  @override
  String get workspacePaneTerminal => 'Terminal';

  @override
  String get workspacePluginUnavailable =>
      'This plugin pane is unavailable. Check that the plugin is enabled.';

  @override
  String workspaceSessionResumeFailed(String error) {
    return 'Could not restore session: $error';
  }

  @override
  String get workspaceTitle => 'Workspace';

  @override
  String statusSemantics(String label) {
    return 'Status: $label';
  }

  @override
  String statusAgentSemantics(String label) {
    return 'Agent status: $label';
  }

  @override
  String statusToolSemantics(String label) {
    return 'Tool status: $label';
  }

  @override
  String get statusIdle => 'Idle';

  @override
  String get statusThinking => 'Thinking';

  @override
  String get statusPlanning => 'Planning';

  @override
  String get statusRunning => 'Running';

  @override
  String get statusWaiting => 'Waiting';

  @override
  String get statusAwaitingApproval => 'Awaiting approval';

  @override
  String get statusPaused => 'Paused';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusStopped => 'Stopped';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get composerUndoInput => 'Undo input';

  @override
  String get composerRedoInput => 'Redo input';

  @override
  String get composerReadOnly => 'Subagent sessions are read-only';

  @override
  String get composerMessageHint => 'Message Hermes...';

  @override
  String composerProfileValue(String value) {
    return 'Profile: $value';
  }

  @override
  String get composerSelectProfile => 'Select profile';

  @override
  String composerWorkspaceValue(String value) {
    return 'Workspace: $value';
  }

  @override
  String get composerSelectWorkspace => 'Select workspace';

  @override
  String composerModelValue(String value) {
    return 'Model: $value';
  }

  @override
  String get composerSelectModel => 'Select model';

  @override
  String composerDifficultyValue(String value) {
    return 'Difficulty: $value';
  }

  @override
  String composerYoloModeValue(String value) {
    return 'Yolo mode: $value';
  }

  @override
  String get composerEnabled => 'Enabled';

  @override
  String get composerDisabled => 'Disabled';

  @override
  String get composerConfigureToolsets => 'Configure toolsets';

  @override
  String get composerCloseEmojiPanel => 'Close emoji panel';

  @override
  String get composerEmoji => 'Emoji';

  @override
  String get composerEditorActions => 'Editor actions';

  @override
  String get composerClearInput => 'Clear input';

  @override
  String get composerEnterSendsTooltip =>
      'Enter sends; Shift+Enter inserts a new line';

  @override
  String get composerEnterNewlineTooltip =>
      'Enter inserts a new line; tap Send to submit';

  @override
  String get composerEnterSends => 'Enter sends';

  @override
  String get composerEnterNewline => 'Enter for new line';

  @override
  String composerRemoveAttachment(String label) {
    return 'Remove attachment: $label';
  }

  @override
  String get composerFolderNotUploaded =>
      'Local folder reference — not sent to the server';

  @override
  String get composerCurrentDefault => 'Current profile default';

  @override
  String get composerUsedDefaultTools => 'Using default tool configuration';

  @override
  String composerAppliedTools(int count) {
    return 'Applied $count tools';
  }

  @override
  String get composerSwitchedToDefault => 'Switched to default configuration';

  @override
  String get composerToolConfiguration => 'Tool configuration';

  @override
  String get composerToolConfigurationDescription =>
      'Use the current profile defaults or select custom toolsets for this session';

  @override
  String get composerUseCurrentDefault => 'Use current profile default';

  @override
  String get composerSelectCustomTools =>
      'Select custom tools for this session';

  @override
  String get composerConfiguredMcpServers => 'Configured MCP servers';

  @override
  String get composerNoConfiguredMcpServers => 'No MCP servers configured';

  @override
  String get composerUseDefault => 'Use default';

  @override
  String get composerApply => 'Apply';

  @override
  String get commonRemove => 'Remove';

  @override
  String get onboardingChatTitle => 'Chat with Hermes';

  @override
  String get onboardingChatDescription =>
      'Start sessions, use voice input, inspect tool calls and reasoning, and continue earlier conversations.';

  @override
  String get onboardingProjectsTitle => 'Projects and sessions';

  @override
  String get onboardingProjectsDescription =>
      'Sessions are grouped by project, Git branch, and worktree, with pinning, archiving, and status filters.';

  @override
  String get onboardingTerminalTitle => 'Terminal and Git';

  @override
  String get onboardingTerminalDescription =>
      'Run terminal commands, review diffs, stage and commit changes, and create pull requests from mobile.';

  @override
  String get onboardingPaletteTitle => 'Command palette';

  @override
  String get onboardingPaletteDescription =>
      'Open the command palette from search or a pull-down gesture to jump to features, recent sessions, or slash commands.';

  @override
  String get onboardingPetTitle => 'Your AI pet';

  @override
  String get onboardingPetDescription =>
      'An AI pet that reacts to task status and can have its own generated appearance.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get onboardingNext => 'Next';

  @override
  String get petGenerateInputRequired =>
      'Enter a description or add a reference image';

  @override
  String get petGenerateEmptyResult => 'No drafts were generated';

  @override
  String petGenerateHatchFailed(Object error) {
    return 'Hatching failed: $error';
  }

  @override
  String petGenerateAdoptFailed(Object error) {
    return 'Adoption failed: $error';
  }

  @override
  String get petGenerateTitle => 'Generate a new pet';

  @override
  String get petGenerateDescribe => 'Describe the pet you want';

  @override
  String get petGeneratePromptHint => 'For example: a cyberpunk mechanical cat';

  @override
  String get petGenerateAddReference => 'Add reference image (optional)';

  @override
  String get petGenerateReferenceHelp =>
      'Every draft will use this image as a reference';

  @override
  String get petGenerateModel => 'Generation model';

  @override
  String get petGenerateAutoSelect => 'Select automatically';

  @override
  String get petGenerateDraftsAction => 'Generate 4 drafts';

  @override
  String petGenerateProgress(Object done, Object total) {
    return 'Generating drafts… ($done/$total)';
  }

  @override
  String get petGenerateChooseDraft => 'Choose your favorite draft';

  @override
  String petGenerateDraftLabel(Object index) {
    return 'Draft $index';
  }

  @override
  String get petGenerateAgain => 'Generate again';

  @override
  String get petGenerateHatch => 'Hatch';

  @override
  String get petGeneratePreparing => 'Preparing…';

  @override
  String petGenerateDrawingProgress(Object done, Object state, Object total) {
    return 'Drawing $state frames ($done/$total)';
  }

  @override
  String petGenerateDrawing(Object state) {
    return 'Drawing $state frames';
  }

  @override
  String get petGenerateComposing => 'Composing sprite sheet…';

  @override
  String get petGenerateSaving => 'Saving…';

  @override
  String get petGenerateHatching => 'Hatching…';

  @override
  String get petGenerateReady => 'Your new pet has hatched!';

  @override
  String get petGenerateNameLabel => 'Give it a name';

  @override
  String get petGenerateDiscard => 'Discard';

  @override
  String get petGenerateAdopt => 'Adopt';

  @override
  String get imageSave => 'Save image';

  @override
  String get imageCopyLink => 'Copy image link';

  @override
  String get imageSavedToGallery => 'Saved to gallery';

  @override
  String get kanbanHomeChannels => 'Home channel notifications';

  @override
  String get kanbanHomeChannelsFailed => 'Could not load home channels';

  @override
  String get kanbanHomeChannelsEmpty => 'No home channels are available';

  @override
  String kanbanUnsupportedAction(Object action) {
    return 'This version does not support the $action action';
  }

  @override
  String chatSessionSaved(Object path) {
    return 'Saved transcript to $path';
  }

  @override
  String get artifactSessionPendingTitle =>
      'Start the session to view artifacts';

  @override
  String get artifactSessionPendingDescription =>
      'Artifacts appear here after this conversation is saved.';

  @override
  String get artifactEmptyTitle => 'No artifacts yet';

  @override
  String get artifactEmptyDescription =>
      'Code, files, links, and images generated in this session appear here.';

  @override
  String artifactFallbackLabel(Object id) {
    return 'Artifact $id';
  }

  @override
  String get artifactDetailTitle => 'Artifact details';

  @override
  String artifactSessionMeta(Object kind, Object session) {
    return '$kind · Session $session';
  }

  @override
  String get artifactMetadata => 'Metadata';

  @override
  String get artifactSaveAs => 'Save as';

  @override
  String get artifactCopyContent => 'Copy content';

  @override
  String artifactExportFailed(String error) {
    return 'Could not export: $error';
  }

  @override
  String get artifactType => 'Type';

  @override
  String get artifactSession => 'Session';

  @override
  String get artifactSessionTitle => 'Session title';

  @override
  String get artifactMessageRow => 'Message row';

  @override
  String get logsAllServers => 'All servers';

  @override
  String get logsLoading => 'Loading logs...';

  @override
  String get webhookEnableFirst => 'Enable the Webhook platform first';

  @override
  String get webhookEnabledRestart =>
      'Webhooks enabled. Restart the Hermes gateway to apply the change.';

  @override
  String get webhookEnabled => 'Webhooks enabled';

  @override
  String webhookEnableFailed(Object error) {
    return 'Could not enable Webhooks: $error';
  }

  @override
  String get webhookLoading => 'Loading Webhooks...';

  @override
  String get webhookEmptyTitle => 'No Webhooks';

  @override
  String get webhookEmptyDescription =>
      'Tap + to create a Webhook for Hermes event delivery.';

  @override
  String get webhookPlatformDisabled =>
      'Webhook platform is disabled · Tap to enable';

  @override
  String get webhookConfigured => 'Configured Webhooks';

  @override
  String get webhookStopped => 'Webhook disabled';

  @override
  String webhookOperationFailed(Object error) {
    return 'Webhook operation failed: $error';
  }

  @override
  String get webhookDeleteTitle => 'Delete Webhook?';

  @override
  String webhookDeletePrompt(Object name) {
    return '$name will be deleted.';
  }

  @override
  String get webhookDeleted => 'Webhook deleted';

  @override
  String webhookDeleteFailed(Object error) {
    return 'Could not delete Webhook: $error';
  }

  @override
  String get webhookEnabledLabel => 'Enabled';

  @override
  String get webhookDisabledLabel => 'Disabled';

  @override
  String get webhookEvents => 'Subscribed events';

  @override
  String get webhookDescription => 'Description';

  @override
  String get webhookPrompt => 'Prompt';

  @override
  String get webhookSkills => 'Skills';

  @override
  String get webhookDeliverTo => 'Delivery target';

  @override
  String get webhookEnableThis => 'Enable this Webhook';

  @override
  String get webhookHotReloadDescription =>
      'Changes are hot-reloaded by the Hermes gateway.';

  @override
  String get webhookNameRequired => 'Enter a name';

  @override
  String get webhookCreated => 'Webhook created';

  @override
  String get webhookSecretOnce =>
      'The signing secret is shown in full only once. Store it now.';

  @override
  String get webhookSecretSaved => 'I stored it';

  @override
  String webhookSaveFailed(Object error) {
    return 'Could not save Webhook: $error';
  }

  @override
  String get webhookNew => 'New Webhook';

  @override
  String get webhookName => 'Name';

  @override
  String get webhookDescriptionOptional => 'Description (optional)';

  @override
  String get webhookEventsComma => 'Subscribed events (comma-separated)';

  @override
  String get webhookPromptOptional => 'Trigger prompt (optional)';

  @override
  String get webhookSkillsComma => 'Skills (comma-separated, optional)';

  @override
  String get webhookDeliveryTarget => 'Delivery target';

  @override
  String get webhookLogOnly => 'Log only';

  @override
  String get webhookSaving => 'Saving...';

  @override
  String commonPartialDataLoadFailed(Object details) {
    return 'Some data could not be loaded: $details';
  }

  @override
  String cronRunsLoadFailed(Object error) {
    return 'Could not load run history: $error';
  }

  @override
  String profilesOptionsLoadFailed(Object details) {
    return 'Some profile editor options could not be loaded: $details';
  }

  @override
  String skillsBulkFailed(Object failed, Object total) {
    return '$failed of $total skill updates failed.';
  }

  @override
  String petCleanupFailed(Object error) {
    return 'Could not clean up the generation task: $error';
  }

  @override
  String get skillsTitle => 'Skills';

  @override
  String get skillsMarketplace => 'Skill marketplace';

  @override
  String get skillsEnableAll => 'Enable all';

  @override
  String get skillsDisableAll => 'Disable all';

  @override
  String skillsToggleFailed(Object error) {
    return 'Could not update skill: $error';
  }

  @override
  String get skillsSearchHint => 'Search skills...';

  @override
  String skillsEnabledCount(Object enabled, Object total) {
    return 'Enabled $enabled/$total';
  }

  @override
  String get skillsLoading => 'Loading skills...';

  @override
  String get skillsEmptyTitle => 'No skills';

  @override
  String get skillsEmptyDescription => 'This agent has no available skills.';

  @override
  String get skillsUncategorized => 'Uncategorized';

  @override
  String get skillsNoMatches => 'No matching skills';

  @override
  String skillsUsageCount(Object count) {
    return 'Used $count times';
  }

  @override
  String get skillsLearned => 'Learned';

  @override
  String get skillsBuiltIn => 'Built in';

  @override
  String get skillsProvenanceMarketplace => 'Marketplace';

  @override
  String get skillsSaved => 'Saved';

  @override
  String skillsSaveFailed(Object error) {
    return 'Could not save skill: $error';
  }

  @override
  String get skillsArchiveQuestion => 'Archive skill?';

  @override
  String skillsArchivePrompt(Object name) {
    return 'Archive the learned skill \"$name\"? You can undo this later.';
  }

  @override
  String get skillsArchive => 'Archive';

  @override
  String get skillsArchived => 'Archived';

  @override
  String skillsArchiveFailed(Object error) {
    return 'Could not archive skill: $error';
  }

  @override
  String get skillsContent => 'Content';

  @override
  String get skillsNoContent => '(No content)';

  @override
  String get skillsCancelEdit => 'Cancel editing';

  @override
  String get skillsSaving => 'Saving...';

  @override
  String get historyTitle => 'History';

  @override
  String historyResumeFailed(Object error) {
    return 'Could not resume session: $error';
  }

  @override
  String get historyManageSessions => 'Manage sessions';

  @override
  String get historyHideArchived => 'Hide archived';

  @override
  String get historyShowArchived => 'Show archived';

  @override
  String get historySelectTitle => 'Select a session';

  @override
  String get historySelectDescription =>
      'Select a session on the left to view its summary and management actions.';

  @override
  String get historyLoading => 'Loading session history...';

  @override
  String get historySearchHint =>
      'Search titles, content, or working directories';

  @override
  String get historyClearSearch => 'Clear search';

  @override
  String get historyEmpty => 'No sessions yet';

  @override
  String get historyNoMatches => 'No matching sessions';

  @override
  String get historyLoadMore => 'Load more';

  @override
  String historyLoadMoreCount(Object loaded, Object total) {
    return 'Load more ($loaded/$total)';
  }

  @override
  String get historyPinned => 'Pinned';

  @override
  String get historyToday => 'Today';

  @override
  String get historyYesterday => 'Yesterday';

  @override
  String get historyThisWeek => 'This week';

  @override
  String get historyLastWeek => 'Last week';

  @override
  String get historyEarlier => 'Earlier';

  @override
  String get historyCollapseChildren => 'Collapse child sessions';

  @override
  String get historyExpandChildren => 'Expand child sessions';

  @override
  String get historySessionActions => 'Session actions';

  @override
  String get historyManageSession => 'Manage session';

  @override
  String get historyUntitled => 'Untitled session';

  @override
  String historyMessageCount(Object count) {
    return '$count messages';
  }

  @override
  String get historyDeleteQuestion => 'Delete session?';

  @override
  String historyDeletePrompt(Object title) {
    return '\"$title\" will be permanently deleted. This cannot be undone.';
  }

  @override
  String historyDeleteFailed(Object error) {
    return 'Could not delete session: $error';
  }

  @override
  String historyRenameFailed(Object error) {
    return 'Could not rename session: $error';
  }

  @override
  String historyCompressed(Object count) {
    return 'Session compressed ($count messages removed)';
  }

  @override
  String historyCompressFailed(Object error) {
    return 'Could not compress session: $error';
  }

  @override
  String historyArchiveFailed(Object error) {
    return 'Could not archive session: $error';
  }

  @override
  String historyUnarchiveFailed(Object error) {
    return 'Could not unarchive session: $error';
  }

  @override
  String get historyManagement => 'Session management';

  @override
  String get historySaveTitle => 'Save title';

  @override
  String historyContextUsage(Object maximum, Object percent, Object used) {
    return 'Context usage: $used / $maximum$percent';
  }

  @override
  String historyPercent(Object percent) {
    return ' ($percent%)';
  }

  @override
  String get historyCompress => 'Compress session';

  @override
  String get historyArchive => 'Archive';

  @override
  String get historyUnarchive => 'Unarchive';

  @override
  String get cronTitle => 'Scheduled tasks';

  @override
  String get cronLoading => 'Loading scheduled tasks...';

  @override
  String get cronEmptyTitle => 'No scheduled tasks yet';

  @override
  String get cronEmptyDescription =>
      'Create an automated task that runs on a schedule.';

  @override
  String get cronNew => 'New task';

  @override
  String cronNextRun(Object time) {
    return 'Next run: $time';
  }

  @override
  String get cronRunHistory => 'Run history';

  @override
  String cronRunHistoryTitle(Object name) {
    return 'Run history · $name';
  }

  @override
  String get cronNoRuns => 'No run history';

  @override
  String get cronTriggerNow => 'Run now';

  @override
  String get cronTriggered => 'Task triggered';

  @override
  String cronTriggerFailed(Object error) {
    return 'Could not trigger task: $error';
  }

  @override
  String cronUpdateFailed(Object error) {
    return 'Could not update task: $error';
  }

  @override
  String get cronDeleteQuestion => 'Delete scheduled task?';

  @override
  String cronDeletePrompt(Object name) {
    return '\"$name\" will be deleted.';
  }

  @override
  String cronDeleteFailed(Object error) {
    return 'Could not delete task: $error';
  }

  @override
  String get cronStateCompleted => 'Completed';

  @override
  String get cronStateDisabled => 'Disabled';

  @override
  String get cronStateEnabled => 'Enabled';

  @override
  String get cronStateError => 'Error';

  @override
  String get cronStatePaused => 'Paused';

  @override
  String get cronStateRunning => 'Running';

  @override
  String get cronStateScheduled => 'Scheduled';

  @override
  String cronModelsLoadFailed(Object error) {
    return 'Could not load model options: $error';
  }

  @override
  String cronBlueprintsLoadFailed(Object error) {
    return 'Could not load automation templates: $error';
  }

  @override
  String cronTargetsLoadFailed(Object error) {
    return 'Could not load delivery targets: $error';
  }

  @override
  String get cronPresetMinute => 'Every minute';

  @override
  String get cronPresetHour => 'Hourly';

  @override
  String get cronPresetDay => 'Daily at 09:00';

  @override
  String get cronPresetWeek => 'Mondays at 09:00';

  @override
  String get cronPresetMonth => 'Monthly on day 1 at 09:00';

  @override
  String get cronPresetCustom => 'Custom';

  @override
  String get cronPresetMinuteHint => 'Runs every minute';

  @override
  String get cronPresetHourHint => 'Runs at the start of every hour';

  @override
  String get cronPresetDayHint => 'Runs every day at 09:00';

  @override
  String get cronPresetWeekHint => 'Runs every Monday at 09:00';

  @override
  String get cronPresetMonthHint => 'Runs on day 1 of every month at 09:00';

  @override
  String get cronPromptAndExpressionRequired =>
      'Enter task instructions and a Cron expression.';

  @override
  String get cronExpressionRequired => 'Enter a Cron expression.';

  @override
  String get cronPromptRequired => 'Enter task instructions.';

  @override
  String cronSaveFailed(Object error) {
    return 'Could not save task: $error';
  }

  @override
  String get cronCreateTitle => 'New scheduled task';

  @override
  String get cronEditTitle => 'Edit scheduled task';

  @override
  String get cronStartFromTemplate => 'Start from a template';

  @override
  String get cronScheduling => 'Scheduling...';

  @override
  String get cronScheduleAutomation => 'Schedule automation';

  @override
  String get cronScriptOnlyDescription =>
      'This is a script-only task. You can change its name, schedule, delivery targets, and the script itself; model settings don\'t apply.';

  @override
  String get cronScriptLabel => 'Script';

  @override
  String cronLastRun(Object time) {
    return 'Last run: $time';
  }

  @override
  String get cronRunScheduledAt => 'Scheduled at';

  @override
  String get cronRunStartedAt => 'Started at';

  @override
  String get cronRunFinishedAt => 'Finished at';

  @override
  String get cronRunStatus => 'Status';

  @override
  String get cronRunOutput => 'Output';

  @override
  String get cronRunDetailTitle => 'Run succeeded';

  @override
  String get cronRunDetailFailedTitle => 'Run failed';

  @override
  String get cronNameOptional => 'Name (optional)';

  @override
  String get cronDeliverResultsTo => 'Deliver results to';

  @override
  String get cronTaskModel => 'Task model';

  @override
  String get cronUseGlobalDefault => 'Use global default';

  @override
  String cronSavedModel(Object model) {
    return '$model (currently saved)';
  }

  @override
  String get cronPromptLabel => 'Task instructions (prompt)';

  @override
  String get cronFrequency => 'Frequency';

  @override
  String get cronExpression => 'Cron expression';

  @override
  String get cronExpressionHint => 'minute hour day month weekday';

  @override
  String get cronSaving => 'Saving...';

  @override
  String get cronThisDevice => 'This device';

  @override
  String get cronConfigureHomeChannelFirst => 'Configure a home channel first';

  @override
  String get profilesTitle => 'Agent Profiles';

  @override
  String get profilesLoading => 'Loading profiles...';

  @override
  String get profilesEmptyTitle => 'No profiles';

  @override
  String get profilesEmptyDescription => 'Create your first agent profile.';

  @override
  String get profilesNew => 'New profile';

  @override
  String get profilesImport => 'Import profile';

  @override
  String get profilesExport => 'Export profile';

  @override
  String get profilesDuplicate => 'Duplicate profile';

  @override
  String get profilesEditSoul => 'Edit SOUL.md';

  @override
  String get profilesSetupCommand => 'Terminal launch command';

  @override
  String profilesSaveFailed(Object error) {
    return 'Could not save profile: $error';
  }

  @override
  String get profilesCreated => 'Profile created';

  @override
  String get profilesSaved => 'Profile saved';

  @override
  String profilesCopyName(Object name) {
    return '$name copy';
  }

  @override
  String profilesDuplicateFailed(Object error) {
    return 'Could not duplicate profile: $error';
  }

  @override
  String get profilesDuplicated => 'Profile duplicated';

  @override
  String profilesDeleteQuestion(Object name) {
    return 'Delete profile \"$name\"?';
  }

  @override
  String get profilesDeleteActiveWarning => 'This profile is currently active.';

  @override
  String get profilesDeleteWarning => 'This action cannot be undone.';

  @override
  String profilesDeleteFailed(Object error) {
    return 'Could not delete profile: $error';
  }

  @override
  String get profilesDeleted => 'Profile deleted';

  @override
  String profilesSwitchFailed(Object error) {
    return 'Could not switch profile: $error';
  }

  @override
  String profilesSwitchedTo(Object name) {
    return 'Switched to \"$name\"';
  }

  @override
  String get profilesSoulHint =>
      'Describe this agent\'s identity, behavior, and communication style';

  @override
  String get profilesSoulSaved => 'SOUL.md saved';

  @override
  String profilesSoulFailed(Object error) {
    return 'SOUL.md operation failed: $error';
  }

  @override
  String get profilesCopy => 'Copy';

  @override
  String profilesSetupCommandFailed(Object error) {
    return 'Could not read launch command: $error';
  }

  @override
  String get profilesExported => 'Profile exported';

  @override
  String profilesExportFailed(Object error) {
    return 'Could not export profile: $error';
  }

  @override
  String profilesImported(Object name) {
    return 'Imported $name';
  }

  @override
  String profilesImportFailed(Object error) {
    return 'Could not import profile: $error';
  }

  @override
  String profilesParameters(
    Object activeSuffix,
    Object maxTokens,
    Object temperature,
  ) {
    return 'temp $temperature · max_tokens $maxTokens$activeSuffix';
  }

  @override
  String get profilesCurrentSuffix => ' · active';

  @override
  String get profilesActive => 'Active';

  @override
  String get profilesActivate => 'Activate';

  @override
  String get profilesNameRequired => 'Enter a profile name.';

  @override
  String get profilesCreateTitle => 'New profile';

  @override
  String get profilesEditTitle => 'Edit profile';

  @override
  String get profilesProvider => 'Provider';

  @override
  String get profilesModel => 'Model';

  @override
  String get profilesSystemPrompt => 'System prompt';

  @override
  String get profilesDescriptionOptional => 'Description (optional)';

  @override
  String get profilesTools => 'Tools';

  @override
  String get profilesDeselectAll => 'Deselect all';

  @override
  String get profilesSelectAll => 'Select all';

  @override
  String get profilesSetActive => 'Set as active profile';

  @override
  String get memoryTitle => 'Memory';

  @override
  String get memoryLoading => 'Loading memory status...';

  @override
  String memorySwitchFailed(Object error) {
    return 'Could not switch provider: $error';
  }

  @override
  String get memoryResetScope => 'Choose what to reset';

  @override
  String get memoryResetScopeDescription =>
      'Only the selected memory files will be deleted.';

  @override
  String get memoryAll => 'All memory';

  @override
  String get memoryAllFiles => 'MEMORY.md and USER.md';

  @override
  String get memoryLongTerm => 'Long-term memory';

  @override
  String get memoryLongTermFile => 'MEMORY.md only';

  @override
  String get memoryUser => 'User memory';

  @override
  String get memoryUserFile => 'USER.md only';

  @override
  String get memoryResetQuestion => 'Reset memory?';

  @override
  String get memoryResetWarning => 'Deleted memory cannot be recovered.';

  @override
  String get memoryNothingDeleted => 'There were no memory files to delete.';

  @override
  String memoryDeleted(Object files) {
    return 'Deleted $files';
  }

  @override
  String memoryResetFailed(Object error) {
    return 'Could not reset memory: $error';
  }

  @override
  String memoryCuratorUpdateFailed(Object error) {
    return 'Could not update Curator: $error';
  }

  @override
  String get memoryCuratorStarted => 'Curator started';

  @override
  String memoryCuratorRunFailed(Object error) {
    return 'Could not run Curator: $error';
  }

  @override
  String get memoryCurrentProvider => 'Current memory provider';

  @override
  String get memoryDisabled => 'Disabled';

  @override
  String get memoryEnabled => 'Enabled';

  @override
  String get memoryProviders => 'Providers';

  @override
  String get memoryNoProviders => 'No providers available';

  @override
  String get memoryBuiltInFiles => 'Built-in memory files';

  @override
  String get memoryReset => 'Reset memory';

  @override
  String get memoryInUse => 'In use';

  @override
  String get memoryConfigured => 'Configured';

  @override
  String memoryConfigureProvider(Object name) {
    return 'Configure $name';
  }

  @override
  String memoryEnableProvider(Object name) {
    return 'Enable $name';
  }

  @override
  String get memoryCuratorLoading => 'Loading Curator status...';

  @override
  String get memoryCuratorUnavailable => 'Curator unavailable';

  @override
  String get memoryPaused => 'Paused';

  @override
  String memoryCuratorInterval(Object hours) {
    return 'Checks every $hours hours';
  }

  @override
  String memoryCuratorLastRun(Object time) {
    return 'Last run $time';
  }

  @override
  String get memoryResume => 'Resume';

  @override
  String get memoryPause => 'Pause';

  @override
  String get memoryRunNow => 'Run now';

  @override
  String memoryInvalidJson(Object field) {
    return '$field is not valid JSON';
  }

  @override
  String memoryInvalidNumber(Object field) {
    return '$field is not a valid number';
  }

  @override
  String get memoryProviderSaved => 'Provider configuration saved';

  @override
  String memoryProviderSaveFailed(Object error) {
    return 'Could not save provider configuration: $error';
  }

  @override
  String get memoryOAuthTimeout => 'Connection timed out. Try again.';

  @override
  String get memoryCurrentProfile => 'Current profile';

  @override
  String memoryProfile(Object name) {
    return 'Profile: $name';
  }

  @override
  String get memoryProviderConfigLoading => 'Loading provider configuration...';

  @override
  String get memoryNoProviderConfig =>
      'This provider has no additional settings';

  @override
  String get memoryViewProviderDocs => 'View provider documentation';

  @override
  String get memorySaving => 'Saving...';

  @override
  String get memorySaveConfig => 'Save configuration';

  @override
  String get memoryAccountConnected => 'Account connected';

  @override
  String get memoryConnectAccount => 'Connect provider account';

  @override
  String get memoryReconnect => 'Reconnect';

  @override
  String get memoryConnect => 'Connect';

  @override
  String get memoryKeepSecretHint => 'Leave blank to keep the current value';

  @override
  String get memoryProviderSetup => 'Provider runtime';

  @override
  String get memoryProviderSetupDescription =>
      'This provider needs dependencies installed in Hermes Server before it can run.';

  @override
  String get memoryPythonDependencies => 'Python dependencies';

  @override
  String get memoryRequiredEnvironment => 'Required environment values';

  @override
  String get memoryInstallDependencies => 'Install provider dependencies';

  @override
  String get memoryInstallingDependencies => 'Installing...';

  @override
  String get memorySetupFinished => 'Provider dependencies installed';

  @override
  String get memorySetupFailed =>
      'Some provider dependencies failed to install. Review the results.';

  @override
  String memorySetupError(Object error) {
    return 'Could not install provider dependencies: $error';
  }

  @override
  String agentOpenBotFailed(Object error) {
    return 'Could not open Bot Chat: $error';
  }

  @override
  String get agentNewGroup => 'New group chat';

  @override
  String get agentEditGroup => 'Edit group chat';

  @override
  String get agentGroupName => 'Group chat name';

  @override
  String get agentSelectMembers => 'Select members';

  @override
  String agentGroupMemberCount(Object count, Object max) {
    return '$count/$max selected';
  }

  @override
  String get agentSearchBots => 'Search bots';

  @override
  String get agentSearchNoMatches => 'No matching bots';

  @override
  String agentGroupSaveFailed(Object error) {
    return 'Could not save group chat: $error';
  }

  @override
  String agentBotThinking(Object name) {
    return '$name is thinking';
  }

  @override
  String agentBotPaused(Object name) {
    return '$name paused';
  }

  @override
  String get agentStartGroupChat => 'Start the group chat';

  @override
  String agentReplyTo(Object id) {
    return 'Reply to #$id';
  }

  @override
  String get agentSendToRoom => 'Send to room';

  @override
  String get agentMentionHint =>
      'Use @name to target a member or @all to notify everyone';

  @override
  String agentAttachmentTooLarge(Object name) {
    return '$name exceeds 20 MB';
  }

  @override
  String agentAttachFailed(Object error) {
    return 'Could not add attachment: $error';
  }

  @override
  String agentGroupSendFailed(Object error) {
    return 'Could not send group message: $error';
  }

  @override
  String get agentAppendMessage => 'Add message';

  @override
  String get agentAwaitingApproval => 'Awaiting approval';

  @override
  String get agentNeedsInformation => 'More information needed';

  @override
  String get agentRespond => 'Respond';

  @override
  String agentMemberRequest(Object name) {
    return 'Request from $name';
  }

  @override
  String get agentAllowOperationQuestion => 'Allow this operation?';

  @override
  String get agentDeny => 'Deny';

  @override
  String get agentAlwaysAllow => 'Always allow';

  @override
  String get agentAllow => 'Allow';

  @override
  String get agentCustomAnswer => 'Custom answer';

  @override
  String get agentEnterAnswer => 'Enter an answer';

  @override
  String agentRespondFailed(Object error) {
    return 'Could not respond: $error';
  }

  @override
  String get agentLoading => 'Loading agent status...';

  @override
  String get agentNoData => 'No data';

  @override
  String get agentBotDirectoryTitle => 'Bot Center';

  @override
  String agentBotDirectorySummary(int bots, int groups) {
    return '$bots bots · $groups groups';
  }

  @override
  String get agentStopped => 'Stopped';

  @override
  String get agentGroupChatsSection => 'Group chats';

  @override
  String get agentIndividualBotsSection => 'Bots';

  @override
  String get agentManageBots => 'Manage or create Bots';

  @override
  String get agentBotRoutinesMenuItem => 'Bot routines';

  @override
  String get agentBotsEmptyTitle => 'No bots yet';

  @override
  String get agentBotsEmptyDescription =>
      'A bot is a standalone chat identity tied to a profile. Create a profile from the top-right icon to get started.';

  @override
  String get agentMentionAll => 'Everyone';

  @override
  String get agentRefreshRoster => 'Refresh Bot roster';

  @override
  String agentGroupSummary(Object count, Object runningSuffix) {
    return '$count Bots · across connections$runningSuffix';
  }

  @override
  String get agentRunningSuffix => ' · running';

  @override
  String agentDeleteGroupQuestion(Object name) {
    return 'Delete group chat \"$name\"?';
  }

  @override
  String get agentDeleteGroupWarning =>
      'The group history will be permanently deleted. This cannot be undone.';

  @override
  String agentDeleteGroupFailed(Object error) {
    return 'Could not delete group chat: $error';
  }

  @override
  String get agentDeleteGroup => 'Delete group chat';

  @override
  String agentDeleteBotQuestion(Object name) {
    return 'Delete Bot \"$name\"?';
  }

  @override
  String agentBotOperationFailed(Object error) {
    return 'Bot operation failed: $error';
  }

  @override
  String get agentDuplicateBot => 'Duplicate Bot';

  @override
  String get agentDeleteBot => 'Delete Bot';

  @override
  String get agentGateway => 'Gateway';

  @override
  String get agentActiveAgents => 'Active agents';

  @override
  String get agentBusy => 'Busy';

  @override
  String get agentYes => 'Yes';

  @override
  String get agentNo => 'No';

  @override
  String get agentModelSection => 'Model';

  @override
  String get agentCurrentModel => 'Current model';

  @override
  String get agentProvider => 'Provider';

  @override
  String get agentContextLength => 'Context length';

  @override
  String get agentSessionModel => 'Session model';

  @override
  String get agentRuntimeSection => 'Runtime';

  @override
  String get agentType => 'Type';

  @override
  String get agentSourceRoot => 'Source root';

  @override
  String get agentHermesHome => 'Hermes home';

  @override
  String get agentServerVersion => 'Server version';

  @override
  String get agentCapability => 'Capability';

  @override
  String get agentRestarting => 'Restarting...';

  @override
  String botRoutineUpdateFailed(Object error) {
    return 'Could not update routine: $error';
  }

  @override
  String get botRoutineDeleteQuestion => 'Delete routine?';

  @override
  String botRoutineDeletePrompt(Object title) {
    return '\"$title\" and its schedule will be permanently deleted.';
  }

  @override
  String get botRoutineStatus => 'Status';

  @override
  String get botRoutinePaused => 'Paused';

  @override
  String get botRoutineSchedule => 'Schedule';

  @override
  String get botRoutineRawSchedule => 'Raw schedule';

  @override
  String get botRoutineRepeatCount => 'Repeat count';

  @override
  String get botRoutineNextRun => 'Next run';

  @override
  String get botRoutineLastRun => 'Last run';

  @override
  String get botRoutineLastResult => 'Last result';

  @override
  String get botRoutineDeliverTo => 'Deliver to';

  @override
  String get botRoutineModel => 'Model';

  @override
  String get botRoutineWorkdir => 'Working directory';

  @override
  String get botRoutineInstruction => 'Instruction';

  @override
  String get botRoutineLegacyWarning =>
      'This legacy task was paused for safety. Delete it and create it again before running it.';

  @override
  String botRoutineTitle(Object name) {
    return '$name · Routines';
  }

  @override
  String commonBytes(Object count) {
    return '$count bytes';
  }

  @override
  String get botRoutineLoading => 'Loading routines...';

  @override
  String get botRoutineEmptyTitle => 'No routines yet';

  @override
  String botRoutineEmptyDescription(Object name) {
    return 'Create a dedicated scheduled task for $name.';
  }

  @override
  String get botRoutineNew => 'New routine';

  @override
  String botRoutineNext(Object time) {
    return 'Next $time';
  }

  @override
  String get botRoutineLegacyPaused => 'Legacy task, paused safely';

  @override
  String get botRoutineDelete => 'Delete routine';

  @override
  String botRoutineScheduleOnce(Object duration) {
    return 'Once · in $duration';
  }

  @override
  String botRoutineScheduleEvery(Object duration) {
    return 'Every $duration';
  }

  @override
  String get botRoutineScheduleHourly => 'At the start of every hour';

  @override
  String get botRoutineScheduleDaily => 'Daily at 09:00';

  @override
  String get botRoutineScheduleWeekdays => 'Weekdays at 09:00';

  @override
  String get botRoutineScheduleWeekly => 'Mondays at 09:00';

  @override
  String get botRoutineScheduleMonthly => 'Monthly on day 1 at 09:00';

  @override
  String get botRoutineRequiredFields =>
      'Enter a name, instruction, and schedule.';

  @override
  String botRoutineCreateTitle(Object name) {
    return 'New routine · $name';
  }

  @override
  String get botRoutineInstructionLabel => 'Instruction to run each time';

  @override
  String get botRoutineFrequencyOnce => 'Once, after a delay';

  @override
  String get botRoutineFrequencyHourly => 'Hourly';

  @override
  String get botRoutineFrequencyDaily => 'Daily';

  @override
  String get botRoutineFrequencyWeekdays => 'Weekdays';

  @override
  String get botRoutineFrequencyWeekly => 'Weekly';

  @override
  String get botRoutineFrequencyMonthly => 'Monthly';

  @override
  String get botRoutineFrequencyInterval => 'Fixed interval';

  @override
  String get botRoutineFrequencyAdvanced => 'Advanced expression';

  @override
  String get botRoutineTime => 'Time (HH:mm)';

  @override
  String get botRoutineWeekday => 'Weekday';

  @override
  String get botRoutineMonday => 'Monday';

  @override
  String get botRoutineTuesday => 'Tuesday';

  @override
  String get botRoutineWednesday => 'Wednesday';

  @override
  String get botRoutineThursday => 'Thursday';

  @override
  String get botRoutineFriday => 'Friday';

  @override
  String get botRoutineSaturday => 'Saturday';

  @override
  String get botRoutineSunday => 'Sunday';

  @override
  String get botRoutineDayOfMonth => 'Day of month';

  @override
  String get botRoutineValue => 'Value';

  @override
  String get botRoutineUnit => 'Unit';

  @override
  String get botRoutineMinutes => 'Minutes';

  @override
  String get botRoutineHours => 'Hours';

  @override
  String get botRoutineDays => 'Days';

  @override
  String get botRoutineAdvancedExpression => 'Cron or every Nm/Nh/Nd';

  @override
  String botRoutineWillSaveAs(Object schedule) {
    return 'Will be saved as: $schedule';
  }

  @override
  String get botRoutineRepeatLimit =>
      'Maximum runs (leave blank to keep running)';

  @override
  String get botRoutineContinuity => 'Continuity';

  @override
  String get botRoutineContinuityDescription =>
      'Each run can read the previous output from this task.';

  @override
  String botRoutineSendToBot(Object name) {
    return 'Send to $name\'s Bot Chat';
  }

  @override
  String get botRoutineSendToBotDescription =>
      'The Bot will read the result and continue responding.';

  @override
  String get botRoutineCreating => 'Creating...';

  @override
  String get botRoutineCreate => 'Create routine';

  @override
  String get mcpTitle => 'MCP servers';

  @override
  String mcpOperationFailed(Object error) {
    return 'Operation failed: $error';
  }

  @override
  String get mcpPersistenceFailed =>
      'The server did not persist the MCP configuration change.';

  @override
  String mcpTestSuccess(Object prompts, Object resources, Object tools) {
    return 'Connected: $tools tools, $prompts prompts, $resources resources';
  }

  @override
  String mcpTestConnectionFailed(Object error) {
    return 'Connection failed: $error';
  }

  @override
  String mcpTestFailed(Object error) {
    return 'Test failed: $error';
  }

  @override
  String mcpReloadFailed(Object error) {
    return 'Configuration was saved, but MCP hot reload failed for the active session: $error';
  }

  @override
  String get mcpImportUnrecognized =>
      'Could not recognize the pasted content. Check its format.';

  @override
  String mcpImportDetected(Object count) {
    return 'Detected $count servers';
  }

  @override
  String mcpImportAllQuestion(Object names) {
    return 'Add all of these servers?\n\n$names';
  }

  @override
  String get mcpAddAll => 'Add all';

  @override
  String mcpServersAdded(Object count) {
    return 'Added $count servers';
  }

  @override
  String mcpServersPartiallyAdded(Object added, Object failed) {
    return 'Added $added; $failed failed';
  }

  @override
  String get mcpAddServer => 'Add MCP server';

  @override
  String get mcpPasteImport =>
      'Paste import (mcp.json / command / claude mcp add / URL)';

  @override
  String get mcpParse => 'Parse';

  @override
  String get mcpRemoteUrl => 'Remote URL';

  @override
  String get mcpLocalStdio => 'Local stdio';

  @override
  String get mcpServerUrl => 'Server URL';

  @override
  String get mcpCommand => 'Command';

  @override
  String get mcpArgumentsOnePerLine => 'Arguments (one per line)';

  @override
  String get mcpEnvironmentJson => 'Environment variables (JSON)';

  @override
  String get mcpAuthentication => 'Authentication';

  @override
  String get mcpNoAuthentication => 'No authentication';

  @override
  String get mcpEnvironmentMustBeJson =>
      'Environment variables must be a JSON object.';

  @override
  String get mcpServerAdded => 'MCP server added';

  @override
  String mcpAddFailed(Object error) {
    return 'Could not add server: $error';
  }

  @override
  String mcpDeleteQuestion(Object name) {
    return 'Delete $name?';
  }

  @override
  String get mcpDeleteWarning =>
      'This server will be permanently removed from the Hermes MCP configuration.';

  @override
  String mcpDeleteFailed(Object error) {
    return 'Could not delete server: $error';
  }

  @override
  String mcpReadConfigFailed(Object error) {
    return 'Could not read configuration: $error';
  }

  @override
  String mcpEditServer(Object name) {
    return 'Edit $name';
  }

  @override
  String mcpInvalidJson(Object error) {
    return 'Not a valid JSON object: $error';
  }

  @override
  String mcpServerSaved(Object name) {
    return '$name saved';
  }

  @override
  String mcpSaveFailed(Object error) {
    return 'Could not save server: $error';
  }

  @override
  String mcpToolToggleFailed(Object error) {
    return 'Could not toggle tool: $error';
  }

  @override
  String get mcpOAuthStartFailed => 'OAuth could not start';

  @override
  String get mcpOAuthMissingUrl =>
      'The OAuth server did not return an authorization URL.';

  @override
  String get mcpBrowserOpenFailed => 'Could not open the system browser.';

  @override
  String mcpCompleteAuthorization(Object name) {
    return 'Complete authorization for $name in the browser.';
  }

  @override
  String get mcpOAuthAuthorizationFailed => 'OAuth authorization failed';

  @override
  String mcpAuthorizationSucceeded(Object name, Object tools) {
    return '$name authorized; found $tools tools';
  }

  @override
  String mcpOAuthFailed(Object error) {
    return 'OAuth failed: $error';
  }

  @override
  String mcpInstallTitle(Object name) {
    return 'Install $name';
  }

  @override
  String get mcpRequired => 'Required';

  @override
  String get mcpOptional => 'Optional';

  @override
  String get mcpRequiredCredentials => 'Enter all required credentials.';

  @override
  String get mcpReinstall => 'Reinstall';

  @override
  String get mcpInstall => 'Install';

  @override
  String mcpInstallExitCode(Object code) {
    return 'Installer exited with code $code';
  }

  @override
  String mcpInstallComplete(Object name) {
    return '$name installed';
  }

  @override
  String mcpInstallFailed(Object error) {
    return 'Installation failed: $error';
  }

  @override
  String get mcpViewLogs => 'View logs';

  @override
  String get mcpLoading => 'Loading MCP servers...';

  @override
  String get mcpConfiguredServers => 'Configured servers';

  @override
  String get mcpNoConfiguredServers => 'No MCP servers configured';

  @override
  String get mcpDescription =>
      'MCP connects agents to external tools and data sources.';

  @override
  String mcpAvailableCatalog(Object count) {
    return 'Available catalog ($count)';
  }

  @override
  String mcpToolCount(Object count) {
    return '$count tools';
  }

  @override
  String mcpUsage30Days(Object count) {
    return '$count uses / 30 days';
  }

  @override
  String get mcpTestConnection => 'Test connection';

  @override
  String get mcpEditConfiguration => 'Edit configuration';

  @override
  String get mcpOAuthAuthorization => 'OAuth authorization';

  @override
  String get mcpInstalledEnabled => 'Installed and enabled';

  @override
  String get mcpInstalledDisabled => 'Installed but disabled';

  @override
  String get commandCenterTitle => 'Command Center';

  @override
  String get commandStatusTab => 'Status';

  @override
  String get commandUsageTab => 'Usage';

  @override
  String get commandMaintenanceTab => 'Maintenance';

  @override
  String commandStatusLoadFailed(Object error) {
    return 'Could not load status: $error';
  }

  @override
  String commandLogsLoadFailed(Object error) {
    return 'Could not load logs: $error';
  }

  @override
  String get commandRestartWarning =>
      'This restarts the Hermes backend process and may interrupt active turns.';

  @override
  String commandRestartResult(Object result) {
    return 'Restart result: $result';
  }

  @override
  String get commandNoLogs => '(No logs)';

  @override
  String get commandBackendProcess => 'Backend process';

  @override
  String get commandStopped => 'Stopped';

  @override
  String get commandLiveLogs => 'Live logs';

  @override
  String get commandDiagnostics => 'Diagnostic details';

  @override
  String get commandSystemStatus => 'System status';

  @override
  String get commandNoStatusData => 'No status data';

  @override
  String commandUsageLoadFailed(Object error) {
    return 'Could not load usage: $error';
  }

  @override
  String commandDays(Object count) {
    return '$count days';
  }

  @override
  String get commandSessions => 'Sessions';

  @override
  String get commandApiCalls => 'API calls';

  @override
  String get commandTokensInOut => 'Tokens (in/out)';

  @override
  String get commandDailyUsage => 'Daily usage';

  @override
  String get commandNoUsageData => 'No usage data';

  @override
  String get commandTopModels => 'Top models';

  @override
  String get commandTopSkills => 'Top skills';

  @override
  String commandUseCount(Object count) {
    return '$count uses';
  }

  @override
  String commandChartTooltip(Object day, Object input, Object output) {
    return '$day\nInput $input / Output $output';
  }

  @override
  String get commandInputTokens => 'Input tokens';

  @override
  String get commandOutputTokens => 'Output tokens';

  @override
  String commandStarting(Object label) {
    return 'Starting $label...';
  }

  @override
  String get commandMissingActionName =>
      'The backend did not return an action name.';

  @override
  String get commandNoOutput => '(No output yet)';

  @override
  String commandActionExitFailed(Object code, Object label) {
    return '$label failed (exit code $code)';
  }

  @override
  String commandActionComplete(Object label) {
    return '$label completed';
  }

  @override
  String commandLogError(Object error, Object logs) {
    return '$logs\n\nError: $error';
  }

  @override
  String commandActionFailed(Object error, Object label) {
    return '$label failed: $error';
  }

  @override
  String commandDebugShareFailed(Object error) {
    return 'Could not generate debug share: $error';
  }

  @override
  String get commandDebugShare => 'Generate debug share';

  @override
  String get commandLogsRedacted =>
      'Sensitive values were redacted from the logs.';

  @override
  String get commandLogsNotRedacted =>
      'The logs were not redacted. Share them carefully.';

  @override
  String commandAutoDeleteHours(Object hours) {
    return 'Links will be deleted automatically in about $hours hours.';
  }

  @override
  String get commandPartialUploadFailed => 'Some content failed to upload:';

  @override
  String get commandDiagnosticsMaintenance => 'Diagnostics and maintenance';

  @override
  String get commandRunDoctor => 'Run diagnostics';

  @override
  String get commandRunDoctorDescription =>
      'hermes doctor - check the environment and configuration';

  @override
  String get commandDoctor => 'Diagnostics';

  @override
  String get commandSecurityAudit => 'Security audit';

  @override
  String get commandSecurityAuditDescription =>
      'hermes security audit - scan for potential security issues';

  @override
  String get commandBackupNow => 'Back up now';

  @override
  String get commandBackupDescription =>
      'hermes backup - package configuration and data locally';

  @override
  String get commandBackup => 'Backup';

  @override
  String get commandDebugShareDescription =>
      'Upload redacted logs and create shareable debug links';

  @override
  String terminalStartFailed(Object error) {
    return 'Could not start terminal: $error';
  }

  @override
  String get terminalSshHost => 'Host or SSH config alias *';

  @override
  String get terminalSshUserOptional => 'User (optional)';

  @override
  String get terminalSshPort => 'Port (default 22)';

  @override
  String get terminalSshIdentityFile => 'Server-side IdentityFile (optional)';

  @override
  String get terminalSshRemoteCwd => 'Remote working directory (optional)';

  @override
  String get terminalSshAuthenticationNote =>
      'Authentication uses the ssh-agent or SSH config on the Hermes server. The mobile app does not store passwords.';

  @override
  String terminalSshFailed(Object error) {
    return 'SSH connection failed: $error';
  }

  @override
  String get terminalCloseRunningQuestion => 'Close running terminal?';

  @override
  String terminalCloseRunningWarning(Object name) {
    return 'Processes in \"$name\" will be terminated. This cannot be undone.';
  }

  @override
  String get terminalClose => 'Close terminal';

  @override
  String get terminalSessions => 'Terminal sessions';

  @override
  String terminalSessionLimit(Object count) {
    return 'Up to $count terminals can be open at once';
  }

  @override
  String terminalCloseNamed(Object name) {
    return 'Close $name';
  }

  @override
  String get terminalSelectTextFirst => 'Select text first.';

  @override
  String terminalPasteLinesQuestion(Object count) {
    return 'Paste $count lines?';
  }

  @override
  String get terminalMergeSingleLine => 'Merge into one line';

  @override
  String get terminalConfirmPaste => 'Paste';

  @override
  String get terminalSelectTerminalTextFirst =>
      'Select text in the terminal first.';

  @override
  String get terminalSentToChat => 'Sent to the chat composer';

  @override
  String terminalOpenLinkFailed(Object link) {
    return 'Could not open link: $link';
  }

  @override
  String get terminalDismissNotice => 'Dismiss notice';

  @override
  String get terminalNew => 'New terminal';

  @override
  String get terminalNewSsh => 'New SSH terminal';

  @override
  String get terminalOpenDirectory => 'Open in a directory';

  @override
  String get terminalDisplaySettings => 'Terminal display settings';

  @override
  String get terminalNoWorkingDirectory => '(No working directory)';

  @override
  String get terminalNoActive => 'No active terminal';

  @override
  String get terminalCommandMode => 'Command mode';

  @override
  String get terminalInteractiveMode => 'Interactive mode';

  @override
  String get terminalControlInterrupt => 'Ctrl+C interrupt';

  @override
  String get terminalControlSuspend => 'Ctrl+Z suspend';

  @override
  String get terminalControlClear => 'Ctrl+L clear screen';

  @override
  String get terminalControlBackWord => 'Alt+B previous word';

  @override
  String get terminalControlForwardWord => 'Alt+F next word';

  @override
  String get terminalControlKeys => 'Control keys';

  @override
  String get terminalVisibleOutputCopied => 'Visible terminal output copied';

  @override
  String get terminalDisplay => 'Terminal display';

  @override
  String get terminalDisplayDescription =>
      'These settings affect only local display, not PTY or command behavior.';

  @override
  String get terminalPreviewOutput =>
      '✓ 42 tests passed  Localized output preview';

  @override
  String terminalFontSize(Object value) {
    return 'Font size  $value';
  }

  @override
  String terminalLineHeight(Object value) {
    return 'Line height  $value';
  }

  @override
  String get terminalColorTheme => 'Color theme';

  @override
  String get terminalThemeSystem => 'Follow system';

  @override
  String get terminalThemeProfessionalDark => 'Professional dark';

  @override
  String get terminalThemeHighContrastDark => 'High-contrast dark';

  @override
  String get terminalThemeSoftLight => 'Soft light';

  @override
  String get terminalCursorStyle => 'Cursor style';

  @override
  String get terminalCursorBar => 'Bar';

  @override
  String get terminalCursorBlock => 'Block';

  @override
  String get terminalCursorUnderline => 'Underline';

  @override
  String get terminalContentPadding => 'Terminal padding';

  @override
  String get terminalContentPaddingHint => 'Turn off to show more columns';

  @override
  String get terminalResetDisplay => 'Restore recommended settings';

  @override
  String get terminalCommandHint => 'Enter a command...';

  @override
  String get terminalRunCommand => 'Run command';

  @override
  String get terminalPaste => 'Paste';

  @override
  String get terminalClear => 'Clear';

  @override
  String get terminalSendToChat => 'Send to chat';

  @override
  String get terminalInteractiveHint =>
      'Interactive mode · input is sent directly to the PTY';

  @override
  String get terminalMoreActions => 'More terminal actions';

  @override
  String get terminalCopySelection => 'Copy selection';

  @override
  String get terminalSendSelectionToChat => 'Send selection to chat';

  @override
  String get terminalOpenOtherDirectory => 'Open terminal in another directory';

  @override
  String get terminalManageSessions => 'Manage terminal sessions';

  @override
  String get terminalPrivacyHistory => 'Privacy and history';

  @override
  String get terminalPrivacyDescription =>
      'Command history and terminal output are not persisted by default.';

  @override
  String get terminalSaveCommandHistory => 'Save command history';

  @override
  String get terminalSaveOutputSnapshots => 'Save terminal output snapshots';

  @override
  String get terminalClearSavedData => 'Clear saved history and snapshots';

  @override
  String get terminalClearDataQuestion => 'Clear history and snapshots?';

  @override
  String get terminalClearDataWarning =>
      'Saved command history and terminal output snapshots will be permanently deleted. This cannot be undone.';

  @override
  String filesRevealFailed(String error) {
    return 'Could not reveal the item in file manager: $error';
  }

  @override
  String get filesLargeDownloadQuestion => 'Download large file?';

  @override
  String filesLargeDownloadDescription(String name, String size) {
    return '\"$name\" is about $size MB. Downloading may take a while and use device storage.';
  }

  @override
  String get filesContinueDownload => 'Continue download';

  @override
  String get filesLargeEditQuestion => 'Open large file?';

  @override
  String filesLargeEditDescription(String name, String size) {
    return '\"$name\" is about $size MB. Loading it into the editor may be slow.';
  }

  @override
  String get filesContinueEdit => 'Open anyway';

  @override
  String get filesFolderDownloadQuestion => 'Download folder?';

  @override
  String filesFolderDownloadDescription(String name) {
    return '\"$name\" will be downloaded to this device as a ZIP archive. Large folders may take a while and use device storage.';
  }

  @override
  String get filesArchiveDownload => 'Archive and download';

  @override
  String filesDownloadedPath(String path) {
    return 'Downloaded to $path (path copied)';
  }

  @override
  String filesDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String get filesSelectDownloadItem => 'Select at least one file or folder';

  @override
  String filesDownloadSummary(int success, int failed, int skipped) {
    return 'Downloaded $success; $failed failed; $skipped skipped';
  }

  @override
  String get filesRevealOnServer => 'Reveal on server';

  @override
  String get filesRevealOnServerDescription =>
      'Open on the machine running Hermes';

  @override
  String get filesDetails => 'Details';

  @override
  String get filesDownloading => 'Downloading...';

  @override
  String get filesDownloadFolderZip => 'Download folder (ZIP)';

  @override
  String get filesDownloadToDevice => 'Download to device';

  @override
  String get filesCopyToClipboard => 'Copy to clipboard';

  @override
  String get filesCopiedPasteHint =>
      'Copied; open the destination folder and tap Paste';

  @override
  String get filesCutToClipboard => 'Cut to clipboard';

  @override
  String get filesCutPasteHint =>
      'Cut; open the destination folder and tap Paste';

  @override
  String get filesRename => 'Rename';

  @override
  String get filesCopyPath => 'Copy path';

  @override
  String get filesPathCopied => 'Path copied';

  @override
  String get filesCopyRelativePath => 'Copy relative path';

  @override
  String get filesRelativePathCopied => 'Relative path copied';

  @override
  String get filesLink => 'Link';

  @override
  String filesInfoPath(String value) {
    return 'Path: $value';
  }

  @override
  String filesInfoType(String value) {
    return 'Type: $value';
  }

  @override
  String filesInfoSize(int value) {
    return 'Size: $value B';
  }

  @override
  String filesInfoModified(String value) {
    return 'Modified: $value';
  }

  @override
  String filesInfoReadable(String value) {
    return 'Readable: $value';
  }

  @override
  String filesInfoWritable(String value) {
    return 'Writable: $value';
  }

  @override
  String filesMovedCount(int count) {
    return 'Moved $count items';
  }

  @override
  String filesCopiedCount(int count) {
    return 'Copied $count items';
  }

  @override
  String filesPasteFailed(String error) {
    return 'Paste failed: $error';
  }

  @override
  String get filesConfirmDelete => 'Confirm deletion';

  @override
  String filesDeleteSelectedDescription(int count) {
    return 'Delete the $count selected items? This cannot be undone.';
  }

  @override
  String filesDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get filesNewFile => 'New file';

  @override
  String get filesFileName => 'File name';

  @override
  String filesCreateFileFailed(String error) {
    return 'Could not create file: $error';
  }

  @override
  String filesNewSessionPrompt(String references) {
    return 'Review and process these files:\n$references';
  }

  @override
  String get filesNewFolder => 'New folder';

  @override
  String get filesNewName => 'New name';

  @override
  String filesRenameFailed(String error) {
    return 'Rename failed: $error';
  }

  @override
  String filesDeleteFolderDescription(String name) {
    return 'Delete folder \"$name\" and all its contents?';
  }

  @override
  String filesDeleteFileDescription(String name) {
    return 'Delete file \"$name\"?';
  }

  @override
  String get filesFolderName => 'Folder name';

  @override
  String filesCreateFolderFailed(String error) {
    return 'Could not create folder: $error';
  }

  @override
  String get filesSelectWorkspaceDirectory => 'Select workspace directory';

  @override
  String filesSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get filesSwitchToDirectoryBrowser => 'Switch to directory browser';

  @override
  String get filesSwitchToProjectTree => 'Switch to project tree';

  @override
  String get filesOpenInGit => 'Open in Git';

  @override
  String get filesNewSessionForDirectory => 'New session for current directory';

  @override
  String get filesSendSelectionToNewSession =>
      'Send selected files to new session';

  @override
  String get filesDownloadSelected => 'Download selected';

  @override
  String get filesCopySelected => 'Copy selected';

  @override
  String get filesCutSelected => 'Cut selected';

  @override
  String get filesDeleteSelected => 'Delete selected';

  @override
  String get filesClearSelection => 'Clear selection';

  @override
  String get filesMoveHere => 'Move here';

  @override
  String get filesCopyHere => 'Copy here';

  @override
  String get filesSelectCurrentDirectory => 'Select current directory';

  @override
  String filesUseAsWorkspace(String name) {
    return 'Use \"$name\" as workspace';
  }

  @override
  String get filesSelectPreview => 'Select a file to preview';

  @override
  String get filesSelectPreviewDescription =>
      'Select a file on the left to edit or preview it here';

  @override
  String get filesFilterProjectTree => 'Filter loaded project tree...';

  @override
  String get filesSearchDirectory => 'Search current directory...';

  @override
  String get filesLoadingDirectory => 'Loading directory...';

  @override
  String get filesNoMatches => 'No matching files';

  @override
  String get filesActions => 'File actions';

  @override
  String get filesUnableToRead => 'Unable to read';

  @override
  String get filesDownload => 'Download';

  @override
  String get filesCut => 'Cut';

  @override
  String get configTabModel => 'Models';

  @override
  String get configTabChat => 'Chat';

  @override
  String get configTabMemory => 'Memory';

  @override
  String get configTabVoice => 'Voice';

  @override
  String get configTabToolsKeys => 'Tools & keys';

  @override
  String configLoadFailed(String error) {
    return 'Could not load configuration: $error';
  }

  @override
  String get configAuxVision => 'Vision';

  @override
  String get configAuxWebExtract => 'Web extraction';

  @override
  String get configAuxCompression => 'Context compression';

  @override
  String get configAuxSkillsHub => 'Skills hub';

  @override
  String get configAuxApproval => 'Approval decisions';

  @override
  String get configAuxMcp => 'MCP assistance';

  @override
  String get configAuxTitleGeneration => 'Title generation';

  @override
  String get configAuxReview => 'Code review';

  @override
  String get configAuxTriage => 'Task triage';

  @override
  String get configAuxKanban => 'Kanban decomposition';

  @override
  String get configAuxProfile => 'Profile description';

  @override
  String get configAuxCurator => 'Content curation';

  @override
  String get configPersonalityDisplay => 'Personality (display.personality)';

  @override
  String get configPersonality => 'Personality';

  @override
  String get configTimezone => 'Time zone (IANA)';

  @override
  String get configShowReasoning => 'Show reasoning blocks';

  @override
  String get configMessageReactions => 'Enable message reactions';

  @override
  String get configApprovalMode => 'Approval mode';

  @override
  String get configYoloApproval => 'YOLO automatic approval';

  @override
  String get configChatFieldsUnavailable =>
      'Chat fields not returned by backend';

  @override
  String get configChatFieldsUnavailableDescription =>
      'GET /api/v1/config did not return personality, timezone, approvals, or yolo.';

  @override
  String get configPersistentMemory => 'Persistent memory';

  @override
  String get configUserProfile => 'User profile';

  @override
  String get configMemoryBudget => 'Memory budget (characters)';

  @override
  String get configProfileBudget => 'Profile budget (characters)';

  @override
  String get configMemoryProvider => 'Memory provider';

  @override
  String get configContextEngine => 'Context engine';

  @override
  String get configAutoCompression => 'Automatic compression';

  @override
  String get configCompressionThreshold => 'Compression threshold';

  @override
  String get configCompressionRatio => 'Compression target ratio';

  @override
  String get configProtectRecent => 'Protect latest N messages';

  @override
  String get configMemoryFieldsUnavailable =>
      'Memory fields not returned by backend';

  @override
  String get configMemoryFieldsUnavailableDescription =>
      'GET /api/v1/config did not return memory, compression, or context.';

  @override
  String get configVoice => 'Voice';

  @override
  String get configVoiceModel => 'Model';

  @override
  String get configVoiceId => 'Voice ID';

  @override
  String get configModelId => 'Model ID';

  @override
  String get configLanguage => 'Language';

  @override
  String get configSpeechSpeed => 'Speech speed';

  @override
  String get configAutoSpeechTags => 'Automatic speech tags';

  @override
  String get configStreamingLatency => 'Streaming latency optimization';

  @override
  String get configSampleRate => 'Sample rate';

  @override
  String get configBitRate => 'Bit rate';

  @override
  String get configDevice => 'Device';

  @override
  String get configLanguageCode => 'Language code';

  @override
  String get configAudioEvents => 'Tag audio events';

  @override
  String get configDiarization => 'Speaker diarization';

  @override
  String get configSpeechToText => 'Speech to text';

  @override
  String get configEchoTranscripts => 'Echo transcripts';

  @override
  String get configSttProvider => 'STT provider';

  @override
  String get configTtsProvider => 'TTS provider';

  @override
  String get configAutoReadReplies => 'Read replies automatically';

  @override
  String get configMaxRecordingSeconds => 'Maximum recording seconds';

  @override
  String get configRecordShortcut => 'Recording shortcut';

  @override
  String get configDirectVoiceService => 'Connect directly to voice service';

  @override
  String get configVoiceFieldsUnavailable =>
      'Voice fields not returned by backend';

  @override
  String get configVoiceFieldsUnavailableDescription =>
      'GET /api/v1/config did not return stt, tts, or voice.';

  @override
  String get configProviderApiKeys => 'Model provider API keys';

  @override
  String get configNoProviders => 'No configured providers';

  @override
  String get configNoProvidersDescription =>
      'Add an API key to enable a model provider';

  @override
  String get configEnvironmentVariables => 'Environment variables';

  @override
  String get configConfigured => 'Configured';

  @override
  String get configNotConfigured => 'Not configured';

  @override
  String configAvailableModels(int count) {
    return '$count models available';
  }

  @override
  String configDisconnectedProvider(String name) {
    return 'Disconnected $name';
  }

  @override
  String configDisconnectFailed(String error) {
    return 'Could not disconnect: $error';
  }

  @override
  String get configUpdateKey => 'Update key';

  @override
  String get configAddKey => 'Add key';

  @override
  String configProviderApiKey(String name) {
    return '$name API key';
  }

  @override
  String configProviderKeySaved(String name) {
    return 'Saved $name API key';
  }

  @override
  String get configSaved => 'Saved';

  @override
  String get configPressEnterToSave => 'Press Enter to save';

  @override
  String get configEnterNumber => 'Enter a number';

  @override
  String get configNewValueOptional =>
      'New value (leave blank to keep unchanged)';

  @override
  String get configValue => 'Value';

  @override
  String configRevealFailed(String error) {
    return 'Could not reveal value: $error';
  }

  @override
  String configDeleteVariableQuestion(String key) {
    return 'Delete $key?';
  }

  @override
  String get configDeleteVariableDescription =>
      'This environment variable will be permanently removed from the server .env file. This cannot be undone.';

  @override
  String get configAddEnvironmentVariable => 'Add environment variable';

  @override
  String get configVariableName => 'Variable name';

  @override
  String get configNoEnvironmentVariables => 'No environment variables';

  @override
  String get configNoEnvironmentVariablesDescription =>
      'Add custom environment variables to configure tools or providers';

  @override
  String get configHideAdvancedVariables => 'Hide advanced variables';

  @override
  String configShowAdvancedVariables(int count) {
    return 'Show advanced variables ($count)';
  }

  @override
  String get configSet => 'Set';

  @override
  String get configNotSet => 'Not set';

  @override
  String get configVoiceIdManual =>
      'Press Enter to save (no account voices were returned; enter an ID manually)';

  @override
  String configVoicesLoadFailed(String error) {
    return 'Could not load account voices: $error. Enter an ID manually and press Enter to save.';
  }

  @override
  String chatDraftHandoffSaveFailed(String error) {
    return 'The draft is available here but could not be saved to the server: $error';
  }

  @override
  String get toolPlanTitle => 'Plan';

  @override
  String get toolPlanCopy => 'Copy plan';

  @override
  String get toolPlanCopied => 'Plan copied';

  @override
  String get toolValueNotProvided => 'Not provided';

  @override
  String get toolCommand => 'Command';

  @override
  String get toolWaitingCommand => 'Waiting for command';

  @override
  String get toolOutput => 'Output';

  @override
  String get toolErrorOutput => 'Error output';

  @override
  String toolExitCode(int code) {
    return 'Exit code: $code';
  }

  @override
  String get toolCode => 'Code';

  @override
  String toolCodeLanguage(String language) {
    return 'Code · $language';
  }

  @override
  String get toolWaitingCode => 'Waiting for code';

  @override
  String get toolExecutionResult => 'Execution result';

  @override
  String toolChangedFiles(int count) {
    return 'Changed files · $count';
  }

  @override
  String get toolPatchContent => 'Patch';

  @override
  String get toolWaitingPatch => 'Waiting for patch';

  @override
  String get toolResult => 'Result';

  @override
  String get toolSearchQuery => 'Search query';

  @override
  String get toolSearchingWeb => 'Searching the web';

  @override
  String toolSearchResults(int count) {
    return 'Search results · $count';
  }

  @override
  String get toolNoResults => 'No results';

  @override
  String get toolLink => 'Link';

  @override
  String get toolContent => 'Content';

  @override
  String get toolFile => 'File';

  @override
  String get toolReadingFile => 'Reading file';

  @override
  String get toolWritingFile => 'Writing file';

  @override
  String get toolWriteContent => 'Content to write';

  @override
  String toolFileList(int count) {
    return 'Files · $count';
  }

  @override
  String get toolNoFiles => 'No files';

  @override
  String get toolDetails => 'Details';

  @override
  String get toolNoReadableContent => '(No readable content)';

  @override
  String get toolWaitingForResult => 'Waiting for tool output';

  @override
  String get toolUntitledResult => 'Untitled result';

  @override
  String get toolCopyAll => 'Copy all';

  @override
  String toolHiddenRestore(String name) {
    return '$name is hidden; tap to restore';
  }

  @override
  String get toolReadableView => 'Readable view';

  @override
  String get toolRawJsonView => 'Raw JSON view';

  @override
  String get toolHideRow => 'Hide this tool row';

  @override
  String get toolCopyResult => 'Copy result';

  @override
  String toolRawDetailsTitle(String name) {
    return '$name raw details';
  }

  @override
  String get toolViewRawDetails => 'View raw details';

  @override
  String get toolArguments => 'Arguments';

  @override
  String get toolNoDetailedData => '(No detailed data)';

  @override
  String toolArgumentDetailsTitle(String key) {
    return '$key argument';
  }

  @override
  String toolTapForFullContent(int count) {
    return '[Tap to view all $count characters]';
  }

  @override
  String toolContentTooLong(int count) {
    return 'Content is long ($count characters)';
  }

  @override
  String toolFullResultTitle(String name) {
    return '$name full result';
  }

  @override
  String get toolViewFull => 'View all';

  @override
  String kanbanDeleteAttachment(String name) {
    return 'Delete $name?';
  }

  @override
  String get kanbanCannotUndo => 'This action cannot be undone.';

  @override
  String kanbanOperationFailed(String error) {
    return 'Operation failed: $error';
  }

  @override
  String get kanbanNoLog => 'No log available';

  @override
  String get kanbanAddChildTask => 'Add child task';

  @override
  String get kanbanTaskId => 'Task ID';

  @override
  String get kanbanDescription => 'Description';

  @override
  String get kanbanCommandCopied => 'Command copied';

  @override
  String get kanbanViewLog => 'View log';

  @override
  String kanbanCreatedAt(Object time) {
    return 'Created $time';
  }

  @override
  String get kanbanTaskIdCopied => 'Task ID copied';

  @override
  String get kanbanEstimate => 'Estimate';

  @override
  String get kanbanDecompose => 'Decompose';

  @override
  String get kanbanNoDescription => 'No description';

  @override
  String get kanbanDiagnostics => 'Diagnostics';

  @override
  String kanbanComments(int count) {
    return 'Comments ($count)';
  }

  @override
  String get kanbanAddComment => 'Add comment';

  @override
  String kanbanDependencies(int parents, int children) {
    return 'Dependencies: $parents parent tasks, $children child tasks';
  }

  @override
  String kanbanChildTask(String id) {
    return 'Child task $id';
  }

  @override
  String kanbanAttachments(int count) {
    return 'Attachments ($count)';
  }

  @override
  String kanbanEventTimeline(int count) {
    return 'Event timeline ($count)';
  }

  @override
  String kanbanRuns(int count) {
    return 'Runs ($count)';
  }

  @override
  String get kanbanUploadAttachment => 'Upload attachment';

  @override
  String kanbanAttachmentBytes(int count) {
    return '$count bytes';
  }

  @override
  String messageReactionFailed(String error) {
    return 'Could not update reaction: $error';
  }

  @override
  String get messageRenderFailed => 'This message cannot be displayed';

  @override
  String get messageRenderFailedDescription => 'Other messages are unaffected';

  @override
  String get messageRemoveMyReaction => 'Remove my reaction';

  @override
  String get messageAgentReaction => 'Agent reaction';

  @override
  String get messageAddReaction => 'Add reaction';

  @override
  String get messageSearchEmoji => 'Search emoji';

  @override
  String messageImageSaveFailed(String error) {
    return 'Could not save image: $error';
  }

  @override
  String get messageGeneratingImage => 'Generating image...';

  @override
  String get messageImageGenerationFailed => 'Image generation failed';

  @override
  String get messageWaitingForImage => 'Waiting for image result';

  @override
  String get messageGeneratedImage => 'Generated image';

  @override
  String get messageImageLinkCopied => 'Image link copied';

  @override
  String get messageOpenInBrowser => 'Open in browser';

  @override
  String get messageMcpSetup => 'MCP server setup';

  @override
  String messageMcpServer(String server) {
    return 'MCP · $server';
  }

  @override
  String get messageMcpSetupFailed => 'Setup failed; retry in MCP settings';

  @override
  String get messageMcpSetupWaiting => 'Waiting for setup to complete';

  @override
  String get messageMcpSetupComplete => 'Setup complete';

  @override
  String get messageOpenMcpSettings => 'Open MCP settings';

  @override
  String get messageFileChanges => 'File changes';

  @override
  String get messageViewDiff => 'View diff';

  @override
  String get messageOpenLink => 'Open link';

  @override
  String messageSendingToAgent(String name) {
    return 'Sending to $name...';
  }

  @override
  String messageSentToAgent(String name) {
    return 'Sent to $name';
  }

  @override
  String messageReplyFromAgent(String name) {
    return 'Reply from $name';
  }

  @override
  String messageRepliedToAgent(String name) {
    return 'Replied to $name';
  }

  @override
  String messageFromAgent(String name) {
    return 'From agent · $name';
  }

  @override
  String get messageSteered => 'Steered';

  @override
  String get messageHermesAvatar => 'Hermes assistant avatar';

  @override
  String get messageSourceWechat => 'WeChat';

  @override
  String get messageSourceFeishu => 'Feishu';

  @override
  String get messageSourceDesktop => 'Desktop';

  @override
  String get messageRestoreVersion => 'Restore this version';

  @override
  String get messagePreviousVersion => 'Previous version';

  @override
  String get messageNextVersion => 'Next version';

  @override
  String get messageCopyText => 'Copy text';

  @override
  String get messageCopyMarkdown => 'Copy as Markdown';

  @override
  String get messageBranchFromHere => 'Branch from this message';

  @override
  String get messageSpeakDisconnected =>
      'Connect to the server to read this message aloud';

  @override
  String get messageSpeakFailed => 'Could not play speech. Try again.';

  @override
  String get messageStopSpeaking => 'Stop reading';

  @override
  String get messageSpeak => 'Read aloud';

  @override
  String get sessionDetailMessages => 'Messages';

  @override
  String get sessionDetailTools => 'Tools';

  @override
  String get sessionDetailEstimated => 'Estimated';

  @override
  String get sessionDetailCost => 'Cost';

  @override
  String get sessionDetailDuration => 'Duration';

  @override
  String get sessionDetailInfo => 'Session information';

  @override
  String get sessionDetailSource => 'Source';

  @override
  String get sessionDetailModel => 'Model';

  @override
  String get sessionDetailStarted => 'Started';

  @override
  String get sessionDetailLastActivity => 'Last activity';

  @override
  String get sessionDetailEnded => 'Ended';

  @override
  String get sessionDetailEndReason => 'End reason';

  @override
  String get sessionDetailHandoff => 'Handoff';

  @override
  String get sessionDetailHandoffError => 'Handoff error';

  @override
  String get sessionDetailTokensBilling => 'Tokens and billing';

  @override
  String get sessionDetailInputOutput => 'Input / output';

  @override
  String get sessionDetailCacheReadWrite => 'Cache read / write';

  @override
  String get sessionDetailReasoningTokens => 'Reasoning tokens';

  @override
  String get sessionDetailBillingSource => 'Billing source';

  @override
  String get sessionDetailContextSource => 'Context and source';

  @override
  String get sessionDetailWorkingDirectory => 'Working directory';

  @override
  String get sessionDetailGitBranch => 'Git branch';

  @override
  String get sessionDetailContact => 'Contact';

  @override
  String get sessionDetailChatType => 'Chat type';

  @override
  String get sessionDetailUserId => 'User ID';

  @override
  String get sessionDetailParentSession => 'Parent session';

  @override
  String get sessionDetailRewindCount => 'Rewind count';

  @override
  String get sessionDetailCompressionFailed => 'Compression temporarily failed';

  @override
  String get sessionDetailOpen => 'Open session';

  @override
  String get sessionActionOpenWorkspace => 'Open in workspace';

  @override
  String get sessionActionUnpin => 'Unpin';

  @override
  String get sessionActionPin => 'Pin';

  @override
  String get sessionActionAppearance => 'Appearance';

  @override
  String get sessionActionDuplicate => 'Duplicate session';

  @override
  String get sessionActionShare => 'Share session';

  @override
  String get sessionActionExport => 'Export session';

  @override
  String get sessionActionMoveProject => 'Move to project';

  @override
  String get sessionActionUnarchive => 'Unarchive';

  @override
  String get sessionActionArchive => 'Archive';

  @override
  String get sessionActionStopResponse => 'Stop response';

  @override
  String get sessionActionAppearanceTitle => 'Session appearance';

  @override
  String sessionActionRenameFailed(String error) {
    return 'Could not rename session: $error';
  }

  @override
  String get sessionActionUnarchived => 'Session unarchived';

  @override
  String get sessionActionArchived => 'Session archived';

  @override
  String sessionActionFailed(String error) {
    return 'Operation failed: $error';
  }

  @override
  String get sessionActionUnpinned => 'Session unpinned';

  @override
  String get sessionActionPinned => 'Session pinned';

  @override
  String get sessionActionMoved => 'Session moved';

  @override
  String sessionActionMoveFailed(String error) {
    return 'Could not move session: $error';
  }

  @override
  String sessionActionBranchCreated(String id) {
    return 'Branch created: $id';
  }

  @override
  String get sessionActionCopyCreated => 'Session copy created';

  @override
  String sessionActionDuplicateFailed(String error) {
    return 'Could not duplicate session: $error';
  }

  @override
  String get sessionActionShareCreated => 'Share link created';

  @override
  String get sessionActionShareWarning =>
      'Anyone with this link can view the session.';

  @override
  String sessionActionShareFailed(String error) {
    return 'Could not share session: $error';
  }

  @override
  String get sessionActionStopRequested => 'Stop requested';

  @override
  String get sessionActionExportMarkdownHint => 'Good for viewing and sharing';

  @override
  String get sessionActionExportJsonHint => 'Preserves all structured data';

  @override
  String get sessionActionExportCopiedWeb =>
      'Export copied to clipboard because web cannot save local files';

  @override
  String sessionActionExported(String path) {
    return 'Exported to $path; path copied';
  }

  @override
  String sessionActionExportFailed(String error) {
    return 'Could not export session: $error';
  }

  @override
  String get sessionsNoDetail => 'No session details';

  @override
  String get sessionsNoDetailDescription =>
      'Adjust the filters to view a session summary';

  @override
  String get sessionsAllProjects => 'All projects';

  @override
  String get sessionsProject => 'Project';

  @override
  String get sessionsSearchHint =>
      'Search titles, previews, or working directories...';

  @override
  String get sessionsToday => 'Today';

  @override
  String get sessionsThisWeek => 'This week';

  @override
  String get sessionsStarred => 'Starred';

  @override
  String get sessionsSortNewest => 'Time: newest first';

  @override
  String get sessionsSortOldest => 'Time: oldest first';

  @override
  String get sessionsSortTitle => 'Title: A-Z';

  @override
  String get sessionsSortMessages => 'Messages: most first';

  @override
  String get sessionsSortMethod => 'Sort method';

  @override
  String get sessionsLoading => 'Loading sessions...';

  @override
  String get sessionsViewFullDetails => 'View full details';

  @override
  String get sessionsSettings => 'Settings';

  @override
  String get requestHermesQuestion => 'Hermes question';

  @override
  String get requestPending => 'Pending request';

  @override
  String get requestAlwaysAllowQuestion => 'Always allow?';

  @override
  String get requestAlwaysAllowDescription =>
      'This operation will be added to the configuration as a permanent allow rule. Similar operations will no longer ask.';

  @override
  String requestAlwaysAllowDetail(String detail) {
    return '“$detail” will be added to the configuration as a permanent allow rule. Similar operations will no longer ask.';
  }

  @override
  String get requestNoActiveSession => 'No active session';

  @override
  String get requestConnectionUnavailable =>
      'The request connection is unavailable';

  @override
  String requestRespondFailed(String error) {
    return 'Could not respond: $error';
  }

  @override
  String get requestAnswerFailed => 'Could not send the answer. Try again.';

  @override
  String get requestMcpNameMissing => 'The request has no MCP server name';

  @override
  String get requestOAuthTimeout => 'OAuth authorization timed out';

  @override
  String get requestMcpTestFailed => 'MCP connection test failed';

  @override
  String get requestMcpSetupFailed => 'MCP setup failed';

  @override
  String requestConfigureMcp(String name) {
    return 'Configure $name';
  }

  @override
  String get requestCloseQuestion => 'Close request?';

  @override
  String get requestCloseDescription =>
      'This request cannot be restored after closing, and the agent will remain waiting.';

  @override
  String get requestProcessed => 'Processed';

  @override
  String get requestInteractionProcessed => 'Interactive request processed';

  @override
  String requestServer(String name) {
    return 'Server: $name';
  }

  @override
  String get requestSubmitAllAnswers => 'Submit all answers';

  @override
  String get requestConfigureLater => 'Not now';

  @override
  String get requestConfiguring => 'Configuring...';

  @override
  String get requestInstallEnable => 'Install and enable';

  @override
  String get requestEnterContent => 'Enter content';

  @override
  String get requestEnterText => 'Enter...';

  @override
  String requestMorePending(int count) {
    return '$count more pending';
  }

  @override
  String get requestAllowOnce => 'Allow once';

  @override
  String get requestAllowSession => 'Allow for this session';

  @override
  String requestSubmitSelected(int count) {
    return 'Submit ($count selected)';
  }

  @override
  String get requestCustomAnswer => 'Other (custom answer)';

  @override
  String get requestRecommended => 'Recommended';

  @override
  String messagingLoadFailed(String error) {
    return 'Could not load messaging platforms: $error';
  }

  @override
  String messagingPlatformEnabled(String name) {
    return '$name enabled';
  }

  @override
  String messagingPlatformDisabled(String name) {
    return '$name disabled';
  }

  @override
  String messagingUpdateFailed(String error) {
    return 'Update failed: $error';
  }

  @override
  String messagingTestPassed(String name) {
    return '$name connection test passed';
  }

  @override
  String get messagingTestNotPassed => 'Connection test did not pass';

  @override
  String messagingTestFailed(String error) {
    return 'Test failed: $error';
  }

  @override
  String messagingConfigSaved(String name) {
    return '$name configuration saved. Restart Gateway to apply connection changes.';
  }

  @override
  String messagingSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String messagingApproved(String name) {
    return 'Approved $name';
  }

  @override
  String messagingApproveFailed(String error) {
    return 'Approval failed: $error';
  }

  @override
  String get messagingRevokeTitle => 'Revoke access';

  @override
  String messagingRevokeQuestion(String name) {
    return 'Revoke messaging access for $name?';
  }

  @override
  String get messagingRevoke => 'Revoke';

  @override
  String get messagingRevoked => 'Access revoked';

  @override
  String messagingRevokeFailed(String error) {
    return 'Could not revoke access: $error';
  }

  @override
  String get messagingRestartQuestion => 'Restart Gateway?';

  @override
  String get messagingRestartWarning =>
      'This interrupts all sessions and clients connected to this Gateway. They will reconnect automatically after it completes.';

  @override
  String get messagingRestarting => 'Gateway is restarting';

  @override
  String messagingRestartFailed(String error) {
    return 'Gateway restart failed: $error';
  }

  @override
  String get messagingTitle => 'Messaging platforms';

  @override
  String get messagingRestartGateway => 'Restart Gateway';

  @override
  String get messagingLoading => 'Loading messaging platforms...';

  @override
  String get messagingPendingApproval => 'Pending approval';

  @override
  String get messagingPlatforms => 'Platforms';

  @override
  String get messagingEmpty => 'No messaging platforms';

  @override
  String get messagingEmptyDescription =>
      'The server returned no configurable messaging platforms';

  @override
  String get messagingAuthorizedUsers => 'Authorized users';

  @override
  String get messagingConfigure => 'Configure';

  @override
  String get messagingTest => 'Test';

  @override
  String get messagingOpenDocs => 'Open documentation';

  @override
  String get messagingUnknownUser => 'Unknown user';

  @override
  String get messagingApprove => 'Approve';

  @override
  String get messagingStateDisabled => 'Disabled';

  @override
  String get messagingStateGatewayStopped => 'Configured; Gateway not running';

  @override
  String get messagingStateFatal => 'Fatal error';

  @override
  String get messagingStateStartupFailed => 'Startup failed';

  @override
  String get messagingStateConfigured => 'Configured';

  @override
  String get messagingStateNeedsConfig => 'Needs configuration';

  @override
  String messagingPlatformConfig(String name) {
    return '$name configuration';
  }

  @override
  String get messagingNoEditableConfig =>
      'This platform has no editable settings.';

  @override
  String get messagingAdvancedSettings => 'Advanced settings';

  @override
  String get messagingSetLeaveBlank => 'Set; leave blank to keep unchanged';

  @override
  String get messagingEnterNewValue => 'Enter a new value';

  @override
  String get messagingShow => 'Show';

  @override
  String get messagingClearSavedValue => 'Clear saved value';

  @override
  String get fileTreeListView => 'List view';

  @override
  String get fileTreeTreeView => 'Tree view';

  @override
  String get fileTreeAttachToChat => 'Attach to chat';

  @override
  String get projectAddFolder => 'Add folder';

  @override
  String get projectFolderPath => 'Folder path';

  @override
  String get projectFolderLabelOptional => 'Label (optional)';

  @override
  String get projectCreate => 'Create project';

  @override
  String get projectLoading => 'Loading projects...';

  @override
  String get projectEmpty => 'No projects yet';

  @override
  String get projectEmptyDescription =>
      'Create a project to organize working directories and sessions';

  @override
  String get projectWorkspace => 'Project workspace';

  @override
  String get projectEditAppearance => 'Edit appearance';

  @override
  String get projectColor => 'Color';

  @override
  String get projectIcon => 'Icon';

  @override
  String projectAppearanceSaveFailed(String error) {
    return 'Could not save appearance: $error';
  }

  @override
  String get projectRename => 'Rename';

  @override
  String get projectRenameTitle => 'Rename project';

  @override
  String get projectName => 'Project name';

  @override
  String projectRenameFailed(String error) {
    return 'Could not rename project: $error';
  }

  @override
  String projectDeleteQuestion(String name) {
    return 'Delete $name?';
  }

  @override
  String get projectDeleteDescription =>
      'The project will be deleted, but its sessions and files will not be affected. This cannot be undone.';

  @override
  String projectDeleteFailed(String error) {
    return 'Could not delete project: $error';
  }

  @override
  String projectCreateFailed(String error) {
    return 'Could not create project: $error';
  }

  @override
  String get projectManagement => 'Manage projects';

  @override
  String get projectLoadFailed => 'Could not load projects';

  @override
  String get projectNoMoveTargets => 'No other eligible projects';

  @override
  String get projectNoMoveTargetsDescription =>
      'A project needs a valid working directory before it can receive sessions';

  @override
  String get projectNew => 'New project';

  @override
  String get projectEditTitle => 'Edit project';

  @override
  String get projectPrimaryPath => 'Primary working directory';

  @override
  String get projectPrimaryPathHint =>
      'For example, /home/user/projects/my-app';

  @override
  String get projectDescriptionOptional => 'Description (optional)';

  @override
  String get projectRequiredFields =>
      'Enter a project name and working directory';

  @override
  String get projectCreated => 'Project created';

  @override
  String get projectUpdated => 'Project updated';

  @override
  String projectSaveFailed(String error) {
    return 'Could not save project: $error';
  }

  @override
  String get projectDeleteTitle => 'Delete project?';

  @override
  String projectDeleteNamedDescription(String name) {
    return 'Project \"$name\" will be deleted. Associated sessions will not be deleted.';
  }

  @override
  String get projectDeleted => 'Project deleted';

  @override
  String subagentsLoadFailed(String error) {
    return 'Could not load subagents: $error';
  }

  @override
  String get subagentsEmpty => 'No subagent activity';

  @override
  String get subagentsOpenSessionDescription =>
      'Open a session to view its subagent tree';

  @override
  String get subagentsCurrentSessionEmpty =>
      'The current session has no running subagents';

  @override
  String get subagentsCurrentSession => 'Current session';

  @override
  String subagentsSession(String id) {
    return 'Session $id';
  }

  @override
  String subagentsCount(int count) {
    return '$count subagents';
  }

  @override
  String subagentsRunningCount(int count) {
    return '$count running';
  }

  @override
  String subagentsFailedCount(int count) {
    return '$count failed';
  }

  @override
  String subagentsToolCalls(int count) {
    return '$count tool calls';
  }

  @override
  String subagentsFiles(int count) {
    return '$count files';
  }

  @override
  String get subagentsInterrupt => 'Interrupt';

  @override
  String get subagentsInterruptSent => 'Interrupt signal sent';

  @override
  String subagentsInterruptFailed(String error) {
    return 'Could not interrupt subagent: $error';
  }

  @override
  String get subagentsOpenSession => 'Open session';

  @override
  String subagentsOpenSessionFailed(String error) {
    return 'Could not open subagent session: $error';
  }

  @override
  String subagentsCurrentTool(String name) {
    return 'Tool: $name';
  }

  @override
  String subagentsTools(int count) {
    return '$count tools';
  }

  @override
  String subagentsFilesRead(int count) {
    return '$count read';
  }

  @override
  String subagentsFilesWritten(int count) {
    return '$count written';
  }

  @override
  String get subagentsStatusQueued => 'Queued';

  @override
  String get subagentsStatusInterrupted => 'Interrupted';

  @override
  String get subagentsStatusUnknown => 'Unknown';

  @override
  String credentialsLoadFailed(String error) {
    return 'Could not load credentials: $error';
  }

  @override
  String get credentialsSearchHint => 'Search credentials or providers...';

  @override
  String get credentialsMissing => 'Missing';

  @override
  String get credentialsNoMatches => 'No matching credentials';

  @override
  String get credentialsNoMatchesDescription =>
      'Adjust the search or status filter';

  @override
  String get credentialsEmpty => 'No credential providers';

  @override
  String get credentialsEmptyDescription =>
      'The server did not return any configurable credential providers';

  @override
  String get credentialsGroupCloud => 'Cloud providers';

  @override
  String get credentialsGroupModelProviders => 'Model providers';

  @override
  String get credentialsGroupThirdParty => 'Third-party services';

  @override
  String get credentialsKeyRequired =>
      'Select a provider and enter an API key or token';

  @override
  String credentialsSaveFailed(String error) {
    return 'Could not save credential: $error';
  }

  @override
  String get credentialsAddTitle => 'Add credential';

  @override
  String get credentialsEditTitle => 'Edit credential';

  @override
  String get credentialsSaving => 'Saving...';

  @override
  String credentialsApiKey(String name) {
    return '$name API key / token';
  }

  @override
  String get credentialsShowKey => 'Show key';

  @override
  String get credentialsHideKey => 'Hide key';

  @override
  String get petCenterTitle => 'Pet center';

  @override
  String get petRename => 'Rename';

  @override
  String get petDisable => 'Disable pet';

  @override
  String petRenameFailed(String error) {
    return 'Could not rename pet: $error';
  }

  @override
  String petDisableFailed(String error) {
    return 'Could not disable pet: $error';
  }

  @override
  String get petRenameTitle => 'Rename pet';

  @override
  String get petRenameHint => 'Enter a new name...';

  @override
  String get petUntitled => 'Untitled';

  @override
  String petStatus(String status) {
    return 'Status: $status';
  }

  @override
  String get petGallery => 'Gallery';

  @override
  String get petGalleryEmpty => 'No pets available';

  @override
  String get petGenerateNew => 'Generate new pet';

  @override
  String get petStateWave => 'Waving';

  @override
  String get petStateJump => 'Jumping';

  @override
  String get petStateCelebrate => 'Celebrating';

  @override
  String credentialsDisconnectQuestion(String name) {
    return 'Disconnect $name?';
  }

  @override
  String get credentialsDisconnectDescription =>
      'The saved credential will be removed from the Hermes server. You can add it again later.';

  @override
  String starmapLoadDetailFailed(String error) {
    return 'Could not load node details: $error';
  }

  @override
  String get starmapRestoreMine => 'Restore my starmap';

  @override
  String get starmapShareImport => 'Share or import';

  @override
  String get starmapResetView => 'Reset view';

  @override
  String get starmapLoading => 'Loading starmap...';

  @override
  String get starmapNoData => 'No data';

  @override
  String get starmapEmpty => 'Your starmap is empty';

  @override
  String get starmapEmptyDescription =>
      'As Hermes learns more, knowledge nodes will appear here.';

  @override
  String get starmapShareTitle => 'Share starmap';

  @override
  String get starmapShareDescription =>
      'Copy this code to share your starmap, or paste another code and load it.';

  @override
  String get starmapShareCodeHint => 'Starmap share code';

  @override
  String get starmapCopy => 'Copy';

  @override
  String get starmapLoad => 'Load';

  @override
  String get starmapInvalidShareCode => 'This starmap share code is invalid.';

  @override
  String get starmapPause => 'Pause';

  @override
  String get starmapPlay => 'Play';

  @override
  String get starmapSkillLegend => 'Skill';

  @override
  String get starmapMemoryLegend => 'Memory';

  @override
  String get starmapChronologyLegend => 'Core: oldest · outer: newest';

  @override
  String starmapOpenNode(String name) {
    return 'Open $name';
  }

  @override
  String get starmapSaved => 'Saved';

  @override
  String starmapSaveFailed(String error) {
    return 'Could not save node: $error';
  }

  @override
  String get starmapDeleteQuestion => 'Delete node?';

  @override
  String starmapDeleteDescription(String name) {
    return '$name will be removed from the starmap.';
  }

  @override
  String get starmapDeleted => 'Node deleted';

  @override
  String starmapDeleteFailed(String error) {
    return 'Could not delete node: $error';
  }

  @override
  String starmapUseCount(int count) {
    return 'Used $count times';
  }

  @override
  String get starmapContent => 'Content';

  @override
  String get starmapSaving => 'Saving...';

  @override
  String starmapCreatedBy(Object value) {
    return 'Created by $value';
  }

  @override
  String starmapSource(Object value) {
    return 'Source: $value';
  }

  @override
  String get starmapStateArchived => 'Archived';

  @override
  String configCenterLoadFailed(String error) {
    return 'Could not load capability data: $error';
  }

  @override
  String get configCenterKnowledgeTab => 'Knowledge';

  @override
  String get configCenterTitle => 'Capability management';

  @override
  String get configCenterLoadErrorTitle => 'Could not load capabilities';

  @override
  String get configCenterMcpEmptyDescription =>
      'Add an MCP server to connect external tools and data.';

  @override
  String get configCenterUrlOrCommand => 'URL or command';

  @override
  String get configCenterTransport => 'Transport';

  @override
  String get configCenterLocalStdio => 'Stdio (local process)';

  @override
  String configCenterMutationFailed(String error) {
    return 'Could not apply change: $error';
  }

  @override
  String get configCenterKnowledgeTitle => 'Knowledge sources';

  @override
  String get configCenterKnowledgeEmpty => 'No knowledge sources';

  @override
  String get configCenterKnowledgeEmptyDescription =>
      'Add a file, folder, or URL as a knowledge source.';

  @override
  String get configCenterDatabase => 'Database';

  @override
  String configCenterKnowledgeMeta(String type, int count, String status) {
    return '$type · $count chunks · $status';
  }

  @override
  String get configCenterIndexed => 'Indexed';

  @override
  String get configCenterNotIndexed => 'Not indexed';

  @override
  String get configCenterSkillsEmpty => 'No skills';

  @override
  String get configCenterSkillsEmptyDescription =>
      'The server did not return any skills for this profile.';

  @override
  String get configCenterConfiguration => 'Configuration';

  @override
  String get configCenterInstallPlugin => 'Install plugin';

  @override
  String get configCenterPluginsEmpty => 'No plugins';

  @override
  String get configCenterPluginsEmptyDescription =>
      'Install a plugin to extend Hermes.';

  @override
  String get configCenterInstall => 'Install';

  @override
  String get configCenterPluginUrl => 'Plugin URL or identifier';

  @override
  String get fileEditorDiscardQuestion => 'Discard unsaved changes?';

  @override
  String get fileEditorDiscardDescription =>
      'Going back will discard your current edits.';

  @override
  String get fileEditorKeepEditing => 'Keep editing';

  @override
  String get fileEditorDiscard => 'Discard';

  @override
  String get fileEditorDisk => 'On disk';

  @override
  String get fileEditorEditor => 'Editor';

  @override
  String get fileEditorConflictDescription =>
      'This file changed on disk. Overwrite it, reload the disk version, or cancel.';

  @override
  String get fileEditorConflictTitle => 'File changed externally';

  @override
  String get fileEditorOverwriteSave => 'Overwrite and save';

  @override
  String get fileEditorReloaded => 'Reloaded the disk version';

  @override
  String get fileEditorSaved => 'Saved';

  @override
  String fileEditorSaveFailed(String error) {
    return 'Could not save file: $error';
  }

  @override
  String get fileEditorSaving => 'Saving...';

  @override
  String fileEditorUnsavedTitle(String name) {
    return '$name, unsaved changes';
  }

  @override
  String get fileEditorEmpty => '(Empty)';

  @override
  String get fileEditorBinaryTitle => 'This file can\'t be edited as text';

  @override
  String get fileEditorBinaryDescription =>
      'It looks like a binary file (image, archive, or executable). Opening it in the text editor would corrupt it on save, so editing is disabled — download it to your device instead.';

  @override
  String kanbanTaskCreatedLinkFailed(String error) {
    return 'Task created, but the parent link could not be added: $error';
  }

  @override
  String get kanbanTaskContentSection => 'Task details';

  @override
  String get kanbanTaskArrangementSection => 'Assignment';

  @override
  String get kanbanTaskRuntimeSection => 'Runtime options';

  @override
  String get kanbanTaskRuntimeDescription =>
      'Optional workspace, model, and task relationship settings';

  @override
  String get kanbanCreateTaskDescription =>
      'Describe the work to complete, then choose its status and owner.';

  @override
  String get kanbanTaskTitleHint => 'Enter a clear, concise task name';

  @override
  String get kanbanTaskTitleRequired => 'Enter a task title';

  @override
  String get kanbanTaskDescriptionHint =>
      'Add goals, acceptance criteria, or implementation notes';

  @override
  String get kanbanTaskStatus => 'Status';

  @override
  String get kanbanPriority => 'Priority';

  @override
  String get kanbanAssignee => 'Assignee';

  @override
  String get kanbanTenant => 'Tenant';

  @override
  String get kanbanParentTaskId => 'Parent task ID';

  @override
  String get kanbanWorkspacePath => 'Workspace path';

  @override
  String get kanbanModelOverride => 'Model override';

  @override
  String get kanbanProviderOverride => 'Provider override';

  @override
  String get kanbanEffort => 'Reasoning effort';

  @override
  String get kanbanEffortLow => 'Low';

  @override
  String get kanbanEffortMedium => 'Medium';

  @override
  String get kanbanEffortHigh => 'High';

  @override
  String get kanbanCreatingTask => 'Creating task...';

  @override
  String get kanbanCreateTask => 'Create task';

  @override
  String get kanbanCreateBoard => 'Create board';

  @override
  String get kanbanBoardSettings => 'Board settings';

  @override
  String get kanbanProject => 'Project';

  @override
  String get kanbanNoProject => 'No project';

  @override
  String get kanbanDeleteBoardQuestion => 'Delete board?';

  @override
  String kanbanDeleteBoardDescription(String name) {
    return '$name will be deleted. This cannot be undone.';
  }

  @override
  String kanbanBoardTaskCount(int count) {
    return '$count tasks';
  }

  @override
  String kanbanBoardTaskCountProject(int count, String project) {
    return '$count tasks · $project';
  }

  @override
  String get kanbanRenameBoard => 'Rename board';

  @override
  String pluginsOperationFailed(String error) {
    return 'Could not update plugin: $error';
  }

  @override
  String get pluginsInstallTitle => 'Install agent plugin';

  @override
  String get pluginsIdentifierHint => 'Git URL or owner/repo';

  @override
  String get pluginsEnableAfterInstall => 'Enable after installation';

  @override
  String get pluginsForceReinstall => 'Force reinstall';

  @override
  String pluginsInstalled(String name) {
    return 'Installed $name';
  }

  @override
  String pluginsInstallFailed(String error) {
    return 'Could not install plugin: $error';
  }

  @override
  String get pluginsLoading => 'Loading plugins...';

  @override
  String get pluginsNoData => 'No plugin data';

  @override
  String pluginsSearchHint(int count) {
    return 'Search $count plugins...';
  }

  @override
  String get pluginsNoMatches => 'No matching plugins';

  @override
  String get pluginsKindPlatform => 'Platform';

  @override
  String get pluginsKindProvider => 'Provider';

  @override
  String get pluginsKindTool => 'Tool';

  @override
  String pluginsContributionTooltip(String area, String description) {
    return '$area · $description';
  }

  @override
  String pluginsActionExecuted(String title) {
    return '$title completed';
  }

  @override
  String get pluginsAreaNavigation => 'Navigation';

  @override
  String get pluginsAreaCommand => 'Commands';

  @override
  String get pluginsAreaSettings => 'Settings';

  @override
  String get pluginsAreaComposer => 'Composer';

  @override
  String get pluginsAreaDetail => 'Details';

  @override
  String get pluginsAreaTranscript => 'Transcript';

  @override
  String get pluginsAreaPane => 'Pane';

  @override
  String knowledgeLoadDetailFailed(String error) {
    return 'Could not load node details: $error';
  }

  @override
  String get knowledgeLoading => 'Loading knowledge graph...';

  @override
  String get knowledgeNoData => 'No knowledge data';

  @override
  String get knowledgeSearchHint => 'Search knowledge nodes...';

  @override
  String knowledgeMemorySummary(int count) {
    return 'Memory summary ($count)';
  }

  @override
  String get knowledgeNoMatches => 'No matching knowledge nodes';

  @override
  String get knowledgeStateActive => 'Active';

  @override
  String get knowledgeStateInactive => 'Inactive';

  @override
  String knowledgeNodeMeta(String category, int count, String state) {
    return '$category · used $count times · $state';
  }

  @override
  String knowledgeNodeMetaNoCategory(int count, String state) {
    return 'Used $count times · $state';
  }

  @override
  String get knowledgeSaved => 'Saved';

  @override
  String knowledgeSaveFailed(String error) {
    return 'Could not save node: $error';
  }

  @override
  String get knowledgeDeleteQuestion => 'Delete knowledge node?';

  @override
  String knowledgeDeleteDescription(String name) {
    return '$name will be deleted. This cannot be undone.';
  }

  @override
  String get knowledgeDeleted => 'Knowledge node deleted';

  @override
  String knowledgeDeleteFailed(String error) {
    return 'Could not delete node: $error';
  }

  @override
  String get knowledgeCancelEditing => 'Cancel editing';

  @override
  String skillHubSearchFailed(String error) {
    return 'Skill search failed: $error';
  }

  @override
  String skillHubExitCode(int code) {
    return 'Action exited with code $code';
  }

  @override
  String get skillHubActionTimeout => 'The skill action timed out.';

  @override
  String get skillHubActionDone => 'Action completed';

  @override
  String skillHubActionFailed(String error) {
    return 'Skill action failed: $error';
  }

  @override
  String skillHubUninstallQuestion(String name) {
    return 'Uninstall $name?';
  }

  @override
  String get skillHubUninstallDescription =>
      'The skill will be removed and can be installed again later.';

  @override
  String get skillHubUninstall => 'Uninstall';

  @override
  String get skillHubUpdateInstalled => 'Update installed skills';

  @override
  String get skillHubSearchHint => 'Search the skill marketplace...';

  @override
  String get skillHubLoading => 'Loading skill marketplace...';

  @override
  String skillHubSourcesTimedOut(String sources) {
    return 'Some sources timed out and were omitted: $sources';
  }

  @override
  String get skillHubNoData => 'No marketplace data';

  @override
  String get skillHubSources => 'Sources';

  @override
  String skillHubRateLimited(String name) {
    return '$name (rate limited)';
  }

  @override
  String get skillHubIndexUnavailable =>
      'The skill index is currently unavailable, so search results may be incomplete.';

  @override
  String get skillHubFeatured => 'Featured';

  @override
  String get skillHubSearchPrompt => 'Enter keywords to search for skills';

  @override
  String get skillHubInstalled => 'Installed';

  @override
  String get skillHubTrustOfficial => 'Official';

  @override
  String get skillHubTrustTrusted => 'Trusted';

  @override
  String get skillHubTrustCommunity => 'Community';

  @override
  String get skillHubTrustUnverified => 'Unverified';

  @override
  String get skillHubTrustUntrusted => 'Untrusted';

  @override
  String get skillHubTrustUnknown => 'Unknown trust level';

  @override
  String newSessionInitFailed(String error) {
    return 'Some session options could not be loaded: $error';
  }

  @override
  String newSessionStartFailed(String error) {
    return 'Could not start session: $error';
  }

  @override
  String get newSessionTitleSection => 'Session title';

  @override
  String get newSessionTitleHint =>
      'Optional; leave blank to generate automatically';

  @override
  String get newSessionWorkspace => 'Workspace';

  @override
  String get newSessionWorkspaceHint => 'Agent workspace on the server';

  @override
  String get newSessionBrowseDirectory => 'Browse directories';

  @override
  String get newSessionNoProject => 'No project';

  @override
  String get newSessionMoveLater =>
      'You can move the session later from its menu';

  @override
  String get newSessionUseCurrentModel => 'Use current model';

  @override
  String get newSessionAgent => 'Agent';

  @override
  String get newSessionStarting => 'Starting...';

  @override
  String get newSessionStart => 'Start session';

  @override
  String newSessionAgentSummary(String model, String cwd) {
    return '$model · $cwd';
  }

  @override
  String get newSessionCurrentModel => 'Current model';

  @override
  String get newSessionWorkspaceAbove => 'Workspace above';

  @override
  String get newSessionParentDirectory => 'Parent directory';

  @override
  String get artifactsTitle => 'Artifacts';

  @override
  String get artifactsSearchHint => 'Search artifact titles and sessions...';

  @override
  String get artifactsKindCode => 'Code';

  @override
  String get artifactsKindImage => 'Image';

  @override
  String get artifactsKindLink => 'Link';

  @override
  String get artifactsEmpty => 'No artifacts';

  @override
  String get artifactsEmptyDescription =>
      'Artifacts generated by your sessions will appear here.';

  @override
  String get artifactsNoMatches => 'No matching artifacts';

  @override
  String get artifactsNoMatchesDescription =>
      'Try a different search or filter.';

  @override
  String artifactsOpen(String name) {
    return 'Open artifact $name';
  }

  @override
  String get artifactsSaved => 'Saved';

  @override
  String artifactsSaveFailed(String error) {
    return 'Could not save artifact: $error';
  }

  @override
  String get artifactsSaveToDevice => 'Save to device';

  @override
  String get artifactsCopy => 'Copy artifact';

  @override
  String get artifactsOpenLink => 'Open link';

  @override
  String get artifactsOpenLinkFailed => 'Could not open the link.';

  @override
  String get artifactsImageLoadFailed => 'Could not load image';

  @override
  String get shellReconnecting => 'Disconnected. Reconnecting...';

  @override
  String get shellReconnectNow => 'Reconnect now';

  @override
  String get shellCollapseNavigation => 'Collapse navigation';

  @override
  String get shellExpandNavigation => 'Expand navigation';

  @override
  String get shellNavigation => 'Navigation';

  @override
  String get shellSessionArea => 'Sessions';

  @override
  String get shellWorkspaceArea => 'Workspace';

  @override
  String get shellIntelligenceArea => 'Intelligence';

  @override
  String shellModelStatus(String value) {
    return 'Model $value';
  }

  @override
  String shellWorkspaceStatus(String value) {
    return 'Workspace $value';
  }

  @override
  String shellAgentStatus(String value) {
    return 'Agent $value';
  }

  @override
  String get gitListView => 'List view';

  @override
  String get gitTreeView => 'Tree view';

  @override
  String get gitViewPr => 'View PR';

  @override
  String gitChangeCounts(int staged, int changed) {
    return '$staged staged · $changed changed';
  }

  @override
  String get gitWorkingTreeCleanDescription =>
      'There are no uncommitted changes.';

  @override
  String get gitStagedSection => 'Staged';

  @override
  String get gitUnstagedSection => 'Unstaged';

  @override
  String get gitOpenPrFailed => 'Could not open the pull request.';

  @override
  String gitUnstageFailed(String error) {
    return 'Could not unstage: $error';
  }

  @override
  String get gitCommitAndPushSucceeded => 'Committed and pushed';

  @override
  String get gitCommitSucceeded => 'Committed';

  @override
  String get gitStatusAdded => 'A';

  @override
  String get gitStatusModified => 'M';

  @override
  String get gitStatusDeleted => 'D';

  @override
  String get gitStatusRenamed => 'R';

  @override
  String get gitStatusConflict => 'U';

  @override
  String get insightsTitle => 'Insights';

  @override
  String insightsDays(int count) {
    return '$count days';
  }

  @override
  String insightsLoading(int count) {
    return 'Loading statistics for the last $count days...';
  }

  @override
  String get insightsNoData => 'No usage data';

  @override
  String get insightsOverview => 'Overview';

  @override
  String get insightsSessions => 'Sessions';

  @override
  String get insightsApiCalls => 'API calls';

  @override
  String get insightsCost => 'Cost';

  @override
  String get insightsDailyUsage => 'Daily usage';

  @override
  String get insightsModelUsage => 'Model usage';

  @override
  String get insightsToolCalls => 'Tool calls';

  @override
  String get insightsUnknownProvider => 'Unknown provider';

  @override
  String insightsModelSummary(String tokens, int sessions, String cost) {
    return '$tokens tokens · $sessions sessions · \$$cost';
  }

  @override
  String webhookBaseUrl(String url) {
    return 'Base URL: $url';
  }

  @override
  String get webhookUrl => 'URL';

  @override
  String get webhookSecret => 'Secret';

  @override
  String get toolsTitle => 'Toolsets';

  @override
  String get toolsEmpty => 'No toolsets';

  @override
  String toolsToolsetSummary(int count, String status) {
    return '$count tools · $status';
  }

  @override
  String get toolsTerminalBackend => 'Terminal execution environment';

  @override
  String get toolsReady => 'Ready';

  @override
  String get toolsNeedsSetup => 'Needs setup';

  @override
  String get toolsUnavailable => 'Unavailable';

  @override
  String toolsBackendSwitchFailed(String error) {
    return 'Could not switch terminal environment: $error';
  }

  @override
  String get toolsComputerUseUnsupported =>
      'This backend platform is unsupported';

  @override
  String get toolsComputerUseNotInstalled => 'cua-driver is not installed';

  @override
  String get toolsComputerUseReady => 'Computer Use is ready';

  @override
  String get toolsComputerUseNotReady =>
      'The driver or permissions are not ready';

  @override
  String get toolsRecheck => 'Check again';

  @override
  String get toolsCheck => 'Check';

  @override
  String toolsCheckResult(String label, String result) {
    return '$label: $result';
  }

  @override
  String get toolsWaitingForPermission => 'Waiting for backend permission...';

  @override
  String get toolsRequestPermission => 'Request backend system permission';

  @override
  String get toolsPermissionTimeout => 'The permission request timed out.';

  @override
  String toolsPermissionFailed(String error) {
    return 'Could not request system permission: $error';
  }

  @override
  String toolsToggleFailed(String error) {
    return 'Could not update toolset: $error';
  }

  @override
  String get agentBotsTitle => 'Bots';

  @override
  String agentRequestSummary(String title, String member) {
    return '$title · $member';
  }

  @override
  String modelPickerRefreshFailed(String error) {
    return 'Could not refresh models: $error';
  }

  @override
  String get modelPickerEdit => 'Edit visible models';

  @override
  String modelPickerVisibilitySaveFailed(String error) {
    return 'Could not save model visibility: $error';
  }

  @override
  String get modelPickerMoaPresets => 'MoA presets';

  @override
  String modelPickerMoaModel(String model) {
    return 'MoA: $model';
  }

  @override
  String get modelPickerRefresh => 'Refresh models';

  @override
  String get modelPickerFree => 'Free';

  @override
  String modelPickerFreeDiscount(num percent) {
    return 'Free · -$percent%';
  }

  @override
  String modelPickerPricing(String input, String output, String discount) {
    return 'Input $input / Output $output$discount';
  }

  @override
  String get modelPickerSelectNone => 'Select none';

  @override
  String get modelPickerSelectAll => 'Select all';

  @override
  String get commonCopy => 'Copy';

  @override
  String get chatMermaidDiagram => 'Mermaid diagram';

  @override
  String chatArtifactTitle(String language) {
    return '$language artifact';
  }

  @override
  String chatCodeArtifactTitle(String language, int count) {
    return '$language code · $count lines';
  }

  @override
  String get chatArtifactPreview => 'Artifact preview';

  @override
  String chatCodeTitle(String language) {
    return '$language code';
  }

  @override
  String get chatCodeCopied => 'Code copied';

  @override
  String get chatLivePreview => 'Live preview';

  @override
  String get chatExpandPreview => 'Expand preview in message';

  @override
  String get chatAudioPlaybackFailed => 'Could not play audio';

  @override
  String get chatPauseAudio => 'Pause audio';

  @override
  String get chatPlayAudio => 'Play audio';

  @override
  String get chatOpenVideo => 'Video · tap to open';

  @override
  String get chatOpenFile => 'File · tap to open';

  @override
  String imageSaveFailed(String error) {
    return 'Could not save image: $error';
  }

  @override
  String get voiceMenu => 'Voice menu';

  @override
  String get voiceStopRecording => 'Stop recording';

  @override
  String get voiceDictation => 'Voice input';

  @override
  String get voiceContinuousConversation => 'Continuous voice conversation';

  @override
  String get voiceAutoReadReplies => 'Read replies automatically';

  @override
  String get voiceWakeWord => 'Wake word';

  @override
  String voiceWakePhrase(String phrase) {
    return '\"$phrase\"';
  }

  @override
  String get voiceStopSpeaking => 'Stop reading';

  @override
  String get voiceWakeEnabling => 'Enabling wake word...';

  @override
  String get voiceWakeTriggered => 'Wake word detected. Listening...';

  @override
  String get voiceWakeListening => 'Listening for the wake word';

  @override
  String voiceWakeListeningFor(String phrase) {
    return 'Listening for \"$phrase\"';
  }

  @override
  String get voiceWakeWaiting => 'Wake word waiting to resume';

  @override
  String get voiceWakeDisabled => 'Wake word off';

  @override
  String sessionPrBadge(int number, String status) {
    return 'PR #$number · $status';
  }

  @override
  String get sessionPrOpenFailed => 'Could not open the pull request.';

  @override
  String get sessionCliBadge => 'CLI session';

  @override
  String get sessionDraftBadge => 'Unsent draft';

  @override
  String get sessionSharedBadge => 'Shared';

  @override
  String get sessionHandedOff => 'Handed off';

  @override
  String sessionHandedOffTo(String platform) {
    return 'Handed off · $platform';
  }

  @override
  String sessionHandoffErrorBadge(String error) {
    return 'Handoff error · $error';
  }

  @override
  String sessionCompressionErrorBadge(String error) {
    return 'Context compression temporarily failed · $error';
  }

  @override
  String sessionEndedWithReason(String reason) {
    return 'Ended · $reason';
  }

  @override
  String get sessionEnded => 'Ended';

  @override
  String toolGroupHiddenRestore(int count) {
    return '$count tools hidden; tap to restore';
  }

  @override
  String backgroundStopFailed(String error) {
    return 'Could not stop process: $error';
  }

  @override
  String get backgroundProcessRemoved =>
      'This process has ended and was removed';

  @override
  String get backgroundCloseAndHide => 'Close and hide';

  @override
  String get mcpLogsEmpty => 'No logs';

  @override
  String get subagentTaskProgress => 'Task progress';

  @override
  String get cloudDiscoverAgain => 'Discover again';

  @override
  String get cloudPortalLoginPrompt =>
      'Sign in to the Portal below. Agents will be discovered automatically after sign-in.';

  @override
  String get backgroundTerminal => 'Background terminal';

  @override
  String get backgroundWaitingOutput => 'Waiting for output...';

  @override
  String get backgroundStopping => 'Stopping...';

  @override
  String get backgroundStopProcess => 'Stop process';

  @override
  String get markdownAlertTip => 'Tip';

  @override
  String get markdownAlertImportant => 'Important';

  @override
  String get markdownAlertWarning => 'Warning';

  @override
  String get markdownAlertCaution => 'Caution';

  @override
  String get markdownAlertNote => 'Note';

  @override
  String get richLinkMaps => 'Maps';

  @override
  String turnActivityTools(int count) {
    return '$count tools';
  }

  @override
  String turnActivityReasoning(int count) {
    return '$count reasoning blocks';
  }

  @override
  String toolGroupFailed(int count) {
    return '$count failed';
  }

  @override
  String get messageSourceDingtalk => 'DingTalk';

  @override
  String get profileScopeApplyTo => 'Apply to';

  @override
  String profileScopeChangesApplyTo(String profile) {
    return 'Changes on this page apply to the $profile profile.';
  }

  @override
  String get profileScopeConfiguring => 'Configuring';

  @override
  String profileScopeCurrent(String name) {
    return '$name (current)';
  }

  @override
  String get mcpLogsAllServers => 'All servers';

  @override
  String get mcpLogsLoading => 'Loading logs...';

  @override
  String badgeUnreadCount(String count) {
    return '$count unread';
  }

  @override
  String progressPercent(int percent) {
    return '$percent% complete';
  }

  @override
  String avatarNamed(String name) {
    return 'Avatar: $name';
  }

  @override
  String get avatarUnnamed => 'Avatar';

  @override
  String get thinkingActive => 'Thinking';

  @override
  String get thinkingProcess => 'Reasoning';

  @override
  String get thinkingBriefly => 'Thought briefly';

  @override
  String thinkingSeconds(String seconds) {
    return 'Thought for ${seconds}s';
  }

  @override
  String thinkingMinutes(int minutes, int seconds) {
    return 'Thought for ${minutes}m ${seconds}s';
  }

  @override
  String thinkingGeneratedCharacters(int count) {
    return 'Generated $count characters';
  }

  @override
  String thinkingCharacters(int count) {
    return '$count characters';
  }

  @override
  String get thinkingAnalyzing => 'Analyzing context...';

  @override
  String get commonNoData => 'No data';

  @override
  String get commonFeatureDisabled => 'Feature disabled';

  @override
  String get cloudDiscoveryFailed => 'Cloud discovery failed';

  @override
  String cloudDiscoveryInvalidData(String error) {
    return 'Cloud returned unrecognized data: $error';
  }

  @override
  String get cloudDiscoveryUnsupported =>
      'Hermes Cloud discovery is not supported on this platform';

  @override
  String sessionCreateFailed(String error) {
    return 'Could not create the session: $error';
  }

  @override
  String get statusReady => 'Ready';

  @override
  String get workspaceDescription => 'Session tiles and plugin panes';

  @override
  String get subagentFallbackName => 'Subagent';

  @override
  String get subagentNoTask => 'No task description';

  @override
  String get subagentsStatusRunning => 'Running';

  @override
  String get subagentsStatusCompleted => 'Completed';

  @override
  String get subagentsStatusFailed => 'Failed';

  @override
  String subagentCardTitle(String name) {
    return 'Subagent · $name';
  }

  @override
  String get subagentTask => 'Task';

  @override
  String get subagentModel => 'Model';

  @override
  String get subagentCurrentTool => 'Current tool';

  @override
  String get subagentSummary => 'Summary';

  @override
  String sessionApiCallCount(int count) {
    return '$count API calls';
  }

  @override
  String sessionTokenCount(String count) {
    return '$count tokens';
  }

  @override
  String get diagnosticsConsentDescription =>
      'Redacted server logs and system and provider configuration will be uploaded. Logs may contain conversation content, tool output, and file paths. API keys are never uploaded, and the diagnostic bundle is deleted after 14 days.';

  @override
  String get diagnosticsApproveUpload => 'Agree and upload';

  @override
  String get diagnosticsGatewayUnavailable =>
      'Not connected to the Hermes gateway';

  @override
  String get diagnosticsUploadFailed => 'Upload failed';

  @override
  String get diagnosticsSentTitle => 'Diagnostics sent';

  @override
  String get diagnosticsLinkCopied =>
      'The view link was copied to the clipboard:';

  @override
  String get diagnosticsSupportPrompt => 'For more help, contact us through:';

  @override
  String diagnosticsSendFailed(String error) {
    return 'Could not send diagnostics: $error';
  }

  @override
  String get slashDescRetry => 'Regenerate the previous response';

  @override
  String get slashDescClear => 'Clear the current session view';

  @override
  String get slashDescUndo => 'Undo the last complete turn';

  @override
  String get slashDescSteer => 'Add guidance to the current turn';

  @override
  String get slashDescStatus => 'View session status';

  @override
  String get slashDescTitle => 'Regenerate the session title';

  @override
  String get slashDescNew => 'Start a new session';

  @override
  String get slashDescYolo => 'Toggle YOLO auto-approval';

  @override
  String get slashDescHandoff => 'Open session handoff';

  @override
  String get slashDescProfile => 'Choose a profile or personality';

  @override
  String get slashDescHelp => 'List local and catalog slash commands';

  @override
  String get slashDescBackground => 'Submit a background task';

  @override
  String get slashDescCompress => 'Compress the current session context';

  @override
  String get slashDescQueue => 'Add the message to the send queue';

  @override
  String get slashDescUsage => 'View usage for this session';

  @override
  String get slashDescVersion => 'Show Hermes and mobile versions';

  @override
  String get slashDescStop => 'Stop the current turn';

  @override
  String get slashDescTools => 'Open tool configuration';

  @override
  String get slashDescApprovals => 'Set approval mode: manual / smart / off';

  @override
  String get slashDescModel => 'Open the model picker';

  @override
  String get slashDescWake => 'Manage wake word: status / on / off / toggle';

  @override
  String get slashDescSkinUnavailable => 'Desktop-only skin command';

  @override
  String get slashDescBrowserUnavailable =>
      'Desktop-only built-in browser command';

  @override
  String get slashDescJourney => 'Open the Starmap journey';

  @override
  String get slashDescPet => 'Open the pet center';

  @override
  String get slashDescHatch => 'Generate and hatch a new pet';

  @override
  String get slashDescSave => 'Save the current session transcript';

  @override
  String get slashDescReloadConfigUnavailable =>
      'reload-config is not supported by Mobile or Gateway';

  @override
  String get cronSuggestionPrefix => 'Schedule this as a recurring task: ';

  @override
  String get kanbanTaskCompletedNotification => 'Kanban task completed';

  @override
  String get kanbanTaskProblemNotification => 'Kanban task needs attention';

  @override
  String get themeGraphite => 'Graphite';

  @override
  String get themeIndigo => 'Indigo';

  @override
  String get themeMoss => 'Moss';

  @override
  String get themeDune => 'Dune';

  @override
  String get connectTransportMobileServer => 'Mobile Server';

  @override
  String get connectTransportDirectGateway => 'Direct Gateway';

  @override
  String get connectTransportSsh => 'SSH';

  @override
  String get connectAuthOauth => 'OAuth';

  @override
  String get connectAuthToken => 'Token';

  @override
  String get mcpAuthOauth => 'OAuth';

  @override
  String get mcpAuthBearerToken => 'Bearer token';

  @override
  String get gitAgentShipTitle => 'Agent Ship';

  @override
  String get commonUrl => 'URL';

  @override
  String get toolEmptyList => '(Empty list)';

  @override
  String toolItemCount(int count) {
    return '$count items';
  }

  @override
  String toolFieldCount(int count) {
    return '$count fields';
  }

  @override
  String get toolPath => 'Path';

  @override
  String get toolLanguage => 'Language';

  @override
  String get toolText => 'Text';

  @override
  String get toolMessage => 'Message';

  @override
  String get toolSummary => 'Summary';

  @override
  String get toolExecuteCommand => 'Run command';

  @override
  String get toolRunCode => 'Run code';

  @override
  String toolRunCodeLanguage(String language) {
    return 'Run $language code';
  }

  @override
  String toolSearchFor(String query) {
    return 'Search: $query';
  }

  @override
  String get toolExtractWeb => 'Extract web page';

  @override
  String get toolApplyPatch => 'Apply file patch';

  @override
  String get toolListFiles => 'List files';

  @override
  String get toolGenerateImage => 'Generate image';

  @override
  String get toolDelegateTask => 'Delegated task';

  @override
  String toolTask(int index) {
    return 'Task $index';
  }

  @override
  String toolRunEditingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Editing $count files',
      one: 'Editing 1 file',
    );
    return '$_temp0';
  }

  @override
  String toolRunExploringFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Exploring $count files',
      one: 'Exploring 1 file',
    );
    return '$_temp0';
  }

  @override
  String toolRunRunningCommands(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Running $count commands',
      one: 'Running 1 command',
    );
    return '$_temp0';
  }

  @override
  String toolRunDelegatingTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delegating $count tasks',
      one: 'Delegating 1 task',
    );
    return '$_temp0';
  }

  @override
  String toolRunUsingTools(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Using $count tools',
      one: 'Using 1 tool',
    );
    return '$_temp0';
  }

  @override
  String toolRunEditedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Edited $count files',
      one: 'Edited 1 file',
    );
    return '$_temp0';
  }

  @override
  String toolRunExploredFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Explored $count files',
      one: 'Explored 1 file',
    );
    return '$_temp0';
  }

  @override
  String toolRunRanCommands(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ran $count commands',
      one: 'Ran 1 command',
    );
    return '$_temp0';
  }

  @override
  String toolRunDelegatedTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delegated $count tasks',
      one: 'Delegated 1 task',
    );
    return '$_temp0';
  }

  @override
  String toolRunUsedTools(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Used $count tools',
      one: 'Used 1 tool',
    );
    return '$_temp0';
  }

  @override
  String get notificationBackgroundCompleted => 'Background task completed';

  @override
  String get notificationBackgroundCompletedBody =>
      'A background task completed. Tap to view the result.';

  @override
  String get notificationApprovalRequired => 'Approval required';

  @override
  String get notificationApprovalRequiredBody =>
      'The agent is requesting approval for a sensitive operation.';

  @override
  String get voiceServerDisconnected => 'Not connected to the server';

  @override
  String get voiceRecordingUnsupported =>
      'Microphone recording is not supported on this platform';

  @override
  String get voiceMicrophoneStartFailed =>
      'Microphone permission was denied or recording could not start';

  @override
  String voiceRecordingFailed(String error) {
    return 'Recording failed: $error';
  }

  @override
  String get voiceNoSpeech => 'I couldn\'t hear that. Try again.';

  @override
  String get voiceSttUnavailable =>
      'Speech-to-text (STT) is not configured on the server';

  @override
  String voiceTranscriptionFailed(String error) {
    return 'Transcription failed: $error';
  }

  @override
  String voiceSpeechFailed(String error) {
    return 'Voice playback failed: $error';
  }

  @override
  String voiceStreamingSpeechFailed(String error) {
    return 'Streaming voice playback failed: $error';
  }

  @override
  String get voiceWakeInstallNotice =>
      'Enabling wake word. The detection engine may need to be installed the first time.';

  @override
  String get voiceWakeUsage => 'Usage: /wake [status|on|off|toggle]';

  @override
  String get voiceWakeNotEnabled => 'Wake word is not enabled';

  @override
  String get voiceWakeOtherSurface => 'Wake word is assigned to another device';

  @override
  String get voiceWakeOwned => 'Another device is listening for the wake word';

  @override
  String get voiceWakeUnavailable => 'This backend does not support wake word';

  @override
  String voiceWakeMicInterrupted(String error) {
    return 'Wake word microphone interrupted: $error';
  }

  @override
  String get voiceWakeMicPermission =>
      'Microphone permission was denied, so wake word cannot listen';

  @override
  String voiceWakeMicStartFailed(String error) {
    return 'Could not start the wake word microphone: $error';
  }

  @override
  String voiceWakeAudioUploadFailed(String error) {
    return 'Could not send wake word audio: $error';
  }

  @override
  String get filesThisComputer => 'This computer';

  @override
  String get billingSavedPaymentMethod => 'Saved payment method';

  @override
  String billingPaymentMethodKind(String kind) {
    return 'Payment method · $kind';
  }

  @override
  String get previewTourBack => 'Back';

  @override
  String get previewTourDone => 'Done';

  @override
  String get previewTourNext => 'Next';

  @override
  String get chatMermaidParseError => 'Could not parse Mermaid diagram';

  @override
  String get petDefaultName => 'Hermes Pet';

  @override
  String get sessionDetailProfile => 'Profile';

  @override
  String get profileArchiveType => 'Hermes profile';

  @override
  String get profilesTemperature => 'Temperature';

  @override
  String get profilesTopP => 'Top P';

  @override
  String get profilesMaxTokens => 'Max tokens';

  @override
  String get sessionDesktopFallback => 'Desktop session';

  @override
  String get backgroundProcessFallback => 'Background process';

  @override
  String get insightsUnknownModel => 'Unknown model';

  @override
  String get billingCard => 'Card';

  @override
  String get billingLink => 'Link';

  @override
  String get slashGroupSkills => 'Skills';

  @override
  String get slashGroupCommands => 'Commands';

  @override
  String get botAuthorYou => 'You';

  @override
  String get botAuthorSystem => 'System';

  @override
  String get botAuthorFallback => 'Bot';

  @override
  String terminalErrorMessage(String error) {
    return 'Terminal error: $error';
  }

  @override
  String sessionCopyTitle(String title) {
    return '$title (copy)';
  }

  @override
  String get gitRemoteFallback => 'Remote';

  @override
  String get gitStashFallback => 'Stash';

  @override
  String get notificationChannelErrors => 'Errors';

  @override
  String get notificationChannelWarnings => 'Warnings';

  @override
  String get notificationChannelSuccess => 'Success';

  @override
  String get notificationChannelApprovals => 'Approvals';

  @override
  String get notificationChannelInfo => 'Info';

  @override
  String get memoryCuratorTitle => 'Curator';

  @override
  String get messageSourceServer => 'Server';

  @override
  String get messageSourceMobile => 'Mobile';

  @override
  String get kanbanRunQueued => 'Queued';

  @override
  String get kanbanRunCompleted => 'Completed';

  @override
  String get kanbanRunFailed => 'Failed';

  @override
  String get kanbanRunCancelled => 'Cancelled';

  @override
  String get kanbanEventTaskCreated => 'Task created';

  @override
  String get kanbanEventTaskUpdated => 'Task updated';

  @override
  String get kanbanEventTaskDeleted => 'Task deleted';

  @override
  String get kanbanEventRunStarted => 'Run started';

  @override
  String get kanbanEventRunCompleted => 'Run completed';

  @override
  String get kanbanEventRunFailed => 'Run failed';

  @override
  String get kanbanEventRunCancelled => 'Run cancelled';

  @override
  String get kanbanEventCommentCreated => 'Comment added';

  @override
  String get kanbanEventAttachmentAdded => 'Attachment added';

  @override
  String get kanbanEventAttachmentDeleted => 'Attachment deleted';

  @override
  String get cloudRoleOwner => 'Owner';

  @override
  String get cloudRoleAdmin => 'Administrator';

  @override
  String get cloudRoleMember => 'Member';

  @override
  String get cloudRoleViewer => 'Viewer';

  @override
  String get chatStatusToolDrafting => 'Preparing tool call';

  @override
  String get chatStatusProvider => 'Provider status';

  @override
  String get previewScriptError => 'Script error';

  @override
  String get previewUnhandledPromiseRejection =>
      'Unhandled promise rejection: ';

  @override
  String botGroupSessionTitle(String roomId) {
    return 'Group: $roomId';
  }

  @override
  String get errorExpectedObjectResponse =>
      'The server returned an invalid object response';

  @override
  String get errorTtsNoAudio => 'Text-to-speech returned no audio';

  @override
  String get errorInvalidDataUrl => 'The server returned an invalid data URL';

  @override
  String get errorExportDirectoryMissing =>
      'The server did not provide an export directory';

  @override
  String get errorImportDirectoryMissing =>
      'The server did not provide an import directory';

  @override
  String get errorRawConfigInvalid =>
      'The server returned an invalid raw configuration';

  @override
  String get errorPluginToggleRejected =>
      'The backend rejected the plugin change';

  @override
  String get errorConnectionNotConfigured => 'The connection is not configured';

  @override
  String errorSessionOwnerUnknown(String sessionId) {
    return 'The session owner is unknown: $sessionId';
  }

  @override
  String get errorRemotePushUnavailable =>
      'Remote push is unavailable for this connection';

  @override
  String get sshCommandTimedOut => 'SSH command timed out';

  @override
  String get sshRemoteHomeUnsafe => 'The remote Hermes home is unsafe';

  @override
  String get sshOwnershipVerificationFailed =>
      'Could not verify remote Hermes process ownership';

  @override
  String sshOwnershipProbeFailed(String status) {
    return 'Remote ownership probe failed ($status)';
  }

  @override
  String get sshHelperInvalidJson => 'The remote helper returned invalid JSON';

  @override
  String get sshWindowsOwnershipVerificationFailed =>
      'Could not verify remote Windows process ownership';

  @override
  String get sshRemotePathInvalid =>
      'The remote Hermes path must be absolute or start with ~/';

  @override
  String get sshExecutableNotFound =>
      'The configured Hermes executable was not found on the remote host';

  @override
  String get sshHermesNotInstalled =>
      'Hermes is not installed on the remote host';

  @override
  String get sshBootstrapFlagsUnsupported =>
      'Remote Hermes must support secure SSH ownership bootstrap flags';

  @override
  String get sshWindowsIdentityInvalid =>
      'The remote Windows backend returned an invalid identity';

  @override
  String get sshWindowsExitedBeforeReady =>
      'The remote Windows backend exited before becoming ready';

  @override
  String get sshWindowsOwnershipProofFailed =>
      'Remote Windows ownership proof failed';

  @override
  String get sshProcessIdMissing => 'Remote Hermes did not return a process ID';

  @override
  String get sshExitedBeforeReady =>
      'Remote Hermes exited before becoming ready';

  @override
  String get sshOwnershipProofFailed => 'Remote Hermes ownership proof failed';

  @override
  String get errorSessionBranchIdMissing =>
      'Hermes did not return a durable branched session ID';

  @override
  String get errorDuplicateImportFailed =>
      'Hermes did not import the duplicated session';

  @override
  String get errorSessionNoTitleableMessages =>
      'The session has no messages that can be used to generate a title';

  @override
  String get errorTitleGeneratorEmpty =>
      'The title generator returned an empty title';

  @override
  String get errorProjectIdRequired => 'A project is required';

  @override
  String get errorProjectWorkingFolderMissing =>
      'The target project has no working folder';

  @override
  String get errorDownloadFailed => 'Download failed';

  @override
  String get errorMessagingPlatformNotFound => 'Messaging platform not found';

  @override
  String errorBotGroupSessionStartFailed(String name) {
    return '$name\'s group session did not start';
  }

  @override
  String sshRemoteCommandFailed(String code) {
    return 'Remote command failed ($code)';
  }

  @override
  String get sshHostAndUserRequired => 'SSH host and user are required';

  @override
  String get sshPortInvalid => 'SSH port must be between 1 and 65535';

  @override
  String sshHostKeyChanged(String host, String expected, String received) {
    return 'The SSH host key for $host changed. Expected $expected; received $received';
  }

  @override
  String get sshProfileInvalid => 'The remote profile name is invalid';

  @override
  String get errorDirectGatewayFeatureUnavailable =>
      'This feature requires Hermes Mobile Server and is unavailable on a direct Gateway connection';

  @override
  String errorOperationFailedWithDetail(String error) {
    return 'Operation failed: $error';
  }

  @override
  String gatewayOauthRejected(String error) {
    return 'Gateway rejected sign-in: $error';
  }

  @override
  String get gatewayOauthCodeMissing =>
      'The Gateway callback is missing the authorization code';

  @override
  String get gatewayOauthStateMismatch =>
      'The Gateway callback state did not match. Sign-in was cancelled for security.';

  @override
  String get gatewayOauthRefreshTokenMissing =>
      'The Gateway session expired and has no refresh token';

  @override
  String get gatewayOauthTicketMissing =>
      'The Gateway did not return a WebSocket ticket';

  @override
  String get gatewayOauthAccessTokenMissing =>
      'The Gateway token response did not include an access token';

  @override
  String get gatewayOauthTimedOut => 'Gateway sign-in timed out';

  @override
  String get gatewayOauthNativeUnsupported =>
      'Native Gateway OAuth is not supported on this platform';

  @override
  String get updateManifestInvalid => 'The update manifest is invalid';

  @override
  String sshRemotePlatformUnsupported(String error) {
    return 'The remote platform is unsupported: $error';
  }

  @override
  String get sshWebUnsupported =>
      'Native SSH connections are not supported on web';

  @override
  String get filesDownloadPlatformUnsupported =>
      'Local file download is unavailable on this platform';

  @override
  String get sessionExportPlatformUnsupported =>
      'Local file export is unavailable on this platform';

  @override
  String get errorPluginCanonicalKeyRequired =>
      'This plugin needs a canonical key before it can be changed';

  @override
  String get connectGatewayToken => 'Gateway token';

  @override
  String get modelMoaTitle => 'Mixture of Agents';

  @override
  String get insightsTokens => 'Tokens';

  @override
  String get messageWebFallback => 'Web';

  @override
  String get mcpLogsSourceStdio => 'stdio';

  @override
  String get mcpLogsSourceAgent => 'Agent';

  @override
  String get projectPrimaryFolder => 'Main';

  @override
  String get botGroupNameRequired => 'Enter a group name';

  @override
  String get botGroupMembersMinimum => 'A group needs at least two bots';

  @override
  String botGroupMembersRange(int max) {
    return 'A group needs 2–$max bots';
  }

  @override
  String botGroupMembersMaximum(int max) {
    return 'A group supports at most $max bots';
  }

  @override
  String get botGroupMemberUnavailable => 'No group member is available';

  @override
  String get botProfileNameUnavailable => 'No free profile name is available';

  @override
  String get botDefaultProfileDeleteForbidden =>
      'The default profile cannot be deleted';

  @override
  String get botConnectionUnavailable => 'The bot connection is unavailable';

  @override
  String get botTurnFailed => 'The bot turn failed';

  @override
  String get mcpInvalidJsonSyntax => 'The JSON syntax is invalid';

  @override
  String get mcpJsonObjectRequired =>
      'The top-level JSON value must be an object';

  @override
  String get voiceWakeMicStreamEnded =>
      'The wake word microphone stream ended unexpectedly';

  @override
  String httpStatusError(int statusCode) {
    return 'The server returned HTTP $statusCode';
  }
}
