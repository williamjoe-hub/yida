import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'app_audio.dart';
import 'app_pressable.dart';
import 'app_theme.dart';
import 'garment_picker_page.dart';
import 'models.dart';
import 'outfit_board.dart';
import 'outfit_detail_page.dart';
import 'outfit_recommendation_service.dart';
import 'outfit_share_page.dart';
import 'profile_settings.dart';
import 'saved_look.dart';
import 'trend_service.dart';
import 'weather_service.dart';
import 'weather_preferences.dart';
import 'wardrobe_store.dart';

class HomePage extends StatefulWidget {
  final UserGender gender;
  final String displayName;
  final int wardrobeRevision;
  final int scheduleRevision;
  const HomePage({
    super.key,
    required this.gender,
    required this.displayName,
    this.wardrobeRevision = 0,
    this.scheduleRevision = 0,
  });
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool isTryOn = false;
  bool displayedTryOn = false;
  bool contentVisible = true;
  late Outfit outfit = customOutfit();
  final List<SavedLook> savedLooks = [];
  OverlayEntry? saveToast;
  SavedLook? todayLook;
  String? editingLookName;
  final Set<ClothingCategory> checkedToday = {};
  WeatherSnapshot? weather;
  String? weatherError = '点击天气图标获取当地天气';
  bool weatherLoading = false;
  bool weatherConsent = false;
  List<TrendItem> trends = const [];
  bool trendLoading = true;
  String? trendError;
  OutfitSeason? recommendationSeason;
  int recommendationPage = 0;
  RecommendationSource recommendationSource = RecommendationSource.inspiration;
  List<ClothingItem> userWardrobeItems = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedLooks();
    _syncTodayLookFromSchedule();
    _loadTodayChecklist();
    _loadTrends();
    _initializeWeather();
    _loadUserWardrobe();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wardrobeRevision != widget.wardrobeRevision) {
      _loadUserWardrobe();
    }
    if (oldWidget.scheduleRevision != widget.scheduleRevision) {
      _syncTodayLookFromSchedule();
    }
  }

  Future<void> _loadUserWardrobe() async {
    final garments = await WardrobeStore.load();
    if (!mounted) return;
    setState(() {
      userWardrobeItems = garments.map((value) => value.item).toList();
      recommendationPage = 0;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    saveToast?.remove();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        weatherConsent &&
        !weatherLoading) {
      _loadWeather();
    }
  }

  Future<void> _initializeWeather() async {
    var consent = await WeatherPreferences.loadConsent();
    if (!consent && await WeatherService.hasLocationPermission()) {
      consent = true;
      await WeatherPreferences.saveConsent(true);
    }
    if (!mounted) return;
    weatherConsent = consent;
    if (consent) await _loadWeather();
  }

  Future<File> _todayLookFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/today_outfit.json');
  }

  Future<File> _todayChecklistFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/today_checklist.json');
  }

  Future<void> _loadTodayChecklist() async {
    try {
      final file = await _todayChecklistFile();
      if (!await file.exists()) return;
      final value =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (value['date'] != SavedLookStore.dateKey(DateTime.now())) return;
      final loaded = (value['checked'] as List<dynamic>)
          .map(
            (name) => ClothingCategory.values.firstWhere((e) => e.name == name),
          )
          .toSet();
      if (mounted) setState(() => checkedToday.addAll(loaded));
    } catch (_) {}
  }

  Future<void> _toggleToday(ClothingCategory category) async {
    setState(() {
      if (!checkedToday.add(category)) checkedToday.remove(category);
    });
    final file = await _todayChecklistFile();
    await file.writeAsString(
      jsonEncode({
        'date': SavedLookStore.dateKey(DateTime.now()),
        'checked': checkedToday.map((e) => e.name).toList(),
      }),
    );
  }

  Future<void> _syncTodayLookFromSchedule() async {
    final todayKey = SavedLookStore.dateKey(DateTime.now());
    final directSchedule = await SavedLookStore.loadDirectSchedule();
    final schedule = await SavedLookStore.loadSchedule();
    final todayName = schedule[todayKey];
    SavedLook? scheduledLook = directSchedule[todayKey];
    if (scheduledLook != null && !scheduledLook.isAvailable) {
      scheduledLook = null;
    }
    if (scheduledLook == null && todayName != null) {
      final looks = await SavedLookStore.loadLooks();
      for (final look in looks) {
        if (look.name == todayName && look.isAvailable) {
          scheduledLook = look;
          break;
        }
      }
    }
    final file = await _todayLookFile();
    if (scheduledLook == null) {
      if (await file.exists()) await file.delete();
    } else {
      await file.writeAsString(jsonEncode(scheduledLook.toJson()));
    }
    if (!mounted) return;
    setState(() {
      todayLook = scheduledLook;
      if (scheduledLook == null) checkedToday.clear();
    });
  }

  Future<void> _setTodayLook(SavedLook look) async {
    setState(() {
      todayLook = look;
      checkedToday.clear();
    });
    final file = await _todayLookFile();
    await file.writeAsString(jsonEncode(look.toJson()));
    final schedule = await SavedLookStore.loadSchedule();
    final todayKey = SavedLookStore.dateKey(DateTime.now());
    schedule[todayKey] = look.name;
    await SavedLookStore.saveSchedule(schedule);
    final directSchedule = await SavedLookStore.loadDirectSchedule();
    directSchedule.remove(todayKey);
    await SavedLookStore.saveDirectSchedule(directSchedule);
    final checklist = await _todayChecklistFile();
    if (await checklist.exists()) await checklist.delete();
    AppTheme.haptic();
    AppAudio.playEffect('complete');
    if (mounted) _showSaveToast(look.name, title: '已设为今日穿搭');
  }

  Future<void> _setCurrentOutfitAsToday() async {
    if (outfit.pieces.whereType<ClothingItem>().isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('还没有选择衣服'),
          content: const Text('至少选择一件单品后再设为今日穿搭。'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }
    final directLook = SavedLook(
      '试衣间搭配',
      Outfit(
        name: '试衣间搭配',
        vibe: outfit.vibe,
        matchScore: outfit.matchScore,
        hat: outfit.hat,
        top: outfit.top,
        bottom: outfit.bottom,
        shoes: outfit.shoes,
      ),
    );
    final todayKey = SavedLookStore.dateKey(DateTime.now());
    final directSchedule = await SavedLookStore.loadDirectSchedule();
    directSchedule[todayKey] = directLook;
    await SavedLookStore.saveDirectSchedule(directSchedule);
    final schedule = await SavedLookStore.loadSchedule();
    schedule.remove(todayKey);
    await SavedLookStore.saveSchedule(schedule);
    await (await _todayLookFile()).writeAsString(
      jsonEncode(directLook.toJson()),
    );
    final checklist = await _todayChecklistFile();
    if (await checklist.exists()) await checklist.delete();
    if (!mounted) return;
    setState(() {
      todayLook = directLook;
      checkedToday.clear();
    });
    AppTheme.haptic();
    AppAudio.playEffect('complete');
    _showSaveToast('无需保存，已同步到日历', title: '已设为今日穿搭');
  }

  Future<void> _loadWeather() async {
    if (mounted) {
      setState(() {
        weatherLoading = true;
        weatherError = null;
      });
    }
    try {
      final value = await WeatherService.current();
      if (!mounted) return;
      setState(() {
        weather = value;
        weatherLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        weatherLoading = false;
        weatherError = error.toString();
      });
    }
  }

  Future<void> _loadTrends() async {
    if (mounted) {
      setState(() {
        trendLoading = true;
        trendError = null;
      });
    }
    try {
      final value = await TrendService.load();
      if (!mounted) return;
      setState(() {
        trends = value;
        trendLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        trendLoading = false;
        trendError = error.toString();
      });
    }
  }

  Future<void> _requestWeather() async {
    if (!weatherConsent) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.location_on_outlined),
          title: const Text('显示当地天气'),
          content: const Text(
            '衣搭会读取约 10 公里精度的大致位置，并发送给 Open-Meteo 获取当前天气。不会读取精确地址，也不会上传衣橱或照片。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('暂不使用'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('允许并获取'),
            ),
          ],
        ),
      );
      if (!mounted || approved != true) return;
      weatherConsent = true;
      await WeatherPreferences.saveConsent(true);
    }
    await _loadWeather();
  }

  Future<void> _loadSavedLooks() async {
    try {
      final loaded = await SavedLookStore.loadLooks();
      if (!mounted) return;
      setState(() {
        savedLooks
          ..clear()
          ..addAll(loaded);
      });
    } catch (_) {}
  }

  Future<void> _persistSavedLooks() async {
    await SavedLookStore.saveLooks(savedLooks);
  }

  Future<void> _saveCurrentLook() async {
    if (outfit.pieces.whereType<ClothingItem>().isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('还没有选择衣服'),
          content: const Text('至少保留一件单品后再保存搭配。'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }
    var draftName = editingLookName ?? '我的搭配 ${savedLooks.length + 1}';
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存这套搭配'),
        content: TextFormField(
          initialValue: draftName,
          autofocus: true,
          maxLength: 16,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: '搭配名称',
            hintText: '例如：周一清爽校园',
          ),
          onChanged: (value) => draftName = value,
          onFieldSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, draftName.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (!mounted || name == null || name.isEmpty) return;
    final previousName = editingLookName;
    final existingIndex = savedLooks.indexWhere(
      (value) => value.name == (previousName ?? name),
    );
    final saved = SavedLook(name, outfit);
    setState(() {
      if (existingIndex >= 0) savedLooks.removeAt(existingIndex);
      savedLooks.insert(0, saved);
      editingLookName = null;
    });
    await _persistSavedLooks();
    AppTheme.haptic();
    AppAudio.playEffect('complete');
    if (!mounted) return;
    _showSaveToast(name);
  }

  void _showSaveToast(String name, {String title = '搭配已保存'}) {
    saveToast?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TopSaveToast(
        name: name,
        title: title,
        onDismiss: () {
          if (saveToast == entry) {
            entry.remove();
            saveToast = null;
          }
        },
      ),
    );
    saveToast = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  Future<void> _renameLook(
    SavedLook look,
    void Function(VoidCallback fn) refreshSheet,
  ) async {
    var draft = look.name;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改搭配名称'),
        content: TextFormField(
          initialValue: draft,
          autofocus: true,
          maxLength: 16,
          onChanged: (value) => draft = value,
          onFieldSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, draft.trim()),
            child: const Text('完成'),
          ),
        ],
      ),
    );
    if (!mounted || name == null || name.isEmpty || name == look.name) return;
    if (savedLooks.any((value) => value.name == name)) {
      _showSaveToast(name, title: '名称已存在，请换一个');
      return;
    }
    final renamed = look.renamed(name);
    final index = savedLooks.indexOf(look);
    setState(() {
      savedLooks[index] = renamed;
      if (todayLook?.name == look.name) todayLook = renamed;
    });
    refreshSheet(() {});
    await _persistSavedLooks();
    if (todayLook?.name == name) {
      await (await _todayLookFile()).writeAsString(
        jsonEncode(renamed.toJson()),
      );
    }
    final schedule = await SavedLookStore.loadSchedule();
    schedule.updateAll((_, value) => value == look.name ? name : value);
    await SavedLookStore.saveSchedule(schedule);
    if (mounted) _showSaveToast(name, title: '名称已更新');
  }

  Future<void> _scheduleLook(SavedLook look) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: '安排穿搭日期',
      cancelText: '取消',
      confirmText: '安排',
    );
    if (!mounted || date == null) return;
    final schedule = await SavedLookStore.loadSchedule();
    schedule[SavedLookStore.dateKey(date)] = look.name;
    await SavedLookStore.saveSchedule(schedule);
    if (mounted) {
      _showSaveToast(
        '${date.month}月${date.day}日 · ${look.name}',
        title: '已加入穿搭日历',
      );
    }
  }

  Future<void> _openSavedLooks() async {
    final selected = await showModalBottomSheet<Outfit>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => _SavedLooksSheet(
          looks: savedLooks,
          onWear: (value) => Navigator.pop(context, value.outfit),
          onEdit: (value) {
            setState(() {
              outfit = value.outfit;
              editingLookName = value.name;
            });
            _changeMode(true);
            Navigator.pop(context);
            _showSaveToast(value.name, title: '已载入，可修改后保存');
          },
          onRename: (value) => _renameLook(value, setSheetState),
          onSchedule: (value) => _scheduleLook(value),
          onShare: (value) => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => OutfitSharePage(look: value)),
          ),
          onDelete: (value) async {
            final wasToday = todayLook?.name == value.name;
            setState(() {
              savedLooks.remove(value);
              if (wasToday) todayLook = null;
            });
            setSheetState(() {});
            await _persistSavedLooks();
            if (wasToday) {
              final file = await _todayLookFile();
              if (await file.exists()) await file.delete();
            }
            AppAudio.playEffect('deleted');
          },
          onToday: (value) async {
            await _setTodayLook(value);
            setSheetState(() {});
          },
          todayName: todayLook?.name,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => outfit = selected);
    _changeMode(true);
  }

  void _changeMode(bool value) {
    if (value == isTryOn && contentVisible) return;
    if (AppTheme.reduceMotion(context)) {
      setState(() {
        isTryOn = value;
        displayedTryOn = value;
        contentVisible = true;
      });
      return;
    }
    setState(() {
      isTryOn = value;
      contentVisible = value == displayedTryOn;
    });
  }

  void _finishContentFade() {
    if (contentVisible || displayedTryOn == isTryOn) return;
    setState(() {
      displayedTryOn = isTryOn;
      contentVisible = true;
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: _TopSwitch(
            isTryOn: isTryOn,
            onChanged: (v) {
              AppTheme.haptic();
              _changeMode(v);
            },
          ),
        ),
        Expanded(
          child: AnimatedOpacity(
            opacity: contentVisible ? 1 : 0,
            duration: AppTheme.reduceMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 360),
            curve: AppTheme.move,
            onEnd: _finishContentFade,
            child: displayedTryOn
                ? _TryOnView(
                    key: const ValueKey('try'),
                    outfit: outfit,
                    onOutfit: (v) => setState(() => outfit = v),
                    savedCount: savedLooks.length,
                    onSave: _saveCurrentLook,
                    onSetToday: _setCurrentOutfitAsToday,
                    onOpenSaved: _openSavedLooks,
                  )
                : _RecommendView(
                    key: const ValueKey('recommend'),
                    todayOutfit: todayLook?.outfit,
                    weather: weather,
                    weatherLoading: weatherLoading,
                    onRefreshWeather: _requestWeather,
                    checkedToday: checkedToday,
                    onToggleChecked: _toggleToday,
                    trends: trends,
                    gender: widget.gender,
                    displayName: widget.displayName,
                    userWardrobeItems: userWardrobeItems,
                    recommendationSource: recommendationSource,
                    onRecommendationSourceChanged: (value) => setState(() {
                      recommendationSource = value;
                      recommendationPage = 0;
                    }),
                    selectedSeason: recommendationSeason,
                    recommendationPage: recommendationPage,
                    onSeasonChanged: (value) => setState(() {
                      recommendationSeason = value;
                      recommendationPage = 0;
                    }),
                    onNextBatch: () => setState(() => recommendationPage++),
                    onTry: (value) {
                      setState(() => outfit = value);
                      _changeMode(true);
                    },
                  ),
          ),
        ),
      ],
    ),
  );
}

class _TopSwitch extends StatelessWidget {
  final bool isTryOn;
  final ValueChanged<bool> onChanged;
  const _TopSwitch({required this.isTryOn, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFE9E6E0),
      borderRadius: BorderRadius.circular(16),
    ),
    child: SizedBox(
      height: 40,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedAlign(
            alignment: isTryOn ? Alignment.centerRight : Alignment.centerLeft,
            duration: AppTheme.reduceMotion(context)
                ? Duration.zero
                : AppTheme.mid,
            curve: AppTheme.move,
            child: FractionallySizedBox(
              widthFactor: .5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < 2; i++)
                Expanded(
                  child: AppPressable(
                    semanticLabel: i == 0 ? '今日推荐' : '搭配',
                    scale: 1,
                    onTap: () {
                      final next = i == 1;
                      if (next != isTryOn) onChanged(next);
                    },
                    child: Center(
                      child: Text(
                        i == 0 ? '今日推荐' : '搭配',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _RecommendView extends StatelessWidget {
  final ValueChanged<Outfit> onTry;
  final Outfit? todayOutfit;
  final WeatherSnapshot? weather;
  final bool weatherLoading;
  final VoidCallback onRefreshWeather;
  final Set<ClothingCategory> checkedToday;
  final ValueChanged<ClothingCategory> onToggleChecked;
  final List<TrendItem> trends;
  final UserGender gender;
  final String displayName;
  final List<ClothingItem> userWardrobeItems;
  final RecommendationSource recommendationSource;
  final ValueChanged<RecommendationSource> onRecommendationSourceChanged;
  final OutfitSeason? selectedSeason;
  final int recommendationPage;
  final ValueChanged<OutfitSeason?> onSeasonChanged;
  final VoidCallback onNextBatch;
  const _RecommendView({
    super.key,
    required this.onTry,
    required this.todayOutfit,
    required this.weather,
    required this.weatherLoading,
    required this.onRefreshWeather,
    required this.checkedToday,
    required this.onToggleChecked,
    required this.trends,
    required this.gender,
    required this.displayName,
    required this.userWardrobeItems,
    required this.recommendationSource,
    required this.onRecommendationSourceChanged,
    required this.selectedSeason,
    required this.recommendationPage,
    required this.onSeasonChanged,
    required this.onNextBatch,
  });
  @override
  Widget build(BuildContext context) {
    final effectiveSeason =
        selectedSeason ?? OutfitRecommendationService.currentSeason(weather);
    final systemSuggestions = [
      ...OutfitRecommendationService.forWeather(
        weather,
        gender: gender,
        preferredSeason: effectiveSeason,
      ),
    ];
    final trendText = trends.map((item) => item.title).join(' ');
    void prioritizeWhere(bool Function(Outfit value) test) {
      final promoted = systemSuggestions.where(test).toList();
      systemSuggestions
        ..removeWhere(test)
        ..insertAll(0, promoted);
    }

    if (RegExp(r'比赛|体育|足球|篮球|跑步|运动|冠军').hasMatch(trendText)) {
      prioritizeWhere((outfit) => outfit.name.contains('运动'));
    } else if (RegExp(r'科技|AI|机器人|手机|数码|未来').hasMatch(trendText)) {
      prioritizeWhere(
        (outfit) => outfit.top?.style.material == GarmentMaterial.nylon,
      );
    } else if (RegExp(r'旅行|文旅|景区|假期|出游').hasMatch(trendText)) {
      prioritizeWhere(
        (outfit) => RegExp(
          r'运动鞋|跑鞋|板鞋|帆布鞋|凉鞋',
        ).hasMatch(outfit.shoes?.style.name ?? ''),
      );
    } else if (RegExp(r'电影|明星|音乐|演唱会|时尚').hasMatch(trendText)) {
      prioritizeWhere(
        (outfit) =>
            outfit.top?.style.material == GarmentMaterial.denim ||
            outfit.top?.style.material == GarmentMaterial.wool,
      );
    }
    if (weather?.rainExpected == true) {
      prioritizeWhere(
        (outfit) =>
            outfit.top?.style.material == GarmentMaterial.nylon ||
            outfit.name.contains('防风') ||
            outfit.name.contains('机能'),
      );
    }
    final personalizedSuggestions = switch (recommendationSource) {
      RecommendationSource.inspiration =>
        OutfitRecommendationService.inspirationForWardrobe(
          systemSuggestions,
          userWardrobeItems,
        ),
      RecommendationSource.mine => OutfitRecommendationService.fromMyWardrobe(
        userItems: userWardrobeItems,
        systemOutfits: systemSuggestions,
        season: effectiveSeason,
        gender: gender,
        weather: weather,
      ),
    };
    final mineIsEmpty =
        recommendationSource == RecommendationSource.mine &&
        personalizedSuggestions.isEmpty;
    final suggestions = mineIsEmpty
        ? systemSuggestions
        : personalizedSuggestions;
    const batchSize = 24;
    final start = (recommendationPage * batchSize) % suggestions.length;
    final batch = List<Outfit>.generate(
      batchSize,
      (index) => suggestions[(start + index) % suggestions.length],
    );
    final featuredOutfit = todayOutfit ?? batch.first;
    final moreOutfits = todayOutfit == null
        ? batch.skip(1).take(8).toList()
        : batch.take(8).toList();
    final featuredLabel = todayOutfit != null ? '今日穿搭' : '今日推荐';
    final hour = DateTime.now().hour;
    final greeting = hour < 11
        ? '早上好'
        : hour < 14
        ? '中午好'
        : hour < 18
        ? '下午好'
        : '晚上好';

    Future<void> openOutfit(Outfit value) async {
      final shouldTry = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => OutfitDetailPage(outfit: value)),
      );
      if (context.mounted && shouldTry == true) onTry(value);
    }

    void openFilters() {
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => _RecommendationFilterSheet(
          effectiveSeason: effectiveSeason,
          selectedSeason: selectedSeason,
          onChanged: (value) {
            Navigator.pop(sheetContext);
            onSeasonChanged(value);
          },
          onNextBatch: () {
            Navigator.pop(sheetContext);
            onNextBatch();
          },
        ),
      );
    }

    void openChecklist() {
      if (todayOutfit == null) return;
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => StatefulBuilder(
          builder: (_, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: _TodayChecklist(
              outfit: todayOutfit!,
              checked: checkedToday,
              onToggle: (category) {
                onToggleChecked(category);
                setSheetState(() {});
              },
            ),
          ),
        ),
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '$greeting，$displayName',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                _WeatherBadge(
                  weather: weather,
                  loading: weatherLoading,
                  onTap: onRefreshWeather,
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _RecommendationSourcePicker(
              value: recommendationSource,
              onChanged: onRecommendationSourceChanged,
            ),
          ),
        ),
        if (mineIsEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _EmptyMineRecommendation(
                hasItems: userWardrobeItems.isNotEmpty,
              ),
            ),
          ),
        if (!mineIsEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _TodayHeroCard(
                outfit: featuredOutfit,
                label: featuredLabel,
                onTap: () => openOutfit(featuredOutfit),
                onChecklist: todayOutfit == null ? null : openChecklist,
                checkedCategories: checkedToday,
              ),
            ),
          ),
        if (!mineIsEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 14, 10),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '更多推荐',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: openFilters,
                    icon: const Icon(Icons.tune_rounded, size: 17),
                    label: Text(selectedSeason?.label ?? '智能'),
                  ),
                ],
              ),
            ),
          ),
        if (!mineIsEmpty)
          SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 52) / 2;
                return SizedBox(
                  height: 198,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: moreOutfits.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, index) => _CompactOutfitCard(
                      width: cardWidth,
                      outfit: moreOutfits[index],
                      onTap: () => openOutfit(moreOutfits[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 30)),
      ],
    );
  }
}

class _RecommendationSourcePicker extends StatelessWidget {
  final RecommendationSource value;
  final ValueChanged<RecommendationSource> onChanged;
  const _RecommendationSourcePicker({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: SegmentedButton<RecommendationSource>(
      segments: const [
        ButtonSegment(
          value: RecommendationSource.inspiration,
          icon: Icon(Icons.auto_awesome_rounded, size: 17),
          label: Text('搭配灵感'),
        ),
        ButtonSegment(
          value: RecommendationSource.mine,
          icon: Icon(Icons.checkroom_rounded, size: 17),
          label: Text('我的衣服'),
        ),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        AppTheme.haptic();
        onChanged(selection.first);
      },
    ),
  );
}

class _EmptyMineRecommendation extends StatelessWidget {
  final bool hasItems;
  const _EmptyMineRecommendation({required this.hasItems});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Column(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFFE1E9E2),
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: EdgeInsets.all(15),
            child: Icon(
              Icons.add_a_photo_outlined,
              color: AppTheme.accentDeep,
              size: 27,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          hasItems ? '当前季节没有合适的单品' : '先添加一件自己的衣服',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          hasItems ? '可以切换季节，或继续向衣橱添加衣服。' : '到衣橱拍摄后，这里会自动生成搭配。',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft),
        ),
      ],
    ),
  );
}

class _TodayHeroCard extends StatelessWidget {
  final Outfit outfit;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onChecklist;
  final Set<ClothingCategory> checkedCategories;
  const _TodayHeroCard({
    required this.outfit,
    required this.label,
    required this.onTap,
    this.onChecklist,
    this.checkedCategories = const {},
  });

  @override
  Widget build(BuildContext context) {
    final pieces = outfit.pieces.whereType<ClothingItem>().toList();
    return AppPressable(
      semanticLabel: '查看${outfit.name}',
      scale: .985,
      onTap: onTap,
      child: Container(
        height: 236,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFDCE9E1), Color(0xFFF2E9DC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: .85)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.ink.withValues(alpha: .07),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentDeep,
                    ),
                  ),
                ),
                if (onChecklist != null)
                  AppPressable(
                    semanticLabel: '出门前清单',
                    onTap: onChecklist,
                    child: const SizedBox(
                      width: 34,
                      height: 28,
                      child: Icon(
                        Icons.checklist_rounded,
                        size: 20,
                        color: AppTheme.accentDeep,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              outfit.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 23,
                height: 1.12,
                letterSpacing: -.45,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  for (var index = 0; index < pieces.length; index++) ...[
                    Expanded(
                      child: _RecommendationPieceImage(
                        item: pieces[index],
                        checked: checkedCategories.contains(
                          pieces[index].category,
                        ),
                      ),
                    ),
                    if (index != pieces.length - 1) const SizedBox(width: 7),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: AppTheme.ink,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactOutfitCard extends StatelessWidget {
  final double width;
  final Outfit outfit;
  final VoidCallback onTap;
  const _CompactOutfitCard({
    required this.width,
    required this.outfit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pieces = outfit.pieces.whereType<ClothingItem>().toList();
    return AppPressable(
      semanticLabel: '查看${outfit.name}',
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                children: [
                  for (final item in pieces)
                    _RecommendationPieceImage(item: item, compact: true),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              outfit.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationPieceImage extends StatelessWidget {
  final ClothingItem item;
  final bool compact;
  final bool checked;
  const _RecommendationPieceImage({
    required this.item,
    this.compact = false,
    this.checked = false,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(compact ? 10 : 16),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppTheme.bg),
        _SavedPieceImage(item: item),
        if (checked)
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppTheme.accentDeep,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 13,
                color: Colors.white,
              ),
            ),
          ),
      ],
    ),
  );
}

class _RecommendationFilterSheet extends StatelessWidget {
  final OutfitSeason effectiveSeason;
  final OutfitSeason? selectedSeason;
  final ValueChanged<OutfitSeason?> onChanged;
  final VoidCallback onNextBatch;
  const _RecommendationFilterSheet({
    required this.effectiveSeason,
    required this.selectedSeason,
    required this.onChanged,
    required this.onNextBatch,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '推荐范围',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _FilterRow(
          label: '智能 · ${effectiveSeason.label}',
          selected: selectedSeason == null,
          onTap: () => onChanged(null),
        ),
        for (final season in OutfitSeason.values)
          _FilterRow(
            label: season.label,
            selected: selectedSeason == season,
            onTap: () => onChanged(season),
          ),
        const Divider(height: 12),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: const Icon(Icons.refresh_rounded),
          title: const Text(
            '换一批推荐',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onNextBatch,
        ),
      ],
    ),
  );
}

class _FilterRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 48,
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    trailing: selected
        ? const Icon(Icons.check_rounded, color: AppTheme.accentDeep)
        : null,
    onTap: onTap,
  );
}

// Legacy components kept temporarily for visual rollback comparison.
// ignore: unused_element
class _SeasonPicker extends StatelessWidget {
  final OutfitSeason effectiveSeason;
  final OutfitSeason? selectedSeason;
  final ValueChanged<OutfitSeason?> onChanged;
  final VoidCallback onNextBatch;
  const _SeasonPicker({
    required this.effectiveSeason,
    required this.selectedSeason,
    required this.onChanged,
    required this.onNextBatch,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: ListView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      children: [
        ChoiceChip(
          label: Text('智能 ${effectiveSeason.label}'),
          selected: selectedSeason == null,
          onSelected: (_) => onChanged(null),
        ),
        const SizedBox(width: 7),
        for (final season in OutfitSeason.values) ...[
          ChoiceChip(
            label: Text('${season.label} ${season.targetCount}'),
            selected: selectedSeason == season,
            onSelected: (_) => onChanged(season),
          ),
          const SizedBox(width: 7),
        ],
        ActionChip(
          avatar: const Icon(Icons.refresh_rounded, size: 17),
          label: const Text('换一批'),
          onPressed: onNextBatch,
        ),
      ],
    ),
  );
}

// ignore: unused_element
class _RainAlert extends StatelessWidget {
  final WeatherSnapshot weather;
  const _RainAlert({required this.weather});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFD8E8F0), Color(0xFFEAF1F3)],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFC9DDE6)),
    ),
    child: Row(
      children: [
        const Icon(Icons.umbrella_rounded, color: Color(0xFF527A91), size: 25),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '今天可能有雨，记得带伞',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF34596E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '最高降雨概率 ${weather.rainProbability}% · 建议短裤脚、防水外层、耐脏鞋',
                style: const TextStyle(fontSize: 11, color: Color(0xFF527A91)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TodayChecklist extends StatelessWidget {
  final Outfit outfit;
  final Set<ClothingCategory> checked;
  final ValueChanged<ClothingCategory> onToggle;
  const _TodayChecklist({
    required this.outfit,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.checklist_rounded, size: 20, color: AppTheme.accentDeep),
            SizedBox(width: 7),
            Text(
              '出门前清单',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 9),
        for (final category in ClothingCategory.values.where(
          (category) => outfit.pieceFor(category) != null,
        ))
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onToggle(category),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Checkbox(
                    value: checked.contains(category),
                    onChanged: (_) => onToggle(category),
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: Text(
                      outfit.pieceFor(category)!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: checked.contains(category)
                            ? AppTheme.inkSoft
                            : AppTheme.ink,
                        decoration: checked.contains(category)
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _WeatherBadge extends StatelessWidget {
  final WeatherSnapshot? weather;
  final bool loading;
  final VoidCallback onTap;
  const _WeatherBadge({
    required this.weather,
    required this.loading,
    required this.onTap,
  });

  IconData get icon {
    if (loading) return Icons.location_searching_rounded;
    if (weather == null) return Icons.location_off_rounded;
    if (weather!.rainExpected) return Icons.umbrella_rounded;
    if (weather!.condition == '雪') return Icons.ac_unit_rounded;
    if (weather!.condition == '多云' || weather!.condition == '阴') {
      return Icons.cloud_rounded;
    }
    return weather!.isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round;
  }

  @override
  Widget build(BuildContext context) => AppPressable(
    semanticLabel: '刷新当地天气',
    onTap: loading ? null : onTap,
    child: Container(
      width: 98,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: weather?.rainExpected == true
            ? const Color(0xFFDDE8EF)
            : const Color(0xFFFFE8D8),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: .8)),
      ),
      child: loading
          ? const Row(
              children: [
                SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  '定位中',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            )
          : Row(
              children: [
                Icon(
                  icon,
                  color: weather?.rainExpected == true
                      ? const Color(0xFF64869B)
                      : const Color(0xFFE79965),
                  size: 21,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weather == null
                            ? '天气'
                            : '${weather!.temperature.round()}°',
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        weather?.condition ?? '点击获取',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.05,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    ),
  );
}

// ignore: unused_element
class _OutfitCard extends StatelessWidget {
  final Outfit outfit;
  final bool featured;
  final VoidCallback onTry;
  const _OutfitCard({
    required this.outfit,
    required this.featured,
    required this.onTry,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: featured ? 270 : 235,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: featured
            ? const [Color(0xFFE0EAE3), Color(0xFFF4EFE7)]
            : const [Colors.white, Color(0xFFF4F2EE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white),
      boxShadow: const [
        BoxShadow(
          color: Color(0x11000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outfit.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    outfit.vibe,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            childAspectRatio: 1.45,
            children: [
              for (final piece in outfit.pieces.whereType<ClothingItem>())
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .82),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          color: piece.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          piece.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onTry,
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.ink,
              borderRadius: BorderRadius.circular(15),
            ),
            alignment: Alignment.center,
            child: const Text(
              '查看',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class TrendSectionLegacy extends StatefulWidget {
  final List<TrendItem> trends;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;
  const TrendSectionLegacy({
    super.key,
    required this.trends,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  @override
  State<TrendSectionLegacy> createState() => _TrendSectionState();
}

class _TrendSectionState extends State<TrendSectionLegacy> {
  int visibleCount = 8;

  int get hotInitialCount {
    if (widget.trends.isEmpty) return 8;
    final hottest = widget.trends.first.hotScore;
    if (hottest >= 7500000) return 12;
    if (hottest >= 5000000) return 10;
    return 8;
  }

  @override
  void didUpdateWidget(covariant TrendSectionLegacy oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trends != widget.trends && widget.trends.isNotEmpty) {
      visibleCount = hotInitialCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = visibleCount.clamp(0, widget.trends.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今日热榜灵感',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '网络热点越高，推荐内容越丰富',
                    style: TextStyle(fontSize: 11, color: AppTheme.inkSoft),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '刷新热点',
              onPressed: widget.loading ? null : widget.onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 21),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.loading)
          const _TrendLoading()
        else if (widget.trends.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '热点暂时没有加载出来，本地穿搭推荐仍可正常使用。',
                    style: TextStyle(fontSize: 12, color: AppTheme.inkSoft),
                  ),
                ),
                TextButton(
                  onPressed: widget.onRefresh,
                  child: const Text('重试'),
                ),
              ],
            ),
          )
        else ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              children: [
                for (var index = 0; index < count; index++) ...[
                  _TrendTile(item: widget.trends[index], rank: index + 1),
                  if (index != count - 1)
                    const Divider(height: 1, indent: 50, endIndent: 14),
                ],
              ],
            ),
          ),
          if (count < widget.trends.length)
            Center(
              child: TextButton.icon(
                onPressed: () => setState(
                  () => visibleCount = (visibleCount + 6).clamp(
                    0,
                    widget.trends.length,
                  ),
                ),
                icon: const Icon(Icons.expand_more_rounded),
                label: Text(
                  '再看 ${widget.trends.length - count >= 6 ? 6 : widget.trends.length - count} 条',
                ),
              ),
            ),
        ],
        const Padding(
          padding: EdgeInsets.only(top: 2, left: 2),
          child: Text(
            '热点来源：百度热搜 · 实时更新',
            style: TextStyle(fontSize: 10, color: AppTheme.inkSoft),
          ),
        ),
      ],
    );
  }
}

class _TrendTile extends StatelessWidget {
  final TrendItem item;
  final int rank;
  const _TrendTile({required this.item, required this.rank});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: rank <= 3
                ? const Color(0xFFFFE4D4)
                : const Color(0xFFF0EFEA),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: rank <= 3 ? const Color(0xFFD66C45) : AppTheme.inkSoft,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.outfitHint,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.inkSoft,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          item.hotLabel,
          style: const TextStyle(
            fontSize: 9.5,
            color: Color(0xFFD66C45),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _TrendLoading extends StatelessWidget {
  const _TrendLoading();
  @override
  Widget build(BuildContext context) => Container(
    height: 118,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppTheme.divider),
    ),
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 2),
          SizedBox(height: 10),
          Text(
            '正在读取今日实时热点…',
            style: TextStyle(fontSize: 11, color: AppTheme.inkSoft),
          ),
        ],
      ),
    ),
  );
}

// ignore: unused_element
class _ReasonCard extends StatelessWidget {
  final WeatherSnapshot? weather;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  const _ReasonCard({
    required this.weather,
    required this.loading,
    required this.error,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        const Icon(Icons.air_rounded, color: AppTheme.accentDeep),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            loading
                ? '正在根据你的位置获取今天的穿搭建议…'
                : weather?.fullAdvice ?? error ?? '暂时无法获取当地天气',
            style: const TextStyle(
              fontSize: 13,
              height: 1.55,
              color: AppTheme.inkSoft,
            ),
          ),
        ),
        if (!loading && weather == null)
          IconButton(
            tooltip: '重试',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
    ),
  );
}

class _TryOnView extends StatelessWidget {
  final Outfit outfit;
  final ValueChanged<Outfit> onOutfit;
  final int savedCount;
  final VoidCallback onSave;
  final VoidCallback onSetToday;
  final VoidCallback onOpenSaved;
  const _TryOnView({
    super.key,
    required this.outfit,
    required this.onOutfit,
    required this.savedCount,
    required this.onSave,
    required this.onSetToday,
    required this.onOpenSaved,
  });

  Future<void> _openPicker(
    BuildContext context,
    ClothingCategory category,
  ) async {
    final current = outfit.pieceFor(category);
    final result = await Navigator.push<GarmentPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => GarmentPickerPage(
          category: category,
          selectedStyleId: current?.style.id,
        ),
      ),
    );
    if (result == null) return;
    final style = result.style;
    if (style == null) {
      onOutfit(outfit.withoutPiece(category));
      return;
    }
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
            _TodayOutfitButton(onTap: onSetToday),
            const SizedBox(width: 7),
            _CompleteOutfitButton(onTap: onSave),
          ],
        ),
      ),
      AppPressable(
        semanticLabel: '打开我的搭配，共$savedCount套',
        scale: .985,
        onTap: onOpenSaved,
        child: Container(
          height: 52,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 9),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFDCE9E1), Color(0xFFEEF1E9)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white),
            boxShadow: const [
              BoxShadow(
                color: Color(0x102B4638),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
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
                child: const Icon(
                  Icons.collections_bookmark_rounded,
                  size: 18,
                  color: AppTheme.accentDeep,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '我的搭配',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '$savedCount 套',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentDeep,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.accentDeep,
              ),
            ],
          ),
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
                item: outfit.pieceFor(category),
                onTap: () => _openPicker(context, category),
              ),
          ],
        ),
      ),
    ],
  );
}

class _TopSaveToast extends StatefulWidget {
  final String name;
  final String title;
  final VoidCallback onDismiss;
  const _TopSaveToast({
    required this.name,
    required this.title,
    required this.onDismiss,
  });

  @override
  State<_TopSaveToast> createState() => _TopSaveToastState();
}

class _TopSaveToastState extends State<_TopSaveToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final Animation<double> animation = CurvedAnimation(
    parent: controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void initState() {
    super.initState();
    _animate();
  }

  Future<void> _animate() async {
    await controller.forward();
    await Future<void>.delayed(const Duration(milliseconds: 1250));
    if (!mounted) return;
    await controller.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    top: MediaQuery.paddingOf(context).top + 10,
    left: 20,
    right: 20,
    child: IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Opacity(
            opacity: animation.value,
            child: Transform.translate(
              offset: Offset(0, -24 * (1 - animation.value)),
              child: child,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
            decoration: BoxDecoration(
              color: const Color(0xFFFDFCF9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE3E8E2)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F26372E),
                  blurRadius: 22,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0EBE3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: AppTheme.accentDeep,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.inkSoft,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.bookmark_added_rounded,
                  size: 19,
                  color: AppTheme.accentDeep,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SavedLooksSheet extends StatelessWidget {
  final List<SavedLook> looks;
  final ValueChanged<SavedLook> onWear;
  final ValueChanged<SavedLook> onDelete;
  final ValueChanged<SavedLook> onToday;
  final ValueChanged<SavedLook> onEdit;
  final ValueChanged<SavedLook> onRename;
  final ValueChanged<SavedLook> onSchedule;
  final ValueChanged<SavedLook> onShare;
  final String? todayName;
  const _SavedLooksSheet({
    required this.looks,
    required this.onWear,
    required this.onDelete,
    required this.onToday,
    required this.onEdit,
    required this.onRename,
    required this.onSchedule,
    required this.onShare,
    required this.todayName,
  });

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.78,
    ),
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
    decoration: const BoxDecoration(
      color: AppTheme.bg,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.divider,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Text(
                '我的搭配',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${looks.length} 套',
              style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (looks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Icon(
                  Icons.collections_bookmark_outlined,
                  size: 42,
                  color: AppTheme.inkSoft,
                ),
                SizedBox(height: 12),
                Text('还没有保存搭配', style: TextStyle(color: AppTheme.inkSoft)),
              ],
            ),
          )
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: looks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final look = looks[index];
                return Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    look.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (todayName == look.name) ...[
                                  const SizedBox(width: 7),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0EBE3),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: const Text(
                                      '今日',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.accentDeep,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: '更多',
                            icon: const Icon(Icons.more_horiz_rounded),
                            onSelected: (value) {
                              switch (value) {
                                case 'edit':
                                  onEdit(look);
                                case 'rename':
                                  onRename(look);
                                case 'schedule':
                                  onSchedule(look);
                                case 'share':
                                  onShare(look);
                                case 'delete':
                                  onDelete(look);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text('编辑搭配'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'rename',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.drive_file_rename_outline,
                                  ),
                                  title: Text('修改名称'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'schedule',
                                child: ListTile(
                                  leading: Icon(Icons.calendar_month_outlined),
                                  title: Text('安排日期'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'share',
                                child: ListTile(
                                  leading: Icon(Icons.ios_share_rounded),
                                  title: Text('分享搭配卡'),
                                ),
                              ),
                              PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
                                  ),
                                  title: Text('删除'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          for (final item
                              in look.outfit.pieces.whereType<ClothingItem>())
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 5),
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: _SavedPieceImage(item: item),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: look.isAvailable
                                  ? () => onToday(look)
                                  : null,
                              icon: const Icon(Icons.today_rounded, size: 17),
                              label: Text(
                                todayName == look.name ? '今日穿搭' : '设为今日',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: look.isAvailable
                                  ? () => onWear(look)
                                  : null,
                              icon: const Icon(
                                Icons.checkroom_rounded,
                                size: 17,
                              ),
                              label: const Text('一键穿上'),
                            ),
                          ),
                        ],
                      ),
                      if (!look.isAvailable)
                        const Padding(
                          padding: EdgeInsets.only(top: 7),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '其中一件个人衣物已被删除',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    ),
  );
}

class _SavedPieceImage extends StatelessWidget {
  final ClothingItem item;
  const _SavedPieceImage({required this.item});

  @override
  Widget build(BuildContext context) {
    Widget fallback(_, _, _) => const ColoredBox(
      color: Color(0xFFF1EFEA),
      child: Icon(Icons.image_not_supported_outlined, color: AppTheme.inkSoft),
    );
    return item.style.isLocalFile
        ? Image.file(
            File(item.assetPath),
            fit: BoxFit.cover,
            errorBuilder: fallback,
          )
        : Image.asset(
            item.assetPath,
            fit: BoxFit.cover,
            errorBuilder: fallback,
          );
  }
}

class _CompleteOutfitButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CompleteOutfitButton({required this.onTap});

  @override
  State<_CompleteOutfitButton> createState() => _CompleteOutfitButtonState();
}

class _TodayOutfitButton extends StatelessWidget {
  final VoidCallback onTap;
  const _TodayOutfitButton({required this.onTap});

  @override
  Widget build(BuildContext context) => AppPressable(
    semanticLabel: '将当前搭配设为今日穿搭',
    scale: .96,
    onTap: onTap,
    child: Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE4ECE6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD2E0D7)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.today_rounded, size: 16, color: AppTheme.accentDeep),
          SizedBox(width: 5),
          Text(
            '设为今日',
            style: TextStyle(
              color: AppTheme.accentDeep,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CompleteOutfitButtonState extends State<_CompleteOutfitButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: pressed ? 0.96 : 1,
    duration: const Duration(milliseconds: 120),
    curve: Curves.easeOutCubic,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => pressed = true),
      onTapCancel: () => setState(() => pressed = false),
      onTapUp: (_) {
        setState(() => pressed = false);
        widget.onTap();
      },
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF789687), Color(0xFF9CB5A7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x66FFFFFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x376E8C7C),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0x30FFFFFF),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(3),
                child: Icon(
                  Icons.bookmark_add_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 6),
            Text(
              '保存搭配',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PartPickerTile extends StatelessWidget {
  final ClothingCategory category;
  final ClothingItem? item;
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
  Widget build(BuildContext context) => AppPressable(
    semanticLabel: '更换${category.label}',
    scale: .975,
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
                  style: const TextStyle(fontSize: 11, color: AppTheme.inkSoft),
                ),
                Text(
                  item == null ? '无' : '${item!.colorName}${item!.style.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: item == null ? AppTheme.inkSoft : AppTheme.ink,
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
