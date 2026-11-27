import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';
import 'native_mode.dart';
import 'product_variations.dart';

/// کارت ۱۸ | علاقه‌مندی‌ها | کاملاً محلی روی دستگاه کاربر (SharedPreferences)
/// بدون هیچ اندپوینت یا جدول تازهٔ وردپرس | مدیریتش هم‌سبک CartManager است
/// (سینگلتون ChangeNotifier | صف تغییرها قبل از پایان بازیابی | همان الگوی ریس).
///
/// اسنپ‌شات «کامل» است نه سبک | چون NativeDetailScreen گالری، ویژگی‌ها،
/// توضیحات HTML و انبار را از همان WpItem پاس‌داده‌شده می‌خواند و هیچ fetch
/// جداگانه‌ای بر اساس id نمیزند | پس حذف هر یک از این فیلدها یعنی صفحهٔ جزئیاتِ
/// محصولِ ذخیره‌شده ناقص باز میشود.
class FavoritesManager extends ChangeNotifier {
  FavoritesManager._() {
    _restoreFuture = _loadFromPrefs();
  }

  static final FavoritesManager instance = FavoritesManager._();

  static const String _storageKey = 'wptf_favorites_v1';

  bool _uiEnabled = false;
  bool get uiEnabled => _uiEnabled;

  /// تنظیم ۱۸ | گیت نمایش قلبها | فقط با تغییر واقعی notify میکند تا قلبها
  /// با آمدن /config زنده، بدون ریبیلد اپ ظاهر یا غایب شوند.
  void setUiEnabled(bool enabled) {
    if (_uiEnabled == enabled) return;
    _uiEnabled = enabled;
    notifyListeners();
  }

  late final Future<void> _restoreFuture;
  Future<void> get ready => _restoreFuture;

  // الگوی ریس CartManager | تغییرِ قبل از پایان بازیابی هم اجرا میشود (تا UI
  // فوری جواب بدهد) و هم در صف میماند تا روی دادهٔ بازیابی‌شده دوباره اعمال شود.
  bool _restored = false;
  final List<VoidCallback> _pendingMutations = <VoidCallback>[];

  /// اسنپ‌شاتها بهترتیب ذخیره | در UI معکوس میشوند تا تازه‌ترین اول دیده شود.
  final Map<int, Map<String, dynamic>> _snapshots =
      <int, Map<String, dynamic>>{};

  List<WpItem> get items => _snapshots.values
      .map(_itemFromSnapshot)
      .toList(growable: false)
      .reversed
      .toList(growable: false);

  bool isFavorite(int productId) => _snapshots.containsKey(productId);

  int get count => _snapshots.length;

  void toggle(WpItem item) => _mutate(() {
        if (_snapshots.containsKey(item.id)) {
          _snapshots.remove(item.id);
        } else {
          _snapshots[item.id] = wpItemSnapshot(item);
        }
      });

  void remove(int productId) => _mutate(() {
        _snapshots.remove(productId);
      });

  /// بهروزرسانی بیصدای اسنپ‌شات | وقتی دادهٔ تازهتر همان محصول لمس شد |
  /// هیچ فیلد پر هرگز با خالی بازنویسی نمیشود (ادغام | نه جایگزینی کور).
  void refreshSnapshot(WpItem item) => _mutate(() {
        if (!_snapshots.containsKey(item.id)) return;
        _snapshots[item.id] = _mergeSnapshot(
          _snapshots[item.id]!,
          _snapshotOf(item),
        );
      });

  /// ادغام | مقدار تازهٔ پر برنده است | مقدار تازهٔ خالی فقط وقتی نوشته میشود
  /// که کلید اصلاً وجود نداشته باشد | false و صفر «خالی» حساب نمیشوند چون
  /// ناموجودشدن و صفرشدن امتیاز خودشان دادهٔ واقعی و معنادارند.
  Map<String, dynamic> _mergeSnapshot(
    Map<String, dynamic> stored,
    Map<String, dynamic> fresh,
  ) {
    final Map<String, dynamic> merged = Map<String, dynamic>.of(stored);
    fresh.forEach((String key, dynamic value) {
      if (_isEmptyValue(value)) {
        if (!merged.containsKey(key)) {
          merged[key] = value;
        }
      } else {
        merged[key] = value;
      }
    });
    return merged;
  }

  bool _isEmptyValue(dynamic value) =>
      value == null ||
      value == '' ||
      (value is List && value.isEmpty);

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
      // دادهٔ خراب | بیصدا خالی میشود | قلب کاربر هرگز اپ را نمیشکند.
    } finally {
      _restored = true;
      // تغییرهای قبل از بازیابی | روی دادهٔ بازیابی‌شده دوباره اعمال میشوند.
      for (final VoidCallback mutation in _pendingMutations) {
        mutation();
      }
      _pendingMutations.clear();
      notifyListeners();
    }
  }

  /// اسنپ‌شات کامل | همهٔ فیلدهایی که NativeDetailScreen از خود WpItem
  /// میخواند (گالری | ویژگیها | توضیحات | انبار | مرتبطها) حفظ میشوند |
  /// related یکسطح بازتولید میشود و در پیلودهای واقعی ته دارد.
  Map<String, dynamic> _snapshotOf(WpItem item) => wpItemSnapshot(item);

  WpItem _itemFromSnapshot(Map<String, dynamic> map) =>
      wpItemFromSnapshot(map);
}

/// هلپر مشترک اسنپ‌شات | FavoritesManager و RecentlyViewedManager هر دو
/// همین تبدیل را استفاده میکنند تا سریالایزیشن دو بار نوشته نشود.
Map<String, dynamic> wpItemSnapshot(WpItem item) => <String, dynamic>{
      'id': item.id,
      'type': item.type,
      'title': item.title,
      'excerpt': item.excerpt,
      'content': item.content,
      'url': item.url,
      'featured_image': item.featuredImage,
      'product_type': item.productType,
      'variations': item.variations.map((WpVariation variation) => variation.toMap()).toList(growable: false),
      'price': item.price,
      'regular_price': item.regularPrice,
      'sale_price': item.salePrice,
      'sku': item.sku,
      'in_stock': item.inStock,
      'purchasable': item.purchasable,
      'on_sale': item.onSale,
      'stock_quantity': item.stockQuantity,
      'rating': item.rating,
      'reviews_count': item.reviewsCount,
      'gallery_images': item.galleryImages,
      'attributes': item.attributes
          .map(
            (WpAttribute attribute) => <String, dynamic>{
              'name': attribute.name,
              'slug': attribute.slug,
              'options': attribute.options
                  .map((WpAttributeOption option) => <String, dynamic>{'name': option.name, 'value': option.value})
                  .toList(growable: false),
              'variation': attribute.variation,
            },
          )
          .toList(growable: false),
      'related_products': item.relatedProducts
          .map(wpItemSnapshot)
          .toList(growable: false),
      'category_names': item.categoryNames,
      // تنظیم ۱۹ | اسلاگ دستهها | برای fallback همدسته در صفحهٔ جزئیات.
      'category_slugs': item.categorySlugs,
    };

/// بازخوانی اسنپ‌شات | آدرسهای تصویر از mapEmulatorUrl میگذرند.
WpItem wpItemFromSnapshot(Map<String, dynamic> map) => WpItem(
      id: (map['id'] as num?)?.toInt() ?? 0,
      type: '${map['type'] ?? 'product'}',
      title: '${map['title'] ?? ''}',
      excerpt: '${map['excerpt'] ?? ''}',
      content: '${map['content'] ?? ''}',
      url: '${map['url'] ?? ''}',
      featuredImage: '${map['featured_image'] ?? ''}',
      productType: '${map['product_type'] ?? 'simple'}',
      variations: (map['variations'] is List
              ? map['variations'] as List
              : const <dynamic>[])
          .whereType<Map>()
          .map((Map row) => WpVariation.fromMap(row.cast<String, dynamic>()))
          .toList(growable: false),
      price: '${map['price'] ?? ''}',
      regularPrice: '${map['regular_price'] ?? ''}',
      salePrice: '${map['sale_price'] ?? ''}',
      sku: '${map['sku'] ?? ''}',
      inStock: map['in_stock'] != false,
      purchasable: map['purchasable'] != false,
      onSale: map['on_sale'] == true,
      stockQuantity: (map['stock_quantity'] as num?)?.toInt(),
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      reviewsCount: (map['reviews_count'] as num?)?.toInt() ?? 0,
      galleryImages: (map['gallery_images'] is List
              ? map['gallery_images'] as List
              : const <dynamic>[])
          .map((dynamic row) => AppConfig.mapEmulatorUrl('$row'))
          .where((String url) => url.isNotEmpty)
          .toList(growable: false),
      attributes: (map['attributes'] is List
              ? map['attributes'] as List
              : const <dynamic>[])
          .whereType<Map>()
          .map(
            (Map row) => WpAttribute(
              name: '${row['name'] ?? ''}',
              slug: '${row['slug'] ?? ''}',
              options: (row['options'] is List
                      ? row['options'] as List
                      : const <dynamic>[])
                  .map(WpAttributeOption.fromMap)
                  .toList(growable: false),
              variation: row['variation'] == true,
            ),
          )
          .toList(growable: false),
      relatedProducts: (map['related_products'] is List
              ? map['related_products'] as List
              : const <dynamic>[])
          .whereType<Map>()
          .map(
            (Map row) => wpItemFromSnapshot(row.cast<String, dynamic>()),
          )
          .toList(growable: false),
      categoryNames: (map['category_names'] is List
              ? map['category_names'] as List
              : const <dynamic>[])
          .map((dynamic row) => '$row')
          .toList(growable: false),
      categorySlugs: (map['category_slugs'] is List
              ? map['category_slugs'] as List
              : const <dynamic>[])
          .map((dynamic row) => '$row')
          .where((String slug) => slug.isNotEmpty)
          .toList(growable: false),
    );

/// صفحهٔ علاقه‌مندی‌ها | گرید دوتایی با همان کارت گرید خانه | حالت خالی با
/// الگوی دایره+آیکون+متن | لمس هر کارت → صفحهٔ جزئیات.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Dk.canvas,
        appBar: AppBar(
          title: const Text(
            'علاقه‌مندی‌ها',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Dk.text1,
            ),
          ),
          elevation: 0.5,
          backgroundColor: Colors.white,
          foregroundColor: Dk.text1,
        ),
        body: ListenableBuilder(
          listenable: FavoritesManager.instance,
          builder: (BuildContext context, Widget? _) {
            final List<WpItem> items = FavoritesManager.instance.items;
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(
                        color: Dk.surface2,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border_rounded,
                        size: 38,
                        color: Dk.text4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'هنوز چیزی به علاقه‌مندی‌ها اضافه نکرده‌اید',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Dk.text1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'روی قلبِ هر محصول بزنید تا اینجا ذخیره شود',
                      style: TextStyle(fontSize: 12, color: Dk.text3),
                    ),
                  ],
                ),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.62,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: items.length,
              itemBuilder: (BuildContext context, int index) {
                final WpItem item = items[index];
                return ProductGridCard(
                  item: item,
                  primaryColor: config.primaryColor,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          NativeDetailScreen(config: config, item: item),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
