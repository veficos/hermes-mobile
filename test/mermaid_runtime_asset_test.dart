import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled Mermaid host is offline, strict, and bridge-driven', () async {
    final host = await rootBundle.loadString(
      'assets/vendor/mermaid/mermaid_host.html',
    );
    final runtime = await rootBundle.loadString(
      'assets/vendor/mermaid/mermaid.min.js',
    );

    expect(host, contains('Content-Security-Policy'));
    expect(host, contains("default-src 'none'"));
    expect(host, contains("securityLevel: 'strict'"));
    expect(host, contains('window.renderMermaid'));
    expect(host, contains('MermaidBridge.postMessage'));
    expect(host, contains('mermaid.min.js'));
    expect(runtime, contains('globalThis["mermaid"]'));
    expect(runtime.length, greaterThan(3000000));
  });
}
