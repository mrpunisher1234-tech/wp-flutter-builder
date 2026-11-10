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

  test('search suggestions are read straight from the bundled config', () {
    final AppConfig config = AppConfig.fromMap(<String, dynamic>{
      'app_name': 'Demo App',
      'site_url': 'https://example.com',
      'search_suggestions': <String>[
        'ساعت هوشمند',
        'گجت',
        'اسپیکر بلوتوثی',
        'اسپیکر شارژی',
      ],
    });

    expect(config.searchSuggestions, hasLength(4));
    expect(config.searchSuggestions.first, 'ساعت هوشمند');
    expect(config.searchSuggestions.last, 'اسپیکر شارژی');
  });

  test('suggestions survive a splash-only overlay map (withSplash)', () {
    final AppConfig config = AppConfig.fromMap(<String, dynamic>{
      'app_name': 'Demo App',
      'site_url': 'https://example.com',
      'search_suggestions': <String>['الف', 'ب'],
    });

    // This is the exact call AppConfig.load() makes for the prefs overlay:
    // it must not wipe the suggestions that came from the bundle.
    final AppConfig overlay = config.withSplash(<String, dynamic>{});
    expect(overlay.searchSuggestions, <String>['الف', 'ب']);
  });

  test('suggestions are trimmed, de-duplicated by emptiness and capped at four', () {
    final List<String> parsed = AppConfig.parseSuggestions(<dynamic>[
      '  یک  ',
      '',
      'دو',
      'سه',
      'چهار',
      'پنج',
    ]);

    expect(parsed, <String>['یک', 'دو', 'سه', 'چهار']);
    expect(AppConfig.parseSuggestions(null), isEmpty);
    expect(AppConfig.parseSuggestions('not-a-list'), isEmpty);
  });
}
