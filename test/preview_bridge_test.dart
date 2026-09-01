import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/preview_bridge.dart';

void main() {
  group('preview bridge document', () {
    test(
      'injects local intent, sizing, and console contracts before body end',
      () {
        final framed = withPreviewBridge(
          '<html><body><button>Go</button></body></html>',
          'token-123',
          scriptErrorLabel: 'Script error',
          unhandledPromiseRejectionLabel: 'Unhandled promise rejection: ',
        );

        expect(framed, contains('window.hermes'));
        expect(framed, contains('data-hermes-send'));
        expect(framed, contains('ResizeObserver'));
        expect(framed, contains('hermes-inline-preview-console'));
        expect(framed.indexOf('<script>'), lessThan(framed.indexOf('</body>')));
        expect(framed, contains(jsonEncode('token-123')));
      },
    );

    test('token is JSON encoded rather than interpolated as JavaScript', () {
      final framed = withPreviewBridge(
        '<p>x</p>',
        'x";alert(1);//',
        scriptErrorLabel: '脚本错误',
        unhandledPromiseRejectionLabel: '未处理：',
      );
      expect(framed, contains(jsonEncode('x";alert(1);//')));
      expect(framed, contains(jsonEncode('脚本错误')));
      expect(framed, isNot(contains('var token=x";alert')));
    });
  });

  group('preview bridge messages', () {
    test('validates token and clamps reported height', () {
      final event = parsePreviewBridgeMessage(
        jsonEncode({
          'type': 'hermes-inline-preview-size',
          'token': 'ours',
          'height': 9000,
          'width': 321.4,
        }),
        'ours',
      );
      expect(event?.kind, PreviewBridgeEventKind.size);
      expect(event?.height, kPreviewMaxHeight);
      expect(event?.width, 321);
      expect(
        parsePreviewBridgeMessage(
          '{"type":"hermes-inline-preview-size","token":"other","height":200}',
          'ours',
        ),
        isNull,
      );
    });

    test('trims and caps hidden intents', () {
      final event = parsePreviewBridgeMessage(
        jsonEncode({
          'type': 'hermes-inline-preview-intent',
          'token': 'ours',
          'prompt': '  ${List.filled(600, 'x').join()}  ',
        }),
        'ours',
      );
      expect(event?.kind, PreviewBridgeEventKind.intent);
      expect(event?.prompt, hasLength(kPreviewMaxIntentLength));
      expect(
        parsePreviewBridgeMessage(
          '{"type":"hermes-inline-preview-intent","token":"ours","prompt":"  "}',
          'ours',
        ),
        isNull,
      );
    });

    test('sanitizes console levels and rejects malformed messages', () {
      final event = parsePreviewBridgeMessage(
        jsonEncode({
          'type': 'hermes-inline-preview-console',
          'token': 'ours',
          'level': 'fatal',
          'message': 'boom',
        }),
        'ours',
      );
      expect(event?.level, 'log');
      expect(event?.message, 'boom');
      expect(parsePreviewBridgeMessage('not json', 'ours'), isNull);
    });
  });

  test('directive heights accept integers and clamp to the supported band', () {
    expect(parsePreviewHeight(null), isNull);
    expect(parsePreviewHeight('12.5'), isNull);
    expect(parsePreviewHeight('20'), kPreviewMinHeight);
    expect(parsePreviewHeight('480'), 480);
    expect(parsePreviewHeight('9999'), kPreviewMaxHeight);
  });

  test(
    'tour script JSON-encodes payload and exposes the complete action set',
    () {
      final script = previewTourScript(
        {'action': 'show', 'selector': '#x";alert(1)', 'title': 'Title'},
        backLabel: 'Zurück',
        doneLabel: 'Fertig',
        nextLabel: 'Weiter',
      );
      expect(script, contains(jsonEncode('#x";alert(1)')));
      expect(script, contains('kind==="targets"'));
      expect(script, contains('kind==="start"'));
      expect(script, contains('kind==="next"||kind==="prev"'));
      expect(script, contains('kind==="stop"'));
      expect(script, contains('__hermes-mobile-tour'));
      expect(script, contains(jsonEncode('Zurück')));
    },
  );
}
