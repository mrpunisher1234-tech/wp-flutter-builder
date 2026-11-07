import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'native_mode.dart';

/// بنر اسلایدر خانه | تصویر + لینک مقصد (لینک خالی = کلیک‌ناپذیر).
class NativeBanner {
  const NativeBanner({required this.image, this.link = ''});

  final String image;
  final String link;
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
    this.headerLogoUrl = '',
    this.headerLogoName = '',
    this.searchSuggestions = const <String>[],
    this.reviewsRequireLogin = false,
    this.reviewsGuestPost = true,
  });

  final String appName;
  final String siteUrl;
  final Color primaryColor;
  final String apiBaseUrl;
  final String renderMode;

  /// اندازه کانواس دسته‌بندی (پیکسل) | از تنظیمات WP خوانده می‌شود.
  /// دایره‌ی نمایشی = این مقدار ÷ ۴ (کلمپ ۶۴ تا ۱۲۸)، در skeleton.dart.
  final int categoryCanvas;

  /// بنرهای اسلایدر خانه (حداکثر ۴) | به ترتیب نمایش، از تنظیمات WP.
  final List<NativeBanner> banners;

  /// فاصله تعویض خودکار اسلایدها (ثانیه).
  final int sliderInterval;

  /// پایان شمارش معکوس «پیشنهاد شگفت‌انگیز» | ISO-8601 با آفست سایت.
  /// خالی = بدون شمارش معکوس.
  final String offerCountdownEnd;

  /// لوگوی سایت (از endpoint تنظیمات) | اگر باشد در هدر نیتیو نمایش
  /// داده می‌شود؛ وگرنه نام اپ به‌شکل نشان برند.
  final String logoUrl;

  /// لوگوی نهایی هدر طبق تصمیم سرور (کارت تنظیم نیتیو شماره ۴):
  /// اختصاصی فعال؟ → همان؛ وگرنه لوگوی سایت. خالی = بدون تصویر.
  final String headerLogoUrl;

  /// نام کنار لوگوی هدر | خالی یعنی فقط لوگو.
  final String headerLogoName;

  /// واژه‌های پیشنهادی جستجو (تنظیم نیتیو شماره ۵) | حداکثر ۴.
  final List<String> searchSuggestions;

  /// دیدگاه فقط برای کاربران واردشده با شماره موبایل (کارت ۸).
  final bool reviewsRequireLogin;

  /// مهمان‌ها بدون هدایت به پروفایل بتوانند دیدگاه بدهند (حالت مقابل).
  final bool reviewsGuestPost;

  bool get isNative => renderMode == 'native';

  /// Resolved REST root consumed by the native render mode.
  String get effectiveApiBaseUrl {
    if (apiBaseUrl.isNotEmpty) {
      return apiBaseUrl.endsWith('/') ? apiBaseUrl : '$apiBaseUrl/';
    }
    final String base = siteUrl.endsWith('/') ? siteUrl : '$siteUrl/';
    return '${base}wp-json/wp-to-flutter/v1/';
  }

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    final String rawApiBase = ((map['api_base_url'] as String?) ?? '').trim();
    return AppConfig(
      appName: _readName(map['app_name']),
      siteUrl: normalizeSiteUrl((map['site_url'] as String?) ?? ''),
      primaryColor: parseHexColor(
        (map['primary_color'] as String?) ?? '',
        fallback: const Color(0xFF2271B1),
      ),
      apiBaseUrl:
          rawApiBase.isEmpty ? '' : normalizeSiteUrl(rawApiBase),
      renderMode:
          (map['render_mode'] as String?) == 'native' ? 'native' : 'webview',
    );
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

  /// Rewrites developer hosts to the Android emulator alias (10.0.2.2) so
  /// local WordPress sites load from the device; real domains stay intact.
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
    final AppConfig config = AppConfig.fromMap(
      decoded is Map<String, dynamic> ? decoded : <String, dynamic>{},
    );
    // فقط نیتیو تنظیمات زنده می‌خواهد؛ وب‌ویو مستقیم می‌رود سراغ سایت.
    return config.isNative
        ? config.refreshRemoteSettings().timeout(
            const Duration(seconds: 3),
            onTimeout: () => config,
          )
        : config;
  }

  /// ادغام تنظیمات زنده از endpoint تنظیمات وردپرس، تا اسکلتون از همان
  /// فریم اول سایز درست را بلد باشد و بنرها هم تازه باشند. هر خطایی =
  /// همان مقدار config.json.
  Future<AppConfig> refreshRemoteSettings() async {
    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 2);
      final HttpClientRequest request = await client
          .getUrl(Uri.parse('${effectiveApiBaseUrl}config'));
      final HttpClientResponse response = await request.close();
      if (response.statusCode != 200) return this;
      final String body = await response.transform(utf8.decoder).join();
      final dynamic decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return this;
      return AppConfig(
        appName: appName,
        siteUrl: siteUrl,
        primaryColor: primaryColor,
        apiBaseUrl: apiBaseUrl,
        renderMode: renderMode,
        categoryCanvas:
            (decoded['category_canvas_size'] as num?)?.toInt() ??
                categoryCanvas,
        banners: AppConfig.parseBanners(decoded['native_banners']),
        offerCountdownEnd:
            ((decoded['offer_countdown_end'] as String?) ?? '').trim(),
        logoUrl: AppConfig.mapEmulatorUrl(
          ((decoded['logo_url'] as String?) ?? '').trim(),
        ),
        headerLogoUrl: AppConfig.mapEmulatorUrl(
          (((decoded['header_logo'] as Map?)?['url'] as String?) ?? '').trim(),
        ),
        headerLogoName:
            (((decoded['header_logo'] as Map?)?['name'] as String?) ?? '')
                .trim(),
        searchSuggestions: ((decoded['search_suggestions'] as List?) ??
                const <dynamic>[])
            .map((dynamic term) => ((term as String?) ?? '').trim())
            .where((String term) => term.isNotEmpty)
            .take(4)
            .toList(growable: false),
        reviewsRequireLogin: decoded['reviews_require_login'] == true,
        reviewsGuestPost: decoded['reviews_guest_post'] != false,
        sliderInterval:
            ((decoded['slider_interval'] as num?)?.toInt() ?? sliderInterval)
                .clamp(3, 15),
      );
    } catch (_) {
      return this;
    } finally {
      client?.close(force: true);
    }
  }

  /// تبدیل خروجی native_banners به مدل | هم آبجکت {image, link} و هم
  /// رشته‌ی ساده (سازگاری) پذیرفته می‌شود؛ بنرهای بی‌تصویر حذف می‌شوند.
  static List<NativeBanner> parseBanners(dynamic raw) {
    return ((raw as List?) ?? const <dynamic>[])
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
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: config.primaryColor,
          surface: Colors.white,
        ).copyWith(primary: config.primaryColor),
        appBarTheme: AppBarTheme(
          backgroundColor: config.primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
      home: config.isNative
          ? NativeHomeScreen(config: config)
          : WebViewHomeScreen(config: config),
    );
  }
}

class WebViewHomeScreen extends StatefulWidget {
  const WebViewHomeScreen({super.key, required this.config});

  final AppConfig config;

  @override
  State<WebViewHomeScreen> createState() => _WebViewHomeScreenState();
}

class _WebViewHomeScreenState extends State<WebViewHomeScreen> {
  late final WebViewController _controller;
  late final bool _isLocalSite;
  double _progress = 0;
  bool _isLoading = true;
  bool _hasError = false;
  bool _hasLoadedOnce = false;

  /// Universal mobile hardening injected into every page: strict viewport,
  /// horizontal-overflow lock, hidden WP admin bar, and on-the-fly repair of
  /// legacy http://localhost/ asset or link URLs for emulator testing.
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
    _isLocalSite = siteHost == 'localhost' ||
        siteHost == '127.0.0.1' ||
        siteHost == '10.0.2.2';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            // Hand protocols the OS owns over to the system gracefully
            // instead of letting the WebView throw on them.
            const List<String> externalSchemes = <String>[
              'tel', 'mailto', 'sms', 'whatsapp', 'intent', 'geo', 'market',
            ];
            final Uri? uri = Uri.tryParse(request.url);
            final String scheme = (uri?.scheme ?? '').toLowerCase();
            if (externalSchemes.contains(scheme)) {
              return NavigationDecision.prevent;
            }

            // Smart Host Bridge: while testing a local WordPress site the
            // page keeps advertising http://localhost/ for its internal
            // links and redirects. Inside the emulator that host means the
            // phone itself, so rewrite it on the fly to the host-machine
            // alias (10.0.2.2). Real public domains are never touched, so
            // production sites route exactly as published.
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
              setState(() {
                _isLoading = !_hasLoadedOnce;
                _hasError = false;
              });
            }
            _injectMobileFixes();
          },
          onPageFinished: (String url) {
            _injectMobileFixes();
            if (mounted) {
              setState(() {
                _hasLoadedOnce = true;
                _isLoading = false;
              });
            }
          },
          onProgress: (int progress) {
            if (mounted) {
              setState(() => _progress = progress / 100.0);
            }
          },
          onWebResourceError: (WebResourceError error) {
            // Fault tolerance: a broken image, font, stylesheet or tracking
            // pixel must NEVER collapse the app. The offline screen appears
            // only when the very first main-frame load fails outright.
            if (mounted &&
                error.isForMainFrame == true &&
                !_hasLoadedOnce) {
              setState(() {
                _hasError = true;
                _isLoading = false;
              });
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
    } catch (_) {
      // DOM not ready yet | the onPageFinished pass re-runs the script.
    }
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _isLoading = !_hasLoadedOnce;
    });
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
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
                  if (_isLoading && !_hasError)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.white,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SpinKitCircle(
                                color: widget.config.primaryColor,
                                size: 64.0,
                              ),
                              const SizedBox(height: 18),
                              Text(
                                widget.config.appName,
                                style: TextStyle(
                                  color: widget.config.primaryColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
