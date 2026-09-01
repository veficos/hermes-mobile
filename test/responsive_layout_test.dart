import 'package:hermes_mobile/theme/hermes_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('600-959 is medium and chat keeps its context rail collapsible', () {
    expect(hermesWindowClass(599), HermesWindowClass.compact);
    for (final width in [600.0, 800.0, 840.0, 900.0, 959.0]) {
      expect(hermesWindowClass(width), HermesWindowClass.medium);
      expect(hermesCanUseThreePaneChat(width), isFalse);
    }
    expect(hermesWindowClass(960), HermesWindowClass.expanded);
    expect(hermesCanUseThreePaneChat(960), isFalse);
    expect(hermesCanUseThreePaneChat(982), isTrue);
  });
}
