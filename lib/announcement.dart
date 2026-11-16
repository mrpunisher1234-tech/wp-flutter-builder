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
    this.displayMode = 'once',
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
  final String displayMode;
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
      displayMode: _readString(map['display_mode']) == 'every_open'
          ? 'every_open'
          : 'once',
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
      displayMode: displayMode,
      productPayload: productPayload,
    );
  }
}

bool _readBool(dynamic value) => value == true || value == 1 || value == '1';

String _readString(dynamic value) => value is String ? value.trim() : '';

int _readInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

class AnnouncementDisplayPolicy {
  const AnnouncementDisplayPolicy._();

  static bool shouldShow({
    required AppAnnouncement announcement,
    required String seenId,
  }) {
    if (!announcement.isDisplayable) return false;
    return announcement.displayMode == 'every_open' ||
        seenId != announcement.id;
  }
}

class AnnouncementSeenStore {
  static const String preferenceKey = 'wptf_seen_announcement_id';

  Future<bool> shouldShow(
    AppAnnouncement announcement, {
    SharedPreferences? preferences,
  }) async {
    final SharedPreferences prefs =
        preferences ?? await SharedPreferences.getInstance();
    return AnnouncementDisplayPolicy.shouldShow(
      announcement: announcement,
      seenId: prefs.getString(preferenceKey) ?? '',
    );
  }

  Future<void> markSeen(
    AppAnnouncement announcement, {
    SharedPreferences? preferences,
  }) async {
    if (announcement.id.isEmpty) return;
    final SharedPreferences prefs =
        preferences ?? await SharedPreferences.getInstance();
    await prefs.setString(preferenceKey, announcement.id);
  }
}
