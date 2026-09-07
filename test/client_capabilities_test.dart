import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/client_capabilities.dart';

void main() {
  test(
    'mobile session manifest is versioned and matches implemented bridges',
    () {
      final fields = hermesMobileSessionClientFields();
      expect(fields['source'], 'mobile');
      final capabilities =
          fields['client_capabilities'] as Map<String, dynamic>;
      expect(capabilities['version'], hermesMobileCapabilityVersion);
      expect(
        capabilities['surfaces'],
        containsAll(<String>[
          'terminal.read',
          'terminal.close',
          'preview.act',
          'preview.annotate',
          'pane.reveal',
          'layout.apply',
          'mcp.setup',
          'tour.preview',
          'tour.app',
        ]),
      );
    },
  );
}
