import 'dart:io';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'garment_filters_page.dart';
import 'models.dart';
import 'wardrobe_store.dart';

class GarmentPickerResult {
  final ClothingStyle? style;
  const GarmentPickerResult.withStyle(ClothingStyle value) : style = value;
  const GarmentPickerResult.none() : style = null;
}

class GarmentPickerPage extends StatefulWidget {
  final ClothingCategory category;
  final String? selectedStyleId;
  const GarmentPickerPage({
    super.key,
    required this.category,
    required this.selectedStyleId,
  });

  @override
  State<GarmentPickerPage> createState() => _GarmentPickerPageState();
}

class _GarmentPickerPageState extends State<GarmentPickerPage> {
  final searchController = TextEditingController();
  String query = '';
  String? colorFilter;
  GarmentMaterial? materialFilter;
  String? styleFilter;
  bool onlyMine = false;
  final List<ClothingStyle> userStyles = [];

  @override
  void initState() {
    super.initState();
    _loadUserStyles();
  }

  Future<void> _loadUserStyles() async {
    final garments = await WardrobeStore.load();
    if (!mounted) return;
    setState(() {
      userStyles
        ..clear()
        ..addAll(garments.map((item) => item.style));
    });
  }

  List<ClothingStyle> get categoryStyles => [
    ...userStyles.where((item) => item.category == widget.category),
    ...clothingStyles.where((item) => item.category == widget.category),
  ];

  List<ClothingStyle> get visibleStyles {
    final normalized = query.toLowerCase();
    return categoryStyles
        .where(
          (item) =>
              (!onlyMine || item.isLocalFile) &&
              (colorFilter == null || item.baseColor.name == colorFilter) &&
              (materialFilter == null || item.material == materialFilter) &&
              (styleFilter == null || item.name == styleFilter) &&
              (normalized.isEmpty ||
                  '${item.baseColor.name}${item.name}${item.material.label}'
                      .toLowerCase()
                      .contains(normalized)),
        )
        .toList(growable: false);
  }

  // Kept temporarily until the combined filter page has shipped broadly.
  // ignore: unused_element
  Future<void> _pickFilter(String kind) async {
    final styleGroups = <String, List<String>>{};
    for (final style in categoryStyles) {
      final group = clothingSubcategory(widget.category, style.name);
      final names = styleGroups.putIfAbsent(group, () => []);
      if (!names.contains(style.name)) names.add(style.name);
    }
    for (final names in styleGroups.values) {
      names.sort();
    }
    final values = switch (kind) {
      '颜色' => categoryStyles.map((item) => item.baseColor.name).toSet(),
      '材质' => categoryStyles.map((item) => item.material.label).toSet(),
      _ => categoryStyles.map((item) => item.name).toSet(),
    };
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .65,
        ),
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '选择$kind',
                style: const TextStyle(
                  fontSize: 21,
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
                const SizedBox(height: 14),
                for (final group in styleGroups.entries) ...[
                  Text(
                    group.key,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 7),
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
                  const SizedBox(height: 15),
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
                            ? _ColorDot(
                                color: colorOptions
                                    .firstWhere((item) => item.name == value)
                                    .color,
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
    if (selected == null || !mounted) return;
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

  int get activeFilterCount =>
      [
        colorFilter,
        materialFilter,
        styleFilter,
      ].where((value) => value != null).length +
      (onlyMine ? 1 : 0);

  Future<void> _openFilters() async {
    final groups = <String, Set<String>>{};
    for (final name in GarmentTaxonomy.styleNamesFor(widget.category)) {
      final group = clothingSubcategory(widget.category, name);
      groups.putIfAbsent(group, () => {}).add(name);
    }
    final result = await Navigator.push<GarmentFilterResult>(
      context,
      MaterialPageRoute(
        builder: (_) => GarmentFiltersPage(
          colors: colorOptions,
          materials: GarmentMaterial.values.map((item) => item.label).toList(),
          styleGroups: {
            for (final entry in groups.entries)
              entry.key: entry.value.toList()..sort(),
          },
          initialColor: colorFilter,
          initialMaterial: materialFilter?.label,
          initialStyle: styleFilter,
          showOnlyMine: true,
          initialOnlyMine: onlyMine,
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
      onlyMine = result.onlyMine;
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final styles = visibleStyles;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F3EF),
        surfaceTintColor: Colors.transparent,
        title: Text(
          '选择${widget.category.label}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      onChanged: (value) =>
                          setState(() => query = value.trim()),
                      decoration: InputDecoration(
                        hintText: '搜索${widget.category.label}',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  searchController.clear();
                                  setState(() => query = '');
                                },
                                icon: const Icon(
                                  Icons.cancel_rounded,
                                  size: 19,
                                ),
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '单品样例',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '我的 ${styles.where((item) => item.isLocalFile).length} · 共 ${styles.length} 件',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: styles.isEmpty
                  ? const Center(
                      child: Text(
                        '没有符合条件的衣服',
                        style: TextStyle(color: AppTheme.inkSoft),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: .78,
                          ),
                      itemCount: styles.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _NoneGarmentCard(
                            category: widget.category,
                            selected: widget.selectedStyleId == null,
                            onTap: () => Navigator.pop(
                              context,
                              const GarmentPickerResult.none(),
                            ),
                          );
                        }
                        final style = styles[index - 1];
                        final selected = style.id == widget.selectedStyleId;
                        return _GarmentSampleCard(
                          style: style,
                          selected: selected,
                          onTap: () => Navigator.pop(
                            context,
                            GarmentPickerResult.withStyle(style),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoneGarmentCard extends StatelessWidget {
  final ClothingCategory category;
  final bool selected;
  final VoidCallback onTap;
  const _NoneGarmentCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: AppTheme.fast,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE1E9E2) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? AppTheme.accentDeep : AppTheme.divider,
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: selected ? Colors.white : const Color(0xFFF2F0EB),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.remove_rounded,
              size: 28,
              color: AppTheme.inkSoft,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            '无${category.label}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            '这个部位留空',
            style: TextStyle(fontSize: 11, color: AppTheme.inkSoft),
          ),
          if (selected) ...[
            const SizedBox(height: 12),
            const Icon(
              Icons.check_circle_rounded,
              size: 22,
              color: AppTheme.accentDeep,
            ),
          ],
        ],
      ),
    ),
  );
}

class _GarmentSampleCard extends StatelessWidget {
  final ClothingStyle style;
  final bool selected;
  final VoidCallback onTap;
  const _GarmentSampleCard({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: AppTheme.fast,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? AppTheme.ink : AppTheme.divider,
          width: selected ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(21),
                    ),
                    child: style.isLocalFile
                        ? Image.file(File(style.assetPath), fit: BoxFit.cover)
                        : Image.asset(
                            style.assetPath,
                            fit: style.category == ClothingCategory.shoes
                                ? BoxFit.contain
                                : BoxFit.cover,
                          ),
                  ),
                ),
                if (selected)
                  const Positioned(
                    top: 9,
                    right: 9,
                    child: CircleAvatar(
                      radius: 13,
                      backgroundColor: AppTheme.ink,
                      child: Icon(Icons.check_rounded, size: 16),
                    ),
                  ),
                if (style.isLocalFile)
                  Positioned(
                    top: 9,
                    left: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xDDFFFFFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '我的',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
            child: Row(
              children: [
                _ColorDot(color: style.baseColor.color),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '${style.baseColor.name}${style.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(33, 0, 12, 11),
            child: Text(
              style.material.label,
              style: const TextStyle(fontSize: 10, color: AppTheme.inkSoft),
            ),
          ),
        ],
      ),
    ),
  );
}

// ignore: unused_element
class _PickerFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color? color;
  final VoidCallback onTap;
  const _PickerFilterChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: active ? AppTheme.ink : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: active ? AppTheme.ink : AppTheme.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (color != null) ...[
            _ColorDot(color: color!),
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
          const SizedBox(width: 2),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 15,
            color: active ? Colors.white : AppTheme.inkSoft,
          ),
        ],
      ),
    ),
  );
}

// ignore: unused_element
class _MineFilterChip extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _MineFilterChip({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: AppTheme.fast,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
      decoration: BoxDecoration(
        color: selected ? AppTheme.ink : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: selected ? AppTheme.ink : AppTheme.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: AppTheme.fast,
            width: 21,
            height: 21,
            decoration: BoxDecoration(
              color: selected ? Colors.white : const Color(0xFFF1EFEB),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.white : const Color(0xFFD2D0CB),
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 15, color: AppTheme.ink)
                : null,
          ),
          const SizedBox(width: 7),
          Text(
            '只看我的',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppTheme.ink,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ColorDot extends StatelessWidget {
  final Color color;
  const _ColorDot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 15,
    height: 15,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0x33000000)),
    ),
  );
}
