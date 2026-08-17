import 'dart:io';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'models.dart';
import 'saved_look.dart';

class OutfitCalendarPage extends StatefulWidget {
  final VoidCallback? onScheduleChanged;
  const OutfitCalendarPage({super.key, this.onScheduleChanged});

  @override
  State<OutfitCalendarPage> createState() => _OutfitCalendarPageState();
}

class _OutfitCalendarPageState extends State<OutfitCalendarPage> {
  DateTime selected = DateTime.now();
  List<SavedLook> looks = [];
  Map<String, String> schedule = {};
  Map<String, SavedLook> directSchedule = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait([
      SavedLookStore.loadLooks(),
      SavedLookStore.loadSchedule(),
      SavedLookStore.loadDirectSchedule(),
    ]);
    if (!mounted) return;
    setState(() {
      looks = values[0] as List<SavedLook>;
      schedule = values[1] as Map<String, String>;
      directSchedule = values[2] as Map<String, SavedLook>;
      loading = false;
    });
  }

  SavedLook? get selectedLook {
    final key = SavedLookStore.dateKey(selected);
    final directLook = directSchedule[key];
    if (directLook != null) return directLook;
    final name = schedule[key];
    if (name == null) return null;
    for (final look in looks) {
      if (look.name == name) return look;
    }
    return null;
  }

  Future<void> _chooseLook() async {
    await _load();
    if (!mounted) return;
    final look = await showModalBottomSheet<SavedLook>(
      context: context,
      backgroundColor: AppTheme.bg,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .58,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '选择一套搭配',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              Expanded(
                child: looks.isEmpty
                    ? const Center(
                        child: Text(
                          '先去试衣间保存一套搭配',
                          style: TextStyle(color: AppTheme.inkSoft),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: looks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final value = looks[index];
                          return ListTile(
                            tileColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            leading: _MiniImage(
                              item: value.outfit.pieces
                                  .whereType<ClothingItem>()
                                  .first,
                            ),
                            title: Text(
                              value.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              value.outfit.pieces
                                  .whereType<ClothingItem>()
                                  .map((e) => e.colorName)
                                  .toSet()
                                  .join(' · '),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.pop(context, value),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || look == null) return;
    final key = SavedLookStore.dateKey(selected);
    setState(() {
      schedule[key] = look.name;
      directSchedule.remove(key);
    });
    await SavedLookStore.saveSchedule(schedule);
    await SavedLookStore.saveDirectSchedule(directSchedule);
    widget.onScheduleChanged?.call();
  }

  Future<void> _remove() async {
    final key = SavedLookStore.dateKey(selected);
    setState(() {
      schedule.remove(key);
      directSchedule.remove(key);
    });
    await SavedLookStore.saveSchedule(schedule);
    await SavedLookStore.saveDirectSchedule(directSchedule);
    widget.onScheduleChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final look = selectedLook;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            const Text(
              '穿搭日历',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text('提前安排每天穿什么', style: TextStyle(color: AppTheme.inkSoft)),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.divider),
              ),
              child: CalendarDatePicker(
                initialDate: selected,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 730)),
                onDateChanged: (value) => setState(() => selected = value),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${selected.month}月${selected.day}日',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (look == null)
              _EmptyDate(onChoose: _chooseLook)
            else
              _ScheduledCard(
                look: look,
                onChange: _chooseLook,
                onRemove: _remove,
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDate extends StatelessWidget {
  final VoidCallback onChoose;
  const _EmptyDate({required this.onChoose});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFE8EFE9),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            '这一天还没有安排\n从“我的搭配”里选一套',
            style: TextStyle(height: 1.5, fontWeight: FontWeight.w600),
          ),
        ),
        FilledButton(onPressed: onChoose, child: const Text('选择')),
      ],
    ),
  );
}

class _ScheduledCard extends StatelessWidget {
  final SavedLook look;
  final VoidCallback onChange;
  final VoidCallback onRemove;
  const _ScheduledCard({
    required this.look,
    required this.onChange,
    required this.onRemove,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          look.name,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final item in look.outfit.pieces.whereType<ClothingItem>())
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _MiniImage(item: item),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onRemove,
                child: const Text('移除'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: onChange,
                child: const Text('更换搭配'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _MiniImage extends StatelessWidget {
  final ClothingItem item;
  const _MiniImage({required this.item});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: ColoredBox(
      color: const Color(0xFFF2F0EB),
      child: item.style.isLocalFile
          ? Image.file(File(item.assetPath), fit: BoxFit.contain)
          : Image.asset(item.assetPath, fit: BoxFit.contain),
    ),
  );
}
