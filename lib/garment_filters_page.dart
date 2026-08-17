import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'models.dart';

class GarmentFilterResult {
  final String? color;
  final String? material;
  final String? style;
  final bool onlyMine;

  const GarmentFilterResult({
    this.color,
    this.material,
    this.style,
    this.onlyMine = false,
  });
}

class GarmentFiltersPage extends StatefulWidget {
  final List<ColorOption> colors;
  final List<String> materials;
  final Map<String, List<String>> styleGroups;
  final String? initialColor;
  final String? initialMaterial;
  final String? initialStyle;
  final bool showOnlyMine;
  final bool initialOnlyMine;

  const GarmentFiltersPage({
    super.key,
    required this.colors,
    required this.materials,
    required this.styleGroups,
    this.initialColor,
    this.initialMaterial,
    this.initialStyle,
    this.showOnlyMine = false,
    this.initialOnlyMine = false,
  });

  @override
  State<GarmentFiltersPage> createState() => _GarmentFiltersPageState();
}

class _GarmentFiltersPageState extends State<GarmentFiltersPage> {
  String? color;
  String? material;
  String? style;
  late bool onlyMine;

  @override
  void initState() {
    super.initState();
    color = widget.initialColor;
    material = widget.initialMaterial;
    style = widget.initialStyle;
    onlyMine = widget.initialOnlyMine;
  }

  void _reset() {
    AppTheme.haptic();
    setState(() {
      color = null;
      material = null;
      style = null;
      onlyMine = false;
    });
  }

  void _apply() {
    AppTheme.haptic();
    Navigator.pop(
      context,
      GarmentFilterResult(
        color: color,
        material: material,
        style: style,
        onlyMine: onlyMine,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.bg,
    appBar: AppBar(
      backgroundColor: AppTheme.bg,
      surfaceTintColor: Colors.transparent,
      actions: [
        TextButton(onPressed: _reset, child: const Text('重置')),
        const SizedBox(width: 8),
      ],
    ),
    body: ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        const Text(
          '筛选单品',
          style: TextStyle(
            fontSize: 30,
            height: 1.08,
            letterSpacing: -.7,
            fontWeight: FontWeight.w900,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          '颜色、材质和款式均可选择一项',
          style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.inkSoft),
        ),
        const SizedBox(height: 22),
        if (widget.showOnlyMine) ...[
          _FilterSection(
            title: '单品来源',
            subtitle: '决定筛选结果包含哪些衣服',
            child: _SelectionTile(
              selected: onlyMine,
              icon: Icons.person_outline_rounded,
              title: '只看我的衣服',
              onTap: () => setState(() => onlyMine = !onlyMine),
            ),
          ),
          const SizedBox(height: 22),
        ],
        _FilterSection(
          title: '颜色',
          subtitle: '选择衣服的主要颜色',
          child: _OptionGrid(
            values: widget.colors.map((item) => item.name).toList(),
            selected: color,
            swatches: {for (final item in widget.colors) item.name: item.color},
            onSelected: (value) =>
                setState(() => color = color == value ? null : value),
          ),
        ),
        const SizedBox(height: 22),
        _FilterSection(
          title: '材质',
          subtitle: '按照面料触感和用途选择',
          child: _OptionGrid(
            values: widget.materials,
            selected: material,
            onSelected: (value) =>
                setState(() => material = material == value ? null : value),
          ),
        ),
        const SizedBox(height: 22),
        _FilterSection(
          title: '款式',
          subtitle: '先看分类，再选择具体款式',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final group in widget.styleGroups.entries) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F0EB),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.key,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _OptionGrid(
                        values: group.value,
                        selected: style,
                        compact: true,
                        onSelected: (value) => setState(
                          () => style = style == value ? null : value,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: FilledButton(
          onPressed: _apply,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: AppTheme.ink,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          child: const Text(
            '显示筛选结果',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    ),
  );
}

class SearchFilterButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const SearchFilterButton({
    super.key,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: count == 0 ? '打开筛选' : '打开筛选，已选择$count项',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: count == 0 ? Colors.white : AppTheme.ink,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: count == 0 ? AppTheme.divider : AppTheme.ink,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.tune_rounded,
              color: count == 0 ? AppTheme.ink : Colors.white,
              size: 21,
            ),
            if (count > 0)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Color(0xFFD6E8D9),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.accentDeep,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _FilterSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _FilterSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppTheme.divider),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            height: 1.1,
            fontWeight: FontWeight.w900,
            letterSpacing: -.35,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            height: 1.35,
            color: AppTheme.inkSoft,
          ),
        ),
        const SizedBox(height: 15),
        child,
      ],
    ),
  );
}

class _SelectionTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _SelectionTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(17),
    child: ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      leading: Icon(icon, color: AppTheme.accentDeep),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: AnimatedContainer(
        duration: AppTheme.fast,
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentDeep : const Color(0xFFF0EEEA),
          borderRadius: BorderRadius.circular(7),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : null,
      ),
    ),
  );
}

class _OptionGrid extends StatelessWidget {
  final List<String> values;
  final String? selected;
  final Map<String, Color> swatches;
  final ValueChanged<String> onSelected;
  final bool compact;
  const _OptionGrid({
    required this.values,
    required this.selected,
    required this.onSelected,
    this.swatches = const {},
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 8) / 2;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final value in values)
            SizedBox(
              width: width,
              child: _OptionTile(
                value: value,
                selected: selected == value,
                swatch: swatches[value],
                compact: compact,
                onTap: () => onSelected(value),
              ),
            ),
        ],
      );
    },
  );
}

class _OptionTile extends StatelessWidget {
  final String value;
  final bool selected;
  final Color? swatch;
  final bool compact;
  final VoidCallback onTap;
  const _OptionTile({
    required this.value,
    required this.selected,
    required this.onTap,
    required this.compact,
    this.swatch,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(13),
    child: AnimatedContainer(
      duration: AppTheme.fast,
      height: compact ? 40 : 44,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFDDE9E1) : const Color(0xFFF7F5F1),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: selected ? AppTheme.accentDeep : const Color(0xFFE9E6E0),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          if (swatch != null) ...[
            Container(
              width: 25,
              height: 17,
              decoration: BoxDecoration(
                color: swatch,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0x26000000)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: AppTheme.ink,
              ),
            ),
          ),
          if (selected)
            const Icon(
              Icons.check_rounded,
              size: 16,
              color: AppTheme.accentDeep,
            ),
        ],
      ),
    ),
  );
}
