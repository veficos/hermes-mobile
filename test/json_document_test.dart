import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/json_document.dart';

void main() {
  test('formats and reads nested JSON without changing the source', () {
    final document = JsonDocument.parse('{"a":[1,{"b":true}]}');
    expect(document.at(['a', 1, 'b']), isTrue);
    expect(document.formatted(), '{\n  "a": [\n    1,\n    {\n      "b": true\n    }\n  ]\n}');
  });

  test('immutable set and remove support object and array paths', () {
    final original = JsonDocument.parse('{"a":[1,2],"keep":true}');
    final changed = original.set(['a', 1], {'nested': 'yes'});
    final removed = changed.remove(['keep']);

    expect(original.at(['a', 1]), 2);
    expect(changed.at(['a', 1, 'nested']), 'yes');
    expect(removed.formatted(), contains('nested'));
    expect(() => removed.at(['keep']), throwsRangeError);
  });

  test('rejects malformed documents and non-JSON replacement values', () {
    expect(() => JsonDocument.parse('{oops'), throwsFormatException);
    expect(
      () => JsonDocument.parse('{}').set(['bad'], DateTime(2020)),
      throwsA(isA<JsonUnsupportedObjectError>()),
    );
  });
}
