import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Application identity injected by the WP to Flutter cloud build engine.
class AppConfig {
  const AppConfig({
    required this.appName,
    required this.siteUrl,
    required this.primaryColor,
  });

  final String appName;
  final String siteUrl;
  final Color primaryColor;

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      appName: _readName(map['app_name']),
      siteUrl: normalizeSiteUrl((map['site_url'] as String?) ?? ''),
      primaryColor: parseHexColor(
        (map['primary_color'] as String?) ?? '',
        fallback: const Color(0xFF2271B1),
      ),
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
    // On the Android emulator the host machine is reachable through the
    // 10.0.2.2 alias, so developer sites configured as http://localhost/
    // or http://127.0.0.1/ are rewritten automatically while real domains
    // stay untouched.
    if (Platform.isAndroid &&
        (url.contains('://localhost') || url.contains('://127.0.0.1'))) {
      url = url
          .replaceFirst('://localhost', '://10.0.2.2')
          .replaceFirst('://127.0.0.1', '://10.0.2.2');
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
    return AppConfig.fromMap(
      decoded is Map<String, dynamic> ? decoded : <String, dynamic>{},
    );
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
        colorScheme: ColorScheme.fromSeed(seedColor: config.primaryColor),
        primaryColor: config.primaryColor,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: WebViewHomeScreen(config: config),
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
        'html, body { overflow-x: hidden !important; max-width: 100vw !important; width: 100% !important; -webkit-overflow-scrolling: touch !important; scroll-behavior: smooth !important; } ' +
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
      // DOM not ready yet — the onPageFinished pass re-runs the script.
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
