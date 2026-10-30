import 'package:flutter_test/flutter_test.dart';
import 'package:wp_flutter_app/main.dart';

void main() {
  test('AppConfig parses the injected build payload', () {
    final AppConfig config = AppConfig.fromMap(<String, dynamic>{
      'app_name': 'Demo App',
      'site_url': 'https://example.com',
      'primary_color': '#2271b1',
    });

    expect(config.appName, 'Demo App');
    expect(config.siteUrl, 'https://example.com');
    expect(config.primaryColor.value, 0xFF2271B1);
  });

  test('AppConfig falls back to safe defaults on empty payload', () {
    final AppConfig config = AppConfig.fromMap(<String, dynamic>{});

    expect(config.appName, 'Demo App');
    expect(config.siteUrl, 'https://example.com');
    expect(config.primaryColor.value, 0xFF2271B1);
  });

  test('normalizeSiteUrl adds the https scheme when missing', () {
    expect(AppConfig.normalizeSiteUrl('example.com'), 'https://example.com');
    expect(AppConfig.normalizeSiteUrl('http://example.com'), 'http://example.com');
    expect(AppConfig.normalizeSiteUrl(''), 'https://example.com');
  });
}
