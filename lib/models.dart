import 'dart:ui';

import 'generated_catalog_data.dart';

enum ClothingCategory {
  hat('帽子'),
  top('上衣'),
  bottom('下装'),
  shoes('鞋子');

  final String label;
  const ClothingCategory(this.label);
}

enum GarmentMaterial {
  cotton('棉质'),
  denim('牛仔'),
  leather('皮革'),
  knit('针织'),
  canvas('帆布'),
  blend('混纺'),
  wool('羊毛'),
  nylon('尼龙'),
  linen('亚麻'),
  polyester('聚酯纤维'),
  fleece('抓绒'),
  corduroy('灯芯绒'),
  mesh('网布'),
  suede('麂皮');

  final String label;
  const GarmentMaterial(this.label);
}

String clothingSubcategory(ClothingCategory category, String styleName) {
  final name = styleName.replaceFirst(RegExp(r' \d+$'), '');
  return switch (category) {
    ClothingCategory.hat =>
      name.contains('棒球帽') ||
              name.contains('弯檐帽') ||
              name.contains('网眼帽') ||
              name.contains('空顶帽')
          ? '运动帽'
          : name.contains('渔夫帽') ||
                name.contains('针织帽') ||
                name.contains('贝雷帽') ||
                name.contains('报童帽')
          ? '软帽'
          : '其他帽型',
    ClothingCategory.top =>
      name.contains('T恤') || name.contains('背心')
          ? 'T恤与背心'
          : name.contains('衬衫') ||
                name.contains('Polo') ||
                name.contains('亨利领') ||
                name.contains('垂感')
          ? '衬衫与有领上衣'
          : name.contains('卫衣')
          ? '卫衣'
          : name.contains('毛衣') || name.contains('针织') || name.contains('高领')
          ? '针织衫'
          : name.contains('球衣') || name.contains('橄榄球') || name.contains('运动')
          ? '运动上衣'
          : name.contains('风衣') || name.contains('大衣') || name.contains('羽绒')
          ? '长款与保暖外套'
          : name.contains('夹克') || name.contains('西装') || name.contains('外套')
          ? '夹克与短外套'
          : '其他上衣',
    ClothingCategory.bottom =>
      name.contains('牛仔裤')
          ? '牛仔长裤'
          : name.contains('西裤') || name.contains('卡其裤') || name.contains('亚麻长裤')
          ? '休闲与西裤'
          : name.contains('工装') ||
                name.contains('运动长裤') ||
                name.contains('束脚') ||
                name.contains('降落伞') ||
                name.contains('灯芯绒裤')
          ? '工装与运动长裤'
          : name.contains('短裤')
          ? '短裤'
          : name.contains('裙') || name.contains('背带裤') || name.contains('连体裤')
          ? '裙装与连体'
          : '其他下装',
    ClothingCategory.shoes =>
      name.contains('板鞋') ||
              name.contains('帆布鞋') ||
              name.contains('跑鞋') ||
              name.contains('运动鞋')
          ? '运动鞋'
          : name.contains('乐福鞋') || name.contains('德比鞋')
          ? '休闲皮鞋'
          : name.contains('靴') || name.contains('凉鞋')
          ? '靴子与凉鞋'
          : '其他鞋款',
  };
}

class ClothingStyle {
  final String id;
  final String name;
  final ClothingCategory category;
  final GarmentMaterial material;
  final String assetPath;
  final ColorOption baseColor;
  final bool isLocalFile;
  const ClothingStyle({
    required this.id,
    required this.name,
    required this.category,
    required this.material,
    required this.assetPath,
    required this.baseColor,
    this.isLocalFile = false,
  });
}

class ColorOption {
  final String name;
  final Color color;
  const ColorOption(this.name, this.color);
}

const colorOptions = <ColorOption>[
  ColorOption('白色', Color(0xFFF0EFEA)),
  ColorOption('黑色', Color(0xFF292A2C)),
  ColorOption('灰色', Color(0xFFA7A8A5)),
  ColorOption('深灰', Color(0xFF55585C)),
  ColorOption('米色', Color(0xFFD8C7AA)),
  ColorOption('卡其', Color(0xFFB49A70)),
  ColorOption('棕色', Color(0xFF80533B)),
  ColorOption('海军蓝', Color(0xFF26354A)),
  ColorOption('蓝色', Color(0xFF527DA5)),
  ColorOption('浅蓝', Color(0xFFAEC6D8)),
  ColorOption('绿色', Color(0xFF82917D)),
  ColorOption('军绿', Color(0xFF59634A)),
  ColorOption('红色', Color(0xFFB95656)),
  ColorOption('酒红', Color(0xFF743D49)),
  ColorOption('粉色', Color(0xFFD89BA7)),
  ColorOption('紫色', Color(0xFF81749D)),
  ColorOption('黄色', Color(0xFFD2A84B)),
  ColorOption('橙色', Color(0xFFD68047)),
];

class GarmentTaxonomy {
  static const styleNames = <ClothingCategory, List<String>>{
    ClothingCategory.hat: [
      '棒球帽',
      '弯檐帽',
      '网眼帽',
      '渔夫帽',
      '针织帽',
      '贝雷帽',
      '报童帽',
      '空顶帽',
      '其他帽子',
    ],
    ClothingCategory.top: [
      '圆领T恤',
      '宽松T恤',
      '背心',
      'Polo衫',
      '亨利领上衣',
      '半高领上衣',
      '牛津衬衫',
      '亚麻衬衫',
      '法兰绒衬衫',
      '垂感衬衫',
      '圆领卫衣',
      '套头卫衣',
      '拉链卫衣',
      '圆领毛衣',
      'V领毛衣',
      '高领毛衣',
      '针织开衫',
      '针织马甲',
      '运动球衣',
      '橄榄球衫',
      '牛仔夹克',
      '棒球夹克',
      '飞行夹克',
      '工装夹克',
      '教练夹克',
      '运动夹克',
      '防风外套',
      '抓绒外套',
      '休闲西装',
      '风衣',
      '羊毛大衣',
      '羽绒服',
      '其他上衣',
    ],
    ClothingCategory.bottom: [
      '直筒牛仔裤',
      '修身牛仔裤',
      '阔腿牛仔裤',
      '卡其裤',
      '直筒西裤',
      '阔腿西裤',
      '亚麻长裤',
      '工装裤',
      '运动长裤',
      '束脚裤',
      '降落伞裤',
      '灯芯绒裤',
      '休闲短裤',
      '运动短裤',
      '牛仔短裤',
      '工装短裤',
      '百慕大短裤',
      '卫裤短裤',
      'A字裙',
      '百褶裙',
      '牛仔裙',
      '衬衫裙',
      '背带裤',
      '连体裤',
      '其他下装',
    ],
    ClothingCategory.shoes: [
      '厚底板鞋',
      '帆布鞋',
      '跑鞋',
      '复古运动鞋',
      '乐福鞋',
      '德比鞋',
      '短靴',
      '运动凉鞋',
      '其他鞋子',
    ],
  };

  static const _styleAliases = <String, String>{
    'T恤': '圆领T恤',
    '圆领T恤': '圆领T恤',
    '卫衣': '圆领卫衣',
    '衬衫': '牛津衬衫',
    '针织衫': '针织开衫',
    '毛衣': '圆领毛衣',
    '外套': '防风外套',
    '牛仔裤': '直筒牛仔裤',
    '休闲裤': '卡其裤',
    '短裤': '休闲短裤',
    '半身裙': 'A字裙',
    '运动鞋': '复古运动鞋',
    '板鞋': '厚底板鞋',
    '靴子': '短靴',
    '凉鞋': '运动凉鞋',
  };

  static List<String> styleNamesFor(ClothingCategory category) =>
      styleNames[category]!;

  static String canonicalStyleName(ClothingCategory category, String rawName) {
    final suffixMatch = RegExp(r' (\d+)$').firstMatch(rawName.trim());
    final suffix = suffixMatch == null ? '' : ' ${suffixMatch.group(1)}';
    final base = rawName
        .trim()
        .replaceFirst(RegExp(r' \d+$'), '')
        .replaceAll(' ', '');
    final candidates = styleNamesFor(category);
    for (final candidate in candidates) {
      if (candidate.replaceAll(' ', '') == base) return '$candidate$suffix';
    }
    final alias = _styleAliases[base];
    if (alias != null && candidates.contains(alias)) return '$alias$suffix';
    return '${candidates.last}$suffix';
  }

  static ColorOption colorByName(String? rawName) {
    final aliases = <String, String>{
      '白': '白色',
      '黑': '黑色',
      '灰': '灰色',
      '浅灰': '灰色',
      '深灰色': '深灰',
      '米白': '米色',
      '卡其色': '卡其',
      '棕': '棕色',
      '藏青': '海军蓝',
      '深蓝': '海军蓝',
      '浅蓝色': '浅蓝',
      '绿': '绿色',
      '橄榄绿': '军绿',
      '红': '红色',
      '酒红色': '酒红',
      '粉': '粉色',
      '紫': '紫色',
      '黄': '黄色',
      '橙': '橙色',
    };
    final name = aliases[rawName] ?? rawName;
    return colorOptions.firstWhere(
      (item) => item.name == name,
      orElse: () => colorOptions.first,
    );
  }

  static GarmentMaterial materialByValue(String? rawValue) {
    const aliases = <String, GarmentMaterial>{
      '棉': GarmentMaterial.cotton,
      '纯棉': GarmentMaterial.cotton,
      '牛仔布': GarmentMaterial.denim,
      '皮质': GarmentMaterial.leather,
      '毛线': GarmentMaterial.knit,
      '毛呢': GarmentMaterial.wool,
      '涤纶': GarmentMaterial.polyester,
      '聚酯': GarmentMaterial.polyester,
    };
    final aliased = aliases[rawValue];
    if (aliased != null) return aliased;
    return GarmentMaterial.values.firstWhere(
      (item) => item.name == rawValue || item.label == rawValue,
      orElse: () => GarmentMaterial.blend,
    );
  }
}

final clothingStyles = generatedCatalogData
    .map((data) {
      final sourceCategory = data['category']!;
      final category = switch (sourceCategory) {
        'hat' => ClothingCategory.hat,
        'top' || 'outer' => ClothingCategory.top,
        'bottom' || 'dress' => ClothingCategory.bottom,
        'shoes' => ClothingCategory.shoes,
        _ => ClothingCategory.top,
      };
      final material = GarmentMaterial.values.firstWhere(
        (value) => value.name == data['material'],
        orElse: () => GarmentMaterial.blend,
      );
      final color = colorOptions.firstWhere(
        (value) => value.name == _catalogColorName(data['color']!),
      );
      return ClothingStyle(
        id: data['id']!,
        name: GarmentTaxonomy.canonicalStyleName(category, data['name']!),
        category: category,
        material: material,
        assetPath: data['asset']!,
        baseColor: color,
      );
    })
    .toList(growable: false);

String _catalogColorName(String id) => switch (id) {
  'white' => '白色',
  'black' => '黑色',
  'beige' => '米色',
  'grey' => '灰色',
  'blue' => '蓝色',
  'brown' => '棕色',
  _ => '白色',
};

class ClothingItem {
  final String id;
  final ClothingStyle style;
  final ColorOption tone;
  const ClothingItem({
    required this.id,
    required this.style,
    required this.tone,
  });
  String get name => '${style.baseColor.name}${style.name}';
  String get colorName => style.baseColor.name;
  Color get color => style.baseColor.color;
  ClothingCategory get category => style.category;
  String get assetPath => style.assetPath;
}

ClothingStyle styleById(String id) =>
    clothingStyles.firstWhere((e) => e.id == id);
ClothingItem makeStyleItem(String id, int colorIndex) =>
    ClothingItem(id: id, style: styleById(id), tone: styleById(id).baseColor);

class Outfit {
  final String name;
  final String vibe;
  final int matchScore;
  final ClothingItem? hat, top, bottom, shoes;
  const Outfit({
    required this.name,
    required this.vibe,
    required this.matchScore,
    this.hat,
    this.top,
    this.bottom,
    this.shoes,
  });
  List<ClothingItem?> get pieces => [hat, top, bottom, shoes];
  ClothingItem? pieceFor(ClothingCategory c) => switch (c) {
    ClothingCategory.hat => hat,
    ClothingCategory.top => top,
    ClothingCategory.bottom => bottom,
    ClothingCategory.shoes => shoes,
  };
  Outfit withPiece(ClothingItem item) => Outfit(
    name: name,
    vibe: vibe,
    matchScore: matchScore,
    hat: item.category == ClothingCategory.hat ? item : hat,
    top: item.category == ClothingCategory.top ? item : top,
    bottom: item.category == ClothingCategory.bottom ? item : bottom,
    shoes: item.category == ClothingCategory.shoes ? item : shoes,
  );
  Outfit withoutPiece(ClothingCategory category) => Outfit(
    name: name,
    vibe: vibe,
    matchScore: matchScore,
    hat: category == ClothingCategory.hat ? null : hat,
    top: category == ClothingCategory.top ? null : top,
    bottom: category == ClothingCategory.bottom ? null : bottom,
    shoes: category == ClothingCategory.shoes ? null : shoes,
  );
}

Outfit customOutfit() => Outfit(
  name: '清爽校园',
  vibe: '轻松自然',
  matchScore: 94,
  hat: makeStyleItem('baseball_cap_black', 1),
  top: makeStyleItem('crew_tee_white', 0),
  bottom: makeStyleItem('wide_jeans_blue', 2),
  shoes: makeStyleItem('platform_sneaker_white', 0),
);
final recommendedOutfits = <Outfit>[
  customOutfit(),
  Outfit(
    name: '雨天轻机能',
    vibe: '防水耐脏',
    matchScore: 96,
    hat: makeStyleItem('bucket_hat_black', 0),
    top: makeStyleItem('windbreaker_blue', 0),
    bottom: makeStyleItem('cargo_pants_black', 0),
    shoes: makeStyleItem('running_shoe_black', 0),
  ),
  Outfit(
    name: '轻透夏日',
    vibe: '宽松透气',
    matchScore: 95,
    hat: makeStyleItem('visor_beige', 0),
    top: makeStyleItem('linen_shirt_white', 0),
    bottom: makeStyleItem('linen_pants_beige', 0),
    shoes: makeStyleItem('sport_sandal_brown', 0),
  ),
  Outfit(
    name: '运动学院',
    vibe: '活力轻便',
    matchScore: 93,
    hat: makeStyleItem('baseball_cap_blue', 0),
    top: makeStyleItem('jersey_white', 0),
    bottom: makeStyleItem('track_pants_grey', 0),
    shoes: makeStyleItem('retro_trainer_blue', 0),
  ),
  Outfit(
    name: '黑灰极简',
    vibe: '利落克制',
    matchScore: 92,
    hat: makeStyleItem('dad_cap_grey', 0),
    top: makeStyleItem('polo_black', 0),
    bottom: makeStyleItem('straight_trousers_grey', 0),
    shoes: makeStyleItem('loafer_black', 0),
  ),
  Outfit(
    name: '自然大地',
    vibe: '温和松弛',
    matchScore: 91,
    hat: makeStyleItem('bucket_hat_brown', 0),
    top: makeStyleItem('oversized_tee_beige', 0),
    bottom: makeStyleItem('cargo_pants_brown', 0),
    shoes: makeStyleItem('canvas_sneaker_beige', 0),
  ),
  Outfit(
    name: '复古牛仔',
    vibe: '经典耐看',
    matchScore: 94,
    hat: makeStyleItem('trucker_cap_blue', 0),
    top: makeStyleItem('denim_jacket_blue', 0),
    bottom: makeStyleItem('straight_jeans_blue', 0),
    shoes: makeStyleItem('canvas_sneaker_white', 0),
  ),
  Outfit(
    name: '城市通勤',
    vibe: '干净利落',
    matchScore: 93,
    hat: makeStyleItem('beret_black', 0),
    top: makeStyleItem('blazer_grey', 0),
    bottom: makeStyleItem('straight_trousers_black', 0),
    shoes: makeStyleItem('derby_black', 0),
  ),
  Outfit(
    name: '宽松松弛',
    vibe: '舒适有型',
    matchScore: 92,
    hat: makeStyleItem('dad_cap_beige', 0),
    top: makeStyleItem('crew_tee_grey', 0),
    bottom: makeStyleItem('wide_trousers_black', 0),
    shoes: makeStyleItem('platform_sneaker_white', 0),
  ),
  Outfit(
    name: '海边轻旅',
    vibe: '清凉自在',
    matchScore: 95,
    hat: makeStyleItem('bucket_hat_white', 0),
    top: makeStyleItem('linen_shirt_blue', 0),
    bottom: makeStyleItem('bermuda_shorts_beige', 0),
    shoes: makeStyleItem('sport_sandal_brown', 0),
  ),
  Outfit(
    name: '暖调复古',
    vibe: '文艺柔和',
    matchScore: 91,
    hat: makeStyleItem('newsboy_cap_brown', 0),
    top: makeStyleItem('cardigan_beige', 0),
    bottom: makeStyleItem('corduroy_pants_brown', 0),
    shoes: makeStyleItem('loafer_brown', 0),
  ),
  Outfit(
    name: '未来机能',
    vibe: '冷静酷感',
    matchScore: 93,
    hat: makeStyleItem('baseball_cap_black', 0),
    top: makeStyleItem('coach_jacket_grey', 0),
    bottom: makeStyleItem('parachute_pants_black', 0),
    shoes: makeStyleItem('retro_trainer_grey', 0),
  ),
];
final seedCloset = <ClothingItem>[
  for (final style in clothingStyles)
    ClothingItem(id: style.id, style: style, tone: style.baseColor),
];
