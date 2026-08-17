from pathlib import Path


path = Path(__file__).resolve().parents[1] / "lib" / "home_page.dart"
text = path.read_text(encoding="utf-8")
marker = "class _TryOnView extends StatelessWidget {"
head = text[: text.index(marker)]
replacement = r'''class _TryOnView extends StatelessWidget {
  final Outfit outfit;
  final ValueChanged<Outfit> onOutfit;
  const _TryOnView({
    super.key,
    required this.outfit,
    required this.onOutfit,
  });

  Future<void> _openPicker(
    BuildContext context,
    ClothingCategory category,
  ) async {
    final current = outfit.pieceFor(category)!;
    final style = await Navigator.push<ClothingStyle>(
      context,
      MaterialPageRoute(
        builder: (_) => GarmentPickerPage(
          category: category,
          selectedStyleId: current.style.id,
        ),
      ),
    );
    if (style == null) return;
    onOutfit(
      outfit.withPiece(
        ClothingItem(id: style.id, style: style, tone: style.baseColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '试衣间',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '点击下方部位更换单品',
                    style: TextStyle(fontSize: 11, color: AppTheme.inkSoft),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE1E9E2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${clothingStyles.length} 件单品',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentDeep,
                ),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE0EAE3), Color(0xFFF4EFE7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white),
            boxShadow: const [
              BoxShadow(
                color: Color(0x11000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: OutfitBoard(outfit: outfit),
        ),
      ),
      Container(
        margin: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.divider),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 7,
          crossAxisSpacing: 7,
          childAspectRatio: 2.75,
          children: [
            for (final category in ClothingCategory.values)
              _PartPickerTile(
                category: category,
                item: outfit.pieceFor(category)!,
                onTap: () => _openPicker(context, category),
              ),
          ],
        ),
      ),
    ],
  );
}

class _PartPickerTile extends StatelessWidget {
  final ClothingCategory category;
  final ClothingItem item;
  final VoidCallback onTap;
  const _PartPickerTile({
    required this.category,
    required this.item,
    required this.onTap,
  });

  IconData get icon => switch (category) {
    ClothingCategory.hat => Icons.face_retouching_natural_rounded,
    ClothingCategory.top => Icons.checkroom_rounded,
    ClothingCategory.bottom => Icons.dry_cleaning_rounded,
    ClothingCategory.shoes => Icons.ice_skating_rounded,
  };

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      AppTheme.haptic();
      onTap();
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3EF),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppTheme.ink),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.inkSoft,
                  ),
                ),
                Text(
                  '${item.colorName}${item.style.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 17,
            color: AppTheme.inkSoft,
          ),
        ],
      ),
    ),
  );
}
'''
path.write_text(head + replacement, encoding="utf-8")
print("rewrote try-on view")
