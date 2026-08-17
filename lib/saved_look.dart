import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'models.dart';

class SavedLook {
  final String name;
  final Outfit outfit;
  const SavedLook(this.name, this.outfit);

  SavedLook renamed(String value) => SavedLook(
    value,
    Outfit(
      name: value,
      vibe: outfit.vibe,
      matchScore: outfit.matchScore,
      hat: outfit.hat,
      top: outfit.top,
      bottom: outfit.bottom,
      shoes: outfit.shoes,
    ),
  );

  bool get isAvailable => outfit.pieces.whereType<ClothingItem>().every(
    (item) => !item.style.isLocalFile || File(item.assetPath).existsSync(),
  );

  Map<String, dynamic> toJson() => {
    'taxonomyVersion': 2,
    'name': name,
    'pieces': outfit.pieces
        .whereType<ClothingItem>()
        .map(
          (item) => {
            'id': item.id,
            'styleName': item.style.name,
            'category': item.category.name,
            'material': item.style.material.name,
            'assetPath': item.assetPath,
            'colorName': item.style.baseColor.name,
            'colorValue': item.style.baseColor.color.toARGB32(),
            'isLocalFile': item.style.isLocalFile,
          },
        )
        .toList(),
  };

  factory SavedLook.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    final items = (json['pieces'] as List<dynamic>)
        .map((value) => _itemFromJson(value as Map<String, dynamic>))
        .toList();
    ClothingItem? piece(ClothingCategory category) {
      for (final item in items) {
        if (item.category == category) return item;
      }
      return null;
    }

    return SavedLook(
      name,
      Outfit(
        name: name,
        vibe: '我的搭配',
        matchScore: 100,
        hat: piece(ClothingCategory.hat),
        top: piece(ClothingCategory.top),
        bottom: piece(ClothingCategory.bottom),
        shoes: piece(ClothingCategory.shoes),
      ),
    );
  }

  static ClothingItem _itemFromJson(Map<String, dynamic> json) {
    final category = ClothingCategory.values.firstWhere(
      (value) => value.name == json['category'],
    );
    final material = GarmentTaxonomy.materialByValue(
      json['material'] as String?,
    );
    final color = GarmentTaxonomy.colorByName(json['colorName'] as String?);
    final style = ClothingStyle(
      id: json['id'] as String,
      name: GarmentTaxonomy.canonicalStyleName(
        category,
        json['styleName'] as String,
      ),
      category: category,
      material: material,
      assetPath: json['assetPath'] as String,
      baseColor: color,
      isLocalFile: json['isLocalFile'] as bool? ?? false,
    );
    return ClothingItem(id: style.id, style: style, tone: color);
  }
}

class SavedLookStore {
  static Future<File> _file(String name) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$name');
  }

  static Future<List<SavedLook>> loadLooks() async {
    try {
      final file = await _file('saved_outfits.json');
      if (!await file.exists()) return [];
      final values = jsonDecode(await file.readAsString()) as List<dynamic>;
      final looks = values
          .map((value) => SavedLook.fromJson(value as Map<String, dynamic>))
          .where(
            (value) => value.outfit.pieces.whereType<ClothingItem>().isNotEmpty,
          )
          .toList();
      if (values.any(
        (value) => (value as Map<String, dynamic>)['taxonomyVersion'] != 2,
      )) {
        await saveLooks(looks);
      }
      return looks;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveLooks(List<SavedLook> looks) async {
    final file = await _file('saved_outfits.json');
    await file.writeAsString(jsonEncode(looks.map((e) => e.toJson()).toList()));
  }

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static Future<Map<String, String>> loadSchedule() async {
    try {
      final file = await _file('outfit_schedule.json');
      if (!await file.exists()) return {};
      final value =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return value.map((key, value) => MapEntry(key, value as String));
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveSchedule(Map<String, String> schedule) async {
    final file = await _file('outfit_schedule.json');
    await file.writeAsString(jsonEncode(schedule));
  }

  static Future<Map<String, SavedLook>> loadDirectSchedule() async {
    try {
      final file = await _file('direct_outfit_schedule.json');
      if (!await file.exists()) return {};
      final value =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return value.map(
        (key, look) => MapEntry(
          key,
          SavedLook.fromJson(look as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveDirectSchedule(
    Map<String, SavedLook> schedule,
  ) async {
    final file = await _file('direct_outfit_schedule.json');
    await file.writeAsString(
      jsonEncode(schedule.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }
}
