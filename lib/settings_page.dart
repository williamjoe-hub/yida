import 'package:flutter/material.dart';

import 'app_audio.dart';
import 'app_theme.dart';
import 'profile_settings.dart';

class SettingsPage extends StatefulWidget {
  final UserGender gender;
  final String displayName;
  final ValueChanged<UserGender> onGenderChanged;
  final ValueChanged<String> onDisplayNameChanged;
  const SettingsPage({
    super.key,
    required this.gender,
    required this.displayName,
    required this.onGenderChanged,
    required this.onDisplayNameChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool effectsEnabled = true;
  bool startupEnabled = true;
  String volume = 'soft';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await AppAudio.settings();
    if (!mounted) return;
    setState(() {
      effectsEnabled = value['effectsEnabled'] as bool? ?? true;
      startupEnabled = value['startupEnabled'] as bool? ?? true;
      volume = value['volume'] as String? ?? 'soft';
    });
  }

  Future<void> _editName() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _NameEditDialog(initialValue: widget.displayName),
    );
    if (value != null && value.isNotEmpty) widget.onDisplayNameChanged(value);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      children: [
        const Text(
          '我的',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          '调整穿搭推荐、声音与触感',
          style: TextStyle(fontSize: 13, color: AppTheme.inkSoft),
        ),
        const SizedBox(height: 20),
        _SettingsCard(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              leading: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFE1E9E2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  widget.displayName.characters.first.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accentDeep,
                  ),
                ),
              ),
              title: Text(
                widget.displayName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('本机资料'),
              trailing: const Icon(Icons.edit_outlined, size: 20),
              onTap: _editName,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          '穿搭推荐',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 10),
        _SettingsCard(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 15, 16, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    color: AppTheme.accentDeep,
                  ),
                  SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '推荐性别',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '男生推荐不会出现裙装',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<UserGender>(
                  segments: const [
                    ButtonSegment(
                      value: UserGender.male,
                      icon: Icon(Icons.male_rounded),
                      label: Text('男生'),
                    ),
                    ButtonSegment(
                      value: UserGender.female,
                      icon: Icon(Icons.female_rounded),
                      label: Text('女生'),
                    ),
                  ],
                  selected: {widget.gender},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) {
                    AppTheme.haptic();
                    widget.onGenderChanged(value.first);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          '声音与触感',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 10),
        _SettingsCard(
          children: [
            _SwitchRow(
              icon: Icons.graphic_eq_rounded,
              title: '应用音效',
              subtitle: '仅在完成重要操作时播放',
              value: effectsEnabled,
              onChanged: (value) {
                setState(() => effectsEnabled = value);
                AppAudio.setSetting('effectsEnabled', value);
              },
            ),
            const _Divider(),
            _SwitchRow(
              icon: Icons.wb_sunny_outlined,
              title: '启动音',
              subtitle: '每次冷启动播放一次',
              value: startupEnabled,
              onChanged: (value) {
                setState(() => startupEnabled = value);
                AppAudio.setSetting('startupEnabled', value);
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SettingsCard(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 15, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.volume_down_rounded, color: AppTheme.accentDeep),
                  SizedBox(width: 11),
                  Text(
                    '音效音量',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'soft', label: Text('轻柔')),
                  ButtonSegment(value: 'standard', label: Text('标准')),
                ],
                selected: {volume},
                showSelectedIcon: false,
                onSelectionChanged: (value) {
                  final next = value.first;
                  setState(() => volume = next);
                  AppAudio.setSetting('volume', next);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: startupEnabled ? AppAudio.playStartup : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('试听启动音'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: effectsEnabled
                    ? () => AppAudio.playEffect('complete')
                    : null,
                icon: const Icon(Icons.check_rounded),
                label: const Text('试听完成音'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _NameEditDialog extends StatefulWidget {
  final String initialValue;
  const _NameEditDialog({required this.initialValue});

  @override
  State<_NameEditDialog> createState() => _NameEditDialogState();
}

class _NameEditDialogState extends State<_NameEditDialog> {
  late final TextEditingController controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('修改称呼'),
    content: TextField(
      controller: controller,
      autofocus: true,
      maxLength: 12,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(hintText: '名字或昵称'),
      onSubmitted: (value) => Navigator.pop(context, value.trim()),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text.trim()),
        child: const Text('完成'),
      ),
    ],
  );
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.divider),
      ),
      child: Column(children: children),
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 11, 10, 11),
    child: Row(
      children: [
        Icon(icon, color: AppTheme.accentDeep),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppTheme.inkSoft),
              ),
            ],
          ),
        ),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 52, color: AppTheme.divider);
}
