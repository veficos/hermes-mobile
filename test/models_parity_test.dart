import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/models.dart';

void main() {
  test(
    'CronJob parses the structured schedule returned by Hermes desktop API',
    () {
      final job = CronJob.fromJson({
        'id': 'cron-1',
        'enabled': true,
        'schedule': {
          'kind': 'cron',
          'expr': '0 9 * * *',
          'display': 'Every day at 09:00',
        },
        'schedule_display': '每天 09:00',
        'deliver': 'telegram',
        'next_run_at': '2026-08-16T01:00:00Z',
        'last_error': 'previous failure',
      });

      expect(job.schedule, '0 9 * * *');
      expect(job.scheduleDisplay, '每天 09:00');
      expect(job.deliver, 'telegram');
      expect(job.nextRunAt, '2026-08-16T01:00:00Z');
      expect(job.lastError, 'previous failure');
    },
  );

  test('Webhook uses the canonical subscription name as its stable id', () {
    final webhook = Webhook.fromJson({
      'name': 'build-done',
      'url': 'http://localhost/webhooks/build-done',
      'enabled': true,
    });

    expect(webhook.id, 'build-done');
    expect(webhook.name, 'build-done');
  });

  test(
    'CronBlueprint preserves typed fields and uses desktop delivery default',
    () {
      final blueprint = CronBlueprint.fromJson({
        'key': 'morning-brief',
        'title': 'Morning briefing',
        'description': 'Daily briefing',
        'category': 'daily',
        'tags': ['daily', 'briefing'],
        'schedule': '{minute} {hour} * * *',
        'scheduleHuman': 'Every day at the chosen time',
        'fields': [
          {
            'name': 'time',
            'type': 'time',
            'label': 'What time?',
            'default': '08:00',
            'options': [],
            'optional': false,
            'strict': true,
            'help': '24h local time',
          },
          {
            'name': 'deliver',
            'type': 'enum',
            'label': 'Where to deliver?',
            'default': 'origin',
            'options': ['origin', 'local', 'telegram'],
            'optional': false,
            'strict': false,
          },
        ],
      });

      expect(blueprint.key, 'morning-brief');
      expect(blueprint.tags, ['daily', 'briefing']);
      expect(blueprint.fields.first.type, 'time');
      expect(blueprint.fields.last.strict, isFalse);
      expect(blueprint.initialValues(), {'time': '08:00', 'deliver': 'local'});
    },
  );

  test('SessionRow coerces numeric counts and active aliases safely', () {
    final row = SessionRow.fromJson({
      'id': 's1',
      'title': 42,
      'message_count': '7',
      'is_active': 1,
      'active': true,
      'isActive': true,
      'is_streaming': 'yes',
    });

    expect(row.title, '42');
    expect(row.messageCount, 7);
    expect(row.isActive, isTrue);
    expect(row.isStreaming, isFalse);
  });

  test('SessionMessage coerces row_id and timestamp from strings', () {
    final message = SessionMessage.fromJson({
      'role': 'assistant',
      'row_id': '123',
      'timestamp': '1692921600',
      'text': 42,
    });

    expect(message.rowId, 123);
    expect(message.timestamp, 1692921600);
    expect(message.text, '42');
  });

  test('SessionInfo stringifies model and workspace fields', () {
    final info = SessionInfo.fromJson({
      'model': {'name': 'gpt-4'},
      'tools_config': 99,
    });

    expect(info.model, '{name: gpt-4}');
    expect(info.toolsConfig, '99');
  });

  test('PetInfo parses the flat camelCase Gateway sprite contract', () {
    final pet = PetInfo.fromJson({
      'enabled': true,
      'slug': 'moxie',
      'displayName': 'Moxie',
      'spritesheetBase64': 'cG5n',
      'frameW': 32,
      'frameH': '48',
      'framesByState': {'idle': 4, 'working': '6'},
      'loopMs': 1200,
      'scale': 1.5,
    });

    expect(pet.displayName, 'Moxie');
    expect(pet.spritesheetBase64, 'cG5n');
    expect(pet.frameW, 32);
    expect(pet.frameH, 48);
    expect(pet.framesByState, {'idle': 4, 'working': 6});
    expect(pet.loopMs, 1200);
  });

  test('BillingState parses money-safe Gateway billing state', () {
    final billing = BillingState.fromJson({
      'balance_usd': '42.50',
      'monthly_cap': {'limit_usd': '125.00'},
      'auto_reload': {
        'enabled': true,
        'threshold_usd': '10.00',
        'reload_to_usd': '50.00',
      },
    });

    expect(billing.balance, 42.5);
    expect(billing.creditLimit, 125);
    expect(billing.autoReload, isTrue);
    expect(billing.autoReloadThreshold, 10);
    expect(billing.autoReloadAmount, 50);
  });

  test('SubscriptionState parses the nested Gateway current plan', () {
    final subscription = SubscriptionState.fromJson({
      'current': {
        'tier_id': 'pro',
        'tier_name': 'Pro',
        'cycle_ends_at': '2026-09-30T00:00:00Z',
        'cancel_at_period_end': true,
      },
    });

    expect(subscription.typeId, 'pro');
    expect(subscription.name, 'Pro');
    expect(subscription.currentPeriodEnd, DateTime.utc(2026, 9, 30));
    expect(subscription.canceledAtPeriodEnd, isTrue);
    expect(subscription.status, 'canceling');
  });
}
