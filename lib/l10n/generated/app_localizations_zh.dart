// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get commonCopyFailed => '无法复制到剪贴板';

  @override
  String get commonClipboardReadFailed => '无法读取剪贴板';

  @override
  String petGenerateReferenceFailed(String error) {
    return '添加参考图片失败：$error';
  }

  @override
  String petSelectFailed(String error) {
    return '无法选择宠物：$error';
  }

  @override
  String terminalSshNamed(String host) {
    return 'SSH $host';
  }

  @override
  String get deepLinkUnsupported => '不支持的 Hermes 链接';

  @override
  String get deepLinkMcpNameInvalid => 'MCP 名称格式无效';

  @override
  String get deepLinkMcpConfigMissing => 'MCP 链接缺少配置';

  @override
  String get deepLinkMcpConfigTooLarge => 'MCP 配置超过 32 KiB';

  @override
  String get deepLinkMcpEncodingInvalid => 'MCP 配置编码无效';

  @override
  String get deepLinkMcpJsonInvalid => 'MCP 配置不是有效 JSON';

  @override
  String get deepLinkMcpObjectRequired => 'MCP 配置必须是对象';

  @override
  String get deepLinkMcpUrlCommandConflict => 'MCP 配置不能同时包含 URL 和命令';

  @override
  String get deepLinkMcpHttpOnly => 'MCP URL 仅支持 HTTP 或 HTTPS';

  @override
  String get deepLinkMcpEndpointMissing => 'MCP 配置缺少 URL 或命令';

  @override
  String get terminalConnectionClosed => '终端连接已关闭';

  @override
  String terminalRequestFailed(String error) {
    return '终端请求发送失败：$error';
  }

  @override
  String get terminalGenericError => '终端错误';

  @override
  String get botUntitledTask => '未命名任务';

  @override
  String botMemberPaused(String name) {
    return '$name 已暂停；直接 @该成员或发送 resume 可恢复。';
  }

  @override
  String get botGroupRoundCapReached => '本轮讨论已达上限，发送新消息即可继续对话。';

  @override
  String get botGroupMessageCapReached => '本次对话消息数已达上限，发送新消息即可继续。';

  @override
  String get botRoutineFieldsRequired => '任务名称、指令和计划不能为空';

  @override
  String get botRoutineNulForbidden => '任务名称、指令和计划不能包含 NUL';

  @override
  String get pluginLoadActionReadOnly => '插件 view.load_action 必须是只读 action';

  @override
  String get pluginMethodMissing => '插件 action 缺少 method';

  @override
  String get pluginPathInvalid => '插件 action path 无效';

  @override
  String pluginMethodUnsupported(String method) {
    return '插件 REST method 不受支持：$method';
  }

  @override
  String get pluginUrlInvalid => '插件 action URL 无效';

  @override
  String get pluginUrlSchemeUnsupported => '插件 action URL scheme 不受支持';

  @override
  String get pluginLinkOpenFailed => '无法打开链接';

  @override
  String get pluginNotificationFieldsMissing =>
      '插件通知 action 缺少 title 或 message';

  @override
  String get pluginNotificationUnavailable => '当前宿主未提供通知能力';

  @override
  String pluginActionUnsupported(String kind) {
    return '移动端不支持插件 action：$kind';
  }

  @override
  String get kanbanTaskAlreadyRunning => '任务已在运行';

  @override
  String get gatewayUnavailable => 'Hermes 后端 Gateway 不可用';

  @override
  String get filesDirectoryMissing => '目录不存在';

  @override
  String get filesFolderFallback => '当前平台无法列举本地文件夹，请改为多选文件';

  @override
  String get billingCreditsExhausted => '余额不足或额度已用尽';

  @override
  String workspacePaneLimit(int count) {
    return '工作区最多同时打开 $count 个窗格';
  }

  @override
  String get projectMissing => '项目不存在或已删除';

  @override
  String updateHttpError(int status) {
    return '更新服务返回 HTTP $status';
  }

  @override
  String get chatCompactingThread => '正在总结线程';

  @override
  String get chatModelChanged => '模型已更改';

  @override
  String get chatTurnContinued => '已继续中断的回合';

  @override
  String get chatPersonalityChanged => '个性配置已更改';

  @override
  String get chatDelegationCompleted => '后台代理工作已完成';

  @override
  String chatDelegationCountCompleted(int count) {
    return '$count 个后台代理任务已完成';
  }

  @override
  String get chatHermesNotification => 'Hermes 通知';

  @override
  String get chatBrowserTask => '浏览器任务';

  @override
  String get chatPreviewRestart => '预览服务重启';

  @override
  String chatPreparingTool(String name) {
    return '正在准备 $name';
  }

  @override
  String get chatMoaAggregating => '◇ 正在汇总多模型结果…';

  @override
  String get chatMoaCollaboration => '多模型协作';

  @override
  String get chatCurrentGoal => '当前目标';

  @override
  String get chatCodeReview => '代码审查';

  @override
  String get chatHermesRunFailed => 'Hermes 运行失败';

  @override
  String get chatPlanItem => '计划项';

  @override
  String get chatAssistantReplyFailed => '助手回复失败';

  @override
  String get terminalServerNotConfigured => '尚未配置服务器';

  @override
  String terminalLimitReached(int count) {
    return '最多同时打开 $count 个终端，请先关闭一个会话';
  }

  @override
  String terminalNumbered(int number) {
    return '终端 $number';
  }

  @override
  String get terminalSnapshotStart => '── 以下是上次会话的只读输出快照 ──';

  @override
  String get terminalSnapshotEnd => '── 快照结束，正在恢复终端 ──';

  @override
  String get terminalSshHostRequired => 'SSH host 不能为空';

  @override
  String get terminalRestartingShell => '── 正在重新启动 shell… ──';

  @override
  String get terminalOpenedNewShell => '── 无法恢复原 shell，已打开新 shell ──';

  @override
  String get terminalPtyIdMissing => '服务器未返回 PTY 会话 ID';

  @override
  String terminalShellExited(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'other': ' (code $code)',
      'empty': '',
    });
    return '── shell 已退出$_temp0 · 可点「重启」继续 ──';
  }

  @override
  String get terminalReconnecting => '终端连接中断，正在重连…';

  @override
  String get terminalRestoringShell => '── 连接中断，正在恢复或重开 shell… ──';

  @override
  String get terminalConnectionRestored => '── 已恢复终端连接 ──';

  @override
  String get terminalConnectionRestoreFailed => '── 恢复终端连接失败 ──';

  @override
  String get terminalReconnected => '终端已重连（可能已重开新 shell）';

  @override
  String get terminalReconnectFailed => '终端重连失败，请手动新建终端';

  @override
  String get sessionChooseHandoffPlatform => '请选择交接平台';

  @override
  String sessionHandoffTargetFailed(String target) {
    return '交接到 $target 失败';
  }

  @override
  String get sessionHandoffTimeout => '交接超时，请重试';

  @override
  String get sessionNoActive => '没有活动会话';

  @override
  String sessionLoadMoreFailed(String error) {
    return '加载更多会话失败：$error';
  }

  @override
  String get sessionOfflineTranscript => '离线模式：显示缓存的转录';

  @override
  String sessionTranscriptRefreshFailed(String error) {
    return '刷新转录失败：$error';
  }

  @override
  String sessionOlderMessagesFailed(String error) {
    return '加载更早消息失败：$error';
  }

  @override
  String sessionListLoadFailed(String error) {
    return '会话列表加载失败：$error';
  }

  @override
  String get sessionProfileSwitching => '配置档正在切换，请稍后重试';

  @override
  String get sessionSubagentReadOnly => '子代理会话为只读';

  @override
  String get sessionChangedRetry => '会话已切换，请稍后重试';

  @override
  String sessionConnectionUnknown(String id) {
    return '会话所属连接未知：$id';
  }

  @override
  String sessionConnectionUnavailable(String id) {
    return '会话所属连接不可用：$id';
  }

  @override
  String get sessionUnsavedTitle => '会话尚未保存，无法生成标题';

  @override
  String get sessionShareLinkMissing => '服务器未返回分享链接';

  @override
  String sessionBatchDeletePartial(int deleted, int failed) {
    return '已删除 $deleted 个，$failed 个删除失败';
  }

  @override
  String get sessionCouldNotCreate => '无法创建会话';

  @override
  String get sessionUserMessageMissing => '找不到对应的用户消息';

  @override
  String get sessionRestoreMessageMissing => '找不到要恢复的用户消息';

  @override
  String get sessionBranchMessageMissing => '找不到要分支的消息';

  @override
  String get sessionHistoryPositionMissing => '该消息缺少历史位置，请刷新会话后重试';

  @override
  String get sessionRuntimeIdMissing => 'Hermes 未返回运行时会话 ID';

  @override
  String get aboutLicenses => '开源许可';

  @override
  String get aboutLicensesDescription => '查看应用使用的第三方软件许可';

  @override
  String get aboutProductDescription => 'Hermes Agent 的移动端客户端';

  @override
  String get aboutProductInfo => '产品信息';

  @override
  String get aboutTitle => '关于 Hermes';

  @override
  String get appTitle => 'Hermes Mobile';

  @override
  String get appearanceHaptics => '触觉反馈';

  @override
  String get appearanceHapticsDesc => '发送、出错和任务完成时震动提示';

  @override
  String get appearanceHighContrast => '高对比模式';

  @override
  String get appearanceHighContrastDesc => '增强文字和边框对比度';

  @override
  String get appearanceKeepAwake => '保持屏幕常亮';

  @override
  String get appearanceKeepAwakeDesc => '打开对话时防止屏幕自动锁定';

  @override
  String get appearanceModeDark => '深色';

  @override
  String get appearanceModeLight => '浅色';

  @override
  String get appearanceModeSystem => '跟随系统';

  @override
  String get appearanceThemeColor => '主题色';

  @override
  String get appearanceTitle => '外观';

  @override
  String get approvalRequests => '审批请求';

  @override
  String get backendConnected => '后端已连接';

  @override
  String get backendDisconnected => '后端未连接';

  @override
  String get billingAccountBalance => '账户余额';

  @override
  String get billingAccountTab => '账户';

  @override
  String get billingAmountUsd => '金额 (USD)';

  @override
  String get billingAutoReload => '自动充值';

  @override
  String get billingAutoReloadDescription => '余额低于阈值时补充额度';

  @override
  String get billingAutoReloadDisabled => '自动充值已关闭';

  @override
  String get billingAutoReloadEnabled => '自动充值已启用';

  @override
  String get billingAutoReloadUpdateFailed => '无法更新自动充值';

  @override
  String get billingAvailableCredits => '可用额度';

  @override
  String get billingCancelAtPeriodEnd => '在周期结束时取消订阅';

  @override
  String get billingCancelAtPeriodEndDescription => '当前套餐权益会保留到本周期结束。';

  @override
  String get billingCancelAtPeriodEndQuestion => '在周期结束时取消？';

  @override
  String get billingCancelFailed => '无法取消订阅';

  @override
  String get billingChargeCompleted => '充值已完成';

  @override
  String get billingChargeForbidden => '当前账户不能从客户端充值';

  @override
  String get billingChargeIncomplete => '充值未完成';

  @override
  String get billingConfirmCancellation => '确认取消';

  @override
  String get billingConfirmPurchase => '确认购买';

  @override
  String get billingConfirmUpgrade => '确认升级套餐。';

  @override
  String billingCreditsPerMonth(Object credits) {
    return '$credits credits/月';
  }

  @override
  String get billingCurrent => '当前';

  @override
  String get billingDowngrade => '降级';

  @override
  String get billingDowngradePeriodEnd => '降级将在当前周期结束后生效。';

  @override
  String get billingGatewayMissing => '尚未连接到 Hermes 网关';

  @override
  String get billingInvalidReloadValues => '请输入有效的阈值和充值金额';

  @override
  String get billingLoading => '读取真实账单状态…';

  @override
  String get billingLoadingPlans => '读取套餐目录…';

  @override
  String get billingLoggedIn => '已登录';

  @override
  String get billingLoggedOut => '未登录';

  @override
  String get billingManageInPortal => '在 Portal 管理';

  @override
  String billingMaximumCharge(Object amount) {
    return '最高 \$$amount';
  }

  @override
  String billingMinimumCharge(Object amount) {
    return '最低 \$$amount';
  }

  @override
  String get billingMonthlySpendingCap => '月度远程消费上限';

  @override
  String get billingNoActivePlan => '无有效套餐';

  @override
  String get billingNoPlans => '没有可用套餐目录';

  @override
  String get billingNoUsageData => '没有可用的用量数据';

  @override
  String get billingNoUsageDescription => '网关尚未返回 Remote Spending 用量模型。';

  @override
  String get billingNotConnected => '未连接到 Hermes';

  @override
  String get billingNotProvided => '未提供';

  @override
  String get billingNotSet => '未设置';

  @override
  String get billingOpenPortal => '打开 Portal';

  @override
  String get billingOpenVerification => '打开验证页面';

  @override
  String get billingPaymentIncomplete => '支付未完成';

  @override
  String get billingPaymentMethod => '支付方式';

  @override
  String get billingPaymentTimeout => '支付状态确认超时，请在 Portal 中检查结果';

  @override
  String get billingPending => '待生效';

  @override
  String billingPendingCancellation(Object date) {
    return '将在 $date 取消';
  }

  @override
  String billingPendingDowngrade(Object date, Object name) {
    return '将在 $date 降级到 $name';
  }

  @override
  String billingPerMonth(Object price) {
    return '$price/月';
  }

  @override
  String get billingPeriodEnd => '周期结束时';

  @override
  String get billingPlanAlreadyActive => '当前已经使用此套餐。';

  @override
  String billingPlanChangeEffectiveAt(Object date) {
    return '套餐变更将在 $date 生效。';
  }

  @override
  String get billingPlanChangeFailed => '无法更改套餐';

  @override
  String get billingPlanChangeForbidden => '当前账户没有更改套餐的权限';

  @override
  String get billingPlanChangePeriodEnd => '套餐变更将在当前周期结束后生效。';

  @override
  String get billingPlanChangeUnavailable => '此变更当前不可用。';

  @override
  String get billingPlanCredits => '套餐额度';

  @override
  String get billingPlansTab => '套餐';

  @override
  String get billingPortalMissing => '服务端没有提供账单 Portal 地址';

  @override
  String get billingPortalOpenFailed => '无法打开账单 Portal';

  @override
  String get billingPurchaseCredits => '购买额度';

  @override
  String get billingReloadAboveMaximum => '充值金额超过服务端允许的最高值';

  @override
  String get billingReloadBelowMinimum => '充值金额低于服务端允许的最低值';

  @override
  String get billingReloadTo => '充值到';

  @override
  String billingRemaining(Object amount) {
    return '剩余 $amount';
  }

  @override
  String billingRenews(Object date) {
    return '续期 $date';
  }

  @override
  String get billingResumeFailed => '无法撤销待处理变更';

  @override
  String get billingSaveAutoReload => '保存自动充值';

  @override
  String billingSpentThisMonth(Object amount) {
    return '本月已使用 $amount';
  }

  @override
  String billingSwitchPlan(Object name) {
    return '切换到 $name？';
  }

  @override
  String get billingTitle => '账单';

  @override
  String get billingTopupCredits => '充值额度';

  @override
  String get billingTriggerThreshold => '触发阈值';

  @override
  String get billingUnavailableForAccount => '此账户不可用';

  @override
  String billingUpgradeAmount(Object amount) {
    return '升级将立即生效，本次应付 \$$amount。';
  }

  @override
  String get billingUpgradeChargeNow => '升级将立即生效并产生费用。';

  @override
  String get billingUsageTab => '用量';

  @override
  String billingUsedOf(Object spent, Object total) {
    return '已用 $spent / $total';
  }

  @override
  String billingVerificationFailed(Object error) {
    return '验证失败：$error';
  }

  @override
  String get billingVerificationIncomplete => '验证未完成，请稍后重试';

  @override
  String get billingVerificationInstructions => '请在浏览器中完成验证，以允许此终端进行远程消费操作。';

  @override
  String get billingVerificationRequired => '需要额外验证';

  @override
  String get billingVerificationStarting => '正在启动验证…';

  @override
  String get billingVerificationSucceeded => '验证成功，可以继续操作';

  @override
  String get billingVerifyAndContinue => '验证并继续';

  @override
  String get billingViewSubscriptionInPortal => '可前往 Portal 查看订阅。';

  @override
  String get chatAbsoluteServerPath => '使用服务器上的绝对路径';

  @override
  String get chatAddImage => '添加图片';

  @override
  String chatAddImageFailed(String error) {
    return '添加图片失败：$error';
  }

  @override
  String chatAddedToQueue(int count) {
    return '已加入队列（当前排队 $count 条）';
  }

  @override
  String get chatAllDates => '所有日期';

  @override
  String get chatAllHistoryShown => '已显示全部历史';

  @override
  String get chatApprovalManual => '手动';

  @override
  String get chatApprovalManualDescription => '每一步都需要确认';

  @override
  String get chatApprovalMode => '审批模式';

  @override
  String chatApprovalModeFailed(String error) {
    return '设置审批模式失败：$error';
  }

  @override
  String chatApprovalModeSet(String mode) {
    return '审批模式已设为 $mode';
  }

  @override
  String get chatApprovalOff => '关闭';

  @override
  String get chatApprovalOffDescription => '无需确认，自动执行';

  @override
  String get chatApprovalSmart => '智能';

  @override
  String get chatApprovalSmartDescription => '仅在有风险的操作时询问';

  @override
  String get chatApprovalsUsage => '用法：/approvals manual|smart|off';

  @override
  String chatArtifactVersions(int count) {
    return '全部版本（$count）';
  }

  @override
  String get chatAssistant => '助手';

  @override
  String get chatAttach => '添加';

  @override
  String get chatAttachFiles => '添加文件';

  @override
  String get chatAttachLink => '添加链接';

  @override
  String chatAttachmentUploadFailed(String error) {
    return '附件上传失败：$error';
  }

  @override
  String get chatAutoRetried => '已自动重试';

  @override
  String get chatBackToNewerMessages => '回到较新消息';

  @override
  String get chatBackToWorkspace => '返回工作区';

  @override
  String get chatBackgroundAgentRunning => '后台代理运行中 · 完成后将继续本回合';

  @override
  String chatBackgroundAgentsRunning(int count) {
    return '$count 个后台代理运行中 · 完成后将继续';
  }

  @override
  String chatBackgroundCount(int count) {
    return '$count 个后台任务';
  }

  @override
  String get chatBackgroundPrompt => '后台任务指令';

  @override
  String chatBackgroundSubmitFailed(String error) {
    return '提交后台任务失败：$error';
  }

  @override
  String get chatBackgroundSubmitted => '已提交后台任务';

  @override
  String chatBackgroundSubmittedWithId(String id) {
    return '已提交后台任务（$id）';
  }

  @override
  String chatBackgroundTaskCompleted(String label) {
    return '$label 已完成';
  }

  @override
  String chatBackgroundTaskFailed(String label) {
    return '$label 失败';
  }

  @override
  String get chatBasicToolsets => '基础工具集';

  @override
  String get chatBranch => '分支';

  @override
  String chatBranchChanges(String branch, int changedFiles) {
    return '$branch · $changedFiles 个文件变更';
  }

  @override
  String get chatBranchCreated => '已创建分支会话';

  @override
  String chatBranchCreatedWithId(String id) {
    return '已创建分支会话（$id）';
  }

  @override
  String chatBranchFailed(String error) {
    return '创建分支失败：$error';
  }

  @override
  String get chatBranchInNewSession => '在新会话中创建分支';

  @override
  String get chatBranchedHere => '已从此处创建分支';

  @override
  String chatBranchedWithId(String id) {
    return '已从此处创建分支（$id）';
  }

  @override
  String chatBranchesLoadFailed(String error) {
    return '加载分支失败：$error';
  }

  @override
  String get chatBrowseArtifactsDescription => '浏览此会话生成的产物';

  @override
  String get chatBrowseFiles => '浏览文件管理';

  @override
  String get chatBrowseFilesDescription => '在文件管理中定位并选择目录';

  @override
  String get chatCancelKeyboardHint => '取消 (Esc)';

  @override
  String get chatCatalogEmpty => '暂无可用服务器';

  @override
  String get chatChangeWorkspace => '切换工作区';

  @override
  String get chatChangeWorkspaceDescription => 'AI 后续将在所选服务器目录中读取和修改文件';

  @override
  String get chatClosePreview => '关闭预览';

  @override
  String get chatCollapseStatusDetails => '收起详情';

  @override
  String get chatCollapseSubsessions => '收起子会话';

  @override
  String get chatCommandCompletedNoOutput => '命令已执行，无输出';

  @override
  String get chatCommandExecutionFailed => '命令执行失败';

  @override
  String chatCommandFailed(String error) {
    return '命令执行失败：$error';
  }

  @override
  String get chatCommandMessageQueued => '消息已加入队列';

  @override
  String get chatCommandNoFillContent => '没有可填充的内容';

  @override
  String get chatCommandNoSendableContent => '没有可发送的内容';

  @override
  String get chatCommandQueued => '命令已加入队列';

  @override
  String get chatCommandSearchHint => '换个关键词试试';

  @override
  String get chatCommandSearchFailed => '命令加载失败，请检查网络连接';

  @override
  String get chatCommandStarting => '命令正在执行';

  @override
  String get chatCompositeToolsets => '组合工具集';

  @override
  String get chatCompressContext => '压缩';

  @override
  String chatCompressionFailed(String error) {
    return '压缩上下文失败：$error';
  }

  @override
  String get chatCompressionRequested => '上下文已压缩';

  @override
  String get chatConfigureProvider => '配置服务商';

  @override
  String get chatConnecting => '正在连接';

  @override
  String get chatConnectionFailed => '连接失败';

  @override
  String get chatContentFilled => '内容已填充';

  @override
  String get chatContextUsage => '上下文使用率';

  @override
  String chatContextUsagePercent(int percent) {
    return '上下文使用率：$percent%';
  }

  @override
  String get chatCopyAsMarkdown => '复制为 Markdown';

  @override
  String get chatCopyDiagnostics => '复制诊断信息';

  @override
  String get chatCopySessionId => '复制会话 ID';

  @override
  String get chatCopySessionLink => '复制会话链接';

  @override
  String get chatCopyText => '复制文本';

  @override
  String get chatCreateScheduledTask => '创建定时任务';

  @override
  String chatCronSuggestion(String phrase) {
    return '检测到定时任务：$phrase';
  }

  @override
  String get chatCurrentSessionArtifacts => '本次会话的产物';

  @override
  String get chatCurrentSessionToolsets => '当前会话工具集';

  @override
  String get chatCurrentlyActive => '当前激活';

  @override
  String chatDeletePromptFailed(String error) {
    return '删除提示词失败：$error';
  }

  @override
  String get chatDeliveryUncertain => '投递状态未知';

  @override
  String get chatDiagnosticsCopied => '诊断信息已复制';

  @override
  String chatDiagnosticsError(String error) {
    return '错误信息：$error';
  }

  @override
  String chatDiagnosticsModel(String provider, String model) {
    return '模型：$provider / $model';
  }

  @override
  String chatDiagnosticsTime(String time) {
    return '时间：$time';
  }

  @override
  String get chatDiagnosticsTitle => '诊断信息';

  @override
  String chatEditFailed(String error) {
    return '编辑失败：$error';
  }

  @override
  String get chatEditMessageHint => '编辑消息…';

  @override
  String get chatEditMessageKeyboardHint => '编辑消息…（Enter 发送，Shift+Enter 换行）';

  @override
  String get chatEmptyDescription => '流式回复、工具调用、审批与澄清，和桌面端一样完整。';

  @override
  String get chatEmptyTitle => '和 Hermes 开始对话吧';

  @override
  String get chatEnterOtherDirectory => '输入其他目录';

  @override
  String get chatEnterWorkspacePath => '输入工作区路径';

  @override
  String get chatErrorAuth => '身份验证错误';

  @override
  String get chatErrorBilling => '账单错误';

  @override
  String get chatErrorNetwork => '网络错误';

  @override
  String get chatErrorProvider => '服务商错误';

  @override
  String get chatErrorRateLimit => '触发速率限制';

  @override
  String get chatErrorReply => '回复出错';

  @override
  String get chatExecuting => '执行中…';

  @override
  String chatExecutionFailed(String error) {
    return '执行失败：$error';
  }

  @override
  String get chatExpandStatusDetails => '展开详情';

  @override
  String get chatExpandSubsessions => '展开子会话';

  @override
  String chatFileTooLarge(int maxMb, String name) {
    return '$name 超过 $maxMb MB 限制';
  }

  @override
  String get chatFillRetry => '重试';

  @override
  String get chatFindHint => '在当前对话中查找';

  @override
  String get chatFindInConversation => '在对话中查找';

  @override
  String chatFolderFilesAttached(int attached, int skipped) {
    return '已添加 $attached 个文件（跳过 $skipped 个）';
  }

  @override
  String get chatFolderPickerUnavailable => '当前平台不支持选择文件夹';

  @override
  String chatForwardedToCommand(String target) {
    return '已转发至 /$target';
  }

  @override
  String get chatGlobalCliToolsets => '全局 CLI 工具集';

  @override
  String get chatGlobalToolsetsDescription => '全局 CLI 工具集开关，立即生效';

  @override
  String get chatGoals => '目标';

  @override
  String chatHandingOffTo(String name) {
    return '正在交接给 $name…';
  }

  @override
  String get chatHandoff => '交接';

  @override
  String get chatHandoffCompleted => '已完成';

  @override
  String chatHandoffCompletedTo(String name) {
    return '已交接给 $name';
  }

  @override
  String chatHandoffFailed(String error) {
    return '交接失败：$error';
  }

  @override
  String get chatHandoffFailedStatus => '失败';

  @override
  String get chatHandoffGatewayRunning => '运行中';

  @override
  String chatHandoffPlatformsFailed(String error) {
    return '加载交接平台失败：$error';
  }

  @override
  String get chatHandoffTimeout => '交接超时';

  @override
  String get chatHandoffToPlatform => '交接至平台';

  @override
  String get chatHandoffWaiting => '等待中';

  @override
  String get chatHideStatus => '隐藏';

  @override
  String get chatHistoryLocator => '聊天记录定位';

  @override
  String chatHomeChannel(String name) {
    return '主频道：$name';
  }

  @override
  String get chatHomeChannelNotSet => '未设置主频道';

  @override
  String get chatHtmlPreview => 'HTML 预览';

  @override
  String get chatInflightRecovered => '已恢复未完成的回复';

  @override
  String get chatInsufficientQuota => '额度不足';

  @override
  String get chatInvalidCommandAlias => '无效的命令别名';

  @override
  String get chatJumpToTopic => '跳转到话题';

  @override
  String get chatLast24Hours => '最近 24 小时';

  @override
  String get chatLast7Days => '最近 7 天';

  @override
  String get chatLastTurnRetried => '已重试上一轮';

  @override
  String get chatLastTurnUndone => '已撤销上一轮';

  @override
  String get chatLoadFailed => '加载失败';

  @override
  String get chatLoadOlderMessagesHint => '上滑加载更早消息';

  @override
  String get chatLoadingCommands => '正在加载命令…';

  @override
  String get chatLocalCommands => '本地命令';

  @override
  String get chatLocateTopic => '定位话题';

  @override
  String get chatLongPressCodingStatus => '长按编码状态可切换分支或新建工作树';

  @override
  String get chatMarkMessage => '标记消息';

  @override
  String get chatMarkdownCopied => '已复制为 Markdown';

  @override
  String get chatMarkedOnly => '仅显示标记';

  @override
  String chatMessageCount(int count) {
    return '$count 条消息';
  }

  @override
  String get chatModel => '模型';

  @override
  String get chatModelSwitchDeferred => '模型切换将在下一轮生效';

  @override
  String chatModelSwitchFailed(String error) {
    return '切换模型失败：$error';
  }

  @override
  String chatModelsLoadFailed(String error) {
    return '加载模型列表失败：$error';
  }

  @override
  String chatMonthDay(int month, int day) {
    return '$month 月 $day 日';
  }

  @override
  String get chatMyMessages => '我的消息';

  @override
  String get chatNewSessionOpened => '已打开新会话';

  @override
  String get chatNewWorktreeDescription => '创建新的 Git 工作树';

  @override
  String get chatNoActiveTurnQueued => '当前没有进行中的回复，已加入队列';

  @override
  String get chatNoConfigurableToolsets => '后端没有可配置的工具集';

  @override
  String get chatNoContextData => '暂无上下文数据';

  @override
  String get chatNoHandoffPlatforms => '没有可用的交接平台';

  @override
  String get chatNoHandoffPlatformsDescription => '尚未连接任何可交接的平台';

  @override
  String get chatNoMatchingCommands => '没有匹配的命令';

  @override
  String get chatNoMatchingMessages => '没有匹配的消息';

  @override
  String get chatNoProfiles => '后端没有可切换的配置档';

  @override
  String get chatNoQueuedMessages => '队列中没有消息';

  @override
  String get chatNoRetryMessage => '没有可重试的消息';

  @override
  String get chatNoSavedPrompts => '还没有保存的提示词';

  @override
  String get chatNoSessions => '暂无会话';

  @override
  String get chatNoText => '无文本内容';

  @override
  String get chatNoUploadableFolderFiles => '文件夹中没有可上传的文件';

  @override
  String get chatNotConfigured => '未配置';

  @override
  String get chatNotConnected => '未连接';

  @override
  String get chatOlderMessagesLoadFailed => '更早消息加载失败，点击重试';

  @override
  String chatPendingRequests(String kind, int count) {
    return '$kind（还有 $count 项待处理）';
  }

  @override
  String chatPlanProgress(int completed, int total) {
    return '$completed/$total 项已完成';
  }

  @override
  String chatPreviewCount(int count) {
    return '$count 个预览';
  }

  @override
  String chatProfileSwitchFailed(String error) {
    return '切换配置档失败：$error';
  }

  @override
  String chatProfileSwitched(String profile) {
    return '已切换到「$profile」';
  }

  @override
  String chatProfilesLoadFailed(String error) {
    return '加载配置档失败：$error';
  }

  @override
  String get chatPromptSaved => '提示词已保存';

  @override
  String get chatProvider => '服务商';

  @override
  String get chatQueue => '队列';

  @override
  String chatQueueFailed(String error) {
    return '加入队列失败：$error';
  }

  @override
  String get chatQueuePaused => '队列已暂停';

  @override
  String chatQueueSummary(String label, int count, String expandLabel) {
    return '$label $count 条 · 点击$expandLabel';
  }

  @override
  String get chatQueueUsage => '请输入要加入队列的内容';

  @override
  String get chatQueued => '已加入队列';

  @override
  String get chatQueuedMessageUpdated => '队列消息已更新';

  @override
  String chatQueuedMinutesAgo(int minutes) {
    return '$minutes 分钟前加入队列';
  }

  @override
  String chatQueuedSecondsAgo(int seconds) {
    return '$seconds 秒前加入队列';
  }

  @override
  String get chatReasoningEffort => '推理强度';

  @override
  String get chatReasoningEffortDescription => '写回后端 reasoning effort 配置';

  @override
  String chatReasoningEffortSet(String value) {
    return '推理强度已设为 $value';
  }

  @override
  String chatReasoningEffortSetFailed(String error) {
    return '设置推理强度失败：$error';
  }

  @override
  String get chatReconnecting => '正在重连';

  @override
  String get chatRegenerate => '重新生成';

  @override
  String chatRegenerateFailed(String error) {
    return '重新生成失败：$error';
  }

  @override
  String get chatRegenerateTitle => '重新生成标题';

  @override
  String chatRegenerateTitleFailed(String error) {
    return '重新生成标题失败：$error';
  }

  @override
  String get chatRename => '重命名';

  @override
  String get chatRenameSession => '重命名会话';

  @override
  String get chatRequestApproval => '审批请求';

  @override
  String get chatRequestMcpConfig => 'MCP 配置请求';

  @override
  String get chatRequestPassword => '密码请求';

  @override
  String get chatRequestQuestion => '提问请求';

  @override
  String get chatRequestSecret => '密钥请求';

  @override
  String get chatRequestTerminalInput => '终端输入请求';

  @override
  String get chatRestoreAndRerun => '恢复并重新运行';

  @override
  String chatRestoreFailed(String error) {
    return '恢复失败：$error';
  }

  @override
  String get chatRestoreToMessage => '恢复到此消息';

  @override
  String get chatRestoreToMessageTitle => '恢复到此消息？';

  @override
  String get chatRestoreVersionTitle => '恢复此版本？';

  @override
  String chatRetryFailed(String error) {
    return '重试失败：$error';
  }

  @override
  String get chatRunInBackground => '在后台运行';

  @override
  String get chatSaveCurrentInput => '保存当前输入';

  @override
  String chatSavePromptFailed(String error) {
    return '保存提示词失败：$error';
  }

  @override
  String get chatSavedPrompts => '已保存的提示词';

  @override
  String chatSavedPromptsLoadFailed(String error) {
    return '加载已保存的提示词失败：$error';
  }

  @override
  String get chatScrollToBottom => '回到底部';

  @override
  String get chatSearchLoadedHistory => '搜索已加载的历史记录';

  @override
  String chatSelectFilesFailed(String error) {
    return '选择文件失败：$error';
  }

  @override
  String get chatSelectFolder => '选择文件夹';

  @override
  String chatSelectFolderFailed(String error) {
    return '选择文件夹失败：$error';
  }

  @override
  String get chatSelectProfile => '选择配置档';

  @override
  String get chatSelectProfileDescription => '选择首页数据与后续启动使用的配置档';

  @override
  String get chatSendDiagnostics => '发送诊断信息';

  @override
  String get chatSendEdit => '发送编辑';

  @override
  String get chatSendEditAndRerun => '发送编辑并重新运行';

  @override
  String get chatSendEditTitle => '发送编辑？';

  @override
  String chatSendFailed(String error) {
    return '发送失败：$error';
  }

  @override
  String get chatSendNow => '立即发送';

  @override
  String get chatSendQueue => '发送队列';

  @override
  String chatSendQueueCount(int count) {
    return '发送队列 ($count)';
  }

  @override
  String get chatServerCatalog => '服务器目录';

  @override
  String get chatServerDirectory => '服务器目录';

  @override
  String get chatServerDirectoryHelp => '目录必须存在，并且服务端账户具有访问权限';

  @override
  String get chatServerNotConnected => '服务器未连接';

  @override
  String get chatSessionCleared => '会话已清空';

  @override
  String get chatSessionIdCopied => '会话 ID 已复制';

  @override
  String get chatSessionInfo => '会话信息';

  @override
  String get chatSessionMenu => '会话菜单';

  @override
  String get chatSessionShareLinkCopied => '会话分享链接已复制';

  @override
  String get chatSessionToolsetsDescription => '会话级工具集（仅当前会话生效）';

  @override
  String get chatSessions => '会话';

  @override
  String get chatSetAsNext => '设为下一条';

  @override
  String chatSetTitleFailed(String error) {
    return '设置标题失败：$error';
  }

  @override
  String chatShareLinkFailed(String error) {
    return '获取分享链接失败：$error';
  }

  @override
  String get chatShareUrlMissing => '未获取到分享链接';

  @override
  String get chatSkillsCenter => '技能中心';

  @override
  String get chatSlashCommands => '斜杠命令';

  @override
  String get chatStartSessionBeforeWorkspace => '请先开始一个会话再切换工作区';

  @override
  String get chatStarterDebugIssue => '帮我定位问题';

  @override
  String get chatStarterDebugIssuePrompt => '我遇到了一个问题，请先帮我梳理定位思路。';

  @override
  String get chatStarterExplainProject => '解释这个项目';

  @override
  String get chatStarterExplainProjectPrompt => '请帮我快速介绍这个项目的结构、核心功能和运行方式。';

  @override
  String get chatStarterReviewChanges => '检查当前改动';

  @override
  String get chatStarterReviewChangesPrompt => '请检查当前工作区的改动，指出潜在问题并给出改进建议。';

  @override
  String get chatSteerCurrentTurn => '引导当前回合';

  @override
  String get chatSteerHint => '引导内容';

  @override
  String get chatSteerInjected => '引导消息已注入当前回合';

  @override
  String get chatSteerMessage => '引导消息';

  @override
  String chatSteerNowFailed(String error) {
    return '立即引导失败：$error';
  }

  @override
  String get chatSteerQueued => '引导内容已加入队列';

  @override
  String get chatSteerUsage => '请输入要引导的内容';

  @override
  String get chatStopProcess => '停止进程';

  @override
  String chatStopProcessFailed(String error) {
    return '停止进程失败：$error';
  }

  @override
  String chatSubagentCount(int count) {
    return '$count 个子代理';
  }

  @override
  String get chatTextSnippet => '文本片段';

  @override
  String get chatTextSnippetHint => '粘贴或输入文本';

  @override
  String get chatTitle => 'Hermes 聊天';

  @override
  String chatTitleSet(String title) {
    return '标题已设为「$title」';
  }

  @override
  String get chatTitleUnchanged => '标题未更改';

  @override
  String chatTitleUpdated(String title) {
    return '标题已更新为「$title」';
  }

  @override
  String get chatToday => '今天';

  @override
  String get chatToolConfiguration => '工具配置';

  @override
  String chatToolCount(int count) {
    return '$count 个工具';
  }

  @override
  String get chatToolStatusMessage => '工具状态消息';

  @override
  String chatToolsetCounts(String sessionCount, String globalCount) {
    return '当前会话工具集：$sessionCount；全局 CLI 工具集：$globalCount';
  }

  @override
  String chatToolsetToggleFailed(String name, String error) {
    return '切换 $name 失败：$error';
  }

  @override
  String chatToolsetsEnabled(String globalCount) {
    return '工具集：$globalCount 已启用';
  }

  @override
  String get chatToolsetsExplanation =>
      '当前会话工具集：Hermes Agent 在本次会话运行时实际注册并可使用的工具集。\n全局 CLI 工具集：Hermes CLI 全局配置中可配置及已启用的工具集，不代表当前会话已全部加载。';

  @override
  String get chatToolsetsLoadFailed => '加载工具集失败';

  @override
  String chatTopicNumber(int index) {
    return '话题 $index';
  }

  @override
  String chatTopicRailSemantics(int count) {
    return '$count 个话题';
  }

  @override
  String get chatTranscriptLoadFailed => '聊天记录加载失败';

  @override
  String get chatTruncateWarning => '这将删除后续所有消息，且无法恢复';

  @override
  String chatUndoFailed(String error) {
    return '撤销失败：$error';
  }

  @override
  String get chatUnknownCommandResult => '未知的命令结果';

  @override
  String get chatUnknownTime => '未知时间';

  @override
  String get chatUnmarkMessage => '取消标记';

  @override
  String get chatUntitled => '未命名会话';

  @override
  String get chatUntitledSession => '未命名会话';

  @override
  String get chatVersion => '版本信息';

  @override
  String chatVersionCount(int count) {
    return '$count 个版本';
  }

  @override
  String chatVersionLoadFailed(String error) {
    return '加载版本失败：$error';
  }

  @override
  String chatVersionNumber(int index) {
    return '版本 $index';
  }

  @override
  String get chatViewBilling => '查看账单';

  @override
  String get chatViewCleared => '视图已清空';

  @override
  String get chatWakeServiceUnavailable => '唤醒词服务不可用';

  @override
  String chatWakeVoiceFailed(String error) {
    return '语音唤醒失败：$error';
  }

  @override
  String chatWarning(String warning) {
    return '警告：$warning';
  }

  @override
  String get chatWorkingDirectory => '工作目录';

  @override
  String get chatWorkspace => '工作区';

  @override
  String get chatWorkspaceFiles => '工作区文件';

  @override
  String chatWorkspaceSwitchFailed(String error) {
    return '切换工作区失败：$error';
  }

  @override
  String chatWorkspaceSwitched(String name) {
    return '工作区已切换到 $name';
  }

  @override
  String get chatYesterday => '昨天';

  @override
  String get chatYoloDisabled => '已关闭 YOLO 模式';

  @override
  String get chatYoloEnabled => '已开启 YOLO 模式';

  @override
  String get chatYoloMode => 'YOLO 模式';

  @override
  String chatYoloToggleFailed(String error) {
    return '切换 YOLO 模式失败：$error';
  }

  @override
  String get appSessionCompletedTitle => '会话已完成';

  @override
  String get appSessionCompletedBody => '后台会话已完成，点击查看结果';

  @override
  String appOpenNotificationFailed(Object error) {
    return '打开通知会话失败：$error';
  }

  @override
  String get deepLinkPluginInstallTitle => '安装 Hermes 插件';

  @override
  String get deepLinkPluginInstallPrompt => '此链接请求从以下来源安装后端插件：';

  @override
  String get deepLinkLegacyPluginWarning =>
      '这是旧版 Desktop 插件链接；移动端仅安装其后端 Agent 能力。';

  @override
  String get deepLinkEnableAfterInstall => '安装后启用';

  @override
  String get deepLinkForceReinstall => '强制重新安装';

  @override
  String get deepLinkInstall => '安装';

  @override
  String deepLinkPluginInstalling(Object identifier) {
    return '正在安装 $identifier…';
  }

  @override
  String get deepLinkPluginInstalled => '插件已安装';

  @override
  String deepLinkPluginInstallFailed(Object error) {
    return '插件安装失败：$error';
  }

  @override
  String get deepLinkMcpAddTitle => '添加 MCP 服务器';

  @override
  String get deepLinkMcpServerName => '服务器名称';

  @override
  String get deepLinkMcpNameFormatError => '仅允许 1–64 位字母、数字、点、下划线和连字符';

  @override
  String get deepLinkMcpNameConflict => '该名称已存在，请使用其他名称';

  @override
  String get deepLinkMcpCommandWarning => '此配置会在 Hermes 后端执行本地命令。请仅确认你信任的来源。';

  @override
  String get deepLinkConfigPreview => '配置预览';

  @override
  String deepLinkMcpAdded(Object name) {
    return 'MCP 服务器 $name 已添加';
  }

  @override
  String deepLinkMcpAddFailed(Object error) {
    return 'MCP 添加失败：$error';
  }

  @override
  String get commonAdd => '添加';

  @override
  String get commonAll => '全部';

  @override
  String get commonAuthorize => '授权';

  @override
  String get commonBack => '返回';

  @override
  String get commonCancel => '取消';

  @override
  String get commonCancelAll => '全部取消';

  @override
  String get commonClose => '关闭';

  @override
  String get commonCollapse => '收起';

  @override
  String get commonCompleted => '已完成';

  @override
  String get commonConfirm => '确定';

  @override
  String get commonConnected => '已连接';

  @override
  String get commonContinue => '继续';

  @override
  String get commonCopied => '已复制';

  @override
  String get commonCreate => '创建';

  @override
  String get commonDefault => '默认';

  @override
  String get commonDelete => '删除';

  @override
  String get commonDisconnect => '断开连接';

  @override
  String get commonDisconnected => '未连接';

  @override
  String get commonDone => '已完成';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonErrorTitle => '出错了';

  @override
  String get commonAuthenticationFailed => '认证失败，请检查 API 密钥';

  @override
  String get commonExpand => '展开';

  @override
  String get commonFile => '文件';

  @override
  String get commonFolder => '文件夹';

  @override
  String get commonGotIt => '知道了';

  @override
  String get commonHide => '隐藏';

  @override
  String get commonIdle => '空闲';

  @override
  String get commonIgnore => '忽略';

  @override
  String get commonLater => '稍后';

  @override
  String get commonListSeparator => '，';

  @override
  String get commonLoading => '加载中…';

  @override
  String get commonManage => '管理';

  @override
  String get commonMore => '更多';

  @override
  String get commonName => '名称';

  @override
  String get commonNew => '新建';

  @override
  String get commonNext => '下一个';

  @override
  String get commonNoMatches => '没有匹配结果';

  @override
  String get commonNotifications => '通知';

  @override
  String get commonOffline => '离线';

  @override
  String get commonOnline => '在线';

  @override
  String get commonOperationFailed => '操作失败，请稍后重试';

  @override
  String get commonNetworkFailed => '无法连接服务器，请检查网络和服务器状态';

  @override
  String get commonOpen => '打开';

  @override
  String get commonPrevious => '上一个';

  @override
  String get commonProcessing => '处理中…';

  @override
  String get commonReauthorize => '重新授权';

  @override
  String get commonRefresh => '刷新';

  @override
  String get commonReload => '重新加载';

  @override
  String get commonReset => '重置';

  @override
  String get commonRestart => '重启';

  @override
  String get commonRetry => '重试';

  @override
  String get commonRun => '运行';

  @override
  String get commonRunning => '运行中';

  @override
  String get commonSave => '保存';

  @override
  String get commonSearch => '搜索';

  @override
  String get commonSelect => '选择';

  @override
  String get commonSend => '发送';

  @override
  String get commonStop => '停止';

  @override
  String get commonSubmit => '提交';

  @override
  String get commonSwitch => '切换';

  @override
  String get commonTitle => '标题';

  @override
  String get commonUndo => '撤销';

  @override
  String get commonUnknownError => '未知错误';

  @override
  String get commonViewAll => '查看全部';

  @override
  String get configAppliesToProfile => '作用于 Profile';

  @override
  String get configConnectionLabel => '连接';

  @override
  String get configCurrentProfile => '当前 Profile';

  @override
  String get configDefaultProcessProfile => '默认 / 进程 Profile';

  @override
  String configDeleteFailed(String error) {
    return '删除覆盖失败：$error';
  }

  @override
  String get configFullJson => '完整 JSON';

  @override
  String configInvalidFieldValue(String path, String error) {
    return '$path 的值无效：$error';
  }

  @override
  String configInvalidJson(String error) {
    return 'JSON 无效：$error';
  }

  @override
  String get configListJsonError => '值必须是 JSON array';

  @override
  String get configLoading => '正在读取配置与 schema…';

  @override
  String get configNoMatches => '没有匹配字段';

  @override
  String get configObjectJsonError => '值必须是 JSON object';

  @override
  String get configRemoveOverride => '删除覆盖并使用默认值';

  @override
  String get configRestore => '恢复';

  @override
  String get configRestoreDefaults => '恢复默认';

  @override
  String configRestoreDefaultsDescription(String profile) {
    return '作用于$profile。现有自定义值将被默认值覆盖。';
  }

  @override
  String get configRestoreDefaultsQuestion => '恢复 Hermes 默认配置？';

  @override
  String configSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get providerEndpointValidationFailed => '端点验证失败';

  @override
  String get kanbanMoveSelected => '移动选中的任务';

  @override
  String get kanbanClearSelection => '清除任务选择';

  @override
  String get configSearchHint => '搜索配置字段…';

  @override
  String configServerDidNotDelete(String path) {
    return '服务器没有删除 $path';
  }

  @override
  String get configServerMismatch => '服务器返回内容与提交的完整配置不一致';

  @override
  String configServerRejected(String path) {
    return '服务器未接受 $path；界面已恢复服务器值。';
  }

  @override
  String get configTitle => '模型与对话';

  @override
  String get configTopLevelObject => '顶层 JSON 值必须是 object';

  @override
  String get configUseDefault => '默认';

  @override
  String get connectAction => '连接';

  @override
  String get connectAddHeader => '添加请求头';

  @override
  String get connectAllowPublicHttp => '允许公网 HTTP 明文连接';

  @override
  String get connectAllowPublicHttpWarning => '仅用于无法启用 HTTPS 的受信网络；令牌可能被截获';

  @override
  String get connectApiKey => 'API 密钥';

  @override
  String get connectConfiguration => '连接配置';

  @override
  String get connectConnecting => '连接中…';

  @override
  String get connectCredentialRequired => '请输入访问凭证';

  @override
  String get connectDeleteHeader => '删除请求头';

  @override
  String get connectDeleteProfile => '删除配置';

  @override
  String get connectDiscoverCloud => '从 Hermes Cloud 发现 Agent';

  @override
  String get connectExtraHeaders => '附加请求头';

  @override
  String get connectHeaderManaged => '由 Hermes 管理';

  @override
  String get connectHeaderName => 'Header 名称';

  @override
  String get connectHeaderNameInvalid => '名称无效';

  @override
  String get connectHeaderValue => '值';

  @override
  String get connectHeaderValueRequired => '请输入值';

  @override
  String get connectHeadersDescription => '用于访问代理，可选；值会存入系统安全存储。';

  @override
  String get connectHideKey => '隐藏密钥';

  @override
  String get connectHidePassphrase => '隐藏口令';

  @override
  String get connectHidePassword => '隐藏密码';

  @override
  String get connectHidePrivateKey => '隐藏私钥';

  @override
  String get connectHideValue => '隐藏';

  @override
  String get connectHttpsRequired => '公网连接必须使用 HTTPS，或明确允许不安全连接';

  @override
  String get connectNativeCleartextRestricted =>
      'Release 版本仅允许 localhost 或 .local companion 名称使用明文 HTTP；请改用 HTTPS 或 .local 主机名。';

  @override
  String get connectNotSignedIn => '尚未登录';

  @override
  String get connectOauthSignedIn => 'OAuth 已登录';

  @override
  String get connectPkceUnavailable =>
      '此 Gateway 未提供 native_pkce 登录，请更新 Hermes 或改用 Token。';

  @override
  String get connectPort => '端口';

  @override
  String get connectPrivateKey => 'OpenSSH / PEM 私钥';

  @override
  String get connectPrivateKeyPassphrase => '私钥口令（可选）';

  @override
  String get connectProfileName => '配置名称（默认用主机名）';

  @override
  String get connectProfileNameInvalid => 'Profile 名称无效';

  @override
  String get connectRemoteHermesPath => '远端 Hermes 路径（自动发现）';

  @override
  String get connectRemoteProfile => '远端 Profile（可选）';

  @override
  String get connectSaveProfile => '保存为服务器配置';

  @override
  String get connectSaveProfileDescription => '下次可从列表一键切换';

  @override
  String get connectSavedBackends => '已保存后端';

  @override
  String get connectServerAddress => '服务器地址';

  @override
  String get connectServerInvalid => '请输入有效的 HTTP(S) 地址';

  @override
  String get connectServerRequired => '请输入服务器地址';

  @override
  String get connectShowKey => '显示密钥';

  @override
  String get connectShowPassphrase => '显示口令';

  @override
  String get connectShowPassword => '显示密码';

  @override
  String get connectShowPrivateKey => '显示私钥';

  @override
  String get connectShowValue => '显示';

  @override
  String get connectSignIn => '登录';

  @override
  String get connectSignInAgain => '重新登录';

  @override
  String get connectSshCredentialRequired => '请输入私钥或密码';

  @override
  String get connectSshHost => 'SSH 主机';

  @override
  String get connectSshHostRequired => '请输入 SSH 主机';

  @override
  String get connectSshPassword => 'SSH 密码（可选）';

  @override
  String get connectSshUser => 'SSH 用户';

  @override
  String get connectSshUserRequired => '请输入 SSH 用户';

  @override
  String get connectTitle => '连接';

  @override
  String get connectUnableServer => '无法连接服务器';

  @override
  String get connectValidationFailed => '连接验证失败，请检查服务器地址和 API 密钥';

  @override
  String get connectValidationNetworkFailed => '连接验证失败，请检查服务器地址、API 密钥和网络状态';

  @override
  String dateMonthDay(int month, int day) {
    return '$month 月 $day 日';
  }

  @override
  String get dateToday => '今天';

  @override
  String get dateYesterday => '昨天';

  @override
  String get discordCommunityTitle => '加入 Discord 社区';

  @override
  String get featureAbout => '关于';

  @override
  String get featureAboutDesc => '版本信息';

  @override
  String get featureAgent => '机器人';

  @override
  String get featureAgentDesc => '机器人、群聊与运行状态';

  @override
  String get featureArtifacts => 'Artifacts';

  @override
  String get featureArtifactsDesc => '会话产出物';

  @override
  String get featureBilling => '账单';

  @override
  String get featureBillingDesc => '用量、套餐与发票';

  @override
  String get featureCommandCenter => '命令中心';

  @override
  String get featureCommandCenterDesc => '实时状态与日志';

  @override
  String get featureConnection => '连接';

  @override
  String get featureConnectionDesc => '多后端 Profile';

  @override
  String get featureCredentials => '凭证';

  @override
  String get featureCredentialsDesc => '第三方账号与密钥';

  @override
  String get featureCron => '定时任务';

  @override
  String get featureCronDesc => 'Cron 计划任务';

  @override
  String get featureFiles => '文件';

  @override
  String get featureFilesDesc => '浏览工作目录';

  @override
  String get featureGit => 'Git';

  @override
  String get featureGitDesc => '变更、提交与分支';

  @override
  String get featureGlobalSearchDesc => '搜索命令、会话与页面';

  @override
  String get featureInsights => '洞察分析';

  @override
  String get featureInsightsDesc => '用量与成本趋势';

  @override
  String get featureMcp => 'MCP';

  @override
  String get featureMcpDesc => 'MCP 服务器配置';

  @override
  String get featureMemory => '记忆';

  @override
  String get featureMemoryDesc => '长期记忆管理';

  @override
  String get featureMessaging => '消息平台';

  @override
  String get featureMessagingDesc => 'Telegram、Discord 与其他平台';

  @override
  String get featureNotificationsDesc => '通知中心';

  @override
  String get featurePet => '宠物';

  @override
  String get featurePetDesc => '伴侣养成与收藏';

  @override
  String get featurePlugins => '插件';

  @override
  String get featurePluginsDesc => '插件管理';

  @override
  String get featureProfiles => 'Profiles';

  @override
  String get featureProfilesDesc => '模型执行档案';

  @override
  String get featureProjects => '项目';

  @override
  String get featureProjectsDesc => '多项目会话分组';

  @override
  String get featureSettings => '设置';

  @override
  String get featureSettingsDesc => '外观与常规';

  @override
  String get featureSkills => '技能';

  @override
  String get featureSkillsDesc => '技能中心';

  @override
  String get featureStarmap => '知识星图';

  @override
  String get featureStarmapDesc => '关键词知识图谱';

  @override
  String get featureSubagents => '子代理';

  @override
  String get featureSubagentsDesc => '后台代理活动树';

  @override
  String get featureTerminal => '终端';

  @override
  String get featureTerminalDesc => '命令行交互';

  @override
  String get featureTools => '工具集';

  @override
  String get featureToolsDesc => '工具与密钥';

  @override
  String get featureWebhooks => 'Webhooks';

  @override
  String get featureWebhooksDesc => '事件推送';

  @override
  String gitAgentShipFailed(Object error) {
    return 'Agent Ship 失败：$error';
  }

  @override
  String get gitAgentShipPrompt => '检查当前更改，使用清晰的约定式提交信息提交，推送分支，并开启一个拉取请求。';

  @override
  String get gitAgentShipQuestion => '让 Agent 提交并推送更改，并创建 PR？';

  @override
  String get gitAgentShipSent => '已将提交并创建 PR 的任务发送给 Hermes';

  @override
  String get gitAuthor => '作者';

  @override
  String gitAuthorMeta(Object author) {
    return '作者：$author';
  }

  @override
  String get gitBaseBranch => '基于分支';

  @override
  String gitBranchMeta(Object branch) {
    return '分支：$branch';
  }

  @override
  String get gitBranchesTab => '分支';

  @override
  String get gitChangeDirectory => '更换目录';

  @override
  String get gitChangedFiles => '更改文件';

  @override
  String get gitChangedFilesLabel => '变更文件：';

  @override
  String get gitChangesTab => '变更';

  @override
  String get gitCommit => '提交';

  @override
  String get gitCommitChanges => '提交更改';

  @override
  String get gitCommitDetails => '提交详情';

  @override
  String gitCommitFailed(Object error) {
    return '提交失败：$error';
  }

  @override
  String get gitCommitMessage => '提交信息';

  @override
  String get gitCommitsTab => '提交';

  @override
  String get gitCreatePr => '创建 PR';

  @override
  String gitCreatePrFailed(Object error) {
    return '创建 PR 失败：$error';
  }

  @override
  String get gitCreatePrQuestion => '使用当前分支通过 GitHub CLI 创建或打开拉取请求？';

  @override
  String gitCreateWorktreeFailed(Object error) {
    return '创建 worktree 失败：$error';
  }

  @override
  String get gitCurrent => '当前';

  @override
  String gitDeleteWorktreeDescription(Object path) {
    return '将删除工作目录 $path 及其未提交的更改。此操作不可恢复。';
  }

  @override
  String gitDeleteWorktreeFailed(Object error) {
    return '删除 worktree 失败：$error';
  }

  @override
  String get gitDeleteWorktreeQuestion => '删除 worktree？';

  @override
  String get gitDetachedHead => '（游离 HEAD）';

  @override
  String gitDiffLoadFailed(Object error) {
    return '加载 diff 失败：$error';
  }

  @override
  String get gitEndOfLog => '— 到底了 —';

  @override
  String get gitForceDelete => '强制删除';

  @override
  String get gitForceDeleteWorktreeQuestion => '是否强制删除并丢弃这些更改？';

  @override
  String get gitGenerateCommitMessage => '生成提交信息';

  @override
  String gitGenerateMessageFailed(Object error) {
    return '生成提交信息失败：$error';
  }

  @override
  String get gitGithubCliUnavailable => '后端尚未安装 GitHub CLI，或尚未完成登录';

  @override
  String gitHoursAgo(Object count) {
    return '$count 小时前';
  }

  @override
  String get gitJustNow => '刚刚';

  @override
  String gitLoadMore(Object loaded, Object total) {
    return '加载更多 ($loaded/$total)';
  }

  @override
  String get gitLoadingBranches => '加载分支…';

  @override
  String get gitLoadingLog => '加载提交日志…';

  @override
  String get gitLoadingStatus => '读取仓库状态…';

  @override
  String get gitLocalBranches => '本地分支';

  @override
  String gitLogLoadFailed(Object error) {
    return '加载提交日志失败：$error';
  }

  @override
  String get gitMainWorktree => '主';

  @override
  String gitMinutesAgo(Object count) {
    return '$count 分钟前';
  }

  @override
  String get gitNewWorktree => '新建 Worktree';

  @override
  String get gitNoAdditionalWorktrees => '没有额外的 worktree';

  @override
  String get gitNoBranches => '没有可用分支';

  @override
  String get gitNoBranchesDescription => '请选择一个 Git 仓库后重试。';

  @override
  String get gitNoCommits => '暂无提交记录';

  @override
  String get gitNoCommitsDescription => '该仓库还没有提交，或当前筛选条件无匹配';

  @override
  String get gitNoDiff => '无差异';

  @override
  String get gitNoDiffDescription => '该文件与 HEAD 没有差异';

  @override
  String get gitNoMatchingBranches => '没有匹配的分支';

  @override
  String get gitNoStashes => '没有贮藏记录';

  @override
  String get gitNoVisibleRemotes => '没有可见远程仓库';

  @override
  String get gitNotRepository => '不是 Git 仓库';

  @override
  String gitNotRepositoryDescription(Object path) {
    return '$path\n\n点击下方按钮更换目录';
  }

  @override
  String get gitOpenInNewSession => '在新会话中打开';

  @override
  String gitOpenPr(Object number) {
    return '打开 PR #$number';
  }

  @override
  String gitOpenedInNewSession(Object path) {
    return '已在新会话中打开 $path';
  }

  @override
  String get gitParent => '父提交';

  @override
  String get gitPrCreated => 'PR 已创建';

  @override
  String gitPrNumber(Object number) {
    return '编号：#$number';
  }

  @override
  String get gitPushAfterCommit => '提交后推送';

  @override
  String gitPushAction(Object count) {
    return '推送 $count 个提交';
  }

  @override
  String get gitPushSucceeded => '已推送到远程';

  @override
  String gitPushFailed(Object error) {
    return '推送失败：$error';
  }

  @override
  String get gitRecentRepositories => '最近仓库';

  @override
  String get gitRemotes => '远程仓库';

  @override
  String get gitRemotesAndStashes => '远程与贮藏';

  @override
  String get gitRepositoryDirectory => '仓库目录';

  @override
  String get gitRevert => '还原';

  @override
  String get gitRevertAll => '全部还原';

  @override
  String get gitRevertAllDescription => '将丢弃工作区中的全部未提交更改，此操作不可撤销。';

  @override
  String get gitRevertAllQuestion => '还原全部更改？';

  @override
  String gitRevertFailed(Object error) {
    return '还原失败：$error';
  }

  @override
  String get gitRevertFile => '还原此文件';

  @override
  String gitRevertFileDescription(Object file) {
    return '将丢弃“$file”的未提交更改，此操作不可撤销。';
  }

  @override
  String get gitRevertFileQuestion => '还原此文件？';

  @override
  String get gitSearchBranches => '搜索分支…';

  @override
  String get gitSearchCommits => '搜索提交信息';

  @override
  String get gitSelectFileForDiff => '选择文件查看 Diff';

  @override
  String get gitSelectFileForDiffDescription => '点击左侧变更文件在此查看差异';

  @override
  String get gitServerRepositoryPath => '服务端仓库路径';

  @override
  String get gitStage => '暂存';

  @override
  String gitStageFailed(Object error) {
    return '暂存操作失败：$error';
  }

  @override
  String gitStagedChanges(Object added, Object removed) {
    return '已暂存 · +$added −$removed';
  }

  @override
  String get gitStashes => '贮藏';

  @override
  String get gitSwitch => '切换';

  @override
  String get gitSwitchBranch => '切换分支';

  @override
  String gitSwitchBranchFailed(Object error) {
    return '切换分支失败：$error';
  }

  @override
  String get gitUnknownAuthor => '未知';

  @override
  String get gitUnstage => '取消暂存';

  @override
  String get gitWorkingTreeClean => '工作区干净，没有更改';

  @override
  String get gitWorktreeHasChanges => 'worktree 中有未提交的更改';

  @override
  String get gitWorktreeNameHint => '例如 feature-login';

  @override
  String get gitWorktrees => '工作区 (Worktree)';

  @override
  String get globalSearch => '全局搜索';

  @override
  String get groupConfiguration => '配置';

  @override
  String get groupIntegrations => '集成';

  @override
  String get groupIntelligence => '智能';

  @override
  String get groupSystem => '系统';

  @override
  String get groupWorkspace => '工作区';

  @override
  String get helpAndFeedbackTitle => '帮助与反馈';

  @override
  String get homeAllFeatures => '全部功能';

  @override
  String get homeAttentionDetail => '代理可能正在等待你的确认';

  @override
  String homeBackendSummary(String model, String profile) {
    return '后端已连接 · $model · Profile: $profile';
  }

  @override
  String homeContinueSession(String title) {
    return '继续「$title」';
  }

  @override
  String get homeContinueWork => '继续你的工作';

  @override
  String get homeCurrentWork => '当前工作';

  @override
  String get homeDefaultProfile => '默认';

  @override
  String get homeDragToReorder => '拖动排序';

  @override
  String get homeEditQuickTools => '编辑常用工具';

  @override
  String get homeLastVisibleTool => '首页展示区最后一项';

  @override
  String get homeLoadingRecent => '加载最近工作…';

  @override
  String get homeMoreTools => '更多工具';

  @override
  String homeNeedsAttention(int count) {
    return '$count 项需要处理';
  }

  @override
  String get homeNoWorkDescription => '在上方描述目标，开始第一项工作';

  @override
  String get homeNoWorkTitle => '还没有工作记录';

  @override
  String homeProfileTooltip(String profile) {
    return '配置档：$profile';
  }

  @override
  String get homeQuickTools => '常用工具';

  @override
  String get homeQuickToolsDescription => '前 5 项会直接显示在首页，其余工具收纳在“更多”中。';

  @override
  String get homeReadyTitle => 'Hermes 已就绪';

  @override
  String get homeRecentSessions => '最近会话';

  @override
  String get homeRestoreDefaults => '恢复默认';

  @override
  String get homeStartNewSession => '开始新会话';

  @override
  String get homeSwitchProfile => '切换配置档';

  @override
  String get homeToolKnowledge => '知识';

  @override
  String get homeViewAttentionSessions => '查看待处理会话';

  @override
  String get homeViewSession => '查看会话';

  @override
  String homeWorkingDetail(String model) {
    return '正在处理当前任务 · $model';
  }

  @override
  String get homeWorkingTitle => 'Hermes 正在工作';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageDescription => '选择 Hermes Mobile 使用的界面语言';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageSimplifiedChinese => '简体中文';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageTitle => '语言';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get legalPrivacy => '隐私政策';

  @override
  String get legalTerms => '服务条款';

  @override
  String get legalTitle => '法律与许可';

  @override
  String get modelAllFollowMain => '全部跟随主模型';

  @override
  String get modelApply => '应用';

  @override
  String modelAuxiliarySaveFailed(String error) {
    return '辅助模型保存失败：$error';
  }

  @override
  String get modelAuxiliaryTitle => '辅助模型';

  @override
  String get modelAuxiliaryUnavailable => '当前 Hermes 后端未提供辅助模型配置接口。';

  @override
  String get modelChoose => '选择模型';

  @override
  String get modelConfirmSelection => '确认模型选择';

  @override
  String get modelCreate => '创建';

  @override
  String get modelCurrent => '使用中';

  @override
  String get modelDefaultTitle => '默认模型';

  @override
  String get modelExpensiveWarning => '该模型可能产生较高费用，是否继续？';

  @override
  String get modelFallbackHint => 'fallback_providers（每行一个 provider:model）';

  @override
  String get modelFallbackTitle => '回退模型';

  @override
  String get modelFollowMain => '跟随主模型';

  @override
  String get modelLabel => '模型';

  @override
  String get modelMoaAddReference => '添加参考模型';

  @override
  String get modelMoaAggregator => '聚合器';

  @override
  String get modelMoaAggregatorMaxTokens => '聚合输出上限';

  @override
  String get modelMoaAggregatorModel => '聚合模型';

  @override
  String modelMoaAggregatorSummary(String provider, String model) {
    return '聚合器：$provider · $model';
  }

  @override
  String get modelMoaAggregatorTemperature => '聚合温度';

  @override
  String get modelMoaCompleteModels => '请补全所有模型';

  @override
  String get modelMoaCreatePreset => '新建 MoA preset';

  @override
  String get modelMoaCreateTooltip => '新建 preset';

  @override
  String get modelMoaDefaultPreset => '默认 preset';

  @override
  String get modelMoaDegradedLoud => '提示降级';

  @override
  String get modelMoaDegradedPolicy => '降级策略';

  @override
  String get modelMoaDegradedSilent => '静默降级';

  @override
  String get modelMoaDeleteTooltip => '删除 preset';

  @override
  String get modelMoaDescription => '参考模型并行回答，聚合器生成最终结果';

  @override
  String get modelMoaEditConfiguration => '编辑配置';

  @override
  String modelMoaEditTitle(String name) {
    return '编辑 $name';
  }

  @override
  String get modelMoaEnablePreset => '启用 preset';

  @override
  String get modelMoaFanoutCadence => 'Fanout cadence';

  @override
  String get modelMoaFanoutHint => 'user_turn / per_iteration / every_n:2';

  @override
  String get modelMoaNoEditable => '没有可编辑的 MoA preset。';

  @override
  String get modelMoaPresetLabel => 'Preset';

  @override
  String modelMoaReferenceCount(int count) {
    return '$count 个参考模型';
  }

  @override
  String get modelMoaReferenceMaxTokens => '参考输出上限';

  @override
  String get modelMoaReferenceModels => '参考模型';

  @override
  String modelMoaReferenceNumber(int index) {
    return '参考 $index';
  }

  @override
  String get modelMoaReferenceTemperature => '参考温度';

  @override
  String get modelMoaReferenceTimeout => '参考超时（秒）';

  @override
  String get modelMoaRuntimeParameters => '运行参数';

  @override
  String get modelMoaSaveConfiguration => '保存配置';

  @override
  String modelMoaSaveFailed(String error) {
    return 'MoA 保存失败：$error';
  }

  @override
  String get modelMoaSetDefault => '设为默认';

  @override
  String get modelMoaUnavailable => '当前 Hermes 后端未提供 MoA 配置接口。';

  @override
  String get modelNoAvailable => '暂无可用模型';

  @override
  String get modelPresetName => '名称';

  @override
  String get modelProvider => '提供商';

  @override
  String get modelProviderNotFound => '找不到模型对应的提供商';

  @override
  String modelRecommended(String model) {
    return '推荐: $model';
  }

  @override
  String get modelRemove => '移除';

  @override
  String get modelSwitchDeferred => '模型切换已排队，将在当前回合完成后生效';

  @override
  String modelSwitchFailed(String error) {
    return '切换模型失败：$error';
  }

  @override
  String modelSwitchSucceeded(String model) {
    return '已切换到 $model';
  }

  @override
  String get moreCloseSearch => '关闭目录搜索';

  @override
  String get moreNoMatches => '没有匹配的功能';

  @override
  String get moreSearchDirectory => '搜索目录';

  @override
  String get moreSearchHint => '搜索功能';

  @override
  String moreStatus(String connection, String agent) {
    return '$connection · Agent $agent';
  }

  @override
  String get navHome => '首页';

  @override
  String get navMore => '更多';

  @override
  String get navSessions => '会话';

  @override
  String get navTasks => '任务';

  @override
  String get notificationClear => '清空';

  @override
  String get notificationClearConfirmTitle => '清空全部通知？';

  @override
  String get notificationClearConfirmBody => '此操作会移除列表中的所有通知，且无法撤销。';

  @override
  String get notificationEmptyDescription => 'Agent 完成、审批与异常事件会出现在这里';

  @override
  String get notificationEmptyTitle => '暂无通知';

  @override
  String get notificationMarkAllRead => '全部已读';

  @override
  String notificationOpenFailed(String error) {
    return '打开会话失败: $error';
  }

  @override
  String get notificationOpenSession => '查看会话';

  @override
  String get notificationTitle => '通知';

  @override
  String get paletteHint => '搜索页面、会话和命令…';

  @override
  String get paletteHintClose => '关闭';

  @override
  String get paletteHintNavigate => '选择';

  @override
  String get paletteHintOpen => '打开';

  @override
  String get paletteKanban => '看板';

  @override
  String get paletteKindAction => '操作';

  @override
  String get paletteKindCommand => '命令';

  @override
  String get paletteKindPage => '页面';

  @override
  String get paletteKindSession => '会话';

  @override
  String get paletteNewSessionDesc => '开始一个新的对话';

  @override
  String get paletteNoResults => '无匹配结果';

  @override
  String get paletteReconnect => '重新连接';

  @override
  String get paletteReconnectDesc => '重新连接到服务器';

  @override
  String get paletteVoiceInput => '语音输入';

  @override
  String get paletteVoiceInputDesc => '开始语音听写';

  @override
  String pluginActionFailed(String title, String error) {
    return '$title 执行失败：$error';
  }

  @override
  String get pluginFieldInvalidNumber => '请输入有效数字';

  @override
  String pluginFieldMaximum(num value) {
    return '最大值：$value';
  }

  @override
  String pluginFieldMinimum(num value) {
    return '最小值：$value';
  }

  @override
  String get pluginFieldRequired => '此字段为必填项';

  @override
  String pluginItemFallback(int index) {
    return '项目 $index';
  }

  @override
  String get pluginNoItems => '暂无项目';

  @override
  String get pluginResultCopied => '结果已复制';

  @override
  String get pluginResultCopy => '复制结果';

  @override
  String get pluginResultOpenLink => '打开链接';

  @override
  String get pluginSubmit => '提交';

  @override
  String previewActionSendFailed(String error) {
    return '预览操作发送失败：$error';
  }

  @override
  String previewActionSent(String prompt) {
    return '已发送预览操作：$prompt';
  }

  @override
  String get previewBack => '后退';

  @override
  String get previewClearConsole => '清空控制台';

  @override
  String get previewCloseConsole => '关闭控制台';

  @override
  String get previewConsoleTitle => 'Console';

  @override
  String get previewEmpty => '在聊天里打开链接，或选择 HTML 文件';

  @override
  String previewFailed(String error) {
    return '预览失败：$error';
  }

  @override
  String get previewForward => '前进';

  @override
  String get previewNoLogs => '暂无日志';

  @override
  String get previewOpenBrowser => '在浏览器打开';

  @override
  String get previewOpenConsole => '打开控制台';

  @override
  String previewOpenSessionFailed(String error) {
    return '无法打开会话：$error';
  }

  @override
  String get previewRefresh => '刷新预览';

  @override
  String get previewRunJavascript => '运行 JavaScript';

  @override
  String get previewRunScript => '运行脚本';

  @override
  String get previewTitle => '预览';

  @override
  String get previewUnsupportedWebView => '当前平台不支持内嵌 WebView，请用浏览器打开';

  @override
  String get projectBrowseFiles => '浏览项目目录';

  @override
  String get projectDetailTitle => '项目详情';

  @override
  String projectFolderCount(int count) {
    return '$count 个文件夹';
  }

  @override
  String get projectGitDescription => '查看仓库状态与更改';

  @override
  String get projectGlobalMemoryDescription => 'Profile 记忆（全局视图）';

  @override
  String get projectGlobalStarmapDescription => '知识图谱（全局视图）';

  @override
  String get projectGlobalSubagentsDescription => '所有会话的子代理活动';

  @override
  String get projectGlobalWebhooksDescription => 'Webhook 配置（全局视图）';

  @override
  String get projectLoadingSessions => '正在加载会话…';

  @override
  String get projectModulesTitle => '模块';

  @override
  String get projectNoKanbanBoard => '此项目没有关联看板';

  @override
  String get projectNoSessions => '没有相关会话';

  @override
  String get projectNoSessionsDescription => '在项目目录下开始的会话会显示在这里';

  @override
  String projectResumeFailed(String error) {
    return '恢复会话失败：$error';
  }

  @override
  String projectSessionCount(int count) {
    return '$count 个会话';
  }

  @override
  String get projectSessionsTitle => '会话';

  @override
  String get projectTasksDescription => '打开关联到此项目的看板';

  @override
  String get projectTasksTitle => '任务与看板';

  @override
  String get projectUnavailable => '不可用';

  @override
  String get projectUntitled => '未命名项目';

  @override
  String get providerActiveDefault => '活动 / 默认';

  @override
  String get providerAddEndpointTitle => '新建自定义端点';

  @override
  String get providerCustomEndpointJson => '自定义 endpoint JSON';

  @override
  String get providerCustomEndpointsSection => '自定义 Endpoints';

  @override
  String get providerDeviceAuthorization => '设备授权';

  @override
  String get providerEditEndpointTitle => '编辑自定义端点';

  @override
  String get providerEndpointApiKey => 'API Key';

  @override
  String get providerEndpointBaseUrl => 'Base URL';

  @override
  String get providerEndpointDefaultModel => '默认模型';

  @override
  String get providerEndpointDiscoverModels => '自动发现模型';

  @override
  String get providerEndpointFallback => 'Endpoint';

  @override
  String get providerEndpointModelsList => '可用模型（每行一个）';

  @override
  String get providerEndpointName => '名称';

  @override
  String get providerEndpointNameRequired => '请填写名称';

  @override
  String get providerEndpointUrlRequired => '请填写 Base URL';

  @override
  String providerEnterDeviceCode(String code) {
    return '在浏览器中输入验证码：$code';
  }

  @override
  String providerActionFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get providerEnvironmentSection => '环境变量';

  @override
  String get providerEnvironmentVariableName => '环境变量名称';

  @override
  String get providerEnvironmentVariableValue => '环境变量值';

  @override
  String providerMissingKeys(String keys) {
    return '缺少：$keys';
  }

  @override
  String providerModelTitle(String provider) {
    return '$provider 模型';
  }

  @override
  String get providerNoConfiguration => '暂无配置';

  @override
  String get providerNotSet => '未设置';

  @override
  String get providerOauthSection => 'Provider OAuth';

  @override
  String get providerPasteOauthCode => '粘贴 OAuth code';

  @override
  String get providerProfileLabel => 'Profile';

  @override
  String providerRevealFailed(String error) {
    return '读取失败：$error';
  }

  @override
  String get providerRevealValue => '查看明文';

  @override
  String get providerRevealedValueTitle => '已保存的值';

  @override
  String providerRunSetupDescription(String provider, String command) {
    return '$provider 需要运行：$command';
  }

  @override
  String get providerRunSetupQuestion => '运行 Provider 安装步骤？';

  @override
  String get providerSetActive => '设为当前';

  @override
  String providerSetEnvironmentVariable(String key) {
    return '设置 $key';
  }

  @override
  String providerToolsCount(int count) {
    return '$count 个工具';
  }

  @override
  String providerToolsetProviderTitle(String toolset) {
    return '$toolset Provider';
  }

  @override
  String get providerToolsetProvidersSection => 'Toolset Providers';

  @override
  String get pushEnabled => '远程通知';

  @override
  String get pushEnabledDescription => '向当前 Hermes 服务器注册此设备';

  @override
  String get pushOsPermissionDenied => '系统通知已被拦截';

  @override
  String get pushOsPermissionDeniedDescription =>
      'Hermes 内已开启远程通知，但系统层面禁止了通知权限，通知实际无法送达。请在设备系统设置中为 Hermes Mobile 开启通知权限。';

  @override
  String get pushNoProviders => '服务器尚未配置 APNs 或 FCM 凭证';

  @override
  String get pushNotRegistered => '尚未注册';

  @override
  String get pushProviders => '投递服务';

  @override
  String get pushRefresh => '刷新推送状态';

  @override
  String get pushRegistered => '已按当前连接和配置档注册';

  @override
  String get pushRegistration => '设备注册';

  @override
  String get pushSendTest => '发送测试通知';

  @override
  String get pushSettingsDescription => 'Hermes Mobile 关闭后仍可接收任务完成和审批请求。';

  @override
  String get pushSettingsTitle => '远程通知';

  @override
  String get pushTestDelivered => '测试通知已投递';

  @override
  String pushTestFailed(String error) {
    return '发送测试通知失败：$error';
  }

  @override
  String get pushTestNotDelivered => '没有投递服务成功发送测试通知';

  @override
  String get reportIssueTitle => '在 GitHub 上反馈问题';

  @override
  String get sendDiagnosticsSubtitle => '上传脱敏日志以帮助我们排查问题';

  @override
  String get sendDiagnosticsTitle => '发送诊断信息';

  @override
  String get sessionActions => '会话操作';

  @override
  String get sessionAllTags => '全部标签';

  @override
  String get sessionArchiveView => '归档视图';

  @override
  String get sessionArchiveViewDescription => '仅显示已归档的会话';

  @override
  String sessionBatchDeleteDescription(int count) {
    return '选中的 $count 个会话将被永久删除，此操作不可撤销。';
  }

  @override
  String get sessionBatchDeleteTitle => '批量删除会话？';

  @override
  String get sessionCancelSelection => '取消选择';

  @override
  String get sessionClearAll => '清除全部';

  @override
  String get sessionClearFilters => '清除筛选';

  @override
  String get sessionClearSearch => '清除搜索';

  @override
  String get sessionCollapseChildren => '收起子会话';

  @override
  String get sessionConfirmDelete => '确认删除';

  @override
  String get sessionContinueLast => '继续上次会话';

  @override
  String get sessionDeepSearchHint => '搜索会话标题和历史消息';

  @override
  String get sessionDeepSearchTitle => '聊天记录定位';

  @override
  String sessionDeleteDescription(String title) {
    return '「$title」将被永久删除。';
  }

  @override
  String sessionDeleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String get sessionDeleteSelected => '删除选中';

  @override
  String get sessionDeleteTitle => '删除会话？';

  @override
  String sessionDeletedCount(int count) {
    return '已删除 $count 个会话';
  }

  @override
  String sessionDurationDaysHours(int days, int hours) {
    return '$days天$hours时';
  }

  @override
  String sessionDurationHoursMinutes(int hours, int minutes) {
    return '$hours时$minutes分';
  }

  @override
  String sessionDurationMinutes(int minutes) {
    return '$minutes分';
  }

  @override
  String get sessionEmptyDescription => '新建会话开始与 Hermes 对话';

  @override
  String get sessionEmptyTitle => '还没有会话';

  @override
  String get sessionExpandChildren => '展开子会话';

  @override
  String get sessionFilterAll => '全部';

  @override
  String get sessionFilterApproval => '需审批';

  @override
  String get sessionFilterByTag => '按标签筛选';

  @override
  String get sessionFilterCompleted => '已完成';

  @override
  String get sessionFilterTitle => '筛选会话';

  @override
  String get sessionGroupArchived => '已归档';

  @override
  String get sessionGroupByProject => '项目分组';

  @override
  String get sessionGroupByTime => '时间分组';

  @override
  String get sessionGroupLast7Days => '过去 7 天';

  @override
  String get sessionGroupOlder => '更早';

  @override
  String get sessionGroupPinned => '置顶';

  @override
  String get sessionGroupRunning => '运行中';

  @override
  String sessionHandoff(String state) {
    return '交接 $state';
  }

  @override
  String get sessionHistoryArchive => '历史归档';

  @override
  String get sessionLoadMore => '加载更多会话';

  @override
  String get sessionManage => '会话管理';

  @override
  String sessionMessageCount(int count) {
    return '$count 条消息';
  }

  @override
  String get sessionNew => '新建会话';

  @override
  String get sessionNoMatchesDescription => '尝试调整搜索或状态筛选';

  @override
  String get sessionNoMatchesTitle => '没有匹配的会话';

  @override
  String get sessionNoProjectsDescription => '在 Git 仓库中开始的会话会自动归入项目';

  @override
  String get sessionNoProjectsTitle => '没有项目';

  @override
  String sessionOpenCopyFailed(String error) {
    return '打开副本失败：$error';
  }

  @override
  String get sessionPrClosed => '已关闭';

  @override
  String get sessionPrDraft => '草稿';

  @override
  String get sessionPrMerged => '已合并';

  @override
  String get sessionPrNone => '无 PR';

  @override
  String get sessionPrOpen => '开放';

  @override
  String get sessionProjectBack => '返回项目列表';

  @override
  String get sessionProjectEnter => '进入';

  @override
  String get sessionProjectNoSessions => '该项目暂无会话';

  @override
  String sessionProjectSessionCount(int count) {
    return '$count 个会话';
  }

  @override
  String get sessionProjectUnavailable => '项目不可用';

  @override
  String get sessionPullRequests => '拉取请求';

  @override
  String sessionResumeFailed(String error) {
    return '恢复会话失败：$error';
  }

  @override
  String sessionResumeLastFailed(String error) {
    return '恢复上次会话失败：$error';
  }

  @override
  String sessionResumeSubagentFailed(String error) {
    return '恢复子代理会话失败：$error';
  }

  @override
  String sessionSearchFailed(String error) {
    return '搜索失败：$error';
  }

  @override
  String get sessionSearchMessages => '搜索消息内容';

  @override
  String get sessionSearchNoFilteredResults => '没有符合当前筛选条件的结果';

  @override
  String get sessionSearchPrompt => '输入关键词后搜索全部历史会话';

  @override
  String sessionSearchResultCount(int total, int visible) {
    return '找到 $total 个会话，当前显示 $visible 个';
  }

  @override
  String get sessionSearchTitleHint => '搜索会话标题…';

  @override
  String get sessionSelectAll => '全选';

  @override
  String get sessionSelectDescription => '从列表打开会话并继续工作';

  @override
  String get sessionSelectMultiple => '多选';

  @override
  String get sessionSelectSessions => '多选会话';

  @override
  String get sessionSelectTitle => '选择会话';

  @override
  String sessionSelectedCount(int count) {
    return '已选 $count 项';
  }

  @override
  String get sessionServerNotConnected => '未连接服务器';

  @override
  String get sessionSortActivity => '最近活跃';

  @override
  String get sessionSortCreated => '创建时间';

  @override
  String get sessionSortTitle => '排序方式';

  @override
  String get sessionSortTokens => 'Token 用量';

  @override
  String get sessionStatusAttention => '待处理';

  @override
  String get sessionStatusIdle => '空闲';

  @override
  String get sessionStatusWorking => '运行中';

  @override
  String get sessionTimeAll => '全部时间';

  @override
  String get sessionTitle => '会话';

  @override
  String sessionToolCount(int count) {
    return '$count 工具';
  }

  @override
  String get sessionUntitled => '未命名会话';

  @override
  String sessionWithinDays(int count) {
    return '$count 天内';
  }

  @override
  String get settingsAppearanceDesc => '显示模式、主题色与高对比';

  @override
  String get settingsBackHome => '返回主页';

  @override
  String get settingsBackendConfigSummary => '后端配置摘要';

  @override
  String get settingsBackendConfigSummaryDesc => '关键配置值';

  @override
  String get settingsBackendConnectionSection => '后端与连接';

  @override
  String settingsBackendRestartFailed(String error) {
    return '重启后端失败：$error';
  }

  @override
  String get settingsBackendRestarted => '后端已重启';

  @override
  String get settingsCapabilitiesDesc => 'MCP、知识库、技能与插件';

  @override
  String get settingsCapabilitiesTitle => '能力管理';

  @override
  String get settingsChangeConnection => '更改连接';

  @override
  String get settingsChangeConnectionDesc => '编辑服务器地址和 API Key';

  @override
  String get settingsChangeConnectionQuestion => '更改连接？';

  @override
  String get settingsChangeConnectionWarning =>
      '将清除当前服务器连接，随后可重新输入服务器地址和 API Key。';

  @override
  String get settingsGroupModels => '模型与能力';

  @override
  String get settingsGroupPersonalization => '个性化';

  @override
  String get settingsModelDesc => '模型、对话、记忆上下文与密钥';

  @override
  String get settingsModelTitle => '模型与对话';

  @override
  String get settingsProvidersDesc => '环境变量、自定义端点、OAuth 与工具集提供者';

  @override
  String get settingsProvidersTitle => 'Providers 与运行环境';

  @override
  String get settingsRestartBackend => '重启 Hermes 后端';

  @override
  String get settingsRestartBackendDesc => '中断当前任务并重新启动服务器进程';

  @override
  String get settingsRestartBackendQuestion => '重启 Hermes 后端？';

  @override
  String get settingsRestartBackendWarning => '服务器上的进行中会话将被中断。';

  @override
  String get settingsSystemConnectionDesc => '连接、安全、终端与后端';

  @override
  String get settingsSystemConnectionTitle => '系统与连接';

  @override
  String get settingsTerminalSection => '终端';

  @override
  String get taskAll => '全部';

  @override
  String taskAssigneeFilter(String value) {
    return '负责人：$value';
  }

  @override
  String get taskAutoDecompose => '自动拆分任务';

  @override
  String get taskAutoGenerate => '自动生成';

  @override
  String get taskBoardView => '看板';

  @override
  String taskBulkFailed(int count) {
    return '$count 个任务更新失败';
  }

  @override
  String get taskClearFilters => '清除筛选';

  @override
  String get taskCloseSearch => '关闭搜索';

  @override
  String taskCommentCount(int count) {
    return '$count 条评论';
  }

  @override
  String get taskConnectBackend => '连接后端后查看任务';

  @override
  String get taskDefault => '默认';

  @override
  String get taskDefaultAssignee => '默认负责人';

  @override
  String get taskFilter => '筛选';

  @override
  String get taskListView => '列表';

  @override
  String get taskNew => '新建任务';

  @override
  String get taskNoDescription => '暂无描述';

  @override
  String get taskOptions => '任务选项';

  @override
  String get taskOrchestration => '编排设置';

  @override
  String get taskOrchestratorProfile => '编排 Profile';

  @override
  String get taskPriorityHigh => '高';

  @override
  String taskPriorityMeta(String priority) {
    return '优先级：$priority';
  }

  @override
  String get taskPriorityNormal => '普通';

  @override
  String get taskPriorityUrgent => '紧急';

  @override
  String taskProfileDescription(String name) {
    return '$name 的描述';
  }

  @override
  String get taskProfileDescriptions => 'Profile 描述';

  @override
  String get taskSearch => '搜索任务';

  @override
  String taskSelectedCount(int count) {
    return '已选择 $count 项';
  }

  @override
  String get taskShowArchived => '显示已归档';

  @override
  String get taskStatusArchived => '已归档';

  @override
  String get taskStatusBlocked => '受阻';

  @override
  String get taskStatusDone => '完成';

  @override
  String get taskStatusReady => '就绪';

  @override
  String get taskStatusReview => '审核';

  @override
  String get taskStatusRunning => '进行中';

  @override
  String get taskStatusScheduled => '已计划';

  @override
  String get taskStatusTodo => '待办';

  @override
  String get taskStatusTriage => '待分类';

  @override
  String get taskSwitchBoard => '切换看板';

  @override
  String taskTenantFilter(String value) {
    return '租户：$value';
  }

  @override
  String get taskTitle => '任务';

  @override
  String get taskUnassigned => '未分配';

  @override
  String get taskWeeklyDelivery => '本周交付';

  @override
  String get terminalDefaultMonospace => '默认等宽字体';

  @override
  String get terminalFontHint => '留空以使用默认等宽字体';

  @override
  String get terminalFontPreview => '预览  ~/project  git:main  >';

  @override
  String terminalFontSaveFailed(String error) {
    return '保存终端字体失败：$error';
  }

  @override
  String get terminalFontSaved => '终端字体已保存';

  @override
  String get terminalFontTitle => '终端字体';

  @override
  String timeDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String get timeJustNow => '刚刚';

  @override
  String timeMinutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String get updateAppVersion => '应用版本';

  @override
  String updateAvailableTitle(String version) {
    return '可更新到 $version';
  }

  @override
  String get updateCheck => '检查更新';

  @override
  String get updateCheckDescription => '从移动发布清单检查新版本';

  @override
  String get updateCheckFailed => '更新检查失败';

  @override
  String updateCheckUnavailable(String error) {
    return '暂时无法检查：$error';
  }

  @override
  String get updateCurrent => '当前已是最新版本';

  @override
  String updateFound(String version) {
    return '发现版本 $version';
  }

  @override
  String get updateGoToUpdate => '前往更新';

  @override
  String updateMinimumVersion(String minimumVersion) {
    return '最低兼容版本：$minimumVersion';
  }

  @override
  String get updateNewVersionPublished => '新版本已发布';

  @override
  String get updateReleaseNotes => '发布说明';

  @override
  String updateRequiredDefault(String currentVersion, String minimumVersion) {
    return '当前版本 $currentVersion 低于最低兼容版本 $minimumVersion。请更新后继续使用。';
  }

  @override
  String get updateRequiredTitle => '需要更新 Hermes Mobile';

  @override
  String get updateSectionTitle => '更新';

  @override
  String get updateUnsupportedTitle => '当前版本已不再受支持';

  @override
  String updateVersionBuild(String version, String build) {
    return 'v$version · build $build';
  }

  @override
  String get workspaceAddPaneTooltip => '打开 Pane';

  @override
  String get workspaceApplyLayoutTooltip => '应用布局';

  @override
  String get workspaceCloseAllAction => '全部关闭';

  @override
  String get workspaceCloseAllDescription => '这只会关闭移动端工作区，不会删除会话或插件数据。';

  @override
  String get workspaceCloseAllQuestion => '关闭所有 Pane？';

  @override
  String get workspaceCloseAllTooltip => '关闭所有 Pane';

  @override
  String get workspaceEmptyDescription => '从会话菜单或插件 Pane 入口打开内容';

  @override
  String get workspaceEmptyTitle => '工作区为空';

  @override
  String get workspaceLayoutDefault => '默认';

  @override
  String get workspaceLayoutFocus => '专注';

  @override
  String get workspaceLayoutQuad => '四宫格';

  @override
  String get workspaceLayoutTerminalDeck => '终端面板';

  @override
  String get workspaceLayoutTooltip => '调整 Pane 布局';

  @override
  String get workspaceMergeTabs => '合并为标签';

  @override
  String get workspaceMoveBottom => '移到下方';

  @override
  String get workspaceMoveLeft => '移到左侧';

  @override
  String get workspaceMoveRight => '移到右侧';

  @override
  String get workspaceMoveTop => '移到上方';

  @override
  String workspaceOpenPluginFailed(String error) {
    return '打开插件 Pane 失败：$error';
  }

  @override
  String workspaceOpenSessionFailed(String error) {
    return '打开工作区失败：$error';
  }

  @override
  String get workspacePaneFiles => '文件';

  @override
  String get workspacePaneLogs => '日志';

  @override
  String get workspacePanePreview => '预览';

  @override
  String get workspacePaneReview => '审查';

  @override
  String get workspacePaneTerminal => '终端';

  @override
  String get workspacePluginUnavailable => '插件 Pane 当前不可用；请检查插件是否已启用';

  @override
  String workspaceSessionResumeFailed(String error) {
    return '恢复会话失败：$error';
  }

  @override
  String get workspaceTitle => '工作区';

  @override
  String statusSemantics(String label) {
    return '状态：$label';
  }

  @override
  String statusAgentSemantics(String label) {
    return '代理状态：$label';
  }

  @override
  String statusToolSemantics(String label) {
    return '工具状态：$label';
  }

  @override
  String get statusIdle => '空闲';

  @override
  String get statusThinking => '思考中';

  @override
  String get statusPlanning => '规划中';

  @override
  String get statusRunning => '运行中';

  @override
  String get statusWaiting => '等待中';

  @override
  String get statusAwaitingApproval => '等待授权';

  @override
  String get statusPaused => '已暂停';

  @override
  String get statusCompleted => '已完成';

  @override
  String get statusFailed => '失败';

  @override
  String get statusStopped => '已停止';

  @override
  String get statusCancelled => '已取消';

  @override
  String get composerUndoInput => '撤销输入';

  @override
  String get composerRedoInput => '重做输入';

  @override
  String get composerReadOnly => '子代理会话为只读';

  @override
  String get composerMessageHint => '给 Hermes 发消息…';

  @override
  String composerProfileValue(String value) {
    return '配置档：$value';
  }

  @override
  String get composerSelectProfile => '选择配置档';

  @override
  String composerWorkspaceValue(String value) {
    return 'Workspace：$value';
  }

  @override
  String get composerSelectWorkspace => '选择 Workspace';

  @override
  String composerModelValue(String value) {
    return '配置模型：$value';
  }

  @override
  String get composerSelectModel => '选择配置模型';

  @override
  String composerDifficultyValue(String value) {
    return '难度：$value';
  }

  @override
  String composerYoloModeValue(String value) {
    return 'Yolo 模式：$value';
  }

  @override
  String get composerEnabled => '已开启';

  @override
  String get composerDisabled => '已关闭';

  @override
  String get composerConfigureToolsets => '配置工具集';

  @override
  String get composerCloseEmojiPanel => '关闭表情面板';

  @override
  String get composerEmoji => '表情';

  @override
  String get composerEditorActions => '编辑器操作';

  @override
  String get composerClearInput => '清空输入';

  @override
  String get composerEnterSendsTooltip => '回车发送，Shift+回车换行';

  @override
  String get composerEnterNewlineTooltip => '回车换行，点击发送';

  @override
  String get composerEnterSends => '回车发送';

  @override
  String get composerEnterNewline => '回车换行';

  @override
  String composerRemoveAttachment(String label) {
    return '移除附件：$label';
  }

  @override
  String get composerFolderNotUploaded => '本地文件夹引用 — 不会发送到服务器';

  @override
  String get composerCurrentDefault => '当前配置默认';

  @override
  String get composerUsedDefaultTools => '已使用默认工具配置';

  @override
  String composerAppliedTools(int count) {
    return '已应用 $count 个工具';
  }

  @override
  String get composerSwitchedToDefault => '已切换到默认配置';

  @override
  String get composerToolConfiguration => '工具配置';

  @override
  String get composerToolConfigurationDescription => '使用当前配置默认工具，或为此会话选择自定义工具集';

  @override
  String get composerUseCurrentDefault => '使用当前配置默认';

  @override
  String get composerSelectCustomTools => '为当前会话选择自定义工具';

  @override
  String get composerConfiguredMcpServers => '已配置 MCP 服务器';

  @override
  String get composerNoConfiguredMcpServers => '没有已配置的 MCP 服务器';

  @override
  String get composerUseDefault => '使用默认';

  @override
  String get composerApply => '应用';

  @override
  String get commonRemove => '移除';

  @override
  String get onboardingChatTitle => '与 Hermes 对话';

  @override
  String get onboardingChatDescription => '发起会话、语音输入、查看工具调用与思考过程，随时继续之前的对话。';

  @override
  String get onboardingProjectsTitle => '项目与会话组织';

  @override
  String get onboardingProjectsDescription =>
      '会话按项目、Git 分支和 worktree 自动分组，置顶、归档、按状态筛选一应俱全。';

  @override
  String get onboardingTerminalTitle => '终端与 Git';

  @override
  String get onboardingTerminalDescription =>
      '在移动端直接跑终端命令、查看改动 diff、暂存提交、创建 Pull Request。';

  @override
  String get onboardingPaletteTitle => '命令面板';

  @override
  String get onboardingPaletteDescription =>
      '通过顶部搜索或下拉手势打开命令面板，快速跳转到功能、最近会话或斜杠命令。';

  @override
  String get onboardingPetTitle => '你的 AI 宠物';

  @override
  String get onboardingPetDescription => '一只会随任务状态改变表情的 AI 宠物，还能生成专属外观。';

  @override
  String get onboardingSkip => '跳过';

  @override
  String get onboardingStart => '开始使用';

  @override
  String get onboardingNext => '下一步';

  @override
  String get petGenerateInputRequired => '请输入描述，或添加一张参考图';

  @override
  String get petGenerateEmptyResult => '生成结果为空';

  @override
  String petGenerateHatchFailed(Object error) {
    return '孵化失败：$error';
  }

  @override
  String petGenerateAdoptFailed(Object error) {
    return '领养失败：$error';
  }

  @override
  String get petGenerateTitle => '生成新宠物';

  @override
  String get petGenerateDescribe => '描述你想要的宠物';

  @override
  String get petGeneratePromptHint => '例如：一只赛博朋克风格的机械猫';

  @override
  String get petGenerateAddReference => '添加参考图（可选）';

  @override
  String get petGenerateReferenceHelp => '每张草图都会参考这张图片';

  @override
  String get petGenerateModel => '生成模型';

  @override
  String get petGenerateAutoSelect => '自动选择';

  @override
  String get petGenerateDraftsAction => '生成 4 个草图';

  @override
  String petGenerateProgress(Object done, Object total) {
    return '正在生成草图… ($done/$total)';
  }

  @override
  String get petGenerateChooseDraft => '选一个喜欢的草图';

  @override
  String petGenerateDraftLabel(Object index) {
    return '草图 $index';
  }

  @override
  String get petGenerateAgain => '重新生成';

  @override
  String get petGenerateHatch => '孵化';

  @override
  String get petGeneratePreparing => '准备中…';

  @override
  String petGenerateDrawingProgress(Object done, Object state, Object total) {
    return '绘制动画帧 $state ($done/$total)';
  }

  @override
  String petGenerateDrawing(Object state) {
    return '绘制动画帧 $state';
  }

  @override
  String get petGenerateComposing => '合成精灵图…';

  @override
  String get petGenerateSaving => '保存中…';

  @override
  String get petGenerateHatching => '孵化中…';

  @override
  String get petGenerateReady => '你的新宠物孵化好了！';

  @override
  String get petGenerateNameLabel => '给它起个名字';

  @override
  String get petGenerateDiscard => '放弃';

  @override
  String get petGenerateAdopt => '领养';

  @override
  String get imageSave => '保存图片';

  @override
  String get imageCopyLink => '复制图片链接';

  @override
  String get imageSavedToGallery => '已保存到相册';

  @override
  String get kanbanHomeChannels => 'Home channel 通知';

  @override
  String get kanbanHomeChannelsFailed => '无法加载 Home channel';

  @override
  String get kanbanHomeChannelsEmpty => '暂无可用的 Home channel';

  @override
  String kanbanUnsupportedAction(Object action) {
    return '当前版本不支持 $action 操作';
  }

  @override
  String chatSessionSaved(Object path) {
    return '会话记录已保存到 $path';
  }

  @override
  String get artifactSessionPendingTitle => '开始会话后查看工件';

  @override
  String get artifactSessionPendingDescription => '此对话保存后，生成的工件会显示在这里。';

  @override
  String get artifactEmptyTitle => '暂无工件';

  @override
  String get artifactEmptyDescription => '会话中生成的代码、文件、链接和图片会显示在这里。';

  @override
  String artifactFallbackLabel(Object id) {
    return '工件 $id';
  }

  @override
  String get artifactDetailTitle => '工件详情';

  @override
  String artifactSessionMeta(Object kind, Object session) {
    return '$kind · 会话 $session';
  }

  @override
  String get artifactMetadata => '元数据';

  @override
  String get artifactSaveAs => '另存为';

  @override
  String get artifactCopyContent => '复制内容';

  @override
  String artifactExportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get artifactType => '类型';

  @override
  String get artifactSession => '会话';

  @override
  String get artifactSessionTitle => '会话标题';

  @override
  String get artifactMessageRow => '消息行';

  @override
  String get logsAllServers => '全部服务器';

  @override
  String get logsLoading => '读取日志…';

  @override
  String get webhookEnableFirst => '请先启用 Webhook 平台';

  @override
  String get webhookEnabledRestart => 'Webhook 已启用，请重启 Hermes 网关以应用变更';

  @override
  String get webhookEnabled => 'Webhook 已启用';

  @override
  String webhookEnableFailed(Object error) {
    return '启用 Webhook 失败：$error';
  }

  @override
  String get webhookLoading => '读取 Webhooks…';

  @override
  String get webhookEmptyTitle => '没有 Webhook';

  @override
  String get webhookEmptyDescription => '点击 + 创建一个 Webhook 以接收 Hermes 事件推送。';

  @override
  String get webhookPlatformDisabled => 'Webhook 平台尚未启用 · 点击启用';

  @override
  String get webhookConfigured => '已配置 Webhook';

  @override
  String get webhookStopped => 'Webhook 已停用';

  @override
  String webhookOperationFailed(Object error) {
    return 'Webhook 操作失败：$error';
  }

  @override
  String get webhookDeleteTitle => '删除 Webhook？';

  @override
  String webhookDeletePrompt(Object name) {
    return '$name 将被删除。';
  }

  @override
  String get webhookDeleted => 'Webhook 已删除';

  @override
  String webhookDeleteFailed(Object error) {
    return '删除 Webhook 失败：$error';
  }

  @override
  String get webhookEnabledLabel => '启用';

  @override
  String get webhookDisabledLabel => '停用';

  @override
  String get webhookEvents => '订阅事件';

  @override
  String get webhookDescription => '描述';

  @override
  String get webhookPrompt => '提示词';

  @override
  String get webhookSkills => '技能';

  @override
  String get webhookDeliverTo => '投递目标';

  @override
  String get webhookEnableThis => '启用此 Webhook';

  @override
  String get webhookHotReloadDescription => '更改会被 Hermes 网关热加载。';

  @override
  String get webhookNameRequired => '请填写名称';

  @override
  String get webhookCreated => 'Webhook 已创建';

  @override
  String get webhookSecretOnce => '签名密钥只会完整显示这一次，请立即保存。';

  @override
  String get webhookSecretSaved => '我已保存';

  @override
  String webhookSaveFailed(Object error) {
    return '保存 Webhook 失败：$error';
  }

  @override
  String get webhookNew => '新建 Webhook';

  @override
  String get webhookName => '名称';

  @override
  String get webhookDescriptionOptional => '描述（可选）';

  @override
  String get webhookEventsComma => '订阅事件（逗号分隔）';

  @override
  String get webhookPromptOptional => '触发提示词（可选）';

  @override
  String get webhookSkillsComma => 'Skills（逗号分隔，可选）';

  @override
  String get webhookDeliveryTarget => '投递目标';

  @override
  String get webhookLogOnly => '仅记录日志';

  @override
  String get webhookSaving => '保存中…';

  @override
  String commonPartialDataLoadFailed(Object details) {
    return '部分数据加载失败：$details';
  }

  @override
  String cronRunsLoadFailed(Object error) {
    return '加载运行记录失败：$error';
  }

  @override
  String profilesOptionsLoadFailed(Object details) {
    return '部分 Profile 编辑选项加载失败：$details';
  }

  @override
  String skillsBulkFailed(Object failed, Object total) {
    return '$total 个技能中有 $failed 个更新失败。';
  }

  @override
  String petCleanupFailed(Object error) {
    return '清理生成任务失败：$error';
  }

  @override
  String get skillsTitle => '技能';

  @override
  String get skillsMarketplace => '技能市场';

  @override
  String get skillsEnableAll => '全部启用';

  @override
  String get skillsDisableAll => '全部禁用';

  @override
  String skillsToggleFailed(Object error) {
    return '切换失败：$error';
  }

  @override
  String get skillsSearchHint => '搜索技能…';

  @override
  String skillsEnabledCount(Object enabled, Object total) {
    return '启用 $enabled/$total';
  }

  @override
  String get skillsLoading => '加载技能…';

  @override
  String get skillsEmptyTitle => '没有技能';

  @override
  String get skillsEmptyDescription => '当前 Agent 没有可用技能';

  @override
  String get skillsUncategorized => '未分类';

  @override
  String get skillsNoMatches => '没有匹配的技能';

  @override
  String skillsUsageCount(Object count) {
    return '使用 $count 次';
  }

  @override
  String get skillsLearned => '已学习';

  @override
  String get skillsBuiltIn => '内置';

  @override
  String get skillsProvenanceMarketplace => '市场';

  @override
  String get skillsSaved => '已保存';

  @override
  String skillsSaveFailed(Object error) {
    return '保存失败：$error';
  }

  @override
  String get skillsArchiveQuestion => '归档技能？';

  @override
  String skillsArchivePrompt(Object name) {
    return '将归档已学习的技能“$name”。此操作可撤销。';
  }

  @override
  String get skillsArchive => '归档';

  @override
  String get skillsArchived => '已归档';

  @override
  String skillsArchiveFailed(Object error) {
    return '归档失败：$error';
  }

  @override
  String get skillsContent => '内容';

  @override
  String get skillsNoContent => '（无内容）';

  @override
  String get skillsCancelEdit => '取消编辑';

  @override
  String get skillsSaving => '保存中…';

  @override
  String get historyTitle => '历史会话';

  @override
  String historyResumeFailed(Object error) {
    return '恢复会话失败：$error';
  }

  @override
  String get historyManageSessions => '会话管理';

  @override
  String get historyHideArchived => '隐藏已归档';

  @override
  String get historyShowArchived => '显示已归档';

  @override
  String get historySelectTitle => '选择会话';

  @override
  String get historySelectDescription => '在左侧选择会话查看摘要与管理操作';

  @override
  String get historyLoading => '加载历史会话…';

  @override
  String get historySearchHint => '搜索标题、内容或工作目录';

  @override
  String get historyClearSearch => '清除';

  @override
  String get historyEmpty => '还没有会话';

  @override
  String get historyNoMatches => '没有匹配的会话';

  @override
  String get historyLoadMore => '加载更多';

  @override
  String historyLoadMoreCount(Object loaded, Object total) {
    return '加载更多（$loaded/$total）';
  }

  @override
  String get historyPinned => '置顶';

  @override
  String get historyToday => '今天';

  @override
  String get historyYesterday => '昨天';

  @override
  String get historyThisWeek => '本周';

  @override
  String get historyLastWeek => '上周';

  @override
  String get historyEarlier => '更早';

  @override
  String get historyCollapseChildren => '收起子会话';

  @override
  String get historyExpandChildren => '展开子会话';

  @override
  String get historySessionActions => '会话操作';

  @override
  String get historyManageSession => '管理会话';

  @override
  String get historyUntitled => '未命名会话';

  @override
  String historyMessageCount(Object count) {
    return '$count 条消息';
  }

  @override
  String get historyDeleteQuestion => '删除会话？';

  @override
  String historyDeletePrompt(Object title) {
    return '“$title”将被永久删除，此操作无法撤销。';
  }

  @override
  String historyDeleteFailed(Object error) {
    return '删除会话失败：$error';
  }

  @override
  String historyRenameFailed(Object error) {
    return '重命名失败：$error';
  }

  @override
  String historyCompressed(Object count) {
    return '已压缩会话（移除了 $count 条消息）';
  }

  @override
  String historyCompressFailed(Object error) {
    return '压缩失败：$error';
  }

  @override
  String historyArchiveFailed(Object error) {
    return '归档失败：$error';
  }

  @override
  String historyUnarchiveFailed(Object error) {
    return '取消归档失败：$error';
  }

  @override
  String get historyManagement => '会话管理';

  @override
  String get historySaveTitle => '保存标题';

  @override
  String historyContextUsage(Object maximum, Object percent, Object used) {
    return '上下文用量：$used / $maximum$percent';
  }

  @override
  String historyPercent(Object percent) {
    return '（$percent%）';
  }

  @override
  String get historyCompress => '压缩会话';

  @override
  String get historyArchive => '归档';

  @override
  String get historyUnarchive => '取消归档';

  @override
  String get cronTitle => '计划任务';

  @override
  String get cronLoading => '加载计划任务…';

  @override
  String get cronEmptyTitle => '还没有计划任务';

  @override
  String get cronEmptyDescription => '创建按计划定时执行的自动任务';

  @override
  String get cronNew => '新建计划';

  @override
  String cronNextRun(Object time) {
    return '下次执行：$time';
  }

  @override
  String get cronRunHistory => '运行记录';

  @override
  String cronRunHistoryTitle(Object name) {
    return '运行记录 · $name';
  }

  @override
  String get cronNoRuns => '暂无运行记录';

  @override
  String get cronTriggerNow => '立即触发';

  @override
  String get cronTriggered => '已触发';

  @override
  String cronTriggerFailed(Object error) {
    return '触发失败：$error';
  }

  @override
  String cronUpdateFailed(Object error) {
    return '更新失败：$error';
  }

  @override
  String get cronDeleteQuestion => '删除计划任务？';

  @override
  String cronDeletePrompt(Object name) {
    return '“$name”将被删除。';
  }

  @override
  String cronDeleteFailed(Object error) {
    return '删除失败：$error';
  }

  @override
  String get cronStateCompleted => '已完成';

  @override
  String get cronStateDisabled => '已停用';

  @override
  String get cronStateEnabled => '已启用';

  @override
  String get cronStateError => '出错';

  @override
  String get cronStatePaused => '已暂停';

  @override
  String get cronStateRunning => '运行中';

  @override
  String get cronStateScheduled => '已计划';

  @override
  String cronModelsLoadFailed(Object error) {
    return '加载模型选项失败：$error';
  }

  @override
  String cronBlueprintsLoadFailed(Object error) {
    return '加载自动化模板失败：$error';
  }

  @override
  String cronTargetsLoadFailed(Object error) {
    return '加载投递目标失败：$error';
  }

  @override
  String get cronPresetMinute => '每分钟';

  @override
  String get cronPresetHour => '每小时';

  @override
  String get cronPresetDay => '每天 09:00';

  @override
  String get cronPresetWeek => '每周一 09:00';

  @override
  String get cronPresetMonth => '每月 1 日 09:00';

  @override
  String get cronPresetCustom => '自定义';

  @override
  String get cronPresetMinuteHint => '每分钟执行一次';

  @override
  String get cronPresetHourHint => '每小时整点执行';

  @override
  String get cronPresetDayHint => '每天早上 9 点执行';

  @override
  String get cronPresetWeekHint => '每周一早上 9 点执行';

  @override
  String get cronPresetMonthHint => '每月 1 日早上 9 点执行';

  @override
  String get cronPromptAndExpressionRequired => '请填写执行内容和 Cron 表达式';

  @override
  String get cronExpressionRequired => '请填写 Cron 表达式';

  @override
  String get cronPromptRequired => '请填写执行内容';

  @override
  String cronSaveFailed(Object error) {
    return '保存失败：$error';
  }

  @override
  String get cronCreateTitle => '新建计划任务';

  @override
  String get cronEditTitle => '编辑计划任务';

  @override
  String get cronStartFromTemplate => '从模板开始';

  @override
  String get cronScheduling => '正在安排…';

  @override
  String get cronScheduleAutomation => '安排此自动化';

  @override
  String get cronScriptOnlyDescription =>
      '这是仅脚本任务。可以调整名称、计划、投递目标以及脚本内容本身；模型设置不适用。';

  @override
  String get cronScriptLabel => '脚本';

  @override
  String cronLastRun(Object time) {
    return '上次运行：$time';
  }

  @override
  String get cronRunScheduledAt => '计划时间';

  @override
  String get cronRunStartedAt => '开始时间';

  @override
  String get cronRunFinishedAt => '结束时间';

  @override
  String get cronRunStatus => '状态';

  @override
  String get cronRunOutput => '输出';

  @override
  String get cronRunDetailTitle => '运行成功';

  @override
  String get cronRunDetailFailedTitle => '运行失败';

  @override
  String get cronNameOptional => '名称（可选）';

  @override
  String get cronDeliverResultsTo => '结果投递到';

  @override
  String get cronTaskModel => '任务模型';

  @override
  String get cronUseGlobalDefault => '跟随全局默认';

  @override
  String cronSavedModel(Object model) {
    return '$model（当前已保存）';
  }

  @override
  String get cronPromptLabel => '执行内容（prompt）';

  @override
  String get cronFrequency => '频率';

  @override
  String get cronExpression => 'Cron 表达式';

  @override
  String get cronExpressionHint => '分 时 日 月 周';

  @override
  String get cronSaving => '保存中…';

  @override
  String get cronThisDevice => '此设备';

  @override
  String get cronConfigureHomeChannelFirst => '请先配置主频道';

  @override
  String get profilesTitle => 'Agent Profiles';

  @override
  String get profilesLoading => '加载配置文件…';

  @override
  String get profilesEmptyTitle => '暂无配置';

  @override
  String get profilesEmptyDescription => '创建第一个 Agent 配置文件';

  @override
  String get profilesNew => '新建 Profile';

  @override
  String get profilesImport => '导入 Profile';

  @override
  String get profilesExport => '导出 Profile';

  @override
  String get profilesDuplicate => '复制配置';

  @override
  String get profilesEditSoul => '编辑 SOUL.md';

  @override
  String get profilesSetupCommand => '终端启动命令';

  @override
  String profilesSaveFailed(Object error) {
    return '保存失败：$error';
  }

  @override
  String get profilesCreated => '已创建配置';

  @override
  String get profilesSaved => '已保存配置';

  @override
  String profilesCopyName(Object name) {
    return '$name 副本';
  }

  @override
  String profilesDuplicateFailed(Object error) {
    return '复制失败：$error';
  }

  @override
  String get profilesDuplicated => '已复制配置';

  @override
  String profilesDeleteQuestion(Object name) {
    return '删除配置“$name”？';
  }

  @override
  String get profilesDeleteActiveWarning => '注意：该配置当前处于激活状态。';

  @override
  String get profilesDeleteWarning => '此操作无法撤销。';

  @override
  String profilesDeleteFailed(Object error) {
    return '删除失败：$error';
  }

  @override
  String get profilesDeleted => '已删除配置';

  @override
  String profilesSwitchFailed(Object error) {
    return '切换失败：$error';
  }

  @override
  String profilesSwitchedTo(Object name) {
    return '已切换到“$name”';
  }

  @override
  String get profilesSoulHint => '描述这个 Agent 的身份、行为与沟通方式';

  @override
  String get profilesSoulSaved => 'SOUL.md 已保存';

  @override
  String profilesSoulFailed(Object error) {
    return 'SOUL.md 操作失败：$error';
  }

  @override
  String get profilesCopy => '复制';

  @override
  String profilesSetupCommandFailed(Object error) {
    return '读取启动命令失败：$error';
  }

  @override
  String get profilesExported => 'Profile 已导出';

  @override
  String profilesExportFailed(Object error) {
    return '导出失败：$error';
  }

  @override
  String profilesImported(Object name) {
    return '已导入 $name';
  }

  @override
  String profilesImportFailed(Object error) {
    return '导入失败：$error';
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
  String get profilesCurrentSuffix => ' · 当前使用';

  @override
  String get profilesActive => '激活';

  @override
  String get profilesActivate => '激活';

  @override
  String get profilesNameRequired => '请填写配置名称';

  @override
  String get profilesCreateTitle => '新建配置文件';

  @override
  String get profilesEditTitle => '编辑配置文件';

  @override
  String get profilesProvider => '提供者';

  @override
  String get profilesModel => '模型';

  @override
  String get profilesSystemPrompt => '系统提示词';

  @override
  String get profilesDescriptionOptional => '描述（可选）';

  @override
  String get profilesTools => '工具开关';

  @override
  String get profilesDeselectAll => '全不选';

  @override
  String get profilesSelectAll => '全选';

  @override
  String get profilesSetActive => '设为激活配置';

  @override
  String get memoryTitle => '记忆';

  @override
  String get memoryLoading => '读取记忆状态…';

  @override
  String memorySwitchFailed(Object error) {
    return '切换失败：$error';
  }

  @override
  String get memoryResetScope => '选择重置范围';

  @override
  String get memoryResetScopeDescription => '只删除所选记忆文件';

  @override
  String get memoryAll => '全部记忆';

  @override
  String get memoryAllFiles => 'MEMORY.md 和 USER.md';

  @override
  String get memoryLongTerm => '长期记忆';

  @override
  String get memoryLongTermFile => '仅 MEMORY.md';

  @override
  String get memoryUser => '用户记忆';

  @override
  String get memoryUserFile => '仅 USER.md';

  @override
  String get memoryResetQuestion => '确认重置记忆？';

  @override
  String get memoryResetWarning => '删除后无法恢复。';

  @override
  String get memoryNothingDeleted => '没有需要删除的记忆文件';

  @override
  String memoryDeleted(Object files) {
    return '已删除 $files';
  }

  @override
  String memoryResetFailed(Object error) {
    return '重置失败：$error';
  }

  @override
  String memoryCuratorUpdateFailed(Object error) {
    return '更新 Curator 失败：$error';
  }

  @override
  String get memoryCuratorStarted => 'Curator 已开始运行';

  @override
  String memoryCuratorRunFailed(Object error) {
    return '运行失败：$error';
  }

  @override
  String get memoryCurrentProvider => '当前记忆提供方';

  @override
  String get memoryDisabled => '未启用';

  @override
  String get memoryEnabled => '已启用';

  @override
  String get memoryProviders => '提供方';

  @override
  String get memoryNoProviders => '没有可用提供方';

  @override
  String get memoryBuiltInFiles => '内置记忆文件';

  @override
  String get memoryReset => '重置记忆';

  @override
  String get memoryInUse => '使用中';

  @override
  String get memoryConfigured => '已配置';

  @override
  String memoryConfigureProvider(Object name) {
    return '配置 $name';
  }

  @override
  String memoryEnableProvider(Object name) {
    return '启用 $name';
  }

  @override
  String get memoryCuratorLoading => '读取 Curator 状态…';

  @override
  String get memoryCuratorUnavailable => 'Curator 不可用';

  @override
  String get memoryPaused => '已暂停';

  @override
  String memoryCuratorInterval(Object hours) {
    return '每 $hours 小时检查';
  }

  @override
  String memoryCuratorLastRun(Object time) {
    return '上次运行 $time';
  }

  @override
  String get memoryResume => '恢复';

  @override
  String get memoryPause => '暂停';

  @override
  String get memoryRunNow => '立即运行';

  @override
  String memoryInvalidJson(Object field) {
    return '$field 不是有效 JSON';
  }

  @override
  String get memoryProviderSaved => '提供方配置已保存';

  @override
  String memoryProviderSaveFailed(Object error) {
    return '保存失败：$error';
  }

  @override
  String get memoryOAuthTimeout => '连接超时，请重试';

  @override
  String get memoryCurrentProfile => '当前 Profile';

  @override
  String memoryProfile(Object name) {
    return 'Profile：$name';
  }

  @override
  String get memoryProviderConfigLoading => '读取提供方配置…';

  @override
  String get memoryNoProviderConfig => '此提供方没有额外配置';

  @override
  String get memoryViewProviderDocs => '查看提供方文档';

  @override
  String get memorySaving => '保存中…';

  @override
  String get memorySaveConfig => '保存配置';

  @override
  String get memoryAccountConnected => '账户已连接';

  @override
  String get memoryConnectAccount => '连接提供方账户';

  @override
  String get memoryReconnect => '重新连接';

  @override
  String get memoryConnect => '连接';

  @override
  String get memoryKeepSecretHint => '留空以保留当前值';

  @override
  String agentOpenBotFailed(Object error) {
    return '无法打开 Bot Chat：$error';
  }

  @override
  String get agentNewGroup => '新建群聊';

  @override
  String get agentEditGroup => '编辑群聊';

  @override
  String get agentGroupName => '群聊名称';

  @override
  String agentGroupSaveFailed(Object error) {
    return '群聊保存失败：$error';
  }

  @override
  String agentBotThinking(Object name) {
    return '$name 正在思考';
  }

  @override
  String agentBotPaused(Object name) {
    return '$name 已暂停';
  }

  @override
  String get agentStartGroupChat => '开始群聊';

  @override
  String agentReplyTo(Object id) {
    return '回复 #$id';
  }

  @override
  String get agentSendToRoom => '发送到房间';

  @override
  String get agentMentionHint => '使用 @名称 定向，@all 通知所有成员';

  @override
  String agentAttachmentTooLarge(Object name) {
    return '$name 超过 20MB';
  }

  @override
  String agentAttachFailed(Object error) {
    return '添加附件失败：$error';
  }

  @override
  String agentGroupSendFailed(Object error) {
    return '群聊发送失败：$error';
  }

  @override
  String get agentAppendMessage => '追加消息';

  @override
  String get agentAwaitingApproval => '等待授权';

  @override
  String get agentNeedsInformation => '需要补充信息';

  @override
  String get agentRespond => '回应';

  @override
  String agentMemberRequest(Object name) {
    return '$name 的请求';
  }

  @override
  String get agentAllowOperationQuestion => '允许该操作？';

  @override
  String get agentDeny => '拒绝';

  @override
  String get agentAlwaysAllow => '始终允许';

  @override
  String get agentAllow => '允许';

  @override
  String get agentCustomAnswer => '自定义回答';

  @override
  String get agentEnterAnswer => '请输入回答';

  @override
  String agentRespondFailed(Object error) {
    return '回应失败：$error';
  }

  @override
  String get agentLoading => '读取 Agent 状态…';

  @override
  String get agentNoData => '暂无数据';

  @override
  String get agentManageBots => '管理 / 新建 Bot';

  @override
  String get agentBotRoutinesMenuItem => '机器人任务';

  @override
  String get agentBotsEmptyTitle => '还没有机器人';

  @override
  String get agentBotsEmptyDescription =>
      '机器人是绑定到某个配置档案的独立聊天身份。点击右上角新建一个配置档案即可开始。';

  @override
  String get agentMentionAll => '所有人';

  @override
  String get agentRefreshRoster => '刷新 Bot roster';

  @override
  String agentGroupSummary(Object count, Object runningSuffix) {
    return '$count 个 Bot · 跨 Connection$runningSuffix';
  }

  @override
  String get agentRunningSuffix => ' · 运行中';

  @override
  String agentDeleteGroupQuestion(Object name) {
    return '删除群聊“$name”？';
  }

  @override
  String get agentDeleteGroupWarning => '群聊记录将被永久删除，此操作无法撤销。';

  @override
  String agentDeleteGroupFailed(Object error) {
    return '删除群聊失败：$error';
  }

  @override
  String get agentDeleteGroup => '删除群聊';

  @override
  String agentDeleteBotQuestion(Object name) {
    return '删除 Bot“$name”？';
  }

  @override
  String agentBotOperationFailed(Object error) {
    return 'Bot 操作失败：$error';
  }

  @override
  String get agentDuplicateBot => '复制 Bot';

  @override
  String get agentDeleteBot => '删除 Bot';

  @override
  String get agentGateway => '网关';

  @override
  String get agentActiveAgents => '活跃 Agent';

  @override
  String get agentBusy => '繁忙';

  @override
  String get agentYes => '是';

  @override
  String get agentNo => '否';

  @override
  String get agentModelSection => '模型';

  @override
  String get agentCurrentModel => '当前模型';

  @override
  String get agentProvider => '提供方';

  @override
  String get agentContextLength => '上下文长度';

  @override
  String get agentSessionModel => '会话模型';

  @override
  String get agentRuntimeSection => '运行时';

  @override
  String get agentType => '类型';

  @override
  String get agentSourceRoot => '源码目录';

  @override
  String get agentHermesHome => 'Hermes 主目录';

  @override
  String get agentServerVersion => '服务器版本';

  @override
  String get agentCapability => '能力';

  @override
  String get agentRestarting => '重启中…';

  @override
  String botRoutineUpdateFailed(Object error) {
    return '任务更新失败：$error';
  }

  @override
  String get botRoutineDeleteQuestion => '删除任务？';

  @override
  String botRoutineDeletePrompt(Object title) {
    return '“$title”及其计划将被永久删除。';
  }

  @override
  String get botRoutineStatus => '状态';

  @override
  String get botRoutinePaused => '已暂停';

  @override
  String get botRoutineSchedule => '计划';

  @override
  String get botRoutineRawSchedule => '原始计划';

  @override
  String get botRoutineRepeatCount => '重复次数';

  @override
  String get botRoutineNextRun => '下次运行';

  @override
  String get botRoutineLastRun => '上次运行';

  @override
  String get botRoutineLastResult => '上次结果';

  @override
  String get botRoutineDeliverTo => '投递到';

  @override
  String get botRoutineModel => '模型';

  @override
  String get botRoutineWorkdir => '工作目录';

  @override
  String get botRoutineInstruction => '指令';

  @override
  String get botRoutineLegacyWarning => '该旧版任务已为安全起见暂停。请删除并重新创建后再运行。';

  @override
  String botRoutineTitle(Object name) {
    return '$name · 机器人任务';
  }

  @override
  String commonBytes(Object count) {
    return '$count 字节';
  }

  @override
  String get botRoutineLoading => '加载机器人任务…';

  @override
  String get botRoutineEmptyTitle => '还没有任务';

  @override
  String botRoutineEmptyDescription(Object name) {
    return '为 $name 创建独立的定时任务';
  }

  @override
  String get botRoutineNew => '新建任务';

  @override
  String botRoutineNext(Object time) {
    return '下次 $time';
  }

  @override
  String get botRoutineLegacyPaused => '旧版任务，已安全暂停';

  @override
  String get botRoutineDelete => '删除任务';

  @override
  String botRoutineScheduleOnce(Object duration) {
    return '一次性 · $duration 后';
  }

  @override
  String botRoutineScheduleEvery(Object duration) {
    return '每 $duration';
  }

  @override
  String get botRoutineScheduleHourly => '每小时整点';

  @override
  String get botRoutineScheduleDaily => '每天 09:00';

  @override
  String get botRoutineScheduleWeekdays => '工作日 09:00';

  @override
  String get botRoutineScheduleWeekly => '每周一 09:00';

  @override
  String get botRoutineScheduleMonthly => '每月 1 日 09:00';

  @override
  String get botRoutineRequiredFields => '请填写名称、指令和执行计划';

  @override
  String botRoutineCreateTitle(Object name) {
    return '新建任务 · $name';
  }

  @override
  String get botRoutineInstructionLabel => '每次运行时执行的指令';

  @override
  String get botRoutineFrequencyOnce => '一次性，在一段时间后';

  @override
  String get botRoutineFrequencyHourly => '每小时';

  @override
  String get botRoutineFrequencyDaily => '每天';

  @override
  String get botRoutineFrequencyWeekdays => '工作日';

  @override
  String get botRoutineFrequencyWeekly => '每周';

  @override
  String get botRoutineFrequencyMonthly => '每月';

  @override
  String get botRoutineFrequencyInterval => '固定间隔';

  @override
  String get botRoutineFrequencyAdvanced => '高级表达式';

  @override
  String get botRoutineTime => '时间（HH:mm）';

  @override
  String get botRoutineWeekday => '星期';

  @override
  String get botRoutineMonday => '星期一';

  @override
  String get botRoutineTuesday => '星期二';

  @override
  String get botRoutineWednesday => '星期三';

  @override
  String get botRoutineThursday => '星期四';

  @override
  String get botRoutineFriday => '星期五';

  @override
  String get botRoutineSaturday => '星期六';

  @override
  String get botRoutineSunday => '星期日';

  @override
  String get botRoutineDayOfMonth => '每月第几日';

  @override
  String get botRoutineValue => '数值';

  @override
  String get botRoutineUnit => '单位';

  @override
  String get botRoutineMinutes => '分钟';

  @override
  String get botRoutineHours => '小时';

  @override
  String get botRoutineDays => '天';

  @override
  String get botRoutineAdvancedExpression => 'Cron 或 every Nm/Nh/Nd';

  @override
  String botRoutineWillSaveAs(Object schedule) {
    return '将保存为：$schedule';
  }

  @override
  String get botRoutineRepeatLimit => '运行次数上限（留空表示持续运行）';

  @override
  String get botRoutineContinuity => '连续性';

  @override
  String get botRoutineContinuityDescription => '每次运行可读取该任务上一次的输出';

  @override
  String botRoutineSendToBot(Object name) {
    return '发送到 $name 的 Bot Chat';
  }

  @override
  String get botRoutineSendToBotDescription => 'Bot 会读取结果并继续响应';

  @override
  String get botRoutineCreating => '创建中…';

  @override
  String get botRoutineCreate => '创建任务';

  @override
  String get mcpTitle => 'MCP 服务器';

  @override
  String mcpOperationFailed(Object error) {
    return '操作失败：$error';
  }

  @override
  String get mcpPersistenceFailed => '服务器未能持久化 MCP 配置变更。';

  @override
  String mcpTestSuccess(Object prompts, Object resources, Object tools) {
    return '连接成功：$tools 个工具、$prompts 个提示、$resources 个资源';
  }

  @override
  String mcpTestConnectionFailed(Object error) {
    return '连接失败：$error';
  }

  @override
  String mcpTestFailed(Object error) {
    return '测试失败：$error';
  }

  @override
  String mcpReloadFailed(Object error) {
    return '配置已保存，但活动会话 MCP 热重载失败：$error';
  }

  @override
  String get mcpImportUnrecognized => '无法识别粘贴内容，请检查格式';

  @override
  String mcpImportDetected(Object count) {
    return '检测到 $count 个服务器';
  }

  @override
  String mcpImportAllQuestion(Object names) {
    return '是否全部添加？\n\n$names';
  }

  @override
  String get mcpAddAll => '全部添加';

  @override
  String mcpServersAdded(Object count) {
    return '已添加 $count 个服务器';
  }

  @override
  String mcpServersPartiallyAdded(Object added, Object failed) {
    return '已添加 $added 个，$failed 个失败';
  }

  @override
  String get mcpAddServer => '添加 MCP 服务器';

  @override
  String get mcpPasteImport => '粘贴导入（mcp.json / 命令行 / claude mcp add / URL）';

  @override
  String get mcpParse => '解析';

  @override
  String get mcpRemoteUrl => '远程 URL';

  @override
  String get mcpLocalStdio => '本地 stdio';

  @override
  String get mcpServerUrl => '服务器 URL';

  @override
  String get mcpCommand => '命令';

  @override
  String get mcpArgumentsOnePerLine => '参数（每行一个）';

  @override
  String get mcpEnvironmentJson => '环境变量 JSON';

  @override
  String get mcpAuthentication => '认证方式';

  @override
  String get mcpNoAuthentication => '无认证';

  @override
  String get mcpEnvironmentMustBeJson => '环境变量必须是 JSON 对象';

  @override
  String get mcpServerAdded => 'MCP 服务器已添加';

  @override
  String mcpAddFailed(Object error) {
    return '添加失败：$error';
  }

  @override
  String mcpDeleteQuestion(Object name) {
    return '删除 $name？';
  }

  @override
  String get mcpDeleteWarning => '此操作会从 Hermes MCP 配置中永久移除该服务器。';

  @override
  String mcpDeleteFailed(Object error) {
    return '删除失败：$error';
  }

  @override
  String mcpReadConfigFailed(Object error) {
    return '读取配置失败：$error';
  }

  @override
  String mcpEditServer(Object name) {
    return '编辑 $name';
  }

  @override
  String mcpInvalidJson(Object error) {
    return '不是合法的 JSON 对象：$error';
  }

  @override
  String mcpServerSaved(Object name) {
    return '$name 已保存';
  }

  @override
  String mcpSaveFailed(Object error) {
    return '保存失败：$error';
  }

  @override
  String mcpToolToggleFailed(Object error) {
    return '切换工具失败：$error';
  }

  @override
  String get mcpOAuthStartFailed => 'OAuth 启动失败';

  @override
  String get mcpOAuthMissingUrl => 'OAuth 服务器没有返回授权地址';

  @override
  String get mcpBrowserOpenFailed => '无法打开系统浏览器';

  @override
  String mcpCompleteAuthorization(Object name) {
    return '请在浏览器完成 $name 授权';
  }

  @override
  String get mcpOAuthAuthorizationFailed => 'OAuth 授权失败';

  @override
  String mcpAuthorizationSucceeded(Object name, Object tools) {
    return '$name 授权成功，发现 $tools 个工具';
  }

  @override
  String mcpOAuthFailed(Object error) {
    return 'OAuth 失败：$error';
  }

  @override
  String mcpInstallTitle(Object name) {
    return '安装 $name';
  }

  @override
  String get mcpRequired => '必填';

  @override
  String get mcpOptional => '可选';

  @override
  String get mcpRequiredCredentials => '请填写所有必填凭据';

  @override
  String get mcpReinstall => '重新安装';

  @override
  String get mcpInstall => '安装';

  @override
  String mcpInstallExitCode(Object code) {
    return '安装进程退出码 $code';
  }

  @override
  String mcpInstallComplete(Object name) {
    return '$name 安装完成';
  }

  @override
  String mcpInstallFailed(Object error) {
    return '安装失败：$error';
  }

  @override
  String get mcpViewLogs => '查看日志';

  @override
  String get mcpLoading => '读取 MCP 服务器…';

  @override
  String get mcpConfiguredServers => '已配置服务器';

  @override
  String get mcpNoConfiguredServers => '还没有配置 MCP 服务器';

  @override
  String get mcpDescription => 'MCP 让 Agent 接入外部工具与数据源。';

  @override
  String mcpAvailableCatalog(Object count) {
    return '可用目录（$count）';
  }

  @override
  String mcpToolCount(Object count) {
    return '$count 个工具';
  }

  @override
  String mcpUsage30Days(Object count) {
    return '$count 次/30天';
  }

  @override
  String get mcpTestConnection => '测试连接';

  @override
  String get mcpEditConfiguration => '编辑配置';

  @override
  String get mcpOAuthAuthorization => 'OAuth 授权';

  @override
  String get mcpInstalledEnabled => '已安装并启用';

  @override
  String get mcpInstalledDisabled => '已安装但未启用';

  @override
  String get commandCenterTitle => '命令中心';

  @override
  String get commandStatusTab => '状态';

  @override
  String get commandUsageTab => '用量';

  @override
  String get commandMaintenanceTab => '维护';

  @override
  String commandStatusLoadFailed(Object error) {
    return '读取状态失败：$error';
  }

  @override
  String commandLogsLoadFailed(Object error) {
    return '读取日志失败：$error';
  }

  @override
  String get commandRestartWarning => '将重启 Hermes backend 进程，进行中的回合可能中断。';

  @override
  String commandRestartResult(Object result) {
    return '重启结果：$result';
  }

  @override
  String get commandNoLogs => '（无日志）';

  @override
  String get commandBackendProcess => '后端进程';

  @override
  String get commandStopped => '已停止';

  @override
  String get commandLiveLogs => '实时日志';

  @override
  String get commandDiagnostics => '诊断详情';

  @override
  String get commandSystemStatus => '系统状态';

  @override
  String get commandNoStatusData => '没有状态数据';

  @override
  String commandUsageLoadFailed(Object error) {
    return '读取用量失败：$error';
  }

  @override
  String commandDays(Object count) {
    return '$count 天';
  }

  @override
  String get commandSessions => '会话';

  @override
  String get commandApiCalls => 'API 调用';

  @override
  String get commandTokensInOut => 'Token（入/出）';

  @override
  String get commandDailyUsage => '每日用量';

  @override
  String get commandNoUsageData => '暂无用量数据';

  @override
  String get commandTopModels => '模型使用排行';

  @override
  String get commandTopSkills => '技能使用排行';

  @override
  String commandUseCount(Object count) {
    return '$count 次';
  }

  @override
  String commandChartTooltip(Object day, Object input, Object output) {
    return '$day\n输入 $input / 输出 $output';
  }

  @override
  String get commandInputTokens => '输入 tokens';

  @override
  String get commandOutputTokens => '输出 tokens';

  @override
  String commandStarting(Object label) {
    return '正在启动 $label…';
  }

  @override
  String get commandMissingActionName => '后端未返回操作名称';

  @override
  String get commandNoOutput => '（暂无输出）';

  @override
  String commandActionExitFailed(Object code, Object label) {
    return '$label 失败（退出码 $code）';
  }

  @override
  String commandActionComplete(Object label) {
    return '$label 完成';
  }

  @override
  String commandLogError(Object error, Object logs) {
    return '$logs\n\n错误：$error';
  }

  @override
  String commandActionFailed(Object error, Object label) {
    return '$label 失败：$error';
  }

  @override
  String commandDebugShareFailed(Object error) {
    return '生成调试分享失败：$error';
  }

  @override
  String get commandDebugShare => '生成调试分享';

  @override
  String get commandLogsRedacted => '已对日志进行脱敏处理。';

  @override
  String get commandLogsNotRedacted => '未进行脱敏处理，请谨慎分享。';

  @override
  String commandAutoDeleteHours(Object hours) {
    return '链接将在约 $hours 小时后自动删除。';
  }

  @override
  String get commandPartialUploadFailed => '部分内容上传失败：';

  @override
  String get commandDiagnosticsMaintenance => '诊断与维护';

  @override
  String get commandRunDoctor => '运行诊断';

  @override
  String get commandRunDoctorDescription => 'hermes doctor - 检查环境与配置';

  @override
  String get commandDoctor => '诊断';

  @override
  String get commandSecurityAudit => '安全审计';

  @override
  String get commandSecurityAuditDescription =>
      'hermes security audit - 扫描潜在安全问题';

  @override
  String get commandBackupNow => '立即备份';

  @override
  String get commandBackupDescription => 'hermes backup - 打包配置与数据到本机';

  @override
  String get commandBackup => '备份';

  @override
  String get commandDebugShareDescription => '上传脱敏日志，生成可分享的调试链接';

  @override
  String terminalStartFailed(Object error) {
    return '启动终端失败：$error';
  }

  @override
  String get terminalSshHost => '主机或 SSH config alias *';

  @override
  String get terminalSshUserOptional => '用户（可选）';

  @override
  String get terminalSshPort => '端口（默认 22）';

  @override
  String get terminalSshIdentityFile => '服务端 IdentityFile（可选）';

  @override
  String get terminalSshRemoteCwd => '远端工作目录（可选）';

  @override
  String get terminalSshAuthenticationNote =>
      '认证由 Hermes server 所在机器的 ssh-agent / SSH config 完成；移动端不保存密码。';

  @override
  String terminalSshFailed(Object error) {
    return 'SSH 连接失败：$error';
  }

  @override
  String get terminalCloseRunningQuestion => '关闭运行中的终端？';

  @override
  String terminalCloseRunningWarning(Object name) {
    return '“$name”中的进程会被终止，此操作无法撤销。';
  }

  @override
  String get terminalClose => '关闭终端';

  @override
  String get terminalSessions => '终端会话';

  @override
  String terminalSessionLimit(Object count) {
    return '最多同时打开 $count 个终端';
  }

  @override
  String terminalCloseNamed(Object name) {
    return '关闭 $name';
  }

  @override
  String get terminalSelectTextFirst => '请先选中文本';

  @override
  String terminalPasteLinesQuestion(Object count) {
    return '粘贴 $count 行内容？';
  }

  @override
  String get terminalMergeSingleLine => '合并为单行';

  @override
  String get terminalConfirmPaste => '确认粘贴';

  @override
  String get terminalSelectTerminalTextFirst => '请先在终端中选中文本';

  @override
  String get terminalSentToChat => '已发送到聊天输入框';

  @override
  String terminalOpenLinkFailed(Object link) {
    return '无法打开链接：$link';
  }

  @override
  String get terminalDismissNotice => '关闭提示';

  @override
  String get terminalNew => '新建终端';

  @override
  String get terminalNewSsh => '新建 SSH Terminal';

  @override
  String get terminalOpenDirectory => '选目录打开';

  @override
  String get terminalDisplaySettings => '终端显示设置';

  @override
  String get terminalNoWorkingDirectory => '（无工作目录）';

  @override
  String get terminalNoActive => '无活动终端';

  @override
  String get terminalCommandMode => '命令模式';

  @override
  String get terminalInteractiveMode => '交互模式';

  @override
  String get terminalControlInterrupt => 'Ctrl+C 中断';

  @override
  String get terminalControlSuspend => 'Ctrl+Z 挂起';

  @override
  String get terminalControlClear => 'Ctrl+L 清屏';

  @override
  String get terminalControlBackWord => 'Alt+B 前移单词';

  @override
  String get terminalControlForwardWord => 'Alt+F 后移单词';

  @override
  String get terminalControlKeys => '控制键';

  @override
  String get terminalVisibleOutputCopied => '已复制当前屏幕输出';

  @override
  String get terminalDisplay => '终端显示';

  @override
  String get terminalDisplayDescription => '仅调整本机显示，不会改变 PTY 和命令行为。';

  @override
  String get terminalPreviewOutput => '✓ 42 tests passed  中文输出预览';

  @override
  String terminalFontSize(Object value) {
    return '字号  $value';
  }

  @override
  String terminalLineHeight(Object value) {
    return '行高  $value';
  }

  @override
  String get terminalColorTheme => '配色主题';

  @override
  String get terminalThemeSystem => '跟随系统';

  @override
  String get terminalThemeProfessionalDark => '专业深色';

  @override
  String get terminalThemeHighContrastDark => '高对比深色';

  @override
  String get terminalThemeSoftLight => '柔和浅色';

  @override
  String get terminalCursorStyle => '光标样式';

  @override
  String get terminalCursorBar => '竖线';

  @override
  String get terminalCursorBlock => '方块';

  @override
  String get terminalCursorUnderline => '下划线';

  @override
  String get terminalContentPadding => '终端内边距';

  @override
  String get terminalContentPaddingHint => '关闭后可显示更多列';

  @override
  String get terminalResetDisplay => '恢复推荐设置';

  @override
  String get terminalCommandHint => '输入命令…';

  @override
  String get terminalRunCommand => '执行命令';

  @override
  String get terminalPaste => '粘贴';

  @override
  String get terminalClear => '清屏';

  @override
  String get terminalSendToChat => '发送到聊天';

  @override
  String get terminalInteractiveHint => '交互模式 · 输入直接发送到 PTY';

  @override
  String get terminalMoreActions => '更多终端操作';

  @override
  String get terminalCopySelection => '复制选中内容';

  @override
  String get terminalSendSelectionToChat => '发送选中内容到聊天';

  @override
  String get terminalOpenOtherDirectory => '在其他目录打开终端';

  @override
  String get terminalManageSessions => '管理终端会话';

  @override
  String get terminalPrivacyHistory => '隐私与历史';

  @override
  String get terminalPrivacyDescription => '默认不持久化命令历史和终端输出。';

  @override
  String get terminalSaveCommandHistory => '保存命令历史';

  @override
  String get terminalSaveOutputSnapshots => '保存终端输出快照';

  @override
  String get terminalClearSavedData => '清除已保存的历史和快照';

  @override
  String get terminalClearDataQuestion => '清除历史和快照？';

  @override
  String get terminalClearDataWarning => '已保存的命令历史和终端输出快照将被永久删除，此操作无法撤销。';

  @override
  String filesRevealFailed(String error) {
    return '无法在文件管理器中显示：$error';
  }

  @override
  String get filesLargeDownloadQuestion => '下载较大文件？';

  @override
  String filesLargeDownloadDescription(String name, String size) {
    return '「$name」约 $size MB，下载可能较慢并占用本机存储。';
  }

  @override
  String get filesContinueDownload => '继续下载';

  @override
  String get filesLargeEditQuestion => '打开大文件？';

  @override
  String filesLargeEditDescription(String name, String size) {
    return '「$name」约 $size MB，加载到编辑器中可能较慢。';
  }

  @override
  String get filesContinueEdit => '仍然打开';

  @override
  String get filesFolderDownloadQuestion => '下载文件夹？';

  @override
  String filesFolderDownloadDescription(String name) {
    return '「$name」将打包为 ZIP 后下载到本机。大文件夹可能较慢并占用存储。';
  }

  @override
  String get filesArchiveDownload => '打包下载';

  @override
  String filesDownloadedPath(String path) {
    return '已下载到 $path（路径已复制）';
  }

  @override
  String filesDownloadFailed(String error) {
    return '下载失败：$error';
  }

  @override
  String get filesSelectDownloadItem => '请选择至少一个文件或文件夹';

  @override
  String filesDownloadSummary(int success, int failed, int skipped) {
    return '已下载 $success 项，失败 $failed 项，跳过 $skipped 项';
  }

  @override
  String get filesRevealOnServer => '在服务器上显示';

  @override
  String get filesRevealOnServerDescription => '于 Hermes 所在机器打开';

  @override
  String get filesDetails => '详细信息';

  @override
  String get filesDownloading => '下载中…';

  @override
  String get filesDownloadFolderZip => '下载文件夹（ZIP）';

  @override
  String get filesDownloadToDevice => '下载到本机';

  @override
  String get filesCopyToClipboard => '复制到剪贴板';

  @override
  String get filesCopiedPasteHint => '已复制；进入目标文件夹后点粘贴';

  @override
  String get filesCutToClipboard => '剪切到剪贴板';

  @override
  String get filesCutPasteHint => '已剪切；进入目标文件夹后点粘贴';

  @override
  String get filesRename => '重命名';

  @override
  String get filesCopyPath => '复制路径';

  @override
  String get filesPathCopied => '已复制路径';

  @override
  String get filesCopyRelativePath => '复制相对路径';

  @override
  String get filesRelativePathCopied => '已复制相对路径';

  @override
  String get filesLink => '链接';

  @override
  String filesInfoPath(String value) {
    return '路径：$value';
  }

  @override
  String filesInfoType(String value) {
    return '类型：$value';
  }

  @override
  String filesInfoSize(int value) {
    return '大小：$value B';
  }

  @override
  String filesInfoModified(String value) {
    return '修改时间：$value';
  }

  @override
  String filesInfoReadable(String value) {
    return '可读：$value';
  }

  @override
  String filesInfoWritable(String value) {
    return '可写：$value';
  }

  @override
  String filesMovedCount(int count) {
    return '已移动 $count 项';
  }

  @override
  String filesCopiedCount(int count) {
    return '已复制 $count 项';
  }

  @override
  String filesPasteFailed(String error) {
    return '粘贴失败：$error';
  }

  @override
  String get filesConfirmDelete => '确认删除';

  @override
  String filesDeleteSelectedDescription(int count) {
    return '删除选中的 $count 项？此操作不可撤销。';
  }

  @override
  String filesDeleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String get filesNewFile => '新建文件';

  @override
  String get filesFileName => '文件名';

  @override
  String filesCreateFileFailed(String error) {
    return '创建文件失败：$error';
  }

  @override
  String filesNewSessionPrompt(String references) {
    return '请查看并处理以下文件：\n$references';
  }

  @override
  String get filesNewFolder => '新建文件夹';

  @override
  String get filesNewName => '新名称';

  @override
  String filesRenameFailed(String error) {
    return '重命名失败：$error';
  }

  @override
  String filesDeleteFolderDescription(String name) {
    return '删除目录「$name」及其所有内容？';
  }

  @override
  String filesDeleteFileDescription(String name) {
    return '删除文件「$name」？';
  }

  @override
  String get filesFolderName => '文件夹名称';

  @override
  String filesCreateFolderFailed(String error) {
    return '创建文件夹失败：$error';
  }

  @override
  String get filesSelectWorkspaceDirectory => '选择工作区目录';

  @override
  String filesSelectedCount(int count) {
    return '已选 $count';
  }

  @override
  String get filesSwitchToDirectoryBrowser => '切换到目录浏览';

  @override
  String get filesSwitchToProjectTree => '切换到项目树';

  @override
  String get filesOpenInGit => '在 Git 中打开';

  @override
  String get filesNewSessionForDirectory => '当前目录新建会话';

  @override
  String get filesSendSelectionToNewSession => '所选文件发到新会话';

  @override
  String get filesDownloadSelected => '下载选中项';

  @override
  String get filesCopySelected => '复制选中项';

  @override
  String get filesCutSelected => '剪切选中项';

  @override
  String get filesDeleteSelected => '删除选中项';

  @override
  String get filesClearSelection => '取消选择';

  @override
  String get filesMoveHere => '移动到此处';

  @override
  String get filesCopyHere => '复制到此处';

  @override
  String get filesSelectCurrentDirectory => '选择当前目录';

  @override
  String filesUseAsWorkspace(String name) {
    return '使用「$name」作为工作区';
  }

  @override
  String get filesSelectPreview => '选择文件预览';

  @override
  String get filesSelectPreviewDescription => '点击左侧文件在此编辑或预览';

  @override
  String get filesFilterProjectTree => '筛选已加载的项目树…';

  @override
  String get filesSearchDirectory => '搜索当前目录…';

  @override
  String get filesLoadingDirectory => '加载目录…';

  @override
  String get filesNoMatches => '没有匹配的文件';

  @override
  String get filesActions => '文件操作';

  @override
  String get filesUnableToRead => '无法读取';

  @override
  String get filesDownload => '下载';

  @override
  String get filesCut => '剪切';

  @override
  String get configTabModel => '模型';

  @override
  String get configTabChat => '对话';

  @override
  String get configTabMemory => '记忆';

  @override
  String get configTabVoice => '语音';

  @override
  String get configTabToolsKeys => '工具与密钥';

  @override
  String configLoadFailed(String error) {
    return '加载配置失败：$error';
  }

  @override
  String get configAuxVision => '视觉理解';

  @override
  String get configAuxWebExtract => '网页提取';

  @override
  String get configAuxCompression => '上下文压缩';

  @override
  String get configAuxSkillsHub => '技能中心';

  @override
  String get configAuxApproval => '审批判断';

  @override
  String get configAuxMcp => 'MCP 辅助';

  @override
  String get configAuxTitleGeneration => '标题生成';

  @override
  String get configAuxReview => '代码审查';

  @override
  String get configAuxTriage => '任务分诊';

  @override
  String get configAuxKanban => '看板拆解';

  @override
  String get configAuxProfile => '配置描述';

  @override
  String get configAuxCurator => '内容整理';

  @override
  String get configPersonalityDisplay => '人格（display.personality）';

  @override
  String get configPersonality => '人格';

  @override
  String get configTimezone => '时区（IANA）';

  @override
  String get configShowReasoning => '显示推理块';

  @override
  String get configMessageReactions => '启用消息表情回应';

  @override
  String get configApprovalMode => '审批模式';

  @override
  String get configYoloApproval => 'YOLO 自动批准';

  @override
  String get configChatFieldsUnavailable => '后端未返回对话字段';

  @override
  String get configChatFieldsUnavailableDescription =>
      'GET /api/v1/config 没有返回 personality、timezone、approvals 或 yolo。';

  @override
  String get configPersistentMemory => '持久记忆';

  @override
  String get configUserProfile => '用户档案';

  @override
  String get configMemoryBudget => '记忆预算（字符）';

  @override
  String get configProfileBudget => '档案预算（字符）';

  @override
  String get configMemoryProvider => '记忆提供者';

  @override
  String get configContextEngine => '上下文引擎';

  @override
  String get configAutoCompression => '自动压缩';

  @override
  String get configCompressionThreshold => '压缩阈值';

  @override
  String get configCompressionRatio => '压缩目标比例';

  @override
  String get configProtectRecent => '保护最近 N 条';

  @override
  String get configMemoryFieldsUnavailable => '后端未返回记忆字段';

  @override
  String get configMemoryFieldsUnavailableDescription =>
      'GET /api/v1/config 没有返回 memory、compression 或 context。';

  @override
  String get configVoice => '音色';

  @override
  String get configVoiceModel => '模型';

  @override
  String get configVoiceId => '音色 ID';

  @override
  String get configModelId => '模型 ID';

  @override
  String get configLanguage => '语言';

  @override
  String get configSpeechSpeed => '语速';

  @override
  String get configAutoSpeechTags => '自动语音标签';

  @override
  String get configStreamingLatency => '流式延迟优化等级';

  @override
  String get configSampleRate => '采样率';

  @override
  String get configBitRate => '比特率';

  @override
  String get configDevice => '设备';

  @override
  String get configLanguageCode => '语言代码';

  @override
  String get configAudioEvents => '标注音频事件';

  @override
  String get configDiarization => '说话人分离';

  @override
  String get configSpeechToText => '语音转文字';

  @override
  String get configEchoTranscripts => '回显转写';

  @override
  String get configSttProvider => 'STT 提供商';

  @override
  String get configTtsProvider => 'TTS 提供商';

  @override
  String get configAutoReadReplies => '自动朗读回复';

  @override
  String get configMaxRecordingSeconds => '最长录音秒数';

  @override
  String get configRecordShortcut => '录音快捷键';

  @override
  String get configDirectVoiceService => '客户端直连语音服务';

  @override
  String get configVoiceFieldsUnavailable => '后端未返回语音字段';

  @override
  String get configVoiceFieldsUnavailableDescription =>
      'GET /api/v1/config 没有返回 stt、tts 或 voice。';

  @override
  String get configProviderApiKeys => '模型提供者 API 密钥';

  @override
  String get configNoProviders => '暂无已配置的提供者';

  @override
  String get configNoProvidersDescription => '添加 API 密钥以启用模型提供者';

  @override
  String get configEnvironmentVariables => '环境变量';

  @override
  String get configConfigured => '已配置';

  @override
  String get configNotConfigured => '未配置';

  @override
  String configAvailableModels(int count) {
    return '可用模型：$count 个';
  }

  @override
  String configDisconnectedProvider(String name) {
    return '已断开 $name';
  }

  @override
  String configDisconnectFailed(String error) {
    return '断开失败：$error';
  }

  @override
  String get configUpdateKey => '更新密钥';

  @override
  String get configAddKey => '添加密钥';

  @override
  String configProviderApiKey(String name) {
    return '$name API 密钥';
  }

  @override
  String configProviderKeySaved(String name) {
    return '已保存 $name API 密钥';
  }

  @override
  String get configSaved => '已保存';

  @override
  String get configPressEnterToSave => '按回车保存';

  @override
  String get configEnterNumber => '请输入数字';

  @override
  String get configNewValueOptional => '新值（留空则不修改）';

  @override
  String get configValue => '值';

  @override
  String configRevealFailed(String error) {
    return '查看失败：$error';
  }

  @override
  String configDeleteVariableQuestion(String key) {
    return '删除 $key？';
  }

  @override
  String get configDeleteVariableDescription =>
      '该环境变量将从服务器 .env 中永久删除，此操作无法撤销。';

  @override
  String get configAddEnvironmentVariable => '添加环境变量';

  @override
  String get configVariableName => '变量名';

  @override
  String get configNoEnvironmentVariables => '暂无环境变量';

  @override
  String get configNoEnvironmentVariablesDescription => '添加自定义环境变量以配置工具或提供商';

  @override
  String get configHideAdvancedVariables => '隐藏高级变量';

  @override
  String configShowAdvancedVariables(int count) {
    return '显示高级变量（$count）';
  }

  @override
  String get configSet => '已设置';

  @override
  String get configNotSet => '未设置';

  @override
  String get configVoiceIdManual => '按回车保存（未获取到账号语音列表，可手动填写）';

  @override
  String configVoicesLoadFailed(String error) {
    return '加载账号语音失败：$error。可手动填写 ID 并按回车保存。';
  }

  @override
  String chatDraftHandoffSaveFailed(String error) {
    return '草稿已保留在当前页面，但未能保存到服务器：$error';
  }

  @override
  String get toolPlanTitle => '计划';

  @override
  String get toolPlanCopy => '复制计划';

  @override
  String get toolPlanCopied => '计划已复制';

  @override
  String get toolValueNotProvided => '未提供';

  @override
  String get toolCommand => '命令';

  @override
  String get toolWaitingCommand => '等待命令';

  @override
  String get toolOutput => '输出';

  @override
  String get toolErrorOutput => '错误输出';

  @override
  String toolExitCode(int code) {
    return '退出码：$code';
  }

  @override
  String get toolCode => '代码';

  @override
  String toolCodeLanguage(String language) {
    return '代码 · $language';
  }

  @override
  String get toolWaitingCode => '等待代码内容';

  @override
  String get toolExecutionResult => '执行结果';

  @override
  String toolChangedFiles(int count) {
    return '变更文件 · $count';
  }

  @override
  String get toolPatchContent => '补丁内容';

  @override
  String get toolWaitingPatch => '等待补丁内容';

  @override
  String get toolResult => '结果';

  @override
  String get toolSearchQuery => '搜索词';

  @override
  String get toolSearchingWeb => '搜索网络';

  @override
  String toolSearchResults(int count) {
    return '搜索结果 · $count';
  }

  @override
  String get toolNoResults => '暂无结果';

  @override
  String get toolLink => '链接';

  @override
  String get toolContent => '内容';

  @override
  String get toolFile => '文件';

  @override
  String get toolReadingFile => '读取文件';

  @override
  String get toolWritingFile => '写入文件';

  @override
  String get toolWriteContent => '写入内容';

  @override
  String toolFileList(int count) {
    return '文件列表 · $count';
  }

  @override
  String get toolNoFiles => '暂无文件';

  @override
  String get toolDetails => '详情';

  @override
  String get toolNoReadableContent => '（暂无可读内容）';

  @override
  String get toolWaitingForResult => '等待工具返回';

  @override
  String get toolUntitledResult => '未命名结果';

  @override
  String get toolCopyAll => '复制全部';

  @override
  String toolHiddenRestore(String name) {
    return '已隐藏 $name，点击恢复';
  }

  @override
  String get toolReadableView => '可读视图';

  @override
  String get toolRawJsonView => '原始 JSON 视图';

  @override
  String get toolHideRow => '隐藏此工具行';

  @override
  String get toolCopyResult => '复制结果';

  @override
  String toolRawDetailsTitle(String name) {
    return '$name 原始详情';
  }

  @override
  String get toolViewRawDetails => '查看原始详情';

  @override
  String get toolArguments => '参数';

  @override
  String get toolNoDetailedData => '（暂无详细数据）';

  @override
  String toolArgumentDetailsTitle(String key) {
    return '$key 参数';
  }

  @override
  String toolTapForFullContent(int count) {
    return '[点击查看完整内容（$count 字符）]';
  }

  @override
  String toolContentTooLong(int count) {
    return '内容过长（共 $count 字符）';
  }

  @override
  String toolFullResultTitle(String name) {
    return '$name 完整结果';
  }

  @override
  String get toolViewFull => '查看完整';

  @override
  String kanbanDeleteAttachment(String name) {
    return '删除 $name？';
  }

  @override
  String get kanbanCannotUndo => '此操作无法撤销。';

  @override
  String kanbanOperationFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get kanbanNoLog => '暂无日志';

  @override
  String get kanbanAddChildTask => '添加子任务';

  @override
  String get kanbanTaskId => '任务 ID';

  @override
  String get kanbanDescription => '说明';

  @override
  String get kanbanCommandCopied => '命令已复制';

  @override
  String get kanbanViewLog => '查看日志';

  @override
  String get kanbanEstimate => '估算';

  @override
  String get kanbanDecompose => '拆解';

  @override
  String get kanbanNoDescription => '无描述';

  @override
  String get kanbanDiagnostics => '诊断';

  @override
  String kanbanComments(int count) {
    return '评论（$count）';
  }

  @override
  String get kanbanAddComment => '添加评论';

  @override
  String kanbanDependencies(int parents, int children) {
    return '依赖：$parents 个父任务，$children 个子任务';
  }

  @override
  String kanbanChildTask(String id) {
    return '子任务 $id';
  }

  @override
  String kanbanAttachments(int count) {
    return '附件（$count）';
  }

  @override
  String kanbanEventTimeline(int count) {
    return '事件时间线（$count）';
  }

  @override
  String kanbanRuns(int count) {
    return '运行（$count）';
  }

  @override
  String get kanbanUploadAttachment => '上传附件';

  @override
  String kanbanAttachmentBytes(int count) {
    return '$count 字节';
  }

  @override
  String messageReactionFailed(String error) {
    return '表情回应失败：$error';
  }

  @override
  String get messageRenderFailed => '这条消息无法显示';

  @override
  String get messageRenderFailedDescription => '其他消息不受影响';

  @override
  String get messageRemoveMyReaction => '移除我的回应';

  @override
  String get messageAgentReaction => '代理回应';

  @override
  String get messageAddReaction => '添加表情回应';

  @override
  String get messageSearchEmoji => '搜索表情';

  @override
  String messageImageSaveFailed(String error) {
    return '保存图片失败：$error';
  }

  @override
  String get messageGeneratingImage => '正在生成图片…';

  @override
  String get messageImageGenerationFailed => '图片生成失败';

  @override
  String get messageWaitingForImage => '等待图片结果';

  @override
  String get messageGeneratedImage => '生成的图片';

  @override
  String get messageImageLinkCopied => '已复制图片链接';

  @override
  String get messageOpenInBrowser => '在浏览器打开';

  @override
  String get messageMcpSetup => 'MCP 服务配置';

  @override
  String messageMcpServer(String server) {
    return 'MCP · $server';
  }

  @override
  String get messageMcpSetupFailed => '配置失败，可在 MCP 设置中重试';

  @override
  String get messageMcpSetupWaiting => '等待完成配置';

  @override
  String get messageMcpSetupComplete => '配置已完成';

  @override
  String get messageOpenMcpSettings => '打开 MCP 设置';

  @override
  String get messageFileChanges => '文件变更';

  @override
  String get messageViewDiff => '查看差异';

  @override
  String get messageOpenLink => '打开链接';

  @override
  String messageSendingToAgent(String name) {
    return '正在发送给 $name…';
  }

  @override
  String messageSentToAgent(String name) {
    return '已发送给 $name';
  }

  @override
  String messageReplyFromAgent(String name) {
    return '来自 $name 的回复';
  }

  @override
  String messageRepliedToAgent(String name) {
    return '已回复 $name';
  }

  @override
  String messageFromAgent(String name) {
    return '来自代理 · $name';
  }

  @override
  String get messageSteered => '已引导';

  @override
  String get messageHermesAvatar => 'Hermes 助手头像';

  @override
  String get messageSourceWechat => '微信';

  @override
  String get messageSourceFeishu => '飞书';

  @override
  String get messageSourceDesktop => '桌面版';

  @override
  String get messageRestoreVersion => '恢复此版本';

  @override
  String get messagePreviousVersion => '上一个版本';

  @override
  String get messageNextVersion => '下一个版本';

  @override
  String get messageCopyText => '复制文本';

  @override
  String get messageCopyMarkdown => '复制为 Markdown';

  @override
  String get messageBranchFromHere => '从此消息新建分支';

  @override
  String get messageSpeakDisconnected => '尚未连接服务器，无法朗读';

  @override
  String get messageSpeakFailed => '语音播报失败，请稍后重试';

  @override
  String get messageStopSpeaking => '停止朗读';

  @override
  String get messageSpeak => '朗读';

  @override
  String get sessionDetailMessages => '消息';

  @override
  String get sessionDetailTools => '工具';

  @override
  String get sessionDetailEstimated => '预估';

  @override
  String get sessionDetailCost => '费用';

  @override
  String get sessionDetailDuration => '时长';

  @override
  String get sessionDetailInfo => '会话信息';

  @override
  String get sessionDetailSource => '来源';

  @override
  String get sessionDetailModel => '模型';

  @override
  String get sessionDetailStarted => '开始';

  @override
  String get sessionDetailLastActivity => '最后活动';

  @override
  String get sessionDetailEnded => '结束';

  @override
  String get sessionDetailEndReason => '结束原因';

  @override
  String get sessionDetailHandoff => '交接';

  @override
  String get sessionDetailHandoffError => '交接异常';

  @override
  String get sessionDetailTokensBilling => 'Token 与计费';

  @override
  String get sessionDetailInputOutput => '输入 / 输出';

  @override
  String get sessionDetailCacheReadWrite => '缓存读 / 写';

  @override
  String get sessionDetailReasoningTokens => '推理 Token';

  @override
  String get sessionDetailBillingSource => '计费来源';

  @override
  String get sessionDetailContextSource => '上下文与来源';

  @override
  String get sessionDetailWorkingDirectory => '工作目录';

  @override
  String get sessionDetailGitBranch => 'Git 分支';

  @override
  String get sessionDetailContact => '联系人';

  @override
  String get sessionDetailChatType => '聊天类型';

  @override
  String get sessionDetailUserId => '用户 ID';

  @override
  String get sessionDetailParentSession => '父会话';

  @override
  String get sessionDetailRewindCount => '回退次数';

  @override
  String get sessionDetailCompressionFailed => '压缩暂时失败';

  @override
  String get sessionDetailOpen => '打开会话';

  @override
  String get sessionActionOpenWorkspace => '在工作区中打开';

  @override
  String get sessionActionUnpin => '取消置顶';

  @override
  String get sessionActionPin => '置顶';

  @override
  String get sessionActionAppearance => '外观';

  @override
  String get sessionActionDuplicate => '复制会话';

  @override
  String get sessionActionShare => '分享会话';

  @override
  String get sessionActionExport => '导出会话';

  @override
  String get sessionActionMoveProject => '移动到项目';

  @override
  String get sessionActionUnarchive => '取消归档';

  @override
  String get sessionActionArchive => '归档';

  @override
  String get sessionActionStopResponse => '停止响应';

  @override
  String get sessionActionAppearanceTitle => '会话外观';

  @override
  String sessionActionRenameFailed(String error) {
    return '重命名失败：$error';
  }

  @override
  String get sessionActionUnarchived => '已取消归档';

  @override
  String get sessionActionArchived => '已归档';

  @override
  String sessionActionFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get sessionActionUnpinned => '已取消置顶';

  @override
  String get sessionActionPinned => '已置顶';

  @override
  String get sessionActionMoved => '会话已移动';

  @override
  String sessionActionMoveFailed(String error) {
    return '移动失败：$error';
  }

  @override
  String sessionActionBranchCreated(String id) {
    return '已创建分支：$id';
  }

  @override
  String get sessionActionCopyCreated => '已创建会话副本';

  @override
  String sessionActionDuplicateFailed(String error) {
    return '复制会话失败：$error';
  }

  @override
  String get sessionActionShareCreated => '分享链接已创建';

  @override
  String get sessionActionShareWarning => '任何获得此链接的人都可以查看会话内容。';

  @override
  String sessionActionShareFailed(String error) {
    return '分享失败：$error';
  }

  @override
  String get sessionActionStopRequested => '已请求停止响应';

  @override
  String get sessionActionExportMarkdownHint => '适合浏览和分享';

  @override
  String get sessionActionExportJsonHint => '保留完整结构化数据';

  @override
  String get sessionActionExportCopiedWeb => '已复制导出内容到剪贴板（Web 不支持本地落盘）';

  @override
  String sessionActionExported(String path) {
    return '已导出到 $path（路径已复制）';
  }

  @override
  String sessionActionExportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get sessionsNoDetail => '暂无会话详情';

  @override
  String get sessionsNoDetailDescription => '调整筛选条件后查看会话摘要';

  @override
  String get sessionsAllProjects => '所有项目';

  @override
  String get sessionsProject => '项目';

  @override
  String get sessionsSearchHint => '搜索标题、预览或工作目录…';

  @override
  String get sessionsToday => '今日';

  @override
  String get sessionsThisWeek => '本周';

  @override
  String get sessionsStarred => '星标';

  @override
  String get sessionsSortNewest => '时间：新到旧';

  @override
  String get sessionsSortOldest => '时间：旧到新';

  @override
  String get sessionsSortTitle => '标题：A 到 Z';

  @override
  String get sessionsSortMessages => '消息数：多到少';

  @override
  String get sessionsSortMethod => '排序方式';

  @override
  String get sessionsLoading => '加载会话…';

  @override
  String get sessionsViewFullDetails => '查看完整详情';

  @override
  String get sessionsSettings => '设置';

  @override
  String get requestHermesQuestion => 'Hermes 询问';

  @override
  String get requestPending => '待处理请求';

  @override
  String get requestAlwaysAllowQuestion => '总是允许？';

  @override
  String get requestAlwaysAllowDescription => '这会把该操作写入配置为永久允许规则，之后同类操作将不再询问。';

  @override
  String requestAlwaysAllowDetail(String detail) {
    return '这会把「$detail」写入配置为永久允许规则，之后同类操作将不再询问。';
  }

  @override
  String get requestNoActiveSession => '没有活动会话';

  @override
  String get requestConnectionUnavailable => '请求所属连接不可用';

  @override
  String requestRespondFailed(String error) {
    return '响应失败：$error';
  }

  @override
  String get requestAnswerFailed => '回答发送失败，请稍后重试';

  @override
  String get requestMcpNameMissing => '请求未包含 MCP 服务器名称';

  @override
  String get requestOAuthTimeout => 'OAuth 授权超时';

  @override
  String get requestMcpTestFailed => 'MCP 连接测试失败';

  @override
  String get requestMcpSetupFailed => 'MCP 配置失败';

  @override
  String requestConfigureMcp(String name) {
    return '配置 $name';
  }

  @override
  String get requestCloseQuestion => '关闭请求？';

  @override
  String get requestCloseDescription => '关闭后该请求将无法恢复，agent 将保持等待。';

  @override
  String get requestProcessed => '已处理';

  @override
  String get requestInteractionProcessed => '交互请求已处理';

  @override
  String requestServer(String name) {
    return '服务器：$name';
  }

  @override
  String get requestSubmitAllAnswers => '提交全部回答';

  @override
  String get requestConfigureLater => '暂不配置';

  @override
  String get requestConfiguring => '正在配置…';

  @override
  String get requestInstallEnable => '安装并启用';

  @override
  String get requestEnterContent => '输入内容';

  @override
  String get requestEnterText => '输入…';

  @override
  String requestMorePending(int count) {
    return '还有 $count 个待处理';
  }

  @override
  String get requestAllowOnce => '允许一次';

  @override
  String get requestAllowSession => '本次会话允许';

  @override
  String requestSubmitSelected(int count) {
    return '提交（已选 $count）';
  }

  @override
  String get requestCustomAnswer => '其他（自定义回答）';

  @override
  String get requestRecommended => '推荐';

  @override
  String messagingLoadFailed(String error) {
    return '加载消息平台失败：$error';
  }

  @override
  String messagingPlatformEnabled(String name) {
    return '$name 已启用';
  }

  @override
  String messagingPlatformDisabled(String name) {
    return '$name 已停用';
  }

  @override
  String messagingUpdateFailed(String error) {
    return '更新失败：$error';
  }

  @override
  String messagingTestPassed(String name) {
    return '$name 连接测试通过';
  }

  @override
  String get messagingTestNotPassed => '连接测试未通过';

  @override
  String messagingTestFailed(String error) {
    return '测试失败：$error';
  }

  @override
  String messagingConfigSaved(String name) {
    return '$name 配置已保存，可重启 Gateway 应用连接变更';
  }

  @override
  String messagingSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String messagingApproved(String name) {
    return '已批准 $name';
  }

  @override
  String messagingApproveFailed(String error) {
    return '批准失败：$error';
  }

  @override
  String get messagingRevokeTitle => '撤销授权';

  @override
  String messagingRevokeQuestion(String name) {
    return '确定撤销 $name 的消息访问权限？';
  }

  @override
  String get messagingRevoke => '撤销';

  @override
  String get messagingRevoked => '授权已撤销';

  @override
  String messagingRevokeFailed(String error) {
    return '撤销失败：$error';
  }

  @override
  String get messagingRestartQuestion => '重启 Gateway？';

  @override
  String get messagingRestartWarning =>
      '这会中断所有连接到该 Gateway 的会话和客户端，操作完成后会自动重新连接。';

  @override
  String get messagingRestarting => 'Gateway 正在重启';

  @override
  String messagingRestartFailed(String error) {
    return 'Gateway 重启失败：$error';
  }

  @override
  String get messagingTitle => '消息平台';

  @override
  String get messagingRestartGateway => '重启 Gateway';

  @override
  String get messagingLoading => '读取消息平台…';

  @override
  String get messagingPendingApproval => '待批准';

  @override
  String get messagingPlatforms => '平台';

  @override
  String get messagingEmpty => '暂无消息平台';

  @override
  String get messagingEmptyDescription => '服务器未返回可配置的消息平台';

  @override
  String get messagingAuthorizedUsers => '已授权用户';

  @override
  String get messagingConfigure => '配置';

  @override
  String get messagingTest => '测试';

  @override
  String get messagingOpenDocs => '打开文档';

  @override
  String get messagingUnknownUser => '未知用户';

  @override
  String get messagingApprove => '批准';

  @override
  String get messagingStateDisabled => '已停用';

  @override
  String get messagingStateGatewayStopped => '已配置，Gateway 未运行';

  @override
  String get messagingStateFatal => '严重错误';

  @override
  String get messagingStateStartupFailed => '启动失败';

  @override
  String get messagingStateConfigured => '已配置';

  @override
  String get messagingStateNeedsConfig => '需要配置';

  @override
  String messagingPlatformConfig(String name) {
    return '$name 配置';
  }

  @override
  String get messagingNoEditableConfig => '此平台没有可编辑的配置项。';

  @override
  String get messagingAdvancedSettings => '高级设置';

  @override
  String get messagingSetLeaveBlank => '已设置，留空则保持不变';

  @override
  String get messagingEnterNewValue => '输入新值';

  @override
  String get messagingShow => '显示';

  @override
  String get messagingClearSavedValue => '清除已保存的值';

  @override
  String get fileTreeListView => '列表视图';

  @override
  String get fileTreeTreeView => '树视图';

  @override
  String get fileTreeAttachToChat => '附加到聊天';

  @override
  String get projectAddFolder => '添加文件夹';

  @override
  String get projectFolderPath => '文件夹路径';

  @override
  String get projectFolderLabelOptional => '标签（可选）';

  @override
  String get projectCreate => '创建项目';

  @override
  String get projectLoading => '加载项目…';

  @override
  String get projectEmpty => '还没有项目';

  @override
  String get projectEmptyDescription => '创建项目来组织工作目录与会话';

  @override
  String get projectWorkspace => '项目工作区';

  @override
  String get projectEditAppearance => '编辑外观';

  @override
  String get projectColor => '颜色';

  @override
  String get projectIcon => '图标';

  @override
  String projectAppearanceSaveFailed(String error) {
    return '保存外观失败：$error';
  }

  @override
  String get projectRename => '重命名';

  @override
  String get projectRenameTitle => '重命名项目';

  @override
  String get projectName => '项目名称';

  @override
  String projectRenameFailed(String error) {
    return '重命名项目失败：$error';
  }

  @override
  String projectDeleteQuestion(String name) {
    return '删除 $name？';
  }

  @override
  String get projectDeleteDescription => '项目本身会被删除，但其中的会话和文件不受影响。此操作不可恢复。';

  @override
  String projectDeleteFailed(String error) {
    return '删除项目失败：$error';
  }

  @override
  String projectCreateFailed(String error) {
    return '创建项目失败：$error';
  }

  @override
  String get projectManagement => '项目管理';

  @override
  String get projectLoadFailed => '加载项目失败';

  @override
  String get projectNoMoveTargets => '没有其他可移动的项目';

  @override
  String get projectNoMoveTargetsDescription => '项目需要配置有效的工作目录后才能接收会话';

  @override
  String get projectNew => '新建项目';

  @override
  String get projectEditTitle => '编辑项目';

  @override
  String get projectPrimaryPath => '主工作目录路径';

  @override
  String get projectPrimaryPathHint => '例如 /home/user/projects/my-app';

  @override
  String get projectDescriptionOptional => '描述（可选）';

  @override
  String get projectRequiredFields => '请填写项目名称和工作目录';

  @override
  String get projectCreated => '项目已创建';

  @override
  String get projectUpdated => '项目已更新';

  @override
  String projectSaveFailed(String error) {
    return '保存项目失败：$error';
  }

  @override
  String get projectDeleteTitle => '删除项目？';

  @override
  String projectDeleteNamedDescription(String name) {
    return '项目「$name」将被删除。关联的会话不会被删除。';
  }

  @override
  String get projectDeleted => '项目已删除';

  @override
  String subagentsLoadFailed(String error) {
    return '子代理加载失败：$error';
  }

  @override
  String get subagentsEmpty => '无子代理活动';

  @override
  String get subagentsOpenSessionDescription => '打开一个会话以查看其子代理树';

  @override
  String get subagentsCurrentSessionEmpty => '当前会话没有正在运行的子代理';

  @override
  String get subagentsCurrentSession => '当前会话';

  @override
  String subagentsSession(String id) {
    return '会话 $id';
  }

  @override
  String subagentsCount(int count) {
    return '$count 个子代理';
  }

  @override
  String subagentsRunningCount(int count) {
    return '运行中 $count';
  }

  @override
  String subagentsFailedCount(int count) {
    return '失败 $count';
  }

  @override
  String subagentsToolCalls(int count) {
    return '$count 次工具调用';
  }

  @override
  String subagentsFiles(int count) {
    return '$count 个文件';
  }

  @override
  String get subagentsInterrupt => '中断';

  @override
  String get subagentsInterruptSent => '已发送中断信号';

  @override
  String subagentsInterruptFailed(String error) {
    return '中断失败：$error';
  }

  @override
  String get subagentsOpenSession => '打开会话';

  @override
  String subagentsOpenSessionFailed(String error) {
    return '打开子代理会话失败：$error';
  }

  @override
  String subagentsCurrentTool(String name) {
    return '工具：$name';
  }

  @override
  String subagentsTools(int count) {
    return '$count 次工具';
  }

  @override
  String subagentsFilesRead(int count) {
    return '读 $count';
  }

  @override
  String subagentsFilesWritten(int count) {
    return '写 $count';
  }

  @override
  String get subagentsStatusQueued => '排队中';

  @override
  String get subagentsStatusInterrupted => '已中断';

  @override
  String get subagentsStatusUnknown => '未知';

  @override
  String credentialsLoadFailed(String error) {
    return '加载凭证失败：$error';
  }

  @override
  String get credentialsSearchHint => '搜索凭证或提供商…';

  @override
  String get credentialsMissing => '缺失';

  @override
  String get credentialsNoMatches => '没有匹配的凭证';

  @override
  String get credentialsNoMatchesDescription => '调整搜索条件或状态过滤器';

  @override
  String get credentialsEmpty => '没有凭证提供商';

  @override
  String get credentialsEmptyDescription => '服务器未返回可配置的凭证提供商';

  @override
  String get credentialsGroupCloud => '云厂商';

  @override
  String get credentialsGroupModelProviders => '模型提供商';

  @override
  String get credentialsGroupThirdParty => '第三方服务';

  @override
  String get credentialsKeyRequired => '请选择提供商并输入 API Key 或 Token';

  @override
  String credentialsSaveFailed(String error) {
    return '保存凭证失败：$error';
  }

  @override
  String get credentialsAddTitle => '添加凭证';

  @override
  String get credentialsEditTitle => '编辑凭证';

  @override
  String get credentialsSaving => '保存中…';

  @override
  String credentialsApiKey(String name) {
    return '$name API Key / Token';
  }

  @override
  String get credentialsShowKey => '显示密钥';

  @override
  String get credentialsHideKey => '隐藏密钥';

  @override
  String get petCenterTitle => '宠物中心';

  @override
  String get petRename => '重命名';

  @override
  String get petDisable => '禁用宠物';

  @override
  String petRenameFailed(String error) {
    return '重命名失败：$error';
  }

  @override
  String petDisableFailed(String error) {
    return '禁用失败：$error';
  }

  @override
  String get petRenameTitle => '重命名宠物';

  @override
  String get petRenameHint => '输入新名字…';

  @override
  String get petUntitled => '未命名';

  @override
  String petStatus(String status) {
    return '状态：$status';
  }

  @override
  String get petGallery => '画廊';

  @override
  String get petGalleryEmpty => '暂无可用宠物';

  @override
  String get petGenerateNew => '生成新宠物';

  @override
  String get petStateWave => '打招呼';

  @override
  String get petStateJump => '跳跃';

  @override
  String get petStateCelebrate => '庆祝';

  @override
  String credentialsDisconnectQuestion(String name) {
    return '断开 $name？';
  }

  @override
  String get credentialsDisconnectDescription =>
      '保存的凭证将从 Hermes 服务器移除，之后可以重新添加。';

  @override
  String starmapLoadDetailFailed(String error) {
    return '读取节点详情失败：$error';
  }

  @override
  String get starmapRestoreMine => '还原为我的星图';

  @override
  String get starmapShareImport => '分享或导入';

  @override
  String get starmapResetView => '还原视图';

  @override
  String get starmapLoading => '读取星图…';

  @override
  String get starmapNoData => '暂无数据';

  @override
  String get starmapEmpty => '星图为空';

  @override
  String get starmapEmptyDescription => '在 Hermes 中积累更多知识后，节点会出现在此图中。';

  @override
  String get starmapShareTitle => '分享星图';

  @override
  String get starmapShareDescription => '复制下方代码分享你的星图；粘贴别人的代码后点击加载即可查看。';

  @override
  String get starmapShareCodeHint => '星图分享代码';

  @override
  String get starmapCopy => '复制';

  @override
  String get starmapLoad => '加载';

  @override
  String get starmapInvalidShareCode => '星图分享代码无效。';

  @override
  String get starmapPause => '暂停';

  @override
  String get starmapPlay => '播放';

  @override
  String get starmapSkillLegend => '技能';

  @override
  String get starmapMemoryLegend => '记忆';

  @override
  String get starmapChronologyLegend => '中心：最旧 · 外圈：最新';

  @override
  String starmapOpenNode(String name) {
    return '打开 $name';
  }

  @override
  String get starmapSaved => '已保存';

  @override
  String starmapSaveFailed(String error) {
    return '保存节点失败：$error';
  }

  @override
  String get starmapDeleteQuestion => '删除节点？';

  @override
  String starmapDeleteDescription(String name) {
    return '「$name」将从星图中移除。';
  }

  @override
  String get starmapDeleted => '节点已删除';

  @override
  String starmapDeleteFailed(String error) {
    return '删除节点失败：$error';
  }

  @override
  String starmapUseCount(int count) {
    return '使用 $count 次';
  }

  @override
  String get starmapContent => '内容';

  @override
  String get starmapSaving => '保存中…';

  @override
  String starmapCreatedBy(Object value) {
    return '创建者：$value';
  }

  @override
  String starmapSource(Object value) {
    return '来源：$value';
  }

  @override
  String get starmapStateArchived => '已归档';

  @override
  String configCenterLoadFailed(String error) {
    return '加载能力数据失败：$error';
  }

  @override
  String get configCenterKnowledgeTab => '知识';

  @override
  String get configCenterTitle => '能力管理';

  @override
  String get configCenterLoadErrorTitle => '加载能力失败';

  @override
  String get configCenterMcpEmptyDescription => '添加 MCP 服务器以连接外部工具和数据。';

  @override
  String get configCenterUrlOrCommand => 'URL 或命令';

  @override
  String get configCenterTransport => '传输方式';

  @override
  String get configCenterLocalStdio => 'Stdio（本地进程）';

  @override
  String configCenterMutationFailed(String error) {
    return '应用更改失败：$error';
  }

  @override
  String get configCenterKnowledgeTitle => '知识来源';

  @override
  String get configCenterKnowledgeEmpty => '暂无知识来源';

  @override
  String get configCenterKnowledgeEmptyDescription => '添加文件、文件夹或 URL 作为知识来源。';

  @override
  String get configCenterDatabase => '数据库';

  @override
  String configCenterKnowledgeMeta(String type, int count, String status) {
    return '$type · $count 个分块 · $status';
  }

  @override
  String get configCenterIndexed => '已索引';

  @override
  String get configCenterNotIndexed => '未索引';

  @override
  String get configCenterSkillsEmpty => '暂无技能';

  @override
  String get configCenterSkillsEmptyDescription => '服务器未返回当前配置文件的技能。';

  @override
  String get configCenterConfiguration => '配置';

  @override
  String get configCenterInstallPlugin => '安装插件';

  @override
  String get configCenterPluginsEmpty => '暂无插件';

  @override
  String get configCenterPluginsEmptyDescription => '安装插件以扩展 Hermes。';

  @override
  String get configCenterInstall => '安装';

  @override
  String get configCenterPluginUrl => '插件 URL 或标识符';

  @override
  String get fileEditorDiscardQuestion => '放弃未保存的修改？';

  @override
  String get fileEditorDiscardDescription => '返回将丢失当前编辑内容。';

  @override
  String get fileEditorKeepEditing => '继续编辑';

  @override
  String get fileEditorDiscard => '放弃';

  @override
  String get fileEditorDisk => '磁盘';

  @override
  String get fileEditorEditor => '编辑器';

  @override
  String get fileEditorConflictDescription => '磁盘上的文件已变化。可覆盖保存、重载磁盘版本，或取消。';

  @override
  String get fileEditorConflictTitle => '文件已在外部修改';

  @override
  String get fileEditorOverwriteSave => '覆盖保存';

  @override
  String get fileEditorReloaded => '已重载磁盘版本';

  @override
  String get fileEditorSaved => '已保存';

  @override
  String fileEditorSaveFailed(String error) {
    return '保存文件失败：$error';
  }

  @override
  String get fileEditorSaving => '保存中…';

  @override
  String fileEditorUnsavedTitle(String name) {
    return '$name，有未保存的修改';
  }

  @override
  String get fileEditorEmpty => '（空）';

  @override
  String get fileEditorBinaryTitle => '该文件无法以文本方式编辑';

  @override
  String get fileEditorBinaryDescription =>
      '这看起来是一个二进制文件（图片、压缩包或可执行文件）。用文本编辑器打开并保存会损坏原文件，因此已禁用编辑——请改为下载到设备。';

  @override
  String kanbanTaskCreatedLinkFailed(String error) {
    return '任务已创建，但添加父任务链接失败：$error';
  }

  @override
  String get kanbanTaskStatus => '状态';

  @override
  String get kanbanPriority => '优先级';

  @override
  String get kanbanAssignee => '负责人';

  @override
  String get kanbanTenant => '租户';

  @override
  String get kanbanParentTaskId => '父任务 ID';

  @override
  String get kanbanWorkspacePath => '工作区路径';

  @override
  String get kanbanModelOverride => '指定模型';

  @override
  String get kanbanProviderOverride => '指定提供商';

  @override
  String get kanbanEffort => '推理强度';

  @override
  String get kanbanEffortLow => '低';

  @override
  String get kanbanEffortMedium => '中';

  @override
  String get kanbanEffortHigh => '高';

  @override
  String get kanbanCreatingTask => '正在创建任务…';

  @override
  String get kanbanCreateTask => '创建任务';

  @override
  String get kanbanCreateBoard => '创建看板';

  @override
  String get kanbanBoardSettings => '看板设置';

  @override
  String get kanbanProject => '项目';

  @override
  String get kanbanNoProject => '不绑定项目';

  @override
  String get kanbanDeleteBoardQuestion => '删除看板？';

  @override
  String kanbanDeleteBoardDescription(String name) {
    return '将删除 $name，此操作不可撤销。';
  }

  @override
  String kanbanBoardTaskCount(int count) {
    return '$count 个任务';
  }

  @override
  String kanbanBoardTaskCountProject(int count, String project) {
    return '$count 个任务 · $project';
  }

  @override
  String get kanbanRenameBoard => '重命名看板';

  @override
  String pluginsOperationFailed(String error) {
    return '更新插件失败：$error';
  }

  @override
  String get pluginsInstallTitle => '安装 Agent 插件';

  @override
  String get pluginsIdentifierHint => 'Git URL 或 owner/repo';

  @override
  String get pluginsEnableAfterInstall => '安装后启用';

  @override
  String get pluginsForceReinstall => '强制重新安装';

  @override
  String pluginsInstalled(String name) {
    return '已安装 $name';
  }

  @override
  String pluginsInstallFailed(String error) {
    return '安装插件失败：$error';
  }

  @override
  String get pluginsLoading => '正在读取插件列表…';

  @override
  String get pluginsNoData => '暂无插件数据';

  @override
  String pluginsSearchHint(int count) {
    return '搜索 $count 个插件…';
  }

  @override
  String get pluginsNoMatches => '没有匹配的插件';

  @override
  String get pluginsKindPlatform => '平台';

  @override
  String get pluginsKindProvider => '提供商';

  @override
  String get pluginsKindTool => '工具';

  @override
  String pluginsContributionTooltip(String area, String description) {
    return '$area · $description';
  }

  @override
  String pluginsActionExecuted(String title) {
    return '$title 已执行';
  }

  @override
  String get pluginsAreaNavigation => '导航';

  @override
  String get pluginsAreaCommand => '命令';

  @override
  String get pluginsAreaSettings => '设置';

  @override
  String get pluginsAreaComposer => '输入器';

  @override
  String get pluginsAreaDetail => '详情';

  @override
  String get pluginsAreaTranscript => '对话记录';

  @override
  String get pluginsAreaPane => '面板';

  @override
  String knowledgeLoadDetailFailed(String error) {
    return '读取节点详情失败：$error';
  }

  @override
  String get knowledgeLoading => '正在读取知识图谱…';

  @override
  String get knowledgeNoData => '暂无知识数据';

  @override
  String get knowledgeSearchHint => '搜索知识节点…';

  @override
  String knowledgeMemorySummary(int count) {
    return '记忆摘要（$count）';
  }

  @override
  String get knowledgeNoMatches => '没有匹配的知识节点';

  @override
  String get knowledgeStateActive => '活跃';

  @override
  String get knowledgeStateInactive => '未激活';

  @override
  String knowledgeNodeMeta(String category, int count, String state) {
    return '$category · 使用 $count 次 · $state';
  }

  @override
  String knowledgeNodeMetaNoCategory(int count, String state) {
    return '使用 $count 次 · $state';
  }

  @override
  String get knowledgeSaved => '已保存';

  @override
  String knowledgeSaveFailed(String error) {
    return '保存节点失败：$error';
  }

  @override
  String get knowledgeDeleteQuestion => '删除知识节点？';

  @override
  String knowledgeDeleteDescription(String name) {
    return '将删除“$name”。此操作不可撤销。';
  }

  @override
  String get knowledgeDeleted => '知识节点已删除';

  @override
  String knowledgeDeleteFailed(String error) {
    return '删除节点失败：$error';
  }

  @override
  String get knowledgeCancelEditing => '取消编辑';

  @override
  String skillHubSearchFailed(String error) {
    return '搜索技能失败：$error';
  }

  @override
  String skillHubExitCode(int code) {
    return '操作退出码 $code';
  }

  @override
  String get skillHubActionTimeout => '技能操作已超时。';

  @override
  String get skillHubActionDone => '操作完成';

  @override
  String skillHubActionFailed(String error) {
    return '技能操作失败：$error';
  }

  @override
  String skillHubUninstallQuestion(String name) {
    return '卸载「$name」？';
  }

  @override
  String get skillHubUninstallDescription => '该技能将被移除，可随时重新安装。';

  @override
  String get skillHubUninstall => '卸载';

  @override
  String get skillHubUpdateInstalled => '更新已安装技能';

  @override
  String get skillHubSearchHint => '搜索技能市场…';

  @override
  String get skillHubLoading => '正在加载技能市场…';

  @override
  String skillHubSourcesTimedOut(String sources) {
    return '部分来源超时，未包含在结果中：$sources';
  }

  @override
  String get skillHubNoData => '暂无市场数据';

  @override
  String get skillHubSources => '来源';

  @override
  String skillHubRateLimited(String name) {
    return '$name（限流）';
  }

  @override
  String get skillHubIndexUnavailable => '技能索引当前不可用，搜索结果可能不完整。';

  @override
  String get skillHubFeatured => '精选';

  @override
  String get skillHubSearchPrompt => '输入关键词搜索技能';

  @override
  String get skillHubInstalled => '已安装';

  @override
  String get skillHubTrustOfficial => '官方';

  @override
  String get skillHubTrustTrusted => '可信';

  @override
  String get skillHubTrustCommunity => '社区';

  @override
  String get skillHubTrustUnverified => '未验证';

  @override
  String get skillHubTrustUntrusted => '不可信';

  @override
  String get skillHubTrustUnknown => '未知信任级别';

  @override
  String newSessionInitFailed(String error) {
    return '部分会话选项加载失败：$error';
  }

  @override
  String newSessionStartFailed(String error) {
    return '启动会话失败：$error';
  }

  @override
  String get newSessionTitleSection => '会话标题';

  @override
  String get newSessionTitleHint => '可选，留空则自动生成';

  @override
  String get newSessionWorkspace => '工作区';

  @override
  String get newSessionWorkspaceHint => 'Agent 在服务器上的工作目录';

  @override
  String get newSessionBrowseDirectory => '浏览目录';

  @override
  String get newSessionNoProject => '不归入项目';

  @override
  String get newSessionMoveLater => '稍后可在会话菜单中移动';

  @override
  String get newSessionUseCurrentModel => '使用当前模型';

  @override
  String get newSessionAgent => 'Agent';

  @override
  String get newSessionStarting => '启动中…';

  @override
  String get newSessionStart => '开始会话';

  @override
  String newSessionAgentSummary(String model, String cwd) {
    return '$model · $cwd';
  }

  @override
  String get newSessionCurrentModel => '当前模型';

  @override
  String get newSessionWorkspaceAbove => '工作目录如上';

  @override
  String get newSessionParentDirectory => '上一级';

  @override
  String get artifactsTitle => '工件';

  @override
  String get artifactsSearchHint => '搜索工件标题和会话…';

  @override
  String get artifactsKindCode => '代码';

  @override
  String get artifactsKindImage => '图片';

  @override
  String get artifactsKindLink => '链接';

  @override
  String get artifactsEmpty => '没有工件';

  @override
  String get artifactsEmptyDescription => '会话生成的工件会显示在这里。';

  @override
  String get artifactsNoMatches => '没有匹配的工件';

  @override
  String get artifactsNoMatchesDescription => '请尝试其他搜索条件或过滤器。';

  @override
  String artifactsOpen(String name) {
    return '打开工件 $name';
  }

  @override
  String get artifactsSaved => '已保存';

  @override
  String artifactsSaveFailed(String error) {
    return '无法保存工件：$error';
  }

  @override
  String get artifactsSaveToDevice => '保存到设备';

  @override
  String get artifactsCopy => '复制工件';

  @override
  String get artifactsOpenLink => '打开链接';

  @override
  String get artifactsOpenLinkFailed => '无法打开链接。';

  @override
  String get artifactsImageLoadFailed => '图片无法加载';

  @override
  String get shellReconnecting => '已断开，正在重连…';

  @override
  String get shellReconnectNow => '立即重连';

  @override
  String get shellCollapseNavigation => '折叠导航';

  @override
  String get shellExpandNavigation => '展开导航';

  @override
  String get shellNavigation => '导航';

  @override
  String get shellSessionArea => '会话域';

  @override
  String get shellWorkspaceArea => '工作区域';

  @override
  String get shellIntelligenceArea => '智能域';

  @override
  String shellModelStatus(String value) {
    return '模型 $value';
  }

  @override
  String shellWorkspaceStatus(String value) {
    return '工作区 $value';
  }

  @override
  String shellAgentStatus(String value) {
    return 'Agent $value';
  }

  @override
  String get gitListView => '列表视图';

  @override
  String get gitTreeView => '树视图';

  @override
  String get gitViewPr => '查看 PR';

  @override
  String gitChangeCounts(int staged, int changed) {
    return '暂存 $staged · 变更 $changed';
  }

  @override
  String get gitWorkingTreeCleanDescription => '没有未提交的变更。';

  @override
  String get gitStagedSection => '暂存区';

  @override
  String get gitUnstagedSection => '未暂存';

  @override
  String get gitOpenPrFailed => '无法打开拉取请求。';

  @override
  String gitUnstageFailed(String error) {
    return '取消暂存失败：$error';
  }

  @override
  String get gitCommitAndPushSucceeded => '提交并推送成功';

  @override
  String get gitCommitSucceeded => '提交成功';

  @override
  String get gitStatusAdded => '新';

  @override
  String get gitStatusModified => '改';

  @override
  String get gitStatusDeleted => '删';

  @override
  String get gitStatusRenamed => '移';

  @override
  String get gitStatusConflict => '冲';

  @override
  String get insightsTitle => '洞察分析';

  @override
  String insightsDays(int count) {
    return '$count 天';
  }

  @override
  String insightsLoading(int count) {
    return '正在统计最近 $count 天…';
  }

  @override
  String get insightsNoData => '暂无用量数据';

  @override
  String get insightsOverview => '总览';

  @override
  String get insightsSessions => '会话';

  @override
  String get insightsApiCalls => 'API 调用';

  @override
  String get insightsCost => '成本';

  @override
  String get insightsDailyUsage => '每日用量';

  @override
  String get insightsModelUsage => '模型用量';

  @override
  String get insightsToolCalls => '工具调用';

  @override
  String get insightsUnknownProvider => '未知提供商';

  @override
  String insightsModelSummary(String tokens, int sessions, String cost) {
    return '$tokens Token · $sessions 个会话 · \$$cost';
  }

  @override
  String webhookBaseUrl(String url) {
    return '基础 URL：$url';
  }

  @override
  String get webhookUrl => 'URL';

  @override
  String get webhookSecret => '密钥';

  @override
  String get toolsTitle => '工具集';

  @override
  String get toolsEmpty => '暂无工具集';

  @override
  String toolsToolsetSummary(int count, String status) {
    return '$count 个工具 · $status';
  }

  @override
  String get toolsTerminalBackend => '终端执行环境';

  @override
  String get toolsReady => '已就绪';

  @override
  String get toolsNeedsSetup => '需要配置';

  @override
  String get toolsUnavailable => '不可用';

  @override
  String toolsBackendSwitchFailed(String error) {
    return '切换终端执行环境失败：$error';
  }

  @override
  String get toolsComputerUseUnsupported => '此后端平台不支持';

  @override
  String get toolsComputerUseNotInstalled => '未安装 cua-driver';

  @override
  String get toolsComputerUseReady => 'Computer Use 已就绪';

  @override
  String get toolsComputerUseNotReady => '驱动或权限尚未就绪';

  @override
  String get toolsRecheck => '重新检查';

  @override
  String get toolsCheck => '检查';

  @override
  String toolsCheckResult(String label, String result) {
    return '$label：$result';
  }

  @override
  String get toolsWaitingForPermission => '等待后端授权…';

  @override
  String get toolsRequestPermission => '请求后端系统权限';

  @override
  String get toolsPermissionTimeout => '系统权限请求已超时。';

  @override
  String toolsPermissionFailed(String error) {
    return '请求系统权限失败：$error';
  }

  @override
  String toolsToggleFailed(String error) {
    return '切换工具集失败：$error';
  }

  @override
  String get agentBotsTitle => '机器人';

  @override
  String agentRequestSummary(String title, String member) {
    return '$title · $member';
  }

  @override
  String modelPickerRefreshFailed(String error) {
    return '刷新模型失败：$error';
  }

  @override
  String get modelPickerEdit => '编辑可见模型';

  @override
  String modelPickerVisibilitySaveFailed(String error) {
    return '保存模型可见性失败：$error';
  }

  @override
  String get modelPickerMoaPresets => 'MoA 预设';

  @override
  String modelPickerMoaModel(String model) {
    return 'MoA：$model';
  }

  @override
  String get modelPickerRefresh => '刷新模型';

  @override
  String get modelPickerFree => '免费';

  @override
  String modelPickerFreeDiscount(num percent) {
    return '免费 · -$percent%';
  }

  @override
  String modelPickerPricing(String input, String output, String discount) {
    return '输入 $input / 输出 $output$discount';
  }

  @override
  String get modelPickerSelectNone => '全不选';

  @override
  String get modelPickerSelectAll => '全选';

  @override
  String get commonCopy => '复制';

  @override
  String get chatMermaidDiagram => 'Mermaid 图表';

  @override
  String chatArtifactTitle(String language) {
    return '$language 工件';
  }

  @override
  String chatCodeArtifactTitle(String language, int count) {
    return '$language 代码 · $count 行';
  }

  @override
  String get chatArtifactPreview => '工件预览';

  @override
  String chatCodeTitle(String language) {
    return '$language 代码';
  }

  @override
  String get chatCodeCopied => '代码已复制';

  @override
  String get chatLivePreview => '实时预览';

  @override
  String get chatExpandPreview => '在消息中展开预览';

  @override
  String get chatAudioPlaybackFailed => '音频播放失败';

  @override
  String get chatPauseAudio => '暂停音频';

  @override
  String get chatPlayAudio => '播放音频';

  @override
  String get chatOpenVideo => '视频 · 点击打开';

  @override
  String get chatOpenFile => '文件 · 点击打开';

  @override
  String imageSaveFailed(String error) {
    return '保存图片失败：$error';
  }

  @override
  String get voiceMenu => '语音菜单';

  @override
  String get voiceStopRecording => '停止录音';

  @override
  String get voiceDictation => '语音输入';

  @override
  String get voiceContinuousConversation => '连续语音对话';

  @override
  String get voiceAutoReadReplies => '自动朗读回复';

  @override
  String get voiceWakeWord => '唤醒词';

  @override
  String voiceWakePhrase(String phrase) {
    return '“$phrase”';
  }

  @override
  String get voiceStopSpeaking => '停止朗读';

  @override
  String get voiceWakeEnabling => '正在启用唤醒词…';

  @override
  String get voiceWakeTriggered => '已唤醒，正在聆听…';

  @override
  String get voiceWakeListening => '唤醒词监听中';

  @override
  String voiceWakeListeningFor(String phrase) {
    return '正在监听“$phrase”';
  }

  @override
  String get voiceWakeWaiting => '唤醒词等待恢复';

  @override
  String get voiceWakeDisabled => '唤醒词已关闭';

  @override
  String sessionPrBadge(int number, String status) {
    return 'PR #$number · $status';
  }

  @override
  String get sessionPrOpenFailed => '无法打开拉取请求。';

  @override
  String get sessionCliBadge => 'CLI 会话';

  @override
  String get sessionDraftBadge => '有未发送草稿';

  @override
  String get sessionSharedBadge => '已分享';

  @override
  String get sessionHandedOff => '已交接';

  @override
  String sessionHandedOffTo(String platform) {
    return '已交接 · $platform';
  }

  @override
  String sessionHandoffErrorBadge(String error) {
    return '交接异常 · $error';
  }

  @override
  String sessionCompressionErrorBadge(String error) {
    return '上下文压缩暂时失败 · $error';
  }

  @override
  String sessionEndedWithReason(String reason) {
    return '已结束 · $reason';
  }

  @override
  String get sessionEnded => '已结束';

  @override
  String toolGroupHiddenRestore(int count) {
    return '已隐藏 $count 个工具，点击恢复';
  }

  @override
  String backgroundStopFailed(String error) {
    return '停止进程失败：$error';
  }

  @override
  String get backgroundProcessRemoved => '该进程已结束并被移除';

  @override
  String get backgroundCloseAndHide => '关闭并隐藏';

  @override
  String get mcpLogsEmpty => '暂无日志';

  @override
  String get subagentTaskProgress => '任务进度';

  @override
  String get cloudDiscoverAgain => '重新发现';

  @override
  String get cloudPortalLoginPrompt => '请在下方完成 Portal 登录，登录后将自动发现 Agent。';

  @override
  String get backgroundTerminal => '后台终端';

  @override
  String get backgroundWaitingOutput => '等待输出…';

  @override
  String get backgroundStopping => '正在停止…';

  @override
  String get backgroundStopProcess => '停止进程';

  @override
  String get markdownAlertTip => '提示';

  @override
  String get markdownAlertImportant => '重要';

  @override
  String get markdownAlertWarning => '警告';

  @override
  String get markdownAlertCaution => '注意';

  @override
  String get markdownAlertNote => '备注';

  @override
  String get richLinkMaps => '地图';

  @override
  String turnActivityTools(int count) {
    return '$count 个工具';
  }

  @override
  String turnActivityReasoning(int count) {
    return '$count 段思考';
  }

  @override
  String toolGroupFailed(int count) {
    return '$count 个失败';
  }

  @override
  String get messageSourceDingtalk => '钉钉';

  @override
  String get profileScopeApplyTo => '应用于';

  @override
  String profileScopeChangesApplyTo(String profile) {
    return '此页面的更改将应用于 $profile 配置档。';
  }

  @override
  String get profileScopeConfiguring => '配置对象';

  @override
  String profileScopeCurrent(String name) {
    return '$name（当前）';
  }

  @override
  String get mcpLogsAllServers => '全部服务器';

  @override
  String get mcpLogsLoading => '正在读取日志…';

  @override
  String badgeUnreadCount(String count) {
    return '$count 条未读';
  }

  @override
  String progressPercent(int percent) {
    return '进度 $percent%';
  }

  @override
  String avatarNamed(String name) {
    return '头像：$name';
  }

  @override
  String get avatarUnnamed => '头像';

  @override
  String get thinkingActive => '正在思考';

  @override
  String get thinkingProcess => '思考过程';

  @override
  String get thinkingBriefly => '已思考片刻';

  @override
  String thinkingSeconds(String seconds) {
    return '已思考 $seconds 秒';
  }

  @override
  String thinkingMinutes(int minutes, int seconds) {
    return '已思考 $minutes 分 $seconds 秒';
  }

  @override
  String thinkingGeneratedCharacters(int count) {
    return '已生成 $count 字';
  }

  @override
  String thinkingCharacters(int count) {
    return '$count 字';
  }

  @override
  String get thinkingAnalyzing => '正在分析上下文…';

  @override
  String get commonNoData => '暂无数据';

  @override
  String get commonFeatureDisabled => '功能未启用';

  @override
  String get cloudDiscoveryFailed => 'Cloud 发现失败';

  @override
  String cloudDiscoveryInvalidData(String error) {
    return 'Cloud 返回了无法识别的数据：$error';
  }

  @override
  String get cloudDiscoveryUnsupported => '当前平台不支持 Hermes Cloud 发现';

  @override
  String sessionCreateFailed(String error) {
    return '创建会话失败：$error';
  }

  @override
  String get statusReady => '已就绪';

  @override
  String get workspaceDescription => '会话磁贴与插件窗格';

  @override
  String get subagentFallbackName => '子代理';

  @override
  String get subagentNoTask => '未提供任务说明';

  @override
  String get subagentsStatusRunning => '执行中';

  @override
  String get subagentsStatusCompleted => '已完成';

  @override
  String get subagentsStatusFailed => '失败';

  @override
  String subagentCardTitle(String name) {
    return '子代理 · $name';
  }

  @override
  String get subagentTask => '任务';

  @override
  String get subagentModel => '模型';

  @override
  String get subagentCurrentTool => '当前工具';

  @override
  String get subagentSummary => '执行摘要';

  @override
  String sessionApiCallCount(int count) {
    return '$count 次 API 调用';
  }

  @override
  String sessionTokenCount(String count) {
    return '$count Token';
  }

  @override
  String get diagnosticsConsentDescription =>
      '将收集并脱敏服务器日志、系统与 Provider 配置信息后上传。日志可能包含对话内容、工具输出和文件路径；不会上传 API Key，诊断包会在 14 天后删除。';

  @override
  String get diagnosticsApproveUpload => '同意并上传';

  @override
  String get diagnosticsGatewayUnavailable => '尚未连接到 Hermes 网关';

  @override
  String get diagnosticsUploadFailed => '上传失败';

  @override
  String get diagnosticsSentTitle => '诊断信息已发送';

  @override
  String get diagnosticsLinkCopied => '查看链接已复制到剪贴板：';

  @override
  String get diagnosticsSupportPrompt => '如需进一步帮助，可通过以下渠道联系我们：';

  @override
  String diagnosticsSendFailed(String error) {
    return '发送诊断失败：$error';
  }

  @override
  String get slashDescRetry => '重新生成上一条回复';

  @override
  String get slashDescClear => '清空当前会话视图';

  @override
  String get slashDescUndo => '撤销上一完整回合';

  @override
  String get slashDescSteer => '向当前回合注入引导消息';

  @override
  String get slashDescStatus => '查看会话状态';

  @override
  String get slashDescTitle => '重新生成会话标题';

  @override
  String get slashDescNew => '开启新会话';

  @override
  String get slashDescYolo => '切换 YOLO 自动批准';

  @override
  String get slashDescHandoff => '打开会话交接';

  @override
  String get slashDescProfile => '选择配置档或人格';

  @override
  String get slashDescHelp => '列出本地与目录中的斜杠命令';

  @override
  String get slashDescBackground => '提交后台任务';

  @override
  String get slashDescCompress => '压缩当前会话上下文';

  @override
  String get slashDescQueue => '把消息加入发送队列';

  @override
  String get slashDescUsage => '查看本会话用量';

  @override
  String get slashDescVersion => '显示 Hermes 与移动端版本';

  @override
  String get slashDescStop => '中断当前回合';

  @override
  String get slashDescTools => '打开工具配置';

  @override
  String get slashDescApprovals => '设置审批模式：manual / smart / off';

  @override
  String get slashDescModel => '打开模型选择器';

  @override
  String get slashDescWake => '管理唤醒词：status / on / off / toggle';

  @override
  String get slashDescSkinUnavailable => '桌面专属皮肤命令';

  @override
  String get slashDescBrowserUnavailable => '桌面专属内置浏览器命令';

  @override
  String get slashDescJourney => '打开星图旅程';

  @override
  String get slashDescPet => '打开宠物中心';

  @override
  String get slashDescHatch => '生成并孵化新宠物';

  @override
  String get slashDescSave => '保存当前会话记录';

  @override
  String get slashDescReloadConfigUnavailable =>
      '移动端与 Gateway 均不支持 reload-config';

  @override
  String get cronSuggestionPrefix => '请将其设置为定时任务：';

  @override
  String get kanbanTaskCompletedNotification => '看板任务完成';

  @override
  String get kanbanTaskProblemNotification => '看板任务异常';

  @override
  String get themeGraphite => '石墨';

  @override
  String get themeIndigo => '靛蓝';

  @override
  String get themeMoss => '苔绿';

  @override
  String get themeDune => '暖沙';

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
  String get toolEmptyList => '（空列表）';

  @override
  String toolItemCount(int count) {
    return '$count 项';
  }

  @override
  String toolFieldCount(int count) {
    return '$count 个字段';
  }

  @override
  String get toolPath => '路径';

  @override
  String get toolLanguage => '语言';

  @override
  String get toolText => '文本';

  @override
  String get toolMessage => '消息';

  @override
  String get toolSummary => '摘要';

  @override
  String get toolExecuteCommand => '执行命令';

  @override
  String get toolRunCode => '运行代码';

  @override
  String toolRunCodeLanguage(String language) {
    return '运行 $language 代码';
  }

  @override
  String toolSearchFor(String query) {
    return '搜索：$query';
  }

  @override
  String get toolExtractWeb => '抓取网页';

  @override
  String get toolApplyPatch => '应用文件补丁';

  @override
  String get toolListFiles => '列出文件';

  @override
  String get toolGenerateImage => '生成图片';

  @override
  String get toolDelegateTask => '委派任务';

  @override
  String toolTask(int index) {
    return '任务 $index';
  }

  @override
  String toolRunEditingFiles(int count) {
    return '正在编辑 $count 个文件';
  }

  @override
  String toolRunExploringFiles(int count) {
    return '正在浏览 $count 个文件';
  }

  @override
  String toolRunRunningCommands(int count) {
    return '正在运行 $count 个命令';
  }

  @override
  String toolRunDelegatingTasks(int count) {
    return '正在委派 $count 个任务';
  }

  @override
  String toolRunUsingTools(int count) {
    return '正在使用 $count 个工具';
  }

  @override
  String toolRunEditedFiles(int count) {
    return '编辑了 $count 个文件';
  }

  @override
  String toolRunExploredFiles(int count) {
    return '浏览了 $count 个文件';
  }

  @override
  String toolRunRanCommands(int count) {
    return '运行了 $count 个命令';
  }

  @override
  String toolRunDelegatedTasks(int count) {
    return '委派了 $count 个任务';
  }

  @override
  String toolRunUsedTools(int count) {
    return '使用了 $count 个工具';
  }

  @override
  String get notificationBackgroundCompleted => '后台任务完成';

  @override
  String get notificationBackgroundCompletedBody => '一个后台任务已完成，点击查看结果。';

  @override
  String get notificationApprovalRequired => '等待授权';

  @override
  String get notificationApprovalRequiredBody => 'Agent 请求授权一个敏感操作。';

  @override
  String get voiceServerDisconnected => '尚未连接服务器';

  @override
  String get voiceRecordingUnsupported => '当前平台暂不支持麦克风录音';

  @override
  String get voiceMicrophoneStartFailed => '麦克风权限被拒绝或无法启动录音';

  @override
  String voiceRecordingFailed(String error) {
    return '录音失败：$error';
  }

  @override
  String get voiceNoSpeech => '没有听清，请再说一次。';

  @override
  String get voiceSttUnavailable => '服务端未配置语音转写（STT）';

  @override
  String voiceTranscriptionFailed(String error) {
    return '转写失败：$error';
  }

  @override
  String voiceSpeechFailed(String error) {
    return '语音播报失败：$error';
  }

  @override
  String voiceStreamingSpeechFailed(String error) {
    return '流式语音播报失败：$error';
  }

  @override
  String get voiceWakeInstallNotice => '正在启用，首次使用可能需要安装检测引擎。';

  @override
  String get voiceWakeUsage => '用法：/wake [status|on|off|toggle]';

  @override
  String get voiceWakeNotEnabled => '唤醒词尚未启用';

  @override
  String get voiceWakeOtherSurface => '唤醒词已限定到其他终端';

  @override
  String get voiceWakeOwned => '另一个终端正在监听唤醒词';

  @override
  String get voiceWakeUnavailable => '当前后端不支持唤醒词';

  @override
  String voiceWakeMicInterrupted(String error) {
    return '唤醒词麦克风中断：$error';
  }

  @override
  String get voiceWakeMicPermission => '麦克风权限被拒绝，无法监听唤醒词';

  @override
  String voiceWakeMicStartFailed(String error) {
    return '无法启动唤醒词麦克风：$error';
  }

  @override
  String voiceWakeAudioUploadFailed(String error) {
    return '唤醒词音频传输失败：$error';
  }

  @override
  String get filesThisComputer => '此电脑';

  @override
  String get billingSavedPaymentMethod => '已保存支付方式';

  @override
  String billingPaymentMethodKind(String kind) {
    return '支付方式 · $kind';
  }

  @override
  String get previewTourBack => '上一步';

  @override
  String get previewTourDone => '完成';

  @override
  String get previewTourNext => '下一步';

  @override
  String get chatMermaidParseError => '无法解析 Mermaid 图表';

  @override
  String get petDefaultName => 'Hermes 宠物';

  @override
  String get sessionDetailProfile => '配置档案';

  @override
  String get profileArchiveType => 'Hermes 配置档案';

  @override
  String get profilesTemperature => '温度';

  @override
  String get profilesTopP => 'Top P';

  @override
  String get profilesMaxTokens => '最大 Token 数';

  @override
  String get sessionDesktopFallback => '桌面会话';

  @override
  String get backgroundProcessFallback => '后台进程';

  @override
  String get insightsUnknownModel => '未知模型';

  @override
  String get billingCard => '银行卡';

  @override
  String get billingLink => 'Link';

  @override
  String get slashGroupSkills => '技能';

  @override
  String get slashGroupCommands => '命令';

  @override
  String get botAuthorYou => '你';

  @override
  String get botAuthorSystem => '系统';

  @override
  String get botAuthorFallback => 'Bot';

  @override
  String terminalErrorMessage(String error) {
    return '终端错误：$error';
  }

  @override
  String sessionCopyTitle(String title) {
    return '$title（副本）';
  }

  @override
  String get gitRemoteFallback => '远程仓库';

  @override
  String get gitStashFallback => '暂存项';

  @override
  String get notificationChannelErrors => '错误';

  @override
  String get notificationChannelWarnings => '警告';

  @override
  String get notificationChannelSuccess => '成功';

  @override
  String get notificationChannelApprovals => '审批';

  @override
  String get notificationChannelInfo => '信息';

  @override
  String get memoryCuratorTitle => '内容整理器';

  @override
  String get messageSourceServer => '服务器';

  @override
  String get messageSourceMobile => '移动端';

  @override
  String get kanbanRunQueued => '排队中';

  @override
  String get kanbanRunCompleted => '已完成';

  @override
  String get kanbanRunFailed => '失败';

  @override
  String get kanbanRunCancelled => '已取消';

  @override
  String get kanbanEventTaskCreated => '任务已创建';

  @override
  String get kanbanEventTaskUpdated => '任务已更新';

  @override
  String get kanbanEventTaskDeleted => '任务已删除';

  @override
  String get kanbanEventRunStarted => '运行已开始';

  @override
  String get kanbanEventRunCompleted => '运行已完成';

  @override
  String get kanbanEventRunFailed => '运行失败';

  @override
  String get kanbanEventRunCancelled => '运行已取消';

  @override
  String get kanbanEventCommentCreated => '已添加评论';

  @override
  String get kanbanEventAttachmentAdded => '已添加附件';

  @override
  String get kanbanEventAttachmentDeleted => '已删除附件';

  @override
  String get cloudRoleOwner => '所有者';

  @override
  String get cloudRoleAdmin => '管理员';

  @override
  String get cloudRoleMember => '成员';

  @override
  String get cloudRoleViewer => '查看者';

  @override
  String get chatStatusToolDrafting => '正在准备工具调用';

  @override
  String get chatStatusProvider => '提供商状态';

  @override
  String get previewScriptError => '脚本错误';

  @override
  String get previewUnhandledPromiseRejection => '未处理的 Promise 拒绝：';

  @override
  String botGroupSessionTitle(String roomId) {
    return '群组：$roomId';
  }

  @override
  String get errorExpectedObjectResponse => '服务器返回了无效的对象响应';

  @override
  String get errorTtsNoAudio => '文本转语音未返回音频';

  @override
  String get errorInvalidDataUrl => '服务器返回了无效的数据 URL';

  @override
  String get errorExportDirectoryMissing => '服务器未提供导出目录';

  @override
  String get errorImportDirectoryMissing => '服务器未提供导入目录';

  @override
  String get errorRawConfigInvalid => '服务器返回了无效的原始配置';

  @override
  String get errorPluginToggleRejected => '后端拒绝了插件变更';

  @override
  String get errorConnectionNotConfigured => '连接尚未配置';

  @override
  String errorSessionOwnerUnknown(String sessionId) {
    return '会话所有者未知：$sessionId';
  }

  @override
  String get errorRemotePushUnavailable => '此连接不支持远程推送';

  @override
  String get sshCommandTimedOut => 'SSH 命令超时';

  @override
  String get sshRemoteHomeUnsafe => '远程 Hermes 主目录不安全';

  @override
  String get sshOwnershipVerificationFailed => '无法验证远程 Hermes 进程的所有权';

  @override
  String sshOwnershipProbeFailed(String status) {
    return '远程所有权探测失败（$status）';
  }

  @override
  String get sshHelperInvalidJson => '远程辅助程序返回了无效 JSON';

  @override
  String get sshWindowsOwnershipVerificationFailed => '无法验证远程 Windows 进程的所有权';

  @override
  String get sshRemotePathInvalid => '远程 Hermes 路径必须是绝对路径或以 ~/ 开头';

  @override
  String get sshExecutableNotFound => '在远程主机上找不到配置的 Hermes 可执行文件';

  @override
  String get sshHermesNotInstalled => '远程主机未安装 Hermes';

  @override
  String get sshBootstrapFlagsUnsupported => '远程 Hermes 必须支持安全 SSH 所有权引导参数';

  @override
  String get sshWindowsIdentityInvalid => '远程 Windows 后端返回了无效身份';

  @override
  String get sshWindowsExitedBeforeReady => '远程 Windows 后端在就绪前退出';

  @override
  String get sshWindowsOwnershipProofFailed => '远程 Windows 所有权证明失败';

  @override
  String get sshProcessIdMissing => '远程 Hermes 未返回进程 ID';

  @override
  String get sshExitedBeforeReady => '远程 Hermes 在就绪前退出';

  @override
  String get sshOwnershipProofFailed => '远程 Hermes 所有权证明失败';

  @override
  String get errorSessionBranchIdMissing => 'Hermes 未返回分支会话的持久 ID';

  @override
  String get errorDuplicateImportFailed => 'Hermes 未能导入复制的会话';

  @override
  String get errorSessionNoTitleableMessages => '会话中没有可用于生成标题的消息';

  @override
  String get errorTitleGeneratorEmpty => '标题生成器返回了空标题';

  @override
  String get errorProjectIdRequired => '请选择项目';

  @override
  String get errorProjectWorkingFolderMissing => '目标项目没有工作目录';

  @override
  String get errorDownloadFailed => '下载失败';

  @override
  String get errorMessagingPlatformNotFound => '找不到消息平台';

  @override
  String errorBotGroupSessionStartFailed(String name) {
    return '$name 的群组会话未能启动';
  }

  @override
  String sshRemoteCommandFailed(String code) {
    return '远程命令失败（$code）';
  }

  @override
  String get sshHostAndUserRequired => 'SSH 主机和用户不能为空';

  @override
  String get sshPortInvalid => 'SSH 端口必须在 1 到 65535 之间';

  @override
  String sshHostKeyChanged(String host, String expected, String received) {
    return '$host 的 SSH 主机密钥已更改。预期为 $expected，实际为 $received';
  }

  @override
  String get sshProfileInvalid => '远程配置档案名称无效';

  @override
  String get errorDirectGatewayFeatureUnavailable =>
      '此功能需要 Hermes Mobile Server，直接 Gateway 连接无法使用';

  @override
  String errorOperationFailedWithDetail(String error) {
    return '操作失败：$error';
  }

  @override
  String gatewayOauthRejected(String error) {
    return 'Gateway 拒绝登录：$error';
  }

  @override
  String get gatewayOauthCodeMissing => 'Gateway 回调缺少授权码';

  @override
  String get gatewayOauthStateMismatch => 'Gateway 回调状态不匹配。为确保安全，登录已取消。';

  @override
  String get gatewayOauthRefreshTokenMissing => 'Gateway 会话已过期且没有刷新令牌';

  @override
  String get gatewayOauthTicketMissing => 'Gateway 未返回 WebSocket 票据';

  @override
  String get gatewayOauthAccessTokenMissing => 'Gateway 令牌响应未包含访问令牌';

  @override
  String get gatewayOauthTimedOut => 'Gateway 登录超时';

  @override
  String get gatewayOauthNativeUnsupported => '此平台不支持原生 Gateway OAuth';

  @override
  String get updateManifestInvalid => '更新清单无效';

  @override
  String sshRemotePlatformUnsupported(String error) {
    return '不支持远程平台：$error';
  }

  @override
  String get sshWebUnsupported => 'Web 端不支持原生 SSH 连接';

  @override
  String get filesDownloadPlatformUnsupported => '此平台不支持下载到本地文件';

  @override
  String get sessionExportPlatformUnsupported => '此平台不支持导出到本地文件';

  @override
  String get errorPluginCanonicalKeyRequired => '此插件需要规范键才能更改';

  @override
  String get connectGatewayToken => 'Gateway 令牌';

  @override
  String get modelMoaTitle => '多智能体混合';

  @override
  String get insightsTokens => 'Token';

  @override
  String get messageWebFallback => '网页';

  @override
  String get mcpLogsSourceStdio => 'stdio';

  @override
  String get mcpLogsSourceAgent => '智能体';

  @override
  String get projectPrimaryFolder => '主目录';

  @override
  String get botGroupNameRequired => '请输入群组名称';

  @override
  String get botGroupMembersMinimum => '群组至少需要两个 Bot';

  @override
  String botGroupMembersRange(int max) {
    return '群组需要 2～$max 个 Bot';
  }

  @override
  String botGroupMembersMaximum(int max) {
    return '群组最多支持 $max 个 Bot';
  }

  @override
  String get botGroupMemberUnavailable => '没有可用的群组成员';

  @override
  String get botProfileNameUnavailable => '没有可用的配置档案名称';

  @override
  String get botDefaultProfileDeleteForbidden => '无法删除默认配置档案';

  @override
  String get botConnectionUnavailable => 'Bot 连接不可用';

  @override
  String get botTurnFailed => 'Bot 回合失败';

  @override
  String get mcpInvalidJsonSyntax => 'JSON 语法无效';

  @override
  String get mcpJsonObjectRequired => 'JSON 顶层内容必须是对象';

  @override
  String get voiceWakeMicStreamEnded => '唤醒词麦克风流意外结束';

  @override
  String httpStatusError(int statusCode) {
    return '服务器返回 HTTP $statusCode';
  }
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get commonCopyFailed => '無法複製到剪貼簿';

  @override
  String get commonClipboardReadFailed => '無法讀取剪貼簿';

  @override
  String petGenerateReferenceFailed(String error) {
    return '新增參考圖片失敗：$error';
  }

  @override
  String petSelectFailed(String error) {
    return '無法選擇寵物：$error';
  }

  @override
  String terminalSshNamed(String host) {
    return 'SSH $host';
  }

  @override
  String get deepLinkUnsupported => '不支援的 Hermes 連結';

  @override
  String get deepLinkMcpNameInvalid => 'MCP 名稱格式無效';

  @override
  String get deepLinkMcpConfigMissing => 'MCP 連結缺少設定';

  @override
  String get deepLinkMcpConfigTooLarge => 'MCP 設定超過 32 KiB';

  @override
  String get deepLinkMcpEncodingInvalid => 'MCP 設定編碼無效';

  @override
  String get deepLinkMcpJsonInvalid => 'MCP 設定不是有效的 JSON';

  @override
  String get deepLinkMcpObjectRequired => 'MCP 設定必須是物件';

  @override
  String get deepLinkMcpUrlCommandConflict => 'MCP 設定不能同時包含 URL 與命令';

  @override
  String get deepLinkMcpHttpOnly => 'MCP URL 僅支援 HTTP 或 HTTPS';

  @override
  String get deepLinkMcpEndpointMissing => 'MCP 設定缺少 URL 或命令';

  @override
  String get terminalConnectionClosed => '終端機連線已關閉';

  @override
  String terminalRequestFailed(String error) {
    return '無法傳送終端機請求：$error';
  }

  @override
  String get terminalGenericError => '終端機錯誤';

  @override
  String get botUntitledTask => '未命名任務';

  @override
  String botMemberPaused(String name) {
    return '$name 已暫停；直接 @此成員或傳送 resume 即可復原。';
  }

  @override
  String get botRoutineFieldsRequired => '任務名稱、指令與排程不能為空';

  @override
  String get botRoutineNulForbidden => '任務名稱、指令與排程不能包含 NUL';

  @override
  String get pluginLoadActionReadOnly => '外掛 view.load_action 必須是唯讀 action';

  @override
  String get pluginMethodMissing => '外掛 action 缺少 method';

  @override
  String get pluginPathInvalid => '外掛 action path 無效';

  @override
  String pluginMethodUnsupported(String method) {
    return '不支援外掛 REST method：$method';
  }

  @override
  String get pluginUrlInvalid => '外掛 action URL 無效';

  @override
  String get pluginUrlSchemeUnsupported => '不支援外掛 action URL scheme';

  @override
  String get pluginLinkOpenFailed => '無法開啟連結';

  @override
  String get pluginNotificationFieldsMissing =>
      '外掛通知 action 缺少 title 或 message';

  @override
  String get pluginNotificationUnavailable => '目前主機未提供通知功能';

  @override
  String pluginActionUnsupported(String kind) {
    return '行動版不支援外掛 action：$kind';
  }

  @override
  String get kanbanTaskAlreadyRunning => '任務已在執行';

  @override
  String get gatewayUnavailable => 'Hermes 後端 Gateway 無法使用';

  @override
  String get filesDirectoryMissing => '目錄不存在';

  @override
  String get filesFolderFallback => '目前平台無法列出本機資料夾，請改為多選檔案';

  @override
  String get billingCreditsExhausted => '餘額不足或額度已用盡';

  @override
  String workspacePaneLimit(int count) {
    return '工作區最多同時開啟 $count 個窗格';
  }

  @override
  String get projectMissing => '專案不存在或已刪除';

  @override
  String updateHttpError(int status) {
    return '更新服務傳回 HTTP $status';
  }

  @override
  String get chatCompactingThread => '正在總結討論串';

  @override
  String get chatModelChanged => '模型已變更';

  @override
  String get chatTurnContinued => '已繼續中斷的回合';

  @override
  String get chatPersonalityChanged => '個性設定已變更';

  @override
  String get chatDelegationCompleted => '背景代理工作已完成';

  @override
  String chatDelegationCountCompleted(int count) {
    return '$count 個背景代理任務已完成';
  }

  @override
  String get chatHermesNotification => 'Hermes 通知';

  @override
  String get chatBrowserTask => '瀏覽器任務';

  @override
  String get chatPreviewRestart => '預覽服務重新啟動';

  @override
  String chatPreparingTool(String name) {
    return '正在準備 $name';
  }

  @override
  String get chatMoaAggregating => '◇ 正在彙總多模型結果…';

  @override
  String get chatMoaCollaboration => '多模型協作';

  @override
  String get chatCurrentGoal => '目前目標';

  @override
  String get chatCodeReview => '程式碼審查';

  @override
  String get chatHermesRunFailed => 'Hermes 執行失敗';

  @override
  String get chatPlanItem => '計畫項目';

  @override
  String get chatAssistantReplyFailed => '助理回覆失敗';

  @override
  String get terminalServerNotConfigured => '尚未設定伺服器';

  @override
  String terminalLimitReached(int count) {
    return '最多同時開啟 $count 個終端機，請先關閉一個工作階段';
  }

  @override
  String terminalNumbered(int number) {
    return '終端機 $number';
  }

  @override
  String get terminalSnapshotStart => '── 以下是上次工作階段的唯讀輸出快照 ──';

  @override
  String get terminalSnapshotEnd => '── 快照結束，正在復原終端機 ──';

  @override
  String get terminalSshHostRequired => 'SSH 主機不能為空';

  @override
  String get terminalRestartingShell => '── 正在重新啟動 shell… ──';

  @override
  String get terminalOpenedNewShell => '── 無法復原原 shell，已開啟新 shell ──';

  @override
  String get terminalPtyIdMissing => '伺服器未傳回 PTY 工作階段 ID';

  @override
  String terminalShellExited(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'other': ' (code $code)',
      'empty': '',
    });
    return '── shell 已結束$_temp0 · 點一下「重新啟動」繼續 ──';
  }

  @override
  String get terminalReconnecting => '終端機連線中斷，正在重新連線…';

  @override
  String get terminalRestoringShell => '── 連線中斷，正在復原或重開 shell… ──';

  @override
  String get terminalConnectionRestored => '── 已復原終端機連線 ──';

  @override
  String get terminalConnectionRestoreFailed => '── 無法復原終端機連線 ──';

  @override
  String get terminalReconnected => '終端機已重新連線（可能已開啟新 shell）';

  @override
  String get terminalReconnectFailed => '無法重新連線終端機，請手動新建終端機';

  @override
  String get sessionChooseHandoffPlatform => '請選擇交接平台';

  @override
  String sessionHandoffTargetFailed(String target) {
    return '交接至 $target 失敗';
  }

  @override
  String get sessionHandoffTimeout => '交接逾時，請再試一次';

  @override
  String get sessionNoActive => '沒有使用中的工作階段';

  @override
  String sessionLoadMoreFailed(String error) {
    return '無法載入更多工作階段：$error';
  }

  @override
  String get sessionOfflineTranscript => '離線模式：顯示快取的轉錄';

  @override
  String sessionTranscriptRefreshFailed(String error) {
    return '無法重新整理轉錄：$error';
  }

  @override
  String sessionOlderMessagesFailed(String error) {
    return '無法載入較早訊息：$error';
  }

  @override
  String sessionListLoadFailed(String error) {
    return '無法載入工作階段：$error';
  }

  @override
  String get sessionProfileSwitching => '設定檔正在切換，請稍後再試';

  @override
  String get sessionSubagentReadOnly => '子代理工作階段為唯讀';

  @override
  String get sessionChangedRetry => '工作階段已變更，請稍後再試';

  @override
  String sessionConnectionUnknown(String id) {
    return '工作階段連線不明：$id';
  }

  @override
  String sessionConnectionUnavailable(String id) {
    return '工作階段連線無法使用：$id';
  }

  @override
  String get sessionUnsavedTitle => '工作階段尚未儲存，無法產生標題';

  @override
  String get sessionShareLinkMissing => '伺服器未傳回分享連結';

  @override
  String sessionBatchDeletePartial(int deleted, int failed) {
    return '已刪除 $deleted 個，$failed 個刪除失敗';
  }

  @override
  String get sessionCouldNotCreate => '無法建立工作階段';

  @override
  String get sessionUserMessageMissing => '找不到對應的使用者訊息';

  @override
  String get sessionRestoreMessageMissing => '找不到要復原的使用者訊息';

  @override
  String get sessionBranchMessageMissing => '找不到要分支的訊息';

  @override
  String get sessionHistoryPositionMissing => '此訊息沒有歷史位置，請重新整理工作階段後再試';

  @override
  String get sessionRuntimeIdMissing => 'Hermes 未傳回執行階段 ID';

  @override
  String get aboutLicenses => '開放原始碼授權';

  @override
  String get aboutLicensesDescription => '檢視應用程式使用的第三方軟體授權';

  @override
  String get aboutProductDescription => 'Hermes Agent 的行動版用戶端';

  @override
  String get aboutProductInfo => '產品資訊';

  @override
  String get aboutTitle => '關於 Hermes';

  @override
  String get appTitle => 'Hermes Mobile';

  @override
  String get appearanceHaptics => '觸覺回饋';

  @override
  String get appearanceHapticsDesc => '傳送、發生錯誤與工作完成時震動提示';

  @override
  String get appearanceHighContrast => '高對比模式';

  @override
  String get appearanceHighContrastDesc => '增強文字與邊框對比';

  @override
  String get appearanceKeepAwake => '保持螢幕常亮';

  @override
  String get appearanceKeepAwakeDesc => '開啟對話時防止螢幕自動鎖定';

  @override
  String get appearanceModeDark => '深色';

  @override
  String get appearanceModeLight => '淺色';

  @override
  String get appearanceModeSystem => '跟隨系統';

  @override
  String get appearanceThemeColor => '主題色';

  @override
  String get appearanceTitle => '外觀';

  @override
  String get approvalRequests => '核准請求';

  @override
  String get backendConnected => '後端已連線';

  @override
  String get backendDisconnected => '後端未連線';

  @override
  String get billingAccountBalance => '帳戶餘額';

  @override
  String get billingAccountTab => '帳戶';

  @override
  String get billingAmountUsd => '金額 (USD)';

  @override
  String get billingAutoReload => '自動加值';

  @override
  String get billingAutoReloadDescription => '餘額低於門檻時補充額度';

  @override
  String get billingAutoReloadDisabled => '自動加值已關閉';

  @override
  String get billingAutoReloadEnabled => '自動加值已啟用';

  @override
  String get billingAutoReloadUpdateFailed => '無法更新自動加值';

  @override
  String get billingAvailableCredits => '可用額度';

  @override
  String get billingCancelAtPeriodEnd => '在週期結束時取消訂閱';

  @override
  String get billingCancelAtPeriodEndDescription => '目前方案權益會保留到本週期結束。';

  @override
  String get billingCancelAtPeriodEndQuestion => '在週期結束時取消？';

  @override
  String get billingCancelFailed => '無法取消訂閱';

  @override
  String get billingChargeCompleted => '額度購買已完成';

  @override
  String get billingChargeForbidden => '目前帳戶無法從應用程式購買額度';

  @override
  String get billingChargeIncomplete => '額度購買未完成';

  @override
  String get billingConfirmCancellation => '確認取消';

  @override
  String get billingConfirmPurchase => '確認購買';

  @override
  String get billingConfirmUpgrade => '確認升級方案。';

  @override
  String billingCreditsPerMonth(Object credits) {
    return '$credits credits/月';
  }

  @override
  String get billingCurrent => '目前';

  @override
  String get billingDowngrade => '降級';

  @override
  String get billingDowngradePeriodEnd => '降級將在目前週期結束後生效。';

  @override
  String get billingGatewayMissing => '尚未連接到 Hermes 閘道';

  @override
  String get billingInvalidReloadValues => '請輸入有效的門檻和加值金額';

  @override
  String get billingLoading => '正在讀取帳單狀態…';

  @override
  String get billingLoadingPlans => '正在讀取方案目錄…';

  @override
  String get billingLoggedIn => '已登入';

  @override
  String get billingLoggedOut => '未登入';

  @override
  String get billingManageInPortal => '在 Portal 管理';

  @override
  String billingMaximumCharge(Object amount) {
    return '最高 \$$amount';
  }

  @override
  String billingMinimumCharge(Object amount) {
    return '最低 \$$amount';
  }

  @override
  String get billingMonthlySpendingCap => '每月遠端消費上限';

  @override
  String get billingNoActivePlan => '沒有有效方案';

  @override
  String get billingNoPlans => '沒有可用的方案目錄';

  @override
  String get billingNoUsageData => '沒有可用的用量資料';

  @override
  String get billingNoUsageDescription => '閘道尚未回傳 Remote Spending 用量模型。';

  @override
  String get billingNotConnected => '未連接到 Hermes';

  @override
  String get billingNotProvided => '未提供';

  @override
  String get billingNotSet => '未設定';

  @override
  String get billingOpenPortal => '開啟 Portal';

  @override
  String get billingOpenVerification => '開啟驗證頁面';

  @override
  String get billingPaymentIncomplete => '付款未完成';

  @override
  String get billingPaymentMethod => '付款方式';

  @override
  String get billingPaymentTimeout => '付款狀態確認逾時，請在 Portal 中檢查結果';

  @override
  String get billingPending => '待生效';

  @override
  String billingPendingCancellation(Object date) {
    return '將於 $date 取消';
  }

  @override
  String billingPendingDowngrade(Object date, Object name) {
    return '將於 $date 降級到 $name';
  }

  @override
  String billingPerMonth(Object price) {
    return '$price/月';
  }

  @override
  String get billingPeriodEnd => '週期結束時';

  @override
  String get billingPlanAlreadyActive => '目前已使用此方案。';

  @override
  String billingPlanChangeEffectiveAt(Object date) {
    return '方案變更將於 $date 生效。';
  }

  @override
  String get billingPlanChangeFailed => '無法變更方案';

  @override
  String get billingPlanChangeForbidden => '目前帳戶沒有變更方案的權限';

  @override
  String get billingPlanChangePeriodEnd => '方案變更將在目前週期結束後生效。';

  @override
  String get billingPlanChangeUnavailable => '此變更目前無法使用。';

  @override
  String get billingPlanCredits => '方案額度';

  @override
  String get billingPlansTab => '方案';

  @override
  String get billingPortalMissing => '伺服器未提供帳單 Portal 網址';

  @override
  String get billingPortalOpenFailed => '無法開啟帳單 Portal';

  @override
  String get billingPurchaseCredits => '購買額度';

  @override
  String get billingReloadAboveMaximum => '加值金額超過伺服器允許的最高值';

  @override
  String get billingReloadBelowMinimum => '加值金額低於伺服器允許的最低值';

  @override
  String get billingReloadTo => '加值至';

  @override
  String billingRemaining(Object amount) {
    return '剩餘 $amount';
  }

  @override
  String billingRenews(Object date) {
    return '續期 $date';
  }

  @override
  String get billingResumeFailed => '無法復原待處理的變更';

  @override
  String get billingSaveAutoReload => '儲存自動加值';

  @override
  String billingSpentThisMonth(Object amount) {
    return '本月已使用 $amount';
  }

  @override
  String billingSwitchPlan(Object name) {
    return '切換到 $name？';
  }

  @override
  String get billingTitle => '帳單';

  @override
  String get billingTopupCredits => '加值額度';

  @override
  String get billingTriggerThreshold => '觸發門檻';

  @override
  String get billingUnavailableForAccount => '此帳戶無法使用';

  @override
  String billingUpgradeAmount(Object amount) {
    return '升級將立即生效，本次應付 \$$amount。';
  }

  @override
  String get billingUpgradeChargeNow => '升級將立即生效並產生費用。';

  @override
  String get billingUsageTab => '用量';

  @override
  String billingUsedOf(Object spent, Object total) {
    return '已用 $spent / $total';
  }

  @override
  String billingVerificationFailed(Object error) {
    return '驗證失敗：$error';
  }

  @override
  String get billingVerificationIncomplete => '驗證尚未完成，請稍後重試';

  @override
  String get billingVerificationInstructions => '請在瀏覽器中完成驗證，以允許此裝置執行遠端消費操作。';

  @override
  String get billingVerificationRequired => '需要額外驗證';

  @override
  String get billingVerificationStarting => '正在啟動驗證…';

  @override
  String get billingVerificationSucceeded => '驗證成功，可以繼續操作';

  @override
  String get billingVerifyAndContinue => '驗證並繼續';

  @override
  String get billingViewSubscriptionInPortal => '可前往 Portal 查看訂閱。';

  @override
  String get chatAbsoluteServerPath => '使用伺服器上的絕對路徑';

  @override
  String get chatAddImage => '新增圖片';

  @override
  String chatAddImageFailed(String error) {
    return '新增圖片失敗：$error';
  }

  @override
  String chatAddedToQueue(int count) {
    return '已加入佇列（目前排隊 $count 則）';
  }

  @override
  String get chatAllDates => '所有日期';

  @override
  String get chatAllHistoryShown => '已顯示全部歷史記錄';

  @override
  String get chatApprovalManual => '手動';

  @override
  String get chatApprovalManualDescription => '每一步都需要確認';

  @override
  String get chatApprovalMode => '審批模式';

  @override
  String chatApprovalModeFailed(String error) {
    return '設定審批模式失敗：$error';
  }

  @override
  String chatApprovalModeSet(String mode) {
    return '審批模式已設為 $mode';
  }

  @override
  String get chatApprovalOff => '關閉';

  @override
  String get chatApprovalOffDescription => '無需確認，自動執行';

  @override
  String get chatApprovalSmart => '智慧';

  @override
  String get chatApprovalSmartDescription => '僅在有風險的操作時詢問';

  @override
  String get chatApprovalsUsage => '用法：/approvals manual|smart|off';

  @override
  String chatArtifactVersions(int count) {
    return '全部版本（$count）';
  }

  @override
  String get chatAssistant => '助手';

  @override
  String get chatAttach => '新增';

  @override
  String get chatAttachFiles => '新增檔案';

  @override
  String get chatAttachLink => '新增連結';

  @override
  String chatAttachmentUploadFailed(String error) {
    return '附件上傳失敗：$error';
  }

  @override
  String get chatAutoRetried => '已自動重試';

  @override
  String get chatBackToNewerMessages => '返回較新的訊息';

  @override
  String get chatBackToWorkspace => '返回工作區';

  @override
  String get chatBackgroundAgentRunning => '背景代理執行中 · 完成後將繼續本回合';

  @override
  String chatBackgroundAgentsRunning(int count) {
    return '$count 個背景代理執行中 · 完成後將繼續';
  }

  @override
  String chatBackgroundCount(int count) {
    return '$count 個背景任務';
  }

  @override
  String get chatBackgroundPrompt => '背景任務指令';

  @override
  String chatBackgroundSubmitFailed(String error) {
    return '提交背景任務失敗：$error';
  }

  @override
  String get chatBackgroundSubmitted => '已提交背景任務';

  @override
  String chatBackgroundSubmittedWithId(String id) {
    return '已提交背景任務（$id）';
  }

  @override
  String chatBackgroundTaskCompleted(String label) {
    return '$label 已完成';
  }

  @override
  String chatBackgroundTaskFailed(String label) {
    return '$label 失敗';
  }

  @override
  String get chatBasicToolsets => '基礎工具集';

  @override
  String get chatBranch => '分支';

  @override
  String chatBranchChanges(String branch, int changedFiles) {
    return '$branch · $changedFiles 個檔案變更';
  }

  @override
  String get chatBranchCreated => '已建立分支工作階段';

  @override
  String chatBranchCreatedWithId(String id) {
    return '已建立分支工作階段（$id）';
  }

  @override
  String chatBranchFailed(String error) {
    return '建立分支失敗：$error';
  }

  @override
  String get chatBranchInNewSession => '在新工作階段中建立分支';

  @override
  String get chatBranchedHere => '已從此處建立分支';

  @override
  String chatBranchedWithId(String id) {
    return '已從此處建立分支（$id）';
  }

  @override
  String chatBranchesLoadFailed(String error) {
    return '載入分支失敗：$error';
  }

  @override
  String get chatBrowseArtifactsDescription => '瀏覽此工作階段產生的產物';

  @override
  String get chatBrowseFiles => '瀏覽檔案管理器';

  @override
  String get chatBrowseFilesDescription => '在檔案管理器中定位並選擇目錄';

  @override
  String get chatCancelKeyboardHint => '取消 (Esc)';

  @override
  String get chatCatalogEmpty => '暫無可用伺服器';

  @override
  String get chatChangeWorkspace => '切換工作區';

  @override
  String get chatChangeWorkspaceDescription => 'AI 接下來會在選取的伺服器目錄中讀取和修改檔案';

  @override
  String get chatClosePreview => '關閉預覽';

  @override
  String get chatCollapseStatusDetails => '收合詳情';

  @override
  String get chatCollapseSubsessions => '收合子工作階段';

  @override
  String get chatCommandCompletedNoOutput => '命令已執行，無輸出';

  @override
  String get chatCommandExecutionFailed => '命令執行失敗';

  @override
  String chatCommandFailed(String error) {
    return '命令執行失敗：$error';
  }

  @override
  String get chatCommandMessageQueued => '訊息已加入佇列';

  @override
  String get chatCommandNoFillContent => '沒有可填入的內容';

  @override
  String get chatCommandNoSendableContent => '沒有可傳送的內容';

  @override
  String get chatCommandQueued => '命令已加入佇列';

  @override
  String get chatCommandSearchHint => '換個關鍵字試試';

  @override
  String get chatCommandSearchFailed => '指令載入失敗，請檢查網路連線';

  @override
  String get chatCommandStarting => '命令正在執行';

  @override
  String get chatCompositeToolsets => '組合工具集';

  @override
  String get chatCompressContext => '壓縮';

  @override
  String chatCompressionFailed(String error) {
    return '壓縮上下文失敗：$error';
  }

  @override
  String get chatCompressionRequested => '已請求壓縮上下文';

  @override
  String get chatConfigureProvider => '設定服務商';

  @override
  String get chatConnecting => '正在連線';

  @override
  String get chatConnectionFailed => '連線失敗';

  @override
  String get chatContentFilled => '內容已填入';

  @override
  String get chatContextUsage => '上下文佔用';

  @override
  String chatContextUsagePercent(int percent) {
    return '上下文佔用 $percent%';
  }

  @override
  String get chatCopyAsMarkdown => '複製為 Markdown';

  @override
  String get chatCopyDiagnostics => '複製診斷資訊';

  @override
  String get chatCopySessionId => '複製工作階段 ID';

  @override
  String get chatCopySessionLink => '複製工作階段連結';

  @override
  String get chatCopyText => '複製文字';

  @override
  String get chatCreateScheduledTask => '建立排程任務';

  @override
  String chatCronSuggestion(String phrase) {
    return '偵測到排程：$phrase';
  }

  @override
  String get chatCurrentSessionArtifacts => '此工作階段的產物';

  @override
  String get chatCurrentSessionToolsets => '目前工作階段工具集';

  @override
  String get chatCurrentlyActive => '目前啟用';

  @override
  String chatDeletePromptFailed(String error) {
    return '刪除提示詞失敗：$error';
  }

  @override
  String get chatDeliveryUncertain => '投遞狀態未知';

  @override
  String get chatDiagnosticsCopied => '診斷資訊已複製';

  @override
  String chatDiagnosticsError(String error) {
    return '錯誤資訊：$error';
  }

  @override
  String chatDiagnosticsModel(String provider, String model) {
    return '模型：$provider / $model';
  }

  @override
  String chatDiagnosticsTime(String time) {
    return '時間：$time';
  }

  @override
  String get chatDiagnosticsTitle => '診斷資訊';

  @override
  String chatEditFailed(String error) {
    return '編輯失敗：$error';
  }

  @override
  String get chatEditMessageHint => '編輯訊息…';

  @override
  String get chatEditMessageKeyboardHint => '編輯訊息…（Enter 傳送，Shift+Enter 換行）';

  @override
  String get chatEmptyDescription => '串流回覆、工具呼叫、審批與澄清，功能與桌面版同樣完整。';

  @override
  String get chatEmptyTitle => '開始與 Hermes 對話吧';

  @override
  String get chatEnterOtherDirectory => '輸入其他目錄';

  @override
  String get chatEnterWorkspacePath => '輸入工作區路徑';

  @override
  String get chatErrorAuth => '身分驗證錯誤';

  @override
  String get chatErrorBilling => '帳單錯誤';

  @override
  String get chatErrorNetwork => '網路錯誤';

  @override
  String get chatErrorProvider => '服務商錯誤';

  @override
  String get chatErrorRateLimit => '觸發速率限制';

  @override
  String get chatErrorReply => '回覆出錯';

  @override
  String get chatExecuting => '執行中…';

  @override
  String chatExecutionFailed(String error) {
    return '執行失敗：$error';
  }

  @override
  String get chatExpandStatusDetails => '展開詳情';

  @override
  String get chatExpandSubsessions => '展開子工作階段';

  @override
  String chatFileTooLarge(int maxMb, String name) {
    return '$name 超過 $maxMb MB 限制';
  }

  @override
  String get chatFillRetry => '重試';

  @override
  String get chatFindHint => '在目前對話中尋找';

  @override
  String get chatFindInConversation => '在對話中尋找';

  @override
  String chatFolderFilesAttached(int attached, int skipped) {
    return '已新增 $attached 個檔案（略過 $skipped 個）';
  }

  @override
  String get chatFolderPickerUnavailable => '目前平台不支援選擇資料夾';

  @override
  String chatForwardedToCommand(String target) {
    return '已轉發至 /$target';
  }

  @override
  String get chatGlobalCliToolsets => '全域 CLI 工具集';

  @override
  String get chatGlobalToolsetsDescription => '全域 CLI 工具集開關，立即生效';

  @override
  String get chatGoals => '目標';

  @override
  String chatHandingOffTo(String name) {
    return '正在交接給 $name…';
  }

  @override
  String get chatHandoff => '交接';

  @override
  String get chatHandoffCompleted => '已完成';

  @override
  String chatHandoffCompletedTo(String name) {
    return '已交接給 $name';
  }

  @override
  String chatHandoffFailed(String error) {
    return '交接失敗：$error';
  }

  @override
  String get chatHandoffFailedStatus => '失敗';

  @override
  String get chatHandoffGatewayRunning => '執行中';

  @override
  String chatHandoffPlatformsFailed(String error) {
    return '載入交接平台失敗：$error';
  }

  @override
  String get chatHandoffTimeout => '交接逾時';

  @override
  String get chatHandoffToPlatform => '交接至平台';

  @override
  String get chatHandoffWaiting => '等待中';

  @override
  String get chatHideStatus => '隱藏';

  @override
  String get chatHistoryLocator => '定位聊天記錄';

  @override
  String chatHomeChannel(String name) {
    return '主頻道：$name';
  }

  @override
  String get chatHomeChannelNotSet => '未設定主頻道';

  @override
  String get chatHtmlPreview => 'HTML 預覽';

  @override
  String get chatInflightRecovered => '已還原未完成的回覆';

  @override
  String get chatInsufficientQuota => '額度不足';

  @override
  String get chatInvalidCommandAlias => '無效的命令別名';

  @override
  String get chatJumpToTopic => '跳轉到話題';

  @override
  String get chatLast24Hours => '最近 24 小時';

  @override
  String get chatLast7Days => '最近 7 天';

  @override
  String get chatLastTurnRetried => '已重試上一輪';

  @override
  String get chatLastTurnUndone => '已復原上一輪';

  @override
  String get chatLoadFailed => '載入失敗';

  @override
  String get chatLoadOlderMessagesHint => '向上滑動載入較舊訊息';

  @override
  String get chatLoadingCommands => '正在載入命令…';

  @override
  String get chatLocalCommands => '本機命令';

  @override
  String get chatLocateTopic => '定位話題';

  @override
  String get chatLongPressCodingStatus => '長按編碼狀態可切換分支或新增工作樹';

  @override
  String get chatMarkMessage => '標記訊息';

  @override
  String get chatMarkdownCopied => '已複製為 Markdown';

  @override
  String get chatMarkedOnly => '僅顯示標記';

  @override
  String chatMessageCount(int count) {
    return '$count 則訊息';
  }

  @override
  String get chatModel => '模型';

  @override
  String get chatModelSwitchDeferred => '模型切換將於下一輪生效';

  @override
  String chatModelSwitchFailed(String error) {
    return '切換模型失敗：$error';
  }

  @override
  String chatModelsLoadFailed(String error) {
    return '載入模型清單失敗：$error';
  }

  @override
  String chatMonthDay(int month, int day) {
    return '$month 月 $day 日';
  }

  @override
  String get chatMyMessages => '我的訊息';

  @override
  String get chatNewSessionOpened => '已開啟新工作階段';

  @override
  String get chatNewWorktreeDescription => '建立新的 Git 工作樹';

  @override
  String get chatNoActiveTurnQueued => '目前沒有進行中的回覆，已加入佇列';

  @override
  String get chatNoConfigurableToolsets => '後端沒有可設定的工具集';

  @override
  String get chatNoContextData => '暫無上下文資料';

  @override
  String get chatNoHandoffPlatforms => '沒有可用的交接平台';

  @override
  String get chatNoHandoffPlatformsDescription => '尚未連接任何可交接的平台';

  @override
  String get chatNoMatchingCommands => '沒有相符的命令';

  @override
  String get chatNoMatchingMessages => '沒有相符的訊息';

  @override
  String get chatNoProfiles => '後端沒有可切換的設定檔';

  @override
  String get chatNoQueuedMessages => '佇列中沒有訊息';

  @override
  String get chatNoRetryMessage => '沒有可重試的訊息';

  @override
  String get chatNoSavedPrompts => '尚未儲存任何提示詞';

  @override
  String get chatNoSessions => '沒有工作階段';

  @override
  String get chatNoText => '無文字內容';

  @override
  String get chatNoUploadableFolderFiles => '資料夾中沒有可上傳的檔案';

  @override
  String get chatNotConfigured => '尚未設定';

  @override
  String get chatNotConnected => '未連接';

  @override
  String get chatOlderMessagesLoadFailed => '載入較舊訊息失敗，點一下重試';

  @override
  String chatPendingRequests(String kind, int count) {
    return '$kind（還有 $count 項待處理）';
  }

  @override
  String chatPlanProgress(int completed, int total) {
    return '$completed/$total 項已完成';
  }

  @override
  String chatPreviewCount(int count) {
    return '$count 個預覽';
  }

  @override
  String chatProfileSwitchFailed(String error) {
    return '切換設定檔失敗：$error';
  }

  @override
  String chatProfileSwitched(String profile) {
    return '已切換至「$profile」';
  }

  @override
  String chatProfilesLoadFailed(String error) {
    return '載入設定檔失敗：$error';
  }

  @override
  String get chatPromptSaved => '提示詞已儲存';

  @override
  String get chatProvider => '服務商';

  @override
  String get chatQueue => '佇列';

  @override
  String chatQueueFailed(String error) {
    return '加入佇列失敗：$error';
  }

  @override
  String get chatQueuePaused => '佇列已暫停';

  @override
  String chatQueueSummary(String label, int count, String expandLabel) {
    return '$label · $count 則 · $expandLabel';
  }

  @override
  String get chatQueueUsage => '請輸入要加入佇列的內容';

  @override
  String get chatQueued => '已加入佇列';

  @override
  String get chatQueuedMessageUpdated => '佇列訊息已更新';

  @override
  String chatQueuedMinutesAgo(int minutes) {
    return '$minutes 分鐘前加入佇列';
  }

  @override
  String chatQueuedSecondsAgo(int seconds) {
    return '$seconds 秒前加入佇列';
  }

  @override
  String get chatReasoningEffort => '推理強度';

  @override
  String get chatReasoningEffortDescription => '更新後端 reasoning effort 設定';

  @override
  String chatReasoningEffortSet(String value) {
    return '推理強度已設為 $value';
  }

  @override
  String chatReasoningEffortSetFailed(String error) {
    return '設定推理強度失敗：$error';
  }

  @override
  String get chatReconnecting => '正在重新連線';

  @override
  String get chatRegenerate => '重新產生';

  @override
  String chatRegenerateFailed(String error) {
    return '重新產生失敗：$error';
  }

  @override
  String get chatRegenerateTitle => '重新產生標題';

  @override
  String chatRegenerateTitleFailed(String error) {
    return '重新產生標題失敗：$error';
  }

  @override
  String get chatRename => '重新命名';

  @override
  String get chatRenameSession => '重新命名工作階段';

  @override
  String get chatRequestApproval => '審批請求';

  @override
  String get chatRequestMcpConfig => 'MCP 設定請求';

  @override
  String get chatRequestPassword => '密碼請求';

  @override
  String get chatRequestQuestion => '提問請求';

  @override
  String get chatRequestSecret => '密鑰請求';

  @override
  String get chatRequestTerminalInput => '終端機輸入請求';

  @override
  String get chatRestoreAndRerun => '還原並重新執行';

  @override
  String chatRestoreFailed(String error) {
    return '還原失敗：$error';
  }

  @override
  String get chatRestoreToMessage => '還原至此訊息';

  @override
  String get chatRestoreToMessageTitle => '還原至此訊息？';

  @override
  String get chatRestoreVersionTitle => '還原此版本？';

  @override
  String chatRetryFailed(String error) {
    return '重試失敗：$error';
  }

  @override
  String get chatRunInBackground => '在背景執行';

  @override
  String get chatSaveCurrentInput => '儲存目前輸入';

  @override
  String chatSavePromptFailed(String error) {
    return '儲存提示詞失敗：$error';
  }

  @override
  String get chatSavedPrompts => '已儲存的提示詞';

  @override
  String chatSavedPromptsLoadFailed(String error) {
    return '載入已儲存的提示詞失敗：$error';
  }

  @override
  String get chatScrollToBottom => '捲動到底部';

  @override
  String get chatSearchLoadedHistory => '搜尋已載入的歷史記錄';

  @override
  String chatSelectFilesFailed(String error) {
    return '選取檔案失敗：$error';
  }

  @override
  String get chatSelectFolder => '選擇資料夾';

  @override
  String chatSelectFolderFailed(String error) {
    return '選擇資料夾失敗：$error';
  }

  @override
  String get chatSelectProfile => '選擇設定檔';

  @override
  String get chatSelectProfileDescription => '選擇首頁資料與後續啟動使用的設定檔';

  @override
  String get chatSendDiagnostics => '傳送診斷資訊';

  @override
  String get chatSendEdit => '傳送編輯';

  @override
  String get chatSendEditAndRerun => '傳送編輯並重新執行';

  @override
  String get chatSendEditTitle => '傳送編輯後的訊息？';

  @override
  String chatSendFailed(String error) {
    return '傳送失敗：$error';
  }

  @override
  String get chatSendNow => '立即傳送';

  @override
  String get chatSendQueue => '傳送佇列';

  @override
  String chatSendQueueCount(int count) {
    return '傳送佇列 ($count)';
  }

  @override
  String get chatServerCatalog => '伺服器目錄';

  @override
  String get chatServerDirectory => '伺服器目錄';

  @override
  String get chatServerDirectoryHelp => '目錄必須存在，且伺服器帳戶必須具有存取權限';

  @override
  String get chatServerNotConnected => '伺服器未連接';

  @override
  String get chatSessionCleared => '工作階段已清空';

  @override
  String get chatSessionIdCopied => '工作階段 ID 已複製';

  @override
  String get chatSessionInfo => '工作階段資訊';

  @override
  String get chatSessionMenu => '工作階段選單';

  @override
  String get chatSessionShareLinkCopied => '工作階段分享連結已複製';

  @override
  String get chatSessionToolsetsDescription => '工作階段工具集（僅影響目前工作階段）';

  @override
  String get chatSessions => '工作階段';

  @override
  String get chatSetAsNext => '設為下一則';

  @override
  String chatSetTitleFailed(String error) {
    return '設定標題失敗：$error';
  }

  @override
  String chatShareLinkFailed(String error) {
    return '取得分享連結失敗：$error';
  }

  @override
  String get chatShareUrlMissing => '未取得分享連結';

  @override
  String get chatSkillsCenter => '技能中心';

  @override
  String get chatSlashCommands => '斜線命令';

  @override
  String get chatStartSessionBeforeWorkspace => '請先開始工作階段，再切換工作區';

  @override
  String get chatStarterDebugIssue => '協助我偵錯';

  @override
  String get chatStarterDebugIssuePrompt => '我遇到了一個問題，請先協助我整理偵錯方向。';

  @override
  String get chatStarterExplainProject => '說明這個專案';

  @override
  String get chatStarterExplainProjectPrompt => '請快速介紹這個專案的結構、核心功能和執行方式。';

  @override
  String get chatStarterReviewChanges => '檢查目前變更';

  @override
  String get chatStarterReviewChangesPrompt => '請檢查目前工作區的變更，指出潛在問題並提供改善建議。';

  @override
  String get chatSteerCurrentTurn => '引導目前回合';

  @override
  String get chatSteerHint => '引導內容';

  @override
  String get chatSteerInjected => '引導內容已注入';

  @override
  String get chatSteerMessage => '引導訊息';

  @override
  String chatSteerNowFailed(String error) {
    return '立即引導失敗：$error';
  }

  @override
  String get chatSteerQueued => '引導內容已加入佇列';

  @override
  String get chatSteerUsage => '請輸入要引導的內容';

  @override
  String get chatStopProcess => '停止程序';

  @override
  String chatStopProcessFailed(String error) {
    return '停止程序失敗：$error';
  }

  @override
  String chatSubagentCount(int count) {
    return '$count 個子代理';
  }

  @override
  String get chatTextSnippet => '文字片段';

  @override
  String get chatTextSnippetHint => '貼上或輸入文字';

  @override
  String get chatTitle => 'Hermes 聊天';

  @override
  String chatTitleSet(String title) {
    return '標題已設為「$title」';
  }

  @override
  String get chatTitleUnchanged => '標題未變更';

  @override
  String chatTitleUpdated(String title) {
    return '標題已更新為「$title」';
  }

  @override
  String get chatToday => '今天';

  @override
  String get chatToolConfiguration => '工具設定';

  @override
  String chatToolCount(int count) {
    return '$count 個工具';
  }

  @override
  String get chatToolStatusMessage => '工具狀態訊息';

  @override
  String chatToolsetCounts(String sessionCount, String globalCount) {
    return '工作階段：$sessionCount · 全域：$globalCount';
  }

  @override
  String chatToolsetToggleFailed(String name, String error) {
    return '切換 $name 失敗：$error';
  }

  @override
  String chatToolsetsEnabled(String globalCount) {
    return '已啟用全域工具集（$globalCount）';
  }

  @override
  String get chatToolsetsExplanation =>
      '目前工作階段工具集是 Hermes Agent 在此工作階段實際註冊並可使用的工具集。\n全域 CLI 工具集來自全域設定，不代表目前工作階段已全部載入。';

  @override
  String get chatToolsetsLoadFailed => '載入工具集失敗';

  @override
  String chatTopicNumber(int index) {
    return '話題 $index';
  }

  @override
  String chatTopicRailSemantics(int count) {
    return '$count 個話題';
  }

  @override
  String get chatTranscriptLoadFailed => '載入聊天記錄失敗';

  @override
  String get chatTruncateWarning => '這將刪除後續所有訊息，且無法復原';

  @override
  String chatUndoFailed(String error) {
    return '復原失敗：$error';
  }

  @override
  String get chatUnknownCommandResult => '未知的命令結果';

  @override
  String get chatUnknownTime => '未知時間';

  @override
  String get chatUnmarkMessage => '取消標記';

  @override
  String get chatUntitled => '未命名工作階段';

  @override
  String get chatUntitledSession => '未命名工作階段';

  @override
  String get chatVersion => '版本資訊';

  @override
  String chatVersionCount(int count) {
    return '$count 個版本';
  }

  @override
  String chatVersionLoadFailed(String error) {
    return '載入版本失敗：$error';
  }

  @override
  String chatVersionNumber(int index) {
    return '版本 $index';
  }

  @override
  String get chatViewBilling => '查看帳單';

  @override
  String get chatViewCleared => '檢視已清空';

  @override
  String get chatWakeServiceUnavailable => '喚醒詞服務不可用';

  @override
  String chatWakeVoiceFailed(String error) {
    return '語音喚醒失敗：$error';
  }

  @override
  String chatWarning(String warning) {
    return '警告：$warning';
  }

  @override
  String get chatWorkingDirectory => '工作目錄';

  @override
  String get chatWorkspace => '工作區';

  @override
  String get chatWorkspaceFiles => '工作區檔案';

  @override
  String chatWorkspaceSwitchFailed(String error) {
    return '切換工作區失敗：$error';
  }

  @override
  String chatWorkspaceSwitched(String name) {
    return '工作區已切換至 $name';
  }

  @override
  String get chatYesterday => '昨天';

  @override
  String get chatYoloDisabled => '已關閉 YOLO 模式';

  @override
  String get chatYoloEnabled => '已開啟 YOLO 模式';

  @override
  String get chatYoloMode => 'YOLO 模式';

  @override
  String chatYoloToggleFailed(String error) {
    return '切換 YOLO 模式失敗：$error';
  }

  @override
  String get appSessionCompletedTitle => '工作階段已完成';

  @override
  String get appSessionCompletedBody => '背景工作階段已完成，點一下查看結果';

  @override
  String appOpenNotificationFailed(Object error) {
    return '無法開啟通知工作階段：$error';
  }

  @override
  String get deepLinkPluginInstallTitle => '安裝 Hermes 外掛程式';

  @override
  String get deepLinkPluginInstallPrompt => '此連結要求從以下來源安裝後端外掛程式：';

  @override
  String get deepLinkLegacyPluginWarning =>
      '這是舊版 Desktop 外掛程式連結；行動版只會安裝其後端 Agent 功能。';

  @override
  String get deepLinkEnableAfterInstall => '安裝後啟用';

  @override
  String get deepLinkForceReinstall => '強制重新安裝';

  @override
  String get deepLinkInstall => '安裝';

  @override
  String deepLinkPluginInstalling(Object identifier) {
    return '正在安裝 $identifier…';
  }

  @override
  String get deepLinkPluginInstalled => '外掛程式已安裝';

  @override
  String deepLinkPluginInstallFailed(Object error) {
    return '外掛程式安裝失敗：$error';
  }

  @override
  String get deepLinkMcpAddTitle => '新增 MCP 伺服器';

  @override
  String get deepLinkMcpServerName => '伺服器名稱';

  @override
  String get deepLinkMcpNameFormatError => '僅允許 1–64 個字母、數字、句點、底線或連字號';

  @override
  String get deepLinkMcpNameConflict => '此名稱已存在，請使用其他名稱';

  @override
  String get deepLinkMcpCommandWarning => '此設定會在 Hermes 後端執行本機命令。請只確認您信任的來源。';

  @override
  String get deepLinkConfigPreview => '設定預覽';

  @override
  String deepLinkMcpAdded(Object name) {
    return '已新增 MCP 伺服器 $name';
  }

  @override
  String deepLinkMcpAddFailed(Object error) {
    return '無法新增 MCP 伺服器：$error';
  }

  @override
  String get commonAdd => '新增';

  @override
  String get commonAll => '全部';

  @override
  String get commonAuthorize => '授權';

  @override
  String get commonBack => '返回';

  @override
  String get commonCancel => '取消';

  @override
  String get commonCancelAll => '全部取消';

  @override
  String get commonClose => '關閉';

  @override
  String get commonCollapse => '收合';

  @override
  String get commonCompleted => '已完成';

  @override
  String get commonConfirm => '確定';

  @override
  String get commonConnected => '已連線';

  @override
  String get commonContinue => '繼續';

  @override
  String get commonCopied => '已複製';

  @override
  String get commonCreate => '建立';

  @override
  String get commonDefault => '預設';

  @override
  String get commonDelete => '刪除';

  @override
  String get commonDisconnect => '中斷連線';

  @override
  String get commonDisconnected => '未連線';

  @override
  String get commonDone => '已完成';

  @override
  String get commonEdit => '編輯';

  @override
  String get commonErrorTitle => '發生錯誤';

  @override
  String get commonAuthenticationFailed => '驗證失敗，請檢查 API 金鑰';

  @override
  String get commonExpand => '展開';

  @override
  String get commonFile => '檔案';

  @override
  String get commonFolder => '資料夾';

  @override
  String get commonGotIt => '知道了';

  @override
  String get commonHide => '隱藏';

  @override
  String get commonIdle => '閒置';

  @override
  String get commonIgnore => '忽略';

  @override
  String get commonLater => '稍後';

  @override
  String get commonListSeparator => '，';

  @override
  String get commonLoading => '載入中…';

  @override
  String get commonManage => '管理';

  @override
  String get commonMore => '更多';

  @override
  String get commonName => '名稱';

  @override
  String get commonNew => '新增';

  @override
  String get commonNext => '下一個';

  @override
  String get commonNoMatches => '沒有符合結果';

  @override
  String get commonNotifications => '通知';

  @override
  String get commonOffline => '離線';

  @override
  String get commonOnline => '線上';

  @override
  String get commonOperationFailed => '操作失敗，請稍後重試';

  @override
  String get commonNetworkFailed => '無法連線伺服器，請檢查網路和伺服器狀態';

  @override
  String get commonOpen => '開啟';

  @override
  String get commonPrevious => '上一個';

  @override
  String get commonProcessing => '處理中…';

  @override
  String get commonReauthorize => '重新授權';

  @override
  String get commonRefresh => '重新整理';

  @override
  String get commonReload => '重新載入';

  @override
  String get commonReset => '重設';

  @override
  String get commonRestart => '重新啟動';

  @override
  String get commonRetry => '重試';

  @override
  String get commonRun => '執行';

  @override
  String get commonRunning => '執行中';

  @override
  String get commonSave => '儲存';

  @override
  String get commonSearch => '搜尋';

  @override
  String get commonSelect => '選擇';

  @override
  String get commonSend => '傳送';

  @override
  String get commonStop => '停止';

  @override
  String get commonSubmit => '提交';

  @override
  String get commonSwitch => '切換';

  @override
  String get commonTitle => '標題';

  @override
  String get commonUndo => '復原';

  @override
  String get commonUnknownError => '未知錯誤';

  @override
  String get commonViewAll => '查看全部';

  @override
  String get configAppliesToProfile => '套用至 Profile';

  @override
  String get configConnectionLabel => '連線';

  @override
  String get configCurrentProfile => '目前 Profile';

  @override
  String get configDefaultProcessProfile => '預設 / 程序 Profile';

  @override
  String configDeleteFailed(String error) {
    return '無法移除覆寫：$error';
  }

  @override
  String get configFullJson => '完整 JSON';

  @override
  String configInvalidFieldValue(String path, String error) {
    return '$path 的值無效：$error';
  }

  @override
  String configInvalidJson(String error) {
    return 'JSON 無效：$error';
  }

  @override
  String get configListJsonError => '值必須是 JSON array';

  @override
  String get configLoading => '正在讀取設定與 schema…';

  @override
  String get configNoMatches => '沒有相符欄位';

  @override
  String get configObjectJsonError => '值必須是 JSON object';

  @override
  String get configRemoveOverride => '移除覆寫並使用預設值';

  @override
  String get configRestore => '還原';

  @override
  String get configRestoreDefaults => '還原預設值';

  @override
  String configRestoreDefaultsDescription(String profile) {
    return '這會套用至$profile。現有自訂值將由預設值取代。';
  }

  @override
  String get configRestoreDefaultsQuestion => '要還原 Hermes 預設設定嗎？';

  @override
  String configSaveFailed(String error) {
    return '無法儲存：$error';
  }

  @override
  String get providerEndpointValidationFailed => '端點驗證失敗';

  @override
  String get kanbanMoveSelected => '移動選取的任務';

  @override
  String get kanbanClearSelection => '清除任務選取';

  @override
  String get configSearchHint => '搜尋設定欄位…';

  @override
  String configServerDidNotDelete(String path) {
    return '伺服器未移除 $path';
  }

  @override
  String get configServerMismatch => '伺服器傳回的內容與提交的完整設定不同';

  @override
  String configServerRejected(String path) {
    return '伺服器未接受 $path；已還原伺服器值。';
  }

  @override
  String get configTitle => '模型與對話';

  @override
  String get configTopLevelObject => '最上層 JSON 值必須是 object';

  @override
  String get configUseDefault => '預設';

  @override
  String get connectAction => '連線';

  @override
  String get connectAddHeader => '新增請求標頭';

  @override
  String get connectAllowPublicHttp => '允許公網 HTTP 明文連線';

  @override
  String get connectAllowPublicHttpWarning => '僅限無法使用 HTTPS 的受信任網路；Token 可能遭截取';

  @override
  String get connectApiKey => 'API 金鑰';

  @override
  String get connectConfiguration => '連線設定';

  @override
  String get connectConnecting => '連線中…';

  @override
  String get connectCredentialRequired => '請輸入存取憑證';

  @override
  String get connectDeleteHeader => '刪除請求標頭';

  @override
  String get connectDeleteProfile => '刪除設定';

  @override
  String get connectDiscoverCloud => '從 Hermes Cloud 探索 Agent';

  @override
  String get connectExtraHeaders => '額外請求標頭';

  @override
  String get connectHeaderManaged => '由 Hermes 管理';

  @override
  String get connectHeaderName => 'Header 名稱';

  @override
  String get connectHeaderNameInvalid => '名稱無效';

  @override
  String get connectHeaderValue => '值';

  @override
  String get connectHeaderValueRequired => '請輸入值';

  @override
  String get connectHeadersDescription => '存取代理所需的選填標頭；值會存入系統安全儲存空間。';

  @override
  String get connectHideKey => '隱藏金鑰';

  @override
  String get connectHidePassphrase => '隱藏密語';

  @override
  String get connectHidePassword => '隱藏密碼';

  @override
  String get connectHidePrivateKey => '隱藏私鑰';

  @override
  String get connectHideValue => '隱藏';

  @override
  String get connectHttpsRequired => '公網連線必須使用 HTTPS，或明確允許不安全傳輸';

  @override
  String get connectNativeCleartextRestricted =>
      'Release 版本僅允許 localhost 或 .local companion 名稱使用明文 HTTP；請改用 HTTPS 或 .local 主機名稱。';

  @override
  String get connectNotSignedIn => '尚未登入';

  @override
  String get connectOauthSignedIn => '已透過 OAuth 登入';

  @override
  String get connectPkceUnavailable =>
      '此 Gateway 不支援 native_pkce 登入，請更新 Hermes 或改用 Token。';

  @override
  String get connectPort => '連接埠';

  @override
  String get connectPrivateKey => 'OpenSSH / PEM 私鑰';

  @override
  String get connectPrivateKeyPassphrase => '私鑰密語（選填）';

  @override
  String get connectProfileName => '設定名稱（預設使用主機名稱）';

  @override
  String get connectProfileNameInvalid => 'Profile 名稱無效';

  @override
  String get connectRemoteHermesPath => '遠端 Hermes 路徑（自動偵測）';

  @override
  String get connectRemoteProfile => '遠端 Profile（選填）';

  @override
  String get connectSaveProfile => '儲存為伺服器設定';

  @override
  String get connectSaveProfileDescription => '下次可從已儲存列表快速切換';

  @override
  String get connectSavedBackends => '已儲存的後端';

  @override
  String get connectServerAddress => '伺服器位址';

  @override
  String get connectServerInvalid => '請輸入有效的 HTTP(S) 位址';

  @override
  String get connectServerRequired => '請輸入伺服器位址';

  @override
  String get connectShowKey => '顯示金鑰';

  @override
  String get connectShowPassphrase => '顯示密語';

  @override
  String get connectShowPassword => '顯示密碼';

  @override
  String get connectShowPrivateKey => '顯示私鑰';

  @override
  String get connectShowValue => '顯示';

  @override
  String get connectSignIn => '登入';

  @override
  String get connectSignInAgain => '重新登入';

  @override
  String get connectSshCredentialRequired => '請輸入私鑰或密碼';

  @override
  String get connectSshHost => 'SSH 主機';

  @override
  String get connectSshHostRequired => '請輸入 SSH 主機';

  @override
  String get connectSshPassword => 'SSH 密碼（選填）';

  @override
  String get connectSshUser => 'SSH 使用者';

  @override
  String get connectSshUserRequired => '請輸入 SSH 使用者';

  @override
  String get connectTitle => '連線';

  @override
  String get connectUnableServer => '無法連線至伺服器';

  @override
  String get connectValidationFailed => '連線驗證失敗，請檢查伺服器位址和 API 金鑰';

  @override
  String get connectValidationNetworkFailed => '連線驗證失敗，請檢查伺服器位址、API 金鑰和網路';

  @override
  String dateMonthDay(int month, int day) {
    return '$month 月 $day 日';
  }

  @override
  String get dateToday => '今天';

  @override
  String get dateYesterday => '昨天';

  @override
  String get discordCommunityTitle => '加入 Discord 社群';

  @override
  String get featureAbout => '關於';

  @override
  String get featureAboutDesc => '版本資訊';

  @override
  String get featureAgent => 'Agent';

  @override
  String get featureAgentDesc => '執行狀態與後端資訊';

  @override
  String get featureArtifacts => 'Artifacts';

  @override
  String get featureArtifactsDesc => '對話產出物';

  @override
  String get featureBilling => '帳務';

  @override
  String get featureBillingDesc => '用量、方案與發票';

  @override
  String get featureCommandCenter => '命令中心';

  @override
  String get featureCommandCenterDesc => '即時狀態與日誌';

  @override
  String get featureConnection => '連線';

  @override
  String get featureConnectionDesc => '多後端設定檔';

  @override
  String get featureCredentials => '憑證';

  @override
  String get featureCredentialsDesc => '第三方帳號與金鑰';

  @override
  String get featureCron => '排程任務';

  @override
  String get featureCronDesc => 'Cron 自動化';

  @override
  String get featureFiles => '檔案';

  @override
  String get featureFilesDesc => '瀏覽工作目錄';

  @override
  String get featureGit => 'Git';

  @override
  String get featureGitDesc => '變更、提交與分支';

  @override
  String get featureGlobalSearchDesc => '搜尋命令、對話與頁面';

  @override
  String get featureInsights => '洞察分析';

  @override
  String get featureInsightsDesc => '用量與成本趨勢';

  @override
  String get featureMcp => 'MCP';

  @override
  String get featureMcpDesc => 'MCP 伺服器設定';

  @override
  String get featureMemory => '記憶';

  @override
  String get featureMemoryDesc => '長期記憶管理';

  @override
  String get featureMessaging => '訊息平台';

  @override
  String get featureMessagingDesc => 'Telegram、Discord 與其他平台';

  @override
  String get featureNotificationsDesc => '通知中心';

  @override
  String get featurePet => '寵物';

  @override
  String get featurePetDesc => '夥伴與收藏';

  @override
  String get featurePlugins => '外掛';

  @override
  String get featurePluginsDesc => '外掛管理';

  @override
  String get featureProfiles => 'Profiles';

  @override
  String get featureProfilesDesc => '模型執行設定檔';

  @override
  String get featureProjects => '專案';

  @override
  String get featureProjectsDesc => '多專案對話分組';

  @override
  String get featureSettings => '設定';

  @override
  String get featureSettingsDesc => '外觀與偏好';

  @override
  String get featureSkills => '技能';

  @override
  String get featureSkillsDesc => '技能中心';

  @override
  String get featureStarmap => '知識星圖';

  @override
  String get featureStarmapDesc => '關鍵字知識圖譜';

  @override
  String get featureSubagents => '子代理';

  @override
  String get featureSubagentsDesc => '背景代理活動';

  @override
  String get featureTerminal => '終端機';

  @override
  String get featureTerminalDesc => '命令列互動';

  @override
  String get featureTools => '工具集';

  @override
  String get featureToolsDesc => '工具與金鑰';

  @override
  String get featureWebhooks => 'Webhooks';

  @override
  String get featureWebhooksDesc => '事件傳送';

  @override
  String gitAgentShipFailed(Object error) {
    return 'Agent Ship 失敗：$error';
  }

  @override
  String get gitAgentShipPrompt => '檢查目前變更，使用清楚的約定式提交訊息提交，推送分支，並開啟拉取請求。';

  @override
  String get gitAgentShipQuestion => '讓 Agent 提交並推送變更，然後建立 PR？';

  @override
  String get gitAgentShipSent => '已將提交並建立 PR 的任務傳送給 Hermes';

  @override
  String get gitAuthor => '作者';

  @override
  String gitAuthorMeta(Object author) {
    return '作者：$author';
  }

  @override
  String get gitBaseBranch => '基礎分支';

  @override
  String gitBranchMeta(Object branch) {
    return '分支：$branch';
  }

  @override
  String get gitBranchesTab => '分支';

  @override
  String get gitChangeDirectory => '變更目錄';

  @override
  String get gitChangedFiles => '變更檔案';

  @override
  String get gitChangedFilesLabel => '變更檔案：';

  @override
  String get gitChangesTab => '變更';

  @override
  String get gitCommit => '提交';

  @override
  String get gitCommitChanges => '提交變更';

  @override
  String get gitCommitDetails => '提交詳情';

  @override
  String gitCommitFailed(Object error) {
    return '提交失敗：$error';
  }

  @override
  String get gitCommitMessage => '提交訊息';

  @override
  String get gitCommitsTab => '提交';

  @override
  String get gitCreatePr => '建立 PR';

  @override
  String gitCreatePrFailed(Object error) {
    return '建立 PR 失敗：$error';
  }

  @override
  String get gitCreatePrQuestion => '要使用目前分支透過 GitHub CLI 建立或開啟拉取請求嗎？';

  @override
  String gitCreateWorktreeFailed(Object error) {
    return '建立 worktree 失敗：$error';
  }

  @override
  String get gitCurrent => '目前';

  @override
  String gitDeleteWorktreeDescription(Object path) {
    return '將刪除工作目錄 $path 及其未提交的變更。此操作無法復原。';
  }

  @override
  String gitDeleteWorktreeFailed(Object error) {
    return '刪除 worktree 失敗：$error';
  }

  @override
  String get gitDeleteWorktreeQuestion => '刪除 worktree？';

  @override
  String get gitDetachedHead => '（游離 HEAD）';

  @override
  String gitDiffLoadFailed(Object error) {
    return '載入 diff 失敗：$error';
  }

  @override
  String get gitEndOfLog => '— 已到底 —';

  @override
  String get gitForceDelete => '強制刪除';

  @override
  String get gitForceDeleteWorktreeQuestion => '要強制刪除並捨棄這些變更嗎？';

  @override
  String get gitGenerateCommitMessage => '產生提交訊息';

  @override
  String gitGenerateMessageFailed(Object error) {
    return '產生提交訊息失敗：$error';
  }

  @override
  String get gitGithubCliUnavailable => '後端尚未安裝 GitHub CLI，或尚未完成登入';

  @override
  String gitHoursAgo(Object count) {
    return '$count 小時前';
  }

  @override
  String get gitJustNow => '剛剛';

  @override
  String gitLoadMore(Object loaded, Object total) {
    return '載入更多 ($loaded/$total)';
  }

  @override
  String get gitLoadingBranches => '正在載入分支…';

  @override
  String get gitLoadingLog => '正在載入提交記錄…';

  @override
  String get gitLoadingStatus => '正在讀取儲存庫狀態…';

  @override
  String get gitLocalBranches => '本機分支';

  @override
  String gitLogLoadFailed(Object error) {
    return '載入提交記錄失敗：$error';
  }

  @override
  String get gitMainWorktree => '主要';

  @override
  String gitMinutesAgo(Object count) {
    return '$count 分鐘前';
  }

  @override
  String get gitNewWorktree => '新增 Worktree';

  @override
  String get gitNoAdditionalWorktrees => '沒有其他 worktree';

  @override
  String get gitNoBranches => '沒有可用分支';

  @override
  String get gitNoBranchesDescription => '請選擇 Git 儲存庫後重試。';

  @override
  String get gitNoCommits => '沒有提交記錄';

  @override
  String get gitNoCommitsDescription => '此儲存庫尚無提交，或目前篩選條件沒有相符項目';

  @override
  String get gitNoDiff => '沒有差異';

  @override
  String get gitNoDiffDescription => '此檔案與 HEAD 沒有差異';

  @override
  String get gitNoMatchingBranches => '沒有相符的分支';

  @override
  String get gitNoStashes => '沒有貯藏記錄';

  @override
  String get gitNoVisibleRemotes => '沒有可見的遠端儲存庫';

  @override
  String get gitNotRepository => '不是 Git 儲存庫';

  @override
  String gitNotRepositoryDescription(Object path) {
    return '$path\n\n點選下方按鈕以變更目錄';
  }

  @override
  String get gitOpenInNewSession => '在新工作階段中開啟';

  @override
  String gitOpenPr(Object number) {
    return '開啟 PR #$number';
  }

  @override
  String gitOpenedInNewSession(Object path) {
    return '已在新工作階段中開啟 $path';
  }

  @override
  String get gitParent => '父提交';

  @override
  String get gitPrCreated => 'PR 已建立';

  @override
  String gitPrNumber(Object number) {
    return '編號：#$number';
  }

  @override
  String get gitPushAfterCommit => '提交後推送';

  @override
  String gitPushAction(Object count) {
    return '推送 $count 個提交';
  }

  @override
  String get gitPushSucceeded => '已推送到遠端';

  @override
  String gitPushFailed(Object error) {
    return '推送失敗：$error';
  }

  @override
  String get gitRecentRepositories => '最近的儲存庫';

  @override
  String get gitRemotes => '遠端儲存庫';

  @override
  String get gitRemotesAndStashes => '遠端與貯藏';

  @override
  String get gitRepositoryDirectory => '儲存庫目錄';

  @override
  String get gitRevert => '還原';

  @override
  String get gitRevertAll => '全部還原';

  @override
  String get gitRevertAllDescription => '將捨棄工作區中的所有未提交變更，此操作無法復原。';

  @override
  String get gitRevertAllQuestion => '還原所有變更？';

  @override
  String gitRevertFailed(Object error) {
    return '還原失敗：$error';
  }

  @override
  String get gitRevertFile => '還原此檔案';

  @override
  String gitRevertFileDescription(Object file) {
    return '將捨棄「$file」的未提交變更，此操作無法復原。';
  }

  @override
  String get gitRevertFileQuestion => '還原此檔案？';

  @override
  String get gitSearchBranches => '搜尋分支…';

  @override
  String get gitSearchCommits => '搜尋提交訊息';

  @override
  String get gitSelectFileForDiff => '選擇檔案以查看 Diff';

  @override
  String get gitSelectFileForDiffDescription => '點選左側的變更檔案以在此查看差異';

  @override
  String get gitServerRepositoryPath => '伺服器儲存庫路徑';

  @override
  String get gitStage => '暫存';

  @override
  String gitStageFailed(Object error) {
    return '暫存操作失敗：$error';
  }

  @override
  String gitStagedChanges(Object added, Object removed) {
    return '已暫存 · +$added −$removed';
  }

  @override
  String get gitStashes => '貯藏';

  @override
  String get gitSwitch => '切換';

  @override
  String get gitSwitchBranch => '切換分支';

  @override
  String gitSwitchBranchFailed(Object error) {
    return '切換分支失敗：$error';
  }

  @override
  String get gitUnknownAuthor => '未知';

  @override
  String get gitUnstage => '取消暫存';

  @override
  String get gitWorkingTreeClean => '工作區乾淨，沒有變更';

  @override
  String get gitWorktreeHasChanges => 'worktree 中有未提交的變更';

  @override
  String get gitWorktreeNameHint => '例如 feature-login';

  @override
  String get gitWorktrees => '工作區 (Worktree)';

  @override
  String get globalSearch => '全域搜尋';

  @override
  String get groupConfiguration => '設定';

  @override
  String get groupIntegrations => '整合';

  @override
  String get groupIntelligence => '智慧';

  @override
  String get groupSystem => '系統';

  @override
  String get groupWorkspace => '工作區';

  @override
  String get helpAndFeedbackTitle => '說明與意見回饋';

  @override
  String get homeAllFeatures => '全部功能';

  @override
  String get homeAttentionDetail => '代理可能正在等待你的確認';

  @override
  String homeBackendSummary(String model, String profile) {
    return '後端已連線 · $model · Profile: $profile';
  }

  @override
  String homeContinueSession(String title) {
    return '繼續「$title」';
  }

  @override
  String get homeContinueWork => '繼續你的工作';

  @override
  String get homeCurrentWork => '目前工作';

  @override
  String get homeDefaultProfile => '預設';

  @override
  String get homeDragToReorder => '拖曳排序';

  @override
  String get homeEditQuickTools => '編輯常用工具';

  @override
  String get homeLastVisibleTool => '首頁顯示區最後一項';

  @override
  String get homeLoadingRecent => '載入最近工作…';

  @override
  String get homeMoreTools => '更多工具';

  @override
  String homeNeedsAttention(int count) {
    return '$count 項需要處理';
  }

  @override
  String get homeNoWorkDescription => '在上方描述目標，開始第一項工作';

  @override
  String get homeNoWorkTitle => '尚無工作記錄';

  @override
  String homeProfileTooltip(String profile) {
    return '設定檔：$profile';
  }

  @override
  String get homeQuickTools => '常用工具';

  @override
  String get homeQuickToolsDescription => '前 5 項會直接顯示在首頁，其餘工具收納在「更多」中。';

  @override
  String get homeReadyTitle => 'Hermes 已就緒';

  @override
  String get homeRecentSessions => '最近對話';

  @override
  String get homeRestoreDefaults => '恢復預設';

  @override
  String get homeStartNewSession => '開始新對話';

  @override
  String get homeSwitchProfile => '切換設定檔';

  @override
  String get homeToolKnowledge => '知識';

  @override
  String get homeViewAttentionSessions => '查看待處理對話';

  @override
  String get homeViewSession => '查看對話';

  @override
  String homeWorkingDetail(String model) {
    return '正在處理目前任務 · $model';
  }

  @override
  String get homeWorkingTitle => 'Hermes 正在工作';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageDescription => '選擇 Hermes Mobile 的介面語言';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageSimplifiedChinese => '简体中文';

  @override
  String get languageSystem => '跟隨系統';

  @override
  String get languageTitle => '語言';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get legalPrivacy => '隱私權政策';

  @override
  String get legalTerms => '服務條款';

  @override
  String get legalTitle => '法律與授權';

  @override
  String get modelAllFollowMain => '全部跟隨主模型';

  @override
  String get modelApply => '套用';

  @override
  String modelAuxiliarySaveFailed(String error) {
    return '儲存輔助模型失敗：$error';
  }

  @override
  String get modelAuxiliaryTitle => '輔助模型';

  @override
  String get modelAuxiliaryUnavailable => '目前 Hermes 後端未提供輔助模型設定介面。';

  @override
  String get modelChoose => '選擇模型';

  @override
  String get modelConfirmSelection => '確認模型選擇';

  @override
  String get modelCreate => '建立';

  @override
  String get modelCurrent => '使用中';

  @override
  String get modelDefaultTitle => '預設模型';

  @override
  String get modelExpensiveWarning => '此模型可能產生較高費用，是否繼續？';

  @override
  String get modelFallbackHint => 'fallback_providers（每行一個 provider:model）';

  @override
  String get modelFallbackTitle => '備援模型';

  @override
  String get modelFollowMain => '跟隨主模型';

  @override
  String get modelLabel => '模型';

  @override
  String get modelMoaAddReference => '新增參考模型';

  @override
  String get modelMoaAggregator => '聚合器';

  @override
  String get modelMoaAggregatorMaxTokens => '聚合輸出上限';

  @override
  String get modelMoaAggregatorModel => '聚合模型';

  @override
  String modelMoaAggregatorSummary(String provider, String model) {
    return '聚合器：$provider · $model';
  }

  @override
  String get modelMoaAggregatorTemperature => '聚合溫度';

  @override
  String get modelMoaCompleteModels => '請補全所有模型';

  @override
  String get modelMoaCreatePreset => '新增 MoA preset';

  @override
  String get modelMoaCreateTooltip => '新增 preset';

  @override
  String get modelMoaDefaultPreset => '預設 preset';

  @override
  String get modelMoaDegradedLoud => '提示降級';

  @override
  String get modelMoaDegradedPolicy => '降級策略';

  @override
  String get modelMoaDegradedSilent => '靜默降級';

  @override
  String get modelMoaDeleteTooltip => '刪除 preset';

  @override
  String get modelMoaDescription => '參考模型平行回答，由聚合器產生最終結果';

  @override
  String get modelMoaEditConfiguration => '編輯設定';

  @override
  String modelMoaEditTitle(String name) {
    return '編輯 $name';
  }

  @override
  String get modelMoaEnablePreset => '啟用 preset';

  @override
  String get modelMoaFanoutCadence => 'Fanout cadence';

  @override
  String get modelMoaFanoutHint => 'user_turn / per_iteration / every_n:2';

  @override
  String get modelMoaNoEditable => '沒有可編輯的 MoA preset。';

  @override
  String get modelMoaPresetLabel => 'Preset';

  @override
  String modelMoaReferenceCount(int count) {
    return '$count 個參考模型';
  }

  @override
  String get modelMoaReferenceMaxTokens => '參考輸出上限';

  @override
  String get modelMoaReferenceModels => '參考模型';

  @override
  String modelMoaReferenceNumber(int index) {
    return '參考 $index';
  }

  @override
  String get modelMoaReferenceTemperature => '參考溫度';

  @override
  String get modelMoaReferenceTimeout => '參考逾時（秒）';

  @override
  String get modelMoaRuntimeParameters => '執行參數';

  @override
  String get modelMoaSaveConfiguration => '儲存設定';

  @override
  String modelMoaSaveFailed(String error) {
    return '儲存 MoA 失敗：$error';
  }

  @override
  String get modelMoaSetDefault => '設為預設';

  @override
  String get modelMoaUnavailable => '目前 Hermes 後端未提供 MoA 設定介面。';

  @override
  String get modelNoAvailable => '沒有可用模型';

  @override
  String get modelPresetName => '名稱';

  @override
  String get modelProvider => '供應商';

  @override
  String get modelProviderNotFound => '找不到模型對應的供應商';

  @override
  String modelRecommended(String model) {
    return '推薦：$model';
  }

  @override
  String get modelRemove => '移除';

  @override
  String get modelSwitchDeferred => '模型切換已排程，將在目前回合完成後生效';

  @override
  String modelSwitchFailed(String error) {
    return '切換模型失敗：$error';
  }

  @override
  String modelSwitchSucceeded(String model) {
    return '已切換至 $model';
  }

  @override
  String get moreCloseSearch => '關閉目錄搜尋';

  @override
  String get moreNoMatches => '沒有符合的功能';

  @override
  String get moreSearchDirectory => '搜尋目錄';

  @override
  String get moreSearchHint => '搜尋功能';

  @override
  String moreStatus(String connection, String agent) {
    return '$connection · Agent $agent';
  }

  @override
  String get navHome => '首頁';

  @override
  String get navMore => '更多';

  @override
  String get navSessions => '對話';

  @override
  String get navTasks => '任務';

  @override
  String get notificationClear => '清除';

  @override
  String get notificationClearConfirmTitle => '清除所有通知？';

  @override
  String get notificationClearConfirmBody => '此操作會移除清單中的所有通知，且無法復原。';

  @override
  String get notificationEmptyDescription => 'Agent 完成、核准與異常事件會顯示在這裡';

  @override
  String get notificationEmptyTitle => '暫無通知';

  @override
  String get notificationMarkAllRead => '全部已讀';

  @override
  String notificationOpenFailed(String error) {
    return '無法開啟對話: $error';
  }

  @override
  String get notificationOpenSession => '查看對話';

  @override
  String get notificationTitle => '通知';

  @override
  String get paletteHint => '搜尋頁面、工作階段與命令…';

  @override
  String get paletteHintClose => '關閉';

  @override
  String get paletteHintNavigate => '選擇';

  @override
  String get paletteHintOpen => '開啟';

  @override
  String get paletteKanban => '看板';

  @override
  String get paletteKindAction => '操作';

  @override
  String get paletteKindCommand => '命令';

  @override
  String get paletteKindPage => '頁面';

  @override
  String get paletteKindSession => '工作階段';

  @override
  String get paletteNewSessionDesc => '開始新的對話';

  @override
  String get paletteNoResults => '沒有相符結果';

  @override
  String get paletteReconnect => '重新連線';

  @override
  String get paletteReconnectDesc => '重新連線至伺服器';

  @override
  String get paletteVoiceInput => '語音輸入';

  @override
  String get paletteVoiceInputDesc => '開始語音聽寫';

  @override
  String pluginActionFailed(String title, String error) {
    return '$title 執行失敗：$error';
  }

  @override
  String get pluginFieldInvalidNumber => '請輸入有效數字';

  @override
  String pluginFieldMaximum(num value) {
    return '最大值：$value';
  }

  @override
  String pluginFieldMinimum(num value) {
    return '最小值：$value';
  }

  @override
  String get pluginFieldRequired => '此欄位為必填';

  @override
  String pluginItemFallback(int index) {
    return '項目 $index';
  }

  @override
  String get pluginNoItems => '暫無項目';

  @override
  String get pluginResultCopied => '結果已複製';

  @override
  String get pluginResultCopy => '複製結果';

  @override
  String get pluginResultOpenLink => '開啟連結';

  @override
  String get pluginSubmit => '提交';

  @override
  String previewActionSendFailed(String error) {
    return '預覽操作傳送失敗：$error';
  }

  @override
  String previewActionSent(String prompt) {
    return '已傳送預覽操作：$prompt';
  }

  @override
  String get previewBack => '上一頁';

  @override
  String get previewClearConsole => '清除主控台';

  @override
  String get previewCloseConsole => '關閉主控台';

  @override
  String get previewConsoleTitle => 'Console';

  @override
  String get previewEmpty => '在對話中開啟連結，或選擇 HTML 檔案';

  @override
  String previewFailed(String error) {
    return '預覽失敗：$error';
  }

  @override
  String get previewForward => '下一頁';

  @override
  String get previewNoLogs => '暫無記錄';

  @override
  String get previewOpenBrowser => '在瀏覽器中開啟';

  @override
  String get previewOpenConsole => '開啟主控台';

  @override
  String previewOpenSessionFailed(String error) {
    return '無法開啟對話：$error';
  }

  @override
  String get previewRefresh => '重新整理預覽';

  @override
  String get previewRunJavascript => '執行 JavaScript';

  @override
  String get previewRunScript => '執行指令碼';

  @override
  String get previewTitle => '預覽';

  @override
  String get previewUnsupportedWebView => '目前平台不支援內嵌 WebView，請使用瀏覽器開啟';

  @override
  String get projectBrowseFiles => '瀏覽專案目錄';

  @override
  String get projectDetailTitle => '專案詳情';

  @override
  String projectFolderCount(int count) {
    return '$count 個資料夾';
  }

  @override
  String get projectGitDescription => '查看儲存庫狀態與變更';

  @override
  String get projectGlobalMemoryDescription => 'Profile 記憶（全域檢視）';

  @override
  String get projectGlobalStarmapDescription => '知識圖譜（全域檢視）';

  @override
  String get projectGlobalSubagentsDescription => '所有工作階段的子代理活動';

  @override
  String get projectGlobalWebhooksDescription => 'Webhook 設定（全域檢視）';

  @override
  String get projectLoadingSessions => '正在載入工作階段…';

  @override
  String get projectModulesTitle => '模組';

  @override
  String get projectNoKanbanBoard => '此專案沒有連結的看板';

  @override
  String get projectNoSessions => '沒有相關工作階段';

  @override
  String get projectNoSessionsDescription => '在專案目錄下開始的工作階段會顯示在這裡';

  @override
  String projectResumeFailed(String error) {
    return '恢復工作階段失敗：$error';
  }

  @override
  String projectSessionCount(int count) {
    return '$count 個工作階段';
  }

  @override
  String get projectSessionsTitle => '工作階段';

  @override
  String get projectTasksDescription => '開啟連結到此專案的看板';

  @override
  String get projectTasksTitle => '任務與看板';

  @override
  String get projectUnavailable => '不可用';

  @override
  String get projectUntitled => '未命名專案';

  @override
  String get providerActiveDefault => '作用中 / 預設';

  @override
  String get providerAddEndpointTitle => '新增自訂端點';

  @override
  String get providerCustomEndpointJson => '自訂 endpoint JSON';

  @override
  String get providerCustomEndpointsSection => '自訂 Endpoints';

  @override
  String get providerDeviceAuthorization => '裝置授權';

  @override
  String get providerEditEndpointTitle => '編輯自訂端點';

  @override
  String get providerEndpointApiKey => 'API Key';

  @override
  String get providerEndpointBaseUrl => 'Base URL';

  @override
  String get providerEndpointDefaultModel => '預設模型';

  @override
  String get providerEndpointDiscoverModels => '自動偵測模型';

  @override
  String get providerEndpointFallback => 'Endpoint';

  @override
  String get providerEndpointModelsList => '可用模型（每行一個）';

  @override
  String get providerEndpointName => '名稱';

  @override
  String get providerEndpointNameRequired => '請輸入名稱';

  @override
  String get providerEndpointUrlRequired => '請輸入 Base URL';

  @override
  String providerEnterDeviceCode(String code) {
    return '在瀏覽器中輸入驗證碼：$code';
  }

  @override
  String providerActionFailed(String error) {
    return '操作失敗：$error';
  }

  @override
  String get providerEnvironmentSection => '環境變數';

  @override
  String get providerEnvironmentVariableName => '環境變數名稱';

  @override
  String get providerEnvironmentVariableValue => '環境變數值';

  @override
  String providerMissingKeys(String keys) {
    return '缺少：$keys';
  }

  @override
  String providerModelTitle(String provider) {
    return '$provider 模型';
  }

  @override
  String get providerNoConfiguration => '尚無設定';

  @override
  String get providerNotSet => '未設定';

  @override
  String get providerOauthSection => 'Provider OAuth';

  @override
  String get providerPasteOauthCode => '貼上 OAuth code';

  @override
  String get providerProfileLabel => 'Profile';

  @override
  String providerRevealFailed(String error) {
    return '讀取失敗：$error';
  }

  @override
  String get providerRevealValue => '查看明文';

  @override
  String get providerRevealedValueTitle => '已儲存的值';

  @override
  String providerRunSetupDescription(String provider, String command) {
    return '$provider 需要執行：$command';
  }

  @override
  String get providerRunSetupQuestion => '要執行 Provider 安裝步驟嗎？';

  @override
  String get providerSetActive => '設為目前使用';

  @override
  String providerSetEnvironmentVariable(String key) {
    return '設定 $key';
  }

  @override
  String providerToolsCount(int count) {
    return '$count 個工具';
  }

  @override
  String providerToolsetProviderTitle(String toolset) {
    return '$toolset Provider';
  }

  @override
  String get providerToolsetProvidersSection => 'Toolset Providers';

  @override
  String get pushEnabled => '遠端通知';

  @override
  String get pushEnabledDescription => '向目前 Hermes 伺服器註冊此裝置';

  @override
  String get pushOsPermissionDenied => '系統通知已被封鎖';

  @override
  String get pushOsPermissionDeniedDescription =>
      'Hermes 內已開啟遠端通知，但作業系統層級封鎖了通知權限，通知實際上無法送達。請在裝置的系統設定中為 Hermes Mobile 開啟通知權限。';

  @override
  String get pushNoProviders => '伺服器尚未設定 APNs 或 FCM 憑證';

  @override
  String get pushNotRegistered => '尚未註冊';

  @override
  String get pushProviders => '傳送服務';

  @override
  String get pushRefresh => '重新整理推播狀態';

  @override
  String get pushRegistered => '已依目前連線與設定檔註冊';

  @override
  String get pushRegistration => '裝置註冊';

  @override
  String get pushSendTest => '傳送測試通知';

  @override
  String get pushSettingsDescription => 'Hermes Mobile 關閉後仍可接收工作完成與核准請求。';

  @override
  String get pushSettingsTitle => '遠端通知';

  @override
  String get pushTestDelivered => '測試通知已傳送';

  @override
  String pushTestFailed(String error) {
    return '無法傳送測試通知：$error';
  }

  @override
  String get pushTestNotDelivered => '沒有傳送服務成功送出測試通知';

  @override
  String get reportIssueTitle => '在 GitHub 回報問題';

  @override
  String get sendDiagnosticsSubtitle => '上傳已去識別化的紀錄以協助我們排查問題';

  @override
  String get sendDiagnosticsTitle => '傳送診斷資訊';

  @override
  String get sessionActions => '對話操作';

  @override
  String get sessionAllTags => '所有標籤';

  @override
  String get sessionArchiveView => '封存檢視';

  @override
  String get sessionArchiveViewDescription => '只顯示已封存的對話';

  @override
  String sessionBatchDeleteDescription(int count) {
    return '選取的 $count 個對話將被永久刪除，且無法復原。';
  }

  @override
  String get sessionBatchDeleteTitle => '刪除多個對話？';

  @override
  String get sessionCancelSelection => '取消選取';

  @override
  String get sessionClearAll => '全部清除';

  @override
  String get sessionClearFilters => '清除篩選';

  @override
  String get sessionClearSearch => '清除搜尋';

  @override
  String get sessionCollapseChildren => '收合子對話';

  @override
  String get sessionConfirmDelete => '永久刪除';

  @override
  String get sessionContinueLast => '繼續上次對話';

  @override
  String get sessionDeepSearchHint => '搜尋對話標題和訊息記錄';

  @override
  String get sessionDeepSearchTitle => '搜尋聊天記錄';

  @override
  String sessionDeleteDescription(String title) {
    return '「$title」將被永久刪除。';
  }

  @override
  String sessionDeleteFailed(String error) {
    return '刪除失敗：$error';
  }

  @override
  String get sessionDeleteSelected => '刪除選取項目';

  @override
  String get sessionDeleteTitle => '刪除對話？';

  @override
  String sessionDeletedCount(int count) {
    return '已刪除 $count 個對話';
  }

  @override
  String sessionDurationDaysHours(int days, int hours) {
    return '$days天$hours小時';
  }

  @override
  String sessionDurationHoursMinutes(int hours, int minutes) {
    return '$hours小時$minutes分鐘';
  }

  @override
  String sessionDurationMinutes(int minutes) {
    return '$minutes分鐘';
  }

  @override
  String get sessionEmptyDescription => '建立新對話以與 Hermes 交談';

  @override
  String get sessionEmptyTitle => '尚無對話';

  @override
  String get sessionExpandChildren => '展開子對話';

  @override
  String get sessionFilterAll => '全部';

  @override
  String get sessionFilterApproval => '需要核准';

  @override
  String get sessionFilterByTag => '依標籤篩選';

  @override
  String get sessionFilterCompleted => '已完成';

  @override
  String get sessionFilterTitle => '篩選對話';

  @override
  String get sessionGroupArchived => '已封存';

  @override
  String get sessionGroupByProject => '依專案分組';

  @override
  String get sessionGroupByTime => '依時間分組';

  @override
  String get sessionGroupLast7Days => '過去 7 天';

  @override
  String get sessionGroupOlder => '更早';

  @override
  String get sessionGroupPinned => '已釘選';

  @override
  String get sessionGroupRunning => '執行中';

  @override
  String sessionHandoff(String state) {
    return '交接 $state';
  }

  @override
  String get sessionHistoryArchive => '歷史封存';

  @override
  String get sessionLoadMore => '載入更多對話';

  @override
  String get sessionManage => '管理對話';

  @override
  String sessionMessageCount(int count) {
    return '$count 則訊息';
  }

  @override
  String get sessionNew => '新增對話';

  @override
  String get sessionNoMatchesDescription => '請調整搜尋或狀態篩選';

  @override
  String get sessionNoMatchesTitle => '沒有符合的對話';

  @override
  String get sessionNoProjectsDescription => '在 Git 儲存庫中開始的對話會自動歸入專案';

  @override
  String get sessionNoProjectsTitle => '沒有專案';

  @override
  String sessionOpenCopyFailed(String error) {
    return '無法開啟副本：$error';
  }

  @override
  String get sessionPrClosed => '已關閉';

  @override
  String get sessionPrDraft => '草稿';

  @override
  String get sessionPrMerged => '已合併';

  @override
  String get sessionPrNone => '無 PR';

  @override
  String get sessionPrOpen => '開放';

  @override
  String get sessionProjectBack => '返回專案列表';

  @override
  String get sessionProjectEnter => '進入';

  @override
  String get sessionProjectNoSessions => '此專案尚無對話';

  @override
  String sessionProjectSessionCount(int count) {
    return '$count 個對話';
  }

  @override
  String get sessionProjectUnavailable => '專案無法使用';

  @override
  String get sessionPullRequests => '拉取請求';

  @override
  String sessionResumeFailed(String error) {
    return '無法恢復對話：$error';
  }

  @override
  String sessionResumeLastFailed(String error) {
    return '無法恢復上次對話：$error';
  }

  @override
  String sessionResumeSubagentFailed(String error) {
    return '無法恢復子代理對話：$error';
  }

  @override
  String sessionSearchFailed(String error) {
    return '搜尋失敗：$error';
  }

  @override
  String get sessionSearchMessages => '搜尋訊息內容';

  @override
  String get sessionSearchNoFilteredResults => '沒有符合目前篩選條件的結果';

  @override
  String get sessionSearchPrompt => '輸入關鍵字以搜尋所有對話記錄';

  @override
  String sessionSearchResultCount(int total, int visible) {
    return '找到 $total 個對話，目前顯示 $visible 個';
  }

  @override
  String get sessionSearchTitleHint => '搜尋對話標題…';

  @override
  String get sessionSelectAll => '全選';

  @override
  String get sessionSelectDescription => '從列表開啟對話以繼續工作';

  @override
  String get sessionSelectMultiple => '多選';

  @override
  String get sessionSelectSessions => '選取對話';

  @override
  String get sessionSelectTitle => '選取對話';

  @override
  String sessionSelectedCount(int count) {
    return '已選取 $count 項';
  }

  @override
  String get sessionServerNotConnected => '伺服器未連線';

  @override
  String get sessionSortActivity => '最近活躍';

  @override
  String get sessionSortCreated => '建立時間';

  @override
  String get sessionSortTitle => '排序方式';

  @override
  String get sessionSortTokens => 'Token 用量';

  @override
  String get sessionStatusAttention => '需要處理';

  @override
  String get sessionStatusIdle => '閒置';

  @override
  String get sessionStatusWorking => '執行中';

  @override
  String get sessionTimeAll => '所有時間';

  @override
  String get sessionTitle => '對話';

  @override
  String sessionToolCount(int count) {
    return '$count 個工具';
  }

  @override
  String get sessionUntitled => '未命名對話';

  @override
  String sessionWithinDays(int count) {
    return '$count 天內';
  }

  @override
  String get settingsAppearanceDesc => '顯示模式、主題色彩與高對比';

  @override
  String get settingsBackHome => '返回首頁';

  @override
  String get settingsBackendConfigSummary => '後端設定摘要';

  @override
  String get settingsBackendConfigSummaryDesc => '主要設定值';

  @override
  String get settingsBackendConnectionSection => '後端與連線';

  @override
  String settingsBackendRestartFailed(String error) {
    return '無法重新啟動後端：$error';
  }

  @override
  String get settingsBackendRestarted => '後端已重新啟動';

  @override
  String get settingsCapabilitiesDesc => 'MCP、知識庫、技能與外掛程式';

  @override
  String get settingsCapabilitiesTitle => '能力管理';

  @override
  String get settingsChangeConnection => '變更連線';

  @override
  String get settingsChangeConnectionDesc => '編輯伺服器位址和 API Key';

  @override
  String get settingsChangeConnectionQuestion => '要變更連線嗎？';

  @override
  String get settingsChangeConnectionWarning =>
      '將清除目前的伺服器連線，之後可重新輸入伺服器位址和 API Key。';

  @override
  String get settingsGroupModels => '模型與能力';

  @override
  String get settingsGroupPersonalization => '個人化';

  @override
  String get settingsModelDesc => '模型、對話、記憶內容與金鑰';

  @override
  String get settingsModelTitle => '模型與對話';

  @override
  String get settingsProvidersDesc => '環境變數、自訂端點、OAuth 與工具集提供者';

  @override
  String get settingsProvidersTitle => 'Providers 與執行環境';

  @override
  String get settingsRestartBackend => '重新啟動 Hermes 後端';

  @override
  String get settingsRestartBackendDesc => '中斷目前工作並重新啟動伺服器程序';

  @override
  String get settingsRestartBackendQuestion => '要重新啟動 Hermes 後端嗎？';

  @override
  String get settingsRestartBackendWarning => '伺服器上進行中的工作階段將被中斷。';

  @override
  String get settingsSystemConnectionDesc => '連線、安全性、終端機與後端';

  @override
  String get settingsSystemConnectionTitle => '系統與連線';

  @override
  String get settingsTerminalSection => '終端機';

  @override
  String get taskAll => '全部';

  @override
  String taskAssigneeFilter(String value) {
    return '負責人：$value';
  }

  @override
  String get taskAutoDecompose => '自動拆分任務';

  @override
  String get taskAutoGenerate => '自動產生';

  @override
  String get taskBoardView => '看板';

  @override
  String taskBulkFailed(int count) {
    return '$count 個任務更新失敗';
  }

  @override
  String get taskClearFilters => '清除篩選';

  @override
  String get taskCloseSearch => '關閉搜尋';

  @override
  String taskCommentCount(int count) {
    return '$count 則評論';
  }

  @override
  String get taskConnectBackend => '連接後端後查看任務';

  @override
  String get taskDefault => '預設';

  @override
  String get taskDefaultAssignee => '預設負責人';

  @override
  String get taskFilter => '篩選';

  @override
  String get taskListView => '列表';

  @override
  String get taskNew => '新增任務';

  @override
  String get taskNoDescription => '暫無描述';

  @override
  String get taskOptions => '任務選項';

  @override
  String get taskOrchestration => '編排設定';

  @override
  String get taskOrchestratorProfile => '編排 Profile';

  @override
  String get taskPriorityHigh => '高';

  @override
  String taskPriorityMeta(String priority) {
    return '優先級：$priority';
  }

  @override
  String get taskPriorityNormal => '普通';

  @override
  String get taskPriorityUrgent => '緊急';

  @override
  String taskProfileDescription(String name) {
    return '$name 的描述';
  }

  @override
  String get taskProfileDescriptions => 'Profile 描述';

  @override
  String get taskSearch => '搜尋任務';

  @override
  String taskSelectedCount(int count) {
    return '已選擇 $count 項';
  }

  @override
  String get taskShowArchived => '顯示已封存';

  @override
  String get taskStatusArchived => '已封存';

  @override
  String get taskStatusBlocked => '受阻';

  @override
  String get taskStatusDone => '完成';

  @override
  String get taskStatusReady => '就緒';

  @override
  String get taskStatusReview => '審核';

  @override
  String get taskStatusRunning => '進行中';

  @override
  String get taskStatusScheduled => '已排程';

  @override
  String get taskStatusTodo => '待辦';

  @override
  String get taskStatusTriage => '待分類';

  @override
  String get taskSwitchBoard => '切換看板';

  @override
  String taskTenantFilter(String value) {
    return '租戶：$value';
  }

  @override
  String get taskTitle => '任務';

  @override
  String get taskUnassigned => '未分配';

  @override
  String get taskWeeklyDelivery => '本週交付';

  @override
  String get terminalDefaultMonospace => '預設等寬字型';

  @override
  String get terminalFontHint => '留空以使用預設等寬字型';

  @override
  String get terminalFontPreview => '預覽  ~/project  git:main  >';

  @override
  String terminalFontSaveFailed(String error) {
    return '無法儲存終端機字型：$error';
  }

  @override
  String get terminalFontSaved => '終端機字型已儲存';

  @override
  String get terminalFontTitle => '終端機字型';

  @override
  String timeDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count 小時前';
  }

  @override
  String get timeJustNow => '剛剛';

  @override
  String timeMinutesAgo(int count) {
    return '$count 分鐘前';
  }

  @override
  String get updateAppVersion => '應用程式版本';

  @override
  String updateAvailableTitle(String version) {
    return '可更新至 $version';
  }

  @override
  String get updateCheck => '檢查更新';

  @override
  String get updateCheckDescription => '從行動版發布資訊清單檢查新版本';

  @override
  String get updateCheckFailed => '更新檢查失敗';

  @override
  String updateCheckUnavailable(String error) {
    return '暫時無法檢查：$error';
  }

  @override
  String get updateCurrent => '目前已是最新版本';

  @override
  String updateFound(String version) {
    return '發現版本 $version';
  }

  @override
  String get updateGoToUpdate => '前往更新';

  @override
  String updateMinimumVersion(String minimumVersion) {
    return '最低相容版本：$minimumVersion';
  }

  @override
  String get updateNewVersionPublished => '新版本已發布';

  @override
  String get updateReleaseNotes => '版本說明';

  @override
  String updateRequiredDefault(String currentVersion, String minimumVersion) {
    return '目前版本 $currentVersion 低於最低相容版本 $minimumVersion。請更新後繼續使用。';
  }

  @override
  String get updateRequiredTitle => '需要更新 Hermes Mobile';

  @override
  String get updateSectionTitle => '更新';

  @override
  String get updateUnsupportedTitle => '目前版本已不再受支援';

  @override
  String updateVersionBuild(String version, String build) {
    return 'v$version · build $build';
  }

  @override
  String get workspaceAddPaneTooltip => '開啟 Pane';

  @override
  String get workspaceApplyLayoutTooltip => '套用版面';

  @override
  String get workspaceCloseAllAction => '全部關閉';

  @override
  String get workspaceCloseAllDescription => '這只會關閉行動端工作區，不會刪除對話或外掛資料。';

  @override
  String get workspaceCloseAllQuestion => '關閉所有 Pane？';

  @override
  String get workspaceCloseAllTooltip => '關閉所有 Pane';

  @override
  String get workspaceEmptyDescription => '從對話選單或外掛 Pane 入口開啟內容';

  @override
  String get workspaceEmptyTitle => '工作區為空';

  @override
  String get workspaceLayoutDefault => '預設';

  @override
  String get workspaceLayoutFocus => '專注';

  @override
  String get workspaceLayoutQuad => '四宮格';

  @override
  String get workspaceLayoutTerminalDeck => '終端機面板';

  @override
  String get workspaceLayoutTooltip => '調整 Pane 版面';

  @override
  String get workspaceMergeTabs => '合併為分頁';

  @override
  String get workspaceMoveBottom => '移到下方';

  @override
  String get workspaceMoveLeft => '移到左側';

  @override
  String get workspaceMoveRight => '移到右側';

  @override
  String get workspaceMoveTop => '移到上方';

  @override
  String workspaceOpenPluginFailed(String error) {
    return '開啟外掛 Pane 失敗：$error';
  }

  @override
  String workspaceOpenSessionFailed(String error) {
    return '開啟工作區失敗：$error';
  }

  @override
  String get workspacePaneFiles => '檔案';

  @override
  String get workspacePaneLogs => '記錄';

  @override
  String get workspacePanePreview => '預覽';

  @override
  String get workspacePaneReview => '審查';

  @override
  String get workspacePaneTerminal => '終端機';

  @override
  String get workspacePluginUnavailable => '外掛 Pane 目前無法使用；請檢查外掛是否已啟用';

  @override
  String workspaceSessionResumeFailed(String error) {
    return '還原對話失敗：$error';
  }

  @override
  String get workspaceTitle => '工作區';

  @override
  String statusSemantics(String label) {
    return '狀態：$label';
  }

  @override
  String statusAgentSemantics(String label) {
    return '代理狀態：$label';
  }

  @override
  String statusToolSemantics(String label) {
    return '工具狀態：$label';
  }

  @override
  String get statusIdle => '閒置';

  @override
  String get statusThinking => '思考中';

  @override
  String get statusPlanning => '規劃中';

  @override
  String get statusRunning => '執行中';

  @override
  String get statusWaiting => '等待中';

  @override
  String get statusAwaitingApproval => '等待授權';

  @override
  String get statusPaused => '已暫停';

  @override
  String get statusCompleted => '已完成';

  @override
  String get statusFailed => '失敗';

  @override
  String get statusStopped => '已停止';

  @override
  String get statusCancelled => '已取消';

  @override
  String get composerUndoInput => '復原輸入';

  @override
  String get composerRedoInput => '重做輸入';

  @override
  String get composerReadOnly => '子代理工作階段為唯讀';

  @override
  String get composerMessageHint => '傳送訊息給 Hermes…';

  @override
  String composerProfileValue(String value) {
    return '設定檔：$value';
  }

  @override
  String get composerSelectProfile => '選擇設定檔';

  @override
  String composerWorkspaceValue(String value) {
    return '工作區：$value';
  }

  @override
  String get composerSelectWorkspace => '選擇工作區';

  @override
  String composerModelValue(String value) {
    return '模型：$value';
  }

  @override
  String get composerSelectModel => '選擇模型';

  @override
  String composerDifficultyValue(String value) {
    return '難度：$value';
  }

  @override
  String composerYoloModeValue(String value) {
    return 'Yolo 模式：$value';
  }

  @override
  String get composerEnabled => '已開啟';

  @override
  String get composerDisabled => '已關閉';

  @override
  String get composerConfigureToolsets => '設定工具集';

  @override
  String get composerCloseEmojiPanel => '關閉表情符號面板';

  @override
  String get composerEmoji => '表情符號';

  @override
  String get composerEditorActions => '編輯器動作';

  @override
  String get composerClearInput => '清除輸入';

  @override
  String get composerEnterSendsTooltip => 'Enter 傳送；Shift+Enter 換行';

  @override
  String get composerEnterNewlineTooltip => 'Enter 換行；點一下傳送以送出';

  @override
  String get composerEnterSends => 'Enter 傳送';

  @override
  String get composerEnterNewline => 'Enter 換行';

  @override
  String composerRemoveAttachment(String label) {
    return '移除附件：$label';
  }

  @override
  String get composerFolderNotUploaded => '本機資料夾參照 — 不會傳送到伺服器';

  @override
  String get composerCurrentDefault => '目前設定檔預設值';

  @override
  String get composerUsedDefaultTools => '已使用預設工具設定';

  @override
  String composerAppliedTools(int count) {
    return '已套用 $count 個工具';
  }

  @override
  String get composerSwitchedToDefault => '已切換至預設設定';

  @override
  String get composerToolConfiguration => '工具設定';

  @override
  String get composerToolConfigurationDescription =>
      '使用目前設定檔的預設工具，或為此工作階段選擇自訂工具集';

  @override
  String get composerUseCurrentDefault => '使用目前設定檔預設值';

  @override
  String get composerSelectCustomTools => '為目前工作階段選擇自訂工具';

  @override
  String get composerConfiguredMcpServers => '已設定的 MCP 伺服器';

  @override
  String get composerNoConfiguredMcpServers => '尚未設定 MCP 伺服器';

  @override
  String get composerUseDefault => '使用預設值';

  @override
  String get composerApply => '套用';

  @override
  String get commonRemove => '移除';

  @override
  String get onboardingChatTitle => '與 Hermes 對話';

  @override
  String get onboardingChatDescription => '發起對話、使用語音輸入、查看工具呼叫與思考過程，並隨時繼續先前的對話。';

  @override
  String get onboardingProjectsTitle => '專案與對話組織';

  @override
  String get onboardingProjectsDescription =>
      '依專案、Git 分支和 worktree 自動分組，並支援置頂、封存與狀態篩選。';

  @override
  String get onboardingTerminalTitle => '終端機與 Git';

  @override
  String get onboardingTerminalDescription =>
      '直接執行終端機命令、查看 diff、暫存提交並建立 Pull Request。';

  @override
  String get onboardingPaletteTitle => '命令面板';

  @override
  String get onboardingPaletteDescription =>
      '透過頂端搜尋或下拉手勢開啟命令面板，快速前往功能、最近對話或斜線命令。';

  @override
  String get onboardingPetTitle => '你的 AI 寵物';

  @override
  String get onboardingPetDescription => '一隻會隨任務狀態改變表情的 AI 寵物，還能產生專屬外觀。';

  @override
  String get onboardingSkip => '略過';

  @override
  String get onboardingStart => '開始使用';

  @override
  String get onboardingNext => '下一步';

  @override
  String get petGenerateInputRequired => '請輸入描述，或加入一張參考圖片';

  @override
  String get petGenerateEmptyResult => '產生結果為空';

  @override
  String petGenerateHatchFailed(Object error) {
    return '孵化失敗：$error';
  }

  @override
  String petGenerateAdoptFailed(Object error) {
    return '領養失敗：$error';
  }

  @override
  String get petGenerateTitle => '產生新寵物';

  @override
  String get petGenerateDescribe => '描述你想要的寵物';

  @override
  String get petGeneratePromptHint => '例如：一隻賽博龐克風格的機械貓';

  @override
  String get petGenerateAddReference => '加入參考圖片（選用）';

  @override
  String get petGenerateReferenceHelp => '每張草圖都會參考這張圖片';

  @override
  String get petGenerateModel => '產生模型';

  @override
  String get petGenerateAutoSelect => '自動選擇';

  @override
  String get petGenerateDraftsAction => '產生 4 張草圖';

  @override
  String petGenerateProgress(Object done, Object total) {
    return '正在產生草圖… ($done/$total)';
  }

  @override
  String get petGenerateChooseDraft => '選一張喜歡的草圖';

  @override
  String petGenerateDraftLabel(Object index) {
    return '草圖 $index';
  }

  @override
  String get petGenerateAgain => '重新產生';

  @override
  String get petGenerateHatch => '孵化';

  @override
  String get petGeneratePreparing => '準備中…';

  @override
  String petGenerateDrawingProgress(Object done, Object state, Object total) {
    return '繪製動畫影格 $state ($done/$total)';
  }

  @override
  String petGenerateDrawing(Object state) {
    return '繪製動畫影格 $state';
  }

  @override
  String get petGenerateComposing => '合成精靈圖…';

  @override
  String get petGenerateSaving => '儲存中…';

  @override
  String get petGenerateHatching => '孵化中…';

  @override
  String get petGenerateReady => '你的新寵物孵化好了！';

  @override
  String get petGenerateNameLabel => '幫它取個名字';

  @override
  String get petGenerateDiscard => '放棄';

  @override
  String get petGenerateAdopt => '領養';

  @override
  String get imageSave => '儲存圖片';

  @override
  String get imageCopyLink => '複製圖片連結';

  @override
  String get imageSavedToGallery => '已儲存至相簿';

  @override
  String get kanbanHomeChannels => 'Home channel 通知';

  @override
  String get kanbanHomeChannelsFailed => '無法載入 Home channel';

  @override
  String get kanbanHomeChannelsEmpty => '暫無可用的 Home channel';

  @override
  String kanbanUnsupportedAction(Object action) {
    return '目前版本不支援 $action 操作';
  }

  @override
  String chatSessionSaved(Object path) {
    return '對話記錄已儲存至 $path';
  }

  @override
  String get artifactSessionPendingTitle => '開始對話後查看工件';

  @override
  String get artifactSessionPendingDescription => '此對話儲存後，產生的工件會顯示在這裡。';

  @override
  String get artifactEmptyTitle => '暫無工件';

  @override
  String get artifactEmptyDescription => '對話中產生的程式碼、檔案、連結和圖片會顯示在這裡。';

  @override
  String artifactFallbackLabel(Object id) {
    return '工件 $id';
  }

  @override
  String get artifactDetailTitle => '工件詳情';

  @override
  String artifactSessionMeta(Object kind, Object session) {
    return '$kind · 對話 $session';
  }

  @override
  String get artifactMetadata => '中繼資料';

  @override
  String get artifactSaveAs => '另存新檔';

  @override
  String get artifactCopyContent => '複製內容';

  @override
  String artifactExportFailed(String error) {
    return '匯出失敗：$error';
  }

  @override
  String get artifactType => '類型';

  @override
  String get artifactSession => '對話';

  @override
  String get artifactSessionTitle => '對話標題';

  @override
  String get artifactMessageRow => '訊息列';

  @override
  String get logsAllServers => '全部伺服器';

  @override
  String get logsLoading => '讀取日誌…';

  @override
  String get webhookEnableFirst => '請先啟用 Webhook 平台';

  @override
  String get webhookEnabledRestart => 'Webhook 已啟用，請重新啟動 Hermes 閘道以套用變更';

  @override
  String get webhookEnabled => 'Webhook 已啟用';

  @override
  String webhookEnableFailed(Object error) {
    return '啟用 Webhook 失敗：$error';
  }

  @override
  String get webhookLoading => '讀取 Webhooks…';

  @override
  String get webhookEmptyTitle => '沒有 Webhook';

  @override
  String get webhookEmptyDescription => '點擊 + 建立 Webhook 以接收 Hermes 事件。';

  @override
  String get webhookPlatformDisabled => 'Webhook 平台尚未啟用 · 點擊啟用';

  @override
  String get webhookConfigured => '已設定 Webhook';

  @override
  String get webhookStopped => 'Webhook 已停用';

  @override
  String webhookOperationFailed(Object error) {
    return 'Webhook 操作失敗：$error';
  }

  @override
  String get webhookDeleteTitle => '刪除 Webhook？';

  @override
  String webhookDeletePrompt(Object name) {
    return '$name 將被刪除。';
  }

  @override
  String get webhookDeleted => 'Webhook 已刪除';

  @override
  String webhookDeleteFailed(Object error) {
    return '刪除 Webhook 失敗：$error';
  }

  @override
  String get webhookEnabledLabel => '啟用';

  @override
  String get webhookDisabledLabel => '停用';

  @override
  String get webhookEvents => '訂閱事件';

  @override
  String get webhookDescription => '描述';

  @override
  String get webhookPrompt => '提示詞';

  @override
  String get webhookSkills => '技能';

  @override
  String get webhookDeliverTo => '投遞目標';

  @override
  String get webhookEnableThis => '啟用此 Webhook';

  @override
  String get webhookHotReloadDescription => '變更會由 Hermes 閘道即時載入。';

  @override
  String get webhookNameRequired => '請填寫名稱';

  @override
  String get webhookCreated => 'Webhook 已建立';

  @override
  String get webhookSecretOnce => '簽署密鑰只會完整顯示一次，請立即儲存。';

  @override
  String get webhookSecretSaved => '我已儲存';

  @override
  String webhookSaveFailed(Object error) {
    return '儲存 Webhook 失敗：$error';
  }

  @override
  String get webhookNew => '新增 Webhook';

  @override
  String get webhookName => '名稱';

  @override
  String get webhookDescriptionOptional => '描述（選填）';

  @override
  String get webhookEventsComma => '訂閱事件（逗號分隔）';

  @override
  String get webhookPromptOptional => '觸發提示詞（選填）';

  @override
  String get webhookSkillsComma => 'Skills（逗號分隔，選填）';

  @override
  String get webhookDeliveryTarget => '傳送目標';

  @override
  String get webhookLogOnly => '僅記錄日誌';

  @override
  String get webhookSaving => '儲存中…';

  @override
  String commonPartialDataLoadFailed(Object details) {
    return '部分資料載入失敗：$details';
  }

  @override
  String cronRunsLoadFailed(Object error) {
    return '載入執行記錄失敗：$error';
  }

  @override
  String profilesOptionsLoadFailed(Object details) {
    return '部分 Profile 編輯選項載入失敗：$details';
  }

  @override
  String skillsBulkFailed(Object failed, Object total) {
    return '$total 個技能中有 $failed 個更新失敗。';
  }

  @override
  String petCleanupFailed(Object error) {
    return '清理生成任務失敗：$error';
  }

  @override
  String get skillsTitle => '技能';

  @override
  String get skillsMarketplace => '技能市集';

  @override
  String get skillsEnableAll => '全部啟用';

  @override
  String get skillsDisableAll => '全部停用';

  @override
  String skillsToggleFailed(Object error) {
    return '切換失敗：$error';
  }

  @override
  String get skillsSearchHint => '搜尋技能…';

  @override
  String skillsEnabledCount(Object enabled, Object total) {
    return '啟用 $enabled/$total';
  }

  @override
  String get skillsLoading => '載入技能…';

  @override
  String get skillsEmptyTitle => '沒有技能';

  @override
  String get skillsEmptyDescription => '目前 Agent 沒有可用技能';

  @override
  String get skillsUncategorized => '未分類';

  @override
  String get skillsNoMatches => '沒有符合的技能';

  @override
  String skillsUsageCount(Object count) {
    return '使用 $count 次';
  }

  @override
  String get skillsLearned => '已學習';

  @override
  String get skillsBuiltIn => '內建';

  @override
  String get skillsProvenanceMarketplace => '市場';

  @override
  String get skillsSaved => '已儲存';

  @override
  String skillsSaveFailed(Object error) {
    return '儲存失敗：$error';
  }

  @override
  String get skillsArchiveQuestion => '封存技能？';

  @override
  String skillsArchivePrompt(Object name) {
    return '將封存已學習的技能「$name」。此操作可復原。';
  }

  @override
  String get skillsArchive => '封存';

  @override
  String get skillsArchived => '已封存';

  @override
  String skillsArchiveFailed(Object error) {
    return '封存失敗：$error';
  }

  @override
  String get skillsContent => '內容';

  @override
  String get skillsNoContent => '（無內容）';

  @override
  String get skillsCancelEdit => '取消編輯';

  @override
  String get skillsSaving => '儲存中…';

  @override
  String get historyTitle => '歷史會話';

  @override
  String historyResumeFailed(Object error) {
    return '恢復會話失敗：$error';
  }

  @override
  String get historyManageSessions => '會話管理';

  @override
  String get historyHideArchived => '隱藏已封存';

  @override
  String get historyShowArchived => '顯示已封存';

  @override
  String get historySelectTitle => '選擇會話';

  @override
  String get historySelectDescription => '在左側選擇會話以查看摘要與管理操作';

  @override
  String get historyLoading => '載入歷史會話…';

  @override
  String get historySearchHint => '搜尋標題、內容或工作目錄';

  @override
  String get historyClearSearch => '清除';

  @override
  String get historyEmpty => '尚無會話';

  @override
  String get historyNoMatches => '沒有符合的會話';

  @override
  String get historyLoadMore => '載入更多';

  @override
  String historyLoadMoreCount(Object loaded, Object total) {
    return '載入更多（$loaded/$total）';
  }

  @override
  String get historyPinned => '置頂';

  @override
  String get historyToday => '今天';

  @override
  String get historyYesterday => '昨天';

  @override
  String get historyThisWeek => '本週';

  @override
  String get historyLastWeek => '上週';

  @override
  String get historyEarlier => '更早';

  @override
  String get historyCollapseChildren => '收合子會話';

  @override
  String get historyExpandChildren => '展開子會話';

  @override
  String get historySessionActions => '會話操作';

  @override
  String get historyManageSession => '管理會話';

  @override
  String get historyUntitled => '未命名會話';

  @override
  String historyMessageCount(Object count) {
    return '$count 則訊息';
  }

  @override
  String get historyDeleteQuestion => '刪除會話？';

  @override
  String historyDeletePrompt(Object title) {
    return '「$title」將永久刪除，此操作無法復原。';
  }

  @override
  String historyDeleteFailed(Object error) {
    return '刪除會話失敗：$error';
  }

  @override
  String historyRenameFailed(Object error) {
    return '重新命名失敗：$error';
  }

  @override
  String historyCompressed(Object count) {
    return '已壓縮會話（移除 $count 則訊息）';
  }

  @override
  String historyCompressFailed(Object error) {
    return '壓縮失敗：$error';
  }

  @override
  String historyArchiveFailed(Object error) {
    return '封存失敗：$error';
  }

  @override
  String historyUnarchiveFailed(Object error) {
    return '取消封存失敗：$error';
  }

  @override
  String get historyManagement => '會話管理';

  @override
  String get historySaveTitle => '儲存標題';

  @override
  String historyContextUsage(Object maximum, Object percent, Object used) {
    return '上下文用量：$used / $maximum$percent';
  }

  @override
  String historyPercent(Object percent) {
    return '（$percent%）';
  }

  @override
  String get historyCompress => '壓縮會話';

  @override
  String get historyArchive => '封存';

  @override
  String get historyUnarchive => '取消封存';

  @override
  String get cronTitle => '排程任務';

  @override
  String get cronLoading => '正在載入排程任務…';

  @override
  String get cronEmptyTitle => '尚無排程任務';

  @override
  String get cronEmptyDescription => '建立按排程定時執行的自動任務';

  @override
  String get cronNew => '新增排程';

  @override
  String cronNextRun(Object time) {
    return '下次執行：$time';
  }

  @override
  String get cronRunHistory => '執行記錄';

  @override
  String cronRunHistoryTitle(Object name) {
    return '執行記錄 · $name';
  }

  @override
  String get cronNoRuns => '尚無執行記錄';

  @override
  String get cronTriggerNow => '立即觸發';

  @override
  String get cronTriggered => '已觸發';

  @override
  String cronTriggerFailed(Object error) {
    return '觸發失敗：$error';
  }

  @override
  String cronUpdateFailed(Object error) {
    return '更新失敗：$error';
  }

  @override
  String get cronDeleteQuestion => '刪除排程任務？';

  @override
  String cronDeletePrompt(Object name) {
    return '「$name」將被刪除。';
  }

  @override
  String cronDeleteFailed(Object error) {
    return '刪除失敗：$error';
  }

  @override
  String get cronStateCompleted => '已完成';

  @override
  String get cronStateDisabled => '已停用';

  @override
  String get cronStateEnabled => '已啟用';

  @override
  String get cronStateError => '發生錯誤';

  @override
  String get cronStatePaused => '已暫停';

  @override
  String get cronStateRunning => '執行中';

  @override
  String get cronStateScheduled => '已排程';

  @override
  String cronModelsLoadFailed(Object error) {
    return '無法載入模型選項：$error';
  }

  @override
  String cronBlueprintsLoadFailed(Object error) {
    return '無法載入自動化範本：$error';
  }

  @override
  String cronTargetsLoadFailed(Object error) {
    return '無法載入投遞目標：$error';
  }

  @override
  String get cronPresetMinute => '每分鐘';

  @override
  String get cronPresetHour => '每小時';

  @override
  String get cronPresetDay => '每天 09:00';

  @override
  String get cronPresetWeek => '每週一 09:00';

  @override
  String get cronPresetMonth => '每月 1 日 09:00';

  @override
  String get cronPresetCustom => '自訂';

  @override
  String get cronPresetMinuteHint => '每分鐘執行一次';

  @override
  String get cronPresetHourHint => '每小時整點執行';

  @override
  String get cronPresetDayHint => '每天上午 9 點執行';

  @override
  String get cronPresetWeekHint => '每週一上午 9 點執行';

  @override
  String get cronPresetMonthHint => '每月 1 日上午 9 點執行';

  @override
  String get cronPromptAndExpressionRequired => '請填寫執行內容和 Cron 運算式';

  @override
  String get cronExpressionRequired => '請填寫 Cron 運算式';

  @override
  String get cronPromptRequired => '請填寫執行內容';

  @override
  String cronSaveFailed(Object error) {
    return '儲存失敗：$error';
  }

  @override
  String get cronCreateTitle => '新增排程任務';

  @override
  String get cronEditTitle => '編輯排程任務';

  @override
  String get cronStartFromTemplate => '從範本開始';

  @override
  String get cronScheduling => '正在排程…';

  @override
  String get cronScheduleAutomation => '排程此自動化';

  @override
  String get cronScriptOnlyDescription =>
      '這是僅指令碼任務。您可以調整名稱、排程和投遞目標；指令碼內容與模型設定將保持不變。';

  @override
  String get cronScriptLabel => '指令碼';

  @override
  String cronLastRun(Object time) {
    return '上次執行：$time';
  }

  @override
  String get cronRunScheduledAt => '排程時間';

  @override
  String get cronRunStartedAt => '開始時間';

  @override
  String get cronRunFinishedAt => '結束時間';

  @override
  String get cronRunStatus => '狀態';

  @override
  String get cronRunOutput => '輸出';

  @override
  String get cronRunDetailTitle => '執行成功';

  @override
  String get cronRunDetailFailedTitle => '執行失敗';

  @override
  String get cronNameOptional => '名稱（選填）';

  @override
  String get cronDeliverResultsTo => '結果投遞至';

  @override
  String get cronTaskModel => '任務模型';

  @override
  String get cronUseGlobalDefault => '使用全域預設值';

  @override
  String cronSavedModel(Object model) {
    return '$model（目前已儲存）';
  }

  @override
  String get cronPromptLabel => '執行內容（prompt）';

  @override
  String get cronFrequency => '頻率';

  @override
  String get cronExpression => 'Cron 運算式';

  @override
  String get cronExpressionHint => '分 時 日 月 週';

  @override
  String get cronSaving => '儲存中…';

  @override
  String get cronThisDevice => '此裝置';

  @override
  String get cronConfigureHomeChannelFirst => '請先設定主頻道';

  @override
  String get profilesTitle => 'Agent Profiles';

  @override
  String get profilesLoading => '正在載入設定檔…';

  @override
  String get profilesEmptyTitle => '尚無設定檔';

  @override
  String get profilesEmptyDescription => '建立第一個 Agent 設定檔';

  @override
  String get profilesNew => '新增 Profile';

  @override
  String get profilesImport => '匯入 Profile';

  @override
  String get profilesExport => '匯出 Profile';

  @override
  String get profilesDuplicate => '複製設定檔';

  @override
  String get profilesEditSoul => '編輯 SOUL.md';

  @override
  String get profilesSetupCommand => '終端機啟動指令';

  @override
  String profilesSaveFailed(Object error) {
    return '儲存失敗：$error';
  }

  @override
  String get profilesCreated => '已建立設定檔';

  @override
  String get profilesSaved => '已儲存設定檔';

  @override
  String profilesCopyName(Object name) {
    return '$name 副本';
  }

  @override
  String profilesDuplicateFailed(Object error) {
    return '複製失敗：$error';
  }

  @override
  String get profilesDuplicated => '已複製設定檔';

  @override
  String profilesDeleteQuestion(Object name) {
    return '刪除設定檔「$name」？';
  }

  @override
  String get profilesDeleteActiveWarning => '注意：此設定檔目前正在使用。';

  @override
  String get profilesDeleteWarning => '此操作無法復原。';

  @override
  String profilesDeleteFailed(Object error) {
    return '刪除失敗：$error';
  }

  @override
  String get profilesDeleted => '已刪除設定檔';

  @override
  String profilesSwitchFailed(Object error) {
    return '切換失敗：$error';
  }

  @override
  String profilesSwitchedTo(Object name) {
    return '已切換至「$name」';
  }

  @override
  String get profilesSoulHint => '描述此 Agent 的身分、行為與溝通方式';

  @override
  String get profilesSoulSaved => 'SOUL.md 已儲存';

  @override
  String profilesSoulFailed(Object error) {
    return 'SOUL.md 操作失敗：$error';
  }

  @override
  String get profilesCopy => '複製';

  @override
  String profilesSetupCommandFailed(Object error) {
    return '無法讀取啟動指令：$error';
  }

  @override
  String get profilesExported => 'Profile 已匯出';

  @override
  String profilesExportFailed(Object error) {
    return '匯出失敗：$error';
  }

  @override
  String profilesImported(Object name) {
    return '已匯入 $name';
  }

  @override
  String profilesImportFailed(Object error) {
    return '匯入失敗：$error';
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
  String get profilesCurrentSuffix => ' · 目前使用';

  @override
  String get profilesActive => '使用中';

  @override
  String get profilesActivate => '啟用';

  @override
  String get profilesNameRequired => '請填寫設定檔名稱';

  @override
  String get profilesCreateTitle => '新增設定檔';

  @override
  String get profilesEditTitle => '編輯設定檔';

  @override
  String get profilesProvider => '提供者';

  @override
  String get profilesModel => '模型';

  @override
  String get profilesSystemPrompt => '系統提示詞';

  @override
  String get profilesDescriptionOptional => '描述（選填）';

  @override
  String get profilesTools => '工具開關';

  @override
  String get profilesDeselectAll => '全部取消選取';

  @override
  String get profilesSelectAll => '全選';

  @override
  String get profilesSetActive => '設為使用中的設定檔';

  @override
  String get memoryTitle => '記憶';

  @override
  String get memoryLoading => '正在讀取記憶狀態…';

  @override
  String memorySwitchFailed(Object error) {
    return '切換失敗：$error';
  }

  @override
  String get memoryResetScope => '選擇重設範圍';

  @override
  String get memoryResetScopeDescription => '只刪除所選記憶檔案';

  @override
  String get memoryAll => '全部記憶';

  @override
  String get memoryAllFiles => 'MEMORY.md 和 USER.md';

  @override
  String get memoryLongTerm => '長期記憶';

  @override
  String get memoryLongTermFile => '僅 MEMORY.md';

  @override
  String get memoryUser => '使用者記憶';

  @override
  String get memoryUserFile => '僅 USER.md';

  @override
  String get memoryResetQuestion => '確認重設記憶？';

  @override
  String get memoryResetWarning => '刪除後無法復原。';

  @override
  String get memoryNothingDeleted => '沒有需要刪除的記憶檔案';

  @override
  String memoryDeleted(Object files) {
    return '已刪除 $files';
  }

  @override
  String memoryResetFailed(Object error) {
    return '重設失敗：$error';
  }

  @override
  String memoryCuratorUpdateFailed(Object error) {
    return '更新 Curator 失敗：$error';
  }

  @override
  String get memoryCuratorStarted => 'Curator 已開始執行';

  @override
  String memoryCuratorRunFailed(Object error) {
    return '執行失敗：$error';
  }

  @override
  String get memoryCurrentProvider => '目前記憶提供方';

  @override
  String get memoryDisabled => '未啟用';

  @override
  String get memoryEnabled => '已啟用';

  @override
  String get memoryProviders => '提供方';

  @override
  String get memoryNoProviders => '沒有可用的提供方';

  @override
  String get memoryBuiltInFiles => '內建記憶檔案';

  @override
  String get memoryReset => '重設記憶';

  @override
  String get memoryInUse => '使用中';

  @override
  String get memoryConfigured => '已設定';

  @override
  String memoryConfigureProvider(Object name) {
    return '設定 $name';
  }

  @override
  String memoryEnableProvider(Object name) {
    return '啟用 $name';
  }

  @override
  String get memoryCuratorLoading => '正在讀取 Curator 狀態…';

  @override
  String get memoryCuratorUnavailable => 'Curator 無法使用';

  @override
  String get memoryPaused => '已暫停';

  @override
  String memoryCuratorInterval(Object hours) {
    return '每 $hours 小時檢查';
  }

  @override
  String memoryCuratorLastRun(Object time) {
    return '上次執行 $time';
  }

  @override
  String get memoryResume => '繼續';

  @override
  String get memoryPause => '暫停';

  @override
  String get memoryRunNow => '立即執行';

  @override
  String memoryInvalidJson(Object field) {
    return '$field 不是有效的 JSON';
  }

  @override
  String get memoryProviderSaved => '提供方設定已儲存';

  @override
  String memoryProviderSaveFailed(Object error) {
    return '儲存失敗：$error';
  }

  @override
  String get memoryOAuthTimeout => '連線逾時，請重試';

  @override
  String get memoryCurrentProfile => '目前 Profile';

  @override
  String memoryProfile(Object name) {
    return 'Profile：$name';
  }

  @override
  String get memoryProviderConfigLoading => '正在讀取提供方設定…';

  @override
  String get memoryNoProviderConfig => '此提供方沒有額外設定';

  @override
  String get memoryViewProviderDocs => '檢視提供方文件';

  @override
  String get memorySaving => '儲存中…';

  @override
  String get memorySaveConfig => '儲存設定';

  @override
  String get memoryAccountConnected => '帳戶已連線';

  @override
  String get memoryConnectAccount => '連線提供方帳戶';

  @override
  String get memoryReconnect => '重新連線';

  @override
  String get memoryConnect => '連線';

  @override
  String get memoryKeepSecretHint => '留空以保留目前的值';

  @override
  String agentOpenBotFailed(Object error) {
    return '無法開啟 Bot Chat：$error';
  }

  @override
  String get agentNewGroup => '新增群組聊天';

  @override
  String get agentEditGroup => '編輯群組聊天';

  @override
  String get agentGroupName => '群組聊天名稱';

  @override
  String agentGroupSaveFailed(Object error) {
    return '無法儲存群組聊天：$error';
  }

  @override
  String agentBotThinking(Object name) {
    return '$name 正在思考';
  }

  @override
  String agentBotPaused(Object name) {
    return '$name 已暫停';
  }

  @override
  String get agentStartGroupChat => '開始群組聊天';

  @override
  String agentReplyTo(Object id) {
    return '回覆 #$id';
  }

  @override
  String get agentSendToRoom => '傳送至房間';

  @override
  String get agentMentionHint => '使用 @名稱 指定成員，或用 @all 通知所有成員';

  @override
  String agentAttachmentTooLarge(Object name) {
    return '$name 超過 20MB';
  }

  @override
  String agentAttachFailed(Object error) {
    return '無法加入附件：$error';
  }

  @override
  String agentGroupSendFailed(Object error) {
    return '無法傳送群組訊息：$error';
  }

  @override
  String get agentAppendMessage => '追加訊息';

  @override
  String get agentAwaitingApproval => '等待授權';

  @override
  String get agentNeedsInformation => '需要補充資訊';

  @override
  String get agentRespond => '回應';

  @override
  String agentMemberRequest(Object name) {
    return '$name 的請求';
  }

  @override
  String get agentAllowOperationQuestion => '允許此操作？';

  @override
  String get agentDeny => '拒絕';

  @override
  String get agentAlwaysAllow => '一律允許';

  @override
  String get agentAllow => '允許';

  @override
  String get agentCustomAnswer => '自訂回答';

  @override
  String get agentEnterAnswer => '請輸入回答';

  @override
  String agentRespondFailed(Object error) {
    return '回應失敗：$error';
  }

  @override
  String get agentLoading => '正在讀取 Agent 狀態…';

  @override
  String get agentNoData => '暫無資料';

  @override
  String get agentManageBots => '管理 / 新增 Bot';

  @override
  String get agentRefreshRoster => '重新整理 Bot 名單';

  @override
  String agentGroupSummary(Object count, Object runningSuffix) {
    return '$count 個 Bot · 跨連線$runningSuffix';
  }

  @override
  String get agentRunningSuffix => ' · 執行中';

  @override
  String agentDeleteGroupQuestion(Object name) {
    return '刪除群組聊天「$name」？';
  }

  @override
  String get agentDeleteGroupWarning => '群組聊天記錄將被永久刪除，此操作無法復原。';

  @override
  String agentDeleteGroupFailed(Object error) {
    return '無法刪除群組聊天：$error';
  }

  @override
  String get agentDeleteGroup => '刪除群組聊天';

  @override
  String agentDeleteBotQuestion(Object name) {
    return '刪除 Bot「$name」？';
  }

  @override
  String agentBotOperationFailed(Object error) {
    return 'Bot 操作失敗：$error';
  }

  @override
  String get agentDuplicateBot => '複製 Bot';

  @override
  String get agentDeleteBot => '刪除 Bot';

  @override
  String get agentGateway => '閘道';

  @override
  String get agentActiveAgents => '作用中的 Agent';

  @override
  String get agentBusy => '忙碌';

  @override
  String get agentYes => '是';

  @override
  String get agentNo => '否';

  @override
  String get agentModelSection => '模型';

  @override
  String get agentCurrentModel => '目前模型';

  @override
  String get agentProvider => '提供方';

  @override
  String get agentContextLength => '上下文長度';

  @override
  String get agentSessionModel => '工作階段模型';

  @override
  String get agentRuntimeSection => '執行階段';

  @override
  String get agentType => '類型';

  @override
  String get agentSourceRoot => '原始碼目錄';

  @override
  String get agentHermesHome => 'Hermes 主目錄';

  @override
  String get agentServerVersion => '伺服器版本';

  @override
  String get agentCapability => '能力';

  @override
  String get agentRestarting => '正在重新啟動…';

  @override
  String botRoutineUpdateFailed(Object error) {
    return '無法更新 Cronjob：$error';
  }

  @override
  String get botRoutineDeleteQuestion => '刪除 Cronjob？';

  @override
  String botRoutineDeletePrompt(Object title) {
    return '「$title」及其排程將被永久刪除。';
  }

  @override
  String get botRoutineStatus => '狀態';

  @override
  String get botRoutinePaused => '已暫停';

  @override
  String get botRoutineSchedule => '排程';

  @override
  String get botRoutineRawSchedule => '原始排程';

  @override
  String get botRoutineRepeatCount => '重複次數';

  @override
  String get botRoutineNextRun => '下次執行';

  @override
  String get botRoutineLastRun => '上次執行';

  @override
  String get botRoutineLastResult => '上次結果';

  @override
  String get botRoutineDeliverTo => '投遞至';

  @override
  String get botRoutineModel => '模型';

  @override
  String get botRoutineWorkdir => '工作目錄';

  @override
  String get botRoutineInstruction => '指令';

  @override
  String get botRoutineLegacyWarning => '此舊版任務已基於安全考量暫停。請刪除並重新建立後再執行。';

  @override
  String botRoutineTitle(Object name) {
    return '$name · 排程任務';
  }

  @override
  String commonBytes(Object count) {
    return '$count 位元組';
  }

  @override
  String get botRoutineLoading => '正在載入 Bot Cronjobs…';

  @override
  String get botRoutineEmptyTitle => '尚無 Cronjob';

  @override
  String botRoutineEmptyDescription(Object name) {
    return '為 $name 建立獨立的排程任務';
  }

  @override
  String get botRoutineNew => '新增 Cronjob';

  @override
  String botRoutineNext(Object time) {
    return '下次 $time';
  }

  @override
  String get botRoutineLegacyPaused => '舊版任務，已安全暫停';

  @override
  String get botRoutineDelete => '刪除 Cronjob';

  @override
  String botRoutineScheduleOnce(Object duration) {
    return '一次性 · $duration 後';
  }

  @override
  String botRoutineScheduleEvery(Object duration) {
    return '每 $duration';
  }

  @override
  String get botRoutineScheduleHourly => '每小時整點';

  @override
  String get botRoutineScheduleDaily => '每天 09:00';

  @override
  String get botRoutineScheduleWeekdays => '工作日 09:00';

  @override
  String get botRoutineScheduleWeekly => '每週一 09:00';

  @override
  String get botRoutineScheduleMonthly => '每月 1 日 09:00';

  @override
  String get botRoutineRequiredFields => '請填寫名稱、指令和執行排程';

  @override
  String botRoutineCreateTitle(Object name) {
    return '新增 Cronjob · $name';
  }

  @override
  String get botRoutineInstructionLabel => '每次執行時使用的指令';

  @override
  String get botRoutineFrequencyOnce => '一次性，在一段時間後';

  @override
  String get botRoutineFrequencyHourly => '每小時';

  @override
  String get botRoutineFrequencyDaily => '每天';

  @override
  String get botRoutineFrequencyWeekdays => '工作日';

  @override
  String get botRoutineFrequencyWeekly => '每週';

  @override
  String get botRoutineFrequencyMonthly => '每月';

  @override
  String get botRoutineFrequencyInterval => '固定間隔';

  @override
  String get botRoutineFrequencyAdvanced => '進階運算式';

  @override
  String get botRoutineTime => '時間（HH:mm）';

  @override
  String get botRoutineWeekday => '星期';

  @override
  String get botRoutineMonday => '星期一';

  @override
  String get botRoutineTuesday => '星期二';

  @override
  String get botRoutineWednesday => '星期三';

  @override
  String get botRoutineThursday => '星期四';

  @override
  String get botRoutineFriday => '星期五';

  @override
  String get botRoutineSaturday => '星期六';

  @override
  String get botRoutineSunday => '星期日';

  @override
  String get botRoutineDayOfMonth => '每月第幾日';

  @override
  String get botRoutineValue => '數值';

  @override
  String get botRoutineUnit => '單位';

  @override
  String get botRoutineMinutes => '分鐘';

  @override
  String get botRoutineHours => '小時';

  @override
  String get botRoutineDays => '天';

  @override
  String get botRoutineAdvancedExpression => 'Cron 或 every Nm/Nh/Nd';

  @override
  String botRoutineWillSaveAs(Object schedule) {
    return '將儲存為：$schedule';
  }

  @override
  String get botRoutineRepeatLimit => '執行次數上限（留空表示持續執行）';

  @override
  String get botRoutineContinuity => '連續性';

  @override
  String get botRoutineContinuityDescription => '每次執行可讀取此任務上一次的輸出';

  @override
  String botRoutineSendToBot(Object name) {
    return '傳送至 $name 的 Bot Chat';
  }

  @override
  String get botRoutineSendToBotDescription => 'Bot 會讀取結果並繼續回應';

  @override
  String get botRoutineCreating => '建立中…';

  @override
  String get botRoutineCreate => '建立 Cronjob';

  @override
  String get mcpTitle => 'MCP 伺服器';

  @override
  String mcpOperationFailed(Object error) {
    return '操作失敗：$error';
  }

  @override
  String get mcpPersistenceFailed => '伺服器未能持久化 MCP 設定變更。';

  @override
  String mcpTestSuccess(Object prompts, Object resources, Object tools) {
    return '連線成功：$tools 個工具、$prompts 個提示、$resources 個資源';
  }

  @override
  String mcpTestConnectionFailed(Object error) {
    return '連線失敗：$error';
  }

  @override
  String mcpTestFailed(Object error) {
    return '測試失敗：$error';
  }

  @override
  String mcpReloadFailed(Object error) {
    return '設定已儲存，但作用中工作階段的 MCP 熱重新載入失敗：$error';
  }

  @override
  String get mcpImportUnrecognized => '無法辨識貼上的內容，請檢查格式';

  @override
  String mcpImportDetected(Object count) {
    return '偵測到 $count 個伺服器';
  }

  @override
  String mcpImportAllQuestion(Object names) {
    return '是否全部加入？\n\n$names';
  }

  @override
  String get mcpAddAll => '全部加入';

  @override
  String mcpServersAdded(Object count) {
    return '已加入 $count 個伺服器';
  }

  @override
  String mcpServersPartiallyAdded(Object added, Object failed) {
    return '已加入 $added 個，$failed 個失敗';
  }

  @override
  String get mcpAddServer => '加入 MCP 伺服器';

  @override
  String get mcpPasteImport => '貼上匯入（mcp.json / 命令列 / claude mcp add / URL）';

  @override
  String get mcpParse => '解析';

  @override
  String get mcpRemoteUrl => '遠端 URL';

  @override
  String get mcpLocalStdio => '本機 stdio';

  @override
  String get mcpServerUrl => '伺服器 URL';

  @override
  String get mcpCommand => '指令';

  @override
  String get mcpArgumentsOnePerLine => '參數（每行一個）';

  @override
  String get mcpEnvironmentJson => '環境變數 JSON';

  @override
  String get mcpAuthentication => '驗證方式';

  @override
  String get mcpNoAuthentication => '無驗證';

  @override
  String get mcpEnvironmentMustBeJson => '環境變數必須是 JSON 物件';

  @override
  String get mcpServerAdded => 'MCP 伺服器已加入';

  @override
  String mcpAddFailed(Object error) {
    return '加入失敗：$error';
  }

  @override
  String mcpDeleteQuestion(Object name) {
    return '刪除 $name？';
  }

  @override
  String get mcpDeleteWarning => '此操作會從 Hermes MCP 設定中永久移除此伺服器。';

  @override
  String mcpDeleteFailed(Object error) {
    return '刪除失敗：$error';
  }

  @override
  String mcpReadConfigFailed(Object error) {
    return '讀取設定失敗：$error';
  }

  @override
  String mcpEditServer(Object name) {
    return '編輯 $name';
  }

  @override
  String mcpInvalidJson(Object error) {
    return '不是有效的 JSON 物件：$error';
  }

  @override
  String mcpServerSaved(Object name) {
    return '$name 已儲存';
  }

  @override
  String mcpSaveFailed(Object error) {
    return '儲存失敗：$error';
  }

  @override
  String mcpToolToggleFailed(Object error) {
    return '切換工具失敗：$error';
  }

  @override
  String get mcpOAuthStartFailed => 'OAuth 啟動失敗';

  @override
  String get mcpOAuthMissingUrl => 'OAuth 伺服器未傳回授權網址';

  @override
  String get mcpBrowserOpenFailed => '無法開啟系統瀏覽器';

  @override
  String mcpCompleteAuthorization(Object name) {
    return '請在瀏覽器完成 $name 授權';
  }

  @override
  String get mcpOAuthAuthorizationFailed => 'OAuth 授權失敗';

  @override
  String mcpAuthorizationSucceeded(Object name, Object tools) {
    return '$name 授權成功，發現 $tools 個工具';
  }

  @override
  String mcpOAuthFailed(Object error) {
    return 'OAuth 失敗：$error';
  }

  @override
  String mcpInstallTitle(Object name) {
    return '安裝 $name';
  }

  @override
  String get mcpRequired => '必填';

  @override
  String get mcpOptional => '選填';

  @override
  String get mcpRequiredCredentials => '請填寫所有必填憑證';

  @override
  String get mcpReinstall => '重新安裝';

  @override
  String get mcpInstall => '安裝';

  @override
  String mcpInstallExitCode(Object code) {
    return '安裝程序結束代碼 $code';
  }

  @override
  String mcpInstallComplete(Object name) {
    return '$name 安裝完成';
  }

  @override
  String mcpInstallFailed(Object error) {
    return '安裝失敗：$error';
  }

  @override
  String get mcpViewLogs => '檢視日誌';

  @override
  String get mcpLoading => '正在讀取 MCP 伺服器…';

  @override
  String get mcpConfiguredServers => '已設定伺服器';

  @override
  String get mcpNoConfiguredServers => '尚未設定 MCP 伺服器';

  @override
  String get mcpDescription => 'MCP 讓 Agent 連接外部工具與資料來源。';

  @override
  String mcpAvailableCatalog(Object count) {
    return '可用目錄（$count）';
  }

  @override
  String mcpToolCount(Object count) {
    return '$count 個工具';
  }

  @override
  String mcpUsage30Days(Object count) {
    return '$count 次/30天';
  }

  @override
  String get mcpTestConnection => '測試連線';

  @override
  String get mcpEditConfiguration => '編輯設定';

  @override
  String get mcpOAuthAuthorization => 'OAuth 授權';

  @override
  String get mcpInstalledEnabled => '已安裝並啟用';

  @override
  String get mcpInstalledDisabled => '已安裝但未啟用';

  @override
  String get commandCenterTitle => '命令中心';

  @override
  String get commandStatusTab => '狀態';

  @override
  String get commandUsageTab => '用量';

  @override
  String get commandMaintenanceTab => '維護';

  @override
  String commandStatusLoadFailed(Object error) {
    return '無法讀取狀態：$error';
  }

  @override
  String commandLogsLoadFailed(Object error) {
    return '無法讀取日誌：$error';
  }

  @override
  String get commandRestartWarning => '這將重新啟動 Hermes backend 程序，進行中的回合可能中斷。';

  @override
  String commandRestartResult(Object result) {
    return '重新啟動結果：$result';
  }

  @override
  String get commandNoLogs => '（無日誌）';

  @override
  String get commandBackendProcess => '後端程序';

  @override
  String get commandStopped => '已停止';

  @override
  String get commandLiveLogs => '即時日誌';

  @override
  String get commandDiagnostics => '診斷詳情';

  @override
  String get commandSystemStatus => '系統狀態';

  @override
  String get commandNoStatusData => '沒有狀態資料';

  @override
  String commandUsageLoadFailed(Object error) {
    return '無法讀取用量：$error';
  }

  @override
  String commandDays(Object count) {
    return '$count 天';
  }

  @override
  String get commandSessions => '工作階段';

  @override
  String get commandApiCalls => 'API 呼叫';

  @override
  String get commandTokensInOut => 'Token（輸入/輸出）';

  @override
  String get commandDailyUsage => '每日用量';

  @override
  String get commandNoUsageData => '暫無用量資料';

  @override
  String get commandTopModels => '模型使用排行';

  @override
  String get commandTopSkills => '技能使用排行';

  @override
  String commandUseCount(Object count) {
    return '$count 次';
  }

  @override
  String commandChartTooltip(Object day, Object input, Object output) {
    return '$day\n輸入 $input / 輸出 $output';
  }

  @override
  String get commandInputTokens => '輸入 tokens';

  @override
  String get commandOutputTokens => '輸出 tokens';

  @override
  String commandStarting(Object label) {
    return '正在啟動 $label…';
  }

  @override
  String get commandMissingActionName => '後端未傳回操作名稱';

  @override
  String get commandNoOutput => '（暫無輸出）';

  @override
  String commandActionExitFailed(Object code, Object label) {
    return '$label 失敗（結束代碼 $code）';
  }

  @override
  String commandActionComplete(Object label) {
    return '$label 完成';
  }

  @override
  String commandLogError(Object error, Object logs) {
    return '$logs\n\n錯誤：$error';
  }

  @override
  String commandActionFailed(Object error, Object label) {
    return '$label 失敗：$error';
  }

  @override
  String commandDebugShareFailed(Object error) {
    return '無法產生除錯分享：$error';
  }

  @override
  String get commandDebugShare => '產生除錯分享';

  @override
  String get commandLogsRedacted => '已對日誌進行脫敏處理。';

  @override
  String get commandLogsNotRedacted => '日誌未經脫敏，請謹慎分享。';

  @override
  String commandAutoDeleteHours(Object hours) {
    return '連結將在約 $hours 小時後自動刪除。';
  }

  @override
  String get commandPartialUploadFailed => '部分內容上傳失敗：';

  @override
  String get commandDiagnosticsMaintenance => '診斷與維護';

  @override
  String get commandRunDoctor => '執行診斷';

  @override
  String get commandRunDoctorDescription => 'hermes doctor - 檢查環境與設定';

  @override
  String get commandDoctor => '診斷';

  @override
  String get commandSecurityAudit => '安全稽核';

  @override
  String get commandSecurityAuditDescription =>
      'hermes security audit - 掃描潛在安全問題';

  @override
  String get commandBackupNow => '立即備份';

  @override
  String get commandBackupDescription => 'hermes backup - 將設定與資料封裝到本機';

  @override
  String get commandBackup => '備份';

  @override
  String get commandDebugShareDescription => '上傳脫敏日誌並產生可分享的除錯連結';

  @override
  String terminalStartFailed(Object error) {
    return '無法啟動終端機：$error';
  }

  @override
  String get terminalSshHost => '主機或 SSH config alias *';

  @override
  String get terminalSshUserOptional => '使用者（選填）';

  @override
  String get terminalSshPort => '連接埠（預設 22）';

  @override
  String get terminalSshIdentityFile => '伺服器端 IdentityFile（選填）';

  @override
  String get terminalSshRemoteCwd => '遠端工作目錄（選填）';

  @override
  String get terminalSshAuthenticationNote =>
      '驗證由 Hermes server 所在機器的 ssh-agent / SSH config 完成；行動端不儲存密碼。';

  @override
  String terminalSshFailed(Object error) {
    return 'SSH 連線失敗：$error';
  }

  @override
  String get terminalCloseRunningQuestion => '關閉執行中的終端機？';

  @override
  String terminalCloseRunningWarning(Object name) {
    return '「$name」中的程序將被終止，此操作無法復原。';
  }

  @override
  String get terminalClose => '關閉終端機';

  @override
  String get terminalSessions => '終端機工作階段';

  @override
  String terminalSessionLimit(Object count) {
    return '最多可同時開啟 $count 個終端機';
  }

  @override
  String terminalCloseNamed(Object name) {
    return '關閉 $name';
  }

  @override
  String get terminalSelectTextFirst => '請先選取文字';

  @override
  String terminalPasteLinesQuestion(Object count) {
    return '貼上 $count 行內容？';
  }

  @override
  String get terminalMergeSingleLine => '合併成單行';

  @override
  String get terminalConfirmPaste => '確認貼上';

  @override
  String get terminalSelectTerminalTextFirst => '請先在終端機中選取文字';

  @override
  String get terminalSentToChat => '已傳送至聊天輸入框';

  @override
  String terminalOpenLinkFailed(Object link) {
    return '無法開啟連結：$link';
  }

  @override
  String get terminalDismissNotice => '關閉提示';

  @override
  String get terminalNew => '新增終端機';

  @override
  String get terminalNewSsh => '新增 SSH Terminal';

  @override
  String get terminalOpenDirectory => '選擇目錄開啟';

  @override
  String get terminalDisplaySettings => '終端機顯示設定';

  @override
  String get terminalNoWorkingDirectory => '（無工作目錄）';

  @override
  String get terminalNoActive => '沒有作用中的終端機';

  @override
  String get terminalCommandMode => '命令模式';

  @override
  String get terminalInteractiveMode => '互動模式';

  @override
  String get terminalControlInterrupt => 'Ctrl+C 中斷';

  @override
  String get terminalControlSuspend => 'Ctrl+Z 暫停';

  @override
  String get terminalControlClear => 'Ctrl+L 清除畫面';

  @override
  String get terminalControlBackWord => 'Alt+B 前一個單字';

  @override
  String get terminalControlForwardWord => 'Alt+F 下一個單字';

  @override
  String get terminalControlKeys => '控制鍵';

  @override
  String get terminalVisibleOutputCopied => '已複製目前畫面輸出';

  @override
  String get terminalDisplay => '終端機顯示';

  @override
  String get terminalDisplayDescription => '只調整本機顯示，不會變更 PTY 和命令行為。';

  @override
  String get terminalPreviewOutput => '✓ 42 tests passed  中文輸出預覽';

  @override
  String terminalFontSize(Object value) {
    return '字型大小  $value';
  }

  @override
  String terminalLineHeight(Object value) {
    return '行高  $value';
  }

  @override
  String get terminalColorTheme => '配色主題';

  @override
  String get terminalThemeSystem => '跟隨系統';

  @override
  String get terminalThemeProfessionalDark => '專業深色';

  @override
  String get terminalThemeHighContrastDark => '高對比深色';

  @override
  String get terminalThemeSoftLight => '柔和淺色';

  @override
  String get terminalCursorStyle => '游標樣式';

  @override
  String get terminalCursorBar => '豎線';

  @override
  String get terminalCursorBlock => '方塊';

  @override
  String get terminalCursorUnderline => '底線';

  @override
  String get terminalContentPadding => '終端機內距';

  @override
  String get terminalContentPaddingHint => '關閉後可顯示更多欄';

  @override
  String get terminalResetDisplay => '恢復建議設定';

  @override
  String get terminalCommandHint => '輸入命令…';

  @override
  String get terminalRunCommand => '執行命令';

  @override
  String get terminalPaste => '貼上';

  @override
  String get terminalClear => '清除畫面';

  @override
  String get terminalSendToChat => '傳送至聊天';

  @override
  String get terminalInteractiveHint => '互動模式 · 輸入會直接傳送至 PTY';

  @override
  String get terminalMoreActions => '更多終端機操作';

  @override
  String get terminalCopySelection => '複製選取內容';

  @override
  String get terminalSendSelectionToChat => '將選取內容傳送至聊天';

  @override
  String get terminalOpenOtherDirectory => '在其他目錄開啟終端機';

  @override
  String get terminalManageSessions => '管理終端機工作階段';

  @override
  String get terminalPrivacyHistory => '隱私與歷史記錄';

  @override
  String get terminalPrivacyDescription => '預設不會持久保存命令歷史和終端機輸出。';

  @override
  String get terminalSaveCommandHistory => '儲存命令歷史';

  @override
  String get terminalSaveOutputSnapshots => '儲存終端機輸出快照';

  @override
  String get terminalClearSavedData => '清除已儲存的歷史和快照';

  @override
  String get terminalClearDataQuestion => '清除歷史和快照？';

  @override
  String get terminalClearDataWarning => '已儲存的命令歷史和終端機輸出快照將被永久刪除，此操作無法復原。';

  @override
  String filesRevealFailed(String error) {
    return '無法在檔案管理器中顯示：$error';
  }

  @override
  String get filesLargeDownloadQuestion => '下載較大檔案？';

  @override
  String filesLargeDownloadDescription(String name, String size) {
    return '「$name」約 $size MB，下載可能較慢並佔用本機儲存空間。';
  }

  @override
  String get filesContinueDownload => '繼續下載';

  @override
  String get filesLargeEditQuestion => '開啟大型檔案？';

  @override
  String filesLargeEditDescription(String name, String size) {
    return '「$name」約 $size MB，載入編輯器可能較慢。';
  }

  @override
  String get filesContinueEdit => '仍然開啟';

  @override
  String get filesFolderDownloadQuestion => '下載資料夾？';

  @override
  String filesFolderDownloadDescription(String name) {
    return '「$name」將壓縮為 ZIP 後下載到本機。大型資料夾可能需要較長時間並佔用儲存空間。';
  }

  @override
  String get filesArchiveDownload => '壓縮並下載';

  @override
  String filesDownloadedPath(String path) {
    return '已下載至 $path（路徑已複製）';
  }

  @override
  String filesDownloadFailed(String error) {
    return '下載失敗：$error';
  }

  @override
  String get filesSelectDownloadItem => '請至少選擇一個檔案或資料夾';

  @override
  String filesDownloadSummary(int success, int failed, int skipped) {
    return '已下載 $success 項，失敗 $failed 項，略過 $skipped 項';
  }

  @override
  String get filesRevealOnServer => '在伺服器上顯示';

  @override
  String get filesRevealOnServerDescription => '在 Hermes 所在的主機開啟';

  @override
  String get filesDetails => '詳細資訊';

  @override
  String get filesDownloading => '下載中…';

  @override
  String get filesDownloadFolderZip => '下載資料夾（ZIP）';

  @override
  String get filesDownloadToDevice => '下載到本機';

  @override
  String get filesCopyToClipboard => '複製到剪貼簿';

  @override
  String get filesCopiedPasteHint => '已複製；進入目標資料夾後點選貼上';

  @override
  String get filesCutToClipboard => '剪下到剪貼簿';

  @override
  String get filesCutPasteHint => '已剪下；進入目標資料夾後點選貼上';

  @override
  String get filesRename => '重新命名';

  @override
  String get filesCopyPath => '複製路徑';

  @override
  String get filesPathCopied => '已複製路徑';

  @override
  String get filesCopyRelativePath => '複製相對路徑';

  @override
  String get filesRelativePathCopied => '已複製相對路徑';

  @override
  String get filesLink => '連結';

  @override
  String filesInfoPath(String value) {
    return '路徑：$value';
  }

  @override
  String filesInfoType(String value) {
    return '類型：$value';
  }

  @override
  String filesInfoSize(int value) {
    return '大小：$value B';
  }

  @override
  String filesInfoModified(String value) {
    return '修改時間：$value';
  }

  @override
  String filesInfoReadable(String value) {
    return '可讀：$value';
  }

  @override
  String filesInfoWritable(String value) {
    return '可寫：$value';
  }

  @override
  String filesMovedCount(int count) {
    return '已移動 $count 項';
  }

  @override
  String filesCopiedCount(int count) {
    return '已複製 $count 項';
  }

  @override
  String filesPasteFailed(String error) {
    return '貼上失敗：$error';
  }

  @override
  String get filesConfirmDelete => '確認刪除';

  @override
  String filesDeleteSelectedDescription(int count) {
    return '刪除已選的 $count 項？此操作無法復原。';
  }

  @override
  String filesDeleteFailed(String error) {
    return '刪除失敗：$error';
  }

  @override
  String get filesNewFile => '新增檔案';

  @override
  String get filesFileName => '檔案名稱';

  @override
  String filesCreateFileFailed(String error) {
    return '無法建立檔案：$error';
  }

  @override
  String filesNewSessionPrompt(String references) {
    return '請查看並處理以下檔案：\n$references';
  }

  @override
  String get filesNewFolder => '新增資料夾';

  @override
  String get filesNewName => '新名稱';

  @override
  String filesRenameFailed(String error) {
    return '重新命名失敗：$error';
  }

  @override
  String filesDeleteFolderDescription(String name) {
    return '刪除資料夾「$name」及其所有內容？';
  }

  @override
  String filesDeleteFileDescription(String name) {
    return '刪除檔案「$name」？';
  }

  @override
  String get filesFolderName => '資料夾名稱';

  @override
  String filesCreateFolderFailed(String error) {
    return '無法建立資料夾：$error';
  }

  @override
  String get filesSelectWorkspaceDirectory => '選擇工作區目錄';

  @override
  String filesSelectedCount(int count) {
    return '已選 $count';
  }

  @override
  String get filesSwitchToDirectoryBrowser => '切換至目錄瀏覽';

  @override
  String get filesSwitchToProjectTree => '切換至專案樹';

  @override
  String get filesOpenInGit => '在 Git 中開啟';

  @override
  String get filesNewSessionForDirectory => '為目前目錄新增會話';

  @override
  String get filesSendSelectionToNewSession => '將所選檔案傳送至新會話';

  @override
  String get filesDownloadSelected => '下載所選項目';

  @override
  String get filesCopySelected => '複製所選項目';

  @override
  String get filesCutSelected => '剪下所選項目';

  @override
  String get filesDeleteSelected => '刪除所選項目';

  @override
  String get filesClearSelection => '取消選擇';

  @override
  String get filesMoveHere => '移動到此處';

  @override
  String get filesCopyHere => '複製到此處';

  @override
  String get filesSelectCurrentDirectory => '選擇目前目錄';

  @override
  String filesUseAsWorkspace(String name) {
    return '使用「$name」作為工作區';
  }

  @override
  String get filesSelectPreview => '選擇檔案進行預覽';

  @override
  String get filesSelectPreviewDescription => '點選左側檔案以在此編輯或預覽';

  @override
  String get filesFilterProjectTree => '篩選已載入的專案樹…';

  @override
  String get filesSearchDirectory => '搜尋目前目錄…';

  @override
  String get filesLoadingDirectory => '正在載入目錄…';

  @override
  String get filesNoMatches => '沒有符合的檔案';

  @override
  String get filesActions => '檔案操作';

  @override
  String get filesUnableToRead => '無法讀取';

  @override
  String get filesDownload => '下載';

  @override
  String get filesCut => '剪下';

  @override
  String get configTabModel => '模型';

  @override
  String get configTabChat => '對話';

  @override
  String get configTabMemory => '記憶';

  @override
  String get configTabVoice => '語音';

  @override
  String get configTabToolsKeys => '工具與金鑰';

  @override
  String configLoadFailed(String error) {
    return '載入設定失敗：$error';
  }

  @override
  String get configAuxVision => '視覺理解';

  @override
  String get configAuxWebExtract => '網頁擷取';

  @override
  String get configAuxCompression => '上下文壓縮';

  @override
  String get configAuxSkillsHub => '技能中心';

  @override
  String get configAuxApproval => '核准判斷';

  @override
  String get configAuxMcp => 'MCP 輔助';

  @override
  String get configAuxTitleGeneration => '標題產生';

  @override
  String get configAuxReview => '程式碼審查';

  @override
  String get configAuxTriage => '任務分流';

  @override
  String get configAuxKanban => '看板拆解';

  @override
  String get configAuxProfile => '設定檔描述';

  @override
  String get configAuxCurator => '內容整理';

  @override
  String get configPersonalityDisplay => '人格（display.personality）';

  @override
  String get configPersonality => '人格';

  @override
  String get configTimezone => '時區（IANA）';

  @override
  String get configShowReasoning => '顯示推理區塊';

  @override
  String get configMessageReactions => '啟用訊息表情回應';

  @override
  String get configApprovalMode => '核准模式';

  @override
  String get configYoloApproval => 'YOLO 自動核准';

  @override
  String get configChatFieldsUnavailable => '後端未回傳對話欄位';

  @override
  String get configChatFieldsUnavailableDescription =>
      'GET /api/v1/config 未回傳 personality、timezone、approvals 或 yolo。';

  @override
  String get configPersistentMemory => '持久記憶';

  @override
  String get configUserProfile => '使用者資料';

  @override
  String get configMemoryBudget => '記憶預算（字元）';

  @override
  String get configProfileBudget => '資料預算（字元）';

  @override
  String get configMemoryProvider => '記憶提供者';

  @override
  String get configContextEngine => '上下文引擎';

  @override
  String get configAutoCompression => '自動壓縮';

  @override
  String get configCompressionThreshold => '壓縮門檻';

  @override
  String get configCompressionRatio => '壓縮目標比例';

  @override
  String get configProtectRecent => '保護最近 N 則訊息';

  @override
  String get configMemoryFieldsUnavailable => '後端未回傳記憶欄位';

  @override
  String get configMemoryFieldsUnavailableDescription =>
      'GET /api/v1/config 未回傳 memory、compression 或 context。';

  @override
  String get configVoice => '音色';

  @override
  String get configVoiceModel => '模型';

  @override
  String get configVoiceId => '音色 ID';

  @override
  String get configModelId => '模型 ID';

  @override
  String get configLanguage => '語言';

  @override
  String get configSpeechSpeed => '語速';

  @override
  String get configAutoSpeechTags => '自動語音標籤';

  @override
  String get configStreamingLatency => '串流延遲最佳化';

  @override
  String get configSampleRate => '取樣率';

  @override
  String get configBitRate => '位元率';

  @override
  String get configDevice => '裝置';

  @override
  String get configLanguageCode => '語言代碼';

  @override
  String get configAudioEvents => '標記音訊事件';

  @override
  String get configDiarization => '說話者分離';

  @override
  String get configSpeechToText => '語音轉文字';

  @override
  String get configEchoTranscripts => '回顯轉錄';

  @override
  String get configSttProvider => 'STT 提供者';

  @override
  String get configTtsProvider => 'TTS 提供者';

  @override
  String get configAutoReadReplies => '自動朗讀回覆';

  @override
  String get configMaxRecordingSeconds => '最長錄音秒數';

  @override
  String get configRecordShortcut => '錄音快捷鍵';

  @override
  String get configDirectVoiceService => '用戶端直連語音服務';

  @override
  String get configVoiceFieldsUnavailable => '後端未回傳語音欄位';

  @override
  String get configVoiceFieldsUnavailableDescription =>
      'GET /api/v1/config 未回傳 stt、tts 或 voice。';

  @override
  String get configProviderApiKeys => '模型提供者 API 金鑰';

  @override
  String get configNoProviders => '尚無已設定的提供者';

  @override
  String get configNoProvidersDescription => '新增 API 金鑰以啟用模型提供者';

  @override
  String get configEnvironmentVariables => '環境變數';

  @override
  String get configConfigured => '已設定';

  @override
  String get configNotConfigured => '未設定';

  @override
  String configAvailableModels(int count) {
    return '可用模型：$count 個';
  }

  @override
  String configDisconnectedProvider(String name) {
    return '已中斷 $name';
  }

  @override
  String configDisconnectFailed(String error) {
    return '中斷連線失敗：$error';
  }

  @override
  String get configUpdateKey => '更新金鑰';

  @override
  String get configAddKey => '新增金鑰';

  @override
  String configProviderApiKey(String name) {
    return '$name API 金鑰';
  }

  @override
  String configProviderKeySaved(String name) {
    return '已儲存 $name API 金鑰';
  }

  @override
  String get configSaved => '已儲存';

  @override
  String get configPressEnterToSave => '按 Enter 儲存';

  @override
  String get configEnterNumber => '請輸入數字';

  @override
  String get configNewValueOptional => '新值（留空則不修改）';

  @override
  String get configValue => '值';

  @override
  String configRevealFailed(String error) {
    return '顯示失敗：$error';
  }

  @override
  String configDeleteVariableQuestion(String key) {
    return '刪除 $key？';
  }

  @override
  String get configDeleteVariableDescription => '此環境變數將從伺服器 .env 永久刪除，無法復原。';

  @override
  String get configAddEnvironmentVariable => '新增環境變數';

  @override
  String get configVariableName => '變數名稱';

  @override
  String get configNoEnvironmentVariables => '尚無環境變數';

  @override
  String get configNoEnvironmentVariablesDescription => '新增自訂環境變數以設定工具或提供者';

  @override
  String get configHideAdvancedVariables => '隱藏進階變數';

  @override
  String configShowAdvancedVariables(int count) {
    return '顯示進階變數（$count）';
  }

  @override
  String get configSet => '已設定';

  @override
  String get configNotSet => '未設定';

  @override
  String get configVoiceIdManual => '按 Enter 儲存（未取得帳號語音清單，可手動輸入）';

  @override
  String configVoicesLoadFailed(String error) {
    return '載入帳號語音失敗：$error。可手動輸入 ID 並按 Enter 儲存。';
  }

  @override
  String chatDraftHandoffSaveFailed(String error) {
    return '草稿已保留在目前頁面，但未能儲存到伺服器：$error';
  }

  @override
  String get toolPlanTitle => '計畫';

  @override
  String get toolPlanCopy => '複製計畫';

  @override
  String get toolPlanCopied => '已複製計畫';

  @override
  String get toolValueNotProvided => '未提供';

  @override
  String get toolCommand => '命令';

  @override
  String get toolWaitingCommand => '等待命令';

  @override
  String get toolOutput => '輸出';

  @override
  String get toolErrorOutput => '錯誤輸出';

  @override
  String toolExitCode(int code) {
    return '結束碼：$code';
  }

  @override
  String get toolCode => '程式碼';

  @override
  String toolCodeLanguage(String language) {
    return '程式碼 · $language';
  }

  @override
  String get toolWaitingCode => '等待程式碼內容';

  @override
  String get toolExecutionResult => '執行結果';

  @override
  String toolChangedFiles(int count) {
    return '變更檔案 · $count';
  }

  @override
  String get toolPatchContent => '修補內容';

  @override
  String get toolWaitingPatch => '等待修補內容';

  @override
  String get toolResult => '結果';

  @override
  String get toolSearchQuery => '搜尋詞';

  @override
  String get toolSearchingWeb => '搜尋網路';

  @override
  String toolSearchResults(int count) {
    return '搜尋結果 · $count';
  }

  @override
  String get toolNoResults => '暫無結果';

  @override
  String get toolLink => '連結';

  @override
  String get toolContent => '內容';

  @override
  String get toolFile => '檔案';

  @override
  String get toolReadingFile => '讀取檔案';

  @override
  String get toolWritingFile => '寫入檔案';

  @override
  String get toolWriteContent => '寫入內容';

  @override
  String toolFileList(int count) {
    return '檔案列表 · $count';
  }

  @override
  String get toolNoFiles => '暫無檔案';

  @override
  String get toolDetails => '詳細資料';

  @override
  String get toolNoReadableContent => '（暫無可讀內容）';

  @override
  String get toolWaitingForResult => '等待工具傳回';

  @override
  String get toolUntitledResult => '未命名結果';

  @override
  String get toolCopyAll => '全部複製';

  @override
  String toolHiddenRestore(String name) {
    return '已隱藏 $name，點選復原';
  }

  @override
  String get toolReadableView => '可讀檢視';

  @override
  String get toolRawJsonView => '原始 JSON 檢視';

  @override
  String get toolHideRow => '隱藏此工具列';

  @override
  String get toolCopyResult => '複製結果';

  @override
  String toolRawDetailsTitle(String name) {
    return '$name 原始詳細資料';
  }

  @override
  String get toolViewRawDetails => '檢視原始詳細資料';

  @override
  String get toolArguments => '參數';

  @override
  String get toolNoDetailedData => '（暫無詳細資料）';

  @override
  String toolArgumentDetailsTitle(String key) {
    return '$key 參數';
  }

  @override
  String toolTapForFullContent(int count) {
    return '[點選檢視完整內容（$count 個字元）]';
  }

  @override
  String toolContentTooLong(int count) {
    return '內容過長（共 $count 個字元）';
  }

  @override
  String toolFullResultTitle(String name) {
    return '$name 完整結果';
  }

  @override
  String get toolViewFull => '檢視完整內容';

  @override
  String kanbanDeleteAttachment(String name) {
    return '刪除 $name？';
  }

  @override
  String get kanbanCannotUndo => '此操作無法復原。';

  @override
  String kanbanOperationFailed(String error) {
    return '操作失敗：$error';
  }

  @override
  String get kanbanNoLog => '暫無日誌';

  @override
  String get kanbanAddChildTask => '新增子任務';

  @override
  String get kanbanTaskId => '任務 ID';

  @override
  String get kanbanDescription => '說明';

  @override
  String get kanbanCommandCopied => '已複製命令';

  @override
  String get kanbanViewLog => '檢視日誌';

  @override
  String get kanbanEstimate => '估算';

  @override
  String get kanbanDecompose => '拆解';

  @override
  String get kanbanNoDescription => '無描述';

  @override
  String get kanbanDiagnostics => '診斷';

  @override
  String kanbanComments(int count) {
    return '評論（$count）';
  }

  @override
  String get kanbanAddComment => '新增評論';

  @override
  String kanbanDependencies(int parents, int children) {
    return '相依項目：$parents 個父任務，$children 個子任務';
  }

  @override
  String kanbanChildTask(String id) {
    return '子任務 $id';
  }

  @override
  String kanbanAttachments(int count) {
    return '附件（$count）';
  }

  @override
  String kanbanEventTimeline(int count) {
    return '事件時間軸（$count）';
  }

  @override
  String kanbanRuns(int count) {
    return '執行（$count）';
  }

  @override
  String get kanbanUploadAttachment => '上傳附件';

  @override
  String kanbanAttachmentBytes(int count) {
    return '$count 位元組';
  }

  @override
  String messageReactionFailed(String error) {
    return '表情回應失敗：$error';
  }

  @override
  String get messageRenderFailed => '無法顯示這則訊息';

  @override
  String get messageRenderFailedDescription => '其他訊息不受影響';

  @override
  String get messageRemoveMyReaction => '移除我的回應';

  @override
  String get messageAgentReaction => '代理回應';

  @override
  String get messageAddReaction => '新增表情回應';

  @override
  String get messageSearchEmoji => '搜尋表情符號';

  @override
  String messageImageSaveFailed(String error) {
    return '儲存圖片失敗：$error';
  }

  @override
  String get messageGeneratingImage => '正在產生圖片…';

  @override
  String get messageImageGenerationFailed => '圖片產生失敗';

  @override
  String get messageWaitingForImage => '等待圖片結果';

  @override
  String get messageGeneratedImage => '產生的圖片';

  @override
  String get messageImageLinkCopied => '已複製圖片連結';

  @override
  String get messageOpenInBrowser => '在瀏覽器開啟';

  @override
  String get messageMcpSetup => 'MCP 服務設定';

  @override
  String messageMcpServer(String server) {
    return 'MCP · $server';
  }

  @override
  String get messageMcpSetupFailed => '設定失敗，可在 MCP 設定中重試';

  @override
  String get messageMcpSetupWaiting => '等待完成設定';

  @override
  String get messageMcpSetupComplete => '設定已完成';

  @override
  String get messageOpenMcpSettings => '開啟 MCP 設定';

  @override
  String get messageFileChanges => '檔案變更';

  @override
  String get messageViewDiff => '檢視差異';

  @override
  String get messageOpenLink => '開啟連結';

  @override
  String messageSendingToAgent(String name) {
    return '正在傳送給 $name…';
  }

  @override
  String messageSentToAgent(String name) {
    return '已傳送給 $name';
  }

  @override
  String messageReplyFromAgent(String name) {
    return '來自 $name 的回覆';
  }

  @override
  String messageRepliedToAgent(String name) {
    return '已回覆 $name';
  }

  @override
  String messageFromAgent(String name) {
    return '來自代理 · $name';
  }

  @override
  String get messageSteered => '已引導';

  @override
  String get messageHermesAvatar => 'Hermes 助手頭像';

  @override
  String get messageSourceWechat => '微信';

  @override
  String get messageSourceFeishu => '飛書';

  @override
  String get messageSourceDesktop => '桌面版';

  @override
  String get messageRestoreVersion => '復原此版本';

  @override
  String get messagePreviousVersion => '上一個版本';

  @override
  String get messageNextVersion => '下一個版本';

  @override
  String get messageCopyText => '複製文字';

  @override
  String get messageCopyMarkdown => '複製為 Markdown';

  @override
  String get messageBranchFromHere => '從此訊息建立分支';

  @override
  String get messageSpeakDisconnected => '尚未連線伺服器，無法朗讀';

  @override
  String get messageSpeakFailed => '語音播放失敗，請稍後再試';

  @override
  String get messageStopSpeaking => '停止朗讀';

  @override
  String get messageSpeak => '朗讀';

  @override
  String get sessionDetailMessages => '訊息';

  @override
  String get sessionDetailTools => '工具';

  @override
  String get sessionDetailEstimated => '預估';

  @override
  String get sessionDetailCost => '費用';

  @override
  String get sessionDetailDuration => '時長';

  @override
  String get sessionDetailInfo => '工作階段資訊';

  @override
  String get sessionDetailSource => '來源';

  @override
  String get sessionDetailModel => '模型';

  @override
  String get sessionDetailStarted => '開始';

  @override
  String get sessionDetailLastActivity => '最後活動';

  @override
  String get sessionDetailEnded => '結束';

  @override
  String get sessionDetailEndReason => '結束原因';

  @override
  String get sessionDetailHandoff => '交接';

  @override
  String get sessionDetailHandoffError => '交接異常';

  @override
  String get sessionDetailTokensBilling => 'Token 與計費';

  @override
  String get sessionDetailInputOutput => '輸入 / 輸出';

  @override
  String get sessionDetailCacheReadWrite => '快取讀取 / 寫入';

  @override
  String get sessionDetailReasoningTokens => '推理 Token';

  @override
  String get sessionDetailBillingSource => '計費來源';

  @override
  String get sessionDetailContextSource => '上下文與來源';

  @override
  String get sessionDetailWorkingDirectory => '工作目錄';

  @override
  String get sessionDetailGitBranch => 'Git 分支';

  @override
  String get sessionDetailContact => '聯絡人';

  @override
  String get sessionDetailChatType => '聊天類型';

  @override
  String get sessionDetailUserId => '使用者 ID';

  @override
  String get sessionDetailParentSession => '父工作階段';

  @override
  String get sessionDetailRewindCount => '回退次數';

  @override
  String get sessionDetailCompressionFailed => '壓縮暫時失敗';

  @override
  String get sessionDetailOpen => '開啟工作階段';

  @override
  String get sessionActionOpenWorkspace => '在工作區中開啟';

  @override
  String get sessionActionUnpin => '取消置頂';

  @override
  String get sessionActionPin => '置頂';

  @override
  String get sessionActionAppearance => '外觀';

  @override
  String get sessionActionDuplicate => '複製工作階段';

  @override
  String get sessionActionShare => '分享工作階段';

  @override
  String get sessionActionExport => '匯出工作階段';

  @override
  String get sessionActionMoveProject => '移至專案';

  @override
  String get sessionActionUnarchive => '取消封存';

  @override
  String get sessionActionArchive => '封存';

  @override
  String get sessionActionStopResponse => '停止回應';

  @override
  String get sessionActionAppearanceTitle => '工作階段外觀';

  @override
  String sessionActionRenameFailed(String error) {
    return '重新命名失敗：$error';
  }

  @override
  String get sessionActionUnarchived => '已取消封存';

  @override
  String get sessionActionArchived => '已封存';

  @override
  String sessionActionFailed(String error) {
    return '操作失敗：$error';
  }

  @override
  String get sessionActionUnpinned => '已取消置頂';

  @override
  String get sessionActionPinned => '已置頂';

  @override
  String get sessionActionMoved => '工作階段已移動';

  @override
  String sessionActionMoveFailed(String error) {
    return '移動失敗：$error';
  }

  @override
  String sessionActionBranchCreated(String id) {
    return '已建立分支：$id';
  }

  @override
  String get sessionActionCopyCreated => '已建立工作階段副本';

  @override
  String sessionActionDuplicateFailed(String error) {
    return '複製工作階段失敗：$error';
  }

  @override
  String get sessionActionShareCreated => '已建立分享連結';

  @override
  String get sessionActionShareWarning => '任何取得此連結的人都能檢視工作階段內容。';

  @override
  String sessionActionShareFailed(String error) {
    return '分享失敗：$error';
  }

  @override
  String get sessionActionStopRequested => '已要求停止回應';

  @override
  String get sessionActionExportMarkdownHint => '適合瀏覽與分享';

  @override
  String get sessionActionExportJsonHint => '保留完整結構化資料';

  @override
  String get sessionActionExportCopiedWeb => '已將匯出內容複製到剪貼簿（Web 不支援儲存本機檔案）';

  @override
  String sessionActionExported(String path) {
    return '已匯出至 $path（路徑已複製）';
  }

  @override
  String sessionActionExportFailed(String error) {
    return '匯出失敗：$error';
  }

  @override
  String get sessionsNoDetail => '暫無工作階段詳細資料';

  @override
  String get sessionsNoDetailDescription => '調整篩選條件後檢視工作階段摘要';

  @override
  String get sessionsAllProjects => '所有專案';

  @override
  String get sessionsProject => '專案';

  @override
  String get sessionsSearchHint => '搜尋標題、預覽或工作目錄…';

  @override
  String get sessionsToday => '今天';

  @override
  String get sessionsThisWeek => '本週';

  @override
  String get sessionsStarred => '已加星號';

  @override
  String get sessionsSortNewest => '時間：新到舊';

  @override
  String get sessionsSortOldest => '時間：舊到新';

  @override
  String get sessionsSortTitle => '標題：A 到 Z';

  @override
  String get sessionsSortMessages => '訊息數：多到少';

  @override
  String get sessionsSortMethod => '排序方式';

  @override
  String get sessionsLoading => '正在載入工作階段…';

  @override
  String get sessionsViewFullDetails => '檢視完整詳細資料';

  @override
  String get sessionsSettings => '設定';

  @override
  String get requestHermesQuestion => 'Hermes 詢問';

  @override
  String get requestPending => '待處理請求';

  @override
  String get requestAlwaysAllowQuestion => '總是允許？';

  @override
  String get requestAlwaysAllowDescription => '這會將該操作寫入設定成為永久允許規則，之後同類操作不再詢問。';

  @override
  String requestAlwaysAllowDetail(String detail) {
    return '這會將「$detail」寫入設定成為永久允許規則，之後同類操作不再詢問。';
  }

  @override
  String get requestNoActiveSession => '沒有作用中的工作階段';

  @override
  String get requestConnectionUnavailable => '請求所屬連線無法使用';

  @override
  String requestRespondFailed(String error) {
    return '回應失敗：$error';
  }

  @override
  String get requestAnswerFailed => '傳送回答失敗，請稍後再試';

  @override
  String get requestMcpNameMissing => '請求未包含 MCP 伺服器名稱';

  @override
  String get requestOAuthTimeout => 'OAuth 授權逾時';

  @override
  String get requestMcpTestFailed => 'MCP 連線測試失敗';

  @override
  String get requestMcpSetupFailed => 'MCP 設定失敗';

  @override
  String requestConfigureMcp(String name) {
    return '設定 $name';
  }

  @override
  String get requestCloseQuestion => '關閉請求？';

  @override
  String get requestCloseDescription => '關閉後此請求無法復原，代理將保持等待。';

  @override
  String get requestProcessed => '已處理';

  @override
  String get requestInteractionProcessed => '互動請求已處理';

  @override
  String requestServer(String name) {
    return '伺服器：$name';
  }

  @override
  String get requestSubmitAllAnswers => '提交所有回答';

  @override
  String get requestConfigureLater => '暫不設定';

  @override
  String get requestConfiguring => '正在設定…';

  @override
  String get requestInstallEnable => '安裝並啟用';

  @override
  String get requestEnterContent => '輸入內容';

  @override
  String get requestEnterText => '輸入…';

  @override
  String requestMorePending(int count) {
    return '還有 $count 個待處理';
  }

  @override
  String get requestAllowOnce => '允許一次';

  @override
  String get requestAllowSession => '本次工作階段允許';

  @override
  String requestSubmitSelected(int count) {
    return '提交（已選 $count）';
  }

  @override
  String get requestCustomAnswer => '其他（自訂回答）';

  @override
  String get requestRecommended => '推薦';

  @override
  String messagingLoadFailed(String error) {
    return '載入訊息平台失敗：$error';
  }

  @override
  String messagingPlatformEnabled(String name) {
    return '$name 已啟用';
  }

  @override
  String messagingPlatformDisabled(String name) {
    return '$name 已停用';
  }

  @override
  String messagingUpdateFailed(String error) {
    return '更新失敗：$error';
  }

  @override
  String messagingTestPassed(String name) {
    return '$name 連線測試通過';
  }

  @override
  String get messagingTestNotPassed => '連線測試未通過';

  @override
  String messagingTestFailed(String error) {
    return '測試失敗：$error';
  }

  @override
  String messagingConfigSaved(String name) {
    return '已儲存 $name 設定，可重新啟動 Gateway 套用連線變更';
  }

  @override
  String messagingSaveFailed(String error) {
    return '儲存失敗：$error';
  }

  @override
  String messagingApproved(String name) {
    return '已核准 $name';
  }

  @override
  String messagingApproveFailed(String error) {
    return '核准失敗：$error';
  }

  @override
  String get messagingRevokeTitle => '撤銷授權';

  @override
  String messagingRevokeQuestion(String name) {
    return '確定撤銷 $name 的訊息存取權？';
  }

  @override
  String get messagingRevoke => '撤銷';

  @override
  String get messagingRevoked => '授權已撤銷';

  @override
  String messagingRevokeFailed(String error) {
    return '撤銷失敗：$error';
  }

  @override
  String get messagingRestartQuestion => '重新啟動 Gateway？';

  @override
  String get messagingRestartWarning =>
      '這會中斷所有連線到此 Gateway 的工作階段和用戶端，完成後會自動重新連線。';

  @override
  String get messagingRestarting => 'Gateway 正在重新啟動';

  @override
  String messagingRestartFailed(String error) {
    return 'Gateway 重新啟動失敗：$error';
  }

  @override
  String get messagingTitle => '訊息平台';

  @override
  String get messagingRestartGateway => '重新啟動 Gateway';

  @override
  String get messagingLoading => '正在讀取訊息平台…';

  @override
  String get messagingPendingApproval => '待核准';

  @override
  String get messagingPlatforms => '平台';

  @override
  String get messagingEmpty => '暫無訊息平台';

  @override
  String get messagingEmptyDescription => '伺服器未回傳可設定的訊息平台';

  @override
  String get messagingAuthorizedUsers => '已授權使用者';

  @override
  String get messagingConfigure => '設定';

  @override
  String get messagingTest => '測試';

  @override
  String get messagingOpenDocs => '開啟文件';

  @override
  String get messagingUnknownUser => '未知使用者';

  @override
  String get messagingApprove => '核准';

  @override
  String get messagingStateDisabled => '已停用';

  @override
  String get messagingStateGatewayStopped => '已設定，Gateway 未執行';

  @override
  String get messagingStateFatal => '嚴重錯誤';

  @override
  String get messagingStateStartupFailed => '啟動失敗';

  @override
  String get messagingStateConfigured => '已設定';

  @override
  String get messagingStateNeedsConfig => '需要設定';

  @override
  String messagingPlatformConfig(String name) {
    return '$name 設定';
  }

  @override
  String get messagingNoEditableConfig => '此平台沒有可編輯的設定項目。';

  @override
  String get messagingAdvancedSettings => '進階設定';

  @override
  String get messagingSetLeaveBlank => '已設定，留空則保持不變';

  @override
  String get messagingEnterNewValue => '輸入新值';

  @override
  String get messagingShow => '顯示';

  @override
  String get messagingClearSavedValue => '清除已儲存的值';

  @override
  String get fileTreeListView => '列表檢視';

  @override
  String get fileTreeTreeView => '樹狀檢視';

  @override
  String get fileTreeAttachToChat => '附加至聊天';

  @override
  String get projectAddFolder => '新增資料夾';

  @override
  String get projectFolderPath => '資料夾路徑';

  @override
  String get projectFolderLabelOptional => '標籤（選填）';

  @override
  String get projectCreate => '建立專案';

  @override
  String get projectLoading => '正在載入專案…';

  @override
  String get projectEmpty => '尚無專案';

  @override
  String get projectEmptyDescription => '建立專案以整理工作目錄與工作階段';

  @override
  String get projectWorkspace => '專案工作區';

  @override
  String get projectEditAppearance => '編輯外觀';

  @override
  String get projectColor => '顏色';

  @override
  String get projectIcon => '圖示';

  @override
  String projectAppearanceSaveFailed(String error) {
    return '無法儲存外觀：$error';
  }

  @override
  String get projectRename => '重新命名';

  @override
  String get projectRenameTitle => '重新命名專案';

  @override
  String get projectName => '專案名稱';

  @override
  String projectRenameFailed(String error) {
    return '無法重新命名專案：$error';
  }

  @override
  String projectDeleteQuestion(String name) {
    return '刪除 $name？';
  }

  @override
  String get projectDeleteDescription => '專案本身會被刪除，但其中的工作階段和檔案不受影響。此操作無法復原。';

  @override
  String projectDeleteFailed(String error) {
    return '無法刪除專案：$error';
  }

  @override
  String projectCreateFailed(String error) {
    return '無法建立專案：$error';
  }

  @override
  String get projectManagement => '專案管理';

  @override
  String get projectLoadFailed => '無法載入專案';

  @override
  String get projectNoMoveTargets => '沒有其他可移動的專案';

  @override
  String get projectNoMoveTargetsDescription => '專案需要設定有效的工作目錄後才能接收工作階段';

  @override
  String get projectNew => '新增專案';

  @override
  String get projectEditTitle => '編輯專案';

  @override
  String get projectPrimaryPath => '主要工作目錄路徑';

  @override
  String get projectPrimaryPathHint => '例如 /home/user/projects/my-app';

  @override
  String get projectDescriptionOptional => '描述（選填）';

  @override
  String get projectRequiredFields => '請填寫專案名稱和工作目錄';

  @override
  String get projectCreated => '專案已建立';

  @override
  String get projectUpdated => '專案已更新';

  @override
  String projectSaveFailed(String error) {
    return '無法儲存專案：$error';
  }

  @override
  String get projectDeleteTitle => '刪除專案？';

  @override
  String projectDeleteNamedDescription(String name) {
    return '專案「$name」將被刪除。關聯的工作階段不會被刪除。';
  }

  @override
  String get projectDeleted => '專案已刪除';

  @override
  String subagentsLoadFailed(String error) {
    return '無法載入子代理：$error';
  }

  @override
  String get subagentsEmpty => '沒有子代理活動';

  @override
  String get subagentsOpenSessionDescription => '開啟工作階段以查看其子代理樹';

  @override
  String get subagentsCurrentSessionEmpty => '目前工作階段沒有執行中的子代理';

  @override
  String get subagentsCurrentSession => '目前工作階段';

  @override
  String subagentsSession(String id) {
    return '工作階段 $id';
  }

  @override
  String subagentsCount(int count) {
    return '$count 個子代理';
  }

  @override
  String subagentsRunningCount(int count) {
    return '執行中 $count';
  }

  @override
  String subagentsFailedCount(int count) {
    return '失敗 $count';
  }

  @override
  String subagentsToolCalls(int count) {
    return '$count 次工具呼叫';
  }

  @override
  String subagentsFiles(int count) {
    return '$count 個檔案';
  }

  @override
  String get subagentsInterrupt => '中斷';

  @override
  String get subagentsInterruptSent => '已傳送中斷訊號';

  @override
  String subagentsInterruptFailed(String error) {
    return '無法中斷子代理：$error';
  }

  @override
  String get subagentsOpenSession => '開啟工作階段';

  @override
  String subagentsOpenSessionFailed(String error) {
    return '無法開啟子代理工作階段：$error';
  }

  @override
  String subagentsCurrentTool(String name) {
    return '工具：$name';
  }

  @override
  String subagentsTools(int count) {
    return '$count 次工具';
  }

  @override
  String subagentsFilesRead(int count) {
    return '讀取 $count';
  }

  @override
  String subagentsFilesWritten(int count) {
    return '寫入 $count';
  }

  @override
  String get subagentsStatusQueued => '排隊中';

  @override
  String get subagentsStatusInterrupted => '已中斷';

  @override
  String get subagentsStatusUnknown => '未知';

  @override
  String credentialsLoadFailed(String error) {
    return '無法載入憑證：$error';
  }

  @override
  String get credentialsSearchHint => '搜尋憑證或提供商…';

  @override
  String get credentialsMissing => '缺少';

  @override
  String get credentialsNoMatches => '沒有符合的憑證';

  @override
  String get credentialsNoMatchesDescription => '調整搜尋條件或狀態篩選';

  @override
  String get credentialsEmpty => '沒有憑證提供商';

  @override
  String get credentialsEmptyDescription => '伺服器未回傳可設定的憑證提供商';

  @override
  String get credentialsGroupCloud => '雲端供應商';

  @override
  String get credentialsGroupModelProviders => '模型提供商';

  @override
  String get credentialsGroupThirdParty => '第三方服務';

  @override
  String get credentialsKeyRequired => '請選擇提供商並輸入 API Key 或 Token';

  @override
  String credentialsSaveFailed(String error) {
    return '無法儲存憑證：$error';
  }

  @override
  String get credentialsAddTitle => '新增憑證';

  @override
  String get credentialsEditTitle => '編輯憑證';

  @override
  String get credentialsSaving => '儲存中…';

  @override
  String credentialsApiKey(String name) {
    return '$name API Key / Token';
  }

  @override
  String get credentialsShowKey => '顯示金鑰';

  @override
  String get credentialsHideKey => '隱藏金鑰';

  @override
  String get petCenterTitle => '寵物中心';

  @override
  String get petRename => '重新命名';

  @override
  String get petDisable => '停用寵物';

  @override
  String petRenameFailed(String error) {
    return '無法重新命名寵物：$error';
  }

  @override
  String petDisableFailed(String error) {
    return '無法停用寵物：$error';
  }

  @override
  String get petRenameTitle => '重新命名寵物';

  @override
  String get petRenameHint => '輸入新名稱…';

  @override
  String get petUntitled => '未命名';

  @override
  String petStatus(String status) {
    return '狀態：$status';
  }

  @override
  String get petGallery => '圖庫';

  @override
  String get petGalleryEmpty => '沒有可用寵物';

  @override
  String get petGenerateNew => '產生新寵物';

  @override
  String get petStateWave => '打招呼';

  @override
  String get petStateJump => '跳躍';

  @override
  String get petStateCelebrate => '慶祝';

  @override
  String credentialsDisconnectQuestion(String name) {
    return '中斷 $name 的連線？';
  }

  @override
  String get credentialsDisconnectDescription =>
      '儲存的憑證將從 Hermes 伺服器移除，之後可重新新增。';

  @override
  String starmapLoadDetailFailed(String error) {
    return '無法讀取節點詳細資料：$error';
  }

  @override
  String get starmapRestoreMine => '還原為我的星圖';

  @override
  String get starmapShareImport => '分享或匯入';

  @override
  String get starmapResetView => '還原視圖';

  @override
  String get starmapLoading => '正在讀取星圖…';

  @override
  String get starmapNoData => '暫無資料';

  @override
  String get starmapEmpty => '星圖為空';

  @override
  String get starmapEmptyDescription => '在 Hermes 中累積更多知識後，節點會出現在此圖中。';

  @override
  String get starmapShareTitle => '分享星圖';

  @override
  String get starmapShareDescription => '複製下方代碼分享星圖，或貼上其他代碼並載入。';

  @override
  String get starmapShareCodeHint => '星圖分享代碼';

  @override
  String get starmapCopy => '複製';

  @override
  String get starmapLoad => '載入';

  @override
  String get starmapInvalidShareCode => '星圖分享代碼無效。';

  @override
  String get starmapPause => '暫停';

  @override
  String get starmapPlay => '播放';

  @override
  String get starmapSkillLegend => '技能';

  @override
  String get starmapMemoryLegend => '記憶';

  @override
  String get starmapChronologyLegend => '中心：最舊 · 外圈：最新';

  @override
  String starmapOpenNode(String name) {
    return '開啟 $name';
  }

  @override
  String get starmapSaved => '已儲存';

  @override
  String starmapSaveFailed(String error) {
    return '無法儲存節點：$error';
  }

  @override
  String get starmapDeleteQuestion => '刪除節點？';

  @override
  String starmapDeleteDescription(String name) {
    return '「$name」將從星圖中移除。';
  }

  @override
  String get starmapDeleted => '節點已刪除';

  @override
  String starmapDeleteFailed(String error) {
    return '無法刪除節點：$error';
  }

  @override
  String starmapUseCount(int count) {
    return '使用 $count 次';
  }

  @override
  String get starmapContent => '內容';

  @override
  String get starmapSaving => '儲存中…';

  @override
  String starmapCreatedBy(Object value) {
    return '建立者：$value';
  }

  @override
  String starmapSource(Object value) {
    return '來源：$value';
  }

  @override
  String get starmapStateArchived => '已封存';

  @override
  String configCenterLoadFailed(String error) {
    return '無法載入能力資料：$error';
  }

  @override
  String get configCenterKnowledgeTab => '知識';

  @override
  String get configCenterTitle => '能力管理';

  @override
  String get configCenterLoadErrorTitle => '無法載入能力';

  @override
  String get configCenterMcpEmptyDescription => '新增 MCP 伺服器以連接外部工具和資料。';

  @override
  String get configCenterUrlOrCommand => 'URL 或命令';

  @override
  String get configCenterTransport => '傳輸方式';

  @override
  String get configCenterLocalStdio => 'Stdio（本機進程）';

  @override
  String configCenterMutationFailed(String error) {
    return '無法套用變更：$error';
  }

  @override
  String get configCenterKnowledgeTitle => '知識來源';

  @override
  String get configCenterKnowledgeEmpty => '暫無知識來源';

  @override
  String get configCenterKnowledgeEmptyDescription => '新增檔案、資料夾或 URL 作為知識來源。';

  @override
  String get configCenterDatabase => '資料庫';

  @override
  String configCenterKnowledgeMeta(String type, int count, String status) {
    return '$type · $count 個區塊 · $status';
  }

  @override
  String get configCenterIndexed => '已索引';

  @override
  String get configCenterNotIndexed => '未索引';

  @override
  String get configCenterSkillsEmpty => '暫無技能';

  @override
  String get configCenterSkillsEmptyDescription => '伺服器未回傳此設定檔的技能。';

  @override
  String get configCenterConfiguration => '設定';

  @override
  String get configCenterInstallPlugin => '安裝外掛程式';

  @override
  String get configCenterPluginsEmpty => '暫無外掛程式';

  @override
  String get configCenterPluginsEmptyDescription => '安裝外掛程式以擴充 Hermes。';

  @override
  String get configCenterInstall => '安裝';

  @override
  String get configCenterPluginUrl => '外掛程式 URL 或識別字';

  @override
  String get fileEditorDiscardQuestion => '放棄未儲存的變更？';

  @override
  String get fileEditorDiscardDescription => '返回將遺失目前的編輯內容。';

  @override
  String get fileEditorKeepEditing => '繼續編輯';

  @override
  String get fileEditorDiscard => '放棄';

  @override
  String get fileEditorDisk => '磁碟';

  @override
  String get fileEditorEditor => '編輯器';

  @override
  String get fileEditorConflictDescription => '磁碟上的檔案已變更。可覆寫儲存、重新載入磁碟版本或取消。';

  @override
  String get fileEditorConflictTitle => '檔案已在外部修改';

  @override
  String get fileEditorOverwriteSave => '覆寫並儲存';

  @override
  String get fileEditorReloaded => '已重新載入磁碟版本';

  @override
  String get fileEditorSaved => '已儲存';

  @override
  String fileEditorSaveFailed(String error) {
    return '無法儲存檔案：$error';
  }

  @override
  String get fileEditorSaving => '儲存中…';

  @override
  String fileEditorUnsavedTitle(String name) {
    return '$name，有未儲存的變更';
  }

  @override
  String get fileEditorEmpty => '（空）';

  @override
  String get fileEditorBinaryTitle => '此檔案無法以文字方式編輯';

  @override
  String get fileEditorBinaryDescription =>
      '這看起來是二進位檔案（圖片、封存檔或執行檔）。用文字編輯器開啟並儲存可能會損毀原始檔案，因此已停用編輯功能——請改為下載到裝置。';

  @override
  String kanbanTaskCreatedLinkFailed(String error) {
    return '任務已建立，但無法新增父任務連結：$error';
  }

  @override
  String get kanbanTaskStatus => '狀態';

  @override
  String get kanbanPriority => '優先順序';

  @override
  String get kanbanAssignee => '負責人';

  @override
  String get kanbanTenant => '租戶';

  @override
  String get kanbanParentTaskId => '父任務 ID';

  @override
  String get kanbanWorkspacePath => '工作區路徑';

  @override
  String get kanbanModelOverride => '指定模型';

  @override
  String get kanbanProviderOverride => '指定提供者';

  @override
  String get kanbanEffort => '推理強度';

  @override
  String get kanbanEffortLow => '低';

  @override
  String get kanbanEffortMedium => '中';

  @override
  String get kanbanEffortHigh => '高';

  @override
  String get kanbanCreatingTask => '正在建立任務…';

  @override
  String get kanbanCreateTask => '建立任務';

  @override
  String get kanbanCreateBoard => '建立看板';

  @override
  String get kanbanBoardSettings => '看板設定';

  @override
  String get kanbanProject => '專案';

  @override
  String get kanbanNoProject => '不綁定專案';

  @override
  String get kanbanDeleteBoardQuestion => '刪除看板？';

  @override
  String kanbanDeleteBoardDescription(String name) {
    return '將刪除 $name，此操作無法復原。';
  }

  @override
  String kanbanBoardTaskCount(int count) {
    return '$count 個任務';
  }

  @override
  String kanbanBoardTaskCountProject(int count, String project) {
    return '$count 個任務 · $project';
  }

  @override
  String get kanbanRenameBoard => '重新命名看板';

  @override
  String pluginsOperationFailed(String error) {
    return '無法更新外掛程式：$error';
  }

  @override
  String get pluginsInstallTitle => '安裝 Agent 外掛程式';

  @override
  String get pluginsIdentifierHint => 'Git URL 或 owner/repo';

  @override
  String get pluginsEnableAfterInstall => '安裝後啟用';

  @override
  String get pluginsForceReinstall => '強制重新安裝';

  @override
  String pluginsInstalled(String name) {
    return '已安裝 $name';
  }

  @override
  String pluginsInstallFailed(String error) {
    return '無法安裝外掛程式：$error';
  }

  @override
  String get pluginsLoading => '正在載入外掛程式…';

  @override
  String get pluginsNoData => '暫無外掛程式資料';

  @override
  String pluginsSearchHint(int count) {
    return '搜尋 $count 個外掛程式…';
  }

  @override
  String get pluginsNoMatches => '沒有符合的外掛程式';

  @override
  String get pluginsKindPlatform => '平台';

  @override
  String get pluginsKindProvider => '提供者';

  @override
  String get pluginsKindTool => '工具';

  @override
  String pluginsContributionTooltip(String area, String description) {
    return '$area · $description';
  }

  @override
  String pluginsActionExecuted(String title) {
    return '$title 已執行';
  }

  @override
  String get pluginsAreaNavigation => '導覽';

  @override
  String get pluginsAreaCommand => '命令';

  @override
  String get pluginsAreaSettings => '設定';

  @override
  String get pluginsAreaComposer => '輸入器';

  @override
  String get pluginsAreaDetail => '詳細資料';

  @override
  String get pluginsAreaTranscript => '對話記錄';

  @override
  String get pluginsAreaPane => '面板';

  @override
  String knowledgeLoadDetailFailed(String error) {
    return '無法讀取節點詳細資料：$error';
  }

  @override
  String get knowledgeLoading => '正在載入知識圖譜…';

  @override
  String get knowledgeNoData => '暫無知識資料';

  @override
  String get knowledgeSearchHint => '搜尋知識節點…';

  @override
  String knowledgeMemorySummary(int count) {
    return '記憶摘要（$count）';
  }

  @override
  String get knowledgeNoMatches => '沒有符合的知識節點';

  @override
  String get knowledgeStateActive => '活躍';

  @override
  String get knowledgeStateInactive => '未啟用';

  @override
  String knowledgeNodeMeta(String category, int count, String state) {
    return '$category · 使用 $count 次 · $state';
  }

  @override
  String knowledgeNodeMetaNoCategory(int count, String state) {
    return '使用 $count 次 · $state';
  }

  @override
  String get knowledgeSaved => '已儲存';

  @override
  String knowledgeSaveFailed(String error) {
    return '無法儲存節點：$error';
  }

  @override
  String get knowledgeDeleteQuestion => '刪除知識節點？';

  @override
  String knowledgeDeleteDescription(String name) {
    return '將刪除「$name」。此操作無法復原。';
  }

  @override
  String get knowledgeDeleted => '知識節點已刪除';

  @override
  String knowledgeDeleteFailed(String error) {
    return '無法刪除節點：$error';
  }

  @override
  String get knowledgeCancelEditing => '取消編輯';

  @override
  String skillHubSearchFailed(String error) {
    return '搜尋技能失敗：$error';
  }

  @override
  String skillHubExitCode(int code) {
    return '操作退出碼 $code';
  }

  @override
  String get skillHubActionTimeout => '技能操作已逾時。';

  @override
  String get skillHubActionDone => '操作完成';

  @override
  String skillHubActionFailed(String error) {
    return '技能操作失敗：$error';
  }

  @override
  String skillHubUninstallQuestion(String name) {
    return '卸載「$name」？';
  }

  @override
  String get skillHubUninstallDescription => '該技能將被移除，可隨時重新安裝。';

  @override
  String get skillHubUninstall => '卸載';

  @override
  String get skillHubUpdateInstalled => '更新已安裝技能';

  @override
  String get skillHubSearchHint => '搜尋技能市場…';

  @override
  String get skillHubLoading => '正在載入技能市場…';

  @override
  String skillHubSourcesTimedOut(String sources) {
    return '部分來源逾時，未包含在結果中：$sources';
  }

  @override
  String get skillHubNoData => '暫無市場資料';

  @override
  String get skillHubSources => '來源';

  @override
  String skillHubRateLimited(String name) {
    return '$name（限流）';
  }

  @override
  String get skillHubIndexUnavailable => '技能索引目前不可用，搜尋結果可能不完整。';

  @override
  String get skillHubFeatured => '精選';

  @override
  String get skillHubSearchPrompt => '輸入關鍵字搜尋技能';

  @override
  String get skillHubInstalled => '已安裝';

  @override
  String get skillHubTrustOfficial => '官方';

  @override
  String get skillHubTrustTrusted => '可信';

  @override
  String get skillHubTrustCommunity => '社群';

  @override
  String get skillHubTrustUnverified => '未驗證';

  @override
  String get skillHubTrustUntrusted => '不可信';

  @override
  String get skillHubTrustUnknown => '未知信任等級';

  @override
  String newSessionInitFailed(String error) {
    return '部分工作階段選項載入失敗：$error';
  }

  @override
  String newSessionStartFailed(String error) {
    return '無法啟動工作階段：$error';
  }

  @override
  String get newSessionTitleSection => '工作階段標題';

  @override
  String get newSessionTitleHint => '選填，留空將自動產生';

  @override
  String get newSessionWorkspace => '工作區';

  @override
  String get newSessionWorkspaceHint => 'Agent 在伺服器上的工作目錄';

  @override
  String get newSessionBrowseDirectory => '瀏覽目錄';

  @override
  String get newSessionNoProject => '不歸入專案';

  @override
  String get newSessionMoveLater => '稍後可從工作階段選單移動';

  @override
  String get newSessionUseCurrentModel => '使用目前模型';

  @override
  String get newSessionAgent => 'Agent';

  @override
  String get newSessionStarting => '啟動中…';

  @override
  String get newSessionStart => '開始工作階段';

  @override
  String newSessionAgentSummary(String model, String cwd) {
    return '$model · $cwd';
  }

  @override
  String get newSessionCurrentModel => '目前模型';

  @override
  String get newSessionWorkspaceAbove => '工作目錄如上';

  @override
  String get newSessionParentDirectory => '上一層';

  @override
  String get artifactsTitle => '工件';

  @override
  String get artifactsSearchHint => '搜尋工件標題和工作階段…';

  @override
  String get artifactsKindCode => '程式碼';

  @override
  String get artifactsKindImage => '圖片';

  @override
  String get artifactsKindLink => '連結';

  @override
  String get artifactsEmpty => '沒有工件';

  @override
  String get artifactsEmptyDescription => '工作階段產生的工件會顯示在這裡。';

  @override
  String get artifactsNoMatches => '沒有相符的工件';

  @override
  String get artifactsNoMatchesDescription => '請嘗試其他搜尋條件或篩選器。';

  @override
  String artifactsOpen(String name) {
    return '開啟工件 $name';
  }

  @override
  String get artifactsSaved => '已儲存';

  @override
  String artifactsSaveFailed(String error) {
    return '無法儲存工件：$error';
  }

  @override
  String get artifactsSaveToDevice => '儲存到裝置';

  @override
  String get artifactsCopy => '複製工件';

  @override
  String get artifactsOpenLink => '開啟連結';

  @override
  String get artifactsOpenLinkFailed => '無法開啟連結。';

  @override
  String get artifactsImageLoadFailed => '圖片無法載入';

  @override
  String get shellReconnecting => '已中斷連線，正在重新連線…';

  @override
  String get shellReconnectNow => '立即重新連線';

  @override
  String get shellCollapseNavigation => '摺疊導覽';

  @override
  String get shellExpandNavigation => '展開導覽';

  @override
  String get shellNavigation => '導覽';

  @override
  String get shellSessionArea => '工作階段';

  @override
  String get shellWorkspaceArea => '工作區';

  @override
  String get shellIntelligenceArea => '智慧功能';

  @override
  String shellModelStatus(String value) {
    return '模型 $value';
  }

  @override
  String shellWorkspaceStatus(String value) {
    return '工作區 $value';
  }

  @override
  String shellAgentStatus(String value) {
    return 'Agent $value';
  }

  @override
  String get gitListView => '列表檢視';

  @override
  String get gitTreeView => '樹狀檢視';

  @override
  String get gitViewPr => '檢視 PR';

  @override
  String gitChangeCounts(int staged, int changed) {
    return '已暫存 $staged · 已變更 $changed';
  }

  @override
  String get gitWorkingTreeCleanDescription => '沒有未提交的變更。';

  @override
  String get gitStagedSection => '已暫存';

  @override
  String get gitUnstagedSection => '未暫存';

  @override
  String get gitOpenPrFailed => '無法開啟提取要求。';

  @override
  String gitUnstageFailed(String error) {
    return '取消暫存失敗：$error';
  }

  @override
  String get gitCommitAndPushSucceeded => '已提交並推送';

  @override
  String get gitCommitSucceeded => '已提交';

  @override
  String get gitStatusAdded => '新';

  @override
  String get gitStatusModified => '改';

  @override
  String get gitStatusDeleted => '刪';

  @override
  String get gitStatusRenamed => '移';

  @override
  String get gitStatusConflict => '衝';

  @override
  String get insightsTitle => '洞察分析';

  @override
  String insightsDays(int count) {
    return '$count 天';
  }

  @override
  String insightsLoading(int count) {
    return '正在統計最近 $count 天…';
  }

  @override
  String get insightsNoData => '暫無用量資料';

  @override
  String get insightsOverview => '總覽';

  @override
  String get insightsSessions => '工作階段';

  @override
  String get insightsApiCalls => 'API 呼叫';

  @override
  String get insightsCost => '成本';

  @override
  String get insightsDailyUsage => '每日用量';

  @override
  String get insightsModelUsage => '模型用量';

  @override
  String get insightsToolCalls => '工具呼叫';

  @override
  String get insightsUnknownProvider => '未知供應商';

  @override
  String insightsModelSummary(String tokens, int sessions, String cost) {
    return '$tokens Token · $sessions 個工作階段 · \$$cost';
  }

  @override
  String webhookBaseUrl(String url) {
    return '基礎 URL：$url';
  }

  @override
  String get webhookUrl => 'URL';

  @override
  String get webhookSecret => '密鑰';

  @override
  String get toolsTitle => '工具集';

  @override
  String get toolsEmpty => '暫無工具集';

  @override
  String toolsToolsetSummary(int count, String status) {
    return '$count 個工具 · $status';
  }

  @override
  String get toolsTerminalBackend => '終端執行環境';

  @override
  String get toolsReady => '已就緒';

  @override
  String get toolsNeedsSetup => '需要設定';

  @override
  String get toolsUnavailable => '不可用';

  @override
  String toolsBackendSwitchFailed(String error) {
    return '切換終端執行環境失敗：$error';
  }

  @override
  String get toolsComputerUseUnsupported => '此後端平台不支援';

  @override
  String get toolsComputerUseNotInstalled => '未安裝 cua-driver';

  @override
  String get toolsComputerUseReady => 'Computer Use 已就緒';

  @override
  String get toolsComputerUseNotReady => '驅動程式或權限尚未就緒';

  @override
  String get toolsRecheck => '重新檢查';

  @override
  String get toolsCheck => '檢查';

  @override
  String toolsCheckResult(String label, String result) {
    return '$label：$result';
  }

  @override
  String get toolsWaitingForPermission => '等待後端授權…';

  @override
  String get toolsRequestPermission => '請求後端系統權限';

  @override
  String get toolsPermissionTimeout => '系統權限請求已逾時。';

  @override
  String toolsPermissionFailed(String error) {
    return '請求系統權限失敗：$error';
  }

  @override
  String toolsToggleFailed(String error) {
    return '切換工具集失敗：$error';
  }

  @override
  String get agentBotsTitle => 'Bots';

  @override
  String agentRequestSummary(String title, String member) {
    return '$title · $member';
  }

  @override
  String modelPickerRefreshFailed(String error) {
    return '重新整理模型失敗：$error';
  }

  @override
  String get modelPickerEdit => '編輯可見模型';

  @override
  String modelPickerVisibilitySaveFailed(String error) {
    return '儲存模型可見性失敗：$error';
  }

  @override
  String get modelPickerMoaPresets => 'MoA 預設';

  @override
  String modelPickerMoaModel(String model) {
    return 'MoA：$model';
  }

  @override
  String get modelPickerRefresh => '重新整理模型';

  @override
  String get modelPickerFree => '免費';

  @override
  String modelPickerFreeDiscount(num percent) {
    return '免費 · -$percent%';
  }

  @override
  String modelPickerPricing(String input, String output, String discount) {
    return '輸入 $input / 輸出 $output$discount';
  }

  @override
  String get modelPickerSelectNone => '全部不選';

  @override
  String get modelPickerSelectAll => '全選';

  @override
  String get commonCopy => '複製';

  @override
  String get chatMermaidDiagram => 'Mermaid 圖表';

  @override
  String chatArtifactTitle(String language) {
    return '$language 工件';
  }

  @override
  String chatCodeArtifactTitle(String language, int count) {
    return '$language 程式碼 · $count 行';
  }

  @override
  String get chatArtifactPreview => '工件預覽';

  @override
  String chatCodeTitle(String language) {
    return '$language 程式碼';
  }

  @override
  String get chatCodeCopied => '程式碼已複製';

  @override
  String get chatLivePreview => '即時預覽';

  @override
  String get chatExpandPreview => '在訊息中展開預覽';

  @override
  String get chatAudioPlaybackFailed => '音訊播放失敗';

  @override
  String get chatPauseAudio => '暫停音訊';

  @override
  String get chatPlayAudio => '播放音訊';

  @override
  String get chatOpenVideo => '影片 · 點一下開啟';

  @override
  String get chatOpenFile => '檔案 · 點一下開啟';

  @override
  String imageSaveFailed(String error) {
    return '儲存圖片失敗：$error';
  }

  @override
  String get voiceMenu => '語音選單';

  @override
  String get voiceStopRecording => '停止錄音';

  @override
  String get voiceDictation => '語音輸入';

  @override
  String get voiceContinuousConversation => '連續語音對話';

  @override
  String get voiceAutoReadReplies => '自動朗讀回覆';

  @override
  String get voiceWakeWord => '喚醒詞';

  @override
  String voiceWakePhrase(String phrase) {
    return '「$phrase」';
  }

  @override
  String get voiceStopSpeaking => '停止朗讀';

  @override
  String get voiceWakeEnabling => '正在啟用喚醒詞…';

  @override
  String get voiceWakeTriggered => '已喚醒，正在聆聽…';

  @override
  String get voiceWakeListening => '正在監聽喚醒詞';

  @override
  String voiceWakeListeningFor(String phrase) {
    return '正在監聽「$phrase」';
  }

  @override
  String get voiceWakeWaiting => '喚醒詞等待恢復';

  @override
  String get voiceWakeDisabled => '喚醒詞已關閉';

  @override
  String sessionPrBadge(int number, String status) {
    return 'PR #$number · $status';
  }

  @override
  String get sessionPrOpenFailed => '無法開啟提取要求。';

  @override
  String get sessionCliBadge => 'CLI 工作階段';

  @override
  String get sessionDraftBadge => '有未傳送的草稿';

  @override
  String get sessionSharedBadge => '已分享';

  @override
  String get sessionHandedOff => '已交接';

  @override
  String sessionHandedOffTo(String platform) {
    return '已交接 · $platform';
  }

  @override
  String sessionHandoffErrorBadge(String error) {
    return '交接異常 · $error';
  }

  @override
  String sessionCompressionErrorBadge(String error) {
    return '上下文壓縮暫時失敗 · $error';
  }

  @override
  String sessionEndedWithReason(String reason) {
    return '已結束 · $reason';
  }

  @override
  String get sessionEnded => '已結束';

  @override
  String toolGroupHiddenRestore(int count) {
    return '已隱藏 $count 個工具，點一下恢復';
  }

  @override
  String backgroundStopFailed(String error) {
    return '停止程序失敗：$error';
  }

  @override
  String get backgroundProcessRemoved => '該程序已結束並被移除';

  @override
  String get backgroundCloseAndHide => '關閉並隱藏';

  @override
  String get mcpLogsEmpty => '暫無日誌';

  @override
  String get subagentTaskProgress => '任務進度';

  @override
  String get cloudDiscoverAgain => '重新探索';

  @override
  String get cloudPortalLoginPrompt => '請在下方完成 Portal 登入，登入後將自動探索 Agent。';

  @override
  String get backgroundTerminal => '背景終端機';

  @override
  String get backgroundWaitingOutput => '正在等待輸出…';

  @override
  String get backgroundStopping => '正在停止…';

  @override
  String get backgroundStopProcess => '停止程序';

  @override
  String get markdownAlertTip => '提示';

  @override
  String get markdownAlertImportant => '重要';

  @override
  String get markdownAlertWarning => '警告';

  @override
  String get markdownAlertCaution => '注意';

  @override
  String get markdownAlertNote => '備註';

  @override
  String get richLinkMaps => '地圖';

  @override
  String turnActivityTools(int count) {
    return '$count 個工具';
  }

  @override
  String turnActivityReasoning(int count) {
    return '$count 段思考';
  }

  @override
  String toolGroupFailed(int count) {
    return '$count 個失敗';
  }

  @override
  String get messageSourceDingtalk => '釘釘';

  @override
  String get profileScopeApplyTo => '套用至';

  @override
  String profileScopeChangesApplyTo(String profile) {
    return '此頁面的變更將套用至 $profile 設定檔。';
  }

  @override
  String get profileScopeConfiguring => '設定對象';

  @override
  String profileScopeCurrent(String name) {
    return '$name（目前）';
  }

  @override
  String get mcpLogsAllServers => '所有伺服器';

  @override
  String get mcpLogsLoading => '正在讀取日誌…';

  @override
  String badgeUnreadCount(String count) {
    return '$count 則未讀';
  }

  @override
  String progressPercent(int percent) {
    return '進度 $percent%';
  }

  @override
  String avatarNamed(String name) {
    return '頭像：$name';
  }

  @override
  String get avatarUnnamed => '頭像';

  @override
  String get thinkingActive => '正在思考';

  @override
  String get thinkingProcess => '思考過程';

  @override
  String get thinkingBriefly => '已思考片刻';

  @override
  String thinkingSeconds(String seconds) {
    return '已思考 $seconds 秒';
  }

  @override
  String thinkingMinutes(int minutes, int seconds) {
    return '已思考 $minutes 分 $seconds 秒';
  }

  @override
  String thinkingGeneratedCharacters(int count) {
    return '已產生 $count 字';
  }

  @override
  String thinkingCharacters(int count) {
    return '$count 字';
  }

  @override
  String get thinkingAnalyzing => '正在分析上下文…';

  @override
  String get commonNoData => '暫無資料';

  @override
  String get commonFeatureDisabled => '功能未啟用';

  @override
  String get cloudDiscoveryFailed => 'Cloud 探索失敗';

  @override
  String cloudDiscoveryInvalidData(String error) {
    return 'Cloud 傳回無法辨識的資料：$error';
  }

  @override
  String get cloudDiscoveryUnsupported => '目前平台不支援 Hermes Cloud 探索';

  @override
  String sessionCreateFailed(String error) {
    return '建立工作階段失敗：$error';
  }

  @override
  String get statusReady => '已就緒';

  @override
  String get workspaceDescription => '工作階段圖塊與外掛窗格';

  @override
  String get subagentFallbackName => '子代理';

  @override
  String get subagentNoTask => '未提供任務說明';

  @override
  String get subagentsStatusRunning => '執行中';

  @override
  String get subagentsStatusCompleted => '已完成';

  @override
  String get subagentsStatusFailed => '失敗';

  @override
  String subagentCardTitle(String name) {
    return '子代理 · $name';
  }

  @override
  String get subagentTask => '任務';

  @override
  String get subagentModel => '模型';

  @override
  String get subagentCurrentTool => '目前工具';

  @override
  String get subagentSummary => '執行摘要';

  @override
  String sessionApiCallCount(int count) {
    return '$count 次 API 呼叫';
  }

  @override
  String sessionTokenCount(String count) {
    return '$count Token';
  }

  @override
  String get diagnosticsConsentDescription =>
      '將上傳已去識別化的伺服器紀錄、系統與 Provider 設定。紀錄可能包含對話內容、工具輸出和檔案路徑；不會上傳 API Key，診斷套件會在 14 天後刪除。';

  @override
  String get diagnosticsApproveUpload => '同意並上傳';

  @override
  String get diagnosticsGatewayUnavailable => '尚未連線至 Hermes Gateway';

  @override
  String get diagnosticsUploadFailed => '上傳失敗';

  @override
  String get diagnosticsSentTitle => '診斷資訊已傳送';

  @override
  String get diagnosticsLinkCopied => '檢視連結已複製到剪貼簿：';

  @override
  String get diagnosticsSupportPrompt => '如需進一步協助，請透過以下管道聯絡我們：';

  @override
  String diagnosticsSendFailed(String error) {
    return '無法傳送診斷資訊：$error';
  }

  @override
  String get slashDescRetry => '重新產生上一則回覆';

  @override
  String get slashDescClear => '清除目前工作階段畫面';

  @override
  String get slashDescUndo => '復原上一個完整回合';

  @override
  String get slashDescSteer => '將引導訊息加入目前回合';

  @override
  String get slashDescStatus => '檢視工作階段狀態';

  @override
  String get slashDescTitle => '重新產生工作階段標題';

  @override
  String get slashDescNew => '開始新工作階段';

  @override
  String get slashDescYolo => '切換 YOLO 自動核准';

  @override
  String get slashDescHandoff => '開啟工作階段交接';

  @override
  String get slashDescProfile => '選擇設定檔或人格';

  @override
  String get slashDescHelp => '列出本機與目錄中的斜線命令';

  @override
  String get slashDescBackground => '提交背景任務';

  @override
  String get slashDescCompress => '壓縮目前工作階段上下文';

  @override
  String get slashDescQueue => '將訊息加入傳送佇列';

  @override
  String get slashDescUsage => '檢視此工作階段用量';

  @override
  String get slashDescVersion => '顯示 Hermes 與行動版版本';

  @override
  String get slashDescStop => '中止目前回合';

  @override
  String get slashDescTools => '開啟工具設定';

  @override
  String get slashDescApprovals => '設定核准模式：manual / smart / off';

  @override
  String get slashDescModel => '開啟模型選擇器';

  @override
  String get slashDescWake => '管理喚醒詞：status / on / off / toggle';

  @override
  String get slashDescSkinUnavailable => '僅桌面版支援的外觀命令';

  @override
  String get slashDescBrowserUnavailable => '僅桌面版支援的內建瀏覽器命令';

  @override
  String get slashDescJourney => '開啟星圖旅程';

  @override
  String get slashDescPet => '開啟寵物中心';

  @override
  String get slashDescHatch => '產生並孵化新寵物';

  @override
  String get slashDescSave => '儲存目前工作階段記錄';

  @override
  String get slashDescReloadConfigUnavailable =>
      '行動版與 Gateway 均不支援 reload-config';

  @override
  String get cronSuggestionPrefix => '將此內容設為排程任務：';

  @override
  String get kanbanTaskCompletedNotification => '看板任務已完成';

  @override
  String get kanbanTaskProblemNotification => '看板任務異常';

  @override
  String get themeGraphite => '石墨';

  @override
  String get themeIndigo => '靛藍';

  @override
  String get themeMoss => '苔綠';

  @override
  String get themeDune => '暖沙';

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
  String get toolEmptyList => '（空列表）';

  @override
  String toolItemCount(int count) {
    return '$count 項';
  }

  @override
  String toolFieldCount(int count) {
    return '$count 個欄位';
  }

  @override
  String get toolPath => '路徑';

  @override
  String get toolLanguage => '語言';

  @override
  String get toolText => '文字';

  @override
  String get toolMessage => '訊息';

  @override
  String get toolSummary => '摘要';

  @override
  String get toolExecuteCommand => '執行命令';

  @override
  String get toolRunCode => '執行程式碼';

  @override
  String toolRunCodeLanguage(String language) {
    return '執行 $language 程式碼';
  }

  @override
  String toolSearchFor(String query) {
    return '搜尋：$query';
  }

  @override
  String get toolExtractWeb => '擷取網頁';

  @override
  String get toolApplyPatch => '套用檔案補丁';

  @override
  String get toolListFiles => '列出檔案';

  @override
  String get toolGenerateImage => '產生圖片';

  @override
  String get toolDelegateTask => '委派任務';

  @override
  String toolTask(int index) {
    return '任務 $index';
  }

  @override
  String toolRunEditingFiles(int count) {
    return '正在編輯 $count 個檔案';
  }

  @override
  String toolRunExploringFiles(int count) {
    return '正在瀏覽 $count 個檔案';
  }

  @override
  String toolRunRunningCommands(int count) {
    return '正在執行 $count 個命令';
  }

  @override
  String toolRunDelegatingTasks(int count) {
    return '正在委派 $count 個任務';
  }

  @override
  String toolRunUsingTools(int count) {
    return '正在使用 $count 個工具';
  }

  @override
  String toolRunEditedFiles(int count) {
    return '已編輯 $count 個檔案';
  }

  @override
  String toolRunExploredFiles(int count) {
    return '已瀏覽 $count 個檔案';
  }

  @override
  String toolRunRanCommands(int count) {
    return '已執行 $count 個命令';
  }

  @override
  String toolRunDelegatedTasks(int count) {
    return '已委派 $count 個任務';
  }

  @override
  String toolRunUsedTools(int count) {
    return '已使用 $count 個工具';
  }

  @override
  String get notificationBackgroundCompleted => '背景任務完成';

  @override
  String get notificationBackgroundCompletedBody => '一個背景任務已完成，點一下查看結果。';

  @override
  String get notificationApprovalRequired => '等待授權';

  @override
  String get notificationApprovalRequiredBody => 'Agent 請求授權一個敏感操作。';

  @override
  String get voiceServerDisconnected => '尚未連線至伺服器';

  @override
  String get voiceRecordingUnsupported => '目前平台不支援麥克風錄音';

  @override
  String get voiceMicrophoneStartFailed => '麥克風權限遭拒或無法開始錄音';

  @override
  String voiceRecordingFailed(String error) {
    return '錄音失敗：$error';
  }

  @override
  String get voiceNoSpeech => '沒有聽清楚，請再說一次。';

  @override
  String get voiceSttUnavailable => '伺服器未設定語音轉文字（STT）';

  @override
  String voiceTranscriptionFailed(String error) {
    return '轉文字失敗：$error';
  }

  @override
  String voiceSpeechFailed(String error) {
    return '語音播放失敗：$error';
  }

  @override
  String voiceStreamingSpeechFailed(String error) {
    return '串流語音播放失敗：$error';
  }

  @override
  String get voiceWakeInstallNotice => '正在啟用，首次使用可能需要安裝偵測引擎。';

  @override
  String get voiceWakeUsage => '用法：/wake [status|on|off|toggle]';

  @override
  String get voiceWakeNotEnabled => '尚未啟用喚醒詞';

  @override
  String get voiceWakeOtherSurface => '喚醒詞已指定給其他裝置';

  @override
  String get voiceWakeOwned => '另一個裝置正在監聽喚醒詞';

  @override
  String get voiceWakeUnavailable => '目前後端不支援喚醒詞';

  @override
  String voiceWakeMicInterrupted(String error) {
    return '喚醒詞麥克風中斷：$error';
  }

  @override
  String get voiceWakeMicPermission => '麥克風權限遭拒，無法監聽喚醒詞';

  @override
  String voiceWakeMicStartFailed(String error) {
    return '無法啟動喚醒詞麥克風：$error';
  }

  @override
  String voiceWakeAudioUploadFailed(String error) {
    return '無法傳送喚醒詞音訊：$error';
  }

  @override
  String get filesThisComputer => '這台電腦';

  @override
  String get billingSavedPaymentMethod => '已儲存的付款方式';

  @override
  String billingPaymentMethodKind(String kind) {
    return '付款方式 · $kind';
  }

  @override
  String get previewTourBack => '上一步';

  @override
  String get previewTourDone => '完成';

  @override
  String get previewTourNext => '下一步';

  @override
  String get chatMermaidParseError => '無法解析 Mermaid 圖表';

  @override
  String get petDefaultName => 'Hermes 寵物';

  @override
  String get sessionDetailProfile => '設定檔';

  @override
  String get profileArchiveType => 'Hermes 設定檔';

  @override
  String get profilesTemperature => '溫度';

  @override
  String get profilesTopP => 'Top P';

  @override
  String get profilesMaxTokens => '最大 Token 數';

  @override
  String get sessionDesktopFallback => '桌面工作階段';

  @override
  String get backgroundProcessFallback => '背景程序';

  @override
  String get insightsUnknownModel => '未知模型';

  @override
  String get billingCard => '信用卡';

  @override
  String get billingLink => 'Link';

  @override
  String get slashGroupSkills => '技能';

  @override
  String get slashGroupCommands => '命令';

  @override
  String get botAuthorYou => '你';

  @override
  String get botAuthorSystem => '系統';

  @override
  String get botAuthorFallback => 'Bot';

  @override
  String terminalErrorMessage(String error) {
    return '終端機錯誤：$error';
  }

  @override
  String sessionCopyTitle(String title) {
    return '$title（副本）';
  }

  @override
  String get gitRemoteFallback => '遠端儲存庫';

  @override
  String get gitStashFallback => '暫存項';

  @override
  String get notificationChannelErrors => '錯誤';

  @override
  String get notificationChannelWarnings => '警告';

  @override
  String get notificationChannelSuccess => '成功';

  @override
  String get notificationChannelApprovals => '核准';

  @override
  String get notificationChannelInfo => '資訊';

  @override
  String get memoryCuratorTitle => '內容整理器';

  @override
  String get messageSourceServer => '伺服器';

  @override
  String get messageSourceMobile => '行動端';

  @override
  String get kanbanRunQueued => '排隊中';

  @override
  String get kanbanRunCompleted => '已完成';

  @override
  String get kanbanRunFailed => '失敗';

  @override
  String get kanbanRunCancelled => '已取消';

  @override
  String get kanbanEventTaskCreated => '任務已建立';

  @override
  String get kanbanEventTaskUpdated => '任務已更新';

  @override
  String get kanbanEventTaskDeleted => '任務已刪除';

  @override
  String get kanbanEventRunStarted => '執行已開始';

  @override
  String get kanbanEventRunCompleted => '執行已完成';

  @override
  String get kanbanEventRunFailed => '執行失敗';

  @override
  String get kanbanEventRunCancelled => '執行已取消';

  @override
  String get kanbanEventCommentCreated => '已新增留言';

  @override
  String get kanbanEventAttachmentAdded => '已新增附件';

  @override
  String get kanbanEventAttachmentDeleted => '已刪除附件';

  @override
  String get cloudRoleOwner => '擁有者';

  @override
  String get cloudRoleAdmin => '管理員';

  @override
  String get cloudRoleMember => '成員';

  @override
  String get cloudRoleViewer => '檢視者';

  @override
  String get chatStatusToolDrafting => '正在準備工具呼叫';

  @override
  String get chatStatusProvider => '供應商狀態';

  @override
  String get previewScriptError => '指令碼錯誤';

  @override
  String get previewUnhandledPromiseRejection => '未處理的 Promise 拒絕：';

  @override
  String botGroupSessionTitle(String roomId) {
    return '群組：$roomId';
  }

  @override
  String get errorExpectedObjectResponse => '伺服器傳回了無效的物件回應';

  @override
  String get errorTtsNoAudio => '文字轉語音未傳回音訊';

  @override
  String get errorInvalidDataUrl => '伺服器傳回了無效的資料 URL';

  @override
  String get errorExportDirectoryMissing => '伺服器未提供匯出目錄';

  @override
  String get errorImportDirectoryMissing => '伺服器未提供匯入目錄';

  @override
  String get errorRawConfigInvalid => '伺服器傳回了無效的原始設定';

  @override
  String get errorPluginToggleRejected => '後端拒絕了外掛程式變更';

  @override
  String get errorConnectionNotConfigured => '連線尚未設定';

  @override
  String errorSessionOwnerUnknown(String sessionId) {
    return '工作階段擁有者未知：$sessionId';
  }

  @override
  String get errorRemotePushUnavailable => '此連線不支援遠端推送';

  @override
  String get sshCommandTimedOut => 'SSH 命令逾時';

  @override
  String get sshRemoteHomeUnsafe => '遠端 Hermes 主目錄不安全';

  @override
  String get sshOwnershipVerificationFailed => '無法驗證遠端 Hermes 程序的擁有權';

  @override
  String sshOwnershipProbeFailed(String status) {
    return '遠端擁有權探測失敗（$status）';
  }

  @override
  String get sshHelperInvalidJson => '遠端輔助程式傳回了無效 JSON';

  @override
  String get sshWindowsOwnershipVerificationFailed => '無法驗證遠端 Windows 程序的擁有權';

  @override
  String get sshRemotePathInvalid => '遠端 Hermes 路徑必須是絕對路徑或以 ~/ 開頭';

  @override
  String get sshExecutableNotFound => '在遠端主機找不到設定的 Hermes 執行檔';

  @override
  String get sshHermesNotInstalled => '遠端主機未安裝 Hermes';

  @override
  String get sshBootstrapFlagsUnsupported => '遠端 Hermes 必須支援安全 SSH 擁有權啟動參數';

  @override
  String get sshWindowsIdentityInvalid => '遠端 Windows 後端傳回了無效身分';

  @override
  String get sshWindowsExitedBeforeReady => '遠端 Windows 後端在就緒前結束';

  @override
  String get sshWindowsOwnershipProofFailed => '遠端 Windows 擁有權證明失敗';

  @override
  String get sshProcessIdMissing => '遠端 Hermes 未傳回程序 ID';

  @override
  String get sshExitedBeforeReady => '遠端 Hermes 在就緒前結束';

  @override
  String get sshOwnershipProofFailed => '遠端 Hermes 擁有權證明失敗';

  @override
  String get errorSessionBranchIdMissing => 'Hermes 未傳回分支工作階段的持久 ID';

  @override
  String get errorDuplicateImportFailed => 'Hermes 未能匯入複製的工作階段';

  @override
  String get errorSessionNoTitleableMessages => '工作階段中沒有可用於產生標題的訊息';

  @override
  String get errorTitleGeneratorEmpty => '標題產生器傳回了空標題';

  @override
  String get errorProjectIdRequired => '請選擇專案';

  @override
  String get errorProjectWorkingFolderMissing => '目標專案沒有工作目錄';

  @override
  String get errorDownloadFailed => '下載失敗';

  @override
  String get errorMessagingPlatformNotFound => '找不到訊息平台';

  @override
  String errorBotGroupSessionStartFailed(String name) {
    return '$name 的群組工作階段未能啟動';
  }

  @override
  String sshRemoteCommandFailed(String code) {
    return '遠端命令失敗（$code）';
  }

  @override
  String get sshHostAndUserRequired => 'SSH 主機和使用者不能為空';

  @override
  String get sshPortInvalid => 'SSH 連接埠必須介於 1 到 65535 之間';

  @override
  String sshHostKeyChanged(String host, String expected, String received) {
    return '$host 的 SSH 主機金鑰已變更。預期為 $expected，實際為 $received';
  }

  @override
  String get sshProfileInvalid => '遠端設定檔名稱無效';

  @override
  String get errorDirectGatewayFeatureUnavailable =>
      '此功能需要 Hermes Mobile Server，直接 Gateway 連線無法使用';

  @override
  String errorOperationFailedWithDetail(String error) {
    return '操作失敗：$error';
  }

  @override
  String gatewayOauthRejected(String error) {
    return 'Gateway 拒絕登入：$error';
  }

  @override
  String get gatewayOauthCodeMissing => 'Gateway 回呼缺少授權碼';

  @override
  String get gatewayOauthStateMismatch => 'Gateway 回呼狀態不相符。為確保安全，登入已取消。';

  @override
  String get gatewayOauthRefreshTokenMissing => 'Gateway 工作階段已過期且沒有重新整理權杖';

  @override
  String get gatewayOauthTicketMissing => 'Gateway 未傳回 WebSocket 票證';

  @override
  String get gatewayOauthAccessTokenMissing => 'Gateway 權杖回應未包含存取權杖';

  @override
  String get gatewayOauthTimedOut => 'Gateway 登入逾時';

  @override
  String get gatewayOauthNativeUnsupported => '此平台不支援原生 Gateway OAuth';

  @override
  String get updateManifestInvalid => '更新資訊清單無效';

  @override
  String sshRemotePlatformUnsupported(String error) {
    return '不支援遠端平台：$error';
  }

  @override
  String get sshWebUnsupported => 'Web 端不支援原生 SSH 連線';

  @override
  String get filesDownloadPlatformUnsupported => '此平台不支援下載至本機檔案';

  @override
  String get sessionExportPlatformUnsupported => '此平台不支援匯出至本機檔案';

  @override
  String get errorPluginCanonicalKeyRequired => '此外掛程式需要標準鍵才能變更';

  @override
  String get connectGatewayToken => 'Gateway 權杖';

  @override
  String get modelMoaTitle => '多代理混合';

  @override
  String get insightsTokens => 'Token';

  @override
  String get messageWebFallback => '網頁';

  @override
  String get mcpLogsSourceStdio => 'stdio';

  @override
  String get mcpLogsSourceAgent => '代理';

  @override
  String get projectPrimaryFolder => '主目錄';

  @override
  String get botGroupNameRequired => '請輸入群組名稱';

  @override
  String get botGroupMembersMinimum => '群組至少需要兩個 Bot';

  @override
  String botGroupMembersRange(int max) {
    return '群組需要 2～$max 個 Bot';
  }

  @override
  String botGroupMembersMaximum(int max) {
    return '群組最多支援 $max 個 Bot';
  }

  @override
  String get botGroupMemberUnavailable => '沒有可用的群組成員';

  @override
  String get botProfileNameUnavailable => '沒有可用的設定檔名稱';

  @override
  String get botDefaultProfileDeleteForbidden => '無法刪除預設設定檔';

  @override
  String get botConnectionUnavailable => 'Bot 連線無法使用';

  @override
  String get botTurnFailed => 'Bot 回合失敗';

  @override
  String get mcpInvalidJsonSyntax => 'JSON 語法無效';

  @override
  String get mcpJsonObjectRequired => 'JSON 最上層內容必須是物件';

  @override
  String get voiceWakeMicStreamEnded => '喚醒詞麥克風串流意外結束';

  @override
  String httpStatusError(int statusCode) {
    return '伺服器傳回 HTTP $statusCode';
  }
}
