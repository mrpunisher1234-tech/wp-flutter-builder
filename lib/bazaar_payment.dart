import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_poolakey/flutter_poolakey.dart' as poolakey;
import 'package:shared_preferences/shared_preferences.dart';

/// وضعیت اتصال به کافه‌بازار.
enum BazaarState { connecting, connected, failed }

/// کلید SharedPreferences برای صف خریدهای در انتظار تسویهٔ سمت سرور.
const String kPrefsPendingBazaarPurchases = 'wptf_pending_bazaar_purchases';

/// سقف تلاش برای تسویهٔ یک خرید | بعد از آن رکورد برای پیگیری پشتیبانی می‌ماند.
const int kMaxBazaarVerifyAttempts = 5;

/// یک خرید در انتظار تسویهٔ سمت سرور | پیش از هر اثر جانبی ذخیره می‌شود تا
/// اگر پروسه وسط کار بمیرد، خرید در اجرای بعدی بازیابی و تسویه شود.
class PendingBazaarPurchase {
  PendingBazaarPurchase({
    required this.sku,
    required this.token,
    this.orderId = '',
    this.packageName = '',
    this.payload = '',
    this.attempts = 0,
    this.credited = false,
    this.wcOrderId = 0,
  });

  factory PendingBazaarPurchase.fromMap(Map<String, dynamic> map) {
    return PendingBazaarPurchase(
      sku: (map['sku'] ?? '').toString(),
      token: (map['token'] ?? '').toString(),
      orderId: (map['order_id'] ?? '').toString(),
      packageName: (map['package_name'] ?? '').toString(),
      payload: (map['payload'] ?? '').toString(),
      attempts: (map['attempts'] is num) ? (map['attempts'] as num).toInt() : 0,
      credited: (map['credited'] ?? false) == true,
      wcOrderId: (map['wc_order_id'] is num) ? (map['wc_order_id'] as num).toInt() : 0,
    );
  }

  final String sku;
  final String token;
  final String orderId;
  final String packageName;
  final String payload;
  int attempts;

  /// سرور این خرید را ثبت کرده | دیگر verify نمی‌خواهد؛ فقط consume.
  bool credited;
  int wcOrderId;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'sku': sku,
        'token': token,
        'order_id': orderId,
        'package_name': packageName,
        'payload': payload,
        'attempts': attempts,
        'credited': credited,
        'wc_order_id': wcOrderId,
      };
}

/// نتیجهٔ استعلام تسویه از سرور.
class _VerifyOutcome {
  const _VerifyOutcome({
    required this.credited,
    required this.retryable,
    this.creditedOrderId = 0,
  });
  final bool credited;
  final bool retryable;
  final int creditedOrderId;
}

/// نتیجهٔ تسویهٔ صریح یک توکن | برای چکاوت نیتیو.
class BazaarSettlement {
  const BazaarSettlement({required this.credited, this.orderId = 0});
  final bool credited;
  final int orderId;
}

/// درگاه پرداخت درون‌برنامه‌ای کافه‌بازار (Poolakey).
///
/// الگو از پروژهٔ کارآمد کalamikoo برداشته شده است:
/// • آیندهٔ `FlutterPoolakey.connect` هرگز complete نمی‌شود؛ نتیجه فقط از
///   کال‌بک‌ها می‌آید، پس روی آن await نمی‌کنیم و وضعیت را می‌پاییم.
/// • اتصال موازی ممنوع است؛ پلاگین فقط یک paymentConnection نگه می‌دارد.
/// • رکورد خرید قبل از هر اثر جانبی در SharedPreferences می‌نشیند و فقط
///   بعد از consumeِ تأییدشده پاک می‌شود.
/// • امضای محلی وقتی روشن است که کلید RSA داده شده باشد؛ پیش‌فرض اپ خاموش
///   است (kUseLocalSignatureCheck = false) و اعتبارسنجی سمت سرور انجام می‌شود.
class BazaarPayments {
  BazaarPayments._();

  static final BazaarPayments instance = BazaarPayments._();

  /// وضعیت اتصال | UI می‌تواند به همین نوتیفایر گوش بدهد.
  final ValueNotifier<BazaarState> stateNotifier =
      ValueNotifier<BazaarState>(BazaarState.connecting);

  BazaarState get state => stateNotifier.value;
  bool get available => !kIsWeb && Platform.isAndroid;

  String? _rsaKey;
  Uri? _verifyUrl;
  bool _connectInFlight = false;
  bool _purchaseInFlight = false;
  bool _recoveryRunning = false;
  HttpClient? _client;

  /// دنبالهٔ نوشتن صف | نوشتنهای همزمان (خرید در جریان + بازیابی) یکدیگر را
  /// بازنویسی نکنند | الگوی کارا از پروژهٔ kalamikoo.
  Future<void> _queueMutexTail = Future<void>.value();

  /// اجرای یک عملیات نوشتن صف به‌صورت سریالی.
  Future<void> _withQueueMutex(Future<void> Function() action) {
    final Future<void> tail = _queueMutexTail.then((_) => action());
    _queueMutexTail = tail.catchError((Object e) {});
    return tail;
  }

  /// کانال خود پلاگین | فقط به‌عنوان مسیر tolerant برای خواندن انبار مصرف‌نشده
  /// وقتی PurchaseInfo.fromMap پلاگین روی رکورد ناسازگار خطا می‌دهد.
  static const MethodChannel _poolakeyChannel =
      MethodChannel('ir.cafebazaar.flutter_poolakey');

  void init({required String apiBase, String? rsaKey}) {
    _rsaKey = rsaKey;
    final String base = apiBase.endsWith('/') ? apiBase : '$apiBase/';
    if (base.startsWith('http')) {
      _verifyUrl = Uri.parse('${base}payment/bazaar/verify');
    }
    if (available) {
      unawaited(connect());
    }
  }

  /// اتصال به کافه‌بازار | از بیرون هم قابل فراخوانی است (مثلاً بعد از resume).
  Future<void> connect() async {
    if (!available || _connectInFlight || state == BazaarState.connected) {
      return;
    }
    _connectInFlight = true;
    _set(BazaarState.connecting);
    try {
      unawaited(
        poolakey.FlutterPoolakey.connect(
          _rsaKey,
          onSucceed: () {
            _connectInFlight = false;
            _set(BazaarState.connected);
            // بلافاصله بعد از اتصال موفق، خریدهای مصرف‌نشده تسویه می‌شوند.
            unawaited(recoverPurchases());
          },
          onFailed: () {
            _connectInFlight = false;
            _set(BazaarState.failed);
          },
          onDisconnected: () {
            _connectInFlight = false;
            _set(BazaarState.connecting);
            unawaited(connect());
          },
        ).catchError((Object e) {
          _connectInFlight = false;
          _set(BazaarState.failed);
          debugPrint('bazaar: connect error $e');
        }),
      );
    } catch (e) {
      _connectInFlight = false;
      _set(BazaarState.failed);
      debugPrint('bazaar: connect threw $e');
    }
  }

  void _set(BazaarState value) {
    stateNotifier.value = value;
  }

  /// یک تلاش محدود برای وصل‌شدن | روی Future خود connect صبر نمی‌کنیم.
  Future<bool> _waitForConnection() async {
    if (state == BazaarState.connected) {
      return true;
    }
    unawaited(connect());
    for (int i = 0; i < 24; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (state == BazaarState.connected) {
        return true;
      }
      if (state == BazaarState.failed) {
        return false;
      }
    }
    return state == BazaarState.connected;
  }

  /// شروع خرید | PurchaseInfo در موفقیت؛ null در لغو/خطا.
  Future<poolakey.PurchaseInfo?> purchase(
    String sku, {
    String payload = '',
    String dynamicPriceToken = '',
  }) async {
    final String cleanSku = sku.trim();
    if (!available || cleanSku.isEmpty) {
      return null;
    }
    if (_purchaseInFlight) {
      // دو خرید هم‌زمان می‌تواند وضعیت نیتیو بازار را خراب کند.
      debugPrint('bazaar: purchase already in flight');
      return null;
    }
    _purchaseInFlight = true;
    try {
      if (!await _waitForConnection()) {
        debugPrint('bazaar: purchase aborted, no connection');
        return null;
      }
      try {
        final poolakey.PurchaseInfo info =
            await poolakey.FlutterPoolakey.purchase(
          cleanSku,
          payload: payload,
          dynamicPriceToken: dynamicPriceToken,
        ).timeout(const Duration(minutes: 5));
        if (info.purchaseState != poolakey.PurchaseState.PURCHASED) {
          debugPrint('bazaar: purchase state ${info.purchaseState.name}');
          return info;
        }
        // رکورد پایدار قبل از هر اثر جانبی.
        await _queue(PendingBazaarPurchase(
          sku: cleanSku,
          token: info.purchaseToken,
          orderId: info.orderId,
          packageName: info.packageName,
          payload: payload,
        ));
        // تسویهٔ فوری؛ اگر شکست بخورد در اجرای بعدی بازیابی میشود.
        unawaited(recoverPurchases());
        return info;
      } on TimeoutException {
        // پول کاربر ممکن است پرداخت شده باشد؛ بازیابی ثبتش میکند.
        unawaited(recoverPurchases());
        return null;
      } on PlatformException catch (e) {
        debugPrint('bazaar: purchase failed ${e.code} ${e.message ?? ''}');
        // خطای بازار لزوماً پرداختنشدن نیست | خرید قبلی پرداختشده بررسی میشود.
        unawaited(recoverPurchases());
        return null;
      } catch (e) {
        // خطای غیرمنتظرهٔ خود پلاگین (مثل StateError هنگام parse نتیجه) |
        // پول کاربر پرداخت شده و توکن مصرفنشده در بازار مانده است.
        debugPrint('bazaar: purchase threw $e');
        unawaited(recoverPurchases());
        return null;
      }
    } finally {
      _purchaseInFlight = false;
    }
  }

  /// بازیابی خریدهای مصرف‌نشده | صف محلی + انبار خود کافه‌بازار.
  /// اول verify با سرور، بعد consume تا قفل محصول در بازار باز شود.
  Future<void> recoverPurchases() async {
    if (!available ||
        _recoveryRunning ||
        state != BazaarState.connected ||
        _verifyUrl == null) {
      return;
    }
    _recoveryRunning = true;
    try {
      final Map<String, PendingBazaarPurchase> queue = await _loadQueue();

      try {
        final List<poolakey.PurchaseInfo> items =
            await poolakey.FlutterPoolakey.getAllPurchasedProducts()
                .timeout(const Duration(seconds: 12));
        for (final poolakey.PurchaseInfo p in items) {
          if (p.purchaseToken.isEmpty ||
              p.purchaseState == poolakey.PurchaseState.REFUNDED) {
            continue;
          }
          queue.putIfAbsent(
            p.purchaseToken,
            () => PendingBazaarPurchase(
              sku: p.productId,
              token: p.purchaseToken,
              orderId: p.orderId,
              packageName: p.packageName,
              payload: p.payload,
            ),
          );
        }
      } catch (e) {
        // مسیر tolerant با همان کانال پلاگین | رکورد ناسازگار کل فهرست را
        // نمی‌بازاند و دست‌کم توکن‌ها خوانده می‌شوند.
        try {
          final Object? raw = await _poolakeyChannel
              .invokeMethod<Object?>('get_all_purchased_products')
              .timeout(const Duration(seconds: 12));
          final List<Object?> list = (raw as List<Object?>?) ?? const <Object?>[];
          for (final Object? item in list) {
            if (item is! Map) {
              continue;
            }
            // همان فیلتر مسیر رسمی | خرید بازپرداخت‌شده ثبت نمی‌شود.
            final Object? rawState = item['purchaseState'];
            if (rawState is num && rawState.toInt() != 0) {
              continue;
            }
            final String token = (item['purchaseToken'] ?? '').toString();
            if (token.isEmpty || queue.containsKey(token)) {
              continue;
            }
            queue[token] = PendingBazaarPurchase(
              sku: (item['productId'] ?? '').toString(),
              token: token,
              orderId: (item['orderId'] ?? '').toString(),
              packageName: (item['packageName'] ?? '').toString(),
              payload: (item['developerPayload'] ?? '').toString(),
            );
          }
        } catch (e2) {
          debugPrint('bazaar: inventory read failed $e2');
        }
      }

      if (queue.isEmpty) {
        return;
      }

      bool changed = false;
      final Set<String> removedTokens = <String>{};
      for (final PendingBazaarPurchase rec in queue.values.toList(growable: false)) {
        if (rec.attempts >= kMaxBazaarVerifyAttempts) {
          // سقف تلاش پر شده | رکورد برای پیگیری پشتیبانی میماند.
          continue;
        }
        if (rec.credited) {
          // سرور قبلاً ثبتش کرده | فقط consume دوباره تلاش میشود تا قفل
          // بازار باز شود؛ verify تکراری حذف شد تا شمارش دوباره انجام نشود.
          final bool consumed = await _consume(rec.token);
          if (consumed) {
            queue.remove(rec.token);
            removedTokens.add(rec.token);
          }
          rec.attempts += 1;
          changed = true;
          continue;
        }
        final _VerifyOutcome outcome = await _verifyPurchase(rec);
        if (outcome.credited) {
          // فقط وقتی consume تأیید شد رکورد پاک میشود؛ وگرنه برای بازکردن
          // قفل بازار در اجرای بعدی میماند.
          rec.credited = true;
          if (outcome.creditedOrderId > 0) {
            rec.wcOrderId = outcome.creditedOrderId;
          }
          final bool consumed = await _consume(rec.token);
          if (consumed) {
            queue.remove(rec.token);
            removedTokens.add(rec.token);
          }
          rec.attempts += 1;
          changed = true;
        } else if (outcome.retryable) {
          rec.attempts += 1;
          changed = true;
        } else {
          // رد قطعی سرور | دوباره تلاش نکن.
          rec.attempts = kMaxBazaarVerifyAttempts;
          changed = true;
        }
      }
      if (changed) {
        // نوشتن صف از طریق mutex | حذفهای این دور هم روی وضعیت دیسک اعمال
        // میشود تا نوشتن همزمان _queue بازنویسی نشود.
        await _withQueueMutex(() async {
          final Map<String, PendingBazaarPurchase> disk = await _loadQueue();
          for (final PendingBazaarPurchase rec in queue.values) {
            disk[rec.token] = rec;
          }
          for (final String token in removedTokens) {
            disk.remove(token);
          }
          await _saveQueue(disk);
        });
      }
    } finally {
      _recoveryRunning = false;
    }
  }

  Future<bool> _consume(String token) async {
    if (token.isEmpty) {
      return false;
    }
    try {
      return await poolakey.FlutterPoolakey.consume(token);
    } catch (e) {
      // consume ناموفق: توکن در انبار بازار می‌ماند و در اجرای بعدی دوباره
      // پیدا و consume می‌شود.
      debugPrint('bazaar: consume failed $e');
      return false;
    }
  }

  /// تسویهٔ خرید مستقیماً از دارت | POST {apiBase}payment/bazaar/verify.
  Future<_VerifyOutcome> _verifyPurchase(PendingBazaarPurchase rec) async {
    final Uri? url = _verifyUrl;
    if (url == null) {
      return const _VerifyOutcome(credited: false, retryable: false);
    }
    try {
      final HttpClient client = _client ??= HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final HttpClientRequest request =
          await client.postUrl(url).timeout(const Duration(seconds: 20));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(jsonEncode(<String, dynamic>{
        'sku': rec.sku,
        'purchase_token': rec.token,
        'order_id': rec.orderId,
        'package_name': rec.packageName,
        'payload': rec.payload,
      }));
      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 20));
      final String body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return const _VerifyOutcome(credited: false, retryable: true);
      }
      final Object? decoded = jsonDecode(body);
      final bool success =
          decoded is Map<String, dynamic> && decoded['success'] == true;
      final int wcOrderId = decoded is Map<String, dynamic>
          ? ((decoded['order_id'] as num?)?.toInt() ?? 0)
          : 0;
      return _VerifyOutcome(
        credited: success,
        retryable: !success,
        creditedOrderId: wcOrderId,
      );
    } catch (e) {
      debugPrint('bazaar: verify transport error $e');
      return const _VerifyOutcome(credited: false, retryable: true);
    }
  }

  Future<Map<String, PendingBazaarPurchase>> _loadQueue() async {    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(kPrefsPendingBazaarPurchases);
    if (raw == null || raw.isEmpty) {
      return <String, PendingBazaarPurchase>{};
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <String, PendingBazaarPurchase>{};
      }
      final Map<String, PendingBazaarPurchase> queue =
          <String, PendingBazaarPurchase>{};
      for (final Object? entry in decoded) {
        if (entry is! Map) {
          continue;
        }
        final PendingBazaarPurchase rec =
            PendingBazaarPurchase.fromMap(Map<String, dynamic>.from(entry));
        if (rec.token.isNotEmpty) {
          queue[rec.token] = rec;
        }
      }
      return queue;
    } catch (e) {
      // رکورد ناسازگار کل صف را نمی‌بازاند؛ صف خالی شروع می‌شود و انبار
      // خود بازار در recoverPurchases جبران می‌کند.
      debugPrint('bazaar: pending queue unreadable $e');
      return <String, PendingBazaarPurchase>{};
    }
  }

  Future<void> _saveQueue(Map<String, PendingBazaarPurchase> queue) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (queue.isEmpty) {
      await prefs.remove(kPrefsPendingBazaarPurchases);
      return;
    }
    final String raw = jsonEncode(
      queue.values.map((PendingBazaarPurchase rec) => rec.toMap()).toList(),
    );
    await prefs.setString(kPrefsPendingBazaarPurchases, raw);
  }

  Future<void> _queue(PendingBazaarPurchase rec) async {
    // نوشتن از طریق mutex | با بازیابی همزمان رکورد یکدیگر بازنویسی نمیشود.
    await _withQueueMutex(() async {
      final Map<String, PendingBazaarPurchase> queue = await _loadQueue();
      queue[rec.token] = rec;
      await _saveQueue(queue);
    });
  }

  /// تسویهٔ صریح توکن برای چکاوت نیتیو | recovery را صدا میزند و نتیجهٔ
  /// ثبت سرور (و شناسهٔ سفارش ووکامرس) را برمیگرداند.
  Future<BazaarSettlement> settleAndWait(String token) async {
    await recoverPurchases();
    final Map<String, PendingBazaarPurchase> queue = await _loadQueue();
    final PendingBazaarPurchase? rec = queue[token];
    if (rec == null) {
      // مصرف و پاک شده | یعنی سرور ثبت کرده است.
      return const BazaarSettlement(credited: true);
    }
    return BazaarSettlement(credited: rec.credited, orderId: rec.wcOrderId);
  }
}
