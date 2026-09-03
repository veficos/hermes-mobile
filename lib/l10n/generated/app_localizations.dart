import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @commonCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy to the clipboard'**
  String get commonCopyFailed;

  /// No description provided for @commonClipboardReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the clipboard'**
  String get commonClipboardReadFailed;

  /// No description provided for @petGenerateReferenceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add the reference image: {error}'**
  String petGenerateReferenceFailed(String error);

  /// No description provided for @petSelectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not select pet: {error}'**
  String petSelectFailed(String error);

  /// No description provided for @terminalSshNamed.
  ///
  /// In en, this message translates to:
  /// **'SSH {host}'**
  String terminalSshNamed(String host);

  /// No description provided for @deepLinkUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported Hermes link'**
  String get deepLinkUnsupported;

  /// No description provided for @deepLinkMcpNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid MCP name format'**
  String get deepLinkMcpNameInvalid;

  /// No description provided for @deepLinkMcpConfigMissing.
  ///
  /// In en, this message translates to:
  /// **'MCP link is missing configuration'**
  String get deepLinkMcpConfigMissing;

  /// No description provided for @deepLinkMcpConfigTooLarge.
  ///
  /// In en, this message translates to:
  /// **'MCP configuration exceeds 32 KiB'**
  String get deepLinkMcpConfigTooLarge;

  /// No description provided for @deepLinkMcpEncodingInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid MCP configuration encoding'**
  String get deepLinkMcpEncodingInvalid;

  /// No description provided for @deepLinkMcpJsonInvalid.
  ///
  /// In en, this message translates to:
  /// **'MCP configuration is not valid JSON'**
  String get deepLinkMcpJsonInvalid;

  /// No description provided for @deepLinkMcpObjectRequired.
  ///
  /// In en, this message translates to:
  /// **'MCP configuration must be an object'**
  String get deepLinkMcpObjectRequired;

  /// No description provided for @deepLinkMcpUrlCommandConflict.
  ///
  /// In en, this message translates to:
  /// **'MCP configuration cannot contain both a URL and a command'**
  String get deepLinkMcpUrlCommandConflict;

  /// No description provided for @deepLinkMcpHttpOnly.
  ///
  /// In en, this message translates to:
  /// **'MCP URL must use HTTP or HTTPS'**
  String get deepLinkMcpHttpOnly;

  /// No description provided for @deepLinkMcpEndpointMissing.
  ///
  /// In en, this message translates to:
  /// **'MCP configuration is missing a URL or command'**
  String get deepLinkMcpEndpointMissing;

  /// No description provided for @terminalConnectionClosed.
  ///
  /// In en, this message translates to:
  /// **'Terminal connection is closed'**
  String get terminalConnectionClosed;

  /// No description provided for @terminalRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send terminal request: {error}'**
  String terminalRequestFailed(String error);

  /// No description provided for @terminalGenericError.
  ///
  /// In en, this message translates to:
  /// **'Terminal error'**
  String get terminalGenericError;

  /// No description provided for @botUntitledTask.
  ///
  /// In en, this message translates to:
  /// **'Untitled task'**
  String get botUntitledTask;

  /// No description provided for @botMemberPaused.
  ///
  /// In en, this message translates to:
  /// **'{name} is paused. Mention this member or send resume to continue.'**
  String botMemberPaused(String name);

  /// No description provided for @botGroupRoundCapReached.
  ///
  /// In en, this message translates to:
  /// **'This round of discussion reached its limit. Send a new message to continue.'**
  String get botGroupRoundCapReached;

  /// No description provided for @botGroupMessageCapReached.
  ///
  /// In en, this message translates to:
  /// **'This conversation reached its message limit. Send a new message to continue.'**
  String get botGroupMessageCapReached;

  /// No description provided for @botRoutineFieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'Task name, instruction, and schedule are required'**
  String get botRoutineFieldsRequired;

  /// No description provided for @botRoutineNulForbidden.
  ///
  /// In en, this message translates to:
  /// **'Task name, instruction, and schedule cannot contain NUL'**
  String get botRoutineNulForbidden;

  /// No description provided for @pluginLoadActionReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Plugin view.load_action must be read-only'**
  String get pluginLoadActionReadOnly;

  /// No description provided for @pluginMethodMissing.
  ///
  /// In en, this message translates to:
  /// **'Plugin action is missing method'**
  String get pluginMethodMissing;

  /// No description provided for @pluginPathInvalid.
  ///
  /// In en, this message translates to:
  /// **'Plugin action path is invalid'**
  String get pluginPathInvalid;

  /// No description provided for @pluginMethodUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Plugin REST method is unsupported: {method}'**
  String pluginMethodUnsupported(String method);

  /// No description provided for @pluginUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'Plugin action URL is invalid'**
  String get pluginUrlInvalid;

  /// No description provided for @pluginUrlSchemeUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Plugin action URL scheme is unsupported'**
  String get pluginUrlSchemeUnsupported;

  /// No description provided for @pluginLinkOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open link'**
  String get pluginLinkOpenFailed;

  /// No description provided for @pluginNotificationFieldsMissing.
  ///
  /// In en, this message translates to:
  /// **'Plugin notification action is missing title or message'**
  String get pluginNotificationFieldsMissing;

  /// No description provided for @pluginNotificationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Notifications are unavailable in this host'**
  String get pluginNotificationUnavailable;

  /// No description provided for @pluginActionUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Plugin action is unsupported on mobile: {kind}'**
  String pluginActionUnsupported(String kind);

  /// No description provided for @kanbanTaskAlreadyRunning.
  ///
  /// In en, this message translates to:
  /// **'Task is already running'**
  String get kanbanTaskAlreadyRunning;

  /// No description provided for @gatewayUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Hermes backend Gateway is unavailable'**
  String get gatewayUnavailable;

  /// No description provided for @filesDirectoryMissing.
  ///
  /// In en, this message translates to:
  /// **'Directory does not exist'**
  String get filesDirectoryMissing;

  /// No description provided for @filesFolderFallback.
  ///
  /// In en, this message translates to:
  /// **'This platform cannot list local folders; select multiple files instead'**
  String get filesFolderFallback;

  /// No description provided for @billingCreditsExhausted.
  ///
  /// In en, this message translates to:
  /// **'Balance or credit limit exhausted'**
  String get billingCreditsExhausted;

  /// No description provided for @workspacePaneLimit.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} panes can be open in the workspace'**
  String workspacePaneLimit(int count);

  /// No description provided for @projectMissing.
  ///
  /// In en, this message translates to:
  /// **'Project does not exist or was deleted'**
  String get projectMissing;

  /// No description provided for @updateHttpError.
  ///
  /// In en, this message translates to:
  /// **'Update service returned HTTP {status}'**
  String updateHttpError(int status);

  /// No description provided for @chatCompactingThread.
  ///
  /// In en, this message translates to:
  /// **'Summarizing thread'**
  String get chatCompactingThread;

  /// No description provided for @chatModelChanged.
  ///
  /// In en, this message translates to:
  /// **'Model changed'**
  String get chatModelChanged;

  /// No description provided for @chatTurnContinued.
  ///
  /// In en, this message translates to:
  /// **'Interrupted turn continued'**
  String get chatTurnContinued;

  /// No description provided for @chatPersonalityChanged.
  ///
  /// In en, this message translates to:
  /// **'Personality changed'**
  String get chatPersonalityChanged;

  /// No description provided for @chatDelegationCompleted.
  ///
  /// In en, this message translates to:
  /// **'Background agent work completed'**
  String get chatDelegationCompleted;

  /// No description provided for @chatDelegationCountCompleted.
  ///
  /// In en, this message translates to:
  /// **'{count} background agent tasks completed'**
  String chatDelegationCountCompleted(int count);

  /// No description provided for @chatHermesNotification.
  ///
  /// In en, this message translates to:
  /// **'Hermes notification'**
  String get chatHermesNotification;

  /// No description provided for @chatBrowserTask.
  ///
  /// In en, this message translates to:
  /// **'Browser task'**
  String get chatBrowserTask;

  /// No description provided for @chatPreviewRestart.
  ///
  /// In en, this message translates to:
  /// **'Preview service restart'**
  String get chatPreviewRestart;

  /// No description provided for @chatPreparingTool.
  ///
  /// In en, this message translates to:
  /// **'Preparing {name}'**
  String chatPreparingTool(String name);

  /// No description provided for @chatMoaAggregating.
  ///
  /// In en, this message translates to:
  /// **'◇ Aggregating multi-model results...'**
  String get chatMoaAggregating;

  /// No description provided for @chatMoaCollaboration.
  ///
  /// In en, this message translates to:
  /// **'Multi-model collaboration'**
  String get chatMoaCollaboration;

  /// No description provided for @chatCurrentGoal.
  ///
  /// In en, this message translates to:
  /// **'Current goal'**
  String get chatCurrentGoal;

  /// No description provided for @chatCodeReview.
  ///
  /// In en, this message translates to:
  /// **'Code review'**
  String get chatCodeReview;

  /// No description provided for @chatHermesRunFailed.
  ///
  /// In en, this message translates to:
  /// **'Hermes run failed'**
  String get chatHermesRunFailed;

  /// No description provided for @chatPlanItem.
  ///
  /// In en, this message translates to:
  /// **'Plan item'**
  String get chatPlanItem;

  /// No description provided for @chatAssistantReplyFailed.
  ///
  /// In en, this message translates to:
  /// **'Assistant reply failed'**
  String get chatAssistantReplyFailed;

  /// No description provided for @terminalServerNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Server is not configured'**
  String get terminalServerNotConfigured;

  /// No description provided for @terminalLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} terminals can be open at once. Close a session first.'**
  String terminalLimitReached(int count);

  /// No description provided for @terminalNumbered.
  ///
  /// In en, this message translates to:
  /// **'Terminal {number}'**
  String terminalNumbered(int number);

  /// No description provided for @terminalSnapshotStart.
  ///
  /// In en, this message translates to:
  /// **'-- Read-only output snapshot from the previous session --'**
  String get terminalSnapshotStart;

  /// No description provided for @terminalSnapshotEnd.
  ///
  /// In en, this message translates to:
  /// **'-- Snapshot ended; restoring terminal --'**
  String get terminalSnapshotEnd;

  /// No description provided for @terminalSshHostRequired.
  ///
  /// In en, this message translates to:
  /// **'SSH host is required'**
  String get terminalSshHostRequired;

  /// No description provided for @terminalRestartingShell.
  ///
  /// In en, this message translates to:
  /// **'-- Restarting shell... --'**
  String get terminalRestartingShell;

  /// No description provided for @terminalOpenedNewShell.
  ///
  /// In en, this message translates to:
  /// **'-- Could not restore the original shell; opened a new shell --'**
  String get terminalOpenedNewShell;

  /// No description provided for @terminalPtyIdMissing.
  ///
  /// In en, this message translates to:
  /// **'The server did not return a PTY session ID'**
  String get terminalPtyIdMissing;

  /// No description provided for @terminalShellExited.
  ///
  /// In en, this message translates to:
  /// **'-- Shell exited{code, select, other{ (code {code})} empty{}} · Tap Restart to continue --'**
  String terminalShellExited(String code);

  /// No description provided for @terminalReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Terminal connection interrupted. Reconnecting...'**
  String get terminalReconnecting;

  /// No description provided for @terminalRestoringShell.
  ///
  /// In en, this message translates to:
  /// **'-- Connection interrupted; restoring or reopening shell... --'**
  String get terminalRestoringShell;

  /// No description provided for @terminalConnectionRestored.
  ///
  /// In en, this message translates to:
  /// **'-- Terminal connection restored --'**
  String get terminalConnectionRestored;

  /// No description provided for @terminalConnectionRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'-- Could not restore terminal connection --'**
  String get terminalConnectionRestoreFailed;

  /// No description provided for @terminalReconnected.
  ///
  /// In en, this message translates to:
  /// **'Terminal reconnected; a new shell may have been opened'**
  String get terminalReconnected;

  /// No description provided for @terminalReconnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reconnect the terminal. Create a new terminal manually.'**
  String get terminalReconnectFailed;

  /// No description provided for @sessionChooseHandoffPlatform.
  ///
  /// In en, this message translates to:
  /// **'Choose a handoff platform'**
  String get sessionChooseHandoffPlatform;

  /// No description provided for @sessionHandoffTargetFailed.
  ///
  /// In en, this message translates to:
  /// **'Handoff to {target} failed'**
  String sessionHandoffTargetFailed(String target);

  /// No description provided for @sessionHandoffTimeout.
  ///
  /// In en, this message translates to:
  /// **'Handoff timed out. Try again.'**
  String get sessionHandoffTimeout;

  /// No description provided for @sessionNoActive.
  ///
  /// In en, this message translates to:
  /// **'No active session'**
  String get sessionNoActive;

  /// No description provided for @sessionLoadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load more sessions: {error}'**
  String sessionLoadMoreFailed(String error);

  /// No description provided for @sessionOfflineTranscript.
  ///
  /// In en, this message translates to:
  /// **'Offline mode: showing the cached transcript'**
  String get sessionOfflineTranscript;

  /// No description provided for @sessionTranscriptRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh transcript: {error}'**
  String sessionTranscriptRefreshFailed(String error);

  /// No description provided for @sessionOlderMessagesFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load older messages: {error}'**
  String sessionOlderMessagesFailed(String error);

  /// No description provided for @sessionListLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load sessions: {error}'**
  String sessionListLoadFailed(String error);

  /// No description provided for @sessionProfileSwitching.
  ///
  /// In en, this message translates to:
  /// **'The profile is switching. Try again shortly.'**
  String get sessionProfileSwitching;

  /// No description provided for @sessionSubagentReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Subagent sessions are read-only'**
  String get sessionSubagentReadOnly;

  /// No description provided for @sessionChangedRetry.
  ///
  /// In en, this message translates to:
  /// **'The session changed. Try again shortly.'**
  String get sessionChangedRetry;

  /// No description provided for @sessionConnectionUnknown.
  ///
  /// In en, this message translates to:
  /// **'The session connection is unknown: {id}'**
  String sessionConnectionUnknown(String id);

  /// No description provided for @sessionConnectionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The session connection is unavailable: {id}'**
  String sessionConnectionUnavailable(String id);

  /// No description provided for @sessionUnsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'The session has not been saved, so a title cannot be generated'**
  String get sessionUnsavedTitle;

  /// No description provided for @sessionShareLinkMissing.
  ///
  /// In en, this message translates to:
  /// **'The server did not return a share link'**
  String get sessionShareLinkMissing;

  /// No description provided for @sessionBatchDeletePartial.
  ///
  /// In en, this message translates to:
  /// **'Deleted {deleted}; {failed} failed'**
  String sessionBatchDeletePartial(int deleted, int failed);

  /// No description provided for @sessionCouldNotCreate.
  ///
  /// In en, this message translates to:
  /// **'Could not create a session'**
  String get sessionCouldNotCreate;

  /// No description provided for @sessionUserMessageMissing.
  ///
  /// In en, this message translates to:
  /// **'Could not find the corresponding user message'**
  String get sessionUserMessageMissing;

  /// No description provided for @sessionRestoreMessageMissing.
  ///
  /// In en, this message translates to:
  /// **'Could not find the user message to restore'**
  String get sessionRestoreMessageMissing;

  /// No description provided for @sessionBranchMessageMissing.
  ///
  /// In en, this message translates to:
  /// **'Could not find the message to branch from'**
  String get sessionBranchMessageMissing;

  /// No description provided for @sessionHistoryPositionMissing.
  ///
  /// In en, this message translates to:
  /// **'This message has no history position. Refresh the session and try again.'**
  String get sessionHistoryPositionMissing;

  /// No description provided for @sessionRuntimeIdMissing.
  ///
  /// In en, this message translates to:
  /// **'Hermes did not return a runtime session ID'**
  String get sessionRuntimeIdMissing;

  /// No description provided for @aboutLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get aboutLicenses;

  /// No description provided for @aboutLicensesDescription.
  ///
  /// In en, this message translates to:
  /// **'View licenses for third-party software used by the app'**
  String get aboutLicensesDescription;

  /// No description provided for @aboutProductDescription.
  ///
  /// In en, this message translates to:
  /// **'The mobile client for Hermes Agent'**
  String get aboutProductDescription;

  /// No description provided for @aboutProductInfo.
  ///
  /// In en, this message translates to:
  /// **'Product information'**
  String get aboutProductInfo;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Hermes'**
  String get aboutTitle;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Hermes Mobile'**
  String get appTitle;

  /// No description provided for @appearanceHaptics.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get appearanceHaptics;

  /// No description provided for @appearanceHapticsDesc.
  ///
  /// In en, this message translates to:
  /// **'Vibrate on send, errors, and completed tasks'**
  String get appearanceHapticsDesc;

  /// No description provided for @appearanceHighContrast.
  ///
  /// In en, this message translates to:
  /// **'High contrast'**
  String get appearanceHighContrast;

  /// No description provided for @appearanceHighContrastDesc.
  ///
  /// In en, this message translates to:
  /// **'Increase text and border contrast'**
  String get appearanceHighContrastDesc;

  /// No description provided for @appearanceKeepAwake.
  ///
  /// In en, this message translates to:
  /// **'Keep screen awake'**
  String get appearanceKeepAwake;

  /// No description provided for @appearanceKeepAwakeDesc.
  ///
  /// In en, this message translates to:
  /// **'Prevent the screen from sleeping while a chat is open'**
  String get appearanceKeepAwakeDesc;

  /// No description provided for @appearanceModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceModeDark;

  /// No description provided for @appearanceModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceModeLight;

  /// No description provided for @appearanceModeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get appearanceModeSystem;

  /// No description provided for @appearanceThemeColor.
  ///
  /// In en, this message translates to:
  /// **'Theme color'**
  String get appearanceThemeColor;

  /// No description provided for @appearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// No description provided for @approvalRequests.
  ///
  /// In en, this message translates to:
  /// **'Approval requests'**
  String get approvalRequests;

  /// No description provided for @backendConnected.
  ///
  /// In en, this message translates to:
  /// **'Backend connected'**
  String get backendConnected;

  /// No description provided for @backendDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Backend disconnected'**
  String get backendDisconnected;

  /// No description provided for @billingAccountBalance.
  ///
  /// In en, this message translates to:
  /// **'Account balance'**
  String get billingAccountBalance;

  /// No description provided for @billingAccountTab.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get billingAccountTab;

  /// No description provided for @billingAmountUsd.
  ///
  /// In en, this message translates to:
  /// **'Amount (USD)'**
  String get billingAmountUsd;

  /// No description provided for @billingAutoReload.
  ///
  /// In en, this message translates to:
  /// **'Auto reload'**
  String get billingAutoReload;

  /// No description provided for @billingAutoReloadDescription.
  ///
  /// In en, this message translates to:
  /// **'Add credits when the balance falls below the threshold'**
  String get billingAutoReloadDescription;

  /// No description provided for @billingAutoReloadDisabled.
  ///
  /// In en, this message translates to:
  /// **'Auto reload disabled'**
  String get billingAutoReloadDisabled;

  /// No description provided for @billingAutoReloadEnabled.
  ///
  /// In en, this message translates to:
  /// **'Auto reload enabled'**
  String get billingAutoReloadEnabled;

  /// No description provided for @billingAutoReloadUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update auto reload'**
  String get billingAutoReloadUpdateFailed;

  /// No description provided for @billingAvailableCredits.
  ///
  /// In en, this message translates to:
  /// **'Available credits'**
  String get billingAvailableCredits;

  /// No description provided for @billingCancelAtPeriodEnd.
  ///
  /// In en, this message translates to:
  /// **'Cancel subscription at period end'**
  String get billingCancelAtPeriodEnd;

  /// No description provided for @billingCancelAtPeriodEndDescription.
  ///
  /// In en, this message translates to:
  /// **'Current plan benefits remain available until the end of this period.'**
  String get billingCancelAtPeriodEndDescription;

  /// No description provided for @billingCancelAtPeriodEndQuestion.
  ///
  /// In en, this message translates to:
  /// **'Cancel at the end of the period?'**
  String get billingCancelAtPeriodEndQuestion;

  /// No description provided for @billingCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel subscription'**
  String get billingCancelFailed;

  /// No description provided for @billingChargeCompleted.
  ///
  /// In en, this message translates to:
  /// **'Credit purchase completed'**
  String get billingChargeCompleted;

  /// No description provided for @billingChargeForbidden.
  ///
  /// In en, this message translates to:
  /// **'This account cannot purchase credits from the app'**
  String get billingChargeForbidden;

  /// No description provided for @billingChargeIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Credit purchase incomplete'**
  String get billingChargeIncomplete;

  /// No description provided for @billingConfirmCancellation.
  ///
  /// In en, this message translates to:
  /// **'Confirm cancellation'**
  String get billingConfirmCancellation;

  /// No description provided for @billingConfirmPurchase.
  ///
  /// In en, this message translates to:
  /// **'Confirm purchase'**
  String get billingConfirmPurchase;

  /// No description provided for @billingConfirmUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Confirm the plan upgrade.'**
  String get billingConfirmUpgrade;

  /// No description provided for @billingCreditsPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{credits} credits/month'**
  String billingCreditsPerMonth(Object credits);

  /// No description provided for @billingCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get billingCurrent;

  /// No description provided for @billingDowngrade.
  ///
  /// In en, this message translates to:
  /// **'Downgrade'**
  String get billingDowngrade;

  /// No description provided for @billingDowngradePeriodEnd.
  ///
  /// In en, this message translates to:
  /// **'The downgrade takes effect at the end of the current period.'**
  String get billingDowngradePeriodEnd;

  /// No description provided for @billingGatewayMissing.
  ///
  /// In en, this message translates to:
  /// **'Not connected to the Hermes gateway'**
  String get billingGatewayMissing;

  /// No description provided for @billingInvalidReloadValues.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid threshold and reload amount'**
  String get billingInvalidReloadValues;

  /// No description provided for @billingLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading billing status...'**
  String get billingLoading;

  /// No description provided for @billingLoadingPlans.
  ///
  /// In en, this message translates to:
  /// **'Loading plan catalog...'**
  String get billingLoadingPlans;

  /// No description provided for @billingLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get billingLoggedIn;

  /// No description provided for @billingLoggedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get billingLoggedOut;

  /// No description provided for @billingManageInPortal.
  ///
  /// In en, this message translates to:
  /// **'Manage in Portal'**
  String get billingManageInPortal;

  /// No description provided for @billingMaximumCharge.
  ///
  /// In en, this message translates to:
  /// **'Maximum \${amount}'**
  String billingMaximumCharge(Object amount);

  /// No description provided for @billingMinimumCharge.
  ///
  /// In en, this message translates to:
  /// **'Minimum \${amount}'**
  String billingMinimumCharge(Object amount);

  /// No description provided for @billingMonthlySpendingCap.
  ///
  /// In en, this message translates to:
  /// **'Monthly remote spending cap'**
  String get billingMonthlySpendingCap;

  /// No description provided for @billingNoActivePlan.
  ///
  /// In en, this message translates to:
  /// **'No active plan'**
  String get billingNoActivePlan;

  /// No description provided for @billingNoPlans.
  ///
  /// In en, this message translates to:
  /// **'No plan catalog available'**
  String get billingNoPlans;

  /// No description provided for @billingNoUsageData.
  ///
  /// In en, this message translates to:
  /// **'No usage data available'**
  String get billingNoUsageData;

  /// No description provided for @billingNoUsageDescription.
  ///
  /// In en, this message translates to:
  /// **'The gateway has not returned a Remote Spending usage model.'**
  String get billingNoUsageDescription;

  /// No description provided for @billingNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected to Hermes'**
  String get billingNotConnected;

  /// No description provided for @billingNotProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get billingNotProvided;

  /// No description provided for @billingNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get billingNotSet;

  /// No description provided for @billingOpenPortal.
  ///
  /// In en, this message translates to:
  /// **'Open Portal'**
  String get billingOpenPortal;

  /// No description provided for @billingOpenVerification.
  ///
  /// In en, this message translates to:
  /// **'Open verification page'**
  String get billingOpenVerification;

  /// No description provided for @billingPaymentIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Payment incomplete'**
  String get billingPaymentIncomplete;

  /// No description provided for @billingPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get billingPaymentMethod;

  /// No description provided for @billingPaymentTimeout.
  ///
  /// In en, this message translates to:
  /// **'Payment status timed out. Check the result in Portal.'**
  String get billingPaymentTimeout;

  /// No description provided for @billingPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get billingPending;

  /// No description provided for @billingPendingCancellation.
  ///
  /// In en, this message translates to:
  /// **'Cancels on {date}'**
  String billingPendingCancellation(Object date);

  /// No description provided for @billingPendingDowngrade.
  ///
  /// In en, this message translates to:
  /// **'Downgrades to {name} on {date}'**
  String billingPendingDowngrade(Object date, Object name);

  /// No description provided for @billingPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{price}/month'**
  String billingPerMonth(Object price);

  /// No description provided for @billingPeriodEnd.
  ///
  /// In en, this message translates to:
  /// **'the end of the period'**
  String get billingPeriodEnd;

  /// No description provided for @billingPlanAlreadyActive.
  ///
  /// In en, this message translates to:
  /// **'This plan is already active.'**
  String get billingPlanAlreadyActive;

  /// No description provided for @billingPlanChangeEffectiveAt.
  ///
  /// In en, this message translates to:
  /// **'The plan change takes effect on {date}.'**
  String billingPlanChangeEffectiveAt(Object date);

  /// No description provided for @billingPlanChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change plan'**
  String get billingPlanChangeFailed;

  /// No description provided for @billingPlanChangeForbidden.
  ///
  /// In en, this message translates to:
  /// **'This account cannot change plans'**
  String get billingPlanChangeForbidden;

  /// No description provided for @billingPlanChangePeriodEnd.
  ///
  /// In en, this message translates to:
  /// **'The plan change takes effect at the end of the current period.'**
  String get billingPlanChangePeriodEnd;

  /// No description provided for @billingPlanChangeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This change is currently unavailable.'**
  String get billingPlanChangeUnavailable;

  /// No description provided for @billingPlanCredits.
  ///
  /// In en, this message translates to:
  /// **'Plan credits'**
  String get billingPlanCredits;

  /// No description provided for @billingPlansTab.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get billingPlansTab;

  /// No description provided for @billingPortalMissing.
  ///
  /// In en, this message translates to:
  /// **'The server did not provide a billing Portal URL'**
  String get billingPortalMissing;

  /// No description provided for @billingPortalOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the billing Portal'**
  String get billingPortalOpenFailed;

  /// No description provided for @billingPurchaseCredits.
  ///
  /// In en, this message translates to:
  /// **'Purchase credits'**
  String get billingPurchaseCredits;

  /// No description provided for @billingReloadAboveMaximum.
  ///
  /// In en, this message translates to:
  /// **'The reload amount exceeds the server maximum'**
  String get billingReloadAboveMaximum;

  /// No description provided for @billingReloadBelowMinimum.
  ///
  /// In en, this message translates to:
  /// **'The reload amount is below the server minimum'**
  String get billingReloadBelowMinimum;

  /// No description provided for @billingReloadTo.
  ///
  /// In en, this message translates to:
  /// **'Reload to'**
  String get billingReloadTo;

  /// No description provided for @billingRemaining.
  ///
  /// In en, this message translates to:
  /// **'{amount} remaining'**
  String billingRemaining(Object amount);

  /// No description provided for @billingRenews.
  ///
  /// In en, this message translates to:
  /// **'Renews {date}'**
  String billingRenews(Object date);

  /// No description provided for @billingResumeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not undo the pending change'**
  String get billingResumeFailed;

  /// No description provided for @billingSaveAutoReload.
  ///
  /// In en, this message translates to:
  /// **'Save auto reload'**
  String get billingSaveAutoReload;

  /// No description provided for @billingSpentThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Spent this month: {amount}'**
  String billingSpentThisMonth(Object amount);

  /// No description provided for @billingSwitchPlan.
  ///
  /// In en, this message translates to:
  /// **'Switch to {name}?'**
  String billingSwitchPlan(Object name);

  /// No description provided for @billingTitle.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get billingTitle;

  /// No description provided for @billingTopupCredits.
  ///
  /// In en, this message translates to:
  /// **'Purchased credits'**
  String get billingTopupCredits;

  /// No description provided for @billingTriggerThreshold.
  ///
  /// In en, this message translates to:
  /// **'Trigger threshold'**
  String get billingTriggerThreshold;

  /// No description provided for @billingUnavailableForAccount.
  ///
  /// In en, this message translates to:
  /// **'Unavailable for this account'**
  String get billingUnavailableForAccount;

  /// No description provided for @billingUpgradeAmount.
  ///
  /// In en, this message translates to:
  /// **'The upgrade takes effect immediately. Amount due now: \${amount}.'**
  String billingUpgradeAmount(Object amount);

  /// No description provided for @billingUpgradeChargeNow.
  ///
  /// In en, this message translates to:
  /// **'The upgrade takes effect immediately and incurs a charge.'**
  String get billingUpgradeChargeNow;

  /// No description provided for @billingUsageTab.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get billingUsageTab;

  /// No description provided for @billingUsedOf.
  ///
  /// In en, this message translates to:
  /// **'Used {spent} of {total}'**
  String billingUsedOf(Object spent, Object total);

  /// No description provided for @billingVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed: {error}'**
  String billingVerificationFailed(Object error);

  /// No description provided for @billingVerificationIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Verification is not complete. Try again shortly.'**
  String get billingVerificationIncomplete;

  /// No description provided for @billingVerificationInstructions.
  ///
  /// In en, this message translates to:
  /// **'Complete verification in your browser to allow remote spending actions from this device.'**
  String get billingVerificationInstructions;

  /// No description provided for @billingVerificationRequired.
  ///
  /// In en, this message translates to:
  /// **'Additional verification required'**
  String get billingVerificationRequired;

  /// No description provided for @billingVerificationStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting verification...'**
  String get billingVerificationStarting;

  /// No description provided for @billingVerificationSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Verification succeeded. You can continue.'**
  String get billingVerificationSucceeded;

  /// No description provided for @billingVerifyAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Verify and continue'**
  String get billingVerifyAndContinue;

  /// No description provided for @billingViewSubscriptionInPortal.
  ///
  /// In en, this message translates to:
  /// **'View your subscription in Portal.'**
  String get billingViewSubscriptionInPortal;

  /// No description provided for @chatAbsoluteServerPath.
  ///
  /// In en, this message translates to:
  /// **'Use an absolute path on the server'**
  String get chatAbsoluteServerPath;

  /// No description provided for @chatAddImage.
  ///
  /// In en, this message translates to:
  /// **'Add image'**
  String get chatAddImage;

  /// No description provided for @chatAddImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add image: {error}'**
  String chatAddImageFailed(String error);

  /// No description provided for @chatAddedToQueue.
  ///
  /// In en, this message translates to:
  /// **'Added to queue ({count} pending)'**
  String chatAddedToQueue(int count);

  /// No description provided for @chatAllDates.
  ///
  /// In en, this message translates to:
  /// **'All dates'**
  String get chatAllDates;

  /// No description provided for @chatAllHistoryShown.
  ///
  /// In en, this message translates to:
  /// **'All history is shown'**
  String get chatAllHistoryShown;

  /// No description provided for @chatApprovalManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get chatApprovalManual;

  /// No description provided for @chatApprovalManualDescription.
  ///
  /// In en, this message translates to:
  /// **'Confirm every step'**
  String get chatApprovalManualDescription;

  /// No description provided for @chatApprovalMode.
  ///
  /// In en, this message translates to:
  /// **'Approval mode'**
  String get chatApprovalMode;

  /// No description provided for @chatApprovalModeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not set approval mode: {error}'**
  String chatApprovalModeFailed(String error);

  /// No description provided for @chatApprovalModeSet.
  ///
  /// In en, this message translates to:
  /// **'Approval mode set to {mode}'**
  String chatApprovalModeSet(String mode);

  /// No description provided for @chatApprovalOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get chatApprovalOff;

  /// No description provided for @chatApprovalOffDescription.
  ///
  /// In en, this message translates to:
  /// **'Run without confirmation'**
  String get chatApprovalOffDescription;

  /// No description provided for @chatApprovalSmart.
  ///
  /// In en, this message translates to:
  /// **'Smart'**
  String get chatApprovalSmart;

  /// No description provided for @chatApprovalSmartDescription.
  ///
  /// In en, this message translates to:
  /// **'Ask only for risky actions'**
  String get chatApprovalSmartDescription;

  /// No description provided for @chatApprovalsUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage: /approvals manual|smart|off'**
  String get chatApprovalsUsage;

  /// No description provided for @chatArtifactVersions.
  ///
  /// In en, this message translates to:
  /// **'All versions ({count})'**
  String chatArtifactVersions(int count);

  /// No description provided for @chatAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get chatAssistant;

  /// No description provided for @chatAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get chatAttach;

  /// No description provided for @chatAttachFiles.
  ///
  /// In en, this message translates to:
  /// **'Attach files'**
  String get chatAttachFiles;

  /// No description provided for @chatAttachLink.
  ///
  /// In en, this message translates to:
  /// **'Attach link'**
  String get chatAttachLink;

  /// No description provided for @chatAttachmentUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not upload attachment: {error}'**
  String chatAttachmentUploadFailed(String error);

  /// No description provided for @chatAutoRetried.
  ///
  /// In en, this message translates to:
  /// **'Automatically retried'**
  String get chatAutoRetried;

  /// No description provided for @chatBackToNewerMessages.
  ///
  /// In en, this message translates to:
  /// **'Back to newer messages'**
  String get chatBackToNewerMessages;

  /// No description provided for @chatBackToWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Back to workspace'**
  String get chatBackToWorkspace;

  /// No description provided for @chatBackgroundAgentRunning.
  ///
  /// In en, this message translates to:
  /// **'Background agent running · this turn will continue when it finishes'**
  String get chatBackgroundAgentRunning;

  /// No description provided for @chatBackgroundAgentsRunning.
  ///
  /// In en, this message translates to:
  /// **'{count} background agents running · the turn will continue when they finish'**
  String chatBackgroundAgentsRunning(int count);

  /// No description provided for @chatBackgroundCount.
  ///
  /// In en, this message translates to:
  /// **'{count} background tasks'**
  String chatBackgroundCount(int count);

  /// No description provided for @chatBackgroundPrompt.
  ///
  /// In en, this message translates to:
  /// **'Background task prompt'**
  String get chatBackgroundPrompt;

  /// No description provided for @chatBackgroundSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not submit background task: {error}'**
  String chatBackgroundSubmitFailed(String error);

  /// No description provided for @chatBackgroundSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Background task submitted'**
  String get chatBackgroundSubmitted;

  /// No description provided for @chatBackgroundSubmittedWithId.
  ///
  /// In en, this message translates to:
  /// **'Background task submitted ({id})'**
  String chatBackgroundSubmittedWithId(String id);

  /// No description provided for @chatBackgroundTaskCompleted.
  ///
  /// In en, this message translates to:
  /// **'{label} completed'**
  String chatBackgroundTaskCompleted(String label);

  /// No description provided for @chatBackgroundTaskFailed.
  ///
  /// In en, this message translates to:
  /// **'{label} failed'**
  String chatBackgroundTaskFailed(String label);

  /// No description provided for @chatBasicToolsets.
  ///
  /// In en, this message translates to:
  /// **'Basic toolsets'**
  String get chatBasicToolsets;

  /// No description provided for @chatBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get chatBranch;

  /// No description provided for @chatBranchChanges.
  ///
  /// In en, this message translates to:
  /// **'{branch} · {changedFiles} changed files'**
  String chatBranchChanges(String branch, int changedFiles);

  /// No description provided for @chatBranchCreated.
  ///
  /// In en, this message translates to:
  /// **'Branch session created'**
  String get chatBranchCreated;

  /// No description provided for @chatBranchCreatedWithId.
  ///
  /// In en, this message translates to:
  /// **'Branch session created ({id})'**
  String chatBranchCreatedWithId(String id);

  /// No description provided for @chatBranchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create branch: {error}'**
  String chatBranchFailed(String error);

  /// No description provided for @chatBranchInNewSession.
  ///
  /// In en, this message translates to:
  /// **'Branch in new session'**
  String get chatBranchInNewSession;

  /// No description provided for @chatBranchedHere.
  ///
  /// In en, this message translates to:
  /// **'Branched from here'**
  String get chatBranchedHere;

  /// No description provided for @chatBranchedWithId.
  ///
  /// In en, this message translates to:
  /// **'Branched from here ({id})'**
  String chatBranchedWithId(String id);

  /// No description provided for @chatBranchesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load branches: {error}'**
  String chatBranchesLoadFailed(String error);

  /// No description provided for @chatBrowseArtifactsDescription.
  ///
  /// In en, this message translates to:
  /// **'Browse artifacts generated in this session'**
  String get chatBrowseArtifactsDescription;

  /// No description provided for @chatBrowseFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse file manager'**
  String get chatBrowseFiles;

  /// No description provided for @chatBrowseFilesDescription.
  ///
  /// In en, this message translates to:
  /// **'Locate and select a directory in file manager'**
  String get chatBrowseFilesDescription;

  /// No description provided for @chatCancelKeyboardHint.
  ///
  /// In en, this message translates to:
  /// **'Cancel (Esc)'**
  String get chatCancelKeyboardHint;

  /// No description provided for @chatCatalogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No servers available'**
  String get chatCatalogEmpty;

  /// No description provided for @chatChangeWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Change workspace'**
  String get chatChangeWorkspace;

  /// No description provided for @chatChangeWorkspaceDescription.
  ///
  /// In en, this message translates to:
  /// **'The AI will read and modify files in the selected server directory'**
  String get chatChangeWorkspaceDescription;

  /// No description provided for @chatClosePreview.
  ///
  /// In en, this message translates to:
  /// **'Close preview'**
  String get chatClosePreview;

  /// No description provided for @chatCollapseStatusDetails.
  ///
  /// In en, this message translates to:
  /// **'Collapse details'**
  String get chatCollapseStatusDetails;

  /// No description provided for @chatCollapseSubsessions.
  ///
  /// In en, this message translates to:
  /// **'collapse subsessions'**
  String get chatCollapseSubsessions;

  /// No description provided for @chatCommandCompletedNoOutput.
  ///
  /// In en, this message translates to:
  /// **'Command completed with no output'**
  String get chatCommandCompletedNoOutput;

  /// No description provided for @chatCommandExecutionFailed.
  ///
  /// In en, this message translates to:
  /// **'Command execution failed'**
  String get chatCommandExecutionFailed;

  /// No description provided for @chatCommandFailed.
  ///
  /// In en, this message translates to:
  /// **'Command failed: {error}'**
  String chatCommandFailed(String error);

  /// No description provided for @chatCommandMessageQueued.
  ///
  /// In en, this message translates to:
  /// **'Message queued'**
  String get chatCommandMessageQueued;

  /// No description provided for @chatCommandNoFillContent.
  ///
  /// In en, this message translates to:
  /// **'Nothing to fill in'**
  String get chatCommandNoFillContent;

  /// No description provided for @chatCommandNoSendableContent.
  ///
  /// In en, this message translates to:
  /// **'Nothing to send'**
  String get chatCommandNoSendableContent;

  /// No description provided for @chatCommandQueued.
  ///
  /// In en, this message translates to:
  /// **'Command queued'**
  String get chatCommandQueued;

  /// No description provided for @chatCommandSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Try a different search'**
  String get chatCommandSearchHint;

  /// No description provided for @chatCommandSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load commands — check your connection'**
  String get chatCommandSearchFailed;

  /// No description provided for @chatCommandStarting.
  ///
  /// In en, this message translates to:
  /// **'Command starting'**
  String get chatCommandStarting;

  /// No description provided for @chatCompositeToolsets.
  ///
  /// In en, this message translates to:
  /// **'Composite toolsets'**
  String get chatCompositeToolsets;

  /// No description provided for @chatCompressContext.
  ///
  /// In en, this message translates to:
  /// **'Compress'**
  String get chatCompressContext;

  /// No description provided for @chatCompressionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not compress context: {error}'**
  String chatCompressionFailed(String error);

  /// No description provided for @chatCompressionRequested.
  ///
  /// In en, this message translates to:
  /// **'Context compression requested'**
  String get chatCompressionRequested;

  /// No description provided for @chatConfigureProvider.
  ///
  /// In en, this message translates to:
  /// **'Configure provider'**
  String get chatConfigureProvider;

  /// No description provided for @chatConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get chatConnecting;

  /// No description provided for @chatConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get chatConnectionFailed;

  /// No description provided for @chatContentFilled.
  ///
  /// In en, this message translates to:
  /// **'Content filled in'**
  String get chatContentFilled;

  /// No description provided for @chatContextUsage.
  ///
  /// In en, this message translates to:
  /// **'Context usage'**
  String get chatContextUsage;

  /// No description provided for @chatContextUsagePercent.
  ///
  /// In en, this message translates to:
  /// **'Context usage {percent}%'**
  String chatContextUsagePercent(int percent);

  /// No description provided for @chatCopyAsMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Copy as Markdown'**
  String get chatCopyAsMarkdown;

  /// No description provided for @chatCopyDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Copy diagnostics'**
  String get chatCopyDiagnostics;

  /// No description provided for @chatCopySessionId.
  ///
  /// In en, this message translates to:
  /// **'Copy session ID'**
  String get chatCopySessionId;

  /// No description provided for @chatCopySessionLink.
  ///
  /// In en, this message translates to:
  /// **'Copy session link'**
  String get chatCopySessionLink;

  /// No description provided for @chatCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get chatCopyText;

  /// No description provided for @chatCreateScheduledTask.
  ///
  /// In en, this message translates to:
  /// **'Create scheduled task'**
  String get chatCreateScheduledTask;

  /// No description provided for @chatCronSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Detected a schedule: {phrase}'**
  String chatCronSuggestion(String phrase);

  /// No description provided for @chatCurrentSessionArtifacts.
  ///
  /// In en, this message translates to:
  /// **'Artifacts in this session'**
  String get chatCurrentSessionArtifacts;

  /// No description provided for @chatCurrentSessionToolsets.
  ///
  /// In en, this message translates to:
  /// **'current session toolsets'**
  String get chatCurrentSessionToolsets;

  /// No description provided for @chatCurrentlyActive.
  ///
  /// In en, this message translates to:
  /// **'Currently active'**
  String get chatCurrentlyActive;

  /// No description provided for @chatDeletePromptFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete prompt: {error}'**
  String chatDeletePromptFailed(String error);

  /// No description provided for @chatDeliveryUncertain.
  ///
  /// In en, this message translates to:
  /// **'Delivery uncertain'**
  String get chatDeliveryUncertain;

  /// No description provided for @chatDiagnosticsCopied.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics copied'**
  String get chatDiagnosticsCopied;

  /// No description provided for @chatDiagnosticsError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String chatDiagnosticsError(String error);

  /// No description provided for @chatDiagnosticsModel.
  ///
  /// In en, this message translates to:
  /// **'Model: {provider} / {model}'**
  String chatDiagnosticsModel(String provider, String model);

  /// No description provided for @chatDiagnosticsTime.
  ///
  /// In en, this message translates to:
  /// **'Time: {time}'**
  String chatDiagnosticsTime(String time);

  /// No description provided for @chatDiagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get chatDiagnosticsTitle;

  /// No description provided for @chatEditFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not edit: {error}'**
  String chatEditFailed(String error);

  /// No description provided for @chatEditMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Edit message...'**
  String get chatEditMessageHint;

  /// No description provided for @chatEditMessageKeyboardHint.
  ///
  /// In en, this message translates to:
  /// **'Edit message... (Enter to send, Shift+Enter for a new line)'**
  String get chatEditMessageKeyboardHint;

  /// No description provided for @chatEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Streaming replies, tool calls, approvals, and clarifications, with full desktop parity.'**
  String get chatEmptyDescription;

  /// No description provided for @chatEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation with Hermes'**
  String get chatEmptyTitle;

  /// No description provided for @chatEnterOtherDirectory.
  ///
  /// In en, this message translates to:
  /// **'Enter another directory'**
  String get chatEnterOtherDirectory;

  /// No description provided for @chatEnterWorkspacePath.
  ///
  /// In en, this message translates to:
  /// **'Enter workspace path'**
  String get chatEnterWorkspacePath;

  /// No description provided for @chatErrorAuth.
  ///
  /// In en, this message translates to:
  /// **'Authentication error'**
  String get chatErrorAuth;

  /// No description provided for @chatErrorBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing error'**
  String get chatErrorBilling;

  /// No description provided for @chatErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error'**
  String get chatErrorNetwork;

  /// No description provided for @chatErrorProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider error'**
  String get chatErrorProvider;

  /// No description provided for @chatErrorRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Rate limited'**
  String get chatErrorRateLimit;

  /// No description provided for @chatErrorReply.
  ///
  /// In en, this message translates to:
  /// **'Reply error'**
  String get chatErrorReply;

  /// No description provided for @chatExecuting.
  ///
  /// In en, this message translates to:
  /// **'Executing…'**
  String get chatExecuting;

  /// No description provided for @chatExecutionFailed.
  ///
  /// In en, this message translates to:
  /// **'Execution failed: {error}'**
  String chatExecutionFailed(String error);

  /// No description provided for @chatExpandStatusDetails.
  ///
  /// In en, this message translates to:
  /// **'Expand details'**
  String get chatExpandStatusDetails;

  /// No description provided for @chatExpandSubsessions.
  ///
  /// In en, this message translates to:
  /// **'expand subsessions'**
  String get chatExpandSubsessions;

  /// No description provided for @chatFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'{name} exceeds the {maxMb} MB limit'**
  String chatFileTooLarge(int maxMb, String name);

  /// No description provided for @chatFillRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get chatFillRetry;

  /// No description provided for @chatFindHint.
  ///
  /// In en, this message translates to:
  /// **'Find in this conversation'**
  String get chatFindHint;

  /// No description provided for @chatFindInConversation.
  ///
  /// In en, this message translates to:
  /// **'Find in conversation'**
  String get chatFindInConversation;

  /// No description provided for @chatFolderFilesAttached.
  ///
  /// In en, this message translates to:
  /// **'Attached {attached} files ({skipped} skipped)'**
  String chatFolderFilesAttached(int attached, int skipped);

  /// No description provided for @chatFolderPickerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Folder selection is not available on this platform'**
  String get chatFolderPickerUnavailable;

  /// No description provided for @chatForwardedToCommand.
  ///
  /// In en, this message translates to:
  /// **'Forwarded to {target}'**
  String chatForwardedToCommand(String target);

  /// No description provided for @chatGlobalCliToolsets.
  ///
  /// In en, this message translates to:
  /// **'global cli toolsets'**
  String get chatGlobalCliToolsets;

  /// No description provided for @chatGlobalToolsetsDescription.
  ///
  /// In en, this message translates to:
  /// **'Global CLI toolset switches; changes apply immediately'**
  String get chatGlobalToolsetsDescription;

  /// No description provided for @chatGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get chatGoals;

  /// No description provided for @chatHandingOffTo.
  ///
  /// In en, this message translates to:
  /// **'Handing off to {name}'**
  String chatHandingOffTo(String name);

  /// No description provided for @chatHandoff.
  ///
  /// In en, this message translates to:
  /// **'Handoff'**
  String get chatHandoff;

  /// No description provided for @chatHandoffCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get chatHandoffCompleted;

  /// No description provided for @chatHandoffCompletedTo.
  ///
  /// In en, this message translates to:
  /// **'Session handed off to {name}'**
  String chatHandoffCompletedTo(String name);

  /// No description provided for @chatHandoffFailed.
  ///
  /// In en, this message translates to:
  /// **'Handoff failed: {error}'**
  String chatHandoffFailed(String error);

  /// No description provided for @chatHandoffFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get chatHandoffFailedStatus;

  /// No description provided for @chatHandoffGatewayRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get chatHandoffGatewayRunning;

  /// No description provided for @chatHandoffPlatformsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load handoff platforms: {error}'**
  String chatHandoffPlatformsFailed(String error);

  /// No description provided for @chatHandoffTimeout.
  ///
  /// In en, this message translates to:
  /// **'Handoff timed out'**
  String get chatHandoffTimeout;

  /// No description provided for @chatHandoffToPlatform.
  ///
  /// In en, this message translates to:
  /// **'Hand off to platform'**
  String get chatHandoffToPlatform;

  /// No description provided for @chatHandoffWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get chatHandoffWaiting;

  /// No description provided for @chatHideStatus.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get chatHideStatus;

  /// No description provided for @chatHistoryLocator.
  ///
  /// In en, this message translates to:
  /// **'history locator'**
  String get chatHistoryLocator;

  /// No description provided for @chatHomeChannel.
  ///
  /// In en, this message translates to:
  /// **'Home channel: {name}'**
  String chatHomeChannel(String name);

  /// No description provided for @chatHomeChannelNotSet.
  ///
  /// In en, this message translates to:
  /// **'Home channel not set'**
  String get chatHomeChannelNotSet;

  /// No description provided for @chatHtmlPreview.
  ///
  /// In en, this message translates to:
  /// **'HTML preview'**
  String get chatHtmlPreview;

  /// No description provided for @chatInflightRecovered.
  ///
  /// In en, this message translates to:
  /// **'Recovered an in-progress reply'**
  String get chatInflightRecovered;

  /// No description provided for @chatInsufficientQuota.
  ///
  /// In en, this message translates to:
  /// **'Insufficient quota'**
  String get chatInsufficientQuota;

  /// No description provided for @chatInvalidCommandAlias.
  ///
  /// In en, this message translates to:
  /// **'Invalid command alias'**
  String get chatInvalidCommandAlias;

  /// No description provided for @chatJumpToTopic.
  ///
  /// In en, this message translates to:
  /// **'Jump to topic'**
  String get chatJumpToTopic;

  /// No description provided for @chatLast24Hours.
  ///
  /// In en, this message translates to:
  /// **'Last 24 hours'**
  String get chatLast24Hours;

  /// No description provided for @chatLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get chatLast7Days;

  /// No description provided for @chatLastTurnRetried.
  ///
  /// In en, this message translates to:
  /// **'Last turn retried'**
  String get chatLastTurnRetried;

  /// No description provided for @chatLastTurnUndone.
  ///
  /// In en, this message translates to:
  /// **'Last turn undone'**
  String get chatLastTurnUndone;

  /// No description provided for @chatLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed'**
  String get chatLoadFailed;

  /// No description provided for @chatLoadOlderMessagesHint.
  ///
  /// In en, this message translates to:
  /// **'Scroll up to load older messages'**
  String get chatLoadOlderMessagesHint;

  /// No description provided for @chatLoadingCommands.
  ///
  /// In en, this message translates to:
  /// **'Loading commands…'**
  String get chatLoadingCommands;

  /// No description provided for @chatLocalCommands.
  ///
  /// In en, this message translates to:
  /// **'Local commands'**
  String get chatLocalCommands;

  /// No description provided for @chatLocateTopic.
  ///
  /// In en, this message translates to:
  /// **'Locate topic'**
  String get chatLocateTopic;

  /// No description provided for @chatLongPressCodingStatus.
  ///
  /// In en, this message translates to:
  /// **'Long-press the coding status to switch branch or start a worktree'**
  String get chatLongPressCodingStatus;

  /// No description provided for @chatMarkMessage.
  ///
  /// In en, this message translates to:
  /// **'Mark message'**
  String get chatMarkMessage;

  /// No description provided for @chatMarkdownCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied as Markdown'**
  String get chatMarkdownCopied;

  /// No description provided for @chatMarkedOnly.
  ///
  /// In en, this message translates to:
  /// **'Marked only'**
  String get chatMarkedOnly;

  /// No description provided for @chatMessageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} messages'**
  String chatMessageCount(int count);

  /// No description provided for @chatModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get chatModel;

  /// No description provided for @chatModelSwitchDeferred.
  ///
  /// In en, this message translates to:
  /// **'Model switch will take effect next turn'**
  String get chatModelSwitchDeferred;

  /// No description provided for @chatModelSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not switch model: {error}'**
  String chatModelSwitchFailed(String error);

  /// No description provided for @chatModelsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load models: {error}'**
  String chatModelsLoadFailed(String error);

  /// No description provided for @chatMonthDay.
  ///
  /// In en, this message translates to:
  /// **'{month}/{day}'**
  String chatMonthDay(int month, int day);

  /// No description provided for @chatMyMessages.
  ///
  /// In en, this message translates to:
  /// **'My messages'**
  String get chatMyMessages;

  /// No description provided for @chatNewSessionOpened.
  ///
  /// In en, this message translates to:
  /// **'New session opened'**
  String get chatNewSessionOpened;

  /// No description provided for @chatNewWorktreeDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a new git worktree'**
  String get chatNewWorktreeDescription;

  /// No description provided for @chatNoActiveTurnQueued.
  ///
  /// In en, this message translates to:
  /// **'No active turn — queued instead'**
  String get chatNoActiveTurnQueued;

  /// No description provided for @chatNoConfigurableToolsets.
  ///
  /// In en, this message translates to:
  /// **'The backend has no configurable toolsets'**
  String get chatNoConfigurableToolsets;

  /// No description provided for @chatNoContextData.
  ///
  /// In en, this message translates to:
  /// **'No context data'**
  String get chatNoContextData;

  /// No description provided for @chatNoHandoffPlatforms.
  ///
  /// In en, this message translates to:
  /// **'No handoff platforms'**
  String get chatNoHandoffPlatforms;

  /// No description provided for @chatNoHandoffPlatformsDescription.
  ///
  /// In en, this message translates to:
  /// **'No platforms are connected for handoff yet'**
  String get chatNoHandoffPlatformsDescription;

  /// No description provided for @chatNoMatchingCommands.
  ///
  /// In en, this message translates to:
  /// **'No matching commands'**
  String get chatNoMatchingCommands;

  /// No description provided for @chatNoMatchingMessages.
  ///
  /// In en, this message translates to:
  /// **'No matching messages'**
  String get chatNoMatchingMessages;

  /// No description provided for @chatNoProfiles.
  ///
  /// In en, this message translates to:
  /// **'The backend has no profiles to switch to'**
  String get chatNoProfiles;

  /// No description provided for @chatNoQueuedMessages.
  ///
  /// In en, this message translates to:
  /// **'No queued messages'**
  String get chatNoQueuedMessages;

  /// No description provided for @chatNoRetryMessage.
  ///
  /// In en, this message translates to:
  /// **'No message to retry'**
  String get chatNoRetryMessage;

  /// No description provided for @chatNoSavedPrompts.
  ///
  /// In en, this message translates to:
  /// **'No saved prompts yet'**
  String get chatNoSavedPrompts;

  /// No description provided for @chatNoSessions.
  ///
  /// In en, this message translates to:
  /// **'No sessions'**
  String get chatNoSessions;

  /// No description provided for @chatNoText.
  ///
  /// In en, this message translates to:
  /// **'No text content'**
  String get chatNoText;

  /// No description provided for @chatNoUploadableFolderFiles.
  ///
  /// In en, this message translates to:
  /// **'No uploadable files in this folder'**
  String get chatNoUploadableFolderFiles;

  /// No description provided for @chatNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get chatNotConfigured;

  /// No description provided for @chatNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get chatNotConnected;

  /// No description provided for @chatOlderMessagesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load older messages; tap to retry'**
  String get chatOlderMessagesLoadFailed;

  /// No description provided for @chatPendingRequests.
  ///
  /// In en, this message translates to:
  /// **'{kind} (+{count} pending)'**
  String chatPendingRequests(String kind, int count);

  /// No description provided for @chatPlanProgress.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total} completed'**
  String chatPlanProgress(int completed, int total);

  /// No description provided for @chatPreviewCount.
  ///
  /// In en, this message translates to:
  /// **'{count} previews'**
  String chatPreviewCount(int count);

  /// No description provided for @chatProfileSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not switch profile: {error}'**
  String chatProfileSwitchFailed(String error);

  /// No description provided for @chatProfileSwitched.
  ///
  /// In en, this message translates to:
  /// **'Switched to “{profile}”'**
  String chatProfileSwitched(String profile);

  /// No description provided for @chatProfilesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load profiles: {error}'**
  String chatProfilesLoadFailed(String error);

  /// No description provided for @chatPromptSaved.
  ///
  /// In en, this message translates to:
  /// **'Prompt saved'**
  String get chatPromptSaved;

  /// No description provided for @chatProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get chatProvider;

  /// No description provided for @chatQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get chatQueue;

  /// No description provided for @chatQueueFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not queue: {error}'**
  String chatQueueFailed(String error);

  /// No description provided for @chatQueuePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get chatQueuePaused;

  /// No description provided for @chatQueueSummary.
  ///
  /// In en, this message translates to:
  /// **'{label} · {count} · {expandLabel}'**
  String chatQueueSummary(String label, int count, String expandLabel);

  /// No description provided for @chatQueueUsage.
  ///
  /// In en, this message translates to:
  /// **'Enter something to queue'**
  String get chatQueueUsage;

  /// No description provided for @chatQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get chatQueued;

  /// No description provided for @chatQueuedMessageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Queued message updated'**
  String get chatQueuedMessageUpdated;

  /// No description provided for @chatQueuedMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'Queued {minutes} min ago'**
  String chatQueuedMinutesAgo(int minutes);

  /// No description provided for @chatQueuedSecondsAgo.
  ///
  /// In en, this message translates to:
  /// **'Queued {seconds} sec ago'**
  String chatQueuedSecondsAgo(int seconds);

  /// No description provided for @chatReasoningEffort.
  ///
  /// In en, this message translates to:
  /// **'reasoning effort'**
  String get chatReasoningEffort;

  /// No description provided for @chatReasoningEffortDescription.
  ///
  /// In en, this message translates to:
  /// **'Update the backend reasoning effort setting'**
  String get chatReasoningEffortDescription;

  /// No description provided for @chatReasoningEffortSet.
  ///
  /// In en, this message translates to:
  /// **'Reasoning effort set to {value}'**
  String chatReasoningEffortSet(String value);

  /// No description provided for @chatReasoningEffortSetFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not set reasoning effort: {error}'**
  String chatReasoningEffortSetFailed(String error);

  /// No description provided for @chatReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get chatReconnecting;

  /// No description provided for @chatRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get chatRegenerate;

  /// No description provided for @chatRegenerateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not regenerate: {error}'**
  String chatRegenerateFailed(String error);

  /// No description provided for @chatRegenerateTitle.
  ///
  /// In en, this message translates to:
  /// **'Regenerate title'**
  String get chatRegenerateTitle;

  /// No description provided for @chatRegenerateTitleFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not regenerate title: {error}'**
  String chatRegenerateTitleFailed(String error);

  /// No description provided for @chatRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get chatRename;

  /// No description provided for @chatRenameSession.
  ///
  /// In en, this message translates to:
  /// **'Rename session'**
  String get chatRenameSession;

  /// No description provided for @chatRequestApproval.
  ///
  /// In en, this message translates to:
  /// **'Approval'**
  String get chatRequestApproval;

  /// No description provided for @chatRequestMcpConfig.
  ///
  /// In en, this message translates to:
  /// **'MCP setup'**
  String get chatRequestMcpConfig;

  /// No description provided for @chatRequestPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get chatRequestPassword;

  /// No description provided for @chatRequestQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get chatRequestQuestion;

  /// No description provided for @chatRequestSecret.
  ///
  /// In en, this message translates to:
  /// **'Secret'**
  String get chatRequestSecret;

  /// No description provided for @chatRequestTerminalInput.
  ///
  /// In en, this message translates to:
  /// **'Terminal input'**
  String get chatRequestTerminalInput;

  /// No description provided for @chatRestoreAndRerun.
  ///
  /// In en, this message translates to:
  /// **'Restore and rerun'**
  String get chatRestoreAndRerun;

  /// No description provided for @chatRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore: {error}'**
  String chatRestoreFailed(String error);

  /// No description provided for @chatRestoreToMessage.
  ///
  /// In en, this message translates to:
  /// **'Restore to this message'**
  String get chatRestoreToMessage;

  /// No description provided for @chatRestoreToMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore to this message?'**
  String get chatRestoreToMessageTitle;

  /// No description provided for @chatRestoreVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore this version?'**
  String get chatRestoreVersionTitle;

  /// No description provided for @chatRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry failed: {error}'**
  String chatRetryFailed(String error);

  /// No description provided for @chatRunInBackground.
  ///
  /// In en, this message translates to:
  /// **'Run in background'**
  String get chatRunInBackground;

  /// No description provided for @chatSaveCurrentInput.
  ///
  /// In en, this message translates to:
  /// **'Save current input'**
  String get chatSaveCurrentInput;

  /// No description provided for @chatSavePromptFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save prompt: {error}'**
  String chatSavePromptFailed(String error);

  /// No description provided for @chatSavedPrompts.
  ///
  /// In en, this message translates to:
  /// **'Saved prompts'**
  String get chatSavedPrompts;

  /// No description provided for @chatSavedPromptsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load saved prompts: {error}'**
  String chatSavedPromptsLoadFailed(String error);

  /// No description provided for @chatScrollToBottom.
  ///
  /// In en, this message translates to:
  /// **'Scroll to bottom'**
  String get chatScrollToBottom;

  /// No description provided for @chatSearchLoadedHistory.
  ///
  /// In en, this message translates to:
  /// **'Search loaded history'**
  String get chatSearchLoadedHistory;

  /// No description provided for @chatSelectFilesFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not select files: {error}'**
  String chatSelectFilesFailed(String error);

  /// No description provided for @chatSelectFolder.
  ///
  /// In en, this message translates to:
  /// **'Select folder'**
  String get chatSelectFolder;

  /// No description provided for @chatSelectFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not select folder: {error}'**
  String chatSelectFolderFailed(String error);

  /// No description provided for @chatSelectProfile.
  ///
  /// In en, this message translates to:
  /// **'select profile'**
  String get chatSelectProfile;

  /// No description provided for @chatSelectProfileDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the profile used for home data and future launches'**
  String get chatSelectProfileDescription;

  /// No description provided for @chatSendDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Send diagnostics'**
  String get chatSendDiagnostics;

  /// No description provided for @chatSendEdit.
  ///
  /// In en, this message translates to:
  /// **'send edit'**
  String get chatSendEdit;

  /// No description provided for @chatSendEditAndRerun.
  ///
  /// In en, this message translates to:
  /// **'Send edit and rerun'**
  String get chatSendEditAndRerun;

  /// No description provided for @chatSendEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Send edited message?'**
  String get chatSendEditTitle;

  /// No description provided for @chatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send: {error}'**
  String chatSendFailed(String error);

  /// No description provided for @chatSendNow.
  ///
  /// In en, this message translates to:
  /// **'Send now'**
  String get chatSendNow;

  /// No description provided for @chatSendQueue.
  ///
  /// In en, this message translates to:
  /// **'Send queue'**
  String get chatSendQueue;

  /// No description provided for @chatSendQueueCount.
  ///
  /// In en, this message translates to:
  /// **'Send queue ({count})'**
  String chatSendQueueCount(int count);

  /// No description provided for @chatServerCatalog.
  ///
  /// In en, this message translates to:
  /// **'Server catalog'**
  String get chatServerCatalog;

  /// No description provided for @chatServerDirectory.
  ///
  /// In en, this message translates to:
  /// **'server directory'**
  String get chatServerDirectory;

  /// No description provided for @chatServerDirectoryHelp.
  ///
  /// In en, this message translates to:
  /// **'The directory must exist and be accessible to the server account'**
  String get chatServerDirectoryHelp;

  /// No description provided for @chatServerNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Server not connected'**
  String get chatServerNotConnected;

  /// No description provided for @chatSessionCleared.
  ///
  /// In en, this message translates to:
  /// **'Session cleared'**
  String get chatSessionCleared;

  /// No description provided for @chatSessionIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Session ID copied'**
  String get chatSessionIdCopied;

  /// No description provided for @chatSessionInfo.
  ///
  /// In en, this message translates to:
  /// **'Session info'**
  String get chatSessionInfo;

  /// No description provided for @chatSessionMenu.
  ///
  /// In en, this message translates to:
  /// **'Session menu'**
  String get chatSessionMenu;

  /// No description provided for @chatSessionShareLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Session share link copied'**
  String get chatSessionShareLinkCopied;

  /// No description provided for @chatSessionToolsetsDescription.
  ///
  /// In en, this message translates to:
  /// **'Session toolsets (only affect this session)'**
  String get chatSessionToolsetsDescription;

  /// No description provided for @chatSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get chatSessions;

  /// No description provided for @chatSetAsNext.
  ///
  /// In en, this message translates to:
  /// **'Queue next'**
  String get chatSetAsNext;

  /// No description provided for @chatSetTitleFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not set title: {error}'**
  String chatSetTitleFailed(String error);

  /// No description provided for @chatShareLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not get share link: {error}'**
  String chatShareLinkFailed(String error);

  /// No description provided for @chatShareUrlMissing.
  ///
  /// In en, this message translates to:
  /// **'No share link was returned'**
  String get chatShareUrlMissing;

  /// No description provided for @chatSkillsCenter.
  ///
  /// In en, this message translates to:
  /// **'Skills center'**
  String get chatSkillsCenter;

  /// No description provided for @chatSlashCommands.
  ///
  /// In en, this message translates to:
  /// **'Slash commands'**
  String get chatSlashCommands;

  /// No description provided for @chatStartSessionBeforeWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Start a session before changing workspace'**
  String get chatStartSessionBeforeWorkspace;

  /// No description provided for @chatStarterDebugIssue.
  ///
  /// In en, this message translates to:
  /// **'Help me debug'**
  String get chatStarterDebugIssue;

  /// No description provided for @chatStarterDebugIssuePrompt.
  ///
  /// In en, this message translates to:
  /// **'I ran into a problem. Help me outline a debugging approach first.'**
  String get chatStarterDebugIssuePrompt;

  /// No description provided for @chatStarterExplainProject.
  ///
  /// In en, this message translates to:
  /// **'Explain this project'**
  String get chatStarterExplainProject;

  /// No description provided for @chatStarterExplainProjectPrompt.
  ///
  /// In en, this message translates to:
  /// **'Give me a quick overview of this project\'s structure, core features, and how to run it.'**
  String get chatStarterExplainProjectPrompt;

  /// No description provided for @chatStarterReviewChanges.
  ///
  /// In en, this message translates to:
  /// **'Review current changes'**
  String get chatStarterReviewChanges;

  /// No description provided for @chatStarterReviewChangesPrompt.
  ///
  /// In en, this message translates to:
  /// **'Review the current workspace changes, identify potential issues, and suggest improvements.'**
  String get chatStarterReviewChangesPrompt;

  /// No description provided for @chatSteerCurrentTurn.
  ///
  /// In en, this message translates to:
  /// **'Steer current turn'**
  String get chatSteerCurrentTurn;

  /// No description provided for @chatSteerHint.
  ///
  /// In en, this message translates to:
  /// **'Steering message'**
  String get chatSteerHint;

  /// No description provided for @chatSteerInjected.
  ///
  /// In en, this message translates to:
  /// **'Steering message injected'**
  String get chatSteerInjected;

  /// No description provided for @chatSteerMessage.
  ///
  /// In en, this message translates to:
  /// **'Steer'**
  String get chatSteerMessage;

  /// No description provided for @chatSteerNowFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not steer now: {error}'**
  String chatSteerNowFailed(String error);

  /// No description provided for @chatSteerQueued.
  ///
  /// In en, this message translates to:
  /// **'Steering message queued'**
  String get chatSteerQueued;

  /// No description provided for @chatSteerUsage.
  ///
  /// In en, this message translates to:
  /// **'Enter something to steer with'**
  String get chatSteerUsage;

  /// No description provided for @chatStopProcess.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get chatStopProcess;

  /// No description provided for @chatStopProcessFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not stop process: {error}'**
  String chatStopProcessFailed(String error);

  /// No description provided for @chatSubagentCount.
  ///
  /// In en, this message translates to:
  /// **'{count} subagents'**
  String chatSubagentCount(int count);

  /// No description provided for @chatTextSnippet.
  ///
  /// In en, this message translates to:
  /// **'Text snippet'**
  String get chatTextSnippet;

  /// No description provided for @chatTextSnippetHint.
  ///
  /// In en, this message translates to:
  /// **'Paste or type text'**
  String get chatTextSnippetHint;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Hermes Chat'**
  String get chatTitle;

  /// No description provided for @chatTitleSet.
  ///
  /// In en, this message translates to:
  /// **'Title set to “{title}”'**
  String chatTitleSet(String title);

  /// No description provided for @chatTitleUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Title unchanged'**
  String get chatTitleUnchanged;

  /// No description provided for @chatTitleUpdated.
  ///
  /// In en, this message translates to:
  /// **'Title updated to “{title}”'**
  String chatTitleUpdated(String title);

  /// No description provided for @chatToday.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get chatToday;

  /// No description provided for @chatToolConfiguration.
  ///
  /// In en, this message translates to:
  /// **'tool configuration'**
  String get chatToolConfiguration;

  /// No description provided for @chatToolCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tools'**
  String chatToolCount(int count);

  /// No description provided for @chatToolStatusMessage.
  ///
  /// In en, this message translates to:
  /// **'Tool status message'**
  String get chatToolStatusMessage;

  /// No description provided for @chatToolsetCounts.
  ///
  /// In en, this message translates to:
  /// **'Session: {sessionCount} · Global: {globalCount}'**
  String chatToolsetCounts(String sessionCount, String globalCount);

  /// No description provided for @chatToolsetToggleFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not toggle {name}: {error}'**
  String chatToolsetToggleFailed(String name, String error);

  /// No description provided for @chatToolsetsEnabled.
  ///
  /// In en, this message translates to:
  /// **'{globalCount} toolsets enabled'**
  String chatToolsetsEnabled(String globalCount);

  /// No description provided for @chatToolsetsExplanation.
  ///
  /// In en, this message translates to:
  /// **'Current session toolsets are registered and usable by Hermes Agent in this session.\nGlobal CLI toolsets are configured globally and may not all be loaded in this session.'**
  String get chatToolsetsExplanation;

  /// No description provided for @chatToolsetsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'toolsets load failed'**
  String get chatToolsetsLoadFailed;

  /// No description provided for @chatTopicNumber.
  ///
  /// In en, this message translates to:
  /// **'Topic {index}'**
  String chatTopicNumber(int index);

  /// No description provided for @chatTopicRailSemantics.
  ///
  /// In en, this message translates to:
  /// **'{count} topics'**
  String chatTopicRailSemantics(int count);

  /// No description provided for @chatTranscriptLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load chat history'**
  String get chatTranscriptLoadFailed;

  /// No description provided for @chatTruncateWarning.
  ///
  /// In en, this message translates to:
  /// **'This will delete all subsequent messages and cannot be undone'**
  String get chatTruncateWarning;

  /// No description provided for @chatUndoFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not undo: {error}'**
  String chatUndoFailed(String error);

  /// No description provided for @chatUnknownCommandResult.
  ///
  /// In en, this message translates to:
  /// **'Unknown command result'**
  String get chatUnknownCommandResult;

  /// No description provided for @chatUnknownTime.
  ///
  /// In en, this message translates to:
  /// **'Unknown time'**
  String get chatUnknownTime;

  /// No description provided for @chatUnmarkMessage.
  ///
  /// In en, this message translates to:
  /// **'Unmark message'**
  String get chatUnmarkMessage;

  /// No description provided for @chatUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled session'**
  String get chatUntitled;

  /// No description provided for @chatUntitledSession.
  ///
  /// In en, this message translates to:
  /// **'Untitled session'**
  String get chatUntitledSession;

  /// No description provided for @chatVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get chatVersion;

  /// No description provided for @chatVersionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} versions'**
  String chatVersionCount(int count);

  /// No description provided for @chatVersionLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load versions: {error}'**
  String chatVersionLoadFailed(String error);

  /// No description provided for @chatVersionNumber.
  ///
  /// In en, this message translates to:
  /// **'Version {index}'**
  String chatVersionNumber(int index);

  /// No description provided for @chatViewBilling.
  ///
  /// In en, this message translates to:
  /// **'View billing'**
  String get chatViewBilling;

  /// No description provided for @chatViewCleared.
  ///
  /// In en, this message translates to:
  /// **'View cleared'**
  String get chatViewCleared;

  /// No description provided for @chatWakeServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Wake word service unavailable'**
  String get chatWakeServiceUnavailable;

  /// No description provided for @chatWakeVoiceFailed.
  ///
  /// In en, this message translates to:
  /// **'Wake word failed: {error}'**
  String chatWakeVoiceFailed(String error);

  /// No description provided for @chatWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: {warning}'**
  String chatWarning(String warning);

  /// No description provided for @chatWorkingDirectory.
  ///
  /// In en, this message translates to:
  /// **'Working directory'**
  String get chatWorkingDirectory;

  /// No description provided for @chatWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get chatWorkspace;

  /// No description provided for @chatWorkspaceFiles.
  ///
  /// In en, this message translates to:
  /// **'workspace files'**
  String get chatWorkspaceFiles;

  /// No description provided for @chatWorkspaceSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change workspace: {error}'**
  String chatWorkspaceSwitchFailed(String error);

  /// No description provided for @chatWorkspaceSwitched.
  ///
  /// In en, this message translates to:
  /// **'Workspace changed to {name}'**
  String chatWorkspaceSwitched(String name);

  /// No description provided for @chatYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get chatYesterday;

  /// No description provided for @chatYoloDisabled.
  ///
  /// In en, this message translates to:
  /// **'YOLO mode disabled'**
  String get chatYoloDisabled;

  /// No description provided for @chatYoloEnabled.
  ///
  /// In en, this message translates to:
  /// **'YOLO mode enabled'**
  String get chatYoloEnabled;

  /// No description provided for @chatYoloMode.
  ///
  /// In en, this message translates to:
  /// **'YOLO mode'**
  String get chatYoloMode;

  /// No description provided for @chatYoloToggleFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not toggle YOLO mode: {error}'**
  String chatYoloToggleFailed(String error);

  /// No description provided for @appSessionCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Session completed'**
  String get appSessionCompletedTitle;

  /// No description provided for @appSessionCompletedBody.
  ///
  /// In en, this message translates to:
  /// **'A background session completed. Tap to view the result.'**
  String get appSessionCompletedBody;

  /// No description provided for @appOpenNotificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the notification session: {error}'**
  String appOpenNotificationFailed(Object error);

  /// No description provided for @deepLinkPluginInstallTitle.
  ///
  /// In en, this message translates to:
  /// **'Install Hermes plugin'**
  String get deepLinkPluginInstallTitle;

  /// No description provided for @deepLinkPluginInstallPrompt.
  ///
  /// In en, this message translates to:
  /// **'This link requests installation of a backend plugin from:'**
  String get deepLinkPluginInstallPrompt;

  /// No description provided for @deepLinkLegacyPluginWarning.
  ///
  /// In en, this message translates to:
  /// **'This is a legacy Desktop plugin link. Mobile installs only its backend Agent capabilities.'**
  String get deepLinkLegacyPluginWarning;

  /// No description provided for @deepLinkEnableAfterInstall.
  ///
  /// In en, this message translates to:
  /// **'Enable after installation'**
  String get deepLinkEnableAfterInstall;

  /// No description provided for @deepLinkForceReinstall.
  ///
  /// In en, this message translates to:
  /// **'Force reinstall'**
  String get deepLinkForceReinstall;

  /// No description provided for @deepLinkInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get deepLinkInstall;

  /// No description provided for @deepLinkPluginInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing {identifier}...'**
  String deepLinkPluginInstalling(Object identifier);

  /// No description provided for @deepLinkPluginInstalled.
  ///
  /// In en, this message translates to:
  /// **'Plugin installed'**
  String get deepLinkPluginInstalled;

  /// No description provided for @deepLinkPluginInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Plugin installation failed: {error}'**
  String deepLinkPluginInstallFailed(Object error);

  /// No description provided for @deepLinkMcpAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add MCP server'**
  String get deepLinkMcpAddTitle;

  /// No description provided for @deepLinkMcpServerName.
  ///
  /// In en, this message translates to:
  /// **'Server name'**
  String get deepLinkMcpServerName;

  /// No description provided for @deepLinkMcpNameFormatError.
  ///
  /// In en, this message translates to:
  /// **'Use 1-64 letters, numbers, periods, underscores, or hyphens'**
  String get deepLinkMcpNameFormatError;

  /// No description provided for @deepLinkMcpNameConflict.
  ///
  /// In en, this message translates to:
  /// **'That name already exists. Choose another name.'**
  String get deepLinkMcpNameConflict;

  /// No description provided for @deepLinkMcpCommandWarning.
  ///
  /// In en, this message translates to:
  /// **'This configuration runs a local command on the Hermes backend. Continue only if you trust the source.'**
  String get deepLinkMcpCommandWarning;

  /// No description provided for @deepLinkConfigPreview.
  ///
  /// In en, this message translates to:
  /// **'Configuration preview'**
  String get deepLinkConfigPreview;

  /// No description provided for @deepLinkMcpAdded.
  ///
  /// In en, this message translates to:
  /// **'MCP server {name} added'**
  String deepLinkMcpAdded(Object name);

  /// No description provided for @deepLinkMcpAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add MCP server: {error}'**
  String deepLinkMcpAddFailed(Object error);

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonAuthorize.
  ///
  /// In en, this message translates to:
  /// **'Authorize'**
  String get commonAuthorize;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonCancelAll.
  ///
  /// In en, this message translates to:
  /// **'Cancel all'**
  String get commonCancelAll;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get commonCollapse;

  /// No description provided for @commonCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get commonCompleted;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get commonConnected;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get commonCopied;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get commonDefault;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get commonDisconnect;

  /// No description provided for @commonDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get commonDisconnected;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonErrorTitle;

  /// No description provided for @commonAuthenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Check the API key.'**
  String get commonAuthenticationFailed;

  /// No description provided for @commonExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get commonExpand;

  /// No description provided for @commonFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get commonFile;

  /// No description provided for @commonFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get commonFolder;

  /// No description provided for @commonGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get commonGotIt;

  /// No description provided for @commonHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get commonHide;

  /// No description provided for @commonIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get commonIdle;

  /// No description provided for @commonIgnore.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get commonIgnore;

  /// No description provided for @commonLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get commonLater;

  /// No description provided for @commonListSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get commonListSeparator;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get commonManage;

  /// No description provided for @commonMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get commonMore;

  /// No description provided for @commonName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// No description provided for @commonNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get commonNew;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get commonNoMatches;

  /// No description provided for @commonNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get commonNotifications;

  /// No description provided for @commonOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get commonOffline;

  /// No description provided for @commonOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get commonOnline;

  /// No description provided for @commonOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'The operation failed. Try again.'**
  String get commonOperationFailed;

  /// No description provided for @commonNetworkFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to reach the server. Check the network and server status.'**
  String get commonNetworkFailed;

  /// No description provided for @commonOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get commonOpen;

  /// No description provided for @commonPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get commonPrevious;

  /// No description provided for @commonProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get commonProcessing;

  /// No description provided for @commonReauthorize.
  ///
  /// In en, this message translates to:
  /// **'Reauthorize'**
  String get commonReauthorize;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get commonReload;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @commonRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get commonRestart;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonRun.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get commonRun;

  /// No description provided for @commonRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get commonRunning;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get commonSelect;

  /// No description provided for @commonSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commonSend;

  /// No description provided for @commonStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get commonStop;

  /// No description provided for @commonSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get commonSubmit;

  /// No description provided for @commonSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get commonSwitch;

  /// No description provided for @commonTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get commonTitle;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @commonUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get commonUnknownError;

  /// No description provided for @commonViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get commonViewAll;

  /// No description provided for @configAppliesToProfile.
  ///
  /// In en, this message translates to:
  /// **'Applies to profile'**
  String get configAppliesToProfile;

  /// No description provided for @configConnectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get configConnectionLabel;

  /// No description provided for @configCurrentProfile.
  ///
  /// In en, this message translates to:
  /// **'the current profile'**
  String get configCurrentProfile;

  /// No description provided for @configDefaultProcessProfile.
  ///
  /// In en, this message translates to:
  /// **'Default / process profile'**
  String get configDefaultProcessProfile;

  /// No description provided for @configDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove override: {error}'**
  String configDeleteFailed(String error);

  /// No description provided for @configFullJson.
  ///
  /// In en, this message translates to:
  /// **'Full JSON'**
  String get configFullJson;

  /// No description provided for @configInvalidFieldValue.
  ///
  /// In en, this message translates to:
  /// **'Invalid value for {path}: {error}'**
  String configInvalidFieldValue(String path, String error);

  /// No description provided for @configInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'Invalid JSON: {error}'**
  String configInvalidJson(String error);

  /// No description provided for @configListJsonError.
  ///
  /// In en, this message translates to:
  /// **'Value must be a JSON array'**
  String get configListJsonError;

  /// No description provided for @configLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading configuration and schema...'**
  String get configLoading;

  /// No description provided for @configNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching fields'**
  String get configNoMatches;

  /// No description provided for @configObjectJsonError.
  ///
  /// In en, this message translates to:
  /// **'Value must be a JSON object'**
  String get configObjectJsonError;

  /// No description provided for @configRemoveOverride.
  ///
  /// In en, this message translates to:
  /// **'Remove override and use the default value'**
  String get configRemoveOverride;

  /// No description provided for @configRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get configRestore;

  /// No description provided for @configRestoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get configRestoreDefaults;

  /// No description provided for @configRestoreDefaultsDescription.
  ///
  /// In en, this message translates to:
  /// **'This applies to {profile}. Existing custom values will be replaced by defaults.'**
  String configRestoreDefaultsDescription(String profile);

  /// No description provided for @configRestoreDefaultsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Restore the default Hermes configuration?'**
  String get configRestoreDefaultsQuestion;

  /// No description provided for @configSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String configSaveFailed(String error);

  /// No description provided for @providerEndpointValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'Endpoint validation failed'**
  String get providerEndpointValidationFailed;

  /// No description provided for @kanbanMoveSelected.
  ///
  /// In en, this message translates to:
  /// **'Move selected tasks'**
  String get kanbanMoveSelected;

  /// No description provided for @kanbanClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear task selection'**
  String get kanbanClearSelection;

  /// No description provided for @configSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search configuration fields...'**
  String get configSearchHint;

  /// No description provided for @configServerDidNotDelete.
  ///
  /// In en, this message translates to:
  /// **'The server did not remove {path}'**
  String configServerDidNotDelete(String path);

  /// No description provided for @configServerMismatch.
  ///
  /// In en, this message translates to:
  /// **'The server returned content that differs from the submitted full configuration'**
  String get configServerMismatch;

  /// No description provided for @configServerRejected.
  ///
  /// In en, this message translates to:
  /// **'The server did not accept {path}; the server value has been restored.'**
  String configServerRejected(String path);

  /// No description provided for @configTitle.
  ///
  /// In en, this message translates to:
  /// **'Models & chat'**
  String get configTitle;

  /// No description provided for @configTopLevelObject.
  ///
  /// In en, this message translates to:
  /// **'The top-level JSON value must be an object'**
  String get configTopLevelObject;

  /// No description provided for @configUseDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get configUseDefault;

  /// No description provided for @connectAction.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectAction;

  /// No description provided for @connectAddHeader.
  ///
  /// In en, this message translates to:
  /// **'Add request header'**
  String get connectAddHeader;

  /// No description provided for @connectAllowPublicHttp.
  ///
  /// In en, this message translates to:
  /// **'Allow public cleartext HTTP'**
  String get connectAllowPublicHttp;

  /// No description provided for @connectAllowPublicHttpWarning.
  ///
  /// In en, this message translates to:
  /// **'Use only on a trusted network where HTTPS is unavailable; tokens may be intercepted'**
  String get connectAllowPublicHttpWarning;

  /// No description provided for @connectApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get connectApiKey;

  /// No description provided for @connectConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Connection configuration'**
  String get connectConfiguration;

  /// No description provided for @connectConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connectConnecting;

  /// No description provided for @connectCredentialRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an access credential'**
  String get connectCredentialRequired;

  /// No description provided for @connectDeleteHeader.
  ///
  /// In en, this message translates to:
  /// **'Delete request header'**
  String get connectDeleteHeader;

  /// No description provided for @connectDeleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Delete configuration'**
  String get connectDeleteProfile;

  /// No description provided for @connectDiscoverCloud.
  ///
  /// In en, this message translates to:
  /// **'Discover an agent from Hermes Cloud'**
  String get connectDiscoverCloud;

  /// No description provided for @connectExtraHeaders.
  ///
  /// In en, this message translates to:
  /// **'Additional request headers'**
  String get connectExtraHeaders;

  /// No description provided for @connectHeaderManaged.
  ///
  /// In en, this message translates to:
  /// **'Managed by Hermes'**
  String get connectHeaderManaged;

  /// No description provided for @connectHeaderName.
  ///
  /// In en, this message translates to:
  /// **'Header name'**
  String get connectHeaderName;

  /// No description provided for @connectHeaderNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid name'**
  String get connectHeaderNameInvalid;

  /// No description provided for @connectHeaderValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get connectHeaderValue;

  /// No description provided for @connectHeaderValueRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a value'**
  String get connectHeaderValueRequired;

  /// No description provided for @connectHeadersDescription.
  ///
  /// In en, this message translates to:
  /// **'Optional access-proxy headers. Values are stored in secure system storage.'**
  String get connectHeadersDescription;

  /// No description provided for @connectHideKey.
  ///
  /// In en, this message translates to:
  /// **'Hide key'**
  String get connectHideKey;

  /// No description provided for @connectHidePassphrase.
  ///
  /// In en, this message translates to:
  /// **'Hide passphrase'**
  String get connectHidePassphrase;

  /// No description provided for @connectHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get connectHidePassword;

  /// No description provided for @connectHidePrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Hide private key'**
  String get connectHidePrivateKey;

  /// No description provided for @connectHideValue.
  ///
  /// In en, this message translates to:
  /// **'Hide value'**
  String get connectHideValue;

  /// No description provided for @connectHttpsRequired.
  ///
  /// In en, this message translates to:
  /// **'Public connections require HTTPS unless insecure transport is explicitly allowed'**
  String get connectHttpsRequired;

  /// No description provided for @connectNativeCleartextRestricted.
  ///
  /// In en, this message translates to:
  /// **'Release builds allow cleartext only for localhost or .local companion names. Use HTTPS or a .local hostname.'**
  String get connectNativeCleartextRestricted;

  /// No description provided for @connectNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get connectNotSignedIn;

  /// No description provided for @connectOauthSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in with OAuth'**
  String get connectOauthSignedIn;

  /// No description provided for @connectPkceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This gateway does not support native_pkce sign-in. Update Hermes or use a token.'**
  String get connectPkceUnavailable;

  /// No description provided for @connectPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get connectPort;

  /// No description provided for @connectPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'OpenSSH / PEM private key'**
  String get connectPrivateKey;

  /// No description provided for @connectPrivateKeyPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Private key passphrase (optional)'**
  String get connectPrivateKeyPassphrase;

  /// No description provided for @connectProfileName.
  ///
  /// In en, this message translates to:
  /// **'Configuration name (defaults to host name)'**
  String get connectProfileName;

  /// No description provided for @connectProfileNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid profile name'**
  String get connectProfileNameInvalid;

  /// No description provided for @connectRemoteHermesPath.
  ///
  /// In en, this message translates to:
  /// **'Remote Hermes path (auto-detect)'**
  String get connectRemoteHermesPath;

  /// No description provided for @connectRemoteProfile.
  ///
  /// In en, this message translates to:
  /// **'Remote profile (optional)'**
  String get connectRemoteProfile;

  /// No description provided for @connectSaveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save as a server configuration'**
  String get connectSaveProfile;

  /// No description provided for @connectSaveProfileDescription.
  ///
  /// In en, this message translates to:
  /// **'Switch to it from the saved list next time'**
  String get connectSaveProfileDescription;

  /// No description provided for @connectSavedBackends.
  ///
  /// In en, this message translates to:
  /// **'Saved backends'**
  String get connectSavedBackends;

  /// No description provided for @connectServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get connectServerAddress;

  /// No description provided for @connectServerInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTP(S) address'**
  String get connectServerInvalid;

  /// No description provided for @connectServerRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a server address'**
  String get connectServerRequired;

  /// No description provided for @connectShowKey.
  ///
  /// In en, this message translates to:
  /// **'Show key'**
  String get connectShowKey;

  /// No description provided for @connectShowPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Show passphrase'**
  String get connectShowPassphrase;

  /// No description provided for @connectShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get connectShowPassword;

  /// No description provided for @connectShowPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Show private key'**
  String get connectShowPrivateKey;

  /// No description provided for @connectShowValue.
  ///
  /// In en, this message translates to:
  /// **'Show value'**
  String get connectShowValue;

  /// No description provided for @connectSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get connectSignIn;

  /// No description provided for @connectSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get connectSignInAgain;

  /// No description provided for @connectSshCredentialRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a private key or password'**
  String get connectSshCredentialRequired;

  /// No description provided for @connectSshHost.
  ///
  /// In en, this message translates to:
  /// **'SSH host'**
  String get connectSshHost;

  /// No description provided for @connectSshHostRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an SSH host'**
  String get connectSshHostRequired;

  /// No description provided for @connectSshPassword.
  ///
  /// In en, this message translates to:
  /// **'SSH password (optional)'**
  String get connectSshPassword;

  /// No description provided for @connectSshUser.
  ///
  /// In en, this message translates to:
  /// **'SSH user'**
  String get connectSshUser;

  /// No description provided for @connectSshUserRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an SSH user'**
  String get connectSshUserRequired;

  /// No description provided for @connectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connectTitle;

  /// No description provided for @connectUnableServer.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the server'**
  String get connectUnableServer;

  /// No description provided for @connectValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection validation failed. Check the server address and API key.'**
  String get connectValidationFailed;

  /// No description provided for @connectValidationNetworkFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection validation failed. Check the server address, API key, and network.'**
  String get connectValidationNetworkFailed;

  /// No description provided for @dateMonthDay.
  ///
  /// In en, this message translates to:
  /// **'{month}/{day}'**
  String dateMonthDay(int month, int day);

  /// No description provided for @dateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dateToday;

  /// No description provided for @dateYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dateYesterday;

  /// No description provided for @discordCommunityTitle.
  ///
  /// In en, this message translates to:
  /// **'Join the Discord community'**
  String get discordCommunityTitle;

  /// No description provided for @featureAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get featureAbout;

  /// No description provided for @featureAboutDesc.
  ///
  /// In en, this message translates to:
  /// **'Version information'**
  String get featureAboutDesc;

  /// No description provided for @featureAgent.
  ///
  /// In en, this message translates to:
  /// **'Bots'**
  String get featureAgent;

  /// No description provided for @featureAgentDesc.
  ///
  /// In en, this message translates to:
  /// **'Bots, group chats and runtime status'**
  String get featureAgentDesc;

  /// No description provided for @featureArtifacts.
  ///
  /// In en, this message translates to:
  /// **'Artifacts'**
  String get featureArtifacts;

  /// No description provided for @featureArtifactsDesc.
  ///
  /// In en, this message translates to:
  /// **'Session outputs'**
  String get featureArtifactsDesc;

  /// No description provided for @featureBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get featureBilling;

  /// No description provided for @featureBillingDesc.
  ///
  /// In en, this message translates to:
  /// **'Usage, plans and invoices'**
  String get featureBillingDesc;

  /// No description provided for @featureCommandCenter.
  ///
  /// In en, this message translates to:
  /// **'Command center'**
  String get featureCommandCenter;

  /// No description provided for @featureCommandCenterDesc.
  ///
  /// In en, this message translates to:
  /// **'Live status and logs'**
  String get featureCommandCenterDesc;

  /// No description provided for @featureConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get featureConnection;

  /// No description provided for @featureConnectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Multiple backend profiles'**
  String get featureConnectionDesc;

  /// No description provided for @featureCredentials.
  ///
  /// In en, this message translates to:
  /// **'Credentials'**
  String get featureCredentials;

  /// No description provided for @featureCredentialsDesc.
  ///
  /// In en, this message translates to:
  /// **'Third-party accounts and keys'**
  String get featureCredentialsDesc;

  /// No description provided for @featureCron.
  ///
  /// In en, this message translates to:
  /// **'Scheduled tasks'**
  String get featureCron;

  /// No description provided for @featureCronDesc.
  ///
  /// In en, this message translates to:
  /// **'Cron automation'**
  String get featureCronDesc;

  /// No description provided for @featureFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get featureFiles;

  /// No description provided for @featureFilesDesc.
  ///
  /// In en, this message translates to:
  /// **'Browse the working directory'**
  String get featureFilesDesc;

  /// No description provided for @featureGit.
  ///
  /// In en, this message translates to:
  /// **'Git'**
  String get featureGit;

  /// No description provided for @featureGitDesc.
  ///
  /// In en, this message translates to:
  /// **'Changes, commits and branches'**
  String get featureGitDesc;

  /// No description provided for @featureGlobalSearchDesc.
  ///
  /// In en, this message translates to:
  /// **'Search commands, sessions and pages'**
  String get featureGlobalSearchDesc;

  /// No description provided for @featureInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get featureInsights;

  /// No description provided for @featureInsightsDesc.
  ///
  /// In en, this message translates to:
  /// **'Usage and cost trends'**
  String get featureInsightsDesc;

  /// No description provided for @featureMcp.
  ///
  /// In en, this message translates to:
  /// **'MCP'**
  String get featureMcp;

  /// No description provided for @featureMcpDesc.
  ///
  /// In en, this message translates to:
  /// **'MCP server configuration'**
  String get featureMcpDesc;

  /// No description provided for @featureMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get featureMemory;

  /// No description provided for @featureMemoryDesc.
  ///
  /// In en, this message translates to:
  /// **'Long-term memory management'**
  String get featureMemoryDesc;

  /// No description provided for @featureMessaging.
  ///
  /// In en, this message translates to:
  /// **'Messaging'**
  String get featureMessaging;

  /// No description provided for @featureMessagingDesc.
  ///
  /// In en, this message translates to:
  /// **'Telegram, Discord and more'**
  String get featureMessagingDesc;

  /// No description provided for @featureNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Notification center'**
  String get featureNotificationsDesc;

  /// No description provided for @featurePet.
  ///
  /// In en, this message translates to:
  /// **'Pet'**
  String get featurePet;

  /// No description provided for @featurePetDesc.
  ///
  /// In en, this message translates to:
  /// **'Companion and collection'**
  String get featurePetDesc;

  /// No description provided for @featurePlugins.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get featurePlugins;

  /// No description provided for @featurePluginsDesc.
  ///
  /// In en, this message translates to:
  /// **'Plugin management'**
  String get featurePluginsDesc;

  /// No description provided for @featureProfiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get featureProfiles;

  /// No description provided for @featureProfilesDesc.
  ///
  /// In en, this message translates to:
  /// **'Model execution profiles'**
  String get featureProfilesDesc;

  /// No description provided for @featureProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get featureProjects;

  /// No description provided for @featureProjectsDesc.
  ///
  /// In en, this message translates to:
  /// **'Group sessions across projects'**
  String get featureProjectsDesc;

  /// No description provided for @featureSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get featureSettings;

  /// No description provided for @featureSettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Appearance and preferences'**
  String get featureSettingsDesc;

  /// No description provided for @featureSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get featureSkills;

  /// No description provided for @featureSkillsDesc.
  ///
  /// In en, this message translates to:
  /// **'Skill hub'**
  String get featureSkillsDesc;

  /// No description provided for @featureStarmap.
  ///
  /// In en, this message translates to:
  /// **'Knowledge starmap'**
  String get featureStarmap;

  /// No description provided for @featureStarmapDesc.
  ///
  /// In en, this message translates to:
  /// **'Keyword knowledge graph'**
  String get featureStarmapDesc;

  /// No description provided for @featureSubagents.
  ///
  /// In en, this message translates to:
  /// **'Subagents'**
  String get featureSubagents;

  /// No description provided for @featureSubagentsDesc.
  ///
  /// In en, this message translates to:
  /// **'Background agent activity'**
  String get featureSubagentsDesc;

  /// No description provided for @featureTerminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get featureTerminal;

  /// No description provided for @featureTerminalDesc.
  ///
  /// In en, this message translates to:
  /// **'Interactive command line'**
  String get featureTerminalDesc;

  /// No description provided for @featureTools.
  ///
  /// In en, this message translates to:
  /// **'Toolsets'**
  String get featureTools;

  /// No description provided for @featureToolsDesc.
  ///
  /// In en, this message translates to:
  /// **'Tools and keys'**
  String get featureToolsDesc;

  /// No description provided for @featureWebhooks.
  ///
  /// In en, this message translates to:
  /// **'Webhooks'**
  String get featureWebhooks;

  /// No description provided for @featureWebhooksDesc.
  ///
  /// In en, this message translates to:
  /// **'Event delivery'**
  String get featureWebhooksDesc;

  /// No description provided for @gitAgentShipFailed.
  ///
  /// In en, this message translates to:
  /// **'Agent Ship failed: {error}'**
  String gitAgentShipFailed(Object error);

  /// No description provided for @gitAgentShipPrompt.
  ///
  /// In en, this message translates to:
  /// **'Review the current changes, commit them with a clear conventional commit message, push the branch, and open a pull request.'**
  String get gitAgentShipPrompt;

  /// No description provided for @gitAgentShipQuestion.
  ///
  /// In en, this message translates to:
  /// **'Have the Agent commit and push changes, then create a PR?'**
  String get gitAgentShipQuestion;

  /// No description provided for @gitAgentShipSent.
  ///
  /// In en, this message translates to:
  /// **'Sent the commit-and-create-PR task to Hermes'**
  String get gitAgentShipSent;

  /// No description provided for @gitAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get gitAuthor;

  /// No description provided for @gitAuthorMeta.
  ///
  /// In en, this message translates to:
  /// **'Author: {author}'**
  String gitAuthorMeta(Object author);

  /// No description provided for @gitBaseBranch.
  ///
  /// In en, this message translates to:
  /// **'Base branch'**
  String get gitBaseBranch;

  /// No description provided for @gitBranchMeta.
  ///
  /// In en, this message translates to:
  /// **'Branch: {branch}'**
  String gitBranchMeta(Object branch);

  /// No description provided for @gitBranchesTab.
  ///
  /// In en, this message translates to:
  /// **'Branches'**
  String get gitBranchesTab;

  /// No description provided for @gitChangeDirectory.
  ///
  /// In en, this message translates to:
  /// **'Change directory'**
  String get gitChangeDirectory;

  /// No description provided for @gitChangedFiles.
  ///
  /// In en, this message translates to:
  /// **'Changed files'**
  String get gitChangedFiles;

  /// No description provided for @gitChangedFilesLabel.
  ///
  /// In en, this message translates to:
  /// **'Changed files:'**
  String get gitChangedFilesLabel;

  /// No description provided for @gitChangesTab.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get gitChangesTab;

  /// No description provided for @gitCommit.
  ///
  /// In en, this message translates to:
  /// **'Commit'**
  String get gitCommit;

  /// No description provided for @gitCommitChanges.
  ///
  /// In en, this message translates to:
  /// **'Commit changes'**
  String get gitCommitChanges;

  /// No description provided for @gitCommitDetails.
  ///
  /// In en, this message translates to:
  /// **'Commit details'**
  String get gitCommitDetails;

  /// No description provided for @gitCommitFailed.
  ///
  /// In en, this message translates to:
  /// **'Commit failed: {error}'**
  String gitCommitFailed(Object error);

  /// No description provided for @gitCommitMessage.
  ///
  /// In en, this message translates to:
  /// **'Commit message'**
  String get gitCommitMessage;

  /// No description provided for @gitCommitsTab.
  ///
  /// In en, this message translates to:
  /// **'Commits'**
  String get gitCommitsTab;

  /// No description provided for @gitCreatePr.
  ///
  /// In en, this message translates to:
  /// **'Create PR'**
  String get gitCreatePr;

  /// No description provided for @gitCreatePrFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create PR: {error}'**
  String gitCreatePrFailed(Object error);

  /// No description provided for @gitCreatePrQuestion.
  ///
  /// In en, this message translates to:
  /// **'Create or open a pull request for the current branch with GitHub CLI?'**
  String get gitCreatePrQuestion;

  /// No description provided for @gitCreateWorktreeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create worktree: {error}'**
  String gitCreateWorktreeFailed(Object error);

  /// No description provided for @gitCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get gitCurrent;

  /// No description provided for @gitDeleteWorktreeDescription.
  ///
  /// In en, this message translates to:
  /// **'This deletes the working directory {path} and its uncommitted changes. It cannot be recovered.'**
  String gitDeleteWorktreeDescription(Object path);

  /// No description provided for @gitDeleteWorktreeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete worktree: {error}'**
  String gitDeleteWorktreeFailed(Object error);

  /// No description provided for @gitDeleteWorktreeQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete worktree?'**
  String get gitDeleteWorktreeQuestion;

  /// No description provided for @gitDetachedHead.
  ///
  /// In en, this message translates to:
  /// **'(detached HEAD)'**
  String get gitDetachedHead;

  /// No description provided for @gitDiffLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load diff: {error}'**
  String gitDiffLoadFailed(Object error);

  /// No description provided for @gitEndOfLog.
  ///
  /// In en, this message translates to:
  /// **'— End of log —'**
  String get gitEndOfLog;

  /// No description provided for @gitForceDelete.
  ///
  /// In en, this message translates to:
  /// **'Force delete'**
  String get gitForceDelete;

  /// No description provided for @gitForceDeleteWorktreeQuestion.
  ///
  /// In en, this message translates to:
  /// **'Force delete and discard these changes?'**
  String get gitForceDeleteWorktreeQuestion;

  /// No description provided for @gitGenerateCommitMessage.
  ///
  /// In en, this message translates to:
  /// **'Generate commit message'**
  String get gitGenerateCommitMessage;

  /// No description provided for @gitGenerateMessageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not generate commit message: {error}'**
  String gitGenerateMessageFailed(Object error);

  /// No description provided for @gitGithubCliUnavailable.
  ///
  /// In en, this message translates to:
  /// **'GitHub CLI is not installed or signed in on the backend'**
  String get gitGithubCliUnavailable;

  /// No description provided for @gitHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} hr ago'**
  String gitHoursAgo(Object count);

  /// No description provided for @gitJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get gitJustNow;

  /// No description provided for @gitLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more ({loaded}/{total})'**
  String gitLoadMore(Object loaded, Object total);

  /// No description provided for @gitLoadingBranches.
  ///
  /// In en, this message translates to:
  /// **'Loading branches...'**
  String get gitLoadingBranches;

  /// No description provided for @gitLoadingLog.
  ///
  /// In en, this message translates to:
  /// **'Loading commit log...'**
  String get gitLoadingLog;

  /// No description provided for @gitLoadingStatus.
  ///
  /// In en, this message translates to:
  /// **'Loading repository status...'**
  String get gitLoadingStatus;

  /// No description provided for @gitLocalBranches.
  ///
  /// In en, this message translates to:
  /// **'Local branches'**
  String get gitLocalBranches;

  /// No description provided for @gitLogLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load commit log: {error}'**
  String gitLogLoadFailed(Object error);

  /// No description provided for @gitMainWorktree.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get gitMainWorktree;

  /// No description provided for @gitMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String gitMinutesAgo(Object count);

  /// No description provided for @gitNewWorktree.
  ///
  /// In en, this message translates to:
  /// **'New worktree'**
  String get gitNewWorktree;

  /// No description provided for @gitNoAdditionalWorktrees.
  ///
  /// In en, this message translates to:
  /// **'No additional worktrees'**
  String get gitNoAdditionalWorktrees;

  /// No description provided for @gitNoBranches.
  ///
  /// In en, this message translates to:
  /// **'No branches available'**
  String get gitNoBranches;

  /// No description provided for @gitNoBranchesDescription.
  ///
  /// In en, this message translates to:
  /// **'Select a Git repository and try again.'**
  String get gitNoBranchesDescription;

  /// No description provided for @gitNoCommits.
  ///
  /// In en, this message translates to:
  /// **'No commits'**
  String get gitNoCommits;

  /// No description provided for @gitNoCommitsDescription.
  ///
  /// In en, this message translates to:
  /// **'This repository has no commits, or no commits match the current filters'**
  String get gitNoCommitsDescription;

  /// No description provided for @gitNoDiff.
  ///
  /// In en, this message translates to:
  /// **'No diff'**
  String get gitNoDiff;

  /// No description provided for @gitNoDiffDescription.
  ///
  /// In en, this message translates to:
  /// **'This file does not differ from HEAD'**
  String get gitNoDiffDescription;

  /// No description provided for @gitNoMatchingBranches.
  ///
  /// In en, this message translates to:
  /// **'No matching branches'**
  String get gitNoMatchingBranches;

  /// No description provided for @gitNoStashes.
  ///
  /// In en, this message translates to:
  /// **'No stashes'**
  String get gitNoStashes;

  /// No description provided for @gitNoVisibleRemotes.
  ///
  /// In en, this message translates to:
  /// **'No visible remotes'**
  String get gitNoVisibleRemotes;

  /// No description provided for @gitNotRepository.
  ///
  /// In en, this message translates to:
  /// **'Not a Git repository'**
  String get gitNotRepository;

  /// No description provided for @gitNotRepositoryDescription.
  ///
  /// In en, this message translates to:
  /// **'{path}\n\nUse the button below to change directory'**
  String gitNotRepositoryDescription(Object path);

  /// No description provided for @gitOpenInNewSession.
  ///
  /// In en, this message translates to:
  /// **'Open in new session'**
  String get gitOpenInNewSession;

  /// No description provided for @gitOpenPr.
  ///
  /// In en, this message translates to:
  /// **'Open PR #{number}'**
  String gitOpenPr(Object number);

  /// No description provided for @gitOpenedInNewSession.
  ///
  /// In en, this message translates to:
  /// **'Opened {path} in a new session'**
  String gitOpenedInNewSession(Object path);

  /// No description provided for @gitParent.
  ///
  /// In en, this message translates to:
  /// **'parent'**
  String get gitParent;

  /// No description provided for @gitPrCreated.
  ///
  /// In en, this message translates to:
  /// **'PR created'**
  String get gitPrCreated;

  /// No description provided for @gitPrNumber.
  ///
  /// In en, this message translates to:
  /// **'Number: #{number}'**
  String gitPrNumber(Object number);

  /// No description provided for @gitPushAfterCommit.
  ///
  /// In en, this message translates to:
  /// **'Push after commit'**
  String get gitPushAfterCommit;

  /// No description provided for @gitPushAction.
  ///
  /// In en, this message translates to:
  /// **'Push {count} commit(s)'**
  String gitPushAction(Object count);

  /// No description provided for @gitPushSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Pushed to remote'**
  String get gitPushSucceeded;

  /// No description provided for @gitPushFailed.
  ///
  /// In en, this message translates to:
  /// **'Push failed: {error}'**
  String gitPushFailed(Object error);

  /// No description provided for @gitRecentRepositories.
  ///
  /// In en, this message translates to:
  /// **'Recent repositories'**
  String get gitRecentRepositories;

  /// No description provided for @gitRemotes.
  ///
  /// In en, this message translates to:
  /// **'Remotes'**
  String get gitRemotes;

  /// No description provided for @gitRemotesAndStashes.
  ///
  /// In en, this message translates to:
  /// **'Remotes and stashes'**
  String get gitRemotesAndStashes;

  /// No description provided for @gitRepositoryDirectory.
  ///
  /// In en, this message translates to:
  /// **'Repository directory'**
  String get gitRepositoryDirectory;

  /// No description provided for @gitRevert.
  ///
  /// In en, this message translates to:
  /// **'Revert'**
  String get gitRevert;

  /// No description provided for @gitRevertAll.
  ///
  /// In en, this message translates to:
  /// **'Revert all'**
  String get gitRevertAll;

  /// No description provided for @gitRevertAllDescription.
  ///
  /// In en, this message translates to:
  /// **'This discards all uncommitted working-tree changes and cannot be undone.'**
  String get gitRevertAllDescription;

  /// No description provided for @gitRevertAllQuestion.
  ///
  /// In en, this message translates to:
  /// **'Revert all changes?'**
  String get gitRevertAllQuestion;

  /// No description provided for @gitRevertFailed.
  ///
  /// In en, this message translates to:
  /// **'Revert failed: {error}'**
  String gitRevertFailed(Object error);

  /// No description provided for @gitRevertFile.
  ///
  /// In en, this message translates to:
  /// **'Revert this file'**
  String get gitRevertFile;

  /// No description provided for @gitRevertFileDescription.
  ///
  /// In en, this message translates to:
  /// **'This discards uncommitted changes to “{file}” and cannot be undone.'**
  String gitRevertFileDescription(Object file);

  /// No description provided for @gitRevertFileQuestion.
  ///
  /// In en, this message translates to:
  /// **'Revert this file?'**
  String get gitRevertFileQuestion;

  /// No description provided for @gitSearchBranches.
  ///
  /// In en, this message translates to:
  /// **'Search branches...'**
  String get gitSearchBranches;

  /// No description provided for @gitSearchCommits.
  ///
  /// In en, this message translates to:
  /// **'Search commit messages'**
  String get gitSearchCommits;

  /// No description provided for @gitSelectFileForDiff.
  ///
  /// In en, this message translates to:
  /// **'Select a file to view its diff'**
  String get gitSelectFileForDiff;

  /// No description provided for @gitSelectFileForDiffDescription.
  ///
  /// In en, this message translates to:
  /// **'Select a changed file on the left to view its diff here'**
  String get gitSelectFileForDiffDescription;

  /// No description provided for @gitServerRepositoryPath.
  ///
  /// In en, this message translates to:
  /// **'Repository path on server'**
  String get gitServerRepositoryPath;

  /// No description provided for @gitStage.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get gitStage;

  /// No description provided for @gitStageFailed.
  ///
  /// In en, this message translates to:
  /// **'Staging operation failed: {error}'**
  String gitStageFailed(Object error);

  /// No description provided for @gitStagedChanges.
  ///
  /// In en, this message translates to:
  /// **'Staged · +{added} −{removed}'**
  String gitStagedChanges(Object added, Object removed);

  /// No description provided for @gitStashes.
  ///
  /// In en, this message translates to:
  /// **'Stashes'**
  String get gitStashes;

  /// No description provided for @gitSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get gitSwitch;

  /// No description provided for @gitSwitchBranch.
  ///
  /// In en, this message translates to:
  /// **'Switch branch'**
  String get gitSwitchBranch;

  /// No description provided for @gitSwitchBranchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not switch branch: {error}'**
  String gitSwitchBranchFailed(Object error);

  /// No description provided for @gitUnknownAuthor.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get gitUnknownAuthor;

  /// No description provided for @gitUnstage.
  ///
  /// In en, this message translates to:
  /// **'Unstage'**
  String get gitUnstage;

  /// No description provided for @gitWorkingTreeClean.
  ///
  /// In en, this message translates to:
  /// **'Working tree clean; no changes'**
  String get gitWorkingTreeClean;

  /// No description provided for @gitWorktreeHasChanges.
  ///
  /// In en, this message translates to:
  /// **'The worktree has uncommitted changes'**
  String get gitWorktreeHasChanges;

  /// No description provided for @gitWorktreeNameHint.
  ///
  /// In en, this message translates to:
  /// **'For example, feature-login'**
  String get gitWorktreeNameHint;

  /// No description provided for @gitWorktrees.
  ///
  /// In en, this message translates to:
  /// **'Worktrees'**
  String get gitWorktrees;

  /// No description provided for @globalSearch.
  ///
  /// In en, this message translates to:
  /// **'Global search'**
  String get globalSearch;

  /// No description provided for @groupConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get groupConfiguration;

  /// No description provided for @groupIntegrations.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get groupIntegrations;

  /// No description provided for @groupIntelligence.
  ///
  /// In en, this message translates to:
  /// **'Intelligence'**
  String get groupIntelligence;

  /// No description provided for @groupSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get groupSystem;

  /// No description provided for @groupWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get groupWorkspace;

  /// No description provided for @helpAndFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Help and feedback'**
  String get helpAndFeedbackTitle;

  /// No description provided for @homeAllFeatures.
  ///
  /// In en, this message translates to:
  /// **'All features'**
  String get homeAllFeatures;

  /// No description provided for @homeAttentionDetail.
  ///
  /// In en, this message translates to:
  /// **'The agent may be waiting for your confirmation'**
  String get homeAttentionDetail;

  /// No description provided for @homeBackendSummary.
  ///
  /// In en, this message translates to:
  /// **'Backend connected · {model} · Profile: {profile}'**
  String homeBackendSummary(String model, String profile);

  /// No description provided for @homeContinueSession.
  ///
  /// In en, this message translates to:
  /// **'Continue “{title}”'**
  String homeContinueSession(String title);

  /// No description provided for @homeContinueWork.
  ///
  /// In en, this message translates to:
  /// **'Continue your work'**
  String get homeContinueWork;

  /// No description provided for @homeCurrentWork.
  ///
  /// In en, this message translates to:
  /// **'Current work'**
  String get homeCurrentWork;

  /// No description provided for @homeDefaultProfile.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get homeDefaultProfile;

  /// No description provided for @homeDragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get homeDragToReorder;

  /// No description provided for @homeEditQuickTools.
  ///
  /// In en, this message translates to:
  /// **'Edit quick tools'**
  String get homeEditQuickTools;

  /// No description provided for @homeLastVisibleTool.
  ///
  /// In en, this message translates to:
  /// **'Last tool shown on Home'**
  String get homeLastVisibleTool;

  /// No description provided for @homeLoadingRecent.
  ///
  /// In en, this message translates to:
  /// **'Loading recent work…'**
  String get homeLoadingRecent;

  /// No description provided for @homeMoreTools.
  ///
  /// In en, this message translates to:
  /// **'More tools'**
  String get homeMoreTools;

  /// No description provided for @homeNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item needs attention} other{{count} items need attention}}'**
  String homeNeedsAttention(int count);

  /// No description provided for @homeNoWorkDescription.
  ///
  /// In en, this message translates to:
  /// **'Describe a goal above to start your first task'**
  String get homeNoWorkDescription;

  /// No description provided for @homeNoWorkTitle.
  ///
  /// In en, this message translates to:
  /// **'No work history yet'**
  String get homeNoWorkTitle;

  /// No description provided for @homeProfileTooltip.
  ///
  /// In en, this message translates to:
  /// **'Profile: {profile}'**
  String homeProfileTooltip(String profile);

  /// No description provided for @homeQuickTools.
  ///
  /// In en, this message translates to:
  /// **'Quick tools'**
  String get homeQuickTools;

  /// No description provided for @homeQuickToolsDescription.
  ///
  /// In en, this message translates to:
  /// **'The first 5 tools appear on Home. The rest are available under More.'**
  String get homeQuickToolsDescription;

  /// No description provided for @homeReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Hermes is ready'**
  String get homeReadyTitle;

  /// No description provided for @homeRecentSessions.
  ///
  /// In en, this message translates to:
  /// **'Recent sessions'**
  String get homeRecentSessions;

  /// No description provided for @homeRestoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get homeRestoreDefaults;

  /// No description provided for @homeStartNewSession.
  ///
  /// In en, this message translates to:
  /// **'Start new session'**
  String get homeStartNewSession;

  /// No description provided for @homeSwitchProfile.
  ///
  /// In en, this message translates to:
  /// **'Switch profile'**
  String get homeSwitchProfile;

  /// No description provided for @homeToolKnowledge.
  ///
  /// In en, this message translates to:
  /// **'Knowledge'**
  String get homeToolKnowledge;

  /// No description provided for @homeViewAttentionSessions.
  ///
  /// In en, this message translates to:
  /// **'View pending sessions'**
  String get homeViewAttentionSessions;

  /// No description provided for @homeViewSession.
  ///
  /// In en, this message translates to:
  /// **'View session'**
  String get homeViewSession;

  /// No description provided for @homeWorkingDetail.
  ///
  /// In en, this message translates to:
  /// **'Processing the current task · {model}'**
  String homeWorkingDetail(String model);

  /// No description provided for @homeWorkingTitle.
  ///
  /// In en, this message translates to:
  /// **'Hermes is working'**
  String get homeWorkingTitle;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// No description provided for @languageDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the language used by Hermes Mobile'**
  String get languageDescription;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageJapanese;

  /// No description provided for @languageSimplifiedChinese.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get languageSimplifiedChinese;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageTraditionalChinese.
  ///
  /// In en, this message translates to:
  /// **'Traditional Chinese'**
  String get languageTraditionalChinese;

  /// No description provided for @legalPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get legalPrivacy;

  /// No description provided for @legalTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get legalTerms;

  /// No description provided for @legalTitle.
  ///
  /// In en, this message translates to:
  /// **'Legal and licenses'**
  String get legalTitle;

  /// No description provided for @modelAllFollowMain.
  ///
  /// In en, this message translates to:
  /// **'Make all follow main model'**
  String get modelAllFollowMain;

  /// No description provided for @modelApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get modelApply;

  /// No description provided for @modelAuxiliarySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save auxiliary model: {error}'**
  String modelAuxiliarySaveFailed(String error);

  /// No description provided for @modelAuxiliaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Auxiliary models'**
  String get modelAuxiliaryTitle;

  /// No description provided for @modelAuxiliaryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This Hermes backend does not provide auxiliary model configuration.'**
  String get modelAuxiliaryUnavailable;

  /// No description provided for @modelChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose model'**
  String get modelChoose;

  /// No description provided for @modelConfirmSelection.
  ///
  /// In en, this message translates to:
  /// **'Confirm model selection'**
  String get modelConfirmSelection;

  /// No description provided for @modelCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get modelCreate;

  /// No description provided for @modelCurrent.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get modelCurrent;

  /// No description provided for @modelDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Default model'**
  String get modelDefaultTitle;

  /// No description provided for @modelExpensiveWarning.
  ///
  /// In en, this message translates to:
  /// **'This model may incur higher costs. Continue?'**
  String get modelExpensiveWarning;

  /// No description provided for @modelFallbackHint.
  ///
  /// In en, this message translates to:
  /// **'fallback_providers (one provider:model per line)'**
  String get modelFallbackHint;

  /// No description provided for @modelFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Fallback models'**
  String get modelFallbackTitle;

  /// No description provided for @modelFollowMain.
  ///
  /// In en, this message translates to:
  /// **'Follow main model'**
  String get modelFollowMain;

  /// No description provided for @modelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get modelLabel;

  /// No description provided for @modelMoaAddReference.
  ///
  /// In en, this message translates to:
  /// **'Add reference model'**
  String get modelMoaAddReference;

  /// No description provided for @modelMoaAggregator.
  ///
  /// In en, this message translates to:
  /// **'Aggregator'**
  String get modelMoaAggregator;

  /// No description provided for @modelMoaAggregatorMaxTokens.
  ///
  /// In en, this message translates to:
  /// **'Aggregator output limit'**
  String get modelMoaAggregatorMaxTokens;

  /// No description provided for @modelMoaAggregatorModel.
  ///
  /// In en, this message translates to:
  /// **'Aggregator model'**
  String get modelMoaAggregatorModel;

  /// No description provided for @modelMoaAggregatorSummary.
  ///
  /// In en, this message translates to:
  /// **'Aggregator: {provider} · {model}'**
  String modelMoaAggregatorSummary(String provider, String model);

  /// No description provided for @modelMoaAggregatorTemperature.
  ///
  /// In en, this message translates to:
  /// **'Aggregator temperature'**
  String get modelMoaAggregatorTemperature;

  /// No description provided for @modelMoaCompleteModels.
  ///
  /// In en, this message translates to:
  /// **'Complete all model selections'**
  String get modelMoaCompleteModels;

  /// No description provided for @modelMoaCreatePreset.
  ///
  /// In en, this message translates to:
  /// **'Create MoA preset'**
  String get modelMoaCreatePreset;

  /// No description provided for @modelMoaCreateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create preset'**
  String get modelMoaCreateTooltip;

  /// No description provided for @modelMoaDefaultPreset.
  ///
  /// In en, this message translates to:
  /// **'Default preset'**
  String get modelMoaDefaultPreset;

  /// No description provided for @modelMoaDegradedLoud.
  ///
  /// In en, this message translates to:
  /// **'Report degradation'**
  String get modelMoaDegradedLoud;

  /// No description provided for @modelMoaDegradedPolicy.
  ///
  /// In en, this message translates to:
  /// **'Degraded policy'**
  String get modelMoaDegradedPolicy;

  /// No description provided for @modelMoaDegradedSilent.
  ///
  /// In en, this message translates to:
  /// **'Silent degradation'**
  String get modelMoaDegradedSilent;

  /// No description provided for @modelMoaDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete preset'**
  String get modelMoaDeleteTooltip;

  /// No description provided for @modelMoaDescription.
  ///
  /// In en, this message translates to:
  /// **'Reference models answer in parallel and the aggregator produces the final result'**
  String get modelMoaDescription;

  /// No description provided for @modelMoaEditConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Edit configuration'**
  String get modelMoaEditConfiguration;

  /// No description provided for @modelMoaEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String modelMoaEditTitle(String name);

  /// No description provided for @modelMoaEnablePreset.
  ///
  /// In en, this message translates to:
  /// **'Enable preset'**
  String get modelMoaEnablePreset;

  /// No description provided for @modelMoaFanoutCadence.
  ///
  /// In en, this message translates to:
  /// **'Fanout cadence'**
  String get modelMoaFanoutCadence;

  /// No description provided for @modelMoaFanoutHint.
  ///
  /// In en, this message translates to:
  /// **'user_turn / per_iteration / every_n:2'**
  String get modelMoaFanoutHint;

  /// No description provided for @modelMoaNoEditable.
  ///
  /// In en, this message translates to:
  /// **'There are no editable MoA presets.'**
  String get modelMoaNoEditable;

  /// No description provided for @modelMoaPresetLabel.
  ///
  /// In en, this message translates to:
  /// **'Preset'**
  String get modelMoaPresetLabel;

  /// No description provided for @modelMoaReferenceCount.
  ///
  /// In en, this message translates to:
  /// **'{count} reference models'**
  String modelMoaReferenceCount(int count);

  /// No description provided for @modelMoaReferenceMaxTokens.
  ///
  /// In en, this message translates to:
  /// **'Reference output limit'**
  String get modelMoaReferenceMaxTokens;

  /// No description provided for @modelMoaReferenceModels.
  ///
  /// In en, this message translates to:
  /// **'Reference models'**
  String get modelMoaReferenceModels;

  /// No description provided for @modelMoaReferenceNumber.
  ///
  /// In en, this message translates to:
  /// **'Reference {index}'**
  String modelMoaReferenceNumber(int index);

  /// No description provided for @modelMoaReferenceTemperature.
  ///
  /// In en, this message translates to:
  /// **'Reference temperature'**
  String get modelMoaReferenceTemperature;

  /// No description provided for @modelMoaReferenceTimeout.
  ///
  /// In en, this message translates to:
  /// **'Reference timeout (seconds)'**
  String get modelMoaReferenceTimeout;

  /// No description provided for @modelMoaRuntimeParameters.
  ///
  /// In en, this message translates to:
  /// **'Runtime parameters'**
  String get modelMoaRuntimeParameters;

  /// No description provided for @modelMoaSaveConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Save configuration'**
  String get modelMoaSaveConfiguration;

  /// No description provided for @modelMoaSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save MoA configuration: {error}'**
  String modelMoaSaveFailed(String error);

  /// No description provided for @modelMoaSetDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get modelMoaSetDefault;

  /// No description provided for @modelMoaUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This Hermes backend does not provide MoA configuration.'**
  String get modelMoaUnavailable;

  /// No description provided for @modelNoAvailable.
  ///
  /// In en, this message translates to:
  /// **'No models available'**
  String get modelNoAvailable;

  /// No description provided for @modelPresetName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get modelPresetName;

  /// No description provided for @modelProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get modelProvider;

  /// No description provided for @modelProviderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Could not find the provider for this model'**
  String get modelProviderNotFound;

  /// No description provided for @modelRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended: {model}'**
  String modelRecommended(String model);

  /// No description provided for @modelRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get modelRemove;

  /// No description provided for @modelSwitchDeferred.
  ///
  /// In en, this message translates to:
  /// **'Model switch queued and will apply after the current turn'**
  String get modelSwitchDeferred;

  /// No description provided for @modelSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not switch model: {error}'**
  String modelSwitchFailed(String error);

  /// No description provided for @modelSwitchSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Switched to {model}'**
  String modelSwitchSucceeded(String model);

  /// No description provided for @moreCloseSearch.
  ///
  /// In en, this message translates to:
  /// **'Close directory search'**
  String get moreCloseSearch;

  /// No description provided for @moreNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching features'**
  String get moreNoMatches;

  /// No description provided for @moreSearchDirectory.
  ///
  /// In en, this message translates to:
  /// **'Search directory'**
  String get moreSearchDirectory;

  /// No description provided for @moreSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search features'**
  String get moreSearchHint;

  /// No description provided for @moreStatus.
  ///
  /// In en, this message translates to:
  /// **'{connection} · Agent {agent}'**
  String moreStatus(String connection, String agent);

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @navSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get navSessions;

  /// No description provided for @navTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get navTasks;

  /// No description provided for @notificationClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get notificationClear;

  /// No description provided for @notificationClearConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all notifications?'**
  String get notificationClearConfirmTitle;

  /// No description provided for @notificationClearConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes every notification from this list. It can\'t be undone.'**
  String get notificationClearConfirmBody;

  /// No description provided for @notificationEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Agent completions, approvals, and errors appear here'**
  String get notificationEmptyDescription;

  /// No description provided for @notificationEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notificationEmptyTitle;

  /// No description provided for @notificationMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationMarkAllRead;

  /// No description provided for @notificationOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open session: {error}'**
  String notificationOpenFailed(String error);

  /// No description provided for @notificationOpenSession.
  ///
  /// In en, this message translates to:
  /// **'View session'**
  String get notificationOpenSession;

  /// No description provided for @notificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationTitle;

  /// No description provided for @paletteHint.
  ///
  /// In en, this message translates to:
  /// **'Search pages, sessions, and commands…'**
  String get paletteHint;

  /// No description provided for @paletteHintClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get paletteHintClose;

  /// No description provided for @paletteHintNavigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get paletteHintNavigate;

  /// No description provided for @paletteHintOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get paletteHintOpen;

  /// No description provided for @paletteKanban.
  ///
  /// In en, this message translates to:
  /// **'Kanban'**
  String get paletteKanban;

  /// No description provided for @paletteKindAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get paletteKindAction;

  /// No description provided for @paletteKindCommand.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get paletteKindCommand;

  /// No description provided for @paletteKindPage.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get paletteKindPage;

  /// No description provided for @paletteKindSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get paletteKindSession;

  /// No description provided for @paletteNewSessionDesc.
  ///
  /// In en, this message translates to:
  /// **'Start a new conversation'**
  String get paletteNewSessionDesc;

  /// No description provided for @paletteNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching results'**
  String get paletteNoResults;

  /// No description provided for @paletteReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get paletteReconnect;

  /// No description provided for @paletteReconnectDesc.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to the server'**
  String get paletteReconnectDesc;

  /// No description provided for @paletteVoiceInput.
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get paletteVoiceInput;

  /// No description provided for @paletteVoiceInputDesc.
  ///
  /// In en, this message translates to:
  /// **'Start voice dictation'**
  String get paletteVoiceInputDesc;

  /// No description provided for @pluginActionFailed.
  ///
  /// In en, this message translates to:
  /// **'{title} failed: {error}'**
  String pluginActionFailed(String title, String error);

  /// No description provided for @pluginFieldInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get pluginFieldInvalidNumber;

  /// No description provided for @pluginFieldMaximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum value: {value}'**
  String pluginFieldMaximum(num value);

  /// No description provided for @pluginFieldMinimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum value: {value}'**
  String pluginFieldMinimum(num value);

  /// No description provided for @pluginFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get pluginFieldRequired;

  /// No description provided for @pluginItemFallback.
  ///
  /// In en, this message translates to:
  /// **'Item {index}'**
  String pluginItemFallback(int index);

  /// No description provided for @pluginNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items'**
  String get pluginNoItems;

  /// No description provided for @pluginResultCopied.
  ///
  /// In en, this message translates to:
  /// **'Result copied'**
  String get pluginResultCopied;

  /// No description provided for @pluginResultCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy result'**
  String get pluginResultCopy;

  /// No description provided for @pluginResultOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get pluginResultOpenLink;

  /// No description provided for @pluginSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get pluginSubmit;

  /// No description provided for @previewActionSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send preview action: {error}'**
  String previewActionSendFailed(String error);

  /// No description provided for @previewActionSent.
  ///
  /// In en, this message translates to:
  /// **'Preview action sent: {prompt}'**
  String previewActionSent(String prompt);

  /// No description provided for @previewBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get previewBack;

  /// No description provided for @previewClearConsole.
  ///
  /// In en, this message translates to:
  /// **'Clear console'**
  String get previewClearConsole;

  /// No description provided for @previewCloseConsole.
  ///
  /// In en, this message translates to:
  /// **'Close console'**
  String get previewCloseConsole;

  /// No description provided for @previewConsoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Console'**
  String get previewConsoleTitle;

  /// No description provided for @previewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Open a link in chat or select an HTML file'**
  String get previewEmpty;

  /// No description provided for @previewFailed.
  ///
  /// In en, this message translates to:
  /// **'Preview failed: {error}'**
  String previewFailed(String error);

  /// No description provided for @previewForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get previewForward;

  /// No description provided for @previewNoLogs.
  ///
  /// In en, this message translates to:
  /// **'No logs'**
  String get previewNoLogs;

  /// No description provided for @previewOpenBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get previewOpenBrowser;

  /// No description provided for @previewOpenConsole.
  ///
  /// In en, this message translates to:
  /// **'Open console'**
  String get previewOpenConsole;

  /// No description provided for @previewOpenSessionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open session: {error}'**
  String previewOpenSessionFailed(String error);

  /// No description provided for @previewRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh preview'**
  String get previewRefresh;

  /// No description provided for @previewRunJavascript.
  ///
  /// In en, this message translates to:
  /// **'Run JavaScript'**
  String get previewRunJavascript;

  /// No description provided for @previewRunScript.
  ///
  /// In en, this message translates to:
  /// **'Run script'**
  String get previewRunScript;

  /// No description provided for @previewTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewTitle;

  /// No description provided for @previewUnsupportedWebView.
  ///
  /// In en, this message translates to:
  /// **'Embedded WebView is unavailable on this platform. Open it in your browser.'**
  String get previewUnsupportedWebView;

  /// No description provided for @projectBrowseFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse the project directory'**
  String get projectBrowseFiles;

  /// No description provided for @projectDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Project details'**
  String get projectDetailTitle;

  /// No description provided for @projectFolderCount.
  ///
  /// In en, this message translates to:
  /// **'{count} folders'**
  String projectFolderCount(int count);

  /// No description provided for @projectGitDescription.
  ///
  /// In en, this message translates to:
  /// **'View repository status and changes'**
  String get projectGitDescription;

  /// No description provided for @projectGlobalMemoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Profile memory (global view)'**
  String get projectGlobalMemoryDescription;

  /// No description provided for @projectGlobalStarmapDescription.
  ///
  /// In en, this message translates to:
  /// **'Knowledge graph (global view)'**
  String get projectGlobalStarmapDescription;

  /// No description provided for @projectGlobalSubagentsDescription.
  ///
  /// In en, this message translates to:
  /// **'Subagent activity across sessions'**
  String get projectGlobalSubagentsDescription;

  /// No description provided for @projectGlobalWebhooksDescription.
  ///
  /// In en, this message translates to:
  /// **'Webhook configuration (global view)'**
  String get projectGlobalWebhooksDescription;

  /// No description provided for @projectLoadingSessions.
  ///
  /// In en, this message translates to:
  /// **'Loading sessions...'**
  String get projectLoadingSessions;

  /// No description provided for @projectModulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Modules'**
  String get projectModulesTitle;

  /// No description provided for @projectNoKanbanBoard.
  ///
  /// In en, this message translates to:
  /// **'This project has no linked board'**
  String get projectNoKanbanBoard;

  /// No description provided for @projectNoSessions.
  ///
  /// In en, this message translates to:
  /// **'No related sessions'**
  String get projectNoSessions;

  /// No description provided for @projectNoSessionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Sessions started inside this project appear here'**
  String get projectNoSessionsDescription;

  /// No description provided for @projectResumeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not resume session: {error}'**
  String projectResumeFailed(String error);

  /// No description provided for @projectSessionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sessions'**
  String projectSessionCount(int count);

  /// No description provided for @projectSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get projectSessionsTitle;

  /// No description provided for @projectTasksDescription.
  ///
  /// In en, this message translates to:
  /// **'Open a board linked to this project'**
  String get projectTasksDescription;

  /// No description provided for @projectTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks and boards'**
  String get projectTasksTitle;

  /// No description provided for @projectUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get projectUnavailable;

  /// No description provided for @projectUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled project'**
  String get projectUntitled;

  /// No description provided for @providerActiveDefault.
  ///
  /// In en, this message translates to:
  /// **'Active / default'**
  String get providerActiveDefault;

  /// No description provided for @providerAddEndpointTitle.
  ///
  /// In en, this message translates to:
  /// **'New custom endpoint'**
  String get providerAddEndpointTitle;

  /// No description provided for @providerCustomEndpointJson.
  ///
  /// In en, this message translates to:
  /// **'Custom endpoint JSON'**
  String get providerCustomEndpointJson;

  /// No description provided for @providerCustomEndpointsSection.
  ///
  /// In en, this message translates to:
  /// **'Custom endpoints'**
  String get providerCustomEndpointsSection;

  /// No description provided for @providerDeviceAuthorization.
  ///
  /// In en, this message translates to:
  /// **'Device authorization'**
  String get providerDeviceAuthorization;

  /// No description provided for @providerEditEndpointTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit custom endpoint'**
  String get providerEditEndpointTitle;

  /// No description provided for @providerEndpointApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get providerEndpointApiKey;

  /// No description provided for @providerEndpointBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get providerEndpointBaseUrl;

  /// No description provided for @providerEndpointDefaultModel.
  ///
  /// In en, this message translates to:
  /// **'Default model'**
  String get providerEndpointDefaultModel;

  /// No description provided for @providerEndpointDiscoverModels.
  ///
  /// In en, this message translates to:
  /// **'Auto-discover models'**
  String get providerEndpointDiscoverModels;

  /// No description provided for @providerEndpointFallback.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get providerEndpointFallback;

  /// No description provided for @providerEndpointModelsList.
  ///
  /// In en, this message translates to:
  /// **'Available models (one per line)'**
  String get providerEndpointModelsList;

  /// No description provided for @providerEndpointName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get providerEndpointName;

  /// No description provided for @providerEndpointNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get providerEndpointNameRequired;

  /// No description provided for @providerEndpointUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a base URL'**
  String get providerEndpointUrlRequired;

  /// No description provided for @providerEnterDeviceCode.
  ///
  /// In en, this message translates to:
  /// **'Enter this verification code in your browser: {code}'**
  String providerEnterDeviceCode(String code);

  /// No description provided for @providerActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed: {error}'**
  String providerActionFailed(String error);

  /// No description provided for @providerEnvironmentSection.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get providerEnvironmentSection;

  /// No description provided for @providerEnvironmentVariableName.
  ///
  /// In en, this message translates to:
  /// **'Environment variable name'**
  String get providerEnvironmentVariableName;

  /// No description provided for @providerEnvironmentVariableValue.
  ///
  /// In en, this message translates to:
  /// **'Environment variable value'**
  String get providerEnvironmentVariableValue;

  /// No description provided for @providerMissingKeys.
  ///
  /// In en, this message translates to:
  /// **'Missing: {keys}'**
  String providerMissingKeys(String keys);

  /// No description provided for @providerModelTitle.
  ///
  /// In en, this message translates to:
  /// **'{provider} model'**
  String providerModelTitle(String provider);

  /// No description provided for @providerNoConfiguration.
  ///
  /// In en, this message translates to:
  /// **'No configuration'**
  String get providerNoConfiguration;

  /// No description provided for @providerNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get providerNotSet;

  /// No description provided for @providerOauthSection.
  ///
  /// In en, this message translates to:
  /// **'Provider OAuth'**
  String get providerOauthSection;

  /// No description provided for @providerPasteOauthCode.
  ///
  /// In en, this message translates to:
  /// **'Paste OAuth code'**
  String get providerPasteOauthCode;

  /// No description provided for @providerProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get providerProfileLabel;

  /// No description provided for @providerRevealFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read value: {error}'**
  String providerRevealFailed(String error);

  /// No description provided for @providerRevealValue.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get providerRevealValue;

  /// No description provided for @providerRevealedValueTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved value'**
  String get providerRevealedValueTitle;

  /// No description provided for @providerRunSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'{provider} needs to run: {command}'**
  String providerRunSetupDescription(String provider, String command);

  /// No description provided for @providerRunSetupQuestion.
  ///
  /// In en, this message translates to:
  /// **'Run provider setup?'**
  String get providerRunSetupQuestion;

  /// No description provided for @providerSetActive.
  ///
  /// In en, this message translates to:
  /// **'Set active'**
  String get providerSetActive;

  /// No description provided for @providerSetEnvironmentVariable.
  ///
  /// In en, this message translates to:
  /// **'Set {key}'**
  String providerSetEnvironmentVariable(String key);

  /// No description provided for @providerToolsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tools'**
  String providerToolsCount(int count);

  /// No description provided for @providerToolsetProviderTitle.
  ///
  /// In en, this message translates to:
  /// **'{toolset} provider'**
  String providerToolsetProviderTitle(String toolset);

  /// No description provided for @providerToolsetProvidersSection.
  ///
  /// In en, this message translates to:
  /// **'Toolset providers'**
  String get providerToolsetProvidersSection;

  /// No description provided for @pushEnabled.
  ///
  /// In en, this message translates to:
  /// **'Remote notifications'**
  String get pushEnabled;

  /// No description provided for @pushEnabledDescription.
  ///
  /// In en, this message translates to:
  /// **'Register this installation with the active Hermes server'**
  String get pushEnabledDescription;

  /// No description provided for @pushOsPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'System notifications are blocked'**
  String get pushOsPermissionDenied;

  /// No description provided for @pushOsPermissionDeniedDescription.
  ///
  /// In en, this message translates to:
  /// **'Remote notifications are enabled in Hermes, but the OS is blocking them, so nothing will actually be delivered. Enable notifications for Hermes Mobile in your device\'s system settings.'**
  String get pushOsPermissionDeniedDescription;

  /// No description provided for @pushNoProviders.
  ///
  /// In en, this message translates to:
  /// **'APNs or FCM credentials are not configured on the server'**
  String get pushNoProviders;

  /// No description provided for @pushNotRegistered.
  ///
  /// In en, this message translates to:
  /// **'Not registered'**
  String get pushNotRegistered;

  /// No description provided for @pushProviders.
  ///
  /// In en, this message translates to:
  /// **'Delivery providers'**
  String get pushProviders;

  /// No description provided for @pushRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh push status'**
  String get pushRefresh;

  /// No description provided for @pushRegistered.
  ///
  /// In en, this message translates to:
  /// **'Registered for the active connection and profile'**
  String get pushRegistered;

  /// No description provided for @pushRegistration.
  ///
  /// In en, this message translates to:
  /// **'Device registration'**
  String get pushRegistration;

  /// No description provided for @pushSendTest.
  ///
  /// In en, this message translates to:
  /// **'Send test notification'**
  String get pushSendTest;

  /// No description provided for @pushSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Receive completions and approval requests when Hermes Mobile is closed.'**
  String get pushSettingsDescription;

  /// No description provided for @pushSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Remote notifications'**
  String get pushSettingsTitle;

  /// No description provided for @pushTestDelivered.
  ///
  /// In en, this message translates to:
  /// **'Test notification delivered'**
  String get pushTestDelivered;

  /// No description provided for @pushTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send test notification: {error}'**
  String pushTestFailed(String error);

  /// No description provided for @pushTestNotDelivered.
  ///
  /// In en, this message translates to:
  /// **'No provider delivered the test notification'**
  String get pushTestNotDelivered;

  /// No description provided for @reportIssueTitle.
  ///
  /// In en, this message translates to:
  /// **'Report an issue on GitHub'**
  String get reportIssueTitle;

  /// No description provided for @sendDiagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload redacted logs to help us debug an issue'**
  String get sendDiagnosticsSubtitle;

  /// No description provided for @sendDiagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Send diagnostics'**
  String get sendDiagnosticsTitle;

  /// No description provided for @sessionActions.
  ///
  /// In en, this message translates to:
  /// **'Session actions'**
  String get sessionActions;

  /// No description provided for @sessionAllTags.
  ///
  /// In en, this message translates to:
  /// **'All tags'**
  String get sessionAllTags;

  /// No description provided for @sessionArchiveView.
  ///
  /// In en, this message translates to:
  /// **'Archive view'**
  String get sessionArchiveView;

  /// No description provided for @sessionArchiveViewDescription.
  ///
  /// In en, this message translates to:
  /// **'Show archived sessions only'**
  String get sessionArchiveViewDescription;

  /// No description provided for @sessionBatchDeleteDescription.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The selected session will be permanently deleted. This cannot be undone.} other{The {count} selected sessions will be permanently deleted. This cannot be undone.}}'**
  String sessionBatchDeleteDescription(int count);

  /// No description provided for @sessionBatchDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete sessions?'**
  String get sessionBatchDeleteTitle;

  /// No description provided for @sessionCancelSelection.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get sessionCancelSelection;

  /// No description provided for @sessionClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get sessionClearAll;

  /// No description provided for @sessionClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get sessionClearFilters;

  /// No description provided for @sessionClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get sessionClearSearch;

  /// No description provided for @sessionCollapseChildren.
  ///
  /// In en, this message translates to:
  /// **'Collapse child sessions'**
  String get sessionCollapseChildren;

  /// No description provided for @sessionConfirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get sessionConfirmDelete;

  /// No description provided for @sessionContinueLast.
  ///
  /// In en, this message translates to:
  /// **'Continue last session'**
  String get sessionContinueLast;

  /// No description provided for @sessionDeepSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search session titles and message history'**
  String get sessionDeepSearchHint;

  /// No description provided for @sessionDeepSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search chat history'**
  String get sessionDeepSearchTitle;

  /// No description provided for @sessionDeleteDescription.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will be permanently deleted.'**
  String sessionDeleteDescription(String title);

  /// No description provided for @sessionDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete sessions: {error}'**
  String sessionDeleteFailed(String error);

  /// No description provided for @sessionDeleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get sessionDeleteSelected;

  /// No description provided for @sessionDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete session?'**
  String get sessionDeleteTitle;

  /// No description provided for @sessionDeletedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Deleted 1 session} other{Deleted {count} sessions}}'**
  String sessionDeletedCount(int count);

  /// No description provided for @sessionDurationDaysHours.
  ///
  /// In en, this message translates to:
  /// **'{days}d {hours}h'**
  String sessionDurationDaysHours(int days, int hours);

  /// No description provided for @sessionDurationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String sessionDurationHoursMinutes(int hours, int minutes);

  /// No description provided for @sessionDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String sessionDurationMinutes(int minutes);

  /// No description provided for @sessionEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Start a new session to chat with Hermes'**
  String get sessionEmptyDescription;

  /// No description provided for @sessionEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get sessionEmptyTitle;

  /// No description provided for @sessionExpandChildren.
  ///
  /// In en, this message translates to:
  /// **'Expand child sessions'**
  String get sessionExpandChildren;

  /// No description provided for @sessionFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get sessionFilterAll;

  /// No description provided for @sessionFilterApproval.
  ///
  /// In en, this message translates to:
  /// **'Needs approval'**
  String get sessionFilterApproval;

  /// No description provided for @sessionFilterByTag.
  ///
  /// In en, this message translates to:
  /// **'Filter by tag'**
  String get sessionFilterByTag;

  /// No description provided for @sessionFilterCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get sessionFilterCompleted;

  /// No description provided for @sessionFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter sessions'**
  String get sessionFilterTitle;

  /// No description provided for @sessionGroupArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get sessionGroupArchived;

  /// No description provided for @sessionGroupByProject.
  ///
  /// In en, this message translates to:
  /// **'Group by project'**
  String get sessionGroupByProject;

  /// No description provided for @sessionGroupByTime.
  ///
  /// In en, this message translates to:
  /// **'Group by time'**
  String get sessionGroupByTime;

  /// No description provided for @sessionGroupLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get sessionGroupLast7Days;

  /// No description provided for @sessionGroupOlder.
  ///
  /// In en, this message translates to:
  /// **'Older'**
  String get sessionGroupOlder;

  /// No description provided for @sessionGroupPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get sessionGroupPinned;

  /// No description provided for @sessionGroupRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get sessionGroupRunning;

  /// No description provided for @sessionHandoff.
  ///
  /// In en, this message translates to:
  /// **'Handoff {state}'**
  String sessionHandoff(String state);

  /// No description provided for @sessionHistoryArchive.
  ///
  /// In en, this message translates to:
  /// **'History archive'**
  String get sessionHistoryArchive;

  /// No description provided for @sessionLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more sessions'**
  String get sessionLoadMore;

  /// No description provided for @sessionManage.
  ///
  /// In en, this message translates to:
  /// **'Manage sessions'**
  String get sessionManage;

  /// No description provided for @sessionMessageCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 message} other{{count} messages}}'**
  String sessionMessageCount(int count);

  /// No description provided for @sessionNew.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get sessionNew;

  /// No description provided for @sessionNoMatchesDescription.
  ///
  /// In en, this message translates to:
  /// **'Adjust the search or status filters'**
  String get sessionNoMatchesDescription;

  /// No description provided for @sessionNoMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching sessions'**
  String get sessionNoMatchesTitle;

  /// No description provided for @sessionNoProjectsDescription.
  ///
  /// In en, this message translates to:
  /// **'Sessions started in Git repositories are grouped into projects automatically'**
  String get sessionNoProjectsDescription;

  /// No description provided for @sessionNoProjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'No projects'**
  String get sessionNoProjectsTitle;

  /// No description provided for @sessionOpenCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the copy: {error}'**
  String sessionOpenCopyFailed(String error);

  /// No description provided for @sessionPrClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get sessionPrClosed;

  /// No description provided for @sessionPrDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get sessionPrDraft;

  /// No description provided for @sessionPrMerged.
  ///
  /// In en, this message translates to:
  /// **'Merged'**
  String get sessionPrMerged;

  /// No description provided for @sessionPrNone.
  ///
  /// In en, this message translates to:
  /// **'No PR'**
  String get sessionPrNone;

  /// No description provided for @sessionPrOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get sessionPrOpen;

  /// No description provided for @sessionProjectBack.
  ///
  /// In en, this message translates to:
  /// **'Back to projects'**
  String get sessionProjectBack;

  /// No description provided for @sessionProjectEnter.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get sessionProjectEnter;

  /// No description provided for @sessionProjectNoSessions.
  ///
  /// In en, this message translates to:
  /// **'No sessions in this project'**
  String get sessionProjectNoSessions;

  /// No description provided for @sessionProjectSessionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 session} other{{count} sessions}}'**
  String sessionProjectSessionCount(int count);

  /// No description provided for @sessionProjectUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Project unavailable'**
  String get sessionProjectUnavailable;

  /// No description provided for @sessionPullRequests.
  ///
  /// In en, this message translates to:
  /// **'Pull requests'**
  String get sessionPullRequests;

  /// No description provided for @sessionResumeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore the session: {error}'**
  String sessionResumeFailed(String error);

  /// No description provided for @sessionResumeLastFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore the last session: {error}'**
  String sessionResumeLastFailed(String error);

  /// No description provided for @sessionResumeSubagentFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore the subagent session: {error}'**
  String sessionResumeSubagentFailed(String error);

  /// No description provided for @sessionSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed: {error}'**
  String sessionSearchFailed(String error);

  /// No description provided for @sessionSearchMessages.
  ///
  /// In en, this message translates to:
  /// **'Search message content'**
  String get sessionSearchMessages;

  /// No description provided for @sessionSearchNoFilteredResults.
  ///
  /// In en, this message translates to:
  /// **'No results match the current filters'**
  String get sessionSearchNoFilteredResults;

  /// No description provided for @sessionSearchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter keywords to search all session history'**
  String get sessionSearchPrompt;

  /// No description provided for @sessionSearchResultCount.
  ///
  /// In en, this message translates to:
  /// **'Found {total} sessions, showing {visible}'**
  String sessionSearchResultCount(int total, int visible);

  /// No description provided for @sessionSearchTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Search session titles…'**
  String get sessionSearchTitleHint;

  /// No description provided for @sessionSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get sessionSelectAll;

  /// No description provided for @sessionSelectDescription.
  ///
  /// In en, this message translates to:
  /// **'Open a session from the list to continue working'**
  String get sessionSelectDescription;

  /// No description provided for @sessionSelectMultiple.
  ///
  /// In en, this message translates to:
  /// **'Select multiple'**
  String get sessionSelectMultiple;

  /// No description provided for @sessionSelectSessions.
  ///
  /// In en, this message translates to:
  /// **'Select sessions'**
  String get sessionSelectSessions;

  /// No description provided for @sessionSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a session'**
  String get sessionSelectTitle;

  /// No description provided for @sessionSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 selected} other{{count} selected}}'**
  String sessionSelectedCount(int count);

  /// No description provided for @sessionServerNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Server not connected'**
  String get sessionServerNotConnected;

  /// No description provided for @sessionSortActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get sessionSortActivity;

  /// No description provided for @sessionSortCreated.
  ///
  /// In en, this message translates to:
  /// **'Date created'**
  String get sessionSortCreated;

  /// No description provided for @sessionSortTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sessionSortTitle;

  /// No description provided for @sessionSortTokens.
  ///
  /// In en, this message translates to:
  /// **'Token usage'**
  String get sessionSortTokens;

  /// No description provided for @sessionStatusAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get sessionStatusAttention;

  /// No description provided for @sessionStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get sessionStatusIdle;

  /// No description provided for @sessionStatusWorking.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get sessionStatusWorking;

  /// No description provided for @sessionTimeAll.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get sessionTimeAll;

  /// No description provided for @sessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionTitle;

  /// No description provided for @sessionToolCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 tool} other{{count} tools}}'**
  String sessionToolCount(int count);

  /// No description provided for @sessionUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled session'**
  String get sessionUntitled;

  /// No description provided for @sessionWithinDays.
  ///
  /// In en, this message translates to:
  /// **'Within {count} days'**
  String sessionWithinDays(int count);

  /// No description provided for @settingsAppearanceDesc.
  ///
  /// In en, this message translates to:
  /// **'Display mode, theme color, and contrast'**
  String get settingsAppearanceDesc;

  /// No description provided for @settingsBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get settingsBackHome;

  /// No description provided for @settingsBackendConfigSummary.
  ///
  /// In en, this message translates to:
  /// **'Backend configuration summary'**
  String get settingsBackendConfigSummary;

  /// No description provided for @settingsBackendConfigSummaryDesc.
  ///
  /// In en, this message translates to:
  /// **'Key configuration values'**
  String get settingsBackendConfigSummaryDesc;

  /// No description provided for @settingsBackendConnectionSection.
  ///
  /// In en, this message translates to:
  /// **'Backend and connection'**
  String get settingsBackendConnectionSection;

  /// No description provided for @settingsBackendRestartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restart backend: {error}'**
  String settingsBackendRestartFailed(String error);

  /// No description provided for @settingsBackendRestarted.
  ///
  /// In en, this message translates to:
  /// **'Backend restarted'**
  String get settingsBackendRestarted;

  /// No description provided for @settingsCapabilitiesDesc.
  ///
  /// In en, this message translates to:
  /// **'MCP, knowledge, skills, and plugins'**
  String get settingsCapabilitiesDesc;

  /// No description provided for @settingsCapabilitiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Capability management'**
  String get settingsCapabilitiesTitle;

  /// No description provided for @settingsChangeConnection.
  ///
  /// In en, this message translates to:
  /// **'Change connection'**
  String get settingsChangeConnection;

  /// No description provided for @settingsChangeConnectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Edit the server address and API key'**
  String get settingsChangeConnectionDesc;

  /// No description provided for @settingsChangeConnectionQuestion.
  ///
  /// In en, this message translates to:
  /// **'Change connection?'**
  String get settingsChangeConnectionQuestion;

  /// No description provided for @settingsChangeConnectionWarning.
  ///
  /// In en, this message translates to:
  /// **'The current server connection will be cleared so you can enter a new server address and API key.'**
  String get settingsChangeConnectionWarning;

  /// No description provided for @settingsGroupModels.
  ///
  /// In en, this message translates to:
  /// **'Models and capabilities'**
  String get settingsGroupModels;

  /// No description provided for @settingsGroupPersonalization.
  ///
  /// In en, this message translates to:
  /// **'Personalization'**
  String get settingsGroupPersonalization;

  /// No description provided for @settingsModelDesc.
  ///
  /// In en, this message translates to:
  /// **'Models, conversations, memory context, and keys'**
  String get settingsModelDesc;

  /// No description provided for @settingsModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Models and conversations'**
  String get settingsModelTitle;

  /// No description provided for @settingsProvidersDesc.
  ///
  /// In en, this message translates to:
  /// **'Environment, custom endpoints, OAuth, and toolset providers'**
  String get settingsProvidersDesc;

  /// No description provided for @settingsProvidersTitle.
  ///
  /// In en, this message translates to:
  /// **'Providers and runtime'**
  String get settingsProvidersTitle;

  /// No description provided for @settingsRestartBackend.
  ///
  /// In en, this message translates to:
  /// **'Restart Hermes backend'**
  String get settingsRestartBackend;

  /// No description provided for @settingsRestartBackendDesc.
  ///
  /// In en, this message translates to:
  /// **'Interrupt current work and restart the server process'**
  String get settingsRestartBackendDesc;

  /// No description provided for @settingsRestartBackendQuestion.
  ///
  /// In en, this message translates to:
  /// **'Restart the Hermes backend?'**
  String get settingsRestartBackendQuestion;

  /// No description provided for @settingsRestartBackendWarning.
  ///
  /// In en, this message translates to:
  /// **'Running sessions on the server will be interrupted.'**
  String get settingsRestartBackendWarning;

  /// No description provided for @settingsSystemConnectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Connection, security, terminal, and backend'**
  String get settingsSystemConnectionDesc;

  /// No description provided for @settingsSystemConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'System and connection'**
  String get settingsSystemConnectionTitle;

  /// No description provided for @settingsTerminalSection.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get settingsTerminalSection;

  /// No description provided for @taskAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get taskAll;

  /// No description provided for @taskAssigneeFilter.
  ///
  /// In en, this message translates to:
  /// **'Assignee: {value}'**
  String taskAssigneeFilter(String value);

  /// No description provided for @taskAutoDecompose.
  ///
  /// In en, this message translates to:
  /// **'Automatically decompose tasks'**
  String get taskAutoDecompose;

  /// No description provided for @taskAutoGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate automatically'**
  String get taskAutoGenerate;

  /// No description provided for @taskBoardView.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get taskBoardView;

  /// No description provided for @taskBulkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update {count} tasks'**
  String taskBulkFailed(int count);

  /// No description provided for @taskClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get taskClearFilters;

  /// No description provided for @taskCloseSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get taskCloseSearch;

  /// No description provided for @taskCommentCount.
  ///
  /// In en, this message translates to:
  /// **'{count} comments'**
  String taskCommentCount(int count);

  /// No description provided for @taskConnectBackend.
  ///
  /// In en, this message translates to:
  /// **'Connect to the backend to view tasks'**
  String get taskConnectBackend;

  /// No description provided for @taskDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get taskDefault;

  /// No description provided for @taskDefaultAssignee.
  ///
  /// In en, this message translates to:
  /// **'Default assignee'**
  String get taskDefaultAssignee;

  /// No description provided for @taskFilter.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get taskFilter;

  /// No description provided for @taskListView.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get taskListView;

  /// No description provided for @taskNew.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get taskNew;

  /// No description provided for @taskNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get taskNoDescription;

  /// No description provided for @taskOptions.
  ///
  /// In en, this message translates to:
  /// **'Task options'**
  String get taskOptions;

  /// No description provided for @taskOrchestration.
  ///
  /// In en, this message translates to:
  /// **'Orchestration'**
  String get taskOrchestration;

  /// No description provided for @taskOrchestratorProfile.
  ///
  /// In en, this message translates to:
  /// **'Orchestrator profile'**
  String get taskOrchestratorProfile;

  /// No description provided for @taskPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get taskPriorityHigh;

  /// No description provided for @taskPriorityMeta.
  ///
  /// In en, this message translates to:
  /// **'Priority: {priority}'**
  String taskPriorityMeta(String priority);

  /// No description provided for @taskPriorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get taskPriorityNormal;

  /// No description provided for @taskPriorityUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get taskPriorityUrgent;

  /// No description provided for @taskProfileDescription.
  ///
  /// In en, this message translates to:
  /// **'Description for {name}'**
  String taskProfileDescription(String name);

  /// No description provided for @taskProfileDescriptions.
  ///
  /// In en, this message translates to:
  /// **'Profile descriptions'**
  String get taskProfileDescriptions;

  /// No description provided for @taskSearch.
  ///
  /// In en, this message translates to:
  /// **'Search tasks'**
  String get taskSearch;

  /// No description provided for @taskSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String taskSelectedCount(int count);

  /// No description provided for @taskShowArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived'**
  String get taskShowArchived;

  /// No description provided for @taskStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get taskStatusArchived;

  /// No description provided for @taskStatusBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get taskStatusBlocked;

  /// No description provided for @taskStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get taskStatusDone;

  /// No description provided for @taskStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get taskStatusReady;

  /// No description provided for @taskStatusReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get taskStatusReview;

  /// No description provided for @taskStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get taskStatusRunning;

  /// No description provided for @taskStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get taskStatusScheduled;

  /// No description provided for @taskStatusTodo.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get taskStatusTodo;

  /// No description provided for @taskStatusTriage.
  ///
  /// In en, this message translates to:
  /// **'Triage'**
  String get taskStatusTriage;

  /// No description provided for @taskSwitchBoard.
  ///
  /// In en, this message translates to:
  /// **'Switch board'**
  String get taskSwitchBoard;

  /// No description provided for @taskTenantFilter.
  ///
  /// In en, this message translates to:
  /// **'Tenant: {value}'**
  String taskTenantFilter(String value);

  /// No description provided for @taskTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get taskTitle;

  /// No description provided for @taskUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get taskUnassigned;

  /// No description provided for @taskWeeklyDelivery.
  ///
  /// In en, this message translates to:
  /// **'Weekly delivery'**
  String get taskWeeklyDelivery;

  /// No description provided for @terminalDefaultMonospace.
  ///
  /// In en, this message translates to:
  /// **'Default monospace font'**
  String get terminalDefaultMonospace;

  /// No description provided for @terminalFontHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the default monospace font'**
  String get terminalFontHint;

  /// No description provided for @terminalFontPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview  ~/project  git:main  >'**
  String get terminalFontPreview;

  /// No description provided for @terminalFontSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save terminal font: {error}'**
  String terminalFontSaveFailed(String error);

  /// No description provided for @terminalFontSaved.
  ///
  /// In en, this message translates to:
  /// **'Terminal font saved'**
  String get terminalFontSaved;

  /// No description provided for @terminalFontTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminal font'**
  String get terminalFontTitle;

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String timeDaysAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String timeHoursAgo(int count);

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String timeMinutesAgo(int count);

  /// No description provided for @updateAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get updateAppVersion;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available: {version}'**
  String updateAvailableTitle(String version);

  /// No description provided for @updateCheck.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get updateCheck;

  /// No description provided for @updateCheckDescription.
  ///
  /// In en, this message translates to:
  /// **'Check the mobile release manifest for a new version'**
  String get updateCheckDescription;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Update check failed'**
  String get updateCheckFailed;

  /// No description provided for @updateCheckUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Temporarily unavailable: {error}'**
  String updateCheckUnavailable(String error);

  /// No description provided for @updateCurrent.
  ///
  /// In en, this message translates to:
  /// **'You are using the latest version'**
  String get updateCurrent;

  /// No description provided for @updateFound.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String updateFound(String version);

  /// No description provided for @updateGoToUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateGoToUpdate;

  /// No description provided for @updateMinimumVersion.
  ///
  /// In en, this message translates to:
  /// **'Minimum compatible version: {minimumVersion}'**
  String updateMinimumVersion(String minimumVersion);

  /// No description provided for @updateNewVersionPublished.
  ///
  /// In en, this message translates to:
  /// **'A new version has been released'**
  String get updateNewVersionPublished;

  /// No description provided for @updateReleaseNotes.
  ///
  /// In en, this message translates to:
  /// **'Release notes'**
  String get updateReleaseNotes;

  /// No description provided for @updateRequiredDefault.
  ///
  /// In en, this message translates to:
  /// **'Version {currentVersion} is below the minimum compatible version {minimumVersion}. Update to continue.'**
  String updateRequiredDefault(String currentVersion, String minimumVersion);

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Hermes Mobile update required'**
  String get updateRequiredTitle;

  /// No description provided for @updateSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updateSectionTitle;

  /// No description provided for @updateUnsupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'This version is no longer supported'**
  String get updateUnsupportedTitle;

  /// No description provided for @updateVersionBuild.
  ///
  /// In en, this message translates to:
  /// **'v{version} · build {build}'**
  String updateVersionBuild(String version, String build);

  /// No description provided for @workspaceAddPaneTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open pane'**
  String get workspaceAddPaneTooltip;

  /// No description provided for @workspaceApplyLayoutTooltip.
  ///
  /// In en, this message translates to:
  /// **'Apply layout'**
  String get workspaceApplyLayoutTooltip;

  /// No description provided for @workspaceCloseAllAction.
  ///
  /// In en, this message translates to:
  /// **'Close all'**
  String get workspaceCloseAllAction;

  /// No description provided for @workspaceCloseAllDescription.
  ///
  /// In en, this message translates to:
  /// **'This only closes the mobile workspace. Sessions and plugin data will not be deleted.'**
  String get workspaceCloseAllDescription;

  /// No description provided for @workspaceCloseAllQuestion.
  ///
  /// In en, this message translates to:
  /// **'Close all panes?'**
  String get workspaceCloseAllQuestion;

  /// No description provided for @workspaceCloseAllTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close all panes'**
  String get workspaceCloseAllTooltip;

  /// No description provided for @workspaceEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Open content from a session menu or plugin pane entry'**
  String get workspaceEmptyDescription;

  /// No description provided for @workspaceEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Workspace is empty'**
  String get workspaceEmptyTitle;

  /// No description provided for @workspaceLayoutDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get workspaceLayoutDefault;

  /// No description provided for @workspaceLayoutFocus.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get workspaceLayoutFocus;

  /// No description provided for @workspaceLayoutQuad.
  ///
  /// In en, this message translates to:
  /// **'Quad'**
  String get workspaceLayoutQuad;

  /// No description provided for @workspaceLayoutTerminalDeck.
  ///
  /// In en, this message translates to:
  /// **'Terminal deck'**
  String get workspaceLayoutTerminalDeck;

  /// No description provided for @workspaceLayoutTooltip.
  ///
  /// In en, this message translates to:
  /// **'Adjust pane layout'**
  String get workspaceLayoutTooltip;

  /// No description provided for @workspaceMergeTabs.
  ///
  /// In en, this message translates to:
  /// **'Merge as tabs'**
  String get workspaceMergeTabs;

  /// No description provided for @workspaceMoveBottom.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get workspaceMoveBottom;

  /// No description provided for @workspaceMoveLeft.
  ///
  /// In en, this message translates to:
  /// **'Move left'**
  String get workspaceMoveLeft;

  /// No description provided for @workspaceMoveRight.
  ///
  /// In en, this message translates to:
  /// **'Move right'**
  String get workspaceMoveRight;

  /// No description provided for @workspaceMoveTop.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get workspaceMoveTop;

  /// No description provided for @workspaceOpenPluginFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open plugin pane: {error}'**
  String workspaceOpenPluginFailed(String error);

  /// No description provided for @workspaceOpenSessionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open workspace: {error}'**
  String workspaceOpenSessionFailed(String error);

  /// No description provided for @workspacePaneFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get workspacePaneFiles;

  /// No description provided for @workspacePaneLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get workspacePaneLogs;

  /// No description provided for @workspacePanePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get workspacePanePreview;

  /// No description provided for @workspacePaneReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get workspacePaneReview;

  /// No description provided for @workspacePaneTerminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get workspacePaneTerminal;

  /// No description provided for @workspacePluginUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This plugin pane is unavailable. Check that the plugin is enabled.'**
  String get workspacePluginUnavailable;

  /// No description provided for @workspaceSessionResumeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore session: {error}'**
  String workspaceSessionResumeFailed(String error);

  /// No description provided for @workspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspaceTitle;

  /// No description provided for @statusSemantics.
  ///
  /// In en, this message translates to:
  /// **'Status: {label}'**
  String statusSemantics(String label);

  /// No description provided for @statusAgentSemantics.
  ///
  /// In en, this message translates to:
  /// **'Agent status: {label}'**
  String statusAgentSemantics(String label);

  /// No description provided for @statusToolSemantics.
  ///
  /// In en, this message translates to:
  /// **'Tool status: {label}'**
  String statusToolSemantics(String label);

  /// No description provided for @statusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get statusIdle;

  /// No description provided for @statusThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get statusThinking;

  /// No description provided for @statusPlanning.
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get statusPlanning;

  /// No description provided for @statusRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get statusRunning;

  /// No description provided for @statusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get statusWaiting;

  /// No description provided for @statusAwaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'Awaiting approval'**
  String get statusAwaitingApproval;

  /// No description provided for @statusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get statusPaused;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @statusStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get statusStopped;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @composerUndoInput.
  ///
  /// In en, this message translates to:
  /// **'Undo input'**
  String get composerUndoInput;

  /// No description provided for @composerRedoInput.
  ///
  /// In en, this message translates to:
  /// **'Redo input'**
  String get composerRedoInput;

  /// No description provided for @composerReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Subagent sessions are read-only'**
  String get composerReadOnly;

  /// No description provided for @composerMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message Hermes...'**
  String get composerMessageHint;

  /// No description provided for @composerProfileValue.
  ///
  /// In en, this message translates to:
  /// **'Profile: {value}'**
  String composerProfileValue(String value);

  /// No description provided for @composerSelectProfile.
  ///
  /// In en, this message translates to:
  /// **'Select profile'**
  String get composerSelectProfile;

  /// No description provided for @composerWorkspaceValue.
  ///
  /// In en, this message translates to:
  /// **'Workspace: {value}'**
  String composerWorkspaceValue(String value);

  /// No description provided for @composerSelectWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Select workspace'**
  String get composerSelectWorkspace;

  /// No description provided for @composerModelValue.
  ///
  /// In en, this message translates to:
  /// **'Model: {value}'**
  String composerModelValue(String value);

  /// No description provided for @composerSelectModel.
  ///
  /// In en, this message translates to:
  /// **'Select model'**
  String get composerSelectModel;

  /// No description provided for @composerDifficultyValue.
  ///
  /// In en, this message translates to:
  /// **'Difficulty: {value}'**
  String composerDifficultyValue(String value);

  /// No description provided for @composerYoloModeValue.
  ///
  /// In en, this message translates to:
  /// **'Yolo mode: {value}'**
  String composerYoloModeValue(String value);

  /// No description provided for @composerEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get composerEnabled;

  /// No description provided for @composerDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get composerDisabled;

  /// No description provided for @composerConfigureToolsets.
  ///
  /// In en, this message translates to:
  /// **'Configure toolsets'**
  String get composerConfigureToolsets;

  /// No description provided for @composerCloseEmojiPanel.
  ///
  /// In en, this message translates to:
  /// **'Close emoji panel'**
  String get composerCloseEmojiPanel;

  /// No description provided for @composerEmoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get composerEmoji;

  /// No description provided for @composerEditorActions.
  ///
  /// In en, this message translates to:
  /// **'Editor actions'**
  String get composerEditorActions;

  /// No description provided for @composerClearInput.
  ///
  /// In en, this message translates to:
  /// **'Clear input'**
  String get composerClearInput;

  /// No description provided for @composerEnterSendsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Enter sends; Shift+Enter inserts a new line'**
  String get composerEnterSendsTooltip;

  /// No description provided for @composerEnterNewlineTooltip.
  ///
  /// In en, this message translates to:
  /// **'Enter inserts a new line; tap Send to submit'**
  String get composerEnterNewlineTooltip;

  /// No description provided for @composerEnterSends.
  ///
  /// In en, this message translates to:
  /// **'Enter sends'**
  String get composerEnterSends;

  /// No description provided for @composerEnterNewline.
  ///
  /// In en, this message translates to:
  /// **'Enter for new line'**
  String get composerEnterNewline;

  /// No description provided for @composerRemoveAttachment.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment: {label}'**
  String composerRemoveAttachment(String label);

  /// No description provided for @composerFolderNotUploaded.
  ///
  /// In en, this message translates to:
  /// **'Local folder reference — not sent to the server'**
  String get composerFolderNotUploaded;

  /// No description provided for @composerCurrentDefault.
  ///
  /// In en, this message translates to:
  /// **'Current profile default'**
  String get composerCurrentDefault;

  /// No description provided for @composerUsedDefaultTools.
  ///
  /// In en, this message translates to:
  /// **'Using default tool configuration'**
  String get composerUsedDefaultTools;

  /// No description provided for @composerAppliedTools.
  ///
  /// In en, this message translates to:
  /// **'Applied {count} tools'**
  String composerAppliedTools(int count);

  /// No description provided for @composerSwitchedToDefault.
  ///
  /// In en, this message translates to:
  /// **'Switched to default configuration'**
  String get composerSwitchedToDefault;

  /// No description provided for @composerToolConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Tool configuration'**
  String get composerToolConfiguration;

  /// No description provided for @composerToolConfigurationDescription.
  ///
  /// In en, this message translates to:
  /// **'Use the current profile defaults or select custom toolsets for this session'**
  String get composerToolConfigurationDescription;

  /// No description provided for @composerUseCurrentDefault.
  ///
  /// In en, this message translates to:
  /// **'Use current profile default'**
  String get composerUseCurrentDefault;

  /// No description provided for @composerSelectCustomTools.
  ///
  /// In en, this message translates to:
  /// **'Select custom tools for this session'**
  String get composerSelectCustomTools;

  /// No description provided for @composerConfiguredMcpServers.
  ///
  /// In en, this message translates to:
  /// **'Configured MCP servers'**
  String get composerConfiguredMcpServers;

  /// No description provided for @composerNoConfiguredMcpServers.
  ///
  /// In en, this message translates to:
  /// **'No MCP servers configured'**
  String get composerNoConfiguredMcpServers;

  /// No description provided for @composerUseDefault.
  ///
  /// In en, this message translates to:
  /// **'Use default'**
  String get composerUseDefault;

  /// No description provided for @composerApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get composerApply;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @onboardingChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat with Hermes'**
  String get onboardingChatTitle;

  /// No description provided for @onboardingChatDescription.
  ///
  /// In en, this message translates to:
  /// **'Start sessions, use voice input, inspect tool calls and reasoning, and continue earlier conversations.'**
  String get onboardingChatDescription;

  /// No description provided for @onboardingProjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Projects and sessions'**
  String get onboardingProjectsTitle;

  /// No description provided for @onboardingProjectsDescription.
  ///
  /// In en, this message translates to:
  /// **'Sessions are grouped by project, Git branch, and worktree, with pinning, archiving, and status filters.'**
  String get onboardingProjectsDescription;

  /// No description provided for @onboardingTerminalTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminal and Git'**
  String get onboardingTerminalTitle;

  /// No description provided for @onboardingTerminalDescription.
  ///
  /// In en, this message translates to:
  /// **'Run terminal commands, review diffs, stage and commit changes, and create pull requests from mobile.'**
  String get onboardingTerminalDescription;

  /// No description provided for @onboardingPaletteTitle.
  ///
  /// In en, this message translates to:
  /// **'Command palette'**
  String get onboardingPaletteTitle;

  /// No description provided for @onboardingPaletteDescription.
  ///
  /// In en, this message translates to:
  /// **'Open the command palette from search or a pull-down gesture to jump to features, recent sessions, or slash commands.'**
  String get onboardingPaletteDescription;

  /// No description provided for @onboardingPetTitle.
  ///
  /// In en, this message translates to:
  /// **'Your AI pet'**
  String get onboardingPetTitle;

  /// No description provided for @onboardingPetDescription.
  ///
  /// In en, this message translates to:
  /// **'An AI pet that reacts to task status and can have its own generated appearance.'**
  String get onboardingPetDescription;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingStart;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @petGenerateInputRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a description or add a reference image'**
  String get petGenerateInputRequired;

  /// No description provided for @petGenerateEmptyResult.
  ///
  /// In en, this message translates to:
  /// **'No drafts were generated'**
  String get petGenerateEmptyResult;

  /// No description provided for @petGenerateHatchFailed.
  ///
  /// In en, this message translates to:
  /// **'Hatching failed: {error}'**
  String petGenerateHatchFailed(Object error);

  /// No description provided for @petGenerateAdoptFailed.
  ///
  /// In en, this message translates to:
  /// **'Adoption failed: {error}'**
  String petGenerateAdoptFailed(Object error);

  /// No description provided for @petGenerateTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate a new pet'**
  String get petGenerateTitle;

  /// No description provided for @petGenerateDescribe.
  ///
  /// In en, this message translates to:
  /// **'Describe the pet you want'**
  String get petGenerateDescribe;

  /// No description provided for @petGeneratePromptHint.
  ///
  /// In en, this message translates to:
  /// **'For example: a cyberpunk mechanical cat'**
  String get petGeneratePromptHint;

  /// No description provided for @petGenerateAddReference.
  ///
  /// In en, this message translates to:
  /// **'Add reference image (optional)'**
  String get petGenerateAddReference;

  /// No description provided for @petGenerateReferenceHelp.
  ///
  /// In en, this message translates to:
  /// **'Every draft will use this image as a reference'**
  String get petGenerateReferenceHelp;

  /// No description provided for @petGenerateModel.
  ///
  /// In en, this message translates to:
  /// **'Generation model'**
  String get petGenerateModel;

  /// No description provided for @petGenerateAutoSelect.
  ///
  /// In en, this message translates to:
  /// **'Select automatically'**
  String get petGenerateAutoSelect;

  /// No description provided for @petGenerateDraftsAction.
  ///
  /// In en, this message translates to:
  /// **'Generate 4 drafts'**
  String get petGenerateDraftsAction;

  /// No description provided for @petGenerateProgress.
  ///
  /// In en, this message translates to:
  /// **'Generating drafts… ({done}/{total})'**
  String petGenerateProgress(Object done, Object total);

  /// No description provided for @petGenerateChooseDraft.
  ///
  /// In en, this message translates to:
  /// **'Choose your favorite draft'**
  String get petGenerateChooseDraft;

  /// No description provided for @petGenerateDraftLabel.
  ///
  /// In en, this message translates to:
  /// **'Draft {index}'**
  String petGenerateDraftLabel(Object index);

  /// No description provided for @petGenerateAgain.
  ///
  /// In en, this message translates to:
  /// **'Generate again'**
  String get petGenerateAgain;

  /// No description provided for @petGenerateHatch.
  ///
  /// In en, this message translates to:
  /// **'Hatch'**
  String get petGenerateHatch;

  /// No description provided for @petGeneratePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get petGeneratePreparing;

  /// No description provided for @petGenerateDrawingProgress.
  ///
  /// In en, this message translates to:
  /// **'Drawing {state} frames ({done}/{total})'**
  String petGenerateDrawingProgress(Object done, Object state, Object total);

  /// No description provided for @petGenerateDrawing.
  ///
  /// In en, this message translates to:
  /// **'Drawing {state} frames'**
  String petGenerateDrawing(Object state);

  /// No description provided for @petGenerateComposing.
  ///
  /// In en, this message translates to:
  /// **'Composing sprite sheet…'**
  String get petGenerateComposing;

  /// No description provided for @petGenerateSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get petGenerateSaving;

  /// No description provided for @petGenerateHatching.
  ///
  /// In en, this message translates to:
  /// **'Hatching…'**
  String get petGenerateHatching;

  /// No description provided for @petGenerateReady.
  ///
  /// In en, this message translates to:
  /// **'Your new pet has hatched!'**
  String get petGenerateReady;

  /// No description provided for @petGenerateNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Give it a name'**
  String get petGenerateNameLabel;

  /// No description provided for @petGenerateDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get petGenerateDiscard;

  /// No description provided for @petGenerateAdopt.
  ///
  /// In en, this message translates to:
  /// **'Adopt'**
  String get petGenerateAdopt;

  /// No description provided for @imageSave.
  ///
  /// In en, this message translates to:
  /// **'Save image'**
  String get imageSave;

  /// No description provided for @imageCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy image link'**
  String get imageCopyLink;

  /// No description provided for @imageSavedToGallery.
  ///
  /// In en, this message translates to:
  /// **'Saved to gallery'**
  String get imageSavedToGallery;

  /// No description provided for @kanbanHomeChannels.
  ///
  /// In en, this message translates to:
  /// **'Home channel notifications'**
  String get kanbanHomeChannels;

  /// No description provided for @kanbanHomeChannelsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load home channels'**
  String get kanbanHomeChannelsFailed;

  /// No description provided for @kanbanHomeChannelsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No home channels are available'**
  String get kanbanHomeChannelsEmpty;

  /// No description provided for @kanbanUnsupportedAction.
  ///
  /// In en, this message translates to:
  /// **'This version does not support the {action} action'**
  String kanbanUnsupportedAction(Object action);

  /// No description provided for @chatSessionSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved transcript to {path}'**
  String chatSessionSaved(Object path);

  /// No description provided for @artifactSessionPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Start the session to view artifacts'**
  String get artifactSessionPendingTitle;

  /// No description provided for @artifactSessionPendingDescription.
  ///
  /// In en, this message translates to:
  /// **'Artifacts appear here after this conversation is saved.'**
  String get artifactSessionPendingDescription;

  /// No description provided for @artifactEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No artifacts yet'**
  String get artifactEmptyTitle;

  /// No description provided for @artifactEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Code, files, links, and images generated in this session appear here.'**
  String get artifactEmptyDescription;

  /// No description provided for @artifactFallbackLabel.
  ///
  /// In en, this message translates to:
  /// **'Artifact {id}'**
  String artifactFallbackLabel(Object id);

  /// No description provided for @artifactDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Artifact details'**
  String get artifactDetailTitle;

  /// No description provided for @artifactSessionMeta.
  ///
  /// In en, this message translates to:
  /// **'{kind} · Session {session}'**
  String artifactSessionMeta(Object kind, Object session);

  /// No description provided for @artifactMetadata.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get artifactMetadata;

  /// No description provided for @artifactSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as'**
  String get artifactSaveAs;

  /// No description provided for @artifactCopyContent.
  ///
  /// In en, this message translates to:
  /// **'Copy content'**
  String get artifactCopyContent;

  /// No description provided for @artifactExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export: {error}'**
  String artifactExportFailed(String error);

  /// No description provided for @artifactType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get artifactType;

  /// No description provided for @artifactSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get artifactSession;

  /// No description provided for @artifactSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Session title'**
  String get artifactSessionTitle;

  /// No description provided for @artifactMessageRow.
  ///
  /// In en, this message translates to:
  /// **'Message row'**
  String get artifactMessageRow;

  /// No description provided for @logsAllServers.
  ///
  /// In en, this message translates to:
  /// **'All servers'**
  String get logsAllServers;

  /// No description provided for @logsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading logs...'**
  String get logsLoading;

  /// No description provided for @webhookEnableFirst.
  ///
  /// In en, this message translates to:
  /// **'Enable the Webhook platform first'**
  String get webhookEnableFirst;

  /// No description provided for @webhookEnabledRestart.
  ///
  /// In en, this message translates to:
  /// **'Webhooks enabled. Restart the Hermes gateway to apply the change.'**
  String get webhookEnabledRestart;

  /// No description provided for @webhookEnabled.
  ///
  /// In en, this message translates to:
  /// **'Webhooks enabled'**
  String get webhookEnabled;

  /// No description provided for @webhookEnableFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not enable Webhooks: {error}'**
  String webhookEnableFailed(Object error);

  /// No description provided for @webhookLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading Webhooks...'**
  String get webhookLoading;

  /// No description provided for @webhookEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Webhooks'**
  String get webhookEmptyTitle;

  /// No description provided for @webhookEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create a Webhook for Hermes event delivery.'**
  String get webhookEmptyDescription;

  /// No description provided for @webhookPlatformDisabled.
  ///
  /// In en, this message translates to:
  /// **'Webhook platform is disabled · Tap to enable'**
  String get webhookPlatformDisabled;

  /// No description provided for @webhookConfigured.
  ///
  /// In en, this message translates to:
  /// **'Configured Webhooks'**
  String get webhookConfigured;

  /// No description provided for @webhookStopped.
  ///
  /// In en, this message translates to:
  /// **'Webhook disabled'**
  String get webhookStopped;

  /// No description provided for @webhookOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Webhook operation failed: {error}'**
  String webhookOperationFailed(Object error);

  /// No description provided for @webhookDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Webhook?'**
  String get webhookDeleteTitle;

  /// No description provided for @webhookDeletePrompt.
  ///
  /// In en, this message translates to:
  /// **'{name} will be deleted.'**
  String webhookDeletePrompt(Object name);

  /// No description provided for @webhookDeleted.
  ///
  /// In en, this message translates to:
  /// **'Webhook deleted'**
  String get webhookDeleted;

  /// No description provided for @webhookDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete Webhook: {error}'**
  String webhookDeleteFailed(Object error);

  /// No description provided for @webhookEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get webhookEnabledLabel;

  /// No description provided for @webhookDisabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get webhookDisabledLabel;

  /// No description provided for @webhookEvents.
  ///
  /// In en, this message translates to:
  /// **'Subscribed events'**
  String get webhookEvents;

  /// No description provided for @webhookDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get webhookDescription;

  /// No description provided for @webhookPrompt.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get webhookPrompt;

  /// No description provided for @webhookSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get webhookSkills;

  /// No description provided for @webhookDeliverTo.
  ///
  /// In en, this message translates to:
  /// **'Delivery target'**
  String get webhookDeliverTo;

  /// No description provided for @webhookEnableThis.
  ///
  /// In en, this message translates to:
  /// **'Enable this Webhook'**
  String get webhookEnableThis;

  /// No description provided for @webhookHotReloadDescription.
  ///
  /// In en, this message translates to:
  /// **'Changes are hot-reloaded by the Hermes gateway.'**
  String get webhookHotReloadDescription;

  /// No description provided for @webhookNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get webhookNameRequired;

  /// No description provided for @webhookCreated.
  ///
  /// In en, this message translates to:
  /// **'Webhook created'**
  String get webhookCreated;

  /// No description provided for @webhookSecretOnce.
  ///
  /// In en, this message translates to:
  /// **'The signing secret is shown in full only once. Store it now.'**
  String get webhookSecretOnce;

  /// No description provided for @webhookSecretSaved.
  ///
  /// In en, this message translates to:
  /// **'I stored it'**
  String get webhookSecretSaved;

  /// No description provided for @webhookSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save Webhook: {error}'**
  String webhookSaveFailed(Object error);

  /// No description provided for @webhookNew.
  ///
  /// In en, this message translates to:
  /// **'New Webhook'**
  String get webhookNew;

  /// No description provided for @webhookName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get webhookName;

  /// No description provided for @webhookDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get webhookDescriptionOptional;

  /// No description provided for @webhookEventsComma.
  ///
  /// In en, this message translates to:
  /// **'Subscribed events (comma-separated)'**
  String get webhookEventsComma;

  /// No description provided for @webhookPromptOptional.
  ///
  /// In en, this message translates to:
  /// **'Trigger prompt (optional)'**
  String get webhookPromptOptional;

  /// No description provided for @webhookSkillsComma.
  ///
  /// In en, this message translates to:
  /// **'Skills (comma-separated, optional)'**
  String get webhookSkillsComma;

  /// No description provided for @webhookDeliveryTarget.
  ///
  /// In en, this message translates to:
  /// **'Delivery target'**
  String get webhookDeliveryTarget;

  /// No description provided for @webhookLogOnly.
  ///
  /// In en, this message translates to:
  /// **'Log only'**
  String get webhookLogOnly;

  /// No description provided for @webhookSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get webhookSaving;

  /// No description provided for @commonPartialDataLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Some data could not be loaded: {details}'**
  String commonPartialDataLoadFailed(Object details);

  /// No description provided for @cronRunsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load run history: {error}'**
  String cronRunsLoadFailed(Object error);

  /// No description provided for @profilesOptionsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Some profile editor options could not be loaded: {details}'**
  String profilesOptionsLoadFailed(Object details);

  /// No description provided for @skillsBulkFailed.
  ///
  /// In en, this message translates to:
  /// **'{failed} of {total} skill updates failed.'**
  String skillsBulkFailed(Object failed, Object total);

  /// No description provided for @petCleanupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not clean up the generation task: {error}'**
  String petCleanupFailed(Object error);

  /// No description provided for @skillsTitle.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get skillsTitle;

  /// No description provided for @skillsMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Skill marketplace'**
  String get skillsMarketplace;

  /// No description provided for @skillsEnableAll.
  ///
  /// In en, this message translates to:
  /// **'Enable all'**
  String get skillsEnableAll;

  /// No description provided for @skillsDisableAll.
  ///
  /// In en, this message translates to:
  /// **'Disable all'**
  String get skillsDisableAll;

  /// No description provided for @skillsToggleFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update skill: {error}'**
  String skillsToggleFailed(Object error);

  /// No description provided for @skillsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search skills...'**
  String get skillsSearchHint;

  /// No description provided for @skillsEnabledCount.
  ///
  /// In en, this message translates to:
  /// **'Enabled {enabled}/{total}'**
  String skillsEnabledCount(Object enabled, Object total);

  /// No description provided for @skillsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading skills...'**
  String get skillsLoading;

  /// No description provided for @skillsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No skills'**
  String get skillsEmptyTitle;

  /// No description provided for @skillsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'This agent has no available skills.'**
  String get skillsEmptyDescription;

  /// No description provided for @skillsUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get skillsUncategorized;

  /// No description provided for @skillsNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching skills'**
  String get skillsNoMatches;

  /// No description provided for @skillsUsageCount.
  ///
  /// In en, this message translates to:
  /// **'Used {count} times'**
  String skillsUsageCount(Object count);

  /// No description provided for @skillsLearned.
  ///
  /// In en, this message translates to:
  /// **'Learned'**
  String get skillsLearned;

  /// No description provided for @skillsBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built in'**
  String get skillsBuiltIn;

  /// No description provided for @skillsProvenanceMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get skillsProvenanceMarketplace;

  /// No description provided for @skillsSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get skillsSaved;

  /// No description provided for @skillsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save skill: {error}'**
  String skillsSaveFailed(Object error);

  /// No description provided for @skillsArchiveQuestion.
  ///
  /// In en, this message translates to:
  /// **'Archive skill?'**
  String get skillsArchiveQuestion;

  /// No description provided for @skillsArchivePrompt.
  ///
  /// In en, this message translates to:
  /// **'Archive the learned skill \"{name}\"? You can undo this later.'**
  String skillsArchivePrompt(Object name);

  /// No description provided for @skillsArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get skillsArchive;

  /// No description provided for @skillsArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get skillsArchived;

  /// No description provided for @skillsArchiveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not archive skill: {error}'**
  String skillsArchiveFailed(Object error);

  /// No description provided for @skillsContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get skillsContent;

  /// No description provided for @skillsNoContent.
  ///
  /// In en, this message translates to:
  /// **'(No content)'**
  String get skillsNoContent;

  /// No description provided for @skillsCancelEdit.
  ///
  /// In en, this message translates to:
  /// **'Cancel editing'**
  String get skillsCancelEdit;

  /// No description provided for @skillsSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get skillsSaving;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @historyResumeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not resume session: {error}'**
  String historyResumeFailed(Object error);

  /// No description provided for @historyManageSessions.
  ///
  /// In en, this message translates to:
  /// **'Manage sessions'**
  String get historyManageSessions;

  /// No description provided for @historyHideArchived.
  ///
  /// In en, this message translates to:
  /// **'Hide archived'**
  String get historyHideArchived;

  /// No description provided for @historyShowArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived'**
  String get historyShowArchived;

  /// No description provided for @historySelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a session'**
  String get historySelectTitle;

  /// No description provided for @historySelectDescription.
  ///
  /// In en, this message translates to:
  /// **'Select a session on the left to view its summary and management actions.'**
  String get historySelectDescription;

  /// No description provided for @historyLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading session history...'**
  String get historyLoading;

  /// No description provided for @historySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search titles, content, or working directories'**
  String get historySearchHint;

  /// No description provided for @historyClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get historyClearSearch;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get historyEmpty;

  /// No description provided for @historyNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching sessions'**
  String get historyNoMatches;

  /// No description provided for @historyLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get historyLoadMore;

  /// No description provided for @historyLoadMoreCount.
  ///
  /// In en, this message translates to:
  /// **'Load more ({loaded}/{total})'**
  String historyLoadMoreCount(Object loaded, Object total);

  /// No description provided for @historyPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get historyPinned;

  /// No description provided for @historyToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get historyToday;

  /// No description provided for @historyYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get historyYesterday;

  /// No description provided for @historyThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get historyThisWeek;

  /// No description provided for @historyLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last week'**
  String get historyLastWeek;

  /// No description provided for @historyEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get historyEarlier;

  /// No description provided for @historyCollapseChildren.
  ///
  /// In en, this message translates to:
  /// **'Collapse child sessions'**
  String get historyCollapseChildren;

  /// No description provided for @historyExpandChildren.
  ///
  /// In en, this message translates to:
  /// **'Expand child sessions'**
  String get historyExpandChildren;

  /// No description provided for @historySessionActions.
  ///
  /// In en, this message translates to:
  /// **'Session actions'**
  String get historySessionActions;

  /// No description provided for @historyManageSession.
  ///
  /// In en, this message translates to:
  /// **'Manage session'**
  String get historyManageSession;

  /// No description provided for @historyUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled session'**
  String get historyUntitled;

  /// No description provided for @historyMessageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} messages'**
  String historyMessageCount(Object count);

  /// No description provided for @historyDeleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete session?'**
  String get historyDeleteQuestion;

  /// No description provided for @historyDeletePrompt.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be permanently deleted. This cannot be undone.'**
  String historyDeletePrompt(Object title);

  /// No description provided for @historyDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete session: {error}'**
  String historyDeleteFailed(Object error);

  /// No description provided for @historyRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not rename session: {error}'**
  String historyRenameFailed(Object error);

  /// No description provided for @historyCompressed.
  ///
  /// In en, this message translates to:
  /// **'Session compressed ({count} messages removed)'**
  String historyCompressed(Object count);

  /// No description provided for @historyCompressFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not compress session: {error}'**
  String historyCompressFailed(Object error);

  /// No description provided for @historyArchiveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not archive session: {error}'**
  String historyArchiveFailed(Object error);

  /// No description provided for @historyUnarchiveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not unarchive session: {error}'**
  String historyUnarchiveFailed(Object error);

  /// No description provided for @historyManagement.
  ///
  /// In en, this message translates to:
  /// **'Session management'**
  String get historyManagement;

  /// No description provided for @historySaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save title'**
  String get historySaveTitle;

  /// No description provided for @historyContextUsage.
  ///
  /// In en, this message translates to:
  /// **'Context usage: {used} / {maximum}{percent}'**
  String historyContextUsage(Object maximum, Object percent, Object used);

  /// No description provided for @historyPercent.
  ///
  /// In en, this message translates to:
  /// **' ({percent}%)'**
  String historyPercent(Object percent);

  /// No description provided for @historyCompress.
  ///
  /// In en, this message translates to:
  /// **'Compress session'**
  String get historyCompress;

  /// No description provided for @historyArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get historyArchive;

  /// No description provided for @historyUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get historyUnarchive;

  /// No description provided for @cronTitle.
  ///
  /// In en, this message translates to:
  /// **'Scheduled tasks'**
  String get cronTitle;

  /// No description provided for @cronLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading scheduled tasks...'**
  String get cronLoading;

  /// No description provided for @cronEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No scheduled tasks yet'**
  String get cronEmptyTitle;

  /// No description provided for @cronEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Create an automated task that runs on a schedule.'**
  String get cronEmptyDescription;

  /// No description provided for @cronNew.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get cronNew;

  /// No description provided for @cronNextRun.
  ///
  /// In en, this message translates to:
  /// **'Next run: {time}'**
  String cronNextRun(Object time);

  /// No description provided for @cronRunHistory.
  ///
  /// In en, this message translates to:
  /// **'Run history'**
  String get cronRunHistory;

  /// No description provided for @cronRunHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Run history · {name}'**
  String cronRunHistoryTitle(Object name);

  /// No description provided for @cronNoRuns.
  ///
  /// In en, this message translates to:
  /// **'No run history'**
  String get cronNoRuns;

  /// No description provided for @cronTriggerNow.
  ///
  /// In en, this message translates to:
  /// **'Run now'**
  String get cronTriggerNow;

  /// No description provided for @cronTriggered.
  ///
  /// In en, this message translates to:
  /// **'Task triggered'**
  String get cronTriggered;

  /// No description provided for @cronTriggerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not trigger task: {error}'**
  String cronTriggerFailed(Object error);

  /// No description provided for @cronUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update task: {error}'**
  String cronUpdateFailed(Object error);

  /// No description provided for @cronDeleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete scheduled task?'**
  String get cronDeleteQuestion;

  /// No description provided for @cronDeletePrompt.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be deleted.'**
  String cronDeletePrompt(Object name);

  /// No description provided for @cronDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete task: {error}'**
  String cronDeleteFailed(Object error);

  /// No description provided for @cronStateCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get cronStateCompleted;

  /// No description provided for @cronStateDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get cronStateDisabled;

  /// No description provided for @cronStateEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get cronStateEnabled;

  /// No description provided for @cronStateError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get cronStateError;

  /// No description provided for @cronStatePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get cronStatePaused;

  /// No description provided for @cronStateRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get cronStateRunning;

  /// No description provided for @cronStateScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get cronStateScheduled;

  /// No description provided for @cronModelsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load model options: {error}'**
  String cronModelsLoadFailed(Object error);

  /// No description provided for @cronBlueprintsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load automation templates: {error}'**
  String cronBlueprintsLoadFailed(Object error);

  /// No description provided for @cronTargetsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load delivery targets: {error}'**
  String cronTargetsLoadFailed(Object error);

  /// No description provided for @cronPresetMinute.
  ///
  /// In en, this message translates to:
  /// **'Every minute'**
  String get cronPresetMinute;

  /// No description provided for @cronPresetHour.
  ///
  /// In en, this message translates to:
  /// **'Hourly'**
  String get cronPresetHour;

  /// No description provided for @cronPresetDay.
  ///
  /// In en, this message translates to:
  /// **'Daily at 09:00'**
  String get cronPresetDay;

  /// No description provided for @cronPresetWeek.
  ///
  /// In en, this message translates to:
  /// **'Mondays at 09:00'**
  String get cronPresetWeek;

  /// No description provided for @cronPresetMonth.
  ///
  /// In en, this message translates to:
  /// **'Monthly on day 1 at 09:00'**
  String get cronPresetMonth;

  /// No description provided for @cronPresetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get cronPresetCustom;

  /// No description provided for @cronPresetMinuteHint.
  ///
  /// In en, this message translates to:
  /// **'Runs every minute'**
  String get cronPresetMinuteHint;

  /// No description provided for @cronPresetHourHint.
  ///
  /// In en, this message translates to:
  /// **'Runs at the start of every hour'**
  String get cronPresetHourHint;

  /// No description provided for @cronPresetDayHint.
  ///
  /// In en, this message translates to:
  /// **'Runs every day at 09:00'**
  String get cronPresetDayHint;

  /// No description provided for @cronPresetWeekHint.
  ///
  /// In en, this message translates to:
  /// **'Runs every Monday at 09:00'**
  String get cronPresetWeekHint;

  /// No description provided for @cronPresetMonthHint.
  ///
  /// In en, this message translates to:
  /// **'Runs on day 1 of every month at 09:00'**
  String get cronPresetMonthHint;

  /// No description provided for @cronPromptAndExpressionRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter task instructions and a Cron expression.'**
  String get cronPromptAndExpressionRequired;

  /// No description provided for @cronExpressionRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a Cron expression.'**
  String get cronExpressionRequired;

  /// No description provided for @cronPromptRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter task instructions.'**
  String get cronPromptRequired;

  /// No description provided for @cronSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save task: {error}'**
  String cronSaveFailed(Object error);

  /// No description provided for @cronCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New scheduled task'**
  String get cronCreateTitle;

  /// No description provided for @cronEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit scheduled task'**
  String get cronEditTitle;

  /// No description provided for @cronStartFromTemplate.
  ///
  /// In en, this message translates to:
  /// **'Start from a template'**
  String get cronStartFromTemplate;

  /// No description provided for @cronScheduling.
  ///
  /// In en, this message translates to:
  /// **'Scheduling...'**
  String get cronScheduling;

  /// No description provided for @cronScheduleAutomation.
  ///
  /// In en, this message translates to:
  /// **'Schedule automation'**
  String get cronScheduleAutomation;

  /// No description provided for @cronScriptOnlyDescription.
  ///
  /// In en, this message translates to:
  /// **'This is a script-only task. You can change its name, schedule, delivery targets, and the script itself; model settings don\'t apply.'**
  String get cronScriptOnlyDescription;

  /// No description provided for @cronScriptLabel.
  ///
  /// In en, this message translates to:
  /// **'Script'**
  String get cronScriptLabel;

  /// No description provided for @cronLastRun.
  ///
  /// In en, this message translates to:
  /// **'Last run: {time}'**
  String cronLastRun(Object time);

  /// No description provided for @cronRunScheduledAt.
  ///
  /// In en, this message translates to:
  /// **'Scheduled at'**
  String get cronRunScheduledAt;

  /// No description provided for @cronRunStartedAt.
  ///
  /// In en, this message translates to:
  /// **'Started at'**
  String get cronRunStartedAt;

  /// No description provided for @cronRunFinishedAt.
  ///
  /// In en, this message translates to:
  /// **'Finished at'**
  String get cronRunFinishedAt;

  /// No description provided for @cronRunStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get cronRunStatus;

  /// No description provided for @cronRunOutput.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get cronRunOutput;

  /// No description provided for @cronRunDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Run succeeded'**
  String get cronRunDetailTitle;

  /// No description provided for @cronRunDetailFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Run failed'**
  String get cronRunDetailFailedTitle;

  /// No description provided for @cronNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get cronNameOptional;

  /// No description provided for @cronDeliverResultsTo.
  ///
  /// In en, this message translates to:
  /// **'Deliver results to'**
  String get cronDeliverResultsTo;

  /// No description provided for @cronTaskModel.
  ///
  /// In en, this message translates to:
  /// **'Task model'**
  String get cronTaskModel;

  /// No description provided for @cronUseGlobalDefault.
  ///
  /// In en, this message translates to:
  /// **'Use global default'**
  String get cronUseGlobalDefault;

  /// No description provided for @cronSavedModel.
  ///
  /// In en, this message translates to:
  /// **'{model} (currently saved)'**
  String cronSavedModel(Object model);

  /// No description provided for @cronPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'Task instructions (prompt)'**
  String get cronPromptLabel;

  /// No description provided for @cronFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get cronFrequency;

  /// No description provided for @cronExpression.
  ///
  /// In en, this message translates to:
  /// **'Cron expression'**
  String get cronExpression;

  /// No description provided for @cronExpressionHint.
  ///
  /// In en, this message translates to:
  /// **'minute hour day month weekday'**
  String get cronExpressionHint;

  /// No description provided for @cronSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get cronSaving;

  /// No description provided for @cronThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get cronThisDevice;

  /// No description provided for @cronConfigureHomeChannelFirst.
  ///
  /// In en, this message translates to:
  /// **'Configure a home channel first'**
  String get cronConfigureHomeChannelFirst;

  /// No description provided for @profilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent Profiles'**
  String get profilesTitle;

  /// No description provided for @profilesLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading profiles...'**
  String get profilesLoading;

  /// No description provided for @profilesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No profiles'**
  String get profilesEmptyTitle;

  /// No description provided for @profilesEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Create your first agent profile.'**
  String get profilesEmptyDescription;

  /// No description provided for @profilesNew.
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get profilesNew;

  /// No description provided for @profilesImport.
  ///
  /// In en, this message translates to:
  /// **'Import profile'**
  String get profilesImport;

  /// No description provided for @profilesExport.
  ///
  /// In en, this message translates to:
  /// **'Export profile'**
  String get profilesExport;

  /// No description provided for @profilesDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate profile'**
  String get profilesDuplicate;

  /// No description provided for @profilesEditSoul.
  ///
  /// In en, this message translates to:
  /// **'Edit SOUL.md'**
  String get profilesEditSoul;

  /// No description provided for @profilesSetupCommand.
  ///
  /// In en, this message translates to:
  /// **'Terminal launch command'**
  String get profilesSetupCommand;

  /// No description provided for @profilesSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save profile: {error}'**
  String profilesSaveFailed(Object error);

  /// No description provided for @profilesCreated.
  ///
  /// In en, this message translates to:
  /// **'Profile created'**
  String get profilesCreated;

  /// No description provided for @profilesSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profilesSaved;

  /// No description provided for @profilesCopyName.
  ///
  /// In en, this message translates to:
  /// **'{name} copy'**
  String profilesCopyName(Object name);

  /// No description provided for @profilesDuplicateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not duplicate profile: {error}'**
  String profilesDuplicateFailed(Object error);

  /// No description provided for @profilesDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Profile duplicated'**
  String get profilesDuplicated;

  /// No description provided for @profilesDeleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete profile \"{name}\"?'**
  String profilesDeleteQuestion(Object name);

  /// No description provided for @profilesDeleteActiveWarning.
  ///
  /// In en, this message translates to:
  /// **'This profile is currently active.'**
  String get profilesDeleteActiveWarning;

  /// No description provided for @profilesDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get profilesDeleteWarning;

  /// No description provided for @profilesDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete profile: {error}'**
  String profilesDeleteFailed(Object error);

  /// No description provided for @profilesDeleted.
  ///
  /// In en, this message translates to:
  /// **'Profile deleted'**
  String get profilesDeleted;

  /// No description provided for @profilesSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not switch profile: {error}'**
  String profilesSwitchFailed(Object error);

  /// No description provided for @profilesSwitchedTo.
  ///
  /// In en, this message translates to:
  /// **'Switched to \"{name}\"'**
  String profilesSwitchedTo(Object name);

  /// No description provided for @profilesSoulHint.
  ///
  /// In en, this message translates to:
  /// **'Describe this agent\'s identity, behavior, and communication style'**
  String get profilesSoulHint;

  /// No description provided for @profilesSoulSaved.
  ///
  /// In en, this message translates to:
  /// **'SOUL.md saved'**
  String get profilesSoulSaved;

  /// No description provided for @profilesSoulFailed.
  ///
  /// In en, this message translates to:
  /// **'SOUL.md operation failed: {error}'**
  String profilesSoulFailed(Object error);

  /// No description provided for @profilesCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get profilesCopy;

  /// No description provided for @profilesSetupCommandFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read launch command: {error}'**
  String profilesSetupCommandFailed(Object error);

  /// No description provided for @profilesExported.
  ///
  /// In en, this message translates to:
  /// **'Profile exported'**
  String get profilesExported;

  /// No description provided for @profilesExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export profile: {error}'**
  String profilesExportFailed(Object error);

  /// No description provided for @profilesImported.
  ///
  /// In en, this message translates to:
  /// **'Imported {name}'**
  String profilesImported(Object name);

  /// No description provided for @profilesImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import profile: {error}'**
  String profilesImportFailed(Object error);

  /// No description provided for @profilesParameters.
  ///
  /// In en, this message translates to:
  /// **'temp {temperature} · max_tokens {maxTokens}{activeSuffix}'**
  String profilesParameters(
    Object activeSuffix,
    Object maxTokens,
    Object temperature,
  );

  /// No description provided for @profilesCurrentSuffix.
  ///
  /// In en, this message translates to:
  /// **' · active'**
  String get profilesCurrentSuffix;

  /// No description provided for @profilesActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get profilesActive;

  /// No description provided for @profilesActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get profilesActivate;

  /// No description provided for @profilesNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a profile name.'**
  String get profilesNameRequired;

  /// No description provided for @profilesCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get profilesCreateTitle;

  /// No description provided for @profilesEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profilesEditTitle;

  /// No description provided for @profilesProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get profilesProvider;

  /// No description provided for @profilesModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get profilesModel;

  /// No description provided for @profilesSystemPrompt.
  ///
  /// In en, this message translates to:
  /// **'System prompt'**
  String get profilesSystemPrompt;

  /// No description provided for @profilesDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get profilesDescriptionOptional;

  /// No description provided for @profilesTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get profilesTools;

  /// No description provided for @profilesDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get profilesDeselectAll;

  /// No description provided for @profilesSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get profilesSelectAll;

  /// No description provided for @profilesSetActive.
  ///
  /// In en, this message translates to:
  /// **'Set as active profile'**
  String get profilesSetActive;

  /// No description provided for @memoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get memoryTitle;

  /// No description provided for @memoryLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading memory status...'**
  String get memoryLoading;

  /// No description provided for @memorySwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not switch provider: {error}'**
  String memorySwitchFailed(Object error);

  /// No description provided for @memoryResetScope.
  ///
  /// In en, this message translates to:
  /// **'Choose what to reset'**
  String get memoryResetScope;

  /// No description provided for @memoryResetScopeDescription.
  ///
  /// In en, this message translates to:
  /// **'Only the selected memory files will be deleted.'**
  String get memoryResetScopeDescription;

  /// No description provided for @memoryAll.
  ///
  /// In en, this message translates to:
  /// **'All memory'**
  String get memoryAll;

  /// No description provided for @memoryAllFiles.
  ///
  /// In en, this message translates to:
  /// **'MEMORY.md and USER.md'**
  String get memoryAllFiles;

  /// No description provided for @memoryLongTerm.
  ///
  /// In en, this message translates to:
  /// **'Long-term memory'**
  String get memoryLongTerm;

  /// No description provided for @memoryLongTermFile.
  ///
  /// In en, this message translates to:
  /// **'MEMORY.md only'**
  String get memoryLongTermFile;

  /// No description provided for @memoryUser.
  ///
  /// In en, this message translates to:
  /// **'User memory'**
  String get memoryUser;

  /// No description provided for @memoryUserFile.
  ///
  /// In en, this message translates to:
  /// **'USER.md only'**
  String get memoryUserFile;

  /// No description provided for @memoryResetQuestion.
  ///
  /// In en, this message translates to:
  /// **'Reset memory?'**
  String get memoryResetQuestion;

  /// No description provided for @memoryResetWarning.
  ///
  /// In en, this message translates to:
  /// **'Deleted memory cannot be recovered.'**
  String get memoryResetWarning;

  /// No description provided for @memoryNothingDeleted.
  ///
  /// In en, this message translates to:
  /// **'There were no memory files to delete.'**
  String get memoryNothingDeleted;

  /// No description provided for @memoryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted {files}'**
  String memoryDeleted(Object files);

  /// No description provided for @memoryResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reset memory: {error}'**
  String memoryResetFailed(Object error);

  /// No description provided for @memoryCuratorUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update Curator: {error}'**
  String memoryCuratorUpdateFailed(Object error);

  /// No description provided for @memoryCuratorStarted.
  ///
  /// In en, this message translates to:
  /// **'Curator started'**
  String get memoryCuratorStarted;

  /// No description provided for @memoryCuratorRunFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not run Curator: {error}'**
  String memoryCuratorRunFailed(Object error);

  /// No description provided for @memoryCurrentProvider.
  ///
  /// In en, this message translates to:
  /// **'Current memory provider'**
  String get memoryCurrentProvider;

  /// No description provided for @memoryDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get memoryDisabled;

  /// No description provided for @memoryEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get memoryEnabled;

  /// No description provided for @memoryProviders.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get memoryProviders;

  /// No description provided for @memoryNoProviders.
  ///
  /// In en, this message translates to:
  /// **'No providers available'**
  String get memoryNoProviders;

  /// No description provided for @memoryBuiltInFiles.
  ///
  /// In en, this message translates to:
  /// **'Built-in memory files'**
  String get memoryBuiltInFiles;

  /// No description provided for @memoryReset.
  ///
  /// In en, this message translates to:
  /// **'Reset memory'**
  String get memoryReset;

  /// No description provided for @memoryInUse.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get memoryInUse;

  /// No description provided for @memoryConfigured.
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get memoryConfigured;

  /// No description provided for @memoryConfigureProvider.
  ///
  /// In en, this message translates to:
  /// **'Configure {name}'**
  String memoryConfigureProvider(Object name);

  /// No description provided for @memoryEnableProvider.
  ///
  /// In en, this message translates to:
  /// **'Enable {name}'**
  String memoryEnableProvider(Object name);

  /// No description provided for @memoryCuratorLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading Curator status...'**
  String get memoryCuratorLoading;

  /// No description provided for @memoryCuratorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Curator unavailable'**
  String get memoryCuratorUnavailable;

  /// No description provided for @memoryPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get memoryPaused;

  /// No description provided for @memoryCuratorInterval.
  ///
  /// In en, this message translates to:
  /// **'Checks every {hours} hours'**
  String memoryCuratorInterval(Object hours);

  /// No description provided for @memoryCuratorLastRun.
  ///
  /// In en, this message translates to:
  /// **'Last run {time}'**
  String memoryCuratorLastRun(Object time);

  /// No description provided for @memoryResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get memoryResume;

  /// No description provided for @memoryPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get memoryPause;

  /// No description provided for @memoryRunNow.
  ///
  /// In en, this message translates to:
  /// **'Run now'**
  String get memoryRunNow;

  /// No description provided for @memoryInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'{field} is not valid JSON'**
  String memoryInvalidJson(Object field);

  /// No description provided for @memoryProviderSaved.
  ///
  /// In en, this message translates to:
  /// **'Provider configuration saved'**
  String get memoryProviderSaved;

  /// No description provided for @memoryProviderSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save provider configuration: {error}'**
  String memoryProviderSaveFailed(Object error);

  /// No description provided for @memoryOAuthTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out. Try again.'**
  String get memoryOAuthTimeout;

  /// No description provided for @memoryCurrentProfile.
  ///
  /// In en, this message translates to:
  /// **'Current profile'**
  String get memoryCurrentProfile;

  /// No description provided for @memoryProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile: {name}'**
  String memoryProfile(Object name);

  /// No description provided for @memoryProviderConfigLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading provider configuration...'**
  String get memoryProviderConfigLoading;

  /// No description provided for @memoryNoProviderConfig.
  ///
  /// In en, this message translates to:
  /// **'This provider has no additional settings'**
  String get memoryNoProviderConfig;

  /// No description provided for @memoryViewProviderDocs.
  ///
  /// In en, this message translates to:
  /// **'View provider documentation'**
  String get memoryViewProviderDocs;

  /// No description provided for @memorySaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get memorySaving;

  /// No description provided for @memorySaveConfig.
  ///
  /// In en, this message translates to:
  /// **'Save configuration'**
  String get memorySaveConfig;

  /// No description provided for @memoryAccountConnected.
  ///
  /// In en, this message translates to:
  /// **'Account connected'**
  String get memoryAccountConnected;

  /// No description provided for @memoryConnectAccount.
  ///
  /// In en, this message translates to:
  /// **'Connect provider account'**
  String get memoryConnectAccount;

  /// No description provided for @memoryReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get memoryReconnect;

  /// No description provided for @memoryConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get memoryConnect;

  /// No description provided for @memoryKeepSecretHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to keep the current value'**
  String get memoryKeepSecretHint;

  /// No description provided for @agentOpenBotFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open Bot Chat: {error}'**
  String agentOpenBotFailed(Object error);

  /// No description provided for @agentNewGroup.
  ///
  /// In en, this message translates to:
  /// **'New group chat'**
  String get agentNewGroup;

  /// No description provided for @agentEditGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit group chat'**
  String get agentEditGroup;

  /// No description provided for @agentGroupName.
  ///
  /// In en, this message translates to:
  /// **'Group chat name'**
  String get agentGroupName;

  /// No description provided for @agentGroupSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save group chat: {error}'**
  String agentGroupSaveFailed(Object error);

  /// No description provided for @agentBotThinking.
  ///
  /// In en, this message translates to:
  /// **'{name} is thinking'**
  String agentBotThinking(Object name);

  /// No description provided for @agentBotPaused.
  ///
  /// In en, this message translates to:
  /// **'{name} paused'**
  String agentBotPaused(Object name);

  /// No description provided for @agentStartGroupChat.
  ///
  /// In en, this message translates to:
  /// **'Start the group chat'**
  String get agentStartGroupChat;

  /// No description provided for @agentReplyTo.
  ///
  /// In en, this message translates to:
  /// **'Reply to #{id}'**
  String agentReplyTo(Object id);

  /// No description provided for @agentSendToRoom.
  ///
  /// In en, this message translates to:
  /// **'Send to room'**
  String get agentSendToRoom;

  /// No description provided for @agentMentionHint.
  ///
  /// In en, this message translates to:
  /// **'Use @name to target a member or @all to notify everyone'**
  String get agentMentionHint;

  /// No description provided for @agentAttachmentTooLarge.
  ///
  /// In en, this message translates to:
  /// **'{name} exceeds 20 MB'**
  String agentAttachmentTooLarge(Object name);

  /// No description provided for @agentAttachFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add attachment: {error}'**
  String agentAttachFailed(Object error);

  /// No description provided for @agentGroupSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send group message: {error}'**
  String agentGroupSendFailed(Object error);

  /// No description provided for @agentAppendMessage.
  ///
  /// In en, this message translates to:
  /// **'Add message'**
  String get agentAppendMessage;

  /// No description provided for @agentAwaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'Awaiting approval'**
  String get agentAwaitingApproval;

  /// No description provided for @agentNeedsInformation.
  ///
  /// In en, this message translates to:
  /// **'More information needed'**
  String get agentNeedsInformation;

  /// No description provided for @agentRespond.
  ///
  /// In en, this message translates to:
  /// **'Respond'**
  String get agentRespond;

  /// No description provided for @agentMemberRequest.
  ///
  /// In en, this message translates to:
  /// **'Request from {name}'**
  String agentMemberRequest(Object name);

  /// No description provided for @agentAllowOperationQuestion.
  ///
  /// In en, this message translates to:
  /// **'Allow this operation?'**
  String get agentAllowOperationQuestion;

  /// No description provided for @agentDeny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get agentDeny;

  /// No description provided for @agentAlwaysAllow.
  ///
  /// In en, this message translates to:
  /// **'Always allow'**
  String get agentAlwaysAllow;

  /// No description provided for @agentAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get agentAllow;

  /// No description provided for @agentCustomAnswer.
  ///
  /// In en, this message translates to:
  /// **'Custom answer'**
  String get agentCustomAnswer;

  /// No description provided for @agentEnterAnswer.
  ///
  /// In en, this message translates to:
  /// **'Enter an answer'**
  String get agentEnterAnswer;

  /// No description provided for @agentRespondFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not respond: {error}'**
  String agentRespondFailed(Object error);

  /// No description provided for @agentLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading agent status...'**
  String get agentLoading;

  /// No description provided for @agentNoData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get agentNoData;

  /// No description provided for @agentManageBots.
  ///
  /// In en, this message translates to:
  /// **'Manage or create Bots'**
  String get agentManageBots;

  /// No description provided for @agentBotRoutinesMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Bot routines'**
  String get agentBotRoutinesMenuItem;

  /// No description provided for @agentBotsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No bots yet'**
  String get agentBotsEmptyTitle;

  /// No description provided for @agentBotsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'A bot is a standalone chat identity tied to a profile. Create a profile from the top-right icon to get started.'**
  String get agentBotsEmptyDescription;

  /// No description provided for @agentMentionAll.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get agentMentionAll;

  /// No description provided for @agentRefreshRoster.
  ///
  /// In en, this message translates to:
  /// **'Refresh Bot roster'**
  String get agentRefreshRoster;

  /// No description provided for @agentGroupSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} Bots · across connections{runningSuffix}'**
  String agentGroupSummary(Object count, Object runningSuffix);

  /// No description provided for @agentRunningSuffix.
  ///
  /// In en, this message translates to:
  /// **' · running'**
  String get agentRunningSuffix;

  /// No description provided for @agentDeleteGroupQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete group chat \"{name}\"?'**
  String agentDeleteGroupQuestion(Object name);

  /// No description provided for @agentDeleteGroupWarning.
  ///
  /// In en, this message translates to:
  /// **'The group history will be permanently deleted. This cannot be undone.'**
  String get agentDeleteGroupWarning;

  /// No description provided for @agentDeleteGroupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete group chat: {error}'**
  String agentDeleteGroupFailed(Object error);

  /// No description provided for @agentDeleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete group chat'**
  String get agentDeleteGroup;

  /// No description provided for @agentDeleteBotQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete Bot \"{name}\"?'**
  String agentDeleteBotQuestion(Object name);

  /// No description provided for @agentBotOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Bot operation failed: {error}'**
  String agentBotOperationFailed(Object error);

  /// No description provided for @agentDuplicateBot.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Bot'**
  String get agentDuplicateBot;

  /// No description provided for @agentDeleteBot.
  ///
  /// In en, this message translates to:
  /// **'Delete Bot'**
  String get agentDeleteBot;

  /// No description provided for @agentGateway.
  ///
  /// In en, this message translates to:
  /// **'Gateway'**
  String get agentGateway;

  /// No description provided for @agentActiveAgents.
  ///
  /// In en, this message translates to:
  /// **'Active agents'**
  String get agentActiveAgents;

  /// No description provided for @agentBusy.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get agentBusy;

  /// No description provided for @agentYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get agentYes;

  /// No description provided for @agentNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get agentNo;

  /// No description provided for @agentModelSection.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get agentModelSection;

  /// No description provided for @agentCurrentModel.
  ///
  /// In en, this message translates to:
  /// **'Current model'**
  String get agentCurrentModel;

  /// No description provided for @agentProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get agentProvider;

  /// No description provided for @agentContextLength.
  ///
  /// In en, this message translates to:
  /// **'Context length'**
  String get agentContextLength;

  /// No description provided for @agentSessionModel.
  ///
  /// In en, this message translates to:
  /// **'Session model'**
  String get agentSessionModel;

  /// No description provided for @agentRuntimeSection.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get agentRuntimeSection;

  /// No description provided for @agentType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get agentType;

  /// No description provided for @agentSourceRoot.
  ///
  /// In en, this message translates to:
  /// **'Source root'**
  String get agentSourceRoot;

  /// No description provided for @agentHermesHome.
  ///
  /// In en, this message translates to:
  /// **'Hermes home'**
  String get agentHermesHome;

  /// No description provided for @agentServerVersion.
  ///
  /// In en, this message translates to:
  /// **'Server version'**
  String get agentServerVersion;

  /// No description provided for @agentCapability.
  ///
  /// In en, this message translates to:
  /// **'Capability'**
  String get agentCapability;

  /// No description provided for @agentRestarting.
  ///
  /// In en, this message translates to:
  /// **'Restarting...'**
  String get agentRestarting;

  /// No description provided for @botRoutineUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update routine: {error}'**
  String botRoutineUpdateFailed(Object error);

  /// No description provided for @botRoutineDeleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete routine?'**
  String get botRoutineDeleteQuestion;

  /// No description provided for @botRoutineDeletePrompt.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" and its schedule will be permanently deleted.'**
  String botRoutineDeletePrompt(Object title);

  /// No description provided for @botRoutineStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get botRoutineStatus;

  /// No description provided for @botRoutinePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get botRoutinePaused;

  /// No description provided for @botRoutineSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get botRoutineSchedule;

  /// No description provided for @botRoutineRawSchedule.
  ///
  /// In en, this message translates to:
  /// **'Raw schedule'**
  String get botRoutineRawSchedule;

  /// No description provided for @botRoutineRepeatCount.
  ///
  /// In en, this message translates to:
  /// **'Repeat count'**
  String get botRoutineRepeatCount;

  /// No description provided for @botRoutineNextRun.
  ///
  /// In en, this message translates to:
  /// **'Next run'**
  String get botRoutineNextRun;

  /// No description provided for @botRoutineLastRun.
  ///
  /// In en, this message translates to:
  /// **'Last run'**
  String get botRoutineLastRun;

  /// No description provided for @botRoutineLastResult.
  ///
  /// In en, this message translates to:
  /// **'Last result'**
  String get botRoutineLastResult;

  /// No description provided for @botRoutineDeliverTo.
  ///
  /// In en, this message translates to:
  /// **'Deliver to'**
  String get botRoutineDeliverTo;

  /// No description provided for @botRoutineModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get botRoutineModel;

  /// No description provided for @botRoutineWorkdir.
  ///
  /// In en, this message translates to:
  /// **'Working directory'**
  String get botRoutineWorkdir;

  /// No description provided for @botRoutineInstruction.
  ///
  /// In en, this message translates to:
  /// **'Instruction'**
  String get botRoutineInstruction;

  /// No description provided for @botRoutineLegacyWarning.
  ///
  /// In en, this message translates to:
  /// **'This legacy task was paused for safety. Delete it and create it again before running it.'**
  String get botRoutineLegacyWarning;

  /// No description provided for @botRoutineTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} · Routines'**
  String botRoutineTitle(Object name);

  /// No description provided for @commonBytes.
  ///
  /// In en, this message translates to:
  /// **'{count} bytes'**
  String commonBytes(Object count);

  /// No description provided for @botRoutineLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading routines...'**
  String get botRoutineLoading;

  /// No description provided for @botRoutineEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No routines yet'**
  String get botRoutineEmptyTitle;

  /// No description provided for @botRoutineEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a dedicated scheduled task for {name}.'**
  String botRoutineEmptyDescription(Object name);

  /// No description provided for @botRoutineNew.
  ///
  /// In en, this message translates to:
  /// **'New routine'**
  String get botRoutineNew;

  /// No description provided for @botRoutineNext.
  ///
  /// In en, this message translates to:
  /// **'Next {time}'**
  String botRoutineNext(Object time);

  /// No description provided for @botRoutineLegacyPaused.
  ///
  /// In en, this message translates to:
  /// **'Legacy task, paused safely'**
  String get botRoutineLegacyPaused;

  /// No description provided for @botRoutineDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete routine'**
  String get botRoutineDelete;

  /// No description provided for @botRoutineScheduleOnce.
  ///
  /// In en, this message translates to:
  /// **'Once · in {duration}'**
  String botRoutineScheduleOnce(Object duration);

  /// No description provided for @botRoutineScheduleEvery.
  ///
  /// In en, this message translates to:
  /// **'Every {duration}'**
  String botRoutineScheduleEvery(Object duration);

  /// No description provided for @botRoutineScheduleHourly.
  ///
  /// In en, this message translates to:
  /// **'At the start of every hour'**
  String get botRoutineScheduleHourly;

  /// No description provided for @botRoutineScheduleDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily at 09:00'**
  String get botRoutineScheduleDaily;

  /// No description provided for @botRoutineScheduleWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays at 09:00'**
  String get botRoutineScheduleWeekdays;

  /// No description provided for @botRoutineScheduleWeekly.
  ///
  /// In en, this message translates to:
  /// **'Mondays at 09:00'**
  String get botRoutineScheduleWeekly;

  /// No description provided for @botRoutineScheduleMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly on day 1 at 09:00'**
  String get botRoutineScheduleMonthly;

  /// No description provided for @botRoutineRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Enter a name, instruction, and schedule.'**
  String get botRoutineRequiredFields;

  /// No description provided for @botRoutineCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New routine · {name}'**
  String botRoutineCreateTitle(Object name);

  /// No description provided for @botRoutineInstructionLabel.
  ///
  /// In en, this message translates to:
  /// **'Instruction to run each time'**
  String get botRoutineInstructionLabel;

  /// No description provided for @botRoutineFrequencyOnce.
  ///
  /// In en, this message translates to:
  /// **'Once, after a delay'**
  String get botRoutineFrequencyOnce;

  /// No description provided for @botRoutineFrequencyHourly.
  ///
  /// In en, this message translates to:
  /// **'Hourly'**
  String get botRoutineFrequencyHourly;

  /// No description provided for @botRoutineFrequencyDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get botRoutineFrequencyDaily;

  /// No description provided for @botRoutineFrequencyWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get botRoutineFrequencyWeekdays;

  /// No description provided for @botRoutineFrequencyWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get botRoutineFrequencyWeekly;

  /// No description provided for @botRoutineFrequencyMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get botRoutineFrequencyMonthly;

  /// No description provided for @botRoutineFrequencyInterval.
  ///
  /// In en, this message translates to:
  /// **'Fixed interval'**
  String get botRoutineFrequencyInterval;

  /// No description provided for @botRoutineFrequencyAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced expression'**
  String get botRoutineFrequencyAdvanced;

  /// No description provided for @botRoutineTime.
  ///
  /// In en, this message translates to:
  /// **'Time (HH:mm)'**
  String get botRoutineTime;

  /// No description provided for @botRoutineWeekday.
  ///
  /// In en, this message translates to:
  /// **'Weekday'**
  String get botRoutineWeekday;

  /// No description provided for @botRoutineMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get botRoutineMonday;

  /// No description provided for @botRoutineTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get botRoutineTuesday;

  /// No description provided for @botRoutineWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get botRoutineWednesday;

  /// No description provided for @botRoutineThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get botRoutineThursday;

  /// No description provided for @botRoutineFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get botRoutineFriday;

  /// No description provided for @botRoutineSaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get botRoutineSaturday;

  /// No description provided for @botRoutineSunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get botRoutineSunday;

  /// No description provided for @botRoutineDayOfMonth.
  ///
  /// In en, this message translates to:
  /// **'Day of month'**
  String get botRoutineDayOfMonth;

  /// No description provided for @botRoutineValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get botRoutineValue;

  /// No description provided for @botRoutineUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get botRoutineUnit;

  /// No description provided for @botRoutineMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get botRoutineMinutes;

  /// No description provided for @botRoutineHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get botRoutineHours;

  /// No description provided for @botRoutineDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get botRoutineDays;

  /// No description provided for @botRoutineAdvancedExpression.
  ///
  /// In en, this message translates to:
  /// **'Cron or every Nm/Nh/Nd'**
  String get botRoutineAdvancedExpression;

  /// No description provided for @botRoutineWillSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Will be saved as: {schedule}'**
  String botRoutineWillSaveAs(Object schedule);

  /// No description provided for @botRoutineRepeatLimit.
  ///
  /// In en, this message translates to:
  /// **'Maximum runs (leave blank to keep running)'**
  String get botRoutineRepeatLimit;

  /// No description provided for @botRoutineContinuity.
  ///
  /// In en, this message translates to:
  /// **'Continuity'**
  String get botRoutineContinuity;

  /// No description provided for @botRoutineContinuityDescription.
  ///
  /// In en, this message translates to:
  /// **'Each run can read the previous output from this task.'**
  String get botRoutineContinuityDescription;

  /// No description provided for @botRoutineSendToBot.
  ///
  /// In en, this message translates to:
  /// **'Send to {name}\'s Bot Chat'**
  String botRoutineSendToBot(Object name);

  /// No description provided for @botRoutineSendToBotDescription.
  ///
  /// In en, this message translates to:
  /// **'The Bot will read the result and continue responding.'**
  String get botRoutineSendToBotDescription;

  /// No description provided for @botRoutineCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get botRoutineCreating;

  /// No description provided for @botRoutineCreate.
  ///
  /// In en, this message translates to:
  /// **'Create routine'**
  String get botRoutineCreate;

  /// No description provided for @mcpTitle.
  ///
  /// In en, this message translates to:
  /// **'MCP servers'**
  String get mcpTitle;

  /// No description provided for @mcpOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {error}'**
  String mcpOperationFailed(Object error);

  /// No description provided for @mcpPersistenceFailed.
  ///
  /// In en, this message translates to:
  /// **'The server did not persist the MCP configuration change.'**
  String get mcpPersistenceFailed;

  /// No description provided for @mcpTestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connected: {tools} tools, {prompts} prompts, {resources} resources'**
  String mcpTestSuccess(Object prompts, Object resources, Object tools);

  /// No description provided for @mcpTestConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {error}'**
  String mcpTestConnectionFailed(Object error);

  /// No description provided for @mcpTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Test failed: {error}'**
  String mcpTestFailed(Object error);

  /// No description provided for @mcpReloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Configuration was saved, but MCP hot reload failed for the active session: {error}'**
  String mcpReloadFailed(Object error);

  /// No description provided for @mcpImportUnrecognized.
  ///
  /// In en, this message translates to:
  /// **'Could not recognize the pasted content. Check its format.'**
  String get mcpImportUnrecognized;

  /// No description provided for @mcpImportDetected.
  ///
  /// In en, this message translates to:
  /// **'Detected {count} servers'**
  String mcpImportDetected(Object count);

  /// No description provided for @mcpImportAllQuestion.
  ///
  /// In en, this message translates to:
  /// **'Add all of these servers?\n\n{names}'**
  String mcpImportAllQuestion(Object names);

  /// No description provided for @mcpAddAll.
  ///
  /// In en, this message translates to:
  /// **'Add all'**
  String get mcpAddAll;

  /// No description provided for @mcpServersAdded.
  ///
  /// In en, this message translates to:
  /// **'Added {count} servers'**
  String mcpServersAdded(Object count);

  /// No description provided for @mcpServersPartiallyAdded.
  ///
  /// In en, this message translates to:
  /// **'Added {added}; {failed} failed'**
  String mcpServersPartiallyAdded(Object added, Object failed);

  /// No description provided for @mcpAddServer.
  ///
  /// In en, this message translates to:
  /// **'Add MCP server'**
  String get mcpAddServer;

  /// No description provided for @mcpPasteImport.
  ///
  /// In en, this message translates to:
  /// **'Paste import (mcp.json / command / claude mcp add / URL)'**
  String get mcpPasteImport;

  /// No description provided for @mcpParse.
  ///
  /// In en, this message translates to:
  /// **'Parse'**
  String get mcpParse;

  /// No description provided for @mcpRemoteUrl.
  ///
  /// In en, this message translates to:
  /// **'Remote URL'**
  String get mcpRemoteUrl;

  /// No description provided for @mcpLocalStdio.
  ///
  /// In en, this message translates to:
  /// **'Local stdio'**
  String get mcpLocalStdio;

  /// No description provided for @mcpServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get mcpServerUrl;

  /// No description provided for @mcpCommand.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get mcpCommand;

  /// No description provided for @mcpArgumentsOnePerLine.
  ///
  /// In en, this message translates to:
  /// **'Arguments (one per line)'**
  String get mcpArgumentsOnePerLine;

  /// No description provided for @mcpEnvironmentJson.
  ///
  /// In en, this message translates to:
  /// **'Environment variables (JSON)'**
  String get mcpEnvironmentJson;

  /// No description provided for @mcpAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get mcpAuthentication;

  /// No description provided for @mcpNoAuthentication.
  ///
  /// In en, this message translates to:
  /// **'No authentication'**
  String get mcpNoAuthentication;

  /// No description provided for @mcpEnvironmentMustBeJson.
  ///
  /// In en, this message translates to:
  /// **'Environment variables must be a JSON object.'**
  String get mcpEnvironmentMustBeJson;

  /// No description provided for @mcpServerAdded.
  ///
  /// In en, this message translates to:
  /// **'MCP server added'**
  String get mcpServerAdded;

  /// No description provided for @mcpAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add server: {error}'**
  String mcpAddFailed(Object error);

  /// No description provided for @mcpDeleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String mcpDeleteQuestion(Object name);

  /// No description provided for @mcpDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'This server will be permanently removed from the Hermes MCP configuration.'**
  String get mcpDeleteWarning;

  /// No description provided for @mcpDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete server: {error}'**
  String mcpDeleteFailed(Object error);

  /// No description provided for @mcpReadConfigFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read configuration: {error}'**
  String mcpReadConfigFailed(Object error);

  /// No description provided for @mcpEditServer.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String mcpEditServer(Object name);

  /// No description provided for @mcpInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'Not a valid JSON object: {error}'**
  String mcpInvalidJson(Object error);

  /// No description provided for @mcpServerSaved.
  ///
  /// In en, this message translates to:
  /// **'{name} saved'**
  String mcpServerSaved(Object name);

  /// No description provided for @mcpSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save server: {error}'**
  String mcpSaveFailed(Object error);

  /// No description provided for @mcpToolToggleFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not toggle tool: {error}'**
  String mcpToolToggleFailed(Object error);

  /// No description provided for @mcpOAuthStartFailed.
  ///
  /// In en, this message translates to:
  /// **'OAuth could not start'**
  String get mcpOAuthStartFailed;

  /// No description provided for @mcpOAuthMissingUrl.
  ///
  /// In en, this message translates to:
  /// **'The OAuth server did not return an authorization URL.'**
  String get mcpOAuthMissingUrl;

  /// No description provided for @mcpBrowserOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the system browser.'**
  String get mcpBrowserOpenFailed;

  /// No description provided for @mcpCompleteAuthorization.
  ///
  /// In en, this message translates to:
  /// **'Complete authorization for {name} in the browser.'**
  String mcpCompleteAuthorization(Object name);

  /// No description provided for @mcpOAuthAuthorizationFailed.
  ///
  /// In en, this message translates to:
  /// **'OAuth authorization failed'**
  String get mcpOAuthAuthorizationFailed;

  /// No description provided for @mcpAuthorizationSucceeded.
  ///
  /// In en, this message translates to:
  /// **'{name} authorized; found {tools} tools'**
  String mcpAuthorizationSucceeded(Object name, Object tools);

  /// No description provided for @mcpOAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'OAuth failed: {error}'**
  String mcpOAuthFailed(Object error);

  /// No description provided for @mcpInstallTitle.
  ///
  /// In en, this message translates to:
  /// **'Install {name}'**
  String mcpInstallTitle(Object name);

  /// No description provided for @mcpRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get mcpRequired;

  /// No description provided for @mcpOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get mcpOptional;

  /// No description provided for @mcpRequiredCredentials.
  ///
  /// In en, this message translates to:
  /// **'Enter all required credentials.'**
  String get mcpRequiredCredentials;

  /// No description provided for @mcpReinstall.
  ///
  /// In en, this message translates to:
  /// **'Reinstall'**
  String get mcpReinstall;

  /// No description provided for @mcpInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get mcpInstall;

  /// No description provided for @mcpInstallExitCode.
  ///
  /// In en, this message translates to:
  /// **'Installer exited with code {code}'**
  String mcpInstallExitCode(Object code);

  /// No description provided for @mcpInstallComplete.
  ///
  /// In en, this message translates to:
  /// **'{name} installed'**
  String mcpInstallComplete(Object name);

  /// No description provided for @mcpInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Installation failed: {error}'**
  String mcpInstallFailed(Object error);

  /// No description provided for @mcpViewLogs.
  ///
  /// In en, this message translates to:
  /// **'View logs'**
  String get mcpViewLogs;

  /// No description provided for @mcpLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading MCP servers...'**
  String get mcpLoading;

  /// No description provided for @mcpConfiguredServers.
  ///
  /// In en, this message translates to:
  /// **'Configured servers'**
  String get mcpConfiguredServers;

  /// No description provided for @mcpNoConfiguredServers.
  ///
  /// In en, this message translates to:
  /// **'No MCP servers configured'**
  String get mcpNoConfiguredServers;

  /// No description provided for @mcpDescription.
  ///
  /// In en, this message translates to:
  /// **'MCP connects agents to external tools and data sources.'**
  String get mcpDescription;

  /// No description provided for @mcpAvailableCatalog.
  ///
  /// In en, this message translates to:
  /// **'Available catalog ({count})'**
  String mcpAvailableCatalog(Object count);

  /// No description provided for @mcpToolCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tools'**
  String mcpToolCount(Object count);

  /// No description provided for @mcpUsage30Days.
  ///
  /// In en, this message translates to:
  /// **'{count} uses / 30 days'**
  String mcpUsage30Days(Object count);

  /// No description provided for @mcpTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get mcpTestConnection;

  /// No description provided for @mcpEditConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Edit configuration'**
  String get mcpEditConfiguration;

  /// No description provided for @mcpOAuthAuthorization.
  ///
  /// In en, this message translates to:
  /// **'OAuth authorization'**
  String get mcpOAuthAuthorization;

  /// No description provided for @mcpInstalledEnabled.
  ///
  /// In en, this message translates to:
  /// **'Installed and enabled'**
  String get mcpInstalledEnabled;

  /// No description provided for @mcpInstalledDisabled.
  ///
  /// In en, this message translates to:
  /// **'Installed but disabled'**
  String get mcpInstalledDisabled;

  /// No description provided for @commandCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Command Center'**
  String get commandCenterTitle;

  /// No description provided for @commandStatusTab.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get commandStatusTab;

  /// No description provided for @commandUsageTab.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get commandUsageTab;

  /// No description provided for @commandMaintenanceTab.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get commandMaintenanceTab;

  /// No description provided for @commandStatusLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load status: {error}'**
  String commandStatusLoadFailed(Object error);

  /// No description provided for @commandLogsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load logs: {error}'**
  String commandLogsLoadFailed(Object error);

  /// No description provided for @commandRestartWarning.
  ///
  /// In en, this message translates to:
  /// **'This restarts the Hermes backend process and may interrupt active turns.'**
  String get commandRestartWarning;

  /// No description provided for @commandRestartResult.
  ///
  /// In en, this message translates to:
  /// **'Restart result: {result}'**
  String commandRestartResult(Object result);

  /// No description provided for @commandNoLogs.
  ///
  /// In en, this message translates to:
  /// **'(No logs)'**
  String get commandNoLogs;

  /// No description provided for @commandBackendProcess.
  ///
  /// In en, this message translates to:
  /// **'Backend process'**
  String get commandBackendProcess;

  /// No description provided for @commandStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get commandStopped;

  /// No description provided for @commandLiveLogs.
  ///
  /// In en, this message translates to:
  /// **'Live logs'**
  String get commandLiveLogs;

  /// No description provided for @commandDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic details'**
  String get commandDiagnostics;

  /// No description provided for @commandSystemStatus.
  ///
  /// In en, this message translates to:
  /// **'System status'**
  String get commandSystemStatus;

  /// No description provided for @commandNoStatusData.
  ///
  /// In en, this message translates to:
  /// **'No status data'**
  String get commandNoStatusData;

  /// No description provided for @commandUsageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load usage: {error}'**
  String commandUsageLoadFailed(Object error);

  /// No description provided for @commandDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String commandDays(Object count);

  /// No description provided for @commandSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get commandSessions;

  /// No description provided for @commandApiCalls.
  ///
  /// In en, this message translates to:
  /// **'API calls'**
  String get commandApiCalls;

  /// No description provided for @commandTokensInOut.
  ///
  /// In en, this message translates to:
  /// **'Tokens (in/out)'**
  String get commandTokensInOut;

  /// No description provided for @commandDailyUsage.
  ///
  /// In en, this message translates to:
  /// **'Daily usage'**
  String get commandDailyUsage;

  /// No description provided for @commandNoUsageData.
  ///
  /// In en, this message translates to:
  /// **'No usage data'**
  String get commandNoUsageData;

  /// No description provided for @commandTopModels.
  ///
  /// In en, this message translates to:
  /// **'Top models'**
  String get commandTopModels;

  /// No description provided for @commandTopSkills.
  ///
  /// In en, this message translates to:
  /// **'Top skills'**
  String get commandTopSkills;

  /// No description provided for @commandUseCount.
  ///
  /// In en, this message translates to:
  /// **'{count} uses'**
  String commandUseCount(Object count);

  /// No description provided for @commandChartTooltip.
  ///
  /// In en, this message translates to:
  /// **'{day}\nInput {input} / Output {output}'**
  String commandChartTooltip(Object day, Object input, Object output);

  /// No description provided for @commandInputTokens.
  ///
  /// In en, this message translates to:
  /// **'Input tokens'**
  String get commandInputTokens;

  /// No description provided for @commandOutputTokens.
  ///
  /// In en, this message translates to:
  /// **'Output tokens'**
  String get commandOutputTokens;

  /// No description provided for @commandStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting {label}...'**
  String commandStarting(Object label);

  /// No description provided for @commandMissingActionName.
  ///
  /// In en, this message translates to:
  /// **'The backend did not return an action name.'**
  String get commandMissingActionName;

  /// No description provided for @commandNoOutput.
  ///
  /// In en, this message translates to:
  /// **'(No output yet)'**
  String get commandNoOutput;

  /// No description provided for @commandActionExitFailed.
  ///
  /// In en, this message translates to:
  /// **'{label} failed (exit code {code})'**
  String commandActionExitFailed(Object code, Object label);

  /// No description provided for @commandActionComplete.
  ///
  /// In en, this message translates to:
  /// **'{label} completed'**
  String commandActionComplete(Object label);

  /// No description provided for @commandLogError.
  ///
  /// In en, this message translates to:
  /// **'{logs}\n\nError: {error}'**
  String commandLogError(Object error, Object logs);

  /// No description provided for @commandActionFailed.
  ///
  /// In en, this message translates to:
  /// **'{label} failed: {error}'**
  String commandActionFailed(Object error, Object label);

  /// No description provided for @commandDebugShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not generate debug share: {error}'**
  String commandDebugShareFailed(Object error);

  /// No description provided for @commandDebugShare.
  ///
  /// In en, this message translates to:
  /// **'Generate debug share'**
  String get commandDebugShare;

  /// No description provided for @commandLogsRedacted.
  ///
  /// In en, this message translates to:
  /// **'Sensitive values were redacted from the logs.'**
  String get commandLogsRedacted;

  /// No description provided for @commandLogsNotRedacted.
  ///
  /// In en, this message translates to:
  /// **'The logs were not redacted. Share them carefully.'**
  String get commandLogsNotRedacted;

  /// No description provided for @commandAutoDeleteHours.
  ///
  /// In en, this message translates to:
  /// **'Links will be deleted automatically in about {hours} hours.'**
  String commandAutoDeleteHours(Object hours);

  /// No description provided for @commandPartialUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Some content failed to upload:'**
  String get commandPartialUploadFailed;

  /// No description provided for @commandDiagnosticsMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics and maintenance'**
  String get commandDiagnosticsMaintenance;

  /// No description provided for @commandRunDoctor.
  ///
  /// In en, this message translates to:
  /// **'Run diagnostics'**
  String get commandRunDoctor;

  /// No description provided for @commandRunDoctorDescription.
  ///
  /// In en, this message translates to:
  /// **'hermes doctor - check the environment and configuration'**
  String get commandRunDoctorDescription;

  /// No description provided for @commandDoctor.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get commandDoctor;

  /// No description provided for @commandSecurityAudit.
  ///
  /// In en, this message translates to:
  /// **'Security audit'**
  String get commandSecurityAudit;

  /// No description provided for @commandSecurityAuditDescription.
  ///
  /// In en, this message translates to:
  /// **'hermes security audit - scan for potential security issues'**
  String get commandSecurityAuditDescription;

  /// No description provided for @commandBackupNow.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get commandBackupNow;

  /// No description provided for @commandBackupDescription.
  ///
  /// In en, this message translates to:
  /// **'hermes backup - package configuration and data locally'**
  String get commandBackupDescription;

  /// No description provided for @commandBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get commandBackup;

  /// No description provided for @commandDebugShareDescription.
  ///
  /// In en, this message translates to:
  /// **'Upload redacted logs and create shareable debug links'**
  String get commandDebugShareDescription;

  /// No description provided for @terminalStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start terminal: {error}'**
  String terminalStartFailed(Object error);

  /// No description provided for @terminalSshHost.
  ///
  /// In en, this message translates to:
  /// **'Host or SSH config alias *'**
  String get terminalSshHost;

  /// No description provided for @terminalSshUserOptional.
  ///
  /// In en, this message translates to:
  /// **'User (optional)'**
  String get terminalSshUserOptional;

  /// No description provided for @terminalSshPort.
  ///
  /// In en, this message translates to:
  /// **'Port (default 22)'**
  String get terminalSshPort;

  /// No description provided for @terminalSshIdentityFile.
  ///
  /// In en, this message translates to:
  /// **'Server-side IdentityFile (optional)'**
  String get terminalSshIdentityFile;

  /// No description provided for @terminalSshRemoteCwd.
  ///
  /// In en, this message translates to:
  /// **'Remote working directory (optional)'**
  String get terminalSshRemoteCwd;

  /// No description provided for @terminalSshAuthenticationNote.
  ///
  /// In en, this message translates to:
  /// **'Authentication uses the ssh-agent or SSH config on the Hermes server. The mobile app does not store passwords.'**
  String get terminalSshAuthenticationNote;

  /// No description provided for @terminalSshFailed.
  ///
  /// In en, this message translates to:
  /// **'SSH connection failed: {error}'**
  String terminalSshFailed(Object error);

  /// No description provided for @terminalCloseRunningQuestion.
  ///
  /// In en, this message translates to:
  /// **'Close running terminal?'**
  String get terminalCloseRunningQuestion;

  /// No description provided for @terminalCloseRunningWarning.
  ///
  /// In en, this message translates to:
  /// **'Processes in \"{name}\" will be terminated. This cannot be undone.'**
  String terminalCloseRunningWarning(Object name);

  /// No description provided for @terminalClose.
  ///
  /// In en, this message translates to:
  /// **'Close terminal'**
  String get terminalClose;

  /// No description provided for @terminalSessions.
  ///
  /// In en, this message translates to:
  /// **'Terminal sessions'**
  String get terminalSessions;

  /// No description provided for @terminalSessionLimit.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} terminals can be open at once'**
  String terminalSessionLimit(Object count);

  /// No description provided for @terminalCloseNamed.
  ///
  /// In en, this message translates to:
  /// **'Close {name}'**
  String terminalCloseNamed(Object name);

  /// No description provided for @terminalSelectTextFirst.
  ///
  /// In en, this message translates to:
  /// **'Select text first.'**
  String get terminalSelectTextFirst;

  /// No description provided for @terminalPasteLinesQuestion.
  ///
  /// In en, this message translates to:
  /// **'Paste {count} lines?'**
  String terminalPasteLinesQuestion(Object count);

  /// No description provided for @terminalMergeSingleLine.
  ///
  /// In en, this message translates to:
  /// **'Merge into one line'**
  String get terminalMergeSingleLine;

  /// No description provided for @terminalConfirmPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get terminalConfirmPaste;

  /// No description provided for @terminalSelectTerminalTextFirst.
  ///
  /// In en, this message translates to:
  /// **'Select text in the terminal first.'**
  String get terminalSelectTerminalTextFirst;

  /// No description provided for @terminalSentToChat.
  ///
  /// In en, this message translates to:
  /// **'Sent to the chat composer'**
  String get terminalSentToChat;

  /// No description provided for @terminalOpenLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open link: {link}'**
  String terminalOpenLinkFailed(Object link);

  /// No description provided for @terminalDismissNotice.
  ///
  /// In en, this message translates to:
  /// **'Dismiss notice'**
  String get terminalDismissNotice;

  /// No description provided for @terminalNew.
  ///
  /// In en, this message translates to:
  /// **'New terminal'**
  String get terminalNew;

  /// No description provided for @terminalNewSsh.
  ///
  /// In en, this message translates to:
  /// **'New SSH terminal'**
  String get terminalNewSsh;

  /// No description provided for @terminalOpenDirectory.
  ///
  /// In en, this message translates to:
  /// **'Open in a directory'**
  String get terminalOpenDirectory;

  /// No description provided for @terminalDisplaySettings.
  ///
  /// In en, this message translates to:
  /// **'Terminal display settings'**
  String get terminalDisplaySettings;

  /// No description provided for @terminalNoWorkingDirectory.
  ///
  /// In en, this message translates to:
  /// **'(No working directory)'**
  String get terminalNoWorkingDirectory;

  /// No description provided for @terminalNoActive.
  ///
  /// In en, this message translates to:
  /// **'No active terminal'**
  String get terminalNoActive;

  /// No description provided for @terminalCommandMode.
  ///
  /// In en, this message translates to:
  /// **'Command mode'**
  String get terminalCommandMode;

  /// No description provided for @terminalInteractiveMode.
  ///
  /// In en, this message translates to:
  /// **'Interactive mode'**
  String get terminalInteractiveMode;

  /// No description provided for @terminalControlInterrupt.
  ///
  /// In en, this message translates to:
  /// **'Ctrl+C interrupt'**
  String get terminalControlInterrupt;

  /// No description provided for @terminalControlSuspend.
  ///
  /// In en, this message translates to:
  /// **'Ctrl+Z suspend'**
  String get terminalControlSuspend;

  /// No description provided for @terminalControlClear.
  ///
  /// In en, this message translates to:
  /// **'Ctrl+L clear screen'**
  String get terminalControlClear;

  /// No description provided for @terminalControlBackWord.
  ///
  /// In en, this message translates to:
  /// **'Alt+B previous word'**
  String get terminalControlBackWord;

  /// No description provided for @terminalControlForwardWord.
  ///
  /// In en, this message translates to:
  /// **'Alt+F next word'**
  String get terminalControlForwardWord;

  /// No description provided for @terminalControlKeys.
  ///
  /// In en, this message translates to:
  /// **'Control keys'**
  String get terminalControlKeys;

  /// No description provided for @terminalVisibleOutputCopied.
  ///
  /// In en, this message translates to:
  /// **'Visible terminal output copied'**
  String get terminalVisibleOutputCopied;

  /// No description provided for @terminalDisplay.
  ///
  /// In en, this message translates to:
  /// **'Terminal display'**
  String get terminalDisplay;

  /// No description provided for @terminalDisplayDescription.
  ///
  /// In en, this message translates to:
  /// **'These settings affect only local display, not PTY or command behavior.'**
  String get terminalDisplayDescription;

  /// No description provided for @terminalPreviewOutput.
  ///
  /// In en, this message translates to:
  /// **'✓ 42 tests passed  Localized output preview'**
  String get terminalPreviewOutput;

  /// No description provided for @terminalFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size  {value}'**
  String terminalFontSize(Object value);

  /// No description provided for @terminalLineHeight.
  ///
  /// In en, this message translates to:
  /// **'Line height  {value}'**
  String terminalLineHeight(Object value);

  /// No description provided for @terminalColorTheme.
  ///
  /// In en, this message translates to:
  /// **'Color theme'**
  String get terminalColorTheme;

  /// No description provided for @terminalThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get terminalThemeSystem;

  /// No description provided for @terminalThemeProfessionalDark.
  ///
  /// In en, this message translates to:
  /// **'Professional dark'**
  String get terminalThemeProfessionalDark;

  /// No description provided for @terminalThemeHighContrastDark.
  ///
  /// In en, this message translates to:
  /// **'High-contrast dark'**
  String get terminalThemeHighContrastDark;

  /// No description provided for @terminalThemeSoftLight.
  ///
  /// In en, this message translates to:
  /// **'Soft light'**
  String get terminalThemeSoftLight;

  /// No description provided for @terminalCursorStyle.
  ///
  /// In en, this message translates to:
  /// **'Cursor style'**
  String get terminalCursorStyle;

  /// No description provided for @terminalCursorBar.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get terminalCursorBar;

  /// No description provided for @terminalCursorBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get terminalCursorBlock;

  /// No description provided for @terminalCursorUnderline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get terminalCursorUnderline;

  /// No description provided for @terminalContentPadding.
  ///
  /// In en, this message translates to:
  /// **'Terminal padding'**
  String get terminalContentPadding;

  /// No description provided for @terminalContentPaddingHint.
  ///
  /// In en, this message translates to:
  /// **'Turn off to show more columns'**
  String get terminalContentPaddingHint;

  /// No description provided for @terminalResetDisplay.
  ///
  /// In en, this message translates to:
  /// **'Restore recommended settings'**
  String get terminalResetDisplay;

  /// No description provided for @terminalCommandHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a command...'**
  String get terminalCommandHint;

  /// No description provided for @terminalRunCommand.
  ///
  /// In en, this message translates to:
  /// **'Run command'**
  String get terminalRunCommand;

  /// No description provided for @terminalPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get terminalPaste;

  /// No description provided for @terminalClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get terminalClear;

  /// No description provided for @terminalSendToChat.
  ///
  /// In en, this message translates to:
  /// **'Send to chat'**
  String get terminalSendToChat;

  /// No description provided for @terminalInteractiveHint.
  ///
  /// In en, this message translates to:
  /// **'Interactive mode · input is sent directly to the PTY'**
  String get terminalInteractiveHint;

  /// No description provided for @terminalMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More terminal actions'**
  String get terminalMoreActions;

  /// No description provided for @terminalCopySelection.
  ///
  /// In en, this message translates to:
  /// **'Copy selection'**
  String get terminalCopySelection;

  /// No description provided for @terminalSendSelectionToChat.
  ///
  /// In en, this message translates to:
  /// **'Send selection to chat'**
  String get terminalSendSelectionToChat;

  /// No description provided for @terminalOpenOtherDirectory.
  ///
  /// In en, this message translates to:
  /// **'Open terminal in another directory'**
  String get terminalOpenOtherDirectory;

  /// No description provided for @terminalManageSessions.
  ///
  /// In en, this message translates to:
  /// **'Manage terminal sessions'**
  String get terminalManageSessions;

  /// No description provided for @terminalPrivacyHistory.
  ///
  /// In en, this message translates to:
  /// **'Privacy and history'**
  String get terminalPrivacyHistory;

  /// No description provided for @terminalPrivacyDescription.
  ///
  /// In en, this message translates to:
  /// **'Command history and terminal output are not persisted by default.'**
  String get terminalPrivacyDescription;

  /// No description provided for @terminalSaveCommandHistory.
  ///
  /// In en, this message translates to:
  /// **'Save command history'**
  String get terminalSaveCommandHistory;

  /// No description provided for @terminalSaveOutputSnapshots.
  ///
  /// In en, this message translates to:
  /// **'Save terminal output snapshots'**
  String get terminalSaveOutputSnapshots;

  /// No description provided for @terminalClearSavedData.
  ///
  /// In en, this message translates to:
  /// **'Clear saved history and snapshots'**
  String get terminalClearSavedData;

  /// No description provided for @terminalClearDataQuestion.
  ///
  /// In en, this message translates to:
  /// **'Clear history and snapshots?'**
  String get terminalClearDataQuestion;

  /// No description provided for @terminalClearDataWarning.
  ///
  /// In en, this message translates to:
  /// **'Saved command history and terminal output snapshots will be permanently deleted. This cannot be undone.'**
  String get terminalClearDataWarning;

  /// No description provided for @filesRevealFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reveal the item in file manager: {error}'**
  String filesRevealFailed(String error);

  /// No description provided for @filesLargeDownloadQuestion.
  ///
  /// In en, this message translates to:
  /// **'Download large file?'**
  String get filesLargeDownloadQuestion;

  /// No description provided for @filesLargeDownloadDescription.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is about {size} MB. Downloading may take a while and use device storage.'**
  String filesLargeDownloadDescription(String name, String size);

  /// No description provided for @filesContinueDownload.
  ///
  /// In en, this message translates to:
  /// **'Continue download'**
  String get filesContinueDownload;

  /// No description provided for @filesLargeEditQuestion.
  ///
  /// In en, this message translates to:
  /// **'Open large file?'**
  String get filesLargeEditQuestion;

  /// No description provided for @filesLargeEditDescription.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is about {size} MB. Loading it into the editor may be slow.'**
  String filesLargeEditDescription(String name, String size);

  /// No description provided for @filesContinueEdit.
  ///
  /// In en, this message translates to:
  /// **'Open anyway'**
  String get filesContinueEdit;

  /// No description provided for @filesFolderDownloadQuestion.
  ///
  /// In en, this message translates to:
  /// **'Download folder?'**
  String get filesFolderDownloadQuestion;

  /// No description provided for @filesFolderDownloadDescription.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be downloaded to this device as a ZIP archive. Large folders may take a while and use device storage.'**
  String filesFolderDownloadDescription(String name);

  /// No description provided for @filesArchiveDownload.
  ///
  /// In en, this message translates to:
  /// **'Archive and download'**
  String get filesArchiveDownload;

  /// No description provided for @filesDownloadedPath.
  ///
  /// In en, this message translates to:
  /// **'Downloaded to {path} (path copied)'**
  String filesDownloadedPath(String path);

  /// No description provided for @filesDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String filesDownloadFailed(String error);

  /// No description provided for @filesSelectDownloadItem.
  ///
  /// In en, this message translates to:
  /// **'Select at least one file or folder'**
  String get filesSelectDownloadItem;

  /// No description provided for @filesDownloadSummary.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {success}; {failed} failed; {skipped} skipped'**
  String filesDownloadSummary(int success, int failed, int skipped);

  /// No description provided for @filesRevealOnServer.
  ///
  /// In en, this message translates to:
  /// **'Reveal on server'**
  String get filesRevealOnServer;

  /// No description provided for @filesRevealOnServerDescription.
  ///
  /// In en, this message translates to:
  /// **'Open on the machine running Hermes'**
  String get filesRevealOnServerDescription;

  /// No description provided for @filesDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get filesDetails;

  /// No description provided for @filesDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get filesDownloading;

  /// No description provided for @filesDownloadFolderZip.
  ///
  /// In en, this message translates to:
  /// **'Download folder (ZIP)'**
  String get filesDownloadFolderZip;

  /// No description provided for @filesDownloadToDevice.
  ///
  /// In en, this message translates to:
  /// **'Download to device'**
  String get filesDownloadToDevice;

  /// No description provided for @filesCopyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get filesCopyToClipboard;

  /// No description provided for @filesCopiedPasteHint.
  ///
  /// In en, this message translates to:
  /// **'Copied; open the destination folder and tap Paste'**
  String get filesCopiedPasteHint;

  /// No description provided for @filesCutToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Cut to clipboard'**
  String get filesCutToClipboard;

  /// No description provided for @filesCutPasteHint.
  ///
  /// In en, this message translates to:
  /// **'Cut; open the destination folder and tap Paste'**
  String get filesCutPasteHint;

  /// No description provided for @filesRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get filesRename;

  /// No description provided for @filesCopyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get filesCopyPath;

  /// No description provided for @filesPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied'**
  String get filesPathCopied;

  /// No description provided for @filesCopyRelativePath.
  ///
  /// In en, this message translates to:
  /// **'Copy relative path'**
  String get filesCopyRelativePath;

  /// No description provided for @filesRelativePathCopied.
  ///
  /// In en, this message translates to:
  /// **'Relative path copied'**
  String get filesRelativePathCopied;

  /// No description provided for @filesLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get filesLink;

  /// No description provided for @filesInfoPath.
  ///
  /// In en, this message translates to:
  /// **'Path: {value}'**
  String filesInfoPath(String value);

  /// No description provided for @filesInfoType.
  ///
  /// In en, this message translates to:
  /// **'Type: {value}'**
  String filesInfoType(String value);

  /// No description provided for @filesInfoSize.
  ///
  /// In en, this message translates to:
  /// **'Size: {value} B'**
  String filesInfoSize(int value);

  /// No description provided for @filesInfoModified.
  ///
  /// In en, this message translates to:
  /// **'Modified: {value}'**
  String filesInfoModified(String value);

  /// No description provided for @filesInfoReadable.
  ///
  /// In en, this message translates to:
  /// **'Readable: {value}'**
  String filesInfoReadable(String value);

  /// No description provided for @filesInfoWritable.
  ///
  /// In en, this message translates to:
  /// **'Writable: {value}'**
  String filesInfoWritable(String value);

  /// No description provided for @filesMovedCount.
  ///
  /// In en, this message translates to:
  /// **'Moved {count} items'**
  String filesMovedCount(int count);

  /// No description provided for @filesCopiedCount.
  ///
  /// In en, this message translates to:
  /// **'Copied {count} items'**
  String filesCopiedCount(int count);

  /// No description provided for @filesPasteFailed.
  ///
  /// In en, this message translates to:
  /// **'Paste failed: {error}'**
  String filesPasteFailed(String error);

  /// No description provided for @filesConfirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get filesConfirmDelete;

  /// No description provided for @filesDeleteSelectedDescription.
  ///
  /// In en, this message translates to:
  /// **'Delete the {count} selected items? This cannot be undone.'**
  String filesDeleteSelectedDescription(int count);

  /// No description provided for @filesDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String filesDeleteFailed(String error);

  /// No description provided for @filesNewFile.
  ///
  /// In en, this message translates to:
  /// **'New file'**
  String get filesNewFile;

  /// No description provided for @filesFileName.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get filesFileName;

  /// No description provided for @filesCreateFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create file: {error}'**
  String filesCreateFileFailed(String error);

  /// No description provided for @filesNewSessionPrompt.
  ///
  /// In en, this message translates to:
  /// **'Review and process these files:\n{references}'**
  String filesNewSessionPrompt(String references);

  /// No description provided for @filesNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get filesNewFolder;

  /// No description provided for @filesNewName.
  ///
  /// In en, this message translates to:
  /// **'New name'**
  String get filesNewName;

  /// No description provided for @filesRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Rename failed: {error}'**
  String filesRenameFailed(String error);

  /// No description provided for @filesDeleteFolderDescription.
  ///
  /// In en, this message translates to:
  /// **'Delete folder \"{name}\" and all its contents?'**
  String filesDeleteFolderDescription(String name);

  /// No description provided for @filesDeleteFileDescription.
  ///
  /// In en, this message translates to:
  /// **'Delete file \"{name}\"?'**
  String filesDeleteFileDescription(String name);

  /// No description provided for @filesFolderName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get filesFolderName;

  /// No description provided for @filesCreateFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create folder: {error}'**
  String filesCreateFolderFailed(String error);

  /// No description provided for @filesSelectWorkspaceDirectory.
  ///
  /// In en, this message translates to:
  /// **'Select workspace directory'**
  String get filesSelectWorkspaceDirectory;

  /// No description provided for @filesSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String filesSelectedCount(int count);

  /// No description provided for @filesSwitchToDirectoryBrowser.
  ///
  /// In en, this message translates to:
  /// **'Switch to directory browser'**
  String get filesSwitchToDirectoryBrowser;

  /// No description provided for @filesSwitchToProjectTree.
  ///
  /// In en, this message translates to:
  /// **'Switch to project tree'**
  String get filesSwitchToProjectTree;

  /// No description provided for @filesOpenInGit.
  ///
  /// In en, this message translates to:
  /// **'Open in Git'**
  String get filesOpenInGit;

  /// No description provided for @filesNewSessionForDirectory.
  ///
  /// In en, this message translates to:
  /// **'New session for current directory'**
  String get filesNewSessionForDirectory;

  /// No description provided for @filesSendSelectionToNewSession.
  ///
  /// In en, this message translates to:
  /// **'Send selected files to new session'**
  String get filesSendSelectionToNewSession;

  /// No description provided for @filesDownloadSelected.
  ///
  /// In en, this message translates to:
  /// **'Download selected'**
  String get filesDownloadSelected;

  /// No description provided for @filesCopySelected.
  ///
  /// In en, this message translates to:
  /// **'Copy selected'**
  String get filesCopySelected;

  /// No description provided for @filesCutSelected.
  ///
  /// In en, this message translates to:
  /// **'Cut selected'**
  String get filesCutSelected;

  /// No description provided for @filesDeleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get filesDeleteSelected;

  /// No description provided for @filesClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get filesClearSelection;

  /// No description provided for @filesMoveHere.
  ///
  /// In en, this message translates to:
  /// **'Move here'**
  String get filesMoveHere;

  /// No description provided for @filesCopyHere.
  ///
  /// In en, this message translates to:
  /// **'Copy here'**
  String get filesCopyHere;

  /// No description provided for @filesSelectCurrentDirectory.
  ///
  /// In en, this message translates to:
  /// **'Select current directory'**
  String get filesSelectCurrentDirectory;

  /// No description provided for @filesUseAsWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Use \"{name}\" as workspace'**
  String filesUseAsWorkspace(String name);

  /// No description provided for @filesSelectPreview.
  ///
  /// In en, this message translates to:
  /// **'Select a file to preview'**
  String get filesSelectPreview;

  /// No description provided for @filesSelectPreviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Select a file on the left to edit or preview it here'**
  String get filesSelectPreviewDescription;

  /// No description provided for @filesFilterProjectTree.
  ///
  /// In en, this message translates to:
  /// **'Filter loaded project tree...'**
  String get filesFilterProjectTree;

  /// No description provided for @filesSearchDirectory.
  ///
  /// In en, this message translates to:
  /// **'Search current directory...'**
  String get filesSearchDirectory;

  /// No description provided for @filesLoadingDirectory.
  ///
  /// In en, this message translates to:
  /// **'Loading directory...'**
  String get filesLoadingDirectory;

  /// No description provided for @filesNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching files'**
  String get filesNoMatches;

  /// No description provided for @filesActions.
  ///
  /// In en, this message translates to:
  /// **'File actions'**
  String get filesActions;

  /// No description provided for @filesUnableToRead.
  ///
  /// In en, this message translates to:
  /// **'Unable to read'**
  String get filesUnableToRead;

  /// No description provided for @filesDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get filesDownload;

  /// No description provided for @filesCut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get filesCut;

  /// No description provided for @configTabModel.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get configTabModel;

  /// No description provided for @configTabChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get configTabChat;

  /// No description provided for @configTabMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get configTabMemory;

  /// No description provided for @configTabVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get configTabVoice;

  /// No description provided for @configTabToolsKeys.
  ///
  /// In en, this message translates to:
  /// **'Tools & keys'**
  String get configTabToolsKeys;

  /// No description provided for @configLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load configuration: {error}'**
  String configLoadFailed(String error);

  /// No description provided for @configAuxVision.
  ///
  /// In en, this message translates to:
  /// **'Vision'**
  String get configAuxVision;

  /// No description provided for @configAuxWebExtract.
  ///
  /// In en, this message translates to:
  /// **'Web extraction'**
  String get configAuxWebExtract;

  /// No description provided for @configAuxCompression.
  ///
  /// In en, this message translates to:
  /// **'Context compression'**
  String get configAuxCompression;

  /// No description provided for @configAuxSkillsHub.
  ///
  /// In en, this message translates to:
  /// **'Skills hub'**
  String get configAuxSkillsHub;

  /// No description provided for @configAuxApproval.
  ///
  /// In en, this message translates to:
  /// **'Approval decisions'**
  String get configAuxApproval;

  /// No description provided for @configAuxMcp.
  ///
  /// In en, this message translates to:
  /// **'MCP assistance'**
  String get configAuxMcp;

  /// No description provided for @configAuxTitleGeneration.
  ///
  /// In en, this message translates to:
  /// **'Title generation'**
  String get configAuxTitleGeneration;

  /// No description provided for @configAuxReview.
  ///
  /// In en, this message translates to:
  /// **'Code review'**
  String get configAuxReview;

  /// No description provided for @configAuxTriage.
  ///
  /// In en, this message translates to:
  /// **'Task triage'**
  String get configAuxTriage;

  /// No description provided for @configAuxKanban.
  ///
  /// In en, this message translates to:
  /// **'Kanban decomposition'**
  String get configAuxKanban;

  /// No description provided for @configAuxProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile description'**
  String get configAuxProfile;

  /// No description provided for @configAuxCurator.
  ///
  /// In en, this message translates to:
  /// **'Content curation'**
  String get configAuxCurator;

  /// No description provided for @configPersonalityDisplay.
  ///
  /// In en, this message translates to:
  /// **'Personality (display.personality)'**
  String get configPersonalityDisplay;

  /// No description provided for @configPersonality.
  ///
  /// In en, this message translates to:
  /// **'Personality'**
  String get configPersonality;

  /// No description provided for @configTimezone.
  ///
  /// In en, this message translates to:
  /// **'Time zone (IANA)'**
  String get configTimezone;

  /// No description provided for @configShowReasoning.
  ///
  /// In en, this message translates to:
  /// **'Show reasoning blocks'**
  String get configShowReasoning;

  /// No description provided for @configMessageReactions.
  ///
  /// In en, this message translates to:
  /// **'Enable message reactions'**
  String get configMessageReactions;

  /// No description provided for @configApprovalMode.
  ///
  /// In en, this message translates to:
  /// **'Approval mode'**
  String get configApprovalMode;

  /// No description provided for @configYoloApproval.
  ///
  /// In en, this message translates to:
  /// **'YOLO automatic approval'**
  String get configYoloApproval;

  /// No description provided for @configChatFieldsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Chat fields not returned by backend'**
  String get configChatFieldsUnavailable;

  /// No description provided for @configChatFieldsUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'GET /api/v1/config did not return personality, timezone, approvals, or yolo.'**
  String get configChatFieldsUnavailableDescription;

  /// No description provided for @configPersistentMemory.
  ///
  /// In en, this message translates to:
  /// **'Persistent memory'**
  String get configPersistentMemory;

  /// No description provided for @configUserProfile.
  ///
  /// In en, this message translates to:
  /// **'User profile'**
  String get configUserProfile;

  /// No description provided for @configMemoryBudget.
  ///
  /// In en, this message translates to:
  /// **'Memory budget (characters)'**
  String get configMemoryBudget;

  /// No description provided for @configProfileBudget.
  ///
  /// In en, this message translates to:
  /// **'Profile budget (characters)'**
  String get configProfileBudget;

  /// No description provided for @configMemoryProvider.
  ///
  /// In en, this message translates to:
  /// **'Memory provider'**
  String get configMemoryProvider;

  /// No description provided for @configContextEngine.
  ///
  /// In en, this message translates to:
  /// **'Context engine'**
  String get configContextEngine;

  /// No description provided for @configAutoCompression.
  ///
  /// In en, this message translates to:
  /// **'Automatic compression'**
  String get configAutoCompression;

  /// No description provided for @configCompressionThreshold.
  ///
  /// In en, this message translates to:
  /// **'Compression threshold'**
  String get configCompressionThreshold;

  /// No description provided for @configCompressionRatio.
  ///
  /// In en, this message translates to:
  /// **'Compression target ratio'**
  String get configCompressionRatio;

  /// No description provided for @configProtectRecent.
  ///
  /// In en, this message translates to:
  /// **'Protect latest N messages'**
  String get configProtectRecent;

  /// No description provided for @configMemoryFieldsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Memory fields not returned by backend'**
  String get configMemoryFieldsUnavailable;

  /// No description provided for @configMemoryFieldsUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'GET /api/v1/config did not return memory, compression, or context.'**
  String get configMemoryFieldsUnavailableDescription;

  /// No description provided for @configVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get configVoice;

  /// No description provided for @configVoiceModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get configVoiceModel;

  /// No description provided for @configVoiceId.
  ///
  /// In en, this message translates to:
  /// **'Voice ID'**
  String get configVoiceId;

  /// No description provided for @configModelId.
  ///
  /// In en, this message translates to:
  /// **'Model ID'**
  String get configModelId;

  /// No description provided for @configLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get configLanguage;

  /// No description provided for @configSpeechSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speech speed'**
  String get configSpeechSpeed;

  /// No description provided for @configAutoSpeechTags.
  ///
  /// In en, this message translates to:
  /// **'Automatic speech tags'**
  String get configAutoSpeechTags;

  /// No description provided for @configStreamingLatency.
  ///
  /// In en, this message translates to:
  /// **'Streaming latency optimization'**
  String get configStreamingLatency;

  /// No description provided for @configSampleRate.
  ///
  /// In en, this message translates to:
  /// **'Sample rate'**
  String get configSampleRate;

  /// No description provided for @configBitRate.
  ///
  /// In en, this message translates to:
  /// **'Bit rate'**
  String get configBitRate;

  /// No description provided for @configDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get configDevice;

  /// No description provided for @configLanguageCode.
  ///
  /// In en, this message translates to:
  /// **'Language code'**
  String get configLanguageCode;

  /// No description provided for @configAudioEvents.
  ///
  /// In en, this message translates to:
  /// **'Tag audio events'**
  String get configAudioEvents;

  /// No description provided for @configDiarization.
  ///
  /// In en, this message translates to:
  /// **'Speaker diarization'**
  String get configDiarization;

  /// No description provided for @configSpeechToText.
  ///
  /// In en, this message translates to:
  /// **'Speech to text'**
  String get configSpeechToText;

  /// No description provided for @configEchoTranscripts.
  ///
  /// In en, this message translates to:
  /// **'Echo transcripts'**
  String get configEchoTranscripts;

  /// No description provided for @configSttProvider.
  ///
  /// In en, this message translates to:
  /// **'STT provider'**
  String get configSttProvider;

  /// No description provided for @configTtsProvider.
  ///
  /// In en, this message translates to:
  /// **'TTS provider'**
  String get configTtsProvider;

  /// No description provided for @configAutoReadReplies.
  ///
  /// In en, this message translates to:
  /// **'Read replies automatically'**
  String get configAutoReadReplies;

  /// No description provided for @configMaxRecordingSeconds.
  ///
  /// In en, this message translates to:
  /// **'Maximum recording seconds'**
  String get configMaxRecordingSeconds;

  /// No description provided for @configRecordShortcut.
  ///
  /// In en, this message translates to:
  /// **'Recording shortcut'**
  String get configRecordShortcut;

  /// No description provided for @configDirectVoiceService.
  ///
  /// In en, this message translates to:
  /// **'Connect directly to voice service'**
  String get configDirectVoiceService;

  /// No description provided for @configVoiceFieldsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice fields not returned by backend'**
  String get configVoiceFieldsUnavailable;

  /// No description provided for @configVoiceFieldsUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'GET /api/v1/config did not return stt, tts, or voice.'**
  String get configVoiceFieldsUnavailableDescription;

  /// No description provided for @configProviderApiKeys.
  ///
  /// In en, this message translates to:
  /// **'Model provider API keys'**
  String get configProviderApiKeys;

  /// No description provided for @configNoProviders.
  ///
  /// In en, this message translates to:
  /// **'No configured providers'**
  String get configNoProviders;

  /// No description provided for @configNoProvidersDescription.
  ///
  /// In en, this message translates to:
  /// **'Add an API key to enable a model provider'**
  String get configNoProvidersDescription;

  /// No description provided for @configEnvironmentVariables.
  ///
  /// In en, this message translates to:
  /// **'Environment variables'**
  String get configEnvironmentVariables;

  /// No description provided for @configConfigured.
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get configConfigured;

  /// No description provided for @configNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get configNotConfigured;

  /// No description provided for @configAvailableModels.
  ///
  /// In en, this message translates to:
  /// **'{count} models available'**
  String configAvailableModels(int count);

  /// No description provided for @configDisconnectedProvider.
  ///
  /// In en, this message translates to:
  /// **'Disconnected {name}'**
  String configDisconnectedProvider(String name);

  /// No description provided for @configDisconnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not disconnect: {error}'**
  String configDisconnectFailed(String error);

  /// No description provided for @configUpdateKey.
  ///
  /// In en, this message translates to:
  /// **'Update key'**
  String get configUpdateKey;

  /// No description provided for @configAddKey.
  ///
  /// In en, this message translates to:
  /// **'Add key'**
  String get configAddKey;

  /// No description provided for @configProviderApiKey.
  ///
  /// In en, this message translates to:
  /// **'{name} API key'**
  String configProviderApiKey(String name);

  /// No description provided for @configProviderKeySaved.
  ///
  /// In en, this message translates to:
  /// **'Saved {name} API key'**
  String configProviderKeySaved(String name);

  /// No description provided for @configSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get configSaved;

  /// No description provided for @configPressEnterToSave.
  ///
  /// In en, this message translates to:
  /// **'Press Enter to save'**
  String get configPressEnterToSave;

  /// No description provided for @configEnterNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get configEnterNumber;

  /// No description provided for @configNewValueOptional.
  ///
  /// In en, this message translates to:
  /// **'New value (leave blank to keep unchanged)'**
  String get configNewValueOptional;

  /// No description provided for @configValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get configValue;

  /// No description provided for @configRevealFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reveal value: {error}'**
  String configRevealFailed(String error);

  /// No description provided for @configDeleteVariableQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete {key}?'**
  String configDeleteVariableQuestion(String key);

  /// No description provided for @configDeleteVariableDescription.
  ///
  /// In en, this message translates to:
  /// **'This environment variable will be permanently removed from the server .env file. This cannot be undone.'**
  String get configDeleteVariableDescription;

  /// No description provided for @configAddEnvironmentVariable.
  ///
  /// In en, this message translates to:
  /// **'Add environment variable'**
  String get configAddEnvironmentVariable;

  /// No description provided for @configVariableName.
  ///
  /// In en, this message translates to:
  /// **'Variable name'**
  String get configVariableName;

  /// No description provided for @configNoEnvironmentVariables.
  ///
  /// In en, this message translates to:
  /// **'No environment variables'**
  String get configNoEnvironmentVariables;

  /// No description provided for @configNoEnvironmentVariablesDescription.
  ///
  /// In en, this message translates to:
  /// **'Add custom environment variables to configure tools or providers'**
  String get configNoEnvironmentVariablesDescription;

  /// No description provided for @configHideAdvancedVariables.
  ///
  /// In en, this message translates to:
  /// **'Hide advanced variables'**
  String get configHideAdvancedVariables;

  /// No description provided for @configShowAdvancedVariables.
  ///
  /// In en, this message translates to:
  /// **'Show advanced variables ({count})'**
  String configShowAdvancedVariables(int count);

  /// No description provided for @configSet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get configSet;

  /// No description provided for @configNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get configNotSet;

  /// No description provided for @configVoiceIdManual.
  ///
  /// In en, this message translates to:
  /// **'Press Enter to save (no account voices were returned; enter an ID manually)'**
  String get configVoiceIdManual;

  /// No description provided for @configVoicesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load account voices: {error}. Enter an ID manually and press Enter to save.'**
  String configVoicesLoadFailed(String error);

  /// No description provided for @chatDraftHandoffSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The draft is available here but could not be saved to the server: {error}'**
  String chatDraftHandoffSaveFailed(String error);

  /// No description provided for @toolPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get toolPlanTitle;

  /// No description provided for @toolPlanCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy plan'**
  String get toolPlanCopy;

  /// No description provided for @toolPlanCopied.
  ///
  /// In en, this message translates to:
  /// **'Plan copied'**
  String get toolPlanCopied;

  /// No description provided for @toolValueNotProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get toolValueNotProvided;

  /// No description provided for @toolCommand.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get toolCommand;

  /// No description provided for @toolWaitingCommand.
  ///
  /// In en, this message translates to:
  /// **'Waiting for command'**
  String get toolWaitingCommand;

  /// No description provided for @toolOutput.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get toolOutput;

  /// No description provided for @toolErrorOutput.
  ///
  /// In en, this message translates to:
  /// **'Error output'**
  String get toolErrorOutput;

  /// No description provided for @toolExitCode.
  ///
  /// In en, this message translates to:
  /// **'Exit code: {code}'**
  String toolExitCode(int code);

  /// No description provided for @toolCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get toolCode;

  /// No description provided for @toolCodeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Code · {language}'**
  String toolCodeLanguage(String language);

  /// No description provided for @toolWaitingCode.
  ///
  /// In en, this message translates to:
  /// **'Waiting for code'**
  String get toolWaitingCode;

  /// No description provided for @toolExecutionResult.
  ///
  /// In en, this message translates to:
  /// **'Execution result'**
  String get toolExecutionResult;

  /// No description provided for @toolChangedFiles.
  ///
  /// In en, this message translates to:
  /// **'Changed files · {count}'**
  String toolChangedFiles(int count);

  /// No description provided for @toolPatchContent.
  ///
  /// In en, this message translates to:
  /// **'Patch'**
  String get toolPatchContent;

  /// No description provided for @toolWaitingPatch.
  ///
  /// In en, this message translates to:
  /// **'Waiting for patch'**
  String get toolWaitingPatch;

  /// No description provided for @toolResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get toolResult;

  /// No description provided for @toolSearchQuery.
  ///
  /// In en, this message translates to:
  /// **'Search query'**
  String get toolSearchQuery;

  /// No description provided for @toolSearchingWeb.
  ///
  /// In en, this message translates to:
  /// **'Searching the web'**
  String get toolSearchingWeb;

  /// No description provided for @toolSearchResults.
  ///
  /// In en, this message translates to:
  /// **'Search results · {count}'**
  String toolSearchResults(int count);

  /// No description provided for @toolNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get toolNoResults;

  /// No description provided for @toolLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get toolLink;

  /// No description provided for @toolContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get toolContent;

  /// No description provided for @toolFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get toolFile;

  /// No description provided for @toolReadingFile.
  ///
  /// In en, this message translates to:
  /// **'Reading file'**
  String get toolReadingFile;

  /// No description provided for @toolWritingFile.
  ///
  /// In en, this message translates to:
  /// **'Writing file'**
  String get toolWritingFile;

  /// No description provided for @toolWriteContent.
  ///
  /// In en, this message translates to:
  /// **'Content to write'**
  String get toolWriteContent;

  /// No description provided for @toolFileList.
  ///
  /// In en, this message translates to:
  /// **'Files · {count}'**
  String toolFileList(int count);

  /// No description provided for @toolNoFiles.
  ///
  /// In en, this message translates to:
  /// **'No files'**
  String get toolNoFiles;

  /// No description provided for @toolDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get toolDetails;

  /// No description provided for @toolNoReadableContent.
  ///
  /// In en, this message translates to:
  /// **'(No readable content)'**
  String get toolNoReadableContent;

  /// No description provided for @toolWaitingForResult.
  ///
  /// In en, this message translates to:
  /// **'Waiting for tool output'**
  String get toolWaitingForResult;

  /// No description provided for @toolUntitledResult.
  ///
  /// In en, this message translates to:
  /// **'Untitled result'**
  String get toolUntitledResult;

  /// No description provided for @toolCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get toolCopyAll;

  /// No description provided for @toolHiddenRestore.
  ///
  /// In en, this message translates to:
  /// **'{name} is hidden; tap to restore'**
  String toolHiddenRestore(String name);

  /// No description provided for @toolReadableView.
  ///
  /// In en, this message translates to:
  /// **'Readable view'**
  String get toolReadableView;

  /// No description provided for @toolRawJsonView.
  ///
  /// In en, this message translates to:
  /// **'Raw JSON view'**
  String get toolRawJsonView;

  /// No description provided for @toolHideRow.
  ///
  /// In en, this message translates to:
  /// **'Hide this tool row'**
  String get toolHideRow;

  /// No description provided for @toolCopyResult.
  ///
  /// In en, this message translates to:
  /// **'Copy result'**
  String get toolCopyResult;

  /// No description provided for @toolRawDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} raw details'**
  String toolRawDetailsTitle(String name);

  /// No description provided for @toolViewRawDetails.
  ///
  /// In en, this message translates to:
  /// **'View raw details'**
  String get toolViewRawDetails;

  /// No description provided for @toolArguments.
  ///
  /// In en, this message translates to:
  /// **'Arguments'**
  String get toolArguments;

  /// No description provided for @toolNoDetailedData.
  ///
  /// In en, this message translates to:
  /// **'(No detailed data)'**
  String get toolNoDetailedData;

  /// No description provided for @toolArgumentDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'{key} argument'**
  String toolArgumentDetailsTitle(String key);

  /// No description provided for @toolTapForFullContent.
  ///
  /// In en, this message translates to:
  /// **'[Tap to view all {count} characters]'**
  String toolTapForFullContent(int count);

  /// No description provided for @toolContentTooLong.
  ///
  /// In en, this message translates to:
  /// **'Content is long ({count} characters)'**
  String toolContentTooLong(int count);

  /// No description provided for @toolFullResultTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} full result'**
  String toolFullResultTitle(String name);

  /// No description provided for @toolViewFull.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get toolViewFull;

  /// No description provided for @kanbanDeleteAttachment.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String kanbanDeleteAttachment(String name);

  /// No description provided for @kanbanCannotUndo.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get kanbanCannotUndo;

  /// No description provided for @kanbanOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {error}'**
  String kanbanOperationFailed(String error);

  /// No description provided for @kanbanNoLog.
  ///
  /// In en, this message translates to:
  /// **'No log available'**
  String get kanbanNoLog;

  /// No description provided for @kanbanAddChildTask.
  ///
  /// In en, this message translates to:
  /// **'Add child task'**
  String get kanbanAddChildTask;

  /// No description provided for @kanbanTaskId.
  ///
  /// In en, this message translates to:
  /// **'Task ID'**
  String get kanbanTaskId;

  /// No description provided for @kanbanDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get kanbanDescription;

  /// No description provided for @kanbanCommandCopied.
  ///
  /// In en, this message translates to:
  /// **'Command copied'**
  String get kanbanCommandCopied;

  /// No description provided for @kanbanViewLog.
  ///
  /// In en, this message translates to:
  /// **'View log'**
  String get kanbanViewLog;

  /// No description provided for @kanbanEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimate'**
  String get kanbanEstimate;

  /// No description provided for @kanbanDecompose.
  ///
  /// In en, this message translates to:
  /// **'Decompose'**
  String get kanbanDecompose;

  /// No description provided for @kanbanNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get kanbanNoDescription;

  /// No description provided for @kanbanDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get kanbanDiagnostics;

  /// No description provided for @kanbanComments.
  ///
  /// In en, this message translates to:
  /// **'Comments ({count})'**
  String kanbanComments(int count);

  /// No description provided for @kanbanAddComment.
  ///
  /// In en, this message translates to:
  /// **'Add comment'**
  String get kanbanAddComment;

  /// No description provided for @kanbanDependencies.
  ///
  /// In en, this message translates to:
  /// **'Dependencies: {parents} parent tasks, {children} child tasks'**
  String kanbanDependencies(int parents, int children);

  /// No description provided for @kanbanChildTask.
  ///
  /// In en, this message translates to:
  /// **'Child task {id}'**
  String kanbanChildTask(String id);

  /// No description provided for @kanbanAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments ({count})'**
  String kanbanAttachments(int count);

  /// No description provided for @kanbanEventTimeline.
  ///
  /// In en, this message translates to:
  /// **'Event timeline ({count})'**
  String kanbanEventTimeline(int count);

  /// No description provided for @kanbanRuns.
  ///
  /// In en, this message translates to:
  /// **'Runs ({count})'**
  String kanbanRuns(int count);

  /// No description provided for @kanbanUploadAttachment.
  ///
  /// In en, this message translates to:
  /// **'Upload attachment'**
  String get kanbanUploadAttachment;

  /// No description provided for @kanbanAttachmentBytes.
  ///
  /// In en, this message translates to:
  /// **'{count} bytes'**
  String kanbanAttachmentBytes(int count);

  /// No description provided for @messageReactionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update reaction: {error}'**
  String messageReactionFailed(String error);

  /// No description provided for @messageRenderFailed.
  ///
  /// In en, this message translates to:
  /// **'This message cannot be displayed'**
  String get messageRenderFailed;

  /// No description provided for @messageRenderFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'Other messages are unaffected'**
  String get messageRenderFailedDescription;

  /// No description provided for @messageRemoveMyReaction.
  ///
  /// In en, this message translates to:
  /// **'Remove my reaction'**
  String get messageRemoveMyReaction;

  /// No description provided for @messageAgentReaction.
  ///
  /// In en, this message translates to:
  /// **'Agent reaction'**
  String get messageAgentReaction;

  /// No description provided for @messageAddReaction.
  ///
  /// In en, this message translates to:
  /// **'Add reaction'**
  String get messageAddReaction;

  /// No description provided for @messageSearchEmoji.
  ///
  /// In en, this message translates to:
  /// **'Search emoji'**
  String get messageSearchEmoji;

  /// No description provided for @messageImageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save image: {error}'**
  String messageImageSaveFailed(String error);

  /// No description provided for @messageGeneratingImage.
  ///
  /// In en, this message translates to:
  /// **'Generating image...'**
  String get messageGeneratingImage;

  /// No description provided for @messageImageGenerationFailed.
  ///
  /// In en, this message translates to:
  /// **'Image generation failed'**
  String get messageImageGenerationFailed;

  /// No description provided for @messageWaitingForImage.
  ///
  /// In en, this message translates to:
  /// **'Waiting for image result'**
  String get messageWaitingForImage;

  /// No description provided for @messageGeneratedImage.
  ///
  /// In en, this message translates to:
  /// **'Generated image'**
  String get messageGeneratedImage;

  /// No description provided for @messageImageLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Image link copied'**
  String get messageImageLinkCopied;

  /// No description provided for @messageOpenInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get messageOpenInBrowser;

  /// No description provided for @messageMcpSetup.
  ///
  /// In en, this message translates to:
  /// **'MCP server setup'**
  String get messageMcpSetup;

  /// No description provided for @messageMcpServer.
  ///
  /// In en, this message translates to:
  /// **'MCP · {server}'**
  String messageMcpServer(String server);

  /// No description provided for @messageMcpSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Setup failed; retry in MCP settings'**
  String get messageMcpSetupFailed;

  /// No description provided for @messageMcpSetupWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for setup to complete'**
  String get messageMcpSetupWaiting;

  /// No description provided for @messageMcpSetupComplete.
  ///
  /// In en, this message translates to:
  /// **'Setup complete'**
  String get messageMcpSetupComplete;

  /// No description provided for @messageOpenMcpSettings.
  ///
  /// In en, this message translates to:
  /// **'Open MCP settings'**
  String get messageOpenMcpSettings;

  /// No description provided for @messageFileChanges.
  ///
  /// In en, this message translates to:
  /// **'File changes'**
  String get messageFileChanges;

  /// No description provided for @messageViewDiff.
  ///
  /// In en, this message translates to:
  /// **'View diff'**
  String get messageViewDiff;

  /// No description provided for @messageOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get messageOpenLink;

  /// No description provided for @messageSendingToAgent.
  ///
  /// In en, this message translates to:
  /// **'Sending to {name}...'**
  String messageSendingToAgent(String name);

  /// No description provided for @messageSentToAgent.
  ///
  /// In en, this message translates to:
  /// **'Sent to {name}'**
  String messageSentToAgent(String name);

  /// No description provided for @messageReplyFromAgent.
  ///
  /// In en, this message translates to:
  /// **'Reply from {name}'**
  String messageReplyFromAgent(String name);

  /// No description provided for @messageRepliedToAgent.
  ///
  /// In en, this message translates to:
  /// **'Replied to {name}'**
  String messageRepliedToAgent(String name);

  /// No description provided for @messageFromAgent.
  ///
  /// In en, this message translates to:
  /// **'From agent · {name}'**
  String messageFromAgent(String name);

  /// No description provided for @messageSteered.
  ///
  /// In en, this message translates to:
  /// **'Steered'**
  String get messageSteered;

  /// No description provided for @messageHermesAvatar.
  ///
  /// In en, this message translates to:
  /// **'Hermes assistant avatar'**
  String get messageHermesAvatar;

  /// No description provided for @messageSourceWechat.
  ///
  /// In en, this message translates to:
  /// **'WeChat'**
  String get messageSourceWechat;

  /// No description provided for @messageSourceFeishu.
  ///
  /// In en, this message translates to:
  /// **'Feishu'**
  String get messageSourceFeishu;

  /// No description provided for @messageSourceDesktop.
  ///
  /// In en, this message translates to:
  /// **'Desktop'**
  String get messageSourceDesktop;

  /// No description provided for @messageRestoreVersion.
  ///
  /// In en, this message translates to:
  /// **'Restore this version'**
  String get messageRestoreVersion;

  /// No description provided for @messagePreviousVersion.
  ///
  /// In en, this message translates to:
  /// **'Previous version'**
  String get messagePreviousVersion;

  /// No description provided for @messageNextVersion.
  ///
  /// In en, this message translates to:
  /// **'Next version'**
  String get messageNextVersion;

  /// No description provided for @messageCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get messageCopyText;

  /// No description provided for @messageCopyMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Copy as Markdown'**
  String get messageCopyMarkdown;

  /// No description provided for @messageBranchFromHere.
  ///
  /// In en, this message translates to:
  /// **'Branch from this message'**
  String get messageBranchFromHere;

  /// No description provided for @messageSpeakDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Connect to the server to read this message aloud'**
  String get messageSpeakDisconnected;

  /// No description provided for @messageSpeakFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play speech. Try again.'**
  String get messageSpeakFailed;

  /// No description provided for @messageStopSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Stop reading'**
  String get messageStopSpeaking;

  /// No description provided for @messageSpeak.
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get messageSpeak;

  /// No description provided for @sessionDetailMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get sessionDetailMessages;

  /// No description provided for @sessionDetailTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get sessionDetailTools;

  /// No description provided for @sessionDetailEstimated.
  ///
  /// In en, this message translates to:
  /// **'Estimated'**
  String get sessionDetailEstimated;

  /// No description provided for @sessionDetailCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get sessionDetailCost;

  /// No description provided for @sessionDetailDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get sessionDetailDuration;

  /// No description provided for @sessionDetailInfo.
  ///
  /// In en, this message translates to:
  /// **'Session information'**
  String get sessionDetailInfo;

  /// No description provided for @sessionDetailSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get sessionDetailSource;

  /// No description provided for @sessionDetailModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get sessionDetailModel;

  /// No description provided for @sessionDetailStarted.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get sessionDetailStarted;

  /// No description provided for @sessionDetailLastActivity.
  ///
  /// In en, this message translates to:
  /// **'Last activity'**
  String get sessionDetailLastActivity;

  /// No description provided for @sessionDetailEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get sessionDetailEnded;

  /// No description provided for @sessionDetailEndReason.
  ///
  /// In en, this message translates to:
  /// **'End reason'**
  String get sessionDetailEndReason;

  /// No description provided for @sessionDetailHandoff.
  ///
  /// In en, this message translates to:
  /// **'Handoff'**
  String get sessionDetailHandoff;

  /// No description provided for @sessionDetailHandoffError.
  ///
  /// In en, this message translates to:
  /// **'Handoff error'**
  String get sessionDetailHandoffError;

  /// No description provided for @sessionDetailTokensBilling.
  ///
  /// In en, this message translates to:
  /// **'Tokens and billing'**
  String get sessionDetailTokensBilling;

  /// No description provided for @sessionDetailInputOutput.
  ///
  /// In en, this message translates to:
  /// **'Input / output'**
  String get sessionDetailInputOutput;

  /// No description provided for @sessionDetailCacheReadWrite.
  ///
  /// In en, this message translates to:
  /// **'Cache read / write'**
  String get sessionDetailCacheReadWrite;

  /// No description provided for @sessionDetailReasoningTokens.
  ///
  /// In en, this message translates to:
  /// **'Reasoning tokens'**
  String get sessionDetailReasoningTokens;

  /// No description provided for @sessionDetailBillingSource.
  ///
  /// In en, this message translates to:
  /// **'Billing source'**
  String get sessionDetailBillingSource;

  /// No description provided for @sessionDetailContextSource.
  ///
  /// In en, this message translates to:
  /// **'Context and source'**
  String get sessionDetailContextSource;

  /// No description provided for @sessionDetailWorkingDirectory.
  ///
  /// In en, this message translates to:
  /// **'Working directory'**
  String get sessionDetailWorkingDirectory;

  /// No description provided for @sessionDetailGitBranch.
  ///
  /// In en, this message translates to:
  /// **'Git branch'**
  String get sessionDetailGitBranch;

  /// No description provided for @sessionDetailContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get sessionDetailContact;

  /// No description provided for @sessionDetailChatType.
  ///
  /// In en, this message translates to:
  /// **'Chat type'**
  String get sessionDetailChatType;

  /// No description provided for @sessionDetailUserId.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get sessionDetailUserId;

  /// No description provided for @sessionDetailParentSession.
  ///
  /// In en, this message translates to:
  /// **'Parent session'**
  String get sessionDetailParentSession;

  /// No description provided for @sessionDetailRewindCount.
  ///
  /// In en, this message translates to:
  /// **'Rewind count'**
  String get sessionDetailRewindCount;

  /// No description provided for @sessionDetailCompressionFailed.
  ///
  /// In en, this message translates to:
  /// **'Compression temporarily failed'**
  String get sessionDetailCompressionFailed;

  /// No description provided for @sessionDetailOpen.
  ///
  /// In en, this message translates to:
  /// **'Open session'**
  String get sessionDetailOpen;

  /// No description provided for @sessionActionOpenWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Open in workspace'**
  String get sessionActionOpenWorkspace;

  /// No description provided for @sessionActionUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get sessionActionUnpin;

  /// No description provided for @sessionActionPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get sessionActionPin;

  /// No description provided for @sessionActionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get sessionActionAppearance;

  /// No description provided for @sessionActionDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate session'**
  String get sessionActionDuplicate;

  /// No description provided for @sessionActionShare.
  ///
  /// In en, this message translates to:
  /// **'Share session'**
  String get sessionActionShare;

  /// No description provided for @sessionActionExport.
  ///
  /// In en, this message translates to:
  /// **'Export session'**
  String get sessionActionExport;

  /// No description provided for @sessionActionMoveProject.
  ///
  /// In en, this message translates to:
  /// **'Move to project'**
  String get sessionActionMoveProject;

  /// No description provided for @sessionActionUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get sessionActionUnarchive;

  /// No description provided for @sessionActionArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get sessionActionArchive;

  /// No description provided for @sessionActionStopResponse.
  ///
  /// In en, this message translates to:
  /// **'Stop response'**
  String get sessionActionStopResponse;

  /// No description provided for @sessionActionAppearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Session appearance'**
  String get sessionActionAppearanceTitle;

  /// No description provided for @sessionActionRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not rename session: {error}'**
  String sessionActionRenameFailed(String error);

  /// No description provided for @sessionActionUnarchived.
  ///
  /// In en, this message translates to:
  /// **'Session unarchived'**
  String get sessionActionUnarchived;

  /// No description provided for @sessionActionArchived.
  ///
  /// In en, this message translates to:
  /// **'Session archived'**
  String get sessionActionArchived;

  /// No description provided for @sessionActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {error}'**
  String sessionActionFailed(String error);

  /// No description provided for @sessionActionUnpinned.
  ///
  /// In en, this message translates to:
  /// **'Session unpinned'**
  String get sessionActionUnpinned;

  /// No description provided for @sessionActionPinned.
  ///
  /// In en, this message translates to:
  /// **'Session pinned'**
  String get sessionActionPinned;

  /// No description provided for @sessionActionMoved.
  ///
  /// In en, this message translates to:
  /// **'Session moved'**
  String get sessionActionMoved;

  /// No description provided for @sessionActionMoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not move session: {error}'**
  String sessionActionMoveFailed(String error);

  /// No description provided for @sessionActionBranchCreated.
  ///
  /// In en, this message translates to:
  /// **'Branch created: {id}'**
  String sessionActionBranchCreated(String id);

  /// No description provided for @sessionActionCopyCreated.
  ///
  /// In en, this message translates to:
  /// **'Session copy created'**
  String get sessionActionCopyCreated;

  /// No description provided for @sessionActionDuplicateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not duplicate session: {error}'**
  String sessionActionDuplicateFailed(String error);

  /// No description provided for @sessionActionShareCreated.
  ///
  /// In en, this message translates to:
  /// **'Share link created'**
  String get sessionActionShareCreated;

  /// No description provided for @sessionActionShareWarning.
  ///
  /// In en, this message translates to:
  /// **'Anyone with this link can view the session.'**
  String get sessionActionShareWarning;

  /// No description provided for @sessionActionShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not share session: {error}'**
  String sessionActionShareFailed(String error);

  /// No description provided for @sessionActionStopRequested.
  ///
  /// In en, this message translates to:
  /// **'Stop requested'**
  String get sessionActionStopRequested;

  /// No description provided for @sessionActionExportMarkdownHint.
  ///
  /// In en, this message translates to:
  /// **'Good for viewing and sharing'**
  String get sessionActionExportMarkdownHint;

  /// No description provided for @sessionActionExportJsonHint.
  ///
  /// In en, this message translates to:
  /// **'Preserves all structured data'**
  String get sessionActionExportJsonHint;

  /// No description provided for @sessionActionExportCopiedWeb.
  ///
  /// In en, this message translates to:
  /// **'Export copied to clipboard because web cannot save local files'**
  String get sessionActionExportCopiedWeb;

  /// No description provided for @sessionActionExported.
  ///
  /// In en, this message translates to:
  /// **'Exported to {path}; path copied'**
  String sessionActionExported(String path);

  /// No description provided for @sessionActionExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export session: {error}'**
  String sessionActionExportFailed(String error);

  /// No description provided for @sessionsNoDetail.
  ///
  /// In en, this message translates to:
  /// **'No session details'**
  String get sessionsNoDetail;

  /// No description provided for @sessionsNoDetailDescription.
  ///
  /// In en, this message translates to:
  /// **'Adjust the filters to view a session summary'**
  String get sessionsNoDetailDescription;

  /// No description provided for @sessionsAllProjects.
  ///
  /// In en, this message translates to:
  /// **'All projects'**
  String get sessionsAllProjects;

  /// No description provided for @sessionsProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get sessionsProject;

  /// No description provided for @sessionsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search titles, previews, or working directories...'**
  String get sessionsSearchHint;

  /// No description provided for @sessionsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get sessionsToday;

  /// No description provided for @sessionsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get sessionsThisWeek;

  /// No description provided for @sessionsStarred.
  ///
  /// In en, this message translates to:
  /// **'Starred'**
  String get sessionsStarred;

  /// No description provided for @sessionsSortNewest.
  ///
  /// In en, this message translates to:
  /// **'Time: newest first'**
  String get sessionsSortNewest;

  /// No description provided for @sessionsSortOldest.
  ///
  /// In en, this message translates to:
  /// **'Time: oldest first'**
  String get sessionsSortOldest;

  /// No description provided for @sessionsSortTitle.
  ///
  /// In en, this message translates to:
  /// **'Title: A-Z'**
  String get sessionsSortTitle;

  /// No description provided for @sessionsSortMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages: most first'**
  String get sessionsSortMessages;

  /// No description provided for @sessionsSortMethod.
  ///
  /// In en, this message translates to:
  /// **'Sort method'**
  String get sessionsSortMethod;

  /// No description provided for @sessionsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading sessions...'**
  String get sessionsLoading;

  /// No description provided for @sessionsViewFullDetails.
  ///
  /// In en, this message translates to:
  /// **'View full details'**
  String get sessionsViewFullDetails;

  /// No description provided for @sessionsSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get sessionsSettings;

  /// No description provided for @requestHermesQuestion.
  ///
  /// In en, this message translates to:
  /// **'Hermes question'**
  String get requestHermesQuestion;

  /// No description provided for @requestPending.
  ///
  /// In en, this message translates to:
  /// **'Pending request'**
  String get requestPending;

  /// No description provided for @requestAlwaysAllowQuestion.
  ///
  /// In en, this message translates to:
  /// **'Always allow?'**
  String get requestAlwaysAllowQuestion;

  /// No description provided for @requestAlwaysAllowDescription.
  ///
  /// In en, this message translates to:
  /// **'This operation will be added to the configuration as a permanent allow rule. Similar operations will no longer ask.'**
  String get requestAlwaysAllowDescription;

  /// No description provided for @requestAlwaysAllowDetail.
  ///
  /// In en, this message translates to:
  /// **'“{detail}” will be added to the configuration as a permanent allow rule. Similar operations will no longer ask.'**
  String requestAlwaysAllowDetail(String detail);

  /// No description provided for @requestNoActiveSession.
  ///
  /// In en, this message translates to:
  /// **'No active session'**
  String get requestNoActiveSession;

  /// No description provided for @requestConnectionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The request connection is unavailable'**
  String get requestConnectionUnavailable;

  /// No description provided for @requestRespondFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not respond: {error}'**
  String requestRespondFailed(String error);

  /// No description provided for @requestAnswerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the answer. Try again.'**
  String get requestAnswerFailed;

  /// No description provided for @requestMcpNameMissing.
  ///
  /// In en, this message translates to:
  /// **'The request has no MCP server name'**
  String get requestMcpNameMissing;

  /// No description provided for @requestOAuthTimeout.
  ///
  /// In en, this message translates to:
  /// **'OAuth authorization timed out'**
  String get requestOAuthTimeout;

  /// No description provided for @requestMcpTestFailed.
  ///
  /// In en, this message translates to:
  /// **'MCP connection test failed'**
  String get requestMcpTestFailed;

  /// No description provided for @requestMcpSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'MCP setup failed'**
  String get requestMcpSetupFailed;

  /// No description provided for @requestConfigureMcp.
  ///
  /// In en, this message translates to:
  /// **'Configure {name}'**
  String requestConfigureMcp(String name);

  /// No description provided for @requestCloseQuestion.
  ///
  /// In en, this message translates to:
  /// **'Close request?'**
  String get requestCloseQuestion;

  /// No description provided for @requestCloseDescription.
  ///
  /// In en, this message translates to:
  /// **'This request cannot be restored after closing, and the agent will remain waiting.'**
  String get requestCloseDescription;

  /// No description provided for @requestProcessed.
  ///
  /// In en, this message translates to:
  /// **'Processed'**
  String get requestProcessed;

  /// No description provided for @requestInteractionProcessed.
  ///
  /// In en, this message translates to:
  /// **'Interactive request processed'**
  String get requestInteractionProcessed;

  /// No description provided for @requestServer.
  ///
  /// In en, this message translates to:
  /// **'Server: {name}'**
  String requestServer(String name);

  /// No description provided for @requestSubmitAllAnswers.
  ///
  /// In en, this message translates to:
  /// **'Submit all answers'**
  String get requestSubmitAllAnswers;

  /// No description provided for @requestConfigureLater.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get requestConfigureLater;

  /// No description provided for @requestConfiguring.
  ///
  /// In en, this message translates to:
  /// **'Configuring...'**
  String get requestConfiguring;

  /// No description provided for @requestInstallEnable.
  ///
  /// In en, this message translates to:
  /// **'Install and enable'**
  String get requestInstallEnable;

  /// No description provided for @requestEnterContent.
  ///
  /// In en, this message translates to:
  /// **'Enter content'**
  String get requestEnterContent;

  /// No description provided for @requestEnterText.
  ///
  /// In en, this message translates to:
  /// **'Enter...'**
  String get requestEnterText;

  /// No description provided for @requestMorePending.
  ///
  /// In en, this message translates to:
  /// **'{count} more pending'**
  String requestMorePending(int count);

  /// No description provided for @requestAllowOnce.
  ///
  /// In en, this message translates to:
  /// **'Allow once'**
  String get requestAllowOnce;

  /// No description provided for @requestAllowSession.
  ///
  /// In en, this message translates to:
  /// **'Allow for this session'**
  String get requestAllowSession;

  /// No description provided for @requestSubmitSelected.
  ///
  /// In en, this message translates to:
  /// **'Submit ({count} selected)'**
  String requestSubmitSelected(int count);

  /// No description provided for @requestCustomAnswer.
  ///
  /// In en, this message translates to:
  /// **'Other (custom answer)'**
  String get requestCustomAnswer;

  /// No description provided for @requestRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get requestRecommended;

  /// No description provided for @messagingLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load messaging platforms: {error}'**
  String messagingLoadFailed(String error);

  /// No description provided for @messagingPlatformEnabled.
  ///
  /// In en, this message translates to:
  /// **'{name} enabled'**
  String messagingPlatformEnabled(String name);

  /// No description provided for @messagingPlatformDisabled.
  ///
  /// In en, this message translates to:
  /// **'{name} disabled'**
  String messagingPlatformDisabled(String name);

  /// No description provided for @messagingUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed: {error}'**
  String messagingUpdateFailed(String error);

  /// No description provided for @messagingTestPassed.
  ///
  /// In en, this message translates to:
  /// **'{name} connection test passed'**
  String messagingTestPassed(String name);

  /// No description provided for @messagingTestNotPassed.
  ///
  /// In en, this message translates to:
  /// **'Connection test did not pass'**
  String get messagingTestNotPassed;

  /// No description provided for @messagingTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Test failed: {error}'**
  String messagingTestFailed(String error);

  /// No description provided for @messagingConfigSaved.
  ///
  /// In en, this message translates to:
  /// **'{name} configuration saved. Restart Gateway to apply connection changes.'**
  String messagingConfigSaved(String name);

  /// No description provided for @messagingSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String messagingSaveFailed(String error);

  /// No description provided for @messagingApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved {name}'**
  String messagingApproved(String name);

  /// No description provided for @messagingApproveFailed.
  ///
  /// In en, this message translates to:
  /// **'Approval failed: {error}'**
  String messagingApproveFailed(String error);

  /// No description provided for @messagingRevokeTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke access'**
  String get messagingRevokeTitle;

  /// No description provided for @messagingRevokeQuestion.
  ///
  /// In en, this message translates to:
  /// **'Revoke messaging access for {name}?'**
  String messagingRevokeQuestion(String name);

  /// No description provided for @messagingRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get messagingRevoke;

  /// No description provided for @messagingRevoked.
  ///
  /// In en, this message translates to:
  /// **'Access revoked'**
  String get messagingRevoked;

  /// No description provided for @messagingRevokeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not revoke access: {error}'**
  String messagingRevokeFailed(String error);

  /// No description provided for @messagingRestartQuestion.
  ///
  /// In en, this message translates to:
  /// **'Restart Gateway?'**
  String get messagingRestartQuestion;

  /// No description provided for @messagingRestartWarning.
  ///
  /// In en, this message translates to:
  /// **'This interrupts all sessions and clients connected to this Gateway. They will reconnect automatically after it completes.'**
  String get messagingRestartWarning;

  /// No description provided for @messagingRestarting.
  ///
  /// In en, this message translates to:
  /// **'Gateway is restarting'**
  String get messagingRestarting;

  /// No description provided for @messagingRestartFailed.
  ///
  /// In en, this message translates to:
  /// **'Gateway restart failed: {error}'**
  String messagingRestartFailed(String error);

  /// No description provided for @messagingTitle.
  ///
  /// In en, this message translates to:
  /// **'Messaging platforms'**
  String get messagingTitle;

  /// No description provided for @messagingRestartGateway.
  ///
  /// In en, this message translates to:
  /// **'Restart Gateway'**
  String get messagingRestartGateway;

  /// No description provided for @messagingLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading messaging platforms...'**
  String get messagingLoading;

  /// No description provided for @messagingPendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Pending approval'**
  String get messagingPendingApproval;

  /// No description provided for @messagingPlatforms.
  ///
  /// In en, this message translates to:
  /// **'Platforms'**
  String get messagingPlatforms;

  /// No description provided for @messagingEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messaging platforms'**
  String get messagingEmpty;

  /// No description provided for @messagingEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'The server returned no configurable messaging platforms'**
  String get messagingEmptyDescription;

  /// No description provided for @messagingAuthorizedUsers.
  ///
  /// In en, this message translates to:
  /// **'Authorized users'**
  String get messagingAuthorizedUsers;

  /// No description provided for @messagingConfigure.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get messagingConfigure;

  /// No description provided for @messagingTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get messagingTest;

  /// No description provided for @messagingOpenDocs.
  ///
  /// In en, this message translates to:
  /// **'Open documentation'**
  String get messagingOpenDocs;

  /// No description provided for @messagingUnknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown user'**
  String get messagingUnknownUser;

  /// No description provided for @messagingApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get messagingApprove;

  /// No description provided for @messagingStateDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get messagingStateDisabled;

  /// No description provided for @messagingStateGatewayStopped.
  ///
  /// In en, this message translates to:
  /// **'Configured; Gateway not running'**
  String get messagingStateGatewayStopped;

  /// No description provided for @messagingStateFatal.
  ///
  /// In en, this message translates to:
  /// **'Fatal error'**
  String get messagingStateFatal;

  /// No description provided for @messagingStateStartupFailed.
  ///
  /// In en, this message translates to:
  /// **'Startup failed'**
  String get messagingStateStartupFailed;

  /// No description provided for @messagingStateConfigured.
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get messagingStateConfigured;

  /// No description provided for @messagingStateNeedsConfig.
  ///
  /// In en, this message translates to:
  /// **'Needs configuration'**
  String get messagingStateNeedsConfig;

  /// No description provided for @messagingPlatformConfig.
  ///
  /// In en, this message translates to:
  /// **'{name} configuration'**
  String messagingPlatformConfig(String name);

  /// No description provided for @messagingNoEditableConfig.
  ///
  /// In en, this message translates to:
  /// **'This platform has no editable settings.'**
  String get messagingNoEditableConfig;

  /// No description provided for @messagingAdvancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced settings'**
  String get messagingAdvancedSettings;

  /// No description provided for @messagingSetLeaveBlank.
  ///
  /// In en, this message translates to:
  /// **'Set; leave blank to keep unchanged'**
  String get messagingSetLeaveBlank;

  /// No description provided for @messagingEnterNewValue.
  ///
  /// In en, this message translates to:
  /// **'Enter a new value'**
  String get messagingEnterNewValue;

  /// No description provided for @messagingShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get messagingShow;

  /// No description provided for @messagingClearSavedValue.
  ///
  /// In en, this message translates to:
  /// **'Clear saved value'**
  String get messagingClearSavedValue;

  /// No description provided for @fileTreeListView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get fileTreeListView;

  /// No description provided for @fileTreeTreeView.
  ///
  /// In en, this message translates to:
  /// **'Tree view'**
  String get fileTreeTreeView;

  /// No description provided for @fileTreeAttachToChat.
  ///
  /// In en, this message translates to:
  /// **'Attach to chat'**
  String get fileTreeAttachToChat;

  /// No description provided for @projectAddFolder.
  ///
  /// In en, this message translates to:
  /// **'Add folder'**
  String get projectAddFolder;

  /// No description provided for @projectFolderPath.
  ///
  /// In en, this message translates to:
  /// **'Folder path'**
  String get projectFolderPath;

  /// No description provided for @projectFolderLabelOptional.
  ///
  /// In en, this message translates to:
  /// **'Label (optional)'**
  String get projectFolderLabelOptional;

  /// No description provided for @projectCreate.
  ///
  /// In en, this message translates to:
  /// **'Create project'**
  String get projectCreate;

  /// No description provided for @projectLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading projects...'**
  String get projectLoading;

  /// No description provided for @projectEmpty.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get projectEmpty;

  /// No description provided for @projectEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a project to organize working directories and sessions'**
  String get projectEmptyDescription;

  /// No description provided for @projectWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Project workspace'**
  String get projectWorkspace;

  /// No description provided for @projectEditAppearance.
  ///
  /// In en, this message translates to:
  /// **'Edit appearance'**
  String get projectEditAppearance;

  /// No description provided for @projectColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get projectColor;

  /// No description provided for @projectIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get projectIcon;

  /// No description provided for @projectAppearanceSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save appearance: {error}'**
  String projectAppearanceSaveFailed(String error);

  /// No description provided for @projectRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get projectRename;

  /// No description provided for @projectRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename project'**
  String get projectRenameTitle;

  /// No description provided for @projectName.
  ///
  /// In en, this message translates to:
  /// **'Project name'**
  String get projectName;

  /// No description provided for @projectRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not rename project: {error}'**
  String projectRenameFailed(String error);

  /// No description provided for @projectDeleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String projectDeleteQuestion(String name);

  /// No description provided for @projectDeleteDescription.
  ///
  /// In en, this message translates to:
  /// **'The project will be deleted, but its sessions and files will not be affected. This cannot be undone.'**
  String get projectDeleteDescription;

  /// No description provided for @projectDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete project: {error}'**
  String projectDeleteFailed(String error);

  /// No description provided for @projectCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create project: {error}'**
  String projectCreateFailed(String error);

  /// No description provided for @projectManagement.
  ///
  /// In en, this message translates to:
  /// **'Manage projects'**
  String get projectManagement;

  /// No description provided for @projectLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load projects'**
  String get projectLoadFailed;

  /// No description provided for @projectNoMoveTargets.
  ///
  /// In en, this message translates to:
  /// **'No other eligible projects'**
  String get projectNoMoveTargets;

  /// No description provided for @projectNoMoveTargetsDescription.
  ///
  /// In en, this message translates to:
  /// **'A project needs a valid working directory before it can receive sessions'**
  String get projectNoMoveTargetsDescription;

  /// No description provided for @projectNew.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get projectNew;

  /// No description provided for @projectEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit project'**
  String get projectEditTitle;

  /// No description provided for @projectPrimaryPath.
  ///
  /// In en, this message translates to:
  /// **'Primary working directory'**
  String get projectPrimaryPath;

  /// No description provided for @projectPrimaryPathHint.
  ///
  /// In en, this message translates to:
  /// **'For example, /home/user/projects/my-app'**
  String get projectPrimaryPathHint;

  /// No description provided for @projectDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get projectDescriptionOptional;

  /// No description provided for @projectRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Enter a project name and working directory'**
  String get projectRequiredFields;

  /// No description provided for @projectCreated.
  ///
  /// In en, this message translates to:
  /// **'Project created'**
  String get projectCreated;

  /// No description provided for @projectUpdated.
  ///
  /// In en, this message translates to:
  /// **'Project updated'**
  String get projectUpdated;

  /// No description provided for @projectSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save project: {error}'**
  String projectSaveFailed(String error);

  /// No description provided for @projectDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete project?'**
  String get projectDeleteTitle;

  /// No description provided for @projectDeleteNamedDescription.
  ///
  /// In en, this message translates to:
  /// **'Project \"{name}\" will be deleted. Associated sessions will not be deleted.'**
  String projectDeleteNamedDescription(String name);

  /// No description provided for @projectDeleted.
  ///
  /// In en, this message translates to:
  /// **'Project deleted'**
  String get projectDeleted;

  /// No description provided for @subagentsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load subagents: {error}'**
  String subagentsLoadFailed(String error);

  /// No description provided for @subagentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No subagent activity'**
  String get subagentsEmpty;

  /// No description provided for @subagentsOpenSessionDescription.
  ///
  /// In en, this message translates to:
  /// **'Open a session to view its subagent tree'**
  String get subagentsOpenSessionDescription;

  /// No description provided for @subagentsCurrentSessionEmpty.
  ///
  /// In en, this message translates to:
  /// **'The current session has no running subagents'**
  String get subagentsCurrentSessionEmpty;

  /// No description provided for @subagentsCurrentSession.
  ///
  /// In en, this message translates to:
  /// **'Current session'**
  String get subagentsCurrentSession;

  /// No description provided for @subagentsSession.
  ///
  /// In en, this message translates to:
  /// **'Session {id}'**
  String subagentsSession(String id);

  /// No description provided for @subagentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} subagents'**
  String subagentsCount(int count);

  /// No description provided for @subagentsRunningCount.
  ///
  /// In en, this message translates to:
  /// **'{count} running'**
  String subagentsRunningCount(int count);

  /// No description provided for @subagentsFailedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} failed'**
  String subagentsFailedCount(int count);

  /// No description provided for @subagentsToolCalls.
  ///
  /// In en, this message translates to:
  /// **'{count} tool calls'**
  String subagentsToolCalls(int count);

  /// No description provided for @subagentsFiles.
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String subagentsFiles(int count);

  /// No description provided for @subagentsInterrupt.
  ///
  /// In en, this message translates to:
  /// **'Interrupt'**
  String get subagentsInterrupt;

  /// No description provided for @subagentsInterruptSent.
  ///
  /// In en, this message translates to:
  /// **'Interrupt signal sent'**
  String get subagentsInterruptSent;

  /// No description provided for @subagentsInterruptFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not interrupt subagent: {error}'**
  String subagentsInterruptFailed(String error);

  /// No description provided for @subagentsOpenSession.
  ///
  /// In en, this message translates to:
  /// **'Open session'**
  String get subagentsOpenSession;

  /// No description provided for @subagentsOpenSessionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open subagent session: {error}'**
  String subagentsOpenSessionFailed(String error);

  /// No description provided for @subagentsCurrentTool.
  ///
  /// In en, this message translates to:
  /// **'Tool: {name}'**
  String subagentsCurrentTool(String name);

  /// No description provided for @subagentsTools.
  ///
  /// In en, this message translates to:
  /// **'{count} tools'**
  String subagentsTools(int count);

  /// No description provided for @subagentsFilesRead.
  ///
  /// In en, this message translates to:
  /// **'{count} read'**
  String subagentsFilesRead(int count);

  /// No description provided for @subagentsFilesWritten.
  ///
  /// In en, this message translates to:
  /// **'{count} written'**
  String subagentsFilesWritten(int count);

  /// No description provided for @subagentsStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get subagentsStatusQueued;

  /// No description provided for @subagentsStatusInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Interrupted'**
  String get subagentsStatusInterrupted;

  /// No description provided for @subagentsStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get subagentsStatusUnknown;

  /// No description provided for @credentialsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load credentials: {error}'**
  String credentialsLoadFailed(String error);

  /// No description provided for @credentialsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search credentials or providers...'**
  String get credentialsSearchHint;

  /// No description provided for @credentialsMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get credentialsMissing;

  /// No description provided for @credentialsNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching credentials'**
  String get credentialsNoMatches;

  /// No description provided for @credentialsNoMatchesDescription.
  ///
  /// In en, this message translates to:
  /// **'Adjust the search or status filter'**
  String get credentialsNoMatchesDescription;

  /// No description provided for @credentialsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No credential providers'**
  String get credentialsEmpty;

  /// No description provided for @credentialsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'The server did not return any configurable credential providers'**
  String get credentialsEmptyDescription;

  /// No description provided for @credentialsGroupCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud providers'**
  String get credentialsGroupCloud;

  /// No description provided for @credentialsGroupModelProviders.
  ///
  /// In en, this message translates to:
  /// **'Model providers'**
  String get credentialsGroupModelProviders;

  /// No description provided for @credentialsGroupThirdParty.
  ///
  /// In en, this message translates to:
  /// **'Third-party services'**
  String get credentialsGroupThirdParty;

  /// No description provided for @credentialsKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a provider and enter an API key or token'**
  String get credentialsKeyRequired;

  /// No description provided for @credentialsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save credential: {error}'**
  String credentialsSaveFailed(String error);

  /// No description provided for @credentialsAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add credential'**
  String get credentialsAddTitle;

  /// No description provided for @credentialsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit credential'**
  String get credentialsEditTitle;

  /// No description provided for @credentialsSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get credentialsSaving;

  /// No description provided for @credentialsApiKey.
  ///
  /// In en, this message translates to:
  /// **'{name} API key / token'**
  String credentialsApiKey(String name);

  /// No description provided for @credentialsShowKey.
  ///
  /// In en, this message translates to:
  /// **'Show key'**
  String get credentialsShowKey;

  /// No description provided for @credentialsHideKey.
  ///
  /// In en, this message translates to:
  /// **'Hide key'**
  String get credentialsHideKey;

  /// No description provided for @petCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Pet center'**
  String get petCenterTitle;

  /// No description provided for @petRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get petRename;

  /// No description provided for @petDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable pet'**
  String get petDisable;

  /// No description provided for @petRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not rename pet: {error}'**
  String petRenameFailed(String error);

  /// No description provided for @petDisableFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not disable pet: {error}'**
  String petDisableFailed(String error);

  /// No description provided for @petRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename pet'**
  String get petRenameTitle;

  /// No description provided for @petRenameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a new name...'**
  String get petRenameHint;

  /// No description provided for @petUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get petUntitled;

  /// No description provided for @petStatus.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String petStatus(String status);

  /// No description provided for @petGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get petGallery;

  /// No description provided for @petGalleryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pets available'**
  String get petGalleryEmpty;

  /// No description provided for @petGenerateNew.
  ///
  /// In en, this message translates to:
  /// **'Generate new pet'**
  String get petGenerateNew;

  /// No description provided for @petStateWave.
  ///
  /// In en, this message translates to:
  /// **'Waving'**
  String get petStateWave;

  /// No description provided for @petStateJump.
  ///
  /// In en, this message translates to:
  /// **'Jumping'**
  String get petStateJump;

  /// No description provided for @petStateCelebrate.
  ///
  /// In en, this message translates to:
  /// **'Celebrating'**
  String get petStateCelebrate;

  /// No description provided for @credentialsDisconnectQuestion.
  ///
  /// In en, this message translates to:
  /// **'Disconnect {name}?'**
  String credentialsDisconnectQuestion(String name);

  /// No description provided for @credentialsDisconnectDescription.
  ///
  /// In en, this message translates to:
  /// **'The saved credential will be removed from the Hermes server. You can add it again later.'**
  String get credentialsDisconnectDescription;

  /// No description provided for @starmapLoadDetailFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load node details: {error}'**
  String starmapLoadDetailFailed(String error);

  /// No description provided for @starmapRestoreMine.
  ///
  /// In en, this message translates to:
  /// **'Restore my starmap'**
  String get starmapRestoreMine;

  /// No description provided for @starmapShareImport.
  ///
  /// In en, this message translates to:
  /// **'Share or import'**
  String get starmapShareImport;

  /// No description provided for @starmapResetView.
  ///
  /// In en, this message translates to:
  /// **'Reset view'**
  String get starmapResetView;

  /// No description provided for @starmapLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading starmap...'**
  String get starmapLoading;

  /// No description provided for @starmapNoData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get starmapNoData;

  /// No description provided for @starmapEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your starmap is empty'**
  String get starmapEmpty;

  /// No description provided for @starmapEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'As Hermes learns more, knowledge nodes will appear here.'**
  String get starmapEmptyDescription;

  /// No description provided for @starmapShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share starmap'**
  String get starmapShareTitle;

  /// No description provided for @starmapShareDescription.
  ///
  /// In en, this message translates to:
  /// **'Copy this code to share your starmap, or paste another code and load it.'**
  String get starmapShareDescription;

  /// No description provided for @starmapShareCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Starmap share code'**
  String get starmapShareCodeHint;

  /// No description provided for @starmapCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get starmapCopy;

  /// No description provided for @starmapLoad.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get starmapLoad;

  /// No description provided for @starmapInvalidShareCode.
  ///
  /// In en, this message translates to:
  /// **'This starmap share code is invalid.'**
  String get starmapInvalidShareCode;

  /// No description provided for @starmapPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get starmapPause;

  /// No description provided for @starmapPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get starmapPlay;

  /// No description provided for @starmapSkillLegend.
  ///
  /// In en, this message translates to:
  /// **'Skill'**
  String get starmapSkillLegend;

  /// No description provided for @starmapMemoryLegend.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get starmapMemoryLegend;

  /// No description provided for @starmapChronologyLegend.
  ///
  /// In en, this message translates to:
  /// **'Core: oldest · outer: newest'**
  String get starmapChronologyLegend;

  /// No description provided for @starmapOpenNode.
  ///
  /// In en, this message translates to:
  /// **'Open {name}'**
  String starmapOpenNode(String name);

  /// No description provided for @starmapSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get starmapSaved;

  /// No description provided for @starmapSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save node: {error}'**
  String starmapSaveFailed(String error);

  /// No description provided for @starmapDeleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete node?'**
  String get starmapDeleteQuestion;

  /// No description provided for @starmapDeleteDescription.
  ///
  /// In en, this message translates to:
  /// **'{name} will be removed from the starmap.'**
  String starmapDeleteDescription(String name);

  /// No description provided for @starmapDeleted.
  ///
  /// In en, this message translates to:
  /// **'Node deleted'**
  String get starmapDeleted;

  /// No description provided for @starmapDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete node: {error}'**
  String starmapDeleteFailed(String error);

  /// No description provided for @starmapUseCount.
  ///
  /// In en, this message translates to:
  /// **'Used {count} times'**
  String starmapUseCount(int count);

  /// No description provided for @starmapContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get starmapContent;

  /// No description provided for @starmapSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get starmapSaving;

  /// No description provided for @starmapCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'Created by {value}'**
  String starmapCreatedBy(Object value);

  /// No description provided for @starmapSource.
  ///
  /// In en, this message translates to:
  /// **'Source: {value}'**
  String starmapSource(Object value);

  /// No description provided for @starmapStateArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get starmapStateArchived;

  /// No description provided for @configCenterLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load capability data: {error}'**
  String configCenterLoadFailed(String error);

  /// No description provided for @configCenterKnowledgeTab.
  ///
  /// In en, this message translates to:
  /// **'Knowledge'**
  String get configCenterKnowledgeTab;

  /// No description provided for @configCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Capability management'**
  String get configCenterTitle;

  /// No description provided for @configCenterLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load capabilities'**
  String get configCenterLoadErrorTitle;

  /// No description provided for @configCenterMcpEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Add an MCP server to connect external tools and data.'**
  String get configCenterMcpEmptyDescription;

  /// No description provided for @configCenterUrlOrCommand.
  ///
  /// In en, this message translates to:
  /// **'URL or command'**
  String get configCenterUrlOrCommand;

  /// No description provided for @configCenterTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get configCenterTransport;

  /// No description provided for @configCenterLocalStdio.
  ///
  /// In en, this message translates to:
  /// **'Stdio (local process)'**
  String get configCenterLocalStdio;

  /// No description provided for @configCenterMutationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not apply change: {error}'**
  String configCenterMutationFailed(String error);

  /// No description provided for @configCenterKnowledgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Knowledge sources'**
  String get configCenterKnowledgeTitle;

  /// No description provided for @configCenterKnowledgeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No knowledge sources'**
  String get configCenterKnowledgeEmpty;

  /// No description provided for @configCenterKnowledgeEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Add a file, folder, or URL as a knowledge source.'**
  String get configCenterKnowledgeEmptyDescription;

  /// No description provided for @configCenterDatabase.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get configCenterDatabase;

  /// No description provided for @configCenterKnowledgeMeta.
  ///
  /// In en, this message translates to:
  /// **'{type} · {count} chunks · {status}'**
  String configCenterKnowledgeMeta(String type, int count, String status);

  /// No description provided for @configCenterIndexed.
  ///
  /// In en, this message translates to:
  /// **'Indexed'**
  String get configCenterIndexed;

  /// No description provided for @configCenterNotIndexed.
  ///
  /// In en, this message translates to:
  /// **'Not indexed'**
  String get configCenterNotIndexed;

  /// No description provided for @configCenterSkillsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No skills'**
  String get configCenterSkillsEmpty;

  /// No description provided for @configCenterSkillsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'The server did not return any skills for this profile.'**
  String get configCenterSkillsEmptyDescription;

  /// No description provided for @configCenterConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get configCenterConfiguration;

  /// No description provided for @configCenterInstallPlugin.
  ///
  /// In en, this message translates to:
  /// **'Install plugin'**
  String get configCenterInstallPlugin;

  /// No description provided for @configCenterPluginsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No plugins'**
  String get configCenterPluginsEmpty;

  /// No description provided for @configCenterPluginsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Install a plugin to extend Hermes.'**
  String get configCenterPluginsEmptyDescription;

  /// No description provided for @configCenterInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get configCenterInstall;

  /// No description provided for @configCenterPluginUrl.
  ///
  /// In en, this message translates to:
  /// **'Plugin URL or identifier'**
  String get configCenterPluginUrl;

  /// No description provided for @fileEditorDiscardQuestion.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get fileEditorDiscardQuestion;

  /// No description provided for @fileEditorDiscardDescription.
  ///
  /// In en, this message translates to:
  /// **'Going back will discard your current edits.'**
  String get fileEditorDiscardDescription;

  /// No description provided for @fileEditorKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get fileEditorKeepEditing;

  /// No description provided for @fileEditorDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get fileEditorDiscard;

  /// No description provided for @fileEditorDisk.
  ///
  /// In en, this message translates to:
  /// **'On disk'**
  String get fileEditorDisk;

  /// No description provided for @fileEditorEditor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get fileEditorEditor;

  /// No description provided for @fileEditorConflictDescription.
  ///
  /// In en, this message translates to:
  /// **'This file changed on disk. Overwrite it, reload the disk version, or cancel.'**
  String get fileEditorConflictDescription;

  /// No description provided for @fileEditorConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'File changed externally'**
  String get fileEditorConflictTitle;

  /// No description provided for @fileEditorOverwriteSave.
  ///
  /// In en, this message translates to:
  /// **'Overwrite and save'**
  String get fileEditorOverwriteSave;

  /// No description provided for @fileEditorReloaded.
  ///
  /// In en, this message translates to:
  /// **'Reloaded the disk version'**
  String get fileEditorReloaded;

  /// No description provided for @fileEditorSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get fileEditorSaved;

  /// No description provided for @fileEditorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save file: {error}'**
  String fileEditorSaveFailed(String error);

  /// No description provided for @fileEditorSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get fileEditorSaving;

  /// No description provided for @fileEditorUnsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}, unsaved changes'**
  String fileEditorUnsavedTitle(String name);

  /// No description provided for @fileEditorEmpty.
  ///
  /// In en, this message translates to:
  /// **'(Empty)'**
  String get fileEditorEmpty;

  /// No description provided for @fileEditorBinaryTitle.
  ///
  /// In en, this message translates to:
  /// **'This file can\'t be edited as text'**
  String get fileEditorBinaryTitle;

  /// No description provided for @fileEditorBinaryDescription.
  ///
  /// In en, this message translates to:
  /// **'It looks like a binary file (image, archive, or executable). Opening it in the text editor would corrupt it on save, so editing is disabled — download it to your device instead.'**
  String get fileEditorBinaryDescription;

  /// No description provided for @kanbanTaskCreatedLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Task created, but the parent link could not be added: {error}'**
  String kanbanTaskCreatedLinkFailed(String error);

  /// No description provided for @kanbanTaskStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get kanbanTaskStatus;

  /// No description provided for @kanbanPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get kanbanPriority;

  /// No description provided for @kanbanAssignee.
  ///
  /// In en, this message translates to:
  /// **'Assignee'**
  String get kanbanAssignee;

  /// No description provided for @kanbanTenant.
  ///
  /// In en, this message translates to:
  /// **'Tenant'**
  String get kanbanTenant;

  /// No description provided for @kanbanParentTaskId.
  ///
  /// In en, this message translates to:
  /// **'Parent task ID'**
  String get kanbanParentTaskId;

  /// No description provided for @kanbanWorkspacePath.
  ///
  /// In en, this message translates to:
  /// **'Workspace path'**
  String get kanbanWorkspacePath;

  /// No description provided for @kanbanModelOverride.
  ///
  /// In en, this message translates to:
  /// **'Model override'**
  String get kanbanModelOverride;

  /// No description provided for @kanbanProviderOverride.
  ///
  /// In en, this message translates to:
  /// **'Provider override'**
  String get kanbanProviderOverride;

  /// No description provided for @kanbanEffort.
  ///
  /// In en, this message translates to:
  /// **'Reasoning effort'**
  String get kanbanEffort;

  /// No description provided for @kanbanEffortLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get kanbanEffortLow;

  /// No description provided for @kanbanEffortMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get kanbanEffortMedium;

  /// No description provided for @kanbanEffortHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get kanbanEffortHigh;

  /// No description provided for @kanbanCreatingTask.
  ///
  /// In en, this message translates to:
  /// **'Creating task...'**
  String get kanbanCreatingTask;

  /// No description provided for @kanbanCreateTask.
  ///
  /// In en, this message translates to:
  /// **'Create task'**
  String get kanbanCreateTask;

  /// No description provided for @kanbanCreateBoard.
  ///
  /// In en, this message translates to:
  /// **'Create board'**
  String get kanbanCreateBoard;

  /// No description provided for @kanbanBoardSettings.
  ///
  /// In en, this message translates to:
  /// **'Board settings'**
  String get kanbanBoardSettings;

  /// No description provided for @kanbanProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get kanbanProject;

  /// No description provided for @kanbanNoProject.
  ///
  /// In en, this message translates to:
  /// **'No project'**
  String get kanbanNoProject;

  /// No description provided for @kanbanDeleteBoardQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete board?'**
  String get kanbanDeleteBoardQuestion;

  /// No description provided for @kanbanDeleteBoardDescription.
  ///
  /// In en, this message translates to:
  /// **'{name} will be deleted. This cannot be undone.'**
  String kanbanDeleteBoardDescription(String name);

  /// No description provided for @kanbanBoardTaskCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks'**
  String kanbanBoardTaskCount(int count);

  /// No description provided for @kanbanBoardTaskCountProject.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks · {project}'**
  String kanbanBoardTaskCountProject(int count, String project);

  /// No description provided for @kanbanRenameBoard.
  ///
  /// In en, this message translates to:
  /// **'Rename board'**
  String get kanbanRenameBoard;

  /// No description provided for @pluginsOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update plugin: {error}'**
  String pluginsOperationFailed(String error);

  /// No description provided for @pluginsInstallTitle.
  ///
  /// In en, this message translates to:
  /// **'Install agent plugin'**
  String get pluginsInstallTitle;

  /// No description provided for @pluginsIdentifierHint.
  ///
  /// In en, this message translates to:
  /// **'Git URL or owner/repo'**
  String get pluginsIdentifierHint;

  /// No description provided for @pluginsEnableAfterInstall.
  ///
  /// In en, this message translates to:
  /// **'Enable after installation'**
  String get pluginsEnableAfterInstall;

  /// No description provided for @pluginsForceReinstall.
  ///
  /// In en, this message translates to:
  /// **'Force reinstall'**
  String get pluginsForceReinstall;

  /// No description provided for @pluginsInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed {name}'**
  String pluginsInstalled(String name);

  /// No description provided for @pluginsInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not install plugin: {error}'**
  String pluginsInstallFailed(String error);

  /// No description provided for @pluginsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading plugins...'**
  String get pluginsLoading;

  /// No description provided for @pluginsNoData.
  ///
  /// In en, this message translates to:
  /// **'No plugin data'**
  String get pluginsNoData;

  /// No description provided for @pluginsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search {count} plugins...'**
  String pluginsSearchHint(int count);

  /// No description provided for @pluginsNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching plugins'**
  String get pluginsNoMatches;

  /// No description provided for @pluginsKindPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get pluginsKindPlatform;

  /// No description provided for @pluginsKindProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get pluginsKindProvider;

  /// No description provided for @pluginsKindTool.
  ///
  /// In en, this message translates to:
  /// **'Tool'**
  String get pluginsKindTool;

  /// No description provided for @pluginsContributionTooltip.
  ///
  /// In en, this message translates to:
  /// **'{area} · {description}'**
  String pluginsContributionTooltip(String area, String description);

  /// No description provided for @pluginsActionExecuted.
  ///
  /// In en, this message translates to:
  /// **'{title} completed'**
  String pluginsActionExecuted(String title);

  /// No description provided for @pluginsAreaNavigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get pluginsAreaNavigation;

  /// No description provided for @pluginsAreaCommand.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get pluginsAreaCommand;

  /// No description provided for @pluginsAreaSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get pluginsAreaSettings;

  /// No description provided for @pluginsAreaComposer.
  ///
  /// In en, this message translates to:
  /// **'Composer'**
  String get pluginsAreaComposer;

  /// No description provided for @pluginsAreaDetail.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get pluginsAreaDetail;

  /// No description provided for @pluginsAreaTranscript.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get pluginsAreaTranscript;

  /// No description provided for @pluginsAreaPane.
  ///
  /// In en, this message translates to:
  /// **'Pane'**
  String get pluginsAreaPane;

  /// No description provided for @knowledgeLoadDetailFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load node details: {error}'**
  String knowledgeLoadDetailFailed(String error);

  /// No description provided for @knowledgeLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading knowledge graph...'**
  String get knowledgeLoading;

  /// No description provided for @knowledgeNoData.
  ///
  /// In en, this message translates to:
  /// **'No knowledge data'**
  String get knowledgeNoData;

  /// No description provided for @knowledgeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search knowledge nodes...'**
  String get knowledgeSearchHint;

  /// No description provided for @knowledgeMemorySummary.
  ///
  /// In en, this message translates to:
  /// **'Memory summary ({count})'**
  String knowledgeMemorySummary(int count);

  /// No description provided for @knowledgeNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching knowledge nodes'**
  String get knowledgeNoMatches;

  /// No description provided for @knowledgeStateActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get knowledgeStateActive;

  /// No description provided for @knowledgeStateInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get knowledgeStateInactive;

  /// No description provided for @knowledgeNodeMeta.
  ///
  /// In en, this message translates to:
  /// **'{category} · used {count} times · {state}'**
  String knowledgeNodeMeta(String category, int count, String state);

  /// No description provided for @knowledgeNodeMetaNoCategory.
  ///
  /// In en, this message translates to:
  /// **'Used {count} times · {state}'**
  String knowledgeNodeMetaNoCategory(int count, String state);

  /// No description provided for @knowledgeSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get knowledgeSaved;

  /// No description provided for @knowledgeSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save node: {error}'**
  String knowledgeSaveFailed(String error);

  /// No description provided for @knowledgeDeleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete knowledge node?'**
  String get knowledgeDeleteQuestion;

  /// No description provided for @knowledgeDeleteDescription.
  ///
  /// In en, this message translates to:
  /// **'{name} will be deleted. This cannot be undone.'**
  String knowledgeDeleteDescription(String name);

  /// No description provided for @knowledgeDeleted.
  ///
  /// In en, this message translates to:
  /// **'Knowledge node deleted'**
  String get knowledgeDeleted;

  /// No description provided for @knowledgeDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete node: {error}'**
  String knowledgeDeleteFailed(String error);

  /// No description provided for @knowledgeCancelEditing.
  ///
  /// In en, this message translates to:
  /// **'Cancel editing'**
  String get knowledgeCancelEditing;

  /// No description provided for @skillHubSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Skill search failed: {error}'**
  String skillHubSearchFailed(String error);

  /// No description provided for @skillHubExitCode.
  ///
  /// In en, this message translates to:
  /// **'Action exited with code {code}'**
  String skillHubExitCode(int code);

  /// No description provided for @skillHubActionTimeout.
  ///
  /// In en, this message translates to:
  /// **'The skill action timed out.'**
  String get skillHubActionTimeout;

  /// No description provided for @skillHubActionDone.
  ///
  /// In en, this message translates to:
  /// **'Action completed'**
  String get skillHubActionDone;

  /// No description provided for @skillHubActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Skill action failed: {error}'**
  String skillHubActionFailed(String error);

  /// No description provided for @skillHubUninstallQuestion.
  ///
  /// In en, this message translates to:
  /// **'Uninstall {name}?'**
  String skillHubUninstallQuestion(String name);

  /// No description provided for @skillHubUninstallDescription.
  ///
  /// In en, this message translates to:
  /// **'The skill will be removed and can be installed again later.'**
  String get skillHubUninstallDescription;

  /// No description provided for @skillHubUninstall.
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get skillHubUninstall;

  /// No description provided for @skillHubUpdateInstalled.
  ///
  /// In en, this message translates to:
  /// **'Update installed skills'**
  String get skillHubUpdateInstalled;

  /// No description provided for @skillHubSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search the skill marketplace...'**
  String get skillHubSearchHint;

  /// No description provided for @skillHubLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading skill marketplace...'**
  String get skillHubLoading;

  /// No description provided for @skillHubSourcesTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Some sources timed out and were omitted: {sources}'**
  String skillHubSourcesTimedOut(String sources);

  /// No description provided for @skillHubNoData.
  ///
  /// In en, this message translates to:
  /// **'No marketplace data'**
  String get skillHubNoData;

  /// No description provided for @skillHubSources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get skillHubSources;

  /// No description provided for @skillHubRateLimited.
  ///
  /// In en, this message translates to:
  /// **'{name} (rate limited)'**
  String skillHubRateLimited(String name);

  /// No description provided for @skillHubIndexUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The skill index is currently unavailable, so search results may be incomplete.'**
  String get skillHubIndexUnavailable;

  /// No description provided for @skillHubFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get skillHubFeatured;

  /// No description provided for @skillHubSearchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter keywords to search for skills'**
  String get skillHubSearchPrompt;

  /// No description provided for @skillHubInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get skillHubInstalled;

  /// No description provided for @skillHubTrustOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get skillHubTrustOfficial;

  /// No description provided for @skillHubTrustTrusted.
  ///
  /// In en, this message translates to:
  /// **'Trusted'**
  String get skillHubTrustTrusted;

  /// No description provided for @skillHubTrustCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get skillHubTrustCommunity;

  /// No description provided for @skillHubTrustUnverified.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get skillHubTrustUnverified;

  /// No description provided for @skillHubTrustUntrusted.
  ///
  /// In en, this message translates to:
  /// **'Untrusted'**
  String get skillHubTrustUntrusted;

  /// No description provided for @skillHubTrustUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown trust level'**
  String get skillHubTrustUnknown;

  /// No description provided for @newSessionInitFailed.
  ///
  /// In en, this message translates to:
  /// **'Some session options could not be loaded: {error}'**
  String newSessionInitFailed(String error);

  /// No description provided for @newSessionStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start session: {error}'**
  String newSessionStartFailed(String error);

  /// No description provided for @newSessionTitleSection.
  ///
  /// In en, this message translates to:
  /// **'Session title'**
  String get newSessionTitleSection;

  /// No description provided for @newSessionTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Optional; leave blank to generate automatically'**
  String get newSessionTitleHint;

  /// No description provided for @newSessionWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get newSessionWorkspace;

  /// No description provided for @newSessionWorkspaceHint.
  ///
  /// In en, this message translates to:
  /// **'Agent workspace on the server'**
  String get newSessionWorkspaceHint;

  /// No description provided for @newSessionBrowseDirectory.
  ///
  /// In en, this message translates to:
  /// **'Browse directories'**
  String get newSessionBrowseDirectory;

  /// No description provided for @newSessionNoProject.
  ///
  /// In en, this message translates to:
  /// **'No project'**
  String get newSessionNoProject;

  /// No description provided for @newSessionMoveLater.
  ///
  /// In en, this message translates to:
  /// **'You can move the session later from its menu'**
  String get newSessionMoveLater;

  /// No description provided for @newSessionUseCurrentModel.
  ///
  /// In en, this message translates to:
  /// **'Use current model'**
  String get newSessionUseCurrentModel;

  /// No description provided for @newSessionAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get newSessionAgent;

  /// No description provided for @newSessionStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting...'**
  String get newSessionStarting;

  /// No description provided for @newSessionStart.
  ///
  /// In en, this message translates to:
  /// **'Start session'**
  String get newSessionStart;

  /// No description provided for @newSessionAgentSummary.
  ///
  /// In en, this message translates to:
  /// **'{model} · {cwd}'**
  String newSessionAgentSummary(String model, String cwd);

  /// No description provided for @newSessionCurrentModel.
  ///
  /// In en, this message translates to:
  /// **'Current model'**
  String get newSessionCurrentModel;

  /// No description provided for @newSessionWorkspaceAbove.
  ///
  /// In en, this message translates to:
  /// **'Workspace above'**
  String get newSessionWorkspaceAbove;

  /// No description provided for @newSessionParentDirectory.
  ///
  /// In en, this message translates to:
  /// **'Parent directory'**
  String get newSessionParentDirectory;

  /// No description provided for @artifactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Artifacts'**
  String get artifactsTitle;

  /// No description provided for @artifactsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search artifact titles and sessions...'**
  String get artifactsSearchHint;

  /// No description provided for @artifactsKindCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get artifactsKindCode;

  /// No description provided for @artifactsKindImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get artifactsKindImage;

  /// No description provided for @artifactsKindLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get artifactsKindLink;

  /// No description provided for @artifactsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No artifacts'**
  String get artifactsEmpty;

  /// No description provided for @artifactsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Artifacts generated by your sessions will appear here.'**
  String get artifactsEmptyDescription;

  /// No description provided for @artifactsNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching artifacts'**
  String get artifactsNoMatches;

  /// No description provided for @artifactsNoMatchesDescription.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or filter.'**
  String get artifactsNoMatchesDescription;

  /// No description provided for @artifactsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open artifact {name}'**
  String artifactsOpen(String name);

  /// No description provided for @artifactsSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get artifactsSaved;

  /// No description provided for @artifactsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save artifact: {error}'**
  String artifactsSaveFailed(String error);

  /// No description provided for @artifactsSaveToDevice.
  ///
  /// In en, this message translates to:
  /// **'Save to device'**
  String get artifactsSaveToDevice;

  /// No description provided for @artifactsCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy artifact'**
  String get artifactsCopy;

  /// No description provided for @artifactsOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get artifactsOpenLink;

  /// No description provided for @artifactsOpenLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link.'**
  String get artifactsOpenLinkFailed;

  /// No description provided for @artifactsImageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load image'**
  String get artifactsImageLoadFailed;

  /// No description provided for @shellReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Disconnected. Reconnecting...'**
  String get shellReconnecting;

  /// No description provided for @shellReconnectNow.
  ///
  /// In en, this message translates to:
  /// **'Reconnect now'**
  String get shellReconnectNow;

  /// No description provided for @shellCollapseNavigation.
  ///
  /// In en, this message translates to:
  /// **'Collapse navigation'**
  String get shellCollapseNavigation;

  /// No description provided for @shellExpandNavigation.
  ///
  /// In en, this message translates to:
  /// **'Expand navigation'**
  String get shellExpandNavigation;

  /// No description provided for @shellNavigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get shellNavigation;

  /// No description provided for @shellSessionArea.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get shellSessionArea;

  /// No description provided for @shellWorkspaceArea.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get shellWorkspaceArea;

  /// No description provided for @shellIntelligenceArea.
  ///
  /// In en, this message translates to:
  /// **'Intelligence'**
  String get shellIntelligenceArea;

  /// No description provided for @shellModelStatus.
  ///
  /// In en, this message translates to:
  /// **'Model {value}'**
  String shellModelStatus(String value);

  /// No description provided for @shellWorkspaceStatus.
  ///
  /// In en, this message translates to:
  /// **'Workspace {value}'**
  String shellWorkspaceStatus(String value);

  /// No description provided for @shellAgentStatus.
  ///
  /// In en, this message translates to:
  /// **'Agent {value}'**
  String shellAgentStatus(String value);

  /// No description provided for @gitListView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get gitListView;

  /// No description provided for @gitTreeView.
  ///
  /// In en, this message translates to:
  /// **'Tree view'**
  String get gitTreeView;

  /// No description provided for @gitViewPr.
  ///
  /// In en, this message translates to:
  /// **'View PR'**
  String get gitViewPr;

  /// No description provided for @gitChangeCounts.
  ///
  /// In en, this message translates to:
  /// **'{staged} staged · {changed} changed'**
  String gitChangeCounts(int staged, int changed);

  /// No description provided for @gitWorkingTreeCleanDescription.
  ///
  /// In en, this message translates to:
  /// **'There are no uncommitted changes.'**
  String get gitWorkingTreeCleanDescription;

  /// No description provided for @gitStagedSection.
  ///
  /// In en, this message translates to:
  /// **'Staged'**
  String get gitStagedSection;

  /// No description provided for @gitUnstagedSection.
  ///
  /// In en, this message translates to:
  /// **'Unstaged'**
  String get gitUnstagedSection;

  /// No description provided for @gitOpenPrFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the pull request.'**
  String get gitOpenPrFailed;

  /// No description provided for @gitUnstageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not unstage: {error}'**
  String gitUnstageFailed(String error);

  /// No description provided for @gitCommitAndPushSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Committed and pushed'**
  String get gitCommitAndPushSucceeded;

  /// No description provided for @gitCommitSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Committed'**
  String get gitCommitSucceeded;

  /// No description provided for @gitStatusAdded.
  ///
  /// In en, this message translates to:
  /// **'A'**
  String get gitStatusAdded;

  /// No description provided for @gitStatusModified.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get gitStatusModified;

  /// No description provided for @gitStatusDeleted.
  ///
  /// In en, this message translates to:
  /// **'D'**
  String get gitStatusDeleted;

  /// No description provided for @gitStatusRenamed.
  ///
  /// In en, this message translates to:
  /// **'R'**
  String get gitStatusRenamed;

  /// No description provided for @gitStatusConflict.
  ///
  /// In en, this message translates to:
  /// **'U'**
  String get gitStatusConflict;

  /// No description provided for @insightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insightsTitle;

  /// No description provided for @insightsDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String insightsDays(int count);

  /// No description provided for @insightsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading statistics for the last {count} days...'**
  String insightsLoading(int count);

  /// No description provided for @insightsNoData.
  ///
  /// In en, this message translates to:
  /// **'No usage data'**
  String get insightsNoData;

  /// No description provided for @insightsOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get insightsOverview;

  /// No description provided for @insightsSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get insightsSessions;

  /// No description provided for @insightsApiCalls.
  ///
  /// In en, this message translates to:
  /// **'API calls'**
  String get insightsApiCalls;

  /// No description provided for @insightsCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get insightsCost;

  /// No description provided for @insightsDailyUsage.
  ///
  /// In en, this message translates to:
  /// **'Daily usage'**
  String get insightsDailyUsage;

  /// No description provided for @insightsModelUsage.
  ///
  /// In en, this message translates to:
  /// **'Model usage'**
  String get insightsModelUsage;

  /// No description provided for @insightsToolCalls.
  ///
  /// In en, this message translates to:
  /// **'Tool calls'**
  String get insightsToolCalls;

  /// No description provided for @insightsUnknownProvider.
  ///
  /// In en, this message translates to:
  /// **'Unknown provider'**
  String get insightsUnknownProvider;

  /// No description provided for @insightsModelSummary.
  ///
  /// In en, this message translates to:
  /// **'{tokens} tokens · {sessions} sessions · \${cost}'**
  String insightsModelSummary(String tokens, int sessions, String cost);

  /// No description provided for @webhookBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Base URL: {url}'**
  String webhookBaseUrl(String url);

  /// No description provided for @webhookUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get webhookUrl;

  /// No description provided for @webhookSecret.
  ///
  /// In en, this message translates to:
  /// **'Secret'**
  String get webhookSecret;

  /// No description provided for @toolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Toolsets'**
  String get toolsTitle;

  /// No description provided for @toolsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No toolsets'**
  String get toolsEmpty;

  /// No description provided for @toolsToolsetSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} tools · {status}'**
  String toolsToolsetSummary(int count, String status);

  /// No description provided for @toolsTerminalBackend.
  ///
  /// In en, this message translates to:
  /// **'Terminal execution environment'**
  String get toolsTerminalBackend;

  /// No description provided for @toolsReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get toolsReady;

  /// No description provided for @toolsNeedsSetup.
  ///
  /// In en, this message translates to:
  /// **'Needs setup'**
  String get toolsNeedsSetup;

  /// No description provided for @toolsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get toolsUnavailable;

  /// No description provided for @toolsBackendSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not switch terminal environment: {error}'**
  String toolsBackendSwitchFailed(String error);

  /// No description provided for @toolsComputerUseUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This backend platform is unsupported'**
  String get toolsComputerUseUnsupported;

  /// No description provided for @toolsComputerUseNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'cua-driver is not installed'**
  String get toolsComputerUseNotInstalled;

  /// No description provided for @toolsComputerUseReady.
  ///
  /// In en, this message translates to:
  /// **'Computer Use is ready'**
  String get toolsComputerUseReady;

  /// No description provided for @toolsComputerUseNotReady.
  ///
  /// In en, this message translates to:
  /// **'The driver or permissions are not ready'**
  String get toolsComputerUseNotReady;

  /// No description provided for @toolsRecheck.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get toolsRecheck;

  /// No description provided for @toolsCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get toolsCheck;

  /// No description provided for @toolsCheckResult.
  ///
  /// In en, this message translates to:
  /// **'{label}: {result}'**
  String toolsCheckResult(String label, String result);

  /// No description provided for @toolsWaitingForPermission.
  ///
  /// In en, this message translates to:
  /// **'Waiting for backend permission...'**
  String get toolsWaitingForPermission;

  /// No description provided for @toolsRequestPermission.
  ///
  /// In en, this message translates to:
  /// **'Request backend system permission'**
  String get toolsRequestPermission;

  /// No description provided for @toolsPermissionTimeout.
  ///
  /// In en, this message translates to:
  /// **'The permission request timed out.'**
  String get toolsPermissionTimeout;

  /// No description provided for @toolsPermissionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not request system permission: {error}'**
  String toolsPermissionFailed(String error);

  /// No description provided for @toolsToggleFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update toolset: {error}'**
  String toolsToggleFailed(String error);

  /// No description provided for @agentBotsTitle.
  ///
  /// In en, this message translates to:
  /// **'Bots'**
  String get agentBotsTitle;

  /// No description provided for @agentRequestSummary.
  ///
  /// In en, this message translates to:
  /// **'{title} · {member}'**
  String agentRequestSummary(String title, String member);

  /// No description provided for @modelPickerRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh models: {error}'**
  String modelPickerRefreshFailed(String error);

  /// No description provided for @modelPickerEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit visible models'**
  String get modelPickerEdit;

  /// No description provided for @modelPickerVisibilitySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save model visibility: {error}'**
  String modelPickerVisibilitySaveFailed(String error);

  /// No description provided for @modelPickerMoaPresets.
  ///
  /// In en, this message translates to:
  /// **'MoA presets'**
  String get modelPickerMoaPresets;

  /// No description provided for @modelPickerMoaModel.
  ///
  /// In en, this message translates to:
  /// **'MoA: {model}'**
  String modelPickerMoaModel(String model);

  /// No description provided for @modelPickerRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh models'**
  String get modelPickerRefresh;

  /// No description provided for @modelPickerFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get modelPickerFree;

  /// No description provided for @modelPickerFreeDiscount.
  ///
  /// In en, this message translates to:
  /// **'Free · -{percent}%'**
  String modelPickerFreeDiscount(num percent);

  /// No description provided for @modelPickerPricing.
  ///
  /// In en, this message translates to:
  /// **'Input {input} / Output {output}{discount}'**
  String modelPickerPricing(String input, String output, String discount);

  /// No description provided for @modelPickerSelectNone.
  ///
  /// In en, this message translates to:
  /// **'Select none'**
  String get modelPickerSelectNone;

  /// No description provided for @modelPickerSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get modelPickerSelectAll;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @chatMermaidDiagram.
  ///
  /// In en, this message translates to:
  /// **'Mermaid diagram'**
  String get chatMermaidDiagram;

  /// No description provided for @chatArtifactTitle.
  ///
  /// In en, this message translates to:
  /// **'{language} artifact'**
  String chatArtifactTitle(String language);

  /// No description provided for @chatCodeArtifactTitle.
  ///
  /// In en, this message translates to:
  /// **'{language} code · {count} lines'**
  String chatCodeArtifactTitle(String language, int count);

  /// No description provided for @chatArtifactPreview.
  ///
  /// In en, this message translates to:
  /// **'Artifact preview'**
  String get chatArtifactPreview;

  /// No description provided for @chatCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'{language} code'**
  String chatCodeTitle(String language);

  /// No description provided for @chatCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get chatCodeCopied;

  /// No description provided for @chatLivePreview.
  ///
  /// In en, this message translates to:
  /// **'Live preview'**
  String get chatLivePreview;

  /// No description provided for @chatExpandPreview.
  ///
  /// In en, this message translates to:
  /// **'Expand preview in message'**
  String get chatExpandPreview;

  /// No description provided for @chatAudioPlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play audio'**
  String get chatAudioPlaybackFailed;

  /// No description provided for @chatPauseAudio.
  ///
  /// In en, this message translates to:
  /// **'Pause audio'**
  String get chatPauseAudio;

  /// No description provided for @chatPlayAudio.
  ///
  /// In en, this message translates to:
  /// **'Play audio'**
  String get chatPlayAudio;

  /// No description provided for @chatOpenVideo.
  ///
  /// In en, this message translates to:
  /// **'Video · tap to open'**
  String get chatOpenVideo;

  /// No description provided for @chatOpenFile.
  ///
  /// In en, this message translates to:
  /// **'File · tap to open'**
  String get chatOpenFile;

  /// No description provided for @imageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save image: {error}'**
  String imageSaveFailed(String error);

  /// No description provided for @voiceMenu.
  ///
  /// In en, this message translates to:
  /// **'Voice menu'**
  String get voiceMenu;

  /// No description provided for @voiceStopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get voiceStopRecording;

  /// No description provided for @voiceDictation.
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get voiceDictation;

  /// No description provided for @voiceContinuousConversation.
  ///
  /// In en, this message translates to:
  /// **'Continuous voice conversation'**
  String get voiceContinuousConversation;

  /// No description provided for @voiceAutoReadReplies.
  ///
  /// In en, this message translates to:
  /// **'Read replies automatically'**
  String get voiceAutoReadReplies;

  /// No description provided for @voiceWakeWord.
  ///
  /// In en, this message translates to:
  /// **'Wake word'**
  String get voiceWakeWord;

  /// No description provided for @voiceWakePhrase.
  ///
  /// In en, this message translates to:
  /// **'\"{phrase}\"'**
  String voiceWakePhrase(String phrase);

  /// No description provided for @voiceStopSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Stop reading'**
  String get voiceStopSpeaking;

  /// No description provided for @voiceWakeEnabling.
  ///
  /// In en, this message translates to:
  /// **'Enabling wake word...'**
  String get voiceWakeEnabling;

  /// No description provided for @voiceWakeTriggered.
  ///
  /// In en, this message translates to:
  /// **'Wake word detected. Listening...'**
  String get voiceWakeTriggered;

  /// No description provided for @voiceWakeListening.
  ///
  /// In en, this message translates to:
  /// **'Listening for the wake word'**
  String get voiceWakeListening;

  /// No description provided for @voiceWakeListeningFor.
  ///
  /// In en, this message translates to:
  /// **'Listening for \"{phrase}\"'**
  String voiceWakeListeningFor(String phrase);

  /// No description provided for @voiceWakeWaiting.
  ///
  /// In en, this message translates to:
  /// **'Wake word waiting to resume'**
  String get voiceWakeWaiting;

  /// No description provided for @voiceWakeDisabled.
  ///
  /// In en, this message translates to:
  /// **'Wake word off'**
  String get voiceWakeDisabled;

  /// No description provided for @sessionPrBadge.
  ///
  /// In en, this message translates to:
  /// **'PR #{number} · {status}'**
  String sessionPrBadge(int number, String status);

  /// No description provided for @sessionPrOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the pull request.'**
  String get sessionPrOpenFailed;

  /// No description provided for @sessionCliBadge.
  ///
  /// In en, this message translates to:
  /// **'CLI session'**
  String get sessionCliBadge;

  /// No description provided for @sessionDraftBadge.
  ///
  /// In en, this message translates to:
  /// **'Unsent draft'**
  String get sessionDraftBadge;

  /// No description provided for @sessionSharedBadge.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get sessionSharedBadge;

  /// No description provided for @sessionHandedOff.
  ///
  /// In en, this message translates to:
  /// **'Handed off'**
  String get sessionHandedOff;

  /// No description provided for @sessionHandedOffTo.
  ///
  /// In en, this message translates to:
  /// **'Handed off · {platform}'**
  String sessionHandedOffTo(String platform);

  /// No description provided for @sessionHandoffErrorBadge.
  ///
  /// In en, this message translates to:
  /// **'Handoff error · {error}'**
  String sessionHandoffErrorBadge(String error);

  /// No description provided for @sessionCompressionErrorBadge.
  ///
  /// In en, this message translates to:
  /// **'Context compression temporarily failed · {error}'**
  String sessionCompressionErrorBadge(String error);

  /// No description provided for @sessionEndedWithReason.
  ///
  /// In en, this message translates to:
  /// **'Ended · {reason}'**
  String sessionEndedWithReason(String reason);

  /// No description provided for @sessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get sessionEnded;

  /// No description provided for @toolGroupHiddenRestore.
  ///
  /// In en, this message translates to:
  /// **'{count} tools hidden; tap to restore'**
  String toolGroupHiddenRestore(int count);

  /// No description provided for @backgroundStopFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not stop process: {error}'**
  String backgroundStopFailed(String error);

  /// No description provided for @backgroundProcessRemoved.
  ///
  /// In en, this message translates to:
  /// **'This process has ended and was removed'**
  String get backgroundProcessRemoved;

  /// No description provided for @backgroundCloseAndHide.
  ///
  /// In en, this message translates to:
  /// **'Close and hide'**
  String get backgroundCloseAndHide;

  /// No description provided for @mcpLogsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No logs'**
  String get mcpLogsEmpty;

  /// No description provided for @subagentTaskProgress.
  ///
  /// In en, this message translates to:
  /// **'Task progress'**
  String get subagentTaskProgress;

  /// No description provided for @cloudDiscoverAgain.
  ///
  /// In en, this message translates to:
  /// **'Discover again'**
  String get cloudDiscoverAgain;

  /// No description provided for @cloudPortalLoginPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to the Portal below. Agents will be discovered automatically after sign-in.'**
  String get cloudPortalLoginPrompt;

  /// No description provided for @backgroundTerminal.
  ///
  /// In en, this message translates to:
  /// **'Background terminal'**
  String get backgroundTerminal;

  /// No description provided for @backgroundWaitingOutput.
  ///
  /// In en, this message translates to:
  /// **'Waiting for output...'**
  String get backgroundWaitingOutput;

  /// No description provided for @backgroundStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping...'**
  String get backgroundStopping;

  /// No description provided for @backgroundStopProcess.
  ///
  /// In en, this message translates to:
  /// **'Stop process'**
  String get backgroundStopProcess;

  /// No description provided for @markdownAlertTip.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get markdownAlertTip;

  /// No description provided for @markdownAlertImportant.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get markdownAlertImportant;

  /// No description provided for @markdownAlertWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get markdownAlertWarning;

  /// No description provided for @markdownAlertCaution.
  ///
  /// In en, this message translates to:
  /// **'Caution'**
  String get markdownAlertCaution;

  /// No description provided for @markdownAlertNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get markdownAlertNote;

  /// No description provided for @richLinkMaps.
  ///
  /// In en, this message translates to:
  /// **'Maps'**
  String get richLinkMaps;

  /// No description provided for @turnActivityTools.
  ///
  /// In en, this message translates to:
  /// **'{count} tools'**
  String turnActivityTools(int count);

  /// No description provided for @turnActivityReasoning.
  ///
  /// In en, this message translates to:
  /// **'{count} reasoning blocks'**
  String turnActivityReasoning(int count);

  /// No description provided for @toolGroupFailed.
  ///
  /// In en, this message translates to:
  /// **'{count} failed'**
  String toolGroupFailed(int count);

  /// No description provided for @messageSourceDingtalk.
  ///
  /// In en, this message translates to:
  /// **'DingTalk'**
  String get messageSourceDingtalk;

  /// No description provided for @profileScopeApplyTo.
  ///
  /// In en, this message translates to:
  /// **'Apply to'**
  String get profileScopeApplyTo;

  /// No description provided for @profileScopeChangesApplyTo.
  ///
  /// In en, this message translates to:
  /// **'Changes on this page apply to the {profile} profile.'**
  String profileScopeChangesApplyTo(String profile);

  /// No description provided for @profileScopeConfiguring.
  ///
  /// In en, this message translates to:
  /// **'Configuring'**
  String get profileScopeConfiguring;

  /// No description provided for @profileScopeCurrent.
  ///
  /// In en, this message translates to:
  /// **'{name} (current)'**
  String profileScopeCurrent(String name);

  /// No description provided for @mcpLogsAllServers.
  ///
  /// In en, this message translates to:
  /// **'All servers'**
  String get mcpLogsAllServers;

  /// No description provided for @mcpLogsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading logs...'**
  String get mcpLogsLoading;

  /// No description provided for @badgeUnreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String badgeUnreadCount(String count);

  /// No description provided for @progressPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% complete'**
  String progressPercent(int percent);

  /// No description provided for @avatarNamed.
  ///
  /// In en, this message translates to:
  /// **'Avatar: {name}'**
  String avatarNamed(String name);

  /// No description provided for @avatarUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get avatarUnnamed;

  /// No description provided for @thinkingActive.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get thinkingActive;

  /// No description provided for @thinkingProcess.
  ///
  /// In en, this message translates to:
  /// **'Reasoning'**
  String get thinkingProcess;

  /// No description provided for @thinkingBriefly.
  ///
  /// In en, this message translates to:
  /// **'Thought briefly'**
  String get thinkingBriefly;

  /// No description provided for @thinkingSeconds.
  ///
  /// In en, this message translates to:
  /// **'Thought for {seconds}s'**
  String thinkingSeconds(String seconds);

  /// No description provided for @thinkingMinutes.
  ///
  /// In en, this message translates to:
  /// **'Thought for {minutes}m {seconds}s'**
  String thinkingMinutes(int minutes, int seconds);

  /// No description provided for @thinkingGeneratedCharacters.
  ///
  /// In en, this message translates to:
  /// **'Generated {count} characters'**
  String thinkingGeneratedCharacters(int count);

  /// No description provided for @thinkingCharacters.
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String thinkingCharacters(int count);

  /// No description provided for @thinkingAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing context...'**
  String get thinkingAnalyzing;

  /// No description provided for @commonNoData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get commonNoData;

  /// No description provided for @commonFeatureDisabled.
  ///
  /// In en, this message translates to:
  /// **'Feature disabled'**
  String get commonFeatureDisabled;

  /// No description provided for @cloudDiscoveryFailed.
  ///
  /// In en, this message translates to:
  /// **'Cloud discovery failed'**
  String get cloudDiscoveryFailed;

  /// No description provided for @cloudDiscoveryInvalidData.
  ///
  /// In en, this message translates to:
  /// **'Cloud returned unrecognized data: {error}'**
  String cloudDiscoveryInvalidData(String error);

  /// No description provided for @cloudDiscoveryUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Hermes Cloud discovery is not supported on this platform'**
  String get cloudDiscoveryUnsupported;

  /// No description provided for @sessionCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the session: {error}'**
  String sessionCreateFailed(String error);

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get statusReady;

  /// No description provided for @workspaceDescription.
  ///
  /// In en, this message translates to:
  /// **'Session tiles and plugin panes'**
  String get workspaceDescription;

  /// No description provided for @subagentFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Subagent'**
  String get subagentFallbackName;

  /// No description provided for @subagentNoTask.
  ///
  /// In en, this message translates to:
  /// **'No task description'**
  String get subagentNoTask;

  /// No description provided for @subagentsStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get subagentsStatusRunning;

  /// No description provided for @subagentsStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get subagentsStatusCompleted;

  /// No description provided for @subagentsStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get subagentsStatusFailed;

  /// No description provided for @subagentCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Subagent · {name}'**
  String subagentCardTitle(String name);

  /// No description provided for @subagentTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get subagentTask;

  /// No description provided for @subagentModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get subagentModel;

  /// No description provided for @subagentCurrentTool.
  ///
  /// In en, this message translates to:
  /// **'Current tool'**
  String get subagentCurrentTool;

  /// No description provided for @subagentSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get subagentSummary;

  /// No description provided for @sessionApiCallCount.
  ///
  /// In en, this message translates to:
  /// **'{count} API calls'**
  String sessionApiCallCount(int count);

  /// No description provided for @sessionTokenCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tokens'**
  String sessionTokenCount(String count);

  /// No description provided for @diagnosticsConsentDescription.
  ///
  /// In en, this message translates to:
  /// **'Redacted server logs and system and provider configuration will be uploaded. Logs may contain conversation content, tool output, and file paths. API keys are never uploaded, and the diagnostic bundle is deleted after 14 days.'**
  String get diagnosticsConsentDescription;

  /// No description provided for @diagnosticsApproveUpload.
  ///
  /// In en, this message translates to:
  /// **'Agree and upload'**
  String get diagnosticsApproveUpload;

  /// No description provided for @diagnosticsGatewayUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not connected to the Hermes gateway'**
  String get diagnosticsGatewayUnavailable;

  /// No description provided for @diagnosticsUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get diagnosticsUploadFailed;

  /// No description provided for @diagnosticsSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics sent'**
  String get diagnosticsSentTitle;

  /// No description provided for @diagnosticsLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'The view link was copied to the clipboard:'**
  String get diagnosticsLinkCopied;

  /// No description provided for @diagnosticsSupportPrompt.
  ///
  /// In en, this message translates to:
  /// **'For more help, contact us through:'**
  String get diagnosticsSupportPrompt;

  /// No description provided for @diagnosticsSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send diagnostics: {error}'**
  String diagnosticsSendFailed(String error);

  /// No description provided for @slashDescRetry.
  ///
  /// In en, this message translates to:
  /// **'Regenerate the previous response'**
  String get slashDescRetry;

  /// No description provided for @slashDescClear.
  ///
  /// In en, this message translates to:
  /// **'Clear the current session view'**
  String get slashDescClear;

  /// No description provided for @slashDescUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo the last complete turn'**
  String get slashDescUndo;

  /// No description provided for @slashDescSteer.
  ///
  /// In en, this message translates to:
  /// **'Add guidance to the current turn'**
  String get slashDescSteer;

  /// No description provided for @slashDescStatus.
  ///
  /// In en, this message translates to:
  /// **'View session status'**
  String get slashDescStatus;

  /// No description provided for @slashDescTitle.
  ///
  /// In en, this message translates to:
  /// **'Regenerate the session title'**
  String get slashDescTitle;

  /// No description provided for @slashDescNew.
  ///
  /// In en, this message translates to:
  /// **'Start a new session'**
  String get slashDescNew;

  /// No description provided for @slashDescYolo.
  ///
  /// In en, this message translates to:
  /// **'Toggle YOLO auto-approval'**
  String get slashDescYolo;

  /// No description provided for @slashDescHandoff.
  ///
  /// In en, this message translates to:
  /// **'Open session handoff'**
  String get slashDescHandoff;

  /// No description provided for @slashDescProfile.
  ///
  /// In en, this message translates to:
  /// **'Choose a profile or personality'**
  String get slashDescProfile;

  /// No description provided for @slashDescHelp.
  ///
  /// In en, this message translates to:
  /// **'List local and catalog slash commands'**
  String get slashDescHelp;

  /// No description provided for @slashDescBackground.
  ///
  /// In en, this message translates to:
  /// **'Submit a background task'**
  String get slashDescBackground;

  /// No description provided for @slashDescCompress.
  ///
  /// In en, this message translates to:
  /// **'Compress the current session context'**
  String get slashDescCompress;

  /// No description provided for @slashDescQueue.
  ///
  /// In en, this message translates to:
  /// **'Add the message to the send queue'**
  String get slashDescQueue;

  /// No description provided for @slashDescUsage.
  ///
  /// In en, this message translates to:
  /// **'View usage for this session'**
  String get slashDescUsage;

  /// No description provided for @slashDescVersion.
  ///
  /// In en, this message translates to:
  /// **'Show Hermes and mobile versions'**
  String get slashDescVersion;

  /// No description provided for @slashDescStop.
  ///
  /// In en, this message translates to:
  /// **'Stop the current turn'**
  String get slashDescStop;

  /// No description provided for @slashDescTools.
  ///
  /// In en, this message translates to:
  /// **'Open tool configuration'**
  String get slashDescTools;

  /// No description provided for @slashDescApprovals.
  ///
  /// In en, this message translates to:
  /// **'Set approval mode: manual / smart / off'**
  String get slashDescApprovals;

  /// No description provided for @slashDescModel.
  ///
  /// In en, this message translates to:
  /// **'Open the model picker'**
  String get slashDescModel;

  /// No description provided for @slashDescWake.
  ///
  /// In en, this message translates to:
  /// **'Manage wake word: status / on / off / toggle'**
  String get slashDescWake;

  /// No description provided for @slashDescSkinUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Desktop-only skin command'**
  String get slashDescSkinUnavailable;

  /// No description provided for @slashDescBrowserUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Desktop-only built-in browser command'**
  String get slashDescBrowserUnavailable;

  /// No description provided for @slashDescJourney.
  ///
  /// In en, this message translates to:
  /// **'Open the Starmap journey'**
  String get slashDescJourney;

  /// No description provided for @slashDescPet.
  ///
  /// In en, this message translates to:
  /// **'Open the pet center'**
  String get slashDescPet;

  /// No description provided for @slashDescHatch.
  ///
  /// In en, this message translates to:
  /// **'Generate and hatch a new pet'**
  String get slashDescHatch;

  /// No description provided for @slashDescSave.
  ///
  /// In en, this message translates to:
  /// **'Save the current session transcript'**
  String get slashDescSave;

  /// No description provided for @slashDescReloadConfigUnavailable.
  ///
  /// In en, this message translates to:
  /// **'reload-config is not supported by Mobile or Gateway'**
  String get slashDescReloadConfigUnavailable;

  /// No description provided for @cronSuggestionPrefix.
  ///
  /// In en, this message translates to:
  /// **'Schedule this as a recurring task: '**
  String get cronSuggestionPrefix;

  /// No description provided for @kanbanTaskCompletedNotification.
  ///
  /// In en, this message translates to:
  /// **'Kanban task completed'**
  String get kanbanTaskCompletedNotification;

  /// No description provided for @kanbanTaskProblemNotification.
  ///
  /// In en, this message translates to:
  /// **'Kanban task needs attention'**
  String get kanbanTaskProblemNotification;

  /// No description provided for @themeGraphite.
  ///
  /// In en, this message translates to:
  /// **'Graphite'**
  String get themeGraphite;

  /// No description provided for @themeIndigo.
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get themeIndigo;

  /// No description provided for @themeMoss.
  ///
  /// In en, this message translates to:
  /// **'Moss'**
  String get themeMoss;

  /// No description provided for @themeDune.
  ///
  /// In en, this message translates to:
  /// **'Dune'**
  String get themeDune;

  /// No description provided for @connectTransportMobileServer.
  ///
  /// In en, this message translates to:
  /// **'Mobile Server'**
  String get connectTransportMobileServer;

  /// No description provided for @connectTransportDirectGateway.
  ///
  /// In en, this message translates to:
  /// **'Direct Gateway'**
  String get connectTransportDirectGateway;

  /// No description provided for @connectTransportSsh.
  ///
  /// In en, this message translates to:
  /// **'SSH'**
  String get connectTransportSsh;

  /// No description provided for @connectAuthOauth.
  ///
  /// In en, this message translates to:
  /// **'OAuth'**
  String get connectAuthOauth;

  /// No description provided for @connectAuthToken.
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get connectAuthToken;

  /// No description provided for @mcpAuthOauth.
  ///
  /// In en, this message translates to:
  /// **'OAuth'**
  String get mcpAuthOauth;

  /// No description provided for @mcpAuthBearerToken.
  ///
  /// In en, this message translates to:
  /// **'Bearer token'**
  String get mcpAuthBearerToken;

  /// No description provided for @gitAgentShipTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent Ship'**
  String get gitAgentShipTitle;

  /// No description provided for @commonUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get commonUrl;

  /// No description provided for @toolEmptyList.
  ///
  /// In en, this message translates to:
  /// **'(Empty list)'**
  String get toolEmptyList;

  /// No description provided for @toolItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String toolItemCount(int count);

  /// No description provided for @toolFieldCount.
  ///
  /// In en, this message translates to:
  /// **'{count} fields'**
  String toolFieldCount(int count);

  /// No description provided for @toolPath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get toolPath;

  /// No description provided for @toolLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get toolLanguage;

  /// No description provided for @toolText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get toolText;

  /// No description provided for @toolMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get toolMessage;

  /// No description provided for @toolSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get toolSummary;

  /// No description provided for @toolExecuteCommand.
  ///
  /// In en, this message translates to:
  /// **'Run command'**
  String get toolExecuteCommand;

  /// No description provided for @toolRunCode.
  ///
  /// In en, this message translates to:
  /// **'Run code'**
  String get toolRunCode;

  /// No description provided for @toolRunCodeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Run {language} code'**
  String toolRunCodeLanguage(String language);

  /// No description provided for @toolSearchFor.
  ///
  /// In en, this message translates to:
  /// **'Search: {query}'**
  String toolSearchFor(String query);

  /// No description provided for @toolExtractWeb.
  ///
  /// In en, this message translates to:
  /// **'Extract web page'**
  String get toolExtractWeb;

  /// No description provided for @toolApplyPatch.
  ///
  /// In en, this message translates to:
  /// **'Apply file patch'**
  String get toolApplyPatch;

  /// No description provided for @toolListFiles.
  ///
  /// In en, this message translates to:
  /// **'List files'**
  String get toolListFiles;

  /// No description provided for @toolGenerateImage.
  ///
  /// In en, this message translates to:
  /// **'Generate image'**
  String get toolGenerateImage;

  /// No description provided for @toolDelegateTask.
  ///
  /// In en, this message translates to:
  /// **'Delegated task'**
  String get toolDelegateTask;

  /// No description provided for @toolTask.
  ///
  /// In en, this message translates to:
  /// **'Task {index}'**
  String toolTask(int index);

  /// No description provided for @toolRunEditingFiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Editing 1 file} other{Editing {count} files}}'**
  String toolRunEditingFiles(int count);

  /// No description provided for @toolRunExploringFiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Exploring 1 file} other{Exploring {count} files}}'**
  String toolRunExploringFiles(int count);

  /// No description provided for @toolRunRunningCommands.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Running 1 command} other{Running {count} commands}}'**
  String toolRunRunningCommands(int count);

  /// No description provided for @toolRunDelegatingTasks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delegating 1 task} other{Delegating {count} tasks}}'**
  String toolRunDelegatingTasks(int count);

  /// No description provided for @toolRunUsingTools.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Using 1 tool} other{Using {count} tools}}'**
  String toolRunUsingTools(int count);

  /// No description provided for @toolRunEditedFiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Edited 1 file} other{Edited {count} files}}'**
  String toolRunEditedFiles(int count);

  /// No description provided for @toolRunExploredFiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Explored 1 file} other{Explored {count} files}}'**
  String toolRunExploredFiles(int count);

  /// No description provided for @toolRunRanCommands.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Ran 1 command} other{Ran {count} commands}}'**
  String toolRunRanCommands(int count);

  /// No description provided for @toolRunDelegatedTasks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delegated 1 task} other{Delegated {count} tasks}}'**
  String toolRunDelegatedTasks(int count);

  /// No description provided for @toolRunUsedTools.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Used 1 tool} other{Used {count} tools}}'**
  String toolRunUsedTools(int count);

  /// No description provided for @notificationBackgroundCompleted.
  ///
  /// In en, this message translates to:
  /// **'Background task completed'**
  String get notificationBackgroundCompleted;

  /// No description provided for @notificationBackgroundCompletedBody.
  ///
  /// In en, this message translates to:
  /// **'A background task completed. Tap to view the result.'**
  String get notificationBackgroundCompletedBody;

  /// No description provided for @notificationApprovalRequired.
  ///
  /// In en, this message translates to:
  /// **'Approval required'**
  String get notificationApprovalRequired;

  /// No description provided for @notificationApprovalRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'The agent is requesting approval for a sensitive operation.'**
  String get notificationApprovalRequiredBody;

  /// No description provided for @voiceServerDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected to the server'**
  String get voiceServerDisconnected;

  /// No description provided for @voiceRecordingUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Microphone recording is not supported on this platform'**
  String get voiceRecordingUnsupported;

  /// No description provided for @voiceMicrophoneStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission was denied or recording could not start'**
  String get voiceMicrophoneStartFailed;

  /// No description provided for @voiceRecordingFailed.
  ///
  /// In en, this message translates to:
  /// **'Recording failed: {error}'**
  String voiceRecordingFailed(String error);

  /// No description provided for @voiceNoSpeech.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t hear that. Try again.'**
  String get voiceNoSpeech;

  /// No description provided for @voiceSttUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech-to-text (STT) is not configured on the server'**
  String get voiceSttUnavailable;

  /// No description provided for @voiceTranscriptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Transcription failed: {error}'**
  String voiceTranscriptionFailed(String error);

  /// No description provided for @voiceSpeechFailed.
  ///
  /// In en, this message translates to:
  /// **'Voice playback failed: {error}'**
  String voiceSpeechFailed(String error);

  /// No description provided for @voiceStreamingSpeechFailed.
  ///
  /// In en, this message translates to:
  /// **'Streaming voice playback failed: {error}'**
  String voiceStreamingSpeechFailed(String error);

  /// No description provided for @voiceWakeInstallNotice.
  ///
  /// In en, this message translates to:
  /// **'Enabling wake word. The detection engine may need to be installed the first time.'**
  String get voiceWakeInstallNotice;

  /// No description provided for @voiceWakeUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage: /wake [status|on|off|toggle]'**
  String get voiceWakeUsage;

  /// No description provided for @voiceWakeNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'Wake word is not enabled'**
  String get voiceWakeNotEnabled;

  /// No description provided for @voiceWakeOtherSurface.
  ///
  /// In en, this message translates to:
  /// **'Wake word is assigned to another device'**
  String get voiceWakeOtherSurface;

  /// No description provided for @voiceWakeOwned.
  ///
  /// In en, this message translates to:
  /// **'Another device is listening for the wake word'**
  String get voiceWakeOwned;

  /// No description provided for @voiceWakeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This backend does not support wake word'**
  String get voiceWakeUnavailable;

  /// No description provided for @voiceWakeMicInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Wake word microphone interrupted: {error}'**
  String voiceWakeMicInterrupted(String error);

  /// No description provided for @voiceWakeMicPermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission was denied, so wake word cannot listen'**
  String get voiceWakeMicPermission;

  /// No description provided for @voiceWakeMicStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the wake word microphone: {error}'**
  String voiceWakeMicStartFailed(String error);

  /// No description provided for @voiceWakeAudioUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send wake word audio: {error}'**
  String voiceWakeAudioUploadFailed(String error);

  /// No description provided for @filesThisComputer.
  ///
  /// In en, this message translates to:
  /// **'This computer'**
  String get filesThisComputer;

  /// No description provided for @billingSavedPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Saved payment method'**
  String get billingSavedPaymentMethod;

  /// No description provided for @billingPaymentMethodKind.
  ///
  /// In en, this message translates to:
  /// **'Payment method · {kind}'**
  String billingPaymentMethodKind(String kind);

  /// No description provided for @previewTourBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get previewTourBack;

  /// No description provided for @previewTourDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get previewTourDone;

  /// No description provided for @previewTourNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get previewTourNext;

  /// No description provided for @chatMermaidParseError.
  ///
  /// In en, this message translates to:
  /// **'Could not parse Mermaid diagram'**
  String get chatMermaidParseError;

  /// No description provided for @petDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Hermes Pet'**
  String get petDefaultName;

  /// No description provided for @sessionDetailProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get sessionDetailProfile;

  /// No description provided for @profileArchiveType.
  ///
  /// In en, this message translates to:
  /// **'Hermes profile'**
  String get profileArchiveType;

  /// No description provided for @profilesTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get profilesTemperature;

  /// No description provided for @profilesTopP.
  ///
  /// In en, this message translates to:
  /// **'Top P'**
  String get profilesTopP;

  /// No description provided for @profilesMaxTokens.
  ///
  /// In en, this message translates to:
  /// **'Max tokens'**
  String get profilesMaxTokens;

  /// No description provided for @sessionDesktopFallback.
  ///
  /// In en, this message translates to:
  /// **'Desktop session'**
  String get sessionDesktopFallback;

  /// No description provided for @backgroundProcessFallback.
  ///
  /// In en, this message translates to:
  /// **'Background process'**
  String get backgroundProcessFallback;

  /// No description provided for @insightsUnknownModel.
  ///
  /// In en, this message translates to:
  /// **'Unknown model'**
  String get insightsUnknownModel;

  /// No description provided for @billingCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get billingCard;

  /// No description provided for @billingLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get billingLink;

  /// No description provided for @slashGroupSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get slashGroupSkills;

  /// No description provided for @slashGroupCommands.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get slashGroupCommands;

  /// No description provided for @botAuthorYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get botAuthorYou;

  /// No description provided for @botAuthorSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get botAuthorSystem;

  /// No description provided for @botAuthorFallback.
  ///
  /// In en, this message translates to:
  /// **'Bot'**
  String get botAuthorFallback;

  /// No description provided for @terminalErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Terminal error: {error}'**
  String terminalErrorMessage(String error);

  /// No description provided for @sessionCopyTitle.
  ///
  /// In en, this message translates to:
  /// **'{title} (copy)'**
  String sessionCopyTitle(String title);

  /// No description provided for @gitRemoteFallback.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get gitRemoteFallback;

  /// No description provided for @gitStashFallback.
  ///
  /// In en, this message translates to:
  /// **'Stash'**
  String get gitStashFallback;

  /// No description provided for @notificationChannelErrors.
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get notificationChannelErrors;

  /// No description provided for @notificationChannelWarnings.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get notificationChannelWarnings;

  /// No description provided for @notificationChannelSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get notificationChannelSuccess;

  /// No description provided for @notificationChannelApprovals.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get notificationChannelApprovals;

  /// No description provided for @notificationChannelInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get notificationChannelInfo;

  /// No description provided for @memoryCuratorTitle.
  ///
  /// In en, this message translates to:
  /// **'Curator'**
  String get memoryCuratorTitle;

  /// No description provided for @messageSourceServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get messageSourceServer;

  /// No description provided for @messageSourceMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get messageSourceMobile;

  /// No description provided for @kanbanRunQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get kanbanRunQueued;

  /// No description provided for @kanbanRunCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get kanbanRunCompleted;

  /// No description provided for @kanbanRunFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get kanbanRunFailed;

  /// No description provided for @kanbanRunCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get kanbanRunCancelled;

  /// No description provided for @kanbanEventTaskCreated.
  ///
  /// In en, this message translates to:
  /// **'Task created'**
  String get kanbanEventTaskCreated;

  /// No description provided for @kanbanEventTaskUpdated.
  ///
  /// In en, this message translates to:
  /// **'Task updated'**
  String get kanbanEventTaskUpdated;

  /// No description provided for @kanbanEventTaskDeleted.
  ///
  /// In en, this message translates to:
  /// **'Task deleted'**
  String get kanbanEventTaskDeleted;

  /// No description provided for @kanbanEventRunStarted.
  ///
  /// In en, this message translates to:
  /// **'Run started'**
  String get kanbanEventRunStarted;

  /// No description provided for @kanbanEventRunCompleted.
  ///
  /// In en, this message translates to:
  /// **'Run completed'**
  String get kanbanEventRunCompleted;

  /// No description provided for @kanbanEventRunFailed.
  ///
  /// In en, this message translates to:
  /// **'Run failed'**
  String get kanbanEventRunFailed;

  /// No description provided for @kanbanEventRunCancelled.
  ///
  /// In en, this message translates to:
  /// **'Run cancelled'**
  String get kanbanEventRunCancelled;

  /// No description provided for @kanbanEventCommentCreated.
  ///
  /// In en, this message translates to:
  /// **'Comment added'**
  String get kanbanEventCommentCreated;

  /// No description provided for @kanbanEventAttachmentAdded.
  ///
  /// In en, this message translates to:
  /// **'Attachment added'**
  String get kanbanEventAttachmentAdded;

  /// No description provided for @kanbanEventAttachmentDeleted.
  ///
  /// In en, this message translates to:
  /// **'Attachment deleted'**
  String get kanbanEventAttachmentDeleted;

  /// No description provided for @cloudRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get cloudRoleOwner;

  /// No description provided for @cloudRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get cloudRoleAdmin;

  /// No description provided for @cloudRoleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get cloudRoleMember;

  /// No description provided for @cloudRoleViewer.
  ///
  /// In en, this message translates to:
  /// **'Viewer'**
  String get cloudRoleViewer;

  /// No description provided for @chatStatusToolDrafting.
  ///
  /// In en, this message translates to:
  /// **'Preparing tool call'**
  String get chatStatusToolDrafting;

  /// No description provided for @chatStatusProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider status'**
  String get chatStatusProvider;

  /// No description provided for @previewScriptError.
  ///
  /// In en, this message translates to:
  /// **'Script error'**
  String get previewScriptError;

  /// No description provided for @previewUnhandledPromiseRejection.
  ///
  /// In en, this message translates to:
  /// **'Unhandled promise rejection: '**
  String get previewUnhandledPromiseRejection;

  /// No description provided for @botGroupSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Group: {roomId}'**
  String botGroupSessionTitle(String roomId);

  /// No description provided for @errorExpectedObjectResponse.
  ///
  /// In en, this message translates to:
  /// **'The server returned an invalid object response'**
  String get errorExpectedObjectResponse;

  /// No description provided for @errorTtsNoAudio.
  ///
  /// In en, this message translates to:
  /// **'Text-to-speech returned no audio'**
  String get errorTtsNoAudio;

  /// No description provided for @errorInvalidDataUrl.
  ///
  /// In en, this message translates to:
  /// **'The server returned an invalid data URL'**
  String get errorInvalidDataUrl;

  /// No description provided for @errorExportDirectoryMissing.
  ///
  /// In en, this message translates to:
  /// **'The server did not provide an export directory'**
  String get errorExportDirectoryMissing;

  /// No description provided for @errorImportDirectoryMissing.
  ///
  /// In en, this message translates to:
  /// **'The server did not provide an import directory'**
  String get errorImportDirectoryMissing;

  /// No description provided for @errorRawConfigInvalid.
  ///
  /// In en, this message translates to:
  /// **'The server returned an invalid raw configuration'**
  String get errorRawConfigInvalid;

  /// No description provided for @errorPluginToggleRejected.
  ///
  /// In en, this message translates to:
  /// **'The backend rejected the plugin change'**
  String get errorPluginToggleRejected;

  /// No description provided for @errorConnectionNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'The connection is not configured'**
  String get errorConnectionNotConfigured;

  /// No description provided for @errorSessionOwnerUnknown.
  ///
  /// In en, this message translates to:
  /// **'The session owner is unknown: {sessionId}'**
  String errorSessionOwnerUnknown(String sessionId);

  /// No description provided for @errorRemotePushUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Remote push is unavailable for this connection'**
  String get errorRemotePushUnavailable;

  /// No description provided for @sshCommandTimedOut.
  ///
  /// In en, this message translates to:
  /// **'SSH command timed out'**
  String get sshCommandTimedOut;

  /// No description provided for @sshRemoteHomeUnsafe.
  ///
  /// In en, this message translates to:
  /// **'The remote Hermes home is unsafe'**
  String get sshRemoteHomeUnsafe;

  /// No description provided for @sshOwnershipVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not verify remote Hermes process ownership'**
  String get sshOwnershipVerificationFailed;

  /// No description provided for @sshOwnershipProbeFailed.
  ///
  /// In en, this message translates to:
  /// **'Remote ownership probe failed ({status})'**
  String sshOwnershipProbeFailed(String status);

  /// No description provided for @sshHelperInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'The remote helper returned invalid JSON'**
  String get sshHelperInvalidJson;

  /// No description provided for @sshWindowsOwnershipVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not verify remote Windows process ownership'**
  String get sshWindowsOwnershipVerificationFailed;

  /// No description provided for @sshRemotePathInvalid.
  ///
  /// In en, this message translates to:
  /// **'The remote Hermes path must be absolute or start with ~/'**
  String get sshRemotePathInvalid;

  /// No description provided for @sshExecutableNotFound.
  ///
  /// In en, this message translates to:
  /// **'The configured Hermes executable was not found on the remote host'**
  String get sshExecutableNotFound;

  /// No description provided for @sshHermesNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Hermes is not installed on the remote host'**
  String get sshHermesNotInstalled;

  /// No description provided for @sshBootstrapFlagsUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Remote Hermes must support secure SSH ownership bootstrap flags'**
  String get sshBootstrapFlagsUnsupported;

  /// No description provided for @sshWindowsIdentityInvalid.
  ///
  /// In en, this message translates to:
  /// **'The remote Windows backend returned an invalid identity'**
  String get sshWindowsIdentityInvalid;

  /// No description provided for @sshWindowsExitedBeforeReady.
  ///
  /// In en, this message translates to:
  /// **'The remote Windows backend exited before becoming ready'**
  String get sshWindowsExitedBeforeReady;

  /// No description provided for @sshWindowsOwnershipProofFailed.
  ///
  /// In en, this message translates to:
  /// **'Remote Windows ownership proof failed'**
  String get sshWindowsOwnershipProofFailed;

  /// No description provided for @sshProcessIdMissing.
  ///
  /// In en, this message translates to:
  /// **'Remote Hermes did not return a process ID'**
  String get sshProcessIdMissing;

  /// No description provided for @sshExitedBeforeReady.
  ///
  /// In en, this message translates to:
  /// **'Remote Hermes exited before becoming ready'**
  String get sshExitedBeforeReady;

  /// No description provided for @sshOwnershipProofFailed.
  ///
  /// In en, this message translates to:
  /// **'Remote Hermes ownership proof failed'**
  String get sshOwnershipProofFailed;

  /// No description provided for @errorSessionBranchIdMissing.
  ///
  /// In en, this message translates to:
  /// **'Hermes did not return a durable branched session ID'**
  String get errorSessionBranchIdMissing;

  /// No description provided for @errorDuplicateImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Hermes did not import the duplicated session'**
  String get errorDuplicateImportFailed;

  /// No description provided for @errorSessionNoTitleableMessages.
  ///
  /// In en, this message translates to:
  /// **'The session has no messages that can be used to generate a title'**
  String get errorSessionNoTitleableMessages;

  /// No description provided for @errorTitleGeneratorEmpty.
  ///
  /// In en, this message translates to:
  /// **'The title generator returned an empty title'**
  String get errorTitleGeneratorEmpty;

  /// No description provided for @errorProjectIdRequired.
  ///
  /// In en, this message translates to:
  /// **'A project is required'**
  String get errorProjectIdRequired;

  /// No description provided for @errorProjectWorkingFolderMissing.
  ///
  /// In en, this message translates to:
  /// **'The target project has no working folder'**
  String get errorProjectWorkingFolderMissing;

  /// No description provided for @errorDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get errorDownloadFailed;

  /// No description provided for @errorMessagingPlatformNotFound.
  ///
  /// In en, this message translates to:
  /// **'Messaging platform not found'**
  String get errorMessagingPlatformNotFound;

  /// No description provided for @errorBotGroupSessionStartFailed.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s group session did not start'**
  String errorBotGroupSessionStartFailed(String name);

  /// No description provided for @sshRemoteCommandFailed.
  ///
  /// In en, this message translates to:
  /// **'Remote command failed ({code})'**
  String sshRemoteCommandFailed(String code);

  /// No description provided for @sshHostAndUserRequired.
  ///
  /// In en, this message translates to:
  /// **'SSH host and user are required'**
  String get sshHostAndUserRequired;

  /// No description provided for @sshPortInvalid.
  ///
  /// In en, this message translates to:
  /// **'SSH port must be between 1 and 65535'**
  String get sshPortInvalid;

  /// No description provided for @sshHostKeyChanged.
  ///
  /// In en, this message translates to:
  /// **'The SSH host key for {host} changed. Expected {expected}; received {received}'**
  String sshHostKeyChanged(String host, String expected, String received);

  /// No description provided for @sshProfileInvalid.
  ///
  /// In en, this message translates to:
  /// **'The remote profile name is invalid'**
  String get sshProfileInvalid;

  /// No description provided for @errorDirectGatewayFeatureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This feature requires Hermes Mobile Server and is unavailable on a direct Gateway connection'**
  String get errorDirectGatewayFeatureUnavailable;

  /// No description provided for @errorOperationFailedWithDetail.
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {error}'**
  String errorOperationFailedWithDetail(String error);

  /// No description provided for @gatewayOauthRejected.
  ///
  /// In en, this message translates to:
  /// **'Gateway rejected sign-in: {error}'**
  String gatewayOauthRejected(String error);

  /// No description provided for @gatewayOauthCodeMissing.
  ///
  /// In en, this message translates to:
  /// **'The Gateway callback is missing the authorization code'**
  String get gatewayOauthCodeMissing;

  /// No description provided for @gatewayOauthStateMismatch.
  ///
  /// In en, this message translates to:
  /// **'The Gateway callback state did not match. Sign-in was cancelled for security.'**
  String get gatewayOauthStateMismatch;

  /// No description provided for @gatewayOauthRefreshTokenMissing.
  ///
  /// In en, this message translates to:
  /// **'The Gateway session expired and has no refresh token'**
  String get gatewayOauthRefreshTokenMissing;

  /// No description provided for @gatewayOauthTicketMissing.
  ///
  /// In en, this message translates to:
  /// **'The Gateway did not return a WebSocket ticket'**
  String get gatewayOauthTicketMissing;

  /// No description provided for @gatewayOauthAccessTokenMissing.
  ///
  /// In en, this message translates to:
  /// **'The Gateway token response did not include an access token'**
  String get gatewayOauthAccessTokenMissing;

  /// No description provided for @gatewayOauthTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Gateway sign-in timed out'**
  String get gatewayOauthTimedOut;

  /// No description provided for @gatewayOauthNativeUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Native Gateway OAuth is not supported on this platform'**
  String get gatewayOauthNativeUnsupported;

  /// No description provided for @updateManifestInvalid.
  ///
  /// In en, this message translates to:
  /// **'The update manifest is invalid'**
  String get updateManifestInvalid;

  /// No description provided for @sshRemotePlatformUnsupported.
  ///
  /// In en, this message translates to:
  /// **'The remote platform is unsupported: {error}'**
  String sshRemotePlatformUnsupported(String error);

  /// No description provided for @sshWebUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Native SSH connections are not supported on web'**
  String get sshWebUnsupported;

  /// No description provided for @filesDownloadPlatformUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Local file download is unavailable on this platform'**
  String get filesDownloadPlatformUnsupported;

  /// No description provided for @sessionExportPlatformUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Local file export is unavailable on this platform'**
  String get sessionExportPlatformUnsupported;

  /// No description provided for @errorPluginCanonicalKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'This plugin needs a canonical key before it can be changed'**
  String get errorPluginCanonicalKeyRequired;

  /// No description provided for @connectGatewayToken.
  ///
  /// In en, this message translates to:
  /// **'Gateway token'**
  String get connectGatewayToken;

  /// No description provided for @modelMoaTitle.
  ///
  /// In en, this message translates to:
  /// **'Mixture of Agents'**
  String get modelMoaTitle;

  /// No description provided for @insightsTokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens'**
  String get insightsTokens;

  /// No description provided for @messageWebFallback.
  ///
  /// In en, this message translates to:
  /// **'Web'**
  String get messageWebFallback;

  /// No description provided for @mcpLogsSourceStdio.
  ///
  /// In en, this message translates to:
  /// **'stdio'**
  String get mcpLogsSourceStdio;

  /// No description provided for @mcpLogsSourceAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get mcpLogsSourceAgent;

  /// No description provided for @projectPrimaryFolder.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get projectPrimaryFolder;

  /// No description provided for @botGroupNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a group name'**
  String get botGroupNameRequired;

  /// No description provided for @botGroupMembersMinimum.
  ///
  /// In en, this message translates to:
  /// **'A group needs at least two bots'**
  String get botGroupMembersMinimum;

  /// No description provided for @botGroupMembersRange.
  ///
  /// In en, this message translates to:
  /// **'A group needs 2–{max} bots'**
  String botGroupMembersRange(int max);

  /// No description provided for @botGroupMembersMaximum.
  ///
  /// In en, this message translates to:
  /// **'A group supports at most {max} bots'**
  String botGroupMembersMaximum(int max);

  /// No description provided for @botGroupMemberUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No group member is available'**
  String get botGroupMemberUnavailable;

  /// No description provided for @botProfileNameUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No free profile name is available'**
  String get botProfileNameUnavailable;

  /// No description provided for @botDefaultProfileDeleteForbidden.
  ///
  /// In en, this message translates to:
  /// **'The default profile cannot be deleted'**
  String get botDefaultProfileDeleteForbidden;

  /// No description provided for @botConnectionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The bot connection is unavailable'**
  String get botConnectionUnavailable;

  /// No description provided for @botTurnFailed.
  ///
  /// In en, this message translates to:
  /// **'The bot turn failed'**
  String get botTurnFailed;

  /// No description provided for @mcpInvalidJsonSyntax.
  ///
  /// In en, this message translates to:
  /// **'The JSON syntax is invalid'**
  String get mcpInvalidJsonSyntax;

  /// No description provided for @mcpJsonObjectRequired.
  ///
  /// In en, this message translates to:
  /// **'The top-level JSON value must be an object'**
  String get mcpJsonObjectRequired;

  /// No description provided for @voiceWakeMicStreamEnded.
  ///
  /// In en, this message translates to:
  /// **'The wake word microphone stream ended unexpectedly'**
  String get voiceWakeMicStreamEnded;

  /// No description provided for @httpStatusError.
  ///
  /// In en, this message translates to:
  /// **'The server returned HTTP {statusCode}'**
  String httpStatusError(int statusCode);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
