import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';

void main() {
  test('partial session.info merges without erasing authoritative fields', () {
    final current = SessionInfoView(
      title: '保留标题',
      model: 'model-a',
      provider: 'provider-a',
      cwd: '/workspace',
      running: true,
    );
    final merged = current.mergeJson(const {'branch': 'main'});
    expect(merged.title, '保留标题');
    expect(merged.model, 'model-a');
    expect(merged.provider, 'provider-a');
    expect(merged.cwd, '/workspace');
    expect(merged.branch, 'main');
    expect(merged.running, isTrue);
  });

  test('stale running true is rejected after a terminal edge', () {
    final current = SessionInfoView(title: 'A', running: false);
    final merged = current.mergeJson(const {
      'running': true,
      'provider': 'nous',
    }, allowRunningTrue: false);
    expect(merged.running, isFalse);
    expect(merged.provider, 'nous');
  });

  test('authoritative running false is accepted', () {
    final current = SessionInfoView(running: true);
    expect(current.mergeJson(const {'running': false}).running, isFalse);
  });
}
