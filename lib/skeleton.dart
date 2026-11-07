import 'package:flutter/material.dart';

/// اندازه دایره دسته‌بندی = category_canvas_size ÷ ۴ (کلمپ ۶۴ تا ۱۲۸).
///
/// تنها منبع حقیقت سایز | هم اسکلتون و هم محتوای واقعی (_CategoryCircles)
/// از همین تابع استفاده می‌کنند تا سایز اسکلتون همیشه دقیقاً با محتوا
/// یکی باشد و هرگز به هم نپرد.
double categoryCircleSize(num canvas) =>
    (canvas / 4).clamp(64.0, 128.0).toDouble();

// --- توکن‌های اسکلتون: خاکستری خنثی، هیچ رنگ دیگری (بدون زرد) ---
const Color _skBase = Color(0xFFECEDEF);
const Color _skPulse = Color(0xFFF7F8FA);
const Duration _skPeriod = Duration(milliseconds: 1150);

/// لرزش ملایم بین دو خاکستری؛ هسته‌ی مشترک همه‌ی اجزای اسکلتون.
class _SkeletonPulse extends StatefulWidget {
  const _SkeletonPulse({required this.builder});

  final Widget Function(BuildContext context, Animation<double> t) builder;

  @override
  State<_SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<_SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _skPeriod,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
        context,
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
}

Color _pulseColor(Animation<double> t) =>
    Color.lerp(_skBase, _skPulse, t.value)!;

/// مستطیل اسکلتونی با گوشه‌ی گرد.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 6,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return _SkeletonPulse(
      builder: (BuildContext context, Animation<double> t) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: _pulseColor(t),
        ),
      ),
    );
  }
}

/// دایره‌ی اسکلتونی (دسته‌بندی‌ها).
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _SkeletonPulse(
      builder: (BuildContext context, Animation<double> t) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: _pulseColor(t)),
      ),
    );
  }
}

/// ردیف دایره‌های دسته‌بندی | چیدمانش باید یک‌به‌یک با
/// _CategoryCircles در native_mode.dart بخواند تا تعویض اسکلتون با
/// محتوا هیچ جابه‌جایی چیدمانی نداشته باشد.
class SkeletonCategoryCircles extends StatelessWidget {
  const SkeletonCategoryCircles({
    super.key,
    required this.circleSize,
    this.count = 5,
  });

  final double circleSize;
  final int count;

  @override
  Widget build(BuildContext context) {
    final double labelWidth = (circleSize * 0.5).clamp(40.0, 64.0);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _skBase)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: circleSize + 60,
        // لیست افقی مثل خود _CategoryCircles | ردیف ثابتِ Row با دایره‌های
        // درشت روی عرض موبایل سرریز می‌شود (خطای زرد RenderFlex).
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          separatorBuilder: (_, __) => const SizedBox(width: 4),
          itemBuilder: (BuildContext context, int index) => SizedBox(
            width: circleSize + 18,
            child: Column(
              children: <Widget>[
                SkeletonCircle(size: circleSize),
                const SizedBox(height: 6),
                SkeletonBox(width: labelWidth, height: 14, radius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// کارت اسکلتونی گرید محصول | نسبت و فاصله‌ها با _ProductGridCard یکی است.
class SkeletonProductCard extends StatelessWidget {
  const SkeletonProductCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _skBase),
      ),
      padding: const EdgeInsets.all(9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _SkeletonPulse(
              builder: (BuildContext context, Animation<double> t) =>
                  DecoratedBox(
                decoration: BoxDecoration(
                  color: _pulseColor(t),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const SkeletonBox(height: 13, radius: 4),
          const SizedBox(height: 6),
          const FractionallySizedBox(
            widthFactor: 0.62,
            alignment: AlignmentDirectional.centerStart,
            child: SkeletonBox(height: 13, radius: 4),
          ),
          const SizedBox(height: 9),
          const FractionallySizedBox(
            widthFactor: 0.5,
            alignment: AlignmentDirectional.centerStart,
            child: SkeletonBox(height: 14, radius: 4),
          ),
        ],
      ),
    );
  }
}

/// اسلایدر بنر اسکلتونی | هم‌چیدمان با بخش بنر واقعی در native_mode.dart:
/// نوار سفید چسبیده به جداکننده‌ی استوری‌ها + جعبه‌ی ~۹۲٪ عرض، ارتفاع ۱۸۰.
class SkeletonBannerSlider extends StatelessWidget {
  const SkeletonBannerSlider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SkeletonBox(height: 180, radius: 8),
      ),
    );
  }
}

/// گرید ۲ ستونه‌ی اسکلتونی (خانه و جستجو).
class SkeletonProductGrid extends StatelessWidget {
  const SkeletonProductGrid({super.key});

  @override
  Widget build(BuildContext context) {
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
        itemCount: 6,
        itemBuilder: (BuildContext context, int index) =>
            const SkeletonProductCard(),
      ),
    );
  }
}
