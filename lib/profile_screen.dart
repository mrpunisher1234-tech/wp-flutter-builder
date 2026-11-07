import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';
import 'native_mode.dart';
import 'product_reviews.dart';

/// تب پروفایل | ورود دومرحله‌ای با شماره موبایل (OTP) + نمای کاربر
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.config});

  final AppConfig config;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _step = 1; // ۱: شماره موبایل | ۲: کد تایید
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String _userName = '';
  String _userPhone = '';

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('wptf_auth_token');
    if (token != null && token.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoggedIn = true;
        _userName = prefs.getString('wptf_user_name') ?? 'کاربر محترم';
        _userPhone = prefs.getString('wptf_user_phone') ?? '';
      });
      // نشست استاتیک دیدگاه‌ها هم تازه می‌شود | گیت کارت ۸ دقیق می‌ماند.
      UserSession.isLoggedIn = true;
      UserSession.displayName = _userName;
    }
  }

  /// همه اعلان‌های این صفحه سیاه‌اند | بدون پس‌زمینه قهوه‌ای پیش‌فرض
  void _showNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.black,
        content: Text(message, style: const TextStyle(color: Colors.white)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _sendOtp() async {
    final String phone = _phoneController.text.trim();
    if (phone.length < 10) {
      _showNotice('لطفاً شماره موبایل معتبر وارد کنید');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final Uri uri = Uri.parse('${widget.config.effectiveApiBaseUrl}auth/send-otp');
      final HttpClient client = HttpClient();
      final HttpClientRequest request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode(<String, String>{'phone': phone})));
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      final dynamic decoded = jsonDecode(body);
      final bool success = decoded is Map<String, dynamic> && decoded['success'] == true;
      if (!mounted) return;
      if (response.statusCode == 200 && success) {
        setState(() {
          _step = 2;
          _isLoading = false;
        });
        if (decoded is Map<String, dynamic> && decoded['mock'] == true) {
          _showNotice('حالت آزمایشی: کد تایید شما 1234 است');
        }
      } else {
        setState(() => _isLoading = false);
        final String message =
            decoded is Map<String, dynamic> && decoded['message'] != null
                ? decoded['message'].toString()
                : 'خطا در ارسال کد';
        // محدودیت ارسال یعنی کد قبلی هنوز معتبر است | مستقیم به کادر کد برو
        if (response.statusCode == 429 || message.contains('معتبر')) {
          setState(() => _step = 2);
          _showNotice('کد قبلی هنوز معتبر است | همون کد رو در کادر زیر وارد کن');
        } else {
          _showNotice(message);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showNotice('خطا در برقراری ارتباط با سرور');
    }
  }

  Future<void> _verifyOtp() async {
    final String code = _otpController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final Uri uri = Uri.parse('${widget.config.effectiveApiBaseUrl}auth/verify-otp');
      final HttpClient client = HttpClient();
      final HttpClientRequest request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(
        utf8.encode(
          jsonEncode(<String, String>{
            'phone': _phoneController.text.trim(),
            'code': code,
          }),
        ),
      );
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      final dynamic decoded = jsonDecode(body);
      final bool success = decoded is Map<String, dynamic> && decoded['success'] == true;
      if (!mounted) return;
      if (response.statusCode == 200 && success) {
        final Map<String, dynamic> data = decoded as Map<String, dynamic>;
        final Map<String, dynamic> user =
            data['user'] as Map<String, dynamic>? ?? <String, dynamic>{};
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('wptf_auth_token', (data['token'] ?? '').toString());
        await prefs.setString('wptf_user_phone', (user['phone'] ?? '').toString());
        await prefs.setString('wptf_user_name', (user['name'] ?? '').toString());
        setState(() {
          _isLoggedIn = true;
          _userPhone = (user['phone'] ?? '').toString();
          _userName = (user['name'] ?? '').toString();
          _isLoading = false;
        });
        // نشست استاتیک دیدگاه‌ها | از این لحظه ثبت دیدگاه با نام کاربر است.
        UserSession.isLoggedIn = true;
        UserSession.displayName = _userName;
      } else {
        setState(() => _isLoading = false);
        _showNotice(
          decoded is Map<String, dynamic> && decoded['message'] != null
              ? decoded['message'].toString()
              : 'کد اشتباه است',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showNotice('خطا در برقراری ارتباط با سرور');
    }
  }

  Future<void> _logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('wptf_auth_token');
    await prefs.remove('wptf_user_phone');
    await prefs.remove('wptf_user_name');
    setState(() {
      _isLoggedIn = false;
      _step = 1;
      _phoneController.clear();
      _otpController.clear();
    });
    UserSession.isLoggedIn = false;
    UserSession.displayName = '';
  }

  @override
  Widget build(BuildContext context) {
    return _isLoggedIn ? _buildLoggedInView() : _buildLoginView();
  }

  Widget _buildLoginView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Dk.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: widget.config.primaryColor,
              ),
              const SizedBox(height: 12),
              Text(
                _step == 1
                    ? 'ورود / ثبت‌نام در ${widget.config.appName}'
                    : 'تایید شماره موبایل',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Dk.text1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _step == 1
                    ? 'برای دسترسی به سفارش‌ها، شماره موبایل خود را وارد کنید.'
                    : 'کد تایید ارسال‌شده به شماره ${_phoneController.text} را وارد کنید.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Dk.text3),
              ),
              const SizedBox(height: 20),
              if (_step == 1) ...<Widget>[
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '۰۹۱۲۳۴۵۶۷۸۹',
                    hintStyle: const TextStyle(color: Dk.text4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.config.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isLoading ? null : _sendOtp,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'دریافت کد تایید',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ] else ...<Widget>[
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 18,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: '- - - -',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.config.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isLoading ? null : _verifyOtp,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'تایید و ورود',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
                TextButton(
                  onPressed: () => setState(() => _step = 1),
                  child: const Text('ویرایش شماره موبایل', style: TextStyle(fontSize: 12)),
                ),
                // کد ۲ دقیقه اعتبار دارد | اگر منقضی شد دوباره بفرست
                TextButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  child: const Text(
                    'ارسال مجدد کد تایید',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoggedInView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Dk.border),
          ),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 28,
                backgroundColor: widget.config.primaryColor.withValues(alpha: 0.12),
                child: Icon(
                  Icons.person,
                  size: 32,
                  color: widget.config.primaryColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _userName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Dk.text1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userPhone,
                      style: const TextStyle(fontSize: 12.5, color: Dk.text3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildProfileTile(Icons.shopping_bag_outlined, 'سفارش‌های من', () {}),
        _buildProfileTile(Icons.location_on_outlined, 'آدرس‌های من', () {}),
        _buildProfileTile(Icons.support_agent_outlined, 'پشتیبانی و تماس با ما', () {}),
        _buildProfileTile(Icons.info_outline, 'درباره ${widget.config.appName}', () {}),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Dk.discount,
            side: const BorderSide(color: Dk.discount),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _logout,
          icon: const Icon(Icons.logout, size: 18),
          label: const Text(
            'خروج از حساب کاربری',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTile(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Dk.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: Dk.text2, size: 22),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Dk.text1,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Dk.text4),
        onTap: onTap,
      ),
    );
  }
}
