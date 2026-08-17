import 'dart:io';

import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'models.dart';

class OutfitBoard extends StatelessWidget {
  final Outfit outfit;
  const OutfitBoard({super.key, required this.outfit});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
    child: Column(
      children: [
        for (final entry in ClothingCategory.values.indexed)
          Expanded(
            child: _AnnotatedPiece(
              key: ValueKey(
                '${entry.$2.name}_${outfit.pieceFor(entry.$2)?.id ?? 'none'}',
              ),
              category: entry.$2,
              item: outfit.pieceFor(entry.$2),
              index: entry.$1,
            ),
          ),
      ],
    ),
  );
}

class _AnnotatedPiece extends StatelessWidget {
  final ClothingCategory category;
  final ClothingItem? item;
  final int index;
  const _AnnotatedPiece({
    super.key,
    required this.category,
    required this.item,
    required this.index,
  });
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppTheme.reduceMotion(context)
        ? Duration.zero
        : Duration(milliseconds: 180 + index * 35),
    curve: AppTheme.spring,
    builder: (_, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(-10 * (1 - value), 0),
        child: child,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3EF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 9,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: item == null
                ? const Icon(
                    Icons.remove_rounded,
                    size: 26,
                    color: AppTheme.inkSoft,
                  )
                : _ProductImage(item: item!),
          ),
        ),
        const SizedBox(width: 4),
        const SizedBox(
          width: 40,
          height: 32,
          child: CustomPaint(painter: _LeaderLinePainter()),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item?.name ?? '${category.label}  无',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1,
                color: item == null ? AppTheme.inkSoft : Color(0xFF1C1B19),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProductImage extends StatelessWidget {
  final ClothingItem item;
  const _ProductImage({required this.item});
  @override
  Widget build(BuildContext context) {
    return item.style.isLocalFile
        ? Image.file(
            File(item.assetPath),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
          )
        : Image.asset(
            item.assetPath,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
          );
  }
}

class _LeaderLinePainter extends CustomPainter {
  const _LeaderLinePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF171717)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height * .5)
      ..lineTo(size.width * .38, size.height * .5)
      ..lineTo(size.width * .58, size.height * .25)
      ..lineTo(size.width, size.height * .25);
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(size.width, size.height * .25),
      2.1,
      Paint()..color = const Color(0xFF171717),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
