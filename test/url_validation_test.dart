import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/url_validation.dart';

void main() {
  test('accepts public http and https URLs', () {
    expect(validateComposerUrl('https://example.com/a?q=1'), isNotNull);
    expect(validateComposerUrl('http://docs.example.org'), isNotNull);
  });

  test('rejects unsafe schemes, credentials and private hosts', () {
    expect(validateComposerUrl('file:///etc/passwd'), isNull);
    expect(validateComposerUrl('javascript:alert(1)'), isNull);
    expect(validateComposerUrl('https://user:pass@example.com'), isNull);
    expect(validateComposerUrl('http://localhost:8080'), isNull);
    expect(validateComposerUrl('http://192.168.1.4/a'), isNull);
    expect(validateComposerUrl('http://172.20.0.2/a'), isNull);
  });

  test('rejects oversized values', () {
    expect(validateComposerUrl('https://example.com/${'x' * 8200}'), isNull);
  });
}
