import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'models.dart';

enum ModelType { female, male }

class TryOnStage extends StatelessWidget {
  final Outfit outfit;
  final ModelType modelType;
  const TryOnStage({
    super.key,
    required this.outfit,
    this.modelType = ModelType.female,
  });
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        Image.asset(
          modelType == ModelType.female
              ? 'assets/mannequin_friendly_v2.png'
              : 'assets/mannequin_male_v2.png',
          fit: BoxFit.contain,
          alignment: Alignment.center,
        ),
        for (final category in ClothingCategory.values)
          AnimatedSwitcher(
            duration: AppTheme.reduceMotion(context)
                ? Duration.zero
                : AppTheme.mid,
            switchInCurve: AppTheme.spring,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, -.025),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: SizedBox.expand(
              key: ValueKey(
                '${modelType.name}_${outfit.pieceFor(category)?.id}',
              ),
              child: CustomPaint(
                painter: _GarmentPainter(
                  outfit.pieceFor(category),
                  modelType: modelType,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _GarmentPainter extends CustomPainter {
  final ClothingItem? item;
  final ModelType modelType;
  _GarmentPainter(this.item, {this.modelType = ModelType.female});
  @override
  void paint(Canvas canvas, Size size) {
    final item = this.item;
    if (item == null) return;
    final scale = math.min(size.width / 100, size.height / 160);
    final dx = (size.width - 100 * scale) / 2;
    final dy = (size.height - 160 * scale) / 2;
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);
    if (modelType == ModelType.male) {
      canvas.translate(-1.5, 0);
      canvas.scale(1.03, 1);
    }
    final base = Paint()..color = item.color;
    final shade = Paint()..color = Color.lerp(item.color, Colors.black, .24)!;
    final light = Paint()..color = Color.lerp(item.color, Colors.white, .30)!;
    switch (item.category) {
      case ClothingCategory.hat:
        final knit = item.style.id == 'beanie';
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(knit ? 38 : 34, 4, knit ? 24 : 33, knit ? 11 : 8),
            const Radius.circular(7),
          ),
          base,
        );
        if (!knit) canvas.drawOval(const Rect.fromLTWH(33, 10, 37, 4.5), shade);
      case ClothingCategory.top:
        final p = Path()
          ..moveTo(40, 38)
          ..lineTo(29, 45)
          ..lineTo(33, 72)
          ..lineTo(40, 73)
          ..lineTo(40, 84)
          ..lineTo(61, 84)
          ..lineTo(61, 73)
          ..lineTo(68, 72)
          ..lineTo(72, 45)
          ..lineTo(61, 38)
          ..quadraticBezierTo(50, 45, 40, 38)
          ..close();
        canvas.drawPath(p, base);
        canvas.drawPath(
          Path()
            ..moveTo(40, 39)
            ..quadraticBezierTo(50, 48, 61, 39),
          shade
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1,
        );
        canvas.drawLine(
          const Offset(43, 48),
          const Offset(42, 80),
          light
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8,
        );
        if (item.style.id == 'hoodie') {
          canvas.drawArc(
            const Rect.fromLTWH(39, 34, 23, 17),
            math.pi,
            math.pi,
            false,
            shade
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.6,
          );
        }
        if (item.style.id == 'jacket') {
          canvas.drawLine(
            const Offset(50.5, 45),
            const Offset(50.5, 83),
            shade
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
      case ClothingCategory.bottom:
        if (item.style.id == 'skirt') {
          final p = Path()
            ..moveTo(38, 81)
            ..lineTo(63, 81)
            ..lineTo(68, 104)
            ..lineTo(33, 104)
            ..close();
          canvas.drawPath(p, base);
          for (var x = 38.0; x < 65; x += 6) {
            canvas.drawLine(
              Offset(x, 84),
              Offset(x - 2, 102),
              shade
                ..style = PaintingStyle.stroke
                ..strokeWidth = .65,
            );
          }
        } else {
          final wide = item.style.id == 'jeans' ? 4.0 : 0.0;
          final p = Path()
            ..moveTo(37, 81)
            ..lineTo(64, 81)
            ..lineTo(68 + wide, 137)
            ..lineTo(54, 137)
            ..lineTo(50.5, 95)
            ..lineTo(47, 137)
            ..lineTo(33 - wide, 137)
            ..close();
          canvas.drawPath(p, base);
          canvas.drawLine(
            const Offset(50.5, 84),
            const Offset(50.5, 97),
            shade
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
      case ClothingCategory.shoes:
        for (final x in [30.5, 51.5]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 140, 20, 11),
              const Radius.circular(4),
            ),
            base,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x - 1, 148, 22, 3),
              const Radius.circular(1.5),
            ),
            light,
          );
          canvas.drawLine(
            Offset(x + 7, 143),
            Offset(x + 15, 143),
            shade
              ..style = PaintingStyle.stroke
              ..strokeWidth = .8,
          );
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GarmentPainter old) => old.item?.id != item?.id;
}
