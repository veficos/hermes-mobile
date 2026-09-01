import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/billing_screen.dart';
import 'package:provider/provider.dart';

class _BillingApi extends ApiClient {
  _BillingApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  double? charged;
  String? idempotencyKey;
  String? changedTier;

  @override
  Future<BillingState> billingState() async => BillingState.fromJson({
    'ok': true,
    'logged_in': true,
    'is_admin': true,
    'can_charge': true,
    'cli_billing_enabled': true,
    'balance_usd': '42.50',
    'balance_display': r'$42.50',
    'portal_url': 'https://portal.example/billing',
    'card': {'brand': 'visa', 'last4': '3206'},
    'charge_presets': ['25', '50'],
    'charge_presets_display': [r'$25', r'$50'],
    'min_usd': '10',
    'max_usd': '500',
    'monthly_cap': {
      'limit_usd': '100',
      'limit_display': r'$100',
      'spent_this_month_usd': '12',
      'spent_display': r'$12',
    },
    'auto_reload': {
      'enabled': true,
      'threshold_usd': '5',
      'threshold_display': r'$5',
      'reload_to_usd': '25',
      'reload_to_display': r'$25',
      'card': {'kind': 'canonical'},
    },
    'usage': _usage,
  });

  @override
  Future<SubscriptionState> subscriptionState() async =>
      SubscriptionState.fromJson({
        'ok': true,
        'logged_in': true,
        'is_admin': true,
        'can_change_plan': true,
        'context': 'personal',
        'org_id': 'org-1',
        'org_name': 'Acme',
        'portal_url': 'https://portal.example/billing',
        'current': {
          'tier_id': 'plus-id',
          'tier_name': 'Plus',
          'monthly_credits': '22',
          'credits_remaining': '18',
          'cycle_ends_at': '2026-09-30T00:00:00Z',
          'cancel_at_period_end': false,
        },
        'tiers': [
          {
            'tier_id': 'free-id',
            'name': 'Free',
            'tier_order': 0,
            'dollars_per_month_display': r'$0',
            'monthly_credits': '0.1',
            'is_current': false,
            'is_enabled': true,
          },
          {
            'tier_id': 'plus-id',
            'name': 'Plus',
            'tier_order': 1,
            'dollars_per_month_display': r'$20',
            'monthly_credits': '22',
            'is_current': true,
            'is_enabled': true,
          },
          {
            'tier_id': 'super-id',
            'name': 'Super',
            'tier_order': 2,
            'dollars_per_month_display': r'$100',
            'monthly_credits': '110',
            'is_current': false,
            'is_enabled': true,
          },
        ],
        'usage': _usage,
      });

  @override
  Future<UsageBars> usageBars() async => UsageBars.fromJson(_usage);

  @override
  Future<Map<String, dynamic>> billingCharge(
    double amount, {
    String? idempotencyKey,
  }) async {
    charged = amount;
    this.idempotencyKey = idempotencyKey;
    return {'ok': true};
  }

  @override
  Future<Map<String, dynamic>> subscriptionPreview(
    Map<String, dynamic> body,
  ) async => {
    'ok': true,
    'effect': 'scheduled',
    'target_tier_name': 'Free',
    'effective_at': '2026-09-30T00:00:00Z',
  };

  @override
  Future<Map<String, dynamic>> subscriptionChange(
    Map<String, dynamic> body,
  ) async {
    changedTier = body['target_plan']?.toString();
    return {'ok': true};
  }

  static const _usage = <String, dynamic>{
    'available': true,
    'status': 'active',
    'plan_name': 'Plus',
    'renews_display': 'Sep 30',
    'total_spendable_display': r'$117',
    'plan_bar': {
      'kind': 'plan',
      'remaining_display': r'$40',
      'spent_display': r'$60',
      'total_display': r'$100',
      'pct_used': 60,
      'fill_fraction': 0.6,
    },
    'topup_bar': {
      'kind': 'topup',
      'remaining_display': r'$77',
      'spent_display': r'$23',
      'total_display': r'$100',
      'pct_used': 23,
      'fill_fraction': 0.23,
    },
  };
}

Future<(_BillingApi, ConnectionStore)> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('zh'),
}) async {
  final api = _BillingApi();
  final connection = ConnectionStore()..api = api;
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: connection,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BillingScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (api, connection);
}

void main() {
  testWidgets('English billing flow does not leak Chinese UI strings', (
    tester,
  ) async {
    final (_, connection) = await _pump(tester, locale: const Locale('en'));
    addTearDown(connection.dispose);

    expect(find.text('Billing'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    _expectNoHanText(tester);

    await tester.tap(find.text('Usage'));
    await tester.pumpAndSettle();
    expect(find.text('Plan credits'), findsOneWidget);
    _expectNoHanText(tester);

    await tester.tap(find.text('Plans'));
    await tester.pumpAndSettle();
    expect(find.text('Downgrade'), findsOneWidget);
    _expectNoHanText(tester);
  });

  testWidgets('renders gateway card, usage and dynamic tier catalog only', (
    tester,
  ) async {
    final (_, connection) = await _pump(tester);
    addTearDown(connection.dispose);

    expect(find.text('Plus'), findsOneWidget);
    expect(find.text(r'$42.50'), findsOneWidget);
    expect(find.text('visa •••• 3206'), findsOneWidget);
    expect(find.text('Visa •• 4242'), findsNothing);
    expect(find.text('发票'), findsNothing);

    await tester.tap(find.text('用量'));
    await tester.pumpAndSettle();
    expect(find.text('套餐额度'), findsOneWidget);
    expect(find.text(r'剩余 $40'), findsOneWidget);
    expect(find.text('充值额度'), findsOneWidget);
    expect(find.text('累计 Tokens'), findsNothing);

    await tester.tap(find.text('套餐'));
    await tester.pumpAndSettle();
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Plus'), findsWidgets);
    expect(find.text('Super'), findsOneWidget);
  });

  testWidgets('charge uses server preset and an idempotency key', (
    tester,
  ) async {
    final (api, connection) = await _pump(tester);
    addTearDown(connection.dispose);

    await tester.tap(find.text('购买额度'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(r'$50'));
    await tester.pump();
    await tester.tap(find.text('确认购买'));
    await tester.pumpAndSettle();

    expect(api.charged, 50);
    expect(api.idempotencyKey, startsWith('mobile-'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('downgrade previews then schedules the selected server tier', (
    tester,
  ) async {
    final (api, connection) = await _pump(tester);
    addTearDown(connection.dispose);

    await tester.tap(find.text('套餐'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '降级'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();

    expect(api.changedTier, 'free-id');
  });
}

void _expectNoHanText(WidgetTester tester) {
  final han = RegExp(r'[\u3400-\u9fff]');
  final leaked = find
      .byType(Text)
      .evaluate()
      .map((element) => element.widget as Text)
      .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
      .where(han.hasMatch)
      .toList();
  expect(leaked, isEmpty);
}
