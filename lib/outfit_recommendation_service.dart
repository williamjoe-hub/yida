import 'models.dart';
import 'profile_settings.dart';
import 'weather_service.dart';

enum OutfitSeason {
  spring('春季', 220),
  summer('夏季', 220),
  autumn('秋季', 240),
  winter('冬季', 280);

  final String label;
  final int targetCount;
  const OutfitSeason(this.label, this.targetCount);
}

enum RecommendationSource {
  inspiration('搭配灵感'),
  mine('我的衣服');

  final String label;
  const RecommendationSource(this.label);
}

class OutfitRecommendationService {
  OutfitRecommendationService._();

  static final Map<(OutfitSeason, UserGender), List<Outfit>> _cache = {};

  static OutfitSeason currentSeason(WeatherSnapshot? weather) {
    final temperature = weather?.temperature;
    if (temperature != null) {
      if (temperature <= 9) return OutfitSeason.winter;
      if (temperature >= 27) return OutfitSeason.summer;
      if (temperature <= 18) {
        return DateTime.now().month <= 5
            ? OutfitSeason.spring
            : OutfitSeason.autumn;
      }
    }
    return switch (DateTime.now().month) {
      3 || 4 || 5 => OutfitSeason.spring,
      6 || 7 || 8 => OutfitSeason.summer,
      9 || 10 || 11 => OutfitSeason.autumn,
      _ => OutfitSeason.winter,
    };
  }

  static List<Outfit> forSeason(
    OutfitSeason season, {
    UserGender gender = UserGender.male,
  }) => _cache.putIfAbsent((season, gender), () => _generate(season, gender));

  static int totalCount(UserGender gender) => OutfitSeason.values.fold(
    0,
    (sum, season) => sum + forSeason(season, gender: gender).length,
  );

  static List<Outfit> inspirationForWardrobe(
    List<Outfit> systemOutfits,
    List<ClothingItem> userItems,
  ) {
    if (userItems.isEmpty) return List.of(systemOutfits);
    final colors = userItems.map((item) => item.colorName).toSet();
    final materials = userItems.map((item) => item.style.material).toSet();
    final subcategories = userItems
        .map((item) => clothingSubcategory(item.category, item.style.name))
        .toSet();
    final indexed = systemOutfits.indexed.toList();
    indexed.sort((a, b) {
      int score(Outfit outfit) => outfit.pieces.whereType<ClothingItem>().fold(
        0,
        (sum, item) {
          final colorScore = colors.contains(item.colorName)
              ? 5
              : _neutralColors.contains(item.colorName)
              ? 1
              : 0;
          final materialScore = materials.contains(item.style.material) ? 3 : 0;
          final styleScore =
              subcategories.contains(
                clothingSubcategory(item.category, item.style.name),
              )
              ? 4
              : 0;
          return sum + colorScore + materialScore + styleScore;
        },
      );

      final difference = score(b.$2).compareTo(score(a.$2));
      return difference != 0 ? difference : a.$1.compareTo(b.$1);
    });
    return indexed.map((entry) => entry.$2).toList(growable: false);
  }

  static List<Outfit> fromMyWardrobe({
    required List<ClothingItem> userItems,
    required List<Outfit> systemOutfits,
    required OutfitSeason season,
    required UserGender gender,
    int count = 24,
  }) {
    if (userItems.isEmpty || systemOutfits.isEmpty) return [];
    final usable = userItems
        .where((item) => _itemFits(item, season, gender))
        .toList(growable: false);
    if (usable.isEmpty) return [];
    final grouped = <ClothingCategory, List<ClothingItem>>{
      for (final category in ClothingCategory.values)
        category: usable.where((item) => item.category == category).toList(),
    };
    final result = <Outfit>[];
    final seen = <String>{};
    for (
      var index = 0;
      index < systemOutfits.length && result.length < count;
      index++
    ) {
      final base = systemOutfits[index];
      ClothingItem choose(ClothingCategory category, ClothingItem fallback) {
        final candidates = grouped[category]!;
        if (candidates.isEmpty) return fallback;
        final ranked = [...candidates]
          ..sort(
            (a, b) => _pieceAffinity(
              b,
              fallback,
            ).compareTo(_pieceAffinity(a, fallback)),
          );
        return ranked[(index ~/ 2 + category.index) % ranked.length];
      }

      final hat = choose(ClothingCategory.hat, base.hat!);
      final top = choose(ClothingCategory.top, base.top!);
      final bottom = choose(ClothingCategory.bottom, base.bottom!);
      final shoes = choose(ClothingCategory.shoes, base.shoes!);
      final pieces = [hat, top, bottom, shoes];
      final key = pieces.map((item) => item.id).join('|');
      if (!seen.add(key)) continue;
      final ownCount = pieces.where((item) => item.style.isLocalFile).length;
      result.add(
        Outfit(
          name: base.name,
          vibe: ownCount == 4 ? '全部来自我的衣橱' : '$ownCount件我的衣服 · 系统补齐',
          matchScore: base.matchScore,
          hat: hat,
          top: top,
          bottom: bottom,
          shoes: shoes,
        ),
      );
    }
    return result;
  }

  static const _neutralColors = {'白色', '黑色', '灰色', '米色', '棕色'};

  static int _pieceAffinity(ClothingItem item, ClothingItem reference) {
    var score = 0;
    if (item.colorName == reference.colorName) score += 6;
    if (_neutralColors.contains(item.colorName)) score += 2;
    if (item.style.material == reference.style.material) score += 3;
    if (clothingSubcategory(item.category, item.style.name) ==
        clothingSubcategory(reference.category, reference.style.name)) {
      score += 4;
    }
    return score;
  }

  static bool _itemFits(
    ClothingItem item,
    OutfitSeason season,
    UserGender gender,
  ) => switch (item.category) {
    ClothingCategory.hat => _hatFits(item, season),
    ClothingCategory.top => _topFits(item, season),
    ClothingCategory.bottom => _bottomFits(item, season, gender),
    ClothingCategory.shoes => _shoeFits(item, season),
  };

  static List<Outfit> _generate(OutfitSeason season, UserGender gender) {
    final hats = _items(
      ClothingCategory.hat,
    ).where((item) => _hatFits(item, season)).toList();
    final tops = _items(
      ClothingCategory.top,
    ).where((item) => _topFits(item, season)).toList();
    final bottoms = _items(
      ClothingCategory.bottom,
    ).where((item) => _bottomFits(item, season, gender)).toList();
    final shoes = _items(
      ClothingCategory.shoes,
    ).where((item) => _shoeFits(item, season)).toList();
    final result = <Outfit>[];
    final seen = <String>{};
    var attempt = 0;
    var randomState = 0x13579B + season.index * 0x2468AC;
    int nextIndex(int length) {
      randomState ^= (randomState << 13) & 0x7fffffff;
      randomState ^= randomState >> 17;
      randomState ^= (randomState << 5) & 0x7fffffff;
      randomState &= 0x7fffffff;
      return randomState % length;
    }

    while (result.length < season.targetCount && attempt < 20000) {
      final hat = hats[nextIndex(hats.length)];
      final top = tops[nextIndex(tops.length)];
      final bottom = bottoms[nextIndex(bottoms.length)];
      final shoe = shoes[nextIndex(shoes.length)];
      attempt++;
      final pieces = [hat, top, bottom, shoe];
      if (!_colorsWork(pieces)) continue;
      final key = pieces.map((item) => item.id).join('|');
      if (!seen.add(key)) continue;
      final theme = _themes(season)[result.length % _themes(season).length];
      result.add(
        Outfit(
          name: theme.$1,
          vibe: theme.$2,
          matchScore: 88 + (result.length * 7) % 11,
          hat: hat,
          top: top,
          bottom: bottom,
          shoes: shoe,
        ),
      );
    }
    return List.unmodifiable(result);
  }

  static List<ClothingItem> _items(ClothingCategory category) => clothingStyles
      .where((style) => style.category == category)
      .map(
        (style) =>
            ClothingItem(id: style.id, style: style, tone: style.baseColor),
      )
      .toList(growable: false);

  static bool _hatFits(ClothingItem item, OutfitSeason season) {
    final name = item.style.name;
    return switch (season) {
      OutfitSeason.summer => RegExp(r'棒球帽|弯檐帽|网眼帽|渔夫帽|空顶帽').hasMatch(name),
      OutfitSeason.winter => RegExp(r'针织帽|贝雷帽|报童帽|棒球帽').hasMatch(name),
      _ => !name.contains('空顶帽'),
    };
  }

  static bool _topFits(ClothingItem item, OutfitSeason season) {
    final name = item.style.name;
    return switch (season) {
      OutfitSeason.spring => RegExp(
        r'T恤|Polo|衬衫|卫衣|开衫|马甲|夹克|西装|外套',
      ).hasMatch(name),
      OutfitSeason.summer => RegExp(
        r'T恤|背心|Polo|亚麻衬衫|牛津衬衫|亨利领|球衣|垂感衬衫',
      ).hasMatch(name),
      OutfitSeason.autumn => RegExp(
        r'衬衫|卫衣|毛衣|针织|高领|夹克|西装|外套|风衣|大衣|抓绒',
      ).hasMatch(name),
      OutfitSeason.winter => RegExp(r'毛衣|针织|高领|羽绒|大衣|抓绒|风衣|夹克').hasMatch(name),
    };
  }

  static bool _bottomFits(
    ClothingItem item,
    OutfitSeason season,
    UserGender gender,
  ) {
    final name = item.style.name;
    if (gender == UserGender.male && name.contains('裙')) return false;
    return switch (season) {
      OutfitSeason.summer => RegExp(r'短裤|裙|亚麻长裤|阔腿西裤|连体裤').hasMatch(name),
      OutfitSeason.winter => !RegExp(r'短裤|短裙|凉爽|亚麻').hasMatch(name),
      _ => !name.contains('连衣裙') || season == OutfitSeason.spring,
    };
  }

  static bool _shoeFits(ClothingItem item, OutfitSeason season) {
    final name = item.style.name;
    return switch (season) {
      OutfitSeason.summer => !name.contains('短靴'),
      OutfitSeason.winter => !name.contains('凉鞋'),
      _ => true,
    };
  }

  static bool _colorsWork(List<ClothingItem> pieces) {
    final colors = pieces.map((item) => item.colorName).toSet();
    if (colors.length <= 2) return true;
    if (colors.length == 3) {
      return colors.contains('白色') ||
          colors.contains('黑色') ||
          colors.contains('灰色') ||
          colors.contains('米色');
    }
    return false;
  }

  static List<(String, String)> _themes(OutfitSeason season) =>
      switch (season) {
        OutfitSeason.spring => const [
          ('春季上课', '适合校园'),
          ('春季通勤', '适合通勤'),
          ('春季日常', '适合日常'),
          ('春季休闲', '适合休闲'),
          ('春季运动', '适合运动'),
        ],
        OutfitSeason.summer => const [
          ('夏季日常', '适合日常'),
          ('夏季上课', '适合校园'),
          ('夏季休闲', '适合休闲'),
          ('夏季运动', '适合运动'),
          ('夏季通勤', '适合通勤'),
        ],
        OutfitSeason.autumn => const [
          ('秋季日常', '适合日常'),
          ('秋季休闲', '适合休闲'),
          ('秋季通勤', '适合通勤'),
          ('秋季上课', '适合校园'),
          ('秋季运动', '适合运动'),
        ],
        OutfitSeason.winter => const [
          ('冬季保暖', '适合低温'),
          ('冬季上课', '适合校园'),
          ('冬季日常', '适合日常'),
          ('冬季休闲', '适合休闲'),
          ('冬季通勤', '适合通勤'),
          ('冬季运动', '适合运动'),
        ],
      };
}
