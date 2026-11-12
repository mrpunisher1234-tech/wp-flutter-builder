import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wp_flutter_app/addresses_screen.dart';
import 'package:wp_flutter_app/main.dart';
import 'package:wp_flutter_app/orders_screen.dart';

void main() {
  test('AppConfig parses the injected build payload', () {
    final AppConfig config = AppConfig.fromMap(<String, dynamic>{
      'app_name': 'Demo App',
      'site_url': 'https://example.com',
      'primary_color': '#2271b1',
    });

    expect(config.appName, 'Demo App');
    expect(config.siteUrl, 'https://example.com');
    expect(config.primaryColor.toARGB32(), 0xFF2271B1);
  });

  test('AppConfig falls back to safe defaults on empty payload', () {
    final AppConfig config = AppConfig.fromMap(<String, dynamic>{});

    expect(config.appName, 'Demo App');
    expect(config.siteUrl, 'https://example.com');
    expect(config.primaryColor.toARGB32(), 0xFF2271B1);
  });

  test('normalizeSiteUrl adds the https scheme when missing', () {
    expect(AppConfig.normalizeSiteUrl('example.com'), 'https://example.com');
    expect(AppConfig.normalizeSiteUrl('http://example.com'), 'http://example.com');
    expect(AppConfig.normalizeSiteUrl(''), 'https://example.com');
  });

  test('search suggestions are read straight from the bundled config', () {
    final AppConfig config = AppConfig.fromMap(<String, dynamic>{
      'app_name': 'Demo App',
      'site_url': 'https://example.com',
      'search_suggestions': <String>[
        'ساعت هوشمند',
        'گجت',
        'اسپیکر بلوتوثی',
        'اسپیکر شارژی',
      ],
    });

    expect(config.searchSuggestions, hasLength(4));
    expect(config.searchSuggestions.first, 'ساعت هوشمند');
    expect(config.searchSuggestions.last, 'اسپیکر شارژی');
  });

  test('suggestions survive a splash-only overlay map (withSplash)', () {
    final AppConfig config = AppConfig.fromMap(<String, dynamic>{
      'app_name': 'Demo App',
      'site_url': 'https://example.com',
      'search_suggestions': <String>['الف', 'ب'],
    });

    // This is the exact call AppConfig.load() makes for the prefs overlay:
    // it must not wipe the suggestions that came from the bundle.
    final AppConfig overlay = config.withSplash(<String, dynamic>{});
    expect(overlay.searchSuggestions, <String>['الف', 'ب']);
  });

  test('suggestions are trimmed, de-duplicated by emptiness and capped at four', () {
    final List<String> parsed = AppConfig.parseSuggestions(<dynamic>[
      '  یک  ',
      '',
      'دو',
      'سه',
      'چهار',
      'پنج',
    ]);

    expect(parsed, <String>['یک', 'دو', 'سه', 'چهار']);
    expect(AppConfig.parseSuggestions(null), isEmpty);
    expect(AppConfig.parseSuggestions('not-a-list'), isEmpty);
  });

  // Real payload captured from POST /wp-to-flutter/v1/orders against the live
  // WooCommerce database, so the keys the app parses are the keys the server sends.
  const String liveOrderJson = '''
  {
    "id": 14119,
    "number": "14119",
    "status": "cancelled",
    "status_label": "لغو شده",
    "date": "2026-10-27T17:51:34+00:00",
    "date_label": "۱۴۰۵/۰۸/۰۵ - ۲۱:۲۱",
    "total": "1320000",
    "items_count": 1,
    "thumbnails": ["http://localhost/wp-content/uploads/x-300x300.jpg"]
  }''';

  test('OrderSummary parses the live orders payload', () {
    final OrderSummary order =
        OrderSummary.fromMap(jsonDecode(liveOrderJson) as Map<String, dynamic>);

    expect(order.id, 14119);
    expect(order.number, '14119');
    expect(order.status, 'cancelled');
    expect(order.statusLabel, 'لغو شده');
    expect(order.dateLabel, '۱۴۰۵/۰۸/۰۵ - ۲۱:۲۱');
    expect(order.total, '1320000');
    expect(order.itemsCount, 1);
    expect(order.thumbnails, hasLength(1));
  });

  test('OrderSummary survives an empty payload without throwing', () {
    final OrderSummary order = OrderSummary.fromMap(<String, dynamic>{});

    expect(order.id, 0);
    expect(order.number, '');
    expect(order.total, '');
    expect(order.itemsCount, 0);
    expect(order.thumbnails, isEmpty);
  });

  // Toman stores return whole numbers, but a store with 2 decimals would send
  // "1320000.00" and dropping only non-digits would inflate it 100x.
  test('decimal totals are truncated before formatting', () {
    final OrderSummary order = OrderSummary.fromMap(<String, dynamic>{
      'total': '1320000.00',
      'thumbnails': <dynamic>['  ', '', 'http://x/y.jpg'],
    });

    expect(order.total, '1320000');
    expect(order.thumbnails, <String>['http://x/y.jpg']);
  });

  test('OrderDetail parses items, addresses and invoice rows', () {
    final OrderDetail detail = OrderDetail.fromMap(<String, dynamic>{
      'number': '14119',
      'status': 'processing',
      'status_label': 'در حال آماده‌سازی',
      'date_label': '۱۴۰۵/۰۸/۰۵',
      'total': '1320000',
      'subtotal': '1150000',
      'discount': '0',
      'shipping_total': '170000',
      'payment_method': 'زیبال',
      'customer_note': '',
      'items': <dynamic>[
        <String, dynamic>{
          'product_id': 12,
          'name': 'ایرپاد پرو هوشمند',
          'quantity': 1,
          'line_total': '1150000',
          'thumbnail': 'http://x/p.jpg',
        },
      ],
      'billing': <String, dynamic>{'city': 'سرباز', 'phone': '09152769410'},
      'shipping': <String, dynamic>{},
    });

    expect(detail.items, hasLength(1));
    expect(detail.items.first.name, 'ایرپاد پرو هوشمند');
    expect(detail.items.first.quantity, 1);
    expect(detail.subtotal, '1150000');
    expect(detail.shippingTotal, '170000');
    expect(detail.paymentMethod, 'زیبال');
    expect(detail.billing.city, 'سرباز');
    expect(detail.billing.isEmpty, isFalse);
    // No shipping address means the screen falls back to billing.
    expect(detail.shipping.isEmpty, isTrue);
    expect(detail.billing.summary.contains('سرباز'), isTrue);
  });

  test('UserAddress parses the addresses payload and round-trips to the save body', () {
    final Map<String, dynamic> payload = <String, dynamic>{
      'id': 1794327280,
      'title': 'خانه',
      'first_name': 'علی',
      'last_name': 'محمدی',
      'phone': '09123456789',
      'state': 'THR',
      'city': 'تهران',
      'address_1': 'خیابان ولیعصر، پلاک ۱۲',
      'postcode': '1234567890',
      'is_default': true,
    };

    final UserAddress address = UserAddress.fromMap(payload);
    expect(address.id, 1794327280);
    expect(address.title, 'خانه');
    expect(address.isDefault, isTrue);
    expect(address.summary, 'خیابان ولیعصر، پلاک ۱۲، تهران');
    expect(address.fullName, 'علی محمدی');

    final Map<String, dynamic> body = address.toBody('token-123');
    expect(body['auth_token'], 'token-123');
    expect(body['state'], 'THR');
    expect(body['is_default'], isTrue);
  });

  test('province list parses the WooCommerce codes', () {
    final List<Province> provinces = <Map<String, dynamic>>[
      {'code': 'KHZ', 'name': 'خوزستان'},
      {'code': 'THR', 'name': 'تهران'},
      {'code': 'SBN', 'name': 'سیستان و بلوچستان'},
    ].map(Province.fromMap).toList();

    expect(provinces, hasLength(3));
    expect(provinces[1].code, 'THR');
    expect(provinces[1].name, 'تهران');
  });

  test('phone and postcode inputs are normalised like the server does', () {
    expect(normalizePhone('۰۹۱۲ ۳۴۵ ۶۷۸۹'), '09123456789');
    expect(normalizePhone('9123456789'), '09123456789');
    expect(normalizePhone('+989123456789'), '09123456789');
    expect(normalizePhone('989123456789'), '09123456789');
    expect(normalizePhone('abc'), '');
  });
}
