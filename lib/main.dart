import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'bazaar_payment.dart';
import 'bank_payment.dart';
import 'cart_screen.dart';
import 'announcement.dart';
import 'favorites_screen.dart';
import 'native_mode.dart';
import 'payment_result_screen.dart';
import 'recently_viewed.dart';
import 'search_history.dart';
import 'splash_screen.dart';

/// بنر اسلایدر خانه | تصویر + لینک مقصد (لینک خالی = کلیک‌ناپذیر).
class NativeBanner {
  const NativeBanner({required this.image, this.link = ''});

  final String image;
  final String link;
}

/// مسیر لوگوی اسپلشی که بیلد ابری داخل APK میگذارد.
/// وجود این فایل یعنی اسپلش در فریم اول و بدون انتظار شبکه رسم میشود.
const String kSplashLogoAssetPath = 'assets/splash_logo.png';

// تیک امضای محلی RSA بازار از تنظیم ۱۵ سرور میآید | اینجا ثابتی نیست؛
// در main() از کش/کانفیگ خوانده میشود تا بدون بیلد مجدد قابل تغییر باشد.

/// یک نشان اعتماد (اینماد، ساماندهی و...) | تصویر + لینک اختیاری.
class AboutBadge {
  const AboutBadge({required this.image, required this.link});

  final String image;
  final String link;

  factory AboutBadge.fromMap(Map<String, dynamic> map) {
    return AboutBadge(
      image: ((map['image'] as String?) ?? '').trim(),
      link: ((map['link'] as String?) ?? '').trim(),
    );
  }
}

/// Application identity injected by the WP to Flutter cloud build engine.
class AppConfig {
  const AppConfig({
    required this.appName,
    required this.siteUrl,
    required this.primaryColor,
    this.apiBaseUrl = '',
    this.renderMode = 'webview',
    this.categoryCanvas = 400,
    this.banners = const <NativeBanner>[],
    this.sliderInterval = 5,
    this.offerCountdownEnd = '',
    this.logoUrl = '',
    this.appIconUrl = '',
    this.headerLogoUrl = '',
    this.headerLogoName = '',
    this.searchSuggestions = const <String>[],
    this.reviewsRequireLogin = false,
    this.reviewsGuestPost = true,
    this.splashImageUrl = '',
    this.splashLogoUrl = '',
    this.splashBackgroundHex = '',
    this.splashText = '',
    this.splashTextHex = '',
    this.splashShowLogo = true,
    this.splashSiteIconUrl = '',
    this.splashSiteName = '',
    this.splashLogoBundledUrl = '',
    this.supportStoreName = '',
    this.supportStorePhone = '',
    this.aboutText = '',
    this.aboutBadges = const <AboutBadge>[],
    this.checkoutMode = 'native',
    this.ordersPerPage = 10,
    this.requirePostcode = true,
    this.requireOrderNote = false,
    this.enableCoupons = true,
    this.defaultShippingCost = 0,
    this.deepLinkScheme = 'wptoflutter',
    this.paymentGateway = 'zarinpal',
    this.paymentSandbox = false,
    this.bazaarUseLocalSignatureCheck = false,
    this.bazaarRsaPublicKey = '',
    // تنظیم ۱۷ | پرداخت دوبارهٔ سفارش معلق.
    this.pendingOrderPayEnabled = false,
    // تنظیم ۱۸ | علاقه‌مندی‌های محلی.
    this.favoritesEnabled = false,
    // تنظیم ۱۹ | محصولات مرتبط.
    this.relatedProductsEnabled = false,
    // تنظیم ۲۰ | تایم‌لاین وضعیت سفارش.
    this.orderTimelineEnabled = false,
    // تنظیم ۲۱ | بازدیدهای اخیر.
    this.recentlyViewedEnabled = false,
    // تنظیم ۲۲ | تاریخچهٔ جستجوهای اخیر.
    this.searchHistoryEnabled = false,
    // تنظیم ۲۳ | مرتب‌سازی و فیلتر موجودی.
    this.sortFilterEnabled = false,
    this.announcement = const AppAnnouncement(),
  });

  final String appName;
  final String siteUrl;
  final Color primaryColor;
  final String apiBaseUrl;
  final String renderMode;
  final int categoryCanvas;
  final List<NativeBanner> banners;
  final int sliderInterval;
  final String offerCountdownEnd;
  final String logoUrl;
  final String appIconUrl;
  final String headerLogoUrl;
  final String headerLogoName;
  final List<String> searchSuggestions;
  final bool reviewsRequireLogin;
  final bool reviewsGuestPost;
  final String splashImageUrl;
  final String splashBackgroundHex;
  final String splashText;
  final String splashTextHex;
  final bool splashShowLogo;
  final String splashSiteIconUrl;
  final String splashSiteName;

  /// لوگوی حلشده در سمت وردپرس | دقیقاً همان آدرسی که بیلد ابری دانلود کرده است.
  final String splashLogoUrl;

  /// آدرس لوگویی که در زمان بیلد داخل APK بستهبندی شده (خالی = بستهبندی نشده).
  /// با مقدار زنده مقایسه میشود تا اگر ادمین بعداً لوگو را عوض کرد، نسخه قدیمی نشان داده نشود.
  final String splashLogoBundledUrl;
  final String supportStoreName;
  final String supportStorePhone;
  final String aboutText;
  final List<AboutBadge> aboutBadges;
  // تنظیم ۱۴ | تسویه‌حساب نیتیو و سوابق سفارشات.
  final String checkoutMode;
  final int ordersPerPage;
  final bool requirePostcode;
  final bool requireOrderNote;
  final bool enableCoupons;
  final int defaultShippingCost;
  // تنظیم ۱۴ | اسکیمای بازگشت پرداخت (دیپ‌لینک).
  final String deepLinkScheme;
  // تنظیم ۱۵ | درگاه پرداخت + امضای محلی RSA بازار.
  final String paymentGateway;
  final bool paymentSandbox;
  final bool bazaarUseLocalSignatureCheck;
  final String bazaarRsaPublicKey;
  // تنظیم ۱۷ | پرداخت دوبارهٔ سفارش معلق | دکمه در صفحه سفارش‌های من.
  final bool pendingOrderPayEnabled;
  // تنظیم ۱۸ | علاقه‌مندی‌ها | قلب روی محصولات | ذخیره روی دستگاه کاربر.
  final bool favoritesEnabled;
  // تنظیم ۱۹ | محصولات مرتبط | ردیف افقی در صفحهٔ جزئیات.
  final bool relatedProductsEnabled;
  // تنظیم ۲۰ | تایم‌لاین وضعیت سفارش | نمایش در جزئیات سفارش.
  final bool orderTimelineEnabled;
  // تنظیم ۲۱ | بازدیدهای اخیر | ردیف افقی در خانه | ذخیره روی دستگاه.
  final bool recentlyViewedEnabled;
  // تنظیم ۲۲ | تاریخچهٔ جستجوهای اخیر | چیپ‌های سریع در صفحهٔ جستجو.
  final bool searchHistoryEnabled;
  // تنظیم ۲۳ | مرتب‌سازی و فیلتر موجودی | نوار بالای محصولات.
  final bool sortFilterEnabled;
  final AppAnnouncement announcement;

  /// لوگوی نهایی اسپلش | اولویت حلشده سمت وردپرس، وگرنه:
  /// ۱. لوگوی اختصاصی اسپلش، ۲. آیکون سایت، ۳. آیکون رسمی اپ.
  String get resolvedSplashLogoUrl {
    if (!splashShowLogo) {
      return '';
    }
    if (splashLogoUrl.isNotEmpty) {
      return splashLogoUrl;
    }
    if (splashImageUrl.isNotEmpty) {
      return splashImageUrl;
    }
    if (splashSiteIconUrl.isNotEmpty) {
      return splashSiteIconUrl;
    }
    if (appIconUrl.isNotEmpty) {
      return appIconUrl;
    }
    return '';
  }

  /// لوگوی شبکه | وقتی فایل بستهبندیشده در دسترس نیست یا منقضی شده است.
  ImageProvider? get splashLogoNetworkProvider {
    final String url = resolvedSplashLogoUrl;
    return url.isEmpty ? null : NetworkImage(url);
  }

  /// لوگویی که در فریم اول و بدون انتظار شبکه قابل استفاده است.
  /// فقط وقتی فایل داخلی معتبر است که آدرس زنده با آدرس بستهبندیشده یکی باشد.
  ImageProvider? get splashLogoProvider {
    final String live = resolvedSplashLogoUrl;
    if (live.isEmpty || splashLogoBundledUrl.isEmpty) {
      return splashLogoNetworkProvider;
    }
    final String bundled = mapEmulatorUrl(splashLogoBundledUrl.trim());
    if (bundled.isEmpty || bundled != live) {
      return splashLogoNetworkProvider;
    }
    return const AssetImage(kSplashLogoAssetPath);
  }

  Color get splashBackgroundColor =>
      parseHexColor(splashBackgroundHex, fallback: primaryColor);

  Color get splashTextColor =>
      parseHexColor(splashTextHex, fallback: const Color(0xFFFFFFFF));

  String get splashLoadingText =>
      splashText.trim().isNotEmpty ? splashText.trim() : 'در حال لودینگ';

  String get splashBrandText {
    final String name = splashSiteName.trim();
    return name.isNotEmpty ? name : appName;
  }

  bool get isNative => renderMode == 'native';

  String get effectiveApiBaseUrl {
    if (apiBaseUrl.isNotEmpty) {
      return apiBaseUrl.endsWith('/') ? apiBaseUrl : '$apiBaseUrl/';
    }
    final String base = siteUrl.endsWith('/') ? siteUrl : '$siteUrl/';
    return '${base}wp-json/wp-to-flutter/v1/';
  }

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    final String rawApiBase = ((map['api_base_url'] as String?) ?? '').trim();
    final Map<dynamic, dynamic> app =
        (map['app'] as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};
    final Map<dynamic, dynamic> icon =
        (app['icon'] as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};
    final Map<dynamic, dynamic> supportBlock = (map['support'] is Map)
        ? (map['support'] as Map).cast<dynamic, dynamic>()
        : <dynamic, dynamic>{};
    final Map<dynamic, dynamic> aboutBlock = (map['about'] is Map)
        ? (map['about'] as Map).cast<dynamic, dynamic>()
        : <dynamic, dynamic>{};
    final String resolvedAppIcon = AppConfig.mapEmulatorUrl(
      ((icon['url'] as String?) ?? (map['app_icon_url'] as String?) ?? '')
          .trim(),
    );

    return AppConfig(
      appName: _readName(map['app_name']),
      siteUrl: normalizeSiteUrl((map['site_url'] as String?) ?? ''),
      primaryColor: parseHexColor(
        (map['primary_color'] as String?) ?? '',
        fallback: const Color(0xFF2271B1),
      ),
      apiBaseUrl: rawApiBase.isEmpty ? '' : normalizeSiteUrl(rawApiBase),
      appIconUrl: resolvedAppIcon,
      renderMode: (map['render_mode'] as String?) == 'native'
          ? 'native'
          : 'webview',
      // همان چهار عبارت پرطرفدار که بیلد ابری داخل APK میپزد؛ از این پس
      // صفحه جستجو حتی بدون شبکه و در اولین فریم هم آنها را دارد.
      searchSuggestions: parseSuggestions(map['search_suggestions']),
      supportStoreName: ((supportBlock['store_name'] as String?) ?? '').trim(),
      supportStorePhone: ((supportBlock['store_phone'] as String?) ?? '')
          .trim(),
      aboutText: ((aboutBlock['text'] as String?) ?? '').trim(),
      aboutBadges: parseBadges(aboutBlock['badges']),
      announcement: parseAnnouncement(map['announcement']),
    );
  }

  static AppAnnouncement parseAnnouncement(
    dynamic raw, {
    AppAnnouncement? fallback,
  }) {
    if (raw is! Map) return fallback ?? const AppAnnouncement();
    final AppAnnouncement parsed = AppAnnouncement.fromMap(raw);
    return parsed.copyWith(
      imageUrl: mapEmulatorUrl(parsed.imageUrl),
      linkUrl: mapEmulatorUrl(parsed.linkUrl),
    );
  }

  /// نشان‌های اعتماد | بدون تصویر حذف می‌شوند و مقدار غیرلیست نادیده گرفته می‌شود.
  static List<AboutBadge> parseBadges(dynamic raw) {
    return (raw is List ? raw : const <dynamic>[])
        .whereType<Map>()
        .map((Map row) => AboutBadge.fromMap(row.cast<String, dynamic>()))
        .where((AboutBadge badge) => badge.image.isNotEmpty)
        .toList(growable: false);
  }

  /// چهار عبارت پرطرفدار | خالیها حذف و بیشتر از چهار مورد پذیرفته نمیشود.
  /// مقدار غیرلیست (رشته یا null) هم بیصدا نادیده گرفته میشود.
  static List<String> parseSuggestions(dynamic raw) {
    return (raw is List ? raw : const <dynamic>[])
        .map((dynamic term) => ((term as String?) ?? '').trim())
        .where((String term) => term.isNotEmpty)
        .take(4)
        .toList(growable: false);
  }

  static String _readName(dynamic value) {
    final String name = (value as String?)?.trim() ?? '';
    return name.isNotEmpty ? name : 'Demo App';
  }

  static String normalizeSiteUrl(String value) {
    final String trimmed = value.trim();
    String url = trimmed.isEmpty ? 'https://example.com' : trimmed;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    return mapEmulatorUrl(url);
  }

  static String mapEmulatorUrl(String url) {
    if (Platform.isAndroid &&
        (url.contains('://localhost') || url.contains('://127.0.0.1'))) {
      return url
          .replaceAll('://localhost', '://10.0.2.2')
          .replaceAll('://127.0.0.1', '://10.0.2.2');
    }
    return url;
  }

  static Color parseHexColor(String value, {required Color fallback}) {
    final String hex = value.trim().replaceFirst('#', '');
    final int? parsed = hex.length == 6 ? int.tryParse(hex, radix: 16) : null;
    return parsed == null ? fallback : Color(0xFF000000 | parsed);
  }

  static Future<AppConfig> load() async {
    final String raw = await rootBundle.loadString('assets/config.json');
    final dynamic decoded = jsonDecode(raw);
    AppConfig config =
        AppConfig.fromMap(
          decoded is Map<String, dynamic> ? decoded : <String, dynamic>{},
        ).withSplash(
          decoded is Map<String, dynamic> ? decoded : <String, dynamic>{},
        );

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> cached = <String, dynamic>{};
      final Map<String, dynamic> cachedApp = <String, dynamic>{};
      final Map<String, dynamic> cachedIcon = <String, dynamic>{};
      final Map<String, dynamic> cachedSplash = <String, dynamic>{};

      void copyString(
        Map<String, dynamic> target,
        String targetKey,
        String preferenceKey,
      ) {
        if (prefs.containsKey(preferenceKey)) {
          target[targetKey] = prefs.getString(preferenceKey) ?? '';
        }
      }

      if (prefs.containsKey('wptf_app_icon_url')) {
        final String value = prefs.getString('wptf_app_icon_url') ?? '';
        cached['app_icon_url'] = value;
        cachedIcon['url'] = value;
      }
      copyString(
        cached,
        'splash_logo_bundled_url',
        'wptf_splash_logo_bundled_url',
      );
      copyString(cachedSplash, 'url', 'wptf_splash_url');
      copyString(cachedSplash, 'logo_url', 'wptf_splash_logo_url');
      if (prefs.containsKey('wptf_splash_show_logo')) {
        cachedSplash['show_logo'] =
            prefs.getBool('wptf_splash_show_logo') ?? true;
      }
      copyString(
        cachedSplash,
        'site_icon_url',
        'wptf_splash_site_icon',
      );
      copyString(cachedSplash, 'site_name', 'wptf_splash_site_name');
      copyString(cachedSplash, 'bg_color', 'wptf_splash_bg');
      copyString(cachedSplash, 'text', 'wptf_splash_text');
      copyString(cachedSplash, 'text_color', 'wptf_splash_text_color');

      if (cachedIcon.isNotEmpty) {
        cachedApp['icon'] = cachedIcon;
      }
      if (cachedSplash.isNotEmpty) {
        cachedApp['splash'] = cachedSplash;
      }
      if (cachedApp.isNotEmpty) {
        cached['app'] = cachedApp;
      }
      if (cached.isNotEmpty) {
        config = config.withSplash(cached);
      }
    } catch (_) {}
    return config;
  }

  AppConfig withSplash(Map<String, dynamic> map) {
    final Map<dynamic, dynamic> app =
        (map['app'] as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};
    final Map<dynamic, dynamic> splash =
        (app['splash'] as Map<dynamic, dynamic>?) ??
        (map['splash'] as Map<dynamic, dynamic>?) ??
        <dynamic, dynamic>{};
    final Map<dynamic, dynamic> icon =
        (app['icon'] as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};
    final dynamic liveAppIcon = icon['url'] ?? map['app_icon_url'];
    final String resolvedAppIcon =
        liveAppIcon == null || liveAppIcon.toString().trim().isEmpty
        ? appIconUrl
        : AppConfig.mapEmulatorUrl(liveAppIcon.toString().trim());

    String pickText(String inner, String flat, String inherited) {
      // کلید موجود یعنی مقدار خالی هم عمدی است | نه برگشت به کش قدیمی.
      if (splash.containsKey(inner)) {
        final dynamic a = splash[inner];
        return a == null ? '' : a.toString().trim();
      }
      if (map.containsKey(flat)) {
        final dynamic b = map[flat];
        return b == null ? '' : b.toString().trim();
      }
      return inherited;
    }

    final Map<dynamic, dynamic> supportBlock = (map['support'] is Map)
        ? (map['support'] as Map).cast<dynamic, dynamic>()
        : <dynamic, dynamic>{};
    final Map<dynamic, dynamic> aboutBlock = (map['about'] is Map)
        ? (map['about'] as Map).cast<dynamic, dynamic>()
        : <dynamic, dynamic>{};

    String blockText(
      Map<dynamic, dynamic> block,
      String key,
      String inherited,
    ) {
      // غایب یعنی قدیم حفظ شود | موجود ولی خالی یعنی عمداً پاک شده.
      if (!block.containsKey(key) || block[key] == null) return inherited;
      return block[key].toString().trim();
    }

    List<AboutBadge> blockBadges(
      Map<dynamic, dynamic> block,
      List<AboutBadge> inherited,
    ) {
      if (!block.containsKey('badges')) return inherited;
      // لیست خالی عمدی یعنی همه نشان‌ها حذف شدهاند | قدیم برنگردد.
      return parseBadges(block['badges']);
    }

    bool pickBool(String inner, String flat, bool inherited) {
      final dynamic a = splash.containsKey(inner)
          ? splash[inner]
          : (map.containsKey(flat) ? map[flat] : null);
      if (a != null) {
        return a == true || a == 1 || a == '1';
      }
      return inherited;
    }

    return AppConfig(
      appName: appName,
      siteUrl: siteUrl,
      primaryColor: primaryColor,
      apiBaseUrl: apiBaseUrl,
      renderMode: renderMode,
      categoryCanvas: categoryCanvas,
      banners: banners,
      sliderInterval: sliderInterval,
      offerCountdownEnd: offerCountdownEnd,
      logoUrl: logoUrl,
      appIconUrl: resolvedAppIcon,
      headerLogoUrl: headerLogoUrl,
      headerLogoName: headerLogoName,
      searchSuggestions: searchSuggestions,
      reviewsRequireLogin: reviewsRequireLogin,
      reviewsGuestPost: reviewsGuestPost,
      splashImageUrl: AppConfig.mapEmulatorUrl(
        pickText('url', 'splash_image_url', splashImageUrl),
      ),
      splashLogoUrl: AppConfig.mapEmulatorUrl(
        pickText('logo_url', 'splash_logo_url', splashLogoUrl),
      ),
      splashBackgroundHex: pickText(
        'bg_color',
        'splash_bg_color',
        splashBackgroundHex,
      ),
      splashText: pickText('text', 'splash_text', splashText),
      splashTextHex: pickText('text_color', 'splash_text_color', splashTextHex),
      splashShowLogo: pickBool('show_logo', 'splash_show_logo', splashShowLogo),
      splashSiteIconUrl: AppConfig.mapEmulatorUrl(
        pickText('site_icon_url', 'splash_site_icon', splashSiteIconUrl),
      ),
      splashSiteName: pickText('site_name', 'splash_site_name', splashSiteName),
      // اطلاعات تماس و درباره ما | اگر بلوک در پاسخ نبود، مقدار فعلی حفظ می‌شود.
      supportStoreName: blockText(supportBlock, 'store_name', supportStoreName),
      supportStorePhone: blockText(
        supportBlock,
        'store_phone',
        supportStorePhone,
      ),
      aboutText: blockText(aboutBlock, 'text', aboutText),
      aboutBadges: blockBadges(aboutBlock, aboutBadges),
      announcement: map.containsKey('announcement')
          ? AppConfig.parseAnnouncement(map['announcement'])
          : announcement,
      // تنظیم ۱۴ | تسویه‌حساب نیتیو | از پاسخ سرور عیناً منتقل میشود.
      checkoutMode: checkoutMode,
      ordersPerPage: ordersPerPage,
      requirePostcode: requirePostcode,
      requireOrderNote: requireOrderNote,
      enableCoupons: enableCoupons,
      defaultShippingCost: defaultShippingCost,
      deepLinkScheme: deepLinkScheme,
      paymentGateway: paymentGateway,
      paymentSandbox: paymentSandbox,
      bazaarUseLocalSignatureCheck: bazaarUseLocalSignatureCheck,
      bazaarRsaPublicKey: bazaarRsaPublicKey,
      pendingOrderPayEnabled: pendingOrderPayEnabled,
      favoritesEnabled: favoritesEnabled,
      relatedProductsEnabled: relatedProductsEnabled,
      orderTimelineEnabled: orderTimelineEnabled,
      recentlyViewedEnabled: recentlyViewedEnabled,
      searchHistoryEnabled: searchHistoryEnabled,
      sortFilterEnabled: sortFilterEnabled,
      // این دو مقدار در زمان بیلد تثبیت شدهاند و هرگز از راه دور بازنویسی نمیشوند.
      splashLogoBundledUrl: pickText(
        'logo_bundled_url',
        'splash_logo_bundled_url',
        splashLogoBundledUrl,
      ),
    );
  }

  Future<AppConfig> refreshRemoteSettings() async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final HttpClientRequest request = await client.getUrl(
        Uri.parse('${effectiveApiBaseUrl}config'),
      );
      final HttpClientResponse response = await request.close();
      if (response.statusCode != 200) return this;
      final String body = await response.transform(utf8.decoder).join();
      final dynamic decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return this;
      return withRemoteSettings(decoded);
    } catch (_) {
      return this;
    } finally {
      client?.close(force: true);
    }
  }

  AppConfig withRemoteSettings(Map<String, dynamic> decoded) {
    final Map<dynamic, dynamic> checkoutBlock = (decoded['checkout'] is Map)
        ? (decoded['checkout'] as Map).cast<dynamic, dynamic>()
        : <dynamic, dynamic>{};
    final Map<dynamic, dynamic> paymentBlock = (decoded['payment'] is Map)
        ? (decoded['payment'] as Map).cast<dynamic, dynamic>()
        : <dynamic, dynamic>{};
    final String remoteScheme = ((decoded['deep_link_scheme'] as String?) ?? '')
        .trim();

    final AppConfig base = AppConfig(
      appName: appName,
      siteUrl: siteUrl,
      primaryColor: primaryColor,
      apiBaseUrl: apiBaseUrl,
      renderMode: renderMode,
      categoryCanvas:
          (decoded['category_canvas_size'] as num?)?.toInt() ?? categoryCanvas,
      banners: AppConfig.parseBanners(decoded['native_banners']),
      offerCountdownEnd: ((decoded['offer_countdown_end'] as String?) ?? '')
          .trim(),
      logoUrl: AppConfig.mapEmulatorUrl(
        ((decoded['logo_url'] as String?) ?? '').trim(),
      ),
      appIconUrl: AppConfig.mapEmulatorUrl(
        (((decoded['app'] as Map?)?['icon'] as Map?)?['url'] as String? ??
                appIconUrl)
            .trim(),
      ),
      headerLogoUrl: AppConfig.mapEmulatorUrl(
        (((decoded['header_logo'] as Map?)?['url'] as String?) ?? '').trim(),
      ),
      headerLogoName:
          (((decoded['header_logo'] as Map?)?['name'] as String?) ?? '').trim(),
      // اگر پاسخ سرور کلید را نداشت، مقدار پخته‌شده در APK حفظ می‌شود.
      searchSuggestions: decoded.containsKey('search_suggestions')
          ? AppConfig.parseSuggestions(decoded['search_suggestions'])
          : searchSuggestions,
      reviewsRequireLogin: decoded['reviews_require_login'] == true,
      reviewsGuestPost: decoded['reviews_guest_post'] != false,
      sliderInterval:
          ((decoded['slider_interval'] as num?)?.toInt() ?? sliderInterval)
              .clamp(3, 15),
      supportStoreName: supportStoreName,
      supportStorePhone: supportStorePhone,
      aboutText: aboutText,
      aboutBadges: aboutBadges,
      announcement: decoded.containsKey('announcement')
          ? AppConfig.parseAnnouncement(decoded['announcement'])
          : announcement,
      // تنظیم ۱۴ | تسویه‌حساب نیتیو | مقادیر غایب یعنی قدیم حفظ شود.
      checkoutMode: ((checkoutBlock['mode'] as String?) == 'webview')
          ? 'webview'
          : 'native',
      ordersPerPage:
          (checkoutBlock['orders_per_page'] as num?)?.toInt() ?? ordersPerPage,
      requirePostcode: checkoutBlock['require_postcode'] == null
          ? requirePostcode
          : checkoutBlock['require_postcode'] == true,
      requireOrderNote: checkoutBlock['require_order_note'] == null
          ? requireOrderNote
          : checkoutBlock['require_order_note'] == true,
      enableCoupons: checkoutBlock['enable_coupons'] == null
          ? enableCoupons
          : checkoutBlock['enable_coupons'] == true,
      defaultShippingCost:
          (checkoutBlock['default_shipping_cost'] as num?)?.toInt() ??
          defaultShippingCost,
      deepLinkScheme: remoteScheme.isEmpty ? deepLinkScheme : remoteScheme,
      // تنظیم ۱۵ | درگاه پرداخت + تیک امضای محلی RSA بازار.
      paymentGateway:
          ((paymentBlock['gateway'] as String?) ?? paymentGateway)
              .trim()
              .isEmpty
          ? paymentGateway
          : ((paymentBlock['gateway'] as String?) ?? paymentGateway).trim(),
      paymentSandbox: paymentBlock['sandbox'] == null
          ? paymentSandbox
          : paymentBlock['sandbox'] == true,
      // تنظیم ۱۷ | پرداخت دوبارهٔ سفارش معلق | غیبت کلید یعنی قدیم حفظ شود.
      pendingOrderPayEnabled: paymentBlock['pending_order_pay_enabled'] == null
          ? pendingOrderPayEnabled
          : paymentBlock['pending_order_pay_enabled'] == true,
      // تنظیم ۱۸ | علاقه‌مندی‌ها | کلید در سطح ریشهٔ /config.
      favoritesEnabled: decoded.containsKey('favorites_enabled')
          ? decoded['favorites_enabled'] == true
          : favoritesEnabled,
      // تنظیم ۱۹ | محصولات مرتبط | کلید در سطح ریشهٔ /config.
      relatedProductsEnabled: decoded.containsKey('related_products_enabled')
          ? decoded['related_products_enabled'] == true
          : relatedProductsEnabled,
      // تنظیم ۲۰ | تایم‌لاین وضعیت سفارش | کلید در سطح ریشهٔ /config.
      orderTimelineEnabled: decoded.containsKey('order_timeline_enabled')
          ? decoded['order_timeline_enabled'] == true
          : orderTimelineEnabled,
      // تنظیم ۲۱ | بازدیدهای اخیر | کلید در سطح ریشهٔ /config.
      recentlyViewedEnabled: decoded.containsKey('recently_viewed_enabled')
          ? decoded['recently_viewed_enabled'] == true
          : recentlyViewedEnabled,
      // تنظیم ۲۲ | تاریخچهٔ جستجوهای اخیر | کلید در سطح ریشهٔ /config.
      searchHistoryEnabled: decoded.containsKey('search_history_enabled')
          ? decoded['search_history_enabled'] == true
          : searchHistoryEnabled,
      // تنظیم ۲۳ | مرتب‌سازی و فیلتر موجودی | کلید در سطح ریشهٔ /config.
      sortFilterEnabled: decoded.containsKey('sort_filter_enabled')
          ? decoded['sort_filter_enabled'] == true
          : sortFilterEnabled,
      bazaarUseLocalSignatureCheck:
          paymentBlock['use_local_signature_check'] == null
          ? bazaarUseLocalSignatureCheck
          : paymentBlock['use_local_signature_check'] == true,
      bazaarRsaPublicKey: paymentBlock['rsa_public_key'] == null
          ? bazaarRsaPublicKey
          : ((paymentBlock['rsa_public_key'] as String?) ?? '').trim(),
      // مقادیر اسپلش عیناً منتقل میشوند تا اگر پاسخ سرور ناقص بود، مقدار فعلی از دست نرود.
      splashImageUrl: splashImageUrl,
      splashLogoUrl: splashLogoUrl,
      splashBackgroundHex: splashBackgroundHex,
      splashText: splashText,
      splashTextHex: splashTextHex,
      splashShowLogo: splashShowLogo,
      splashSiteIconUrl: splashSiteIconUrl,
      splashSiteName: splashSiteName,
      // واقعیت زمان بیلد | همیشه از داخل اپ میآید، نه از سرور.
      splashLogoBundledUrl: splashLogoBundledUrl,
    );

    return base.withSplash(decoded);
  }

  Future<void> cacheSplash() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('wptf_app_icon_url', appIconUrl);
      await prefs.setString('wptf_splash_url', splashImageUrl);
      await prefs.setString('wptf_splash_logo_url', splashLogoUrl);
      await prefs.setString(
        'wptf_splash_logo_bundled_url',
        splashLogoBundledUrl,
      );
      await prefs.setBool('wptf_splash_show_logo', splashShowLogo);
      await prefs.setString('wptf_splash_site_icon', splashSiteIconUrl);
      await prefs.setString('wptf_splash_site_name', splashSiteName);
      await prefs.setString('wptf_splash_bg', splashBackgroundHex);
      await prefs.setString('wptf_splash_text', splashText);
      await prefs.setString('wptf_splash_text_color', splashTextHex);
      // تیک امضای محلی RSA بازار | کش میشود تا در لانچ بعدی قبل از کانفیگ تازه اعمال شود.
      await prefs.setBool(
        'wptf_bazaar_local_check',
        bazaarUseLocalSignatureCheck,
      );
      await prefs.setString('wptf_bazaar_rsa_key', bazaarRsaPublicKey);
    } catch (_) {}
  }

  static List<NativeBanner> parseBanners(dynamic raw) {
    return (raw is List ? raw : const <dynamic>[])
        .map((dynamic item) {
          if (item is Map<String, dynamic>) {
            return NativeBanner(
              image: AppConfig.mapEmulatorUrl(
                ((item['image'] as String?) ?? '').trim(),
              ),
              link: ((item['link'] as String?) ?? '').trim(),
            );
          }
          if (item is String) {
            return NativeBanner(image: AppConfig.mapEmulatorUrl(item.trim()));
          }
          return null;
        })
        .whereType<NativeBanner>()
        .where((NativeBanner banner) => banner.image.isNotEmpty)
        .toList(growable: false);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppConfig config = await AppConfig.load();
  // درگاه پرداخت درون‌برنامه‌ای کافه‌بازار | فقط روی اندروید وصل میشود.
  // تیک امضای محلی RSA از تنظیم ۱۵ میآید | کش قبلی تا رسیدن کانفیگ تازه معتبر است.
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool cachedLocalCheck =
      prefs.getBool('wptf_bazaar_local_check') ?? false;
  final String cachedRsaKey = prefs.getString('wptf_bazaar_rsa_key') ?? '';
  final String? rsaKey;
  if (cachedLocalCheck && cachedRsaKey.isNotEmpty) {
    rsaKey = cachedRsaKey;
  } else if (config.bazaarUseLocalSignatureCheck &&
      config.bazaarRsaPublicKey.isNotEmpty) {
    rsaKey = config.bazaarRsaPublicKey;
  } else {
    // null یعنی بررسی امضای محلی خاموش | اعتبارسنجی سمت سرور انجام میشود.
    rsaKey = null;
  }
  BazaarPayments.instance.init(
    apiBase: config.effectiveApiBaseUrl,
    rsaKey: rsaKey,
  );
  runApp(WpToFlutterApp(config: config));
}

class WpToFlutterApp extends StatelessWidget {
  const WpToFlutterApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: config.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // فونت پایهٔ کل اپ | همهٔ متن‌ها (مثل عنوان/متن/دکمهٔ اعلان) از همین
        // خانواده ارث میبرند؛ ارقام فارسی و لاتین هر دو در وزیرمتن هست.
        fontFamily: 'Vazirmatn',
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: config.primaryColor,
          surface: Colors.white,
        ).copyWith(primary: config.primaryColor),
        appBarTheme: AppBarTheme(
          backgroundColor: config.primaryColor,
          foregroundColor: Colors.white,
        ),
        // حذف هاله قهوه‌ای Material 3 | surfaceTint روی مودال/دیالوگ اعمال نمیشود.
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Colors.black,
          contentTextStyle: TextStyle(color: Colors.white, fontSize: 13),
          behavior: SnackBarBehavior.floating,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          modalBackgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: _SplashGate(config: config),
    );
  }
}

class _SplashGate extends StatefulWidget {
  const _SplashGate({required this.config});

  final AppConfig config;

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// حداقل زمان نمایش اسپلش | تا انیمیشن برند و لوگو دیده شود.
  static const Duration _minimumSplash = Duration(milliseconds: 2000);

  /// سقف انتظار برای آماده شدن محتوا | اگر سایت دیر جواب داد، اسپلش بیشتر از این نمیماند.
  static const Duration _maximumSplash = Duration(milliseconds: 7000);

  /// محو شدن پایانی | پس از آن اسپلش کاملاً برداشته میشود.
  static const Duration _fadeOut = Duration(milliseconds: 250);
  static const Duration _remoteSettingsCooldown = Duration(seconds: 30);
  static const Duration _remoteSettingsTimeout = Duration(seconds: 15);
  static const Duration _remoteSettingsRetryDelay = Duration(seconds: 1);
  static const Duration _resumeAnnouncementDelay = Duration(milliseconds: 500);

  late final AnimationController _fade;
  Timer? _minimumTimer;
  Timer? _ceilingTimer;
  Timer? _remoteSettingsRetryTimer;
  StreamSubscription<Uri>? _linkSub;
  final Set<String> _handledPaymentLinks = <String>{};
  final Set<String> _paymentLinksInFlight = <String>{};
  late AppConfig _current;
  AppConfig? _pending;
  bool _minimumElapsed = false;
  bool _contentReady = false;
  bool _dismissing = false;
  bool _splashGone = false;
  bool _wasBackgrounded = false;
  bool _remoteSettingsLoading = false;
  bool _initialRemoteRetryScheduled = false;
  bool _announcementDialogOpen = false;
  bool _announcementCheckInProgress = false;
  int _foregroundCycle = 0;
  int _lastAnnouncementCycle = -1;
  DateTime? _lastRemoteSettingsRefresh;

  /// تنظیمهای ۱۸ و ۲۱ و ۲۲ | گیت نمایش قلبها، بازدیدهای اخیر و تاریخچهٔ
  /// جستجو همیشه با همین _current همگام میشود | WpToFlutterApp فقط با
  /// کانفیگ سردِ داخل APK بیلد میشود و با آمدن /config زنده هرگز دوباره
  /// اجرا نمیشود | پس همگامسازی اینجاست و همیشه بیرون از build، بعد از
  /// هر جایگذاری _current.
  void _syncLocalUiToggles() {
    FavoritesManager.instance.setUiEnabled(_current.favoritesEnabled);
    RecentlyViewedManager.instance.setUiEnabled(_current.recentlyViewedEnabled);
    SearchHistoryManager.instance.setUiEnabled(_current.searchHistoryEnabled);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _current = widget.config;
    _syncLocalUiToggles();

    // نسخه نیتیو سیگنال «آماده شد» ندارد و محتوایش از ابتدا هست، پس فقط حداقل زمان.
    _contentReady = _current.isNative;

    _fade = AnimationController(vsync: this, duration: _fadeOut, value: 1.0)
      ..addStatusListener((AnimationStatus status) {
        if (status != AnimationStatus.dismissed || !mounted) {
          return;
        }
        // اسپلش کاملاً کنار رفت | حالا تنظیمات تازه آزادانه اعمال میشوند.
        setState(() {
          _splashGone = true;
          final AppConfig? pending = _pending;
          _pending = null;
          if (pending != null) {
            _current = pending;
            _syncLocalUiToggles();
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_maybeShowAnnouncement());
        });
      });

    _minimumTimer = Timer(_minimumSplash, () {
      _minimumElapsed = true;
      _maybeDismiss();
    });

    _ceilingTimer = Timer(_maximumSplash, () {
      _contentReady = true;
      _maybeDismiss();
    });

    // دریافت تنظیمات در پسزمینه (هم وبویو و هم نیتیو) کاملاً غیرمسدودکننده.
    _syncRemoteSettings(force: true);

    // دیپ‌لینک بازگشت از درگاه پرداخت | wptoflutter://payment-result
    _listenDeepLinks();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reconcileBankPayment(),
    );
  }

  /// رهگیری دیپ‌لینک نتیجه پرداخت | مرورگرِ درگاه بعد از تأیید به اپ برمیگردد.
  Future<void> _listenDeepLinks() async {
    try {
      final AppLinks links = AppLinks();
      _linkSub = links.uriLinkStream.listen(
        (Uri uri) => _handlePaymentDeepLink(uri),
        onError: (Object error) {},
      );
      final Uri? initialLink = await links.getInitialLink();
      if (initialLink != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _handlePaymentDeepLink(initialLink),
        );
      }
    } catch (_) {}
  }

  Future<void> _reconcileBankPayment() async {
    if (!mounted ||
        BankPayments.instance.checkoutBusy ||
        _paymentLinksInFlight.isNotEmpty) {
      return;
    }
    try {
      final BankOrderStatus? result = await BankPayments.instance.reconcile(
        _current.effectiveApiBaseUrl,
      );
      if (!mounted ||
          _paymentLinksInFlight.isNotEmpty ||
          result == null ||
          !result.paid) {
        return;
      }
      await _handlePaymentDeepLink(
        Uri(
          scheme: _current.deepLinkScheme.trim().isEmpty
              ? 'wptoflutter'
              : _current.deepLinkScheme.trim(),
          host: 'payment-result',
          queryParameters: <String, String>{
            'status': 'success',
            'order_id': '${result.order.id}',
            'ref_id': result.refId,
          },
        ),
      );
    } catch (_) {}
  }

  /// نتیجه پرداخت از مرورگر رسید | سبد در موفقیت خالی و صفحه نتیجه باز میشود.
  Future<void> _handlePaymentDeepLink(Uri uri) async {
    final String scheme = _current.deepLinkScheme.trim().isEmpty
        ? 'wptoflutter'
        : _current.deepLinkScheme.trim();
    if (uri.scheme.toLowerCase() != scheme.toLowerCase()) {
      return;
    }
    // بعضی درگاه‌ها لینک را بدون //host برمی‌گردانند؛ در آن حالت مقدار در path است.
    final String host = uri.host.toLowerCase();
    final String path = uri.path.replaceFirst(RegExp(r'^/'), '').toLowerCase();
    if (host != 'payment-result' && path != 'payment-result') {
      return;
    }
    final String status = (uri.queryParameters['status'] ?? '').toLowerCase();
    final int orderId =
        int.tryParse(uri.queryParameters['order_id'] ?? '') ?? 0;
    if (status == 'success' && orderId <= 0) return;
    final String identity = orderId > 0 ? '$orderId:$status' : uri.toString();
    if (!mounted ||
        _handledPaymentLinks.contains(identity) ||
        !_paymentLinksInFlight.add(identity)) {
      return;
    }
    try {
      unawaited(closeInAppWebView().catchError((Object error) {}));
      if (status == 'success') {
        _handledPaymentLinks.add(identity);
      }
      final PageRoute<void> resultRoute = PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PaymentResultScreen(uri: uri, config: _current),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
      if (status == 'success') {
        Navigator.of(context).pushAndRemoveUntil<void>(
          resultRoute,
          (Route<dynamic> route) => route.isFirst,
        );
      } else {
        Navigator.of(context).push<void>(resultRoute);
      }
      if (status == 'success') {
        await Future<void>(() async {
          if (await BankPayments.instance.complete(
            _current.effectiveApiBaseUrl,
            orderId,
          )) {
            CartManager.instance.clearCart();
          }
        });
      }
    } catch (_) {
    } finally {
      _paymentLinksInFlight.remove(identity);
    }
  }

  /// وبویو خبر میدهد که صفحه آماده است (onPageFinished یا خطای صفحه اصلی).
  void _onContentReady() {
    if (_contentReady) {
      return;
    }
    _contentReady = true;
    _maybeDismiss();
  }

  /// اسپلش فقط وقتی کنار میرود که هم حداقل زمان گذشته باشد و هم محتوا آماده باشد.
  void _maybeDismiss() {
    if (!mounted || _dismissing || _splashGone) {
      return;
    }
    if (!_minimumElapsed || !_contentReady) {
      return;
    }
    _dismissing = true;
    _fade.reverse();
  }

  Future<void> _syncRemoteSettings({bool force = false}) async {
    if (_remoteSettingsLoading) return;
    final DateTime now = DateTime.now();
    if (!force &&
        _lastRemoteSettingsRefresh != null &&
        now.difference(_lastRemoteSettingsRefresh!) < _remoteSettingsCooldown) {
      return;
    }
    _remoteSettingsLoading = true;
    try {
      final AppConfig previous = _current;
      final AppConfig updated = await previous.refreshRemoteSettings().timeout(
        _remoteSettingsTimeout,
        onTimeout: () => previous,
      );
      if (identical(updated, previous)) {
        if (force && !_initialRemoteRetryScheduled && mounted) {
          _initialRemoteRetryScheduled = true;
          _remoteSettingsRetryTimer = Timer(_remoteSettingsRetryDelay, () {
            _remoteSettingsRetryTimer = null;
            if (mounted) unawaited(_syncRemoteSettings(force: true));
          });
        }
        return;
      }
      _remoteSettingsRetryTimer?.cancel();
      _remoteSettingsRetryTimer = null;
      _lastRemoteSettingsRefresh = DateTime.now();
      unawaited(updated.cacheSplash());
      if (_splashGone) {
        // اسپلش تمام شده | تغییرات آزادانه اعمال میشود.
        if (mounted) {
          setState(() {
            _current = updated;
            _syncLocalUiToggles();
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_maybeShowAnnouncement());
          });
        }
      } else {
        // وسط اسپلش | تا پایان آن نگه داشته میشود تا رنگ و لوگو ناگهان عوض نشوند.
        _pending = updated;
      }
    } catch (_) {
    } finally {
      _remoteSettingsLoading = false;
    }
  }

  bool get _canPresentAnnouncement {
    if (!mounted ||
        !_splashGone ||
        !_current.isNative ||
        _announcementDialogOpen ||
        _paymentLinksInFlight.isNotEmpty ||
        BankPayments.instance.checkoutBusy) {
      return false;
    }
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  Future<void> _maybeShowAnnouncement() async {
    if (_announcementCheckInProgress ||
        _lastAnnouncementCycle == _foregroundCycle ||
        !_canPresentAnnouncement) {
      return;
    }
    _announcementCheckInProgress = true;
    try {
      final AppAnnouncement announcement = _current.announcement;
      final AnnouncementSeenStore seenStore = AnnouncementSeenStore();
      final NavigatorState navigator = Navigator.of(context);
      if (!await seenStore.shouldShow(announcement) ||
          !_canPresentAnnouncement ||
          _lastAnnouncementCycle == _foregroundCycle ||
          !navigator.mounted) {
        return;
      }

      await seenStore.markShown(announcement);
      _lastAnnouncementCycle = _foregroundCycle;
      _announcementDialogOpen = true;
      if (!mounted || !navigator.mounted) return;
      final bool? openAction = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) => AnnouncementDialog(
          announcement: announcement,
          primaryColor: _current.primaryColor,
        ),
      );
      _announcementDialogOpen = false;
      if (openAction != true || !mounted || !navigator.mounted) return;

      if (announcement.hasProductTarget) {
        final WpItem product = WpItem.fromMap(announcement.productPayload!);
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => NativeDetailScreen(item: product, config: _current),
          ),
        );
      } else {
        final Uri? uri = announcement.validLinkUri;
        if (uri != null) {
          navigator.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => NativeWebViewScreen(
                title: announcement.title,
                url: AppConfig.mapEmulatorUrl(uri.toString()),
              ),
            ),
          );
        }
      }
    } catch (_) {
    } finally {
      _announcementDialogOpen = false;
      _announcementCheckInProgress = false;
    }
  }

  Future<void> _refreshAndShowAnnouncement() async {
    await Future<void>.delayed(_resumeAnnouncementDelay);
    if (!mounted || !_splashGone || !_canPresentAnnouncement) return;
    await _syncRemoteSettings();
    if (mounted) await _maybeShowAnnouncement();
  }

  /// بازگشت به اپ از دیالوگ پرداخت بازار | اتصال و بازیابی خریدهای مصرفنشده.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
    }
    if (state != AppLifecycleState.resumed) {
      return;
    }
    if (_paymentLinksInFlight.isEmpty) {
      unawaited(_reconcileBankPayment());
    }
    if (BazaarPayments.instance.state == BazaarState.connected) {
      BazaarPayments.instance.recoverPurchases();
    } else {
      BazaarPayments.instance.connect();
    }
    if (_wasBackgrounded) {
      _wasBackgrounded = false;
      _foregroundCycle++;
      unawaited(_refreshAndShowAnnouncement());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _minimumTimer?.cancel();
    _ceilingTimer?.cancel();
    _remoteSettingsRetryTimer?.cancel();
    _linkSub?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fade,
      builder: (BuildContext context, Widget? child) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _current.isNative
                ? NativeHomeScreen(config: _current)
                : WebViewHomeScreen(config: _current, onReady: _onContentReady),
            if (!_splashGone)
              // تا پایان اسپلش لمسها جذب میشوند تا کاربر تصادفی روی وبویو کلک نکند.
              IgnorePointer(
                child: Opacity(
                  opacity: _fade.value,
                  child: SplashScreen(config: _current),
                ),
              ),
          ],
        );
      },
    );
  }
}

class WebViewHomeScreen extends StatefulWidget {
  const WebViewHomeScreen({super.key, required this.config, this.onReady});

  final AppConfig config;

  /// وقتی اولین صفحه آماده شد صدا زده میشود تا اسپلش برداشته شود.
  final VoidCallback? onReady;

  @override
  State<WebViewHomeScreen> createState() => _WebViewHomeScreenState();
}

class _WebViewHomeScreenState extends State<WebViewHomeScreen> {
  late final WebViewController _controller;
  late final bool _isLocalSite;
  double _progress = 0;
  bool _hasError = false;
  bool _hasLoadedOnce = false;
  bool _readyReported = false;

  /// خبر دادن آمادهشدن | فقط یکبار، تا اسپلش دیرتر از موعد برداشته نشود.
  void _reportReady() {
    if (_readyReported) {
      return;
    }
    _readyReported = true;
    widget.onReady?.call();
  }

  static const String _mobileFixesJs = r'''
(function() {
  try {
    var head = document.head || document.documentElement;
    if (!head) { return; }
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'viewport';
      head.appendChild(meta);
    }
    meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
    if (!document.getElementById('wptf-universal-mobile-fix')) {
      var style = document.createElement('style');
      style.id = 'wptf-universal-mobile-fix';
      style.textContent =
        'html, body { overflow-x: hidden !important; max-width: 100vw !important; width: 100% !important; -webkit-overflow-scrolling: touch !important; } ' +
        'img, video, iframe, table { max-width: 100% !important; height: auto !important; } ' +
        '#wpadminbar { display: none !important; }';
      head.appendChild(style);
    }
    document.documentElement.style.overflowX = 'hidden';
    if (document.body) { document.body.style.overflowX = 'hidden'; }
    var fix = function (value) { return String(value).replace('://localhost/', '://10.0.2.2/'); };
    var images = document.querySelectorAll('img[src], img[data-src], img[srcset]');
    for (var i = 0; i < images.length; i++) {
      var img = images[i];
      if (img.src && img.src.indexOf('://localhost/') !== -1) { img.src = fix(img.src); }
      if (img.dataset && img.dataset.src && img.dataset.src.indexOf('://localhost/') !== -1) { img.dataset.src = fix(img.dataset.src); }
      if (img.srcset && img.srcset.indexOf('://localhost/') !== -1) { img.srcset = fix(img.srcset); }
    }
    var links = document.querySelectorAll('a[href^="http://localhost/"]');
    for (var j = 0; j < links.length; j++) {
      links[j].href = fix(links[j].href);
    }
  } catch (e) {}
})();
''';

  @override
  void initState() {
    super.initState();
    final Uri siteUri = Uri.tryParse(widget.config.siteUrl) ?? Uri();
    final String siteHost = siteUri.host.toLowerCase();
    _isLocalSite =
        siteHost == 'localhost' ||
        siteHost == '127.0.0.1' ||
        siteHost == '10.0.2.2';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            const List<String> externalSchemes = <String>[
              'tel',
              'mailto',
              'sms',
              'whatsapp',
              'intent',
              'geo',
              'market',
            ];
            final Uri? uri = Uri.tryParse(request.url);
            final String scheme = (uri?.scheme ?? '').toLowerCase();
            if (externalSchemes.contains(scheme)) {
              return NavigationDecision.prevent;
            }

            if (_isLocalSite &&
                Platform.isAndroid &&
                (scheme == 'http' || scheme == 'https') &&
                uri != null) {
              final String host = uri.host.toLowerCase();
              if (host == 'localhost' || host == '127.0.0.1') {
                final Uri mapped = uri.replace(host: '10.0.2.2');
                if (mapped.toString() != request.url) {
                  _controller.loadRequest(mapped);
                  return NavigationDecision.prevent;
                }
              }
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() => _hasError = false);
            }
            _injectMobileFixes();
          },
          onPageFinished: (String url) {
            _injectMobileFixes();
            if (mounted) {
              setState(() => _hasLoadedOnce = true);
            }
            // صفحه آماده است | اسپلش اجازه برداشته شدن میگیرد.
            _reportReady();
          },
          onProgress: (int progress) {
            if (mounted) {
              setState(() => _progress = progress / 100.0);
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted && error.isForMainFrame == true && !_hasLoadedOnce) {
              setState(() => _hasError = true);
              // سایت بالا نیامد | اسپلش نباید تا سقف ۷ ثانیه منتظر بماند.
              _reportReady();
            }
          },
        ),
      );

    if (_controller.platform is AndroidWebViewController) {
      final AndroidWebViewController androidController =
          _controller.platform as AndroidWebViewController;
      androidController
        ..setMixedContentMode(MixedContentMode.alwaysAllow)
        ..setUseWideViewPort(true)
        ..enableZoom(true)
        ..setOverScrollMode(WebViewOverScrollMode.ifContentScrolls);
    }

    _controller.loadRequest(Uri.parse(widget.config.siteUrl));
  }

  Future<void> _injectMobileFixes() async {
    try {
      await _controller.runJavaScript(_mobileFixesJs);
    } catch (_) {}
  }

  void _retry() {
    setState(() => _hasError = false);
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            if (_progress > 0 && _progress < 1)
              LinearProgressIndicator(
                value: _progress,
                minHeight: 3,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.config.primaryColor,
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  RefreshIndicator(
                    color: widget.config.primaryColor,
                    onRefresh: () => _controller.reload(),
                    child: WebViewWidget(controller: _controller),
                  ),
                  // لودینگ دومی وجود ندارد | اسپلش برند تا آماده شدن همین صفحه روی آن میماند.
                  if (_hasError)
                    OfflineErrorScreen(config: widget.config, onRetry: _retry),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OfflineErrorScreen extends StatelessWidget {
  const OfflineErrorScreen({
    super.key,
    required this.config,
    required this.onRetry,
  });

  final AppConfig config;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.white,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 72,
                      color: config.primaryColor,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'اتصال اینترنت برقرار نیست',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: config.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'لطفاً اتصال اینترنت گوشی خود را بررسی کنید و دوباره تلاش کنید.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.9,
                        color: Color(0xFF646970),
                      ),
                    ),
                    const SizedBox(height: 26),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('تلاش مجدد'),
                      style: FilledButton.styleFrom(
                        backgroundColor: config.primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
