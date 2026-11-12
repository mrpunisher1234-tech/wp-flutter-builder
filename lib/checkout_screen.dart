import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'addresses_screen.dart' show Province, UserAddress, latinDigits, normalizePhone;
import 'cart_screen.dart';
import 'main.dart';
import 'native_mode.dart';

/// خطای API با پیام فارسی قابل نمایش | سرور پیام واقعی برمیگرداند.
class WptfApiException implements Exception {
  WptfApiException(this.message);

  final String message;
}

/// تسویه‌حساب کاملاً نیتیو | فرم تحویل + کد تخفیف + فاکتور + اتصال درگاه.
/// کل فرآیند داخل اپ است و فقط صفحه امن خودِ درگاه در مرورگر گوشی باز میشود.
/// پس از پرداخت، دیپ‌لینک (wptoflutter://payment-result) کاربر را به اپ برمیگرداند.
class NativeCheckoutScreen extends StatefulWidget {
  const NativeCheckoutScreen({super.key, required this.config});

  final AppConfig config;

  @override
  State<NativeCheckoutScreen> createState() => _NativeCheckoutScreenState();
}

class _NativeCheckoutScreenState extends State<NativeCheckoutScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _postcode = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _coupon = TextEditingController();
  final TextEditingController _provinceText = TextEditingController();

  final List<Province> _provinces = <Province>[];
  String _stateCode = '';

  bool _applyingCoupon = false;
  bool _submitting = false;
  String? _appliedCode;
  int _discountAmount = 0;
  // سفارش ناتمام همین نشست | اگر درخواست پرداخت شکست بخورد، تلاش بعدی
  // سفارش pending تکراری نمی‌سازد و همان سفارش را دوباره استفاده می‌کند.
  int? _pendingOrderId;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    _address.dispose();
    _postcode.dispose();
    _note.dispose();
    _coupon.dispose();
    _provinceText.dispose();
    super.dispose();
  }

  /// پیش‌پر کردن فرم | اگر کاربر وارد شده باشد آدرس پیش‌فرض + لیست استانها میآید.
  Future<void> _prefill() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _name.text = prefs.getString('wptf_user_name') ?? '';
      _phone.text = prefs.getString('wptf_user_phone') ?? '';

      final String? token = prefs.getString('wptf_auth_token');
      if (token == null || token.isEmpty) {
        return;
      }

      HttpClient? client;
      try {
        client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
        final HttpClientRequest request = await client.postUrl(
          Uri.parse('${widget.config.effectiveApiBaseUrl}addresses'),
        );
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        request.write(jsonEncode(<String, dynamic>{'auth_token': token}));
        final HttpClientResponse response = await request.close();
        final String raw = await response.transform(utf8.decoder).join();
        final dynamic decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic> || !mounted) return;

        final List<dynamic> provinces =
            decoded['provinces'] is List ? decoded['provinces'] as List<dynamic> : const <dynamic>[];
        _provinces
          ..clear()
          ..addAll(provinces
              .whereType<Map<String, dynamic>>()
              .map(Province.fromMap));

        final List<dynamic> items =
            decoded['items'] is List ? decoded['items'] as List<dynamic> : const <dynamic>[];
        UserAddress? defaultAddress;
        for (final dynamic row in items) {
          if (row is Map<String, dynamic> && row['is_default'] == true) {
            defaultAddress = UserAddress.fromMap(row);
            break;
          }
        }
        defaultAddress ??= items.isNotEmpty && items.first is Map<String, dynamic>
            ? UserAddress.fromMap(items.first as Map<String, dynamic>)
            : null;

        if (defaultAddress != null) {
          _city.text = defaultAddress.city;
          _address.text = defaultAddress.address1;
          _postcode.text = defaultAddress.postcode;
          if (_name.text.trim().isEmpty) {
            _name.text = defaultAddress.fullName;
          }
          if (_phone.text.trim().isEmpty) {
            _phone.text = defaultAddress.phone;
          }
          final bool knownState = _provinces
              .any((Province province) => province.code == defaultAddress!.state);
          if (knownState) {
            _stateCode = defaultAddress.state;
          }
        }
      } finally {
        client?.close(force: true);
      }
    } catch (_) {
      // پیش‌پر کردن اختیاری است | خطا فرم را نمیبندد.
    }
  }

  /// جمع اقلام با قیمت حراج | همان منطق سبد خرید.
  int get _subtotal => CartManager.instance.totalPrice;

  /// هزینه ارسال از تنظیم ۱۴ | صفر یعنی ارسال رایگان.
  int get _shipping => widget.config.defaultShippingCost;

  int get _total {
    final int value = _subtotal + _shipping - _discountAmount;
    return value > 0 ? value : 0;
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// بررسی زندهٔ کد تخفیف | فاکتور بدون رفرش فرم بهروز میشود.
  Future<void> _applyCoupon() async {
    final String code = _coupon.text.trim();
    if (code.isEmpty) {
      _notice('کد تخفیف را وارد کنید');
      return;
    }
    setState(() => _applyingCoupon = true);
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final HttpClientRequest request = await client.postUrl(
        Uri.parse('${widget.config.effectiveApiBaseUrl}checkout/apply-coupon'),
      );
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(jsonEncode(<String, dynamic>{
        'coupon_code': code,
        'subtotal': _subtotal,
        'items': <Map<String, dynamic>>[
          for (final CartItem cartItem in CartManager.instance.items)
            <String, dynamic>{
              'product_id': cartItem.item.id,
              'quantity': cartItem.quantity,
            },
        ],
      }));
      final HttpClientResponse response = await request.close();
      final String raw = await response.transform(utf8.decoder).join();
      final dynamic decoded = jsonDecode(raw);
      if (!mounted) return;
      if (response.statusCode == 200 &&
          decoded is Map<String, dynamic> &&
          decoded['valid'] == true) {
        setState(() {
          _appliedCode = code;
          _discountAmount = (decoded['discount_amount'] as num?)?.toInt() ?? 0;
        });
        _notice((decoded['message'] as String?) ?? 'کد تخفیف اعمال شد');
      } else {
        setState(() {
          _appliedCode = null;
          _discountAmount = 0;
        });
        _notice(decoded is Map<String, dynamic> && decoded['message'] is String
            ? decoded['message'] as String
            : 'کد تخفیف نامعتبر است');
      }
    } catch (_) {
      if (!mounted) return;
      _notice('خطا در بررسی کد تخفیف');
    } finally {
      client?.close(force: true);
      if (mounted) {
        setState(() => _applyingCoupon = false);
      }
    }
  }

  /// ۱) ساخت سفارش رسمی ووکامرس | ۲) لینک درگاه | ۳) باز کردن مرورگر امن بانک.
  Future<void> _submitAndPay() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_submitting) {
      return;
    }
    setState(() => _submitting = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => const Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(strokeWidth: 2.5),
              SizedBox(height: 16),
              Text('در حال ثبت سفارش…', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );

    // قبل از هر await گرفته می‌شود تا بستن لودینگ حتی بعد از unmount هم امن
    // باشد و هیچ‌وقت دو بار pop نشود (پاپ دوم صفحهٔ چک‌اوت را می‌بست).
    final NavigatorState navigator = Navigator.of(context);
    bool dialogOpen = true;
    HttpClient? client;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('wptf_auth_token') ?? '';

      client = HttpClient()..connectionTimeout = const Duration(seconds: 10);

      // ۱) ساخت سفارش | قیمتها و موجودی از خود ووکامرس خوانده میشود.
      final int orderId = _pendingOrderId ?? await _createOrder(client, token);
      _pendingOrderId = orderId;

      // ۲) لینک درگاه | زرین‌پال StartPay.
      final String paymentUrl = await _requestPayment(client, orderId, token);

      if (dialogOpen) {
        dialogOpen = false;
        navigator.pop(); // بستن لودینگ
      }

      // ۳) صفحه امن بانک در مرورگر گوشی | بعد از پرداخت دیپ‌لینک به اپ برمیگردد.
      final Uri gatewayUri = Uri.parse(paymentUrl);
      if (await canLaunchUrl(gatewayUri)) {
        await launchUrl(gatewayUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(gatewayUri, mode: LaunchMode.platformDefault);
      }
      _notice('صفحه پرداخت باز شد | پس از پرداخت به اپ برمی‌گردید');
    } on WptfApiException catch (error) {
      if (dialogOpen) {
        dialogOpen = false;
        navigator.pop();
      }
      if (mounted) {
        _notice(error.message);
      }
    } catch (_) {
      if (dialogOpen) {
        dialogOpen = false;
        navigator.pop();
      }
      if (mounted) {
        _notice('خطا در ارتباط با سایت');
      }
    } finally {
      client?.close(force: true);
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<int> _createOrder(HttpClient client, String token) async {
    final HttpClientRequest request = await client.postUrl(
      Uri.parse('${widget.config.effectiveApiBaseUrl}checkout/create-order'),
    );
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.write(jsonEncode(<String, dynamic>{
      if (token.isNotEmpty) 'auth_token': token,
      'name': _name.text.trim(),
      'phone': normalizePhone(_phone.text),
      'province': _stateCode,
      'city': _city.text.trim(),
      'address_1': _address.text.trim(),
      'postcode': latinDigits(_postcode.text).replaceAll(RegExp(r'[^0-9]'), ''),
      'note': _note.text.trim(),
      if (widget.config.enableCoupons && _appliedCode != null)
        'coupon_code': _appliedCode,
      'items': <Map<String, dynamic>>[
        for (final CartItem cartItem in CartManager.instance.items)
          <String, dynamic>{
            'product_id': cartItem.item.id,
            'quantity': cartItem.quantity,
          },
      ],
    }));
    final HttpClientResponse response = await request.close();
    final String raw = await response.transform(utf8.decoder).join();
    final dynamic decoded = jsonDecode(raw);
    if (response.statusCode != 200 ||
        decoded is! Map<String, dynamic> ||
        decoded['success'] != true ||
        decoded['order_id'] is! num) {
      throw WptfApiException(
        decoded is Map<String, dynamic> && decoded['message'] is String
            ? decoded['message'] as String
            : 'ثبت سفارش ناموفق بود | دوباره تلاش کنید',
      );
    }
    return (decoded['order_id'] as num).toInt();
  }

  Future<String> _requestPayment(HttpClient client, int orderId, String token) async {
    final HttpClientRequest request = await client.postUrl(
      Uri.parse('${widget.config.effectiveApiBaseUrl}payment/request'),
    );
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.write(jsonEncode(<String, dynamic>{
      if (token.isNotEmpty) 'auth_token': token,
      'order_id': orderId,
    }));
    final HttpClientResponse response = await request.close();
    final String raw = await response.transform(utf8.decoder).join();
    final dynamic decoded = jsonDecode(raw);
    if (response.statusCode != 200 ||
        decoded is! Map<String, dynamic> ||
        decoded['success'] != true ||
        (decoded['payment_url'] as String?) == null) {
      throw WptfApiException(
        decoded is Map<String, dynamic> && decoded['message'] is String
            ? decoded['message'] as String
            : 'اتصال به درگاه ناموفق بود',
      );
    }
    return decoded['payment_url'] as String;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Dk.canvas,
        appBar: AppBar(
          title: const Text(
            'تسویه‌حساب و ثبت سفارش',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Dk.text1),
          ),
          elevation: 0.5,
          backgroundColor: Colors.white,
          foregroundColor: Dk.text1,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: <Widget>[
              _buildSectionTitle('مشخصات تحویل‌گیرنده'),
              const SizedBox(height: 10),
              _buildField(
                controller: _name,
                hint: 'نام و نام‌خانوادگی',
                maxLength: 60,
                validator: (String? value) =>
                    (value ?? '').trim().length < 2 ? 'نام را کامل وارد کنید' : null,
              ),
              const SizedBox(height: 10),
              _buildField(
                controller: _phone,
                hint: 'شماره موبایل',
                keyboardType: TextInputType.phone,
                maxLength: 14,
                validator: (String? value) {
                  final String phone = normalizePhone(value ?? '');
                  if (phone.length != 11 || !phone.startsWith('09')) {
                    return 'شماره موبایل معتبر نیست';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _buildProvinceCityRow(),
              const SizedBox(height: 10),
              _buildField(
                controller: _address,
                hint: 'نشانی کامل (خیابان، کوچه، پلاک، واحد)',
                maxLength: 500,
                maxLines: 3,
                validator: (String? value) =>
                    (value ?? '').trim().isEmpty ? 'نشانی را وارد کنید' : null,
              ),
              const SizedBox(height: 10),
              _buildField(
                controller: _postcode,
                hint: widget.config.requirePostcode
                    ? 'کد پستی ۱۰ رقمی'
                    : 'کد پستی (اختیاری)',
                keyboardType: TextInputType.number,
                maxLength: 10,
                validator: (String? value) {
                  final String digits =
                      latinDigits(value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                  if (widget.config.requirePostcode && digits.length != 10) {
                    return 'کد پستی ۱۰ رقمی الزامی است';
                  }
                  if (digits.isNotEmpty && digits.length != 10) {
                    return 'کد پستی باید ۱۰ رقم باشد';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _buildField(
                controller: _note,
                hint: widget.config.requireOrderNote
                    ? 'یادداشت سفارش (الزامی)'
                    : 'یادداشت سفارش (اختیاری)',
                maxLength: 200,
                maxLines: 2,
                validator: (String? value) =>
                    (widget.config.requireOrderNote && (value ?? '').trim().isEmpty)
                        ? 'یادداشت سفارش را وارد کنید'
                        : null,
              ),

              const SizedBox(height: 18),
              if (widget.config.enableCoupons) ...<Widget>[
                _buildSectionTitle('کد تخفیف'),
                const SizedBox(height: 10),
                _buildCouponRow(),
                const SizedBox(height: 18),
              ],

              _buildSectionTitle('سفارش شما'),
              const SizedBox(height: 10),
              _buildInvoice(),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Dk.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _submitting ? null : _submitAndPay,
                  child: Text(
                    _submitting ? 'در حال ثبت…' : 'ثبت و پرداخت آنلاین',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'پس از ثبت سفارش، صفحه امن پرداخت بانک در مرورگر گوشی باز می‌شود.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: Dk.text3, height: 1.8),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w800,
        color: Dk.text1,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int maxLength = 100,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      style: const TextStyle(fontSize: 13.5, color: Dk.text1),
      decoration: _decoration(hint),
      validator: validator,
    );
  }

  /// استان و شهر | استان از لیست ووکامرس (پیش‌پر از آدرس ذخیره‌شده).
  Widget _buildProvinceCityRow() {
    final Widget provinceField;
    if (_provinces.isEmpty) {
      provinceField = TextFormField(
        controller: _provinceText,
        onChanged: (String value) => _stateCode = value,
        decoration: _decoration('استان'),
        style: const TextStyle(fontSize: 13.5, color: Dk.text1),
        validator: (String? value) =>
            (value ?? '').trim().isEmpty && _stateCode.isEmpty ? 'استان را وارد کنید' : null,
      );
    } else {
      provinceField = DropdownButtonFormField<String>(
        initialValue: _provinces.any((Province province) => province.code == _stateCode)
            ? _stateCode
            : null,
        decoration: _decoration('استان'),
        style: const TextStyle(fontSize: 13.5, color: Dk.text1),
        items: _provinces
            .map((Province province) => DropdownMenuItem<String>(
                  value: province.code,
                  child: Text(province.name, style: const TextStyle(fontSize: 13.5)),
                ))
            .toList(growable: false),
        onChanged: (String? value) {
          if (value != null) {
            setState(() => _stateCode = value);
          }
        },
        validator: (String? value) =>
            (value == null || value.isEmpty) ? 'استان را انتخاب کنید' : null,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: 2, child: provinceField),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: _city,
            maxLength: 60,
            style: const TextStyle(fontSize: 13.5, color: Dk.text1),
            decoration: _decoration('شهر'),
            validator: (String? value) =>
                (value ?? '').trim().isEmpty ? 'شهر را وارد کنید' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildCouponRow() {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextFormField(
            controller: _coupon,
            maxLength: 40,
            enabled: _appliedCode == null,
            style: const TextStyle(fontSize: 13.5, color: Dk.text1),
            decoration: _decoration(_appliedCode == null
                ? 'کد تخفیف را وارد کنید'
                : 'کد فعال: $_appliedCode'),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _appliedCode == null ? Dk.text1 : Dk.discount,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _applyingCoupon
              ? null
              : () {
                  if (_appliedCode == null) {
                    _applyCoupon();
                    return;
                  }
                  // حذف کد اعمالشده | فاکتور بدون تخفیف میشود.
                  setState(() {
                    _appliedCode = null;
                    _discountAmount = 0;
                    _coupon.clear();
                  });
                },
          child: _applyingCoupon
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  _appliedCode == null ? 'اعمال' : 'حذف کد',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  /// حذف کد تخفیف اعمالشده | لمس دکمه در حالت فعال.
  Widget _buildInvoice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Dk.border),
      ),
      child: Column(
        children: <Widget>[
          _invoiceRow('جمع اقلام (${toPersianDigits('${CartManager.instance.totalCount}')} کالا)', formatToman('$_subtotal')),
          if (_shipping > 0) ...<Widget>[
            const SizedBox(height: 10),
            _invoiceRow('هزینه ارسال', formatToman('$_shipping')),
          ],
          if (_discountAmount > 0) ...<Widget>[
            const SizedBox(height: 10),
            _invoiceRow('تخفیف اعمال‌شده', '- ${formatToman('$_discountAmount')}', color: Dk.discount),
          ],
          const Divider(height: 20, color: Dk.border),
          _invoiceRow('مبلغ نهایی قابل پرداخت', formatToman('$_total'), bold: true),
        ],
      ),
    );
  }

  Widget _invoiceRow(String label, String value, {Color? color, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 13.5 : 12.5,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: bold ? Dk.text1 : Dk.text2,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 14.5 : 13,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: color ?? Dk.text1,
          ),
        ),
      ],
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      counterText: '',
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Dk.border),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
