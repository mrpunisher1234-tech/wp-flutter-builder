import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';
import 'native_mode.dart';
import 'skeleton.dart';

/// نشست کاربر | با ورود موبایلی (پروفایل) پر می‌شود و دیدگاه‌ها را گیت می‌کند.
class UserSession {
  UserSession._();

  static bool isLoggedIn = false;
  static String displayName = '';

  /// بازیابی نشست از حافظه دائمی | توکن ورود موبایلی.
  static Future<void> refresh() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('wptf_auth_token');
    isLoggedIn = token != null && token.isNotEmpty;
    displayName = prefs.getString('wptf_user_name') ?? '';
  }
}

/// مدل دیدگاه کاربر
class WpReview {
  final int id;
  final String author;
  final String content;
  final int rating;
  final String date;
  final bool verified;

  const WpReview({
    required this.id,
    required this.author,
    required this.content,
    required this.rating,
    required this.date,
    this.verified = false,
  });

  factory WpReview.fromMap(Map<String, dynamic> map) {
    return WpReview(
      id: (map['id'] as num?)?.toInt() ?? 0,
      author: ((map['author'] as String?) ?? '').trim(),
      content: ((map['content'] as String?) ?? '').trim(),
      rating: (map['rating'] as num?)?.toInt() ?? 0,
      date: ((map['date'] as String?) ?? '').trim(),
      verified: map['verified'] == true,
    );
  }
}

/// بخش «امتیاز و دیدگاه کاربران» در انتهای صفحه محصول |
/// fetch واقعی ۵تایی + اسکرول بی‌نهایت + ثبت دیدگاه با ستاره‌های کلیک‌خور.
class ProductReviewsSection extends StatefulWidget {
  const ProductReviewsSection({
    super.key,
    required this.item,
    required this.config,
    this.requireLogin = false,
    this.onGoToLogin,
  });

  final WpItem item;
  final AppConfig config;

  /// تنظیم نیتیو شماره ۸: فقط کاربران واردشده با موبایل بتوانند دیدگاه بدهند.
  final bool requireLogin;

  /// هدایت به صفحه پروفایل/لاگین | از صفحه جزئیات پاس داده می‌شود.
  final VoidCallback? onGoToLogin;

  @override
  State<ProductReviewsSection> createState() => _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends State<ProductReviewsSection> {
  static const int _pageSize = 5;

  List<WpReview> _reviews = <WpReview>[];
  int _page = 1;
  int _pages = 1;
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // نشست استاتیک دیدگاه‌ها از حافظه دائمی تازه می‌شود | گیت کارت ۸ دقیق.
    UserSession.refresh();
    _fetchPage(1);
  }

  Future<void> _fetchPage(int page) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final Uri uri = Uri.parse(
        '${widget.config.effectiveApiBaseUrl}reviews',
      ).replace(
        queryParameters: <String, String>{
          'product_id': '${widget.item.id}',
          'page': '$page',
          'per_page': '$_pageSize',
        },
      );
      final HttpClient client = HttpClient();
      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _error = 'خطا در بارگذاری دیدگاه‌ها';
          _loading = false;
        });
        return;
      }
      final dynamic decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        setState(() {
          _error = 'خطا در بارگذاری دیدگاه‌ها';
          _loading = false;
        });
        return;
      }
      final List<dynamic> list = decoded['items'] as List? ?? const <dynamic>[];
      if (!mounted) return;
      setState(() {
        _reviews = list
            .whereType<Map<String, dynamic>>()
            .map(WpReview.fromMap)
            .toList();
        _page = (decoded['page'] as num?)?.toInt() ?? page;
        _pages = (decoded['pages'] as num?)?.toInt() ?? 1;
        _total = (decoded['total'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'خطا در اتصال به سایت';
        _loading = false;
      });
    }
  }

  double get _averageRating {
    if (widget.item.rating > 0) return widget.item.rating;
    final List<WpReview> rated = _reviews
        .where((WpReview review) => review.rating > 0)
        .toList();
    if (rated.isEmpty) return 0;
    final double sum = rated.fold(
      0,
      (double total, WpReview review) => total + review.rating,
    );
    return sum / rated.length;
  }

  Future<void> _submitReview(String author, String content, int rating) async {
    // توکن ورود موبایلی (اگر کاربر وارد باشد) | سرور نامش را جایگزین می‌کند
    // و دیدگاهش را مستقیم منتشر می‌کند (قانون کارت ۸).
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('wptf_auth_token');
    try {
      final Uri uri = Uri.parse('${widget.config.effectiveApiBaseUrl}reviews');
      final HttpClient client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final HttpClientRequest request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(
        utf8.encode(
          jsonEncode(<String, dynamic>{
            'product_id': widget.item.id,
            'author': author,
            'content': content,
            'rating': rating,
            'auth_token': token ?? '',
          }),
        ),
      );
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      if (!mounted) return;
      if (response.statusCode != 200) {
        final dynamic decodedError = jsonDecode(body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decodedError is Map<String, dynamic> &&
                      decodedError['message'] != null
                  ? decodedError['message'].toString()
                  : 'ثبت دیدگاه ناموفق بود | دوباره تلاش کنید',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('دیدگاه شما با موفقیت ثبت شد'),
            backgroundColor: widget.config.primaryColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        // دیدگاه تازه اولین آیتم صفحه ۱ است | بازگشت به صفحه اول و تازه‌سازی
        _fetchPage(1);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطا در اتصال | دیدگاه ثبت نشد'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildHeader(),
          const SizedBox(height: 12),
          _buildAverageCard(),
          const SizedBox(height: 14),
          _buildList(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        const Text(
          'امتیاز و دیدگاه کاربران',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Dk.text1,
          ),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: widget.config.primaryColor,
            side: BorderSide(color: widget.config.primaryColor, width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            // گیت کارت ۸: اگر «فقط کاربران واردشده» فعال باشد و کاربر
            // لاگین نکرده باشد، به صفحه پروفایل/لاگین هدایت می‌شود.
            if (widget.requireLogin && !UserSession.isLoggedIn) {
              if (widget.onGoToLogin != null) {
                widget.onGoToLogin!();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('برای ثبت دیدگاه، ابتدا با شماره موبایل وارد شوید'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              return;
            }
            _openAddReviewSheet();
          },
          icon: const Icon(Icons.rate_review_outlined, size: 16),
          label: const Text(
            'ثبت دیدگاه',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildAverageCard() {
    final double average = _averageRating;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Dk.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Dk.border),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.star_rounded, color: Dk.star, size: 28),
          const SizedBox(width: 8),
          Text(
            average > 0
                ? toPersianDigits(average.toStringAsFixed(1))
                : toPersianDigits('0'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Dk.text1,
            ),
          ),
          const SizedBox(width: 6),
          const Text('از ۵', style: TextStyle(fontSize: 12, color: Dk.text3)),
          const Spacer(),
          Text(
            'بر اساس ${toPersianDigits('$_total')} دیدگاه ثبت‌شده',
            style: const TextStyle(
              fontSize: 11.5,
              color: Dk.text2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: <Widget>[
            SkeletonBox(height: 74, radius: 8),
            SizedBox(height: 8),
            SkeletonBox(height: 74, radius: 8),
          ],
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            _error!,
            style: const TextStyle(color: Dk.text3, fontSize: 12),
          ),
        ),
      );
    }
    if (_reviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'هنوز دیدگاهی برای این محصول ثبت نشده است.',
            style: TextStyle(color: Dk.text3, fontSize: 12),
          ),
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final WpReview review in _reviews)
          _ReviewCard(review: review, primaryColor: widget.config.primaryColor),
        // نوار شماره‌صفحه | فعال پررنگ، با یک صفحه کلاً مخفی می‌شود
        _buildPagination(),
      ],
    );
  }

  /// نوار صفحه‌بندی دیدگاه‌ها | هر صفحه ۵ دیدگاه
  Widget _buildPagination() {
    if (_pages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _pageChip('‹', _page - 1, enabled: _page > 1),
            for (int p = 1; p <= _pages; p++)
              _pageChip(
                toPersianDigits('$p'),
                p,
                enabled: p != _page,
                active: p == _page,
              ),
            _pageChip('›', _page + 1, enabled: _page < _pages),
          ],
        ),
      ),
    );
  }

  Widget _pageChip(
    String label,
    int target, {
    required bool enabled,
    bool active = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: enabled ? () => _fetchPage(target) : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? widget.config.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active ? widget.config.primaryColor : Dk.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active
                  ? Colors.white
                  : (enabled ? Dk.text2 : Dk.text4),
            ),
          ),
        ),
      ),
    );
  }

  void _openAddReviewSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _AddReviewBottomSheet(
        productTitle: widget.item.title,
        primaryColor: widget.config.primaryColor,
        onSubmit: (String author, String content, int rating) {
          Navigator.of(sheetContext).pop();
          _submitReview(author, content, rating);
        },
      ),
    );
  }
}

/// کارت تک دیدگاه (سبک دیجی‌کالا) | متن بلند بعد از ۵ خط با «بیشتر...» باز می‌شود
class _ReviewCard extends StatefulWidget {
  const _ReviewCard({required this.review, required this.primaryColor});

  final WpReview review;
  final Color primaryColor;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  static const TextStyle _contentStyle = TextStyle(
    fontSize: 12.5,
    color: Dk.text2,
    height: 1.6,
  );

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Dk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildHeaderRow(),
          const SizedBox(height: 8),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: <Widget>[
        if (widget.review.rating > 0) ...<Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF00A049),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: <Widget>[
                Text(
                  toPersianDigits('${widget.review.rating}'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.star, color: Colors.white, size: 10),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            widget.review.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Dk.text1,
            ),
          ),
        ),
        if (widget.review.verified) ...<Widget>[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Dk.surface2,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'خریدار',
              style: TextStyle(fontSize: 9.5, color: Dk.text3),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Text(
          widget.review.date,
          style: const TextStyle(fontSize: 11, color: Dk.text4),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // تشخیص دقیق سرریز با TextPainter | نه تخمین طول کاراکتر
        final TextPainter painter = TextPainter(
          text: TextSpan(text: widget.review.content, style: _contentStyle),
          maxLines: 5,
          textDirection: TextDirection.rtl,
        )..layout(maxWidth: constraints.maxWidth - 24);
        final bool isLong = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.review.content,
              maxLines: _expanded ? null : 5,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: _contentStyle,
            ),
            if (isLong || _expanded)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _expanded ? 'کمتر...' : 'بیشتر...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.primaryColor,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// باتم‌شیت ثبت دیدگاه با ستاره‌های تعاملی
class _AddReviewBottomSheet extends StatefulWidget {
  const _AddReviewBottomSheet({
    required this.productTitle,
    required this.primaryColor,
    required this.onSubmit,
  });

  final String productTitle;
  final Color primaryColor;
  final void Function(String author, String content, int rating) onSubmit;

  @override
  State<_AddReviewBottomSheet> createState() => _AddReviewBottomSheetState();
}

class _AddReviewBottomSheetState extends State<_AddReviewBottomSheet> {
  int _selectedStars = 5;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  String get _ratingLabel {
    switch (_selectedStars) {
      case 1:
        return 'خیلی بد';
      case 2:
        return 'بد';
      case 3:
        return 'معمولی';
      case 4:
        return 'خوب';
      default:
        return 'عالی و فوق‌العاده!';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // باتم‌شیت از روت ناوگیتور باز می‌شود که RTL ندارد | اینجا صریح می‌شود
    // تا placeholder، علامت «!» و چینش ردیف‌ها راست‌به‌چپ شوند.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  'ثبت نظر و امتیاز',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Dk.text1,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 1, color: Dk.border),
            const SizedBox(height: 12),

            Center(
              child: Column(
                children: <Widget>[
                  const Text(
                    'امتیاز شما به این محصول:',
                    style: TextStyle(fontSize: 12, color: Dk.text3),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List<Widget>.generate(5, (int index) {
                      final int starValue = index + 1;
                      return IconButton(
                        iconSize: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        icon: Icon(
                          starValue <= _selectedStars
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: starValue <= _selectedStars
                              ? Dk.star
                              : Dk.text4,
                        ),
                        onPressed: () =>
                            setState(() => _selectedStars = starValue),
                      );
                    }),
                  ),
                  Text(
                    _ratingLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Dk.text1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: 'نام شما (اختیاری)',
                hintStyle: const TextStyle(fontSize: 12, color: Dk.text4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Dk.border),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'متن نظر خود را بنویسید…',
                hintStyle: const TextStyle(fontSize: 12, color: Dk.text4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Dk.border),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                if (_commentController.text.trim().length < 3) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('لطفاً متن نظر را وارد کنید'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  return;
                }
                widget.onSubmit(
                  _nameController.text.trim(),
                  _commentController.text.trim(),
                  _selectedStars,
                );
              },
              child: const Text(
                'ثبت دیدگاه',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
