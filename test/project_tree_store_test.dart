import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/project_tree_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ProjectApi extends ApiClient {
  _ProjectApi(this.label)
    : super(baseUrl: 'http://project.invalid', apiKey: 'test');

  final String label;
  final gate = Completer<void>();

  @override
  Future<ProjectTreePayload> projectTree({int previewLimit = 3}) async {
    await gate.future;
    return ProjectTreePayload(
      projects: [ProjectTreeNode(id: label, label: label)],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('old backend project response cannot overwrite new binding', () async {
    final oldApi = _ProjectApi('old');
    final newApi = _ProjectApi('new');
    ApiClient? active = oldApi;
    final store = ProjectTreeStore(() => active);
    addTearDown(store.dispose);

    final oldRefresh = store.refresh();
    active = newApi;
    final newRefresh = store.refresh();
    newApi.gate.complete();
    await newRefresh;
    expect(store.projects.single.label, 'new');

    oldApi.gate.complete();
    await oldRefresh;
    expect(store.projects.single.label, 'new');
  });
}
