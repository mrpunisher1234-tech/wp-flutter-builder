import 'package:flutter_test/flutter_test.dart';
import 'package:wp_flutter_app/webview_support.dart';

void main() {
  group('external URI handling', () {
    test('HTTP, HTTPS, about, data and blob stay inside WebView', () {
      for (final String value in <String>[
        'https://example.com/checkout',
        'http://localhost/checkout',
        'about:blank',
        'data:text/html,<h1>Hello</h1>',
        'blob:https://example.com/123',
      ]) {
        expect(externalUriAction(Uri.parse(value)), ExternalUriAction.navigate, reason: value);
      }
    });

    test('payment, contact, social, market and intent schemes launch externally', () {
      for (final String value in <String>[
        'wptoflutter://payment-result?status=success&order_id=12',
        'intent://payment-result#Intent;scheme=wptoflutter;end;',
        'tel:+9821000000',
        'mailto:shop@example.com',
        'sms:+989120000000',
        'whatsapp://send?phone=989120000000',
        'tg://resolve?domain=shop',
        'eitaa://shop',
        'bale://shop',
        'rubika://shop',
        'geo:35.7,51.4',
        'market://details?id=ir.example.app',
      ]) {
        expect(externalUriAction(Uri.parse(value)), ExternalUriAction.launchExternal, reason: value);
      }
    });

    test('javascript and scheme-less values are ignored safely', () {
      expect(externalUriAction(null), ExternalUriAction.ignore);
      expect(externalUriAction(Uri.parse('/checkout')), ExternalUriAction.ignore);
      expect(externalUriAction(Uri.parse('javascript:void(0)')), ExternalUriAction.ignore);
      expect(externalUriAction(Uri.parse('javascript:alert(1)')), ExternalUriAction.ignore);
    });

    test('intent candidates try native app before WebView fallback', () {
      final Uri intent = Uri.parse(
        'intent://payment-result?status=success#Intent;scheme=wptoflutter;S.browser_fallback_url=https%3A%2F%2Fexample.com%2Fresult;end;',
      );
      final List<Uri> candidates = externalUriCandidates(intent);
      expect(candidates, hasLength(2));
      expect(candidates[0].toString(), 'wptoflutter://payment-result?status=success');
      expect(candidates[1].toString(), 'https://example.com/result');
      expect(intentNativeUri(intent).toString(), 'wptoflutter://payment-result?status=success');
      expect(intentFallbackUri(intent).toString(), 'https://example.com/result');
      expect(intentFallbackUri(Uri.parse('wptoflutter://payment-result')), isNull);
    });
  });

  group('compatibility script', () {
    test('uses conservative store-only theme rules and safe popup handling', () {
      final String script = webViewCompatibilityScript(
        mapLocalhost: false,
        currentUrl: 'https://shop.example.com/checkout',
        storeHost: 'example.com',
      );
      expect(script, contains('window.open'));
      expect(script, contains('a[target="_blank"]'));
      expect(script, contains('form.target'));
      expect(script, contains('closed: false'));
      expect(script, contains('width=device-width, initial-scale=1.0'));
      expect(script, contains('overflow-x: clip'));
      expect(script, isNot(contains('table { display: block')));
      expect(script, isNot(contains('height: auto')));
      expect(script, isNot(contains('#wpadminbar')));
      expect(script, isNot(contains('maximum-scale')));
      expect(script, isNot(contains('user-scalable=no')));
      expect(script, isNot(contains('10.0.2.2')));
    });

    test('does not inject theme CSS onto external payment pages', () {
      final String script = webViewCompatibilityScript(
        mapLocalhost: false,
        currentUrl: 'https://bank.example/pay',
        storeHost: 'example.com',
      );
      expect(script, isNot(contains('wptf-compatibility-style')));
      expect(script, isNot(contains('width=device-width, initial-scale=1.0')));
    });

    test('localhost rewriting is opt-in and store-only', () {
      final String script = webViewCompatibilityScript(
        mapLocalhost: true,
        currentUrl: 'http://localhost/checkout',
        storeHost: 'localhost',
      );
      expect(script, contains('10.0.2.2'));
      expect(script, contains('127.0.0.1'));
    });
  });

  group('pushed WebView back navigation', () {
    test('back goes through WebView history when available', () async {
      var historyCalls = 0;
      var routeCalls = 0;
      await handlePushedWebViewBack(
        canGoBack: true,
        goBack: () async => historyCalls++,
        popRoute: () => routeCalls++,
      );
      expect(historyCalls, 1);
      expect(routeCalls, 0);
    });

    test('back pops the pushed route without killing the app', () async {
      var historyCalls = 0;
      var routeCalls = 0;
      await handlePushedWebViewBack(
        canGoBack: false,
        goBack: () async => historyCalls++,
        popRoute: () => routeCalls++,
      );
      expect(historyCalls, 0);
      expect(routeCalls, 1);
    });
  });
}
