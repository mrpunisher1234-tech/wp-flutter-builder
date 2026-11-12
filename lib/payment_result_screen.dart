import 'package:flutter/material.dart';

import 'main.dart';
import 'native_mode.dart';
import 'orders_screen.dart';

/// صفحه نتیجه پرداخت | مرورگرِ درگاه بعد از وریفای با دیپ‌لینک اینجا میآورد:
/// {scheme}://payment-result?status=success&order_id=..&ref_id=..
class PaymentResultScreen extends StatelessWidget {
  const PaymentResultScreen({super.key, required this.uri, required this.config});

  final Uri uri;
  final AppConfig config;

  bool get _success => (uri.queryParameters['status'] ?? '') == 'success';

  int get _orderId => int.tryParse(uri.queryParameters['order_id'] ?? '') ?? 0;

  String get _refId => (uri.queryParameters['ref_id'] ?? '').trim();

  String get _message => (uri.queryParameters['message'] ?? '').trim();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Dk.canvas,
        appBar: AppBar(
          title: Text(
            _success ? 'نتیجه پرداخت' : 'پرداخت ناموفق',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Dk.text1),
          ),
          elevation: 0.5,
          backgroundColor: Colors.white,
          foregroundColor: Dk.text1,
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: _success ? const Color(0xFFEAF7EC) : const Color(0xFFFDECEF),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _success ? Dk.success : Dk.discount,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _success ? Icons.check_rounded : Icons.close_rounded,
                    size: 52,
                    color: _success ? Dk.success : Dk.discount,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _success ? 'سفارش شما دریافت شد' : 'پرداخت انجام نشد',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Dk.text1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _success
                      ? 'سفارش شما آماده ارسال می‌باشد.'
                      : (_message.isNotEmpty
                          ? _message
                          : 'در صورت کسر مبلغ از حساب، تا ۷۲ ساعت آینده برمی‌گردد.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Dk.text3, height: 1.8),
                ),
                if (_success && _orderId > 0) ...<Widget>[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Dk.border),
                    ),
                    child: Column(
                      children: <Widget>[
                        Text(
                          'سفارش #${toPersianDigits('$_orderId')}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Dk.text1,
                          ),
                        ),
                        if (_refId.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            'کد رهگیری بانکی: ${toPersianDigits(_refId)}',
                            style: const TextStyle(fontSize: 12.5, color: Dk.text3),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                if (_success) ...<Widget>[
                  _bigButton(
                    label: 'مشاهده سوابق سفارشات',
                    background: config.primaryColor,
                    foreground: Colors.white,
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => OrdersScreen(config: config),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _bigButton(
                    label: 'بازگشت به فروشگاه',
                    background: Colors.white,
                    foreground: config.primaryColor,
                    onTap: () {
                      Navigator.of(context).popUntil(
                        (Route<dynamic> route) => route.isFirst,
                      );
                    },
                  ),
                ] else ...<Widget>[
                  _bigButton(
                    label: 'تلاش مجدد برای پرداخت',
                    background: config.primaryColor,
                    foreground: Colors.white,
                    onTap: () {
                      // بازگشت به صفحه تسویه‌حساب | سبد هنوز پاک نشده و سفارش هم pending است.
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bigButton({
    required String label,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 240,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: foreground == Colors.white ? Colors.transparent : background),
          ),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
