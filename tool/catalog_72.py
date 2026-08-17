STYLES = [
    # 帽子 8
    ("baseball_cap", "棒球帽", "hat", "cotton"), ("dad_cap", "弯檐帽", "hat", "cotton"),
    ("trucker_cap", "网眼帽", "hat", "canvas"), ("bucket_hat", "渔夫帽", "hat", "cotton"),
    ("beanie", "针织帽", "hat", "knit"), ("beret", "贝雷帽", "hat", "wool"),
    ("newsboy_cap", "报童帽", "hat", "wool"), ("visor", "空顶帽", "hat", "nylon"),
    # 上衣 20
    ("crew_tee", "圆领T恤", "top", "cotton"), ("oversized_tee", "宽松T恤", "top", "cotton"),
    ("polo", "Polo衫", "top", "cotton"), ("tank_top", "背心", "top", "cotton"),
    ("oxford_shirt", "牛津衬衫", "top", "cotton"), ("linen_shirt", "亚麻衬衫", "top", "linen"),
    ("flannel_shirt", "法兰绒衬衫", "top", "cotton"), ("sweatshirt", "圆领卫衣", "top", "cotton"),
    ("pullover_hoodie", "套头卫衣", "top", "cotton"), ("zip_hoodie", "拉链卫衣", "top", "cotton"),
    ("crew_sweater", "圆领毛衣", "top", "knit"), ("vneck_sweater", "V领毛衣", "top", "knit"),
    ("cardigan", "针织开衫", "top", "knit"), ("vest_sweater", "针织马甲", "top", "knit"),
    ("rugby_shirt", "橄榄球衫", "top", "cotton"), ("henley", "亨利领上衣", "top", "cotton"),
    ("mockneck", "半高领上衣", "top", "knit"), ("turtleneck", "高领毛衣", "top", "knit"),
    ("jersey", "运动球衣", "top", "polyester"), ("blouse", "垂感衬衫", "top", "polyester"),
    # 外套 12
    ("denim_jacket", "牛仔夹克", "outer", "denim"), ("bomber", "飞行夹克", "outer", "nylon"),
    ("varsity", "棒球夹克", "outer", "wool"), ("coach_jacket", "教练夹克", "outer", "nylon"),
    ("windbreaker", "防风外套", "outer", "nylon"), ("track_jacket", "运动夹克", "outer", "polyester"),
    ("chore_jacket", "工装夹克", "outer", "canvas"), ("blazer", "休闲西装", "outer", "blend"),
    ("trench", "风衣", "outer", "cotton"), ("wool_coat", "羊毛大衣", "outer", "wool"),
    ("puffer", "羽绒服", "outer", "nylon"), ("fleece_jacket", "抓绒外套", "outer", "fleece"),
    # 下装 18
    ("straight_jeans", "直筒牛仔裤", "bottom", "denim"), ("wide_jeans", "阔腿牛仔裤", "bottom", "denim"),
    ("slim_jeans", "修身牛仔裤", "bottom", "denim"), ("cargo_pants", "工装裤", "bottom", "cotton"),
    ("chinos", "卡其裤", "bottom", "cotton"), ("straight_trousers", "直筒西裤", "bottom", "blend"),
    ("wide_trousers", "阔腿西裤", "bottom", "blend"), ("joggers", "束脚裤", "bottom", "cotton"),
    ("track_pants", "运动长裤", "bottom", "polyester"), ("parachute_pants", "降落伞裤", "bottom", "nylon"),
    ("corduroy_pants", "灯芯绒裤", "bottom", "corduroy"), ("linen_pants", "亚麻长裤", "bottom", "linen"),
    ("denim_shorts", "牛仔短裤", "bottom", "denim"), ("chino_shorts", "休闲短裤", "bottom", "cotton"),
    ("cargo_shorts", "工装短裤", "bottom", "cotton"), ("sport_shorts", "运动短裤", "bottom", "polyester"),
    ("bermuda_shorts", "百慕大短裤", "bottom", "cotton"), ("sweat_shorts", "卫裤短裤", "bottom", "cotton"),
    # 裙装/连体 6
    ("pleated_skirt", "百褶裙", "dress", "polyester"), ("denim_skirt", "牛仔裙", "dress", "denim"),
    ("aline_skirt", "A字裙", "dress", "blend"), ("shirt_dress", "衬衫裙", "dress", "cotton"),
    ("overall", "背带裤", "dress", "denim"), ("jumpsuit", "连体裤", "dress", "cotton"),
    # 鞋子 8
    ("platform_sneaker", "厚底板鞋", "shoes", "leather"), ("canvas_sneaker", "帆布鞋", "shoes", "canvas"),
    ("running_shoe", "跑鞋", "shoes", "mesh"), ("retro_trainer", "复古运动鞋", "shoes", "suede"),
    ("loafer", "乐福鞋", "shoes", "leather"), ("derby", "德比鞋", "shoes", "leather"),
    ("ankle_boot", "短靴", "shoes", "leather"), ("sport_sandal", "运动凉鞋", "shoes", "nylon"),
]

COLORS = {
    "white": ("白色", "clean soft white"), "black": ("黑色", "deep neutral black"),
    "beige": ("米色", "warm oatmeal beige"), "grey": ("灰色", "medium neutral grey"),
    "blue": ("蓝色", "versatile campus blue"), "brown": ("棕色", "warm medium brown"),
}

assert len(STYLES) == 72
