import 'dart:ui';

import 'package:flutter/material.dart';
import 'app_audio.dart';
import 'app_pressable.dart';
import 'app_theme.dart';
import 'home_page.dart';
import 'onboarding_page.dart';
import 'outfit_calendar_page.dart';
import 'profile_settings.dart';
import 'settings_page.dart';
import 'wardrobe_page.dart';

void main() => runApp(const DressFitApp());

class DressFitApp extends StatelessWidget {
  const DressFitApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '衣搭',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.theme(),
    home: const RootShell(),
  );
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  static bool _startupSoundPlayed = false;
  int index = 0;
  int calendarGeneration = 0;
  int homeScheduleRevision = 0;
  int wardrobeRevision = 0;
  UserGender gender = UserGender.male;
  String displayName = '';
  bool profileLoaded = false;
  bool onboardingComplete = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    if (!_startupSoundPlayed) {
      _startupSoundPlayed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await AppAudio.playStartup();
      });
    }
  }

  Future<void> _loadProfile() async {
    final value = await ProfileSettings.loadProfile();
    if (!mounted) return;
    setState(() {
      gender = value.gender;
      displayName = value.displayName;
      onboardingComplete = value.onboardingComplete && displayName.isNotEmpty;
      profileLoaded = true;
    });
  }

  Future<void> _setGender(UserGender value) async {
    setState(() => gender = value);
    await ProfileSettings.saveGender(value);
  }

  Future<void> _setDisplayName(String value) async {
    final name = value.trim();
    if (name.isEmpty) return;
    setState(() => displayName = name);
    await ProfileSettings.saveDisplayName(name);
  }

  Future<void> _completeOnboarding(OnboardingResult value) async {
    await ProfileSettings.completeOnboarding(
      displayName: value.displayName,
      gender: value.gender,
    );
    if (!mounted) return;
    setState(() {
      displayName = value.displayName;
      gender = value.gender;
      onboardingComplete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!profileLoaded) {
      return const Scaffold(body: SizedBox.expand());
    }
    if (!onboardingComplete) {
      return OnboardingPage(onComplete: _completeOnboarding);
    }
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          HomePage(
            gender: gender,
            displayName: displayName,
            wardrobeRevision: wardrobeRevision,
            scheduleRevision: homeScheduleRevision,
          ),
          OutfitCalendarPage(
            key: ValueKey(calendarGeneration),
            onScheduleChanged: () => setState(() => homeScheduleRevision++),
          ),
          WardrobePage(onChanged: () => setState(() => wardrobeRevision++)),
          SettingsPage(
            gender: gender,
            displayName: displayName,
            onGenderChanged: _setGender,
            onDisplayNameChanged: _setDisplayName,
          ),
        ],
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .88),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: .92)),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.ink.withValues(alpha: .055),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  for (final entry in const [
                    (Icons.home_rounded, '首页'),
                    (Icons.calendar_month_rounded, '日历'),
                    (Icons.checkroom_rounded, '衣橱'),
                    (Icons.person_rounded, '我的'),
                  ].indexed)
                    Expanded(
                      child: AppPressable(
                        semanticLabel: entry.$2.$2,
                        scale: .96,
                        onTap: () {
                          if (index == entry.$1) return;
                          AppTheme.haptic();
                          setState(() {
                            index = entry.$1;
                            if (index == 1) calendarGeneration++;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: AppTheme.fast,
                                curve: AppTheme.spring,
                                width: 36,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: index == entry.$1
                                      ? AppTheme.accent.withValues(alpha: .22)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  entry.$2.$1,
                                  size: 23,
                                  color: index == entry.$1
                                      ? AppTheme.ink
                                      : AppTheme.inkSoft,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                entry.$2.$2,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: index == entry.$1
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: index == entry.$1
                                      ? AppTheme.ink
                                      : AppTheme.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
