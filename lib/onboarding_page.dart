import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'email_account_page.dart';
import 'profile_settings.dart';

class OnboardingResult {
  final String displayName;
  final UserGender gender;

  const OnboardingResult({required this.displayName, required this.gender});
}

class OnboardingPage extends StatefulWidget {
  final ValueChanged<OnboardingResult> onComplete;
  const OnboardingPage({super.key, required this.onComplete});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final controller = PageController();
  final nameController = TextEditingController();
  int page = 0;
  UserGender gender = UserGender.male;

  @override
  void dispose() {
    controller.dispose();
    nameController.dispose();
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (page < 2) {
      HapticFeedback.selectionClick();
      controller.nextPage(
        duration: AppTheme.reduceMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 280),
        curve: AppTheme.move,
      );
      return;
    }
    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('先告诉我怎么称呼你')));
      return;
    }
    HapticFeedback.lightImpact();
    widget.onComplete(OnboardingResult(displayName: name, gender: gender));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                const Text(
                  '衣搭',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  '${page + 1} / 3',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: controller,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (value) => setState(() => page = value),
              children: [
                _IntroPage(
                  visual: const _OutfitOrbit(),
                  title: '每天少想一点',
                  subtitle: '根据天气和你的风格，把今天穿什么提前准备好。',
                ),
                _IntroPage(
                  visual: const _WardrobeVisual(),
                  title: '衣服真正属于你',
                  subtitle: '拍下自己的衣服，和系统单品自由搭配。',
                ),
                _ProfileStep(
                  nameController: nameController,
                  gender: gender,
                  onGenderChanged: (value) => setState(() => gender = value),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var index = 0; index < 3; index++)
                      AnimatedContainer(
                        duration: AppTheme.fast,
                        curve: AppTheme.move,
                        width: index == page ? 22 : 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: index == page
                              ? AppTheme.ink
                              : AppTheme.divider,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _next,
                    child: Text(page == 2 ? '开始使用' : '继续'),
                  ),
                ),
                if (page == 2)
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmailAccountPage(),
                      ),
                    ),
                    child: const Text('使用邮箱登录或注册'),
                  )
                else
                  const SizedBox(height: 44),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _IntroPage extends StatelessWidget {
  final Widget visual;
  final String title;
  final String subtitle;
  const _IntroPage({
    required this.visual,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
    child: Column(
      children: [
        Expanded(child: Center(child: visual)),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 31,
            height: 1.08,
            letterSpacing: -.8,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: AppTheme.inkSoft,
          ),
        ),
        const SizedBox(height: 22),
      ],
    ),
  );
}

class _OutfitOrbit extends StatelessWidget {
  const _OutfitOrbit();

  @override
  Widget build(BuildContext context) => _EntranceMotion(
    child: Container(
      width: 260,
      height: 290,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDCE9E1), Color(0xFFF2E9DC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: .08),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          _FloatingIcon(
            icon: Icons.checkroom_rounded,
            alignment: Alignment(-.52, -.48),
            color: Color(0xFF89A595),
          ),
          _FloatingIcon(
            icon: Icons.dry_cleaning_rounded,
            alignment: Alignment(.5, -.14),
            color: Color(0xFFA88975),
          ),
          _FloatingIcon(
            icon: Icons.ice_skating_rounded,
            alignment: Alignment(-.18, .55),
            color: Color(0xFF6F7D89),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 31,
                color: AppTheme.accentDeep,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _WardrobeVisual extends StatelessWidget {
  const _WardrobeVisual();

  @override
  Widget build(BuildContext context) => _EntranceMotion(
    child: Container(
      width: 270,
      height: 270,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(42),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Expanded(
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: const [
                _GarmentTile(Icons.checkroom_rounded, Color(0xFFE1EAE3)),
                _GarmentTile(Icons.dry_cleaning_rounded, Color(0xFFF1E3D6)),
                _GarmentTile(Icons.face_rounded, Color(0xFFE1E7EF)),
                _GarmentTile(Icons.ice_skating_rounded, Color(0xFFE8E4DC)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_rounded, size: 18),
              SizedBox(width: 7),
              Text('拍下衣服，加入衣橱', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ProfileStep extends StatelessWidget {
  final TextEditingController nameController;
  final UserGender gender;
  final ValueChanged<UserGender> onGenderChanged;
  const _ProfileStep({
    required this.nameController,
    required this.gender,
    required this.onGenderChanged,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 38, 24, 12),
    children: [
      const Icon(Icons.waving_hand_rounded, size: 58, color: Color(0xFFF0A98F)),
      const SizedBox(height: 24),
      const Text(
        '怎么称呼你？',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 30,
          letterSpacing: -.7,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        '只用于问候和个性化推荐，之后可以修改。',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: AppTheme.inkSoft),
      ),
      const SizedBox(height: 28),
      TextField(
        controller: nameController,
        autofocus: false,
        maxLength: 12,
        textAlign: TextAlign.center,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        decoration: const InputDecoration(
          hintText: '输入你的名字或昵称',
          counterText: '',
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<UserGender>(
          segments: const [
            ButtonSegment(value: UserGender.male, label: Text('男生')),
            ButtonSegment(value: UserGender.female, label: Text('女生')),
          ],
          selected: {gender},
          showSelectedIcon: false,
          onSelectionChanged: (value) => onGenderChanged(value.first),
        ),
      ),
    ],
  );
}

class _EntranceMotion extends StatelessWidget {
  final Widget child;
  const _EntranceMotion({required this.child});

  @override
  Widget build(BuildContext context) {
    if (AppTheme.reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: AppTheme.spring,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: Transform.scale(scale: .96 + .04 * value, child: child),
        ),
      ),
      child: child,
    );
  }
}

class _FloatingIcon extends StatelessWidget {
  final IconData icon;
  final Alignment alignment;
  final Color color;
  const _FloatingIcon({
    required this.icon,
    required this.alignment,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(23),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 31),
    ),
  );
}

class _GarmentTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _GarmentTile(this.icon, this.color);

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Icon(icon, size: 28, color: AppTheme.ink),
  );
}
