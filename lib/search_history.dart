import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تنظیم ۲۲ | تاریخچهٔ جستجوهای اخیر | کاملاً محلی روی دستگاه کاربر
/// (SharedPreferences) | بدون هیچ اندپوینت یا جدول تازهٔ وردپرس |
/// مدیریتش هم‌سبک FavoritesManager/RecentlyViewedManager است.
class SearchHistoryManager extends ChangeNotifier {
  SearchHistoryManager._() {
    _restoreFuture = _loadFromPrefs();
  }

  static final SearchHistoryManager instance = SearchHistoryManager._();

  static const String _storageKey = 'wptf_search_history_v1';
  static const int _maxItems = 10;

  bool _uiEnabled = false;
  bool get uiEnabled => _uiEnabled;

  /// گیت نمایش چیپها | فقط با تغییر واقعی notify میکند تا بخش با آمدن
  /// /config زنده، بدون ریبیلد اپ ظاهر یا غایب شود.
  void setUiEnabled(bool enabled) {
    if (_uiEnabled == enabled) return;
    _uiEnabled = enabled;
    notifyListeners();
  }

  late final Future<void> _restoreFuture;
  Future<void> get ready => _restoreFuture;

  // الگوی ریس FavoritesManager/RecentlyViewedManager | تغییرِ قبل از پایان
  // بازیابی هم اجرا میشود و هم در صف میماند تا روی دادهٔ بازیابی‌شده اعمال شود.
  bool _restored = false;
  final List<VoidCallback> _pendingMutations = <VoidCallback>[];

  /// کوئریها | تازهترین اول | متن با همان حروفی که کاربر نوشته حفظ میشود.
  final List<String> _queries = <String>[];

  List<String> get queries => List<String>.unmodifiable(_queries);

  int get count => _queries.length;

  /// ثبت جستجو | فقط رشتهٔ ۲ نویسه‌ای به بالا | یکتا (مقایسهٔ بی‌حس به حروف
  /// بزرگ/کوچک) | نسخهٔ تازهٔ کاربر سر جای اول نشسته و قدیمیها تا ۱۰ مورد
  /// نگه داشته میشوند | تایپهای میانی جستجوی زنده هرگز اینجا نمیآیند.
  void recordQuery(String rawQuery) => _mutate(() {
        final String query = rawQuery.trim();
        if (query.length < 2) return;
        final String key = query.toLowerCase();
        _queries.removeWhere((String existing) => existing.toLowerCase() == key);
        _queries.insert(0, query);
        if (_queries.length > _maxItems) {
          _queries.removeRange(_maxItems, _queries.length);
        }
      });

  void removeQuery(String query) => _mutate(() {
        final String key = query.trim().toLowerCase();
        _queries.removeWhere((String existing) => existing.toLowerCase() == key);
      });

  void clearAll() => _mutate(() {
        _queries.clear();
      });

  void _mutate(VoidCallback mutation) {
    if (!_restored) _pendingMutations.add(mutation);
    mutation();
    _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      await _restoreFuture;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_queries));
    } catch (_) {
      // خطای ذخیره | دادهٔ حافظهای سر جایش میماند.
    }
  }

  Future<void> _loadFromPrefs() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String raw = prefs.getString(_storageKey) ?? '';
      final dynamic decoded = raw.isEmpty ? null : jsonDecode(raw);
      if (decoded is List) {
        for (final dynamic row in decoded) {
          if (row is String && row.trim().isNotEmpty) {
            _queries.add(row);
          }
        }
      }
    } catch (_) {
      // دادهٔ خراب | بیصدا خالی میشود | تاریخچه هرگز اپ را نمیشکند.
    } finally {
      _restored = true;
      for (final VoidCallback mutation in _pendingMutations) {
        mutation();
      }
      _pendingMutations.clear();
      notifyListeners();
    }
  }
}
