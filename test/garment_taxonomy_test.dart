import 'package:dressfit_app/models.dart';
import 'package:dressfit_app/saved_look.dart';
import 'package:dressfit_app/wardrobe_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses one complete color material and style taxonomy', () {
    expect(colorOptions, hasLength(18));
    expect(GarmentMaterial.values, hasLength(14));
    expect(
      GarmentTaxonomy.styleNames.values.expand((values) => values),
      hasLength(76),
    );
  });

  test('every system garment uses a canonical style name', () {
    for (final style in clothingStyles) {
      expect(
        GarmentTaxonomy.styleNamesFor(style.category),
        contains(style.name),
        reason: '${style.category.name}: ${style.name}',
      );
    }
  });

  test('legacy labels migrate without losing duplicate suffixes', () {
    expect(
      GarmentTaxonomy.canonicalStyleName(ClothingCategory.top, 'T 恤 2'),
      '圆领T恤 2',
    );
    expect(
      GarmentTaxonomy.canonicalStyleName(ClothingCategory.shoes, '运动鞋'),
      '复古运动鞋',
    );
    expect(GarmentTaxonomy.colorByName('藏青').name, '海军蓝');
    expect(GarmentTaxonomy.materialByValue('涤纶'), GarmentMaterial.polyester);
  });

  test('legacy wardrobe json is normalized on read', () {
    final garment = UserGarment.fromJson({
      'path': 'legacy.png',
      'category': 'bottom',
      'styleName': '休闲裤 1',
      'color': '深蓝',
      'material': '涤纶',
    });
    expect(garment.styleName, '卡其裤 1');
    expect(garment.color.name, '海军蓝');
    expect(garment.material, GarmentMaterial.polyester);
  });

  test('outfit parts can be intentionally left empty', () {
    final outfit = customOutfit()
        .withoutPiece(ClothingCategory.hat)
        .withoutPiece(ClothingCategory.bottom);
    expect(outfit.hat, isNull);
    expect(outfit.bottom, isNull);
    expect(outfit.top, isNotNull);
    expect(outfit.pieces.whereType<ClothingItem>(), hasLength(2));
  });

  test('partial saved looks keep empty slots when restored', () {
    final source = SavedLook(
      '轻装出门',
      customOutfit()
          .withoutPiece(ClothingCategory.hat)
          .withoutPiece(ClothingCategory.bottom),
    );
    final restored = SavedLook.fromJson(source.toJson());
    expect(restored.outfit.hat, isNull);
    expect(restored.outfit.bottom, isNull);
    expect(restored.outfit.top, isNotNull);
    expect(restored.outfit.shoes, isNotNull);
  });
}
