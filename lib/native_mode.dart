import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'cart_screen.dart';
import 'categories_screen.dart';
import 'api_page.dart';
import 'announcement.dart';
import 'favorites_screen.dart';
import 'main.dart';
import 'product_reviews.dart';
import 'profile_screen.dart';
import 'recently_viewed.dart';
import 'search_history.dart';
import 'skeleton.dart';

// --- توکن‌های طراحی (استخراج‌شده از دیجی‌کالا موبایل) ---
class Dk {
  static const Color canvas = Color(0xFFF2F3F5);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFECEDEF);
  static const Color text1 = Color(0xFF1F1F1F);
  static const Color text2 = Color(0xFF5C5C5C);
  static const Color text3 = Color(0xFF848484);
  static const Color text4 = Color(0xFFA2A2A2);
  static const Color discount = Color(0xFFEB3850);
  static const Color success = Color(0xFF2E7B32);
  static const Color star = Color(0xFFF9BC00);
  static const Color surface2 = Color(0xFFF7F8FA);
  static const List<Color> offerGradient = <Color>[
    Color(0xFFD22C4E),
    Color(0xFFEE384E),
  ];
}

// ---------------------------------------------------------------------------
// پالت کارت اعلان | کاغذ گرم + مرکب + لهجهٔ رنگ برند.
// ---------------------------------------------------------------------------
const Color _paper = Color(0xFFFAF7F2);
const Color _ink = Color(0xFF1C1917);
const Color _muted = Color(0xFF857D71);
const Color _lac = Color(0xFFE0452F);
const Color _hairline = Color(0xFFE8E1D6);

/// پنجرهٔ اعلان | کارت «ویترین» با عکس تمام‌عرض، قیمت قهرمان و مهر تخفیف.
/// بستن با ضربدرِ روی عکس انجام میشود | دکمهٔ اصلی فقط مقصد را باز میکند.
class AnnouncementDialog extends StatelessWidget {
  const AnnouncementDialog({
    super.key,
    required this.announcement,
    required this.primaryColor,
  });

  final AppAnnouncement announcement;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            child: SaleAnnouncementCard(
              title: announcement.title.trim(),
              message: announcement.message.trim(),
              salePrice: announcement.salePrice.trim(),
              regularPrice: announcement.regularPrice.trim(),
              imageUrl: AppConfig.mapEmulatorUrl(announcement.imageUrl),
              // بدون مقصد | همان دکمه نقش بستن را بازی میکند.
              ctaLabel: announcement.hasAction
                  ? announcement.buttonText
                  : 'بستن',
              onView: () => Navigator.of(context).pop(announcement.hasAction),
              onClose: () => Navigator.of(context).pop(false),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// کارت «ویترین» اعلان فروش
// ---------------------------------------------------------------------------
class SaleAnnouncementCard extends StatelessWidget {
  const SaleAnnouncementCard({
    super.key,
    required this.title,
    required this.message,
    required this.salePrice,
    this.regularPrice = '',
    this.imageUrl,
    this.currency = 'تومان',
    this.overline = 'پیشنهاد ویژه',
    this.ctaLabel = 'مشاهده پیشنهاد',
    this.onView,
    this.onClose,
  });

  final String title;
  final String message;
  final String salePrice;
  final String regularPrice;
  final String? imageUrl;
  final String currency;
  final String overline;
  final String ctaLabel;
  final VoidCallback? onView;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final String sale = _formatAmount(salePrice);
    final String regular = _formatAmount(regularPrice);
    final int? saleN = _parseAmount(salePrice);
    final int? regularN = _parseAmount(regularPrice);

    final int? percent =
        (saleN != null && regularN != null && regularN > 0 && saleN < regularN)
        ? (((regularN - saleN) / regularN) * 100).round()
        : null;
    final bool hasSeal = percent != null && percent > 0 && percent < 100;
    final String? savings =
        (saleN != null && regularN != null && regularN > saleN)
        ? _formatAmount((regularN - saleN).toString())
        : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(26),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ---- عکس: تمامعرض، نسبت 4:3 -----------------------------------
          Stack(
            children: <Widget>[
              _Photo(url: imageUrl, semanticLabel: title),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: <double>[0, 0.3],
                      colors: <Color>[Color(0x59000000), Colors.transparent],
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                top: 12,
                end: 12,
                child: _CloseButton(onTap: onClose),
              ),
            ],
          ),

          // ---- بدنه: ۲۲px روی عکس میآید → درز منحنی ---------------------
          Container(
            transform: Matrix4.translationValues(0, -22, 0),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 2),
            decoration: const BoxDecoration(
              color: _paper,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // برچسب بدون خط کنار + hr زیرش
                Text(
                  overline,
                  style: const TextStyle(
                    color: _lac,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, thickness: 1, color: _hairline),
                const SizedBox(height: 12),

                // عنوان + hr زیرش
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 18,
                    height: 1.55,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, thickness: 1, color: _hairline),
                const SizedBox(height: 10),

                // توضیحات + hr زیرش
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, thickness: 1, color: _hairline),
                const SizedBox(height: 16),

                // ---- قیمت: قهرمان کارت + مهر تخفیف -----------------------
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: _PriceLine(amount: sale, currency: currency),
                          ),
                          if (regular.isNotEmpty ||
                              savings != null) ...<Widget>[
                            const SizedBox(height: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  if (regular.isNotEmpty) _Struck(regular),
                                  if (regular.isNotEmpty && savings != null)
                                    const SizedBox(width: 10),
                                  if (savings != null)
                                    Text(
                                      '$savings $currency سود شما',
                                      style: const TextStyle(
                                        color: _lac,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (hasSeal) ...<Widget>[
                      const SizedBox(width: 14),
                      _DiscountSeal(percent: percent, color: _lac),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                // ---- یک اکشن، تمامعرض، بدون فلش --------------------------
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink,
                      foregroundColor: _paper,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: onView ?? () {},
                    child: Text(ctaLabel),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// اجزا
// ---------------------------------------------------------------------------
class _Photo extends StatelessWidget {
  const _Photo({this.url, this.semanticLabel});

  final String? url;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: (url == null || url!.isEmpty)
          ? const _PhotoFallback()
          : Image.network(
              url!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              semanticLabel: semanticLabel,
              loadingBuilder:
                  (BuildContext c, Widget child, ImageChunkEvent? progress) =>
                      progress == null
                      ? child
                      : const _PhotoFallback(loading: true),
              errorBuilder: (_, __, ___) => const _PhotoFallback(),
            ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEFE8DC),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFC2B6A2),
                ),
              )
            : const Icon(
                Icons.image_outlined,
                size: 40,
                color: Color(0xFFC2B6A2),
              ),
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.amount, required this.currency});

  final String amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          amount.isEmpty ? '-' : amount,
          style: const TextStyle(
            color: _ink,
            fontSize: 34,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          currency,
          style: const TextStyle(
            color: _muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Struck extends StatelessWidget {
  const _Struck(this.amount);

  final String amount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Text(
          amount,
          style: const TextStyle(
            color: _muted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: const Alignment(0, 0.08),
            child: Container(height: 1.2, color: _muted),
          ),
        ),
      ],
    );
  }
}

class _DiscountSeal extends StatelessWidget {
  const _DiscountSeal({required this.percent, required this.color});

  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            '${_faDigits(percent.toString())}٪',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'تخفیف',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap ?? () {},
      style: IconButton.styleFrom(
        backgroundColor: _lac,
        foregroundColor: Colors.white,
        fixedSize: const Size(34, 34),
        minimumSize: const Size(34, 34),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
      ),
      icon: const Icon(Icons.close_rounded, size: 19),
    );
  }
}

// ---------------------------------------------------------------------------
// هلپرهای عدد فارسی
// ---------------------------------------------------------------------------
int? _parseAmount(String raw) {
  final String digits = _asciiDigits(raw).replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : int.tryParse(digits);
}

String _formatAmount(String raw) {
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final int? n = _parseAmount(trimmed);
  if (n == null) return _faDigits(trimmed);
  final String s = n.toString();
  final StringBuffer b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    b.write(s[i]);
    final int rem = s.length - i - 1;
    if (rem > 0 && rem % 3 == 0) b.write('٬');
  }
  return _faDigits(b.toString());
}

String _asciiDigits(String input) {
  return input
      .replaceAllMapped(
        RegExp(r'[۰-۹]'),
        (Match m) =>
            String.fromCharCode(m.group(0)!.codeUnitAt(0) - 0x06F0 + 0x30),
      )
      .replaceAllMapped(
        RegExp(r'[٠-٩]'),
        (Match m) =>
            String.fromCharCode(m.group(0)!.codeUnitAt(0) - 0x0660 + 0x30),
      );
}

String _faDigits(String input) {
  const List<String> fa = <String>[
    '۰',
    '۱',
    '۲',
    '۳',
    '۴',
    '۵',
    '۶',
    '۷',
    '۸',
    '۹',
  ];
  return input.replaceAllMapped(
    RegExp(r'[0-9]'),
    (Match m) => fa[m.group(0)!.codeUnitAt(0) - 0x30],
  );
}

/// ویژگی محصول (رنگ، سایز، گارانتی…)
class WpAttribute {
  const WpAttribute({
    required this.name,
    required this.slug,
    required this.options,
    required this.variation,
  });

  final String name;
  final String slug;
  final List<String> options;
  final bool variation;
}

/// مدل داده محصول و نوشته (تمام فیلدهای API نسخه ۱.۱)
class WpItem {
  const WpItem({
    required this.id,
    required this.type,
    required this.title,
    required this.excerpt,
    required this.content,
    required this.url,
    required this.featuredImage,
    this.price = '',
    this.regularPrice = '',
    this.salePrice = '',
    this.sku = '',
    this.inStock = true,
    this.purchasable = true,
    this.onSale = false,
    this.stockQuantity,
    this.rating = 0,
    this.reviewsCount = 0,
    this.galleryImages = const <String>[],
    this.attributes = const <WpAttribute>[],
    this.relatedProducts = const <WpItem>[],
    this.categoryNames = const <String>[],
    this.categorySlugs = const <String>[],
  });

  final int id;
  final String type;
  final String title;
  final String excerpt;
  final String content;
  final String url;
  final String featuredImage;
  final String price;
  final String regularPrice;
  final String salePrice;
  final String sku;
  final bool inStock;
  final bool purchasable;
  final bool onSale;
  final int? stockQuantity;
  final double rating;
  final int reviewsCount;
  final List<String> galleryImages;
  final List<WpAttribute> attributes;
  final List<WpItem> relatedProducts;
  final List<String> categoryNames;

  /// تنظیم ۱۹ | اسلاگ دسته‌ها | برای fetch همدسته‌ها وقتی پیلود خالی است.
  final List<String> categorySlugs;

  bool get isProduct => type == 'product';

  factory WpItem.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> product = map['product'] is Map<String, dynamic>
        ? map['product'] as Map<String, dynamic>
        : <String, dynamic>{};
    final List<dynamic> categories = map['categories'] is List
        ? map['categories'] as List<dynamic>
        : const <dynamic>[];
    final Object? rawGalleryImages = product['gallery_images'];
    final Object? rawAttributes = product['attributes'];
    final Object? rawRelatedProducts = product['related_products'];

    return WpItem(
      id: (map['id'] as num?)?.toInt() ?? 0,
      type: (map['type'] as String?) ?? 'post',
      title: ((map['title'] as String?) ?? '').trim(),
      excerpt: ((map['excerpt'] as String?) ?? '').trim(),
      content: ((map['content'] as String?) ?? '').trim(),
      url: AppConfig.mapEmulatorUrl(((map['url'] as String?) ?? '').trim()),
      featuredImage: AppConfig.mapEmulatorUrl(
        ((map['featured_image'] as String?) ?? '').trim(),
      ),
      price: (product['price'] as String?) ?? '',
      regularPrice: (product['regular_price'] as String?) ?? '',
      salePrice: (product['sale_price'] as String?) ?? '',
      sku: (product['sku'] as String?) ?? '',
      inStock: product['in_stock'] == null ? true : product['in_stock'] == true,
      purchasable: product['purchasable'] == null
          ? true
          : product['purchasable'] == true,
      onSale: product['on_sale'] == true,
      stockQuantity: (product['stock_quantity'] as num?)?.toInt(),
      rating: (product['rating'] as num?)?.toDouble() ?? 0,
      reviewsCount: (product['reviews_count'] as num?)?.toInt() ?? 0,
      galleryImages:
          (rawGalleryImages is List ? rawGalleryImages : const <dynamic>[])
              .map(
                (dynamic url) =>
                    AppConfig.mapEmulatorUrl((url as String? ?? '').trim()),
              )
              .where((String url) => url.isNotEmpty)
              .toList(growable: false),
      attributes:
          (rawAttributes is List ? rawAttributes : const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(
                (Map<String, dynamic> attribute) {
                  final Object? rawOptions = attribute['options'];
                  return WpAttribute(
                    name: (attribute['name'] as String?) ?? '',
                    slug: (attribute['slug'] as String?) ?? '',
                    options:
                        (rawOptions is List ? rawOptions : const <dynamic>[])
                            .whereType<String>()
                            .toList(growable: false),
                    variation: attribute['variation'] == true,
                  );
                },
              )
              .toList(growable: false),
      relatedProducts:
          (rawRelatedProducts is List ? rawRelatedProducts : const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(WpItem.fromMap)
              .toList(growable: false),
      categoryNames: categories
          .whereType<Map>()
          .map(
            (dynamic category) =>
                ((category.cast<String, dynamic>())['name'] as String?) ?? '',
          )
          .where((String name) => name.isNotEmpty)
          .toList(growable: false),
      categorySlugs: categories
          .whereType<Map>()
          .map(
            (dynamic category) =>
                ((category.cast<String, dynamic>())['slug'] as String?) ?? '',
          )
          .where((String slug) => slug.isNotEmpty)
          .toList(growable: false),
    );
  }
}

// --- تبدیل قیمت خام به فرمت تومانی و اعداد فارسی ---
/// بخش صحیح قیمت | «150000.00» را «150000» میکند تا اعشار ۱۰۰ برابر نشود.
String priceIntegerPart(String raw) {
  final String trimmed = raw.trim();
  final int dot = trimmed.indexOf('.');
  return (dot == -1 ? trimmed : trimmed.substring(0, dot)).replaceAll(
    RegExp(r'[^0-9]'),
    '',
  );
}

String formatToman(String raw) {
  if (raw.isEmpty) return '';
  final String clean = priceIntegerPart(raw);
  if (clean.isEmpty) return raw;

  final String withCommas = clean.replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match match) => '${match[1]},',
  );

  const List<String> en = <String>[
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
  ];
  const List<String> fa = <String>[
    '۰',
    '۱',
    '۲',
    '۳',
    '۴',
    '۵',
    '۶',
    '۷',
    '۸',
    '۹',
  ];
  String result = withCommas;
  for (int i = 0; i < 10; i++) {
    result = result.replaceAll(en[i], fa[i]);
  }
  return '$result تومان';
}

// --- تبدیل ارقام به فارسی (برای تایمر و شمارنده‌ها) ---
String toPersianDigits(String input) {
  const List<String> en = <String>[
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
  ];
  const List<String> fa = <String>[
    '۰',
    '۱',
    '۲',
    '۳',
    '۴',
    '۵',
    '۶',
    '۷',
    '۸',
    '۹',
  ];
  String result = input;
  for (int i = 0; i < 10; i++) {
    result = result.replaceAll(en[i], fa[i]);
  }
  return result;
}

// --- محاسبه درصد تخفیف ---
String? calcDiscountPercent(String regularPrice, String salePrice) {
  final int? regular = int.tryParse(priceIntegerPart(regularPrice));
  final int? sale = int.tryParse(priceIntegerPart(salePrice));
  if (regular != null && sale != null && regular > sale && regular > 0) {
    final int percent = (((regular - sale) / regular) * 100).round();
    if (percent > 0) return '٪$percent';
  }
  return null;
}

// --- صفحه اصلی فروشگاه (سبک دیجی‌کالا موبایل) ---
class NativeHomeScreen extends StatefulWidget {
  const NativeHomeScreen({super.key, required this.config});

  final AppConfig config;

  @override
  State<NativeHomeScreen> createState() => _NativeHomeScreenState();
}

class _NativeHomeScreenState extends State<NativeHomeScreen> {
  int _currentBottomNavIndex = 0;
  List<WpItem> _items = <WpItem>[];
  List<Map<String, dynamic>> _categories = <Map<String, dynamic>>[];
  // مقدار اولیه از AppConfig می‌آید (fetch /config در استارتاپ) تا
  // اسکلتون از همان فریم اول با سایز درست رندر شود | نه پیش‌فرض کور.
  int _categoryCanvas = 400;
  bool _isLoading = true;
  bool _loadingCategories = true;
  String? _error;
  String _selectedCategory = 'همه';
  List<NativeBanner> _banners = const <NativeBanner>[];
  int _sliderInterval = 5;
  String _offerCountdownEnd = '';
  String _headerLogoUrl = '';
  String _headerLogoName = '';
  List<String> _searchSuggestions = const <String>[];
  bool _loadingBanners = true;
  final GlobalKey _productGridKey = GlobalKey();
  final ScrollController _homeScroll = ScrollController();
  int _productsPage = 1;
  bool _hasMoreProducts = false;
  bool _loadingMoreProducts = false;

  static const int _homePageSize = 10;

  // حالت «دسته انتخاب‌شده»: محصولات همان دسته مستقیم از سرور با صفحه‌بندی
  List<WpItem> _categoryItems = <WpItem>[];
  String _activeCategorySlug = '';
  int _categoryPage = 1;
  bool _hasMoreCategoryItems = false;
  bool _loadingCategoryItems = false;
  bool _loadingMoreCategoryItems = false;

  @override
  void initState() {
    super.initState();
    _categoryCanvas = widget.config.categoryCanvas;
    _banners = widget.config.banners;
    _offerCountdownEnd = widget.config.offerCountdownEnd;
    _headerLogoUrl = widget.config.headerLogoUrl;
    _headerLogoName = widget.config.headerLogoName;
    _searchSuggestions = widget.config.searchSuggestions;
    // اسکرول بی‌نهایت: نزدیک انتهای لیست (یا صفحه‌ی پرنشده) صفحه بعدی می‌آید.
    _homeScroll.addListener(_autoFillViewport);
    _fetchProducts();
    _fetchCategories();
    _fetchBanners();
  }

  @override
  void dispose() {
    _homeScroll.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts({bool loadMore = false}) async {
    if (loadMore) {
      if (_loadingMoreProducts || !_hasMoreProducts || _isLoading) return;
      if (mounted) setState(() => _loadingMoreProducts = true);
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final int page = loadMore ? _productsPage + 1 : 1;
      final Uri uri = Uri.parse('${widget.config.effectiveApiBaseUrl}posts')
          .replace(
            queryParameters: <String, String>{
              'per_page': '$_homePageSize',
              'type': 'all',
              'page': '$page',
            },
          );

      final ApiPage response = await fetchApiPage(uri);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final String body = response.body;
        final List<dynamic> list = jsonDecode(body) as List<dynamic>;
        final List<WpItem> fetched = list
            .whereType<Map<String, dynamic>>()
            .map(WpItem.fromMap)
            .toList();
        if (!mounted) return;
        setState(() {
          _items = loadMore ? <WpItem>[..._items, ...fetched] : fetched;
          _productsPage = page;
          _hasMoreProducts = response.hasNextPage(page);
          _isLoading = false;
          _loadingMoreProducts = false;
        });
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _autoFillViewport(),
        );
      } else if (loadMore) {
        // خطای صفحه‌بندی: بی‌سروصدا متوقف می‌شود | محتوای موجود می‌ماند
        setState(() {
          _loadingMoreProducts = false;
          _hasMoreProducts = false;
        });
      } else {
        setState(() {
          _error = 'خطا در ارتباط با سرور (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      if (loadMore) {
        setState(() {
          _loadingMoreProducts = false;
          _hasMoreProducts = false;
        });
      } else {
        setState(() {
          _error = 'خطا در اتصال به سایت';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final Uri uri = Uri.parse(
        '${widget.config.effectiveApiBaseUrl}categories?per_page=30'
        '&taxonomy=product_cat&orderby=count&order=DESC',
      );
      final ApiPage response = await fetchApiPage(uri);
      if (response.statusCode == 200) {
        final String body = response.body;
        final List<dynamic> list = jsonDecode(body) as List<dynamic>;
        if (!mounted) return;
        setState(() {
          _categories = list.whereType<Map<String, dynamic>>().toList();
          _categoryCanvas = _categories.isNotEmpty
              ? ((_categories.first['canvas'] as num?)?.toInt() ??
                    widget.config.categoryCanvas)
              : widget.config.categoryCanvas;
          _loadingCategories = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _loadingCategories = false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingCategories = false);
      // دسته‌بندی‌ها اختیاری‌اند | خطا نادیده گرفته می‌شود.
    }
  }

  /// بنرهای اسلایدر | زنده در خود خانه fetch می‌شوند (نه در استارتاپ) تا
  /// مثل محصولات، هر بار باز شدن صفحه تازه باشند و از ریس تایم‌اوت
  /// استارتاپ خارج باشند. خطا = اسلایدر مخفی، بقیه اپ سالم.
  Future<void> _fetchBanners() async {
    try {
      final ApiPage response = await fetchApiPage(
        Uri.parse('${widget.config.effectiveApiBaseUrl}config'),
      );
      if (response.statusCode == 200) {
        final String body = response.body;
        final dynamic decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic> && mounted) {
          final Object? rawSearchSuggestions = decoded['search_suggestions'];
          setState(() {
            _banners = AppConfig.parseBanners(decoded['native_banners']);
            _offerCountdownEnd =
                ((decoded['offer_countdown_end'] as String?) ?? '').trim();
            _headerLogoUrl = AppConfig.mapEmulatorUrl(
              (((decoded['header_logo'] as Map?)?['url'] as String?) ?? '')
                  .trim(),
            );
            _headerLogoName =
                (((decoded['header_logo'] as Map?)?['name'] as String?) ?? '')
                    .trim();
            _searchSuggestions =
                (rawSearchSuggestions is List
                        ? rawSearchSuggestions
                        : const <dynamic>[])
                    .map((dynamic term) => ((term as String?) ?? '').trim())
                    .where((String term) => term.isNotEmpty)
                    .take(4)
                    .toList(growable: false);
            _sliderInterval =
                ((decoded['slider_interval'] as num?)?.toInt() ?? 5).clamp(
                  3,
                  15,
                );
          });
        }
      }
    } catch (_) {
      // بنرها اختیاری‌اند | بی‌خیال؛ بقیه صفحه مستقل کار می‌کند.
    } finally {
      if (mounted) {
        setState(() => _loadingBanners = false);
      }
    }
  }

  /// کلیک روی هر استوری: اگر دسته اسلاگ داشته باشد، محصولاتش مستقیم از
  /// سرور با صفحه‌بندی می‌آید (اسکلتون واقعی)؛ وگرنه فیلتر محلی. سپس
  /// اسکرول نرم به گرید.
  void _selectCategory(String? category) {
    final String name = category ?? 'همه';
    String slug = '';
    if (name != 'همه') {
      for (final Map<String, dynamic> categoryData in _categories) {
        if (((categoryData['name'] as String?) ?? '') == name) {
          slug = ((categoryData['slug'] as String?) ?? '');
          break;
        }
      }
    }
    setState(() {
      _selectedCategory = name;
      _activeCategorySlug = slug;
      _categoryItems = <WpItem>[];
      _categoryPage = 1;
      _hasMoreCategoryItems = false;
      _loadingMoreCategoryItems = false;
    });
    if (slug.isNotEmpty) {
      _fetchCategoryItems(loadMore: false);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? gridContext = _productGridKey.currentContext;
      if (gridContext != null) {
        Scrollable.ensureVisible(
          gridContext,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  /// محصولات دسته انتخاب‌شده | صفحه‌بندی سمت سرور (product_cat).
  Future<void> _fetchCategoryItems({required bool loadMore}) async {
    if (loadMore) {
      if (_loadingMoreCategoryItems ||
          !_hasMoreCategoryItems ||
          _loadingCategoryItems) {
        return;
      }
      if (mounted) setState(() => _loadingMoreCategoryItems = true);
    } else {
      setState(() => _loadingCategoryItems = true);
    }

    try {
      final int page = loadMore ? _categoryPage + 1 : 1;
      final Uri uri = Uri.parse('${widget.config.effectiveApiBaseUrl}posts')
          .replace(
            queryParameters: <String, String>{
              'per_page': '$_homePageSize',
              'type': 'product',
              'category': _activeCategorySlug,
              'page': '$page',
            },
          );
      final ApiPage response = await fetchApiPage(uri);
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _loadingCategoryItems = false;
          _loadingMoreCategoryItems = false;
          _hasMoreCategoryItems = false;
        });
        return;
      }
      final String body = response.body;
      final List<dynamic> list = jsonDecode(body) as List<dynamic>;
      final List<WpItem> fetched = list
          .whereType<Map<String, dynamic>>()
          .map(WpItem.fromMap)
          .toList();
      if (!mounted) return;
      setState(() {
        _categoryItems = loadMore
            ? <WpItem>[..._categoryItems, ...fetched]
            : fetched;
        _categoryPage = page;
        _hasMoreCategoryItems = response.hasNextPage(page);
        _loadingCategoryItems = false;
        _loadingMoreCategoryItems = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoFillViewport());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCategoryItems = false;
        _loadingMoreCategoryItems = false;
        if (loadMore) _hasMoreCategoryItems = false;
      });
    }
  }

  /// اگر بعد از هر لود، صفحه هنوز پر نشده باشد (اسکرول ممکن نیست)،
  /// خودکار صفحه بعدی را بگیر | وگرنه صفحه‌بندی با صفحه‌های کوتاه می‌خوابد.
  void _autoFillViewport() {
    if (!_homeScroll.hasClients) return;
    if (_homeScroll.position.extentAfter >= 400) return;
    if (_selectedCategory == 'همه') {
      if (_hasMoreProducts && !_loadingMoreProducts && !_isLoading) {
        _fetchProducts(loadMore: true);
      }
    } else if (_activeCategorySlug.isNotEmpty) {
      if (_hasMoreCategoryItems &&
          !_loadingMoreCategoryItems &&
          !_loadingCategoryItems) {
        _fetchCategoryItems(loadMore: true);
      }
    }
  }

  /// تب‌ها: برگشتن به خانه یعنی خروج کامل از فیلتر دسته | لیست عمومی
  /// از قبل در حافظه است و بدون fetch فوری می‌آید؛ اسکرول هم به بالا.
  void _onBottomNavTap(int index) {
    setState(() {
      _currentBottomNavIndex = index;
      if (index == 0) {
        _selectedCategory = 'همه';
        _activeCategorySlug = '';
        _categoryItems = <WpItem>[];
        _categoryPage = 1;
        _hasMoreCategoryItems = false;
        _loadingCategoryItems = false;
        _loadingMoreCategoryItems = false;
      }
    });
    if (index == 0 && _homeScroll.hasClients) {
      _homeScroll.jumpTo(0);
    }
  }

  /// ناحیه‌ی گرید محصولات در سه حالت: اسکلتونِ لود دسته / خالی / گرید.
  Widget _buildProductArea(List<WpItem> displayedItems) {
    if (_selectedCategory != 'همه' &&
        _activeCategorySlug.isNotEmpty &&
        _loadingCategoryItems) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: SkeletonProductGrid(),
      );
    }
    if (displayedItems.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'محصولی در این دسته‌بندی یافت نشد',
            style: TextStyle(color: Dk.text2),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(10),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.62,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: displayedItems.length,
        itemBuilder: (BuildContext context, int index) {
          final WpItem item = displayedItems[index];
          return ProductGridCard(
            item: item,
            primaryColor: widget.config.primaryColor,
            onTap: () => _openDetail(item),
          );
        },
      ),
    );
  }

  void _openDetail(WpItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NativeDetailScreen(
          item: item,
          config: widget.config,
          // گیت دیدگاه: بازگشت به ریشه + پرش به تب پروفایل برای لاگین
          onGoToLogin: () {
            Navigator.of(
              context,
            ).popUntil((Route<dynamic> route) => route.isFirst);
            setState(() => _currentBottomNavIndex = 3);
          },
        ),
      ),
    );
  }

  Widget _buildSkeletonHome() {
    // همان تابع سایزی که محتوای واقعی استفاده می‌کند | از فریم اول درست.
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: <Widget>[
        SkeletonCategoryCircles(
          circleSize: categoryCircleSize(_categoryCanvas),
        ),
        const SkeletonBannerSlider(),
        const SkeletonProductGrid(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<WpItem> offers = _items
        .where((WpItem item) => item.onSale && item.price.isNotEmpty)
        .toList();
    // لیست محصولات بر اساس حالت: همه (عمومی) / دسته با اسلاگ (سروری) /
    // دسته بدون اسلاگ (فال‌بک فیلتر محلی)
    final List<WpItem> displayedItems;
    if (_selectedCategory == 'همه') {
      displayedItems = _items;
    } else if (_activeCategorySlug.isNotEmpty) {
      displayedItems = _categoryItems;
    } else {
      displayedItems = _items
          .where(
            (WpItem item) => item.categoryNames.contains(_selectedCategory),
          )
          .toList();
    }

    // اگر فراخوانی API دسته‌بندی‌ها خالی بود، از نام دسته‌های خود محصولات
    // به‌عنوان جایگزین استفاده می‌کنیم تا نوار دایره‌ها هرگز خالی نماند.
    final List<Map<String, dynamic>> effectiveCategories =
        _categories.isNotEmpty
        ? _categories
        : (() {
            final Set<String> names = <String>{};
            for (final WpItem item in _items) {
              names.addAll(item.categoryNames);
            }
            return names
                .map((String name) => <String, dynamic>{'name': name})
                .toList();
          })();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Dk.canvas,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 6,
              bottom: 8,
              left: 14,
              right: 14,
            ),
            child: Row(
              children: <Widget>[
                // لوگو/نام برند اول | سپس کادر جستجو
                _HeaderLogo(
                  loading: _loadingBanners,
                  logoUrl: _headerLogoUrl,
                  name: _headerLogoName,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NativeSearchScreen(
                          config: widget.config,
                          // لیست محلی فقط با آمدن پاسخ سرور پر میشود؛ تا آن لحظه
                          // از کانفیگ تازه استفاده میکنیم تا صفحه جستجو خالی نماند.
                          suggestions: _searchSuggestions.isNotEmpty
                              ? _searchSuggestions
                              : widget.config.searchSuggestions,
                        ),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Dk.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.search, color: Dk.text3, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'جستجو در ${widget.config.appName}…',
                            style: const TextStyle(
                              color: Dk.text3,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body:
            _currentBottomNavIndex == 0 &&
                (_isLoading || _loadingCategories || _loadingBanners)
            ? _buildSkeletonHome()
            : _currentBottomNavIndex == 0 && _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _fetchProducts,
                      child: const Text('تلاش مجدد'),
                    ),
                  ],
                ),
              )
            : _currentBottomNavIndex == 0
            ? ListView(
                controller: _homeScroll,
                padding: const EdgeInsets.only(bottom: 16),
                children: <Widget>[
                  // دایره‌های دسته‌بندی
                  _CategoryCircles(
                    categories: effectiveCategories,
                    selected: _selectedCategory,
                    accent: widget.config.primaryColor,
                    circleSize: categoryCircleSize(_categoryCanvas),
                    onSelect: _selectCategory,
                  ),

                  // اسلایدر بنرها (تنظیم نیتیو شماره ۲) | روی سفید،
                  // چسبیده به خط جداکننده‌ی استوری‌ها
                  if (_banners.isNotEmpty)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BannerSlider(
                        banners: _banners,
                        interval: _sliderInterval,
                        config: widget.config,
                      ),
                    ),

                  // پیشنهاد شگفت‌انگیز (فقط محصولات تخفیف‌دار)
                  if (offers.isNotEmpty)
                    _OfferSection(
                      offers: offers,
                      countdownEnd: _offerCountdownEnd,
                      onTap: _openDetail,
                      onViewAll: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => NativeOffersScreen(
                            offers: offers,
                            config: widget.config,
                          ),
                        ),
                      ),
                    ),

                  // تنظیم ۲۱ | بازدیدهای اخیر | با تیک ادمین و وقتی چیزی
                  // دیده شده باشد | دکمهٔ «پاک کردن» در هدر ردیف.
                  _RecentlyViewedSection(config: widget.config),

                  // گرید محصولات | کلید روی کل ناحیه است تا اسکرولِ
                  // لحظه‌ی کلیک به اسکلتون هم برسد، نه فقط محتوا
                  KeyedSubtree(
                    key: _productGridKey,
                    child: _buildProductArea(displayedItems),
                  ),

                  // اسکرول بی‌نهایت | لودر صفحه‌ی بعدی (متناسب با حالت)
                  if (_selectedCategory == 'همه'
                      ? _loadingMoreProducts
                      : _loadingMoreCategoryItems)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    ),
                ],
              )
            : _currentBottomNavIndex == 1
            // تب شماره ۱: دسته‌بندی‌ها
            ? CategoriesScreen(config: widget.config)
            : _currentBottomNavIndex == 2
            // تب شماره ۲: سبد خرید اختصاصی
            ? CartView(
                config: widget.config,
                onGoToShop: () => setState(() => _currentBottomNavIndex = 0),
              )
            : _currentBottomNavIndex == 3
            // تب شماره ۳: پروفایل و ورود با موبایل
            ? ProfileScreen(config: widget.config)
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.construction_rounded, size: 52, color: Dk.text4),
                    const SizedBox(height: 10),
                    const Text(
                      'این بخش به‌زودی فعال می‌شود',
                      style: TextStyle(color: Dk.text2),
                    ),
                  ],
                ),
              ),

        // نوار ناوبری پایین صفحه | با بج زنده‌ی تعداد سبد خرید
        bottomNavigationBar: ListenableBuilder(
          listenable: CartManager.instance,
          builder: (BuildContext context, Widget? child) {
            final int cartCount = CartManager.instance.totalCount;
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Dk.border)),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentBottomNavIndex,
                onTap: (int index) => _onBottomNavTap(index),
                selectedItemColor: widget.config.primaryColor,
                unselectedItemColor: Dk.text3,
                selectedFontSize: 11,
                unselectedFontSize: 11,
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                items: <BottomNavigationBarItem>[
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'خانه',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.category_outlined),
                    activeIcon: Icon(Icons.category),
                    label: 'دسته‌ها',
                  ),
                  BottomNavigationBarItem(
                    icon: Badge(
                      isLabelVisible: cartCount > 0,
                      label: Text(toPersianDigits('$cartCount')),
                      backgroundColor: Dk.discount,
                      child: const Icon(Icons.shopping_bag_outlined),
                    ),
                    activeIcon: Badge(
                      isLabelVisible: cartCount > 0,
                      label: Text(toPersianDigits('$cartCount')),
                      backgroundColor: Dk.discount,
                      child: const Icon(Icons.shopping_bag),
                    ),
                    label: 'سبد خرید',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'پروفایل',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// --- لوگوی هدر (کارت تنظیم نیتیو شماره ۴): تا وقتی تنظیمات می‌رسد
// اسکلتون می‌گیرد؛ بعد لوگو + نام اختیاری کنارش، یا فقط متن ساده.
// چیپ رنگی حذف شد | متن خالی کافی است و باکس مشکی زشت نباشد. ---
class _HeaderLogo extends StatelessWidget {
  const _HeaderLogo({
    required this.loading,
    required this.logoUrl,
    required this.name,
  });

  final bool loading;
  final String logoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    // هیچ‌چیز برای نشان دادن نیست → اسلات کلاً جمع می‌شود
    if (!loading && logoUrl.isEmpty && name.isEmpty) {
      return const SizedBox.shrink();
    }
    // اسلات ثابت ۱۳۰×۳۶: عرض لوگو/نام هرچه باشد، سرچ‌باکس نمی‌پرد
    return SizedBox(width: 130, height: 36, child: _buildSlot());
  }

  Widget _buildSlot() {
    if (loading) {
      return const SkeletonBox(width: 130, height: 36, radius: 6);
    }
    if (logoUrl.isNotEmpty) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.network(
              logoUrl,
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (_, Object? error, StackTrace? trace) =>
                  const SizedBox.shrink(),
            ),
            if (name.isNotEmpty) ...<Widget>[
              const SizedBox(width: 8),
              _nameText(),
            ],
          ],
        ),
      );
    }
    if (name.isNotEmpty) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: _nameText(),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _nameText() {
    // فقط متن | بدون هیچ باکس و حاشیه‌ای.
    return Text(
      name,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1F2937),
      ),
    );
  }
}

// --- دایره‌های دسته‌بندی (سبک دیجی‌کالا) ---
class _CategoryCircles extends StatelessWidget {
  const _CategoryCircles({
    required this.categories,
    required this.selected,
    required this.accent,
    required this.circleSize,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> categories;
  final String selected;
  final Color accent;
  final double circleSize;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Dk.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: circleSize + 60,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          separatorBuilder: (_, __) => const SizedBox(width: 4),
          itemCount: categories.length,
          itemBuilder: (BuildContext context, int index) {
            final Map<String, dynamic> category = categories[index];
            final String name = (category['name'] as String?) ?? '';
            if (name.isEmpty) return const SizedBox.shrink();
            final String image = AppConfig.mapEmulatorUrl(
              (category['image'] as String?) ?? '',
            );
            final bool isSelected = name == selected;
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onSelect(isSelected ? null : name),
              child: SizedBox(
                width: circleSize + 18,
                child: Column(
                  children: <Widget>[
                    Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Dk.surface2,
                        border: Border.all(
                          color: isSelected ? accent : Dk.border,
                          width: isSelected ? 2 : 1,
                        ),
                        image: image.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(image),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: image.isNotEmpty
                          ? null
                          : Center(
                              child: Text(
                                name.characters.first.toUpperCase(),
                                style: TextStyle(
                                  fontSize: circleSize * 0.34,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? accent : Dk.text2,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Dk.text2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// --- اسلایدر بنرهای خانه (استایل دیجی‌کالا: اسلاید ~۹۲٪ عرض، ارتفاع ۱۸۰،
// گوشه ۸، فاصله ۸، پیک همسایه‌ها از طرفین؛ تعویض خودکار هر N ثانیه) ---
class _BannerSlider extends StatefulWidget {
  const _BannerSlider({
    required this.banners,
    required this.interval,
    required this.config,
  });

  final List<NativeBanner> banners;
  final int interval;
  final AppConfig config;

  @override
  State<_BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<_BannerSlider> {
  late final PageController _controller = PageController(
    viewportFraction: 0.92,
  );
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: widget.interval), (_) {
      if (!mounted || !_controller.hasClients) return;
      final int next = (_page + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// لینک نسبی (/landing/…) با ریشه‌ی سایت کامل می‌شود؛ localhost هم
  /// برای شبیه‌ساز به 10.0.2.2 نگاشت می‌شود.
  String _resolveBannerUrl(String link) {
    final String resolved = link.startsWith('/')
        ? '${widget.config.siteUrl}$link'
        : link;
    return AppConfig.mapEmulatorUrl(resolved);
  }

  @override
  Widget build(BuildContext context) {
    // بخش سفید و فاصله‌ها با والدِ این ویجت تنظیم می‌شود | اینجا فقط خود اسلایدر.
    return SizedBox(
      height: 180,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.banners.length,
        onPageChanged: (int index) {
          _page = index;
          _restartTimer();
        },
        itemBuilder: (BuildContext context, int index) {
          final NativeBanner banner = widget.banners[index];
          // بنر با لینک → وب‌ویو داخلی؛ بدون لینک → کلیک‌ناپذیر.
          final VoidCallback? onTap = banner.link.isEmpty
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NativeWebViewScreen(
                      title: 'تبلیغ',
                      url: _resolveBannerUrl(banner.link),
                    ),
                  ),
                );
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.04),
                  child: Image.network(
                    banner.image,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, Object? error, StackTrace? trace) =>
                        const Center(child: Icon(Icons.image, color: Dk.text4)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- شمارش معکوس شگفت‌انگیز: فقط روز و ساعت (تنظیم نیتیو شماره ۳) ---
class _OfferCountdown extends StatefulWidget {
  const _OfferCountdown({required this.endRaw});

  final String endRaw;

  @override
  State<_OfferCountdown> createState() => _OfferCountdownState();
}

class _OfferCountdownState extends State<_OfferCountdown> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    // هر دقیقه یک‌بار به‌روز می‌شود | نمایش روز/ساعت دقیق‌تر نمی‌خواهد.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _OfferCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endRaw != widget.endRaw) {
      _startTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? end = DateTime.tryParse(widget.endRaw);
    if (end == null) {
      return const SizedBox.shrink();
    }
    final Duration remaining = end.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      return const SizedBox.shrink();
    }
    final int days = remaining.inDays;
    final int hours = remaining.inHours.remainder(24);
    final int minutes = remaining.inMinutes.remainder(60);

    // سه حالت: بیش از یک روز → روز+ساعت؛ کمتر از یک روز → ساعت+دقیقه؛
    // کمتر از یک ساعت → فقط یک کادر دقیقه (هیچ‌وقت «۰ ساعت» نمی‌بینیم).
    final List<Widget> boxes;
    if (days > 0) {
      boxes = <Widget>[
        _countdownBox('${toPersianDigits(days.toString())} روز'),
        const SizedBox(width: 4),
        _countdownBox('${toPersianDigits(hours.toString())} ساعت'),
      ];
    } else if (remaining.inHours > 0) {
      boxes = <Widget>[
        _countdownBox('${toPersianDigits(remaining.inHours.toString())} ساعت'),
        const SizedBox(width: 4),
        _countdownBox('${toPersianDigits(minutes.toString())} دقیقه'),
      ];
    } else {
      boxes = <Widget>[
        _countdownBox('${toPersianDigits(minutes.toString())} دقیقه'),
      ];
    }
    // یک «مانده» مشترک بیرون از کادرها | برای هر سه حالت.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ...boxes,
        const SizedBox(width: 5),
        const Text(
          'مانده',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _countdownBox(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Dk.text1,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// --- بخش پیشنهاد شگفت‌انگیز (هدر گرادیان + کاروسل افقی) ---
class _OfferSection extends StatelessWidget {
  const _OfferSection({
    required this.offers,
    required this.countdownEnd,
    required this.onTap,
    required this.onViewAll,
  });

  final List<WpItem> offers;
  final String countdownEnd;
  final void Function(WpItem) onTap;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 5, 10, 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: Dk.offerGradient,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: <Widget>[
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 4),
                const Text(
                  'پیشنهاد شگفت‌انگیز',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                _OfferCountdown(endRaw: countdownEnd),
                const Spacer(),
                // دکمه مستطیلی «مشاهده همه» | دقیقاً بدون گردی
                InkWell(
                  onTap: onViewAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    color: Colors.white,
                    child: const Text(
                      'مشاهده همه',
                      style: TextStyle(
                        color: Dk.discount,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              itemCount: offers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int index) {
                final WpItem item = offers[index];
                final String? discount = calcDiscountPercent(
                  item.regularPrice,
                  item.salePrice,
                );
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onTap(item),
                  child: Container(
                    width: 132,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Stack(
                            children: <Widget>[
                              Positioned.fill(
                                child: item.featuredImage.isNotEmpty
                                    ? Image.network(
                                        item.featuredImage,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (
                                              _,
                                              Object? error,
                                              StackTrace? trace,
                                            ) => const Icon(
                                              Icons.image_not_supported,
                                              color: Dk.text4,
                                            ),
                                      )
                                    : const Icon(Icons.image, color: Dk.text4),
                              ),
                              if (discount != null)
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Dk.discount,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      discount,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Dk.text1,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (item.onSale && item.regularPrice.isNotEmpty)
                          Text(
                            formatToman(item.regularPrice),
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Dk.text4,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        Text(
                          formatToman(
                            item.onSale && item.salePrice.isNotEmpty
                                ? item.salePrice
                                : item.price,
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Dk.text1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- صفحه «مشاهده همه» | فهرست کامل محصولات تخفیف‌دار ---
class NativeOffersScreen extends StatelessWidget {
  const NativeOffersScreen({
    super.key,
    required this.offers,
    required this.config,
  });

  final List<WpItem> offers;
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Dk.canvas,
        appBar: AppBar(
          title: const Text(
            'پیشنهاد شگفت‌انگیز',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Dk.text1,
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Dk.text1,
          elevation: 0.5,
        ),
        body: GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.62,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: offers.length,
          itemBuilder: (BuildContext context, int index) {
            final WpItem item = offers[index];
            return ProductGridCard(
              item: item,
              primaryColor: config.primaryColor,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      NativeDetailScreen(item: item, config: config),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// --- کارت ۲ ستونه محصول با استپر تعاملی و تیتر فیکس‌شده ---
class ProductGridCard extends StatelessWidget {
  final WpItem item;
  final Color primaryColor;
  final VoidCallback onTap;

  const ProductGridCard({
    super.key,
    required this.item,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String? discount = calcDiscountPercent(
      item.regularPrice,
      item.salePrice,
    );
    final bool hasSale = item.onSale && item.salePrice.isNotEmpty;

    return InkWell(
      onTap: () {
        // تنظیم ۱۸ | اسنپ‌شات ذخیره‌شده با دادهٔ تازهٔ همین لمس بهروز میشود.
        FavoritesManager.instance.refreshSnapshot(item);
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Dk.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Dk.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ۱. تصویر محصول و برچسب تخفیف/ناموجود
            Expanded(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: item.featuredImage.isNotEmpty
                          ? Image.network(
                              item.featuredImage,
                              fit: BoxFit.contain,
                              errorBuilder:
                                  (_, Object? error, StackTrace? trace) =>
                                      const Icon(
                                        Icons.image_not_supported,
                                        color: Dk.text4,
                                      ),
                            )
                          : const Icon(Icons.image, color: Dk.text4),
                    ),
                  ),
                  if (discount != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Dk.discount,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          discount,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (!item.inStock)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.55),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: const Text(
                          'ناموجود',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  // تنظیم ۱۸ | قلب علاقه‌مندی | گوشهٔ مقابل برچسب تخفیف |
                  // گیت واکنشگرا داخل ListenableBuilder | خاموش = هیچ فضایی
                  // نمیگیرد | روشن شدن از /config بدون ریبیلد اپ ظاهر میشود.
                  PositionedDirectional(
                    top: 4,
                    end: 4,
                    child: ListenableBuilder(
                      listenable: FavoritesManager.instance,
                      builder: (BuildContext context, Widget? _) {
                        if (!FavoritesManager.instance.uiEnabled) {
                          return const SizedBox.shrink();
                        }
                        final bool saved = FavoritesManager.instance.isFavorite(
                          item.id,
                        );
                        return InkWell(
                          onTap: () => FavoritesManager.instance.toggle(item),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              shape: BoxShape.circle,
                              border: Border.all(color: Dk.border),
                            ),
                            child: Icon(
                              saved
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 18,
                              color: saved ? Dk.discount : Dk.text3,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ۲. بخش مشخصات کالا، قیمت و دکمه تعاملی
            Padding(
              padding: const EdgeInsets.all(9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // تیتر ثابت و تراز شده در بالا
                  SizedBox(
                    height: 38,
                    child: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Dk.text1,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ردیف پایین: قیمت (راست) + استپر/سبد خرید (چپ)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      // ستون قیمت
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (hasSale && item.regularPrice.isNotEmpty)
                              Text(
                                formatToman(item.regularPrice),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Dk.text4,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            Text(
                              formatToman(
                                hasSale ? item.salePrice : item.price,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: Dk.text1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // دکمه هوشمند سبد / کم و زیاد کردن زنده
                      if (item.inStock && item.purchasable)
                        ListenableBuilder(
                          listenable: CartManager.instance,
                          builder: (BuildContext context, Widget? child) {
                            final CartItem? cartItem = CartManager
                                .instance
                                .items
                                .cast<CartItem?>()
                                .firstWhere(
                                  (CartItem? ci) => ci?.item.id == item.id,
                                  orElse: () => null,
                                );
                            final int count = cartItem?.quantity ?? 0;

                            // اگر کالا در سبد نیست: آیکون سبد خرید
                            if (count == 0) {
                              // ارتفاع ثابت برابر با استپر تا کارت تغییر اندازه ندهد
                              return SizedBox(
                                height: 26,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: InkWell(
                                    onTap: () =>
                                        CartManager.instance.addItem(item),
                                    borderRadius: BorderRadius.circular(999),
                                    child: const Icon(
                                      Icons.shopping_cart_outlined,
                                      color: Color(0xFF424750),
                                      size: 22,
                                    ),
                                  ),
                                ),
                              );
                            }

                            // اگر کالا در سبد هست: کنترلر استپر (+ و تعداد و -)
                            return Container(
                              height: 26,
                              transform: Matrix4.translationValues(0, 3, 0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Dk.border,
                                  width: 1.2,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  // دکمه افزایش (+)
                                  InkWell(
                                    onTap: () =>
                                        CartManager.instance.addItem(item),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Icon(
                                        Icons.add,
                                        size: 16,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                                  // عدد تعداد به فارسی
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Text(
                                      toPersianDigits('$count'),
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: Dk.text1,
                                      ),
                                    ),
                                  ),
                                  // دکمه کاهش (-) یا سطل زباله قرمز
                                  InkWell(
                                    onTap: () =>
                                        CartManager.instance.removeOne(item),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Icon(
                                        count == 1
                                            ? Icons.delete_outline
                                            : Icons.remove,
                                        size: 16,
                                        color: count == 1
                                            ? Dk.discount
                                            : Dk.text1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- صفحه جستجو ---
class NativeSearchScreen extends StatefulWidget {
  const NativeSearchScreen({
    super.key,
    required this.config,
    this.suggestions = const <String>[],
  });

  final AppConfig config;
  final List<String> suggestions;

  /// پیشنهادهای نهایی | اگر صداکننده لیستی نداده باشد، از خود کانفیگ خوانده میشود؛
  /// اینطور باز شدن صفحه جستجو هیچوقت به زمانبندی شبکه وابسته نیست.
  List<String> get effectiveSuggestions =>
      suggestions.isNotEmpty ? suggestions : config.searchSuggestions;

  @override
  State<NativeSearchScreen> createState() => _NativeSearchScreenState();
}

class _NativeSearchScreenState extends State<NativeSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _resultsScroll = ScrollController();
  Timer? _debounce;
  int _searchSeq = 0;
  String _activeQuery = '';
  int _resultsPage = 1;
  bool _hasMoreResults = false;
  bool _loadingMoreResults = false;
  List<WpItem>? _results;
  bool _searching = false;
  String? _error;

  // تنظیم ۲۳ | وضعیت مرتب‌سازی/فیلتر | با تغییر، جستجو از صفحهٔ ۱ ریست میشود.
  String _sort = 'newest';
  bool _inStockOnly = false;

  static const int _searchPageSize = 10;

  @override
  void initState() {
    super.initState();
    // اسکرول بی‌نهایت نتایج: نزدیک انتها، صفحه بعدی همان کوئری می‌آید.
    _resultsScroll.addListener(() {
      if (_resultsScroll.position.extentAfter < 400) {
        _loadMoreResults();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _resultsScroll.dispose();
    super.dispose();
  }

  /// سرچ زنده: هر تایپ، تایمر نیم‌ثانیه‌ای را از نو شروع می‌کند؛ مکث کاربر
  /// یعنی جستجو. متن خالی هم همه‌چیز را پاک می‌کند.
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      _searchSeq++;
      if (!mounted) return;
      setState(() {
        _searching = false;
        _results = null;
        _error = null;
        _hasMoreResults = false;
        _loadingMoreResults = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 550), () {
      _runSearch(trimmed);
    });
  }

  /// تنظیم ۲۲ | ثبت کوئری فقط در سابمیت (کیبورد/ذرهبین) | تایپهای میانیِ
  /// جستجوی زنده هرگز ثبت نمیشوند | رشتهٔ کوتاهتر از ۲ نویسه در خودِ
  /// manager رد میشود.
  void _submitSearch(String query) {
    SearchHistoryManager.instance.recordQuery(query);
    _runSearch(query);
  }

  /// تنظیم ۲۲ | انتخاب چیپ تاریخچه | مکان‌نما به آخر کلمه میرود.
  void _selectHistoryQuery(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    SearchHistoryManager.instance.recordQuery(query);
    _runSearch(query);
  }

  Future<void> _runSearch(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _debounce?.cancel();
    final int seq = ++_searchSeq;
    setState(() {
      _searching = true;
      _error = null;
      _activeQuery = trimmed;
      _resultsPage = 1;
      _hasMoreResults = false;
      _loadingMoreResults = false;
    });
    final List<WpItem>? fetched = await _fetchSearchPage(
      trimmed,
      1,
      seq,
      showError: true,
    );
    if (fetched == null || !mounted) {
      return; // جواب قدیمی یا خطای نمایش‌داده‌شده
    }
    setState(() {
      _results = fetched;
      _searching = false;
    });
  }

  /// اسکرول بی‌نهایت: صفحه بعدی از همان کوئری فعال ضمیمه می‌شود.
  Future<void> _loadMoreResults() async {
    if (_loadingMoreResults || !_hasMoreResults || _searching) return;
    final int seq = ++_searchSeq;
    if (mounted) setState(() => _loadingMoreResults = true);
    final List<WpItem>? fetched = await _fetchSearchPage(
      _activeQuery,
      _resultsPage + 1,
      seq,
      showError: false,
    );
    if (!mounted) return;
    if (fetched == null) {
      if (seq == _searchSeq) {
        setState(() {
          _loadingMoreResults = false;
          _hasMoreResults = false; // خطا: تلاش مجدد خودکار متوقف می‌شود
        });
      }
      return;
    }
    if (seq != _searchSeq) return;
    setState(() {
      _results = <WpItem>[...?_results, ...fetched];
      _resultsPage++;
      _loadingMoreResults = false;
    });
  }

  /// یک صفحه از نتایج | null یعنی خطا یا جواب قدیمیِ یک جستجوی عقب‌تر.
  Future<List<WpItem>?> _fetchSearchPage(
    String query,
    int page,
    int seq, {
    required bool showError,
  }) async {
    try {
      // queryParameters کدگذاری درست فارسی/فاصله را هم تضمین می‌کند.
      final Uri
      uri = Uri.parse('${widget.config.effectiveApiBaseUrl}posts').replace(
        queryParameters: <String, String>{
          'per_page': '$_searchPageSize',
          'search': query,
          'page': '$page',
          // تنظیم ۲۳ | با تیک مرتب‌سازی، نتایج جستجو فقط محصول برمیگردند
          // تا sort/in_stock سمت سرور معنا پیدا کنند | تیک خاموش = مثل قبل.
          if (widget.config.sortFilterEnabled) 'type': 'product',
          if (widget.config.sortFilterEnabled && _sort != 'newest')
            'sort': _sort,
          if (widget.config.sortFilterEnabled && _inStockOnly) 'in_stock': '1',
        },
      );
      final ApiPage response = await fetchApiPage(uri);
      if (seq != _searchSeq || !mounted) return null;
      if (response.statusCode != 200) {
        if (showError) {
          setState(() => _error = 'خطا در جستجو (${response.statusCode})');
        }
        return null;
      }
      final String body = response.body;
      if (seq != _searchSeq || !mounted) return null;
      final List<dynamic> list = jsonDecode(body) as List<dynamic>;
      _hasMoreResults = response.hasNextPage(page);
      return list
          .whereType<Map<String, dynamic>>()
          .map(WpItem.fromMap)
          .toList();
    } catch (error) {
      if (showError && mounted && seq == _searchSeq) {
        setState(() => _error = 'خطا در اتصال به سایت');
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Dk.canvas,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 6,
              bottom: 8,
              left: 14,
              right: 14,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Dk.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      textAlignVertical: TextAlignVertical.center,
                      onChanged: _onQueryChanged,
                      onSubmitted: _submitSearch,
                      style: const TextStyle(fontSize: 12.5, color: Dk.text1),
                      decoration: InputDecoration(
                        hintText: 'جستجوی نام محصول…',
                        hintStyle: const TextStyle(
                          color: Dk.text3,
                          fontSize: 12.5,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        suffixIcon: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          icon: const Icon(Icons.search, size: 20),
                          color: Dk.text3,
                          onPressed: () => _submitSearch(_controller.text),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    // تنظیم ۲۳ | نوار مرتبسازی بالای همهٔ حالتها ثابت است (لودینگ/خطا/خالی/
    // گرید) تا کاربر با نتیجهٔ خالیِ فیلتر قفل نشود | بدون جستجوی فعال =
    // محتوای عادی (تاریخچه/پیشنهادها) بدون نوار.
    final Widget content = _buildResultsContent();
    if (!widget.config.sortFilterEnabled || _activeQuery.isEmpty) {
      return content;
    }
    return Column(
      children: <Widget>[
        SortFilterBar(
          sort: _sort,
          inStockOnly: _inStockOnly,
          primaryColor: widget.config.primaryColor,
          onChanged: (String sort, bool inStockOnly) {
            setState(() {
              _sort = sort;
              _inStockOnly = inStockOnly;
            });
            _runSearch(_activeQuery);
          },
        ),
        Expanded(child: content),
      ],
    );
  }

  Widget _buildResultsContent() {
    if (_searching) {
      return const SkeletonProductGrid();
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }
    final List<WpItem>? results = _results;
    if (results == null) {
      // حالت اولیه: تاریخچهٔ جستجو (تنظیم ۲۲) + پیشنهادهای پرطرفدار (تنظیم ۵)
      // داخل ListenableBuilder | پاک‌کردن تاریخچه بلافاصله به متن راهنما
      // برمیگردد، حتی وقتی پیشنهادها خالی باشند.
      return ListenableBuilder(
        listenable: SearchHistoryManager.instance,
        builder: (BuildContext context, Widget? _) {
          final List<String> suggestions = widget.effectiveSuggestions;
          final bool showHistory =
              SearchHistoryManager.instance.uiEnabled &&
              SearchHistoryManager.instance.queries.isNotEmpty;
          if (!showHistory && suggestions.isEmpty) {
            return const Center(
              child: Padding(
                // ۲۴ پیکسل استاندارد + ۳ پیکسل اضافه فاصله از راست
                padding: EdgeInsets.fromLTRB(24, 0, 27, 0),
                child: Text(
                  'نام محصولی که دنبالش هستید را بنویسید. نتایج زنده می‌آیند.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Dk.text2, fontSize: 13, height: 1.9),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(14),
            children: <Widget>[
              // تنظیم ۲۲ | جستجوهای اخیر | با پاک‌کردن تکی/همه.
              if (showHistory)
                _SearchHistorySection(onSelect: _selectHistoryQuery),
              if (suggestions.isNotEmpty) ...<Widget>[
                if (showHistory) const SizedBox(height: 18),
                const Text(
                  'جستجوهای پرطرفدار',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Dk.text1,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final String term in suggestions)
                      _SuggestionChip(
                        term: term,
                        onTap: () {
                          _controller.text = term;
                          _runSearch(term);
                        },
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      );
    }
    if (results.isEmpty) {
      return const Center(child: Text('نتیجه‌ای یافت نشد.'));
    }
    return Column(
      children: <Widget>[
        Expanded(
          child: GridView.builder(
            controller: _resultsScroll,
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.62,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: results.length,
            itemBuilder: (BuildContext context, int index) {
              final WpItem item = results[index];
              return ProductGridCard(
                item: item,
                primaryColor: widget.config.primaryColor,
                onTap: () {
                  // تنظیم ۲۲ | کوئری جستجویی که به نتیجه رسید با لمس ثبت میشود.
                  SearchHistoryManager.instance.recordQuery(_activeQuery);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          NativeDetailScreen(item: item, config: widget.config),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // لودر اسکرول بی‌نهایت | زیر گرید، وسط صفحه
        if (_loadingMoreResults)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
      ],
    );
  }
}

// --- چیپ واژه پرطرفدار جستجو (استایل دیجی‌کالا: قرص سفید + فلش) ---
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.term, required this.onTap});

  final String term;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Dk.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                term,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: Dk.text1),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.north_west, size: 13, color: Dk.text3),
          ],
        ),
      ),
    );
  }
}

// --- صفحه جزئیات محصول (تکی) ---
/// تنظیم ۲۴ | اشتراک‌گذاری محصول | متن نام + قیمت + لینک | شیت بومی
/// اندروید از MainActivity (MethodChannel | بدون پکیج خارجی) | هرجا شیت
/// باز نشد، متن کامل در کلیپ‌بورد کپی و به کاربر اعلام میشود.
Future<void> _shareProduct(
  BuildContext context,
  WpItem item,
  AppConfig config,
) async {
  // قیمت نهایی | حراج وقتی فعال است وگرنه قیمت عادی | formatToman خودش
  // کلمهٔ تومان را میچسباند (باگ «تومان تومان» گرفته شد).
  final String rawPrice = (item.onSale && item.salePrice.isNotEmpty)
      ? item.salePrice
      : item.price;
  final String price = rawPrice.isNotEmpty ? formatToman(rawPrice) : '';
  final String link = item.url.isNotEmpty
      ? item.url
      : '${config.siteUrl.replaceFirst(RegExp(r'/+$'), '')}/?p=${item.id}';
  final List<String> parts = <String>[
    item.title,
    if (price.isNotEmpty) price,
    link,
  ];
  final String text = parts.join('\n');
  bool shared = false;
  if (Platform.isAndroid) {
    try {
      shared =
          await const MethodChannel('wptf_share').invokeMethod<bool>(
            'shareText',
            <String, dynamic>{'text': text, 'title': item.title},
          ) ??
          false;
    } catch (_) {
      shared = false;
    }
  }
  if (shared) {
    return;
  }
  // فالبک | کپی کامل متن در کلیپ‌بورد.
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'لینک محصول کپی شد',
          style: TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// تنظیم ۲۵ | کانالهای تماس پیکربندی‌شده | واتساپ/تلگرام از کارت ۲۵ و
/// تلفن از شمارهٔ فروشگاه کارت ۱۲ | پیام واتساپ با نام و لینک محصول پر میشود.
class _InquiryChannel {
  const _InquiryChannel(this.label, this.icon, this.uri);

  final String label;
  final IconData icon;
  final Uri uri;
}

List<_InquiryChannel> _quickInquiryChannels(AppConfig config, WpItem item) {
  final List<_InquiryChannel> channels = <_InquiryChannel>[];
  final String whatsapp = config.quickInquiryWhatsapp.trim();
  // گارد تلگرام | اگر ادمین اشتباهی لینک یا @ گذاشته باشد تمیز میشود.
  final String telegram = config.quickInquiryTelegram
      .trim()
      .replaceFirst(
        RegExp(r'^(https?://)?(www\.)?t\.me/', caseSensitive: false),
        '',
      )
      .replaceFirst('@', '')
      .trim();
  final String phone = config.supportStorePhone.trim();
  final String link = item.url.isNotEmpty
      ? item.url
      : '${config.siteUrl.replaceFirst(RegExp(r'/+$'), '')}/?p=${item.id}';
  if (whatsapp.isNotEmpty) {
    channels.add(
      _InquiryChannel(
        'واتساپ',
        Icons.chat_rounded,
        Uri.parse(
          'https://wa.me/$whatsapp?text=${Uri.encodeComponent('سلام | درباره «${item.title}» سوال داشتم\n$link')}',
        ),
      ),
    );
  }
  if (telegram.isNotEmpty) {
    channels.add(
      _InquiryChannel(
        'تلگرام',
        Icons.send_rounded,
        Uri.parse('https://t.me/$telegram'),
      ),
    );
  }
  if (phone.isNotEmpty) {
    // گارد شماره | ارقام فارسی/عربی اول انگلیسی میشوند وگرنه مسیر tel:
    // خالی میماند | فقط وقتی شمارهٔ تمیز باقی مانده باشد کانال ساخته میشود.
    final String cleanPhone = _asciiDigits(
      phone,
    ).replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isNotEmpty) {
      channels.add(
        _InquiryChannel(
          'تماس تلفنی',
          Icons.phone_rounded,
          Uri(scheme: 'tel', path: cleanPhone),
        ),
      );
    }
  }
  return channels;
}

/// باز کردن کانال | تککانال = مستقیم | چندکانال = ورق انتخاب سفید RTL.
Future<void> _openInquirySheet(
  BuildContext context,
  AppConfig config,
  WpItem item,
) async {
  final List<_InquiryChannel> channels = _quickInquiryChannels(config, item);
  if (channels.isEmpty) return;
  if (channels.length == 1) {
    await _launchInquiry(context, channels.first);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (BuildContext sheetContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'سوال یا مشاوره قبل از خرید',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Dk.text1,
                ),
              ),
            ),
            for (final _InquiryChannel channel in channels)
              ListTile(
                leading: Icon(channel.icon, color: config.primaryColor),
                title: Text(
                  channel.label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Dk.text1,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _launchInquiry(context, channel);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _launchInquiry(
  BuildContext context,
  _InquiryChannel channel,
) async {
  bool opened = false;
  try {
    opened = await launchUrl(channel.uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'باز نشد | با شمارهٔ فروشگاه تماس بگیرید',
        style: TextStyle(color: Colors.white, fontSize: 13),
      ),
      backgroundColor: Colors.black,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class NativeDetailScreen extends StatelessWidget {
  final WpItem item;
  final AppConfig config;
  final VoidCallback? onGoToLogin;

  const NativeDetailScreen({
    super.key,
    required this.item,
    required this.config,
    this.onGoToLogin,
  });

  @override
  Widget build(BuildContext context) {
    final String? discount = calcDiscountPercent(
      item.regularPrice,
      item.salePrice,
    );
    final bool hasSale = item.onSale && item.salePrice.isNotEmpty;
    final List<String> gallery = item.galleryImages.isNotEmpty
        ? item.galleryImages
        : (item.featuredImage.isNotEmpty
              ? <String>[item.featuredImage]
              : <String>[]);

    // تنظیم ۲۱ | ثبت بازدید | رکورد بعد از فریم اول انجام میشود تا
    // notifyListeners هرگز داخل build نیفتد | تغییر item هم پوشش دارد.
    return _RecentlyViewedRecorder(
      item: item,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              item.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Dk.text1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: <Widget>[
              // تنظیم ۲۴ | اشتراک‌گذاری محصول | شیت بومی + فالبک کپی.
              if (config.shareProductEnabled && item.isProduct)
                IconButton(
                  tooltip: 'اشتراک‌گذاری',
                  onPressed: () => _shareProduct(context, item, config),
                  icon: const Icon(Icons.share_outlined, color: Dk.text1),
                ),
              // تنظیم ۱۸ | قلب علاقه‌مندی | زنده و کنار آیکون سبد.
              if (config.favoritesEnabled)
                ListenableBuilder(
                  listenable: FavoritesManager.instance,
                  builder: (BuildContext context, Widget? _) {
                    final bool saved = FavoritesManager.instance.isFavorite(
                      item.id,
                    );
                    return IconButton(
                      tooltip: 'علاقه‌مندی',
                      onPressed: () => FavoritesManager.instance.toggle(item),
                      icon: Icon(
                        saved
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: saved ? Dk.discount : Dk.text1,
                      ),
                    );
                  },
                ),
              ListenableBuilder(
                listenable: CartManager.instance,
                builder: (BuildContext context, Widget? child) {
                  final int count = CartManager.instance.totalCount;
                  return IconButton(
                    tooltip: '\u0633\u0628\u062F \u062E\u0631\u06CC\u062F',
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext cartContext) => Directionality(
                            textDirection: TextDirection.rtl,
                            child: Scaffold(
                              appBar: AppBar(
                                title: const Text(
                                  '\u0633\u0628\u062F \u062E\u0631\u06CC\u062F',
                                ),
                              ),
                              body: CartView(
                                config: config,
                                onGoToShop: () =>
                                    Navigator.of(cartContext).popUntil(
                                      (Route<dynamic> route) => route.isFirst,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    icon: Badge(
                      isLabelVisible: count > 0,
                      label: Text(
                        toPersianDigits('$count'),
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Dk.discount,
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: Dk.text1,
                      ),
                    ),
                  );
                },
              ),
            ],
            backgroundColor: Colors.white,
            foregroundColor: Dk.text1,
            elevation: 0.5,
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // گالری تصاویر محصول | لمس هر عکس = نمایشگر تمام‌قد زوم‌دار
                if (gallery.isNotEmpty)
                  SizedBox(
                    height: 280,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: gallery.length,
                      itemBuilder: (BuildContext context, int index) {
                        return GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            PageRouteBuilder<void>(
                              opaque: true,
                              transitionDuration: const Duration(
                                milliseconds: 250,
                              ),
                              pageBuilder:
                                  (
                                    _,
                                    Animation<double> __,
                                    Animation<double> ___,
                                  ) => _ImageViewerScreen(
                                    images: gallery,
                                    initialIndex: index,
                                  ),
                              transitionsBuilder:
                                  (
                                    _,
                                    Animation<double> animation,
                                    Animation<double> __,
                                    Widget child,
                                  ) {
                                    return SlideTransition(
                                      position:
                                          Tween<Offset>(
                                            begin: const Offset(0, 1),
                                            end: Offset.zero,
                                          ).animate(
                                            CurvedAnimation(
                                              parent: animation,
                                              curve: Curves.easeOutCubic,
                                            ),
                                          ),
                                      child: child,
                                    );
                                  },
                            ),
                          ),
                          child: Container(
                            width: MediaQuery.of(context).size.width,
                            padding: const EdgeInsets.all(20),
                            color: Dk.surface2,
                            child: Image.network(
                              gallery[index],
                              fit: BoxFit.contain,
                              errorBuilder:
                                  (_, Object? error, StackTrace? trace) =>
                                      const SizedBox.shrink(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                          color: Dk.text1,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // امتیاز و دیدگاه‌ها
                      if (item.rating > 0)
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.star_rounded,
                              color: Dk.star,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Dk.text1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${item.reviewsCount} دیدگاه',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Dk.text3,
                              ),
                            ),
                          ],
                        ),

                      // قیمت در صفحه جزئیات
                      if (item.price.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Dk.surface2,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              const Text(
                                'قیمت محصول:',
                                style: TextStyle(color: Dk.text3, fontSize: 13),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  if (hasSale && discount != null)
                                    Row(
                                      children: <Widget>[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Dk.discount,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            discount,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          formatToman(item.regularPrice),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Dk.text4,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formatToman(
                                      hasSale ? item.salePrice : item.price,
                                    ),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: hasSale ? Dk.success : Dk.text1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      // وضعیت انبار
                      if (item.isProduct) ...<Widget>[
                        const SizedBox(height: 10),
                        if (!item.inStock) ...<Widget>[
                          _StockBadge(
                            text: 'ناموجود',
                            color: const Color(0xFFD63638),
                          ),
                          // تنظیم ۲۶ | موجود شد خبرم کن | فقط با تیک ادمین.
                          if (config.stockNotifyEnabled)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: _StockNotifyButton(
                                item: item,
                                config: config,
                              ),
                            ),
                        ] else if (item.stockQuantity != null &&
                            item.stockQuantity! > 0 &&
                            item.stockQuantity! <= 5)
                          _StockBadge(
                            text:
                                'تنها ${item.stockQuantity} عدد در انبار باقیست!',
                            color: const Color(0xFF996800),
                          ),
                        if (item.sku.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'کد محصول: ${item.sku}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Dk.text3,
                              ),
                            ),
                          ),
                      ],

                      // تنظیم ۲۵ | مشاوره و استعلام سریع | فقط با تیک ادمین و
                      // حداقل یک کانال تماس پیکربندی‌شده.
                      if (config.quickInquiryEnabled &&
                          item.isProduct &&
                          _quickInquiryChannels(config, item).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: InkWell(
                            onTap: () =>
                                _openInquirySheet(context, config, item),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Dk.surface2,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Dk.border),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.support_agent_rounded,
                                    size: 20,
                                    color: config.primaryColor,
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'سوال یا مشاوره قبل از خرید؟',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Dk.text1,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_left_rounded,
                                    size: 18,
                                    color: Dk.text3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // ویژگی‌های محصول
                      if (item.attributes.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 14),
                        for (final WpAttribute attribute in item.attributes)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '${attribute.name}: ',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Dk.text1,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    attribute.options.join('، '),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.8,
                                      color: Dk.text2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],

                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Dk.border),
                      const SizedBox(height: 12),
                      const Text(
                        'توضیحات:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Dk.text1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      HtmlWidget(
                        item.content.isNotEmpty
                            ? item.content
                            : '<p>توضیحات تکمیلی برای این محصول ثبت نشده است.</p>',
                        textStyle: const TextStyle(
                          color: Dk.text2,
                          fontSize: 13,
                          height: 1.8,
                        ),
                      ),

                      // تنظیم ۱۹ | محصولات مرتبط | فقط با تیک ادمین و فقط
                      // برای محصول | تیک خاموش = هیچ ردیف مرتبطی نمایش داده
                      // نمیشود | همسلوک با کارت ۱۷ و ۱۸.
                      if (config.relatedProductsEnabled && item.isProduct)
                        _RelatedProductsSection(config: config, item: item),

                      // دیدگاه‌های کاربران | با خط جداکننده، بالای دکمه سبد
                      const SizedBox(height: 24),
                      const Divider(height: 1, color: Dk.border),
                      const SizedBox(height: 16),
                      ProductReviewsSection(
                        item: item,
                        config: config,
                        requireLogin: config.reviewsRequireLogin,
                        onGoToLogin: onGoToLogin,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // دکمه ثابت خرید در پایین صفحه
          bottomNavigationBar: Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 12 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Dk.border)),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: config.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: item.purchasable
                  ? () {
                      CartManager.instance.addItem(item);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('کالا به سبد خرید اضافه شد'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  : null,
              child: Text(
                item.purchasable ? 'افزودن به سبد خرید' : 'خرید در دسترس نیست',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// نمایشگر تمام‌قد عکس محصول | پس‌زمینه مشکی، ورود از پایین، زوم پینچ و
/// دابل‌تپ، لمس هر‌جا = بستن، بدون هیچ متنی
class _ImageViewerScreen extends StatefulWidget {
  const _ImageViewerScreen({required this.images, required this.initialIndex});

  final List<String> images;
  final int initialIndex;

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen> {
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  final TransformationController _zoom = TransformationController();
  Offset? _doubleTapPosition;

  @override
  void dispose() {
    _pageController.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_zoom.value != Matrix4.identity()) {
      _zoom.value = Matrix4.identity();
      return;
    }
    final Offset position = _doubleTapPosition ?? Offset.zero;
    const double scale = 2.5;
    _zoom.value = Matrix4.identity()
      ..translateByDouble(
        -position.dx * (scale - 1),
        -position.dy * (scale - 1),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        onDoubleTapDown: (TapDownDetails details) =>
            _doubleTapPosition = details.localPosition,
        onDoubleTap: _handleDoubleTap,
        child: Stack(
          children: <Widget>[
            PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (int index) {
                setState(() => _index = index);
                _zoom.value = Matrix4.identity();
              },
              itemBuilder: (BuildContext context, int index) {
                return InteractiveViewer(
                  transformationController: _zoom,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      widget.images[index],
                      fit: BoxFit.contain,
                      errorBuilder: (_, Object? error, StackTrace? trace) =>
                          const Icon(
                            Icons.image_not_supported,
                            color: Colors.white24,
                            size: 48,
                          ),
                    ),
                  ),
                );
              },
            ),
            // دکمه بستن مینیمال | بدون هیچ متن
            SafeArea(
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.45),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ),
            if (widget.images.length > 1)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Text(
                    '${toPersianDigits('${_index + 1}')} / '
                    '${toPersianDigits('${widget.images.length}')}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RelatedProductDetailScreen extends StatefulWidget {
  const _RelatedProductDetailScreen({
    required this.productId,
    required this.config,
  });

  final int productId;
  final AppConfig config;

  @override
  State<_RelatedProductDetailScreen> createState() =>
      _RelatedProductDetailScreenState();
}

class _RelatedProductDetailScreenState
    extends State<_RelatedProductDetailScreen> {
  late Future<WpItem> _product;

  @override
  void initState() {
    super.initState();
    _product = _fetchProduct();
  }

  Future<WpItem> _fetchProduct() async {
    final ApiPage response = await fetchApiPage(
      Uri.parse('${widget.config.effectiveApiBaseUrl}posts').replace(
        queryParameters: <String, String>{
          'type': 'product',
          'id': '${widget.productId}',
          'per_page': '1',
          'page': '1',
        },
      ),
    );
    if (response.statusCode != 200) {
      throw const HttpException('Product request failed');
    }
    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! List ||
        decoded.length != 1 ||
        decoded.first is! Map<String, dynamic>) {
      throw const FormatException('Invalid product response');
    }
    final Map<String, dynamic> data = decoded.first as Map<String, dynamic>;
    final dynamic product = data['product'];
    const List<String> requiredFields = <String>[
      'price',
      'regular_price',
      'sale_price',
      'in_stock',
      'purchasable',
      'on_sale',
      'sku',
      'stock_quantity',
      'rating',
      'reviews_count',
      'gallery_images',
      'attributes',
      'related_products',
    ];
    if (data['id'] != widget.productId ||
        data['type'] != 'product' ||
        data['excerpt'] is! String ||
        data['content'] is! String ||
        product is! Map<String, dynamic> ||
        !requiredFields.every(product.containsKey) ||
        product['in_stock'] is! bool ||
        product['purchasable'] is! bool ||
        product['on_sale'] is! bool ||
        product['gallery_images'] is! List ||
        product['attributes'] is! List ||
        product['related_products'] is! List) {
      throw const FormatException('Incomplete product response');
    }
    return WpItem.fromMap(data);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WpItem>(
      future: _product,
      builder: (BuildContext context, AsyncSnapshot<WpItem> snapshot) {
        final bool loading = snapshot.connectionState != ConnectionState.done;
        if (!loading && snapshot.hasData) {
          return NativeDetailScreen(
            item: snapshot.data!,
            config: widget.config,
          );
        }
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(title: const Text('جزئیات محصول')),
            body: Center(
              child: loading
                  ? CircularProgressIndicator(color: widget.config.primaryColor)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text('اطلاعات محصول دریافت نشد'),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() {
                            _product = _fetchProduct();
                          }),
                          child: const Text('تلاش مجدد'),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// تنظیم ۱۹ | ردیف افقی محصولات مرتبط | اول پیلود خود محصول
/// (wc_get_related_products)، وگرنه تا ۸ محصول همدسته زنده گرفته میشود |
/// خالی یا خطای شبکه = کل بخش بیصدا حذف | بدون هیچ اندپوینت تازه.
class _RelatedProductsSection extends StatefulWidget {
  const _RelatedProductsSection({required this.config, required this.item});

  final AppConfig config;
  final WpItem item;

  @override
  State<_RelatedProductsSection> createState() =>
      _RelatedProductsSectionState();
}

class _RelatedProductsSectionState extends State<_RelatedProductsSection> {
  static const int _maxItems = 8;

  /// عرض و ارتفاع ثابت | دقیقاً همان نسبت ۰.۶۲ کارت گرید خانه | صفر سرریز.
  static const double _cardWidth = 165;
  static const double _cardHeight = 266;

  List<WpItem>? _related;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant _RelatedProductsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _related = null;
      _loading = false;
      _prepare();
    }
  }

  void _prepare() {
    final List<WpItem> bundled = widget.item.relatedProducts
        .where(
          (WpItem related) => related.id > 0 && related.id != widget.item.id,
        )
        .toList(growable: false);
    if (bundled.isNotEmpty) {
      _related = bundled.take(_maxItems).toList(growable: false);
      return;
    }
    if (widget.item.categorySlugs.isNotEmpty) {
      unawaited(_fetchSameCategory());
    }
    // بدون اسلاگ دسته | داده و fallback هر دو خالی | کل بخش پنهان میماند.
  }

  Future<void> _fetchSameCategory() async {
    setState(() => _loading = true);
    try {
      final ApiPage page = await fetchApiPage(
        Uri.parse(
          '${widget.config.effectiveApiBaseUrl}posts?type=product'
          '&category=${Uri.encodeComponent(widget.item.categorySlugs.first)}'
          '&per_page=9&page=1',
        ),
      );
      final dynamic decoded = jsonDecode(page.body);
      final List<WpItem> fetched =
          (decoded is List ? decoded : const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(WpItem.fromMap)
              .where((WpItem related) => related.id != widget.item.id)
              .take(_maxItems)
              .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _related = fetched;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // خطای شبکه | کل بخش بیصدا پنهان | بدون پیام خطا.
      setState(() {
        _related = const <WpItem>[];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 20),
          const Text(
            'محصولات مرتبط',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Dk.text1,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: _cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              itemCount: 3,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(width: 4),
              itemBuilder: (BuildContext context, int index) => SizedBox(
                width: _cardWidth,
                child: const SkeletonBox(height: _cardHeight, radius: 8),
              ),
            ),
          ),
        ],
      );
    }
    final List<WpItem> related = _related ?? const <WpItem>[];
    if (related.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 20),
        const Text(
          'محصولات مرتبط',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Dk.text1,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: _cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: related.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 4),
            itemBuilder: (BuildContext context, int index) {
              final WpItem relatedItem = related[index];
              return SizedBox(
                width: _cardWidth,
                child: ProductGridCard(
                  item: relatedItem,
                  primaryColor: widget.config.primaryColor,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _RelatedProductDetailScreen(
                        productId: relatedItem.id,
                        config: widget.config,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// تنظیم ۲۱ | رکوردگر بازدید | دور کل صفحهٔ جزئیات | رکورد در
/// post-frame callback انجام میشود تا notifyListeners هرگز داخل build
/// نیفتد | تغییر شناسهٔ محصول هم پوشش داده میشود.
class _RecentlyViewedRecorder extends StatefulWidget {
  const _RecentlyViewedRecorder({required this.item, required this.child});

  final WpItem item;
  final Widget child;

  @override
  State<_RecentlyViewedRecorder> createState() =>
      _RecentlyViewedRecorderState();
}

/// تنظیم ۲۶ | محصول موجود شده | شناسه از لیست محلی خبرم‌کنها پاک میشود
/// تا چرخهٔ بعدیِ ناموجودی دوباره کار کند.
Future<void> _clearStockNotifyIfInStock(WpItem item) async {
  if (!item.inStock) return;
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> ids =
        prefs.getStringList('wptf_stock_waitlist_ids') ?? <String>[];
    if (ids.remove('${item.id}')) {
      await prefs.setStringList('wptf_stock_waitlist_ids', ids);
    }
  } catch (_) {}
}

class _RecentlyViewedRecorderState extends State<_RecentlyViewedRecorder> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        RecentlyViewedManager.instance.recordView(widget.item);
        unawaited(_clearStockNotifyIfInStock(widget.item));
      }
    });
  }

  @override
  void didUpdateWidget(covariant _RecentlyViewedRecorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          RecentlyViewedManager.instance.recordView(widget.item);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// تنظیم ۲۱ | ردیف افقی «بازدیدهای اخیر شما» در خانه | فقط با تیک ادمین و
/// وقتی چیزی دیده شده باشد | کارت‌ها همان ProductGridCard با نسبت گرید خانه.
class _RecentlyViewedSection extends StatelessWidget {
  const _RecentlyViewedSection({required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RecentlyViewedManager.instance,
      builder: (BuildContext context, Widget? _) {
        if (!RecentlyViewedManager.instance.uiEnabled) {
          return const SizedBox.shrink();
        }
        final List<WpItem> items = RecentlyViewedManager.instance.items;
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'بازدیدهای اخیر شما',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Dk.text1,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => RecentlyViewedManager.instance.clearAll(),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const <Widget>[
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: Dk.text3,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'پاک کردن',
                              style: TextStyle(fontSize: 12, color: Dk.text3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 266,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final WpItem item = items[index];
                    return SizedBox(
                      width: 165,
                      child: ProductGridCard(
                        item: item,
                        primaryColor: config.primaryColor,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                NativeDetailScreen(config: config, item: item),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// تنظیم ۲۲ | بخش «جستجوهای اخیر» | تیتر + پاک‌کردن همه + چیپ‌های سریع |
/// کاملاً واکنش‌گرا با ListenableBuilder.
class _SearchHistorySection extends StatelessWidget {
  const _SearchHistorySection({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SearchHistoryManager.instance,
      builder: (BuildContext context, Widget? _) {
        final List<String> queries = SearchHistoryManager.instance.queries;
        if (queries.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'جستجوهای اخیر',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Dk.text1,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => SearchHistoryManager.instance.clearAll(),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      'پاک کردن همه',
                      style: TextStyle(fontSize: 12, color: Dk.text3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String query in queries)
                  _SearchHistoryChip(query: query, onSelect: onSelect),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// چیپ تاریخچه | آیکون ساعت + متن کوئری + ضربدر حذف تکی.
class _SearchHistoryChip extends StatelessWidget {
  const _SearchHistoryChip({required this.query, required this.onSelect});

  final String query;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onSelect(query),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.only(right: 12, left: 4, top: 5, bottom: 5),
        decoration: BoxDecoration(
          color: Dk.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Dk.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.history_rounded, size: 15, color: Dk.text3),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: Dk.text1),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => SearchHistoryManager.instance.removeQuery(query),
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 14, color: Dk.text3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// تنظیم ۲۳ | نوار مرتب‌سازی و فیلتر موجودی | چیپ‌های RTL افقی | عمومی
/// چون هم جستجو و هم صفحهٔ محصولات دسته از آن استفاده میکنند | تغییر هر
/// چیپ با onChanged به صفحه برمیگردد تا صفحه‌بندی ریست و سرور صدا زده شود.
class SortFilterBar extends StatelessWidget {
  const SortFilterBar({
    super.key,
    required this.sort,
    required this.inStockOnly,
    required this.primaryColor,
    required this.onChanged,
  });

  /// newest | price_asc | price_desc | bestselling
  final String sort;
  final bool inStockOnly;
  final Color primaryColor;
  final void Function(String sort, bool inStockOnly) onChanged;

  static const List<(String, String)> _options = <(String, String)>[
    ('newest', 'جدیدترین'),
    ('price_asc', 'ارزان‌ترین'),
    ('price_desc', 'گران‌ترین'),
    ('bestselling', 'پرفروش‌ترین'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (final (String value, String label) in _options)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: InkWell(
                  onTap: () {
                    // چیپِ مرتبسازیِ فعال دوباره کلیک = درخواست اضافه نمیخواهیم.
                    if (sort == value) return;
                    onChanged(value, inStockOnly);
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: sort == value ? primaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: sort == value ? primaryColor : Dk.border,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: sort == value ? Colors.white : Dk.text2,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 2),
            InkWell(
              onTap: () => onChanged(sort, !inStockOnly),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: inStockOnly ? const Color(0xFFEAF7EC) : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: inStockOnly ? Dk.success : Dk.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      inStockOnly
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 14,
                      color: inStockOnly ? Dk.success : Dk.text4,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'فقط کالاهای موجود',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: inStockOnly ? Dk.success : Dk.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// تنظیم ۲۶ | دکمهٔ «موجود شد خبرم کن» | ثبت شماره روی سرور | واردشده با
/// توکن و مهمان با دیالوگ شماره | وضعیت ثبت روی خود دستگاه نگه داشته میشود.
class _StockNotifyButton extends StatefulWidget {
  const _StockNotifyButton({required this.item, required this.config});

  final WpItem item;
  final AppConfig config;

  @override
  State<_StockNotifyButton> createState() => _StockNotifyButtonState();
}

class _StockNotifyButtonState extends State<_StockNotifyButton> {
  static const String _prefsKey = 'wptf_stock_waitlist_ids';

  bool _registered = false;
  bool _busy = false;
  TextEditingController? _guestPhoneController;

  @override
  void initState() {
    super.initState();
    _loadRegistered();
  }

  @override
  void dispose() {
    _guestPhoneController?.dispose();
    super.dispose();
  }

  Future<void> _loadRegistered() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (widget.item.inStock) {
        // محصول موجود شده | شناسه از حافظه پاک میشود تا چرخهٔ بعدی کار کند.
        final List<String> ids = prefs.getStringList(_prefsKey) ?? <String>[];
        if (ids.remove('${widget.item.id}')) {
          await prefs.setStringList(_prefsKey, ids);
        }
        return;
      }
      final List<String> ids = prefs.getStringList(_prefsKey) ?? <String>[];
      if (!mounted) return;
      setState(() => _registered = ids.contains('${widget.item.id}'));
    } catch (_) {
      // بدون وضعیت ذخیره | دکمه عادی میماند.
    }
  }

  Future<void> _markRegistered() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> ids = prefs.getStringList(_prefsKey) ?? <String>[];
      if (!ids.contains('${widget.item.id}')) {
        ids.add('${widget.item.id}');
        await prefs.setStringList(_prefsKey, ids);
      }
    } catch (_) {}
    if (mounted) setState(() => _registered = true);
  }

  /// موجود شده | شناسه از حافظه پاک میشود تا چرخهٔ بعدی کار کند.
  Future<void> _clearRegistered() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> ids = prefs.getStringList(_prefsKey) ?? <String>[];
      if (ids.remove('${widget.item.id}')) {
        await prefs.setStringList(_prefsKey, ids);
      }
    } catch (_) {}
    if (mounted) setState(() => _registered = false);
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// ارسال درخواست ثبت | خروجی رکورد | needPhone یعنی حساب بدون شماره است.
  Future<({bool ok, String message, bool needPhone, bool alreadyInStock})>
  _postSubscribe({required String token, String phone = ''}) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final HttpClientRequest request = await client
          .postUrl(
            Uri.parse(
              '${widget.config.effectiveApiBaseUrl}stock-notify/subscribe',
            ),
          )
          .timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(
        jsonEncode(<String, dynamic>{
          'product_id': widget.item.id,
          if (token.isNotEmpty) 'auth_token': token,
          if (phone.isNotEmpty) 'phone': phone,
        }),
      );
      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final String raw = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return (
          ok: false,
          message: 'خطا در ارتباط با سایت',
          needPhone: false,
          alreadyInStock: false,
        );
      }
      final String message = decoded['message'] is String
          ? decoded['message'] as String
          : 'خطا در ارتباط با سایت';
      final String errorCode = decoded['code'] is String
          ? decoded['code'] as String
          : '';
      return (
        ok: response.statusCode == 200 && decoded['success'] == true,
        message: message,
        needPhone:
            errorCode == 'wptf_bad_phone' || errorCode == 'wptf_login_required',
        alreadyInStock: decoded['already_in_stock'] == true,
      );
    } catch (_) {
      return (
        ok: false,
        message: 'خطا در ارتباط با سایت',
        needPhone: false,
        alreadyInStock: false,
      );
    } finally {
      client?.close(force: true);
    }
  }

  Future<void> _subscribe() async {
    if (_busy) return;
    if (_registered) {
      // ثبت تکراری | بدون باز کردن دوبارهٔ دیالوگ شماره.
      _notice('این محصول قبلاً در لیست اطلاع‌رسانی ثبت شده است ✓');
      return;
    }
    setState(() => _busy = true);
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('wptf_auth_token') ?? '';
      String phone = '';
      if (token.isEmpty) {
        phone = await _askGuestPhone();
        if (!mounted) return;
        if (phone.isEmpty) return;
        if (!RegExp(r'^09\d{9}$').hasMatch(phone)) {
          _notice('شمارهٔ موبایل معتبر نیست | با 09 شروع میشود');
          return;
        }
      }
      var result = await _postSubscribe(token: token, phone: phone);

      // حساب واردشدهٔ بدون شماره | فالبک به دیالوگ شماره و یک تلاش دوباره.
      if (result.needPhone) {
        phone = await _askGuestPhone();
        if (!mounted) return;
        if (phone.isEmpty) return;
        if (!RegExp(r'^09\d{9}$').hasMatch(phone)) {
          _notice('شمارهٔ موبایل معتبر نیست | با 09 شروع میشود');
          return;
        }
        result = await _postSubscribe(token: token, phone: phone);
      }

      if (!mounted) return;
      if (result.alreadyInStock) {
        // موجود شده | شناسه از حافظه پاک میشود تا چرخهٔ بعدی کار کند.
        await _clearRegistered();
        _notice(result.message);
        return;
      }
      if (result.ok) {
        await _markRegistered();
      }
      _notice(result.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// دیالوگ مهمان | خروجی = ارقام انگلیسی شماره یا رشتهٔ خالی یعنی انصراف |
  /// کنترلر در State نگه داشته و در dispose تمیز میشود.
  Future<String> _askGuestPhone() async {
    final TextEditingController controller = _guestPhoneController ??=
        TextEditingController();
    controller.clear();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'موجود شد خبرم کن',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Dk.text1,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'شمارهٔ موبایل شما فقط برای یک پیامک اطلاع‌رسانی همین کالا استفاده میشود.',
                style: TextStyle(fontSize: 12, color: Dk.text2, height: 1.7),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                style: const TextStyle(fontSize: 14, color: Dk.text1),
                decoration: const InputDecoration(
                  hintText: '09123456789',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('انصراف', style: TextStyle(color: Dk.text3)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(
                'ثبت',
                style: TextStyle(
                  color: widget.config.primaryColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return _asciiDigits((result ?? '').trim());
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Dk.text1,
          backgroundColor: Colors.white,
          side: const BorderSide(color: Dk.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        onPressed: _busy ? null : _subscribe,
        child: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Dk.text2,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    _registered
                        ? Icons.check_circle_outline_rounded
                        : Icons.notifications_active_outlined,
                    size: 16,
                    color: _registered ? Dk.success : Dk.text2,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _registered
                        ? 'در لیست اطلاع‌رسانی ثبت شد ✓'
                        : 'موجود شد خبرم کن',
                  ),
                ],
              ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// --- صفحه وب‌ویو برای خرید و پرداخت ---
class NativeWebViewScreen extends StatefulWidget {
  final String title;
  final String url;

  const NativeWebViewScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<NativeWebViewScreen> createState() => _NativeWebViewScreenState();
}

class _NativeWebViewScreenState extends State<NativeWebViewScreen> {
  late final WebViewController _controller;

  /// اصلاحات موبایل برای صفحات باز شده در وبویو (نشان اعتماد، تبلیغ، پرداخت):
  /// متا ویوپورت + هیچ تصویری نباید از عرض صفحه بیرون بزند + پدینگ چپ/راست بدنه.
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
    if (!document.getElementById('wptf-webview-fix')) {
      var style = document.createElement('style');
      style.id = 'wptf-webview-fix';
      style.textContent =
        'html, body { overflow-x: hidden !important; max-width: 100vw !important; } ' +
        'img, video, iframe, table { max-width: 100% !important; height: auto !important; } ' +
        'body { padding-left: 8px !important; padding-right: 8px !important; box-sizing: border-box !important; }';
      head.appendChild(style);
    }
  } catch (e) {}
})();
''';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            _applyMobileFixes();
          },
          onPageFinished: (String url) {
            _applyMobileFixes();
          },
          onNavigationRequest: (NavigationRequest request) {
            // اسکیمهای بومی درون وبویو کرش میکنند | به سیستم واگذار میشوند.
            final Uri? uri = Uri.tryParse(request.url);
            final String scheme = (uri?.scheme ?? '').toLowerCase();
            const List<String> externalSchemes = <String>[
              'tel',
              'mailto',
              'sms',
              'whatsapp',
              'intent',
              'geo',
              'market',
              'tg',
              'instagram',
              'telegram',
              'eitaa',
            ];
            if (externalSchemes.contains(scheme)) {
              return NavigationDecision.prevent;
            }
            // شبیهساز اندروید | میزبان محلی به 10.0.2.2 نگاشت میشود.
            if (Platform.isAndroid &&
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
        ),
      )
      ..loadRequest(Uri.parse(AppConfig.mapEmulatorUrl(widget.url)));
  }

  Future<void> _applyMobileFixes() async {
    try {
      await _controller.runJavaScript(_mobileFixesJs);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            style: const TextStyle(fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          elevation: 0.5,
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
