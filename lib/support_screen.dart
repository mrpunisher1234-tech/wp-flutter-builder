import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';
import 'native_mode.dart';
import 'addresses_screen.dart' show latinDigits, normalizePhone;

/// پشتیبانی و تماس با ما | اطلاعات فروشگاه (از تنظیم نیتیو ۱۲) + فرم شرح مشکل.
/// پیام‌ها روی سرور در wptf_support_messages ذخیره و در کارت ۱۲ ادمین نمایش داده می‌شوند.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.config});

  final AppConfig config;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _message;

  bool _sending = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
    _message = TextEditingController();
    _prefill();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  /// اگر کاربر وارد شده باشد، نام و موبایلش از قبل پر است.
  Future<void> _prefill() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      _name.text = prefs.getString('wptf_user_name') ?? '';
      _phone.text = prefs.getString('wptf_user_phone') ?? '';
    } catch (_) {}
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// تماس با فروشگاه | لمس شماره، شمارهگیر گوشی را با شماره آماده باز میکند.
  /// اگر دستگاه شمارهگیر نداشت (تبلت یا شبیهساز)، شماره کپی و اطلاع داده میشود.
  Future<void> _contactStore() async {
    final String phone = widget.config.supportStorePhone;
    if (phone.isEmpty) return;

    // شماره تمیز | فقط رقم و + تا tel: همیشه معتبر باشد.
    final String cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri telUri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {
      // شمارهگیر در دسترس نیست | در ادامه کپی میشود.
    }

    // فال‌بک | کپی شماره در حافظه گوشی.
    await Clipboard.setData(ClipboardData(text: phone));
    _notice('شماره تماس کپی شد: $phone');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _sending = true);

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final HttpClientRequest request = await client.postUrl(
        Uri.parse('${widget.config.effectiveApiBaseUrl}support/contact'),
      );
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(jsonEncode(<String, dynamic>{
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'message': _message.text.trim(),
      }));
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      final dynamic decoded = jsonDecode(body);

      if (!mounted) return;
      if (response.statusCode != 200 || decoded is! Map<String, dynamic>) {
        // دکمه آزاد میشود و پیام واقعی سرور (۴۰۰، ۴۲۹ و...) نشان داده میشود.
        setState(() => _sending = false);
        _notice(decoded is Map<String, dynamic> && decoded['message'] is String
            ? decoded['message'] as String
            : 'ارسال نشد | کمی بعد دوباره تلاش کنید.');
        return;
      }
      if (decoded['success'] != true) {
        _notice((decoded['message'] as String?) ?? 'ارسال نشد.');
        return;
      }

      setState(() {
        _sent = true;
        _message.clear();
        _sending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      _notice('خطا در ارتباط با سایت');
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
          title: const Text(
            'پشتیبانی و تماس با ما',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Dk.text1),
          ),
          elevation: 0.5,
          backgroundColor: Colors.white,
          foregroundColor: Dk.text1,
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            if (widget.config.supportStoreName.isNotEmpty ||
                widget.config.supportStorePhone.isNotEmpty)
              _StoreContactCard(
                config: widget.config,
                onCopyPhone: _contactStore,
              ),
            if (_sent) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Dk.success),
                ),
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEAF7EC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, size: 32, color: Dk.success),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'پیام شما ثبت شد',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Dk.text1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'کارشناسان ما به‌زودی با شما تماس می‌گیرند.',
                      style: TextStyle(fontSize: 12, color: Dk.text3),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => setState(() => _sent = false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: widget.config.primaryColor,
                        side: BorderSide(color: widget.config.primaryColor),
                      ),
                      child: const Text('ارسال پیام جدید'),
                    ),
                  ],
                ),
              ),
            ] else ...<Widget>[
              _SectionCard(
                title: 'شرح مشکل خود را بنویسید',
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: <Widget>[
                      TextFormField(
                        controller: _name,
                        maxLength: 60,
                        decoration: _decoration('نام شما'),
                        style: const TextStyle(fontSize: 13.5),
                        validator: (String? value) {
                          if ((value ?? '').trim().length < 2) {
                            return 'نام را وارد کنید';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _phone,
                        maxLength: 13,
                        keyboardType: TextInputType.phone,
                        decoration: _decoration('شماره موبایل', hint: '۰۹۱۲۳۴۵۶۷۸۹'),
                        style: const TextStyle(fontSize: 13.5),
                        validator: (String? value) {
                          // ارقام فارسی هم پذیرفته میشود | +98 هم با نرمالسازی درست میشود.
                          final String digits =
                              latinDigits(value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                          final String normalized = normalizePhone(digits);
                          if (normalized.length != 11 || !normalized.startsWith('09')) {
                            return 'شماره موبایل معتبر نیست';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _message,
                        maxLength: 1000,
                        minLines: 4,
                        maxLines: 6,
                        decoration: _decoration('شرح مشکل', hint: 'مشکل یا درخواست خود را کامل بنویسید'),
                        style: const TextStyle(fontSize: 13.5, height: 1.6),
                        validator: (String? value) {
                          if ((value ?? '').trim().length < 10) {
                            return 'شرح مشکل حداقل ۱۰ پیام باشد';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        // دکمه تمامعرض | هم‌عرض فیلدهای فرم، نه دکمه کوچک لبه‌چسب.
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: widget.config.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _sending ? null : _submit,
                          child: _sending
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : const Text(
                                  'ارسال پیام',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'پاسخ در اولین فرصت از طریق تماس یا پیامک داده می‌شود.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: Dk.text3, height: 1.8),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      counterText: '',
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Dk.border),
      ),
    );
  }
}

/// کارت اطلاعات تماس فروشگاه | از تنظیم نیتیو ۱۲، فقط اگر پر شده باشد.
class _StoreContactCard extends StatelessWidget {
  const _StoreContactCard({required this.config, required this.onCopyPhone});

  final AppConfig config;
  final VoidCallback onCopyPhone;

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
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: config.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.support_agent, size: 24, color: config.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (config.supportStoreName.isNotEmpty)
                  Text(
                    config.supportStoreName,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Dk.text1,
                    ),
                  ),
                if (config.supportStorePhone.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'پشتیبانی: ${toPersianDigits(config.supportStorePhone)}',
                    style: const TextStyle(fontSize: 12.5, color: Dk.text2),
                  ),
                ],
              ],
            ),
          ),
          if (config.supportStorePhone.isNotEmpty)
            IconButton(
              onPressed: onCopyPhone,
              icon: const Icon(Icons.copy_rounded, size: 20),
              color: config.primaryColor,
              tooltip: 'کپی شماره',
            ),
        ],
      ),
    );
  }
}

/// کارت سفید بخش‌دار | هم‌خانوادهٔ کارت‌های سفارش‌ها.
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
