import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wp_flutter_app/bank_payment.dart';
import 'package:wp_flutter_app/cart_screen.dart';
import 'package:wp_flutter_app/main.dart';
import 'package:wp_flutter_app/native_mode.dart';
import 'package:wp_flutter_app/payment_result_screen.dart';

const String _apiBase = 'https://payment-return.example/api/';
const AppConfig _config = AppConfig(
  appName: 'Payment return test',
  siteUrl: 'https://payment-return.example/',
  apiBaseUrl: _apiBase,
  renderMode: 'native',
  primaryColor: Colors.blue,
  splashShowLogo: false,
);
const MethodChannel _linkMethods = MethodChannel(
  'com.llfbandit.app_links/messages',
);
const MethodChannel _linkEvents = MethodChannel(
  'com.llfbandit.app_links/events',
);
const MethodChannel _browser = MethodChannel('plugins.flutter.io/url_launcher');

Future<void> _sendLink(WidgetTester tester, String link) async {
  tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    _linkEvents.name,
    const StandardMethodCodec().encodeSuccessEnvelope(link),
    (ByteData? reply) {},
  );
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('payment returns immediately, deduplicates and preserves retry', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BankPayments.instance.checkoutBusy = true;
    final Completer<void> browserClosed = Completer<void>();
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_linkMethods, (call) async => null);
    messenger.setMockMethodCallHandler(_linkEvents, (call) async => null);
    messenger.setMockMethodCallHandler(_browser, (call) async {
      if (call.method == 'closeWebView') await browserClosed.future;
      return null;
    });
    addTearDown(() {
      BankPayments.instance.checkoutBusy = false;
      if (!browserClosed.isCompleted) browserClosed.complete();
      messenger.setMockMethodCallHandler(_linkMethods, null);
      messenger.setMockMethodCallHandler(_linkEvents, null);
      messenger.setMockMethodCallHandler(_browser, null);
    });

    await tester.runAsync(() async {
      await CartManager.instance.ready;
      CartManager.instance.clearCart();
      await BankPayments.instance.save(
        _apiBase,
        const PendingBankOrder(id: 901, key: 'private-order-key', total: 120),
      );
      CartManager.instance.addItem(
        WpItem.fromMap(<String, dynamic>{
          'id': 41,
          'title': 'Paid product',
          'product': <String, dynamic>{'price': '120'},
        }),
      );
    });
    await tester.pumpWidget(const WpToFlutterApp(config: _config));
    final NavigatorState navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (context) =>
              const Scaffold(body: Text('Checkout test route')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    BankPayments.instance.checkoutBusy = false;

    const String successLink =
        'wptoflutter://payment-result?status=success&order_id=901&ref_id=bank-ref';
    await _sendLink(tester, successLink);
    expect(find.byType(PaymentResultScreen), findsOneWidget);
    expect(find.text('Checkout test route'), findsNothing);
    expect(browserClosed.isCompleted, isFalse);
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      await tester.runAsync(() => BankPayments.instance.load(_apiBase)),
      isNull,
    );
    expect(CartManager.instance.items, isEmpty);
    await _sendLink(tester, successLink);
    expect(find.byType(PaymentResultScreen), findsOneWidget);
    navigator.pop();
    await tester.pump();
    expect(navigator.canPop(), isFalse);
    browserClosed.complete();

    await tester.runAsync(
      () => BankPayments.instance.save(
        _apiBase,
        const PendingBankOrder(id: 902, key: 'retry-order-key', total: 120),
      ),
    );
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (context) =>
              const Scaffold(body: Text('Checkout test route')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    for (int attempt = 0; attempt < 2; attempt++) {
      await _sendLink(
        tester,
        'wptoflutter://payment-result?status=failed&order_id=902',
      );
      expect(find.byType(PaymentResultScreen), findsOneWidget);
      expect(
        (await tester.runAsync(() => BankPayments.instance.load(_apiBase)))?.id,
        902,
      );
      await tester.tap(find.text('تلاش مجدد برای پرداخت'));
      await tester.pump();
      expect(find.text('Checkout test route'), findsOneWidget);
    }

    await _sendLink(
      tester,
      'wptoflutter://payment-result?status=success&order_id=902',
    );
    expect(find.byType(PaymentResultScreen), findsOneWidget);
    expect(find.text('Checkout test route'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 8));
  });
}
