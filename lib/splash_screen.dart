import 'package:flutter/material.dart';

import 'main.dart';

/// صفحه شروع اپ (اسپلش) | ترتیب ثابت و دقیقاً همان پیشنمایش پنل وردپرس:
/// لوگو (قاب ثابت ۹۵ پیکسل، ضدپرش) → نام سایت → ردیف راستبهچپ متن لودینگ و نقطههای متحرک.
///
/// لوگو از `AppConfig.splashLogoProvider` خوانده میشود؛ اگر بیلد ابری لوگو را داخل APK
/// بستهبندی کرده باشد از assets میآید و در فریم اول رسم میشود، وگرنه از شبکه.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.config});

  final AppConfig config;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// قاب ثابت لوگو | عدد ثابت است تا نه سایز عوض شود و نه چیدمان بپرد.
  static const double _logoBox = 95;

  bool _precacheStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // پیشدیکد لوگو پیش از نخستین رنگآمیزی | همان فریم اول بدون معطلی آماده میشود.
    if (_precacheStarted) {
      return;
    }
    _precacheStarted = true;
    final ImageProvider? provider = widget.config.splashLogoProvider;
    if (provider == null) {
      return;
    }
    precacheImage(provider, context, onError: (Object _, StackTrace? __) {
      // نبود فایل داخلی نباید اسپلش را خراب کند؛ build خودش به نسخه شبکه برمیگردد.
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color background = widget.config.splashBackgroundColor;
    final Color foreground = widget.config.splashTextColor;

    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: background,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: _logoBox,
                  height: _logoBox,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildLogo(),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.config.splashBrandText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 18),
                // چینش RTL: متن لودینگ سمت راست و نقطهها در سمت چپ آن.
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        widget.config.splashLoadingText,
                        style: TextStyle(
                          color: foreground.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _PulsingDots(color: foreground),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    final ImageProvider? provider = widget.config.splashLogoProvider;
    if (provider == null) {
      return const SizedBox.shrink();
    }
    return Image(
      image: provider,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      frameBuilder: (
        BuildContext context,
        Widget child,
        int? frame,
        bool wasSynchronouslyLoaded,
      ) {
        // لوگوی بستهبندیشده در همان فریم حاضر است و بدون فیدین نمایش داده میشود.
        if (wasSynchronouslyLoaded) {
          return child;
        }
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        // فایل داخلی خراب یا منقضی شده | نمایش از شبکه، و در نهایت قاب خالی.
        final ImageProvider? fallback = widget.config.splashLogoNetworkProvider;
        if (fallback == null || fallback == provider) {
          return const SizedBox.shrink();
        }
        return Image(
          image: fallback,
          fit: BoxFit.contain,
          errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}

class _PulsingDots extends StatefulWidget {
  const _PulsingDots({required this.color});

  final Color color;

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(3, (int index) {
            final double phase = (_controller.value - index / 6.0) % 1.0;
            final double t = Curves.easeInOut.transform(phase);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Opacity(
                opacity: 0.25 + 0.75 * t,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
