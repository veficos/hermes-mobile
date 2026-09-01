import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_en.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_zh.dart';
import 'package:hermes_mobile/l10n/runtime_l10n.dart';

void main() {
  setUp(() => RuntimeL10n.use(AppLocalizationsEn()));

  test('billing payment method fallbacks use the active locale', () {
    RuntimeL10n.use(AppLocalizationsZh());
    const card = BillingPaymentMethod(kind: 'card', last4: '4242');
    const link = BillingPaymentMethod(kind: 'link');

    expect(card.display, '银行卡 •••• 4242');
    expect(link.display, AppLocalizationsZh().billingLink);
  });
}
