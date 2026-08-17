import 'dart:io';
import 'package:flutter/material.dart';
import 'app_audio.dart';
import 'app_theme.dart';
import 'camera_capture_page.dart';
import 'garment_filters_page.dart';
import 'models.dart';
import 'wardrobe_store.dart';

class WardrobePage extends StatefulWidget {
  final VoidCallback? onChanged;
  const WardrobePage({super.key, this.onChanged});
  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  final searchController = TextEditingController();
  final List<UserGarment> userGarments = [];
  bool systemLibrary = false;
  String? colorFilter;
  GarmentMaterial? materialFilter;
  String? styleFilter;
  String query = '';

  @override
  void initState() {
    super.initState();
    _loadWardrobe();
  }

  Future<void> _loadWardrobe() async {
    final garments = await WardrobeStore.load();
    if (!mounted) return;
    setState(() => userGarments.addAll(garments));
  }

  Future<void> _saveWardrobe() async {
    await WardrobeStore.save(userGarments);
    widget.onChanged?.call();
  }

  Future<void> _capture([
    ClothingCategory initial = ClothingCategory.top,
  ]) async {
    final captured = await Navigator.push<CapturedGarment>(
      context,
      MaterialPageRoute(
        builder: (_) => GarmentCameraPage(initialCategory: initial),
      ),
    );
    if (!mounted || captured == null) return;
    final result = await showModalBottomSheet<UserGarment>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GarmentDetailsSheet(captured: captured),
    );
    if (result != null) {
      final baseName = '${result.color.name}${result.styleName}';
      final duplicateCount = userGarments.where((item) {
        final current = '${item.color.name}${item.styleName}'.replaceFirst(
          RegExp(r' \d+$'),
          '',
        );
        return current == baseName;
      }).length;
      final named = UserGarment(
        result.path,
        result.category,
        duplicateCount == 0
            ? result.styleName
            : '${result.styleName} $duplicateCount',
        result.color,
        result.material,
      );
      setState(() => userGarments.insert(0, named));
      await _saveWardrobe();
      AppAudio.playEffect('added');
    }
  }

  Future<void> _deleteUserGarment(UserGarment garment) async {
    final confirmed = await _confirmDelete(garment.styleName);
    if (!confirmed) return;
    setState(() => userGarments.remove(garment));
    final file = File(garment.path);
    if (await file.exists()) await file.delete();
    await _saveWardrobe();
    AppAudio.playEffect('deleted');
  }

  Future<bool> _confirmDelete(String name) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除衣服？'),
          content: Text('“$name”将从你的衣橱中移除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('删除'),
            ),
          ],
        ),
      ) ??
      false;

  IconData _categoryIcon(ClothingCategory category) => switch (category) {
    ClothingCategory.hat => Icons.face_retouching_natural_rounded,
    ClothingCategory.top => Icons.checkroom_rounded,
    ClothingCategory.bottom => Icons.dry_cleaning_rounded,
    ClothingCategory.shoes => Icons.ice_skating_rounded,
  };

  // Kept temporarily until the combined filter page has shipped broadly.
  // ignore: unused_element
  Future<void> _pickFilter(String kind) async {
    final styleGroups = <ClothingCategory, Map<String, List<String>>>{};
    for (final category in ClothingCategory.values) {
      final groups = <String, Set<String>>{};
      for (final style in clothingStyles.where(
        (item) => item.category == category,
      )) {
        final group = clothingSubcategory(category, style.name);
        groups.putIfAbsent(group, () => {}).add(style.name);
      }
      for (final garment in userGarments.where(
        (item) => item.category == category,
      )) {
        final name = garment.styleName.replaceFirst(RegExp(r' \d+$'), '');
        final group = clothingSubcategory(category, name);
        groups.putIfAbsent(group, () => {}).add(name);
      }
      styleGroups[category] = {
        for (final entry in groups.entries)
          entry.key: entry.value.toList()..sort(),
      };
    }
    final values = switch (kind) {
      '颜色' => colorOptions.map((item) => item.name).toSet().toList(),
      '材质' => GarmentMaterial.values.map((item) => item.label).toList(),
      _ => {
        ...clothingStyles.map((item) => item.name),
        ...userGarments.map(
          (item) => item.styleName.replaceFirst(RegExp(r' \d+$'), ''),
        ),
      }.toList()..sort(),
    };
    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.paddingOf(context).bottom + 18,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF5F3EF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .62,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '筛选$kind',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              if (kind == '款式') ...[
                ActionChip(
                  avatar: const Icon(Icons.apps_rounded, size: 17),
                  label: const Text('全部款式'),
                  onPressed: () => Navigator.pop(context, ''),
                ),
                const SizedBox(height: 16),
                for (final category in ClothingCategory.values) ...[
                  Row(
                    children: [
                      Icon(
                        _categoryIcon(category),
                        size: 17,
                        color: AppTheme.inkSoft,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        category.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${styleGroups[category]!.values.fold<int>(0, (sum, list) => sum + list.length)} 种',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.inkSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final group in styleGroups[category]!.entries) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9E6E0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        group.key,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.inkSoft,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final value in group.value)
                          ChoiceChip(
                            label: Text(value),
                            selected: styleFilter == value,
                            onSelected: (_) => Navigator.pop(context, value),
                          ),
                      ],
                    ),
                    const SizedBox(height: 11),
                  ],
                  const SizedBox(height: 18),
                ],
              ] else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('全部'),
                      onPressed: () => Navigator.pop(context, ''),
                    ),
                    for (final value in values)
                      ActionChip(
                        avatar: kind == '颜色'
                            ? Container(
                                decoration: BoxDecoration(
                                  color: colorOptions
                                      .firstWhere((item) => item.name == value)
                                      .color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0x22000000),
                                  ),
                                ),
                              )
                            : null,
                        label: Text(value),
                        onPressed: () => Navigator.pop(context, value),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    setState(() {
      if (kind == '颜色') {
        colorFilter = selected.isEmpty ? null : selected;
      } else if (kind == '材质') {
        materialFilter = selected.isEmpty
            ? null
            : GarmentMaterial.values.firstWhere(
                (item) => item.label == selected,
              );
      } else {
        styleFilter = selected.isEmpty ? null : selected;
      }
    });
  }

  int get activeFilterCount => [
    colorFilter,
    materialFilter,
    styleFilter,
  ].where((value) => value != null).length;

  Future<void> _openFilters() async {
    final groupedStyles = <String, Set<String>>{};
    for (final category in ClothingCategory.values) {
      for (final name in GarmentTaxonomy.styleNamesFor(category)) {
        final subgroup = clothingSubcategory(category, name);
        groupedStyles
            .putIfAbsent('${category.label}  $subgroup', () => {})
            .add(name);
      }
    }
    final result = await Navigator.push<GarmentFilterResult>(
      context,
      MaterialPageRoute(
        builder: (_) => GarmentFiltersPage(
          colors: colorOptions,
          materials: GarmentMaterial.values.map((item) => item.label).toList(),
          styleGroups: {
            for (final entry in groupedStyles.entries)
              entry.key: entry.value.toList()..sort(),
          },
          initialColor: colorFilter,
          initialMaterial: materialFilter?.label,
          initialStyle: styleFilter,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      colorFilter = result.color;
      materialFilter = result.material == null
          ? null
          : GarmentMaterial.values.firstWhere(
              (item) => item.label == result.material,
            );
      styleFilter = result.style;
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '我的衣橱',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                      letterSpacing: -.6,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _capture,
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: const Text('拍衣服'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.ink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE9E6E0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  for (final entry in const ['我的衣服', '全部'].indexed)
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => systemLibrary = entry.$1 == 1),
                        child: AnimatedContainer(
                          duration: AppTheme.fast,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: systemLibrary == (entry.$1 == 1)
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: systemLibrary == (entry.$1 == 1)
                                ? const [
                                    BoxShadow(
                                      color: Color(0x10000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            entry.$2,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: (value) => setState(() => query = value.trim()),
                    decoration: InputDecoration(
                      hintText: '搜索衣服',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppTheme.inkSoft,
                      ),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.cancel_rounded, size: 18),
                              onPressed: () {
                                searchController.clear();
                                setState(() => query = '');
                              },
                            ),
                      filled: true,
                      fillColor: const Color(0xFFE9E6E0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                SearchFilterButton(
                  count: activeFilterCount,
                  onTap: _openFilters,
                ),
              ],
            ),
          ),
        ),
        for (final category in ClothingCategory.values)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            sliver: SliverToBoxAdapter(
              child: _CategoryBoard(
                category: category,
                query: query,
                userGarments: userGarments
                    .where(
                      (item) =>
                          item.category == category &&
                          (colorFilter == null ||
                              item.color.name == colorFilter) &&
                          (materialFilter == null ||
                              item.material == materialFilter) &&
                          (styleFilter == null ||
                              item.styleName.replaceFirst(
                                    RegExp(r' \d+$'),
                                    '',
                                  ) ==
                                  styleFilter),
                    )
                    .toList(),
                showSystem: systemLibrary,
                colorFilter: colorFilter,
                materialFilter: materialFilter,
                styleFilter: styleFilter,
                onCamera: () => _capture(category),
                onDeleteUser: _deleteUserGarment,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 30)),
      ],
    ),
  );
}

class _CategoryBoard extends StatelessWidget {
  final ClothingCategory category;
  final String query;
  final List<UserGarment> userGarments;
  final bool showSystem;
  final String? colorFilter;
  final GarmentMaterial? materialFilter;
  final String? styleFilter;
  final VoidCallback onCamera;
  final ValueChanged<UserGarment> onDeleteUser;
  const _CategoryBoard({
    required this.category,
    required this.query,
    required this.userGarments,
    required this.showSystem,
    required this.colorFilter,
    required this.materialFilter,
    required this.styleFilter,
    required this.onCamera,
    required this.onDeleteUser,
  });

  IconData get icon => switch (category) {
    ClothingCategory.hat => Icons.face_retouching_natural_rounded,
    ClothingCategory.top => Icons.checkroom_rounded,
    ClothingCategory.bottom => Icons.dry_cleaning_rounded,
    ClothingCategory.shoes => Icons.ice_skating_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final styles = clothingStyles
        .where(
          (style) =>
              style.category == category &&
              showSystem &&
              (colorFilter == null || style.baseColor.name == colorFilter) &&
              (materialFilter == null || style.material == materialFilter) &&
              (styleFilter == null || style.name == styleFilter) &&
              (query.isEmpty ||
                  '${style.baseColor.name}${style.name}${style.material.label}'
                      .toLowerCase()
                      .contains(query.toLowerCase())),
        )
        .toList();
    final own = userGarments
        .where(
          (item) =>
              query.isEmpty ||
              '${item.color.name}${item.styleName}${item.material.label}'
                  .contains(query),
        )
        .toList();
    if (query.isNotEmpty && styles.isEmpty && own.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      height: 146,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 25, color: AppTheme.ink),
                const SizedBox(height: 7),
                Text(
                  category.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${styles.length + own.length} 件',
                  style: const TextStyle(fontSize: 10, color: AppTheme.inkSoft),
                ),
              ],
            ),
          ),
          Container(
            width: .5,
            margin: const EdgeInsets.symmetric(vertical: 16),
            color: AppTheme.divider,
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              children: [
                for (final item in own)
                  _GarmentTile(
                    name: '${item.color.name}${item.styleName}',
                    subtitle: item.material.label,
                    filePath: item.path,
                    onDelete: () => onDeleteUser(item),
                  ),
                for (final style in styles)
                  _GarmentTile(
                    name: '${style.baseColor.name}${style.name}',
                    subtitle: style.material.label,
                    assetPath: style.assetPath,
                    fit: style.category == ClothingCategory.shoes
                        ? BoxFit.contain
                        : BoxFit.cover,
                  ),
                if (!showSystem) _AddTile(onTap: onCamera),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GarmentTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final String? assetPath;
  final String? filePath;
  final VoidCallback? onDelete;
  final BoxFit fit;
  const _GarmentTile({
    required this.name,
    required this.subtitle,
    this.assetPath,
    this.filePath,
    this.onDelete,
    this.fit = BoxFit.cover,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: 94,
    margin: const EdgeInsets.only(right: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: filePath != null
                      ? Image.file(
                          File(filePath!),
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Image.asset(
                          assetPath!,
                          width: double.infinity,
                          fit: fit,
                        ),
                ),
              ),
              if (onDelete != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: const BoxDecoration(
                        color: Color(0xCCFFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_horiz_rounded,
                        size: 17,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
        ),
        Text(
          subtitle,
          maxLines: 1,
          style: const TextStyle(fontSize: 9, color: AppTheme.inkSoft),
        ),
      ],
    ),
  );
}

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTile({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 72,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3EF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_rounded, size: 23, color: AppTheme.accentDeep),
          SizedBox(height: 6),
          Text(
            '添加',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.accentDeep,
            ),
          ),
        ],
      ),
    ),
  );
}

// ignore: unused_element
class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color? color;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    // ignore: unused_element_parameter
    this.color,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppTheme.ink : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: active ? AppTheme.ink : AppTheme.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (color != null) ...[
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x33000000)),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppTheme.ink,
            ),
          ),
        ],
      ),
    ),
  );
}

class _GarmentDetailsSheet extends StatefulWidget {
  final CapturedGarment captured;
  const _GarmentDetailsSheet({required this.captured});
  @override
  State<_GarmentDetailsSheet> createState() => _GarmentDetailsSheetState();
}

class _GarmentDetailsSheetState extends State<_GarmentDetailsSheet> {
  late ClothingCategory category = widget.captured.category;
  late ColorOption color = colorOptions.first;
  GarmentMaterial material = GarmentMaterial.cotton;
  late String style = GarmentTaxonomy.styleNamesFor(category).first;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      MediaQuery.paddingOf(context).bottom + 18,
    ),
    decoration: const BoxDecoration(
      color: Color(0xFFF5F3EF),
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFD1CFCB),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '这是什么衣服？',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(
                File(widget.captured.path),
                width: 112,
                height: 142,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '类别',
                    style: TextStyle(fontSize: 12, color: AppTheme.inkSoft),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ClothingCategory.values
                        .map(
                          (item) => ChoiceChip(
                            label: Text(item.label),
                            selected: item == category,
                            onSelected: (_) => setState(() {
                              category = item;
                              style = GarmentTaxonomy.styleNamesFor(item).first;
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          '款式',
          style: TextStyle(fontSize: 12, color: AppTheme.inkSoft),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: ValueKey(category),
          initialValue: style,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          items: GarmentTaxonomy.styleNamesFor(category)
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => style = value);
          },
        ),
        const SizedBox(height: 14),
        const Text(
          '颜色',
          style: TextStyle(fontSize: 12, color: AppTheme.inkSoft),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: colorOptions
                .map(
                  (item) => GestureDetector(
                    onTap: () => setState(() => color = item),
                    child: Container(
                      width: 36,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: item == color ? AppTheme.ink : Colors.white,
                          width: item == color ? 3 : 2,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '材质',
          style: TextStyle(fontSize: 12, color: AppTheme.inkSoft),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: GarmentMaterial.values
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(item.label),
                      selected: item == material,
                      onSelected: (_) => setState(() => material = item),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(
              context,
              UserGarment(
                widget.captured.path,
                category,
                style,
                color,
                material,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.ink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              '加入衣橱',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    ),
  );
}
