import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wp_flutter_app/api_page.dart';
import 'package:wp_flutter_app/bank_payment.dart';
import 'package:wp_flutter_app/bazaar_payment.dart';
import 'package:wp_flutter_app/cart_screen.dart';
import 'package:wp_flutter_app/native_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cart restore replays in-memory additions and deletions', () async {
    final Map<String, dynamic> product = <String, dynamic>{
      'id': 41,
      'title': 'Saved product',
      'product': <String, dynamic>{'price': '120.00', 'sku': 'sku41'},
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
    final Map<String, dynamic> savedItem =
        (saved.first as Map<String, dynamic>)['item'] as Map<String, dynamic>;
    expect(
      (savedItem['product'] as Map<String, dynamic>)['sku'],
      'sku41',
    );
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

  test('cancelled order or changed cart fingerprint discards pending order', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const String base = 'https://shop.example/api/';
    // سفارش قدیمی بدون fingerprint (نسخهٔ قبلی اپ) | اثر انگشت خالی با هر سبد تازه‌ای فرق دارد.
    final PendingBankOrder legacy = PendingBankOrder.fromMap(<String, dynamic>{
      'order_id': 77,
      'order_key': 'wc_order_legacy',
      'total': '90000',
    });
    expect(legacy.fingerprint, '');

    final PendingBankOrder stored = PendingBankOrder(
      id: 88,
      key: 'wc_order_stored',
      total: 120000,
      fingerprint: '41:2|coupon=',
    );
    await BankPayments.instance.save(base, stored);
    expect((await BankPayments.instance.load(base))!.fingerprint, '41:2|coupon=');

    // وضعیت لغو/ناموفق از سرور | سفارش باید دور ریخته شود.
    expect(
      BankPayments.isDiscardable(
        BankOrderStatus(stored, false, 'cancelled', ''),
        stored.fingerprint,
        stored.fingerprint,
      ),
      isTrue,
    );
    expect(
      BankPayments.isDiscardable(
        BankOrderStatus(stored, false, 'failed', ''),
        stored.fingerprint,
        stored.fingerprint,
      ),
      isTrue,
    );
    expect(
      BankPayments.isDiscardable(
        BankOrderStatus(stored, false, 'trash', ''),
        stored.fingerprint,
        stored.fingerprint,
      ),
      isTrue,
    );
    // در انتظار پرداخت و سبد دست‌نخورده | سفارش میماند.
    expect(
      BankPayments.isDiscardable(
        BankOrderStatus(stored, false, 'pending', ''),
        stored.fingerprint,
        stored.fingerprint,
      ),
      isFalse,
    );
    expect(
      BankPayments.isDiscardable(null, stored.fingerprint, stored.fingerprint),
      isFalse,
    );
    // سفارش پرداختشده هرگز اینجا دور ریخته نمیشود | مسیر موفقیت جدا است.
    expect(
      BankPayments.isDiscardable(
        BankOrderStatus(stored, true, 'cancelled', ''),
        stored.fingerprint,
        stored.fingerprint,
      ),
      isFalse,
    );
    // تغییر سبد | حتی بدون جواب سرور (status null) سفارش کهنه اعتبار ندارد.
    expect(
      BankPayments.isDiscardable(null, stored.fingerprint, '41:3|coupon='),
      isTrue,
    );

    // پاکسازی واقعی انبار | فقط کلید همین سایت پاک میشود و بقیه دست‌نخورده میمانند.
    await BankPayments.instance.save('https://other.example/api/', stored);
    await BankPayments.instance.clear(base);
    expect(await BankPayments.instance.load(base), isNull);
    expect(
      await BankPayments.instance.load('https://other.example/api/'),
      isNotNull,
    );
  });

  test('checkout idempotency key survives retry and rotates with fingerprint', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const String base = 'https://shop.example/api/';
    final String first = await BankPayments.instance.prepareIdempotencyKey(
      base,
      '41:2|coupon=',
    );
    final String retry = await BankPayments.instance.prepareIdempotencyKey(
      base,
      '41:2|coupon=',
    );
    final String changed = await BankPayments.instance.prepareIdempotencyKey(
      base,
      '41:3|coupon=',
    );

    expect(retry, first);
    expect(changed, isNot(first));
    await BankPayments.instance.clear(base);
    final String afterClear =
        await BankPayments.instance.prepareIdempotencyKey(
      base,
      '41:3|coupon=',
    );
    expect(afterClear, isNot(changed));
  });

  test('bazaar settlement confirms a consumed token with server order id',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final HttpServer server =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    late String requestPath;
    late Map<String, dynamic> requestBody;
    final Future<void> responder = () async {
      final HttpRequest request = await server.first;
      requestPath = request.uri.path;
      requestBody = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, dynamic>{
        'credited': true,
        'order_id': 712,
        'status': 'verified',
      }));
      await request.response.close();
    }();

    try {
      BazaarPayments.instance.init(
        apiBase: 'http://127.0.0.1:${server.port}/',
      );
      final BazaarSettlement result =
          await BazaarPayments.instance.settleAndWait('purchase-token-712');
      await responder;
      expect(requestPath, '/payment/bazaar/status');
      expect(requestBody['purchase_token'], 'purchase-token-712');
      expect(result.credited, isTrue);
      expect(result.orderId, 712);
    } finally {
      await server.close(force: true);
    }
  });

  test('bazaar settlement fails closed when missing queue is unconfirmed',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kPrefsPendingBazaarPurchases: '{broken',
    });
    final HttpServer server =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final Future<void> responder = () async {
      final HttpRequest request = await server.first;
      await utf8.decoder.bind(request).join();
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, dynamic>{
        'credited': false,
        'order_id': 0,
        'status': 'pending',
      }));
      await request.response.close();
    }();

    try {
      BazaarPayments.instance.init(
        apiBase: 'http://127.0.0.1:${server.port}/',
      );
      final BazaarSettlement result =
          await BazaarPayments.instance.settleAndWait('unknown-token');
      await responder;
      expect(result.credited, isFalse);
      expect(result.orderId, 0);
    } finally {
      await server.close(force: true);
    }
  });

  test('pagination uses server page count even for full last pages', () {
    const ApiPage lastPage = ApiPage(200, '[]', 2);
    expect(lastPage.hasNextPage(1), isTrue);
    expect(lastPage.hasNextPage(2), isFalse);
    expect(const ApiPage(200, '[]', 0).hasNextPage(1), isFalse);
  });
}
