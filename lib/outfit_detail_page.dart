import 'dart:io';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'models.dart';

class OutfitDetailPage extends StatelessWidget {
  final Outfit outfit;
  const OutfitDetailPage({super.key, required this.outfit});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('搭配详情')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE0EAE3), Color(0xFFF4EFE7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              outfit.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              outfit.vibe,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: .82,
                  children: [
                    for (final item in outfit.pieces.whereType<ClothingItem>())
                      _DetailPiece(item: item),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: () {
                  AppTheme.haptic();
                  Navigator.pop(context, true);
                },
                icon: const Icon(Icons.checkroom_rounded),
                label: const Text('进入试衣间试试'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DetailPiece extends StatelessWidget {
  final ClothingItem item;
  const _DetailPiece({required this.item});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: ColoredBox(
              color: const Color(0xFFF2F0EB),
              child: SizedBox.expand(child: _image()),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          '${item.category.label} · ${item.style.material.label}',
          style: const TextStyle(fontSize: 10.5, color: AppTheme.inkSoft),
        ),
      ],
    ),
  );

  Widget _image() => item.style.isLocalFile
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
  ) => const Icon(Icons.image_not_supported_outlined, color: AppTheme.inkSoft);
}
