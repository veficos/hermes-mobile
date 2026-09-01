import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/profile_scope_store.dart';
import 'package:hermes_mobile/screens/skills_screen.dart';
import 'package:provider/provider.dart';

/// Regression coverage: `_toggle` used to reconstruct a bare `SkillInfo(...)`
/// on every toggle, silently dropping `provenance`/`usage` (fields added
/// alongside the skills-marketplace work) instead of preserving them via
/// `SkillInfo.copyWith`. A hub-installed skill's "市场" provenance badge and
/// its usage count must both survive a toggle.
class _SkillsContractApi extends ApiClient {
  _SkillsContractApi()
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  bool enabled = false;

  @override
  Future<ProfilesPayload> listProfiles() async => const ProfilesPayload(
    profiles: [ProfileInfo(name: 'default', isActive: true)],
    active: 'default',
  );

  @override
  Future<List<SkillInfo>> skills({String? profile}) async => [
    SkillInfo(
      name: 'web-research',
      description: 'Search the web',
      enabled: enabled,
      category: 'research',
      provenance: 'hub',
      usage: 12,
    ),
  ];

  @override
  Future<void> toggleSkill(String name, bool value, {String? profile}) async {
    enabled = value;
  }
}

void main() {
  testWidgets(
    'toggling a skill preserves its provenance badge and usage count',
    (tester) async {
      final connection = ConnectionStore()..api = _SkillsContractApi();
      final scope = ProfileScopeStore()..bindApi(connection.api);
      addTearDown(connection.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ConnectionStore>.value(value: connection),
            ChangeNotifierProvider<ProfileScopeStore>.value(value: scope),
          ],
          child: const MaterialApp(home: SkillsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('web-research'), findsOneWidget);
      expect(find.text('市场'), findsOneWidget);
      expect(find.textContaining('使用 12 次'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(
        find.text('市场'),
        findsOneWidget,
        reason: 'toggling must not drop the provenance badge',
      );
      expect(
        find.textContaining('使用 12 次'),
        findsOneWidget,
        reason: 'toggling must not drop the usage count',
      );
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    },
  );
}
