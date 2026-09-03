// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get commonCopyFailed => 'تعذر النسخ إلى الحافظة';

  @override
  String get commonClipboardReadFailed => 'تعذرت قراءة الحافظة';

  @override
  String petGenerateReferenceFailed(String error) {
    return 'تعذرت إضافة الصورة المرجعية: $error';
  }

  @override
  String petSelectFailed(String error) {
    return 'تعذر اختيار الحيوان الأليف: $error';
  }

  @override
  String terminalSshNamed(String host) {
    return 'SSH $host';
  }

  @override
  String get deepLinkUnsupported => 'رابط Hermes غير مدعوم';

  @override
  String get deepLinkMcpNameInvalid => 'تنسيق اسم MCP غير صالح';

  @override
  String get deepLinkMcpConfigMissing => 'رابط MCP يفتقد إلى الإعداد';

  @override
  String get deepLinkMcpConfigTooLarge => 'يتجاوز إعداد MCP حجم 32 KiB';

  @override
  String get deepLinkMcpEncodingInvalid => 'ترميز إعداد MCP غير صالح';

  @override
  String get deepLinkMcpJsonInvalid => 'إعداد MCP ليس JSON صالحاً';

  @override
  String get deepLinkMcpObjectRequired => 'يجب أن يكون إعداد MCP كائناً';

  @override
  String get deepLinkMcpUrlCommandConflict =>
      'لا يمكن أن يحتوي إعداد MCP على URL وأمر معاً';

  @override
  String get deepLinkMcpHttpOnly =>
      'يجب أن يستخدم MCP URL بروتوكول HTTP أو HTTPS';

  @override
  String get deepLinkMcpEndpointMissing => 'إعداد MCP يفتقد إلى URL أو أمر';

  @override
  String get terminalConnectionClosed => 'اتصال الطرفية مغلق';

  @override
  String terminalRequestFailed(String error) {
    return 'تعذر إرسال طلب الطرفية: $error';
  }

  @override
  String get terminalGenericError => 'خطأ في الطرفية';

  @override
  String get botUntitledTask => 'مهمة بلا عنوان';

  @override
  String botMemberPaused(String name) {
    return '$name متوقف. اذكر هذا العضو أو أرسل resume للمتابعة.';
  }

  @override
  String get botGroupRoundCapReached =>
      'This round of discussion reached its limit. Send a new message to continue.';

  @override
  String get botGroupMessageCapReached =>
      'This conversation reached its message limit. Send a new message to continue.';

  @override
  String get botRoutineFieldsRequired => 'اسم المهمة والتعليمات والجدول مطلوبة';

  @override
  String get botRoutineNulForbidden =>
      'لا يمكن أن يحتوي اسم المهمة أو التعليمات أو الجدول على NUL';

  @override
  String get pluginLoadActionReadOnly =>
      'يجب أن يكون view.load_action للمكون الإضافي للقراءة فقط';

  @override
  String get pluginMethodMissing => 'action للمكون الإضافي يفتقد إلى method';

  @override
  String get pluginPathInvalid => 'path لـ action المكون الإضافي غير صالح';

  @override
  String pluginMethodUnsupported(String method) {
    return 'REST method للمكون الإضافي غير مدعوم: $method';
  }

  @override
  String get pluginUrlInvalid => 'URL لـ action المكون الإضافي غير صالح';

  @override
  String get pluginUrlSchemeUnsupported =>
      'scheme لعنوان URL للمكون الإضافي غير مدعوم';

  @override
  String get pluginLinkOpenFailed => 'تعذر فتح الرابط';

  @override
  String get pluginNotificationFieldsMissing =>
      'action إشعار المكون الإضافي يفتقد إلى title أو message';

  @override
  String get pluginNotificationUnavailable =>
      'الإشعارات غير متاحة في هذا المضيف';

  @override
  String pluginActionUnsupported(String kind) {
    return 'action المكون الإضافي غير مدعوم على الهاتف: $kind';
  }

  @override
  String get kanbanTaskAlreadyRunning => 'المهمة قيد التشغيل بالفعل';

  @override
  String get gatewayUnavailable => 'Gateway لخلفية Hermes غير متاح';

  @override
  String get filesDirectoryMissing => 'الدليل غير موجود';

  @override
  String get filesFolderFallback =>
      'لا يمكن لهذه المنصة سرد المجلدات المحلية؛ حدد ملفات متعددة بدلاً من ذلك';

  @override
  String get billingCreditsExhausted => 'نفد الرصيد أو حد الائتمان';

  @override
  String workspacePaneLimit(int count) {
    return 'يمكن فتح $count أجزاء كحد أقصى في مساحة العمل';
  }

  @override
  String get projectMissing => 'المشروع غير موجود أو تم حذفه';

  @override
  String updateHttpError(int status) {
    return 'أعادت خدمة التحديث HTTP $status';
  }

  @override
  String get chatCompactingThread => 'جارٍ تلخيص سلسلة المحادثة';

  @override
  String get chatModelChanged => 'تم تغيير النموذج';

  @override
  String get chatTurnContinued => 'تمت متابعة الجولة المتوقفة';

  @override
  String get chatPersonalityChanged => 'تم تغيير الشخصية';

  @override
  String get chatDelegationCompleted => 'اكتمل عمل الوكيل في الخلفية';

  @override
  String chatDelegationCountCompleted(int count) {
    return 'اكتملت $count مهمة للوكلاء في الخلفية';
  }

  @override
  String get chatHermesNotification => 'إشعار Hermes';

  @override
  String get chatBrowserTask => 'مهمة المتصفح';

  @override
  String get chatPreviewRestart => 'إعادة تشغيل خدمة المعاينة';

  @override
  String chatPreparingTool(String name) {
    return 'جارٍ تحضير $name';
  }

  @override
  String get chatMoaAggregating => '◇ جارٍ تجميع نتائج نماذج متعددة…';

  @override
  String get chatMoaCollaboration => 'تعاون متعدد النماذج';

  @override
  String get chatCurrentGoal => 'الهدف الحالي';

  @override
  String get chatCodeReview => 'مراجعة الرمز';

  @override
  String get chatHermesRunFailed => 'فشل تشغيل Hermes';

  @override
  String get chatPlanItem => 'عنصر الخطة';

  @override
  String get chatAssistantReplyFailed => 'فشل رد المساعد';

  @override
  String get terminalServerNotConfigured => 'الخادم غير معد';

  @override
  String terminalLimitReached(int count) {
    return 'يمكن فتح $count طرفيات كحد أقصى. أغلق جلسة أولاً.';
  }

  @override
  String terminalNumbered(int number) {
    return 'الطرفية $number';
  }

  @override
  String get terminalSnapshotStart =>
      '-- لقطة إخراج للقراءة فقط من الجلسة السابقة --';

  @override
  String get terminalSnapshotEnd => '-- انتهت اللقطة؛ جارٍ استعادة الطرفية --';

  @override
  String get terminalSshHostRequired => 'مضيف SSH مطلوب';

  @override
  String get terminalRestartingShell => '-- جارٍ إعادة تشغيل shell... --';

  @override
  String get terminalOpenedNewShell =>
      '-- تعذر استعادة shell الأصلي؛ تم فتح shell جديد --';

  @override
  String get terminalPtyIdMissing => 'لم يعد الخادم معرف جلسة PTY';

  @override
  String terminalShellExited(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'other': ' (code $code)',
      'empty': '',
    });
    return '-- انتهى shell$_temp0 · اضغط إعادة التشغيل للمتابعة --';
  }

  @override
  String get terminalReconnecting =>
      'انقطع اتصال الطرفية. جارٍ إعادة الاتصال...';

  @override
  String get terminalRestoringShell =>
      '-- انقطع الاتصال؛ جارٍ استعادة shell أو إعادة فتحه... --';

  @override
  String get terminalConnectionRestored => '-- تمت استعادة اتصال الطرفية --';

  @override
  String get terminalConnectionRestoreFailed =>
      '-- تعذرت استعادة اتصال الطرفية --';

  @override
  String get terminalReconnected =>
      'أعيد اتصال الطرفية؛ ربما تم فتح shell جديد';

  @override
  String get terminalReconnectFailed =>
      'تعذرت إعادة اتصال الطرفية. أنشئ طرفية جديدة يدوياً.';

  @override
  String get sessionChooseHandoffPlatform => 'اختر منصة التسليم';

  @override
  String sessionHandoffTargetFailed(String target) {
    return 'فشل التسليم إلى $target';
  }

  @override
  String get sessionHandoffTimeout => 'انتهت مهلة التسليم. حاول مرة أخرى.';

  @override
  String get sessionNoActive => 'لا توجد جلسة نشطة';

  @override
  String sessionLoadMoreFailed(String error) {
    return 'تعذر تحميل المزيد من الجلسات: $error';
  }

  @override
  String get sessionOfflineTranscript => 'وضع عدم الاتصال: عرض النسخة المخبأة';

  @override
  String sessionTranscriptRefreshFailed(String error) {
    return 'تعذر تحديث النسخة: $error';
  }

  @override
  String sessionOlderMessagesFailed(String error) {
    return 'تعذر تحميل الرسائل الأقدم: $error';
  }

  @override
  String sessionListLoadFailed(String error) {
    return 'تعذر تحميل الجلسات: $error';
  }

  @override
  String get sessionProfileSwitching => 'جارٍ تبديل الملف. حاول بعد قليل.';

  @override
  String get sessionSubagentReadOnly => 'جلسات الوكيل الفرعي للقراءة فقط';

  @override
  String get sessionChangedRetry => 'تغيرت الجلسة. حاول بعد قليل.';

  @override
  String sessionConnectionUnknown(String id) {
    return 'اتصال الجلسة غير معروف: $id';
  }

  @override
  String sessionConnectionUnavailable(String id) {
    return 'اتصال الجلسة غير متاح: $id';
  }

  @override
  String get sessionUnsavedTitle => 'لم تحفظ الجلسة، لذلك لا يمكن إنشاء عنوان';

  @override
  String get sessionShareLinkMissing => 'لم يعد الخادم رابط مشاركة';

  @override
  String sessionBatchDeletePartial(int deleted, int failed) {
    return 'تم حذف $deleted؛ فشل $failed';
  }

  @override
  String get sessionCouldNotCreate => 'تعذر إنشاء جلسة';

  @override
  String get sessionUserMessageMissing =>
      'تعذر العثور على رسالة المستخدم المقابلة';

  @override
  String get sessionRestoreMessageMissing =>
      'تعذر العثور على رسالة المستخدم للاستعادة';

  @override
  String get sessionBranchMessageMissing => 'تعذر العثور على رسالة للتفرع منها';

  @override
  String get sessionHistoryPositionMissing =>
      'لا تحتوي هذه الرسالة على موضع في السجل. حدث الجلسة وحاول مرة أخرى.';

  @override
  String get sessionRuntimeIdMissing => 'لم يعد Hermes معرف جلسة وقت التشغيل';

  @override
  String get aboutLicenses => 'تراخيص المصادر المفتوحة';

  @override
  String get aboutLicensesDescription =>
      'عرض تراخيص برامج الجهات الخارجية المستخدمة في التطبيق';

  @override
  String get aboutProductDescription => 'عميل الهاتف المحمول لـ Hermes Agent';

  @override
  String get aboutProductInfo => 'معلومات المنتج';

  @override
  String get aboutTitle => 'حول Hermes';

  @override
  String get appTitle => 'Hermes Mobile';

  @override
  String get appearanceHaptics => 'التغذية الراجعة اللمسية';

  @override
  String get appearanceHapticsDesc =>
      'اهتزاز عند الإرسال والأخطاء واكتمال المهام';

  @override
  String get appearanceHighContrast => 'تباين عالٍ';

  @override
  String get appearanceHighContrastDesc => 'زيادة تباين النص والحدود';

  @override
  String get appearanceKeepAwake => 'إبقاء الشاشة نشطة';

  @override
  String get appearanceKeepAwakeDesc =>
      'منع قفل الشاشة تلقائيًا أثناء فتح محادثة';

  @override
  String get appearanceModeDark => 'داكن';

  @override
  String get appearanceModeLight => 'فاتح';

  @override
  String get appearanceModeSystem => 'النظام';

  @override
  String get appearanceThemeColor => 'لون السمة';

  @override
  String get appearanceTitle => 'المظهر';

  @override
  String get approvalRequests => 'طلبات الموافقة';

  @override
  String get backendConnected => 'الخادم متصل';

  @override
  String get backendDisconnected => 'الخادم غير متصل';

  @override
  String get billingAccountBalance => 'رصيد الحساب';

  @override
  String get billingAccountTab => 'الحساب';

  @override
  String get billingAmountUsd => 'المبلغ (USD)';

  @override
  String get billingAutoReload => 'إعادة الشحن التلقائي';

  @override
  String get billingAutoReloadDescription =>
      'إضافة رصيد عندما ينخفض الرصيد عن الحد';

  @override
  String get billingAutoReloadDisabled => 'تم إيقاف إعادة الشحن التلقائي';

  @override
  String get billingAutoReloadEnabled => 'تم تفعيل إعادة الشحن التلقائي';

  @override
  String get billingAutoReloadUpdateFailed => 'تعذر تحديث إعادة الشحن التلقائي';

  @override
  String get billingAvailableCredits => 'الرصيد المتاح';

  @override
  String get billingCancelAtPeriodEnd => 'إلغاء الاشتراك في نهاية الفترة';

  @override
  String get billingCancelAtPeriodEndDescription =>
      'تظل مزايا الخطة الحالية متاحة حتى نهاية هذه الفترة.';

  @override
  String get billingCancelAtPeriodEndQuestion => 'الإلغاء في نهاية الفترة؟';

  @override
  String get billingCancelFailed => 'تعذر إلغاء الاشتراك';

  @override
  String get billingChargeCompleted => 'اكتمل شراء الرصيد';

  @override
  String get billingChargeForbidden =>
      'لا يمكن لهذا الحساب شراء الرصيد من التطبيق';

  @override
  String get billingChargeIncomplete => 'لم يكتمل شراء الرصيد';

  @override
  String get billingConfirmCancellation => 'تأكيد الإلغاء';

  @override
  String get billingConfirmPurchase => 'تأكيد الشراء';

  @override
  String get billingConfirmUpgrade => 'أكد ترقية الخطة.';

  @override
  String billingCreditsPerMonth(Object credits) {
    return '$credits رصيد/شهر';
  }

  @override
  String get billingCurrent => 'الحالية';

  @override
  String get billingDowngrade => 'تخفيض';

  @override
  String get billingDowngradePeriodEnd =>
      'يسري تخفيض الخطة في نهاية الفترة الحالية.';

  @override
  String get billingGatewayMissing => 'غير متصل ببوابة Hermes';

  @override
  String get billingInvalidReloadValues => 'أدخل حدًا ومبلغ إعادة شحن صالحين';

  @override
  String get billingLoading => 'جارٍ تحميل حالة الفوترة…';

  @override
  String get billingLoadingPlans => 'جارٍ تحميل قائمة الخطط…';

  @override
  String get billingLoggedIn => 'تم تسجيل الدخول';

  @override
  String get billingLoggedOut => 'غير مسجل';

  @override
  String get billingManageInPortal => 'الإدارة في البوابة';

  @override
  String billingMaximumCharge(Object amount) {
    return 'الحد الأقصى \$$amount';
  }

  @override
  String billingMinimumCharge(Object amount) {
    return 'الحد الأدنى \$$amount';
  }

  @override
  String get billingMonthlySpendingCap => 'الحد الشهري للإنفاق عن بُعد';

  @override
  String get billingNoActivePlan => 'لا توجد خطة مفعلة';

  @override
  String get billingNoPlans => 'لا تتوفر قائمة خطط';

  @override
  String get billingNoUsageData => 'لا تتوفر بيانات استخدام';

  @override
  String get billingNoUsageDescription =>
      'لم تُرجع البوابة نموذج استخدام Remote Spending.';

  @override
  String get billingNotConnected => 'غير متصل بـ Hermes';

  @override
  String get billingNotProvided => 'غير متوفر';

  @override
  String get billingNotSet => 'غير محدد';

  @override
  String get billingOpenPortal => 'فتح البوابة';

  @override
  String get billingOpenVerification => 'فتح صفحة التحقق';

  @override
  String get billingPaymentIncomplete => 'لم يكتمل الدفع';

  @override
  String get billingPaymentMethod => 'طريقة الدفع';

  @override
  String get billingPaymentTimeout =>
      'انتهت مهلة تأكيد حالة الدفع. تحقق من النتيجة في البوابة.';

  @override
  String get billingPending => 'معلقة';

  @override
  String billingPendingCancellation(Object date) {
    return 'سيتم الإلغاء في $date';
  }

  @override
  String billingPendingDowngrade(Object date, Object name) {
    return 'سيتم التخفيض إلى $name في $date';
  }

  @override
  String billingPerMonth(Object price) {
    return '$price/شهر';
  }

  @override
  String get billingPeriodEnd => 'نهاية الفترة';

  @override
  String get billingPlanAlreadyActive => 'هذه الخطة مفعلة بالفعل.';

  @override
  String billingPlanChangeEffectiveAt(Object date) {
    return 'يسري تغيير الخطة في $date.';
  }

  @override
  String get billingPlanChangeFailed => 'تعذر تغيير الخطة';

  @override
  String get billingPlanChangeForbidden => 'لا يمكن لهذا الحساب تغيير الخطط';

  @override
  String get billingPlanChangePeriodEnd =>
      'يسري تغيير الخطة في نهاية الفترة الحالية.';

  @override
  String get billingPlanChangeUnavailable => 'هذا التغيير غير متاح حاليًا.';

  @override
  String get billingPlanCredits => 'رصيد الخطة';

  @override
  String get billingPlansTab => 'الخطط';

  @override
  String get billingPortalMissing => 'لم يوفر الخادم رابط بوابة الفوترة';

  @override
  String get billingPortalOpenFailed => 'تعذر فتح بوابة الفوترة';

  @override
  String get billingPurchaseCredits => 'شراء رصيد';

  @override
  String get billingReloadAboveMaximum =>
      'مبلغ إعادة الشحن يتجاوز الحد الأقصى للخادم';

  @override
  String get billingReloadBelowMinimum =>
      'مبلغ إعادة الشحن أقل من الحد الأدنى للخادم';

  @override
  String get billingReloadTo => 'إعادة الشحن إلى';

  @override
  String billingRemaining(Object amount) {
    return 'المتبقي $amount';
  }

  @override
  String billingRenews(Object date) {
    return 'يتجدد في $date';
  }

  @override
  String get billingResumeFailed => 'تعذر التراجع عن التغيير المعلق';

  @override
  String get billingSaveAutoReload => 'حفظ إعادة الشحن التلقائي';

  @override
  String billingSpentThisMonth(Object amount) {
    return 'المُنفق هذا الشهر: $amount';
  }

  @override
  String billingSwitchPlan(Object name) {
    return 'التبديل إلى $name؟';
  }

  @override
  String get billingTitle => 'الفوترة';

  @override
  String get billingTopupCredits => 'الرصيد المشترى';

  @override
  String get billingTriggerThreshold => 'حد التشغيل';

  @override
  String get billingUnavailableForAccount => 'غير متاح لهذا الحساب';

  @override
  String billingUpgradeAmount(Object amount) {
    return 'تدخل الترقية حيز التنفيذ فورًا. المستحق الآن: \$$amount.';
  }

  @override
  String get billingUpgradeChargeNow =>
      'تدخل الترقية حيز التنفيذ فورًا وتترتب عليها رسوم.';

  @override
  String get billingUsageTab => 'الاستخدام';

  @override
  String billingUsedOf(Object spent, Object total) {
    return 'استُخدم $spent من $total';
  }

  @override
  String billingVerificationFailed(Object error) {
    return 'فشل التحقق: $error';
  }

  @override
  String get billingVerificationIncomplete =>
      'لم يكتمل التحقق. أعد المحاولة بعد قليل.';

  @override
  String get billingVerificationInstructions =>
      'أكمل التحقق في المتصفح للسماح بإجراءات الإنفاق عن بُعد من هذا الجهاز.';

  @override
  String get billingVerificationRequired => 'يلزم تحقق إضافي';

  @override
  String get billingVerificationStarting => 'جارٍ بدء التحقق…';

  @override
  String get billingVerificationSucceeded => 'نجح التحقق. يمكنك المتابعة.';

  @override
  String get billingVerifyAndContinue => 'التحقق والمتابعة';

  @override
  String get billingViewSubscriptionInPortal => 'يمكنك عرض اشتراكك في البوابة.';

  @override
  String get chatAbsoluteServerPath => 'استخدام مسار مطلق على الخادم';

  @override
  String get chatAddImage => 'إضافة صورة';

  @override
  String chatAddImageFailed(String error) {
    return 'تعذرت إضافة الصورة: $error';
  }

  @override
  String chatAddedToQueue(int count) {
    return 'أُضيف إلى قائمة الانتظار ($count في الانتظار)';
  }

  @override
  String get chatAllDates => 'كل التواريخ';

  @override
  String get chatAllHistoryShown => 'تم عرض السجل بالكامل';

  @override
  String get chatApprovalManual => 'يدوي';

  @override
  String get chatApprovalManualDescription => 'تأكيد كل خطوة';

  @override
  String get chatApprovalMode => 'وضع الموافقة';

  @override
  String chatApprovalModeFailed(String error) {
    return 'تعذر ضبط وضع الموافقة: $error';
  }

  @override
  String chatApprovalModeSet(String mode) {
    return 'تم ضبط وضع الموافقة على $mode';
  }

  @override
  String get chatApprovalOff => 'إيقاف';

  @override
  String get chatApprovalOffDescription => 'التنفيذ دون تأكيد';

  @override
  String get chatApprovalSmart => 'ذكي';

  @override
  String get chatApprovalSmartDescription => 'السؤال فقط عند الإجراءات الخطرة';

  @override
  String get chatApprovalsUsage => 'الاستخدام: ‎/approvals manual|smart|off';

  @override
  String chatArtifactVersions(int count) {
    return 'كل الإصدارات ($count)';
  }

  @override
  String get chatAssistant => 'المساعد';

  @override
  String get chatAttach => 'إرفاق';

  @override
  String get chatAttachFiles => 'إرفاق ملفات';

  @override
  String get chatAttachLink => 'إرفاق رابط';

  @override
  String chatAttachmentUploadFailed(String error) {
    return 'تعذر رفع المرفق: $error';
  }

  @override
  String get chatAutoRetried => 'أُعيدت المحاولة تلقائيًا';

  @override
  String get chatBackToNewerMessages => 'العودة إلى الرسائل الأحدث';

  @override
  String get chatBackToWorkspace => 'العودة إلى مساحة العمل';

  @override
  String get chatBackgroundAgentRunning =>
      'وكيل يعمل في الخلفية · ستُستأنف هذه الجولة عند اكتماله';

  @override
  String chatBackgroundAgentsRunning(int count) {
    return 'يعمل $count وكلاء في الخلفية · ستُستأنف الجولة عند اكتمالهم';
  }

  @override
  String chatBackgroundCount(int count) {
    return '$count مهمة في الخلفية';
  }

  @override
  String get chatBackgroundPrompt => 'تعليمات المهمة في الخلفية';

  @override
  String chatBackgroundSubmitFailed(String error) {
    return 'تعذر إرسال المهمة في الخلفية: $error';
  }

  @override
  String get chatBackgroundSubmitted => 'أُرسلت المهمة في الخلفية';

  @override
  String chatBackgroundSubmittedWithId(String id) {
    return 'أُرسلت المهمة في الخلفية ($id)';
  }

  @override
  String chatBackgroundTaskCompleted(String label) {
    return 'اكتملت $label';
  }

  @override
  String chatBackgroundTaskFailed(String label) {
    return 'فشلت $label';
  }

  @override
  String get chatBasicToolsets => 'مجموعات الأدوات الأساسية';

  @override
  String get chatBranch => 'فرع';

  @override
  String chatBranchChanges(String branch, int changedFiles) {
    return '$branch · $changedFiles ملف متغيّر';
  }

  @override
  String get chatBranchCreated => 'أُنشئت جلسة الفرع';

  @override
  String chatBranchCreatedWithId(String id) {
    return 'أُنشئت جلسة الفرع ($id)';
  }

  @override
  String chatBranchFailed(String error) {
    return 'تعذر إنشاء الفرع: $error';
  }

  @override
  String get chatBranchInNewSession => 'التفريع في جلسة جديدة';

  @override
  String get chatBranchedHere => 'تم التفريع من هنا';

  @override
  String chatBranchedWithId(String id) {
    return 'تم التفريع من هنا ($id)';
  }

  @override
  String chatBranchesLoadFailed(String error) {
    return 'تعذر تحميل الفروع: $error';
  }

  @override
  String get chatBrowseArtifactsDescription =>
      'تصفح الملفات الناتجة في هذه الجلسة';

  @override
  String get chatBrowseFiles => 'تصفح مدير الملفات';

  @override
  String get chatBrowseFilesDescription => 'حدد مجلدًا في مدير الملفات';

  @override
  String get chatCancelKeyboardHint => 'إلغاء (Esc)';

  @override
  String get chatCatalogEmpty => 'لا توجد خوادم متاحة';

  @override
  String get chatChangeWorkspace => 'تغيير مساحة العمل';

  @override
  String get chatChangeWorkspaceDescription =>
      'سيقرأ الذكاء الاصطناعي الملفات ويعدلها في مجلد الخادم المحدد';

  @override
  String get chatClosePreview => 'إغلاق المعاينة';

  @override
  String get chatCollapseStatusDetails => 'طي التفاصيل';

  @override
  String get chatCollapseSubsessions => 'طي الجلسات الفرعية';

  @override
  String get chatCommandCompletedNoOutput => 'اكتمل الأمر دون أي ناتج';

  @override
  String get chatCommandExecutionFailed => 'فشل تنفيذ الأمر';

  @override
  String chatCommandFailed(String error) {
    return 'فشل الأمر: $error';
  }

  @override
  String get chatCommandMessageQueued => 'أُضيفت الرسالة إلى قائمة الانتظار';

  @override
  String get chatCommandNoFillContent => 'لا يوجد محتوى لملئه';

  @override
  String get chatCommandNoSendableContent => 'لا يوجد محتوى لإرساله';

  @override
  String get chatCommandQueued => 'أُضيف الأمر إلى قائمة الانتظار';

  @override
  String get chatCommandSearchHint => 'جرّب كلمات بحث مختلفة';

  @override
  String get chatCommandSearchFailed => 'تعذّر تحميل الأوامر — تحقق من اتصالك';

  @override
  String get chatCommandStarting => 'بدء تنفيذ الأمر';

  @override
  String get chatCompositeToolsets => 'مجموعات الأدوات المركّبة';

  @override
  String get chatCompressContext => 'ضغط';

  @override
  String chatCompressionFailed(String error) {
    return 'تعذر ضغط السياق: $error';
  }

  @override
  String get chatCompressionRequested => 'طُلب ضغط السياق';

  @override
  String get chatConfigureProvider => 'إعداد المزوّد';

  @override
  String get chatConnecting => 'جارٍ الاتصال';

  @override
  String get chatConnectionFailed => 'فشل الاتصال';

  @override
  String get chatContentFilled => 'تم ملء المحتوى';

  @override
  String get chatContextUsage => 'استخدام السياق';

  @override
  String chatContextUsagePercent(int percent) {
    return 'استخدام السياق $percent%';
  }

  @override
  String get chatCopyAsMarkdown => 'نسخ كـ Markdown';

  @override
  String get chatCopyDiagnostics => 'نسخ معلومات التشخيص';

  @override
  String get chatCopySessionId => 'نسخ معرّف الجلسة';

  @override
  String get chatCopySessionLink => 'نسخ رابط الجلسة';

  @override
  String get chatCopyText => 'نسخ النص';

  @override
  String get chatCreateScheduledTask => 'إنشاء مهمة مجدولة';

  @override
  String chatCronSuggestion(String phrase) {
    return 'تم اكتشاف جدولة: $phrase';
  }

  @override
  String get chatCurrentSessionArtifacts => 'الملفات الناتجة في هذه الجلسة';

  @override
  String get chatCurrentSessionToolsets => 'مجموعات أدوات الجلسة الحالية';

  @override
  String get chatCurrentlyActive => 'النشط حاليًا';

  @override
  String chatDeletePromptFailed(String error) {
    return 'تعذر حذف المُوجّه: $error';
  }

  @override
  String get chatDeliveryUncertain => 'حالة التسليم غير مؤكدة';

  @override
  String get chatDiagnosticsCopied => 'تم نسخ معلومات التشخيص';

  @override
  String chatDiagnosticsError(String error) {
    return 'خطأ: $error';
  }

  @override
  String chatDiagnosticsModel(String provider, String model) {
    return 'النموذج: $provider / $model';
  }

  @override
  String chatDiagnosticsTime(String time) {
    return 'الوقت: $time';
  }

  @override
  String get chatDiagnosticsTitle => 'معلومات التشخيص';

  @override
  String chatEditFailed(String error) {
    return 'تعذر التعديل: $error';
  }

  @override
  String get chatEditMessageHint => 'تحرير الرسالة…';

  @override
  String get chatEditMessageKeyboardHint =>
      'تحرير الرسالة… (Enter للإرسال وShift+Enter لسطر جديد)';

  @override
  String get chatEmptyDescription =>
      'ردود متدفقة واستدعاءات أدوات وموافقات واستيضاحات بميزات مماثلة لسطح المكتب.';

  @override
  String get chatEmptyTitle => 'ابدأ محادثة مع Hermes';

  @override
  String get chatEnterOtherDirectory => 'إدخال مجلد آخر';

  @override
  String get chatEnterWorkspacePath => 'إدخال مسار مساحة العمل';

  @override
  String get chatErrorAuth => 'خطأ في المصادقة';

  @override
  String get chatErrorBilling => 'خطأ في الفوترة';

  @override
  String get chatErrorNetwork => 'خطأ في الشبكة';

  @override
  String get chatErrorProvider => 'خطأ في المزوّد';

  @override
  String get chatErrorRateLimit => 'تم تجاوز حد المعدل';

  @override
  String get chatErrorReply => 'خطأ في الرد';

  @override
  String get chatExecuting => 'جارٍ التنفيذ…';

  @override
  String chatExecutionFailed(String error) {
    return 'فشل التنفيذ: $error';
  }

  @override
  String get chatExpandStatusDetails => 'توسيع التفاصيل';

  @override
  String get chatExpandSubsessions => 'توسيع الجلسات الفرعية';

  @override
  String chatFileTooLarge(int maxMb, String name) {
    return '$name يتجاوز الحد الأقصى البالغ $maxMb ميغابايت';
  }

  @override
  String get chatFillRetry => 'إعادة المحاولة';

  @override
  String get chatFindHint => 'البحث في المحادثة الحالية';

  @override
  String get chatFindInConversation => 'البحث في المحادثة';

  @override
  String chatFolderFilesAttached(int attached, int skipped) {
    return 'أُرفق $attached ملفًا (تم تخطي $skipped)';
  }

  @override
  String get chatFolderPickerUnavailable =>
      'اختيار المجلد غير متاح على هذه المنصة';

  @override
  String chatForwardedToCommand(String target) {
    return 'تم التحويل إلى ‎/$target';
  }

  @override
  String get chatGlobalCliToolsets => 'مجموعات أدوات CLI العامة';

  @override
  String get chatGlobalToolsetsDescription =>
      'مفاتيح مجموعات أدوات CLI العامة؛ تسري التغييرات فورًا';

  @override
  String get chatGoals => 'الأهداف';

  @override
  String chatHandingOffTo(String name) {
    return 'جارٍ التسليم إلى $name…';
  }

  @override
  String get chatHandoff => 'تسليم';

  @override
  String get chatHandoffCompleted => 'مكتمل';

  @override
  String chatHandoffCompletedTo(String name) {
    return 'تم التسليم إلى $name';
  }

  @override
  String chatHandoffFailed(String error) {
    return 'فشل التسليم: $error';
  }

  @override
  String get chatHandoffFailedStatus => 'فشل';

  @override
  String get chatHandoffGatewayRunning => 'قيد التشغيل';

  @override
  String chatHandoffPlatformsFailed(String error) {
    return 'تعذر تحميل منصات التسليم: $error';
  }

  @override
  String get chatHandoffTimeout => 'انتهت مهلة التسليم';

  @override
  String get chatHandoffToPlatform => 'التسليم إلى منصة';

  @override
  String get chatHandoffWaiting => 'في الانتظار';

  @override
  String get chatHideStatus => 'إخفاء';

  @override
  String get chatHistoryLocator => 'تحديد موضع سجل الدردشة';

  @override
  String chatHomeChannel(String name) {
    return 'القناة الرئيسية: $name';
  }

  @override
  String get chatHomeChannelNotSet => 'لم يتم تعيين قناة رئيسية';

  @override
  String get chatHtmlPreview => 'معاينة HTML';

  @override
  String get chatInflightRecovered => 'تم استرداد رد كان قيد التقدم';

  @override
  String get chatInsufficientQuota => 'الحصة غير كافية';

  @override
  String get chatInvalidCommandAlias => 'اسم مستعار غير صالح للأمر';

  @override
  String get chatJumpToTopic => 'الانتقال إلى الموضوع';

  @override
  String get chatLast24Hours => 'آخر 24 ساعة';

  @override
  String get chatLast7Days => 'آخر 7 أيام';

  @override
  String get chatLastTurnRetried => 'أُعيدت محاولة الدور الأخير';

  @override
  String get chatLastTurnUndone => 'تم التراجع عن الدور الأخير';

  @override
  String get chatLoadFailed => 'فشل التحميل';

  @override
  String get chatLoadOlderMessagesHint => 'مرر لأعلى لتحميل رسائل أقدم';

  @override
  String get chatLoadingCommands => 'جارٍ تحميل الأوامر…';

  @override
  String get chatLocalCommands => 'الأوامر المحلية';

  @override
  String get chatLocateTopic => 'تحديد موضع الموضوع';

  @override
  String get chatLongPressCodingStatus =>
      'اضغط مطولاً على حالة البرمجة لتبديل الفرع أو بدء شجرة عمل';

  @override
  String get chatMarkMessage => 'تمييز الرسالة';

  @override
  String get chatMarkdownCopied => 'تم النسخ كـ Markdown';

  @override
  String get chatMarkedOnly => 'المميّز فقط';

  @override
  String chatMessageCount(int count) {
    return '$count رسالة';
  }

  @override
  String get chatModel => 'النموذج';

  @override
  String get chatModelSwitchDeferred => 'سيسري تبديل النموذج في الدور التالي';

  @override
  String chatModelSwitchFailed(String error) {
    return 'تعذر تبديل النموذج: $error';
  }

  @override
  String chatModelsLoadFailed(String error) {
    return 'تعذر تحميل النماذج: $error';
  }

  @override
  String chatMonthDay(int month, int day) {
    return '$day/$month';
  }

  @override
  String get chatMyMessages => 'رسائلي';

  @override
  String get chatNewSessionOpened => 'تم فتح جلسة جديدة';

  @override
  String get chatNewWorktreeDescription => 'إنشاء شجرة عمل Git جديدة';

  @override
  String get chatNoActiveTurnQueued =>
      'لا يوجد دور نشط — أُضيف إلى قائمة الانتظار بدلاً من ذلك';

  @override
  String get chatNoConfigurableToolsets =>
      'لا توجد مجموعات أدوات قابلة للتهيئة في الخادم';

  @override
  String get chatNoContextData => 'لا توجد بيانات سياق';

  @override
  String get chatNoHandoffPlatforms => 'لا توجد منصات تسليم';

  @override
  String get chatNoHandoffPlatformsDescription =>
      'لم تُوصَل أي منصة للتسليم بعد';

  @override
  String get chatNoMatchingCommands => 'لا توجد أوامر مطابقة';

  @override
  String get chatNoMatchingMessages => 'لا توجد رسائل مطابقة';

  @override
  String get chatNoProfiles => 'لا توجد ملفات تعريف للتبديل إليها';

  @override
  String get chatNoQueuedMessages => 'لا توجد رسائل في قائمة الانتظار';

  @override
  String get chatNoRetryMessage => 'لا توجد رسالة لإعادة المحاولة';

  @override
  String get chatNoSavedPrompts => 'لا توجد مُوجّهات محفوظة بعد';

  @override
  String get chatNoSessions => 'لا توجد جلسات';

  @override
  String get chatNoText => 'لا يوجد محتوى نصي';

  @override
  String get chatNoUploadableFolderFiles =>
      'لا توجد ملفات قابلة للرفع في هذا المجلد';

  @override
  String get chatNotConfigured => 'غير مهيأ';

  @override
  String get chatNotConnected => 'غير متصل';

  @override
  String get chatOlderMessagesLoadFailed =>
      'تعذر تحميل الرسائل الأقدم؛ اضغط لإعادة المحاولة';

  @override
  String chatPendingRequests(String kind, int count) {
    return '$kind (+$count في الانتظار)';
  }

  @override
  String chatPlanProgress(int completed, int total) {
    return 'اكتمل $completed/$total';
  }

  @override
  String chatPreviewCount(int count) {
    return '$count معاينة';
  }

  @override
  String chatProfileSwitchFailed(String error) {
    return 'تعذر تبديل ملف التعريف: $error';
  }

  @override
  String chatProfileSwitched(String profile) {
    return 'تم التبديل إلى «$profile»';
  }

  @override
  String chatProfilesLoadFailed(String error) {
    return 'تعذر تحميل ملفات التعريف: $error';
  }

  @override
  String get chatPromptSaved => 'تم حفظ المُوجّه';

  @override
  String get chatProvider => 'المزوّد';

  @override
  String get chatQueue => 'قائمة الانتظار';

  @override
  String chatQueueFailed(String error) {
    return 'تعذرت الإضافة إلى قائمة الانتظار: $error';
  }

  @override
  String get chatQueuePaused => 'متوقف مؤقتًا';

  @override
  String chatQueueSummary(String label, int count, String expandLabel) {
    return '$label · $count · $expandLabel';
  }

  @override
  String get chatQueueUsage => 'أدخل محتوى لإضافته إلى قائمة الانتظار';

  @override
  String get chatQueued => 'أُضيف إلى قائمة الانتظار';

  @override
  String get chatQueuedMessageUpdated => 'تم تحديث الرسالة في قائمة الانتظار';

  @override
  String chatQueuedMinutesAgo(int minutes) {
    return 'أُضيف إلى قائمة الانتظار قبل $minutes دقيقة';
  }

  @override
  String chatQueuedSecondsAgo(int seconds) {
    return 'أُضيف إلى قائمة الانتظار قبل $seconds ثانية';
  }

  @override
  String get chatReasoningEffort => 'مستوى الاستدلال';

  @override
  String get chatReasoningEffortDescription =>
      'تحديث إعداد reasoning effort في الخادم';

  @override
  String chatReasoningEffortSet(String value) {
    return 'تم ضبط مستوى الاستدلال على $value';
  }

  @override
  String chatReasoningEffortSetFailed(String error) {
    return 'تعذر ضبط مستوى الاستدلال: $error';
  }

  @override
  String get chatReconnecting => 'جارٍ إعادة الاتصال';

  @override
  String get chatRegenerate => 'إعادة التوليد';

  @override
  String chatRegenerateFailed(String error) {
    return 'تعذرت إعادة التوليد: $error';
  }

  @override
  String get chatRegenerateTitle => 'إعادة توليد العنوان';

  @override
  String chatRegenerateTitleFailed(String error) {
    return 'تعذرت إعادة توليد العنوان: $error';
  }

  @override
  String get chatRename => 'إعادة تسمية';

  @override
  String get chatRenameSession => 'إعادة تسمية الجلسة';

  @override
  String get chatRequestApproval => 'طلب موافقة';

  @override
  String get chatRequestMcpConfig => 'إعداد MCP';

  @override
  String get chatRequestPassword => 'طلب كلمة مرور';

  @override
  String get chatRequestQuestion => 'طلب سؤال';

  @override
  String get chatRequestSecret => 'طلب سر';

  @override
  String get chatRequestTerminalInput => 'طلب إدخال طرفية';

  @override
  String get chatRestoreAndRerun => 'استعادة وإعادة التشغيل';

  @override
  String chatRestoreFailed(String error) {
    return 'تعذرت الاستعادة: $error';
  }

  @override
  String get chatRestoreToMessage => 'الاستعادة إلى هذه الرسالة';

  @override
  String get chatRestoreToMessageTitle => 'هل تريد الاستعادة إلى هذه الرسالة؟';

  @override
  String get chatRestoreVersionTitle => 'هل تريد استعادة هذا الإصدار؟';

  @override
  String chatRetryFailed(String error) {
    return 'فشلت إعادة المحاولة: $error';
  }

  @override
  String get chatRunInBackground => 'التشغيل في الخلفية';

  @override
  String get chatSaveCurrentInput => 'حفظ الإدخال الحالي';

  @override
  String chatSavePromptFailed(String error) {
    return 'تعذر حفظ المُوجّه: $error';
  }

  @override
  String get chatSavedPrompts => 'المُوجّهات المحفوظة';

  @override
  String chatSavedPromptsLoadFailed(String error) {
    return 'تعذر تحميل المُوجّهات المحفوظة: $error';
  }

  @override
  String get chatScrollToBottom => 'الانتقال إلى الأسفل';

  @override
  String get chatSearchLoadedHistory => 'البحث في السجل المحمّل';

  @override
  String chatSelectFilesFailed(String error) {
    return 'تعذر اختيار الملفات: $error';
  }

  @override
  String get chatSelectFolder => 'اختيار مجلد';

  @override
  String chatSelectFolderFailed(String error) {
    return 'تعذر اختيار المجلد: $error';
  }

  @override
  String get chatSelectProfile => 'اختيار ملف تعريف';

  @override
  String get chatSelectProfileDescription =>
      'اختر ملف التعريف المستخدم لبيانات الصفحة الرئيسية وعمليات التشغيل التالية';

  @override
  String get chatSendDiagnostics => 'إرسال معلومات التشخيص';

  @override
  String get chatSendEdit => 'إرسال التعديل';

  @override
  String get chatSendEditAndRerun => 'إرسال التعديل وإعادة التشغيل';

  @override
  String get chatSendEditTitle => 'هل تريد إرسال الرسالة المعدّلة؟';

  @override
  String chatSendFailed(String error) {
    return 'تعذر الإرسال: $error';
  }

  @override
  String get chatSendNow => 'الإرسال الآن';

  @override
  String get chatSendQueue => 'قائمة انتظار الإرسال';

  @override
  String chatSendQueueCount(int count) {
    return 'قائمة انتظار الإرسال ($count)';
  }

  @override
  String get chatServerCatalog => 'دليل الخوادم';

  @override
  String get chatServerDirectory => 'مجلد الخادم';

  @override
  String get chatServerDirectoryHelp =>
      'يجب أن يكون المجلد موجودًا ومتاحًا لحساب الخادم';

  @override
  String get chatServerNotConnected => 'الخادم غير متصل';

  @override
  String get chatSessionCleared => 'تم مسح الجلسة';

  @override
  String get chatSessionIdCopied => 'تم نسخ معرّف الجلسة';

  @override
  String get chatSessionInfo => 'معلومات الجلسة';

  @override
  String get chatSessionMenu => 'قائمة الجلسة';

  @override
  String get chatSessionShareLinkCopied => 'تم نسخ رابط مشاركة الجلسة';

  @override
  String get chatSessionToolsetsDescription =>
      'مجموعات أدوات الجلسة (تؤثر في الجلسة الحالية فقط)';

  @override
  String get chatSessions => 'الجلسات';

  @override
  String get chatSetAsNext => 'التعيين كالتالي';

  @override
  String chatSetTitleFailed(String error) {
    return 'تعذر ضبط العنوان: $error';
  }

  @override
  String chatShareLinkFailed(String error) {
    return 'تعذر الحصول على رابط المشاركة: $error';
  }

  @override
  String get chatShareUrlMissing => 'لم يُرجَع رابط مشاركة';

  @override
  String get chatSkillsCenter => 'مركز المهارات';

  @override
  String get chatSlashCommands => 'أوامر الشرطة المائلة';

  @override
  String get chatStartSessionBeforeWorkspace =>
      'ابدأ جلسة قبل تغيير مساحة العمل';

  @override
  String get chatStarterDebugIssue => 'ساعدني في تصحيح مشكلة';

  @override
  String get chatStarterDebugIssuePrompt =>
      'واجهت مشكلة. ساعدني أولًا في وضع منهج لتشخيصها.';

  @override
  String get chatStarterExplainProject => 'اشرح هذا المشروع';

  @override
  String get chatStarterExplainProjectPrompt =>
      'قدم نظرة سريعة على بنية المشروع وميزاته الأساسية وطريقة تشغيله.';

  @override
  String get chatStarterReviewChanges => 'راجع التغييرات الحالية';

  @override
  String get chatStarterReviewChangesPrompt =>
      'راجع تغييرات مساحة العمل الحالية وحدد المشكلات المحتملة واقترح تحسينات.';

  @override
  String get chatSteerCurrentTurn => 'توجيه الدور الحالي';

  @override
  String get chatSteerHint => 'رسالة التوجيه';

  @override
  String get chatSteerInjected => 'تم إدراج رسالة التوجيه';

  @override
  String get chatSteerMessage => 'توجيه';

  @override
  String chatSteerNowFailed(String error) {
    return 'تعذر التوجيه الآن: $error';
  }

  @override
  String get chatSteerQueued => 'أُضيفت رسالة التوجيه إلى قائمة الانتظار';

  @override
  String get chatSteerUsage => 'أدخل محتوى للتوجيه به';

  @override
  String get chatStopProcess => 'إيقاف';

  @override
  String chatStopProcessFailed(String error) {
    return 'تعذر إيقاف العملية: $error';
  }

  @override
  String chatSubagentCount(int count) {
    return '$count وكيل فرعي';
  }

  @override
  String get chatTextSnippet => 'مقتطف نصي';

  @override
  String get chatTextSnippetHint => 'الصق النص أو اكتبه';

  @override
  String get chatTitle => 'دردشة Hermes';

  @override
  String chatTitleSet(String title) {
    return 'تم ضبط العنوان على “$title”';
  }

  @override
  String get chatTitleUnchanged => 'لم يتغيّر العنوان';

  @override
  String chatTitleUpdated(String title) {
    return 'تم تحديث العنوان إلى “$title”';
  }

  @override
  String get chatToday => 'اليوم';

  @override
  String get chatToolConfiguration => 'إعدادات الأدوات';

  @override
  String chatToolCount(int count) {
    return '$count أداة';
  }

  @override
  String get chatToolStatusMessage => 'رسالة حالة الأداة';

  @override
  String chatToolsetCounts(String sessionCount, String globalCount) {
    return 'الجلسة: $sessionCount · العام: $globalCount';
  }

  @override
  String chatToolsetToggleFailed(String name, String error) {
    return 'تعذر تبديل $name: $error';
  }

  @override
  String chatToolsetsEnabled(String globalCount) {
    return 'تم تفعيل مجموعات الأدوات العامة ($globalCount)';
  }

  @override
  String get chatToolsetsExplanation =>
      'مجموعات أدوات الجلسة الحالية هي الأدوات المسجلة والمتاحة فعليًا لـ Hermes Agent في هذه الجلسة.\nمجموعات أدوات CLI العامة مضبوطة عموميًا وقد لا تكون كلها محملة في الجلسة الحالية.';

  @override
  String get chatToolsetsLoadFailed => 'تعذر تحميل مجموعات الأدوات';

  @override
  String chatTopicNumber(int index) {
    return 'الموضوع $index';
  }

  @override
  String chatTopicRailSemantics(int count) {
    return '$count موضوع';
  }

  @override
  String get chatTranscriptLoadFailed => 'تعذر تحميل سجل الدردشة';

  @override
  String get chatTruncateWarning =>
      'سيؤدي هذا إلى حذف جميع الرسائل اللاحقة ولا يمكن التراجع عنه';

  @override
  String chatUndoFailed(String error) {
    return 'تعذر التراجع: $error';
  }

  @override
  String get chatUnknownCommandResult => 'نتيجة أمر غير معروفة';

  @override
  String get chatUnknownTime => 'وقت غير معروف';

  @override
  String get chatUnmarkMessage => 'إلغاء تمييز الرسالة';

  @override
  String get chatUntitled => 'جلسة بلا عنوان';

  @override
  String get chatUntitledSession => 'جلسة بلا عنوان';

  @override
  String get chatVersion => 'الإصدار';

  @override
  String chatVersionCount(int count) {
    return '$count إصدار';
  }

  @override
  String chatVersionLoadFailed(String error) {
    return 'تعذر تحميل الإصدارات: $error';
  }

  @override
  String chatVersionNumber(int index) {
    return 'الإصدار $index';
  }

  @override
  String get chatViewBilling => 'عرض الفوترة';

  @override
  String get chatViewCleared => 'تم مسح العرض';

  @override
  String get chatWakeServiceUnavailable => 'خدمة كلمة التنبيه غير متاحة';

  @override
  String chatWakeVoiceFailed(String error) {
    return 'فشلت كلمة التنبيه: $error';
  }

  @override
  String chatWarning(String warning) {
    return 'تحذير: $warning';
  }

  @override
  String get chatWorkingDirectory => 'دليل العمل';

  @override
  String get chatWorkspace => 'مساحة العمل';

  @override
  String get chatWorkspaceFiles => 'ملفات مساحة العمل';

  @override
  String chatWorkspaceSwitchFailed(String error) {
    return 'تعذر تغيير مساحة العمل: $error';
  }

  @override
  String chatWorkspaceSwitched(String name) {
    return 'تم تغيير مساحة العمل إلى $name';
  }

  @override
  String get chatYesterday => 'أمس';

  @override
  String get chatYoloDisabled => 'تم إيقاف وضع YOLO';

  @override
  String get chatYoloEnabled => 'تم تفعيل وضع YOLO';

  @override
  String get chatYoloMode => 'وضع YOLO';

  @override
  String chatYoloToggleFailed(String error) {
    return 'تعذر تبديل وضع YOLO: $error';
  }

  @override
  String get appSessionCompletedTitle => 'اكتملت الجلسة';

  @override
  String get appSessionCompletedBody =>
      'اكتملت جلسة في الخلفية. اضغط لعرض النتيجة.';

  @override
  String appOpenNotificationFailed(Object error) {
    return 'تعذر فتح جلسة الإشعار: $error';
  }

  @override
  String get deepLinkPluginInstallTitle => 'تثبيت إضافة Hermes';

  @override
  String get deepLinkPluginInstallPrompt =>
      'يطلب هذا الرابط تثبيت إضافة للخادم من المصدر التالي:';

  @override
  String get deepLinkLegacyPluginWarning =>
      'هذا رابط قديم لإضافة Desktop. يثبت تطبيق الهاتف إمكانات Agent الخلفية فقط.';

  @override
  String get deepLinkEnableAfterInstall => 'تمكين بعد التثبيت';

  @override
  String get deepLinkForceReinstall => 'فرض إعادة التثبيت';

  @override
  String get deepLinkInstall => 'تثبيت';

  @override
  String deepLinkPluginInstalling(Object identifier) {
    return 'جارٍ تثبيت $identifier...';
  }

  @override
  String get deepLinkPluginInstalled => 'تم تثبيت الإضافة';

  @override
  String deepLinkPluginInstallFailed(Object error) {
    return 'فشل تثبيت الإضافة: $error';
  }

  @override
  String get deepLinkMcpAddTitle => 'إضافة خادم MCP';

  @override
  String get deepLinkMcpServerName => 'اسم الخادم';

  @override
  String get deepLinkMcpNameFormatError =>
      'استخدم من 1 إلى 64 حرفًا أو رقمًا أو نقطة أو شرطة سفلية أو واصلة';

  @override
  String get deepLinkMcpNameConflict =>
      'هذا الاسم موجود بالفعل. اختر اسمًا آخر.';

  @override
  String get deepLinkMcpCommandWarning =>
      'يشغّل هذا الإعداد أمرًا محليًا على خادم Hermes. تابع فقط إذا كنت تثق بالمصدر.';

  @override
  String get deepLinkConfigPreview => 'معاينة الإعداد';

  @override
  String deepLinkMcpAdded(Object name) {
    return 'تمت إضافة خادم MCP ‏$name';
  }

  @override
  String deepLinkMcpAddFailed(Object error) {
    return 'تعذرت إضافة خادم MCP: $error';
  }

  @override
  String get commonAdd => 'إضافة';

  @override
  String get commonAll => 'الكل';

  @override
  String get commonAuthorize => 'تفويض';

  @override
  String get commonBack => 'رجوع';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonCancelAll => 'إلغاء الكل';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get commonCollapse => 'طي';

  @override
  String get commonCompleted => 'مكتمل';

  @override
  String get commonConfirm => 'تأكيد';

  @override
  String get commonConnected => 'متصل';

  @override
  String get commonContinue => 'متابعة';

  @override
  String get commonCopied => 'تم النسخ';

  @override
  String get commonCreate => 'إنشاء';

  @override
  String get commonDefault => 'افتراضي';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonDisconnect => 'قطع الاتصال';

  @override
  String get commonDisconnected => 'غير متصل';

  @override
  String get commonDone => 'تم';

  @override
  String get commonEdit => 'تعديل';

  @override
  String get commonErrorTitle => 'حدث خطأ';

  @override
  String get commonAuthenticationFailed => 'فشلت المصادقة. تحقق من مفتاح API.';

  @override
  String get commonExpand => 'توسيع';

  @override
  String get commonFile => 'ملف';

  @override
  String get commonFolder => 'مجلد';

  @override
  String get commonGotIt => 'فهمت';

  @override
  String get commonHide => 'إخفاء';

  @override
  String get commonIdle => 'خامل';

  @override
  String get commonIgnore => 'تجاهل';

  @override
  String get commonLater => 'لاحقًا';

  @override
  String get commonListSeparator => '، ';

  @override
  String get commonLoading => 'جارٍ التحميل...';

  @override
  String get commonManage => 'إدارة';

  @override
  String get commonMore => 'المزيد';

  @override
  String get commonName => 'الاسم';

  @override
  String get commonNew => 'جديد';

  @override
  String get commonNext => 'التالي';

  @override
  String get commonNoMatches => 'لا توجد نتائج مطابقة';

  @override
  String get commonNotifications => 'الإشعارات';

  @override
  String get commonOffline => 'غير متصل';

  @override
  String get commonOnline => 'متصل';

  @override
  String get commonOperationFailed => 'فشلت العملية. حاول مرة أخرى.';

  @override
  String get commonNetworkFailed =>
      'تعذر الوصول إلى الخادم. تحقق من الشبكة وحالة الخادم.';

  @override
  String get commonOpen => 'فتح';

  @override
  String get commonPrevious => 'السابق';

  @override
  String get commonProcessing => 'جارٍ المعالجة…';

  @override
  String get commonReauthorize => 'إعادة التفويض';

  @override
  String get commonRefresh => 'تحديث';

  @override
  String get commonReload => 'إعادة التحميل';

  @override
  String get commonReset => 'إعادة تعيين';

  @override
  String get commonRestart => 'إعادة التشغيل';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonRun => 'تشغيل';

  @override
  String get commonRunning => 'قيد التشغيل';

  @override
  String get commonSave => 'حفظ';

  @override
  String get commonSearch => 'بحث';

  @override
  String get commonSelect => 'اختيار';

  @override
  String get commonSend => 'إرسال';

  @override
  String get commonStop => 'إيقاف';

  @override
  String get commonSubmit => 'إرسال';

  @override
  String get commonSwitch => 'تبديل';

  @override
  String get commonTitle => 'العنوان';

  @override
  String get commonUndo => 'تراجع';

  @override
  String get commonUnknownError => 'خطأ غير معروف';

  @override
  String get commonViewAll => 'عرض الكل';

  @override
  String get configAppliesToProfile => 'ينطبق على ملف التعريف';

  @override
  String get configConnectionLabel => 'الاتصال';

  @override
  String get configCurrentProfile => 'ملف التعريف الحالي';

  @override
  String get configDefaultProcessProfile => 'ملف التعريف الافتراضي / للعملية';

  @override
  String configDeleteFailed(String error) {
    return 'تعذرت إزالة التجاوز: $error';
  }

  @override
  String get configFullJson => 'JSON الكامل';

  @override
  String configInvalidFieldValue(String path, String error) {
    return 'قيمة $path غير صالحة: $error';
  }

  @override
  String configInvalidJson(String error) {
    return 'JSON غير صالح: $error';
  }

  @override
  String get configListJsonError => 'يجب أن تكون القيمة JSON array';

  @override
  String get configLoading => 'جارٍ تحميل الإعداد وschema…';

  @override
  String get configNoMatches => 'لا توجد حقول مطابقة';

  @override
  String get configObjectJsonError => 'يجب أن تكون القيمة JSON object';

  @override
  String get configRemoveOverride => 'إزالة التجاوز واستخدام القيمة الافتراضية';

  @override
  String get configRestore => 'استعادة';

  @override
  String get configRestoreDefaults => 'استعادة الإعدادات الافتراضية';

  @override
  String configRestoreDefaultsDescription(String profile) {
    return 'ينطبق هذا على $profile. ستُستبدل القيم المخصصة الحالية بالقيم الافتراضية.';
  }

  @override
  String get configRestoreDefaultsQuestion =>
      'هل تريد استعادة إعداد Hermes الافتراضي؟';

  @override
  String configSaveFailed(String error) {
    return 'تعذر الحفظ: $error';
  }

  @override
  String get providerEndpointValidationFailed => 'فشل التحقق من نقطة النهاية';

  @override
  String get kanbanMoveSelected => 'نقل المهام المحددة';

  @override
  String get kanbanClearSelection => 'مسح تحديد المهام';

  @override
  String get configSearchHint => 'البحث في حقول الإعداد…';

  @override
  String configServerDidNotDelete(String path) {
    return 'لم يزل الخادم $path';
  }

  @override
  String get configServerMismatch =>
      'أعاد الخادم محتوى يختلف عن الإعداد الكامل المرسل';

  @override
  String configServerRejected(String path) {
    return 'لم يقبل الخادم $path؛ تمت استعادة قيمة الخادم.';
  }

  @override
  String get configTitle => 'النماذج والمحادثة';

  @override
  String get configTopLevelObject =>
      'يجب أن تكون قيمة JSON العليا من النوع object';

  @override
  String get configUseDefault => 'افتراضي';

  @override
  String get connectAction => 'اتصال';

  @override
  String get connectAddHeader => 'إضافة ترويسة';

  @override
  String get connectAllowPublicHttp => 'السماح باتصال HTTP عام غير مشفر';

  @override
  String get connectAllowPublicHttpWarning =>
      'استخدمه فقط في شبكة موثوقة لا يتوفر فيها HTTPS؛ قد يتم اعتراض Token';

  @override
  String get connectApiKey => 'مفتاح API';

  @override
  String get connectConfiguration => 'إعداد الاتصال';

  @override
  String get connectConnecting => 'جارٍ الاتصال…';

  @override
  String get connectCredentialRequired => 'أدخل بيانات اعتماد الوصول';

  @override
  String get connectDeleteHeader => 'حذف ترويسة الطلب';

  @override
  String get connectDeleteProfile => 'حذف الإعداد';

  @override
  String get connectDiscoverCloud => 'اكتشاف Agent من Hermes Cloud';

  @override
  String get connectExtraHeaders => 'ترويسات طلب إضافية';

  @override
  String get connectHeaderManaged => 'يديره Hermes';

  @override
  String get connectHeaderName => 'اسم Header';

  @override
  String get connectHeaderNameInvalid => 'الاسم غير صالح';

  @override
  String get connectHeaderValue => 'القيمة';

  @override
  String get connectHeaderValueRequired => 'أدخل قيمة';

  @override
  String get connectHeadersDescription =>
      'ترويسات اختيارية لوكيل الوصول؛ تُحفظ القيم في التخزين الآمن للنظام.';

  @override
  String get connectHideKey => 'إخفاء المفتاح';

  @override
  String get connectHidePassphrase => 'إخفاء عبارة المرور';

  @override
  String get connectHidePassword => 'إخفاء كلمة المرور';

  @override
  String get connectHidePrivateKey => 'إخفاء المفتاح الخاص';

  @override
  String get connectHideValue => 'إخفاء القيمة';

  @override
  String get connectHttpsRequired =>
      'تتطلب الاتصالات العامة HTTPS ما لم تسمح بالنقل غير الآمن صراحة';

  @override
  String get connectNativeCleartextRestricted =>
      'تسمح نسخة Release باتصال HTTP غير المشفر فقط مع localhost أو أسماء companion التي تنتهي بـ .local. استخدم HTTPS أو اسم مضيف .local.';

  @override
  String get connectNotSignedIn => 'لم تسجل الدخول';

  @override
  String get connectOauthSignedIn => 'تم تسجيل الدخول عبر OAuth';

  @override
  String get connectPkceUnavailable =>
      'لا يدعم هذا Gateway تسجيل native_pkce. حدّث Hermes أو استخدم Token.';

  @override
  String get connectPort => 'المنفذ';

  @override
  String get connectPrivateKey => 'مفتاح OpenSSH / PEM الخاص';

  @override
  String get connectPrivateKeyPassphrase => 'عبارة مرور المفتاح (اختياري)';

  @override
  String get connectProfileName => 'اسم الإعداد (الافتراضي اسم المضيف)';

  @override
  String get connectProfileNameInvalid => 'اسم Profile غير صالح';

  @override
  String get connectRemoteHermesPath => 'مسار Hermes البعيد (اكتشاف تلقائي)';

  @override
  String get connectRemoteProfile => 'Profile بعيد (اختياري)';

  @override
  String get connectSaveProfile => 'حفظ كإعداد خادم';

  @override
  String get connectSaveProfileDescription =>
      'يمكن التبديل إليه من القائمة المحفوظة لاحقاً';

  @override
  String get connectSavedBackends => 'الخوادم المحفوظة';

  @override
  String get connectServerAddress => 'عنوان الخادم';

  @override
  String get connectServerInvalid => 'أدخل عنوان HTTP(S) صالحاً';

  @override
  String get connectServerRequired => 'أدخل عنوان الخادم';

  @override
  String get connectShowKey => 'إظهار المفتاح';

  @override
  String get connectShowPassphrase => 'إظهار عبارة المرور';

  @override
  String get connectShowPassword => 'إظهار كلمة المرور';

  @override
  String get connectShowPrivateKey => 'إظهار المفتاح الخاص';

  @override
  String get connectShowValue => 'إظهار القيمة';

  @override
  String get connectSignIn => 'تسجيل الدخول';

  @override
  String get connectSignInAgain => 'إعادة تسجيل الدخول';

  @override
  String get connectSshCredentialRequired => 'أدخل مفتاحاً خاصاً أو كلمة مرور';

  @override
  String get connectSshHost => 'مضيف SSH';

  @override
  String get connectSshHostRequired => 'أدخل مضيف SSH';

  @override
  String get connectSshPassword => 'كلمة مرور SSH (اختياري)';

  @override
  String get connectSshUser => 'مستخدم SSH';

  @override
  String get connectSshUserRequired => 'أدخل مستخدم SSH';

  @override
  String get connectTitle => 'الاتصال';

  @override
  String get connectUnableServer => 'تعذر الاتصال بالخادم';

  @override
  String get connectValidationFailed =>
      'فشل التحقق من الاتصال. تحقق من عنوان الخادم ومفتاح API.';

  @override
  String get connectValidationNetworkFailed =>
      'فشل التحقق من الاتصال. تحقق من عنوان الخادم ومفتاح API والشبكة.';

  @override
  String dateMonthDay(int month, int day) {
    return '$day/$month';
  }

  @override
  String get dateToday => 'اليوم';

  @override
  String get dateYesterday => 'أمس';

  @override
  String get discordCommunityTitle => 'انضم إلى مجتمع Discord';

  @override
  String get featureAbout => 'حول';

  @override
  String get featureAboutDesc => 'معلومات الإصدار';

  @override
  String get featureAgent => 'Agent';

  @override
  String get featureAgentDesc => 'حالة التشغيل والخادم';

  @override
  String get featureArtifacts => 'المخرجات';

  @override
  String get featureArtifactsDesc => 'مخرجات الجلسات';

  @override
  String get featureBilling => 'الفوترة';

  @override
  String get featureBillingDesc => 'الاستخدام والخطط والفواتير';

  @override
  String get featureCommandCenter => 'مركز الأوامر';

  @override
  String get featureCommandCenterDesc => 'الحالة والسجلات المباشرة';

  @override
  String get featureConnection => 'الاتصال';

  @override
  String get featureConnectionDesc => 'ملفات خوادم متعددة';

  @override
  String get featureCredentials => 'بيانات الاعتماد';

  @override
  String get featureCredentialsDesc => 'حسابات ومفاتيح خارجية';

  @override
  String get featureCron => 'المهام المجدولة';

  @override
  String get featureCronDesc => 'أتمتة Cron';

  @override
  String get featureFiles => 'الملفات';

  @override
  String get featureFilesDesc => 'تصفح مجلد العمل';

  @override
  String get featureGit => 'Git';

  @override
  String get featureGitDesc => 'التغييرات والالتزامات والفروع';

  @override
  String get featureGlobalSearchDesc => 'ابحث في الأوامر والجلسات والصفحات';

  @override
  String get featureInsights => 'التحليلات';

  @override
  String get featureInsightsDesc => 'اتجاهات الاستخدام والتكلفة';

  @override
  String get featureMcp => 'MCP';

  @override
  String get featureMcpDesc => 'إعداد خوادم MCP';

  @override
  String get featureMemory => 'الذاكرة';

  @override
  String get featureMemoryDesc => 'إدارة الذاكرة طويلة الأمد';

  @override
  String get featureMessaging => 'المراسلة';

  @override
  String get featureMessagingDesc => 'Telegram وDiscord والمزيد';

  @override
  String get featureNotificationsDesc => 'مركز الإشعارات';

  @override
  String get featurePet => 'الرفيق';

  @override
  String get featurePetDesc => 'الرفيق والمجموعة';

  @override
  String get featurePlugins => 'الإضافات';

  @override
  String get featurePluginsDesc => 'إدارة الإضافات';

  @override
  String get featureProfiles => 'الملفات الشخصية';

  @override
  String get featureProfilesDesc => 'ملفات تنفيذ النماذج';

  @override
  String get featureProjects => 'المشاريع';

  @override
  String get featureProjectsDesc => 'تنظيم الجلسات حسب المشروع';

  @override
  String get featureSettings => 'الإعدادات';

  @override
  String get featureSettingsDesc => 'المظهر والتفضيلات';

  @override
  String get featureSkills => 'المهارات';

  @override
  String get featureSkillsDesc => 'مركز المهارات';

  @override
  String get featureStarmap => 'خريطة المعرفة';

  @override
  String get featureStarmapDesc => 'رسم بياني للمعرفة';

  @override
  String get featureSubagents => 'الوكلاء الفرعيون';

  @override
  String get featureSubagentsDesc => 'نشاط الوكلاء في الخلفية';

  @override
  String get featureTerminal => 'الطرفية';

  @override
  String get featureTerminalDesc => 'سطر أوامر تفاعلي';

  @override
  String get featureTools => 'مجموعات الأدوات';

  @override
  String get featureToolsDesc => 'الأدوات والمفاتيح';

  @override
  String get featureWebhooks => 'Webhooks';

  @override
  String get featureWebhooksDesc => 'تسليم الأحداث';

  @override
  String gitAgentShipFailed(Object error) {
    return 'فشل Agent Ship: $error';
  }

  @override
  String get gitAgentShipPrompt =>
      'راجع التغييرات الحالية، والتزم بها برسالة تقليدية واضحة، وادفع الفرع، وافتح طلب سحب.';

  @override
  String get gitAgentShipQuestion =>
      'تكليف Agent بالتزام التغييرات ودفعها ثم إنشاء PR؟';

  @override
  String get gitAgentShipSent => 'أُرسلت مهمة الالتزام وإنشاء PR إلى Hermes';

  @override
  String get gitAuthor => 'المؤلف';

  @override
  String gitAuthorMeta(Object author) {
    return 'المؤلف: $author';
  }

  @override
  String get gitBaseBranch => 'الفرع الأساسي';

  @override
  String gitBranchMeta(Object branch) {
    return 'الفرع: $branch';
  }

  @override
  String get gitBranchesTab => 'الفروع';

  @override
  String get gitChangeDirectory => 'تغيير المجلد';

  @override
  String get gitChangedFiles => 'الملفات المتغيرة';

  @override
  String get gitChangedFilesLabel => 'الملفات المتغيرة:';

  @override
  String get gitChangesTab => 'التغييرات';

  @override
  String get gitCommit => 'التزام';

  @override
  String get gitCommitChanges => 'التزام التغييرات';

  @override
  String get gitCommitDetails => 'تفاصيل الالتزام';

  @override
  String gitCommitFailed(Object error) {
    return 'فشل الالتزام: $error';
  }

  @override
  String get gitCommitMessage => 'رسالة الالتزام';

  @override
  String get gitCommitsTab => 'الالتزامات';

  @override
  String get gitCreatePr => 'إنشاء PR';

  @override
  String gitCreatePrFailed(Object error) {
    return 'تعذر إنشاء PR: $error';
  }

  @override
  String get gitCreatePrQuestion =>
      'إنشاء أو فتح طلب سحب للفرع الحالي باستخدام GitHub CLI؟';

  @override
  String gitCreateWorktreeFailed(Object error) {
    return 'تعذر إنشاء شجرة العمل: $error';
  }

  @override
  String get gitCurrent => 'الحالي';

  @override
  String gitDeleteWorktreeDescription(Object path) {
    return 'سيؤدي ذلك إلى حذف مجلد العمل $path وتغييراته غير الملتزم بها. لا يمكن استعادته.';
  }

  @override
  String gitDeleteWorktreeFailed(Object error) {
    return 'تعذر حذف شجرة العمل: $error';
  }

  @override
  String get gitDeleteWorktreeQuestion => 'حذف شجرة العمل؟';

  @override
  String get gitDetachedHead => '(HEAD منفصل)';

  @override
  String gitDiffLoadFailed(Object error) {
    return 'تعذر تحميل الفرق: $error';
  }

  @override
  String get gitEndOfLog => '— نهاية السجل —';

  @override
  String get gitForceDelete => 'فرض الحذف';

  @override
  String get gitForceDeleteWorktreeQuestion =>
      'فرض الحذف والتخلص من هذه التغييرات؟';

  @override
  String get gitGenerateCommitMessage => 'إنشاء رسالة التزام';

  @override
  String gitGenerateMessageFailed(Object error) {
    return 'تعذر إنشاء رسالة الالتزام: $error';
  }

  @override
  String get gitGithubCliUnavailable =>
      'GitHub CLI غير مثبت أو لم يُسجل دخوله على الخادم';

  @override
  String gitHoursAgo(Object count) {
    return 'قبل $count ساعة';
  }

  @override
  String get gitJustNow => 'الآن';

  @override
  String gitLoadMore(Object loaded, Object total) {
    return 'تحميل المزيد ($loaded/$total)';
  }

  @override
  String get gitLoadingBranches => 'جارٍ تحميل الفروع…';

  @override
  String get gitLoadingLog => 'جارٍ تحميل سجل الالتزامات…';

  @override
  String get gitLoadingStatus => 'جارٍ تحميل حالة المستودع…';

  @override
  String get gitLocalBranches => 'الفروع المحلية';

  @override
  String gitLogLoadFailed(Object error) {
    return 'تعذر تحميل سجل الالتزامات: $error';
  }

  @override
  String get gitMainWorktree => 'الرئيسية';

  @override
  String gitMinutesAgo(Object count) {
    return 'قبل $count دقيقة';
  }

  @override
  String get gitNewWorktree => 'شجرة عمل جديدة';

  @override
  String get gitNoAdditionalWorktrees => 'لا توجد أشجار عمل إضافية';

  @override
  String get gitNoBranches => 'لا توجد فروع متاحة';

  @override
  String get gitNoBranchesDescription => 'اختر مستودع Git وأعد المحاولة.';

  @override
  String get gitNoCommits => 'لا توجد التزامات';

  @override
  String get gitNoCommitsDescription =>
      'لا توجد التزامات في هذا المستودع، أو لا توجد نتائج تطابق عوامل التصفية الحالية';

  @override
  String get gitNoDiff => 'لا فرق';

  @override
  String get gitNoDiffDescription => 'هذا الملف لا يختلف عن HEAD';

  @override
  String get gitNoMatchingBranches => 'لا توجد فروع مطابقة';

  @override
  String get gitNoStashes => 'لا توجد محفوظات';

  @override
  String get gitNoVisibleRemotes => 'لا توجد مستودعات بعيدة ظاهرة';

  @override
  String get gitNotRepository => 'ليس مستودع Git';

  @override
  String gitNotRepositoryDescription(Object path) {
    return '$path\n\nاستخدم الزر أدناه لتغيير المجلد';
  }

  @override
  String get gitOpenInNewSession => 'فتح في جلسة جديدة';

  @override
  String gitOpenPr(Object number) {
    return 'فتح PR #$number';
  }

  @override
  String gitOpenedInNewSession(Object path) {
    return 'تم فتح $path في جلسة جديدة';
  }

  @override
  String get gitParent => 'أصل';

  @override
  String get gitPrCreated => 'تم إنشاء PR';

  @override
  String gitPrNumber(Object number) {
    return 'الرقم: #$number';
  }

  @override
  String get gitPushAfterCommit => 'الدفع بعد الالتزام';

  @override
  String gitPushAction(Object count) {
    return 'دفع $count من الالتزامات';
  }

  @override
  String get gitPushSucceeded => 'تم الدفع إلى البعيد';

  @override
  String gitPushFailed(Object error) {
    return 'فشل الدفع: $error';
  }

  @override
  String get gitRecentRepositories => 'المستودعات الأخيرة';

  @override
  String get gitRemotes => 'المستودعات البعيدة';

  @override
  String get gitRemotesAndStashes => 'المستودعات البعيدة والمحفوظات';

  @override
  String get gitRepositoryDirectory => 'مجلد المستودع';

  @override
  String get gitRevert => 'تراجع';

  @override
  String get gitRevertAll => 'التراجع عن الكل';

  @override
  String get gitRevertAllDescription =>
      'سيؤدي ذلك إلى التخلص من كل تغييرات شجرة العمل غير الملتزم بها ولا يمكن التراجع عنه.';

  @override
  String get gitRevertAllQuestion => 'التراجع عن كل التغييرات؟';

  @override
  String gitRevertFailed(Object error) {
    return 'فشل التراجع: $error';
  }

  @override
  String get gitRevertFile => 'التراجع عن هذا الملف';

  @override
  String gitRevertFileDescription(Object file) {
    return 'سيؤدي ذلك إلى التخلص من تغييرات “$file” غير الملتزم بها ولا يمكن التراجع عنه.';
  }

  @override
  String get gitRevertFileQuestion => 'التراجع عن هذا الملف؟';

  @override
  String get gitSearchBranches => 'البحث في الفروع…';

  @override
  String get gitSearchCommits => 'البحث في رسائل الالتزام';

  @override
  String get gitSelectFileForDiff => 'اختر ملفًا لعرض الفرق';

  @override
  String get gitSelectFileForDiffDescription =>
      'اختر ملفًا متغيرًا من اليسار لعرض الفرق هنا';

  @override
  String get gitServerRepositoryPath => 'مسار المستودع على الخادم';

  @override
  String get gitStage => 'تجهيز';

  @override
  String gitStageFailed(Object error) {
    return 'فشلت عملية التجهيز: $error';
  }

  @override
  String gitStagedChanges(Object added, Object removed) {
    return 'مجهّز · +$added −$removed';
  }

  @override
  String get gitStashes => 'المحفوظات';

  @override
  String get gitSwitch => 'تبديل';

  @override
  String get gitSwitchBranch => 'تبديل الفرع';

  @override
  String gitSwitchBranchFailed(Object error) {
    return 'تعذر تبديل الفرع: $error';
  }

  @override
  String get gitUnknownAuthor => 'غير معروف';

  @override
  String get gitUnstage => 'إلغاء التجهيز';

  @override
  String get gitWorkingTreeClean => 'شجرة العمل نظيفة؛ لا تغييرات';

  @override
  String get gitWorktreeHasChanges =>
      'تحتوي شجرة العمل على تغييرات غير ملتزم بها';

  @override
  String get gitWorktreeNameHint => 'مثال: feature-login';

  @override
  String get gitWorktrees => 'أشجار العمل';

  @override
  String get globalSearch => 'بحث شامل';

  @override
  String get groupConfiguration => 'الإعدادات';

  @override
  String get groupIntegrations => 'التكاملات';

  @override
  String get groupIntelligence => 'الذكاء';

  @override
  String get groupSystem => 'النظام';

  @override
  String get groupWorkspace => 'مساحة العمل';

  @override
  String get helpAndFeedbackTitle => 'المساعدة والملاحظات';

  @override
  String get homeAllFeatures => 'كل الميزات';

  @override
  String get homeAttentionDetail => 'قد يكون Agent بانتظار تأكيدك';

  @override
  String homeBackendSummary(String model, String profile) {
    return 'الخادم متصل · $model · Profile: $profile';
  }

  @override
  String homeContinueSession(String title) {
    return 'متابعة «$title»';
  }

  @override
  String get homeContinueWork => 'تابع عملك';

  @override
  String get homeCurrentWork => 'العمل الحالي';

  @override
  String get homeDefaultProfile => 'الافتراضي';

  @override
  String get homeDragToReorder => 'اسحب لإعادة الترتيب';

  @override
  String get homeEditQuickTools => 'تعديل الأدوات السريعة';

  @override
  String get homeLastVisibleTool => 'آخر أداة ظاهرة في الرئيسية';

  @override
  String get homeLoadingRecent => 'جارٍ تحميل العمل الأخير…';

  @override
  String get homeMoreTools => 'أدوات أخرى';

  @override
  String homeNeedsAttention(int count) {
    return '$count عناصر تحتاج إلى معالجة';
  }

  @override
  String get homeNoWorkDescription => 'صف هدفك أعلاه لبدء أول مهمة';

  @override
  String get homeNoWorkTitle => 'لا يوجد سجل عمل بعد';

  @override
  String homeProfileTooltip(String profile) {
    return 'الملف الشخصي: $profile';
  }

  @override
  String get homeQuickTools => 'أدوات سريعة';

  @override
  String get homeQuickToolsDescription =>
      'تظهر أول 5 أدوات في الرئيسية، والباقي ضمن المزيد.';

  @override
  String get homeReadyTitle => 'Hermes جاهز';

  @override
  String get homeRecentSessions => 'الجلسات الأخيرة';

  @override
  String get homeRestoreDefaults => 'استعادة الافتراضيات';

  @override
  String get homeStartNewSession => 'جلسة جديدة';

  @override
  String get homeSwitchProfile => 'تبديل الملف الشخصي';

  @override
  String get homeToolKnowledge => 'المعرفة';

  @override
  String get homeViewAttentionSessions => 'عرض الجلسات المعلقة';

  @override
  String get homeViewSession => 'عرض الجلسة';

  @override
  String homeWorkingDetail(String model) {
    return 'تتم معالجة المهمة الحالية · $model';
  }

  @override
  String get homeWorkingTitle => 'Hermes يعمل';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageDescription => 'اختر لغة واجهة Hermes Mobile';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageSimplifiedChinese => '简体中文';

  @override
  String get languageSystem => 'لغة النظام';

  @override
  String get languageTitle => 'اللغة';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get legalPrivacy => 'سياسة الخصوصية';

  @override
  String get legalTerms => 'شروط الخدمة';

  @override
  String get legalTitle => 'الشؤون القانونية والتراخيص';

  @override
  String get modelAllFollowMain => 'جعل الكل يتبع النموذج الرئيسي';

  @override
  String get modelApply => 'تطبيق';

  @override
  String modelAuxiliarySaveFailed(String error) {
    return 'تعذر حفظ النموذج المساعد: $error';
  }

  @override
  String get modelAuxiliaryTitle => 'النماذج المساعدة';

  @override
  String get modelAuxiliaryUnavailable =>
      'لا توفر خلفية Hermes إعداد النماذج المساعدة.';

  @override
  String get modelChoose => 'اختيار نموذج';

  @override
  String get modelConfirmSelection => 'تأكيد اختيار النموذج';

  @override
  String get modelCreate => 'إنشاء';

  @override
  String get modelCurrent => 'قيد الاستخدام';

  @override
  String get modelDefaultTitle => 'النموذج الافتراضي';

  @override
  String get modelExpensiveWarning =>
      'قد تترتب على هذا النموذج تكلفة أعلى. هل تريد المتابعة؟';

  @override
  String get modelFallbackHint =>
      'fallback_providers (سطر واحد لكل provider:model)';

  @override
  String get modelFallbackTitle => 'النماذج الاحتياطية';

  @override
  String get modelFollowMain => 'اتباع النموذج الرئيسي';

  @override
  String get modelLabel => 'النموذج';

  @override
  String get modelMoaAddReference => 'إضافة نموذج مرجعي';

  @override
  String get modelMoaAggregator => 'المُجمِّع';

  @override
  String get modelMoaAggregatorMaxTokens => 'حد إخراج المُجمِّع';

  @override
  String get modelMoaAggregatorModel => 'نموذج المُجمِّع';

  @override
  String modelMoaAggregatorSummary(String provider, String model) {
    return 'المُجمِّع: $provider · $model';
  }

  @override
  String get modelMoaAggregatorTemperature => 'حرارة المُجمِّع';

  @override
  String get modelMoaCompleteModels => 'أكمل اختيار كل النماذج';

  @override
  String get modelMoaCreatePreset => 'إنشاء إعداد MoA مسبق';

  @override
  String get modelMoaCreateTooltip => 'إنشاء إعداد مسبق';

  @override
  String get modelMoaDefaultPreset => 'الإعداد الافتراضي';

  @override
  String get modelMoaDegradedLoud => 'إظهار التدهور';

  @override
  String get modelMoaDegradedPolicy => 'سياسة التدهور';

  @override
  String get modelMoaDegradedSilent => 'تدهور صامت';

  @override
  String get modelMoaDeleteTooltip => 'حذف الإعداد المسبق';

  @override
  String get modelMoaDescription =>
      'تجيب النماذج المرجعية بالتوازي وينشئ المُجمِّع النتيجة النهائية';

  @override
  String get modelMoaEditConfiguration => 'تحرير الإعداد';

  @override
  String modelMoaEditTitle(String name) {
    return 'تحرير $name';
  }

  @override
  String get modelMoaEnablePreset => 'تفعيل الإعداد المسبق';

  @override
  String get modelMoaFanoutCadence => 'وتيرة التوزيع';

  @override
  String get modelMoaFanoutHint => 'user_turn / per_iteration / every_n:2';

  @override
  String get modelMoaNoEditable => 'لا توجد إعدادات MoA مسبقة قابلة للتحرير.';

  @override
  String get modelMoaPresetLabel => 'الإعداد المسبق';

  @override
  String modelMoaReferenceCount(int count) {
    return '$count من النماذج المرجعية';
  }

  @override
  String get modelMoaReferenceMaxTokens => 'حد إخراج المرجع';

  @override
  String get modelMoaReferenceModels => 'النماذج المرجعية';

  @override
  String modelMoaReferenceNumber(int index) {
    return 'مرجع $index';
  }

  @override
  String get modelMoaReferenceTemperature => 'حرارة المرجع';

  @override
  String get modelMoaReferenceTimeout => 'مهلة المرجع (ثوانٍ)';

  @override
  String get modelMoaRuntimeParameters => 'معلمات التشغيل';

  @override
  String get modelMoaSaveConfiguration => 'حفظ الإعداد';

  @override
  String modelMoaSaveFailed(String error) {
    return 'تعذر حفظ إعداد MoA: $error';
  }

  @override
  String get modelMoaSetDefault => 'تعيين كافتراضي';

  @override
  String get modelMoaUnavailable => 'لا توفر خلفية Hermes إعداد MoA.';

  @override
  String get modelNoAvailable => 'لا توجد نماذج متاحة';

  @override
  String get modelPresetName => 'الاسم';

  @override
  String get modelProvider => 'المزوّد';

  @override
  String get modelProviderNotFound => 'تعذر العثور على مزوّد هذا النموذج';

  @override
  String modelRecommended(String model) {
    return 'موصى به: $model';
  }

  @override
  String get modelRemove => 'إزالة';

  @override
  String get modelSwitchDeferred =>
      'تمت جدولة تبديل النموذج وسيُطبّق بعد اكتمال الجولة الحالية';

  @override
  String modelSwitchFailed(String error) {
    return 'تعذر تبديل النموذج: $error';
  }

  @override
  String modelSwitchSucceeded(String model) {
    return 'تم التبديل إلى $model';
  }

  @override
  String get moreCloseSearch => 'إغلاق البحث';

  @override
  String get moreNoMatches => 'لا توجد ميزات مطابقة';

  @override
  String get moreSearchDirectory => 'بحث في القائمة';

  @override
  String get moreSearchHint => 'ابحث عن ميزة';

  @override
  String moreStatus(String connection, String agent) {
    return '$connection · Agent $agent';
  }

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navMore => 'المزيد';

  @override
  String get navSessions => 'الجلسات';

  @override
  String get navTasks => 'المهام';

  @override
  String get notificationClear => 'مسح';

  @override
  String get notificationClearConfirmTitle => 'مسح جميع الإشعارات؟';

  @override
  String get notificationClearConfirmBody =>
      'سيؤدي هذا إلى إزالة جميع الإشعارات من هذه القائمة. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get notificationEmptyDescription =>
      'تظهر هنا عمليات اكتمال Agent والموافقات والأخطاء';

  @override
  String get notificationEmptyTitle => 'لا توجد إشعارات';

  @override
  String get notificationMarkAllRead => 'تحديد الكل كمقروء';

  @override
  String notificationOpenFailed(String error) {
    return 'تعذر فتح الجلسة: $error';
  }

  @override
  String get notificationOpenSession => 'عرض الجلسة';

  @override
  String get notificationTitle => 'الإشعارات';

  @override
  String get paletteHint => 'البحث في الصفحات والجلسات والأوامر…';

  @override
  String get paletteHintClose => 'إغلاق';

  @override
  String get paletteHintNavigate => 'التنقل';

  @override
  String get paletteHintOpen => 'فتح';

  @override
  String get paletteKanban => 'لوحة كانبان';

  @override
  String get paletteKindAction => 'إجراء';

  @override
  String get paletteKindCommand => 'أمر';

  @override
  String get paletteKindPage => 'صفحة';

  @override
  String get paletteKindSession => 'جلسة';

  @override
  String get paletteNewSessionDesc => 'بدء محادثة جديدة';

  @override
  String get paletteNoResults => 'لا توجد نتائج مطابقة';

  @override
  String get paletteReconnect => 'إعادة الاتصال';

  @override
  String get paletteReconnectDesc => 'إعادة الاتصال بالخادم';

  @override
  String get paletteVoiceInput => 'إدخال صوتي';

  @override
  String get paletteVoiceInputDesc => 'بدء الإملاء الصوتي';

  @override
  String pluginActionFailed(String title, String error) {
    return 'فشل $title: $error';
  }

  @override
  String get pluginFieldInvalidNumber => 'أدخل رقمًا صالحًا';

  @override
  String pluginFieldMaximum(num value) {
    return 'الحد الأقصى: $value';
  }

  @override
  String pluginFieldMinimum(num value) {
    return 'الحد الأدنى: $value';
  }

  @override
  String get pluginFieldRequired => 'هذا الحقل مطلوب';

  @override
  String pluginItemFallback(int index) {
    return 'العنصر $index';
  }

  @override
  String get pluginNoItems => 'لا توجد عناصر';

  @override
  String get pluginResultCopied => 'تم نسخ النتيجة';

  @override
  String get pluginResultCopy => 'نسخ النتيجة';

  @override
  String get pluginResultOpenLink => 'فتح الرابط';

  @override
  String get pluginSubmit => 'إرسال';

  @override
  String previewActionSendFailed(String error) {
    return 'تعذر إرسال إجراء المعاينة: $error';
  }

  @override
  String previewActionSent(String prompt) {
    return 'تم إرسال إجراء المعاينة: $prompt';
  }

  @override
  String get previewBack => 'رجوع';

  @override
  String get previewClearConsole => 'مسح وحدة التحكم';

  @override
  String get previewCloseConsole => 'إغلاق وحدة التحكم';

  @override
  String get previewConsoleTitle => 'وحدة التحكم';

  @override
  String get previewEmpty => 'افتح رابطًا في الدردشة أو اختر ملف HTML';

  @override
  String previewFailed(String error) {
    return 'فشلت المعاينة: $error';
  }

  @override
  String get previewForward => 'تقدم';

  @override
  String get previewNoLogs => 'لا توجد سجلات';

  @override
  String get previewOpenBrowser => 'فتح في المتصفح';

  @override
  String get previewOpenConsole => 'فتح وحدة التحكم';

  @override
  String previewOpenSessionFailed(String error) {
    return 'تعذر فتح الجلسة: $error';
  }

  @override
  String get previewRefresh => 'تحديث المعاينة';

  @override
  String get previewRunJavascript => 'تشغيل JavaScript';

  @override
  String get previewRunScript => 'تشغيل البرنامج النصي';

  @override
  String get previewTitle => 'المعاينة';

  @override
  String get previewUnsupportedWebView =>
      'لا تتوفر WebView مضمّنة على هذه المنصة. افتحها في المتصفح.';

  @override
  String get projectBrowseFiles => 'تصفح مجلد المشروع';

  @override
  String get projectDetailTitle => 'تفاصيل المشروع';

  @override
  String projectFolderCount(int count) {
    return '$count مجلد';
  }

  @override
  String get projectGitDescription => 'عرض حالة المستودع والتغييرات';

  @override
  String get projectGlobalMemoryDescription => 'ذاكرة الملف الشخصي (عرض عام)';

  @override
  String get projectGlobalStarmapDescription => 'رسم المعرفة (عرض عام)';

  @override
  String get projectGlobalSubagentsDescription =>
      'نشاط الوكلاء الفرعيين عبر الجلسات';

  @override
  String get projectGlobalWebhooksDescription => 'إعداد Webhook (عرض عام)';

  @override
  String get projectLoadingSessions => 'جارٍ تحميل الجلسات…';

  @override
  String get projectModulesTitle => 'الوحدات';

  @override
  String get projectNoKanbanBoard => 'لا توجد لوحة مرتبطة بهذا المشروع';

  @override
  String get projectNoSessions => 'لا توجد جلسات مرتبطة';

  @override
  String get projectNoSessionsDescription =>
      'تظهر هنا الجلسات التي بدأت داخل هذا المشروع';

  @override
  String projectResumeFailed(String error) {
    return 'تعذر استئناف الجلسة: $error';
  }

  @override
  String projectSessionCount(int count) {
    return '$count جلسة';
  }

  @override
  String get projectSessionsTitle => 'الجلسات';

  @override
  String get projectTasksDescription => 'فتح لوحة مرتبطة بهذا المشروع';

  @override
  String get projectTasksTitle => 'المهام واللوحات';

  @override
  String get projectUnavailable => 'غير متاح';

  @override
  String get projectUntitled => 'مشروع بلا عنوان';

  @override
  String get providerActiveDefault => 'نشط / افتراضي';

  @override
  String get providerAddEndpointTitle => 'نقطة نهاية مخصصة جديدة';

  @override
  String get providerCustomEndpointJson => 'JSON لنقطة النهاية المخصصة';

  @override
  String get providerCustomEndpointsSection => 'نقاط النهاية المخصصة';

  @override
  String get providerDeviceAuthorization => 'تفويض الجهاز';

  @override
  String get providerEditEndpointTitle => 'تعديل نقطة النهاية المخصصة';

  @override
  String get providerEndpointApiKey => 'مفتاح API';

  @override
  String get providerEndpointBaseUrl => 'Base URL';

  @override
  String get providerEndpointDefaultModel => 'النموذج الافتراضي';

  @override
  String get providerEndpointDiscoverModels => 'اكتشاف النماذج تلقائيًا';

  @override
  String get providerEndpointFallback => 'نقطة نهاية';

  @override
  String get providerEndpointModelsList =>
      'النماذج المتاحة (سطر واحد لكل نموذج)';

  @override
  String get providerEndpointName => 'الاسم';

  @override
  String get providerEndpointNameRequired => 'الرجاء إدخال الاسم';

  @override
  String get providerEndpointUrlRequired => 'الرجاء إدخال Base URL';

  @override
  String providerEnterDeviceCode(String code) {
    return 'أدخل رمز التحقق هذا في المتصفح: $code';
  }

  @override
  String providerActionFailed(String error) {
    return 'فشل الإجراء: $error';
  }

  @override
  String get providerEnvironmentSection => 'متغيرات البيئة';

  @override
  String get providerEnvironmentVariableName => 'اسم متغير البيئة';

  @override
  String get providerEnvironmentVariableValue => 'قيمة متغير البيئة';

  @override
  String providerMissingKeys(String keys) {
    return 'مفقود: $keys';
  }

  @override
  String providerModelTitle(String provider) {
    return 'نموذج $provider';
  }

  @override
  String get providerNoConfiguration => 'لا يوجد إعداد';

  @override
  String get providerNotSet => 'غير معيّن';

  @override
  String get providerOauthSection => 'OAuth للموفر';

  @override
  String get providerPasteOauthCode => 'لصق رمز OAuth';

  @override
  String get providerProfileLabel => 'ملف التعريف';

  @override
  String providerRevealFailed(String error) {
    return 'تعذرت قراءة القيمة: $error';
  }

  @override
  String get providerRevealValue => 'إظهار القيمة';

  @override
  String get providerRevealedValueTitle => 'القيمة المحفوظة';

  @override
  String providerRunSetupDescription(String provider, String command) {
    return 'يحتاج $provider إلى تشغيل: $command';
  }

  @override
  String get providerRunSetupQuestion => 'هل تريد تشغيل إعداد الموفر؟';

  @override
  String get providerSetActive => 'تعيين كنشط';

  @override
  String providerSetEnvironmentVariable(String key) {
    return 'تعيين $key';
  }

  @override
  String providerToolsCount(int count) {
    return '$count أداة';
  }

  @override
  String providerToolsetProviderTitle(String toolset) {
    return 'موفر $toolset';
  }

  @override
  String get providerToolsetProvidersSection => 'موفرو مجموعات الأدوات';

  @override
  String get pushEnabled => 'الإشعارات عن بُعد';

  @override
  String get pushEnabledDescription => 'تسجيل هذا الجهاز في خادم Hermes النشط';

  @override
  String get pushOsPermissionDenied => 'تم حظر إشعارات النظام';

  @override
  String get pushOsPermissionDeniedDescription =>
      'تم تفعيل الإشعارات عن بُعد في Hermes، لكن نظام التشغيل يحظرها، لذا لن يصل أي إشعار فعليًا. فعّل إشعارات Hermes Mobile من إعدادات النظام على جهازك.';

  @override
  String get pushNoProviders => 'لم تُضبط بيانات اعتماد APNs أو FCM على الخادم';

  @override
  String get pushNotRegistered => 'غير مسجل';

  @override
  String get pushProviders => 'خدمات الإرسال';

  @override
  String get pushRefresh => 'تحديث حالة الإشعارات';

  @override
  String get pushRegistered => 'مسجل للاتصال والملف النشطين';

  @override
  String get pushRegistration => 'تسجيل الجهاز';

  @override
  String get pushSendTest => 'إرسال إشعار تجريبي';

  @override
  String get pushSettingsDescription =>
      'استلم إشعارات الاكتمال وطلبات الموافقة عند إغلاق Hermes Mobile.';

  @override
  String get pushSettingsTitle => 'الإشعارات عن بُعد';

  @override
  String get pushTestDelivered => 'تم إرسال الإشعار التجريبي';

  @override
  String pushTestFailed(String error) {
    return 'تعذر إرسال الإشعار التجريبي: $error';
  }

  @override
  String get pushTestNotDelivered =>
      'لم تنجح أي خدمة في إرسال الإشعار التجريبي';

  @override
  String get reportIssueTitle => 'الإبلاغ عن مشكلة على GitHub';

  @override
  String get sendDiagnosticsSubtitle =>
      'تحميل سجلات منقّحة لمساعدتنا في حل المشكلة';

  @override
  String get sendDiagnosticsTitle => 'إرسال معلومات التشخيص';

  @override
  String get sessionActions => 'إجراءات الجلسة';

  @override
  String get sessionAllTags => 'كل الوسوم';

  @override
  String get sessionArchiveView => 'عرض الأرشيف';

  @override
  String get sessionArchiveViewDescription => 'إظهار الجلسات المؤرشفة فقط';

  @override
  String sessionBatchDeleteDescription(int count) {
    return 'سيتم حذف الجلسات المحددة وعددها $count نهائياً ولا يمكن التراجع.';
  }

  @override
  String get sessionBatchDeleteTitle => 'حذف الجلسات؟';

  @override
  String get sessionCancelSelection => 'إلغاء التحديد';

  @override
  String get sessionClearAll => 'مسح الكل';

  @override
  String get sessionClearFilters => 'مسح عوامل التصفية';

  @override
  String get sessionClearSearch => 'مسح البحث';

  @override
  String get sessionCollapseChildren => 'طي الجلسات الفرعية';

  @override
  String get sessionConfirmDelete => 'حذف نهائي';

  @override
  String get sessionContinueLast => 'متابعة الجلسة السابقة';

  @override
  String get sessionDeepSearchHint => 'ابحث في عناوين الجلسات وسجل الرسائل';

  @override
  String get sessionDeepSearchTitle => 'بحث في سجل المحادثة';

  @override
  String sessionDeleteDescription(String title) {
    return 'سيتم حذف «$title» نهائياً.';
  }

  @override
  String sessionDeleteFailed(String error) {
    return 'تعذر الحذف: $error';
  }

  @override
  String get sessionDeleteSelected => 'حذف المحدد';

  @override
  String get sessionDeleteTitle => 'حذف الجلسة؟';

  @override
  String sessionDeletedCount(int count) {
    return 'تم حذف $count جلسات';
  }

  @override
  String sessionDurationDaysHours(int days, int hours) {
    return '$daysي $hoursس';
  }

  @override
  String sessionDurationHoursMinutes(int hours, int minutes) {
    return '$hoursس $minutesد';
  }

  @override
  String sessionDurationMinutes(int minutes) {
    return '$minutesد';
  }

  @override
  String get sessionEmptyDescription => 'ابدأ جلسة جديدة للتحدث مع Hermes';

  @override
  String get sessionEmptyTitle => 'لا توجد جلسات بعد';

  @override
  String get sessionExpandChildren => 'توسيع الجلسات الفرعية';

  @override
  String get sessionFilterAll => 'الكل';

  @override
  String get sessionFilterApproval => 'تحتاج موافقة';

  @override
  String get sessionFilterByTag => 'تصفية حسب الوسم';

  @override
  String get sessionFilterCompleted => 'مكتملة';

  @override
  String get sessionFilterTitle => 'تصفية الجلسات';

  @override
  String get sessionGroupArchived => 'مؤرشفة';

  @override
  String get sessionGroupByProject => 'تجميع حسب المشروع';

  @override
  String get sessionGroupByTime => 'تجميع حسب الوقت';

  @override
  String get sessionGroupLast7Days => 'آخر 7 أيام';

  @override
  String get sessionGroupOlder => 'أقدم';

  @override
  String get sessionGroupPinned => 'مثبتة';

  @override
  String get sessionGroupRunning => 'قيد التشغيل';

  @override
  String sessionHandoff(String state) {
    return 'تسليم $state';
  }

  @override
  String get sessionHistoryArchive => 'أرشيف السجل';

  @override
  String get sessionLoadMore => 'تحميل جلسات أخرى';

  @override
  String get sessionManage => 'إدارة الجلسات';

  @override
  String sessionMessageCount(int count) {
    return '$count رسائل';
  }

  @override
  String get sessionNew => 'جلسة جديدة';

  @override
  String get sessionNoMatchesDescription => 'عدّل البحث أو عوامل تصفية الحالة';

  @override
  String get sessionNoMatchesTitle => 'لا توجد جلسات مطابقة';

  @override
  String get sessionNoProjectsDescription =>
      'تُجمع الجلسات التي تبدأ في مستودعات Git ضمن المشاريع تلقائياً';

  @override
  String get sessionNoProjectsTitle => 'لا توجد مشاريع';

  @override
  String sessionOpenCopyFailed(String error) {
    return 'تعذر فتح النسخة: $error';
  }

  @override
  String get sessionPrClosed => 'مغلقة';

  @override
  String get sessionPrDraft => 'مسودة';

  @override
  String get sessionPrMerged => 'مدمجة';

  @override
  String get sessionPrNone => 'بلا PR';

  @override
  String get sessionPrOpen => 'مفتوحة';

  @override
  String get sessionProjectBack => 'العودة إلى المشاريع';

  @override
  String get sessionProjectEnter => 'فتح';

  @override
  String get sessionProjectNoSessions => 'لا توجد جلسات في هذا المشروع';

  @override
  String sessionProjectSessionCount(int count) {
    return '$count جلسات';
  }

  @override
  String get sessionProjectUnavailable => 'المشروع غير متاح';

  @override
  String get sessionPullRequests => 'طلبات السحب';

  @override
  String sessionResumeFailed(String error) {
    return 'تعذرت استعادة الجلسة: $error';
  }

  @override
  String sessionResumeLastFailed(String error) {
    return 'تعذرت استعادة الجلسة السابقة: $error';
  }

  @override
  String sessionResumeSubagentFailed(String error) {
    return 'تعذرت استعادة جلسة الوكيل الفرعي: $error';
  }

  @override
  String sessionSearchFailed(String error) {
    return 'فشل البحث: $error';
  }

  @override
  String get sessionSearchMessages => 'بحث في الرسائل';

  @override
  String get sessionSearchNoFilteredResults =>
      'لا توجد نتائج تطابق عوامل التصفية الحالية';

  @override
  String get sessionSearchPrompt => 'أدخل كلمات للبحث في سجل الجلسات';

  @override
  String sessionSearchResultCount(int total, int visible) {
    return 'تم العثور على $total جلسة، المعروض $visible';
  }

  @override
  String get sessionSearchTitleHint => 'ابحث في عناوين الجلسات…';

  @override
  String get sessionSelectAll => 'تحديد الكل';

  @override
  String get sessionSelectDescription => 'افتح جلسة من القائمة لمتابعة العمل';

  @override
  String get sessionSelectMultiple => 'تحديد متعدد';

  @override
  String get sessionSelectSessions => 'تحديد الجلسات';

  @override
  String get sessionSelectTitle => 'اختر جلسة';

  @override
  String sessionSelectedCount(int count) {
    return 'تم تحديد $count';
  }

  @override
  String get sessionServerNotConnected => 'الخادم غير متصل';

  @override
  String get sessionSortActivity => 'النشاط الأخير';

  @override
  String get sessionSortCreated => 'تاريخ الإنشاء';

  @override
  String get sessionSortTitle => 'الترتيب حسب';

  @override
  String get sessionSortTokens => 'استخدام التوكن';

  @override
  String get sessionStatusAttention => 'تحتاج إلى إجراء';

  @override
  String get sessionStatusIdle => 'خاملة';

  @override
  String get sessionStatusWorking => 'قيد العمل';

  @override
  String get sessionTimeAll => 'كل الوقت';

  @override
  String get sessionTitle => 'الجلسات';

  @override
  String sessionToolCount(int count) {
    return '$count أدوات';
  }

  @override
  String get sessionUntitled => 'جلسة بلا عنوان';

  @override
  String sessionWithinDays(int count) {
    return 'خلال $count أيام';
  }

  @override
  String get settingsAppearanceDesc => 'وضع العرض ولون السمة والتباين العالي';

  @override
  String get settingsBackHome => 'العودة إلى الرئيسية';

  @override
  String get settingsBackendConfigSummary => 'ملخص إعداد الخادم';

  @override
  String get settingsBackendConfigSummaryDesc => 'قيم الإعداد الأساسية';

  @override
  String get settingsBackendConnectionSection => 'الخادم والاتصال';

  @override
  String settingsBackendRestartFailed(String error) {
    return 'تعذرت إعادة تشغيل الخادم: $error';
  }

  @override
  String get settingsBackendRestarted => 'تمت إعادة تشغيل الخادم';

  @override
  String get settingsCapabilitiesDesc =>
      'MCP والمعرفة والمهارات والمكونات الإضافية';

  @override
  String get settingsCapabilitiesTitle => 'إدارة الإمكانات';

  @override
  String get settingsChangeConnection => 'تغيير الاتصال';

  @override
  String get settingsChangeConnectionDesc => 'تعديل عنوان الخادم ومفتاح API';

  @override
  String get settingsChangeConnectionQuestion => 'هل تريد تغيير الاتصال؟';

  @override
  String get settingsChangeConnectionWarning =>
      'سيتم مسح اتصال الخادم الحالي لتتمكن من إدخال عنوان خادم ومفتاح API جديدين.';

  @override
  String get settingsGroupModels => 'النماذج والإمكانات';

  @override
  String get settingsGroupPersonalization => 'التخصيص';

  @override
  String get settingsModelDesc => 'النماذج والمحادثات وسياق الذاكرة والمفاتيح';

  @override
  String get settingsModelTitle => 'النماذج والمحادثات';

  @override
  String get settingsProvidersDesc =>
      'متغيرات البيئة والنقاط المخصصة وOAuth ومزودو الأدوات';

  @override
  String get settingsProvidersTitle => 'المزودون وبيئة التشغيل';

  @override
  String get settingsRestartBackend => 'إعادة تشغيل خادم Hermes';

  @override
  String get settingsRestartBackendDesc =>
      'إيقاف العمل الحالي وإعادة تشغيل عملية الخادم';

  @override
  String get settingsRestartBackendQuestion =>
      'هل تريد إعادة تشغيل خادم Hermes؟';

  @override
  String get settingsRestartBackendWarning =>
      'ستتوقف الجلسات قيد التشغيل على الخادم.';

  @override
  String get settingsSystemConnectionDesc =>
      'الاتصال والأمان والطرفية والخلفية';

  @override
  String get settingsSystemConnectionTitle => 'النظام والاتصال';

  @override
  String get settingsTerminalSection => 'الطرفية';

  @override
  String get taskAll => 'الكل';

  @override
  String taskAssigneeFilter(String value) {
    return 'المسؤول: $value';
  }

  @override
  String get taskAutoDecompose => 'تقسيم المهام تلقائيًا';

  @override
  String get taskAutoGenerate => 'إنشاء تلقائي';

  @override
  String get taskBoardView => 'لوحة';

  @override
  String taskBulkFailed(int count) {
    return 'تعذر تحديث $count من المهام';
  }

  @override
  String get taskClearFilters => 'مسح عوامل التصفية';

  @override
  String get taskCloseSearch => 'إغلاق البحث';

  @override
  String taskCommentCount(int count) {
    return '$count تعليق';
  }

  @override
  String get taskConnectBackend => 'اتصل بالخادم لعرض المهام';

  @override
  String get taskDefault => 'افتراضي';

  @override
  String get taskDefaultAssignee => 'المسؤول الافتراضي';

  @override
  String get taskFilter => 'عوامل التصفية';

  @override
  String get taskListView => 'قائمة';

  @override
  String get taskNew => 'مهمة جديدة';

  @override
  String get taskNoDescription => 'بلا وصف';

  @override
  String get taskOptions => 'خيارات المهام';

  @override
  String get taskOrchestration => 'التنسيق';

  @override
  String get taskOrchestratorProfile => 'ملف المنسق';

  @override
  String get taskPriorityHigh => 'عالية';

  @override
  String taskPriorityMeta(String priority) {
    return 'الأولوية: $priority';
  }

  @override
  String get taskPriorityNormal => 'عادية';

  @override
  String get taskPriorityUrgent => 'عاجلة';

  @override
  String taskProfileDescription(String name) {
    return 'وصف $name';
  }

  @override
  String get taskProfileDescriptions => 'أوصاف الملفات الشخصية';

  @override
  String get taskSearch => 'البحث في المهام';

  @override
  String taskSelectedCount(int count) {
    return 'تم تحديد $count';
  }

  @override
  String get taskShowArchived => 'إظهار المؤرشفة';

  @override
  String get taskStatusArchived => 'مؤرشفة';

  @override
  String get taskStatusBlocked => 'محظورة';

  @override
  String get taskStatusDone => 'مكتملة';

  @override
  String get taskStatusReady => 'جاهزة';

  @override
  String get taskStatusReview => 'مراجعة';

  @override
  String get taskStatusRunning => 'قيد التنفيذ';

  @override
  String get taskStatusScheduled => 'مجدولة';

  @override
  String get taskStatusTodo => 'للعمل';

  @override
  String get taskStatusTriage => 'فرز';

  @override
  String get taskSwitchBoard => 'تبديل اللوحة';

  @override
  String taskTenantFilter(String value) {
    return 'المستأجر: $value';
  }

  @override
  String get taskTitle => 'المهام';

  @override
  String get taskUnassigned => 'غير معيّن';

  @override
  String get taskWeeklyDelivery => 'إنجاز الأسبوع';

  @override
  String get terminalDefaultMonospace => 'الخط أحادي المسافة الافتراضي';

  @override
  String get terminalFontHint =>
      'اتركه فارغًا لاستخدام الخط أحادي المسافة الافتراضي';

  @override
  String get terminalFontPreview => 'معاينة  ~/project  git:main  >';

  @override
  String terminalFontSaveFailed(String error) {
    return 'تعذر حفظ خط الطرفية: $error';
  }

  @override
  String get terminalFontSaved => 'تم حفظ خط الطرفية';

  @override
  String get terminalFontTitle => 'خط الطرفية';

  @override
  String timeDaysAgo(int count) {
    return 'قبل $count أيام';
  }

  @override
  String timeHoursAgo(int count) {
    return 'قبل $count ساعة';
  }

  @override
  String get timeJustNow => 'الآن';

  @override
  String timeMinutesAgo(int count) {
    return 'قبل $count دقيقة';
  }

  @override
  String get updateAppVersion => 'إصدار التطبيق';

  @override
  String updateAvailableTitle(String version) {
    return 'يتوفر التحديث إلى $version';
  }

  @override
  String get updateCheck => 'التحقق من التحديثات';

  @override
  String get updateCheckDescription =>
      'التحقق من بيان إصدار الهاتف المحمول بحثًا عن إصدار جديد';

  @override
  String get updateCheckFailed => 'فشل التحقق من التحديث';

  @override
  String updateCheckUnavailable(String error) {
    return 'غير متاح مؤقتًا: $error';
  }

  @override
  String get updateCurrent => 'أنت تستخدم أحدث إصدار';

  @override
  String updateFound(String version) {
    return 'الإصدار $version متاح';
  }

  @override
  String get updateGoToUpdate => 'تحديث';

  @override
  String updateMinimumVersion(String minimumVersion) {
    return 'أدنى إصدار متوافق: $minimumVersion';
  }

  @override
  String get updateNewVersionPublished => 'تم إصدار نسخة جديدة';

  @override
  String get updateReleaseNotes => 'ملاحظات الإصدار';

  @override
  String updateRequiredDefault(String currentVersion, String minimumVersion) {
    return 'الإصدار الحالي $currentVersion أقدم من الحد الأدنى المتوافق $minimumVersion. حدّث التطبيق للمتابعة.';
  }

  @override
  String get updateRequiredTitle => 'يلزم تحديث Hermes Mobile';

  @override
  String get updateSectionTitle => 'التحديثات';

  @override
  String get updateUnsupportedTitle => 'لم يعد هذا الإصدار مدعومًا';

  @override
  String updateVersionBuild(String version, String build) {
    return 'v$version · build $build';
  }

  @override
  String get workspaceAddPaneTooltip => 'فتح جزء';

  @override
  String get workspaceApplyLayoutTooltip => 'تطبيق تخطيط';

  @override
  String get workspaceCloseAllAction => 'إغلاق الكل';

  @override
  String get workspaceCloseAllDescription =>
      'سيؤدي هذا إلى إغلاق مساحة العمل على الهاتف فقط، ولن يحذف الجلسات أو بيانات الإضافات.';

  @override
  String get workspaceCloseAllQuestion => 'إغلاق كل الأجزاء؟';

  @override
  String get workspaceCloseAllTooltip => 'إغلاق كل الأجزاء';

  @override
  String get workspaceEmptyDescription =>
      'افتح المحتوى من قائمة جلسة أو من مدخل جزء إضافة';

  @override
  String get workspaceEmptyTitle => 'مساحة العمل فارغة';

  @override
  String get workspaceLayoutDefault => 'الافتراضي';

  @override
  String get workspaceLayoutFocus => 'التركيز';

  @override
  String get workspaceLayoutQuad => 'رباعي';

  @override
  String get workspaceLayoutTerminalDeck => 'لوحة الطرفية';

  @override
  String get workspaceLayoutTooltip => 'ضبط تخطيط الأجزاء';

  @override
  String get workspaceMergeTabs => 'دمج كعلامات تبويب';

  @override
  String get workspaceMoveBottom => 'نقل إلى الأسفل';

  @override
  String get workspaceMoveLeft => 'نقل إلى اليسار';

  @override
  String get workspaceMoveRight => 'نقل إلى اليمين';

  @override
  String get workspaceMoveTop => 'نقل إلى الأعلى';

  @override
  String workspaceOpenPluginFailed(String error) {
    return 'تعذر فتح جزء الإضافة: $error';
  }

  @override
  String workspaceOpenSessionFailed(String error) {
    return 'تعذر فتح مساحة العمل: $error';
  }

  @override
  String get workspacePaneFiles => 'الملفات';

  @override
  String get workspacePaneLogs => 'السجلات';

  @override
  String get workspacePanePreview => 'المعاينة';

  @override
  String get workspacePaneReview => 'المراجعة';

  @override
  String get workspacePaneTerminal => 'الطرفية';

  @override
  String get workspacePluginUnavailable =>
      'جزء الإضافة غير متاح. تحقق من تفعيل الإضافة.';

  @override
  String workspaceSessionResumeFailed(String error) {
    return 'تعذرت استعادة الجلسة: $error';
  }

  @override
  String get workspaceTitle => 'مساحة العمل';

  @override
  String statusSemantics(String label) {
    return 'الحالة: $label';
  }

  @override
  String statusAgentSemantics(String label) {
    return 'حالة الوكيل: $label';
  }

  @override
  String statusToolSemantics(String label) {
    return 'حالة الأداة: $label';
  }

  @override
  String get statusIdle => 'خامل';

  @override
  String get statusThinking => 'جارٍ التفكير';

  @override
  String get statusPlanning => 'جارٍ التخطيط';

  @override
  String get statusRunning => 'قيد التشغيل';

  @override
  String get statusWaiting => 'قيد الانتظار';

  @override
  String get statusAwaitingApproval => 'بانتظار الموافقة';

  @override
  String get statusPaused => 'متوقف مؤقتًا';

  @override
  String get statusCompleted => 'مكتمل';

  @override
  String get statusFailed => 'فشل';

  @override
  String get statusStopped => 'متوقف';

  @override
  String get statusCancelled => 'ملغى';

  @override
  String get composerUndoInput => 'التراجع عن الإدخال';

  @override
  String get composerRedoInput => 'إعادة الإدخال';

  @override
  String get composerReadOnly => 'جلسات الوكلاء الفرعيين للقراءة فقط';

  @override
  String get composerMessageHint => 'إرسال رسالة إلى Hermes…';

  @override
  String composerProfileValue(String value) {
    return 'ملف التعريف: $value';
  }

  @override
  String get composerSelectProfile => 'اختيار ملف تعريف';

  @override
  String composerWorkspaceValue(String value) {
    return 'مساحة العمل: $value';
  }

  @override
  String get composerSelectWorkspace => 'اختيار مساحة عمل';

  @override
  String composerModelValue(String value) {
    return 'النموذج: $value';
  }

  @override
  String get composerSelectModel => 'اختيار نموذج';

  @override
  String composerDifficultyValue(String value) {
    return 'الصعوبة: $value';
  }

  @override
  String composerYoloModeValue(String value) {
    return 'وضع Yolo: $value';
  }

  @override
  String get composerEnabled => 'مفعل';

  @override
  String get composerDisabled => 'معطل';

  @override
  String get composerConfigureToolsets => 'تهيئة مجموعات الأدوات';

  @override
  String get composerCloseEmojiPanel => 'إغلاق لوحة الرموز التعبيرية';

  @override
  String get composerEmoji => 'رمز تعبيري';

  @override
  String get composerEditorActions => 'إجراءات المحرر';

  @override
  String get composerClearInput => 'مسح الإدخال';

  @override
  String get composerEnterSendsTooltip =>
      'Enter للإرسال وShift+Enter لسطر جديد';

  @override
  String get composerEnterNewlineTooltip =>
      'Enter لسطر جديد؛ اضغط إرسال للإرسال';

  @override
  String get composerEnterSends => 'Enter للإرسال';

  @override
  String get composerEnterNewline => 'Enter لسطر جديد';

  @override
  String composerRemoveAttachment(String label) {
    return 'إزالة المرفق: $label';
  }

  @override
  String get composerFolderNotUploaded =>
      'مرجع لمجلد محلي — لن يُرسل إلى الخادم';

  @override
  String get composerCurrentDefault => 'الإعداد الافتراضي لملف التعريف الحالي';

  @override
  String get composerUsedDefaultTools => 'تم استخدام إعداد الأدوات الافتراضي';

  @override
  String composerAppliedTools(int count) {
    return 'تم تطبيق $count أداة';
  }

  @override
  String get composerSwitchedToDefault => 'تم التبديل إلى الإعداد الافتراضي';

  @override
  String get composerToolConfiguration => 'إعدادات الأدوات';

  @override
  String get composerToolConfigurationDescription =>
      'استخدم الأدوات الافتراضية لملف التعريف الحالي أو اختر مجموعات أدوات مخصصة لهذه الجلسة';

  @override
  String get composerUseCurrentDefault => 'استخدام الإعداد الافتراضي الحالي';

  @override
  String get composerSelectCustomTools => 'اختيار أدوات مخصصة لهذه الجلسة';

  @override
  String get composerConfiguredMcpServers => 'خوادم MCP المهيأة';

  @override
  String get composerNoConfiguredMcpServers => 'لا توجد خوادم MCP مهيأة';

  @override
  String get composerUseDefault => 'استخدام الافتراضي';

  @override
  String get composerApply => 'تطبيق';

  @override
  String get commonRemove => 'إزالة';

  @override
  String get onboardingChatTitle => 'الدردشة مع Hermes';

  @override
  String get onboardingChatDescription =>
      'ابدأ الجلسات واستخدم الإدخال الصوتي وراجع استدعاءات الأدوات والتفكير وتابع المحادثات السابقة.';

  @override
  String get onboardingProjectsTitle => 'المشاريع والجلسات';

  @override
  String get onboardingProjectsDescription =>
      'تُنظّم الجلسات حسب المشروع وفرع Git وworktree، مع التثبيت والأرشفة وعوامل تصفية الحالة.';

  @override
  String get onboardingTerminalTitle => 'الطرفية وGit';

  @override
  String get onboardingTerminalDescription =>
      'شغّل الأوامر وراجع الفروقات وجهّز التغييرات وثبّتها وأنشئ طلبات السحب من الهاتف.';

  @override
  String get onboardingPaletteTitle => 'لوحة الأوامر';

  @override
  String get onboardingPaletteDescription =>
      'افتح لوحة الأوامر من البحث أو بالسحب للأسفل للانتقال إلى الميزات أو الجلسات الأخيرة أو أوامر الشرطة المائلة.';

  @override
  String get onboardingPetTitle => 'حيوانك الأليف بالذكاء الاصطناعي';

  @override
  String get onboardingPetDescription =>
      'حيوان أليف يتفاعل مع حالة المهمة ويمكن إنشاء مظهر خاص له.';

  @override
  String get onboardingSkip => 'تخطي';

  @override
  String get onboardingStart => 'البدء';

  @override
  String get onboardingNext => 'التالي';

  @override
  String get petGenerateInputRequired => 'أدخل وصفًا أو أضف صورة مرجعية';

  @override
  String get petGenerateEmptyResult => 'لم يتم إنشاء أي مسودات';

  @override
  String petGenerateHatchFailed(Object error) {
    return 'فشل الفقس: $error';
  }

  @override
  String petGenerateAdoptFailed(Object error) {
    return 'فشل التبني: $error';
  }

  @override
  String get petGenerateTitle => 'إنشاء حيوان أليف جديد';

  @override
  String get petGenerateDescribe => 'صف الحيوان الأليف الذي تريده';

  @override
  String get petGeneratePromptHint => 'مثال: قطة آلية بأسلوب سايبربانك';

  @override
  String get petGenerateAddReference => 'إضافة صورة مرجعية (اختياري)';

  @override
  String get petGenerateReferenceHelp => 'ستستخدم كل مسودة هذه الصورة كمرجع';

  @override
  String get petGenerateModel => 'نموذج الإنشاء';

  @override
  String get petGenerateAutoSelect => 'اختيار تلقائي';

  @override
  String get petGenerateDraftsAction => 'إنشاء 4 مسودات';

  @override
  String petGenerateProgress(Object done, Object total) {
    return 'جارٍ إنشاء المسودات… ($done/$total)';
  }

  @override
  String get petGenerateChooseDraft => 'اختر مسودتك المفضلة';

  @override
  String petGenerateDraftLabel(Object index) {
    return 'المسودة $index';
  }

  @override
  String get petGenerateAgain => 'إنشاء مرة أخرى';

  @override
  String get petGenerateHatch => 'فقس';

  @override
  String get petGeneratePreparing => 'جارٍ التحضير…';

  @override
  String petGenerateDrawingProgress(Object done, Object state, Object total) {
    return 'رسم إطارات $state ($done/$total)';
  }

  @override
  String petGenerateDrawing(Object state) {
    return 'رسم إطارات $state';
  }

  @override
  String get petGenerateComposing => 'جارٍ تركيب لوحة الرسوم…';

  @override
  String get petGenerateSaving => 'جارٍ الحفظ…';

  @override
  String get petGenerateHatching => 'جارٍ الفقس…';

  @override
  String get petGenerateReady => 'فقس حيوانك الأليف الجديد!';

  @override
  String get petGenerateNameLabel => 'أعطه اسمًا';

  @override
  String get petGenerateDiscard => 'تجاهل';

  @override
  String get petGenerateAdopt => 'تبنّي';

  @override
  String get imageSave => 'حفظ الصورة';

  @override
  String get imageCopyLink => 'نسخ رابط الصورة';

  @override
  String get imageSavedToGallery => 'تم الحفظ في المعرض';

  @override
  String get kanbanHomeChannels => 'إشعارات القنوات الرئيسية';

  @override
  String get kanbanHomeChannelsFailed => 'تعذر تحميل القنوات الرئيسية';

  @override
  String get kanbanHomeChannelsEmpty => 'لا توجد قنوات رئيسية متاحة';

  @override
  String kanbanUnsupportedAction(Object action) {
    return 'هذا الإصدار لا يدعم الإجراء $action';
  }

  @override
  String chatSessionSaved(Object path) {
    return 'تم حفظ نص المحادثة في $path';
  }

  @override
  String get artifactSessionPendingTitle => 'ابدأ الجلسة لعرض المخرجات';

  @override
  String get artifactSessionPendingDescription =>
      'ستظهر المخرجات هنا بعد حفظ هذه المحادثة.';

  @override
  String get artifactEmptyTitle => 'لا توجد مخرجات بعد';

  @override
  String get artifactEmptyDescription =>
      'ستظهر هنا الشفرة والملفات والروابط والصور التي تم إنشاؤها في هذه الجلسة.';

  @override
  String artifactFallbackLabel(Object id) {
    return 'مخرج $id';
  }

  @override
  String get artifactDetailTitle => 'تفاصيل المخرج';

  @override
  String artifactSessionMeta(Object kind, Object session) {
    return '$kind · الجلسة $session';
  }

  @override
  String get artifactMetadata => 'البيانات الوصفية';

  @override
  String get artifactSaveAs => 'حفظ باسم';

  @override
  String get artifactCopyContent => 'نسخ المحتوى';

  @override
  String artifactExportFailed(String error) {
    return 'تعذّر التصدير: $error';
  }

  @override
  String get artifactType => 'النوع';

  @override
  String get artifactSession => 'الجلسة';

  @override
  String get artifactSessionTitle => 'عنوان الجلسة';

  @override
  String get artifactMessageRow => 'صف الرسالة';

  @override
  String get logsAllServers => 'كل الخوادم';

  @override
  String get logsLoading => 'جارٍ تحميل السجلات...';

  @override
  String get webhookEnableFirst => 'فعّل منصة Webhook أولاً';

  @override
  String get webhookEnabledRestart =>
      'تم تفعيل Webhooks. أعد تشغيل بوابة Hermes لتطبيق التغيير.';

  @override
  String get webhookEnabled => 'تم تفعيل Webhooks';

  @override
  String webhookEnableFailed(Object error) {
    return 'تعذر تفعيل Webhooks: $error';
  }

  @override
  String get webhookLoading => 'جارٍ تحميل Webhooks...';

  @override
  String get webhookEmptyTitle => 'لا توجد Webhooks';

  @override
  String get webhookEmptyDescription =>
      'اضغط + لإنشاء Webhook لتسليم أحداث Hermes.';

  @override
  String get webhookPlatformDisabled => 'منصة Webhook معطلة · اضغط للتفعيل';

  @override
  String get webhookConfigured => 'Webhooks المهيأة';

  @override
  String get webhookStopped => 'تم تعطيل Webhook';

  @override
  String webhookOperationFailed(Object error) {
    return 'فشلت عملية Webhook: $error';
  }

  @override
  String get webhookDeleteTitle => 'حذف Webhook؟';

  @override
  String webhookDeletePrompt(Object name) {
    return 'سيتم حذف $name.';
  }

  @override
  String get webhookDeleted => 'تم حذف Webhook';

  @override
  String webhookDeleteFailed(Object error) {
    return 'تعذر حذف Webhook: $error';
  }

  @override
  String get webhookEnabledLabel => 'مفعّل';

  @override
  String get webhookDisabledLabel => 'معطّل';

  @override
  String get webhookEvents => 'الأحداث المشتركة';

  @override
  String get webhookDescription => 'الوصف';

  @override
  String get webhookPrompt => 'المُوجّه';

  @override
  String get webhookSkills => 'المهارات';

  @override
  String get webhookDeliverTo => 'وجهة التسليم';

  @override
  String get webhookEnableThis => 'تفعيل Webhook هذا';

  @override
  String get webhookHotReloadDescription =>
      'تُطبق التغييرات مباشرة بواسطة بوابة Hermes.';

  @override
  String get webhookNameRequired => 'أدخل اسماً';

  @override
  String get webhookCreated => 'تم إنشاء Webhook';

  @override
  String get webhookSecretOnce =>
      'يظهر سر التوقيع كاملاً مرة واحدة فقط. احفظه الآن.';

  @override
  String get webhookSecretSaved => 'تم الحفظ';

  @override
  String webhookSaveFailed(Object error) {
    return 'تعذر حفظ Webhook: $error';
  }

  @override
  String get webhookNew => 'Webhook جديد';

  @override
  String get webhookName => 'الاسم';

  @override
  String get webhookDescriptionOptional => 'الوصف (اختياري)';

  @override
  String get webhookEventsComma => 'الأحداث المشتركة (مفصولة بفواصل)';

  @override
  String get webhookPromptOptional => 'موجّه التشغيل (اختياري)';

  @override
  String get webhookSkillsComma => 'Skills (مفصولة بفواصل، اختياري)';

  @override
  String get webhookDeliveryTarget => 'وجهة التسليم';

  @override
  String get webhookLogOnly => 'السجل فقط';

  @override
  String get webhookSaving => 'جارٍ الحفظ...';

  @override
  String commonPartialDataLoadFailed(Object details) {
    return 'تعذر تحميل بعض البيانات: $details';
  }

  @override
  String cronRunsLoadFailed(Object error) {
    return 'تعذر تحميل سجل التشغيل: $error';
  }

  @override
  String profilesOptionsLoadFailed(Object details) {
    return 'تعذر تحميل بعض خيارات محرر الملفات الشخصية: $details';
  }

  @override
  String skillsBulkFailed(Object failed, Object total) {
    return 'فشل تحديث $failed من أصل $total مهارة.';
  }

  @override
  String petCleanupFailed(Object error) {
    return 'تعذر تنظيف مهمة الإنشاء: $error';
  }

  @override
  String get skillsTitle => 'المهارات';

  @override
  String get skillsMarketplace => 'سوق المهارات';

  @override
  String get skillsEnableAll => 'تمكين الكل';

  @override
  String get skillsDisableAll => 'تعطيل الكل';

  @override
  String skillsToggleFailed(Object error) {
    return 'تعذر تحديث المهارة: $error';
  }

  @override
  String get skillsSearchHint => 'البحث في المهارات...';

  @override
  String skillsEnabledCount(Object enabled, Object total) {
    return 'مُمكّن $enabled/$total';
  }

  @override
  String get skillsLoading => 'جارٍ تحميل المهارات...';

  @override
  String get skillsEmptyTitle => 'لا توجد مهارات';

  @override
  String get skillsEmptyDescription => 'لا توجد مهارات متاحة لهذا الوكيل.';

  @override
  String get skillsUncategorized => 'غير مصنف';

  @override
  String get skillsNoMatches => 'لا توجد مهارات مطابقة';

  @override
  String skillsUsageCount(Object count) {
    return 'استُخدمت $count مرة';
  }

  @override
  String get skillsLearned => 'متعلّمة';

  @override
  String get skillsBuiltIn => 'مدمجة';

  @override
  String get skillsProvenanceMarketplace => 'السوق';

  @override
  String get skillsSaved => 'تم الحفظ';

  @override
  String skillsSaveFailed(Object error) {
    return 'تعذر حفظ المهارة: $error';
  }

  @override
  String get skillsArchiveQuestion => 'أرشفة المهارة؟';

  @override
  String skillsArchivePrompt(Object name) {
    return 'ستتم أرشفة المهارة المتعلّمة \"$name\". يمكنك التراجع لاحقًا.';
  }

  @override
  String get skillsArchive => 'أرشفة';

  @override
  String get skillsArchived => 'تمت الأرشفة';

  @override
  String skillsArchiveFailed(Object error) {
    return 'تعذر أرشفة المهارة: $error';
  }

  @override
  String get skillsContent => 'المحتوى';

  @override
  String get skillsNoContent => '(لا يوجد محتوى)';

  @override
  String get skillsCancelEdit => 'إلغاء التحرير';

  @override
  String get skillsSaving => 'جارٍ الحفظ...';

  @override
  String get historyTitle => 'السجل';

  @override
  String historyResumeFailed(Object error) {
    return 'تعذر استئناف الجلسة: $error';
  }

  @override
  String get historyManageSessions => 'إدارة الجلسات';

  @override
  String get historyHideArchived => 'إخفاء المؤرشف';

  @override
  String get historyShowArchived => 'إظهار المؤرشف';

  @override
  String get historySelectTitle => 'اختر جلسة';

  @override
  String get historySelectDescription =>
      'اختر جلسة من اليسار لعرض ملخصها وإجراءات إدارتها.';

  @override
  String get historyLoading => 'جارٍ تحميل سجل الجلسات...';

  @override
  String get historySearchHint =>
      'البحث في العناوين أو المحتوى أو مجلدات العمل';

  @override
  String get historyClearSearch => 'مسح البحث';

  @override
  String get historyEmpty => 'لا توجد جلسات بعد';

  @override
  String get historyNoMatches => 'لا توجد جلسات مطابقة';

  @override
  String get historyLoadMore => 'تحميل المزيد';

  @override
  String historyLoadMoreCount(Object loaded, Object total) {
    return 'تحميل المزيد ($loaded/$total)';
  }

  @override
  String get historyPinned => 'مثبتة';

  @override
  String get historyToday => 'اليوم';

  @override
  String get historyYesterday => 'أمس';

  @override
  String get historyThisWeek => 'هذا الأسبوع';

  @override
  String get historyLastWeek => 'الأسبوع الماضي';

  @override
  String get historyEarlier => 'أقدم';

  @override
  String get historyCollapseChildren => 'طي الجلسات الفرعية';

  @override
  String get historyExpandChildren => 'توسيع الجلسات الفرعية';

  @override
  String get historySessionActions => 'إجراءات الجلسة';

  @override
  String get historyManageSession => 'إدارة الجلسة';

  @override
  String get historyUntitled => 'جلسة بلا عنوان';

  @override
  String historyMessageCount(Object count) {
    return '$count رسالة';
  }

  @override
  String get historyDeleteQuestion => 'حذف الجلسة؟';

  @override
  String historyDeletePrompt(Object title) {
    return 'سيتم حذف \"$title\" نهائيًا ولا يمكن التراجع عن ذلك.';
  }

  @override
  String historyDeleteFailed(Object error) {
    return 'تعذر حذف الجلسة: $error';
  }

  @override
  String historyRenameFailed(Object error) {
    return 'تعذر إعادة تسمية الجلسة: $error';
  }

  @override
  String historyCompressed(Object count) {
    return 'تم ضغط الجلسة (أزيلت $count رسالة)';
  }

  @override
  String historyCompressFailed(Object error) {
    return 'تعذر ضغط الجلسة: $error';
  }

  @override
  String historyArchiveFailed(Object error) {
    return 'تعذرت أرشفة الجلسة: $error';
  }

  @override
  String historyUnarchiveFailed(Object error) {
    return 'تعذر إلغاء أرشفة الجلسة: $error';
  }

  @override
  String get historyManagement => 'إدارة الجلسة';

  @override
  String get historySaveTitle => 'حفظ العنوان';

  @override
  String historyContextUsage(Object maximum, Object percent, Object used) {
    return 'استخدام السياق: $used / $maximum$percent';
  }

  @override
  String historyPercent(Object percent) {
    return ' ($percent%)';
  }

  @override
  String get historyCompress => 'ضغط الجلسة';

  @override
  String get historyArchive => 'أرشفة';

  @override
  String get historyUnarchive => 'إلغاء الأرشفة';

  @override
  String get cronTitle => 'المهام المجدولة';

  @override
  String get cronLoading => 'جارٍ تحميل المهام المجدولة...';

  @override
  String get cronEmptyTitle => 'لا توجد مهام مجدولة بعد';

  @override
  String get cronEmptyDescription => 'أنشئ مهمة آلية تعمل وفق جدول محدد.';

  @override
  String get cronNew => 'مهمة جديدة';

  @override
  String cronNextRun(Object time) {
    return 'التشغيل التالي: $time';
  }

  @override
  String get cronRunHistory => 'سجل التشغيل';

  @override
  String cronRunHistoryTitle(Object name) {
    return 'سجل التشغيل · $name';
  }

  @override
  String get cronNoRuns => 'لا يوجد سجل تشغيل';

  @override
  String get cronTriggerNow => 'تشغيل الآن';

  @override
  String get cronTriggered => 'تم بدء المهمة';

  @override
  String cronTriggerFailed(Object error) {
    return 'تعذر بدء المهمة: $error';
  }

  @override
  String cronUpdateFailed(Object error) {
    return 'تعذر تحديث المهمة: $error';
  }

  @override
  String get cronDeleteQuestion => 'حذف المهمة المجدولة؟';

  @override
  String cronDeletePrompt(Object name) {
    return 'سيتم حذف \"$name\".';
  }

  @override
  String cronDeleteFailed(Object error) {
    return 'تعذر حذف المهمة: $error';
  }

  @override
  String get cronStateCompleted => 'مكتملة';

  @override
  String get cronStateDisabled => 'معطلة';

  @override
  String get cronStateEnabled => 'مفعلة';

  @override
  String get cronStateError => 'خطأ';

  @override
  String get cronStatePaused => 'متوقفة مؤقتًا';

  @override
  String get cronStateRunning => 'قيد التشغيل';

  @override
  String get cronStateScheduled => 'مجدولة';

  @override
  String cronModelsLoadFailed(Object error) {
    return 'تعذر تحميل خيارات النماذج: $error';
  }

  @override
  String cronBlueprintsLoadFailed(Object error) {
    return 'تعذر تحميل قوالب الأتمتة: $error';
  }

  @override
  String cronTargetsLoadFailed(Object error) {
    return 'تعذر تحميل وجهات التسليم: $error';
  }

  @override
  String get cronPresetMinute => 'كل دقيقة';

  @override
  String get cronPresetHour => 'كل ساعة';

  @override
  String get cronPresetDay => 'يوميًا الساعة 09:00';

  @override
  String get cronPresetWeek => 'كل اثنين الساعة 09:00';

  @override
  String get cronPresetMonth => 'اليوم الأول من كل شهر الساعة 09:00';

  @override
  String get cronPresetCustom => 'مخصص';

  @override
  String get cronPresetMinuteHint => 'تشغيل كل دقيقة';

  @override
  String get cronPresetHourHint => 'تشغيل في بداية كل ساعة';

  @override
  String get cronPresetDayHint => 'تشغيل يوميًا الساعة 09:00';

  @override
  String get cronPresetWeekHint => 'تشغيل كل اثنين الساعة 09:00';

  @override
  String get cronPresetMonthHint =>
      'تشغيل في اليوم الأول من كل شهر الساعة 09:00';

  @override
  String get cronPromptAndExpressionRequired =>
      'أدخل تعليمات المهمة وتعبير Cron.';

  @override
  String get cronExpressionRequired => 'أدخل تعبير Cron.';

  @override
  String get cronPromptRequired => 'أدخل تعليمات المهمة.';

  @override
  String cronSaveFailed(Object error) {
    return 'تعذر حفظ المهمة: $error';
  }

  @override
  String get cronCreateTitle => 'مهمة مجدولة جديدة';

  @override
  String get cronEditTitle => 'تعديل المهمة المجدولة';

  @override
  String get cronStartFromTemplate => 'البدء من قالب';

  @override
  String get cronScheduling => 'جارٍ الجدولة...';

  @override
  String get cronScheduleAutomation => 'جدولة الأتمتة';

  @override
  String get cronScriptOnlyDescription =>
      'هذه مهمة نصية فقط. يمكنك تغيير الاسم والجدول ووجهات التسليم، بينما يبقى النص البرمجي وإعدادات النموذج دون تغيير.';

  @override
  String get cronScriptLabel => 'النص البرمجي';

  @override
  String cronLastRun(Object time) {
    return 'آخر تشغيل: $time';
  }

  @override
  String get cronRunScheduledAt => 'وقت الجدولة';

  @override
  String get cronRunStartedAt => 'وقت البدء';

  @override
  String get cronRunFinishedAt => 'وقت الانتهاء';

  @override
  String get cronRunStatus => 'الحالة';

  @override
  String get cronRunOutput => 'المخرجات';

  @override
  String get cronRunDetailTitle => 'نجح التشغيل';

  @override
  String get cronRunDetailFailedTitle => 'فشل التشغيل';

  @override
  String get cronNameOptional => 'الاسم (اختياري)';

  @override
  String get cronDeliverResultsTo => 'تسليم النتائج إلى';

  @override
  String get cronTaskModel => 'نموذج المهمة';

  @override
  String get cronUseGlobalDefault => 'استخدام الإعداد العام الافتراضي';

  @override
  String cronSavedModel(Object model) {
    return '$model (محفوظ حاليًا)';
  }

  @override
  String get cronPromptLabel => 'تعليمات المهمة (prompt)';

  @override
  String get cronFrequency => 'التكرار';

  @override
  String get cronExpression => 'تعبير Cron';

  @override
  String get cronExpressionHint => 'دقيقة ساعة يوم شهر يوم-الأسبوع';

  @override
  String get cronSaving => 'جارٍ الحفظ...';

  @override
  String get cronThisDevice => 'هذا الجهاز';

  @override
  String get cronConfigureHomeChannelFirst => 'اضبط القناة الرئيسية أولًا';

  @override
  String get profilesTitle => 'ملفات الوكلاء';

  @override
  String get profilesLoading => 'جارٍ تحميل الملفات...';

  @override
  String get profilesEmptyTitle => 'لا توجد ملفات';

  @override
  String get profilesEmptyDescription => 'أنشئ أول ملف وكيل.';

  @override
  String get profilesNew => 'ملف جديد';

  @override
  String get profilesImport => 'استيراد ملف';

  @override
  String get profilesExport => 'تصدير الملف';

  @override
  String get profilesDuplicate => 'تكرار الملف';

  @override
  String get profilesEditSoul => 'تعديل SOUL.md';

  @override
  String get profilesSetupCommand => 'أمر التشغيل في الطرفية';

  @override
  String profilesSaveFailed(Object error) {
    return 'تعذر حفظ الملف: $error';
  }

  @override
  String get profilesCreated => 'تم إنشاء الملف';

  @override
  String get profilesSaved => 'تم حفظ الملف';

  @override
  String profilesCopyName(Object name) {
    return 'نسخة من $name';
  }

  @override
  String profilesDuplicateFailed(Object error) {
    return 'تعذر تكرار الملف: $error';
  }

  @override
  String get profilesDuplicated => 'تم تكرار الملف';

  @override
  String profilesDeleteQuestion(Object name) {
    return 'حذف الملف \"$name\"؟';
  }

  @override
  String get profilesDeleteActiveWarning => 'هذا الملف نشط حاليًا.';

  @override
  String get profilesDeleteWarning => 'لا يمكن التراجع عن هذا الإجراء.';

  @override
  String profilesDeleteFailed(Object error) {
    return 'تعذر حذف الملف: $error';
  }

  @override
  String get profilesDeleted => 'تم حذف الملف';

  @override
  String profilesSwitchFailed(Object error) {
    return 'تعذر تبديل الملف: $error';
  }

  @override
  String profilesSwitchedTo(Object name) {
    return 'تم التبديل إلى \"$name\"';
  }

  @override
  String get profilesSoulHint => 'صِف هوية هذا الوكيل وسلوكه وأسلوب تواصله';

  @override
  String get profilesSoulSaved => 'تم حفظ SOUL.md';

  @override
  String profilesSoulFailed(Object error) {
    return 'فشلت عملية SOUL.md: $error';
  }

  @override
  String get profilesCopy => 'نسخ';

  @override
  String profilesSetupCommandFailed(Object error) {
    return 'تعذر قراءة أمر التشغيل: $error';
  }

  @override
  String get profilesExported => 'تم تصدير الملف';

  @override
  String profilesExportFailed(Object error) {
    return 'تعذر تصدير الملف: $error';
  }

  @override
  String profilesImported(Object name) {
    return 'تم استيراد $name';
  }

  @override
  String profilesImportFailed(Object error) {
    return 'تعذر استيراد الملف: $error';
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
  String get profilesCurrentSuffix => ' · نشط';

  @override
  String get profilesActive => 'نشط';

  @override
  String get profilesActivate => 'تفعيل';

  @override
  String get profilesNameRequired => 'أدخل اسم الملف.';

  @override
  String get profilesCreateTitle => 'ملف جديد';

  @override
  String get profilesEditTitle => 'تعديل الملف';

  @override
  String get profilesProvider => 'المزود';

  @override
  String get profilesModel => 'النموذج';

  @override
  String get profilesSystemPrompt => 'موجّه النظام';

  @override
  String get profilesDescriptionOptional => 'الوصف (اختياري)';

  @override
  String get profilesTools => 'الأدوات';

  @override
  String get profilesDeselectAll => 'إلغاء تحديد الكل';

  @override
  String get profilesSelectAll => 'تحديد الكل';

  @override
  String get profilesSetActive => 'تعيين كملف نشط';

  @override
  String get memoryTitle => 'الذاكرة';

  @override
  String get memoryLoading => 'جارٍ تحميل حالة الذاكرة...';

  @override
  String memorySwitchFailed(Object error) {
    return 'تعذر تبديل المزود: $error';
  }

  @override
  String get memoryResetScope => 'اختر ما تريد إعادة ضبطه';

  @override
  String get memoryResetScopeDescription =>
      'سيتم حذف ملفات الذاكرة المحددة فقط.';

  @override
  String get memoryAll => 'كل الذاكرة';

  @override
  String get memoryAllFiles => 'MEMORY.md وUSER.md';

  @override
  String get memoryLongTerm => 'الذاكرة طويلة الأمد';

  @override
  String get memoryLongTermFile => 'MEMORY.md فقط';

  @override
  String get memoryUser => 'ذاكرة المستخدم';

  @override
  String get memoryUserFile => 'USER.md فقط';

  @override
  String get memoryResetQuestion => 'إعادة ضبط الذاكرة؟';

  @override
  String get memoryResetWarning => 'لا يمكن استعادة الذاكرة المحذوفة.';

  @override
  String get memoryNothingDeleted => 'لم توجد ملفات ذاكرة لحذفها.';

  @override
  String memoryDeleted(Object files) {
    return 'تم حذف $files';
  }

  @override
  String memoryResetFailed(Object error) {
    return 'تعذرت إعادة ضبط الذاكرة: $error';
  }

  @override
  String memoryCuratorUpdateFailed(Object error) {
    return 'تعذر تحديث Curator: $error';
  }

  @override
  String get memoryCuratorStarted => 'بدأ Curator العمل';

  @override
  String memoryCuratorRunFailed(Object error) {
    return 'تعذر تشغيل Curator: $error';
  }

  @override
  String get memoryCurrentProvider => 'مزود الذاكرة الحالي';

  @override
  String get memoryDisabled => 'معطل';

  @override
  String get memoryEnabled => 'مفعل';

  @override
  String get memoryProviders => 'المزودون';

  @override
  String get memoryNoProviders => 'لا يوجد مزودون متاحون';

  @override
  String get memoryBuiltInFiles => 'ملفات الذاكرة المضمنة';

  @override
  String get memoryReset => 'إعادة ضبط الذاكرة';

  @override
  String get memoryInUse => 'قيد الاستخدام';

  @override
  String get memoryConfigured => 'تم إعداده';

  @override
  String memoryConfigureProvider(Object name) {
    return 'إعداد $name';
  }

  @override
  String memoryEnableProvider(Object name) {
    return 'تفعيل $name';
  }

  @override
  String get memoryCuratorLoading => 'جارٍ تحميل حالة Curator...';

  @override
  String get memoryCuratorUnavailable => 'Curator غير متاح';

  @override
  String get memoryPaused => 'متوقف مؤقتًا';

  @override
  String memoryCuratorInterval(Object hours) {
    return 'فحص كل $hours ساعة';
  }

  @override
  String memoryCuratorLastRun(Object time) {
    return 'آخر تشغيل $time';
  }

  @override
  String get memoryResume => 'استئناف';

  @override
  String get memoryPause => 'إيقاف مؤقت';

  @override
  String get memoryRunNow => 'تشغيل الآن';

  @override
  String memoryInvalidJson(Object field) {
    return '$field ليس JSON صالحًا';
  }

  @override
  String get memoryProviderSaved => 'تم حفظ إعدادات المزود';

  @override
  String memoryProviderSaveFailed(Object error) {
    return 'تعذر حفظ إعدادات المزود: $error';
  }

  @override
  String get memoryOAuthTimeout => 'انتهت مهلة الاتصال. حاول مرة أخرى.';

  @override
  String get memoryCurrentProfile => 'الملف الحالي';

  @override
  String memoryProfile(Object name) {
    return 'الملف: $name';
  }

  @override
  String get memoryProviderConfigLoading => 'جارٍ تحميل إعدادات المزود...';

  @override
  String get memoryNoProviderConfig => 'لا توجد إعدادات إضافية لهذا المزود';

  @override
  String get memoryViewProviderDocs => 'عرض وثائق المزود';

  @override
  String get memorySaving => 'جارٍ الحفظ...';

  @override
  String get memorySaveConfig => 'حفظ الإعدادات';

  @override
  String get memoryAccountConnected => 'الحساب متصل';

  @override
  String get memoryConnectAccount => 'ربط حساب المزود';

  @override
  String get memoryReconnect => 'إعادة الاتصال';

  @override
  String get memoryConnect => 'اتصال';

  @override
  String get memoryKeepSecretHint => 'اتركه فارغًا للاحتفاظ بالقيمة الحالية';

  @override
  String agentOpenBotFailed(Object error) {
    return 'تعذر فتح محادثة Bot: $error';
  }

  @override
  String get agentNewGroup => 'محادثة جماعية جديدة';

  @override
  String get agentEditGroup => 'تعديل المحادثة الجماعية';

  @override
  String get agentGroupName => 'اسم المحادثة الجماعية';

  @override
  String agentGroupSaveFailed(Object error) {
    return 'تعذر حفظ المحادثة الجماعية: $error';
  }

  @override
  String agentBotThinking(Object name) {
    return '$name يفكر';
  }

  @override
  String agentBotPaused(Object name) {
    return '$name متوقف مؤقتًا';
  }

  @override
  String get agentStartGroupChat => 'بدء المحادثة الجماعية';

  @override
  String agentReplyTo(Object id) {
    return 'الرد على #$id';
  }

  @override
  String get agentSendToRoom => 'إرسال إلى الغرفة';

  @override
  String get agentMentionHint =>
      'استخدم @الاسم لتوجيه الرسالة أو @all لإشعار الجميع';

  @override
  String agentAttachmentTooLarge(Object name) {
    return 'يتجاوز $name حجم 20 ميغابايت';
  }

  @override
  String agentAttachFailed(Object error) {
    return 'تعذرت إضافة المرفق: $error';
  }

  @override
  String agentGroupSendFailed(Object error) {
    return 'تعذر إرسال رسالة المجموعة: $error';
  }

  @override
  String get agentAppendMessage => 'إضافة رسالة';

  @override
  String get agentAwaitingApproval => 'بانتظار الموافقة';

  @override
  String get agentNeedsInformation => 'مطلوب مزيد من المعلومات';

  @override
  String get agentRespond => 'رد';

  @override
  String agentMemberRequest(Object name) {
    return 'طلب من $name';
  }

  @override
  String get agentAllowOperationQuestion => 'السماح بهذه العملية؟';

  @override
  String get agentDeny => 'رفض';

  @override
  String get agentAlwaysAllow => 'السماح دائمًا';

  @override
  String get agentAllow => 'سماح';

  @override
  String get agentCustomAnswer => 'إجابة مخصصة';

  @override
  String get agentEnterAnswer => 'أدخل إجابة';

  @override
  String agentRespondFailed(Object error) {
    return 'تعذر الرد: $error';
  }

  @override
  String get agentLoading => 'جارٍ تحميل حالة الوكيل...';

  @override
  String get agentNoData => 'لا توجد بيانات';

  @override
  String get agentManageBots => 'إدارة أو إنشاء Bots';

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
  String get agentRefreshRoster => 'تحديث قائمة Bots';

  @override
  String agentGroupSummary(Object count, Object runningSuffix) {
    return '$count Bots · عبر الاتصالات$runningSuffix';
  }

  @override
  String get agentRunningSuffix => ' · قيد التشغيل';

  @override
  String agentDeleteGroupQuestion(Object name) {
    return 'حذف المحادثة الجماعية \"$name\"؟';
  }

  @override
  String get agentDeleteGroupWarning =>
      'سيتم حذف سجل المجموعة نهائيًا ولا يمكن التراجع عن ذلك.';

  @override
  String agentDeleteGroupFailed(Object error) {
    return 'تعذر حذف المحادثة الجماعية: $error';
  }

  @override
  String get agentDeleteGroup => 'حذف المحادثة الجماعية';

  @override
  String agentDeleteBotQuestion(Object name) {
    return 'حذف Bot \"$name\"؟';
  }

  @override
  String agentBotOperationFailed(Object error) {
    return 'فشلت عملية Bot: $error';
  }

  @override
  String get agentDuplicateBot => 'تكرار Bot';

  @override
  String get agentDeleteBot => 'حذف Bot';

  @override
  String get agentGateway => 'البوابة';

  @override
  String get agentActiveAgents => 'الوكلاء النشطون';

  @override
  String get agentBusy => 'مشغول';

  @override
  String get agentYes => 'نعم';

  @override
  String get agentNo => 'لا';

  @override
  String get agentModelSection => 'النموذج';

  @override
  String get agentCurrentModel => 'النموذج الحالي';

  @override
  String get agentProvider => 'المزود';

  @override
  String get agentContextLength => 'طول السياق';

  @override
  String get agentSessionModel => 'نموذج الجلسة';

  @override
  String get agentRuntimeSection => 'بيئة التشغيل';

  @override
  String get agentType => 'النوع';

  @override
  String get agentSourceRoot => 'جذر المصدر';

  @override
  String get agentHermesHome => 'مجلد Hermes الرئيسي';

  @override
  String get agentServerVersion => 'إصدار الخادم';

  @override
  String get agentCapability => 'الإمكانات';

  @override
  String get agentRestarting => 'جارٍ إعادة التشغيل...';

  @override
  String botRoutineUpdateFailed(Object error) {
    return 'تعذر تحديث Cronjob: $error';
  }

  @override
  String get botRoutineDeleteQuestion => 'حذف Cronjob؟';

  @override
  String botRoutineDeletePrompt(Object title) {
    return 'سيتم حذف \"$title\" وجدوله نهائيًا.';
  }

  @override
  String get botRoutineStatus => 'الحالة';

  @override
  String get botRoutinePaused => 'متوقف مؤقتًا';

  @override
  String get botRoutineSchedule => 'الجدول';

  @override
  String get botRoutineRawSchedule => 'الجدول الخام';

  @override
  String get botRoutineRepeatCount => 'عدد التكرارات';

  @override
  String get botRoutineNextRun => 'التشغيل التالي';

  @override
  String get botRoutineLastRun => 'آخر تشغيل';

  @override
  String get botRoutineLastResult => 'النتيجة الأخيرة';

  @override
  String get botRoutineDeliverTo => 'التسليم إلى';

  @override
  String get botRoutineModel => 'النموذج';

  @override
  String get botRoutineWorkdir => 'مجلد العمل';

  @override
  String get botRoutineInstruction => 'التعليمات';

  @override
  String get botRoutineLegacyWarning =>
      'تم إيقاف هذه المهمة القديمة مؤقتًا للأمان. احذفها وأعد إنشاءها قبل تشغيلها.';

  @override
  String botRoutineTitle(Object name) {
    return '$name · المهام المجدولة';
  }

  @override
  String commonBytes(Object count) {
    return '$count بايت';
  }

  @override
  String get botRoutineLoading => 'جارٍ تحميل Bot Cronjobs...';

  @override
  String get botRoutineEmptyTitle => 'لا توجد Cronjobs بعد';

  @override
  String botRoutineEmptyDescription(Object name) {
    return 'أنشئ مهمة مجدولة مخصصة لـ $name.';
  }

  @override
  String get botRoutineNew => 'Cronjob جديدة';

  @override
  String botRoutineNext(Object time) {
    return 'التالي $time';
  }

  @override
  String get botRoutineLegacyPaused => 'مهمة قديمة، متوقفة بأمان';

  @override
  String get botRoutineDelete => 'حذف Cronjob';

  @override
  String botRoutineScheduleOnce(Object duration) {
    return 'مرة واحدة · بعد $duration';
  }

  @override
  String botRoutineScheduleEvery(Object duration) {
    return 'كل $duration';
  }

  @override
  String get botRoutineScheduleHourly => 'في بداية كل ساعة';

  @override
  String get botRoutineScheduleDaily => 'يوميًا الساعة 09:00';

  @override
  String get botRoutineScheduleWeekdays => 'أيام العمل الساعة 09:00';

  @override
  String get botRoutineScheduleWeekly => 'كل اثنين الساعة 09:00';

  @override
  String get botRoutineScheduleMonthly => 'اليوم الأول من كل شهر الساعة 09:00';

  @override
  String get botRoutineRequiredFields => 'أدخل الاسم والتعليمات والجدول.';

  @override
  String botRoutineCreateTitle(Object name) {
    return 'Cronjob جديدة · $name';
  }

  @override
  String get botRoutineInstructionLabel => 'التعليمات المنفذة في كل مرة';

  @override
  String get botRoutineFrequencyOnce => 'مرة واحدة بعد مدة';

  @override
  String get botRoutineFrequencyHourly => 'كل ساعة';

  @override
  String get botRoutineFrequencyDaily => 'يوميًا';

  @override
  String get botRoutineFrequencyWeekdays => 'أيام العمل';

  @override
  String get botRoutineFrequencyWeekly => 'أسبوعيًا';

  @override
  String get botRoutineFrequencyMonthly => 'شهريًا';

  @override
  String get botRoutineFrequencyInterval => 'فاصل ثابت';

  @override
  String get botRoutineFrequencyAdvanced => 'تعبير متقدم';

  @override
  String get botRoutineTime => 'الوقت (HH:mm)';

  @override
  String get botRoutineWeekday => 'يوم الأسبوع';

  @override
  String get botRoutineMonday => 'الاثنين';

  @override
  String get botRoutineTuesday => 'الثلاثاء';

  @override
  String get botRoutineWednesday => 'الأربعاء';

  @override
  String get botRoutineThursday => 'الخميس';

  @override
  String get botRoutineFriday => 'الجمعة';

  @override
  String get botRoutineSaturday => 'السبت';

  @override
  String get botRoutineSunday => 'الأحد';

  @override
  String get botRoutineDayOfMonth => 'يوم الشهر';

  @override
  String get botRoutineValue => 'القيمة';

  @override
  String get botRoutineUnit => 'الوحدة';

  @override
  String get botRoutineMinutes => 'دقائق';

  @override
  String get botRoutineHours => 'ساعات';

  @override
  String get botRoutineDays => 'أيام';

  @override
  String get botRoutineAdvancedExpression => 'Cron أو every Nm/Nh/Nd';

  @override
  String botRoutineWillSaveAs(Object schedule) {
    return 'سيُحفظ كالتالي: $schedule';
  }

  @override
  String get botRoutineRepeatLimit =>
      'الحد الأقصى للتشغيل (اتركه فارغًا للاستمرار)';

  @override
  String get botRoutineContinuity => 'الاستمرارية';

  @override
  String get botRoutineContinuityDescription =>
      'يمكن لكل تشغيل قراءة ناتج التشغيل السابق لهذه المهمة.';

  @override
  String botRoutineSendToBot(Object name) {
    return 'إرسال إلى Bot Chat الخاصة بـ $name';
  }

  @override
  String get botRoutineSendToBotDescription => 'سيقرأ Bot النتيجة ويواصل الرد.';

  @override
  String get botRoutineCreating => 'جارٍ الإنشاء...';

  @override
  String get botRoutineCreate => 'إنشاء Cronjob';

  @override
  String get mcpTitle => 'خوادم MCP';

  @override
  String mcpOperationFailed(Object error) {
    return 'فشلت العملية: $error';
  }

  @override
  String get mcpPersistenceFailed =>
      'لم يحفظ الخادم تغيير إعداد MCP بشكل دائم.';

  @override
  String mcpTestSuccess(Object prompts, Object resources, Object tools) {
    return 'تم الاتصال: $tools أدوات، $prompts موجّهات، $resources موارد';
  }

  @override
  String mcpTestConnectionFailed(Object error) {
    return 'فشل الاتصال: $error';
  }

  @override
  String mcpTestFailed(Object error) {
    return 'فشل الاختبار: $error';
  }

  @override
  String mcpReloadFailed(Object error) {
    return 'تم حفظ الإعدادات، لكن فشلت إعادة تحميل MCP للجلسة النشطة: $error';
  }

  @override
  String get mcpImportUnrecognized =>
      'تعذر التعرّف على المحتوى الملصق. تحقق من التنسيق.';

  @override
  String mcpImportDetected(Object count) {
    return 'تم اكتشاف $count خوادم';
  }

  @override
  String mcpImportAllQuestion(Object names) {
    return 'هل تريد إضافة جميع هذه الخوادم؟\n\n$names';
  }

  @override
  String get mcpAddAll => 'إضافة الكل';

  @override
  String mcpServersAdded(Object count) {
    return 'تمت إضافة $count خوادم';
  }

  @override
  String mcpServersPartiallyAdded(Object added, Object failed) {
    return 'تمت إضافة $added وفشل $failed';
  }

  @override
  String get mcpAddServer => 'إضافة خادم MCP';

  @override
  String get mcpPasteImport =>
      'الصق للاستيراد (mcp.json / أمر / claude mcp add / URL)';

  @override
  String get mcpParse => 'تحليل';

  @override
  String get mcpRemoteUrl => 'عنوان URL بعيد';

  @override
  String get mcpLocalStdio => 'stdio محلي';

  @override
  String get mcpServerUrl => 'عنوان الخادم';

  @override
  String get mcpCommand => 'الأمر';

  @override
  String get mcpArgumentsOnePerLine => 'المعاملات (واحد في كل سطر)';

  @override
  String get mcpEnvironmentJson => 'متغيرات البيئة (JSON)';

  @override
  String get mcpAuthentication => 'المصادقة';

  @override
  String get mcpNoAuthentication => 'بلا مصادقة';

  @override
  String get mcpEnvironmentMustBeJson =>
      'يجب أن تكون متغيرات البيئة كائن JSON.';

  @override
  String get mcpServerAdded => 'تمت إضافة خادم MCP';

  @override
  String mcpAddFailed(Object error) {
    return 'تعذرت إضافة الخادم: $error';
  }

  @override
  String mcpDeleteQuestion(Object name) {
    return 'حذف $name؟';
  }

  @override
  String get mcpDeleteWarning =>
      'سيتم حذف هذا الخادم نهائيًا من إعدادات Hermes MCP.';

  @override
  String mcpDeleteFailed(Object error) {
    return 'تعذر حذف الخادم: $error';
  }

  @override
  String mcpReadConfigFailed(Object error) {
    return 'تعذرت قراءة الإعدادات: $error';
  }

  @override
  String mcpEditServer(Object name) {
    return 'تعديل $name';
  }

  @override
  String mcpInvalidJson(Object error) {
    return 'ليس كائن JSON صالحًا: $error';
  }

  @override
  String mcpServerSaved(Object name) {
    return 'تم حفظ $name';
  }

  @override
  String mcpSaveFailed(Object error) {
    return 'تعذر حفظ الخادم: $error';
  }

  @override
  String mcpToolToggleFailed(Object error) {
    return 'تعذر تبديل الأداة: $error';
  }

  @override
  String get mcpOAuthStartFailed => 'تعذر بدء OAuth';

  @override
  String get mcpOAuthMissingUrl => 'لم يُرجع خادم OAuth عنوان التفويض.';

  @override
  String get mcpBrowserOpenFailed => 'تعذر فتح متصفح النظام.';

  @override
  String mcpCompleteAuthorization(Object name) {
    return 'أكمل تفويض $name في المتصفح.';
  }

  @override
  String get mcpOAuthAuthorizationFailed => 'فشل تفويض OAuth';

  @override
  String mcpAuthorizationSucceeded(Object name, Object tools) {
    return 'تم تفويض $name والعثور على $tools أدوات';
  }

  @override
  String mcpOAuthFailed(Object error) {
    return 'فشل OAuth: $error';
  }

  @override
  String mcpInstallTitle(Object name) {
    return 'تثبيت $name';
  }

  @override
  String get mcpRequired => 'مطلوب';

  @override
  String get mcpOptional => 'اختياري';

  @override
  String get mcpRequiredCredentials => 'أدخل كل بيانات الاعتماد المطلوبة.';

  @override
  String get mcpReinstall => 'إعادة التثبيت';

  @override
  String get mcpInstall => 'تثبيت';

  @override
  String mcpInstallExitCode(Object code) {
    return 'خرج برنامج التثبيت بالرمز $code';
  }

  @override
  String mcpInstallComplete(Object name) {
    return 'اكتمل تثبيت $name';
  }

  @override
  String mcpInstallFailed(Object error) {
    return 'فشل التثبيت: $error';
  }

  @override
  String get mcpViewLogs => 'عرض السجلات';

  @override
  String get mcpLoading => 'جارٍ تحميل خوادم MCP...';

  @override
  String get mcpConfiguredServers => 'الخوادم المعدة';

  @override
  String get mcpNoConfiguredServers => 'لا توجد خوادم MCP معدة';

  @override
  String get mcpDescription =>
      'يربط MCP الوكلاء بالأدوات ومصادر البيانات الخارجية.';

  @override
  String mcpAvailableCatalog(Object count) {
    return 'الدليل المتاح ($count)';
  }

  @override
  String mcpToolCount(Object count) {
    return '$count أدوات';
  }

  @override
  String mcpUsage30Days(Object count) {
    return '$count استخدامات / 30 يومًا';
  }

  @override
  String get mcpTestConnection => 'اختبار الاتصال';

  @override
  String get mcpEditConfiguration => 'تعديل الإعدادات';

  @override
  String get mcpOAuthAuthorization => 'تفويض OAuth';

  @override
  String get mcpInstalledEnabled => 'مثبت ومفعّل';

  @override
  String get mcpInstalledDisabled => 'مثبت وغير مفعّل';

  @override
  String get commandCenterTitle => 'مركز الأوامر';

  @override
  String get commandStatusTab => 'الحالة';

  @override
  String get commandUsageTab => 'الاستخدام';

  @override
  String get commandMaintenanceTab => 'الصيانة';

  @override
  String commandStatusLoadFailed(Object error) {
    return 'تعذر تحميل الحالة: $error';
  }

  @override
  String commandLogsLoadFailed(Object error) {
    return 'تعذر تحميل السجلات: $error';
  }

  @override
  String get commandRestartWarning =>
      'سيؤدي ذلك إلى إعادة تشغيل Hermes backend وقد يقطع الجولات النشطة.';

  @override
  String commandRestartResult(Object result) {
    return 'نتيجة إعادة التشغيل: $result';
  }

  @override
  String get commandNoLogs => '(لا توجد سجلات)';

  @override
  String get commandBackendProcess => 'عملية الخلفية';

  @override
  String get commandStopped => 'متوقف';

  @override
  String get commandLiveLogs => 'السجلات المباشرة';

  @override
  String get commandDiagnostics => 'تفاصيل التشخيص';

  @override
  String get commandSystemStatus => 'حالة النظام';

  @override
  String get commandNoStatusData => 'لا توجد بيانات حالة';

  @override
  String commandUsageLoadFailed(Object error) {
    return 'تعذر تحميل الاستخدام: $error';
  }

  @override
  String commandDays(Object count) {
    return '$count أيام';
  }

  @override
  String get commandSessions => 'الجلسات';

  @override
  String get commandApiCalls => 'استدعاءات API';

  @override
  String get commandTokensInOut => 'الرموز (دخل/خرج)';

  @override
  String get commandDailyUsage => 'الاستخدام اليومي';

  @override
  String get commandNoUsageData => 'لا توجد بيانات استخدام';

  @override
  String get commandTopModels => 'أكثر النماذج استخدامًا';

  @override
  String get commandTopSkills => 'أكثر المهارات استخدامًا';

  @override
  String commandUseCount(Object count) {
    return '$count استخدامات';
  }

  @override
  String commandChartTooltip(Object day, Object input, Object output) {
    return '$day\nالإدخال $input / الإخراج $output';
  }

  @override
  String get commandInputTokens => 'رموز الإدخال';

  @override
  String get commandOutputTokens => 'رموز الإخراج';

  @override
  String commandStarting(Object label) {
    return 'جارٍ بدء $label...';
  }

  @override
  String get commandMissingActionName => 'لم تُرجع الخلفية اسم العملية.';

  @override
  String get commandNoOutput => '(لا يوجد إخراج بعد)';

  @override
  String commandActionExitFailed(Object code, Object label) {
    return 'فشل $label (رمز الخروج $code)';
  }

  @override
  String commandActionComplete(Object label) {
    return 'اكتمل $label';
  }

  @override
  String commandLogError(Object error, Object logs) {
    return '$logs\n\nخطأ: $error';
  }

  @override
  String commandActionFailed(Object error, Object label) {
    return 'فشل $label: $error';
  }

  @override
  String commandDebugShareFailed(Object error) {
    return 'تعذر إنشاء مشاركة التصحيح: $error';
  }

  @override
  String get commandDebugShare => 'إنشاء مشاركة تصحيح';

  @override
  String get commandLogsRedacted => 'تم حجب القيم الحساسة من السجلات.';

  @override
  String get commandLogsNotRedacted => 'لم تُحجب السجلات. شاركها بحذر.';

  @override
  String commandAutoDeleteHours(Object hours) {
    return 'ستُحذف الروابط تلقائيًا بعد نحو $hours ساعة.';
  }

  @override
  String get commandPartialUploadFailed => 'فشل رفع بعض المحتوى:';

  @override
  String get commandDiagnosticsMaintenance => 'التشخيص والصيانة';

  @override
  String get commandRunDoctor => 'تشغيل التشخيص';

  @override
  String get commandRunDoctorDescription =>
      'hermes doctor - فحص البيئة والإعدادات';

  @override
  String get commandDoctor => 'التشخيص';

  @override
  String get commandSecurityAudit => 'تدقيق الأمان';

  @override
  String get commandSecurityAuditDescription =>
      'hermes security audit - البحث عن مشكلات أمنية محتملة';

  @override
  String get commandBackupNow => 'نسخ احتياطي الآن';

  @override
  String get commandBackupDescription =>
      'hermes backup - حفظ الإعدادات والبيانات محليًا';

  @override
  String get commandBackup => 'النسخ الاحتياطي';

  @override
  String get commandDebugShareDescription =>
      'رفع سجلات محجوبة وإنشاء روابط تصحيح قابلة للمشاركة';

  @override
  String terminalStartFailed(Object error) {
    return 'تعذر بدء الطرفية: $error';
  }

  @override
  String get terminalSshHost => 'المضيف أو اسم SSH config *';

  @override
  String get terminalSshUserOptional => 'المستخدم (اختياري)';

  @override
  String get terminalSshPort => 'المنفذ (الافتراضي 22)';

  @override
  String get terminalSshIdentityFile => 'IdentityFile على الخادم (اختياري)';

  @override
  String get terminalSshRemoteCwd => 'مجلد العمل البعيد (اختياري)';

  @override
  String get terminalSshAuthenticationNote =>
      'تستخدم المصادقة ssh-agent أو SSH config على خادم Hermes. لا يحفظ تطبيق الهاتف كلمات المرور.';

  @override
  String terminalSshFailed(Object error) {
    return 'فشل اتصال SSH: $error';
  }

  @override
  String get terminalCloseRunningQuestion => 'إغلاق الطرفية النشطة؟';

  @override
  String terminalCloseRunningWarning(Object name) {
    return 'سيتم إنهاء العمليات في \"$name\" ولا يمكن التراجع عن ذلك.';
  }

  @override
  String get terminalClose => 'إغلاق الطرفية';

  @override
  String get terminalSessions => 'جلسات الطرفية';

  @override
  String terminalSessionLimit(Object count) {
    return 'يمكن فتح $count طرفيات في الوقت نفسه كحد أقصى';
  }

  @override
  String terminalCloseNamed(Object name) {
    return 'إغلاق $name';
  }

  @override
  String get terminalSelectTextFirst => 'حدد نصًا أولًا.';

  @override
  String terminalPasteLinesQuestion(Object count) {
    return 'لصق $count أسطر؟';
  }

  @override
  String get terminalMergeSingleLine => 'دمج في سطر واحد';

  @override
  String get terminalConfirmPaste => 'لصق';

  @override
  String get terminalSelectTerminalTextFirst => 'حدد نصًا في الطرفية أولًا.';

  @override
  String get terminalSentToChat => 'تم الإرسال إلى محرر المحادثة';

  @override
  String terminalOpenLinkFailed(Object link) {
    return 'تعذر فتح الرابط: $link';
  }

  @override
  String get terminalDismissNotice => 'إغلاق التنبيه';

  @override
  String get terminalNew => 'طرفية جديدة';

  @override
  String get terminalNewSsh => 'طرفية SSH جديدة';

  @override
  String get terminalOpenDirectory => 'فتح في مجلد';

  @override
  String get terminalDisplaySettings => 'إعدادات عرض الطرفية';

  @override
  String get terminalNoWorkingDirectory => '(لا يوجد مجلد عمل)';

  @override
  String get terminalNoActive => 'لا توجد طرفية نشطة';

  @override
  String get terminalCommandMode => 'وضع الأوامر';

  @override
  String get terminalInteractiveMode => 'الوضع التفاعلي';

  @override
  String get terminalControlInterrupt => 'Ctrl+C مقاطعة';

  @override
  String get terminalControlSuspend => 'Ctrl+Z تعليق';

  @override
  String get terminalControlClear => 'Ctrl+L مسح الشاشة';

  @override
  String get terminalControlBackWord => 'Alt+B الكلمة السابقة';

  @override
  String get terminalControlForwardWord => 'Alt+F الكلمة التالية';

  @override
  String get terminalControlKeys => 'مفاتيح التحكم';

  @override
  String get terminalVisibleOutputCopied => 'تم نسخ إخراج الشاشة الحالي';

  @override
  String get terminalDisplay => 'عرض الطرفية';

  @override
  String get terminalDisplayDescription =>
      'تؤثر هذه الإعدادات في العرض المحلي فقط، لا في PTY أو سلوك الأوامر.';

  @override
  String get terminalPreviewOutput => '✓ 42 tests passed  معاينة إخراج مترجمة';

  @override
  String terminalFontSize(Object value) {
    return 'حجم الخط  $value';
  }

  @override
  String terminalLineHeight(Object value) {
    return 'ارتفاع السطر  $value';
  }

  @override
  String get terminalColorTheme => 'سمة الألوان';

  @override
  String get terminalThemeSystem => 'اتباع النظام';

  @override
  String get terminalThemeProfessionalDark => 'داكن احترافي';

  @override
  String get terminalThemeHighContrastDark => 'داكن عالي التباين';

  @override
  String get terminalThemeSoftLight => 'فاتح ناعم';

  @override
  String get terminalCursorStyle => 'نمط المؤشر';

  @override
  String get terminalCursorBar => 'شريط';

  @override
  String get terminalCursorBlock => 'كتلة';

  @override
  String get terminalCursorUnderline => 'تسطير';

  @override
  String get terminalContentPadding => 'حشو الطرفية';

  @override
  String get terminalContentPaddingHint => 'عطّله لإظهار أعمدة أكثر';

  @override
  String get terminalResetDisplay => 'استعادة الإعدادات الموصى بها';

  @override
  String get terminalCommandHint => 'أدخل أمرًا...';

  @override
  String get terminalRunCommand => 'تشغيل الأمر';

  @override
  String get terminalPaste => 'لصق';

  @override
  String get terminalClear => 'مسح';

  @override
  String get terminalSendToChat => 'إرسال إلى المحادثة';

  @override
  String get terminalInteractiveHint =>
      'الوضع التفاعلي · يُرسل الإدخال مباشرة إلى PTY';

  @override
  String get terminalMoreActions => 'مزيد من إجراءات الطرفية';

  @override
  String get terminalCopySelection => 'نسخ التحديد';

  @override
  String get terminalSendSelectionToChat => 'إرسال التحديد إلى المحادثة';

  @override
  String get terminalOpenOtherDirectory => 'فتح طرفية في مجلد آخر';

  @override
  String get terminalManageSessions => 'إدارة جلسات الطرفية';

  @override
  String get terminalPrivacyHistory => 'الخصوصية والسجل';

  @override
  String get terminalPrivacyDescription =>
      'لا يُحفظ سجل الأوامر وإخراج الطرفية افتراضيًا.';

  @override
  String get terminalSaveCommandHistory => 'حفظ سجل الأوامر';

  @override
  String get terminalSaveOutputSnapshots => 'حفظ لقطات إخراج الطرفية';

  @override
  String get terminalClearSavedData => 'مسح السجل واللقطات المحفوظة';

  @override
  String get terminalClearDataQuestion => 'مسح السجل واللقطات؟';

  @override
  String get terminalClearDataWarning =>
      'سيتم حذف سجل الأوامر ولقطات إخراج الطرفية المحفوظة نهائيًا ولا يمكن التراجع عن ذلك.';

  @override
  String filesRevealFailed(String error) {
    return 'تعذر إظهار العنصر في مدير الملفات: $error';
  }

  @override
  String get filesLargeDownloadQuestion => 'تنزيل ملف كبير؟';

  @override
  String filesLargeDownloadDescription(String name, String size) {
    return 'يبلغ حجم \"$name\" نحو $size ميغابايت. قد يستغرق التنزيل وقتًا ويستخدم مساحة الجهاز.';
  }

  @override
  String get filesContinueDownload => 'متابعة التنزيل';

  @override
  String get filesLargeEditQuestion => 'فتح ملف كبير؟';

  @override
  String filesLargeEditDescription(String name, String size) {
    return '\"$name\" حجمه حوالي $size ميجابايت. قد يكون تحميله في المحرر بطيئًا.';
  }

  @override
  String get filesContinueEdit => 'فتح على أي حال';

  @override
  String get filesFolderDownloadQuestion => 'تنزيل المجلد؟';

  @override
  String filesFolderDownloadDescription(String name) {
    return 'سيُنزل \"$name\" كأرشيف ZIP. قد تستغرق المجلدات الكبيرة وقتًا ومساحة تخزين.';
  }

  @override
  String get filesArchiveDownload => 'ضغط وتنزيل';

  @override
  String filesDownloadedPath(String path) {
    return 'تم التنزيل إلى $path (تم نسخ المسار)';
  }

  @override
  String filesDownloadFailed(String error) {
    return 'فشل التنزيل: $error';
  }

  @override
  String get filesSelectDownloadItem => 'حدد ملفًا أو مجلدًا واحدًا على الأقل';

  @override
  String filesDownloadSummary(int success, int failed, int skipped) {
    return 'تم تنزيل $success، وفشل $failed، وتم تخطي $skipped';
  }

  @override
  String get filesRevealOnServer => 'إظهار على الخادم';

  @override
  String get filesRevealOnServerDescription =>
      'فتح على الجهاز الذي يشغّل Hermes';

  @override
  String get filesDetails => 'التفاصيل';

  @override
  String get filesDownloading => 'جارٍ التنزيل…';

  @override
  String get filesDownloadFolderZip => 'تنزيل المجلد (ZIP)';

  @override
  String get filesDownloadToDevice => 'تنزيل إلى الجهاز';

  @override
  String get filesCopyToClipboard => 'نسخ إلى الحافظة';

  @override
  String get filesCopiedPasteHint => 'تم النسخ؛ افتح مجلد الوجهة واضغط لصق';

  @override
  String get filesCutToClipboard => 'قص إلى الحافظة';

  @override
  String get filesCutPasteHint => 'تم القص؛ افتح مجلد الوجهة واضغط لصق';

  @override
  String get filesRename => 'إعادة تسمية';

  @override
  String get filesCopyPath => 'نسخ المسار';

  @override
  String get filesPathCopied => 'تم نسخ المسار';

  @override
  String get filesCopyRelativePath => 'نسخ المسار النسبي';

  @override
  String get filesRelativePathCopied => 'تم نسخ المسار النسبي';

  @override
  String get filesLink => 'رابط';

  @override
  String filesInfoPath(String value) {
    return 'المسار: $value';
  }

  @override
  String filesInfoType(String value) {
    return 'النوع: $value';
  }

  @override
  String filesInfoSize(int value) {
    return 'الحجم: $value بايت';
  }

  @override
  String filesInfoModified(String value) {
    return 'التعديل: $value';
  }

  @override
  String filesInfoReadable(String value) {
    return 'قابل للقراءة: $value';
  }

  @override
  String filesInfoWritable(String value) {
    return 'قابل للكتابة: $value';
  }

  @override
  String filesMovedCount(int count) {
    return 'تم نقل $count عناصر';
  }

  @override
  String filesCopiedCount(int count) {
    return 'تم نسخ $count عناصر';
  }

  @override
  String filesPasteFailed(String error) {
    return 'فشل اللصق: $error';
  }

  @override
  String get filesConfirmDelete => 'تأكيد الحذف';

  @override
  String filesDeleteSelectedDescription(int count) {
    return 'حذف $count من العناصر المحددة؟ لا يمكن التراجع.';
  }

  @override
  String filesDeleteFailed(String error) {
    return 'فشل الحذف: $error';
  }

  @override
  String get filesNewFile => 'ملف جديد';

  @override
  String get filesFileName => 'اسم الملف';

  @override
  String filesCreateFileFailed(String error) {
    return 'تعذر إنشاء الملف: $error';
  }

  @override
  String filesNewSessionPrompt(String references) {
    return 'راجع وعالج هذه الملفات:\n$references';
  }

  @override
  String get filesNewFolder => 'مجلد جديد';

  @override
  String get filesNewName => 'الاسم الجديد';

  @override
  String filesRenameFailed(String error) {
    return 'فشلت إعادة التسمية: $error';
  }

  @override
  String filesDeleteFolderDescription(String name) {
    return 'حذف المجلد \"$name\" وكل محتوياته؟';
  }

  @override
  String filesDeleteFileDescription(String name) {
    return 'حذف الملف \"$name\"؟';
  }

  @override
  String get filesFolderName => 'اسم المجلد';

  @override
  String filesCreateFolderFailed(String error) {
    return 'تعذر إنشاء المجلد: $error';
  }

  @override
  String get filesSelectWorkspaceDirectory => 'حدد دليل مساحة العمل';

  @override
  String filesSelectedCount(int count) {
    return 'تم تحديد $count';
  }

  @override
  String get filesSwitchToDirectoryBrowser => 'التبديل إلى متصفح الدليل';

  @override
  String get filesSwitchToProjectTree => 'التبديل إلى شجرة المشروع';

  @override
  String get filesOpenInGit => 'فتح في Git';

  @override
  String get filesNewSessionForDirectory => 'جلسة جديدة للدليل الحالي';

  @override
  String get filesSendSelectionToNewSession =>
      'إرسال الملفات المحددة إلى جلسة جديدة';

  @override
  String get filesDownloadSelected => 'تنزيل المحدد';

  @override
  String get filesCopySelected => 'نسخ المحدد';

  @override
  String get filesCutSelected => 'قص المحدد';

  @override
  String get filesDeleteSelected => 'حذف المحدد';

  @override
  String get filesClearSelection => 'إلغاء التحديد';

  @override
  String get filesMoveHere => 'نقل هنا';

  @override
  String get filesCopyHere => 'نسخ هنا';

  @override
  String get filesSelectCurrentDirectory => 'حدد الدليل الحالي';

  @override
  String filesUseAsWorkspace(String name) {
    return 'استخدم \"$name\" كمساحة عمل';
  }

  @override
  String get filesSelectPreview => 'حدد ملفًا للمعاينة';

  @override
  String get filesSelectPreviewDescription =>
      'حدد ملفًا على اليسار لتحريره أو معاينته هنا';

  @override
  String get filesFilterProjectTree => 'تصفية شجرة المشروع المحمّلة…';

  @override
  String get filesSearchDirectory => 'البحث في الدليل الحالي…';

  @override
  String get filesLoadingDirectory => 'جارٍ تحميل الدليل…';

  @override
  String get filesNoMatches => 'لا توجد ملفات مطابقة';

  @override
  String get filesActions => 'إجراءات الملف';

  @override
  String get filesUnableToRead => 'تعذرت القراءة';

  @override
  String get filesDownload => 'تنزيل';

  @override
  String get filesCut => 'قص';

  @override
  String get configTabModel => 'النماذج';

  @override
  String get configTabChat => 'المحادثة';

  @override
  String get configTabMemory => 'الذاكرة';

  @override
  String get configTabVoice => 'الصوت';

  @override
  String get configTabToolsKeys => 'الأدوات والمفاتيح';

  @override
  String configLoadFailed(String error) {
    return 'تعذر تحميل الإعدادات: $error';
  }

  @override
  String get configAuxVision => 'فهم الصور';

  @override
  String get configAuxWebExtract => 'استخراج الويب';

  @override
  String get configAuxCompression => 'ضغط السياق';

  @override
  String get configAuxSkillsHub => 'مركز المهارات';

  @override
  String get configAuxApproval => 'قرارات الموافقة';

  @override
  String get configAuxMcp => 'مساعدة MCP';

  @override
  String get configAuxTitleGeneration => 'إنشاء العناوين';

  @override
  String get configAuxReview => 'مراجعة الشيفرة';

  @override
  String get configAuxTriage => 'فرز المهام';

  @override
  String get configAuxKanban => 'تفكيك Kanban';

  @override
  String get configAuxProfile => 'وصف الملف الشخصي';

  @override
  String get configAuxCurator => 'تنظيم المحتوى';

  @override
  String get configPersonalityDisplay => 'الشخصية (display.personality)';

  @override
  String get configPersonality => 'الشخصية';

  @override
  String get configTimezone => 'المنطقة الزمنية (IANA)';

  @override
  String get configShowReasoning => 'إظهار كتل الاستدلال';

  @override
  String get configMessageReactions => 'تمكين تفاعلات الرسائل';

  @override
  String get configApprovalMode => 'وضع الموافقة';

  @override
  String get configYoloApproval => 'موافقة YOLO التلقائية';

  @override
  String get configChatFieldsUnavailable => 'لم يعد الخادم حقول المحادثة';

  @override
  String get configChatFieldsUnavailableDescription =>
      'لم يعد GET /api/v1/config حقول personality أو timezone أو approvals أو yolo.';

  @override
  String get configPersistentMemory => 'الذاكرة الدائمة';

  @override
  String get configUserProfile => 'ملف المستخدم';

  @override
  String get configMemoryBudget => 'حد الذاكرة (أحرف)';

  @override
  String get configProfileBudget => 'حد الملف (أحرف)';

  @override
  String get configMemoryProvider => 'موفر الذاكرة';

  @override
  String get configContextEngine => 'محرك السياق';

  @override
  String get configAutoCompression => 'الضغط التلقائي';

  @override
  String get configCompressionThreshold => 'حد الضغط';

  @override
  String get configCompressionRatio => 'نسبة الضغط المستهدفة';

  @override
  String get configProtectRecent => 'حماية آخر N رسالة';

  @override
  String get configMemoryFieldsUnavailable => 'لم يعد الخادم حقول الذاكرة';

  @override
  String get configMemoryFieldsUnavailableDescription =>
      'لم يعد GET /api/v1/config حقول memory أو compression أو context.';

  @override
  String get configVoice => 'الصوت';

  @override
  String get configVoiceModel => 'النموذج';

  @override
  String get configVoiceId => 'معرف الصوت';

  @override
  String get configModelId => 'معرف النموذج';

  @override
  String get configLanguage => 'اللغة';

  @override
  String get configSpeechSpeed => 'سرعة الكلام';

  @override
  String get configAutoSpeechTags => 'وسوم الكلام التلقائية';

  @override
  String get configStreamingLatency => 'تحسين زمن البث';

  @override
  String get configSampleRate => 'معدل العينات';

  @override
  String get configBitRate => 'معدل البت';

  @override
  String get configDevice => 'الجهاز';

  @override
  String get configLanguageCode => 'رمز اللغة';

  @override
  String get configAudioEvents => 'وسم أحداث الصوت';

  @override
  String get configDiarization => 'فصل المتحدثين';

  @override
  String get configSpeechToText => 'تحويل الكلام إلى نص';

  @override
  String get configEchoTranscripts => 'إظهار النسخ';

  @override
  String get configSttProvider => 'موفر STT';

  @override
  String get configTtsProvider => 'موفر TTS';

  @override
  String get configAutoReadReplies => 'قراءة الردود تلقائيًا';

  @override
  String get configMaxRecordingSeconds => 'الحد الأقصى لثواني التسجيل';

  @override
  String get configRecordShortcut => 'اختصار التسجيل';

  @override
  String get configDirectVoiceService => 'الاتصال مباشرة بخدمة الصوت';

  @override
  String get configVoiceFieldsUnavailable => 'لم يعد الخادم حقول الصوت';

  @override
  String get configVoiceFieldsUnavailableDescription =>
      'لم يعد GET /api/v1/config حقول stt أو tts أو voice.';

  @override
  String get configProviderApiKeys => 'مفاتيح API لموفري النماذج';

  @override
  String get configNoProviders => 'لا يوجد موفرون معدون';

  @override
  String get configNoProvidersDescription =>
      'أضف مفتاح API لتمكين موفر النموذج';

  @override
  String get configEnvironmentVariables => 'متغيرات البيئة';

  @override
  String get configConfigured => 'معد';

  @override
  String get configNotConfigured => 'غير معد';

  @override
  String configAvailableModels(int count) {
    return 'النماذج المتاحة: $count';
  }

  @override
  String configDisconnectedProvider(String name) {
    return 'تم فصل $name';
  }

  @override
  String configDisconnectFailed(String error) {
    return 'تعذر قطع الاتصال: $error';
  }

  @override
  String get configUpdateKey => 'تحديث المفتاح';

  @override
  String get configAddKey => 'إضافة مفتاح';

  @override
  String configProviderApiKey(String name) {
    return 'مفتاح API لـ $name';
  }

  @override
  String configProviderKeySaved(String name) {
    return 'تم حفظ مفتاح API لـ $name';
  }

  @override
  String get configSaved => 'تم الحفظ';

  @override
  String get configPressEnterToSave => 'اضغط Enter للحفظ';

  @override
  String get configEnterNumber => 'أدخل رقمًا';

  @override
  String get configNewValueOptional => 'قيمة جديدة (اتركها فارغة لعدم التغيير)';

  @override
  String get configValue => 'القيمة';

  @override
  String configRevealFailed(String error) {
    return 'تعذر إظهار القيمة: $error';
  }

  @override
  String configDeleteVariableQuestion(String key) {
    return 'حذف $key؟';
  }

  @override
  String get configDeleteVariableDescription =>
      'سيحذف متغير البيئة هذا نهائيًا من ملف .env على الخادم، ولا يمكن التراجع.';

  @override
  String get configAddEnvironmentVariable => 'إضافة متغير بيئة';

  @override
  String get configVariableName => 'اسم المتغير';

  @override
  String get configNoEnvironmentVariables => 'لا توجد متغيرات بيئة';

  @override
  String get configNoEnvironmentVariablesDescription =>
      'أضف متغيرات مخصصة لإعداد الأدوات أو الموفرين';

  @override
  String get configHideAdvancedVariables => 'إخفاء المتغيرات المتقدمة';

  @override
  String configShowAdvancedVariables(int count) {
    return 'إظهار المتغيرات المتقدمة ($count)';
  }

  @override
  String get configSet => 'معين';

  @override
  String get configNotSet => 'غير معين';

  @override
  String get configVoiceIdManual =>
      'اضغط Enter للحفظ (لم تعد قائمة أصوات الحساب؛ أدخل معرفًا يدويًا)';

  @override
  String configVoicesLoadFailed(String error) {
    return 'تعذر تحميل أصوات الحساب: $error. أدخل معرفًا يدويًا واضغط Enter للحفظ.';
  }

  @override
  String chatDraftHandoffSaveFailed(String error) {
    return 'المسودة متاحة هنا، لكن تعذر حفظها على الخادم: $error';
  }

  @override
  String get toolPlanTitle => 'الخطة';

  @override
  String get toolPlanCopy => 'نسخ الخطة';

  @override
  String get toolPlanCopied => 'تم نسخ الخطة';

  @override
  String get toolValueNotProvided => 'غير متوفر';

  @override
  String get toolCommand => 'الأمر';

  @override
  String get toolWaitingCommand => 'بانتظار الأمر';

  @override
  String get toolOutput => 'المخرجات';

  @override
  String get toolErrorOutput => 'مخرجات الخطأ';

  @override
  String toolExitCode(int code) {
    return 'رمز الخروج: $code';
  }

  @override
  String get toolCode => 'الرمز';

  @override
  String toolCodeLanguage(String language) {
    return 'الرمز · $language';
  }

  @override
  String get toolWaitingCode => 'بانتظار الرمز';

  @override
  String get toolExecutionResult => 'نتيجة التنفيذ';

  @override
  String toolChangedFiles(int count) {
    return 'الملفات المعدّلة · $count';
  }

  @override
  String get toolPatchContent => 'محتوى التصحيح';

  @override
  String get toolWaitingPatch => 'بانتظار التصحيح';

  @override
  String get toolResult => 'النتيجة';

  @override
  String get toolSearchQuery => 'عبارة البحث';

  @override
  String get toolSearchingWeb => 'جارٍ البحث في الويب';

  @override
  String toolSearchResults(int count) {
    return 'نتائج البحث · $count';
  }

  @override
  String get toolNoResults => 'لا توجد نتائج';

  @override
  String get toolLink => 'الرابط';

  @override
  String get toolContent => 'المحتوى';

  @override
  String get toolFile => 'الملف';

  @override
  String get toolReadingFile => 'جارٍ قراءة الملف';

  @override
  String get toolWritingFile => 'جارٍ كتابة الملف';

  @override
  String get toolWriteContent => 'المحتوى المراد كتابته';

  @override
  String toolFileList(int count) {
    return 'الملفات · $count';
  }

  @override
  String get toolNoFiles => 'لا توجد ملفات';

  @override
  String get toolDetails => 'التفاصيل';

  @override
  String get toolNoReadableContent => '(لا يوجد محتوى قابل للقراءة)';

  @override
  String get toolWaitingForResult => 'بانتظار مخرجات الأداة';

  @override
  String get toolUntitledResult => 'نتيجة بلا عنوان';

  @override
  String get toolCopyAll => 'نسخ الكل';

  @override
  String toolHiddenRestore(String name) {
    return '$name مخفي؛ اضغط للاستعادة';
  }

  @override
  String get toolReadableView => 'عرض مقروء';

  @override
  String get toolRawJsonView => 'عرض JSON الخام';

  @override
  String get toolHideRow => 'إخفاء صف الأداة';

  @override
  String get toolCopyResult => 'نسخ النتيجة';

  @override
  String toolRawDetailsTitle(String name) {
    return 'التفاصيل الخام لـ $name';
  }

  @override
  String get toolViewRawDetails => 'عرض التفاصيل الخام';

  @override
  String get toolArguments => 'المعاملات';

  @override
  String get toolNoDetailedData => '(لا توجد بيانات تفصيلية)';

  @override
  String toolArgumentDetailsTitle(String key) {
    return 'معامل $key';
  }

  @override
  String toolTapForFullContent(int count) {
    return '[اضغط لعرض $count حرفًا بالكامل]';
  }

  @override
  String toolContentTooLong(int count) {
    return 'المحتوى طويل ($count حرفًا)';
  }

  @override
  String toolFullResultTitle(String name) {
    return 'النتيجة الكاملة لـ $name';
  }

  @override
  String get toolViewFull => 'عرض الكل';

  @override
  String kanbanDeleteAttachment(String name) {
    return 'حذف $name؟';
  }

  @override
  String get kanbanCannotUndo => 'لا يمكن التراجع عن هذا الإجراء.';

  @override
  String kanbanOperationFailed(String error) {
    return 'فشلت العملية: $error';
  }

  @override
  String get kanbanNoLog => 'لا يوجد سجل';

  @override
  String get kanbanAddChildTask => 'إضافة مهمة فرعية';

  @override
  String get kanbanTaskId => 'معرف المهمة';

  @override
  String get kanbanDescription => 'الوصف';

  @override
  String get kanbanCommandCopied => 'تم نسخ الأمر';

  @override
  String get kanbanViewLog => 'عرض السجل';

  @override
  String get kanbanEstimate => 'تقدير';

  @override
  String get kanbanDecompose => 'تفكيك';

  @override
  String get kanbanNoDescription => 'لا يوجد وصف';

  @override
  String get kanbanDiagnostics => 'التشخيص';

  @override
  String kanbanComments(int count) {
    return 'التعليقات ($count)';
  }

  @override
  String get kanbanAddComment => 'إضافة تعليق';

  @override
  String kanbanDependencies(int parents, int children) {
    return 'التبعيات: $parents مهام رئيسية و$children مهام فرعية';
  }

  @override
  String kanbanChildTask(String id) {
    return 'المهمة الفرعية $id';
  }

  @override
  String kanbanAttachments(int count) {
    return 'المرفقات ($count)';
  }

  @override
  String kanbanEventTimeline(int count) {
    return 'الخط الزمني للأحداث ($count)';
  }

  @override
  String kanbanRuns(int count) {
    return 'عمليات التشغيل ($count)';
  }

  @override
  String get kanbanUploadAttachment => 'رفع مرفق';

  @override
  String kanbanAttachmentBytes(int count) {
    return '$count بايت';
  }

  @override
  String messageReactionFailed(String error) {
    return 'تعذر تحديث التفاعل: $error';
  }

  @override
  String get messageRenderFailed => 'تعذر عرض هذه الرسالة';

  @override
  String get messageRenderFailedDescription => 'لن تتأثر الرسائل الأخرى';

  @override
  String get messageRemoveMyReaction => 'إزالة تفاعلي';

  @override
  String get messageAgentReaction => 'تفاعل الوكيل';

  @override
  String get messageAddReaction => 'إضافة تفاعل';

  @override
  String get messageSearchEmoji => 'البحث عن رمز تعبيري';

  @override
  String messageImageSaveFailed(String error) {
    return 'تعذر حفظ الصورة: $error';
  }

  @override
  String get messageGeneratingImage => 'جارٍ إنشاء الصورة…';

  @override
  String get messageImageGenerationFailed => 'فشل إنشاء الصورة';

  @override
  String get messageWaitingForImage => 'بانتظار نتيجة الصورة';

  @override
  String get messageGeneratedImage => 'الصورة المنشأة';

  @override
  String get messageImageLinkCopied => 'تم نسخ رابط الصورة';

  @override
  String get messageOpenInBrowser => 'فتح في المتصفح';

  @override
  String get messageMcpSetup => 'إعداد خادم MCP';

  @override
  String messageMcpServer(String server) {
    return 'MCP · $server';
  }

  @override
  String get messageMcpSetupFailed =>
      'فشل الإعداد؛ أعد المحاولة من إعدادات MCP';

  @override
  String get messageMcpSetupWaiting => 'بانتظار اكتمال الإعداد';

  @override
  String get messageMcpSetupComplete => 'اكتمل الإعداد';

  @override
  String get messageOpenMcpSettings => 'فتح إعدادات MCP';

  @override
  String get messageFileChanges => 'تغييرات الملفات';

  @override
  String get messageViewDiff => 'عرض الفرق';

  @override
  String get messageOpenLink => 'فتح الرابط';

  @override
  String messageSendingToAgent(String name) {
    return 'جارٍ الإرسال إلى $name…';
  }

  @override
  String messageSentToAgent(String name) {
    return 'تم الإرسال إلى $name';
  }

  @override
  String messageReplyFromAgent(String name) {
    return 'رد من $name';
  }

  @override
  String messageRepliedToAgent(String name) {
    return 'تم الرد على $name';
  }

  @override
  String messageFromAgent(String name) {
    return 'من الوكيل · $name';
  }

  @override
  String get messageSteered => 'تم التوجيه';

  @override
  String get messageHermesAvatar => 'صورة مساعد Hermes';

  @override
  String get messageSourceWechat => 'WeChat';

  @override
  String get messageSourceFeishu => 'Feishu';

  @override
  String get messageSourceDesktop => 'سطح المكتب';

  @override
  String get messageRestoreVersion => 'استعادة هذا الإصدار';

  @override
  String get messagePreviousVersion => 'الإصدار السابق';

  @override
  String get messageNextVersion => 'الإصدار التالي';

  @override
  String get messageCopyText => 'نسخ النص';

  @override
  String get messageCopyMarkdown => 'نسخ بصيغة Markdown';

  @override
  String get messageBranchFromHere => 'إنشاء فرع من هذه الرسالة';

  @override
  String get messageSpeakDisconnected => 'اتصل بالخادم لقراءة الرسالة';

  @override
  String get messageSpeakFailed => 'تعذر تشغيل الصوت. حاول مرة أخرى.';

  @override
  String get messageStopSpeaking => 'إيقاف القراءة';

  @override
  String get messageSpeak => 'قراءة بصوت عالٍ';

  @override
  String get sessionDetailMessages => 'الرسائل';

  @override
  String get sessionDetailTools => 'الأدوات';

  @override
  String get sessionDetailEstimated => 'تقديري';

  @override
  String get sessionDetailCost => 'التكلفة';

  @override
  String get sessionDetailDuration => 'المدة';

  @override
  String get sessionDetailInfo => 'معلومات الجلسة';

  @override
  String get sessionDetailSource => 'المصدر';

  @override
  String get sessionDetailModel => 'النموذج';

  @override
  String get sessionDetailStarted => 'البدء';

  @override
  String get sessionDetailLastActivity => 'آخر نشاط';

  @override
  String get sessionDetailEnded => 'الانتهاء';

  @override
  String get sessionDetailEndReason => 'سبب الانتهاء';

  @override
  String get sessionDetailHandoff => 'التسليم';

  @override
  String get sessionDetailHandoffError => 'خطأ التسليم';

  @override
  String get sessionDetailTokensBilling => 'الرموز والفوترة';

  @override
  String get sessionDetailInputOutput => 'الإدخال / الإخراج';

  @override
  String get sessionDetailCacheReadWrite => 'قراءة / كتابة الذاكرة المؤقتة';

  @override
  String get sessionDetailReasoningTokens => 'رموز الاستدلال';

  @override
  String get sessionDetailBillingSource => 'مصدر الفوترة';

  @override
  String get sessionDetailContextSource => 'السياق والمصدر';

  @override
  String get sessionDetailWorkingDirectory => 'دليل العمل';

  @override
  String get sessionDetailGitBranch => 'فرع Git';

  @override
  String get sessionDetailContact => 'جهة الاتصال';

  @override
  String get sessionDetailChatType => 'نوع الدردشة';

  @override
  String get sessionDetailUserId => 'معرف المستخدم';

  @override
  String get sessionDetailParentSession => 'الجلسة الرئيسية';

  @override
  String get sessionDetailRewindCount => 'عدد التراجعات';

  @override
  String get sessionDetailCompressionFailed => 'فشل الضغط مؤقتًا';

  @override
  String get sessionDetailOpen => 'فتح الجلسة';

  @override
  String get sessionActionOpenWorkspace => 'فتح في مساحة العمل';

  @override
  String get sessionActionUnpin => 'إلغاء التثبيت';

  @override
  String get sessionActionPin => 'تثبيت';

  @override
  String get sessionActionAppearance => 'المظهر';

  @override
  String get sessionActionDuplicate => 'نسخ الجلسة';

  @override
  String get sessionActionShare => 'مشاركة الجلسة';

  @override
  String get sessionActionExport => 'تصدير الجلسة';

  @override
  String get sessionActionMoveProject => 'نقل إلى مشروع';

  @override
  String get sessionActionUnarchive => 'إلغاء الأرشفة';

  @override
  String get sessionActionArchive => 'أرشفة';

  @override
  String get sessionActionStopResponse => 'إيقاف الرد';

  @override
  String get sessionActionAppearanceTitle => 'مظهر الجلسة';

  @override
  String sessionActionRenameFailed(String error) {
    return 'تعذرت إعادة التسمية: $error';
  }

  @override
  String get sessionActionUnarchived => 'تم إلغاء الأرشفة';

  @override
  String get sessionActionArchived => 'تمت الأرشفة';

  @override
  String sessionActionFailed(String error) {
    return 'فشلت العملية: $error';
  }

  @override
  String get sessionActionUnpinned => 'تم إلغاء التثبيت';

  @override
  String get sessionActionPinned => 'تم التثبيت';

  @override
  String get sessionActionMoved => 'تم نقل الجلسة';

  @override
  String sessionActionMoveFailed(String error) {
    return 'تعذر النقل: $error';
  }

  @override
  String sessionActionBranchCreated(String id) {
    return 'تم إنشاء الفرع: $id';
  }

  @override
  String get sessionActionCopyCreated => 'تم إنشاء نسخة من الجلسة';

  @override
  String sessionActionDuplicateFailed(String error) {
    return 'تعذر نسخ الجلسة: $error';
  }

  @override
  String get sessionActionShareCreated => 'تم إنشاء رابط المشاركة';

  @override
  String get sessionActionShareWarning =>
      'يمكن لأي شخص لديه الرابط عرض الجلسة.';

  @override
  String sessionActionShareFailed(String error) {
    return 'تعذرت المشاركة: $error';
  }

  @override
  String get sessionActionStopRequested => 'تم طلب الإيقاف';

  @override
  String get sessionActionExportMarkdownHint => 'مناسب للعرض والمشاركة';

  @override
  String get sessionActionExportJsonHint => 'يحتفظ بكل البيانات المنظمة';

  @override
  String get sessionActionExportCopiedWeb =>
      'تم نسخ التصدير إلى الحافظة لأن الويب لا يحفظ ملفات محلية';

  @override
  String sessionActionExported(String path) {
    return 'تم التصدير إلى $path ونسخ المسار';
  }

  @override
  String sessionActionExportFailed(String error) {
    return 'تعذر تصدير الجلسة: $error';
  }

  @override
  String get sessionsNoDetail => 'لا توجد تفاصيل للجلسة';

  @override
  String get sessionsNoDetailDescription =>
      'عدّل عوامل التصفية لعرض ملخص الجلسة';

  @override
  String get sessionsAllProjects => 'كل المشاريع';

  @override
  String get sessionsProject => 'المشروع';

  @override
  String get sessionsSearchHint =>
      'البحث في العناوين أو المعاينات أو أدلة العمل…';

  @override
  String get sessionsToday => 'اليوم';

  @override
  String get sessionsThisWeek => 'هذا الأسبوع';

  @override
  String get sessionsStarred => 'مميزة بنجمة';

  @override
  String get sessionsSortNewest => 'الوقت: الأحدث أولًا';

  @override
  String get sessionsSortOldest => 'الوقت: الأقدم أولًا';

  @override
  String get sessionsSortTitle => 'العنوان: أ-ي';

  @override
  String get sessionsSortMessages => 'الرسائل: الأكثر أولًا';

  @override
  String get sessionsSortMethod => 'طريقة الترتيب';

  @override
  String get sessionsLoading => 'جارٍ تحميل الجلسات…';

  @override
  String get sessionsViewFullDetails => 'عرض التفاصيل الكاملة';

  @override
  String get sessionsSettings => 'الإعدادات';

  @override
  String get requestHermesQuestion => 'سؤال من Hermes';

  @override
  String get requestPending => 'طلب معلّق';

  @override
  String get requestAlwaysAllowQuestion => 'السماح دائمًا؟';

  @override
  String get requestAlwaysAllowDescription =>
      'ستضاف هذه العملية إلى الإعدادات كقاعدة سماح دائمة، ولن تسأل العمليات المشابهة لاحقًا.';

  @override
  String requestAlwaysAllowDetail(String detail) {
    return 'ستضاف «$detail» إلى الإعدادات كقاعدة سماح دائمة، ولن تسأل العمليات المشابهة لاحقًا.';
  }

  @override
  String get requestNoActiveSession => 'لا توجد جلسة نشطة';

  @override
  String get requestConnectionUnavailable => 'اتصال الطلب غير متاح';

  @override
  String requestRespondFailed(String error) {
    return 'تعذر الرد: $error';
  }

  @override
  String get requestAnswerFailed => 'تعذر إرسال الإجابة. حاول مرة أخرى.';

  @override
  String get requestMcpNameMissing => 'لا يتضمن الطلب اسم خادم MCP';

  @override
  String get requestOAuthTimeout => 'انتهت مهلة مصادقة OAuth';

  @override
  String get requestMcpTestFailed => 'فشل اختبار اتصال MCP';

  @override
  String get requestMcpSetupFailed => 'فشل إعداد MCP';

  @override
  String requestConfigureMcp(String name) {
    return 'إعداد $name';
  }

  @override
  String get requestCloseQuestion => 'إغلاق الطلب؟';

  @override
  String get requestCloseDescription =>
      'لا يمكن استعادة الطلب بعد إغلاقه وسيظل الوكيل منتظرًا.';

  @override
  String get requestProcessed => 'تمت المعالجة';

  @override
  String get requestInteractionProcessed => 'تمت معالجة الطلب التفاعلي';

  @override
  String requestServer(String name) {
    return 'الخادم: $name';
  }

  @override
  String get requestSubmitAllAnswers => 'إرسال كل الإجابات';

  @override
  String get requestConfigureLater => 'ليس الآن';

  @override
  String get requestConfiguring => 'جارٍ الإعداد…';

  @override
  String get requestInstallEnable => 'التثبيت والتمكين';

  @override
  String get requestEnterContent => 'أدخل المحتوى';

  @override
  String get requestEnterText => 'أدخل…';

  @override
  String requestMorePending(int count) {
    return '$count طلبات أخرى معلقة';
  }

  @override
  String get requestAllowOnce => 'السماح مرة واحدة';

  @override
  String get requestAllowSession => 'السماح لهذه الجلسة';

  @override
  String requestSubmitSelected(int count) {
    return 'إرسال ($count محدد)';
  }

  @override
  String get requestCustomAnswer => 'أخرى (إجابة مخصصة)';

  @override
  String get requestRecommended => 'موصى به';

  @override
  String messagingLoadFailed(String error) {
    return 'تعذر تحميل منصات الرسائل: $error';
  }

  @override
  String messagingPlatformEnabled(String name) {
    return 'تم تمكين $name';
  }

  @override
  String messagingPlatformDisabled(String name) {
    return 'تم تعطيل $name';
  }

  @override
  String messagingUpdateFailed(String error) {
    return 'فشل التحديث: $error';
  }

  @override
  String messagingTestPassed(String name) {
    return 'نجح اختبار اتصال $name';
  }

  @override
  String get messagingTestNotPassed => 'لم ينجح اختبار الاتصال';

  @override
  String messagingTestFailed(String error) {
    return 'فشل الاختبار: $error';
  }

  @override
  String messagingConfigSaved(String name) {
    return 'تم حفظ إعداد $name. أعد تشغيل Gateway لتطبيق تغييرات الاتصال';
  }

  @override
  String messagingSaveFailed(String error) {
    return 'فشل الحفظ: $error';
  }

  @override
  String messagingApproved(String name) {
    return 'تمت الموافقة على $name';
  }

  @override
  String messagingApproveFailed(String error) {
    return 'فشلت الموافقة: $error';
  }

  @override
  String get messagingRevokeTitle => 'إلغاء الوصول';

  @override
  String messagingRevokeQuestion(String name) {
    return 'إلغاء وصول $name إلى الرسائل؟';
  }

  @override
  String get messagingRevoke => 'إلغاء';

  @override
  String get messagingRevoked => 'تم إلغاء الوصول';

  @override
  String messagingRevokeFailed(String error) {
    return 'تعذر إلغاء الوصول: $error';
  }

  @override
  String get messagingRestartQuestion => 'إعادة تشغيل Gateway؟';

  @override
  String get messagingRestartWarning =>
      'سيؤدي ذلك إلى مقاطعة كل الجلسات والعملاء المتصلين بهذا Gateway، وسيعيدون الاتصال تلقائيًا بعد الاكتمال.';

  @override
  String get messagingRestarting => 'جارٍ إعادة تشغيل Gateway';

  @override
  String messagingRestartFailed(String error) {
    return 'فشلت إعادة تشغيل Gateway: $error';
  }

  @override
  String get messagingTitle => 'منصات الرسائل';

  @override
  String get messagingRestartGateway => 'إعادة تشغيل Gateway';

  @override
  String get messagingLoading => 'جارٍ تحميل منصات الرسائل…';

  @override
  String get messagingPendingApproval => 'بانتظار الموافقة';

  @override
  String get messagingPlatforms => 'المنصات';

  @override
  String get messagingEmpty => 'لا توجد منصات رسائل';

  @override
  String get messagingEmptyDescription =>
      'لم يعد الخادم منصات رسائل قابلة للإعداد';

  @override
  String get messagingAuthorizedUsers => 'المستخدمون المصرح لهم';

  @override
  String get messagingConfigure => 'إعداد';

  @override
  String get messagingTest => 'اختبار';

  @override
  String get messagingOpenDocs => 'فتح الوثائق';

  @override
  String get messagingUnknownUser => 'مستخدم غير معروف';

  @override
  String get messagingApprove => 'موافقة';

  @override
  String get messagingStateDisabled => 'معطل';

  @override
  String get messagingStateGatewayStopped => 'معد، لكن Gateway لا يعمل';

  @override
  String get messagingStateFatal => 'خطأ فادح';

  @override
  String get messagingStateStartupFailed => 'فشل بدء التشغيل';

  @override
  String get messagingStateConfigured => 'معد';

  @override
  String get messagingStateNeedsConfig => 'يحتاج إلى إعداد';

  @override
  String messagingPlatformConfig(String name) {
    return 'إعداد $name';
  }

  @override
  String get messagingNoEditableConfig =>
      'لا توجد إعدادات قابلة للتعديل لهذه المنصة.';

  @override
  String get messagingAdvancedSettings => 'إعدادات متقدمة';

  @override
  String get messagingSetLeaveBlank => 'معين؛ اتركه فارغًا دون تغيير';

  @override
  String get messagingEnterNewValue => 'أدخل قيمة جديدة';

  @override
  String get messagingShow => 'إظهار';

  @override
  String get messagingClearSavedValue => 'مسح القيمة المحفوظة';

  @override
  String get fileTreeListView => 'عرض القائمة';

  @override
  String get fileTreeTreeView => 'عرض الشجرة';

  @override
  String get fileTreeAttachToChat => 'إرفاق بالدردشة';

  @override
  String get projectAddFolder => 'إضافة مجلد';

  @override
  String get projectFolderPath => 'مسار المجلد';

  @override
  String get projectFolderLabelOptional => 'التسمية (اختياري)';

  @override
  String get projectCreate => 'إنشاء مشروع';

  @override
  String get projectLoading => 'جارٍ تحميل المشاريع…';

  @override
  String get projectEmpty => 'لا توجد مشاريع بعد';

  @override
  String get projectEmptyDescription =>
      'أنشئ مشروعًا لتنظيم أدلة العمل والجلسات';

  @override
  String get projectWorkspace => 'مساحة عمل المشروع';

  @override
  String get projectEditAppearance => 'تعديل المظهر';

  @override
  String get projectColor => 'اللون';

  @override
  String get projectIcon => 'الأيقونة';

  @override
  String projectAppearanceSaveFailed(String error) {
    return 'تعذر حفظ المظهر: $error';
  }

  @override
  String get projectRename => 'إعادة التسمية';

  @override
  String get projectRenameTitle => 'إعادة تسمية المشروع';

  @override
  String get projectName => 'اسم المشروع';

  @override
  String projectRenameFailed(String error) {
    return 'تعذرت إعادة تسمية المشروع: $error';
  }

  @override
  String projectDeleteQuestion(String name) {
    return 'حذف $name؟';
  }

  @override
  String get projectDeleteDescription =>
      'سيحذف المشروع دون التأثير في جلساته وملفاته. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String projectDeleteFailed(String error) {
    return 'تعذر حذف المشروع: $error';
  }

  @override
  String projectCreateFailed(String error) {
    return 'تعذر إنشاء المشروع: $error';
  }

  @override
  String get projectManagement => 'إدارة المشاريع';

  @override
  String get projectLoadFailed => 'تعذر تحميل المشاريع';

  @override
  String get projectNoMoveTargets => 'لا توجد مشاريع أخرى مؤهلة';

  @override
  String get projectNoMoveTargetsDescription =>
      'يحتاج المشروع إلى دليل عمل صالح قبل أن يتمكن من استقبال الجلسات';

  @override
  String get projectNew => 'مشروع جديد';

  @override
  String get projectEditTitle => 'تعديل المشروع';

  @override
  String get projectPrimaryPath => 'دليل العمل الأساسي';

  @override
  String get projectPrimaryPathHint => 'مثال: /home/user/projects/my-app';

  @override
  String get projectDescriptionOptional => 'الوصف (اختياري)';

  @override
  String get projectRequiredFields => 'أدخل اسم المشروع ودليل العمل';

  @override
  String get projectCreated => 'تم إنشاء المشروع';

  @override
  String get projectUpdated => 'تم تحديث المشروع';

  @override
  String projectSaveFailed(String error) {
    return 'تعذر حفظ المشروع: $error';
  }

  @override
  String get projectDeleteTitle => 'حذف المشروع؟';

  @override
  String projectDeleteNamedDescription(String name) {
    return 'سيتم حذف المشروع «$name». لن تحذف الجلسات المرتبطة.';
  }

  @override
  String get projectDeleted => 'تم حذف المشروع';

  @override
  String subagentsLoadFailed(String error) {
    return 'تعذر تحميل الوكلاء الفرعيين: $error';
  }

  @override
  String get subagentsEmpty => 'لا يوجد نشاط للوكلاء الفرعيين';

  @override
  String get subagentsOpenSessionDescription =>
      'افتح جلسة لعرض شجرة الوكلاء الفرعيين';

  @override
  String get subagentsCurrentSessionEmpty =>
      'لا تحتوي الجلسة الحالية على وكلاء فرعيين قيد التشغيل';

  @override
  String get subagentsCurrentSession => 'الجلسة الحالية';

  @override
  String subagentsSession(String id) {
    return 'الجلسة $id';
  }

  @override
  String subagentsCount(int count) {
    return '$count من الوكلاء الفرعيين';
  }

  @override
  String subagentsRunningCount(int count) {
    return 'قيد التشغيل $count';
  }

  @override
  String subagentsFailedCount(int count) {
    return 'فشل $count';
  }

  @override
  String subagentsToolCalls(int count) {
    return '$count من استدعاءات الأدوات';
  }

  @override
  String subagentsFiles(int count) {
    return '$count ملفات';
  }

  @override
  String get subagentsInterrupt => 'مقاطعة';

  @override
  String get subagentsInterruptSent => 'تم إرسال إشارة المقاطعة';

  @override
  String subagentsInterruptFailed(String error) {
    return 'تعذرت مقاطعة الوكيل الفرعي: $error';
  }

  @override
  String get subagentsOpenSession => 'فتح الجلسة';

  @override
  String subagentsOpenSessionFailed(String error) {
    return 'تعذر فتح جلسة الوكيل الفرعي: $error';
  }

  @override
  String subagentsCurrentTool(String name) {
    return 'الأداة: $name';
  }

  @override
  String subagentsTools(int count) {
    return '$count أدوات';
  }

  @override
  String subagentsFilesRead(int count) {
    return 'قراءة $count';
  }

  @override
  String subagentsFilesWritten(int count) {
    return 'كتابة $count';
  }

  @override
  String get subagentsStatusQueued => 'في قائمة الانتظار';

  @override
  String get subagentsStatusInterrupted => 'تمت مقاطعته';

  @override
  String get subagentsStatusUnknown => 'غير معروف';

  @override
  String credentialsLoadFailed(String error) {
    return 'تعذر تحميل بيانات الاعتماد: $error';
  }

  @override
  String get credentialsSearchHint => 'البحث في بيانات الاعتماد أو المزودين…';

  @override
  String get credentialsMissing => 'مفقود';

  @override
  String get credentialsNoMatches => 'لا توجد بيانات اعتماد مطابقة';

  @override
  String get credentialsNoMatchesDescription =>
      'عدّل البحث أو عامل تصفية الحالة';

  @override
  String get credentialsEmpty => 'لا يوجد مزودو بيانات اعتماد';

  @override
  String get credentialsEmptyDescription =>
      'لم يعد الخادم مزودي بيانات اعتماد قابلين للإعداد';

  @override
  String get credentialsGroupCloud => 'مزودو السحابة';

  @override
  String get credentialsGroupModelProviders => 'مزودو النماذج';

  @override
  String get credentialsGroupThirdParty => 'خدمات الطرف الثالث';

  @override
  String get credentialsKeyRequired => 'اختر مزودًا وأدخل مفتاح API أو رمزًا';

  @override
  String credentialsSaveFailed(String error) {
    return 'تعذر حفظ بيانات الاعتماد: $error';
  }

  @override
  String get credentialsAddTitle => 'إضافة بيانات اعتماد';

  @override
  String get credentialsEditTitle => 'تعديل بيانات الاعتماد';

  @override
  String get credentialsSaving => 'جارٍ الحفظ…';

  @override
  String credentialsApiKey(String name) {
    return 'مفتاح API / الرمز لـ $name';
  }

  @override
  String get credentialsShowKey => 'إظهار المفتاح';

  @override
  String get credentialsHideKey => 'إخفاء المفتاح';

  @override
  String get petCenterTitle => 'مركز الحيوانات الأليفة';

  @override
  String get petRename => 'إعادة التسمية';

  @override
  String get petDisable => 'تعطيل الحيوان الأليف';

  @override
  String petRenameFailed(String error) {
    return 'تعذرت إعادة تسمية الحيوان الأليف: $error';
  }

  @override
  String petDisableFailed(String error) {
    return 'تعذر تعطيل الحيوان الأليف: $error';
  }

  @override
  String get petRenameTitle => 'إعادة تسمية الحيوان الأليف';

  @override
  String get petRenameHint => 'أدخل اسمًا جديدًا…';

  @override
  String get petUntitled => 'بلا اسم';

  @override
  String petStatus(String status) {
    return 'الحالة: $status';
  }

  @override
  String get petGallery => 'المعرض';

  @override
  String get petGalleryEmpty => 'لا توجد حيوانات أليفة متاحة';

  @override
  String get petGenerateNew => 'إنشاء حيوان أليف جديد';

  @override
  String get petStateWave => 'يلوح';

  @override
  String get petStateJump => 'يقفز';

  @override
  String get petStateCelebrate => 'يحتفل';

  @override
  String credentialsDisconnectQuestion(String name) {
    return 'قطع اتصال $name؟';
  }

  @override
  String get credentialsDisconnectDescription =>
      'ستتم إزالة بيانات الاعتماد المحفوظة من خادم Hermes ويمكن إضافتها مرة أخرى لاحقًا.';

  @override
  String starmapLoadDetailFailed(String error) {
    return 'تعذر تحميل تفاصيل العقدة: $error';
  }

  @override
  String get starmapRestoreMine => 'استعادة خريطتي';

  @override
  String get starmapShareImport => 'مشاركة أو استيراد';

  @override
  String get starmapResetView => 'إعادة ضبط العرض';

  @override
  String get starmapLoading => 'جارٍ تحميل الخريطة…';

  @override
  String get starmapNoData => 'لا توجد بيانات';

  @override
  String get starmapEmpty => 'خريطة المعرفة فارغة';

  @override
  String get starmapEmptyDescription =>
      'ستظهر عقد المعرفة هنا كلما تعلم Hermes المزيد.';

  @override
  String get starmapShareTitle => 'مشاركة الخريطة';

  @override
  String get starmapShareDescription =>
      'انسخ الرمز لمشاركة الخريطة، أو الصق رمزًا آخر وحمّله.';

  @override
  String get starmapShareCodeHint => 'رمز مشاركة الخريطة';

  @override
  String get starmapCopy => 'نسخ';

  @override
  String get starmapLoad => 'تحميل';

  @override
  String get starmapInvalidShareCode => 'رمز مشاركة الخريطة غير صالح.';

  @override
  String get starmapPause => 'إيقاف مؤقت';

  @override
  String get starmapPlay => 'تشغيل';

  @override
  String get starmapSkillLegend => 'مهارة';

  @override
  String get starmapMemoryLegend => 'ذاكرة';

  @override
  String get starmapChronologyLegend => 'المركز: الأقدم · الخارج: الأحدث';

  @override
  String starmapOpenNode(String name) {
    return 'فتح $name';
  }

  @override
  String get starmapSaved => 'تم الحفظ';

  @override
  String starmapSaveFailed(String error) {
    return 'تعذر حفظ العقدة: $error';
  }

  @override
  String get starmapDeleteQuestion => 'حذف العقدة؟';

  @override
  String starmapDeleteDescription(String name) {
    return 'ستتم إزالة $name من الخريطة.';
  }

  @override
  String get starmapDeleted => 'تم حذف العقدة';

  @override
  String starmapDeleteFailed(String error) {
    return 'تعذر حذف العقدة: $error';
  }

  @override
  String starmapUseCount(int count) {
    return 'استُخدمت $count مرة';
  }

  @override
  String get starmapContent => 'المحتوى';

  @override
  String get starmapSaving => 'جارٍ الحفظ…';

  @override
  String starmapCreatedBy(Object value) {
    return 'بواسطة $value';
  }

  @override
  String starmapSource(Object value) {
    return 'المصدر: $value';
  }

  @override
  String get starmapStateArchived => 'مؤرشفة';

  @override
  String configCenterLoadFailed(String error) {
    return 'تعذر تحميل بيانات القدرات: $error';
  }

  @override
  String get configCenterKnowledgeTab => 'المعرفة';

  @override
  String get configCenterTitle => 'إدارة القدرات';

  @override
  String get configCenterLoadErrorTitle => 'تعذر تحميل القدرات';

  @override
  String get configCenterMcpEmptyDescription =>
      'أضف خادم MCP لربط الأدوات والبيانات الخارجية.';

  @override
  String get configCenterUrlOrCommand => 'عنوان URL أو الأمر';

  @override
  String get configCenterTransport => 'النقل';

  @override
  String get configCenterLocalStdio => 'Stdio (عملية محلية)';

  @override
  String configCenterMutationFailed(String error) {
    return 'تعذر تطبيق التغيير: $error';
  }

  @override
  String get configCenterKnowledgeTitle => 'مصادر المعرفة';

  @override
  String get configCenterKnowledgeEmpty => 'لا توجد مصادر معرفة';

  @override
  String get configCenterKnowledgeEmptyDescription =>
      'أضف ملفًا أو مجلدًا أو URL كمصدر معرفة.';

  @override
  String get configCenterDatabase => 'قاعدة بيانات';

  @override
  String configCenterKnowledgeMeta(String type, int count, String status) {
    return '$type · $count أجزاء · $status';
  }

  @override
  String get configCenterIndexed => 'مفهرس';

  @override
  String get configCenterNotIndexed => 'غير مفهرس';

  @override
  String get configCenterSkillsEmpty => 'لا توجد مهارات';

  @override
  String get configCenterSkillsEmptyDescription =>
      'لم يعد الخادم مهارات لهذا الملف الشخصي.';

  @override
  String get configCenterConfiguration => 'الإعداد';

  @override
  String get configCenterInstallPlugin => 'تثبيت مكون إضافي';

  @override
  String get configCenterPluginsEmpty => 'لا توجد مكونات إضافية';

  @override
  String get configCenterPluginsEmptyDescription =>
      'ثبت مكونًا إضافيًا لتوسيع Hermes.';

  @override
  String get configCenterInstall => 'تثبيت';

  @override
  String get configCenterPluginUrl => 'عنوان URL للمكون أو معرفه';

  @override
  String get fileEditorDiscardQuestion => 'تجاهل التغييرات غير المحفوظة؟';

  @override
  String get fileEditorDiscardDescription =>
      'سيؤدي الرجوع إلى فقدان التعديلات الحالية.';

  @override
  String get fileEditorKeepEditing => 'متابعة التحرير';

  @override
  String get fileEditorDiscard => 'تجاهل';

  @override
  String get fileEditorDisk => 'على القرص';

  @override
  String get fileEditorEditor => 'المحرر';

  @override
  String get fileEditorConflictDescription =>
      'تغير الملف على القرص. يمكنك الكتابة فوقه أو إعادة تحميله أو الإلغاء.';

  @override
  String get fileEditorConflictTitle => 'تغير الملف خارجيًا';

  @override
  String get fileEditorOverwriteSave => 'الكتابة فوقه والحفظ';

  @override
  String get fileEditorReloaded => 'تمت إعادة تحميل نسخة القرص';

  @override
  String get fileEditorSaved => 'تم الحفظ';

  @override
  String fileEditorSaveFailed(String error) {
    return 'تعذر حفظ الملف: $error';
  }

  @override
  String get fileEditorSaving => 'جارٍ الحفظ…';

  @override
  String fileEditorUnsavedTitle(String name) {
    return '$name، تغييرات غير محفوظة';
  }

  @override
  String get fileEditorEmpty => '(فارغ)';

  @override
  String get fileEditorBinaryTitle => 'لا يمكن تحرير هذا الملف كنص';

  @override
  String get fileEditorBinaryDescription =>
      'يبدو أنه ملف ثنائي (صورة أو أرشيف أو ملف تنفيذي). فتحه في محرر النصوص قد يتلفه عند الحفظ، لذا تم تعطيل التحرير — نزّله إلى جهازك بدلاً من ذلك.';

  @override
  String kanbanTaskCreatedLinkFailed(String error) {
    return 'تم إنشاء المهمة، لكن تعذرت إضافة رابط المهمة الأصل: $error';
  }

  @override
  String get kanbanTaskStatus => 'الحالة';

  @override
  String get kanbanPriority => 'الأولوية';

  @override
  String get kanbanAssignee => 'المكلف';

  @override
  String get kanbanTenant => 'المستأجر';

  @override
  String get kanbanParentTaskId => 'معرف المهمة الأصل';

  @override
  String get kanbanWorkspacePath => 'مسار مساحة العمل';

  @override
  String get kanbanModelOverride => 'تحديد النموذج';

  @override
  String get kanbanProviderOverride => 'تحديد المزود';

  @override
  String get kanbanEffort => 'جهد الاستدلال';

  @override
  String get kanbanEffortLow => 'منخفض';

  @override
  String get kanbanEffortMedium => 'متوسط';

  @override
  String get kanbanEffortHigh => 'مرتفع';

  @override
  String get kanbanCreatingTask => 'جارٍ إنشاء المهمة…';

  @override
  String get kanbanCreateTask => 'إنشاء مهمة';

  @override
  String get kanbanCreateBoard => 'إنشاء لوحة';

  @override
  String get kanbanBoardSettings => 'إعدادات اللوحة';

  @override
  String get kanbanProject => 'المشروع';

  @override
  String get kanbanNoProject => 'بدون مشروع';

  @override
  String get kanbanDeleteBoardQuestion => 'حذف اللوحة؟';

  @override
  String kanbanDeleteBoardDescription(String name) {
    return 'سيتم حذف $name. لا يمكن التراجع.';
  }

  @override
  String kanbanBoardTaskCount(int count) {
    return '$count مهام';
  }

  @override
  String kanbanBoardTaskCountProject(int count, String project) {
    return '$count مهام · $project';
  }

  @override
  String get kanbanRenameBoard => 'إعادة تسمية اللوحة';

  @override
  String pluginsOperationFailed(String error) {
    return 'تعذر تحديث المكون الإضافي: $error';
  }

  @override
  String get pluginsInstallTitle => 'تثبيت مكون Agent';

  @override
  String get pluginsIdentifierHint => 'عنوان Git أو owner/repo';

  @override
  String get pluginsEnableAfterInstall => 'تمكين بعد التثبيت';

  @override
  String get pluginsForceReinstall => 'فرض إعادة التثبيت';

  @override
  String pluginsInstalled(String name) {
    return 'تم تثبيت $name';
  }

  @override
  String pluginsInstallFailed(String error) {
    return 'تعذر تثبيت المكون: $error';
  }

  @override
  String get pluginsLoading => 'جارٍ تحميل المكونات…';

  @override
  String get pluginsNoData => 'لا توجد بيانات للمكونات';

  @override
  String pluginsSearchHint(int count) {
    return 'البحث في $count مكونات…';
  }

  @override
  String get pluginsNoMatches => 'لا توجد مكونات مطابقة';

  @override
  String get pluginsKindPlatform => 'منصة';

  @override
  String get pluginsKindProvider => 'مزود';

  @override
  String get pluginsKindTool => 'أداة';

  @override
  String pluginsContributionTooltip(String area, String description) {
    return '$area · $description';
  }

  @override
  String pluginsActionExecuted(String title) {
    return 'اكتمل $title';
  }

  @override
  String get pluginsAreaNavigation => 'التنقل';

  @override
  String get pluginsAreaCommand => 'الأوامر';

  @override
  String get pluginsAreaSettings => 'الإعدادات';

  @override
  String get pluginsAreaComposer => 'محرر الرسالة';

  @override
  String get pluginsAreaDetail => 'التفاصيل';

  @override
  String get pluginsAreaTranscript => 'سجل الحوار';

  @override
  String get pluginsAreaPane => 'اللوحة';

  @override
  String knowledgeLoadDetailFailed(String error) {
    return 'تعذر تحميل تفاصيل العقدة: $error';
  }

  @override
  String get knowledgeLoading => 'جارٍ تحميل رسم المعرفة…';

  @override
  String get knowledgeNoData => 'لا توجد بيانات معرفة';

  @override
  String get knowledgeSearchHint => 'البحث في عقد المعرفة…';

  @override
  String knowledgeMemorySummary(int count) {
    return 'ملخص الذاكرة ($count)';
  }

  @override
  String get knowledgeNoMatches => 'لا توجد عقد معرفة مطابقة';

  @override
  String get knowledgeStateActive => 'نشط';

  @override
  String get knowledgeStateInactive => 'غير نشط';

  @override
  String knowledgeNodeMeta(String category, int count, String state) {
    return '$category · استُخدمت $count مرة · $state';
  }

  @override
  String knowledgeNodeMetaNoCategory(int count, String state) {
    return 'استُخدمت $count مرة · $state';
  }

  @override
  String get knowledgeSaved => 'تم الحفظ';

  @override
  String knowledgeSaveFailed(String error) {
    return 'تعذر حفظ العقدة: $error';
  }

  @override
  String get knowledgeDeleteQuestion => 'حذف عقدة المعرفة؟';

  @override
  String knowledgeDeleteDescription(String name) {
    return 'سيتم حذف $name. لا يمكن التراجع.';
  }

  @override
  String get knowledgeDeleted => 'تم حذف عقدة المعرفة';

  @override
  String knowledgeDeleteFailed(String error) {
    return 'تعذر حذف العقدة: $error';
  }

  @override
  String get knowledgeCancelEditing => 'إلغاء التحرير';

  @override
  String skillHubSearchFailed(String error) {
    return 'فشل البحث عن المهارات: $error';
  }

  @override
  String skillHubExitCode(int code) {
    return 'انتهت العملية بالرمز $code';
  }

  @override
  String get skillHubActionTimeout => 'انتهت مهلة عملية المهارة.';

  @override
  String get skillHubActionDone => 'اكتملت العملية';

  @override
  String skillHubActionFailed(String error) {
    return 'فشلت عملية المهارة: $error';
  }

  @override
  String skillHubUninstallQuestion(String name) {
    return 'إلغاء تثبيت $name؟';
  }

  @override
  String get skillHubUninstallDescription =>
      'ستتم إزالة المهارة ويمكن تثبيتها لاحقًا.';

  @override
  String get skillHubUninstall => 'إلغاء التثبيت';

  @override
  String get skillHubUpdateInstalled => 'تحديث المهارات المثبتة';

  @override
  String get skillHubSearchHint => 'البحث في سوق المهارات…';

  @override
  String get skillHubLoading => 'جارٍ تحميل سوق المهارات…';

  @override
  String skillHubSourcesTimedOut(String sources) {
    return 'انتهت مهلة بعض المصادر: $sources';
  }

  @override
  String get skillHubNoData => 'لا توجد بيانات للسوق';

  @override
  String get skillHubSources => 'المصادر';

  @override
  String skillHubRateLimited(String name) {
    return '$name (محدود)';
  }

  @override
  String get skillHubIndexUnavailable =>
      'فهرس المهارات غير متاح حاليًا، وقد تكون النتائج غير مكتملة.';

  @override
  String get skillHubFeatured => 'مميز';

  @override
  String get skillHubSearchPrompt => 'أدخل كلمات للبحث عن مهارات';

  @override
  String get skillHubInstalled => 'مثبت';

  @override
  String get skillHubTrustOfficial => 'رسمي';

  @override
  String get skillHubTrustTrusted => 'موثوق';

  @override
  String get skillHubTrustCommunity => 'المجتمع';

  @override
  String get skillHubTrustUnverified => 'غير متحقق';

  @override
  String get skillHubTrustUntrusted => 'غير موثوق';

  @override
  String get skillHubTrustUnknown => 'مستوى ثقة غير معروف';

  @override
  String newSessionInitFailed(String error) {
    return 'تعذر تحميل بعض خيارات الجلسة: $error';
  }

  @override
  String newSessionStartFailed(String error) {
    return 'تعذر بدء الجلسة: $error';
  }

  @override
  String get newSessionTitleSection => 'عنوان الجلسة';

  @override
  String get newSessionTitleHint => 'اختياري؛ اتركه فارغًا للإنشاء التلقائي';

  @override
  String get newSessionWorkspace => 'مساحة العمل';

  @override
  String get newSessionWorkspaceHint => 'مجلد عمل Agent على الخادم';

  @override
  String get newSessionBrowseDirectory => 'تصفح المجلدات';

  @override
  String get newSessionNoProject => 'بدون مشروع';

  @override
  String get newSessionMoveLater => 'يمكنك نقل الجلسة لاحقًا من قائمتها';

  @override
  String get newSessionUseCurrentModel => 'استخدام النموذج الحالي';

  @override
  String get newSessionAgent => 'Agent';

  @override
  String get newSessionStarting => 'جارٍ البدء…';

  @override
  String get newSessionStart => 'بدء الجلسة';

  @override
  String newSessionAgentSummary(String model, String cwd) {
    return '$model · $cwd';
  }

  @override
  String get newSessionCurrentModel => 'النموذج الحالي';

  @override
  String get newSessionWorkspaceAbove => 'مساحة العمل أعلاه';

  @override
  String get newSessionParentDirectory => 'المجلد الأصل';

  @override
  String get artifactsTitle => 'العناصر';

  @override
  String get artifactsSearchHint => 'البحث في عناوين العناصر والجلسات…';

  @override
  String get artifactsKindCode => 'رمز';

  @override
  String get artifactsKindImage => 'صورة';

  @override
  String get artifactsKindLink => 'رابط';

  @override
  String get artifactsEmpty => 'لا توجد عناصر';

  @override
  String get artifactsEmptyDescription =>
      'ستظهر هنا العناصر التي تنشئها الجلسات.';

  @override
  String get artifactsNoMatches => 'لا توجد عناصر مطابقة';

  @override
  String get artifactsNoMatchesDescription => 'جرّب بحثًا أو مرشحًا مختلفًا.';

  @override
  String artifactsOpen(String name) {
    return 'فتح العنصر $name';
  }

  @override
  String get artifactsSaved => 'تم الحفظ';

  @override
  String artifactsSaveFailed(String error) {
    return 'تعذر حفظ العنصر: $error';
  }

  @override
  String get artifactsSaveToDevice => 'حفظ على الجهاز';

  @override
  String get artifactsCopy => 'نسخ العنصر';

  @override
  String get artifactsOpenLink => 'فتح الرابط';

  @override
  String get artifactsOpenLinkFailed => 'تعذر فتح الرابط.';

  @override
  String get artifactsImageLoadFailed => 'تعذر تحميل الصورة';

  @override
  String get shellReconnecting => 'انقطع الاتصال. جارٍ إعادة الاتصال…';

  @override
  String get shellReconnectNow => 'إعادة الاتصال الآن';

  @override
  String get shellCollapseNavigation => 'طي التنقل';

  @override
  String get shellExpandNavigation => 'توسيع التنقل';

  @override
  String get shellNavigation => 'التنقل';

  @override
  String get shellSessionArea => 'الجلسات';

  @override
  String get shellWorkspaceArea => 'مساحة العمل';

  @override
  String get shellIntelligenceArea => 'الذكاء';

  @override
  String shellModelStatus(String value) {
    return 'النموذج $value';
  }

  @override
  String shellWorkspaceStatus(String value) {
    return 'مساحة العمل $value';
  }

  @override
  String shellAgentStatus(String value) {
    return 'الوكيل $value';
  }

  @override
  String get gitListView => 'عرض القائمة';

  @override
  String get gitTreeView => 'عرض الشجرة';

  @override
  String get gitViewPr => 'عرض طلب السحب';

  @override
  String gitChangeCounts(int staged, int changed) {
    return '$staged مرحّلة · $changed متغيرة';
  }

  @override
  String get gitWorkingTreeCleanDescription => 'لا توجد تغييرات غير مثبتة.';

  @override
  String get gitStagedSection => 'مرحّلة';

  @override
  String get gitUnstagedSection => 'غير مرحّلة';

  @override
  String get gitOpenPrFailed => 'تعذر فتح طلب السحب.';

  @override
  String gitUnstageFailed(String error) {
    return 'تعذر إلغاء الترحيل: $error';
  }

  @override
  String get gitCommitAndPushSucceeded => 'تم التثبيت والدفع';

  @override
  String get gitCommitSucceeded => 'تم التثبيت';

  @override
  String get gitStatusAdded => 'ض';

  @override
  String get gitStatusModified => 'ع';

  @override
  String get gitStatusDeleted => 'ح';

  @override
  String get gitStatusRenamed => 'ن';

  @override
  String get gitStatusConflict => 'ت';

  @override
  String get insightsTitle => 'الإحصاءات';

  @override
  String insightsDays(int count) {
    return '$count يومًا';
  }

  @override
  String insightsLoading(int count) {
    return 'جارٍ تحميل إحصاءات آخر $count يومًا…';
  }

  @override
  String get insightsNoData => 'لا توجد بيانات استخدام';

  @override
  String get insightsOverview => 'نظرة عامة';

  @override
  String get insightsSessions => 'الجلسات';

  @override
  String get insightsApiCalls => 'استدعاءات API';

  @override
  String get insightsCost => 'التكلفة';

  @override
  String get insightsDailyUsage => 'الاستخدام اليومي';

  @override
  String get insightsModelUsage => 'استخدام النماذج';

  @override
  String get insightsToolCalls => 'استدعاءات الأدوات';

  @override
  String get insightsUnknownProvider => 'موفر غير معروف';

  @override
  String insightsModelSummary(String tokens, int sessions, String cost) {
    return '$tokens رمز · $sessions جلسة · \$$cost';
  }

  @override
  String webhookBaseUrl(String url) {
    return 'عنوان URL الأساسي: $url';
  }

  @override
  String get webhookUrl => 'URL';

  @override
  String get webhookSecret => 'السر';

  @override
  String get toolsTitle => 'مجموعات الأدوات';

  @override
  String get toolsEmpty => 'لا توجد مجموعات أدوات';

  @override
  String toolsToolsetSummary(int count, String status) {
    return '$count أداة · $status';
  }

  @override
  String get toolsTerminalBackend => 'بيئة تنفيذ الطرفية';

  @override
  String get toolsReady => 'جاهز';

  @override
  String get toolsNeedsSetup => 'يحتاج إلى إعداد';

  @override
  String get toolsUnavailable => 'غير متاح';

  @override
  String toolsBackendSwitchFailed(String error) {
    return 'تعذر تبديل بيئة الطرفية: $error';
  }

  @override
  String get toolsComputerUseUnsupported => 'منصة الخادم هذه غير مدعومة';

  @override
  String get toolsComputerUseNotInstalled => 'cua-driver غير مثبت';

  @override
  String get toolsComputerUseReady => 'Computer Use جاهز';

  @override
  String get toolsComputerUseNotReady => 'برنامج التشغيل أو الأذونات غير جاهزة';

  @override
  String get toolsRecheck => 'إعادة الفحص';

  @override
  String get toolsCheck => 'فحص';

  @override
  String toolsCheckResult(String label, String result) {
    return '$label: $result';
  }

  @override
  String get toolsWaitingForPermission => 'بانتظار إذن الخادم…';

  @override
  String get toolsRequestPermission => 'طلب إذن نظام الخادم';

  @override
  String get toolsPermissionTimeout => 'انتهت مهلة طلب الإذن.';

  @override
  String toolsPermissionFailed(String error) {
    return 'تعذر طلب إذن النظام: $error';
  }

  @override
  String toolsToggleFailed(String error) {
    return 'تعذر تحديث مجموعة الأدوات: $error';
  }

  @override
  String get agentBotsTitle => 'Bots';

  @override
  String agentRequestSummary(String title, String member) {
    return '$title · $member';
  }

  @override
  String modelPickerRefreshFailed(String error) {
    return 'تعذر تحديث النماذج: $error';
  }

  @override
  String get modelPickerEdit => 'تعديل النماذج الظاهرة';

  @override
  String modelPickerVisibilitySaveFailed(String error) {
    return 'تعذر حفظ ظهور النماذج: $error';
  }

  @override
  String get modelPickerMoaPresets => 'إعدادات MoA';

  @override
  String modelPickerMoaModel(String model) {
    return 'MoA: $model';
  }

  @override
  String get modelPickerRefresh => 'تحديث النماذج';

  @override
  String get modelPickerFree => 'مجاني';

  @override
  String modelPickerFreeDiscount(num percent) {
    return 'مجاني · -$percent%';
  }

  @override
  String modelPickerPricing(String input, String output, String discount) {
    return 'الإدخال $input / الإخراج $output$discount';
  }

  @override
  String get modelPickerSelectNone => 'إلغاء تحديد الكل';

  @override
  String get modelPickerSelectAll => 'تحديد الكل';

  @override
  String get commonCopy => 'نسخ';

  @override
  String get chatMermaidDiagram => 'مخطط Mermaid';

  @override
  String chatArtifactTitle(String language) {
    return 'عنصر $language';
  }

  @override
  String chatCodeArtifactTitle(String language, int count) {
    return 'رمز $language · $count سطر';
  }

  @override
  String get chatArtifactPreview => 'معاينة العنصر';

  @override
  String chatCodeTitle(String language) {
    return 'رمز $language';
  }

  @override
  String get chatCodeCopied => 'تم نسخ الرمز';

  @override
  String get chatLivePreview => 'معاينة مباشرة';

  @override
  String get chatExpandPreview => 'توسيع المعاينة في الرسالة';

  @override
  String get chatAudioPlaybackFailed => 'تعذر تشغيل الصوت';

  @override
  String get chatPauseAudio => 'إيقاف الصوت مؤقتًا';

  @override
  String get chatPlayAudio => 'تشغيل الصوت';

  @override
  String get chatOpenVideo => 'فيديو · اضغط للفتح';

  @override
  String get chatOpenFile => 'ملف · اضغط للفتح';

  @override
  String imageSaveFailed(String error) {
    return 'تعذر حفظ الصورة: $error';
  }

  @override
  String get voiceMenu => 'قائمة الصوت';

  @override
  String get voiceStopRecording => 'إيقاف التسجيل';

  @override
  String get voiceDictation => 'إدخال صوتي';

  @override
  String get voiceContinuousConversation => 'محادثة صوتية مستمرة';

  @override
  String get voiceAutoReadReplies => 'قراءة الردود تلقائيًا';

  @override
  String get voiceWakeWord => 'كلمة التنبيه';

  @override
  String voiceWakePhrase(String phrase) {
    return '\"$phrase\"';
  }

  @override
  String get voiceStopSpeaking => 'إيقاف القراءة';

  @override
  String get voiceWakeEnabling => 'جارٍ تفعيل كلمة التنبيه…';

  @override
  String get voiceWakeTriggered => 'تم اكتشاف كلمة التنبيه. جارٍ الاستماع…';

  @override
  String get voiceWakeListening => 'الاستماع لكلمة التنبيه';

  @override
  String voiceWakeListeningFor(String phrase) {
    return 'الاستماع إلى \"$phrase\"';
  }

  @override
  String get voiceWakeWaiting => 'كلمة التنبيه بانتظار الاستئناف';

  @override
  String get voiceWakeDisabled => 'كلمة التنبيه متوقفة';

  @override
  String sessionPrBadge(int number, String status) {
    return 'PR #$number · $status';
  }

  @override
  String get sessionPrOpenFailed => 'تعذر فتح طلب السحب.';

  @override
  String get sessionCliBadge => 'جلسة CLI';

  @override
  String get sessionDraftBadge => 'مسودة غير مرسلة';

  @override
  String get sessionSharedBadge => 'تمت المشاركة';

  @override
  String get sessionHandedOff => 'تم التسليم';

  @override
  String sessionHandedOffTo(String platform) {
    return 'تم التسليم · $platform';
  }

  @override
  String sessionHandoffErrorBadge(String error) {
    return 'خطأ في التسليم · $error';
  }

  @override
  String sessionCompressionErrorBadge(String error) {
    return 'فشل ضغط السياق مؤقتًا · $error';
  }

  @override
  String sessionEndedWithReason(String reason) {
    return 'انتهت · $reason';
  }

  @override
  String get sessionEnded => 'انتهت';

  @override
  String toolGroupHiddenRestore(int count) {
    return 'تم إخفاء $count أداة؛ اضغط للاستعادة';
  }

  @override
  String backgroundStopFailed(String error) {
    return 'تعذر إيقاف العملية: $error';
  }

  @override
  String get backgroundProcessRemoved => 'انتهت هذه العملية وتمت إزالتها';

  @override
  String get backgroundCloseAndHide => 'إغلاق وإخفاء';

  @override
  String get mcpLogsEmpty => 'لا توجد سجلات';

  @override
  String get subagentTaskProgress => 'تقدم المهمة';

  @override
  String get cloudDiscoverAgain => 'إعادة الاكتشاف';

  @override
  String get cloudPortalLoginPrompt =>
      'سجّل الدخول إلى Portal أدناه. سيتم اكتشاف الوكلاء تلقائيًا بعد الدخول.';

  @override
  String get backgroundTerminal => 'طرفية في الخلفية';

  @override
  String get backgroundWaitingOutput => 'بانتظار الإخراج...';

  @override
  String get backgroundStopping => 'جارٍ الإيقاف...';

  @override
  String get backgroundStopProcess => 'إيقاف العملية';

  @override
  String get markdownAlertTip => 'تلميح';

  @override
  String get markdownAlertImportant => 'مهم';

  @override
  String get markdownAlertWarning => 'تحذير';

  @override
  String get markdownAlertCaution => 'تنبيه';

  @override
  String get markdownAlertNote => 'ملاحظة';

  @override
  String get richLinkMaps => 'الخرائط';

  @override
  String turnActivityTools(int count) {
    return '$count أداة';
  }

  @override
  String turnActivityReasoning(int count) {
    return '$count مقطع تفكير';
  }

  @override
  String toolGroupFailed(int count) {
    return 'فشل $count';
  }

  @override
  String get messageSourceDingtalk => 'DingTalk';

  @override
  String get profileScopeApplyTo => 'تطبيق على';

  @override
  String profileScopeChangesApplyTo(String profile) {
    return 'تنطبق تغييرات هذه الصفحة على ملف $profile.';
  }

  @override
  String get profileScopeConfiguring => 'جارٍ إعداد';

  @override
  String profileScopeCurrent(String name) {
    return '$name (الحالي)';
  }

  @override
  String get mcpLogsAllServers => 'كل الخوادم';

  @override
  String get mcpLogsLoading => 'جارٍ تحميل السجلات...';

  @override
  String badgeUnreadCount(String count) {
    return '$count غير مقروء';
  }

  @override
  String progressPercent(int percent) {
    return 'التقدم $percent%';
  }

  @override
  String avatarNamed(String name) {
    return 'الصورة الرمزية: $name';
  }

  @override
  String get avatarUnnamed => 'الصورة الرمزية';

  @override
  String get thinkingActive => 'جارٍ التفكير';

  @override
  String get thinkingProcess => 'مسار التفكير';

  @override
  String get thinkingBriefly => 'تم التفكير للحظات';

  @override
  String thinkingSeconds(String seconds) {
    return 'تم التفكير لمدة $seconds ث';
  }

  @override
  String thinkingMinutes(int minutes, int seconds) {
    return 'تم التفكير لمدة $minutes د $seconds ث';
  }

  @override
  String thinkingGeneratedCharacters(int count) {
    return 'تم إنشاء $count حرف';
  }

  @override
  String thinkingCharacters(int count) {
    return '$count حرف';
  }

  @override
  String get thinkingAnalyzing => 'جارٍ تحليل السياق...';

  @override
  String get commonNoData => 'لا توجد بيانات';

  @override
  String get commonFeatureDisabled => 'الميزة معطلة';

  @override
  String get cloudDiscoveryFailed => 'فشل اكتشاف Cloud';

  @override
  String cloudDiscoveryInvalidData(String error) {
    return 'أعاد Cloud بيانات غير معروفة: $error';
  }

  @override
  String get cloudDiscoveryUnsupported =>
      'اكتشاف Hermes Cloud غير مدعوم على هذه المنصة';

  @override
  String sessionCreateFailed(String error) {
    return 'تعذر إنشاء الجلسة: $error';
  }

  @override
  String get statusReady => 'جاهز';

  @override
  String get workspaceDescription => 'مربعات الجلسات وأجزاء المكونات الإضافية';

  @override
  String get subagentFallbackName => 'وكيل فرعي';

  @override
  String get subagentNoTask => 'لا يوجد وصف للمهمة';

  @override
  String get subagentsStatusRunning => 'قيد التنفيذ';

  @override
  String get subagentsStatusCompleted => 'مكتمل';

  @override
  String get subagentsStatusFailed => 'فشل';

  @override
  String subagentCardTitle(String name) {
    return 'وكيل فرعي · $name';
  }

  @override
  String get subagentTask => 'المهمة';

  @override
  String get subagentModel => 'النموذج';

  @override
  String get subagentCurrentTool => 'الأداة الحالية';

  @override
  String get subagentSummary => 'ملخص التنفيذ';

  @override
  String sessionApiCallCount(int count) {
    return '$count استدعاء API';
  }

  @override
  String sessionTokenCount(String count) {
    return '$count Token';
  }

  @override
  String get diagnosticsConsentDescription =>
      'سيتم رفع سجلات الخادم المنقحة وإعدادات النظام وProvider. قد تتضمن السجلات محتوى المحادثة ومخرجات الأدوات ومسارات الملفات. لا يتم رفع مفاتيح API، وتُحذف حزمة التشخيص بعد 14 يومًا.';

  @override
  String get diagnosticsApproveUpload => 'الموافقة والرفع';

  @override
  String get diagnosticsGatewayUnavailable => 'غير متصل ببوابة Hermes';

  @override
  String get diagnosticsUploadFailed => 'فشل الرفع';

  @override
  String get diagnosticsSentTitle => 'تم إرسال معلومات التشخيص';

  @override
  String get diagnosticsLinkCopied => 'تم نسخ رابط العرض إلى الحافظة:';

  @override
  String get diagnosticsSupportPrompt => 'لمزيد من المساعدة تواصل معنا عبر:';

  @override
  String diagnosticsSendFailed(String error) {
    return 'تعذر إرسال معلومات التشخيص: $error';
  }

  @override
  String get slashDescRetry => 'إعادة إنشاء الرد السابق';

  @override
  String get slashDescClear => 'مسح عرض الجلسة الحالية';

  @override
  String get slashDescUndo => 'التراجع عن آخر جولة مكتملة';

  @override
  String get slashDescSteer => 'إضافة توجيه إلى الجولة الحالية';

  @override
  String get slashDescStatus => 'عرض حالة الجلسة';

  @override
  String get slashDescTitle => 'إعادة إنشاء عنوان الجلسة';

  @override
  String get slashDescNew => 'بدء جلسة جديدة';

  @override
  String get slashDescYolo => 'تبديل موافقة YOLO التلقائية';

  @override
  String get slashDescHandoff => 'فتح تسليم الجلسة';

  @override
  String get slashDescProfile => 'اختيار ملف أو شخصية';

  @override
  String get slashDescHelp => 'عرض أوامر الشرطة المحلية وأوامر الدليل';

  @override
  String get slashDescBackground => 'إرسال مهمة في الخلفية';

  @override
  String get slashDescCompress => 'ضغط سياق الجلسة الحالية';

  @override
  String get slashDescQueue => 'إضافة الرسالة إلى قائمة الإرسال';

  @override
  String get slashDescUsage => 'عرض استخدام هذه الجلسة';

  @override
  String get slashDescVersion => 'عرض إصداري Hermes والجوال';

  @override
  String get slashDescStop => 'إيقاف الجولة الحالية';

  @override
  String get slashDescTools => 'فتح إعداد الأدوات';

  @override
  String get slashDescApprovals => 'ضبط وضع الموافقة: manual / smart / off';

  @override
  String get slashDescModel => 'فتح منتقي النموذج';

  @override
  String get slashDescWake => 'إدارة كلمة التنبيه: status / on / off / toggle';

  @override
  String get slashDescSkinUnavailable => 'أمر السمة متاح لسطح المكتب فقط';

  @override
  String get slashDescBrowserUnavailable =>
      'أمر المتصفح المدمج متاح لسطح المكتب فقط';

  @override
  String get slashDescJourney => 'فتح رحلة الخريطة النجمية';

  @override
  String get slashDescPet => 'فتح مركز الحيوان الأليف';

  @override
  String get slashDescHatch => 'إنشاء حيوان أليف جديد وتفريخه';

  @override
  String get slashDescSave => 'حفظ سجل الجلسة الحالية';

  @override
  String get slashDescReloadConfigUnavailable =>
      'لا يدعم الجوال أو Gateway الأمر reload-config';

  @override
  String get cronSuggestionPrefix => 'جدولة هذا كمهمة متكررة: ';

  @override
  String get kanbanTaskCompletedNotification => 'اكتملت مهمة كانبان';

  @override
  String get kanbanTaskProblemNotification => 'تحتاج مهمة كانبان إلى الانتباه';

  @override
  String get themeGraphite => 'غرافيت';

  @override
  String get themeIndigo => 'نيلي';

  @override
  String get themeMoss => 'طحلبي';

  @override
  String get themeDune => 'كثيب';

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
  String get mcpAuthBearerToken => 'رمز Bearer';

  @override
  String get gitAgentShipTitle => 'Agent Ship';

  @override
  String get commonUrl => 'URL';

  @override
  String get toolEmptyList => '(قائمة فارغة)';

  @override
  String toolItemCount(int count) {
    return '$count عنصر';
  }

  @override
  String toolFieldCount(int count) {
    return '$count حقل';
  }

  @override
  String get toolPath => 'المسار';

  @override
  String get toolLanguage => 'اللغة';

  @override
  String get toolText => 'النص';

  @override
  String get toolMessage => 'الرسالة';

  @override
  String get toolSummary => 'الملخص';

  @override
  String get toolExecuteCommand => 'تنفيذ أمر';

  @override
  String get toolRunCode => 'تشغيل الرمز';

  @override
  String toolRunCodeLanguage(String language) {
    return 'تشغيل رمز $language';
  }

  @override
  String toolSearchFor(String query) {
    return 'بحث: $query';
  }

  @override
  String get toolExtractWeb => 'استخراج صفحة الويب';

  @override
  String get toolApplyPatch => 'تطبيق تصحيح ملف';

  @override
  String get toolListFiles => 'سرد الملفات';

  @override
  String get toolGenerateImage => 'إنشاء صورة';

  @override
  String get toolDelegateTask => 'مهمة مفوضة';

  @override
  String toolTask(int index) {
    return 'المهمة $index';
  }

  @override
  String toolRunEditingFiles(int count) {
    return 'جارٍ تحرير $count ملف';
  }

  @override
  String toolRunExploringFiles(int count) {
    return 'جارٍ استكشاف $count ملف';
  }

  @override
  String toolRunRunningCommands(int count) {
    return 'جارٍ تشغيل $count أمر';
  }

  @override
  String toolRunDelegatingTasks(int count) {
    return 'جارٍ تفويض $count مهمة';
  }

  @override
  String toolRunUsingTools(int count) {
    return 'جارٍ استخدام $count أداة';
  }

  @override
  String toolRunEditedFiles(int count) {
    return 'تم تحرير $count ملف';
  }

  @override
  String toolRunExploredFiles(int count) {
    return 'تم استكشاف $count ملف';
  }

  @override
  String toolRunRanCommands(int count) {
    return 'تم تشغيل $count أمر';
  }

  @override
  String toolRunDelegatedTasks(int count) {
    return 'تم تفويض $count مهمة';
  }

  @override
  String toolRunUsedTools(int count) {
    return 'تم استخدام $count أداة';
  }

  @override
  String get notificationBackgroundCompleted => 'اكتملت مهمة في الخلفية';

  @override
  String get notificationBackgroundCompletedBody =>
      'اكتملت مهمة في الخلفية. اضغط لعرض النتيجة.';

  @override
  String get notificationApprovalRequired => 'الموافقة مطلوبة';

  @override
  String get notificationApprovalRequiredBody =>
      'يطلب الوكيل الموافقة على عملية حساسة.';

  @override
  String get voiceServerDisconnected => 'غير متصل بالخادم';

  @override
  String get voiceRecordingUnsupported =>
      'تسجيل الميكروفون غير مدعوم على هذه المنصة';

  @override
  String get voiceMicrophoneStartFailed =>
      'تم رفض إذن الميكروفون أو تعذر بدء التسجيل';

  @override
  String voiceRecordingFailed(String error) {
    return 'فشل التسجيل: $error';
  }

  @override
  String get voiceNoSpeech => 'لم أسمع ذلك. حاول مرة أخرى.';

  @override
  String get voiceSttUnavailable =>
      'تحويل الكلام إلى نص (STT) غير معد على الخادم';

  @override
  String voiceTranscriptionFailed(String error) {
    return 'فشل النسخ: $error';
  }

  @override
  String voiceSpeechFailed(String error) {
    return 'فشل تشغيل الصوت: $error';
  }

  @override
  String voiceStreamingSpeechFailed(String error) {
    return 'فشل تشغيل الصوت المتدفق: $error';
  }

  @override
  String get voiceWakeInstallNotice =>
      'جارٍ تفعيل كلمة التنبيه. قد يلزم تثبيت محرك الاكتشاف عند الاستخدام الأول.';

  @override
  String get voiceWakeUsage => 'الاستخدام: /wake [status|on|off|toggle]';

  @override
  String get voiceWakeNotEnabled => 'كلمة التنبيه غير مفعلة';

  @override
  String get voiceWakeOtherSurface => 'كلمة التنبيه معينة لجهاز آخر';

  @override
  String get voiceWakeOwned => 'جهاز آخر يستمع لكلمة التنبيه';

  @override
  String get voiceWakeUnavailable => 'هذا الخلفية لا تدعم كلمة التنبيه';

  @override
  String voiceWakeMicInterrupted(String error) {
    return 'انقطع ميكروفون كلمة التنبيه: $error';
  }

  @override
  String get voiceWakeMicPermission =>
      'تم رفض إذن الميكروفون، لذلك لا يمكن الاستماع لكلمة التنبيه';

  @override
  String voiceWakeMicStartFailed(String error) {
    return 'تعذر بدء ميكروفون كلمة التنبيه: $error';
  }

  @override
  String voiceWakeAudioUploadFailed(String error) {
    return 'تعذر إرسال صوت كلمة التنبيه: $error';
  }

  @override
  String get filesThisComputer => 'هذا الكمبيوتر';

  @override
  String get billingSavedPaymentMethod => 'طريقة دفع محفوظة';

  @override
  String billingPaymentMethodKind(String kind) {
    return 'طريقة الدفع · $kind';
  }

  @override
  String get previewTourBack => 'رجوع';

  @override
  String get previewTourDone => 'تم';

  @override
  String get previewTourNext => 'التالي';

  @override
  String get chatMermaidParseError => 'تعذر تحليل مخطط Mermaid';

  @override
  String get petDefaultName => 'حيوان Hermes الأليف';

  @override
  String get sessionDetailProfile => 'الملف الشخصي';

  @override
  String get profileArchiveType => 'ملف Hermes الشخصي';

  @override
  String get profilesTemperature => 'درجة الحرارة';

  @override
  String get profilesTopP => 'Top P';

  @override
  String get profilesMaxTokens => 'الحد الأقصى للرموز';

  @override
  String get sessionDesktopFallback => 'جلسة سطح المكتب';

  @override
  String get backgroundProcessFallback => 'عملية في الخلفية';

  @override
  String get insightsUnknownModel => 'نموذج غير معروف';

  @override
  String get billingCard => 'بطاقة';

  @override
  String get billingLink => 'Link';

  @override
  String get slashGroupSkills => 'المهارات';

  @override
  String get slashGroupCommands => 'الأوامر';

  @override
  String get botAuthorYou => 'أنت';

  @override
  String get botAuthorSystem => 'النظام';

  @override
  String get botAuthorFallback => 'Bot';

  @override
  String terminalErrorMessage(String error) {
    return 'خطأ في الطرفية: $error';
  }

  @override
  String sessionCopyTitle(String title) {
    return '$title (نسخة)';
  }

  @override
  String get gitRemoteFallback => 'المستودع البعيد';

  @override
  String get gitStashFallback => 'المخزون المؤقت';

  @override
  String get notificationChannelErrors => 'الأخطاء';

  @override
  String get notificationChannelWarnings => 'التحذيرات';

  @override
  String get notificationChannelSuccess => 'النجاح';

  @override
  String get notificationChannelApprovals => 'الموافقات';

  @override
  String get notificationChannelInfo => 'المعلومات';

  @override
  String get memoryCuratorTitle => 'منظّم المحتوى';

  @override
  String get messageSourceServer => 'الخادم';

  @override
  String get messageSourceMobile => 'الهاتف';

  @override
  String get kanbanRunQueued => 'في قائمة الانتظار';

  @override
  String get kanbanRunCompleted => 'مكتمل';

  @override
  String get kanbanRunFailed => 'فشل';

  @override
  String get kanbanRunCancelled => 'ملغى';

  @override
  String get kanbanEventTaskCreated => 'أُنشئت المهمة';

  @override
  String get kanbanEventTaskUpdated => 'حُدّثت المهمة';

  @override
  String get kanbanEventTaskDeleted => 'حُذفت المهمة';

  @override
  String get kanbanEventRunStarted => 'بدأ التشغيل';

  @override
  String get kanbanEventRunCompleted => 'اكتمل التشغيل';

  @override
  String get kanbanEventRunFailed => 'فشل التشغيل';

  @override
  String get kanbanEventRunCancelled => 'أُلغي التشغيل';

  @override
  String get kanbanEventCommentCreated => 'أُضيف تعليق';

  @override
  String get kanbanEventAttachmentAdded => 'أُضيف مرفق';

  @override
  String get kanbanEventAttachmentDeleted => 'حُذف المرفق';

  @override
  String get cloudRoleOwner => 'المالك';

  @override
  String get cloudRoleAdmin => 'المسؤول';

  @override
  String get cloudRoleMember => 'عضو';

  @override
  String get cloudRoleViewer => 'مشاهد';

  @override
  String get chatStatusToolDrafting => 'جارٍ تحضير استدعاء الأداة';

  @override
  String get chatStatusProvider => 'حالة المزوّد';

  @override
  String get previewScriptError => 'خطأ في البرنامج النصي';

  @override
  String get previewUnhandledPromiseRejection => 'رفض Promise غير معالج: ';

  @override
  String botGroupSessionTitle(String roomId) {
    return 'المجموعة: $roomId';
  }

  @override
  String get errorExpectedObjectResponse =>
      'أعاد الخادم استجابة كائن غير صالحة';

  @override
  String get errorTtsNoAudio => 'لم تُعد ميزة تحويل النص إلى كلام أي صوت';

  @override
  String get errorInvalidDataUrl => 'أعاد الخادم عنوان بيانات غير صالح';

  @override
  String get errorExportDirectoryMissing => 'لم يحدد الخادم مجلد التصدير';

  @override
  String get errorImportDirectoryMissing => 'لم يحدد الخادم مجلد الاستيراد';

  @override
  String get errorRawConfigInvalid => 'أعاد الخادم إعدادًا خامًا غير صالح';

  @override
  String get errorPluginToggleRejected => 'رفضت الواجهة الخلفية تغيير الملحق';

  @override
  String get errorConnectionNotConfigured => 'الاتصال غير مهيأ';

  @override
  String errorSessionOwnerUnknown(String sessionId) {
    return 'مالك الجلسة غير معروف: $sessionId';
  }

  @override
  String get errorRemotePushUnavailable => 'الدفع البعيد غير متاح لهذا الاتصال';

  @override
  String get sshCommandTimedOut => 'انتهت مهلة أمر SSH';

  @override
  String get sshRemoteHomeUnsafe => 'مجلد Hermes البعيد غير آمن';

  @override
  String get sshOwnershipVerificationFailed =>
      'تعذر التحقق من ملكية عملية Hermes البعيدة';

  @override
  String sshOwnershipProbeFailed(String status) {
    return 'فشل فحص الملكية البعيد ($status)';
  }

  @override
  String get sshHelperInvalidJson => 'أعادت الأداة البعيدة JSON غير صالح';

  @override
  String get sshWindowsOwnershipVerificationFailed =>
      'تعذر التحقق من ملكية عملية Windows البعيدة';

  @override
  String get sshRemotePathInvalid =>
      'يجب أن يكون مسار Hermes البعيد مطلقًا أو يبدأ بـ ~/';

  @override
  String get sshExecutableNotFound =>
      'لم يُعثر على ملف Hermes التنفيذي المهيأ على المضيف البعيد';

  @override
  String get sshHermesNotInstalled => 'Hermes غير مثبت على المضيف البعيد';

  @override
  String get sshBootstrapFlagsUnsupported =>
      'يجب أن يدعم Hermes البعيد خيارات تمهيد ملكية SSH الآمنة';

  @override
  String get sshWindowsIdentityInvalid =>
      'أعادت واجهة Windows الخلفية البعيدة هوية غير صالحة';

  @override
  String get sshWindowsExitedBeforeReady =>
      'خرجت واجهة Windows الخلفية البعيدة قبل أن تصبح جاهزة';

  @override
  String get sshWindowsOwnershipProofFailed => 'فشل إثبات ملكية Windows البعيد';

  @override
  String get sshProcessIdMissing => 'لم يُعد Hermes البعيد معرّف عملية';

  @override
  String get sshExitedBeforeReady => 'خرج Hermes البعيد قبل أن يصبح جاهزًا';

  @override
  String get sshOwnershipProofFailed => 'فشل إثبات ملكية Hermes البعيد';

  @override
  String get errorSessionBranchIdMissing =>
      'لم يُعد Hermes معرّفًا دائمًا للجلسة المتفرعة';

  @override
  String get errorDuplicateImportFailed =>
      'لم يتمكن Hermes من استيراد الجلسة المنسوخة';

  @override
  String get errorSessionNoTitleableMessages =>
      'لا تحتوي الجلسة على رسائل تصلح لإنشاء عنوان';

  @override
  String get errorTitleGeneratorEmpty => 'أعاد مولّد العنوان عنوانًا فارغًا';

  @override
  String get errorProjectIdRequired => 'يلزم اختيار مشروع';

  @override
  String get errorProjectWorkingFolderMissing =>
      'لا يحتوي المشروع الهدف على مجلد عمل';

  @override
  String get errorDownloadFailed => 'فشل التنزيل';

  @override
  String get errorMessagingPlatformNotFound => 'لم يُعثر على منصة المراسلة';

  @override
  String errorBotGroupSessionStartFailed(String name) {
    return 'تعذر بدء جلسة المجموعة الخاصة بـ $name';
  }

  @override
  String sshRemoteCommandFailed(String code) {
    return 'فشل الأمر البعيد ($code)';
  }

  @override
  String get sshHostAndUserRequired => 'يلزم مضيف SSH ومستخدمه';

  @override
  String get sshPortInvalid => 'يجب أن يكون منفذ SSH بين 1 و65535';

  @override
  String sshHostKeyChanged(String host, String expected, String received) {
    return 'تغير مفتاح مضيف SSH لـ $host. المتوقع $expected؛ والمستلم $received';
  }

  @override
  String get sshProfileInvalid => 'اسم الملف الشخصي البعيد غير صالح';

  @override
  String get errorDirectGatewayFeatureUnavailable =>
      'تتطلب هذه الميزة Hermes Mobile Server ولا تتوفر عبر اتصال Gateway مباشر';

  @override
  String errorOperationFailedWithDetail(String error) {
    return 'فشلت العملية: $error';
  }

  @override
  String gatewayOauthRejected(String error) {
    return 'رفض Gateway تسجيل الدخول: $error';
  }

  @override
  String get gatewayOauthCodeMissing => 'تفتقد استجابة Gateway إلى رمز التفويض';

  @override
  String get gatewayOauthStateMismatch =>
      'لم تتطابق حالة استجابة Gateway. أُلغي تسجيل الدخول للحماية.';

  @override
  String get gatewayOauthRefreshTokenMissing =>
      'انتهت جلسة Gateway ولا يوجد رمز تحديث';

  @override
  String get gatewayOauthTicketMissing => 'لم يُعد Gateway تذكرة WebSocket';

  @override
  String get gatewayOauthAccessTokenMissing =>
      'لا تتضمن استجابة رمز Gateway رمز وصول';

  @override
  String get gatewayOauthTimedOut => 'انتهت مهلة تسجيل الدخول إلى Gateway';

  @override
  String get gatewayOauthNativeUnsupported =>
      'مصادقة Gateway OAuth الأصلية غير مدعومة على هذه المنصة';

  @override
  String get updateManifestInvalid => 'بيان التحديث غير صالح';

  @override
  String sshRemotePlatformUnsupported(String error) {
    return 'المنصة البعيدة غير مدعومة: $error';
  }

  @override
  String get sshWebUnsupported => 'اتصالات SSH الأصلية غير مدعومة على الويب';

  @override
  String get filesDownloadPlatformUnsupported =>
      'تنزيل الملفات محليًا غير متاح على هذه المنصة';

  @override
  String get sessionExportPlatformUnsupported =>
      'تصدير الملفات محليًا غير متاح على هذه المنصة';

  @override
  String get errorPluginCanonicalKeyRequired =>
      'يحتاج هذا الملحق إلى مفتاح قياسي قبل تغييره';

  @override
  String get connectGatewayToken => 'رمز Gateway';

  @override
  String get modelMoaTitle => 'مزيج الوكلاء';

  @override
  String get insightsTokens => 'الرموز';

  @override
  String get messageWebFallback => 'الويب';

  @override
  String get mcpLogsSourceStdio => 'stdio';

  @override
  String get mcpLogsSourceAgent => 'الوكيل';

  @override
  String get projectPrimaryFolder => 'الرئيسي';

  @override
  String get botGroupNameRequired => 'أدخل اسم المجموعة';

  @override
  String get botGroupMembersMinimum => 'تحتاج المجموعة إلى روبوتين على الأقل';

  @override
  String botGroupMembersRange(int max) {
    return 'تحتاج المجموعة من روبوتين إلى $max';
  }

  @override
  String botGroupMembersMaximum(int max) {
    return 'تدعم المجموعة $max روبوتات كحد أقصى';
  }

  @override
  String get botGroupMemberUnavailable => 'لا يوجد عضو مجموعة متاح';

  @override
  String get botProfileNameUnavailable => 'لا يتوفر اسم ملف شخصي شاغر';

  @override
  String get botDefaultProfileDeleteForbidden =>
      'لا يمكن حذف الملف الشخصي الافتراضي';

  @override
  String get botConnectionUnavailable => 'اتصال Bot غير متاح';

  @override
  String get botTurnFailed => 'فشلت جولة Bot';

  @override
  String get mcpInvalidJsonSyntax => 'بنية JSON غير صالحة';

  @override
  String get mcpJsonObjectRequired => 'يجب أن تكون قيمة JSON العليا كائنًا';

  @override
  String get voiceWakeMicStreamEnded =>
      'انتهى تدفق ميكروفون كلمة التنبيه بشكل غير متوقع';

  @override
  String httpStatusError(int statusCode) {
    return 'أعاد الخادم HTTP $statusCode';
  }
}
