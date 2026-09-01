import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/terminal_store.dart';

void main() {
  test('SSH target emits only configured non-secret transport fields', () {
    const target = SshTerminalTarget(
      host: 'build-box',
      user: 'runner',
      port: 2222,
      identityFile: '/srv/hermes/.ssh/id_ed25519',
      cwd: '/work/repo',
    );
    expect(target.toJson(), {
      'host': 'build-box',
      'user': 'runner',
      'port': 2222,
      'identity_file': '/srv/hermes/.ssh/id_ed25519',
      'cwd': '/work/repo',
    });
    expect(target.toJson().containsKey('password'), isFalse);
  });
}
