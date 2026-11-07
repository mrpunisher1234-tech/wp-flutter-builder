import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'main.dart';
import 'native_mode.dart';
import 'skeleton.dart';

/// مدل داده داینامیک دسته‌بندی ووکامرس
class WpCategory {
  final int id;
  final String name;
  final String slug;
  final int count;
  final String image;

  WpCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.count,
    required this.image,
  });

  factory WpCategory.fromMap(Map<String, dynamic> map) {
    return WpCategory(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: ((map['name'] as String?) ?? '').trim(),
      slug: (map['slug'] as String?) ?? '',
      count: (map['count'] as num?)?.toInt() ?? 0,
      image: AppConfig.mapEmulatorUrl(((map['image'] as String?) ?? '').trim()),
    );
  }
}

/// صفحه اصلی تب دسته‌بندی‌ها با اسکرول بی‌نهایت و اسکلتون.
/// فقط دسته‌های فروشگاه (product_cat) | دسته‌های وبلاگ اینجا نیستند.
class CategoriesScreen extends StatefulWidget {
  final AppConfig config;

  const CategoriesScreen({super.key, required this.config});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<WpCategory> _categories = <WpCategory>[];

  static const int _pageSize = 10;

  int _page = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _scrollController.addListener(_autoFillViewport);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// نزدیک انتهای لیست (یا صفحه‌ی پرنشده) صفحه بعدی می‌آید.
  /// موقع رفرش غیرفعال است تا دو fetch هم‌زمان و دو اسپینر روی هم نیفتد.
  void _autoFillViewport() {
    if (!_scrollController.hasClients) return;
    if (_refreshing || _isLoadingMore || _isLoading) return;
    if (_scrollController.position.extentAfter >= 400) return;
    if (_hasMore) {
      _fetchMoreCategories();
    }
  }

  Future<void> _fetchCategories({bool refresh = false}) async {
    if (_isLoadingMore || _refreshing) return;
    if (refresh) {
      _refreshing = true;
      setState(() {
        _page = 1;
        _hasMore = true;
        _error = null;
      });
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final Uri uri = Uri.parse(
        '${widget.config.effectiveApiBaseUrl}categories',
      ).replace(
        queryParameters: <String, String>{
          'per_page': '$_pageSize',
          'page': '1',
          'taxonomy': 'product_cat',
          'orderby': 'count',
          'order': 'DESC',
        },
      );
      final HttpClient client = HttpClient();
      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close();

      if (response.statusCode == 200) {
        final String body = await response.transform(utf8.decoder).join();
        final List<dynamic> list = jsonDecode(body) as List<dynamic>;

        if (!mounted) return;
        setState(() {
          _categories.clear();
          _categories.addAll(
            list.whereType<Map<String, dynamic>>().map(WpCategory.fromMap),
          );
          _page = 1;
          _hasMore = list.length >= _pageSize;
          _isLoading = false;
          _refreshing = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _autoFillViewport());
      } else {
        if (!mounted) return;
        setState(() {
          _error = 'خطا در بارگذاری دسته‌بندی‌ها (${response.statusCode})';
          _isLoading = false;
          _refreshing = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'خطا در اتصال به سایت';
        _isLoading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _fetchMoreCategories() async {
    if (_isLoadingMore || !_hasMore || _isLoading || _refreshing) return;

    setState(() => _isLoadingMore = true);
    final int nextPage = _page + 1;

    try {
      final Uri uri = Uri.parse(
        '${widget.config.effectiveApiBaseUrl}categories',
      ).replace(
        queryParameters: <String, String>{
          'per_page': '$_pageSize',
          'page': '$nextPage',
          'taxonomy': 'product_cat',
          'orderby': 'count',
          'order': 'DESC',
        },
      );
      final HttpClient client = HttpClient();
      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close();

      if (response.statusCode == 200) {
        final String body = await response.transform(utf8.decoder).join();
        final List<dynamic> list = jsonDecode(body) as List<dynamic>;

        if (!mounted) return;
        setState(() {
          if (list.isEmpty) {
            _hasMore = false;
          } else {
            _categories.addAll(
              list.whereType<Map<String, dynamic>>().map(WpCategory.fromMap),
            );
            _page = nextPage;
            _hasMore = list.length >= _pageSize;
          }
          _isLoadingMore = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoadingMore = false;
          _hasMore = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _hasMore = false;
      });
    }
  }

  void _openCategoryProducts(WpCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryProductsScreen(
          category: category,
          config: widget.config,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _CategoriesSkeletonGrid();
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.config.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _fetchCategories(),
              child: const Text('تلاش مجدد'),
            ),
          ],
        ),
      );
    }

    if (_categories.isEmpty) {
      return const Center(
        child: Text(
          'هیچ دسته‌بندی در فروشگاه تعریف نشده است.',
          style: TextStyle(color: Dk.text3, fontSize: 13),
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.88,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final WpCategory cat = _categories[index];
                  return _CategoryItemCard(
                    category: cat,
                    primaryColor: widget.config.primaryColor,
                    onTap: () => _openCategoryProducts(cat),
                  );
                },
                childCount: _categories.length,
              ),
            ),
          ),
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
        ],
    );
  }
}

/// کارت تک دسته‌بندی (ریسپانسیو با فال‌بک تصویر)
class _CategoryItemCard extends StatelessWidget {
  final WpCategory category;
  final Color primaryColor;
  final VoidCallback onTap;

  const _CategoryItemCard({
    required this.category,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Dk.border),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: <Widget>[
            // عکس دسته یا آیکون فال‌بک تمیز
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Dk.surface2,
                  borderRadius: BorderRadius.circular(8),
                ),
                width: double.infinity,
                child: category.image.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          category.image,
                          fit: BoxFit.contain,
                          errorBuilder: (_, Object? error, StackTrace? trace) =>
                              const Icon(
                            Icons.category_outlined,
                            size: 36,
                            color: Dk.text4,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.category_outlined,
                        size: 36,
                        color: Dk.text4,
                      ),
              ),
            ),
            const SizedBox(height: 8),

            // عنوان دسته
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Dk.text1,
              ),
            ),
            const SizedBox(height: 4),

            // ردیف پایین: تعداد کالا درشت (راست) + امتیاز ستاره‌ای (چپ)
            Row(
              children: <Widget>[
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '${toPersianDigits('${category.count}')} کالا',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Dk.text1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _CategoryStars(count: categoryStars(category)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// امتیاز ستاره‌ای قطعی هر دسته از داده‌ی خود وردپرس | بدون هیچ تنظیمی:
/// پایه از حجم محصول (۱ تا ۵) + تلورانس ±۱ از شناسه دسته تا یکنواخت نشود.
/// همیشه برای هر دسته همان عدد تولید می‌شود.
int categoryStars(WpCategory category) {
  if (category.count <= 0) return 0;
  final int base;
  if (category.count >= 50) {
    base = 5;
  } else if (category.count >= 20) {
    base = 4;
  } else if (category.count >= 8) {
    base = 3;
  } else if (category.count >= 3) {
    base = 2;
  } else {
    base = 1;
  }
  final int jitter = (category.id % 3) - 1; // -1، ۰ یا +۱
  return (base + jitter).clamp(0, 5);
}

/// پنج ستاره | روشن‌ها طلایی (Dk.star)، خاموش‌ها خاکستری کم‌رنگ.
class _CategoryStars extends StatelessWidget {
  const _CategoryStars({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    // ردیف همیشه چپ‌به‌راست رندر می‌شود و از «راست» روشن می‌گیرد |
    // یعنی پرشدن ستاره‌ها راست‌به‌چپ خوانده می‌شود (RTL).
    return Row(
      textDirection: TextDirection.ltr,
      children: List<Widget>.generate(5, (int index) {
        final bool lit = index >= 5 - count;
        return Icon(
          Icons.star_rounded,
          size: 13,
          color: lit ? Dk.star : Dk.text4.withValues(alpha: 0.4),
        );
      }),
    );
  }
}

/// اسکلتون ۲ ستونه بارگذاری دسته‌ها
class _CategoriesSkeletonGrid extends StatelessWidget {
  const _CategoriesSkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.88,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: 6,
        itemBuilder: (BuildContext context, int index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Dk.border),
            ),
            padding: const EdgeInsets.all(8),
            child: const Column(
              children: <Widget>[
                Expanded(child: SkeletonBox(radius: 8)),
                SizedBox(height: 10),
                SkeletonBox(width: 80, height: 12, radius: 4),
                SizedBox(height: 6),
                SkeletonBox(width: 45, height: 10, radius: 4),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// صفحه محصولات دسته‌بندی انتخاب‌شده | با slug و صفحه‌بندی واقعی
class CategoryProductsScreen extends StatefulWidget {
  final WpCategory category;
  final AppConfig config;

  const CategoryProductsScreen({
    super.key,
    required this.category,
    required this.config,
  });

  @override
  State<CategoryProductsScreen> createState() =>
      _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final ScrollController _scroll = ScrollController();

  static const int _pageSize = 10;

  List<WpItem> _items = <WpItem>[];
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_autoFillViewport);
    _fetchProducts();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _autoFillViewport() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter >= 400) return;
    if (_hasMore && !_loadingMore && !_loading) {
      _loadMore();
    }
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _loading = true;
      _error = null;
      _items = <WpItem>[];
      _page = 1;
      _hasMore = false;
    });

    final List<WpItem>? fetched = await _fetchPage(1);
    if (!mounted) return;
    if (fetched == null) return; // خطا نمایش داده شد
    setState(() {
      _items = fetched;
      _hasMore = fetched.length >= _pageSize;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoFillViewport());
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);

    final List<WpItem>? fetched = await _fetchPage(_page + 1);
    if (!mounted) return;
    if (fetched == null) {
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
      return;
    }
    setState(() {
      _items = <WpItem>[..._items, ...fetched];
      _page++;
      _hasMore = fetched.length >= _pageSize;
      _loadingMore = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoFillViewport());
  }

  /// یک صفحه محصول با slug واقعی دسته (نه نام!) | taxonomy=product_cat
  Future<List<WpItem>?> _fetchPage(int page) async {
    try {
      final Uri uri = Uri.parse(
        '${widget.config.effectiveApiBaseUrl}posts',
      ).replace(
        queryParameters: <String, String>{
          'per_page': '$_pageSize',
          'type': 'product',
          'category': widget.category.slug,
          'page': '$page',
        },
      );
      final HttpClient client = HttpClient();
      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close();

      if (response.statusCode != 200) {
        setState(() => _error = 'خطا در بارگذاری محصولات');
        return null;
      }
      final String body = await response.transform(utf8.decoder).join();
      final List<dynamic> list = jsonDecode(body) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(WpItem.fromMap)
          .toList();
    } catch (_) {
      setState(() => _error = 'خطا در اتصال به اینترنت');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Dk.canvas,
        appBar: AppBar(
          title: Text(
            widget.category.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Dk.text1,
            ),
          ),
          elevation: 0.5,
          backgroundColor: Colors.white,
          foregroundColor: Dk.text1,
        ),
        body: _loading
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: SkeletonProductGrid(),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.config.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _fetchProducts(),
                          child: const Text('تلاش مجدد'),
                        ),
                      ],
                    ),
                  )
                : _items.isEmpty
                    ? const Center(
                        child: Text(
                          'محصولی در این دسته‌بندی یافت نشد.',
                          style: TextStyle(color: Dk.text3),
                        ),
                      )
                    : Column(
                        children: <Widget>[
                          Expanded(
                            child: GridView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.all(10),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.62,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                              ),
                              itemCount: _items.length,
                              itemBuilder: (BuildContext context, int index) {
                                final WpItem item = _items[index];
                                return ProductGridCard(
                                  item: item,
                                  primaryColor: widget.config.primaryColor,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => NativeDetailScreen(
                                        item: item,
                                        config: widget.config,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // لودر اسکرول بی‌نهایت | زیر گرید، وسط صفحه
                          if (_loadingMore)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
      ),
    );
  }
}
