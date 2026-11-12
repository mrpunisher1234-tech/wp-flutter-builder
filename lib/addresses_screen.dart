import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';
import 'native_mode.dart';
import 'skeleton.dart';

/// آدرس‌های من | دفترچهٔ آدرس کاربر موبایلی.
/// سرور آدرس‌ها را در متای خود کاربر نگه می‌دارد (wptf_addresses) و استان‌ها را
/// از خود ووکامرس می‌دهد، پس لیست استان‌های اپ همان لیست چک‌اوت سایت است.

/// یک آدرس ذخیره‌شده.
class UserAddress {
  const UserAddress({
    required this.id,
    required this.title,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.state,
    required this.city,
    required this.address1,
    required this.postcode,
    required this.isDefault,
  });

  final int id;
  final String title;
  final String firstName;
  final String lastName;
  final String phone;
  final String state;
  final String city;
  final String address1;
  final String postcode;
  final bool isDefault;

  static String _text(dynamic value) => ((value as String?) ?? '').trim();

  /// آدرس در یک خط، برای کارت لیست | نام استان را صفحه از لیست استان‌ها اضافه می‌کند.
  String get summary {
    final List<String> parts = <String>[address1, city]
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
    return parts.join('، ');
  }

  String get fullName {
    final String name = '$firstName $lastName'.trim();
    return name.isEmpty ? 'کاربر' : name;
  }

  factory UserAddress.fromMap(Map<String, dynamic> map) {
    return UserAddress(
      id: (map['id'] as num?)?.toInt() ?? 0,
      title: _text(map['title']),
      firstName: _text(map['first_name']),
      lastName: _text(map['last_name']),
      phone: _text(map['phone']),
      state: _text(map['state']),
      city: _text(map['city']),
      address1: _text(map['address_1']),
      postcode: _text(map['postcode']),
      isDefault: map['is_default'] == true,
    );
  }

  /// بدنهٔ ارسالی به /addresses/save.
  Map<String, dynamic> toBody(String token) {
    return <String, dynamic>{
      'auth_token': token,
      'id': id,
      'title': title,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'state': state,
      'city': city,
      'address_1': address1,
      'postcode': postcode,
      'is_default': isDefault,
    };
  }
}

/// یک استان | کد و نام فارسی، از خود ووکامرس.
class Province {
  const Province({required this.code, required this.name});

  final String code;
  final String name;

  factory Province.fromMap(Map<String, dynamic> map) {
    return Province(
      code: ((map['code'] as String?) ?? '').trim(),
      name: ((map['name'] as String?) ?? '').trim(),
    );
  }
}

/// ارقام فارسی/عربی به لاتین | همان کاری که سرور می‌کند، ولی اینجا برای اعتبارسنجی محلی.
String latinDigits(String value) {
  const String persian = '۰۱۲۳۴۵۶۷۸۹';
  const String arabic = '٠١٢٣٤٥٦٧٨٩';
  final StringBuffer out = StringBuffer();
  for (final int code in value.codeUnits) {
    final String char = String.fromCharCode(code);
    final int persianIndex = persian.indexOf(char);
    final int arabicIndex = arabic.indexOf(char);
    out.write(persianIndex >= 0 ? '$persianIndex' : (arabicIndex >= 0 ? '$arabicIndex' : char));
  }
  return out.toString();
}

/// موبایل ایران به شکل استاندارد ۰۹... | مثل منطق سمت سرور.
String normalizePhone(String value) {
  final String digits = latinDigits(value).replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 10 && digits.startsWith('9')) {
    return '0$digits';
  }
  if (digits.length == 12 && digits.startsWith('98')) {
    return '0${digits.substring(2)}';
  }
  return digits;
}

/// صفحهٔ فهرست آدرس‌ها | افزودن، ویرایش، حذف و پیش‌فرض.
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key, required this.config});

  final AppConfig config;

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final List<UserAddress> _addresses = <UserAddress>[];
  final List<Province> _provinces = <Province>[];

  bool _isLoading = true;
  bool _needsLogin = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
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

  /// همهٔ درخواست‌ها از یک جا | هر سه روت پاکت یکسانی برمی‌گردانند.
  Future<Map<String, dynamic>?> _call(String route, Map<String, dynamic> body) async {
    final String? token = await _authToken();
    if (token == null) {
      if (!mounted) return null;
      setState(() {
        _isLoading = false;
        _needsLogin = true;
      });
      return null;
    }

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final HttpClientRequest request = await client.postUrl(
        Uri.parse('${widget.config.effectiveApiBaseUrl}$route'),
      );
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(jsonEncode(<String, dynamic>{'auth_token': token}..addAll(body)));
      final HttpClientResponse response = await request.close();

      if (response.statusCode == 401) {
        if (!mounted) return null;
        setState(() {
          _isLoading = false;
          _needsLogin = true;
        });
        return null;
      }
      if (response.statusCode != 200) {
        throw const HttpException('bad status');
      }

      final String raw = await response.transform(utf8.decoder).join();
      final dynamic decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      if (!mounted) return null;
      setState(() {
        _isLoading = false;
        _error = 'خطا در ارتباط با سایت';
      });
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  void _applyEnvelope(Map<String, dynamic>? data) {
    if (data == null || !mounted) {
      return;
    }
    final List<dynamic> items = data['items'] is List ? data['items'] as List<dynamic> : const <dynamic>[];
    final List<dynamic> provinces =
        data['provinces'] is List ? data['provinces'] as List<dynamic> : const <dynamic>[];

    setState(() {
      _addresses
        ..clear()
        ..addAll(items.whereType<Map<String, dynamic>>().map(UserAddress.fromMap));
      _provinces
        ..clear()
        ..addAll(provinces.whereType<Map<String, dynamic>>().map(Province.fromMap));
      _isLoading = false;
      _error = null;
    });
  }

  Future<void> _fetchAddresses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _applyEnvelope(await _call('addresses', <String, dynamic>{}));
  }

  /// پیام خطا | سیاه/سفید، مطابق قانون اسنک‌بار پروفایل.
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

  Future<void> _openForm({UserAddress? address}) async {
    final Map<String, dynamic>? result = await Navigator.of(context).push(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => AddressFormScreen(
          config: widget.config,
          provinces: List<Province>.from(_provinces),
          address: address,
        ),
      ),
    );
    if (result != null) {
      _applyEnvelope(result);
    }
  }

  Future<void> _confirmDelete(UserAddress address) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('حذف آدرس', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text(
          'آدرس «${address.title}» حذف شود؟',
          style: const TextStyle(fontSize: 13, color: Dk.text2, height: 1.8),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('انصراف'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Dk.discount),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final Map<String, dynamic>? data = await _call(
      'addresses/delete',
      <String, dynamic>{'id': address.id},
    );
    if (data == null) {
      return;
    }
    _applyEnvelope(data);
    _notice('آدرس حذف شد.');
  }

  /// پیش‌فرض کردن یک آدرس | همان روت ذخیره با پرچم پیش‌فرض.
  Future<void> _makeDefault(UserAddress address) async {
    final Map<String, dynamic>? data = await _call(
      'addresses/save',
      address.toBody((await _authToken()) ?? '')..['is_default'] = true,
    );
    if (data == null) {
      return;
    }
    _applyEnvelope(data);
    _notice('آدرس پیش‌فرض تغییر کرد.');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Dk.canvas,
        appBar: AppBar(
          title: const Text(
            'آدرس‌های من',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Dk.text1),
          ),
          elevation: 0.5,
          backgroundColor: Colors.white,
          foregroundColor: Dk.text1,
        ),
        floatingActionButton: _isLoading || _needsLogin || _error != null
            ? null
            : FloatingActionButton.extended(
                backgroundColor: widget.config.primaryColor,
                foregroundColor: Colors.white,
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('آدرس جدید', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_needsLogin) {
      return _AddressesEmptyState(
        icon: Icons.lock_outline,
        title: 'برای دیدن آدرس‌ها وارد حساب شوید',
        subtitle: 'با شماره موبایل خود وارد شوید تا آدرس‌هایتان اینجا ذخیره شود.',
      );
    }
    if (_isLoading) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: List<Widget>.generate(
          3,
          (int index) => const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: SkeletonBox(height: 104, radius: 10),
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
              onPressed: _fetchAddresses,
              child: const Text('تلاش مجدد'),
            ),
          ],
        ),
      );
    }
    if (_addresses.isEmpty) {
      return _AddressesEmptyState(
        icon: Icons.location_off_outlined,
        title: 'هنوز آدرسی ثبت نکرده‌اید',
        subtitle: 'برای خرید راحت‌تر، آدرس‌هایتان را یک‌بار ذخیره کنید.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      children: <Widget>[
        for (final UserAddress address in _addresses)
          _AddressCard(
            address: address,
            provinceName: _provinceName(address.state),
            primaryColor: widget.config.primaryColor,
            onEdit: () => _openForm(address: address),
            onDelete: () => _confirmDelete(address),
            onSetDefault: address.isDefault ? null : () => _makeDefault(address),
          ),
      ],
    );
  }

  /// نام فارسی استان از کد | از همان لیستی که سرور داده است.
  String _provinceName(String code) {
    for (final Province province in _provinces) {
      if (province.code == code) {
        return province.name;
      }
    }
    return '';
  }
}

/// کارت یک آدرس | عنوان + چیپ پیش‌فرض + متن آدرس + عملیات.
class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.provinceName,
    required this.primaryColor,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  final UserAddress address;
  final String provinceName;
  final Color primaryColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onSetDefault;

  @override
  Widget build(BuildContext context) {
    final Color accent = primaryColor;
    final String summaryLine = provinceName.isEmpty
        ? address.summary
        : '${address.summary}، $provinceName';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: address.isDefault ? accent : Dk.border,
          width: address.isDefault ? 1.2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          address.title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Dk.text1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (address.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'پیش‌فرض',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                summaryLine,
                style: const TextStyle(fontSize: 12.5, color: Dk.text2, height: 1.8),
              ),
              if (address.firstName.isNotEmpty || address.lastName.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  'گیرنده: ${address.fullName}',
                  style: const TextStyle(fontSize: 12, color: Dk.text3),
                ),
              ],
              if (address.phone.isNotEmpty || address.postcode.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  [
                    if (address.phone.isNotEmpty)
                      'شماره تماس: ${toPersianDigits(address.phone)}',
                    if (address.postcode.isNotEmpty)
                      'کد پستی: ${toPersianDigits(address.postcode)}',
                  ].join(' | '),
                  style: const TextStyle(fontSize: 12, color: Dk.text3),
                ),
              ],
              const SizedBox(height: 10),
              const Divider(height: 1, color: Dk.border),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('ویرایش', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: Dk.text2,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  if (onSetDefault != null)
                    TextButton.icon(
                      onPressed: onSetDefault,
                      icon: const Icon(Icons.star_outline, size: 16),
                      label: const Text('پیش‌فرض کن', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: accent,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Dk.discount,
                    tooltip: 'حذف',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// فرم افزودن/ویرایش آدرس | اعتبارسنجی محلی + پیام خطای سرور.
class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({
    super.key,
    required this.config,
    required this.provinces,
    this.address,
  });

  final AppConfig config;
  final List<Province> provinces;
  final UserAddress? address;

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _city;
  late final TextEditingController _address;
  late final TextEditingController _postcode;

  late String _state;
  bool _isDefault = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final UserAddress? address = widget.address;
    _title = TextEditingController(text: address?.title ?? '');
    _firstName = TextEditingController(text: address?.firstName ?? '');
    _lastName = TextEditingController(text: address?.lastName ?? '');
    _phone = TextEditingController(text: address?.phone ?? '');
    _city = TextEditingController(text: address?.city ?? '');
    _address = TextEditingController(text: address?.address1 ?? '');
    _postcode = TextEditingController(text: address?.postcode ?? '');
    _state = address?.state ?? _defaultProvinceCode();
    _isDefault = address?.isDefault ?? widget.provinces.isEmpty;
  }

  String _defaultProvinceCode() {
    for (final Province province in widget.provinces) {
      if (province.code == 'THR') {
        return 'THR';
      }
    }
    return widget.provinces.isEmpty ? '' : widget.provinces.first.code;
  }

  @override
  void dispose() {
    _title.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _city.dispose();
    _address.dispose();
    _postcode.dispose();
    super.dispose();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('wptf_auth_token') ?? '';

      HttpClient? client;
      try {
        client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
        final HttpClientRequest request = await client.postUrl(
          Uri.parse('${widget.config.effectiveApiBaseUrl}addresses/save'),
        );
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        request.write(jsonEncode(<String, dynamic>{
          'auth_token': token,
          'id': widget.address?.id,
          'title': _title.text.trim(),
          'first_name': _firstName.text.trim(),
          'last_name': _lastName.text.trim(),
          'phone': normalizePhone(_phone.text),
          'state': _state,
          'city': _city.text.trim(),
          'address_1': _address.text.trim(),
          'postcode': latinDigits(_postcode.text).replaceAll(RegExp(r'[^0-9]'), ''),
          'is_default': _isDefault,
        }));
        final HttpClientResponse response = await request.close();
        final String raw = await response.transform(utf8.decoder).join();
        final dynamic decoded = jsonDecode(raw);

        if (!mounted) return;
        if (response.statusCode != 200 || decoded is! Map<String, dynamic>) {
          // دکمه آزاد میشود و پیام واقعی سرور (۴۰۰، ۴۲۹ و...) نشان داده میشود.
          setState(() => _saving = false);
          _notice(decoded is Map<String, dynamic> && decoded['message'] is String
              ? decoded['message'] as String
              : 'ذخیره نشد. لطفاً دوباره تلاش کنید.');
          return;
        }

        // پیام خطای سرور (موبایل تکراری، استان نامعتبر و...) به کاربر نشان داده می‌شود.
        Navigator.of(context).pop(decoded);
      } finally {
        client?.close(force: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _notice('خطا در ارتباط با سایت');
    }
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

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.address != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Dk.canvas,
        appBar: AppBar(
          title: Text(
            isEdit ? 'ویرایش آدرس' : 'آدرس جدید',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Dk.text1),
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
              TextFormField(
                controller: _title,
                maxLength: 40,
                decoration: _decoration('عنوان آدرس', hint: 'خانه، محل کار و...'),
                style: const TextStyle(fontSize: 13.5),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _firstName,
                      maxLength: 60,
                      decoration: _decoration('نام'),
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _lastName,
                      maxLength: 60,
                      decoration: _decoration('نام خانوادگی'),
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phone,
                maxLength: 14,
                keyboardType: TextInputType.phone,
                decoration: _decoration('شماره موبایل', hint: '۰۹۱۲۳۴۵۶۷۸۹'),
                style: const TextStyle(fontSize: 13.5),
                validator: (String? value) {
                  // ارقام فارسی و +98 هم پذیرفته میشود | بعد از نرمالسازی چک میشود.
                  final String phone = normalizePhone(value ?? '');
                  if (phone.length != 11 || !phone.startsWith('09')) {
                    return 'شماره موبایل معتبر نیست (مثال: ۰۹۱۲۳۴۵۶۷۸۹)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      // مقدار باید حتماً داخل آیتمها باشد | وگرنه فلاتر با
                      // assertion کرش میکند؛ لیست خالی یا ناهمخوان = بدون مقدار.
                      initialValue: widget.provinces.any((Province province) => province.code == _state)
                          ? _state
                          : null,
                      decoration: _decoration('استان'),
                      style: const TextStyle(fontSize: 13.5, color: Dk.text1),
                      items: widget.provinces
                          .map(
                            (Province province) => DropdownMenuItem<String>(
                              value: province.code,
                              child: Text(province.name, style: const TextStyle(fontSize: 13.5)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() => _state = value);
                        }
                      },
                      validator: (String? value) =>
                          value == null || value.isEmpty ? 'استان را انتخاب کنید' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _city,
                      maxLength: 60,
                      decoration: _decoration('شهر'),
                      style: const TextStyle(fontSize: 13.5),
                      validator: (String? value) =>
                          (value == null || value.trim().isEmpty) ? 'شهر را وارد کنید' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _address,
                maxLength: 500,
                minLines: 3,
                maxLines: 5,
                decoration: _decoration('نشانی کامل', hint: 'خیابان، کوچه، پلاک، واحد'),
                style: const TextStyle(fontSize: 13.5, height: 1.6),
                validator: (String? value) =>
                    (value == null || value.trim().isEmpty) ? 'نشانی کامل را وارد کنید' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _postcode,
                maxLength: 10,
                keyboardType: TextInputType.number,
                decoration: _decoration('کد پستی (اختیاری)'),
                style: const TextStyle(fontSize: 13.5),
                validator: (String? value) {
                  final String digits = latinDigits(value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.isEmpty || digits.length == 10) {
                    return null;
                  }
                  return 'کد پستی باید ۱۰ رقم باشد';
                },
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isDefault,
                onChanged: (bool value) => setState(() => _isDefault = value),
                activeThumbColor: widget.config.primaryColor,
                title: const Text(
                  'این آدرس پیش‌فرض من باشد',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Dk.text1),
                ),
                subtitle: const Text(
                  'در خریدهای بعدی همین آدرس انتخاب می‌شود.',
                  style: TextStyle(fontSize: 11.5, color: Dk.text3),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: widget.config.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text(
                        'ذخیره آدرس',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// حالت خالی و حالت نیاز به ورود | هم‌خانوادهٔ حالت خالی سفارش‌ها.
class _AddressesEmptyState extends StatelessWidget {
  const _AddressesEmptyState({
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
