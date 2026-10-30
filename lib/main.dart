import 'dart:convert';

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
    if (trimmed.isEmpty) {
      return 'https://example.com';
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
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
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onHttpError: (HttpResponseError error) {
            final int? statusCode = error.response?.statusCode;
            if (mounted && statusCode != null && statusCode >= 400) {
              setState(() {
                _hasError = true;
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() {
                _hasError = true;
                _isLoading = false;
              });
            }
          },
        ),
      );

    // Any website must render completely: allow http sites (cleartext is
    // enabled in the manifest) and never block mixed-content assets so
    // images on https pages served over http still load.
    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setMixedContentMode(MixedContentMode.alwaysAllow);
    }

    _controller.loadRequest(Uri.parse(widget.config.siteUrl));
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
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
