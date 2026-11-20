import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'favorites_screen.dart';
import 'native_mode.dart';

/// تنظیم ۲۱ | بازدیدهای اخیر | کاملاً محلی روی دستگاه کاربر
/// (SharedPreferences) | بدون هیچ اندپوینت یا جدول تازهٔ وردپرس |
/// مدیریتش هم‌سبک FavoritesManager است (سینگلتون ChangeNotifier | صف تغییرها
/// قبل از پایان بازیابی | اسنپ‌شات کامل مشترک از wpItemSnapshot).
class RecentlyViewedManager extends ChangeNotifier {
  RecentlyViewedManager._() {
    _restoreFuture = _loadFromPrefs();
  }

  static final RecentlyViewedManager instance = RecentlyViewedManager._();

  static const String _storageKey = 'wptf_recently_viewed_v1';
  static const int _maxItems = 12;

  bool _uiEnabled = false;
  bool get uiEnabled => _uiEnabled;

  /// گیت نمایش ردیف | فقط با تغییر واقعی notify میکند تا ردیف با آمدن
  /// /config زنده، بدون ریبیلد اپ ظاهر یا غایب شود.
  void setUiEnabled(bool enabled) {
    if (_uiEnabled == enabled) return;
    _uiEnabled = enabled;
    notifyListeners();
  }

  late final Future<void> _restoreFuture;
  Future<void> get ready => _restoreFuture;

  // الگوی ریس FavoritesManager/CartManager | تغییرِ قبل از پایان بازیابی هم
  // اجرا میشود و هم در صف میماند تا روی دادهٔ بازیابی‌شده دوباره اعمال شود.
  bool _restored = false;
  final List<VoidCallback> _pendingMutations = <VoidCallback>[];

  /// بهترتیب بازدید | قدیمیترین اول | getter معکوس میدهد تا تازهترین اول.
  final Map<int, Map<String, dynamic>> _snapshots =
      <int, Map<String, dynamic>>{};

  List<WpItem> get items => _snapshots.values
      .map(wpItemFromSnapshot)
      .toList(growable: false)
      .reversed
      .toList(growable: false);

  int get count => _snapshots.length;

  /// ثبت بازدید | فقط محصول و شناسهٔ معتبر | محصول دیده‌شده به تازه‌ترین
  /// میرود و از ۱۲ مورد بیشتر، قدیمیترینها حذف میشوند.
  void recordView(WpItem item) => _mutate(() {
        if (!item.isProduct || item.id <= 0) return;
        _snapshots.remove(item.id);
        _snapshots[item.id] = wpItemSnapshot(item);
        while (_snapshots.length > _maxItems) {
          _snapshots.remove(_snapshots.keys.first);
        }
      });

  void clearAll() => _mutate(() {
        _snapshots.clear();
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
      await prefs.setString(
        _storageKey,
        jsonEncode(_snapshots.values.toList(growable: false)),
      );
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
          if (row is Map) {
            final Map<String, dynamic> snapshot = row.cast<String, dynamic>();
            final int id = (snapshot['id'] as num?)?.toInt() ?? 0;
            if (id > 0) _snapshots[id] = snapshot;
          }
        }
      }
    } catch (_) {
      // دادهٔ خراب | بیصدا خالی میشود | بازدیدهای اخیر هرگز اپ را نمیشکند.
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
