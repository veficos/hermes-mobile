import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/model_catalog.dart';

void main() {
  test('model catalog retains free and discounted pricing metadata', () {
    final catalog = ModelCatalog.fromJson({
      'current': {'provider': 'nous', 'model': 'free-model'},
      'providers': [
        {
          'slug': 'nous',
          'name': 'Nous',
          'models': ['free-model'],
          'pricing': {
            'free-model': {
              'input': r'$0.00',
              'output': r'$0.00',
              'free': true,
              'discount_percent': 100,
            },
          },
        },
      ],
    });

    final price = catalog.providers.single.pricing['free-model']!;
    expect(price.free, isTrue);
    expect(price.discountPercent, 100);
    expect(
      catalog.project().providers.single.pricing['free-model'],
      same(price),
    );
  });
}
