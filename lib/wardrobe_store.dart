import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'models.dart';

class UserGarment {
  final String path;
  final ClothingCategory category;
  final String styleName;
  final ColorOption color;
  final GarmentMaterial material;

  const UserGarment(
    this.path,
    this.category,
    this.styleName,
    this.color,
    this.material,
  );

  ClothingStyle get style => ClothingStyle(
    id: 'user_${path.hashCode}',
    name: styleName,
    category: category,
    material: material,
    assetPath: path,
    baseColor: color,
    isLocalFile: true,
  );

  ClothingItem get item =>
      ClothingItem(id: style.id, style: style, tone: color);

  Map<String, dynamic> toJson() => {
    'path': path,
    'category': category.name,
    'styleName': styleName,
    'color': color.name,
    'material': material.name,
  };

  factory UserGarment.fromJson(Map<String, dynamic> json) {
    final category = ClothingCategory.values.firstWhere(
      (item) => item.name == json['category'],
      orElse: () => ClothingCategory.top,
    );
    final color = GarmentTaxonomy.colorByName(json['color'] as String?);
    final material = GarmentTaxonomy.materialByValue(
      json['material'] as String?,
    );
    return UserGarment(
      json['path'] as String,
      category,
      GarmentTaxonomy.canonicalStyleName(category, json['styleName'] as String),
      color,
      material,
    );
  }
}

class WardrobeStore {
  WardrobeStore._();

  static Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/wardrobe.json');
  }

  static Future<List<UserGarment>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final garments = (data['garments'] as List<dynamic>? ?? [])
          .map((item) => UserGarment.fromJson(item as Map<String, dynamic>))
          .where((item) => File(item.path).existsSync())
          .toList(growable: false);
      if (data['schemaVersion'] != 2) {
        await file.writeAsString(
          jsonEncode({
            'schemaVersion': 2,
            'garments': garments.map((item) => item.toJson()).toList(),
          }),
        );
      }
      return garments;
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<UserGarment> garments) async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode({
        'schemaVersion': 2,
        'garments': garments.map((item) => item.toJson()).toList(),
      }),
    );
  }
}
