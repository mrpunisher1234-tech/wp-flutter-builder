import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wp_flutter_app/announcement.dart';
import 'package:wp_flutter_app/main.dart';
import 'package:wp_flutter_app/native_mode.dart';

const AppAnnouncement _productAnnouncement = AppAnnouncement(
  enabled: true,
  id: 'sale-v2',
  title: 'پیشنهاد ویژه',
  message: 'این محصول با قیمت تازه عرضه شد.',
  targetType: 'product',
  productId: 73,
  productPayload: <String, dynamic>{
    'id': 73,
    'type': 'product',
    'title': 'محصول تخفیف‌خورده',
    'product': <String, dynamic>{'price': '125000', 'on_sale': true},
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'AppConfig parses and preserves announcement fields with splash data',
    () {
      final AppConfig config = AppConfig.fromMap(<String, dynamic>{
        'app_name': 'فروشگاه',
        'site_url': 'https://shop.example/',
        'render_mode': 'native',
        'announcement': <String, dynamic>{
          'enabled': true,
          'id': 'sale-v2',
          'title': 'پیشنهاد ویژه',
          'message': 'تخفیف امروز',
          'image_url': 'https://shop.example/sale.jpg',
          'button_text': 'خرید',
          'target_type': 'product',
          'product_id': 73,
          'max_shows': 2,
          'product': _productAnnouncement.productPayload,
        },
      });

      expect(config.announcement.isDisplayable, isTrue);
      expect(config.announcement.title, 'پیشنهاد ویژه');
      expect(config.announcement.hasProductTarget, isTrue);
      expect(config.announcement.maxShows, 2);
      expect(config.announcement.productPayload?['id'], 73);

      final AppConfig withSplash = config.withSplash(<String, dynamic>{
        'app': <String, dynamic>{
          'splash': <String, dynamic>{'text': 'در حال آماده‌سازی'},
        },
      });
      expect(withSplash.announcement.id, 'sale-v2');
      expect(withSplash.announcement.message, 'تخفیف امروز');
    },
  );

  test('remote config merge updates and preserves announcement config', () {
    final AppConfig initial = AppConfig(
      appName: 'Test',
      siteUrl: 'https://shop.example/',
      apiBaseUrl: 'https://shop.example/wp-json/wp-to-flutter/v1/',
      primaryColor: Colors.blue,
      renderMode: 'native',
      announcement: const AppAnnouncement(
        enabled: true,
        id: 'old-v1',
        title: 'نسخه قبلی',
        message: 'متن قبلی',
      ),
    );

    final AppConfig refreshed = initial.withRemoteSettings(<String, dynamic>{
      'announcement': <String, dynamic>{
        'enabled': true,
        'id': 'remote-v3',
        'title': 'خبر تازه',
        'message': 'از سرور دریافت شد',
        'max_shows': 0,
      },
    });
    expect(refreshed.announcement.id, 'remote-v3');
    expect(refreshed.announcement.maxShows, 0);
    expect(refreshed.announcement.message, 'از سرور دریافت شد');

    final AppConfig omitted = initial.withRemoteSettings(<String, dynamic>{});
    expect(omitted.announcement.id, 'old-v1');
  });

  test(
    'seen announcement ID persists and republished IDs show again',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final AnnouncementSeenStore store = AnnouncementSeenStore();

      expect(
        await store.shouldShow(_productAnnouncement, preferences: preferences),
        isTrue,
      );
      await store.markShown(_productAnnouncement, preferences: preferences);
      expect(
        preferences.getString(AnnouncementSeenStore.seenIdPreferenceKey),
        'sale-v2',
      );
      expect(
        preferences.getInt(AnnouncementSeenStore.seenCountPreferenceKey),
        1,
      );
      expect(
        await store.shouldShow(_productAnnouncement, preferences: preferences),
        isFalse,
      );

      const AppAnnouncement republished = AppAnnouncement(
        enabled: true,
        id: 'sale-v3',
        title: 'پیشنهاد ویژه',
        message: 'محصول دوباره تخفیف خورد',
      );
      expect(
        await store.shouldShow(republished, preferences: preferences),
        isTrue,
      );
    },
  );

  test('display policy respects per-ID counts and unlimited mode', () {
    expect(
      AnnouncementDisplayPolicy.shouldShow(
        announcement: _productAnnouncement,
        seenId: 'sale-v2',
        seenCount: 1,
      ),
      isFalse,
    );
    expect(
      AnnouncementDisplayPolicy.shouldShow(
        announcement: _productAnnouncement,
        seenId: 'sale-v2',
        seenCount: 0,
      ),
      isTrue,
    );
    expect(
      AnnouncementDisplayPolicy.shouldShow(
        announcement: _productAnnouncement,
        seenId: 'another-id',
        seenCount: 99,
      ),
      isTrue,
    );
    const AppAnnouncement everyOpen = AppAnnouncement(
      enabled: true,
      id: 'open-v1',
      title: 'اطلاعیه',
      message: 'متن اطلاعیه',
      maxShows: 0,
    );
    expect(
      AnnouncementDisplayPolicy.shouldShow(
        announcement: everyOpen,
        seenId: 'open-v1',
        seenCount: 99,
      ),
      isTrue,
    );
  });

  testWidgets('announcement popup renders RTL content and returns CTA action', (
    WidgetTester tester,
  ) async {
    bool? actionResult;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                actionResult = await showDialog<bool>(
                  context: context,
                  builder: (_) => const AnnouncementDialog(
                    announcement: AppAnnouncement(
                      enabled: true,
                      id: 'url-v1',
                      title: 'فروش ویژه',
                      message: 'برای دیدن جزئیات بیشتر ادامه دهید.',
                      targetType: 'url',
                      linkUrl: 'https://shop.example/sale',
                    ),
                    primaryColor: Colors.deepOrange,
                  ),
                );
              },
              child: const Text('باز کردن اعلان'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('باز کردن اعلان'));
    await tester.pumpAndSettle();
    expect(find.text('فروش ویژه'), findsOneWidget);
    expect(find.text('برای دیدن جزئیات بیشتر ادامه دهید.'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.text('مشاهده'), findsOneWidget);
    expect(find.byType(Directionality), findsWidgets);

    await tester.tap(find.text('مشاهده'));
    await tester.pumpAndSettle();
    expect(actionResult, isTrue);
    expect(find.text('فروش ویژه'), findsNothing);
  });

  testWidgets('informational popup has no CTA button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnnouncementDialog(
            announcement: AppAnnouncement(
              enabled: true,
              id: 'info-v1',
              title: 'اطلاعیه',
              message: 'این پیام فقط جهت اطلاع‌رسانی است.',
            ),
            primaryColor: Colors.blue,
          ),
        ),
      ),
    );

    expect(find.text('اطلاعیه'), findsOneWidget);
    expect(find.text('بستن'), findsOneWidget);
    expect(find.text('مشاهده'), findsNothing);
  });
}
