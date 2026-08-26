import 'package:flutter/material.dart';

import 'package:unicore_mobile_app/theme/app_theme.dart';

/// The UNiCORE logo mark + wordmark. [compact] shrinks it for app bars.
class HeaderBrand extends StatelessWidget {
  const HeaderBrand({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: compact ? 40 : 46,
          height: compact ? 40 : 46,
          decoration: BoxDecoration(
            color: AppColors.blue,
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(colors: [Color(0xff2456e8), Color(0xff7ca9ff)]),
          ),
          child: const Center(
            child: Text('U', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UNiCORE',
              style: TextStyle(
                color: AppColors.deepBlue,
                fontWeight: FontWeight.w900,
                fontSize: compact ? 22 : 28,
                letterSpacing: 0,
              ),
            ),
            Text(
              compact ? 'Mobile' : 'Мэргэжлийн бизнесийн шийдэл',
              style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}

/// The marketing hero card shown on the login screen.
class HeroPreview extends StatelessWidget {
  const HeroPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 188,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        boxShadow: softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: DashboardMockPainter()),
          ),
          const Positioned(
            left: 18,
            top: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UNiCORE', style: TextStyle(color: AppColors.deepBlue, fontSize: 30, fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text('Бизнесийн өдөр тутмын үйл ажиллагаа', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                SizedBox(height: 22),
                Text('Хөгжүүлэгч', style: TextStyle(color: AppColors.muted)),
                Text('EhIel Group', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the decorative mock dashboard behind [HeroPreview].
class DashboardMockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = AppColors.line;
    final blue = Paint()..color = AppColors.blue;
    final green = Paint()..color = const Color(0xff72d38d);
    final red = Paint()..color = const Color(0xfff06c6c);
    final orange = Paint()..color = const Color(0xffffbd5c);

    canvas.drawCircle(Offset(size.width * .72, size.height * .28), 72, Paint()..color = AppColors.softBlue);
    final panel = RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .46, 62, size.width * .48, 94), const Radius.circular(8));
    canvas.drawRRect(panel, Paint()..color = Colors.white);
    canvas.drawRRect(panel, line..style = PaintingStyle.stroke);
    line.style = PaintingStyle.fill;

    for (var i = 0; i < 4; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .49 + i * 42, 78, 34, 22), const Radius.circular(5)),
        Paint()..color = const Color(0xfff3f6fb),
      );
    }

    final bars = [44.0, 78.0, 55.0, 90.0, 66.0, 104.0];
    final paints = [blue, green, orange, blue, red, green];
    for (var i = 0; i < bars.length; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .52 + i * 22, 148 - bars[i] * .45, 10, bars[i] * .45), const Radius.circular(4)),
        paints[i],
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
