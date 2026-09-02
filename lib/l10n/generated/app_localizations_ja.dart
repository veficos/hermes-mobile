// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get commonCopyFailed => 'クリップボードにコピーできませんでした';

  @override
  String get commonClipboardReadFailed => 'クリップボードを読み取れませんでした';

  @override
  String petGenerateReferenceFailed(String error) {
    return '参照画像を追加できませんでした：$error';
  }

  @override
  String petSelectFailed(String error) {
    return 'ペットを選択できませんでした：$error';
  }

  @override
  String terminalSshNamed(String host) {
    return 'SSH $host';
  }

  @override
  String get deepLinkUnsupported => '対応していない Hermes リンクです';

  @override
  String get deepLinkMcpNameInvalid => 'MCP 名の形式が無効です';

  @override
  String get deepLinkMcpConfigMissing => 'MCP リンクに設定がありません';

  @override
  String get deepLinkMcpConfigTooLarge => 'MCP 設定が 32 KiB を超えています';

  @override
  String get deepLinkMcpEncodingInvalid => 'MCP 設定のエンコードが無効です';

  @override
  String get deepLinkMcpJsonInvalid => 'MCP 設定が有効な JSON ではありません';

  @override
  String get deepLinkMcpObjectRequired => 'MCP 設定はオブジェクトである必要があります';

  @override
  String get deepLinkMcpUrlCommandConflict =>
      'MCP 設定に URL とコマンドの両方を含めることはできません';

  @override
  String get deepLinkMcpHttpOnly => 'MCP URL は HTTP または HTTPS のみ対応します';

  @override
  String get deepLinkMcpEndpointMissing => 'MCP 設定に URL またはコマンドがありません';

  @override
  String get terminalConnectionClosed => 'ターミナル接続は閉じられています';

  @override
  String terminalRequestFailed(String error) {
    return 'ターミナルリクエストを送信できませんでした: $error';
  }

  @override
  String get terminalGenericError => 'ターミナルエラー';

  @override
  String get botUntitledTask => '無題のタスク';

  @override
  String botMemberPaused(String name) {
    return '$name は一時停止中です。このメンバーにメンションするか resume を送信すると再開します。';
  }

  @override
  String get botRoutineFieldsRequired => 'タスク名、指示、スケジュールは必須です';

  @override
  String get botRoutineNulForbidden => 'タスク名、指示、スケジュールに NUL を含めることはできません';

  @override
  String get pluginLoadActionReadOnly =>
      'プラグイン view.load_action は読み取り専用である必要があります';

  @override
  String get pluginMethodMissing => 'プラグイン action に method がありません';

  @override
  String get pluginPathInvalid => 'プラグイン action path が無効です';

  @override
  String pluginMethodUnsupported(String method) {
    return '対応していないプラグイン REST method: $method';
  }

  @override
  String get pluginUrlInvalid => 'プラグイン action URL が無効です';

  @override
  String get pluginUrlSchemeUnsupported => 'プラグイン action URL scheme は対応していません';

  @override
  String get pluginLinkOpenFailed => 'リンクを開けませんでした';

  @override
  String get pluginNotificationFieldsMissing =>
      'プラグイン通知 action に title または message がありません';

  @override
  String get pluginNotificationUnavailable => 'このホストでは通知を利用できません';

  @override
  String pluginActionUnsupported(String kind) {
    return 'モバイルではプラグイン action に対応していません: $kind';
  }

  @override
  String get kanbanTaskAlreadyRunning => 'タスクはすでに実行中です';

  @override
  String get gatewayUnavailable => 'Hermes バックエンド Gateway を利用できません';

  @override
  String get filesDirectoryMissing => 'ディレクトリが存在しません';

  @override
  String get filesFolderFallback =>
      'このプラットフォームではローカルフォルダーを一覧表示できません。複数のファイルを選択してください。';

  @override
  String get billingCreditsExhausted => '残高またはクレジット上限を使い切りました';

  @override
  String workspacePaneLimit(int count) {
    return 'ワークスペースで同時に開けるペインは $count 件までです';
  }

  @override
  String get projectMissing => 'プロジェクトが存在しないか、削除されました';

  @override
  String updateHttpError(int status) {
    return '更新サービスが HTTP $status を返しました';
  }

  @override
  String get chatCompactingThread => 'スレッドを要約中';

  @override
  String get chatModelChanged => 'モデルが変更されました';

  @override
  String get chatTurnContinued => '中断したターンを再開しました';

  @override
  String get chatPersonalityChanged => 'パーソナリティが変更されました';

  @override
  String get chatDelegationCompleted => 'バックグラウンドエージェントの作業が完了しました';

  @override
  String chatDelegationCountCompleted(int count) {
    return 'バックグラウンドエージェントタスク $count 件が完了';
  }

  @override
  String get chatHermesNotification => 'Hermes 通知';

  @override
  String get chatBrowserTask => 'ブラウザタスク';

  @override
  String get chatPreviewRestart => 'プレビューサービスの再起動';

  @override
  String chatPreparingTool(String name) {
    return '$name を準備中';
  }

  @override
  String get chatMoaAggregating => '◇ 複数モデルの結果を集約中…';

  @override
  String get chatMoaCollaboration => '複数モデルの協調';

  @override
  String get chatCurrentGoal => '現在の目標';

  @override
  String get chatCodeReview => 'コードレビュー';

  @override
  String get chatHermesRunFailed => 'Hermes の実行に失敗しました';

  @override
  String get chatPlanItem => '計画項目';

  @override
  String get chatAssistantReplyFailed => 'アシスタントの返信に失敗しました';

  @override
  String get terminalServerNotConfigured => 'サーバーが設定されていません';

  @override
  String terminalLimitReached(int count) {
    return '同時に開けるターミナルは $count 件までです。先にセッションを閉じてください。';
  }

  @override
  String terminalNumbered(int number) {
    return 'ターミナル $number';
  }

  @override
  String get terminalSnapshotStart => '-- 前回セッションの読み取り専用出力スナップショット --';

  @override
  String get terminalSnapshotEnd => '-- スナップショット終了。ターミナルを復元中 --';

  @override
  String get terminalSshHostRequired => 'SSH ホストは必須です';

  @override
  String get terminalRestartingShell => '-- shell を再起動中… --';

  @override
  String get terminalOpenedNewShell =>
      '-- 元の shell を復元できないため、新しい shell を開きました --';

  @override
  String get terminalPtyIdMissing => 'サーバーが PTY セッション ID を返しませんでした';

  @override
  String terminalShellExited(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'other': ' (code $code)',
      'empty': '',
    });
    return '-- shell が終了しました$_temp0 · 「再起動」をタップして続行 --';
  }

  @override
  String get terminalReconnecting => 'ターミナル接続が中断しました。再接続中…';

  @override
  String get terminalRestoringShell => '-- 接続が中断しました。shell を復元または再オープン中… --';

  @override
  String get terminalConnectionRestored => '-- ターミナル接続を復元しました --';

  @override
  String get terminalConnectionRestoreFailed => '-- ターミナル接続を復元できませんでした --';

  @override
  String get terminalReconnected => 'ターミナルに再接続しました。新しい shell が開かれた可能性があります';

  @override
  String get terminalReconnectFailed => 'ターミナルに再接続できません。新しいターミナルを手動で作成してください。';

  @override
  String get sessionChooseHandoffPlatform => '引き継ぎ先を選択してください';

  @override
  String sessionHandoffTargetFailed(String target) {
    return '$target への引き継ぎに失敗しました';
  }

  @override
  String get sessionHandoffTimeout => '引き継ぎがタイムアウトしました。もう一度お試しください。';

  @override
  String get sessionNoActive => 'アクティブなセッションがありません';

  @override
  String sessionLoadMoreFailed(String error) {
    return 'セッションを追加読み込みできませんでした: $error';
  }

  @override
  String get sessionOfflineTranscript => 'オフラインモード: キャッシュ済みのトランスクリプトを表示中';

  @override
  String sessionTranscriptRefreshFailed(String error) {
    return 'トランスクリプトを更新できませんでした: $error';
  }

  @override
  String sessionOlderMessagesFailed(String error) {
    return '古いメッセージを読み込めませんでした: $error';
  }

  @override
  String sessionListLoadFailed(String error) {
    return 'セッションを読み込めませんでした: $error';
  }

  @override
  String get sessionProfileSwitching => 'プロファイルを切り替え中です。少し待ってから再度お試しください。';

  @override
  String get sessionSubagentReadOnly => 'サブエージェントセッションは読み取り専用です';

  @override
  String get sessionChangedRetry => 'セッションが変更されました。少し待ってから再度お試しください。';

  @override
  String sessionConnectionUnknown(String id) {
    return 'セッションの接続先が不明です: $id';
  }

  @override
  String sessionConnectionUnavailable(String id) {
    return 'セッションの接続先を利用できません: $id';
  }

  @override
  String get sessionUnsavedTitle => 'セッションが保存されていないため、タイトルを生成できません';

  @override
  String get sessionShareLinkMissing => 'サーバーが共有リンクを返しませんでした';

  @override
  String sessionBatchDeletePartial(int deleted, int failed) {
    return '$deleted 件を削除、$failed 件は失敗';
  }

  @override
  String get sessionCouldNotCreate => 'セッションを作成できませんでした';

  @override
  String get sessionUserMessageMissing => '対応するユーザーメッセージが見つかりません';

  @override
  String get sessionRestoreMessageMissing => '復元するユーザーメッセージが見つかりません';

  @override
  String get sessionBranchMessageMissing => '分岐元のメッセージが見つかりません';

  @override
  String get sessionHistoryPositionMissing =>
      'このメッセージに履歴位置がありません。セッションを更新して再試行してください。';

  @override
  String get sessionRuntimeIdMissing => 'Hermes が実行時セッション ID を返しませんでした';

  @override
  String get aboutLicenses => 'オープンソースライセンス';

  @override
  String get aboutLicensesDescription => 'アプリが使用するサードパーティソフトウェアのライセンスを表示';

  @override
  String get aboutProductDescription => 'Hermes Agent のモバイルクライアント';

  @override
  String get aboutProductInfo => '製品情報';

  @override
  String get aboutTitle => 'Hermes について';

  @override
  String get appTitle => 'Hermes Mobile';

  @override
  String get appearanceHaptics => '触覚フィードバック';

  @override
  String get appearanceHapticsDesc => '送信・エラー・タスク完了時に振動でお知らせ';

  @override
  String get appearanceHighContrast => '高コントラスト';

  @override
  String get appearanceHighContrastDesc => '文字と境界線のコントラストを強化';

  @override
  String get appearanceKeepAwake => '画面をスリープさせない';

  @override
  String get appearanceKeepAwakeDesc => 'チャットを開いている間、画面が自動ロックされないようにします';

  @override
  String get appearanceModeDark => 'ダーク';

  @override
  String get appearanceModeLight => 'ライト';

  @override
  String get appearanceModeSystem => 'システム';

  @override
  String get appearanceThemeColor => 'テーマカラー';

  @override
  String get appearanceTitle => '外観';

  @override
  String get approvalRequests => '承認リクエスト';

  @override
  String get backendConnected => 'バックエンド接続済み';

  @override
  String get backendDisconnected => 'バックエンド未接続';

  @override
  String get billingAccountBalance => 'アカウント残高';

  @override
  String get billingAccountTab => 'アカウント';

  @override
  String get billingAmountUsd => '金額 (USD)';

  @override
  String get billingAutoReload => '自動追加';

  @override
  String get billingAutoReloadDescription => '残高がしきい値を下回ったらクレジットを追加';

  @override
  String get billingAutoReloadDisabled => '自動追加を無効にしました';

  @override
  String get billingAutoReloadEnabled => '自動追加を有効にしました';

  @override
  String get billingAutoReloadUpdateFailed => '自動追加を更新できませんでした';

  @override
  String get billingAvailableCredits => '利用可能なクレジット';

  @override
  String get billingCancelAtPeriodEnd => '期間終了時にサブスクリプションをキャンセル';

  @override
  String get billingCancelAtPeriodEndDescription => '現在のプラン特典はこの期間の終了まで利用できます。';

  @override
  String get billingCancelAtPeriodEndQuestion => '期間終了時にキャンセルしますか？';

  @override
  String get billingCancelFailed => 'サブスクリプションをキャンセルできませんでした';

  @override
  String get billingChargeCompleted => 'クレジットの購入が完了しました';

  @override
  String get billingChargeForbidden => 'このアカウントはアプリからクレジットを購入できません';

  @override
  String get billingChargeIncomplete => 'クレジットの購入が完了しませんでした';

  @override
  String get billingConfirmCancellation => 'キャンセルを確定';

  @override
  String get billingConfirmPurchase => '購入を確定';

  @override
  String get billingConfirmUpgrade => 'プランのアップグレードを確認してください。';

  @override
  String billingCreditsPerMonth(Object credits) {
    return '$credits クレジット/月';
  }

  @override
  String get billingCurrent => '現在';

  @override
  String get billingDowngrade => 'ダウングレード';

  @override
  String get billingDowngradePeriodEnd => 'ダウングレードは現在の期間終了時に有効になります。';

  @override
  String get billingGatewayMissing => 'Hermes ゲートウェイに接続されていません';

  @override
  String get billingInvalidReloadValues => '有効なしきい値と追加金額を入力してください';

  @override
  String get billingLoading => '請求状況を読み込んでいます…';

  @override
  String get billingLoadingPlans => 'プラン一覧を読み込んでいます…';

  @override
  String get billingLoggedIn => 'ログイン済み';

  @override
  String get billingLoggedOut => '未ログイン';

  @override
  String get billingManageInPortal => 'Portal で管理';

  @override
  String billingMaximumCharge(Object amount) {
    return '最大 \$$amount';
  }

  @override
  String billingMinimumCharge(Object amount) {
    return '最小 \$$amount';
  }

  @override
  String get billingMonthlySpendingCap => '月間リモート支出上限';

  @override
  String get billingNoActivePlan => '有効なプランはありません';

  @override
  String get billingNoPlans => '利用可能なプラン一覧がありません';

  @override
  String get billingNoUsageData => '使用量データがありません';

  @override
  String get billingNoUsageDescription =>
      'ゲートウェイから Remote Spending の使用量モデルが返されていません。';

  @override
  String get billingNotConnected => 'Hermes に接続されていません';

  @override
  String get billingNotProvided => '未設定';

  @override
  String get billingNotSet => '未設定';

  @override
  String get billingOpenPortal => 'Portal を開く';

  @override
  String get billingOpenVerification => '確認ページを開く';

  @override
  String get billingPaymentIncomplete => '支払いが完了しませんでした';

  @override
  String get billingPaymentMethod => '支払い方法';

  @override
  String get billingPaymentTimeout =>
      '支払い状況の確認がタイムアウトしました。Portal で結果を確認してください。';

  @override
  String get billingPending => '適用待ち';

  @override
  String billingPendingCancellation(Object date) {
    return '$date にキャンセル';
  }

  @override
  String billingPendingDowngrade(Object date, Object name) {
    return '$date に $name へダウングレード';
  }

  @override
  String billingPerMonth(Object price) {
    return '$price/月';
  }

  @override
  String get billingPeriodEnd => '期間終了時';

  @override
  String get billingPlanAlreadyActive => 'このプランはすでに使用中です。';

  @override
  String billingPlanChangeEffectiveAt(Object date) {
    return 'プラン変更は $date に有効になります。';
  }

  @override
  String get billingPlanChangeFailed => 'プランを変更できませんでした';

  @override
  String get billingPlanChangeForbidden => 'このアカウントにはプランを変更する権限がありません';

  @override
  String get billingPlanChangePeriodEnd => 'プラン変更は現在の期間終了時に有効になります。';

  @override
  String get billingPlanChangeUnavailable => 'この変更は現在利用できません。';

  @override
  String get billingPlanCredits => 'プランクレジット';

  @override
  String get billingPlansTab => 'プラン';

  @override
  String get billingPortalMissing => 'サーバーから請求 Portal の URL が提供されていません';

  @override
  String get billingPortalOpenFailed => '請求 Portal を開けませんでした';

  @override
  String get billingPurchaseCredits => 'クレジットを購入';

  @override
  String get billingReloadAboveMaximum => '追加金額がサーバーの最大値を超えています';

  @override
  String get billingReloadBelowMinimum => '追加金額がサーバーの最小値を下回っています';

  @override
  String get billingReloadTo => '追加後の残高';

  @override
  String billingRemaining(Object amount) {
    return '残り $amount';
  }

  @override
  String billingRenews(Object date) {
    return '$date に更新';
  }

  @override
  String get billingResumeFailed => '保留中の変更を元に戻せませんでした';

  @override
  String get billingSaveAutoReload => '自動追加を保存';

  @override
  String billingSpentThisMonth(Object amount) {
    return '今月の使用額: $amount';
  }

  @override
  String billingSwitchPlan(Object name) {
    return '$name に切り替えますか？';
  }

  @override
  String get billingTitle => '請求';

  @override
  String get billingTopupCredits => '購入済みクレジット';

  @override
  String get billingTriggerThreshold => '開始しきい値';

  @override
  String get billingUnavailableForAccount => 'このアカウントでは利用できません';

  @override
  String billingUpgradeAmount(Object amount) {
    return 'アップグレードはすぐに有効になります。今回の支払額: \$$amount。';
  }

  @override
  String get billingUpgradeChargeNow => 'アップグレードはすぐに有効になり、料金が発生します。';

  @override
  String get billingUsageTab => '使用量';

  @override
  String billingUsedOf(Object spent, Object total) {
    return '$total 中 $spent を使用';
  }

  @override
  String billingVerificationFailed(Object error) {
    return '確認に失敗しました: $error';
  }

  @override
  String get billingVerificationIncomplete => '確認が完了していません。しばらくしてから再試行してください。';

  @override
  String get billingVerificationInstructions =>
      'この端末からリモート支出操作を行うには、ブラウザーで確認を完了してください。';

  @override
  String get billingVerificationRequired => '追加の確認が必要です';

  @override
  String get billingVerificationStarting => '確認を開始しています…';

  @override
  String get billingVerificationSucceeded => '確認が完了しました。続行できます。';

  @override
  String get billingVerifyAndContinue => '確認して続行';

  @override
  String get billingViewSubscriptionInPortal => 'Portal でサブスクリプションを確認できます。';

  @override
  String get chatAbsoluteServerPath => 'サーバー上の絶対パスを使用';

  @override
  String get chatAddImage => '画像を追加';

  @override
  String chatAddImageFailed(String error) {
    return '画像を追加できませんでした：$error';
  }

  @override
  String chatAddedToQueue(int count) {
    return 'キューに追加しました（待機中 $count 件）';
  }

  @override
  String get chatAllDates => 'すべての日付';

  @override
  String get chatAllHistoryShown => 'すべての履歴を表示しました';

  @override
  String get chatApprovalManual => '手動';

  @override
  String get chatApprovalManualDescription => 'すべてのステップで確認します';

  @override
  String get chatApprovalMode => '承認モード';

  @override
  String chatApprovalModeFailed(String error) {
    return '承認モードを設定できませんでした：$error';
  }

  @override
  String chatApprovalModeSet(String mode) {
    return '承認モードを $mode に設定しました';
  }

  @override
  String get chatApprovalOff => 'オフ';

  @override
  String get chatApprovalOffDescription => '確認なしで実行します';

  @override
  String get chatApprovalSmart => 'スマート';

  @override
  String get chatApprovalSmartDescription => 'リスクのある操作のときだけ確認します';

  @override
  String get chatApprovalsUsage => '使い方：/approvals manual|smart|off';

  @override
  String chatArtifactVersions(int count) {
    return 'すべてのバージョン（$count）';
  }

  @override
  String get chatAssistant => 'アシスタント';

  @override
  String get chatAttach => '添付';

  @override
  String get chatAttachFiles => 'ファイルを添付';

  @override
  String get chatAttachLink => 'リンクを添付';

  @override
  String chatAttachmentUploadFailed(String error) {
    return '添付ファイルをアップロードできませんでした：$error';
  }

  @override
  String get chatAutoRetried => '自動的に再試行しました';

  @override
  String get chatBackToNewerMessages => '新しいメッセージに戻る';

  @override
  String get chatBackToWorkspace => 'ワークスペースに戻る';

  @override
  String get chatBackgroundAgentRunning =>
      'バックグラウンドエージェントが実行中です · 完了後にこのターンを再開します';

  @override
  String chatBackgroundAgentsRunning(int count) {
    return '$count 件のバックグラウンドエージェントが実行中です · 完了後に再開します';
  }

  @override
  String chatBackgroundCount(int count) {
    return 'バックグラウンドタスク $count 件';
  }

  @override
  String get chatBackgroundPrompt => 'バックグラウンドタスクの指示';

  @override
  String chatBackgroundSubmitFailed(String error) {
    return 'バックグラウンドタスクを送信できませんでした：$error';
  }

  @override
  String get chatBackgroundSubmitted => 'バックグラウンドタスクを送信しました';

  @override
  String chatBackgroundSubmittedWithId(String id) {
    return 'バックグラウンドタスクを送信しました（$id）';
  }

  @override
  String chatBackgroundTaskCompleted(String label) {
    return '$label が完了しました';
  }

  @override
  String chatBackgroundTaskFailed(String label) {
    return '$label が失敗しました';
  }

  @override
  String get chatBasicToolsets => '基本ツールセット';

  @override
  String get chatBranch => 'ブランチ';

  @override
  String chatBranchChanges(String branch, int changedFiles) {
    return '$branch ・ 変更ファイル $changedFiles 件';
  }

  @override
  String get chatBranchCreated => 'ブランチセッションを作成しました';

  @override
  String chatBranchCreatedWithId(String id) {
    return 'ブランチセッションを作成しました（$id）';
  }

  @override
  String chatBranchFailed(String error) {
    return 'ブランチを作成できませんでした：$error';
  }

  @override
  String get chatBranchInNewSession => '新しいセッションでブランチ';

  @override
  String get chatBranchedHere => 'この時点からブランチしました';

  @override
  String chatBranchedWithId(String id) {
    return 'この時点からブランチしました（$id）';
  }

  @override
  String chatBranchesLoadFailed(String error) {
    return 'ブランチを読み込めませんでした：$error';
  }

  @override
  String get chatBrowseArtifactsDescription => 'このセッションで生成された成果物を参照';

  @override
  String get chatBrowseFiles => 'ファイルマネージャーを開く';

  @override
  String get chatBrowseFilesDescription => 'ファイルマネージャーでディレクトリを選択します';

  @override
  String get chatCancelKeyboardHint => 'キャンセル (Esc)';

  @override
  String get chatCatalogEmpty => '利用可能なサーバーがありません';

  @override
  String get chatChangeWorkspace => 'ワークスペースを切り替え';

  @override
  String get chatChangeWorkspaceDescription =>
      'AI は選択したサーバーディレクトリ内のファイルを読み書きします';

  @override
  String get chatClosePreview => 'プレビューを閉じる';

  @override
  String get chatCollapseStatusDetails => '詳細を折りたたむ';

  @override
  String get chatCollapseSubsessions => '子セッションを折りたたむ';

  @override
  String get chatCommandCompletedNoOutput => 'コマンドは完了しましたが出力はありません';

  @override
  String get chatCommandExecutionFailed => 'コマンドの実行に失敗しました';

  @override
  String chatCommandFailed(String error) {
    return 'コマンドが失敗しました：$error';
  }

  @override
  String get chatCommandMessageQueued => 'メッセージをキューに追加しました';

  @override
  String get chatCommandNoFillContent => '入力できる内容がありません';

  @override
  String get chatCommandNoSendableContent => '送信できる内容がありません';

  @override
  String get chatCommandQueued => 'コマンドをキューに追加しました';

  @override
  String get chatCommandSearchHint => '別のキーワードを試してください';

  @override
  String get chatCommandSearchFailed => 'コマンドを読み込めませんでした — 接続を確認してください';

  @override
  String get chatCommandStarting => 'コマンドを開始しています';

  @override
  String get chatCompositeToolsets => '複合ツールセット';

  @override
  String get chatCompressContext => '圧縮';

  @override
  String chatCompressionFailed(String error) {
    return 'コンテキストを圧縮できませんでした：$error';
  }

  @override
  String get chatCompressionRequested => 'コンテキストの圧縮を要求しました';

  @override
  String get chatConfigureProvider => 'プロバイダーを設定';

  @override
  String get chatConnecting => '接続中';

  @override
  String get chatConnectionFailed => '接続に失敗しました';

  @override
  String get chatContentFilled => '内容を入力しました';

  @override
  String get chatContextUsage => 'コンテキスト使用量';

  @override
  String chatContextUsagePercent(int percent) {
    return 'コンテキスト使用量 $percent%';
  }

  @override
  String get chatCopyAsMarkdown => 'Markdown としてコピー';

  @override
  String get chatCopyDiagnostics => '診断情報をコピー';

  @override
  String get chatCopySessionId => 'セッション ID をコピー';

  @override
  String get chatCopySessionLink => 'セッションリンクをコピー';

  @override
  String get chatCopyText => 'テキストをコピー';

  @override
  String get chatCreateScheduledTask => '定期タスクを作成';

  @override
  String chatCronSuggestion(String phrase) {
    return 'スケジュールを検出しました：$phrase';
  }

  @override
  String get chatCurrentSessionArtifacts => 'このセッションの成果物';

  @override
  String get chatCurrentSessionToolsets => '現在のセッションのツールセット';

  @override
  String get chatCurrentlyActive => '現在有効';

  @override
  String chatDeletePromptFailed(String error) {
    return 'プロンプトを削除できませんでした：$error';
  }

  @override
  String get chatDeliveryUncertain => '配信状況が不明です';

  @override
  String get chatDiagnosticsCopied => '診断情報をコピーしました';

  @override
  String chatDiagnosticsError(String error) {
    return 'エラー：$error';
  }

  @override
  String chatDiagnosticsModel(String provider, String model) {
    return 'モデル：$provider / $model';
  }

  @override
  String chatDiagnosticsTime(String time) {
    return '時刻：$time';
  }

  @override
  String get chatDiagnosticsTitle => '診断情報';

  @override
  String chatEditFailed(String error) {
    return '編集できませんでした：$error';
  }

  @override
  String get chatEditMessageHint => 'メッセージを編集…';

  @override
  String get chatEditMessageKeyboardHint =>
      'メッセージを編集…（Enter で送信、Shift+Enter で改行）';

  @override
  String get chatEmptyDescription =>
      'ストリーミング応答、ツール呼び出し、承認、確認をデスクトップ版と同様に利用できます。';

  @override
  String get chatEmptyTitle => 'Hermes と会話を始めましょう';

  @override
  String get chatEnterOtherDirectory => '別のディレクトリを入力';

  @override
  String get chatEnterWorkspacePath => 'ワークスペースのパスを入力';

  @override
  String get chatErrorAuth => '認証エラー';

  @override
  String get chatErrorBilling => '請求エラー';

  @override
  String get chatErrorNetwork => 'ネットワークエラー';

  @override
  String get chatErrorProvider => 'プロバイダーエラー';

  @override
  String get chatErrorRateLimit => 'レート制限に達しました';

  @override
  String get chatErrorReply => '返信エラー';

  @override
  String get chatExecuting => '実行中…';

  @override
  String chatExecutionFailed(String error) {
    return '実行に失敗しました：$error';
  }

  @override
  String get chatExpandStatusDetails => '詳細を展開';

  @override
  String get chatExpandSubsessions => '子セッションを展開';

  @override
  String chatFileTooLarge(int maxMb, String name) {
    return '$name は $maxMb MB の上限を超えています';
  }

  @override
  String get chatFillRetry => '再試行';

  @override
  String get chatFindHint => '現在の会話内を検索';

  @override
  String get chatFindInConversation => '会話内を検索';

  @override
  String chatFolderFilesAttached(int attached, int skipped) {
    return '$attached 件のファイルを添付しました（$skipped 件をスキップ）';
  }

  @override
  String get chatFolderPickerUnavailable => 'このプラットフォームではフォルダ選択を利用できません';

  @override
  String chatForwardedToCommand(String target) {
    return '/$target に転送しました';
  }

  @override
  String get chatGlobalCliToolsets => 'グローバル CLI ツールセット';

  @override
  String get chatGlobalToolsetsDescription => 'グローバル CLI ツールセットの切り替えは直ちに反映されます';

  @override
  String get chatGoals => '目標';

  @override
  String chatHandingOffTo(String name) {
    return '$name に引き継いでいます…';
  }

  @override
  String get chatHandoff => 'ハンドオフ';

  @override
  String get chatHandoffCompleted => '完了';

  @override
  String chatHandoffCompletedTo(String name) {
    return '$name に引き継ぎました';
  }

  @override
  String chatHandoffFailed(String error) {
    return '引き継ぎに失敗しました：$error';
  }

  @override
  String get chatHandoffFailedStatus => '失敗';

  @override
  String get chatHandoffGatewayRunning => '実行中';

  @override
  String chatHandoffPlatformsFailed(String error) {
    return '引き継ぎ先プラットフォームを読み込めませんでした：$error';
  }

  @override
  String get chatHandoffTimeout => '引き継ぎがタイムアウトしました';

  @override
  String get chatHandoffToPlatform => 'プラットフォームに引き継ぐ';

  @override
  String get chatHandoffWaiting => '待機中';

  @override
  String get chatHideStatus => '非表示';

  @override
  String get chatHistoryLocator => 'チャット履歴を探す';

  @override
  String chatHomeChannel(String name) {
    return 'ホームチャンネル：$name';
  }

  @override
  String get chatHomeChannelNotSet => 'ホームチャンネルが未設定です';

  @override
  String get chatHtmlPreview => 'HTML プレビュー';

  @override
  String get chatInflightRecovered => '進行中だった返信を復元しました';

  @override
  String get chatInsufficientQuota => '利用枠が不足しています';

  @override
  String get chatInvalidCommandAlias => '無効なコマンドエイリアスです';

  @override
  String get chatJumpToTopic => 'トピックへ移動';

  @override
  String get chatLast24Hours => '過去 24 時間';

  @override
  String get chatLast7Days => '過去 7 日間';

  @override
  String get chatLastTurnRetried => '直前のターンを再試行しました';

  @override
  String get chatLastTurnUndone => '直前のターンを取り消しました';

  @override
  String get chatLoadFailed => '読み込みに失敗';

  @override
  String get chatLoadOlderMessagesHint => '上にスクロールして古いメッセージを読み込む';

  @override
  String get chatLoadingCommands => 'コマンドを読み込んでいます…';

  @override
  String get chatLocalCommands => 'ローカルコマンド';

  @override
  String get chatLocateTopic => 'トピックを表示';

  @override
  String get chatLongPressCodingStatus =>
      'コーディング状況を長押しするとブランチ切り替えや worktree 作成ができます';

  @override
  String get chatMarkMessage => 'メッセージにマークを付ける';

  @override
  String get chatMarkdownCopied => 'Markdown としてコピーしました';

  @override
  String get chatMarkedOnly => 'マーク済みのみ';

  @override
  String chatMessageCount(int count) {
    return '$count 件のメッセージ';
  }

  @override
  String get chatModel => 'モデル';

  @override
  String get chatModelSwitchDeferred => 'モデルの切り替えは次のターンから適用されます';

  @override
  String chatModelSwitchFailed(String error) {
    return 'モデルを切り替えられませんでした：$error';
  }

  @override
  String chatModelsLoadFailed(String error) {
    return 'モデル一覧を読み込めませんでした：$error';
  }

  @override
  String chatMonthDay(int month, int day) {
    return '$month月$day日';
  }

  @override
  String get chatMyMessages => '自分のメッセージ';

  @override
  String get chatNewSessionOpened => '新しいセッションを開きました';

  @override
  String get chatNewWorktreeDescription => '新しい git worktree を作成します';

  @override
  String get chatNoActiveTurnQueued => '進行中のターンがないためキューに追加しました';

  @override
  String get chatNoConfigurableToolsets => '設定可能なツールセットがありません';

  @override
  String get chatNoContextData => 'コンテキストデータがありません';

  @override
  String get chatNoHandoffPlatforms => '引き継ぎ先のプラットフォームがありません';

  @override
  String get chatNoHandoffPlatformsDescription => '引き継ぎ可能なプラットフォームがまだ接続されていません';

  @override
  String get chatNoMatchingCommands => '一致するコマンドはありません';

  @override
  String get chatNoMatchingMessages => '一致するメッセージはありません';

  @override
  String get chatNoProfiles => '切り替え可能なプロファイルがありません';

  @override
  String get chatNoQueuedMessages => 'キューにメッセージはありません';

  @override
  String get chatNoRetryMessage => '再試行できるメッセージがありません';

  @override
  String get chatNoSavedPrompts => '保存されたプロンプトはまだありません';

  @override
  String get chatNoSessions => 'セッションがありません';

  @override
  String get chatNoText => 'テキストがありません';

  @override
  String get chatNoUploadableFolderFiles => 'このフォルダにアップロードできるファイルはありません';

  @override
  String get chatNotConfigured => '未設定';

  @override
  String get chatNotConnected => '未接続';

  @override
  String get chatOlderMessagesLoadFailed => '古いメッセージを読み込めませんでした。タップして再試行';

  @override
  String chatPendingRequests(String kind, int count) {
    return '$kind（他に $count 件保留中）';
  }

  @override
  String chatPlanProgress(int completed, int total) {
    return '$completed/$total 件完了';
  }

  @override
  String chatPreviewCount(int count) {
    return 'プレビュー $count 件';
  }

  @override
  String chatProfileSwitchFailed(String error) {
    return 'プロファイルを切り替えられませんでした: $error';
  }

  @override
  String chatProfileSwitched(String profile) {
    return '「$profile」に切り替えました';
  }

  @override
  String chatProfilesLoadFailed(String error) {
    return 'プロファイルを読み込めませんでした: $error';
  }

  @override
  String get chatPromptSaved => 'プロンプトを保存しました';

  @override
  String get chatProvider => 'プロバイダー';

  @override
  String get chatQueue => 'キュー';

  @override
  String chatQueueFailed(String error) {
    return 'キューに追加できませんでした：$error';
  }

  @override
  String get chatQueuePaused => '一時停止中';

  @override
  String chatQueueSummary(String label, int count, String expandLabel) {
    return '$label ・ $count 件 ・ $expandLabel';
  }

  @override
  String get chatQueueUsage => 'キューに追加する内容を入力してください';

  @override
  String get chatQueued => 'キューに追加しました';

  @override
  String get chatQueuedMessageUpdated => 'キュー内のメッセージを更新しました';

  @override
  String chatQueuedMinutesAgo(int minutes) {
    return '$minutes 分前にキューに追加';
  }

  @override
  String chatQueuedSecondsAgo(int seconds) {
    return '$seconds 秒前にキューに追加';
  }

  @override
  String get chatReasoningEffort => '推論の強度';

  @override
  String get chatReasoningEffortDescription =>
      'バックエンドの reasoning effort 設定を更新します';

  @override
  String chatReasoningEffortSet(String value) {
    return '推論の強度を $value に設定しました';
  }

  @override
  String chatReasoningEffortSetFailed(String error) {
    return '推論の強度を設定できませんでした: $error';
  }

  @override
  String get chatReconnecting => '再接続中';

  @override
  String get chatRegenerate => '再生成';

  @override
  String chatRegenerateFailed(String error) {
    return '再生成できませんでした：$error';
  }

  @override
  String get chatRegenerateTitle => 'タイトルを再生成';

  @override
  String chatRegenerateTitleFailed(String error) {
    return 'タイトルを再生成できませんでした：$error';
  }

  @override
  String get chatRename => '名前を変更';

  @override
  String get chatRenameSession => 'セッション名を変更';

  @override
  String get chatRequestApproval => '承認リクエスト';

  @override
  String get chatRequestMcpConfig => 'MCP セットアップ';

  @override
  String get chatRequestPassword => 'パスワードリクエスト';

  @override
  String get chatRequestQuestion => '質問リクエスト';

  @override
  String get chatRequestSecret => 'シークレットリクエスト';

  @override
  String get chatRequestTerminalInput => 'ターミナル入力リクエスト';

  @override
  String get chatRestoreAndRerun => '復元して再実行';

  @override
  String chatRestoreFailed(String error) {
    return '復元できませんでした：$error';
  }

  @override
  String get chatRestoreToMessage => 'このメッセージまで復元';

  @override
  String get chatRestoreToMessageTitle => 'このメッセージまで復元しますか？';

  @override
  String get chatRestoreVersionTitle => 'このバージョンを復元しますか？';

  @override
  String chatRetryFailed(String error) {
    return '再試行に失敗しました：$error';
  }

  @override
  String get chatRunInBackground => 'バックグラウンドで実行';

  @override
  String get chatSaveCurrentInput => '現在の入力を保存';

  @override
  String chatSavePromptFailed(String error) {
    return 'プロンプトを保存できませんでした：$error';
  }

  @override
  String get chatSavedPrompts => '保存済みのプロンプト';

  @override
  String chatSavedPromptsLoadFailed(String error) {
    return '保存済みのプロンプトを読み込めませんでした：$error';
  }

  @override
  String get chatScrollToBottom => '一番下へ移動';

  @override
  String get chatSearchLoadedHistory => '読み込み済みの履歴を検索';

  @override
  String chatSelectFilesFailed(String error) {
    return 'ファイルを選択できませんでした：$error';
  }

  @override
  String get chatSelectFolder => 'フォルダを選択';

  @override
  String chatSelectFolderFailed(String error) {
    return 'フォルダを選択できませんでした：$error';
  }

  @override
  String get chatSelectProfile => 'プロファイルを選択';

  @override
  String get chatSelectProfileDescription => 'ホームデータと今後の起動に使うプロファイルを選択します';

  @override
  String get chatSendDiagnostics => '診断情報を送信';

  @override
  String get chatSendEdit => '編集内容を送信';

  @override
  String get chatSendEditAndRerun => '編集を送信して再実行';

  @override
  String get chatSendEditTitle => '編集したメッセージを送信しますか？';

  @override
  String chatSendFailed(String error) {
    return '送信できませんでした：$error';
  }

  @override
  String get chatSendNow => '今すぐ送信';

  @override
  String get chatSendQueue => '送信キュー';

  @override
  String chatSendQueueCount(int count) {
    return '送信キュー ($count)';
  }

  @override
  String get chatServerCatalog => 'サーバーカタログ';

  @override
  String get chatServerDirectory => 'サーバーディレクトリ';

  @override
  String get chatServerDirectoryHelp => 'ディレクトリが存在し、サーバーアカウントにアクセス権が必要です';

  @override
  String get chatServerNotConnected => 'サーバーに接続されていません';

  @override
  String get chatSessionCleared => 'セッションをクリアしました';

  @override
  String get chatSessionIdCopied => 'セッション ID をコピーしました';

  @override
  String get chatSessionInfo => 'セッション情報';

  @override
  String get chatSessionMenu => 'セッションメニュー';

  @override
  String get chatSessionShareLinkCopied => 'セッションの共有リンクをコピーしました';

  @override
  String get chatSessionToolsetsDescription => 'セッション用ツールセット（現在のセッションのみに適用）';

  @override
  String get chatSessions => 'セッション';

  @override
  String get chatSetAsNext => '次に送信';

  @override
  String chatSetTitleFailed(String error) {
    return 'タイトルを設定できませんでした：$error';
  }

  @override
  String chatShareLinkFailed(String error) {
    return '共有リンクを取得できませんでした：$error';
  }

  @override
  String get chatShareUrlMissing => '共有リンクが返されませんでした';

  @override
  String get chatSkillsCenter => 'スキルセンター';

  @override
  String get chatSlashCommands => 'スラッシュコマンド';

  @override
  String get chatStartSessionBeforeWorkspace => 'ワークスペースを変更する前にセッションを開始してください';

  @override
  String get chatStarterDebugIssue => '問題を調査する';

  @override
  String get chatStarterDebugIssuePrompt => '問題が発生しました。まず調査の進め方を整理してください。';

  @override
  String get chatStarterExplainProject => 'このプロジェクトを説明';

  @override
  String get chatStarterExplainProjectPrompt =>
      'このプロジェクトの構成、主要機能、実行方法を簡潔に説明してください。';

  @override
  String get chatStarterReviewChanges => '現在の変更を確認';

  @override
  String get chatStarterReviewChangesPrompt =>
      '現在のワークスペースの変更を確認し、潜在的な問題と改善案を示してください。';

  @override
  String get chatSteerCurrentTurn => '現在のターンを操作';

  @override
  String get chatSteerHint => '操作メッセージ';

  @override
  String get chatSteerInjected => '操作メッセージを反映しました';

  @override
  String get chatSteerMessage => '操作';

  @override
  String chatSteerNowFailed(String error) {
    return 'すぐに操作できませんでした：$error';
  }

  @override
  String get chatSteerQueued => '操作メッセージをキューに追加しました';

  @override
  String get chatSteerUsage => '操作に使う内容を入力してください';

  @override
  String get chatStopProcess => '停止';

  @override
  String chatStopProcessFailed(String error) {
    return 'プロセスを停止できませんでした：$error';
  }

  @override
  String chatSubagentCount(int count) {
    return 'サブエージェント $count 件';
  }

  @override
  String get chatTextSnippet => 'テキストスニペット';

  @override
  String get chatTextSnippetHint => 'テキストを貼り付けるか入力してください';

  @override
  String get chatTitle => 'Hermes チャット';

  @override
  String chatTitleSet(String title) {
    return 'タイトルを「$title」に設定しました';
  }

  @override
  String get chatTitleUnchanged => 'タイトルは変更されていません';

  @override
  String chatTitleUpdated(String title) {
    return 'タイトルを「$title」に更新しました';
  }

  @override
  String get chatToday => '今日';

  @override
  String get chatToolConfiguration => 'ツール設定';

  @override
  String chatToolCount(int count) {
    return '$count 個のツール';
  }

  @override
  String get chatToolStatusMessage => 'ツールステータスメッセージ';

  @override
  String chatToolsetCounts(String sessionCount, String globalCount) {
    return 'セッション：$sessionCount ・ グローバル：$globalCount';
  }

  @override
  String chatToolsetToggleFailed(String name, String error) {
    return '$name を切り替えられませんでした: $error';
  }

  @override
  String chatToolsetsEnabled(String globalCount) {
    return 'グローバルツールセットを有効化しました（$globalCount）';
  }

  @override
  String get chatToolsetsExplanation =>
      '現在のセッションのツールセットは、このセッションで Hermes Agent が実際に登録して使用できるものです。\nグローバル CLI ツールセットは全体設定であり、すべてが現在のセッションに読み込まれるとは限りません。';

  @override
  String get chatToolsetsLoadFailed => 'ツールセットを読み込めませんでした';

  @override
  String chatTopicNumber(int index) {
    return 'トピック $index';
  }

  @override
  String chatTopicRailSemantics(int count) {
    return 'トピック $count 件';
  }

  @override
  String get chatTranscriptLoadFailed => 'チャット履歴を読み込めませんでした';

  @override
  String get chatTruncateWarning => 'これ以降のすべてのメッセージが削除され、元に戻せません';

  @override
  String chatUndoFailed(String error) {
    return '取り消せませんでした：$error';
  }

  @override
  String get chatUnknownCommandResult => '不明なコマンド結果です';

  @override
  String get chatUnknownTime => '時刻不明';

  @override
  String get chatUnmarkMessage => 'マークを解除';

  @override
  String get chatUntitled => '無題のセッション';

  @override
  String get chatUntitledSession => '無題のセッション';

  @override
  String get chatVersion => 'バージョン';

  @override
  String chatVersionCount(int count) {
    return 'バージョン $count 件';
  }

  @override
  String chatVersionLoadFailed(String error) {
    return 'バージョンを読み込めませんでした：$error';
  }

  @override
  String chatVersionNumber(int index) {
    return 'バージョン $index';
  }

  @override
  String get chatViewBilling => '請求情報を見る';

  @override
  String get chatViewCleared => '表示をクリアしました';

  @override
  String get chatWakeServiceUnavailable => 'ウェイクワードサービスが利用できません';

  @override
  String chatWakeVoiceFailed(String error) {
    return 'ウェイクワードに失敗しました：$error';
  }

  @override
  String chatWarning(String warning) {
    return '警告：$warning';
  }

  @override
  String get chatWorkingDirectory => '作業ディレクトリ';

  @override
  String get chatWorkspace => 'ワークスペース';

  @override
  String get chatWorkspaceFiles => 'ワークスペースのファイル';

  @override
  String chatWorkspaceSwitchFailed(String error) {
    return 'ワークスペースを変更できませんでした: $error';
  }

  @override
  String chatWorkspaceSwitched(String name) {
    return 'ワークスペースを $name に変更しました';
  }

  @override
  String get chatYesterday => '昨日';

  @override
  String get chatYoloDisabled => 'YOLO モードを無効にしました';

  @override
  String get chatYoloEnabled => 'YOLO モードを有効にしました';

  @override
  String get chatYoloMode => 'YOLO モード';

  @override
  String chatYoloToggleFailed(String error) {
    return 'YOLO モードを切り替えられませんでした：$error';
  }

  @override
  String get appSessionCompletedTitle => 'セッションが完了しました';

  @override
  String get appSessionCompletedBody => 'バックグラウンドセッションが完了しました。タップして結果を表示します。';

  @override
  String appOpenNotificationFailed(Object error) {
    return '通知のセッションを開けませんでした: $error';
  }

  @override
  String get deepLinkPluginInstallTitle => 'Hermes プラグインをインストール';

  @override
  String get deepLinkPluginInstallPrompt =>
      'このリンクは次のソースからバックエンドプラグインをインストールします:';

  @override
  String get deepLinkLegacyPluginWarning =>
      'これは旧 Desktop プラグインのリンクです。モバイルではバックエンド Agent 機能のみをインストールします。';

  @override
  String get deepLinkEnableAfterInstall => 'インストール後に有効化';

  @override
  String get deepLinkForceReinstall => '強制的に再インストール';

  @override
  String get deepLinkInstall => 'インストール';

  @override
  String deepLinkPluginInstalling(Object identifier) {
    return '$identifier をインストールしています…';
  }

  @override
  String get deepLinkPluginInstalled => 'プラグインをインストールしました';

  @override
  String deepLinkPluginInstallFailed(Object error) {
    return 'プラグインのインストールに失敗しました: $error';
  }

  @override
  String get deepLinkMcpAddTitle => 'MCP サーバーを追加';

  @override
  String get deepLinkMcpServerName => 'サーバー名';

  @override
  String get deepLinkMcpNameFormatError =>
      '1～64 文字の英数字、ピリオド、アンダースコア、ハイフンを使用してください';

  @override
  String get deepLinkMcpNameConflict => 'その名前は既に存在します。別の名前を指定してください。';

  @override
  String get deepLinkMcpCommandWarning =>
      'この設定は Hermes バックエンドでローカルコマンドを実行します。信頼できるソースの場合のみ続行してください。';

  @override
  String get deepLinkConfigPreview => '設定プレビュー';

  @override
  String deepLinkMcpAdded(Object name) {
    return 'MCP サーバー $name を追加しました';
  }

  @override
  String deepLinkMcpAddFailed(Object error) {
    return 'MCP サーバーを追加できませんでした: $error';
  }

  @override
  String get commonAdd => '追加';

  @override
  String get commonAll => 'すべて';

  @override
  String get commonAuthorize => '認証';

  @override
  String get commonBack => '戻る';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonCancelAll => 'すべてキャンセル';

  @override
  String get commonClose => '閉じる';

  @override
  String get commonCollapse => '折りたたむ';

  @override
  String get commonCompleted => '完了';

  @override
  String get commonConfirm => '確認';

  @override
  String get commonConnected => '接続済み';

  @override
  String get commonContinue => '続行';

  @override
  String get commonCopied => 'コピーしました';

  @override
  String get commonCreate => '作成';

  @override
  String get commonDefault => 'デフォルト';

  @override
  String get commonDelete => '削除';

  @override
  String get commonDisconnect => '切断';

  @override
  String get commonDisconnected => '未接続';

  @override
  String get commonDone => '完了';

  @override
  String get commonEdit => '編集';

  @override
  String get commonErrorTitle => 'エラーが発生しました';

  @override
  String get commonAuthenticationFailed => '認証に失敗しました。API キーを確認してください。';

  @override
  String get commonExpand => '展開';

  @override
  String get commonFile => 'ファイル';

  @override
  String get commonFolder => 'フォルダ';

  @override
  String get commonGotIt => '了解';

  @override
  String get commonHide => '非表示';

  @override
  String get commonIdle => '待機中';

  @override
  String get commonIgnore => '無視';

  @override
  String get commonLater => '後で';

  @override
  String get commonListSeparator => '、';

  @override
  String get commonLoading => '読み込み中…';

  @override
  String get commonManage => '管理';

  @override
  String get commonMore => 'その他';

  @override
  String get commonName => '名前';

  @override
  String get commonNew => '新規';

  @override
  String get commonNext => '次へ';

  @override
  String get commonNoMatches => '一致する結果はありません';

  @override
  String get commonNotifications => '通知';

  @override
  String get commonOffline => 'オフライン';

  @override
  String get commonOnline => 'オンライン';

  @override
  String get commonOperationFailed => '操作に失敗しました。もう一度お試しください。';

  @override
  String get commonNetworkFailed => 'サーバーに接続できません。ネットワークとサーバーの状態を確認してください。';

  @override
  String get commonOpen => '開く';

  @override
  String get commonPrevious => '前へ';

  @override
  String get commonProcessing => '処理中…';

  @override
  String get commonReauthorize => '再認証';

  @override
  String get commonRefresh => '更新';

  @override
  String get commonReload => '再読み込み';

  @override
  String get commonReset => 'リセット';

  @override
  String get commonRestart => '再起動';

  @override
  String get commonRetry => '再試行';

  @override
  String get commonRun => '実行';

  @override
  String get commonRunning => '実行中';

  @override
  String get commonSave => '保存';

  @override
  String get commonSearch => '検索';

  @override
  String get commonSelect => '選択';

  @override
  String get commonSend => '送信';

  @override
  String get commonStop => '停止';

  @override
  String get commonSubmit => '送信';

  @override
  String get commonSwitch => '切り替え';

  @override
  String get commonTitle => 'タイトル';

  @override
  String get commonUndo => '元に戻す';

  @override
  String get commonUnknownError => '不明なエラー';

  @override
  String get commonViewAll => 'すべて表示';

  @override
  String get configAppliesToProfile => '適用先 Profile';

  @override
  String get configConnectionLabel => '接続';

  @override
  String get configCurrentProfile => '現在の Profile';

  @override
  String get configDefaultProcessProfile => '既定 / プロセス Profile';

  @override
  String configDeleteFailed(String error) {
    return '上書きを削除できませんでした：$error';
  }

  @override
  String get configFullJson => '完全な JSON';

  @override
  String configInvalidFieldValue(String path, String error) {
    return '$path の値が無効です：$error';
  }

  @override
  String configInvalidJson(String error) {
    return '無効な JSON：$error';
  }

  @override
  String get configListJsonError => '値は JSON array である必要があります';

  @override
  String get configLoading => '設定と schema を読み込んでいます…';

  @override
  String get configNoMatches => '一致するフィールドはありません';

  @override
  String get configObjectJsonError => '値は JSON object である必要があります';

  @override
  String get configRemoveOverride => '上書きを削除して既定値を使用';

  @override
  String get configRestore => '復元';

  @override
  String get configRestoreDefaults => '既定値に戻す';

  @override
  String configRestoreDefaultsDescription(String profile) {
    return '$profile に適用されます。既存のカスタム値は既定値に置き換えられます。';
  }

  @override
  String get configRestoreDefaultsQuestion => 'Hermes の既定設定に戻しますか？';

  @override
  String configSaveFailed(String error) {
    return '保存できませんでした：$error';
  }

  @override
  String get providerEndpointValidationFailed => 'エンドポイントの検証に失敗しました';

  @override
  String get kanbanMoveSelected => '選択したタスクを移動';

  @override
  String get kanbanClearSelection => 'タスクの選択を解除';

  @override
  String get configSearchHint => '設定フィールドを検索…';

  @override
  String configServerDidNotDelete(String path) {
    return 'サーバーが $path を削除しませんでした';
  }

  @override
  String get configServerMismatch => 'サーバーから返された内容が送信した完全な設定と一致しません';

  @override
  String configServerRejected(String path) {
    return 'サーバーが $path を受け入れなかったため、サーバーの値を復元しました。';
  }

  @override
  String get configTitle => 'モデルとチャット';

  @override
  String get configTopLevelObject => '最上位の JSON 値は object である必要があります';

  @override
  String get configUseDefault => '既定';

  @override
  String get connectAction => '接続';

  @override
  String get connectAddHeader => 'リクエストヘッダーを追加';

  @override
  String get connectAllowPublicHttp => '公開 HTTP 平文接続を許可';

  @override
  String get connectAllowPublicHttpWarning =>
      'HTTPS を利用できない信頼済みネットワークでのみ使用してください。Token が傍受される可能性があります';

  @override
  String get connectApiKey => 'API キー';

  @override
  String get connectConfiguration => '接続設定';

  @override
  String get connectConnecting => '接続中…';

  @override
  String get connectCredentialRequired => 'アクセス認証情報を入力してください';

  @override
  String get connectDeleteHeader => 'リクエストヘッダーを削除';

  @override
  String get connectDeleteProfile => '設定を削除';

  @override
  String get connectDiscoverCloud => 'Hermes Cloud から Agent を探す';

  @override
  String get connectExtraHeaders => '追加リクエストヘッダー';

  @override
  String get connectHeaderManaged => 'Hermes が管理しています';

  @override
  String get connectHeaderName => 'Header 名';

  @override
  String get connectHeaderNameInvalid => '名前が無効です';

  @override
  String get connectHeaderValue => '値';

  @override
  String get connectHeaderValueRequired => '値を入力してください';

  @override
  String get connectHeadersDescription =>
      'アクセスプロキシ用の任意ヘッダーです。値はシステムの安全なストレージに保存されます。';

  @override
  String get connectHideKey => 'キーを隠す';

  @override
  String get connectHidePassphrase => 'パスフレーズを隠す';

  @override
  String get connectHidePassword => 'パスワードを隠す';

  @override
  String get connectHidePrivateKey => '秘密鍵を隠す';

  @override
  String get connectHideValue => '値を隠す';

  @override
  String get connectHttpsRequired =>
      '公開接続には HTTPS が必要です。不安全な通信を明示的に許可することもできます';

  @override
  String get connectNativeCleartextRestricted =>
      'Release ビルドで平文 HTTP を使用できるのは localhost または .local の companion 名だけです。HTTPS または .local ホスト名を使用してください。';

  @override
  String get connectNotSignedIn => '未ログイン';

  @override
  String get connectOauthSignedIn => 'OAuth でログイン済み';

  @override
  String get connectPkceUnavailable =>
      'この Gateway は native_pkce ログインに対応していません。Hermes を更新するか Token を使用してください。';

  @override
  String get connectPort => 'ポート';

  @override
  String get connectPrivateKey => 'OpenSSH / PEM 秘密鍵';

  @override
  String get connectPrivateKeyPassphrase => '秘密鍵のパスフレーズ（任意）';

  @override
  String get connectProfileName => '設定名（既定はホスト名）';

  @override
  String get connectProfileNameInvalid => 'Profile 名が無効です';

  @override
  String get connectRemoteHermesPath => 'リモートの Hermes パス（自動検出）';

  @override
  String get connectRemoteProfile => 'リモート Profile（任意）';

  @override
  String get connectSaveProfile => 'サーバー設定として保存';

  @override
  String get connectSaveProfileDescription => '次回は保存済み一覧から切り替えられます';

  @override
  String get connectSavedBackends => '保存済みバックエンド';

  @override
  String get connectServerAddress => 'サーバーアドレス';

  @override
  String get connectServerInvalid => '有効な HTTP(S) アドレスを入力してください';

  @override
  String get connectServerRequired => 'サーバーアドレスを入力してください';

  @override
  String get connectShowKey => 'キーを表示';

  @override
  String get connectShowPassphrase => 'パスフレーズを表示';

  @override
  String get connectShowPassword => 'パスワードを表示';

  @override
  String get connectShowPrivateKey => '秘密鍵を表示';

  @override
  String get connectShowValue => '値を表示';

  @override
  String get connectSignIn => 'ログイン';

  @override
  String get connectSignInAgain => '再ログイン';

  @override
  String get connectSshCredentialRequired => '秘密鍵またはパスワードを入力してください';

  @override
  String get connectSshHost => 'SSH ホスト';

  @override
  String get connectSshHostRequired => 'SSH ホストを入力してください';

  @override
  String get connectSshPassword => 'SSH パスワード（任意）';

  @override
  String get connectSshUser => 'SSH ユーザー';

  @override
  String get connectSshUserRequired => 'SSH ユーザーを入力してください';

  @override
  String get connectTitle => '接続';

  @override
  String get connectUnableServer => 'サーバーに接続できません';

  @override
  String get connectValidationFailed =>
      '接続を検証できませんでした。サーバーアドレスと API キーを確認してください。';

  @override
  String get connectValidationNetworkFailed =>
      '接続を検証できませんでした。サーバーアドレス、API キー、ネットワークを確認してください。';

  @override
  String dateMonthDay(int month, int day) {
    return '$month月$day日';
  }

  @override
  String get dateToday => '今日';

  @override
  String get dateYesterday => '昨日';

  @override
  String get discordCommunityTitle => 'Discord コミュニティに参加';

  @override
  String get featureAbout => 'このアプリについて';

  @override
  String get featureAboutDesc => 'バージョン情報';

  @override
  String get featureAgent => 'Agent';

  @override
  String get featureAgentDesc => 'ランタイムとバックエンド状態';

  @override
  String get featureArtifacts => 'Artifacts';

  @override
  String get featureArtifactsDesc => 'セッションの成果物';

  @override
  String get featureBilling => '請求';

  @override
  String get featureBillingDesc => '使用量、プラン、請求書';

  @override
  String get featureCommandCenter => 'コマンドセンター';

  @override
  String get featureCommandCenterDesc => 'ライブ状態とログ';

  @override
  String get featureConnection => '接続';

  @override
  String get featureConnectionDesc => '複数バックエンドプロファイル';

  @override
  String get featureCredentials => '認証情報';

  @override
  String get featureCredentialsDesc => '外部アカウントとキー';

  @override
  String get featureCron => 'スケジュール';

  @override
  String get featureCronDesc => 'Cron 自動化';

  @override
  String get featureFiles => 'ファイル';

  @override
  String get featureFilesDesc => '作業ディレクトリを参照';

  @override
  String get featureGit => 'Git';

  @override
  String get featureGitDesc => '変更、コミット、ブランチ';

  @override
  String get featureGlobalSearchDesc => 'コマンド、セッション、ページを検索';

  @override
  String get featureInsights => '分析';

  @override
  String get featureInsightsDesc => '使用量とコストの推移';

  @override
  String get featureMcp => 'MCP';

  @override
  String get featureMcpDesc => 'MCP サーバー設定';

  @override
  String get featureMemory => 'メモリ';

  @override
  String get featureMemoryDesc => '長期メモリ管理';

  @override
  String get featureMessaging => 'メッセージング';

  @override
  String get featureMessagingDesc => 'Telegram、Discord など';

  @override
  String get featureNotificationsDesc => '通知センター';

  @override
  String get featurePet => 'ペット';

  @override
  String get featurePetDesc => 'コンパニオンとコレクション';

  @override
  String get featurePlugins => 'プラグイン';

  @override
  String get featurePluginsDesc => 'プラグイン管理';

  @override
  String get featureProfiles => 'プロファイル';

  @override
  String get featureProfilesDesc => 'モデル実行プロファイル';

  @override
  String get featureProjects => 'プロジェクト';

  @override
  String get featureProjectsDesc => 'プロジェクト別のセッション管理';

  @override
  String get featureSettings => '設定';

  @override
  String get featureSettingsDesc => '外観と環境設定';

  @override
  String get featureSkills => 'スキル';

  @override
  String get featureSkillsDesc => 'スキルハブ';

  @override
  String get featureStarmap => '知識スターマップ';

  @override
  String get featureStarmapDesc => 'キーワード知識グラフ';

  @override
  String get featureSubagents => 'サブエージェント';

  @override
  String get featureSubagentsDesc => 'バックグラウンド活動';

  @override
  String get featureTerminal => 'ターミナル';

  @override
  String get featureTerminalDesc => 'コマンドライン操作';

  @override
  String get featureTools => 'ツールセット';

  @override
  String get featureToolsDesc => 'ツールとキー';

  @override
  String get featureWebhooks => 'Webhooks';

  @override
  String get featureWebhooksDesc => 'イベント配信';

  @override
  String gitAgentShipFailed(Object error) {
    return 'Agent Ship に失敗しました: $error';
  }

  @override
  String get gitAgentShipPrompt =>
      '現在の変更を確認し、明確な Conventional Commit メッセージでコミットしてブランチをプッシュし、プルリクエストを開いてください。';

  @override
  String get gitAgentShipQuestion => 'Agent に変更のコミットとプッシュ、PR の作成を依頼しますか？';

  @override
  String get gitAgentShipSent => 'コミットと PR 作成のタスクを Hermes に送信しました';

  @override
  String get gitAuthor => '作成者';

  @override
  String gitAuthorMeta(Object author) {
    return '作成者: $author';
  }

  @override
  String get gitBaseBranch => 'ベースブランチ';

  @override
  String gitBranchMeta(Object branch) {
    return 'ブランチ: $branch';
  }

  @override
  String get gitBranchesTab => 'ブランチ';

  @override
  String get gitChangeDirectory => 'ディレクトリを変更';

  @override
  String get gitChangedFiles => '変更ファイル';

  @override
  String get gitChangedFilesLabel => '変更ファイル:';

  @override
  String get gitChangesTab => '変更';

  @override
  String get gitCommit => 'コミット';

  @override
  String get gitCommitChanges => '変更をコミット';

  @override
  String get gitCommitDetails => 'コミット詳細';

  @override
  String gitCommitFailed(Object error) {
    return 'コミットに失敗しました: $error';
  }

  @override
  String get gitCommitMessage => 'コミットメッセージ';

  @override
  String get gitCommitsTab => 'コミット';

  @override
  String get gitCreatePr => 'PR を作成';

  @override
  String gitCreatePrFailed(Object error) {
    return 'PR を作成できませんでした: $error';
  }

  @override
  String get gitCreatePrQuestion => 'GitHub CLI で現在のブランチのプルリクエストを作成または開きますか？';

  @override
  String gitCreateWorktreeFailed(Object error) {
    return 'worktree を作成できませんでした: $error';
  }

  @override
  String get gitCurrent => '現在';

  @override
  String gitDeleteWorktreeDescription(Object path) {
    return '作業ディレクトリ $path と未コミット変更を削除します。復元できません。';
  }

  @override
  String gitDeleteWorktreeFailed(Object error) {
    return 'worktree を削除できませんでした: $error';
  }

  @override
  String get gitDeleteWorktreeQuestion => 'worktree を削除しますか？';

  @override
  String get gitDetachedHead => '（detached HEAD）';

  @override
  String gitDiffLoadFailed(Object error) {
    return 'diff を読み込めませんでした: $error';
  }

  @override
  String get gitEndOfLog => '— ログの終端 —';

  @override
  String get gitForceDelete => '強制削除';

  @override
  String get gitForceDeleteWorktreeQuestion => '強制削除して変更を破棄しますか？';

  @override
  String get gitGenerateCommitMessage => 'コミットメッセージを生成';

  @override
  String gitGenerateMessageFailed(Object error) {
    return 'コミットメッセージを生成できませんでした: $error';
  }

  @override
  String get gitGithubCliUnavailable => 'バックエンドに GitHub CLI がないか、ログインしていません';

  @override
  String gitHoursAgo(Object count) {
    return '$count 時間前';
  }

  @override
  String get gitJustNow => 'たった今';

  @override
  String gitLoadMore(Object loaded, Object total) {
    return 'さらに読み込む ($loaded/$total)';
  }

  @override
  String get gitLoadingBranches => 'ブランチを読み込んでいます…';

  @override
  String get gitLoadingLog => 'コミットログを読み込んでいます…';

  @override
  String get gitLoadingStatus => 'リポジトリの状態を読み込んでいます…';

  @override
  String get gitLocalBranches => 'ローカルブランチ';

  @override
  String gitLogLoadFailed(Object error) {
    return 'コミットログを読み込めませんでした: $error';
  }

  @override
  String get gitMainWorktree => 'メイン';

  @override
  String gitMinutesAgo(Object count) {
    return '$count 分前';
  }

  @override
  String get gitNewWorktree => '新しい Worktree';

  @override
  String get gitNoAdditionalWorktrees => '追加の worktree はありません';

  @override
  String get gitNoBranches => '利用可能なブランチがありません';

  @override
  String get gitNoBranchesDescription => 'Git リポジトリを選択して再試行してください。';

  @override
  String get gitNoCommits => 'コミットなし';

  @override
  String get gitNoCommitsDescription => 'このリポジトリにはコミットがないか、現在のフィルターに一致しません';

  @override
  String get gitNoDiff => '差分なし';

  @override
  String get gitNoDiffDescription => 'このファイルは HEAD と同じです';

  @override
  String get gitNoMatchingBranches => '一致するブランチはありません';

  @override
  String get gitNoStashes => 'スタッシュはありません';

  @override
  String get gitNoVisibleRemotes => '表示できるリモートはありません';

  @override
  String get gitNotRepository => 'Git リポジトリではありません';

  @override
  String gitNotRepositoryDescription(Object path) {
    return '$path\n\n下のボタンでディレクトリを変更してください';
  }

  @override
  String get gitOpenInNewSession => '新しいセッションで開く';

  @override
  String gitOpenPr(Object number) {
    return 'PR #$number を開く';
  }

  @override
  String gitOpenedInNewSession(Object path) {
    return '$path を新しいセッションで開きました';
  }

  @override
  String get gitParent => '親';

  @override
  String get gitPrCreated => 'PR を作成しました';

  @override
  String gitPrNumber(Object number) {
    return '番号: #$number';
  }

  @override
  String get gitPushAfterCommit => 'コミット後にプッシュ';

  @override
  String gitPushAction(Object count) {
    return '$count 件のコミットをプッシュ';
  }

  @override
  String get gitPushSucceeded => 'リモートにプッシュしました';

  @override
  String gitPushFailed(Object error) {
    return 'プッシュに失敗しました: $error';
  }

  @override
  String get gitRecentRepositories => '最近のリポジトリ';

  @override
  String get gitRemotes => 'リモート';

  @override
  String get gitRemotesAndStashes => 'リモートとスタッシュ';

  @override
  String get gitRepositoryDirectory => 'リポジトリディレクトリ';

  @override
  String get gitRevert => '元に戻す';

  @override
  String get gitRevertAll => 'すべて元に戻す';

  @override
  String get gitRevertAllDescription => '作業ツリーの未コミット変更をすべて破棄します。この操作は取り消せません。';

  @override
  String get gitRevertAllQuestion => 'すべての変更を元に戻しますか？';

  @override
  String gitRevertFailed(Object error) {
    return '元に戻せませんでした: $error';
  }

  @override
  String get gitRevertFile => 'このファイルを元に戻す';

  @override
  String gitRevertFileDescription(Object file) {
    return '「$file」の未コミット変更を破棄します。この操作は取り消せません。';
  }

  @override
  String get gitRevertFileQuestion => 'このファイルを元に戻しますか？';

  @override
  String get gitSearchBranches => 'ブランチを検索…';

  @override
  String get gitSearchCommits => 'コミットメッセージを検索';

  @override
  String get gitSelectFileForDiff => 'ファイルを選択して diff を表示';

  @override
  String get gitSelectFileForDiffDescription => '左側の変更ファイルを選択すると、ここに差分が表示されます';

  @override
  String get gitServerRepositoryPath => 'サーバー上のリポジトリパス';

  @override
  String get gitStage => 'ステージ';

  @override
  String gitStageFailed(Object error) {
    return 'ステージ操作に失敗しました: $error';
  }

  @override
  String gitStagedChanges(Object added, Object removed) {
    return 'ステージ済み · +$added −$removed';
  }

  @override
  String get gitStashes => 'スタッシュ';

  @override
  String get gitSwitch => '切り替え';

  @override
  String get gitSwitchBranch => 'ブランチを切り替え';

  @override
  String gitSwitchBranchFailed(Object error) {
    return 'ブランチを切り替えられませんでした: $error';
  }

  @override
  String get gitUnknownAuthor => '不明';

  @override
  String get gitUnstage => 'ステージ解除';

  @override
  String get gitWorkingTreeClean => '作業ツリーはクリーンです';

  @override
  String get gitWorktreeHasChanges => 'worktree に未コミット変更があります';

  @override
  String get gitWorktreeNameHint => '例: feature-login';

  @override
  String get gitWorktrees => 'ワークツリー';

  @override
  String get globalSearch => 'グローバル検索';

  @override
  String get groupConfiguration => '設定';

  @override
  String get groupIntegrations => '連携';

  @override
  String get groupIntelligence => 'インテリジェンス';

  @override
  String get groupSystem => 'システム';

  @override
  String get groupWorkspace => 'ワークスペース';

  @override
  String get helpAndFeedbackTitle => 'ヘルプとフィードバック';

  @override
  String get homeAllFeatures => 'すべての機能';

  @override
  String get homeAttentionDetail => 'Agent が確認を待っている可能性があります';

  @override
  String homeBackendSummary(String model, String profile) {
    return 'バックエンド接続済み · $model · Profile: $profile';
  }

  @override
  String homeContinueSession(String title) {
    return '「$title」を続ける';
  }

  @override
  String get homeContinueWork => '作業を続ける';

  @override
  String get homeCurrentWork => '現在の作業';

  @override
  String get homeDefaultProfile => 'デフォルト';

  @override
  String get homeDragToReorder => 'ドラッグして並べ替え';

  @override
  String get homeEditQuickTools => 'クイックツールを編集';

  @override
  String get homeLastVisibleTool => 'ホームに表示される最後の項目';

  @override
  String get homeLoadingRecent => '最近の作業を読み込み中…';

  @override
  String get homeMoreTools => 'その他のツール';

  @override
  String homeNeedsAttention(int count) {
    return '$count 件の確認が必要です';
  }

  @override
  String get homeNoWorkDescription => '上で目標を入力して最初の作業を開始します';

  @override
  String get homeNoWorkTitle => '作業履歴はまだありません';

  @override
  String homeProfileTooltip(String profile) {
    return 'プロファイル: $profile';
  }

  @override
  String get homeQuickTools => 'クイックツール';

  @override
  String get homeQuickToolsDescription => '最初の 5 項目はホームに表示され、残りは「その他」に収納されます。';

  @override
  String get homeReadyTitle => 'Hermes の準備ができました';

  @override
  String get homeRecentSessions => '最近のセッション';

  @override
  String get homeRestoreDefaults => '初期設定に戻す';

  @override
  String get homeStartNewSession => '新しいセッション';

  @override
  String get homeSwitchProfile => 'プロファイルを切り替え';

  @override
  String get homeToolKnowledge => 'ナレッジ';

  @override
  String get homeViewAttentionSessions => '保留中のセッションを表示';

  @override
  String get homeViewSession => 'セッションを表示';

  @override
  String homeWorkingDetail(String model) {
    return '現在のタスクを処理中 · $model';
  }

  @override
  String get homeWorkingTitle => 'Hermes は作業中です';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageDescription => 'Hermes Mobile の表示言語を選択';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageSimplifiedChinese => '简体中文';

  @override
  String get languageSystem => 'システム設定';

  @override
  String get languageTitle => '言語';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get legalPrivacy => 'プライバシーポリシー';

  @override
  String get legalTerms => '利用規約';

  @override
  String get legalTitle => '法的情報とライセンス';

  @override
  String get modelAllFollowMain => 'すべてメインモデルに従う';

  @override
  String get modelApply => '適用';

  @override
  String modelAuxiliarySaveFailed(String error) {
    return '補助モデルを保存できませんでした：$error';
  }

  @override
  String get modelAuxiliaryTitle => '補助モデル';

  @override
  String get modelAuxiliaryUnavailable => 'この Hermes バックエンドは補助モデル設定を提供していません。';

  @override
  String get modelChoose => 'モデルを選択';

  @override
  String get modelConfirmSelection => 'モデル選択の確認';

  @override
  String get modelCreate => '作成';

  @override
  String get modelCurrent => '使用中';

  @override
  String get modelDefaultTitle => 'デフォルトモデル';

  @override
  String get modelExpensiveWarning => 'このモデルは高額になる可能性があります。続行しますか？';

  @override
  String get modelFallbackHint =>
      'fallback_providers（1 行に 1 つの provider:model）';

  @override
  String get modelFallbackTitle => 'フォールバックモデル';

  @override
  String get modelFollowMain => 'メインモデルに従う';

  @override
  String get modelLabel => 'モデル';

  @override
  String get modelMoaAddReference => '参照モデルを追加';

  @override
  String get modelMoaAggregator => 'アグリゲーター';

  @override
  String get modelMoaAggregatorMaxTokens => 'アグリゲーター出力上限';

  @override
  String get modelMoaAggregatorModel => 'アグリゲーターモデル';

  @override
  String modelMoaAggregatorSummary(String provider, String model) {
    return 'アグリゲーター：$provider · $model';
  }

  @override
  String get modelMoaAggregatorTemperature => 'アグリゲーター temperature';

  @override
  String get modelMoaCompleteModels => 'すべてのモデルを選択してください';

  @override
  String get modelMoaCreatePreset => 'MoA preset を作成';

  @override
  String get modelMoaCreateTooltip => 'preset を作成';

  @override
  String get modelMoaDefaultPreset => 'デフォルト preset';

  @override
  String get modelMoaDegradedLoud => '縮退を通知';

  @override
  String get modelMoaDegradedPolicy => '縮退ポリシー';

  @override
  String get modelMoaDegradedSilent => 'サイレント縮退';

  @override
  String get modelMoaDeleteTooltip => 'preset を削除';

  @override
  String get modelMoaDescription => '参照モデルが並列で回答し、アグリゲーターが最終結果を生成します';

  @override
  String get modelMoaEditConfiguration => '設定を編集';

  @override
  String modelMoaEditTitle(String name) {
    return '$name を編集';
  }

  @override
  String get modelMoaEnablePreset => 'preset を有効化';

  @override
  String get modelMoaFanoutCadence => 'Fanout cadence';

  @override
  String get modelMoaFanoutHint => 'user_turn / per_iteration / every_n:2';

  @override
  String get modelMoaNoEditable => '編集可能な MoA preset はありません。';

  @override
  String get modelMoaPresetLabel => 'Preset';

  @override
  String modelMoaReferenceCount(int count) {
    return '参照モデル $count 個';
  }

  @override
  String get modelMoaReferenceMaxTokens => '参照出力上限';

  @override
  String get modelMoaReferenceModels => '参照モデル';

  @override
  String modelMoaReferenceNumber(int index) {
    return '参照 $index';
  }

  @override
  String get modelMoaReferenceTemperature => '参照 temperature';

  @override
  String get modelMoaReferenceTimeout => '参照タイムアウト（秒）';

  @override
  String get modelMoaRuntimeParameters => '実行パラメーター';

  @override
  String get modelMoaSaveConfiguration => '設定を保存';

  @override
  String modelMoaSaveFailed(String error) {
    return 'MoA 設定を保存できませんでした：$error';
  }

  @override
  String get modelMoaSetDefault => 'デフォルトに設定';

  @override
  String get modelMoaUnavailable => 'この Hermes バックエンドは MoA 設定を提供していません。';

  @override
  String get modelNoAvailable => '利用可能なモデルはありません';

  @override
  String get modelPresetName => '名前';

  @override
  String get modelProvider => 'プロバイダー';

  @override
  String get modelProviderNotFound => 'このモデルのプロバイダーが見つかりません';

  @override
  String modelRecommended(String model) {
    return '推奨：$model';
  }

  @override
  String get modelRemove => '削除';

  @override
  String get modelSwitchDeferred => 'モデルの切り替えを予約しました。現在のターン完了後に適用されます';

  @override
  String modelSwitchFailed(String error) {
    return 'モデルを切り替えられませんでした：$error';
  }

  @override
  String modelSwitchSucceeded(String model) {
    return '$model に切り替えました';
  }

  @override
  String get moreCloseSearch => '検索を閉じる';

  @override
  String get moreNoMatches => '一致する機能はありません';

  @override
  String get moreSearchDirectory => '機能を検索';

  @override
  String get moreSearchHint => '機能を検索';

  @override
  String moreStatus(String connection, String agent) {
    return '$connection · Agent $agent';
  }

  @override
  String get navHome => 'ホーム';

  @override
  String get navMore => 'その他';

  @override
  String get navSessions => 'セッション';

  @override
  String get navTasks => 'タスク';

  @override
  String get notificationClear => '消去';

  @override
  String get notificationClearConfirmTitle => 'すべての通知を消去しますか？';

  @override
  String get notificationClearConfirmBody => 'リスト内のすべての通知が削除されます。この操作は元に戻せません。';

  @override
  String get notificationEmptyDescription => 'Agent の完了、承認、エラーがここに表示されます';

  @override
  String get notificationEmptyTitle => '通知はありません';

  @override
  String get notificationMarkAllRead => 'すべて既読';

  @override
  String notificationOpenFailed(String error) {
    return 'セッションを開けませんでした: $error';
  }

  @override
  String get notificationOpenSession => 'セッションを表示';

  @override
  String get notificationTitle => '通知';

  @override
  String get paletteHint => 'ページ、セッション、コマンドを検索…';

  @override
  String get paletteHintClose => '閉じる';

  @override
  String get paletteHintNavigate => '選択';

  @override
  String get paletteHintOpen => '開く';

  @override
  String get paletteKanban => 'カンバン';

  @override
  String get paletteKindAction => '操作';

  @override
  String get paletteKindCommand => 'コマンド';

  @override
  String get paletteKindPage => 'ページ';

  @override
  String get paletteKindSession => 'セッション';

  @override
  String get paletteNewSessionDesc => '新しい会話を開始';

  @override
  String get paletteNoResults => '一致する結果はありません';

  @override
  String get paletteReconnect => '再接続';

  @override
  String get paletteReconnectDesc => 'サーバーに再接続';

  @override
  String get paletteVoiceInput => '音声入力';

  @override
  String get paletteVoiceInputDesc => '音声入力を開始';

  @override
  String pluginActionFailed(String title, String error) {
    return '$title に失敗しました：$error';
  }

  @override
  String get pluginFieldInvalidNumber => '有効な数値を入力してください';

  @override
  String pluginFieldMaximum(num value) {
    return '最大値：$value';
  }

  @override
  String pluginFieldMinimum(num value) {
    return '最小値：$value';
  }

  @override
  String get pluginFieldRequired => 'この項目は必須です';

  @override
  String pluginItemFallback(int index) {
    return '項目 $index';
  }

  @override
  String get pluginNoItems => '項目はありません';

  @override
  String get pluginResultCopied => '結果をコピーしました';

  @override
  String get pluginResultCopy => '結果をコピー';

  @override
  String get pluginResultOpenLink => 'リンクを開く';

  @override
  String get pluginSubmit => '送信';

  @override
  String previewActionSendFailed(String error) {
    return 'プレビュー操作を送信できませんでした：$error';
  }

  @override
  String previewActionSent(String prompt) {
    return 'プレビュー操作を送信しました：$prompt';
  }

  @override
  String get previewBack => '戻る';

  @override
  String get previewClearConsole => 'コンソールを消去';

  @override
  String get previewCloseConsole => 'コンソールを閉じる';

  @override
  String get previewConsoleTitle => 'Console';

  @override
  String get previewEmpty => 'チャットでリンクを開くか、HTML ファイルを選択してください';

  @override
  String previewFailed(String error) {
    return 'プレビューに失敗しました：$error';
  }

  @override
  String get previewForward => '進む';

  @override
  String get previewNoLogs => 'ログはありません';

  @override
  String get previewOpenBrowser => 'ブラウザーで開く';

  @override
  String get previewOpenConsole => 'コンソールを開く';

  @override
  String previewOpenSessionFailed(String error) {
    return 'セッションを開けませんでした：$error';
  }

  @override
  String get previewRefresh => 'プレビューを更新';

  @override
  String get previewRunJavascript => 'JavaScript を実行';

  @override
  String get previewRunScript => 'スクリプトを実行';

  @override
  String get previewTitle => 'プレビュー';

  @override
  String get previewUnsupportedWebView =>
      'このプラットフォームでは埋め込み WebView を利用できません。ブラウザーで開いてください。';

  @override
  String get projectBrowseFiles => 'プロジェクトディレクトリを参照';

  @override
  String get projectDetailTitle => 'プロジェクト詳細';

  @override
  String projectFolderCount(int count) {
    return '$count フォルダー';
  }

  @override
  String get projectGitDescription => 'リポジトリの状態と変更を表示';

  @override
  String get projectGlobalMemoryDescription => 'Profile メモリ（グローバル表示）';

  @override
  String get projectGlobalStarmapDescription => 'ナレッジグラフ（グローバル表示）';

  @override
  String get projectGlobalSubagentsDescription => '全セッションのサブエージェント活動';

  @override
  String get projectGlobalWebhooksDescription => 'Webhook 設定（グローバル表示）';

  @override
  String get projectLoadingSessions => 'セッションを読み込み中…';

  @override
  String get projectModulesTitle => 'モジュール';

  @override
  String get projectNoKanbanBoard => 'このプロジェクトに紐づくボードはありません';

  @override
  String get projectNoSessions => '関連するセッションはありません';

  @override
  String get projectNoSessionsDescription => 'このプロジェクト内で開始したセッションがここに表示されます';

  @override
  String projectResumeFailed(String error) {
    return 'セッションを再開できませんでした: $error';
  }

  @override
  String projectSessionCount(int count) {
    return '$count セッション';
  }

  @override
  String get projectSessionsTitle => 'セッション';

  @override
  String get projectTasksDescription => 'このプロジェクトに紐づくボードを開く';

  @override
  String get projectTasksTitle => 'タスクとボード';

  @override
  String get projectUnavailable => '利用不可';

  @override
  String get projectUntitled => '名称未設定のプロジェクト';

  @override
  String get providerActiveDefault => 'アクティブ / 既定';

  @override
  String get providerAddEndpointTitle => '新しいカスタムエンドポイント';

  @override
  String get providerCustomEndpointJson => 'カスタム endpoint JSON';

  @override
  String get providerCustomEndpointsSection => 'カスタム Endpoints';

  @override
  String get providerDeviceAuthorization => 'デバイス認証';

  @override
  String get providerEditEndpointTitle => 'カスタムエンドポイントを編集';

  @override
  String get providerEndpointApiKey => 'API キー';

  @override
  String get providerEndpointBaseUrl => 'Base URL';

  @override
  String get providerEndpointDefaultModel => 'デフォルトモデル';

  @override
  String get providerEndpointDiscoverModels => 'モデルを自動検出';

  @override
  String get providerEndpointFallback => 'Endpoint';

  @override
  String get providerEndpointModelsList => '利用可能なモデル（1 行に 1 つ）';

  @override
  String get providerEndpointName => '名前';

  @override
  String get providerEndpointNameRequired => '名前を入力してください';

  @override
  String get providerEndpointUrlRequired => 'Base URL を入力してください';

  @override
  String providerEnterDeviceCode(String code) {
    return 'ブラウザーで確認コードを入力してください：$code';
  }

  @override
  String providerActionFailed(String error) {
    return '操作に失敗しました: $error';
  }

  @override
  String get providerEnvironmentSection => '環境変数';

  @override
  String get providerEnvironmentVariableName => '環境変数名';

  @override
  String get providerEnvironmentVariableValue => '環境変数の値';

  @override
  String providerMissingKeys(String keys) {
    return '不足：$keys';
  }

  @override
  String providerModelTitle(String provider) {
    return '$provider モデル';
  }

  @override
  String get providerNoConfiguration => '設定はありません';

  @override
  String get providerNotSet => '未設定';

  @override
  String get providerOauthSection => 'Provider OAuth';

  @override
  String get providerPasteOauthCode => 'OAuth code を貼り付け';

  @override
  String get providerProfileLabel => 'Profile';

  @override
  String providerRevealFailed(String error) {
    return '値の取得に失敗しました：$error';
  }

  @override
  String get providerRevealValue => '表示';

  @override
  String get providerRevealedValueTitle => '保存済みの値';

  @override
  String providerRunSetupDescription(String provider, String command) {
    return '$provider は次の実行が必要です：$command';
  }

  @override
  String get providerRunSetupQuestion => 'Provider のセットアップを実行しますか？';

  @override
  String get providerSetActive => '現在の設定にする';

  @override
  String providerSetEnvironmentVariable(String key) {
    return '$key を設定';
  }

  @override
  String providerToolsCount(int count) {
    return '$count 個のツール';
  }

  @override
  String providerToolsetProviderTitle(String toolset) {
    return '$toolset Provider';
  }

  @override
  String get providerToolsetProvidersSection => 'Toolset Providers';

  @override
  String get pushEnabled => 'リモート通知';

  @override
  String get pushEnabledDescription => 'この端末を現在の Hermes サーバーに登録します';

  @override
  String get pushOsPermissionDenied => 'システム通知がブロックされています';

  @override
  String get pushOsPermissionDeniedDescription =>
      'Hermes ではリモート通知が有効になっていますが、OS がブロックしているため実際には配信されません。デバイスのシステム設定で Hermes Mobile の通知を有効にしてください。';

  @override
  String get pushNoProviders => 'サーバーに APNs または FCM の認証情報が設定されていません';

  @override
  String get pushNotRegistered => '未登録';

  @override
  String get pushProviders => '配信プロバイダー';

  @override
  String get pushRefresh => 'プッシュ状態を更新';

  @override
  String get pushRegistered => '現在の接続とプロファイルで登録済み';

  @override
  String get pushRegistration => '端末登録';

  @override
  String get pushSendTest => 'テスト通知を送信';

  @override
  String get pushSettingsDescription => 'Hermes Mobile を閉じていても完了通知と承認要求を受信します。';

  @override
  String get pushSettingsTitle => 'リモート通知';

  @override
  String get pushTestDelivered => 'テスト通知を配信しました';

  @override
  String pushTestFailed(String error) {
    return 'テスト通知を送信できませんでした: $error';
  }

  @override
  String get pushTestNotDelivered => 'テスト通知を配信できるプロバイダーがありません';

  @override
  String get reportIssueTitle => 'GitHub で問題を報告';

  @override
  String get sendDiagnosticsSubtitle => '問題解決のため匿名化したログをアップロード';

  @override
  String get sendDiagnosticsTitle => '診断情報を送信';

  @override
  String get sessionActions => 'セッション操作';

  @override
  String get sessionAllTags => 'すべてのタグ';

  @override
  String get sessionArchiveView => 'アーカイブ表示';

  @override
  String get sessionArchiveViewDescription => 'アーカイブ済みセッションのみ表示';

  @override
  String sessionBatchDeleteDescription(int count) {
    return '選択した $count 件のセッションは完全に削除され、元に戻せません。';
  }

  @override
  String get sessionBatchDeleteTitle => 'セッションを削除しますか？';

  @override
  String get sessionCancelSelection => '選択を解除';

  @override
  String get sessionClearAll => 'すべてクリア';

  @override
  String get sessionClearFilters => '条件をクリア';

  @override
  String get sessionClearSearch => '検索をクリア';

  @override
  String get sessionCollapseChildren => '子セッションを閉じる';

  @override
  String get sessionConfirmDelete => '完全に削除';

  @override
  String get sessionContinueLast => '前回のセッションを続ける';

  @override
  String get sessionDeepSearchHint => 'セッション名とメッセージ履歴を検索';

  @override
  String get sessionDeepSearchTitle => 'チャット履歴を検索';

  @override
  String sessionDeleteDescription(String title) {
    return '「$title」は完全に削除されます。';
  }

  @override
  String sessionDeleteFailed(String error) {
    return '削除に失敗しました：$error';
  }

  @override
  String get sessionDeleteSelected => '選択項目を削除';

  @override
  String get sessionDeleteTitle => 'セッションを削除しますか？';

  @override
  String sessionDeletedCount(int count) {
    return '$count 件のセッションを削除しました';
  }

  @override
  String sessionDurationDaysHours(int days, int hours) {
    return '$days日$hours時間';
  }

  @override
  String sessionDurationHoursMinutes(int hours, int minutes) {
    return '$hours時間$minutes分';
  }

  @override
  String sessionDurationMinutes(int minutes) {
    return '$minutes分';
  }

  @override
  String get sessionEmptyDescription => '新しいセッションで Hermes と会話を始めます';

  @override
  String get sessionEmptyTitle => 'セッションはまだありません';

  @override
  String get sessionExpandChildren => '子セッションを展開';

  @override
  String get sessionFilterAll => 'すべて';

  @override
  String get sessionFilterApproval => '承認が必要';

  @override
  String get sessionFilterByTag => 'タグで絞り込む';

  @override
  String get sessionFilterCompleted => '完了';

  @override
  String get sessionFilterTitle => 'セッションを絞り込む';

  @override
  String get sessionGroupArchived => 'アーカイブ済み';

  @override
  String get sessionGroupByProject => 'プロジェクトでグループ化';

  @override
  String get sessionGroupByTime => '時間でグループ化';

  @override
  String get sessionGroupLast7Days => '過去 7 日';

  @override
  String get sessionGroupOlder => '以前';

  @override
  String get sessionGroupPinned => '固定';

  @override
  String get sessionGroupRunning => '実行中';

  @override
  String sessionHandoff(String state) {
    return '引き継ぎ $state';
  }

  @override
  String get sessionHistoryArchive => '履歴アーカイブ';

  @override
  String get sessionLoadMore => 'さらに読み込む';

  @override
  String get sessionManage => 'セッション管理';

  @override
  String sessionMessageCount(int count) {
    return '$count メッセージ';
  }

  @override
  String get sessionNew => '新しいセッション';

  @override
  String get sessionNoMatchesDescription => '検索またはステータス条件を調整してください';

  @override
  String get sessionNoMatchesTitle => '一致するセッションはありません';

  @override
  String get sessionNoProjectsDescription =>
      'Git リポジトリで開始したセッションは自動的にプロジェクトへ分類されます';

  @override
  String get sessionNoProjectsTitle => 'プロジェクトはありません';

  @override
  String sessionOpenCopyFailed(String error) {
    return 'コピーを開けませんでした：$error';
  }

  @override
  String get sessionPrClosed => 'クローズ済み';

  @override
  String get sessionPrDraft => '下書き';

  @override
  String get sessionPrMerged => 'マージ済み';

  @override
  String get sessionPrNone => 'PR なし';

  @override
  String get sessionPrOpen => 'オープン';

  @override
  String get sessionProjectBack => 'プロジェクト一覧へ戻る';

  @override
  String get sessionProjectEnter => '開く';

  @override
  String get sessionProjectNoSessions => 'このプロジェクトにセッションはありません';

  @override
  String sessionProjectSessionCount(int count) {
    return '$count セッション';
  }

  @override
  String get sessionProjectUnavailable => 'プロジェクトを利用できません';

  @override
  String get sessionPullRequests => 'プルリクエスト';

  @override
  String sessionResumeFailed(String error) {
    return 'セッションを復元できませんでした：$error';
  }

  @override
  String sessionResumeLastFailed(String error) {
    return '前回のセッションを復元できませんでした：$error';
  }

  @override
  String sessionResumeSubagentFailed(String error) {
    return 'サブエージェントのセッションを復元できませんでした：$error';
  }

  @override
  String sessionSearchFailed(String error) {
    return '検索に失敗しました：$error';
  }

  @override
  String get sessionSearchMessages => 'メッセージ内容を検索';

  @override
  String get sessionSearchNoFilteredResults => '現在の条件に一致する結果はありません';

  @override
  String get sessionSearchPrompt => 'キーワードを入力してすべての履歴を検索';

  @override
  String sessionSearchResultCount(int total, int visible) {
    return '$total 件中 $visible 件を表示';
  }

  @override
  String get sessionSearchTitleHint => 'セッション名を検索…';

  @override
  String get sessionSelectAll => 'すべて選択';

  @override
  String get sessionSelectDescription => '一覧からセッションを開いて作業を続けます';

  @override
  String get sessionSelectMultiple => '複数選択';

  @override
  String get sessionSelectSessions => 'セッションを選択';

  @override
  String get sessionSelectTitle => 'セッションを選択';

  @override
  String sessionSelectedCount(int count) {
    return '$count 件選択中';
  }

  @override
  String get sessionServerNotConnected => 'サーバーに接続されていません';

  @override
  String get sessionSortActivity => '最近のアクティビティ';

  @override
  String get sessionSortCreated => '作成日時';

  @override
  String get sessionSortTitle => '並び替え';

  @override
  String get sessionSortTokens => 'トークン使用量';

  @override
  String get sessionStatusAttention => '要対応';

  @override
  String get sessionStatusIdle => '待機中';

  @override
  String get sessionStatusWorking => '実行中';

  @override
  String get sessionTimeAll => '全期間';

  @override
  String get sessionTitle => 'セッション';

  @override
  String sessionToolCount(int count) {
    return '$count ツール';
  }

  @override
  String get sessionUntitled => '無題のセッション';

  @override
  String sessionWithinDays(int count) {
    return '$count 日以内';
  }

  @override
  String get settingsAppearanceDesc => '表示モード、テーマカラー、ハイコントラスト';

  @override
  String get settingsBackHome => 'ホームに戻る';

  @override
  String get settingsBackendConfigSummary => 'バックエンド設定の概要';

  @override
  String get settingsBackendConfigSummaryDesc => '主要な設定値';

  @override
  String get settingsBackendConnectionSection => 'バックエンドと接続';

  @override
  String settingsBackendRestartFailed(String error) {
    return 'バックエンドを再起動できませんでした：$error';
  }

  @override
  String get settingsBackendRestarted => 'バックエンドを再起動しました';

  @override
  String get settingsCapabilitiesDesc => 'MCP、ナレッジ、スキル、プラグイン';

  @override
  String get settingsCapabilitiesTitle => '機能管理';

  @override
  String get settingsChangeConnection => '接続を変更';

  @override
  String get settingsChangeConnectionDesc => 'サーバーアドレスと API Key を編集します';

  @override
  String get settingsChangeConnectionQuestion => '接続を変更しますか？';

  @override
  String get settingsChangeConnectionWarning =>
      '現在のサーバー接続を消去し、新しいサーバーアドレスと API Key を入力できるようにします。';

  @override
  String get settingsGroupModels => 'モデルと機能';

  @override
  String get settingsGroupPersonalization => 'パーソナライズ';

  @override
  String get settingsModelDesc => 'モデル、会話、メモリコンテキスト、キー';

  @override
  String get settingsModelTitle => 'モデルと会話';

  @override
  String get settingsProvidersDesc => '環境変数、カスタムエンドポイント、OAuth、ツールセットプロバイダー';

  @override
  String get settingsProvidersTitle => 'プロバイダーと実行環境';

  @override
  String get settingsRestartBackend => 'Hermes バックエンドを再起動';

  @override
  String get settingsRestartBackendDesc => '現在の処理を中断してサーバープロセスを再起動します';

  @override
  String get settingsRestartBackendQuestion => 'Hermes バックエンドを再起動しますか？';

  @override
  String get settingsRestartBackendWarning => 'サーバーで実行中のセッションは中断されます。';

  @override
  String get settingsSystemConnectionDesc => '接続、セキュリティ、ターミナル、バックエンド';

  @override
  String get settingsSystemConnectionTitle => 'システムと接続';

  @override
  String get settingsTerminalSection => 'ターミナル';

  @override
  String get taskAll => 'すべて';

  @override
  String taskAssigneeFilter(String value) {
    return '担当者: $value';
  }

  @override
  String get taskAutoDecompose => 'タスクを自動分解';

  @override
  String get taskAutoGenerate => '自動生成';

  @override
  String get taskBoardView => 'ボード';

  @override
  String taskBulkFailed(int count) {
    return '$count 件のタスクを更新できませんでした';
  }

  @override
  String get taskClearFilters => 'フィルターをクリア';

  @override
  String get taskCloseSearch => '検索を閉じる';

  @override
  String taskCommentCount(int count) {
    return 'コメント $count 件';
  }

  @override
  String get taskConnectBackend => 'バックエンドに接続してタスクを表示';

  @override
  String get taskDefault => 'デフォルト';

  @override
  String get taskDefaultAssignee => 'デフォルトの担当者';

  @override
  String get taskFilter => 'フィルター';

  @override
  String get taskListView => 'リスト';

  @override
  String get taskNew => '新規タスク';

  @override
  String get taskNoDescription => '説明なし';

  @override
  String get taskOptions => 'タスクのオプション';

  @override
  String get taskOrchestration => 'オーケストレーション';

  @override
  String get taskOrchestratorProfile => 'オーケストレーター Profile';

  @override
  String get taskPriorityHigh => '高';

  @override
  String taskPriorityMeta(String priority) {
    return '優先度: $priority';
  }

  @override
  String get taskPriorityNormal => '通常';

  @override
  String get taskPriorityUrgent => '緊急';

  @override
  String taskProfileDescription(String name) {
    return '$name の説明';
  }

  @override
  String get taskProfileDescriptions => 'Profile の説明';

  @override
  String get taskSearch => 'タスクを検索';

  @override
  String taskSelectedCount(int count) {
    return '$count 件選択中';
  }

  @override
  String get taskShowArchived => 'アーカイブ済みを表示';

  @override
  String get taskStatusArchived => 'アーカイブ済み';

  @override
  String get taskStatusBlocked => 'ブロック中';

  @override
  String get taskStatusDone => '完了';

  @override
  String get taskStatusReady => '準備完了';

  @override
  String get taskStatusReview => 'レビュー';

  @override
  String get taskStatusRunning => '実行中';

  @override
  String get taskStatusScheduled => '予定';

  @override
  String get taskStatusTodo => '未着手';

  @override
  String get taskStatusTriage => 'トリアージ';

  @override
  String get taskSwitchBoard => 'ボードを切り替え';

  @override
  String taskTenantFilter(String value) {
    return 'テナント: $value';
  }

  @override
  String get taskTitle => 'タスク';

  @override
  String get taskUnassigned => '未割り当て';

  @override
  String get taskWeeklyDelivery => '今週の完了状況';

  @override
  String get terminalDefaultMonospace => '既定の等幅フォント';

  @override
  String get terminalFontHint => '空欄にすると既定の等幅フォントを使用します';

  @override
  String get terminalFontPreview => 'プレビュー  ~/project  git:main  >';

  @override
  String terminalFontSaveFailed(String error) {
    return 'ターミナルフォントを保存できませんでした：$error';
  }

  @override
  String get terminalFontSaved => 'ターミナルフォントを保存しました';

  @override
  String get terminalFontTitle => 'ターミナルフォント';

  @override
  String timeDaysAgo(int count) {
    return '$count 日前';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count 時間前';
  }

  @override
  String get timeJustNow => 'たった今';

  @override
  String timeMinutesAgo(int count) {
    return '$count 分前';
  }

  @override
  String get updateAppVersion => 'アプリのバージョン';

  @override
  String updateAvailableTitle(String version) {
    return 'バージョン $version に更新できます';
  }

  @override
  String get updateCheck => 'アップデートを確認';

  @override
  String get updateCheckDescription => 'モバイルリリースマニフェストから新しいバージョンを確認';

  @override
  String get updateCheckFailed => 'アップデートの確認に失敗しました';

  @override
  String updateCheckUnavailable(String error) {
    return '一時的に確認できません：$error';
  }

  @override
  String get updateCurrent => '最新バージョンです';

  @override
  String updateFound(String version) {
    return 'バージョン $version が見つかりました';
  }

  @override
  String get updateGoToUpdate => '更新する';

  @override
  String updateMinimumVersion(String minimumVersion) {
    return '最低対応バージョン：$minimumVersion';
  }

  @override
  String get updateNewVersionPublished => '新しいバージョンが公開されました';

  @override
  String get updateReleaseNotes => 'リリースノート';

  @override
  String updateRequiredDefault(String currentVersion, String minimumVersion) {
    return '現在のバージョン $currentVersion は最低互換バージョン $minimumVersion 未満です。更新して続行してください。';
  }

  @override
  String get updateRequiredTitle => 'Hermes Mobile の更新が必要です';

  @override
  String get updateSectionTitle => 'アップデート';

  @override
  String get updateUnsupportedTitle => 'このバージョンはサポートされていません';

  @override
  String updateVersionBuild(String version, String build) {
    return 'v$version · build $build';
  }

  @override
  String get workspaceAddPaneTooltip => 'ペインを開く';

  @override
  String get workspaceApplyLayoutTooltip => 'レイアウトを適用';

  @override
  String get workspaceCloseAllAction => 'すべて閉じる';

  @override
  String get workspaceCloseAllDescription =>
      'モバイルのワークスペースのみを閉じます。セッションやプラグインのデータは削除されません。';

  @override
  String get workspaceCloseAllQuestion => 'すべてのペインを閉じますか？';

  @override
  String get workspaceCloseAllTooltip => 'すべてのペインを閉じる';

  @override
  String get workspaceEmptyDescription => 'セッションメニューまたはプラグインペインからコンテンツを開いてください';

  @override
  String get workspaceEmptyTitle => 'ワークスペースは空です';

  @override
  String get workspaceLayoutDefault => 'デフォルト';

  @override
  String get workspaceLayoutFocus => 'フォーカス';

  @override
  String get workspaceLayoutQuad => '4 分割';

  @override
  String get workspaceLayoutTerminalDeck => 'ターミナルデッキ';

  @override
  String get workspaceLayoutTooltip => 'ペインのレイアウトを調整';

  @override
  String get workspaceMergeTabs => 'タブとして統合';

  @override
  String get workspaceMoveBottom => '下へ移動';

  @override
  String get workspaceMoveLeft => '左へ移動';

  @override
  String get workspaceMoveRight => '右へ移動';

  @override
  String get workspaceMoveTop => '上へ移動';

  @override
  String workspaceOpenPluginFailed(String error) {
    return 'プラグインペインを開けませんでした：$error';
  }

  @override
  String workspaceOpenSessionFailed(String error) {
    return 'ワークスペースを開けませんでした：$error';
  }

  @override
  String get workspacePaneFiles => 'ファイル';

  @override
  String get workspacePaneLogs => 'ログ';

  @override
  String get workspacePanePreview => 'プレビュー';

  @override
  String get workspacePaneReview => 'レビュー';

  @override
  String get workspacePaneTerminal => 'ターミナル';

  @override
  String get workspacePluginUnavailable =>
      'このプラグインペインは利用できません。プラグインが有効か確認してください。';

  @override
  String workspaceSessionResumeFailed(String error) {
    return 'セッションを復元できませんでした：$error';
  }

  @override
  String get workspaceTitle => 'ワークスペース';

  @override
  String statusSemantics(String label) {
    return '状態: $label';
  }

  @override
  String statusAgentSemantics(String label) {
    return 'エージェントの状態: $label';
  }

  @override
  String statusToolSemantics(String label) {
    return 'ツールの状態: $label';
  }

  @override
  String get statusIdle => '待機中';

  @override
  String get statusThinking => '思考中';

  @override
  String get statusPlanning => '計画中';

  @override
  String get statusRunning => '実行中';

  @override
  String get statusWaiting => '待機中';

  @override
  String get statusAwaitingApproval => '承認待ち';

  @override
  String get statusPaused => '一時停止';

  @override
  String get statusCompleted => '完了';

  @override
  String get statusFailed => '失敗';

  @override
  String get statusStopped => '停止済み';

  @override
  String get statusCancelled => 'キャンセル済み';

  @override
  String get composerUndoInput => '入力を元に戻す';

  @override
  String get composerRedoInput => '入力をやり直す';

  @override
  String get composerReadOnly => 'サブエージェントのセッションは読み取り専用です';

  @override
  String get composerMessageHint => 'Hermes にメッセージを送信…';

  @override
  String composerProfileValue(String value) {
    return 'プロファイル: $value';
  }

  @override
  String get composerSelectProfile => 'プロファイルを選択';

  @override
  String composerWorkspaceValue(String value) {
    return 'ワークスペース: $value';
  }

  @override
  String get composerSelectWorkspace => 'ワークスペースを選択';

  @override
  String composerModelValue(String value) {
    return 'モデル: $value';
  }

  @override
  String get composerSelectModel => 'モデルを選択';

  @override
  String composerDifficultyValue(String value) {
    return '難易度: $value';
  }

  @override
  String composerYoloModeValue(String value) {
    return 'Yolo モード: $value';
  }

  @override
  String get composerEnabled => '有効';

  @override
  String get composerDisabled => '無効';

  @override
  String get composerConfigureToolsets => 'ツールセットを設定';

  @override
  String get composerCloseEmojiPanel => '絵文字パネルを閉じる';

  @override
  String get composerEmoji => '絵文字';

  @override
  String get composerEditorActions => 'エディター操作';

  @override
  String get composerClearInput => '入力をクリア';

  @override
  String get composerEnterSendsTooltip => 'Enter で送信、Shift+Enter で改行';

  @override
  String get composerEnterNewlineTooltip => 'Enter で改行し、送信ボタンで送信';

  @override
  String get composerEnterSends => 'Enter で送信';

  @override
  String get composerEnterNewline => 'Enter で改行';

  @override
  String composerRemoveAttachment(String label) {
    return '添付を削除: $label';
  }

  @override
  String get composerFolderNotUploaded => 'ローカルフォルダーの参照 — サーバーには送信されません';

  @override
  String get composerCurrentDefault => '現在のプロファイルの既定値';

  @override
  String get composerUsedDefaultTools => '既定のツール設定を使用しました';

  @override
  String composerAppliedTools(int count) {
    return '$count 個のツールを適用しました';
  }

  @override
  String get composerSwitchedToDefault => '既定の設定に切り替えました';

  @override
  String get composerToolConfiguration => 'ツール設定';

  @override
  String get composerToolConfigurationDescription =>
      '現在のプロファイルの既定ツールを使うか、このセッション用のツールセットを選択します';

  @override
  String get composerUseCurrentDefault => '現在のプロファイルの既定値を使用';

  @override
  String get composerSelectCustomTools => 'このセッション用のカスタムツールを選択';

  @override
  String get composerConfiguredMcpServers => '設定済みの MCP サーバー';

  @override
  String get composerNoConfiguredMcpServers => '設定済みの MCP サーバーはありません';

  @override
  String get composerUseDefault => '既定値を使用';

  @override
  String get composerApply => '適用';

  @override
  String get commonRemove => '削除';

  @override
  String get onboardingChatTitle => 'Hermes とチャット';

  @override
  String get onboardingChatDescription =>
      'セッションの開始、音声入力、ツール呼び出しや推論の確認、過去の会話の継続ができます。';

  @override
  String get onboardingProjectsTitle => 'プロジェクトとセッション';

  @override
  String get onboardingProjectsDescription =>
      'プロジェクト、Git ブランチ、worktree ごとに自動整理し、ピン留め、アーカイブ、状態フィルターを利用できます。';

  @override
  String get onboardingTerminalTitle => 'ターミナルと Git';

  @override
  String get onboardingTerminalDescription =>
      'モバイルからコマンド実行、diff 確認、ステージとコミット、Pull Request の作成ができます。';

  @override
  String get onboardingPaletteTitle => 'コマンドパレット';

  @override
  String get onboardingPaletteDescription =>
      '検索またはプルダウンで開き、機能、最近のセッション、スラッシュコマンドへ移動できます。';

  @override
  String get onboardingPetTitle => 'あなたの AI ペット';

  @override
  String get onboardingPetDescription => 'タスクの状態に反応し、専用の外観も生成できる AI ペットです。';

  @override
  String get onboardingSkip => 'スキップ';

  @override
  String get onboardingStart => '始める';

  @override
  String get onboardingNext => '次へ';

  @override
  String get petGenerateInputRequired => '説明を入力するか、参照画像を追加してください';

  @override
  String get petGenerateEmptyResult => '生成結果がありません';

  @override
  String petGenerateHatchFailed(Object error) {
    return '孵化に失敗しました: $error';
  }

  @override
  String petGenerateAdoptFailed(Object error) {
    return '引き取りに失敗しました: $error';
  }

  @override
  String get petGenerateTitle => '新しいペットを生成';

  @override
  String get petGenerateDescribe => 'ほしいペットを説明してください';

  @override
  String get petGeneratePromptHint => '例: サイバーパンク風の機械猫';

  @override
  String get petGenerateAddReference => '参照画像を追加（任意）';

  @override
  String get petGenerateReferenceHelp => 'すべての案でこの画像を参照します';

  @override
  String get petGenerateModel => '生成モデル';

  @override
  String get petGenerateAutoSelect => '自動選択';

  @override
  String get petGenerateDraftsAction => '4 つの案を生成';

  @override
  String petGenerateProgress(Object done, Object total) {
    return '案を生成中… ($done/$total)';
  }

  @override
  String get petGenerateChooseDraft => '気に入った案を選択';

  @override
  String petGenerateDraftLabel(Object index) {
    return '案 $index';
  }

  @override
  String get petGenerateAgain => '再生成';

  @override
  String get petGenerateHatch => '孵化';

  @override
  String get petGeneratePreparing => '準備中…';

  @override
  String petGenerateDrawingProgress(Object done, Object state, Object total) {
    return '$state のフレームを描画中 ($done/$total)';
  }

  @override
  String petGenerateDrawing(Object state) {
    return '$state のフレームを描画中';
  }

  @override
  String get petGenerateComposing => 'スプライトシートを合成中…';

  @override
  String get petGenerateSaving => '保存中…';

  @override
  String get petGenerateHatching => '孵化中…';

  @override
  String get petGenerateReady => '新しいペットが孵化しました！';

  @override
  String get petGenerateNameLabel => '名前を付ける';

  @override
  String get petGenerateDiscard => '破棄';

  @override
  String get petGenerateAdopt => '引き取る';

  @override
  String get imageSave => '画像を保存';

  @override
  String get imageCopyLink => '画像リンクをコピー';

  @override
  String get imageSavedToGallery => 'ギャラリーに保存しました';

  @override
  String get kanbanHomeChannels => 'ホームチャンネル通知';

  @override
  String get kanbanHomeChannelsFailed => 'ホームチャンネルを読み込めませんでした';

  @override
  String get kanbanHomeChannelsEmpty => '利用可能なホームチャンネルはありません';

  @override
  String kanbanUnsupportedAction(Object action) {
    return 'このバージョンでは $action 操作をサポートしていません';
  }

  @override
  String chatSessionSaved(Object path) {
    return '会話履歴を $path に保存しました';
  }

  @override
  String get artifactSessionPendingTitle => 'セッションを開始すると成果物を確認できます';

  @override
  String get artifactSessionPendingDescription =>
      'この会話が保存されると、生成された成果物がここに表示されます。';

  @override
  String get artifactEmptyTitle => '成果物はまだありません';

  @override
  String get artifactEmptyDescription =>
      'このセッションで生成されたコード、ファイル、リンク、画像がここに表示されます。';

  @override
  String artifactFallbackLabel(Object id) {
    return '成果物 $id';
  }

  @override
  String get artifactDetailTitle => '成果物の詳細';

  @override
  String artifactSessionMeta(Object kind, Object session) {
    return '$kind · セッション $session';
  }

  @override
  String get artifactMetadata => 'メタデータ';

  @override
  String get artifactSaveAs => '名前を付けて保存';

  @override
  String get artifactCopyContent => '内容をコピー';

  @override
  String artifactExportFailed(String error) {
    return 'エクスポートに失敗しました: $error';
  }

  @override
  String get artifactType => '種類';

  @override
  String get artifactSession => 'セッション';

  @override
  String get artifactSessionTitle => 'セッション名';

  @override
  String get artifactMessageRow => 'メッセージ行';

  @override
  String get logsAllServers => 'すべてのサーバー';

  @override
  String get logsLoading => 'ログを読み込み中…';

  @override
  String get webhookEnableFirst => '先に Webhook プラットフォームを有効にしてください';

  @override
  String get webhookEnabledRestart =>
      'Webhook を有効にしました。Hermes ゲートウェイを再起動してください。';

  @override
  String get webhookEnabled => 'Webhook を有効にしました';

  @override
  String webhookEnableFailed(Object error) {
    return 'Webhook を有効にできませんでした: $error';
  }

  @override
  String get webhookLoading => 'Webhook を読み込み中…';

  @override
  String get webhookEmptyTitle => 'Webhook はありません';

  @override
  String get webhookEmptyDescription =>
      '+ をタップして Hermes イベント配信用の Webhook を作成します。';

  @override
  String get webhookPlatformDisabled => 'Webhook プラットフォームは無効です · タップして有効化';

  @override
  String get webhookConfigured => '設定済み Webhook';

  @override
  String get webhookStopped => 'Webhook を無効にしました';

  @override
  String webhookOperationFailed(Object error) {
    return 'Webhook 操作に失敗しました: $error';
  }

  @override
  String get webhookDeleteTitle => 'Webhook を削除しますか？';

  @override
  String webhookDeletePrompt(Object name) {
    return '$name を削除します。';
  }

  @override
  String get webhookDeleted => 'Webhook を削除しました';

  @override
  String webhookDeleteFailed(Object error) {
    return 'Webhook を削除できませんでした: $error';
  }

  @override
  String get webhookEnabledLabel => '有効';

  @override
  String get webhookDisabledLabel => '無効';

  @override
  String get webhookEvents => '購読イベント';

  @override
  String get webhookDescription => '説明';

  @override
  String get webhookPrompt => 'プロンプト';

  @override
  String get webhookSkills => 'スキル';

  @override
  String get webhookDeliverTo => '配信先';

  @override
  String get webhookEnableThis => 'この Webhook を有効にする';

  @override
  String get webhookHotReloadDescription => '変更は Hermes ゲートウェイに即時反映されます。';

  @override
  String get webhookNameRequired => '名前を入力してください';

  @override
  String get webhookCreated => 'Webhook を作成しました';

  @override
  String get webhookSecretOnce => '署名シークレットが完全に表示されるのは一度だけです。今すぐ保存してください。';

  @override
  String get webhookSecretSaved => '保存しました';

  @override
  String webhookSaveFailed(Object error) {
    return 'Webhook を保存できませんでした: $error';
  }

  @override
  String get webhookNew => '新しい Webhook';

  @override
  String get webhookName => '名前';

  @override
  String get webhookDescriptionOptional => '説明（任意）';

  @override
  String get webhookEventsComma => '購読イベント（カンマ区切り）';

  @override
  String get webhookPromptOptional => 'トリガープロンプト（任意）';

  @override
  String get webhookSkillsComma => 'Skills（カンマ区切り、任意）';

  @override
  String get webhookDeliveryTarget => '配信先';

  @override
  String get webhookLogOnly => 'ログのみ';

  @override
  String get webhookSaving => '保存中…';

  @override
  String commonPartialDataLoadFailed(Object details) {
    return '一部のデータを読み込めませんでした: $details';
  }

  @override
  String cronRunsLoadFailed(Object error) {
    return '実行履歴を読み込めませんでした: $error';
  }

  @override
  String profilesOptionsLoadFailed(Object details) {
    return '一部のプロファイル編集オプションを読み込めませんでした: $details';
  }

  @override
  String skillsBulkFailed(Object failed, Object total) {
    return '$total 件中 $failed 件のスキル更新に失敗しました。';
  }

  @override
  String petCleanupFailed(Object error) {
    return '生成タスクをクリーンアップできませんでした: $error';
  }

  @override
  String get skillsTitle => 'スキル';

  @override
  String get skillsMarketplace => 'スキルマーケット';

  @override
  String get skillsEnableAll => 'すべて有効化';

  @override
  String get skillsDisableAll => 'すべて無効化';

  @override
  String skillsToggleFailed(Object error) {
    return 'スキルを更新できませんでした: $error';
  }

  @override
  String get skillsSearchHint => 'スキルを検索...';

  @override
  String skillsEnabledCount(Object enabled, Object total) {
    return '有効 $enabled/$total';
  }

  @override
  String get skillsLoading => 'スキルを読み込み中...';

  @override
  String get skillsEmptyTitle => 'スキルがありません';

  @override
  String get skillsEmptyDescription => 'この Agent で利用できるスキルはありません。';

  @override
  String get skillsUncategorized => '未分類';

  @override
  String get skillsNoMatches => '一致するスキルがありません';

  @override
  String skillsUsageCount(Object count) {
    return '$count 回使用';
  }

  @override
  String get skillsLearned => '学習済み';

  @override
  String get skillsBuiltIn => '組み込み';

  @override
  String get skillsProvenanceMarketplace => 'マーケット';

  @override
  String get skillsSaved => '保存しました';

  @override
  String skillsSaveFailed(Object error) {
    return 'スキルを保存できませんでした: $error';
  }

  @override
  String get skillsArchiveQuestion => 'スキルをアーカイブしますか？';

  @override
  String skillsArchivePrompt(Object name) {
    return '学習済みスキル「$name」をアーカイブします。後で元に戻せます。';
  }

  @override
  String get skillsArchive => 'アーカイブ';

  @override
  String get skillsArchived => 'アーカイブしました';

  @override
  String skillsArchiveFailed(Object error) {
    return 'スキルをアーカイブできませんでした: $error';
  }

  @override
  String get skillsContent => '内容';

  @override
  String get skillsNoContent => '（内容なし）';

  @override
  String get skillsCancelEdit => '編集をキャンセル';

  @override
  String get skillsSaving => '保存中...';

  @override
  String get historyTitle => '履歴';

  @override
  String historyResumeFailed(Object error) {
    return 'セッションを再開できませんでした: $error';
  }

  @override
  String get historyManageSessions => 'セッション管理';

  @override
  String get historyHideArchived => 'アーカイブ済みを非表示';

  @override
  String get historyShowArchived => 'アーカイブ済みを表示';

  @override
  String get historySelectTitle => 'セッションを選択';

  @override
  String get historySelectDescription => '左側でセッションを選択すると、概要と管理操作を表示できます。';

  @override
  String get historyLoading => 'セッション履歴を読み込み中...';

  @override
  String get historySearchHint => 'タイトル、内容、作業ディレクトリを検索';

  @override
  String get historyClearSearch => '検索をクリア';

  @override
  String get historyEmpty => 'セッションはまだありません';

  @override
  String get historyNoMatches => '一致するセッションがありません';

  @override
  String get historyLoadMore => 'さらに読み込む';

  @override
  String historyLoadMoreCount(Object loaded, Object total) {
    return 'さらに読み込む（$loaded/$total）';
  }

  @override
  String get historyPinned => '固定';

  @override
  String get historyToday => '今日';

  @override
  String get historyYesterday => '昨日';

  @override
  String get historyThisWeek => '今週';

  @override
  String get historyLastWeek => '先週';

  @override
  String get historyEarlier => 'それ以前';

  @override
  String get historyCollapseChildren => '子セッションを閉じる';

  @override
  String get historyExpandChildren => '子セッションを展開';

  @override
  String get historySessionActions => 'セッション操作';

  @override
  String get historyManageSession => 'セッションを管理';

  @override
  String get historyUntitled => '無題のセッション';

  @override
  String historyMessageCount(Object count) {
    return '$count 件のメッセージ';
  }

  @override
  String get historyDeleteQuestion => 'セッションを削除しますか？';

  @override
  String historyDeletePrompt(Object title) {
    return '「$title」は完全に削除されます。この操作は元に戻せません。';
  }

  @override
  String historyDeleteFailed(Object error) {
    return 'セッションを削除できませんでした: $error';
  }

  @override
  String historyRenameFailed(Object error) {
    return 'セッション名を変更できませんでした: $error';
  }

  @override
  String historyCompressed(Object count) {
    return 'セッションを圧縮しました（$count 件のメッセージを削除）';
  }

  @override
  String historyCompressFailed(Object error) {
    return 'セッションを圧縮できませんでした: $error';
  }

  @override
  String historyArchiveFailed(Object error) {
    return 'セッションをアーカイブできませんでした: $error';
  }

  @override
  String historyUnarchiveFailed(Object error) {
    return 'アーカイブを解除できませんでした: $error';
  }

  @override
  String get historyManagement => 'セッション管理';

  @override
  String get historySaveTitle => 'タイトルを保存';

  @override
  String historyContextUsage(Object maximum, Object percent, Object used) {
    return 'コンテキスト使用量: $used / $maximum$percent';
  }

  @override
  String historyPercent(Object percent) {
    return '（$percent%）';
  }

  @override
  String get historyCompress => 'セッションを圧縮';

  @override
  String get historyArchive => 'アーカイブ';

  @override
  String get historyUnarchive => 'アーカイブ解除';

  @override
  String get cronTitle => 'スケジュールタスク';

  @override
  String get cronLoading => 'スケジュールタスクを読み込み中…';

  @override
  String get cronEmptyTitle => 'スケジュールタスクはありません';

  @override
  String get cronEmptyDescription => '指定したスケジュールで実行する自動タスクを作成します。';

  @override
  String get cronNew => '新規タスク';

  @override
  String cronNextRun(Object time) {
    return '次回実行：$time';
  }

  @override
  String get cronRunHistory => '実行履歴';

  @override
  String cronRunHistoryTitle(Object name) {
    return '実行履歴 · $name';
  }

  @override
  String get cronNoRuns => '実行履歴はありません';

  @override
  String get cronTriggerNow => '今すぐ実行';

  @override
  String get cronTriggered => 'タスクを開始しました';

  @override
  String cronTriggerFailed(Object error) {
    return 'タスクを開始できませんでした：$error';
  }

  @override
  String cronUpdateFailed(Object error) {
    return 'タスクを更新できませんでした：$error';
  }

  @override
  String get cronDeleteQuestion => 'スケジュールタスクを削除しますか？';

  @override
  String cronDeletePrompt(Object name) {
    return '「$name」は削除されます。';
  }

  @override
  String cronDeleteFailed(Object error) {
    return 'タスクを削除できませんでした：$error';
  }

  @override
  String get cronStateCompleted => '完了';

  @override
  String get cronStateDisabled => '無効';

  @override
  String get cronStateEnabled => '有効';

  @override
  String get cronStateError => 'エラー';

  @override
  String get cronStatePaused => '一時停止';

  @override
  String get cronStateRunning => '実行中';

  @override
  String get cronStateScheduled => '予定済み';

  @override
  String cronModelsLoadFailed(Object error) {
    return 'モデル選択肢を読み込めませんでした：$error';
  }

  @override
  String cronBlueprintsLoadFailed(Object error) {
    return '自動化テンプレートを読み込めませんでした：$error';
  }

  @override
  String cronTargetsLoadFailed(Object error) {
    return '配信先を読み込めませんでした：$error';
  }

  @override
  String get cronPresetMinute => '毎分';

  @override
  String get cronPresetHour => '毎時';

  @override
  String get cronPresetDay => '毎日 09:00';

  @override
  String get cronPresetWeek => '毎週月曜 09:00';

  @override
  String get cronPresetMonth => '毎月 1 日 09:00';

  @override
  String get cronPresetCustom => 'カスタム';

  @override
  String get cronPresetMinuteHint => '毎分実行します';

  @override
  String get cronPresetHourHint => '毎時 0 分に実行します';

  @override
  String get cronPresetDayHint => '毎日 9 時に実行します';

  @override
  String get cronPresetWeekHint => '毎週月曜 9 時に実行します';

  @override
  String get cronPresetMonthHint => '毎月 1 日 9 時に実行します';

  @override
  String get cronPromptAndExpressionRequired => 'タスク指示と Cron 式を入力してください。';

  @override
  String get cronExpressionRequired => 'Cron 式を入力してください。';

  @override
  String get cronPromptRequired => 'タスク指示を入力してください。';

  @override
  String cronSaveFailed(Object error) {
    return 'タスクを保存できませんでした：$error';
  }

  @override
  String get cronCreateTitle => '新規スケジュールタスク';

  @override
  String get cronEditTitle => 'スケジュールタスクを編集';

  @override
  String get cronStartFromTemplate => 'テンプレートから開始';

  @override
  String get cronScheduling => 'スケジュール中…';

  @override
  String get cronScheduleAutomation => '自動化をスケジュール';

  @override
  String get cronScriptOnlyDescription =>
      'これはスクリプト専用タスクです。名前、スケジュール、配信先は変更できますが、スクリプトとモデル設定は変更されません。';

  @override
  String get cronScriptLabel => 'スクリプト';

  @override
  String cronLastRun(Object time) {
    return '前回実行：$time';
  }

  @override
  String get cronRunScheduledAt => 'スケジュール時刻';

  @override
  String get cronRunStartedAt => '開始時刻';

  @override
  String get cronRunFinishedAt => '終了時刻';

  @override
  String get cronRunStatus => '状態';

  @override
  String get cronRunOutput => '出力';

  @override
  String get cronRunDetailTitle => '実行に成功しました';

  @override
  String get cronRunDetailFailedTitle => '実行に失敗しました';

  @override
  String get cronNameOptional => '名前（任意）';

  @override
  String get cronDeliverResultsTo => '結果の配信先';

  @override
  String get cronTaskModel => 'タスクモデル';

  @override
  String get cronUseGlobalDefault => 'グローバル既定値を使用';

  @override
  String cronSavedModel(Object model) {
    return '$model（保存済み）';
  }

  @override
  String get cronPromptLabel => 'タスク指示（prompt）';

  @override
  String get cronFrequency => '頻度';

  @override
  String get cronExpression => 'Cron 式';

  @override
  String get cronExpressionHint => '分 時 日 月 曜日';

  @override
  String get cronSaving => '保存中…';

  @override
  String get cronThisDevice => 'このデバイス';

  @override
  String get cronConfigureHomeChannelFirst => '先にホームチャンネルを設定してください';

  @override
  String get profilesTitle => 'Agent Profiles';

  @override
  String get profilesLoading => 'プロファイルを読み込み中…';

  @override
  String get profilesEmptyTitle => 'プロファイルはありません';

  @override
  String get profilesEmptyDescription => '最初のエージェントプロファイルを作成します。';

  @override
  String get profilesNew => '新規プロファイル';

  @override
  String get profilesImport => 'プロファイルをインポート';

  @override
  String get profilesExport => 'プロファイルをエクスポート';

  @override
  String get profilesDuplicate => 'プロファイルを複製';

  @override
  String get profilesEditSoul => 'SOUL.md を編集';

  @override
  String get profilesSetupCommand => 'ターミナル起動コマンド';

  @override
  String profilesSaveFailed(Object error) {
    return 'プロファイルを保存できませんでした：$error';
  }

  @override
  String get profilesCreated => 'プロファイルを作成しました';

  @override
  String get profilesSaved => 'プロファイルを保存しました';

  @override
  String profilesCopyName(Object name) {
    return '$name のコピー';
  }

  @override
  String profilesDuplicateFailed(Object error) {
    return 'プロファイルを複製できませんでした：$error';
  }

  @override
  String get profilesDuplicated => 'プロファイルを複製しました';

  @override
  String profilesDeleteQuestion(Object name) {
    return 'プロファイル「$name」を削除しますか？';
  }

  @override
  String get profilesDeleteActiveWarning => 'このプロファイルは現在使用中です。';

  @override
  String get profilesDeleteWarning => 'この操作は元に戻せません。';

  @override
  String profilesDeleteFailed(Object error) {
    return 'プロファイルを削除できませんでした：$error';
  }

  @override
  String get profilesDeleted => 'プロファイルを削除しました';

  @override
  String profilesSwitchFailed(Object error) {
    return 'プロファイルを切り替えられませんでした：$error';
  }

  @override
  String profilesSwitchedTo(Object name) {
    return '「$name」に切り替えました';
  }

  @override
  String get profilesSoulHint => 'このエージェントの役割、振る舞い、コミュニケーション方法を記述します';

  @override
  String get profilesSoulSaved => 'SOUL.md を保存しました';

  @override
  String profilesSoulFailed(Object error) {
    return 'SOUL.md の操作に失敗しました：$error';
  }

  @override
  String get profilesCopy => 'コピー';

  @override
  String profilesSetupCommandFailed(Object error) {
    return '起動コマンドを読み込めませんでした：$error';
  }

  @override
  String get profilesExported => 'プロファイルをエクスポートしました';

  @override
  String profilesExportFailed(Object error) {
    return 'プロファイルをエクスポートできませんでした：$error';
  }

  @override
  String profilesImported(Object name) {
    return '$name をインポートしました';
  }

  @override
  String profilesImportFailed(Object error) {
    return 'プロファイルをインポートできませんでした：$error';
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
  String get profilesCurrentSuffix => ' · 使用中';

  @override
  String get profilesActive => '使用中';

  @override
  String get profilesActivate => '有効化';

  @override
  String get profilesNameRequired => 'プロファイル名を入力してください。';

  @override
  String get profilesCreateTitle => '新規プロファイル';

  @override
  String get profilesEditTitle => 'プロファイルを編集';

  @override
  String get profilesProvider => 'プロバイダー';

  @override
  String get profilesModel => 'モデル';

  @override
  String get profilesSystemPrompt => 'システムプロンプト';

  @override
  String get profilesDescriptionOptional => '説明（任意）';

  @override
  String get profilesTools => 'ツール';

  @override
  String get profilesDeselectAll => 'すべて選択解除';

  @override
  String get profilesSelectAll => 'すべて選択';

  @override
  String get profilesSetActive => '使用中のプロファイルに設定';

  @override
  String get memoryTitle => 'メモリ';

  @override
  String get memoryLoading => 'メモリの状態を読み込み中…';

  @override
  String memorySwitchFailed(Object error) {
    return 'プロバイダーを切り替えられませんでした：$error';
  }

  @override
  String get memoryResetScope => 'リセットする範囲を選択';

  @override
  String get memoryResetScopeDescription => '選択したメモリファイルのみ削除されます。';

  @override
  String get memoryAll => 'すべてのメモリ';

  @override
  String get memoryAllFiles => 'MEMORY.md と USER.md';

  @override
  String get memoryLongTerm => '長期メモリ';

  @override
  String get memoryLongTermFile => 'MEMORY.md のみ';

  @override
  String get memoryUser => 'ユーザーメモリ';

  @override
  String get memoryUserFile => 'USER.md のみ';

  @override
  String get memoryResetQuestion => 'メモリをリセットしますか？';

  @override
  String get memoryResetWarning => '削除したメモリは復元できません。';

  @override
  String get memoryNothingDeleted => '削除するメモリファイルはありませんでした。';

  @override
  String memoryDeleted(Object files) {
    return '$files を削除しました';
  }

  @override
  String memoryResetFailed(Object error) {
    return 'メモリをリセットできませんでした：$error';
  }

  @override
  String memoryCuratorUpdateFailed(Object error) {
    return 'Curator を更新できませんでした：$error';
  }

  @override
  String get memoryCuratorStarted => 'Curator を開始しました';

  @override
  String memoryCuratorRunFailed(Object error) {
    return 'Curator を実行できませんでした：$error';
  }

  @override
  String get memoryCurrentProvider => '現在のメモリプロバイダー';

  @override
  String get memoryDisabled => '無効';

  @override
  String get memoryEnabled => '有効';

  @override
  String get memoryProviders => 'プロバイダー';

  @override
  String get memoryNoProviders => '利用可能なプロバイダーはありません';

  @override
  String get memoryBuiltInFiles => '組み込みメモリファイル';

  @override
  String get memoryReset => 'メモリをリセット';

  @override
  String get memoryInUse => '使用中';

  @override
  String get memoryConfigured => '設定済み';

  @override
  String memoryConfigureProvider(Object name) {
    return '$name を設定';
  }

  @override
  String memoryEnableProvider(Object name) {
    return '$name を有効化';
  }

  @override
  String get memoryCuratorLoading => 'Curator の状態を読み込み中…';

  @override
  String get memoryCuratorUnavailable => 'Curator は利用できません';

  @override
  String get memoryPaused => '一時停止';

  @override
  String memoryCuratorInterval(Object hours) {
    return '$hours 時間ごとに確認';
  }

  @override
  String memoryCuratorLastRun(Object time) {
    return '前回の実行 $time';
  }

  @override
  String get memoryResume => '再開';

  @override
  String get memoryPause => '一時停止';

  @override
  String get memoryRunNow => '今すぐ実行';

  @override
  String memoryInvalidJson(Object field) {
    return '$field は有効な JSON ではありません';
  }

  @override
  String get memoryProviderSaved => 'プロバイダー設定を保存しました';

  @override
  String memoryProviderSaveFailed(Object error) {
    return 'プロバイダー設定を保存できませんでした：$error';
  }

  @override
  String get memoryOAuthTimeout => '接続がタイムアウトしました。再試行してください。';

  @override
  String get memoryCurrentProfile => '現在のプロファイル';

  @override
  String memoryProfile(Object name) {
    return 'プロファイル：$name';
  }

  @override
  String get memoryProviderConfigLoading => 'プロバイダー設定を読み込み中…';

  @override
  String get memoryNoProviderConfig => 'このプロバイダーに追加設定はありません';

  @override
  String get memoryViewProviderDocs => 'プロバイダーのドキュメントを表示';

  @override
  String get memorySaving => '保存中…';

  @override
  String get memorySaveConfig => '設定を保存';

  @override
  String get memoryAccountConnected => 'アカウント接続済み';

  @override
  String get memoryConnectAccount => 'プロバイダーアカウントに接続';

  @override
  String get memoryReconnect => '再接続';

  @override
  String get memoryConnect => '接続';

  @override
  String get memoryKeepSecretHint => '現在の値を保持するには空欄のままにします';

  @override
  String agentOpenBotFailed(Object error) {
    return 'Bot Chat を開けませんでした：$error';
  }

  @override
  String get agentNewGroup => '新規グループチャット';

  @override
  String get agentEditGroup => 'グループチャットを編集';

  @override
  String get agentGroupName => 'グループチャット名';

  @override
  String agentGroupSaveFailed(Object error) {
    return 'グループチャットを保存できませんでした：$error';
  }

  @override
  String agentBotThinking(Object name) {
    return '$name が考えています';
  }

  @override
  String agentBotPaused(Object name) {
    return '$name は一時停止中';
  }

  @override
  String get agentStartGroupChat => 'グループチャットを開始';

  @override
  String agentReplyTo(Object id) {
    return '#$id に返信';
  }

  @override
  String get agentSendToRoom => 'ルームに送信';

  @override
  String get agentMentionHint => '@名前でメンバーを指定し、@all で全員に通知します';

  @override
  String agentAttachmentTooLarge(Object name) {
    return '$name は 20MB を超えています';
  }

  @override
  String agentAttachFailed(Object error) {
    return '添付ファイルを追加できませんでした：$error';
  }

  @override
  String agentGroupSendFailed(Object error) {
    return 'グループメッセージを送信できませんでした：$error';
  }

  @override
  String get agentAppendMessage => 'メッセージを追加';

  @override
  String get agentAwaitingApproval => '承認待ち';

  @override
  String get agentNeedsInformation => '追加情報が必要です';

  @override
  String get agentRespond => '応答';

  @override
  String agentMemberRequest(Object name) {
    return '$name からのリクエスト';
  }

  @override
  String get agentAllowOperationQuestion => 'この操作を許可しますか？';

  @override
  String get agentDeny => '拒否';

  @override
  String get agentAlwaysAllow => '常に許可';

  @override
  String get agentAllow => '許可';

  @override
  String get agentCustomAnswer => 'カスタム回答';

  @override
  String get agentEnterAnswer => '回答を入力してください';

  @override
  String agentRespondFailed(Object error) {
    return '応答できませんでした：$error';
  }

  @override
  String get agentLoading => 'Agent の状態を読み込み中…';

  @override
  String get agentNoData => 'データがありません';

  @override
  String get agentManageBots => 'Bot の管理または作成';

  @override
  String get agentRefreshRoster => 'Bot 名簿を更新';

  @override
  String agentGroupSummary(Object count, Object runningSuffix) {
    return '$count Bot · 複数接続$runningSuffix';
  }

  @override
  String get agentRunningSuffix => ' · 実行中';

  @override
  String agentDeleteGroupQuestion(Object name) {
    return 'グループチャット「$name」を削除しますか？';
  }

  @override
  String get agentDeleteGroupWarning => 'グループ履歴は完全に削除されます。この操作は元に戻せません。';

  @override
  String agentDeleteGroupFailed(Object error) {
    return 'グループチャットを削除できませんでした：$error';
  }

  @override
  String get agentDeleteGroup => 'グループチャットを削除';

  @override
  String agentDeleteBotQuestion(Object name) {
    return 'Bot「$name」を削除しますか？';
  }

  @override
  String agentBotOperationFailed(Object error) {
    return 'Bot 操作に失敗しました：$error';
  }

  @override
  String get agentDuplicateBot => 'Bot を複製';

  @override
  String get agentDeleteBot => 'Bot を削除';

  @override
  String get agentGateway => 'ゲートウェイ';

  @override
  String get agentActiveAgents => '稼働中の Agent';

  @override
  String get agentBusy => 'ビジー';

  @override
  String get agentYes => 'はい';

  @override
  String get agentNo => 'いいえ';

  @override
  String get agentModelSection => 'モデル';

  @override
  String get agentCurrentModel => '現在のモデル';

  @override
  String get agentProvider => 'プロバイダー';

  @override
  String get agentContextLength => 'コンテキスト長';

  @override
  String get agentSessionModel => 'セッションモデル';

  @override
  String get agentRuntimeSection => 'ランタイム';

  @override
  String get agentType => '種類';

  @override
  String get agentSourceRoot => 'ソースルート';

  @override
  String get agentHermesHome => 'Hermes ホーム';

  @override
  String get agentServerVersion => 'サーバーバージョン';

  @override
  String get agentCapability => '機能';

  @override
  String get agentRestarting => '再起動中…';

  @override
  String botRoutineUpdateFailed(Object error) {
    return 'Cronjob を更新できませんでした：$error';
  }

  @override
  String get botRoutineDeleteQuestion => 'Cronjob を削除しますか？';

  @override
  String botRoutineDeletePrompt(Object title) {
    return '「$title」とそのスケジュールは完全に削除されます。';
  }

  @override
  String get botRoutineStatus => '状態';

  @override
  String get botRoutinePaused => '一時停止';

  @override
  String get botRoutineSchedule => 'スケジュール';

  @override
  String get botRoutineRawSchedule => '元のスケジュール';

  @override
  String get botRoutineRepeatCount => '繰り返し回数';

  @override
  String get botRoutineNextRun => '次回実行';

  @override
  String get botRoutineLastRun => '前回実行';

  @override
  String get botRoutineLastResult => '前回の結果';

  @override
  String get botRoutineDeliverTo => '配信先';

  @override
  String get botRoutineModel => 'モデル';

  @override
  String get botRoutineWorkdir => '作業ディレクトリ';

  @override
  String get botRoutineInstruction => '指示';

  @override
  String get botRoutineLegacyWarning =>
      'この旧形式のタスクは安全のため一時停止されています。削除して再作成してから実行してください。';

  @override
  String botRoutineTitle(Object name) {
    return '$name · 定期タスク';
  }

  @override
  String commonBytes(Object count) {
    return '$count バイト';
  }

  @override
  String get botRoutineLoading => 'Bot Cronjob を読み込み中…';

  @override
  String get botRoutineEmptyTitle => 'Cronjob はありません';

  @override
  String botRoutineEmptyDescription(Object name) {
    return '$name 専用のスケジュールタスクを作成します。';
  }

  @override
  String get botRoutineNew => '新規 Cronjob';

  @override
  String botRoutineNext(Object time) {
    return '次回 $time';
  }

  @override
  String get botRoutineLegacyPaused => '旧形式のタスク、安全に一時停止中';

  @override
  String get botRoutineDelete => 'Cronjob を削除';

  @override
  String botRoutineScheduleOnce(Object duration) {
    return '1 回 · $duration 後';
  }

  @override
  String botRoutineScheduleEvery(Object duration) {
    return '$duration ごと';
  }

  @override
  String get botRoutineScheduleHourly => '毎時 0 分';

  @override
  String get botRoutineScheduleDaily => '毎日 09:00';

  @override
  String get botRoutineScheduleWeekdays => '平日 09:00';

  @override
  String get botRoutineScheduleWeekly => '毎週月曜 09:00';

  @override
  String get botRoutineScheduleMonthly => '毎月 1 日 09:00';

  @override
  String get botRoutineRequiredFields => '名前、指示、実行スケジュールを入力してください。';

  @override
  String botRoutineCreateTitle(Object name) {
    return '新規 Cronjob · $name';
  }

  @override
  String get botRoutineInstructionLabel => '毎回実行する指示';

  @override
  String get botRoutineFrequencyOnce => '一定時間後に 1 回';

  @override
  String get botRoutineFrequencyHourly => '毎時';

  @override
  String get botRoutineFrequencyDaily => '毎日';

  @override
  String get botRoutineFrequencyWeekdays => '平日';

  @override
  String get botRoutineFrequencyWeekly => '毎週';

  @override
  String get botRoutineFrequencyMonthly => '毎月';

  @override
  String get botRoutineFrequencyInterval => '固定間隔';

  @override
  String get botRoutineFrequencyAdvanced => '高度な式';

  @override
  String get botRoutineTime => '時刻（HH:mm）';

  @override
  String get botRoutineWeekday => '曜日';

  @override
  String get botRoutineMonday => '月曜日';

  @override
  String get botRoutineTuesday => '火曜日';

  @override
  String get botRoutineWednesday => '水曜日';

  @override
  String get botRoutineThursday => '木曜日';

  @override
  String get botRoutineFriday => '金曜日';

  @override
  String get botRoutineSaturday => '土曜日';

  @override
  String get botRoutineSunday => '日曜日';

  @override
  String get botRoutineDayOfMonth => '日付';

  @override
  String get botRoutineValue => '値';

  @override
  String get botRoutineUnit => '単位';

  @override
  String get botRoutineMinutes => '分';

  @override
  String get botRoutineHours => '時間';

  @override
  String get botRoutineDays => '日';

  @override
  String get botRoutineAdvancedExpression => 'Cron または every Nm/Nh/Nd';

  @override
  String botRoutineWillSaveAs(Object schedule) {
    return '保存形式：$schedule';
  }

  @override
  String get botRoutineRepeatLimit => '最大実行回数（空欄なら継続）';

  @override
  String get botRoutineContinuity => '継続性';

  @override
  String get botRoutineContinuityDescription => '各実行でこのタスクの前回出力を参照できます。';

  @override
  String botRoutineSendToBot(Object name) {
    return '$name の Bot Chat に送信';
  }

  @override
  String get botRoutineSendToBotDescription => 'Bot が結果を読み取り、応答を続けます。';

  @override
  String get botRoutineCreating => '作成中…';

  @override
  String get botRoutineCreate => 'Cronjob を作成';

  @override
  String get mcpTitle => 'MCP サーバー';

  @override
  String mcpOperationFailed(Object error) {
    return '操作に失敗しました：$error';
  }

  @override
  String get mcpPersistenceFailed => 'サーバーが MCP 設定の変更を永続化しませんでした。';

  @override
  String mcpTestSuccess(Object prompts, Object resources, Object tools) {
    return '接続成功：$tools ツール、$prompts プロンプト、$resources リソース';
  }

  @override
  String mcpTestConnectionFailed(Object error) {
    return '接続失敗：$error';
  }

  @override
  String mcpTestFailed(Object error) {
    return 'テストに失敗しました：$error';
  }

  @override
  String mcpReloadFailed(Object error) {
    return '設定は保存されましたが、アクティブセッションの MCP ホットリロードに失敗しました：$error';
  }

  @override
  String get mcpImportUnrecognized => '貼り付けた内容を認識できません。形式を確認してください。';

  @override
  String mcpImportDetected(Object count) {
    return '$count 台のサーバーを検出';
  }

  @override
  String mcpImportAllQuestion(Object names) {
    return 'すべて追加しますか？\n\n$names';
  }

  @override
  String get mcpAddAll => 'すべて追加';

  @override
  String mcpServersAdded(Object count) {
    return '$count 台のサーバーを追加しました';
  }

  @override
  String mcpServersPartiallyAdded(Object added, Object failed) {
    return '$added 台を追加、$failed 台が失敗';
  }

  @override
  String get mcpAddServer => 'MCP サーバーを追加';

  @override
  String get mcpPasteImport =>
      '貼り付けてインポート（mcp.json / コマンド / claude mcp add / URL）';

  @override
  String get mcpParse => '解析';

  @override
  String get mcpRemoteUrl => 'リモート URL';

  @override
  String get mcpLocalStdio => 'ローカル stdio';

  @override
  String get mcpServerUrl => 'サーバー URL';

  @override
  String get mcpCommand => 'コマンド';

  @override
  String get mcpArgumentsOnePerLine => '引数（1 行に 1 つ）';

  @override
  String get mcpEnvironmentJson => '環境変数 JSON';

  @override
  String get mcpAuthentication => '認証方式';

  @override
  String get mcpNoAuthentication => '認証なし';

  @override
  String get mcpEnvironmentMustBeJson => '環境変数は JSON オブジェクトである必要があります。';

  @override
  String get mcpServerAdded => 'MCP サーバーを追加しました';

  @override
  String mcpAddFailed(Object error) {
    return 'サーバーを追加できませんでした：$error';
  }

  @override
  String mcpDeleteQuestion(Object name) {
    return '$name を削除しますか？';
  }

  @override
  String get mcpDeleteWarning => 'このサーバーは Hermes MCP 設定から完全に削除されます。';

  @override
  String mcpDeleteFailed(Object error) {
    return 'サーバーを削除できませんでした：$error';
  }

  @override
  String mcpReadConfigFailed(Object error) {
    return '設定を読み込めませんでした：$error';
  }

  @override
  String mcpEditServer(Object name) {
    return '$name を編集';
  }

  @override
  String mcpInvalidJson(Object error) {
    return '有効な JSON オブジェクトではありません：$error';
  }

  @override
  String mcpServerSaved(Object name) {
    return '$name を保存しました';
  }

  @override
  String mcpSaveFailed(Object error) {
    return 'サーバーを保存できませんでした：$error';
  }

  @override
  String mcpToolToggleFailed(Object error) {
    return 'ツールを切り替えられませんでした：$error';
  }

  @override
  String get mcpOAuthStartFailed => 'OAuth を開始できませんでした';

  @override
  String get mcpOAuthMissingUrl => 'OAuth サーバーから認証 URL が返されませんでした。';

  @override
  String get mcpBrowserOpenFailed => 'システムブラウザーを開けませんでした。';

  @override
  String mcpCompleteAuthorization(Object name) {
    return 'ブラウザーで $name の認証を完了してください。';
  }

  @override
  String get mcpOAuthAuthorizationFailed => 'OAuth 認証に失敗しました';

  @override
  String mcpAuthorizationSucceeded(Object name, Object tools) {
    return '$name の認証に成功し、$tools 個のツールを検出しました';
  }

  @override
  String mcpOAuthFailed(Object error) {
    return 'OAuth に失敗しました：$error';
  }

  @override
  String mcpInstallTitle(Object name) {
    return '$name をインストール';
  }

  @override
  String get mcpRequired => '必須';

  @override
  String get mcpOptional => '任意';

  @override
  String get mcpRequiredCredentials => 'すべての必須認証情報を入力してください。';

  @override
  String get mcpReinstall => '再インストール';

  @override
  String get mcpInstall => 'インストール';

  @override
  String mcpInstallExitCode(Object code) {
    return 'インストーラーの終了コード：$code';
  }

  @override
  String mcpInstallComplete(Object name) {
    return '$name のインストールが完了しました';
  }

  @override
  String mcpInstallFailed(Object error) {
    return 'インストールに失敗しました：$error';
  }

  @override
  String get mcpViewLogs => 'ログを表示';

  @override
  String get mcpLoading => 'MCP サーバーを読み込み中…';

  @override
  String get mcpConfiguredServers => '設定済みサーバー';

  @override
  String get mcpNoConfiguredServers => 'MCP サーバーは設定されていません';

  @override
  String get mcpDescription => 'MCP は Agent を外部ツールやデータソースに接続します。';

  @override
  String mcpAvailableCatalog(Object count) {
    return '利用可能なカタログ（$count）';
  }

  @override
  String mcpToolCount(Object count) {
    return '$count ツール';
  }

  @override
  String mcpUsage30Days(Object count) {
    return '30 日間で $count 回';
  }

  @override
  String get mcpTestConnection => '接続をテスト';

  @override
  String get mcpEditConfiguration => '設定を編集';

  @override
  String get mcpOAuthAuthorization => 'OAuth 認証';

  @override
  String get mcpInstalledEnabled => 'インストール済み・有効';

  @override
  String get mcpInstalledDisabled => 'インストール済み・無効';

  @override
  String get commandCenterTitle => 'コマンドセンター';

  @override
  String get commandStatusTab => '状態';

  @override
  String get commandUsageTab => '使用量';

  @override
  String get commandMaintenanceTab => 'メンテナンス';

  @override
  String commandStatusLoadFailed(Object error) {
    return '状態を読み込めませんでした：$error';
  }

  @override
  String commandLogsLoadFailed(Object error) {
    return 'ログを読み込めませんでした：$error';
  }

  @override
  String get commandRestartWarning =>
      'Hermes backend プロセスを再起動します。実行中のターンが中断される場合があります。';

  @override
  String commandRestartResult(Object result) {
    return '再起動結果：$result';
  }

  @override
  String get commandNoLogs => '（ログなし）';

  @override
  String get commandBackendProcess => 'バックエンドプロセス';

  @override
  String get commandStopped => '停止';

  @override
  String get commandLiveLogs => 'ライブログ';

  @override
  String get commandDiagnostics => '診断の詳細';

  @override
  String get commandSystemStatus => 'システム状態';

  @override
  String get commandNoStatusData => '状態データがありません';

  @override
  String commandUsageLoadFailed(Object error) {
    return '使用量を読み込めませんでした：$error';
  }

  @override
  String commandDays(Object count) {
    return '$count 日';
  }

  @override
  String get commandSessions => 'セッション';

  @override
  String get commandApiCalls => 'API 呼び出し';

  @override
  String get commandTokensInOut => 'Token（入/出）';

  @override
  String get commandDailyUsage => '日別使用量';

  @override
  String get commandNoUsageData => '使用量データがありません';

  @override
  String get commandTopModels => 'モデル使用ランキング';

  @override
  String get commandTopSkills => 'スキル使用ランキング';

  @override
  String commandUseCount(Object count) {
    return '$count 回';
  }

  @override
  String commandChartTooltip(Object day, Object input, Object output) {
    return '$day\n入力 $input / 出力 $output';
  }

  @override
  String get commandInputTokens => '入力 tokens';

  @override
  String get commandOutputTokens => '出力 tokens';

  @override
  String commandStarting(Object label) {
    return '$label を開始中…';
  }

  @override
  String get commandMissingActionName => 'バックエンドから操作名が返されませんでした。';

  @override
  String get commandNoOutput => '（出力はまだありません）';

  @override
  String commandActionExitFailed(Object code, Object label) {
    return '$label に失敗しました（終了コード $code）';
  }

  @override
  String commandActionComplete(Object label) {
    return '$label が完了しました';
  }

  @override
  String commandLogError(Object error, Object logs) {
    return '$logs\n\nエラー：$error';
  }

  @override
  String commandActionFailed(Object error, Object label) {
    return '$label に失敗しました：$error';
  }

  @override
  String commandDebugShareFailed(Object error) {
    return 'デバッグ共有を生成できませんでした：$error';
  }

  @override
  String get commandDebugShare => 'デバッグ共有を生成';

  @override
  String get commandLogsRedacted => 'ログの機密情報はマスクされています。';

  @override
  String get commandLogsNotRedacted => 'ログはマスクされていません。共有時は注意してください。';

  @override
  String commandAutoDeleteHours(Object hours) {
    return 'リンクは約 $hours 時間後に自動削除されます。';
  }

  @override
  String get commandPartialUploadFailed => '一部のコンテンツをアップロードできませんでした：';

  @override
  String get commandDiagnosticsMaintenance => '診断とメンテナンス';

  @override
  String get commandRunDoctor => '診断を実行';

  @override
  String get commandRunDoctorDescription => 'hermes doctor - 環境と設定を確認';

  @override
  String get commandDoctor => '診断';

  @override
  String get commandSecurityAudit => 'セキュリティ監査';

  @override
  String get commandSecurityAuditDescription =>
      'hermes security audit - 潜在的なセキュリティ問題を検査';

  @override
  String get commandBackupNow => '今すぐバックアップ';

  @override
  String get commandBackupDescription => 'hermes backup - 設定とデータをローカルに保存';

  @override
  String get commandBackup => 'バックアップ';

  @override
  String get commandDebugShareDescription => 'マスク済みログをアップロードして共有可能なデバッグリンクを作成';

  @override
  String terminalStartFailed(Object error) {
    return 'ターミナルを起動できませんでした：$error';
  }

  @override
  String get terminalSshHost => 'ホストまたは SSH config alias *';

  @override
  String get terminalSshUserOptional => 'ユーザー（任意）';

  @override
  String get terminalSshPort => 'ポート（既定 22）';

  @override
  String get terminalSshIdentityFile => 'サーバー側 IdentityFile（任意）';

  @override
  String get terminalSshRemoteCwd => 'リモート作業ディレクトリ（任意）';

  @override
  String get terminalSshAuthenticationNote =>
      '認証には Hermes server 上の ssh-agent または SSH config を使用します。モバイルアプリはパスワードを保存しません。';

  @override
  String terminalSshFailed(Object error) {
    return 'SSH 接続に失敗しました：$error';
  }

  @override
  String get terminalCloseRunningQuestion => '実行中のターミナルを閉じますか？';

  @override
  String terminalCloseRunningWarning(Object name) {
    return '「$name」のプロセスは終了します。この操作は元に戻せません。';
  }

  @override
  String get terminalClose => 'ターミナルを閉じる';

  @override
  String get terminalSessions => 'ターミナルセッション';

  @override
  String terminalSessionLimit(Object count) {
    return '同時に最大 $count 個のターミナルを開けます';
  }

  @override
  String terminalCloseNamed(Object name) {
    return '$name を閉じる';
  }

  @override
  String get terminalSelectTextFirst => '先にテキストを選択してください。';

  @override
  String terminalPasteLinesQuestion(Object count) {
    return '$count 行を貼り付けますか？';
  }

  @override
  String get terminalMergeSingleLine => '1 行にまとめる';

  @override
  String get terminalConfirmPaste => '貼り付け';

  @override
  String get terminalSelectTerminalTextFirst => '先にターミナル内のテキストを選択してください。';

  @override
  String get terminalSentToChat => 'チャット入力欄に送信しました';

  @override
  String terminalOpenLinkFailed(Object link) {
    return 'リンクを開けませんでした：$link';
  }

  @override
  String get terminalDismissNotice => '通知を閉じる';

  @override
  String get terminalNew => '新規ターミナル';

  @override
  String get terminalNewSsh => '新規 SSH ターミナル';

  @override
  String get terminalOpenDirectory => 'ディレクトリを選択して開く';

  @override
  String get terminalDisplaySettings => 'ターミナル表示設定';

  @override
  String get terminalNoWorkingDirectory => '（作業ディレクトリなし）';

  @override
  String get terminalNoActive => 'アクティブなターミナルはありません';

  @override
  String get terminalCommandMode => 'コマンドモード';

  @override
  String get terminalInteractiveMode => '対話モード';

  @override
  String get terminalControlInterrupt => 'Ctrl+C 中断';

  @override
  String get terminalControlSuspend => 'Ctrl+Z 一時停止';

  @override
  String get terminalControlClear => 'Ctrl+L 画面消去';

  @override
  String get terminalControlBackWord => 'Alt+B 前の単語';

  @override
  String get terminalControlForwardWord => 'Alt+F 次の単語';

  @override
  String get terminalControlKeys => 'コントロールキー';

  @override
  String get terminalVisibleOutputCopied => '現在の画面出力をコピーしました';

  @override
  String get terminalDisplay => 'ターミナル表示';

  @override
  String get terminalDisplayDescription => 'ローカル表示だけを調整し、PTY やコマンドの動作は変更しません。';

  @override
  String get terminalPreviewOutput => '✓ 42 tests passed  ローカライズ出力プレビュー';

  @override
  String terminalFontSize(Object value) {
    return 'フォントサイズ  $value';
  }

  @override
  String terminalLineHeight(Object value) {
    return '行の高さ  $value';
  }

  @override
  String get terminalColorTheme => 'カラーテーマ';

  @override
  String get terminalThemeSystem => 'システムに合わせる';

  @override
  String get terminalThemeProfessionalDark => 'プロフェッショナルダーク';

  @override
  String get terminalThemeHighContrastDark => '高コントラストダーク';

  @override
  String get terminalThemeSoftLight => 'ソフトライト';

  @override
  String get terminalCursorStyle => 'カーソルスタイル';

  @override
  String get terminalCursorBar => 'バー';

  @override
  String get terminalCursorBlock => 'ブロック';

  @override
  String get terminalCursorUnderline => '下線';

  @override
  String get terminalContentPadding => 'ターミナル余白';

  @override
  String get terminalContentPaddingHint => 'オフにすると列を多く表示できます';

  @override
  String get terminalResetDisplay => '推奨設定に戻す';

  @override
  String get terminalCommandHint => 'コマンドを入力…';

  @override
  String get terminalRunCommand => 'コマンドを実行';

  @override
  String get terminalPaste => '貼り付け';

  @override
  String get terminalClear => '画面消去';

  @override
  String get terminalSendToChat => 'チャットに送信';

  @override
  String get terminalInteractiveHint => '対話モード · 入力は PTY に直接送信されます';

  @override
  String get terminalMoreActions => 'その他のターミナル操作';

  @override
  String get terminalCopySelection => '選択範囲をコピー';

  @override
  String get terminalSendSelectionToChat => '選択範囲をチャットに送信';

  @override
  String get terminalOpenOtherDirectory => '別のディレクトリでターミナルを開く';

  @override
  String get terminalManageSessions => 'ターミナルセッションを管理';

  @override
  String get terminalPrivacyHistory => 'プライバシーと履歴';

  @override
  String get terminalPrivacyDescription => 'コマンド履歴とターミナル出力は既定では保存されません。';

  @override
  String get terminalSaveCommandHistory => 'コマンド履歴を保存';

  @override
  String get terminalSaveOutputSnapshots => 'ターミナル出力スナップショットを保存';

  @override
  String get terminalClearSavedData => '保存済みの履歴とスナップショットを消去';

  @override
  String get terminalClearDataQuestion => '履歴とスナップショットを消去しますか？';

  @override
  String get terminalClearDataWarning =>
      '保存済みのコマンド履歴とターミナル出力スナップショットは完全に削除されます。この操作は元に戻せません。';

  @override
  String filesRevealFailed(String error) {
    return 'ファイルマネージャーで表示できません: $error';
  }

  @override
  String get filesLargeDownloadQuestion => '大きなファイルをダウンロードしますか？';

  @override
  String filesLargeDownloadDescription(String name, String size) {
    return '「$name」は約 $size MB です。ダウンロードに時間と容量がかかる場合があります。';
  }

  @override
  String get filesContinueDownload => 'ダウンロードを続ける';

  @override
  String get filesLargeEditQuestion => '大きなファイルを開きますか？';

  @override
  String filesLargeEditDescription(String name, String size) {
    return '「$name」は約 $size MB です。エディターへの読み込みに時間がかかる場合があります。';
  }

  @override
  String get filesContinueEdit => '続けて開く';

  @override
  String get filesFolderDownloadQuestion => 'フォルダーをダウンロードしますか？';

  @override
  String filesFolderDownloadDescription(String name) {
    return '「$name」を ZIP にしてデバイスにダウンロードします。大きなフォルダーは時間と容量を要します。';
  }

  @override
  String get filesArchiveDownload => 'ZIP でダウンロード';

  @override
  String filesDownloadedPath(String path) {
    return '$path にダウンロードしました（パスをコピー済み）';
  }

  @override
  String filesDownloadFailed(String error) {
    return 'ダウンロード失敗: $error';
  }

  @override
  String get filesSelectDownloadItem => '1 つ以上のファイルまたはフォルダーを選択してください';

  @override
  String filesDownloadSummary(int success, int failed, int skipped) {
    return '$success 件完了、$failed 件失敗、$skipped 件スキップ';
  }

  @override
  String get filesRevealOnServer => 'サーバーで表示';

  @override
  String get filesRevealOnServerDescription => 'Hermes を実行しているマシンで開く';

  @override
  String get filesDetails => '詳細';

  @override
  String get filesDownloading => 'ダウンロード中…';

  @override
  String get filesDownloadFolderZip => 'フォルダーをダウンロード（ZIP）';

  @override
  String get filesDownloadToDevice => 'デバイスにダウンロード';

  @override
  String get filesCopyToClipboard => 'クリップボードにコピー';

  @override
  String get filesCopiedPasteHint => 'コピーしました。移動先フォルダーで貼り付けてください';

  @override
  String get filesCutToClipboard => 'クリップボードに切り取り';

  @override
  String get filesCutPasteHint => '切り取りました。移動先フォルダーで貼り付けてください';

  @override
  String get filesRename => '名前を変更';

  @override
  String get filesCopyPath => 'パスをコピー';

  @override
  String get filesPathCopied => 'パスをコピーしました';

  @override
  String get filesCopyRelativePath => '相対パスをコピー';

  @override
  String get filesRelativePathCopied => '相対パスをコピーしました';

  @override
  String get filesLink => 'リンク';

  @override
  String filesInfoPath(String value) {
    return 'パス: $value';
  }

  @override
  String filesInfoType(String value) {
    return '種類: $value';
  }

  @override
  String filesInfoSize(int value) {
    return 'サイズ: $value B';
  }

  @override
  String filesInfoModified(String value) {
    return '更新日時: $value';
  }

  @override
  String filesInfoReadable(String value) {
    return '読み取り: $value';
  }

  @override
  String filesInfoWritable(String value) {
    return '書き込み: $value';
  }

  @override
  String filesMovedCount(int count) {
    return '$count 件移動しました';
  }

  @override
  String filesCopiedCount(int count) {
    return '$count 件コピーしました';
  }

  @override
  String filesPasteFailed(String error) {
    return '貼り付け失敗: $error';
  }

  @override
  String get filesConfirmDelete => '削除の確認';

  @override
  String filesDeleteSelectedDescription(int count) {
    return '選択した $count 件を削除しますか？この操作は元に戻せません。';
  }

  @override
  String filesDeleteFailed(String error) {
    return '削除失敗: $error';
  }

  @override
  String get filesNewFile => '新規ファイル';

  @override
  String get filesFileName => 'ファイル名';

  @override
  String filesCreateFileFailed(String error) {
    return 'ファイルを作成できません: $error';
  }

  @override
  String filesNewSessionPrompt(String references) {
    return '次のファイルを確認して処理してください:\n$references';
  }

  @override
  String get filesNewFolder => '新規フォルダー';

  @override
  String get filesNewName => '新しい名前';

  @override
  String filesRenameFailed(String error) {
    return '名前の変更に失敗しました: $error';
  }

  @override
  String filesDeleteFolderDescription(String name) {
    return 'フォルダー「$name」とすべての内容を削除しますか？';
  }

  @override
  String filesDeleteFileDescription(String name) {
    return 'ファイル「$name」を削除しますか？';
  }

  @override
  String get filesFolderName => 'フォルダー名';

  @override
  String filesCreateFolderFailed(String error) {
    return 'フォルダーを作成できません: $error';
  }

  @override
  String get filesSelectWorkspaceDirectory => 'ワークスペースディレクトリを選択';

  @override
  String filesSelectedCount(int count) {
    return '$count 件選択中';
  }

  @override
  String get filesSwitchToDirectoryBrowser => 'ディレクトリブラウザーに切り替え';

  @override
  String get filesSwitchToProjectTree => 'プロジェクトツリーに切り替え';

  @override
  String get filesOpenInGit => 'Git で開く';

  @override
  String get filesNewSessionForDirectory => '現在のディレクトリで新規セッション';

  @override
  String get filesSendSelectionToNewSession => '選択したファイルを新規セッションに送信';

  @override
  String get filesDownloadSelected => '選択項目をダウンロード';

  @override
  String get filesCopySelected => '選択項目をコピー';

  @override
  String get filesCutSelected => '選択項目を切り取り';

  @override
  String get filesDeleteSelected => '選択項目を削除';

  @override
  String get filesClearSelection => '選択を解除';

  @override
  String get filesMoveHere => 'ここに移動';

  @override
  String get filesCopyHere => 'ここにコピー';

  @override
  String get filesSelectCurrentDirectory => '現在のディレクトリを選択';

  @override
  String filesUseAsWorkspace(String name) {
    return '「$name」をワークスペースとして使用';
  }

  @override
  String get filesSelectPreview => 'プレビューするファイルを選択';

  @override
  String get filesSelectPreviewDescription => '左側のファイルを選択してここで編集またはプレビュー';

  @override
  String get filesFilterProjectTree => '読み込み済みのプロジェクトツリーを絞り込む…';

  @override
  String get filesSearchDirectory => '現在のディレクトリを検索…';

  @override
  String get filesLoadingDirectory => 'ディレクトリを読み込み中…';

  @override
  String get filesNoMatches => '一致するファイルはありません';

  @override
  String get filesActions => 'ファイル操作';

  @override
  String get filesUnableToRead => '読み取れません';

  @override
  String get filesDownload => 'ダウンロード';

  @override
  String get filesCut => '切り取り';

  @override
  String get configTabModel => 'モデル';

  @override
  String get configTabChat => 'チャット';

  @override
  String get configTabMemory => 'メモリ';

  @override
  String get configTabVoice => '音声';

  @override
  String get configTabToolsKeys => 'ツールとキー';

  @override
  String configLoadFailed(String error) {
    return '設定を読み込めませんでした: $error';
  }

  @override
  String get configAuxVision => '画像理解';

  @override
  String get configAuxWebExtract => 'Web 抽出';

  @override
  String get configAuxCompression => 'コンテキスト圧縮';

  @override
  String get configAuxSkillsHub => 'スキルハブ';

  @override
  String get configAuxApproval => '承認判定';

  @override
  String get configAuxMcp => 'MCP 支援';

  @override
  String get configAuxTitleGeneration => 'タイトル生成';

  @override
  String get configAuxReview => 'コードレビュー';

  @override
  String get configAuxTriage => 'タスク振り分け';

  @override
  String get configAuxKanban => 'カンバン分解';

  @override
  String get configAuxProfile => 'プロファイル説明';

  @override
  String get configAuxCurator => 'コンテンツ整理';

  @override
  String get configPersonalityDisplay => 'パーソナリティ（display.personality）';

  @override
  String get configPersonality => 'パーソナリティ';

  @override
  String get configTimezone => 'タイムゾーン（IANA）';

  @override
  String get configShowReasoning => '推論ブロックを表示';

  @override
  String get configMessageReactions => 'メッセージリアクションを有効化';

  @override
  String get configApprovalMode => '承認モード';

  @override
  String get configYoloApproval => 'YOLO 自動承認';

  @override
  String get configChatFieldsUnavailable => 'バックエンドがチャット項目を返しませんでした';

  @override
  String get configChatFieldsUnavailableDescription =>
      'GET /api/v1/config は personality、timezone、approvals、yolo を返しませんでした。';

  @override
  String get configPersistentMemory => '永続メモリ';

  @override
  String get configUserProfile => 'ユーザープロファイル';

  @override
  String get configMemoryBudget => 'メモリ上限（文字）';

  @override
  String get configProfileBudget => 'プロファイル上限（文字）';

  @override
  String get configMemoryProvider => 'メモリプロバイダー';

  @override
  String get configContextEngine => 'コンテキストエンジン';

  @override
  String get configAutoCompression => '自動圧縮';

  @override
  String get configCompressionThreshold => '圧縮しきい値';

  @override
  String get configCompressionRatio => '圧縮目標比率';

  @override
  String get configProtectRecent => '最新 N 件を保護';

  @override
  String get configMemoryFieldsUnavailable => 'バックエンドがメモリ項目を返しませんでした';

  @override
  String get configMemoryFieldsUnavailableDescription =>
      'GET /api/v1/config は memory、compression、context を返しませんでした。';

  @override
  String get configVoice => '音声';

  @override
  String get configVoiceModel => 'モデル';

  @override
  String get configVoiceId => '音声 ID';

  @override
  String get configModelId => 'モデル ID';

  @override
  String get configLanguage => '言語';

  @override
  String get configSpeechSpeed => '話速';

  @override
  String get configAutoSpeechTags => '自動音声タグ';

  @override
  String get configStreamingLatency => 'ストリーミング遅延最適化';

  @override
  String get configSampleRate => 'サンプルレート';

  @override
  String get configBitRate => 'ビットレート';

  @override
  String get configDevice => 'デバイス';

  @override
  String get configLanguageCode => '言語コード';

  @override
  String get configAudioEvents => '音声イベントをタグ付け';

  @override
  String get configDiarization => '話者分離';

  @override
  String get configSpeechToText => '音声認識';

  @override
  String get configEchoTranscripts => '文字起こしをエコー';

  @override
  String get configSttProvider => 'STT プロバイダー';

  @override
  String get configTtsProvider => 'TTS プロバイダー';

  @override
  String get configAutoReadReplies => '返信を自動読み上げ';

  @override
  String get configMaxRecordingSeconds => '最大録音秒数';

  @override
  String get configRecordShortcut => '録音ショートカット';

  @override
  String get configDirectVoiceService => '音声サービスに直接接続';

  @override
  String get configVoiceFieldsUnavailable => 'バックエンドが音声項目を返しませんでした';

  @override
  String get configVoiceFieldsUnavailableDescription =>
      'GET /api/v1/config は stt、tts、voice を返しませんでした。';

  @override
  String get configProviderApiKeys => 'モデルプロバイダー API キー';

  @override
  String get configNoProviders => '設定済みのプロバイダーはありません';

  @override
  String get configNoProvidersDescription => 'API キーを追加してモデルプロバイダーを有効にします';

  @override
  String get configEnvironmentVariables => '環境変数';

  @override
  String get configConfigured => '設定済み';

  @override
  String get configNotConfigured => '未設定';

  @override
  String configAvailableModels(int count) {
    return '利用可能なモデル: $count 件';
  }

  @override
  String configDisconnectedProvider(String name) {
    return '$name を切断しました';
  }

  @override
  String configDisconnectFailed(String error) {
    return '切断できませんでした: $error';
  }

  @override
  String get configUpdateKey => 'キーを更新';

  @override
  String get configAddKey => 'キーを追加';

  @override
  String configProviderApiKey(String name) {
    return '$name API キー';
  }

  @override
  String configProviderKeySaved(String name) {
    return '$name API キーを保存しました';
  }

  @override
  String get configSaved => '保存しました';

  @override
  String get configPressEnterToSave => 'Enter で保存';

  @override
  String get configEnterNumber => '数値を入力してください';

  @override
  String get configNewValueOptional => '新しい値（空欄なら変更しません）';

  @override
  String get configValue => '値';

  @override
  String configRevealFailed(String error) {
    return '値を表示できませんでした: $error';
  }

  @override
  String configDeleteVariableQuestion(String key) {
    return '$key を削除しますか？';
  }

  @override
  String get configDeleteVariableDescription =>
      'この環境変数はサーバーの .env から完全に削除されます。元に戻せません。';

  @override
  String get configAddEnvironmentVariable => '環境変数を追加';

  @override
  String get configVariableName => '変数名';

  @override
  String get configNoEnvironmentVariables => '環境変数はありません';

  @override
  String get configNoEnvironmentVariablesDescription =>
      'カスタム環境変数を追加してツールやプロバイダーを設定します';

  @override
  String get configHideAdvancedVariables => '詳細変数を非表示';

  @override
  String configShowAdvancedVariables(int count) {
    return '詳細変数を表示（$count）';
  }

  @override
  String get configSet => '設定済み';

  @override
  String get configNotSet => '未設定';

  @override
  String get configVoiceIdManual => 'Enter で保存（アカウントの音声一覧を取得できない場合は手動入力）';

  @override
  String configVoicesLoadFailed(String error) {
    return 'アカウントの音声を読み込めませんでした: $error。ID を手動入力し、Enter で保存できます。';
  }

  @override
  String chatDraftHandoffSaveFailed(String error) {
    return '下書きはこの画面に保持されていますが、サーバーに保存できませんでした：$error';
  }

  @override
  String get toolPlanTitle => 'プラン';

  @override
  String get toolPlanCopy => 'プランをコピー';

  @override
  String get toolPlanCopied => 'プランをコピーしました';

  @override
  String get toolValueNotProvided => '未指定';

  @override
  String get toolCommand => 'コマンド';

  @override
  String get toolWaitingCommand => 'コマンドを待機中';

  @override
  String get toolOutput => '出力';

  @override
  String get toolErrorOutput => 'エラー出力';

  @override
  String toolExitCode(int code) {
    return '終了コード：$code';
  }

  @override
  String get toolCode => 'コード';

  @override
  String toolCodeLanguage(String language) {
    return 'コード · $language';
  }

  @override
  String get toolWaitingCode => 'コードを待機中';

  @override
  String get toolExecutionResult => '実行結果';

  @override
  String toolChangedFiles(int count) {
    return '変更ファイル · $count';
  }

  @override
  String get toolPatchContent => 'パッチ内容';

  @override
  String get toolWaitingPatch => 'パッチを待機中';

  @override
  String get toolResult => '結果';

  @override
  String get toolSearchQuery => '検索語';

  @override
  String get toolSearchingWeb => 'ウェブを検索中';

  @override
  String toolSearchResults(int count) {
    return '検索結果 · $count';
  }

  @override
  String get toolNoResults => '結果なし';

  @override
  String get toolLink => 'リンク';

  @override
  String get toolContent => '内容';

  @override
  String get toolFile => 'ファイル';

  @override
  String get toolReadingFile => 'ファイルを読み取り中';

  @override
  String get toolWritingFile => 'ファイルに書き込み中';

  @override
  String get toolWriteContent => '書き込む内容';

  @override
  String toolFileList(int count) {
    return 'ファイル一覧 · $count';
  }

  @override
  String get toolNoFiles => 'ファイルなし';

  @override
  String get toolDetails => '詳細';

  @override
  String get toolNoReadableContent => '（表示可能な内容なし）';

  @override
  String get toolWaitingForResult => 'ツールの結果を待機中';

  @override
  String get toolUntitledResult => '無題の結果';

  @override
  String get toolCopyAll => 'すべてコピー';

  @override
  String toolHiddenRestore(String name) {
    return '$name は非表示です。タップして復元';
  }

  @override
  String get toolReadableView => '読みやすい表示';

  @override
  String get toolRawJsonView => '生 JSON 表示';

  @override
  String get toolHideRow => 'このツール行を非表示';

  @override
  String get toolCopyResult => '結果をコピー';

  @override
  String toolRawDetailsTitle(String name) {
    return '$name の生データ';
  }

  @override
  String get toolViewRawDetails => '生データを表示';

  @override
  String get toolArguments => '引数';

  @override
  String get toolNoDetailedData => '（詳細データなし）';

  @override
  String toolArgumentDetailsTitle(String key) {
    return '$key の引数';
  }

  @override
  String toolTapForFullContent(int count) {
    return '[タップして全 $count 文字を表示]';
  }

  @override
  String toolContentTooLong(int count) {
    return '内容が長いため省略（全 $count 文字）';
  }

  @override
  String toolFullResultTitle(String name) {
    return '$name の完全な結果';
  }

  @override
  String get toolViewFull => 'すべて表示';

  @override
  String kanbanDeleteAttachment(String name) {
    return '$name を削除しますか？';
  }

  @override
  String get kanbanCannotUndo => 'この操作は元に戻せません。';

  @override
  String kanbanOperationFailed(String error) {
    return '操作に失敗しました：$error';
  }

  @override
  String get kanbanNoLog => 'ログはありません';

  @override
  String get kanbanAddChildTask => '子タスクを追加';

  @override
  String get kanbanTaskId => 'タスク ID';

  @override
  String get kanbanDescription => '説明';

  @override
  String get kanbanCommandCopied => 'コマンドをコピーしました';

  @override
  String get kanbanViewLog => 'ログを表示';

  @override
  String get kanbanEstimate => '見積もり';

  @override
  String get kanbanDecompose => '分解';

  @override
  String get kanbanNoDescription => '説明なし';

  @override
  String get kanbanDiagnostics => '診断';

  @override
  String kanbanComments(int count) {
    return 'コメント（$count）';
  }

  @override
  String get kanbanAddComment => 'コメントを追加';

  @override
  String kanbanDependencies(int parents, int children) {
    return '依存関係：親タスク $parents 件、子タスク $children 件';
  }

  @override
  String kanbanChildTask(String id) {
    return '子タスク $id';
  }

  @override
  String kanbanAttachments(int count) {
    return '添付ファイル（$count）';
  }

  @override
  String kanbanEventTimeline(int count) {
    return 'イベント履歴（$count）';
  }

  @override
  String kanbanRuns(int count) {
    return '実行（$count）';
  }

  @override
  String get kanbanUploadAttachment => '添付ファイルをアップロード';

  @override
  String kanbanAttachmentBytes(int count) {
    return '$count バイト';
  }

  @override
  String messageReactionFailed(String error) {
    return 'リアクションを更新できませんでした：$error';
  }

  @override
  String get messageRenderFailed => 'このメッセージを表示できません';

  @override
  String get messageRenderFailedDescription => '他のメッセージには影響しません';

  @override
  String get messageRemoveMyReaction => '自分のリアクションを削除';

  @override
  String get messageAgentReaction => 'エージェントのリアクション';

  @override
  String get messageAddReaction => 'リアクションを追加';

  @override
  String get messageSearchEmoji => '絵文字を検索';

  @override
  String messageImageSaveFailed(String error) {
    return '画像を保存できませんでした：$error';
  }

  @override
  String get messageGeneratingImage => '画像を生成中…';

  @override
  String get messageImageGenerationFailed => '画像生成に失敗しました';

  @override
  String get messageWaitingForImage => '画像の結果を待機中';

  @override
  String get messageGeneratedImage => '生成画像';

  @override
  String get messageImageLinkCopied => '画像リンクをコピーしました';

  @override
  String get messageOpenInBrowser => 'ブラウザーで開く';

  @override
  String get messageMcpSetup => 'MCP サーバー設定';

  @override
  String messageMcpServer(String server) {
    return 'MCP · $server';
  }

  @override
  String get messageMcpSetupFailed => '設定に失敗しました。MCP 設定から再試行できます';

  @override
  String get messageMcpSetupWaiting => '設定完了を待機中';

  @override
  String get messageMcpSetupComplete => '設定完了';

  @override
  String get messageOpenMcpSettings => 'MCP 設定を開く';

  @override
  String get messageFileChanges => 'ファイル変更';

  @override
  String get messageViewDiff => '差分を表示';

  @override
  String get messageOpenLink => 'リンクを開く';

  @override
  String messageSendingToAgent(String name) {
    return '$name に送信中…';
  }

  @override
  String messageSentToAgent(String name) {
    return '$name に送信済み';
  }

  @override
  String messageReplyFromAgent(String name) {
    return '$name からの返信';
  }

  @override
  String messageRepliedToAgent(String name) {
    return '$name に返信済み';
  }

  @override
  String messageFromAgent(String name) {
    return 'エージェントから · $name';
  }

  @override
  String get messageSteered => '方向を修正済み';

  @override
  String get messageHermesAvatar => 'Hermes アシスタントのアバター';

  @override
  String get messageSourceWechat => 'WeChat';

  @override
  String get messageSourceFeishu => 'Feishu';

  @override
  String get messageSourceDesktop => 'デスクトップ';

  @override
  String get messageRestoreVersion => 'このバージョンを復元';

  @override
  String get messagePreviousVersion => '前のバージョン';

  @override
  String get messageNextVersion => '次のバージョン';

  @override
  String get messageCopyText => 'テキストをコピー';

  @override
  String get messageCopyMarkdown => 'Markdown としてコピー';

  @override
  String get messageBranchFromHere => 'このメッセージから分岐';

  @override
  String get messageSpeakDisconnected => '読み上げるにはサーバーに接続してください';

  @override
  String get messageSpeakFailed => '音声を再生できませんでした。再試行してください';

  @override
  String get messageStopSpeaking => '読み上げを停止';

  @override
  String get messageSpeak => '読み上げ';

  @override
  String get sessionDetailMessages => 'メッセージ';

  @override
  String get sessionDetailTools => 'ツール';

  @override
  String get sessionDetailEstimated => '見積もり';

  @override
  String get sessionDetailCost => '費用';

  @override
  String get sessionDetailDuration => '所要時間';

  @override
  String get sessionDetailInfo => 'セッション情報';

  @override
  String get sessionDetailSource => 'ソース';

  @override
  String get sessionDetailModel => 'モデル';

  @override
  String get sessionDetailStarted => '開始';

  @override
  String get sessionDetailLastActivity => '最終アクティビティ';

  @override
  String get sessionDetailEnded => '終了';

  @override
  String get sessionDetailEndReason => '終了理由';

  @override
  String get sessionDetailHandoff => '引き継ぎ';

  @override
  String get sessionDetailHandoffError => '引き継ぎエラー';

  @override
  String get sessionDetailTokensBilling => 'トークンと請求';

  @override
  String get sessionDetailInputOutput => '入力 / 出力';

  @override
  String get sessionDetailCacheReadWrite => 'キャッシュ読み取り / 書き込み';

  @override
  String get sessionDetailReasoningTokens => '推論トークン';

  @override
  String get sessionDetailBillingSource => '請求元';

  @override
  String get sessionDetailContextSource => 'コンテキストとソース';

  @override
  String get sessionDetailWorkingDirectory => '作業ディレクトリ';

  @override
  String get sessionDetailGitBranch => 'Git ブランチ';

  @override
  String get sessionDetailContact => '連絡先';

  @override
  String get sessionDetailChatType => 'チャット形式';

  @override
  String get sessionDetailUserId => 'ユーザー ID';

  @override
  String get sessionDetailParentSession => '親セッション';

  @override
  String get sessionDetailRewindCount => '巻き戻し回数';

  @override
  String get sessionDetailCompressionFailed => '圧縮に一時的に失敗';

  @override
  String get sessionDetailOpen => 'セッションを開く';

  @override
  String get sessionActionOpenWorkspace => 'ワークスペースで開く';

  @override
  String get sessionActionUnpin => 'ピン留めを解除';

  @override
  String get sessionActionPin => 'ピン留め';

  @override
  String get sessionActionAppearance => '外観';

  @override
  String get sessionActionDuplicate => 'セッションを複製';

  @override
  String get sessionActionShare => 'セッションを共有';

  @override
  String get sessionActionExport => 'セッションをエクスポート';

  @override
  String get sessionActionMoveProject => 'プロジェクトへ移動';

  @override
  String get sessionActionUnarchive => 'アーカイブを解除';

  @override
  String get sessionActionArchive => 'アーカイブ';

  @override
  String get sessionActionStopResponse => '応答を停止';

  @override
  String get sessionActionAppearanceTitle => 'セッションの外観';

  @override
  String sessionActionRenameFailed(String error) {
    return '名前を変更できませんでした：$error';
  }

  @override
  String get sessionActionUnarchived => 'アーカイブを解除しました';

  @override
  String get sessionActionArchived => 'アーカイブしました';

  @override
  String sessionActionFailed(String error) {
    return '操作に失敗しました：$error';
  }

  @override
  String get sessionActionUnpinned => 'ピン留めを解除しました';

  @override
  String get sessionActionPinned => 'ピン留めしました';

  @override
  String get sessionActionMoved => 'セッションを移動しました';

  @override
  String sessionActionMoveFailed(String error) {
    return '移動できませんでした：$error';
  }

  @override
  String sessionActionBranchCreated(String id) {
    return 'ブランチを作成しました：$id';
  }

  @override
  String get sessionActionCopyCreated => 'セッションのコピーを作成しました';

  @override
  String sessionActionDuplicateFailed(String error) {
    return 'セッションを複製できませんでした：$error';
  }

  @override
  String get sessionActionShareCreated => '共有リンクを作成しました';

  @override
  String get sessionActionShareWarning => 'リンクを知っている人はセッションを閲覧できます。';

  @override
  String sessionActionShareFailed(String error) {
    return '共有できませんでした：$error';
  }

  @override
  String get sessionActionStopRequested => '停止をリクエストしました';

  @override
  String get sessionActionExportMarkdownHint => '閲覧と共有に適しています';

  @override
  String get sessionActionExportJsonHint => '完全な構造化データを保持します';

  @override
  String get sessionActionExportCopiedWeb =>
      'Web ではローカル保存できないため、エクスポートをクリップボードにコピーしました';

  @override
  String sessionActionExported(String path) {
    return '$path にエクスポートしました（パスをコピー済み）';
  }

  @override
  String sessionActionExportFailed(String error) {
    return 'エクスポートできませんでした：$error';
  }

  @override
  String get sessionsNoDetail => 'セッションの詳細がありません';

  @override
  String get sessionsNoDetailDescription => 'フィルターを調整してセッション概要を表示します';

  @override
  String get sessionsAllProjects => 'すべてのプロジェクト';

  @override
  String get sessionsProject => 'プロジェクト';

  @override
  String get sessionsSearchHint => 'タイトル、プレビュー、作業ディレクトリを検索…';

  @override
  String get sessionsToday => '今日';

  @override
  String get sessionsThisWeek => '今週';

  @override
  String get sessionsStarred => 'スター付き';

  @override
  String get sessionsSortNewest => '時間：新しい順';

  @override
  String get sessionsSortOldest => '時間：古い順';

  @override
  String get sessionsSortTitle => 'タイトル：A-Z';

  @override
  String get sessionsSortMessages => 'メッセージ数：多い順';

  @override
  String get sessionsSortMethod => '並べ替え方法';

  @override
  String get sessionsLoading => 'セッションを読み込み中…';

  @override
  String get sessionsViewFullDetails => '完全な詳細を表示';

  @override
  String get sessionsSettings => '設定';

  @override
  String get requestHermesQuestion => 'Hermes からの質問';

  @override
  String get requestPending => '保留中のリクエスト';

  @override
  String get requestAlwaysAllowQuestion => '常に許可しますか？';

  @override
  String get requestAlwaysAllowDescription =>
      'この操作を永続的な許可ルールとして設定に追加します。以後、同様の操作では確認されません。';

  @override
  String requestAlwaysAllowDetail(String detail) {
    return '「$detail」を永続的な許可ルールとして設定に追加します。以後、同様の操作では確認されません。';
  }

  @override
  String get requestNoActiveSession => 'アクティブなセッションがありません';

  @override
  String get requestConnectionUnavailable => 'リクエストの接続を利用できません';

  @override
  String requestRespondFailed(String error) {
    return '応答できませんでした：$error';
  }

  @override
  String get requestAnswerFailed => '回答を送信できませんでした。再試行してください';

  @override
  String get requestMcpNameMissing => 'MCP サーバー名がリクエストにありません';

  @override
  String get requestOAuthTimeout => 'OAuth 認証がタイムアウトしました';

  @override
  String get requestMcpTestFailed => 'MCP 接続テストに失敗しました';

  @override
  String get requestMcpSetupFailed => 'MCP 設定に失敗しました';

  @override
  String requestConfigureMcp(String name) {
    return '$name を設定';
  }

  @override
  String get requestCloseQuestion => 'リクエストを閉じますか？';

  @override
  String get requestCloseDescription => '閉じたリクエストは復元できず、エージェントは待機したままになります。';

  @override
  String get requestProcessed => '処理済み';

  @override
  String get requestInteractionProcessed => '対話リクエストを処理しました';

  @override
  String requestServer(String name) {
    return 'サーバー：$name';
  }

  @override
  String get requestSubmitAllAnswers => 'すべての回答を送信';

  @override
  String get requestConfigureLater => '今は設定しない';

  @override
  String get requestConfiguring => '設定中…';

  @override
  String get requestInstallEnable => 'インストールして有効化';

  @override
  String get requestEnterContent => '内容を入力';

  @override
  String get requestEnterText => '入力…';

  @override
  String requestMorePending(int count) {
    return 'ほか $count 件が保留中';
  }

  @override
  String get requestAllowOnce => '一度だけ許可';

  @override
  String get requestAllowSession => 'このセッションで許可';

  @override
  String requestSubmitSelected(int count) {
    return '送信（$count 件選択）';
  }

  @override
  String get requestCustomAnswer => 'その他（自由回答）';

  @override
  String get requestRecommended => '推奨';

  @override
  String messagingLoadFailed(String error) {
    return 'メッセージプラットフォームを読み込めませんでした：$error';
  }

  @override
  String messagingPlatformEnabled(String name) {
    return '$name を有効にしました';
  }

  @override
  String messagingPlatformDisabled(String name) {
    return '$name を無効にしました';
  }

  @override
  String messagingUpdateFailed(String error) {
    return '更新できませんでした：$error';
  }

  @override
  String messagingTestPassed(String name) {
    return '$name の接続テストに成功しました';
  }

  @override
  String get messagingTestNotPassed => '接続テストに合格しませんでした';

  @override
  String messagingTestFailed(String error) {
    return 'テストに失敗しました：$error';
  }

  @override
  String messagingConfigSaved(String name) {
    return '$name の設定を保存しました。Gateway を再起動して接続変更を適用してください';
  }

  @override
  String messagingSaveFailed(String error) {
    return '保存できませんでした：$error';
  }

  @override
  String messagingApproved(String name) {
    return '$name を承認しました';
  }

  @override
  String messagingApproveFailed(String error) {
    return '承認できませんでした：$error';
  }

  @override
  String get messagingRevokeTitle => 'アクセスを取り消す';

  @override
  String messagingRevokeQuestion(String name) {
    return '$name のメッセージアクセスを取り消しますか？';
  }

  @override
  String get messagingRevoke => '取り消す';

  @override
  String get messagingRevoked => 'アクセスを取り消しました';

  @override
  String messagingRevokeFailed(String error) {
    return 'アクセスを取り消せませんでした：$error';
  }

  @override
  String get messagingRestartQuestion => 'Gateway を再起動しますか？';

  @override
  String get messagingRestartWarning =>
      'この Gateway に接続しているすべてのセッションとクライアントが中断されます。完了後、自動的に再接続します。';

  @override
  String get messagingRestarting => 'Gateway を再起動中';

  @override
  String messagingRestartFailed(String error) {
    return 'Gateway の再起動に失敗しました：$error';
  }

  @override
  String get messagingTitle => 'メッセージプラットフォーム';

  @override
  String get messagingRestartGateway => 'Gateway を再起動';

  @override
  String get messagingLoading => 'メッセージプラットフォームを読み込み中…';

  @override
  String get messagingPendingApproval => '承認待ち';

  @override
  String get messagingPlatforms => 'プラットフォーム';

  @override
  String get messagingEmpty => 'メッセージプラットフォームなし';

  @override
  String get messagingEmptyDescription => '設定可能なメッセージプラットフォームがサーバーから返されませんでした';

  @override
  String get messagingAuthorizedUsers => '承認済みユーザー';

  @override
  String get messagingConfigure => '設定';

  @override
  String get messagingTest => 'テスト';

  @override
  String get messagingOpenDocs => 'ドキュメントを開く';

  @override
  String get messagingUnknownUser => '不明なユーザー';

  @override
  String get messagingApprove => '承認';

  @override
  String get messagingStateDisabled => '無効';

  @override
  String get messagingStateGatewayStopped => '設定済み、Gateway は停止中';

  @override
  String get messagingStateFatal => '重大なエラー';

  @override
  String get messagingStateStartupFailed => '起動失敗';

  @override
  String get messagingStateConfigured => '設定済み';

  @override
  String get messagingStateNeedsConfig => '設定が必要';

  @override
  String messagingPlatformConfig(String name) {
    return '$name の設定';
  }

  @override
  String get messagingNoEditableConfig => 'このプラットフォームに編集可能な設定はありません。';

  @override
  String get messagingAdvancedSettings => '詳細設定';

  @override
  String get messagingSetLeaveBlank => '設定済み。空欄なら変更しません';

  @override
  String get messagingEnterNewValue => '新しい値を入力';

  @override
  String get messagingShow => '表示';

  @override
  String get messagingClearSavedValue => '保存済みの値を消去';

  @override
  String get fileTreeListView => 'リスト表示';

  @override
  String get fileTreeTreeView => 'ツリー表示';

  @override
  String get fileTreeAttachToChat => 'チャットに添付';

  @override
  String get projectAddFolder => 'フォルダーを追加';

  @override
  String get projectFolderPath => 'フォルダーのパス';

  @override
  String get projectFolderLabelOptional => 'ラベル（任意）';

  @override
  String get projectCreate => 'プロジェクトを作成';

  @override
  String get projectLoading => 'プロジェクトを読み込み中…';

  @override
  String get projectEmpty => 'プロジェクトはまだありません';

  @override
  String get projectEmptyDescription => 'プロジェクトを作成して作業ディレクトリとセッションを整理します';

  @override
  String get projectWorkspace => 'プロジェクトワークスペース';

  @override
  String get projectEditAppearance => '外観を編集';

  @override
  String get projectColor => '色';

  @override
  String get projectIcon => 'アイコン';

  @override
  String projectAppearanceSaveFailed(String error) {
    return '外観を保存できませんでした：$error';
  }

  @override
  String get projectRename => '名前を変更';

  @override
  String get projectRenameTitle => 'プロジェクト名を変更';

  @override
  String get projectName => 'プロジェクト名';

  @override
  String projectRenameFailed(String error) {
    return 'プロジェクト名を変更できませんでした：$error';
  }

  @override
  String projectDeleteQuestion(String name) {
    return '$name を削除しますか？';
  }

  @override
  String get projectDeleteDescription =>
      'プロジェクトは削除されますが、セッションとファイルには影響しません。この操作は元に戻せません。';

  @override
  String projectDeleteFailed(String error) {
    return 'プロジェクトを削除できませんでした：$error';
  }

  @override
  String projectCreateFailed(String error) {
    return 'プロジェクトを作成できませんでした：$error';
  }

  @override
  String get projectManagement => 'プロジェクト管理';

  @override
  String get projectLoadFailed => 'プロジェクトを読み込めませんでした';

  @override
  String get projectNoMoveTargets => '移動先にできる他のプロジェクトがありません';

  @override
  String get projectNoMoveTargetsDescription =>
      'セッションを受け入れるには、有効な作業ディレクトリを設定する必要があります';

  @override
  String get projectNew => '新規プロジェクト';

  @override
  String get projectEditTitle => 'プロジェクトを編集';

  @override
  String get projectPrimaryPath => 'メイン作業ディレクトリ';

  @override
  String get projectPrimaryPathHint => '例：/home/user/projects/my-app';

  @override
  String get projectDescriptionOptional => '説明（任意）';

  @override
  String get projectRequiredFields => 'プロジェクト名と作業ディレクトリを入力してください';

  @override
  String get projectCreated => 'プロジェクトを作成しました';

  @override
  String get projectUpdated => 'プロジェクトを更新しました';

  @override
  String projectSaveFailed(String error) {
    return 'プロジェクトを保存できませんでした：$error';
  }

  @override
  String get projectDeleteTitle => 'プロジェクトを削除しますか？';

  @override
  String projectDeleteNamedDescription(String name) {
    return 'プロジェクト「$name」を削除します。関連するセッションは削除されません。';
  }

  @override
  String get projectDeleted => 'プロジェクトを削除しました';

  @override
  String subagentsLoadFailed(String error) {
    return 'サブエージェントを読み込めませんでした：$error';
  }

  @override
  String get subagentsEmpty => 'サブエージェントのアクティビティはありません';

  @override
  String get subagentsOpenSessionDescription => 'セッションを開いてサブエージェントツリーを表示します';

  @override
  String get subagentsCurrentSessionEmpty => '現在のセッションに実行中のサブエージェントはいません';

  @override
  String get subagentsCurrentSession => '現在のセッション';

  @override
  String subagentsSession(String id) {
    return 'セッション $id';
  }

  @override
  String subagentsCount(int count) {
    return 'サブエージェント $count 件';
  }

  @override
  String subagentsRunningCount(int count) {
    return '実行中 $count';
  }

  @override
  String subagentsFailedCount(int count) {
    return '失敗 $count';
  }

  @override
  String subagentsToolCalls(int count) {
    return 'ツール呼び出し $count 回';
  }

  @override
  String subagentsFiles(int count) {
    return 'ファイル $count 件';
  }

  @override
  String get subagentsInterrupt => '中断';

  @override
  String get subagentsInterruptSent => '中断シグナルを送信しました';

  @override
  String subagentsInterruptFailed(String error) {
    return 'サブエージェントを中断できませんでした：$error';
  }

  @override
  String get subagentsOpenSession => 'セッションを開く';

  @override
  String subagentsOpenSessionFailed(String error) {
    return 'サブエージェントセッションを開けませんでした：$error';
  }

  @override
  String subagentsCurrentTool(String name) {
    return 'ツール：$name';
  }

  @override
  String subagentsTools(int count) {
    return 'ツール $count 回';
  }

  @override
  String subagentsFilesRead(int count) {
    return '読み取り $count';
  }

  @override
  String subagentsFilesWritten(int count) {
    return '書き込み $count';
  }

  @override
  String get subagentsStatusQueued => '待機中';

  @override
  String get subagentsStatusInterrupted => '中断済み';

  @override
  String get subagentsStatusUnknown => '不明';

  @override
  String credentialsLoadFailed(String error) {
    return '認証情報を読み込めませんでした：$error';
  }

  @override
  String get credentialsSearchHint => '認証情報またはプロバイダーを検索…';

  @override
  String get credentialsMissing => '未設定';

  @override
  String get credentialsNoMatches => '一致する認証情報がありません';

  @override
  String get credentialsNoMatchesDescription => '検索またはステータスフィルターを調整してください';

  @override
  String get credentialsEmpty => '認証情報プロバイダーがありません';

  @override
  String get credentialsEmptyDescription => '設定可能な認証情報プロバイダーがサーバーから返されませんでした';

  @override
  String get credentialsGroupCloud => 'クラウドプロバイダー';

  @override
  String get credentialsGroupModelProviders => 'モデルプロバイダー';

  @override
  String get credentialsGroupThirdParty => 'サードパーティサービス';

  @override
  String get credentialsKeyRequired =>
      'プロバイダーを選択して API Key または Token を入力してください';

  @override
  String credentialsSaveFailed(String error) {
    return '認証情報を保存できませんでした：$error';
  }

  @override
  String get credentialsAddTitle => '認証情報を追加';

  @override
  String get credentialsEditTitle => '認証情報を編集';

  @override
  String get credentialsSaving => '保存中…';

  @override
  String credentialsApiKey(String name) {
    return '$name API Key / Token';
  }

  @override
  String get credentialsShowKey => 'キーを表示';

  @override
  String get credentialsHideKey => 'キーを隠す';

  @override
  String get petCenterTitle => 'ペットセンター';

  @override
  String get petRename => '名前を変更';

  @override
  String get petDisable => 'ペットを無効化';

  @override
  String petRenameFailed(String error) {
    return 'ペット名を変更できませんでした：$error';
  }

  @override
  String petDisableFailed(String error) {
    return 'ペットを無効化できませんでした：$error';
  }

  @override
  String get petRenameTitle => 'ペット名を変更';

  @override
  String get petRenameHint => '新しい名前を入力…';

  @override
  String get petUntitled => '名前なし';

  @override
  String petStatus(String status) {
    return '状態：$status';
  }

  @override
  String get petGallery => 'ギャラリー';

  @override
  String get petGalleryEmpty => '利用できるペットがありません';

  @override
  String get petGenerateNew => '新しいペットを生成';

  @override
  String get petStateWave => '手を振る';

  @override
  String get petStateJump => 'ジャンプ';

  @override
  String get petStateCelebrate => 'お祝い';

  @override
  String credentialsDisconnectQuestion(String name) {
    return '$name を切断しますか？';
  }

  @override
  String get credentialsDisconnectDescription =>
      '保存済みの認証情報を Hermes サーバーから削除します。後で再度追加できます。';

  @override
  String starmapLoadDetailFailed(String error) {
    return 'ノード詳細を読み込めませんでした：$error';
  }

  @override
  String get starmapRestoreMine => '自分のスターマップに戻す';

  @override
  String get starmapShareImport => '共有またはインポート';

  @override
  String get starmapResetView => '表示をリセット';

  @override
  String get starmapLoading => 'スターマップを読み込み中…';

  @override
  String get starmapNoData => 'データがありません';

  @override
  String get starmapEmpty => 'スターマップは空です';

  @override
  String get starmapEmptyDescription => 'Hermes が学習すると、ここに知識ノードが表示されます。';

  @override
  String get starmapShareTitle => 'スターマップを共有';

  @override
  String get starmapShareDescription => 'このコードをコピーして共有するか、別のコードを貼り付けて読み込みます。';

  @override
  String get starmapShareCodeHint => 'スターマップ共有コード';

  @override
  String get starmapCopy => 'コピー';

  @override
  String get starmapLoad => '読み込む';

  @override
  String get starmapInvalidShareCode => 'スターマップ共有コードが無効です。';

  @override
  String get starmapPause => '一時停止';

  @override
  String get starmapPlay => '再生';

  @override
  String get starmapSkillLegend => 'スキル';

  @override
  String get starmapMemoryLegend => 'メモリ';

  @override
  String get starmapChronologyLegend => '中心：最古 · 外側：最新';

  @override
  String starmapOpenNode(String name) {
    return '$name を開く';
  }

  @override
  String get starmapSaved => '保存しました';

  @override
  String starmapSaveFailed(String error) {
    return 'ノードを保存できませんでした：$error';
  }

  @override
  String get starmapDeleteQuestion => 'ノードを削除しますか？';

  @override
  String starmapDeleteDescription(String name) {
    return '$name をスターマップから削除します。';
  }

  @override
  String get starmapDeleted => 'ノードを削除しました';

  @override
  String starmapDeleteFailed(String error) {
    return 'ノードを削除できませんでした：$error';
  }

  @override
  String starmapUseCount(int count) {
    return '$count 回使用';
  }

  @override
  String get starmapContent => '内容';

  @override
  String get starmapSaving => '保存中…';

  @override
  String starmapCreatedBy(Object value) {
    return '作成者：$value';
  }

  @override
  String starmapSource(Object value) {
    return 'ソース：$value';
  }

  @override
  String get starmapStateArchived => 'アーカイブ済み';

  @override
  String configCenterLoadFailed(String error) {
    return '機能データを読み込めませんでした：$error';
  }

  @override
  String get configCenterKnowledgeTab => '知識';

  @override
  String get configCenterTitle => '機能管理';

  @override
  String get configCenterLoadErrorTitle => '機能を読み込めませんでした';

  @override
  String get configCenterMcpEmptyDescription => 'MCP サーバーを追加して外部ツールやデータに接続します。';

  @override
  String get configCenterUrlOrCommand => 'URL またはコマンド';

  @override
  String get configCenterTransport => 'トランスポート';

  @override
  String get configCenterLocalStdio => 'Stdio（ローカルプロセス）';

  @override
  String configCenterMutationFailed(String error) {
    return '変更を適用できませんでした：$error';
  }

  @override
  String get configCenterKnowledgeTitle => '知識ソース';

  @override
  String get configCenterKnowledgeEmpty => '知識ソースがありません';

  @override
  String get configCenterKnowledgeEmptyDescription =>
      'ファイル、フォルダー、URL を知識ソースとして追加します。';

  @override
  String get configCenterDatabase => 'データベース';

  @override
  String configCenterKnowledgeMeta(String type, int count, String status) {
    return '$type · $count チャンク · $status';
  }

  @override
  String get configCenterIndexed => 'インデックス済み';

  @override
  String get configCenterNotIndexed => '未インデックス';

  @override
  String get configCenterSkillsEmpty => 'スキルがありません';

  @override
  String get configCenterSkillsEmptyDescription => 'このプロファイルのスキルが返されませんでした。';

  @override
  String get configCenterConfiguration => '設定';

  @override
  String get configCenterInstallPlugin => 'プラグインをインストール';

  @override
  String get configCenterPluginsEmpty => 'プラグインがありません';

  @override
  String get configCenterPluginsEmptyDescription => 'プラグインを追加して Hermes を拡張します。';

  @override
  String get configCenterInstall => 'インストール';

  @override
  String get configCenterPluginUrl => 'プラグイン URL または識別子';

  @override
  String get fileEditorDiscardQuestion => '未保存の変更を破棄しますか？';

  @override
  String get fileEditorDiscardDescription => '戻ると現在の編集内容は失われます。';

  @override
  String get fileEditorKeepEditing => '編集を続ける';

  @override
  String get fileEditorDiscard => '破棄';

  @override
  String get fileEditorDisk => 'ディスク';

  @override
  String get fileEditorEditor => 'エディター';

  @override
  String get fileEditorConflictDescription =>
      'ディスク上のファイルが変更されました。上書き保存、再読み込み、またはキャンセルできます。';

  @override
  String get fileEditorConflictTitle => 'ファイルが外部で変更されました';

  @override
  String get fileEditorOverwriteSave => '上書き保存';

  @override
  String get fileEditorReloaded => 'ディスク版を再読み込みしました';

  @override
  String get fileEditorSaved => '保存しました';

  @override
  String fileEditorSaveFailed(String error) {
    return 'ファイルを保存できませんでした：$error';
  }

  @override
  String get fileEditorSaving => '保存中…';

  @override
  String fileEditorUnsavedTitle(String name) {
    return '$name、未保存の変更あり';
  }

  @override
  String get fileEditorEmpty => '（空）';

  @override
  String get fileEditorBinaryTitle => 'このファイルはテキストとして編集できません';

  @override
  String get fileEditorBinaryDescription =>
      'これはバイナリファイル（画像、アーカイブ、実行ファイルなど）のようです。テキストエディターで開いて保存すると破損する可能性があるため、編集は無効になっています。代わりにデバイスにダウンロードしてください。';

  @override
  String kanbanTaskCreatedLinkFailed(String error) {
    return 'タスクは作成されましたが、親タスクリンクを追加できませんでした：$error';
  }

  @override
  String get kanbanTaskStatus => 'ステータス';

  @override
  String get kanbanPriority => '優先度';

  @override
  String get kanbanAssignee => '担当者';

  @override
  String get kanbanTenant => 'テナント';

  @override
  String get kanbanParentTaskId => '親タスク ID';

  @override
  String get kanbanWorkspacePath => 'ワークスペースパス';

  @override
  String get kanbanModelOverride => 'モデルを指定';

  @override
  String get kanbanProviderOverride => 'プロバイダーを指定';

  @override
  String get kanbanEffort => '推論強度';

  @override
  String get kanbanEffortLow => '低';

  @override
  String get kanbanEffortMedium => '中';

  @override
  String get kanbanEffortHigh => '高';

  @override
  String get kanbanCreatingTask => 'タスクを作成中…';

  @override
  String get kanbanCreateTask => 'タスクを作成';

  @override
  String get kanbanCreateBoard => 'ボードを作成';

  @override
  String get kanbanBoardSettings => 'ボード設定';

  @override
  String get kanbanProject => 'プロジェクト';

  @override
  String get kanbanNoProject => 'プロジェクトに紐付けない';

  @override
  String get kanbanDeleteBoardQuestion => 'ボードを削除しますか？';

  @override
  String kanbanDeleteBoardDescription(String name) {
    return '$name を削除します。この操作は元に戻せません。';
  }

  @override
  String kanbanBoardTaskCount(int count) {
    return '$count 件のタスク';
  }

  @override
  String kanbanBoardTaskCountProject(int count, String project) {
    return '$count 件のタスク · $project';
  }

  @override
  String get kanbanRenameBoard => 'ボード名を変更';

  @override
  String pluginsOperationFailed(String error) {
    return 'プラグインを更新できませんでした：$error';
  }

  @override
  String get pluginsInstallTitle => 'Agent プラグインをインストール';

  @override
  String get pluginsIdentifierHint => 'Git URL または owner/repo';

  @override
  String get pluginsEnableAfterInstall => 'インストール後に有効化';

  @override
  String get pluginsForceReinstall => '強制再インストール';

  @override
  String pluginsInstalled(String name) {
    return '$name をインストールしました';
  }

  @override
  String pluginsInstallFailed(String error) {
    return 'プラグインをインストールできませんでした：$error';
  }

  @override
  String get pluginsLoading => 'プラグインを読み込み中…';

  @override
  String get pluginsNoData => 'プラグインデータがありません';

  @override
  String pluginsSearchHint(int count) {
    return '$count 件のプラグインを検索…';
  }

  @override
  String get pluginsNoMatches => '一致するプラグインがありません';

  @override
  String get pluginsKindPlatform => 'プラットフォーム';

  @override
  String get pluginsKindProvider => 'プロバイダー';

  @override
  String get pluginsKindTool => 'ツール';

  @override
  String pluginsContributionTooltip(String area, String description) {
    return '$area · $description';
  }

  @override
  String pluginsActionExecuted(String title) {
    return '$title を実行しました';
  }

  @override
  String get pluginsAreaNavigation => 'ナビゲーション';

  @override
  String get pluginsAreaCommand => 'コマンド';

  @override
  String get pluginsAreaSettings => '設定';

  @override
  String get pluginsAreaComposer => '入力欄';

  @override
  String get pluginsAreaDetail => '詳細';

  @override
  String get pluginsAreaTranscript => '対話履歴';

  @override
  String get pluginsAreaPane => 'ペイン';

  @override
  String knowledgeLoadDetailFailed(String error) {
    return 'ノード詳細を読み込めませんでした：$error';
  }

  @override
  String get knowledgeLoading => '知識グラフを読み込み中…';

  @override
  String get knowledgeNoData => '知識データがありません';

  @override
  String get knowledgeSearchHint => '知識ノードを検索…';

  @override
  String knowledgeMemorySummary(int count) {
    return 'メモリの概要（$count）';
  }

  @override
  String get knowledgeNoMatches => '一致する知識ノードがありません';

  @override
  String get knowledgeStateActive => 'アクティブ';

  @override
  String get knowledgeStateInactive => '非アクティブ';

  @override
  String knowledgeNodeMeta(String category, int count, String state) {
    return '$category · $count 回使用 · $state';
  }

  @override
  String knowledgeNodeMetaNoCategory(int count, String state) {
    return '$count 回使用 · $state';
  }

  @override
  String get knowledgeSaved => '保存しました';

  @override
  String knowledgeSaveFailed(String error) {
    return 'ノードを保存できませんでした：$error';
  }

  @override
  String get knowledgeDeleteQuestion => '知識ノードを削除しますか？';

  @override
  String knowledgeDeleteDescription(String name) {
    return '$name を削除します。この操作は元に戻せません。';
  }

  @override
  String get knowledgeDeleted => '知識ノードを削除しました';

  @override
  String knowledgeDeleteFailed(String error) {
    return 'ノードを削除できませんでした：$error';
  }

  @override
  String get knowledgeCancelEditing => '編集をキャンセル';

  @override
  String skillHubSearchFailed(String error) {
    return 'スキル検索に失敗しました：$error';
  }

  @override
  String skillHubExitCode(int code) {
    return '操作はコード $code で終了しました';
  }

  @override
  String get skillHubActionTimeout => 'スキル操作がタイムアウトしました。';

  @override
  String get skillHubActionDone => '操作が完了しました';

  @override
  String skillHubActionFailed(String error) {
    return 'スキル操作に失敗しました：$error';
  }

  @override
  String skillHubUninstallQuestion(String name) {
    return '$name をアンインストールしますか？';
  }

  @override
  String get skillHubUninstallDescription => 'スキルは削除され、後で再インストールできます。';

  @override
  String get skillHubUninstall => 'アンインストール';

  @override
  String get skillHubUpdateInstalled => 'インストール済みスキルを更新';

  @override
  String get skillHubSearchHint => 'スキルマーケットを検索…';

  @override
  String get skillHubLoading => 'スキルマーケットを読み込み中…';

  @override
  String skillHubSourcesTimedOut(String sources) {
    return '一部のソースがタイムアウトしました：$sources';
  }

  @override
  String get skillHubNoData => 'マーケットデータがありません';

  @override
  String get skillHubSources => 'ソース';

  @override
  String skillHubRateLimited(String name) {
    return '$name（レート制限）';
  }

  @override
  String get skillHubIndexUnavailable => 'スキルインデックスは現在利用できず、検索結果が不完全な場合があります。';

  @override
  String get skillHubFeatured => '注目';

  @override
  String get skillHubSearchPrompt => 'キーワードを入力してスキルを検索';

  @override
  String get skillHubInstalled => 'インストール済み';

  @override
  String get skillHubTrustOfficial => '公式';

  @override
  String get skillHubTrustTrusted => '信頼済み';

  @override
  String get skillHubTrustCommunity => 'コミュニティ';

  @override
  String get skillHubTrustUnverified => '未検証';

  @override
  String get skillHubTrustUntrusted => '信頼できない';

  @override
  String get skillHubTrustUnknown => '信頼レベル不明';

  @override
  String newSessionInitFailed(String error) {
    return '一部のセッションオプションを読み込めませんでした：$error';
  }

  @override
  String newSessionStartFailed(String error) {
    return 'セッションを開始できませんでした：$error';
  }

  @override
  String get newSessionTitleSection => 'セッションタイトル';

  @override
  String get newSessionTitleHint => '任意。空欄の場合は自動生成';

  @override
  String get newSessionWorkspace => 'ワークスペース';

  @override
  String get newSessionWorkspaceHint => 'サーバー上の Agent 作業ディレクトリ';

  @override
  String get newSessionBrowseDirectory => 'ディレクトリを参照';

  @override
  String get newSessionNoProject => 'プロジェクトなし';

  @override
  String get newSessionMoveLater => '後でセッションメニューから移動できます';

  @override
  String get newSessionUseCurrentModel => '現在のモデルを使用';

  @override
  String get newSessionAgent => 'Agent';

  @override
  String get newSessionStarting => '開始中…';

  @override
  String get newSessionStart => 'セッションを開始';

  @override
  String newSessionAgentSummary(String model, String cwd) {
    return '$model · $cwd';
  }

  @override
  String get newSessionCurrentModel => '現在のモデル';

  @override
  String get newSessionWorkspaceAbove => '上記のワークスペース';

  @override
  String get newSessionParentDirectory => '親ディレクトリ';

  @override
  String get artifactsTitle => '成果物';

  @override
  String get artifactsSearchHint => '成果物のタイトルとセッションを検索…';

  @override
  String get artifactsKindCode => 'コード';

  @override
  String get artifactsKindImage => '画像';

  @override
  String get artifactsKindLink => 'リンク';

  @override
  String get artifactsEmpty => '成果物はありません';

  @override
  String get artifactsEmptyDescription => 'セッションで生成された成果物がここに表示されます。';

  @override
  String get artifactsNoMatches => '一致する成果物はありません';

  @override
  String get artifactsNoMatchesDescription => '別の検索条件またはフィルターをお試しください。';

  @override
  String artifactsOpen(String name) {
    return '成果物 $name を開く';
  }

  @override
  String get artifactsSaved => '保存しました';

  @override
  String artifactsSaveFailed(String error) {
    return '成果物を保存できませんでした: $error';
  }

  @override
  String get artifactsSaveToDevice => 'デバイスに保存';

  @override
  String get artifactsCopy => '成果物をコピー';

  @override
  String get artifactsOpenLink => 'リンクを開く';

  @override
  String get artifactsOpenLinkFailed => 'リンクを開けませんでした。';

  @override
  String get artifactsImageLoadFailed => '画像を読み込めませんでした';

  @override
  String get shellReconnecting => '切断されました。再接続中…';

  @override
  String get shellReconnectNow => '今すぐ再接続';

  @override
  String get shellCollapseNavigation => 'ナビゲーションを折りたたむ';

  @override
  String get shellExpandNavigation => 'ナビゲーションを展開';

  @override
  String get shellNavigation => 'ナビゲーション';

  @override
  String get shellSessionArea => 'セッション';

  @override
  String get shellWorkspaceArea => 'ワークスペース';

  @override
  String get shellIntelligenceArea => 'インテリジェンス';

  @override
  String shellModelStatus(String value) {
    return 'モデル $value';
  }

  @override
  String shellWorkspaceStatus(String value) {
    return 'ワークスペース $value';
  }

  @override
  String shellAgentStatus(String value) {
    return 'Agent $value';
  }

  @override
  String get gitListView => 'リスト表示';

  @override
  String get gitTreeView => 'ツリー表示';

  @override
  String get gitViewPr => 'PR を表示';

  @override
  String gitChangeCounts(int staged, int changed) {
    return 'ステージ済み $staged · 変更 $changed';
  }

  @override
  String get gitWorkingTreeCleanDescription => '未コミットの変更はありません。';

  @override
  String get gitStagedSection => 'ステージ済み';

  @override
  String get gitUnstagedSection => '未ステージ';

  @override
  String get gitOpenPrFailed => 'プルリクエストを開けませんでした。';

  @override
  String gitUnstageFailed(String error) {
    return 'ステージ解除に失敗しました: $error';
  }

  @override
  String get gitCommitAndPushSucceeded => 'コミットしてプッシュしました';

  @override
  String get gitCommitSucceeded => 'コミットしました';

  @override
  String get gitStatusAdded => '追';

  @override
  String get gitStatusModified => '変';

  @override
  String get gitStatusDeleted => '削';

  @override
  String get gitStatusRenamed => '名';

  @override
  String get gitStatusConflict => '競';

  @override
  String get insightsTitle => 'インサイト';

  @override
  String insightsDays(int count) {
    return '$count 日';
  }

  @override
  String insightsLoading(int count) {
    return '過去 $count 日間の統計を読み込み中…';
  }

  @override
  String get insightsNoData => '使用量データはありません';

  @override
  String get insightsOverview => '概要';

  @override
  String get insightsSessions => 'セッション';

  @override
  String get insightsApiCalls => 'API 呼び出し';

  @override
  String get insightsCost => 'コスト';

  @override
  String get insightsDailyUsage => '日別使用量';

  @override
  String get insightsModelUsage => 'モデル使用量';

  @override
  String get insightsToolCalls => 'ツール呼び出し';

  @override
  String get insightsUnknownProvider => '不明なプロバイダー';

  @override
  String insightsModelSummary(String tokens, int sessions, String cost) {
    return '$tokens トークン · $sessions セッション · \$$cost';
  }

  @override
  String webhookBaseUrl(String url) {
    return 'ベース URL: $url';
  }

  @override
  String get webhookUrl => 'URL';

  @override
  String get webhookSecret => 'シークレット';

  @override
  String get toolsTitle => 'ツールセット';

  @override
  String get toolsEmpty => 'ツールセットはありません';

  @override
  String toolsToolsetSummary(int count, String status) {
    return '$count ツール · $status';
  }

  @override
  String get toolsTerminalBackend => 'ターミナル実行環境';

  @override
  String get toolsReady => '準備完了';

  @override
  String get toolsNeedsSetup => '設定が必要';

  @override
  String get toolsUnavailable => '利用不可';

  @override
  String toolsBackendSwitchFailed(String error) {
    return 'ターミナル環境を切り替えられませんでした: $error';
  }

  @override
  String get toolsComputerUseUnsupported => 'このバックエンド環境は非対応です';

  @override
  String get toolsComputerUseNotInstalled => 'cua-driver がインストールされていません';

  @override
  String get toolsComputerUseReady => 'Computer Use は準備完了です';

  @override
  String get toolsComputerUseNotReady => 'ドライバーまたは権限の準備ができていません';

  @override
  String get toolsRecheck => '再確認';

  @override
  String get toolsCheck => '確認';

  @override
  String toolsCheckResult(String label, String result) {
    return '$label: $result';
  }

  @override
  String get toolsWaitingForPermission => 'バックエンドの許可を待機中…';

  @override
  String get toolsRequestPermission => 'バックエンドのシステム権限を要求';

  @override
  String get toolsPermissionTimeout => '権限要求がタイムアウトしました。';

  @override
  String toolsPermissionFailed(String error) {
    return 'システム権限を要求できませんでした: $error';
  }

  @override
  String toolsToggleFailed(String error) {
    return 'ツールセットを更新できませんでした: $error';
  }

  @override
  String get agentBotsTitle => 'Bots';

  @override
  String agentRequestSummary(String title, String member) {
    return '$title · $member';
  }

  @override
  String modelPickerRefreshFailed(String error) {
    return 'モデルを更新できませんでした: $error';
  }

  @override
  String get modelPickerEdit => '表示モデルを編集';

  @override
  String modelPickerVisibilitySaveFailed(String error) {
    return 'モデルの表示設定を保存できませんでした: $error';
  }

  @override
  String get modelPickerMoaPresets => 'MoA プリセット';

  @override
  String modelPickerMoaModel(String model) {
    return 'MoA: $model';
  }

  @override
  String get modelPickerRefresh => 'モデルを更新';

  @override
  String get modelPickerFree => '無料';

  @override
  String modelPickerFreeDiscount(num percent) {
    return '無料 · -$percent%';
  }

  @override
  String modelPickerPricing(String input, String output, String discount) {
    return '入力 $input / 出力 $output$discount';
  }

  @override
  String get modelPickerSelectNone => 'すべて解除';

  @override
  String get modelPickerSelectAll => 'すべて選択';

  @override
  String get commonCopy => 'コピー';

  @override
  String get chatMermaidDiagram => 'Mermaid 図';

  @override
  String chatArtifactTitle(String language) {
    return '$language 成果物';
  }

  @override
  String chatCodeArtifactTitle(String language, int count) {
    return '$language コード · $count 行';
  }

  @override
  String get chatArtifactPreview => '成果物プレビュー';

  @override
  String chatCodeTitle(String language) {
    return '$language コード';
  }

  @override
  String get chatCodeCopied => 'コードをコピーしました';

  @override
  String get chatLivePreview => 'ライブプレビュー';

  @override
  String get chatExpandPreview => 'メッセージ内でプレビューを展開';

  @override
  String get chatAudioPlaybackFailed => '音声を再生できませんでした';

  @override
  String get chatPauseAudio => '音声を一時停止';

  @override
  String get chatPlayAudio => '音声を再生';

  @override
  String get chatOpenVideo => '動画 · タップして開く';

  @override
  String get chatOpenFile => 'ファイル · タップして開く';

  @override
  String imageSaveFailed(String error) {
    return '画像を保存できませんでした: $error';
  }

  @override
  String get voiceMenu => '音声メニュー';

  @override
  String get voiceStopRecording => '録音を停止';

  @override
  String get voiceDictation => '音声入力';

  @override
  String get voiceContinuousConversation => '連続音声会話';

  @override
  String get voiceAutoReadReplies => '返信を自動読み上げ';

  @override
  String get voiceWakeWord => 'ウェイクワード';

  @override
  String voiceWakePhrase(String phrase) {
    return '「$phrase」';
  }

  @override
  String get voiceStopSpeaking => '読み上げを停止';

  @override
  String get voiceWakeEnabling => 'ウェイクワードを有効化中…';

  @override
  String get voiceWakeTriggered => 'ウェイクワードを検出しました。聞き取り中…';

  @override
  String get voiceWakeListening => 'ウェイクワードを待機中';

  @override
  String voiceWakeListeningFor(String phrase) {
    return '「$phrase」を待機中';
  }

  @override
  String get voiceWakeWaiting => 'ウェイクワードの再開待ち';

  @override
  String get voiceWakeDisabled => 'ウェイクワードはオフです';

  @override
  String sessionPrBadge(int number, String status) {
    return 'PR #$number · $status';
  }

  @override
  String get sessionPrOpenFailed => 'プルリクエストを開けませんでした。';

  @override
  String get sessionCliBadge => 'CLI セッション';

  @override
  String get sessionDraftBadge => '未送信の下書きあり';

  @override
  String get sessionSharedBadge => '共有済み';

  @override
  String get sessionHandedOff => '引き継ぎ済み';

  @override
  String sessionHandedOffTo(String platform) {
    return '引き継ぎ済み · $platform';
  }

  @override
  String sessionHandoffErrorBadge(String error) {
    return '引き継ぎエラー · $error';
  }

  @override
  String sessionCompressionErrorBadge(String error) {
    return 'コンテキスト圧縮が一時的に失敗 · $error';
  }

  @override
  String sessionEndedWithReason(String reason) {
    return '終了 · $reason';
  }

  @override
  String get sessionEnded => '終了';

  @override
  String toolGroupHiddenRestore(int count) {
    return '$count 個のツールを非表示中。タップして復元';
  }

  @override
  String backgroundStopFailed(String error) {
    return 'プロセスを停止できませんでした: $error';
  }

  @override
  String get backgroundProcessRemoved => 'このプロセスは終了して削除されました';

  @override
  String get backgroundCloseAndHide => '閉じて非表示';

  @override
  String get mcpLogsEmpty => 'ログはありません';

  @override
  String get subagentTaskProgress => 'タスク進捗';

  @override
  String get cloudDiscoverAgain => '再検索';

  @override
  String get cloudPortalLoginPrompt =>
      '下の Portal でサインインしてください。サインイン後に Agent が自動検出されます。';

  @override
  String get backgroundTerminal => 'バックグラウンドターミナル';

  @override
  String get backgroundWaitingOutput => '出力を待機中…';

  @override
  String get backgroundStopping => '停止中…';

  @override
  String get backgroundStopProcess => 'プロセスを停止';

  @override
  String get markdownAlertTip => 'ヒント';

  @override
  String get markdownAlertImportant => '重要';

  @override
  String get markdownAlertWarning => '警告';

  @override
  String get markdownAlertCaution => '注意';

  @override
  String get markdownAlertNote => 'メモ';

  @override
  String get richLinkMaps => '地図';

  @override
  String turnActivityTools(int count) {
    return 'ツール $count 件';
  }

  @override
  String turnActivityReasoning(int count) {
    return '思考 $count 件';
  }

  @override
  String toolGroupFailed(int count) {
    return '$count 件失敗';
  }

  @override
  String get messageSourceDingtalk => 'DingTalk';

  @override
  String get profileScopeApplyTo => '適用先';

  @override
  String profileScopeChangesApplyTo(String profile) {
    return 'このページの変更は $profile プロファイルに適用されます。';
  }

  @override
  String get profileScopeConfiguring => '設定対象';

  @override
  String profileScopeCurrent(String name) {
    return '$name（現在）';
  }

  @override
  String get mcpLogsAllServers => 'すべてのサーバー';

  @override
  String get mcpLogsLoading => 'ログを読み込み中…';

  @override
  String badgeUnreadCount(String count) {
    return '未読 $count 件';
  }

  @override
  String progressPercent(int percent) {
    return '進捗 $percent%';
  }

  @override
  String avatarNamed(String name) {
    return 'アバター: $name';
  }

  @override
  String get avatarUnnamed => 'アバター';

  @override
  String get thinkingActive => '思考中';

  @override
  String get thinkingProcess => '思考過程';

  @override
  String get thinkingBriefly => '少し思考しました';

  @override
  String thinkingSeconds(String seconds) {
    return '$seconds 秒思考しました';
  }

  @override
  String thinkingMinutes(int minutes, int seconds) {
    return '$minutes 分 $seconds 秒思考しました';
  }

  @override
  String thinkingGeneratedCharacters(int count) {
    return '$count 文字生成済み';
  }

  @override
  String thinkingCharacters(int count) {
    return '$count 文字';
  }

  @override
  String get thinkingAnalyzing => 'コンテキストを分析中…';

  @override
  String get commonNoData => 'データはありません';

  @override
  String get commonFeatureDisabled => '機能は無効です';

  @override
  String get cloudDiscoveryFailed => 'Cloud の検出に失敗しました';

  @override
  String cloudDiscoveryInvalidData(String error) {
    return 'Cloud が認識できないデータを返しました: $error';
  }

  @override
  String get cloudDiscoveryUnsupported =>
      'このプラットフォームでは Hermes Cloud の検出を利用できません';

  @override
  String sessionCreateFailed(String error) {
    return 'セッションを作成できませんでした: $error';
  }

  @override
  String get statusReady => '準備完了';

  @override
  String get workspaceDescription => 'セッションタイルとプラグインペイン';

  @override
  String get subagentFallbackName => 'サブエージェント';

  @override
  String get subagentNoTask => 'タスクの説明がありません';

  @override
  String get subagentsStatusRunning => '実行中';

  @override
  String get subagentsStatusCompleted => '完了';

  @override
  String get subagentsStatusFailed => '失敗';

  @override
  String subagentCardTitle(String name) {
    return 'サブエージェント · $name';
  }

  @override
  String get subagentTask => 'タスク';

  @override
  String get subagentModel => 'モデル';

  @override
  String get subagentCurrentTool => '現在のツール';

  @override
  String get subagentSummary => '実行概要';

  @override
  String sessionApiCallCount(int count) {
    return 'API 呼び出し $count 回';
  }

  @override
  String sessionTokenCount(String count) {
    return '$count Token';
  }

  @override
  String get diagnosticsConsentDescription =>
      '匿名化したサーバーログ、システムおよび Provider 設定をアップロードします。ログには会話内容、ツール出力、ファイルパスが含まれる場合があります。API Key はアップロードされず、診断バンドルは 14 日後に削除されます。';

  @override
  String get diagnosticsApproveUpload => '同意してアップロード';

  @override
  String get diagnosticsGatewayUnavailable => 'Hermes Gateway に接続されていません';

  @override
  String get diagnosticsUploadFailed => 'アップロードに失敗しました';

  @override
  String get diagnosticsSentTitle => '診断情報を送信しました';

  @override
  String get diagnosticsLinkCopied => '表示リンクをクリップボードにコピーしました：';

  @override
  String get diagnosticsSupportPrompt => 'さらにサポートが必要な場合はこちらからお問い合わせください：';

  @override
  String diagnosticsSendFailed(String error) {
    return '診断情報を送信できませんでした：$error';
  }

  @override
  String get slashDescRetry => '前の応答を再生成';

  @override
  String get slashDescClear => '現在のセッション表示を消去';

  @override
  String get slashDescUndo => '直前の完全なターンを元に戻す';

  @override
  String get slashDescSteer => '現在のターンに指示を追加';

  @override
  String get slashDescStatus => 'セッション状態を表示';

  @override
  String get slashDescTitle => 'セッションタイトルを再生成';

  @override
  String get slashDescNew => '新しいセッションを開始';

  @override
  String get slashDescYolo => 'YOLO 自動承認を切り替え';

  @override
  String get slashDescHandoff => 'セッション引き継ぎを開く';

  @override
  String get slashDescProfile => 'プロファイルまたは人格を選択';

  @override
  String get slashDescHelp => 'ローカルとカタログのスラッシュコマンドを表示';

  @override
  String get slashDescBackground => 'バックグラウンドタスクを送信';

  @override
  String get slashDescCompress => '現在のセッションコンテキストを圧縮';

  @override
  String get slashDescQueue => 'メッセージを送信キューに追加';

  @override
  String get slashDescUsage => 'このセッションの使用量を表示';

  @override
  String get slashDescVersion => 'Hermes とモバイル版のバージョンを表示';

  @override
  String get slashDescStop => '現在のターンを停止';

  @override
  String get slashDescTools => 'ツール設定を開く';

  @override
  String get slashDescApprovals => '承認モードを設定：manual / smart / off';

  @override
  String get slashDescModel => 'モデル選択を開く';

  @override
  String get slashDescWake => 'ウェイクワードを管理：status / on / off / toggle';

  @override
  String get slashDescSkinUnavailable => 'デスクトップ専用のスキンコマンド';

  @override
  String get slashDescBrowserUnavailable => 'デスクトップ専用の内蔵ブラウザーコマンド';

  @override
  String get slashDescJourney => '星図ジャーニーを開く';

  @override
  String get slashDescPet => 'ペットセンターを開く';

  @override
  String get slashDescHatch => '新しいペットを生成して孵化';

  @override
  String get slashDescSave => '現在のセッション記録を保存';

  @override
  String get slashDescReloadConfigUnavailable =>
      'モバイル版と Gateway は reload-config に対応していません';

  @override
  String get cronSuggestionPrefix => '繰り返しタスクとして設定：';

  @override
  String get kanbanTaskCompletedNotification => '看板タスクが完了しました';

  @override
  String get kanbanTaskProblemNotification => '看板タスクに問題があります';

  @override
  String get themeGraphite => 'グラファイト';

  @override
  String get themeIndigo => 'インディゴ';

  @override
  String get themeMoss => 'モス';

  @override
  String get themeDune => 'デューン';

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
  String get mcpAuthBearerToken => 'Bearer Token';

  @override
  String get gitAgentShipTitle => 'Agent Ship';

  @override
  String get commonUrl => 'URL';

  @override
  String get toolEmptyList => '(空のリスト)';

  @override
  String toolItemCount(int count) {
    return '$count 件';
  }

  @override
  String toolFieldCount(int count) {
    return '$count フィールド';
  }

  @override
  String get toolPath => 'パス';

  @override
  String get toolLanguage => '言語';

  @override
  String get toolText => 'テキスト';

  @override
  String get toolMessage => 'メッセージ';

  @override
  String get toolSummary => '概要';

  @override
  String get toolExecuteCommand => 'コマンドを実行';

  @override
  String get toolRunCode => 'コードを実行';

  @override
  String toolRunCodeLanguage(String language) {
    return '$language コードを実行';
  }

  @override
  String toolSearchFor(String query) {
    return '検索: $query';
  }

  @override
  String get toolExtractWeb => 'Web ページを取得';

  @override
  String get toolApplyPatch => 'ファイルパッチを適用';

  @override
  String get toolListFiles => 'ファイル一覧';

  @override
  String get toolGenerateImage => '画像を生成';

  @override
  String get toolDelegateTask => '委任タスク';

  @override
  String toolTask(int index) {
    return 'タスク $index';
  }

  @override
  String toolRunEditingFiles(int count) {
    return '$count ファイルを編集中';
  }

  @override
  String toolRunExploringFiles(int count) {
    return '$count ファイルを調査中';
  }

  @override
  String toolRunRunningCommands(int count) {
    return '$count コマンドを実行中';
  }

  @override
  String toolRunDelegatingTasks(int count) {
    return '$count タスクを委任中';
  }

  @override
  String toolRunUsingTools(int count) {
    return '$count ツールを使用中';
  }

  @override
  String toolRunEditedFiles(int count) {
    return '$count ファイルを編集';
  }

  @override
  String toolRunExploredFiles(int count) {
    return '$count ファイルを調査';
  }

  @override
  String toolRunRanCommands(int count) {
    return '$count コマンドを実行';
  }

  @override
  String toolRunDelegatedTasks(int count) {
    return '$count タスクを委任';
  }

  @override
  String toolRunUsedTools(int count) {
    return '$count ツールを使用';
  }

  @override
  String get notificationBackgroundCompleted => 'バックグラウンドタスクが完了';

  @override
  String get notificationBackgroundCompletedBody =>
      'バックグラウンドタスクが完了しました。タップして結果を表示します。';

  @override
  String get notificationApprovalRequired => '承認が必要';

  @override
  String get notificationApprovalRequiredBody => 'エージェントが機密性の高い操作の承認を求めています。';

  @override
  String get voiceServerDisconnected => 'サーバーに接続されていません';

  @override
  String get voiceRecordingUnsupported => 'このプラットフォームではマイク録音を利用できません';

  @override
  String get voiceMicrophoneStartFailed => 'マイク権限が拒否されたか、録音を開始できません';

  @override
  String voiceRecordingFailed(String error) {
    return '録音に失敗しました: $error';
  }

  @override
  String get voiceNoSpeech => '聞き取れませんでした。もう一度お試しください。';

  @override
  String get voiceSttUnavailable => 'サーバーに音声認識（STT）が設定されていません';

  @override
  String voiceTranscriptionFailed(String error) {
    return '文字起こしに失敗しました: $error';
  }

  @override
  String voiceSpeechFailed(String error) {
    return '音声再生に失敗しました: $error';
  }

  @override
  String voiceStreamingSpeechFailed(String error) {
    return 'ストリーミング音声再生に失敗しました: $error';
  }

  @override
  String get voiceWakeInstallNotice =>
      'ウェイクワードを有効化中です。初回は検出エンジンのインストールが必要な場合があります。';

  @override
  String get voiceWakeUsage => '使い方: /wake [status|on|off|toggle]';

  @override
  String get voiceWakeNotEnabled => 'ウェイクワードが有効ではありません';

  @override
  String get voiceWakeOtherSurface => 'ウェイクワードは別のデバイスに割り当てられています';

  @override
  String get voiceWakeOwned => '別のデバイスがウェイクワードを待機中です';

  @override
  String get voiceWakeUnavailable => 'このバックエンドはウェイクワードに対応していません';

  @override
  String voiceWakeMicInterrupted(String error) {
    return 'ウェイクワードのマイクが中断しました: $error';
  }

  @override
  String get voiceWakeMicPermission => 'マイク権限が拒否されたため、ウェイクワードを待機できません';

  @override
  String voiceWakeMicStartFailed(String error) {
    return 'ウェイクワードのマイクを開始できません: $error';
  }

  @override
  String voiceWakeAudioUploadFailed(String error) {
    return 'ウェイクワード音声を送信できません: $error';
  }

  @override
  String get filesThisComputer => 'このコンピューター';

  @override
  String get billingSavedPaymentMethod => '保存済みの支払い方法';

  @override
  String billingPaymentMethodKind(String kind) {
    return '支払い方法 · $kind';
  }

  @override
  String get previewTourBack => '戻る';

  @override
  String get previewTourDone => '完了';

  @override
  String get previewTourNext => '次へ';

  @override
  String get chatMermaidParseError => 'Mermaid 図を解析できません';

  @override
  String get petDefaultName => 'Hermes ペット';

  @override
  String get sessionDetailProfile => 'プロファイル';

  @override
  String get profileArchiveType => 'Hermes プロファイル';

  @override
  String get profilesTemperature => '温度';

  @override
  String get profilesTopP => 'Top P';

  @override
  String get profilesMaxTokens => '最大トークン数';

  @override
  String get sessionDesktopFallback => 'デスクトップセッション';

  @override
  String get backgroundProcessFallback => 'バックグラウンドプロセス';

  @override
  String get insightsUnknownModel => '不明なモデル';

  @override
  String get billingCard => 'カード';

  @override
  String get billingLink => 'Link';

  @override
  String get slashGroupSkills => 'スキル';

  @override
  String get slashGroupCommands => 'コマンド';

  @override
  String get botAuthorYou => 'あなた';

  @override
  String get botAuthorSystem => 'システム';

  @override
  String get botAuthorFallback => 'Bot';

  @override
  String terminalErrorMessage(String error) {
    return 'ターミナルエラー: $error';
  }

  @override
  String sessionCopyTitle(String title) {
    return '$title（コピー）';
  }

  @override
  String get gitRemoteFallback => 'リモート';

  @override
  String get gitStashFallback => 'スタッシュ';

  @override
  String get notificationChannelErrors => 'エラー';

  @override
  String get notificationChannelWarnings => '警告';

  @override
  String get notificationChannelSuccess => '成功';

  @override
  String get notificationChannelApprovals => '承認';

  @override
  String get notificationChannelInfo => '情報';

  @override
  String get memoryCuratorTitle => 'キュレーター';

  @override
  String get messageSourceServer => 'サーバー';

  @override
  String get messageSourceMobile => 'モバイル';

  @override
  String get kanbanRunQueued => '待機中';

  @override
  String get kanbanRunCompleted => '完了';

  @override
  String get kanbanRunFailed => '失敗';

  @override
  String get kanbanRunCancelled => 'キャンセル済み';

  @override
  String get kanbanEventTaskCreated => 'タスクを作成';

  @override
  String get kanbanEventTaskUpdated => 'タスクを更新';

  @override
  String get kanbanEventTaskDeleted => 'タスクを削除';

  @override
  String get kanbanEventRunStarted => '実行を開始';

  @override
  String get kanbanEventRunCompleted => '実行が完了';

  @override
  String get kanbanEventRunFailed => '実行に失敗';

  @override
  String get kanbanEventRunCancelled => '実行をキャンセル';

  @override
  String get kanbanEventCommentCreated => 'コメントを追加';

  @override
  String get kanbanEventAttachmentAdded => '添付ファイルを追加';

  @override
  String get kanbanEventAttachmentDeleted => '添付ファイルを削除';

  @override
  String get cloudRoleOwner => '所有者';

  @override
  String get cloudRoleAdmin => '管理者';

  @override
  String get cloudRoleMember => 'メンバー';

  @override
  String get cloudRoleViewer => '閲覧者';

  @override
  String get chatStatusToolDrafting => 'ツール呼び出しを準備中';

  @override
  String get chatStatusProvider => 'プロバイダーの状態';

  @override
  String get previewScriptError => 'スクリプトエラー';

  @override
  String get previewUnhandledPromiseRejection => '未処理の Promise 拒否：';

  @override
  String botGroupSessionTitle(String roomId) {
    return 'グループ：$roomId';
  }

  @override
  String get errorExpectedObjectResponse => 'サーバーから無効なオブジェクト応答が返されました';

  @override
  String get errorTtsNoAudio => '音声合成から音声が返されませんでした';

  @override
  String get errorInvalidDataUrl => 'サーバーから無効なデータ URL が返されました';

  @override
  String get errorExportDirectoryMissing => 'サーバーからエクスポート先が返されませんでした';

  @override
  String get errorImportDirectoryMissing => 'サーバーからインポート先が返されませんでした';

  @override
  String get errorRawConfigInvalid => 'サーバーから無効な設定が返されました';

  @override
  String get errorPluginToggleRejected => 'バックエンドがプラグイン変更を拒否しました';

  @override
  String get errorConnectionNotConfigured => '接続が設定されていません';

  @override
  String errorSessionOwnerUnknown(String sessionId) {
    return 'セッション所有者が不明です：$sessionId';
  }

  @override
  String get errorRemotePushUnavailable => 'この接続ではリモートプッシュを利用できません';

  @override
  String get sshCommandTimedOut => 'SSH コマンドがタイムアウトしました';

  @override
  String get sshRemoteHomeUnsafe => 'リモートの Hermes ホームは安全ではありません';

  @override
  String get sshOwnershipVerificationFailed =>
      'リモート Hermes プロセスの所有権を確認できませんでした';

  @override
  String sshOwnershipProbeFailed(String status) {
    return 'リモート所有権の確認に失敗しました（$status）';
  }

  @override
  String get sshHelperInvalidJson => 'リモートヘルパーから無効な JSON が返されました';

  @override
  String get sshWindowsOwnershipVerificationFailed =>
      'リモート Windows プロセスの所有権を確認できませんでした';

  @override
  String get sshRemotePathInvalid => 'リモート Hermes パスは絶対パスまたは ~/ で始める必要があります';

  @override
  String get sshExecutableNotFound => '設定された Hermes 実行ファイルがリモートホストにありません';

  @override
  String get sshHermesNotInstalled => 'リモートホストに Hermes がインストールされていません';

  @override
  String get sshBootstrapFlagsUnsupported =>
      'リモート Hermes は安全な SSH 所有権ブートストラップフラグをサポートする必要があります';

  @override
  String get sshWindowsIdentityInvalid => 'リモート Windows バックエンドから無効な ID が返されました';

  @override
  String get sshWindowsExitedBeforeReady => 'リモート Windows バックエンドが準備完了前に終了しました';

  @override
  String get sshWindowsOwnershipProofFailed => 'リモート Windows の所有権証明に失敗しました';

  @override
  String get sshProcessIdMissing => 'リモート Hermes からプロセス ID が返されませんでした';

  @override
  String get sshExitedBeforeReady => 'リモート Hermes が準備完了前に終了しました';

  @override
  String get sshOwnershipProofFailed => 'リモート Hermes の所有権証明に失敗しました';

  @override
  String get errorSessionBranchIdMissing => 'Hermes から分岐セッションの永続 ID が返されませんでした';

  @override
  String get errorDuplicateImportFailed => 'Hermes が複製セッションをインポートできませんでした';

  @override
  String get errorSessionNoTitleableMessages => 'タイトル生成に使用できるメッセージがありません';

  @override
  String get errorTitleGeneratorEmpty => 'タイトル生成機能から空のタイトルが返されました';

  @override
  String get errorProjectIdRequired => 'プロジェクトを選択してください';

  @override
  String get errorProjectWorkingFolderMissing => '対象プロジェクトに作業フォルダーがありません';

  @override
  String get errorDownloadFailed => 'ダウンロードに失敗しました';

  @override
  String get errorMessagingPlatformNotFound => 'メッセージングプラットフォームが見つかりません';

  @override
  String errorBotGroupSessionStartFailed(String name) {
    return '$name のグループセッションを開始できませんでした';
  }

  @override
  String sshRemoteCommandFailed(String code) {
    return 'リモートコマンドに失敗しました（$code）';
  }

  @override
  String get sshHostAndUserRequired => 'SSH ホストとユーザーが必要です';

  @override
  String get sshPortInvalid => 'SSH ポートは 1～65535 の範囲で指定してください';

  @override
  String sshHostKeyChanged(String host, String expected, String received) {
    return '$host の SSH ホストキーが変更されました。期待値：$expected、受信値：$received';
  }

  @override
  String get sshProfileInvalid => 'リモートプロファイル名が無効です';

  @override
  String get errorDirectGatewayFeatureUnavailable =>
      'この機能には Hermes Mobile Server が必要で、直接 Gateway 接続では利用できません';

  @override
  String errorOperationFailedWithDetail(String error) {
    return '操作に失敗しました：$error';
  }

  @override
  String gatewayOauthRejected(String error) {
    return 'Gateway がサインインを拒否しました：$error';
  }

  @override
  String get gatewayOauthCodeMissing => 'Gateway コールバックに認証コードがありません';

  @override
  String get gatewayOauthStateMismatch =>
      'Gateway コールバックの状態が一致しません。安全のためサインインを中止しました。';

  @override
  String get gatewayOauthRefreshTokenMissing =>
      'Gateway セッションの期限が切れ、更新トークンがありません';

  @override
  String get gatewayOauthTicketMissing => 'Gateway から WebSocket チケットが返されませんでした';

  @override
  String get gatewayOauthAccessTokenMissing => 'Gateway のトークン応答にアクセストークンがありません';

  @override
  String get gatewayOauthTimedOut => 'Gateway のサインインがタイムアウトしました';

  @override
  String get gatewayOauthNativeUnsupported =>
      'このプラットフォームではネイティブ Gateway OAuth を利用できません';

  @override
  String get updateManifestInvalid => '更新マニフェストが無効です';

  @override
  String sshRemotePlatformUnsupported(String error) {
    return 'リモートプラットフォームはサポートされていません：$error';
  }

  @override
  String get sshWebUnsupported => 'Web ではネイティブ SSH 接続を利用できません';

  @override
  String get filesDownloadPlatformUnsupported =>
      'このプラットフォームではローカルファイルへダウンロードできません';

  @override
  String get sessionExportPlatformUnsupported =>
      'このプラットフォームではローカルファイルへエクスポートできません';

  @override
  String get errorPluginCanonicalKeyRequired => 'このプラグインを変更するには正規キーが必要です';

  @override
  String get connectGatewayToken => 'Gateway トークン';

  @override
  String get modelMoaTitle => 'エージェント混合';

  @override
  String get insightsTokens => 'トークン';

  @override
  String get messageWebFallback => 'Web';

  @override
  String get mcpLogsSourceStdio => 'stdio';

  @override
  String get mcpLogsSourceAgent => 'エージェント';

  @override
  String get projectPrimaryFolder => 'メイン';

  @override
  String get botGroupNameRequired => 'グループ名を入力してください';

  @override
  String get botGroupMembersMinimum => 'グループには少なくとも 2 つの Bot が必要です';

  @override
  String botGroupMembersRange(int max) {
    return 'グループには 2～$max 個の Bot が必要です';
  }

  @override
  String botGroupMembersMaximum(int max) {
    return 'グループに追加できる Bot は最大 $max 個です';
  }

  @override
  String get botGroupMemberUnavailable => '利用できるグループメンバーがいません';

  @override
  String get botProfileNameUnavailable => '利用できるプロファイル名がありません';

  @override
  String get botDefaultProfileDeleteForbidden => 'デフォルトプロファイルは削除できません';

  @override
  String get botConnectionUnavailable => 'Bot 接続を利用できません';

  @override
  String get botTurnFailed => 'Bot のターンに失敗しました';

  @override
  String get mcpInvalidJsonSyntax => 'JSON の構文が無効です';

  @override
  String get mcpJsonObjectRequired => 'JSON のトップレベル値はオブジェクトである必要があります';

  @override
  String get voiceWakeMicStreamEnded => 'ウェイクワードのマイクストリームが予期せず終了しました';

  @override
  String httpStatusError(int statusCode) {
    return 'サーバーが HTTP $statusCode を返しました';
  }
}
