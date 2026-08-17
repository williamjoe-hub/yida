import 'dart:ui';

import 'package:dressfit_app/models.dart';
import 'package:dressfit_app/outfit_recommendation_service.dart';
import 'package:dressfit_app/profile_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generates exactly 960 complete seasonal outfits', () {
    for (final gender in UserGender.values) {
      for (final season in OutfitSeason.values) {
        final outfits = OutfitRecommendationService.forSeason(
          season,
          gender: gender,
        );
        expect(
          outfits.length,
          season.targetCount,
          reason: '${gender.label}${season.label}',
        );
        expect(
          outfits.every(
            (outfit) => outfit.pieces.whereType<ClothingItem>().length == 4,
          ),
          isTrue,
        );
      }
      expect(OutfitRecommendationService.totalCount(gender), 960);
    }
  });

  test('male recommendations exclude every skirt', () {
    for (final season in OutfitSeason.values) {
      expect(
        OutfitRecommendationService.forSeason(
          season,
          gender: UserGender.male,
        ).every((outfit) => !outfit.bottom!.style.name.contains('裙')),
        isTrue,
      );
    }
  });

  test('female recommendations retain skirt options', () {
    expect(
      OutfitRecommendationService.forSeason(
        OutfitSeason.summer,
        gender: UserGender.female,
      ).any((outfit) => outfit.bottom!.style.name.contains('裙')),
      isTrue,
    );
  });

  test('winter outfits avoid sandals and summer outfits avoid boots', () {
    expect(
      OutfitRecommendationService.forSeason(
        OutfitSeason.winter,
      ).every((outfit) => !outfit.shoes!.style.name.contains('凉鞋')),
      isTrue,
    );
    expect(
      OutfitRecommendationService.forSeason(
        OutfitSeason.summer,
      ).every((outfit) => !outfit.shoes!.style.name.contains('短靴')),
      isTrue,
    );
  });

  test(
    'my wardrobe recommendations keep owned pieces and fill missing parts',
    () {
      const userTopStyle = ClothingStyle(
        id: 'user_top',
        name: '卫衣',
        category: ClothingCategory.top,
        material: GarmentMaterial.cotton,
        assetPath: 'test-user-top.png',
        baseColor: ColorOption('黑色', Color(0xFF292A2C)),
        isLocalFile: true,
      );
      const userTop = ClothingItem(
        id: 'user_top',
        style: userTopStyle,
        tone: ColorOption('黑色', Color(0xFF292A2C)),
      );
      final outfits = OutfitRecommendationService.fromMyWardrobe(
        userItems: const [userTop],
        systemOutfits: OutfitRecommendationService.forSeason(
          OutfitSeason.autumn,
        ),
        season: OutfitSeason.autumn,
        gender: UserGender.male,
      );
      expect(outfits, isNotEmpty);
      expect(outfits.every((outfit) => outfit.top!.style.isLocalFile), isTrue);
      expect(
        outfits.every((outfit) => !outfit.shoes!.style.isLocalFile),
        isTrue,
      );
    },
  );

  test('inspiration is ranked using wardrobe colors and materials', () {
    const userStyle = ClothingStyle(
      id: 'user_denim',
      name: '牛仔夹克',
      category: ClothingCategory.top,
      material: GarmentMaterial.denim,
      assetPath: 'test-user-denim.png',
      baseColor: ColorOption('蓝色', Color(0xFF527DA5)),
      isLocalFile: true,
    );
    const userItem = ClothingItem(
      id: 'user_denim',
      style: userStyle,
      tone: ColorOption('蓝色', Color(0xFF527DA5)),
    );
    final ranked = OutfitRecommendationService.inspirationForWardrobe(
      OutfitRecommendationService.forSeason(OutfitSeason.autumn),
      const [userItem],
    );
    expect(ranked, isNotEmpty);
    expect(
      ranked.first.pieces.whereType<ClothingItem>().any(
        (item) =>
            item.colorName == '蓝色' ||
            item.style.material == GarmentMaterial.denim,
      ),
      isTrue,
    );
  });
}
