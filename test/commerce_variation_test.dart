import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wp_flutter_app/addresses_screen.dart';
import 'package:wp_flutter_app/cart_screen.dart';
import 'package:wp_flutter_app/commerce_rules.dart';
import 'package:wp_flutter_app/favorites_screen.dart';
import 'package:wp_flutter_app/native_mode.dart';
import 'package:wp_flutter_app/product_variations.dart';

Map<String, dynamic> variation(int id, String color, int price) => <String, dynamic>{
      'id': id,
      'attributes': <String, String>{'attribute_pa_color': color},
      'price': '$price',
      'regular_price': '${price + 20000}',
      'sale_price': '$price',
      'in_stock': true,
      'stock_quantity': 4,
      'purchasable': true,
      'on_sale': true,
      'sku': 'SKU-$id',
      'image': 'https://example.com/$id.jpg',
    };

Map<String, dynamic> variableProduct() => <String, dynamic>{
      'id': 77,
      'type': 'product',
      'title': 'تیشرت',
      'excerpt': '',
      'content': '',
      'url': 'https://example.com/shirt',
      'featured_image': 'https://example.com/shirt.jpg',
      'categories': <dynamic>[],
      'product': <String, dynamic>{
        'product_type': 'variable',
        'price': '100000',
        'regular_price': '120000',
        'sale_price': '100000',
        'in_stock': true,
        'purchasable': true,
        'on_sale': true,
        'sku': 'PARENT',
        'stock_quantity': null,
        'rating': 0,
        'reviews_count': 0,
        'gallery_images': <dynamic>[],
        'attributes': <dynamic>[
          <String, dynamic>{
            'slug': 'pa_color',
            'name': 'رنگ',
            'variation': true,
            'options': <dynamic>[
              <String, String>{'name': 'قرمز', 'value': 'red'},
              <String, String>{'name': 'آبی', 'value': 'blue'},
            ],
          },
        ],
        'variations': <dynamic>[variation(701, 'red', 100000), variation(702, 'blue', 120000)],
        'related_products': <dynamic>[],
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await CartManager.instance.ready;
    CartManager.instance.clearCart();
  });

  tearDown(() => CartManager.instance.clearCart());

  test('variable product exposes typed options and complete variations', () {
    final WpItem item = WpItem.fromMap(variableProduct());
    expect(item.isVariable, isTrue);
    expect(item.variations, hasLength(2));
    expect(item.attributes.single.options.first.name, 'قرمز');
    expect(item.attributes.single.options.first.value, 'red');
    expect(item.variations.first.sku, 'SKU-701');
    expect(item.variations.first.inStock, isTrue);
    expect(item.variations.first.image, contains('701.jpg'));
  });

  test('different variations coexist and selected variation survives serialization', () async {
    final WpItem item = WpItem.fromMap(variableProduct());
    final WpVariation red = item.variations[0];
    final WpVariation blue = item.variations[1];
    expect(CartManager.instance.addItem(item), isFalse);
    expect(CartManager.instance.addItem(item, variation: red), isTrue);
    expect(CartManager.instance.addItem(item, variation: blue), isTrue);
    expect(CartManager.instance.addItem(item, variation: red), isTrue);
    final List<CartItem> lines = CartManager.instance.items;
    expect(lines, hasLength(2));
    expect(lines.map((CartItem line) => line.key).toSet(), hasLength(2));
    expect(lines.firstWhere((line) => line.variationId == red.id).quantity, 2);
    expect(lines.firstWhere((line) => line.variationId == blue.id).quantity, 1);
    expect(lines.firstWhere((line) => line.variationId == blue.id).unitPrice, 120000);
    expect(lines.firstWhere((line) => line.variationId == blue.id).sku, 'SKU-702');
    expect(lines.firstWhere((line) => line.variationId == blue.id).featuredImage, contains('702.jpg'));
    final WpVariation restored = WpVariation.fromMap(blue.toMap());
    expect(variationCartKey(item.id, restored), variationCartKey(item.id, blue));
    expect(restored.price, blue.price);
    expect(restored.attributes, blue.attributes);
  });

  test('favorite and recent snapshots preserve variable selection data', () {
    final WpItem original = WpItem.fromMap(variableProduct());
    final WpItem restored = wpItemFromSnapshot(wpItemSnapshot(original));
    expect(restored.isVariable, isTrue);
    expect(restored.variations, hasLength(2));
    expect(restored.variations.first.id, 701);
    expect(restored.attributes.single.options.first.value, 'red');
    expect(variationCartKey(restored.id, restored.variations.first), variationCartKey(original.id, original.variations.first));
  });

  test('free shipping uses the same enabled threshold rule', () {
    expect(shippingCost(subtotal: 499999, freeShippingEnabled: true, freeShippingThreshold: 500000, defaultShippingCost: 45000), 45000);
    expect(shippingCost(subtotal: 500000, freeShippingEnabled: true, freeShippingThreshold: 500000, defaultShippingCost: 45000), 0);
    expect(shippingCost(subtotal: 900000, freeShippingEnabled: false, freeShippingThreshold: 500000, defaultShippingCost: 45000), 45000);
    expect(shippingCost(subtotal: 900000, freeShippingEnabled: true, freeShippingThreshold: 0, defaultShippingCost: 45000), 45000);
  });

  test('phone normalization accepts local, international and Persian digits', () {
    expect(normalizePhone('09123456789'), '09123456789');
    expect(normalizePhone('9123456789'), '09123456789');
    expect(normalizePhone('989123456789'), '09123456789');
    expect(normalizePhone('+989123456789'), '09123456789');
    expect(normalizePhone('۰۹۱۲۳۴۵۶۷۸۹'), '09123456789');
  });
}
