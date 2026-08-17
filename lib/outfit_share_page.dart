import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_theme.dart';
import 'models.dart';
import 'saved_look.dart';

class OutfitSharePage extends StatefulWidget {
  final SavedLook look;
  const OutfitSharePage({super.key, required this.look});

  @override
  State<OutfitSharePage> createState() => _OutfitSharePageState();
}

class _OutfitSharePageState extends State<OutfitSharePage> {
  final cardKey = GlobalKey();
  bool sharing = false;

  Future<void> _share() async {
    setState(() => sharing = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final boundary =
          cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = await getTemporaryDirectory();
      final safeName = widget.look.name.replaceAll(
        RegExp(r'[^\w\u4e00-\u9fa5]+'),
        '_',
      );
      final file = File('${directory.path}/衣搭_$safeName.png');
      await file.writeAsBytes(data!.buffer.asUint8List());
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          title: widget.look.name,
          text: '我的穿搭 · ${widget.look.name}',
          files: [XFile(file.path, mimeType: 'image/png')],
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('分享搭配卡')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: RepaintBoundary(
                  key: cardKey,
                  child: Container(
                    width: 330,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE0EAE3), Color(0xFFF4EFE7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '衣搭 · OUTFIT',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          widget.look.name,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 18),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          children: [
                            for (final item
                                in widget.look.outfit.pieces
                                    .whereType<ClothingItem>())
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F3EE),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  children: [
                                    Expanded(child: _ShareImage(item: item)),
                                    Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 17),
                        const Text(
                          '今天，也穿得像自己。',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: sharing ? null : _share,
                icon: sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share_rounded),
                label: Text(sharing ? '正在生成…' : '分享图片'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ShareImage extends StatelessWidget {
  final ClothingItem item;
  const _ShareImage({required this.item});

  @override
  Widget build(BuildContext context) => item.style.isLocalFile
      ? Image.file(
          File(item.assetPath),
          fit: BoxFit.contain,
          errorBuilder: _fallback,
        )
      : Image.asset(
          item.assetPath,
          fit: BoxFit.contain,
          errorBuilder: _fallback,
        );

  Widget _fallback(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) => const Icon(Icons.checkroom_rounded, color: AppTheme.inkSoft);
}
