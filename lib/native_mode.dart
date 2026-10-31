import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import 'main.dart';

/// Data model for a post or product returned by the plugin REST API.
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

  bool get isProduct => type == 'product';

  factory WpItem.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> product =
        map['product'] is Map<String, dynamic>
            ? map['product'] as Map<String, dynamic>
            : <String, dynamic>{};
    return WpItem(
      id: (map['id'] as num?)?.toInt() ?? 0,
      type: (map['type'] as String?) ?? 'post',
      title: (map['title'] as String?) ?? '',
      excerpt: (map['excerpt'] as String?) ?? '',
      content: (map['content'] as String?) ?? '',
      url: (map['url'] as String?) ?? '',
      featuredImage: (map['featured_image'] as String?) ?? '',
      price: (product['price'] as String?) ?? '',
      regularPrice: (product['regular_price'] as String?) ?? '',
      salePrice: (product['sale_price'] as String?) ?? '',
    );
  }
}

String _stripTags(String html) {
  final String clean = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
  return clean
      .replaceAll('&hellip;', '…')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Fetches one page of posts/products from the plugin REST API.
Future<List<WpItem>> fetchItems(
  AppConfig config, {
  int page = 1,
  String type = 'all',
  String category = '',
  String search = '',
}) async {
  final Map<String, String> query = <String, String>{
    'page': '$page',
    'per_page': '10',
    'type': type,
  };
  if (category.isNotEmpty) {
    query['category'] = category;
  }
  if (search.trim().isNotEmpty) {
    query['search'] = search.trim();
  }
  final String queryString = query.entries
      .map((MapEntry<String, String> entry) =>
          '${entry.key}=${Uri.encodeQueryComponent(entry.value)}')
      .join('&');
  final Uri uri =
      Uri.parse('${config.effectiveApiBaseUrl}posts?$queryString');

  final http.Response response = await http
      .get(uri, headers: <String, String>{'Accept': 'application/json'})
      .timeout(const Duration(seconds: 25));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('HTTP ${response.statusCode}');
  }
  final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
  if (decoded is! List) {
    return <WpItem>[];
  }
  return decoded
      .whereType<Map<String, dynamic>>()
      .map(WpItem.fromMap)
      .toList(growable: false);
}

/// Fetches category / product-cat chips from the plugin REST API.
Future<List<Map<String, dynamic>>> fetchCategories(AppConfig config) async {
  final Uri uri = Uri.parse(
    '${config.effectiveApiBaseUrl}categories?per_page=30&hide_empty=1',
  );
  final http.Response response = await http
      .get(uri, headers: <String, String>{'Accept': 'application/json'})
      .timeout(const Duration(seconds: 20));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    return <Map<String, dynamic>>[];
  }
  final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
  if (decoded is! List) {
    return <Map<String, dynamic>>[];
  }
  return decoded.whereType<Map<String, dynamic>>().toList(growable: false);
}

class NativeHomeScreen extends StatefulWidget {
  const NativeHomeScreen({super.key, required this.config});

  final AppConfig config;

  @override
  State<NativeHomeScreen> createState() => _NativeHomeScreenState();
}

class _NativeHomeScreenState extends State<NativeHomeScreen> {
  final ScrollController _scrollController = ScrollController();
  List<WpItem> _items = <WpItem>[];
  List<Map<String, dynamic>> _categories = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;
  String _type = 'all';
  String _category = '';

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadCategories();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
            _scrollController.position.maxScrollExtent - 400 &&
        !_loadingMore &&
        _hasMore &&
        !_loading) {
      _loadMore();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
    });
    try {
      final List<WpItem> items = await fetchItems(
        widget.config,
        page: 1,
        type: _type,
        category: _category,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _loading = false;
        _hasMore = items.length >= 10;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'خطا در دریافت محتوا. اتصال اینترنت را بررسی کنید.';
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final List<WpItem> items = await fetchItems(
        widget.config,
        page: _page + 1,
        type: _type,
        category: _category,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _page += 1;
        _items = _items + items;
        _loadingMore = false;
        _hasMore = items.length >= 10;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final List<Map<String, dynamic>> categories =
          await fetchCategories(widget.config);
      if (mounted) {
        setState(() => _categories = categories);
      }
    } catch (error) {
      // Category chips are optional decoration — silence is fine.
    }
  }

  void _selectCategory(Map<String, dynamic>? chip) {
    setState(() {
      if (chip == null) {
        _type = 'all';
        _category = '';
      } else {
        _category = (chip['slug'] as String?) ?? '';
        _type = (chip['taxonomy'] as String?) == 'product_cat'
            ? 'product'
            : 'post';
      }
    });
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: widget.config.primaryColor,
          foregroundColor: Colors.white,
          title: Text(widget.config.appName),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NativeSearchScreen(config: widget.config),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            SizedBox(
              height: 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: const Text('همه'),
                      selected: _category.isEmpty,
                      selectedColor: widget.config.primaryColor,
                      labelStyle: TextStyle(
                        color: _category.isEmpty ? Colors.white : null,
                      ),
                      onSelected: (_) => _selectCategory(null),
                    ),
                  ),
                  for (final Map<String, dynamic> chip in _categories)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text((chip['name'] as String?) ?? ''),
                        selected: _category == (chip['slug'] ?? ''),
                        selectedColor: widget.config.primaryColor,
                        labelStyle: TextStyle(
                          color:
                              _category == (chip['slug'] ?? '') ? Colors.white : null,
                        ),
                        onSelected: (_) => _selectCategory(chip),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: SpinKitFallback(color: widget.config.primaryColor),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off_rounded,
                size: 56, color: widget.config.primaryColor),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _refresh,
              style: FilledButton.styleFrom(
                backgroundColor: widget.config.primaryColor,
              ),
              child: const Text('تلاش مجدد'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('موردی یافت نشد.'));
    }
    return RefreshIndicator(
      color: widget.config.primaryColor,
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 6, bottom: 24),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (BuildContext context, int index) {
          if (index >= _items.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: SpinKitFallback(color: widget.config.primaryColor, small: true),
              ),
            );
          }
          final WpItem item = _items[index];
          return WpItemCard(
            item: item,
            accent: widget.config.primaryColor,
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
    );
  }
}

/// Simple spinner used by native screens (no extra dependency needed here).
class SpinKitFallback extends StatelessWidget {
  const SpinKitFallback({super.key, required this.color, this.small = false});

  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: small ? 24 : 46,
      height: small ? 24 : 46,
      child: CircularProgressIndicator(
        strokeWidth: small ? 2.4 : 3.4,
        color: color,
      ),
    );
  }
}

class WpItemCard extends StatelessWidget {
  const WpItemCard({
    super.key,
    required this.item,
    required this.accent,
    required this.onTap,
  });

  final WpItem item;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      elevation: 0.6,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (item.featuredImage.isNotEmpty)
              Image.network(
                AppConfig.mapEmulatorUrl(item.featuredImage),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, Object? error, StackTrace? trace) =>
                    const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_stripTags(item.excerpt).isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      _stripTags(item.excerpt),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.8,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (item.isProduct && item.price.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    WpPriceRow(item: item, accent: accent),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WpPriceRow extends StatelessWidget {
  const WpPriceRow({super.key, required this.item, required this.accent});

  final WpItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final bool hasSale =
        item.salePrice.isNotEmpty && item.salePrice != item.regularPrice;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: <Widget>[
        Text(
          hasSale ? item.salePrice : item.price,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: hasSale ? const Color(0xFF0A7D33) : accent,
          ),
          textDirection: TextDirection.ltr,
        ),
        if (hasSale && item.regularPrice.isNotEmpty)
          Text(
            item.regularPrice,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              decoration: TextDecoration.lineThrough,
            ),
            textDirection: TextDirection.ltr,
          ),
      ],
    );
  }
}

class NativeDetailScreen extends StatelessWidget {
  const NativeDetailScreen({
    super.key,
    required this.item,
    required this.config,
  });

  final WpItem item;
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: config.primaryColor,
          foregroundColor: Colors.white,
          title: Text(
            item.isProduct ? 'محصول' : 'نوشته',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (item.featuredImage.isNotEmpty)
                Image.network(
                  AppConfig.mapEmulatorUrl(item.featuredImage),
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, Object? error, StackTrace? trace) =>
                      const SizedBox.shrink(),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.6,
                      ),
                    ),
                    if (item.isProduct && item.price.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10),
                      WpPriceRow(item: item, accent: config.primaryColor),
                    ],
                    const SizedBox(height: 14),
                    if (item.isProduct && item.url.isNotEmpty) ...<Widget>[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => NativeWebViewScreen(
                                url: AppConfig.mapEmulatorUrl(item.url),
                                title: item.title,
                                accent: config.primaryColor,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.shopping_cart_checkout_rounded),
                          label: const Text('مشاهده و خرید در سایت'),
                          style: FilledButton.styleFrom(
                            backgroundColor: config.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    HtmlWidget(
                      AppConfig.mapEmulatorUrl(item.content),
                      textStyle: const TextStyle(fontSize: 15, height: 1.9),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class NativeSearchScreen extends StatefulWidget {
  const NativeSearchScreen({super.key, required this.config});

  final AppConfig config;

  @override
  State<NativeSearchScreen> createState() => _NativeSearchScreenState();
}

class _NativeSearchScreenState extends State<NativeSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<WpItem>? _results;
  bool _searching = false;
  String? _error;

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final List<WpItem> items = await fetchItems(
        widget.config,
        search: query,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _results = items;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _searching = false;
        _error = 'جستجو ناموفق بود.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: widget.config.primaryColor,
          foregroundColor: Colors.white,
          title: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: _runSearch,
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.white,
            decoration: const InputDecoration(
              hintText: 'جستجو در محصولات و نوشته‌ها…',
              hintStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none,
            ),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_searching) {
      return Center(
        child: SpinKitFallback(color: widget.config.primaryColor),
      );
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    final List<WpItem>? results = _results;
    if (results == null) {
      return const Center(
        child: Text('عبارت مورد نظر را برای جستجو وارد کنید.'),
      );
    }
    if (results.isEmpty) {
      return const Center(child: Text('نتیجه‌ای یافت نشد.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 24),
      itemCount: results.length,
      itemBuilder: (BuildContext context, int index) {
        final WpItem item = results[index];
        return WpItemCard(
          item: item,
          accent: widget.config.primaryColor,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  NativeDetailScreen(item: item, config: widget.config),
            ),
          ),
        );
      },
    );
  }
}

/// Minimal in-app browser used for checkout and external product pages.
class NativeWebViewScreen extends StatefulWidget {
  const NativeWebViewScreen({
    super.key,
    required this.url,
    required this.title,
    required this.accent,
  });

  final String url;
  final String title;
  final Color accent;

  @override
  State<NativeWebViewScreen> createState() => _NativeWebViewScreenState();
}

class _NativeWebViewScreenState extends State<NativeWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _loading = false);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: widget.accent,
          foregroundColor: Colors.white,
          title: Text(widget.title,
              style: const TextStyle(fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        body: Stack(
          children: <Widget>[
            WebViewWidget(controller: _controller),
            if (_loading)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.white,
                  child: Center(
                    child: SpinKitFallback(color: widget.accent),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
