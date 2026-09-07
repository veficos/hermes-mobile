import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/incoming_share.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('incoming share payload normalizes text and files', () {
    final payload = IncomingSharePayload.fromMap({
      'text': 'https://example.com',
      'files': ['/tmp/a.png', '', '/tmp/b.txt'],
    });
    expect(payload.text, 'https://example.com');
    expect(payload.files, ['/tmp/a.png', '/tmp/b.txt']);
    expect(payload.isEmpty, isFalse);
  });
}
