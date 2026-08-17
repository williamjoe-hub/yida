from pathlib import Path


path = Path(__file__).resolve().parents[1] / "lib" / "models.dart"
text = path.read_text(encoding="utf-8")
text = text.replace(
    "import 'dart:ui';\n",
    "import 'dart:ui';\n\nimport 'generated_catalog_data.dart';\n",
)
text = text.replace(
    "  canvas('帆布'),\n  blend('混纺');",
    "  canvas('帆布'),\n"
    "  blend('混纺'),\n"
    "  wool('羊毛'),\n"
    "  nylon('尼龙'),\n"
    "  linen('亚麻'),\n"
    "  polyester('聚酯纤维'),\n"
    "  fleece('抓绒'),\n"
    "  corduroy('灯芯绒'),\n"
    "  mesh('网布'),\n"
    "  suede('麂皮');",
)

start = text.index("const clothingStyles = <ClothingStyle>[")
end = text.index("\n\nclass ClothingItem", start)
replacement = '''final clothingStyles = generatedCatalogData.map((data) {
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
    name: data['name']!,
    category: category,
    material: material,
    assetPath: data['asset']!,
    baseColor: color,
  );
}).toList(growable: false);

String _catalogColorName(String id) => switch (id) {
  'white' => '白色',
  'black' => '黑色',
  'beige' => '米色',
  'grey' => '灰色',
  'blue' => '蓝色',
  'brown' => '棕色',
  _ => '白色',
};'''
text = text[:start] + replacement + text[end:]

text = text.replace(
    "  ColorOption('浅蓝', Color(0xFFAEC6D8)),",
    "  ColorOption('蓝色', Color(0xFF527DA5)),\n"
    "  ColorOption('浅蓝', Color(0xFFAEC6D8)),",
)
text = text.replace("makeStyleItem('cap', 1)", "makeStyleItem('baseball_cap_black', 1)")
text = text.replace("makeStyleItem('tee', 0)", "makeStyleItem('crew_tee_white', 0)")
text = text.replace("makeStyleItem('jeans', 2)", "makeStyleItem('wide_jeans_blue', 2)")
text = text.replace("makeStyleItem('sneaker', 0)", "makeStyleItem('platform_sneaker_white', 0)")
path.write_text(text, encoding="utf-8")
print("integrated generated catalog into models.dart")
