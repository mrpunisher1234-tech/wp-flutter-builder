import 'package:shared_preferences/shared_preferences.dart';

class AppAnnouncement {
  const AppAnnouncement({
    this.enabled = false,
    this.id = '',
    this.title = '',
    this.message = '',
    this.imageUrl = '',
    this.buttonText = 'مشاهده',
    this.targetType = 'none',
    this.productId = 0,
    this.linkUrl = '',
    this.maxShows = 1,
    this.productPayload,
  });

  final bool enabled;
  final String id;
  final String title;
  final String message;
  final String imageUrl;
  final String buttonText;
  final String targetType;
  final int productId;
  final String linkUrl;
  final int maxShows;
  final Map<String, dynamic>? productPayload;

  factory AppAnnouncement.fromMap(Map<dynamic, dynamic> map) {
    final dynamic rawProduct = map['product'];
    return AppAnnouncement(
      enabled: _readBool(map['enabled']),
      id: _readString(map['id']),
      title: _readString(map['title']),
      message: _readString(map['message']),
      imageUrl: _readString(map['image_url']),
      buttonText: _readString(map['button_text']).isEmpty
          ? 'مشاهده'
          : _readString(map['button_text']),
      targetType:
          const <String>{
            'none',
            'product',
            'url',
          }.contains(_readString(map['target_type']))
          ? _readString(map['target_type'])
          : 'none',
      productId: _readInt(map['product_id']),
      linkUrl: _readString(map['link_url']),
      maxShows: _readNonNegativeInt(map['max_shows'], fallback: 1),
      productPayload: rawProduct is Map
          ? rawProduct.map<String, dynamic>(
              (dynamic key, dynamic value) =>
                  MapEntry<String, dynamic>(key.toString(), value),
            )
          : null,
    );
  }

  bool get isDisplayable =>
      enabled && id.isNotEmpty && title.isNotEmpty && message.isNotEmpty;

  bool get hasProductTarget {
    final Map<String, dynamic>? payload = productPayload;
    final dynamic rawId = payload?['id'];
    final dynamic rawType = payload?['type'];
    return targetType == 'product' &&
        productId > 0 &&
        rawId is num &&
        rawId.toInt() == productId &&
        rawType == 'product';
  }

  Uri? get validLinkUri {
    if (targetType != 'url') return null;
    final Uri? uri = Uri.tryParse(linkUrl.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return uri;
  }

  bool get hasAction => hasProductTarget || validLinkUri != null;

  AppAnnouncement copyWith({String? imageUrl, String? linkUrl}) {
    return AppAnnouncement(
      enabled: enabled,
      id: id,
      title: title,
      message: message,
      imageUrl: imageUrl ?? this.imageUrl,
      buttonText: buttonText,
      targetType: targetType,
      productId: productId,
      linkUrl: linkUrl ?? this.linkUrl,
      maxShows: maxShows,
      productPayload: productPayload,
    );
  }
}

bool _readBool(dynamic value) => value == true || value == 1 || value == '1';

String _readString(dynamic value) => value is String ? value.trim() : '';

int _readInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

int _readNonNegativeInt(dynamic value, {required int fallback}) {
  if (value == null || '$value'.trim().isEmpty) return fallback;
  final int? parsed = value is num
      ? value.toInt()
      : int.tryParse(value.toString().trim());
  return parsed == null || parsed < 0 ? fallback : parsed;
}

class AnnouncementDisplayPolicy {
  const AnnouncementDisplayPolicy._();

  static bool shouldShow({
    required AppAnnouncement announcement,
    required String seenId,
    required int seenCount,
  }) {
    if (!announcement.isDisplayable) return false;
    if (announcement.maxShows == 0) return true;
    final int effectiveCount = seenId == announcement.id && seenCount > 0
        ? seenCount
        : 0;
    return effectiveCount < announcement.maxShows;
  }
}

class AnnouncementSeenStore {
  static const String seenIdPreferenceKey = 'wptf_seen_announcement_id';
  static const String seenCountPreferenceKey =
      'wptf_seen_announcement_count';

  Future<bool> shouldShow(
    AppAnnouncement announcement, {
    SharedPreferences? preferences,
  }) async {
    if (!announcement.isDisplayable) return false;
    final SharedPreferences prefs =
        preferences ?? await SharedPreferences.getInstance();
    String seenId = prefs.getString(seenIdPreferenceKey) ?? '';
    int seenCount;
    if (seenId != announcement.id) {
      seenId = announcement.id;
      seenCount = 0;
      await prefs.setString(seenIdPreferenceKey, seenId);
      await prefs.setInt(seenCountPreferenceKey, seenCount);
    } else {
      final int? storedCount = prefs.getInt(seenCountPreferenceKey);
      seenCount = storedCount == null ? 1 : (storedCount < 0 ? 0 : storedCount);
      if (storedCount == null || storedCount < 0) {
        await prefs.setInt(seenCountPreferenceKey, seenCount);
      }
    }
    return AnnouncementDisplayPolicy.shouldShow(
      announcement: announcement,
      seenId: seenId,
      seenCount: seenCount,
    );
  }

  Future<void> markShown(
    AppAnnouncement announcement, {
    SharedPreferences? preferences,
  }) async {
    if (announcement.id.isEmpty || announcement.maxShows == 0) return;
    final SharedPreferences prefs =
        preferences ?? await SharedPreferences.getInstance();
    final String seenId = prefs.getString(seenIdPreferenceKey) ?? '';
    int seenCount = 0;
    if (seenId != announcement.id) {
      await prefs.setString(seenIdPreferenceKey, announcement.id);
      await prefs.setInt(seenCountPreferenceKey, 0);
    } else {
      final int storedCount = prefs.getInt(seenCountPreferenceKey) ?? 1;
      seenCount = storedCount < 0 ? 0 : storedCount;
    }
    await prefs.setInt(seenCountPreferenceKey, seenCount + 1);
  }
}
