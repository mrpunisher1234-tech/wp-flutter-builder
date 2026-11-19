import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';
import 'native_mode.dart';
import 'skeleton.dart';

/// پیام خطای فارسی سرور | برای اسنک‌بار صفحهٔ سفارش‌ها.
class _OrderApiException implements Exception {
  const _OrderApiException(this.message);

  final String message;
}

/// سفارش‌های من | فهرست و جزئیات سفارش‌های همان شمارهٔ موبایلی که کاربر با آن
/// وارد شده است. هویت از توکن ورود می‌آید (کلید prefs: wptf_auth_token) و سرور
/// سفارش‌ها را با همان شمارهٔ صورتحساب پیدا می‌کند.

/// خلاصهٔ یک سفارش | همان کلیدهایی که اندپوینت /orders برمی‌گرداند.
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.number,
    required this.status,
    required this.statusLabel,
    required this.dateLabel,
    required this.total,
    required this.itemsCount,
    required this.thumbnails,
    this.orderKey = '',
  });

  final int id;
  final String number;
  final String status;
  final String statusLabel;
  final String dateLabel;
  final String total;
  final int itemsCount;
  final List<String> thumbnails;

  /// کارت ۱۷ | کلید سفارش | برای استعلام وضعیت و پرداخت دوباره | خالی یعنی
  /// سرور قدیمی است و استعلام اول حذف میشود (سرور خودش دوباره چک میکند).
  final String orderKey;

  static String _text(dynamic value) => ((value as String?) ?? '').trim();

  /// مبالغ ووکامرس ممکن است اعشار داشته باشند («1320000.00»)؛ formatToman
  /// هر رقم غیرعددی را دور می‌ریزد و اعشار را صد برابر بزرگ می‌کرد، پس اینجا بریده می‌شود.
  static String _money(dynamic value) => _text(value).split('.').first;

  static List<String> _urls(dynamic raw) => (raw is List ? raw : const <dynamic>[])
      .map((dynamic item) => AppConfig.mapEmulatorUrl(_text(item)))
      .where((String url) => url.isNotEmpty)
      .toList(growable: false);

  factory OrderSummary.fromMap(Map<String, dynamic> map) {
    return OrderSummary(
      id: (map['id'] as num?)?.toInt() ?? 0,
      number: _text(map['number']),
      status: _text(map['status']),
      statusLabel: _text(map['status_label']),
      dateLabel: _text(map['date_label']),
      total: _money(map['total']),
      itemsCount: (map['items_count'] as num?)?.toInt() ?? 0,
      thumbnails: _urls(map['thumbnails']),
      orderKey: _text(map['order_key']),
    );
  }
}

/// یک قلم از سفارش.
class OrderLine {
  const OrderLine({
    required this.name,
    required this.quantity,
    required this.lineTotal,
    required this.thumbnail,
  });

  final String name;
  final int quantity;
  final String lineTotal;
  final String thumbnail;

  factory OrderLine.fromMap(Map<String, dynamic> map) {
    return OrderLine(
      name: OrderSummary._text(map['name']),
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      lineTotal: OrderSummary._money(map['line_total']),
      thumbnail: AppConfig.mapEmulatorUrl(OrderSummary._text(map['thumbnail'])),
    );
  }
}

/// آدرس صورتحساب یا ارسال.
class OrderAddress {
  const OrderAddress({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.address1,
    required this.address2,
    required this.city,
    required this.state,
    required this.postcode,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String address1;
  final String address2;
  final String city;
  final String state;
  final String postcode;

  bool get isEmpty =>
      address1.isEmpty && city.isEmpty && phone.isEmpty && firstName.isEmpty;

  /// آدرس در یک خط، برای نمایش ساده.
  String get summary {
    final List<String> parts = <String>[
      '$firstName $lastName'.trim(),
      address1,
      address2,
      city,
      state,
      postcode,
    ].where((String part) => part.trim().isNotEmpty).toList(growable: false);
    return parts.join('، ');
  }

  factory OrderAddress.fromMap(Map<String, dynamic> map) {
    return OrderAddress(
      firstName: OrderSummary._text(map['first_name']),
      lastName: OrderSummary._text(map['last_name']),
      phone: OrderSummary._text(map['phone']),
      address1: OrderSummary._text(map['address_1']),
      address2: OrderSummary._text(map['address_2']),
      city: OrderSummary._text(map['city']),
      state: OrderSummary._text(map['state']),
      postcode: OrderSummary._text(map['postcode']),
    );
  }
}

/// جزئیات کامل یک سفارش | خلاصه + اقلام + آدرس‌ها + جمع فاکتور.
class OrderDetail {
  const OrderDetail({
    required this.summary,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.shippingTotal,
    required this.paymentMethod,
    required this.customerNote,
    required this.billing,
    required this.shipping,
  });

  final OrderSummary summary;
  final List<OrderLine> items;
  final String subtotal;
  final String discount;
  final String shippingTotal;
  final String paymentMethod;
  final String customerNote;
  final OrderAddress billing;
  final OrderAddress shipping;

  factory OrderDetail.fromMap(Map<String, dynamic> map) {
    return OrderDetail(
      summary: OrderSummary.fromMap(map),
      items: (map['items'] is List ? map['items'] as List<dynamic> : const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(OrderLine.fromMap)
          .toList(growable: false),
      subtotal: OrderSummary._money(map['subtotal']),
      discount: OrderSummary._money(map['discount']),
      shippingTotal: OrderSummary._money(map['shipping_total']),
      paymentMethod: OrderSummary._text(map['payment_method']),
      customerNote: OrderSummary._text(map['customer_note']),
      billing: OrderAddress.fromMap(
        map['billing'] is Map<String, dynamic>
            ? map['billing'] as Map<String, dynamic>
            : const <String, dynamic>{},
      ),
      shipping: OrderAddress.fromMap(
        map['shipping'] is Map<String, dynamic>
            ? map['shipping'] as Map<String, dynamic>
            : const <String, dynamic>{},
      ),
    );
  }
}

/// رنگ و برچسب چیپ وضعیت | ووکامرس برچسب فارسی را خودش می‌دهد و اینجا فقط رنگ می‌شود.
class OrderStatusStyle {
  const OrderStatusStyle(this.background, this.foreground);

  final Color background;
  final Color foreground;

  static OrderStatusStyle of(String status) {
    switch (status) {
      case 'completed':
        return const OrderStatusStyle(Color(0xFFEAF7EC), Dk.success);
      case 'processing':
        return const OrderStatusStyle(Color(0xFFEAF1FE), Color(0xFF1D4ED8));
      case 'on-hold':
        return const OrderStatusStyle(Color(0xFFFFF6E5), Color(0xFF9A6A00));
      case 'cancelled':
      case 'failed':
        return const OrderStatusStyle(Color(0xFFFDECEF), Dk.discount);
      default:
        return const OrderStatusStyle(Color(0xFFF2F3F5), Dk.text2);
    }
  }
}

/// صفحهٔ فهرست سفارش‌ها | با اسکرول بی‌نهایت، مثل بقیهٔ لیست‌های اپ.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, required this.config});

  final AppConfig config;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final List<OrderSummary> _orders = <OrderSummary>[];

  // کارت ۱۷ | سفارشی که همین الان در جریان پرداخت دوباره است.
  int? _payingOrderId;

  // تنظیم ۱۴ | تعداد سفارشات در هر صفحه از کانفیگ ادمین میآید (۵ تا ۵۰).
  int get _pageSize => widget.config.ordersPerPage.clamp(5, 50);

  int _page = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  bool _needsLogin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_autoFillViewport);
    _fetchOrders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  /// کارت ۱۷ | بازگشت از مرورگر بانک | فهرست بی‌صدا تازه میشود تا وضعیت
  /// سفارش بهروز شود | موفقیت کامل خودش صفحهٔ نتیجه را باز میکند.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.config.pendingOrderPayEnabled &&
        !_isLoading &&
        !_needsLogin) {
      _fetchOrders(silent: true);
    }
  }

  /// نزدیک شدن به انتهای لیست، صفحهٔ بعدی را می‌آورد و اگر صفحه کوتاه بود
  /// همان‌جا لیست را پر می‌کند تا کاربر با فهرست نیمه‌خالی روبه‌رو نشود.
  void _autoFillViewport() {
    if (!_scrollController.hasClients) return;
    if (_isLoadingMore || _isLoading) return;
    if (_scrollController.position.extentAfter >= 400) return;
    if (_hasMore) {
      _fetchOrders(loadMore: true);
    }
  }

  Future<String?> _authToken() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('wptf_auth_token');
      return token == null || token.isEmpty ? null : token;
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchOrders({bool loadMore = false, bool silent = false}) async {
    if (loadMore) {
      if (_isLoadingMore || !_hasMore || _isLoading) return;
      setState(() => _isLoadingMore = true);
    } else if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
        _needsLogin = false;
      });
    }

    final int nextPage = loadMore ? _page + 1 : 1;
    HttpClient? client;

    try {
      final String? token = await _authToken();
      if (token == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _needsLogin = true;
        });
        return;
      }

      client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final HttpClientRequest request = await client.postUrl(
        Uri.parse('${widget.config.effectiveApiBaseUrl}orders'),
      );
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(jsonEncode(<String, dynamic>{
        'auth_token': token,
        'page': nextPage,
        'per_page': _pageSize,
      }));
      final HttpClientResponse response = await request.close();

      if (response.statusCode == 401) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _needsLogin = true;
        });
        return;
      }
      if (response.statusCode != 200) {
        throw const HttpException('bad status');
      }

      final String body = await response.transform(utf8.decoder).join();
      final dynamic decoded = jsonDecode(body);
      final List<dynamic> rawItems = decoded is Map<String, dynamic> && decoded['items'] is List
          ? decoded['items'] as List<dynamic>
          : const <dynamic>[];
      final List<OrderSummary> page = rawItems
          .whereType<Map<String, dynamic>>()
          .map(OrderSummary.fromMap)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _orders.addAll(page);
          _page = nextPage;
        } else {
          _orders
            ..clear()
            ..addAll(page);
          _page = 1;
        }
        final int totalPages =
            (decoded is Map<String, dynamic>
                ? (decoded['pages'] as num?)?.toInt()
                : null) ??
            0;
        _hasMore = _page < totalPages;
        _isLoading = false;
        _isLoadingMore = false;
      });

      if (!loadMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _autoFillViewport());
      }
    } catch (_) {
      if (!mounted) return;
      if (silent) {
        // تازه‌سازی بی‌صدا | خطا لیست فعلی را نمی‌ریزد و صفحه‌بندی نمی‌شکند.
        _isLoadingMore = false;
        return;
      }
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        if (!loadMore) {
          _error = 'خطا در دریافت سفارش‌ها';
          _hasMore = false;
        }
        // خطای گذرای «بیشتر» | _hasMore برقرار می‌ماند تا اسکرول بعدی دوباره
        // تلاش کند و بقیهٔ صفحات از دست نروند.
      });
    } finally {
      client?.close(force: true);
    }
  }

  void _openDetail(OrderSummary order) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailScreen(config: widget.config, order: order),
      ),
    );
  }

  /// کارت ۱۷ | آیا روی این سفارش دکمهٔ پرداخت دوباره نمایش داده شود؟
  bool _canPayAgain(OrderSummary order) =>
      widget.config.pendingOrderPayEnabled && order.status == 'pending';

  /// پیام‌های صفحه سفارش‌ها | اسنک‌بار سیاه/سفید.
  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// POST JSON به REST افزونه | پیام فارسی سرور بیرون پرتاب میشود.
  Future<Map<String, dynamic>> _postJson(
    HttpClient client,
    String path,
    Map<String, dynamic> payload,
  ) async {
    final HttpClientRequest request = await client
        .postUrl(Uri.parse('${widget.config.effectiveApiBaseUrl}$path'))
        .timeout(const Duration(seconds: 15));
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.write(jsonEncode(payload));
    final HttpClientResponse response = await request.close().timeout(
      const Duration(seconds: 15),
    );
    final String raw = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 15));
    final dynamic decoded = jsonDecode(raw);
    if (response.statusCode != 200 || decoded is! Map<String, dynamic>) {
      throw _OrderApiException(
        decoded is Map<String, dynamic> && decoded['message'] is String
            ? decoded['message'] as String
            : 'خطا در ارتباط با سایت',
      );
    }
    return decoded;
  }

  /// کارت ۱۷ | پرداخت دوبارهٔ سفارش معلق | اول استعلام وضعیت، بعد درگاه |
  /// بازگشت موفق با دیپ‌لینک خودش صفحهٔ نتیجه را باز میکند.
  Future<void> _payAgain(OrderSummary order) async {
    if (_payingOrderId != null || order.status != 'pending') return;
    setState(() => _payingOrderId = order.id);
    HttpClient? client;
    try {
      final String? token = await _authToken();
      if (token == null) {
        _notice('برای پرداخت دوباره ابتدا وارد حساب شوید');
        return;
      }
      client = HttpClient()..connectionTimeout = const Duration(seconds: 10);

      // ۱) استعلام وضعیت | سفارش پرداختشده هرگز دوباره به درگاه نمیرود.
      if (order.orderKey.isNotEmpty) {
        final Map<String, dynamic> status = await _postJson(
          client,
          'payment/order-status',
          <String, dynamic>{'order_id': order.id, 'order_key': order.orderKey},
        );
        if (status['paid'] == true) {
          await _fetchOrders(silent: true);
          _notice('این سفارش قبلاً پرداخت شده است | فهرست به‌روزرسانی شد');
          return;
        }
      }

      // ۲) لینک پرداخت دوباره | سرور مالکیت و needs_payment را دوباره چک میکند.
      final Map<String, dynamic> payment = await _postJson(
        client,
        'payment/retry',
        <String, dynamic>{'auth_token': token, 'order_id': order.id},
      );
      if (payment['already_paid'] == true) {
        await _fetchOrders(silent: true);
        _notice('این سفارش قبلاً پرداخت شده است | فهرست به‌روزرسانی شد');
        return;
      }
      final String paymentUrl = AppConfig.mapEmulatorUrl(
        ((payment['payment_url'] as String?) ?? '').trim(),
      );
      if (paymentUrl.isEmpty) {
        throw const HttpException('empty payment url');
      }

      // ۳) صفحه امن بانک | همان الگوی تسویه‌حساب | Custom Tab وگرنه مرورگر بیرونی.
      final Uri gatewayUri = Uri.parse(paymentUrl);
      bool opened = false;
      try {
        opened = await launchUrl(gatewayUri, mode: LaunchMode.inAppBrowserView);
      } catch (_) {
        opened = false;
      }
      if (!opened) {
        try {
          opened = await launchUrl(
            gatewayUri,
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {
          opened = false;
        }
      }
      _notice(
        opened
            ? 'صفحه پرداخت باز شد | پس از پرداخت به اپ برمی‌گردید'
            : 'صفحه پرداخت باز نشد | دوباره تلاش کنید',
      );
    } on _OrderApiException catch (error) {
      _notice(error.message);
    } catch (_) {
      _notice('خطا در ارتباط با سایت');
    } finally {
      client?.close(force: true);
      if (mounted) {
        setState(() => _payingOrderId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Dk.canvas,
        appBar: AppBar(
          title: const Text(
            'سفارش‌های من',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Dk.text1),
          ),
          elevation: 0.5,
          backgroundColor: Colors.white,
          foregroundColor: Dk.text1,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_needsLogin) {
      return _OrdersEmptyState(
        icon: Icons.lock_outline,
        title: 'برای دیدن سفارش‌ها وارد حساب شوید',
        subtitle: 'با شماره موبایل خود وارد شوید تا سفارش‌هایتان اینجا نمایش داده شود.',
      );
    }
    if (_isLoading) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: List<Widget>.generate(
          4,
          (int index) => const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: SkeletonBox(height: 118, radius: 10),
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.config.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _fetchOrders(),
              child: const Text('تلاش مجدد'),
            ),
          ],
        ),
      );
    }
    if (_orders.isEmpty) {
      return _OrdersEmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'هنوز سفارشی ثبت نکرده‌اید',
        subtitle: 'بعد از ثبت اولین خرید، وضعیت سفارش‌هایتان همین‌جا قابل پیگیری است.',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _orders.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (index >= _orders.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }
        final OrderSummary order = _orders[index];
        return _OrderCard(
          order: order,
          primaryColor: widget.config.primaryColor,
          onTap: () => _openDetail(order),
          onPayAgain: _canPayAgain(order) ? () => _payAgain(order) : null,
          payBusy: _payingOrderId == order.id,
          payLocked: _payingOrderId != null && _payingOrderId != order.id,
        );
      },
    );
  }
}

/// کارت یک سفارش در فهرست.
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.primaryColor,
    required this.onTap,
    this.onPayAgain,
    this.payBusy = false,
    this.payLocked = false,
  });

  final OrderSummary order;
  final Color primaryColor;
  final VoidCallback onTap;

  /// کارت ۱۷ | فقط برای سفارش pending و وقتی تنظیم ادمین روشن باشد مقدار دارد.
  final VoidCallback? onPayAgain;

  /// اسپینر فقط روی سفارشِ در جریان پرداخت | بقیه فقط قفل میشوند.
  final bool payBusy;
  final bool payLocked;

  @override
  Widget build(BuildContext context) {
    final OrderStatusStyle style = OrderStatusStyle.of(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Dk.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'سفارش #${toPersianDigits(order.number)}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Dk.text1,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: style.background,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      order.statusLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: style.foreground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  _OrderThumbnails(urls: order.thumbnails),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      order.itemsCount > 0
                          ? '${toPersianDigits('${order.itemsCount}')} کالا'
                          : '',
                      style: const TextStyle(fontSize: 12.5, color: Dk.text3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Dk.border),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      order.dateLabel,
                      style: const TextStyle(fontSize: 12, color: Dk.text3),
                    ),
                  ),
                  Text(
                    formatToman(order.total),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: Dk.text1,
                    ),
                  ),
                ],
              ),
              if (onPayAgain != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: (payBusy || payLocked) ? null : onPayAgain,
                      child: payBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('پرداخت دوباره'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// حداکثر چهار بندانگشتی اقلام سفارش | در نبود تصویر، جای خالی نشان داده نمی‌شود.
class _OrderThumbnails extends StatelessWidget {
  const _OrderThumbnails({required this.urls});

  final List<String> urls;

  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: Dk.surface2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.shopping_bag_outlined, size: 20, color: Dk.text4),
      );
    }

    return SizedBox(
      height: _size,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: urls
            .map(
              (String url) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    width: _size,
                    height: _size,
                    fit: BoxFit.cover,
                    errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
                      return Container(
                        width: _size,
                        height: _size,
                        color: Dk.surface2,
                        child: const Icon(Icons.image_not_supported_outlined,
                            size: 18, color: Dk.text4),
                      );
                    },
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

/// صفحهٔ جزئیات سفارش | اقلام، آدرس و جمع فاکتور.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.config, required this.order});

  final AppConfig config;
  final OrderSummary order;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderDetail? _detail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    HttpClient? client;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('wptf_auth_token') ?? '';
      if (token.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = 'برای دیدن جزئیات سفارش وارد حساب شوید.';
        });
        return;
      }

      client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final HttpClientRequest request = await client.postUrl(
        Uri.parse('${widget.config.effectiveApiBaseUrl}orders/detail'),
      );
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(jsonEncode(<String, dynamic>{
        'auth_token': token,
        'order_id': widget.order.id,
      }));
      final HttpClientResponse response = await request.close();

      if (response.statusCode != 200) {
        throw const HttpException('bad status');
      }

      final String body = await response.transform(utf8.decoder).join();
      final dynamic decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const HttpException('bad payload');
      }

      if (!mounted) return;
      setState(() {
        _detail = OrderDetail.fromMap(decoded);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'خطا در دریافت جزئیات سفارش';
      });
    } finally {
      client?.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Dk.canvas,
        appBar: AppBar(
          title: Text(
            'سفارش #${toPersianDigits(widget.order.number)}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Dk.text1),
          ),
          elevation: 0.5,
          backgroundColor: Colors.white,
          foregroundColor: Dk.text1,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          const SkeletonBox(height: 90, radius: 10),
          const SizedBox(height: 10),
          const SkeletonBox(height: 160, radius: 10),
          const SizedBox(height: 10),
          const SkeletonBox(height: 130, radius: 10),
        ],
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.config.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: _fetchDetail,
              child: const Text('تلاش مجدد'),
            ),
          ],
        ),
      );
    }

    final OrderDetail? detail = _detail;
    if (detail == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _SectionCard(
          title: 'وضعیت سفارش',
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  detail.summary.dateLabel,
                  style: const TextStyle(fontSize: 12.5, color: Dk.text2),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: OrderStatusStyle.of(detail.summary.status).background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  detail.summary.statusLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: OrderStatusStyle.of(detail.summary.status).foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (detail.items.isNotEmpty)
          _SectionCard(
            title: 'اقلام سفارش',
            child: Column(
              children: detail.items
                  .map(
                    (OrderLine line) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: line.thumbnail.isEmpty
                                ? Container(
                                    width: 52,
                                    height: 52,
                                    color: Dk.surface2,
                                    child: const Icon(Icons.image_outlined,
                                        size: 20, color: Dk.text4),
                                  )
                                : Image.network(
                                    line.thumbnail,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    errorBuilder: (BuildContext context, Object error,
                                        StackTrace? stack) {
                                      return Container(
                                        width: 52,
                                        height: 52,
                                        color: Dk.surface2,
                                        child: const Icon(Icons.image_outlined,
                                            size: 20, color: Dk.text4),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  line.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Dk.text1,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${toPersianDigits('${line.quantity}')} عدد',
                                  style: const TextStyle(fontSize: 12, color: Dk.text3),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatToman(line.lineTotal),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Dk.text1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        _SectionCard(
          title: 'جزئیات پرداخت',
          child: Column(
            children: <Widget>[
              _InvoiceRow(label: 'جمع کالاها', value: formatToman(detail.subtotal)),
              if (detail.discount != '0' && detail.discount.isNotEmpty)
                _InvoiceRow(
                  label: 'تخفیف',
                  value: '- ${formatToman(detail.discount)}',
                  highlight: Dk.discount,
                ),
              if (detail.shippingTotal != '0' && detail.shippingTotal.isNotEmpty)
                _InvoiceRow(
                  label: 'هزینه ارسال',
                  value: formatToman(detail.shippingTotal),
                ),
              const Divider(height: 20, color: Dk.border),
              _InvoiceRow(
                label: 'مبلغ کل',
                value: formatToman(detail.summary.total),
                strong: true,
              ),
              if (detail.paymentMethod.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text('روش پرداخت',
                          style: TextStyle(fontSize: 12.5, color: Dk.text3)),
                    ),
                    Text(
                      detail.paymentMethod,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Dk.text1,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (!detail.shipping.isEmpty || !detail.billing.isEmpty)
          _SectionCard(
            title: 'آدرس تحویل',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  (detail.shipping.isEmpty ? detail.billing : detail.shipping).summary,
                  style: const TextStyle(fontSize: 12.5, color: Dk.text2, height: 1.9),
                ),
                if (!detail.shipping.isEmpty &&
                    detail.shipping.phone.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    'شماره تماس: ${toPersianDigits(detail.shipping.phone)}',
                    style: const TextStyle(fontSize: 12.5, color: Dk.text3),
                  ),
                ],
              ],
            ),
          ),
        if (detail.customerNote.isNotEmpty)
          _SectionCard(
            title: 'یادداشت سفارش',
            child: Text(
              detail.customerNote,
              style: const TextStyle(fontSize: 12.5, color: Dk.text2, height: 1.9),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// کارت سفید بخش‌دار | همان زبان بصری بقیهٔ صفحات.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Dk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: Dk.text1,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// یک ردیف فاکتور | برچسب راست، مبلغ چپ.
class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.label,
    required this.value,
    this.strong = false,
    this.highlight,
  });

  final String label;
  final String value;
  final bool strong;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: strong ? 13.5 : 12.5,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                color: strong ? Dk.text1 : Dk.text3,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: strong ? 14 : 13,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              color: highlight ?? Dk.text1,
            ),
          ),
        ],
      ),
    );
  }
}

/// حالت خالی و حالت نیاز به ورود | دایره + آیکون + متن، مثل حالت خالی سبد خرید.
class _OrdersEmptyState extends StatelessWidget {
  const _OrdersEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Dk.surface2,
                shape: BoxShape.circle,
                border: Border.all(color: Dk.border),
              ),
              child: Icon(icon, size: 48, color: Dk.text4),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Dk.text1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Dk.text3, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
