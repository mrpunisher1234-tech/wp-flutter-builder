import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wp_flutter_app/api_page.dart';
import 'package:wp_flutter_app/bank_payment.dart';
import 'package:wp_flutter_app/cart_screen.dart';
import 'package:wp_flutter_app/native_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cart restore replays in-memory additions and deletions', () async {
    final Map<String, dynamic> product = <String, dynamic>{
      'id': 41,
      'title': 'Saved product',
      'product': <String, dynamic>{'price': '120.00'},
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      'wptf_persisted_cart': jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{'item': product, 'quantity': 2},
        <String, dynamic>{
          'item': <String, dynamic>{...product, 'id': 42},
          'quantity': 1,
        },
      ]),
    });
    final CartManager cart = CartManager.instance;
    cart.addItem(WpItem.fromMap(product));
    cart.addItem(WpItem.fromMap(<String, dynamic>{...product, 'id': 43}));
    cart.deleteItem(42);
    await cart.ready;
    expect(cart.items.map((CartItem item) => item.item.id), <int>[41, 43]);
    expect(cart.items.first.quantity, 3);
    expect(cart.totalPrice, 480);
    await Future<void>.delayed(Duration.zero);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<dynamic> saved = jsonDecode(prefs.getString('wptf_persisted_cart')!) as List<dynamic>;
    expect(saved.length, 2);
    expect((saved.first as Map<String, dynamic>)['quantity'], 3);
    cart.clearCart();
    await Future<void>.delayed(Duration.zero);
  });

  test('bank order credentials and server total survive restoration', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const String base = 'https://shop.example/api/';
    final PendingBankOrder order = PendingBankOrder.fromMap(<String, dynamic>{
      'order_id': 51,
      'order_key': 'wc_order_private',
      'total': '125000.00',
      'coupon_error': 'Coupon expired',
    });
    await BankPayments.instance.save(base, order);
    final PendingBankOrder? restored = await BankPayments.instance.load(base);
    expect(restored!.id, 51);
    expect(restored.key, 'wc_order_private');
    expect(restored.total, 125000);
    expect(restored.couponError, 'Coupon expired');
    expect(await BankPayments.instance.load('https://other.example/api/'), isNull);
    expect(await BankPayments.instance.complete(base, 51), isTrue);
    expect(await BankPayments.instance.complete(base, 51), isFalse);
    expect(await BankPayments.instance.load(base), isNull);
  });

  test('pagination uses server page count even for full last pages', () {
    const ApiPage lastPage = ApiPage(200, '[]', 2);
    expect(lastPage.hasNextPage(1), isTrue);
    expect(lastPage.hasNextPage(2), isFalse);
    expect(const ApiPage(200, '[]', 0).hasNextPage(1), isFalse);
  });
}
