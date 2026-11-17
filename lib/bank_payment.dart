import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class PendingBankOrder {
  const PendingBankOrder({
    required this.id,
    required this.key,
    required this.total,
    this.couponError = '',
    this.fingerprint = '',
  });

  final int id;
  final String key;
  final int total;
  final String couponError;

  /// اثر انگشت سبد و آدرس لحظهٔ ساختن سفارش | مقایسه در submit | عوضشده = سفارش کهنه بیاعتبار.
  final String fingerprint;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'order_id': id,
    'order_key': key,
    'total': total,
    'coupon_error': couponError,
    'fingerprint': fingerprint,
  };

  factory PendingBankOrder.fromMap(Map<String, dynamic> data) =>
      PendingBankOrder(
        id: (data['order_id'] as num).toInt(),
        key: data['order_key'] as String,
        total: num.parse('${data['total']}').round(),
        couponError: (data['coupon_error'] ?? '').toString(),
        fingerprint: (data['fingerprint'] ?? '').toString(),
      );
}

class BankOrderStatus {
  const BankOrderStatus(this.order, this.paid, this.status, this.refId);

  final PendingBankOrder order;
  final bool paid;
  final String status;
  final String refId;
}

class BankPayments {
  BankPayments._();

  static final BankPayments instance = BankPayments._();
  final Map<String, Future<BankOrderStatus?>> _checks =
      <String, Future<BankOrderStatus?>>{};
  final Set<String> _completed = <String>{};
  bool checkoutBusy = false;

  String _storageKey(String apiBase) => 'wptf_pending_bank_order_$apiBase';
  String _idempotencyStorageKey(String apiBase) =>
      'wptf_checkout_idempotency_$apiBase';

  Future<String> prepareIdempotencyKey(
    String apiBase,
    String fingerprint,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_idempotencyStorageKey(apiBase));
    if (raw != null && raw.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> &&
            decoded['fingerprint'] == fingerprint) {
          final String existing = (decoded['key'] ?? '').toString();
          if (existing.isNotEmpty) return existing;
        }
      } catch (_) {
        // رکورد ناسازگار با کلید تازه جایگزین می‌شود.
      }
    }

    final Random random = Random.secure();
    final String key = 'wptf_${List<int>.generate(16, (_) => random.nextInt(256))
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()}';
    if (!await prefs.setString(
      _idempotencyStorageKey(apiBase),
      jsonEncode(<String, String>{
        'key': key,
        'fingerprint': fingerprint,
      }),
    )) {
      throw StateError('Checkout idempotency key could not be saved');
    }
    return key;
  }

  Future<PendingBankOrder?> load(String apiBase) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_storageKey(apiBase));
    if (raw == null) return null;
    final PendingBankOrder order = PendingBankOrder.fromMap(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    if (order.id <= 0 || order.key.isEmpty) {
      throw const FormatException('Invalid pending order');
    }
    return order;
  }

  Future<void> save(String apiBase, PendingBankOrder order) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      _storageKey(apiBase),
      jsonEncode(order.toMap()),
    )) {
      throw StateError('Pending order could not be saved');
    }
  }

  /// پاک کردن سفارش انبار | برای سفارش لغوشده یا سبد عوضشده تا سفارش تازه ساخته شود.
  Future<void> clear(String apiBase) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey(apiBase));
    await prefs.remove(_idempotencyStorageKey(apiBase));
  }

  /// سفارش انبار دیگر قابل استفاده نیست؟ | وضعیت لغوشده/ناموفق یا سبد و آدرس
  /// عوضشده | سفارش پرداختشده هرگز اینجا دور ریخته نمیشود (مسیر موفقیت جدا است).
  static bool isDiscardable(
    BankOrderStatus? status,
    String storedFingerprint,
    String currentFingerprint,
  ) {
    if (status != null && status.paid) return false;
    if (storedFingerprint != currentFingerprint) return true;
    return status != null &&
        (status.status == 'cancelled' ||
            status.status == 'failed' ||
            status.status == 'trash');
  }

  Future<bool> complete(String apiBase, int orderId) async {
    final String receipt = '$apiBase:$orderId';
    if (!_completed.add(receipt)) return false;
    try {
      final PendingBankOrder? pending = await load(apiBase);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (pending?.id == orderId &&
          !await prefs.remove(_storageKey(apiBase))) {
        throw StateError('Pending order could not be cleared');
      }
      await prefs.remove(_idempotencyStorageKey(apiBase));
      return true;
    } catch (_) {
      _completed.remove(receipt);
      rethrow;
    }
  }

  Future<BankOrderStatus?> reconcile(String apiBase) {
    return _checks[apiBase] ??= _check(apiBase);
  }

  Future<BankOrderStatus?> _check(String apiBase) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final PendingBankOrder? order = await load(apiBase);
      if (order == null) return null;
      final HttpClientRequest request = await client
          .postUrl(Uri.parse('${apiBase}payment/order-status'))
          .timeout(const Duration(seconds: 15));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<String, dynamic>{
          'order_id': order.id,
          'order_key': order.key,
        }),
      );
      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final String body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      final dynamic data = jsonDecode(body);
      if (response.statusCode != 200 ||
          data is! Map<String, dynamic> ||
          data['success'] != true) {
        throw const HttpException('Order status unavailable');
      }
      return BankOrderStatus(
        order,
        data['paid'] == true,
        '${data['status'] ?? ''}',
        '${data['ref_id'] ?? ''}',
      );
    } finally {
      client.close(force: true);
      _checks.remove(apiBase);
    }
  }
}
