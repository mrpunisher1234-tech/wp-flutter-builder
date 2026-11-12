import 'package:flutter/material.dart';

import 'main.dart';
import 'native_mode.dart';
import 'skeleton.dart';

/// درباره ما | متن معرفی فروشگاه + نشان‌های اعتماد، از تنظیم نیتیو ۱۳.
/// داده‌ها از /config می‌آیند (بدون بیلد مجدد به‌روز می‌شوند) و تا رسیدن جواب
/// سرور، اسکلتون پالس‌زننده نمایش داده میشود؛ حالت خالی فقط پس از اتمام لود.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, required this.config});

  final AppConfig config;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late AppConfig _config = widget.config;

  /// تا پایان لود اولیه، اسکلتون بهجای حالت خالی نمایش داده میشود.
  bool _loading = true;

  /// حداقل زمان نمایش اسکلتون | جواب سریع سرور نباید فلش نامرئی بسازد.
  static const Duration _minimumSkeleton = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final DateTime started = DateTime.now();
    try {
      final AppConfig updated = await _config.refreshRemoteSettings();
      final Duration elapsed = DateTime.now().difference(started);
      if (elapsed < _minimumSkeleton) {
        await Future<void>.delayed(_minimumSkeleton - elapsed);
      }
      if (mounted) {
        setState(() {
          _config = updated;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _openBadge(BuildContext context, String url) {
    if (url.trim().isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NativeWebViewScreen(
          title: 'نشان اعتماد',
          url: AppConfig.mapEmulatorUrl(url),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasText = _config.aboutText.trim().isNotEmpty;
    final bool hasBadges = _config.aboutBadges.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        appBar: AppBar(
          title: Text(
            'درباره ${_config.appName}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
          elevation: 0,
        ),
        body: _loading
            ? const _RealSkeletonAbout()
            : (!hasText && !hasBadges)
                ? Center(
                    child: Text(
                      'اطلاعاتی ثبت نشده است.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: <Widget>[
                      // کارت اول: معرفی فروشگاه.
                      if (hasText)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  const Icon(Icons.storefront_rounded,
                                      size: 22, color: Color(0xFF1E293B)),
                                  const SizedBox(width: 8),
                                  Text(
                                    _config.appName,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _config.aboutText,
                                style: const TextStyle(
                                    fontSize: 13,
                                    height: 2.0,
                                    color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ),
                      if (hasText && hasBadges) const SizedBox(height: 12),
                      // کارت دوم: نشان‌های اعتماد.
                      if (hasBadges)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'نشان‌های اعتماد',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: _config.aboutBadges.map((AboutBadge badge) {
                                  return InkWell(
                                    onTap: () => _openBadge(context, badge.link),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 76,
                                      height: 76,
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: const Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Image.network(
                                        AppConfig.mapEmulatorUrl(badge.image),
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (_, __, ___) => const Icon(
                                                Icons.verified_outlined,
                                                color: Colors.grey),
                                      ),
                                    ),
                                  );
                                }).toList(),
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

/// اسکلتون صفحه درباره | دقیقاً با اجزای اسکلتون فروشگاه (skeleton.dart):
/// همان SkeletonBox و SkeletonCircle با همان پالس دو خاکستری.
/// نکته: هیچ FractionallySizedBox داخل Row نیست | عرض Row نامحدود است
/// و ضرب فاکتور در بی‌نهایت، خطای infinite width و صفحه خالی میسازد.
class _RealSkeletonAbout extends StatelessWidget {
  const _RealSkeletonAbout();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      children: <Widget>[
        // کارت سفید معرفی | سربرگ + خط‌های متن.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Dk.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const SkeletonCircle(size: 22),
                  const SizedBox(width: 8),
                  const SkeletonBox(width: 90, height: 16, radius: 4),
                ],
              ),
              const SizedBox(height: 18),
              // خطوط تمامعرض | داخل Column با crossStart محدود است، امن.
              for (int i = 0; i < 3; i++) ...<Widget>[
                const SkeletonBox(height: 12, radius: 4),
                const SizedBox(height: 10),
              ],
              const SkeletonBox(width: 240, height: 12, radius: 4),
              const SizedBox(height: 10),
              const SkeletonBox(width: 160, height: 12, radius: 4),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // کارت سفید نشان‌های اعتماد | عنوان + دایره‌های هم‌اندازه نشان واقعی.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Dk.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SkeletonBox(width: 110, height: 14, radius: 4),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  for (int i = 0; i < 3; i++) ...<Widget>[
                    const SkeletonCircle(size: 76),
                    if (i < 2) const SizedBox(width: 12),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
