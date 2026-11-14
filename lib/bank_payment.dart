import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class PendingBankOrder {
  const PendingBankOrder({
    required this.id,
    required this.key,
    required this.total,
    this.couponError = '',
  });

  final int id;
  final String key;
  final int total;
  final String couponError;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'order_id': id,
    'order_key': key,
    'total': total,
    'coupon_error': couponError,
  };

  factory PendingBankOrder.fromMap(Map<String, dynamic> data) =>
      PendingBankOrder(
        id: (data['order_id'] as num).toInt(),
        key: data['order_key'] as String,
        total: num.parse('${data['total']}').round(),
        couponError: (data['coupon_error'] ?? '').toString(),
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

  Future<bool> complete(String apiBase, int orderId) async {
    final String receipt = '$apiBase:$orderId';
    if (!_completed.add(receipt)) return false;
    try {
      final PendingBankOrder? pending = await load(apiBase);
      if (pending?.id == orderId) {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        if (!await prefs.remove(_storageKey(apiBase))) {
          throw StateError('Pending order could not be cleared');
        }
      }
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
