import 'dart:convert';

import 'package:http/http.dart' as http;

class TrendItem {
  final String title;
  final String description;
  final int hotScore;
  final String url;

  const TrendItem({
    required this.title,
    required this.description,
    required this.hotScore,
    required this.url,
  });

  String get hotLabel {
    if (hotScore >= 10000) return '${(hotScore / 10000).round()}万热度';
    return '$hotScore热度';
  }

  String get outfitHint {
    final text = '$title $description';
    if (RegExp(r'雨|暴雨|台风|积水|降水').hasMatch(text)) {
      return '热点提示：带伞，选防水外层与耐脏鞋。';
    }
    if (RegExp(r'高温|大暑|炎热|酷暑|夏天').hasMatch(text)) {
      return '热点提示：浅色、宽松、透气材质更舒服。';
    }
    if (RegExp(r'比赛|体育|足球|篮球|跑步|运动|冠军').hasMatch(text)) {
      return '风格灵感：运动学院风，轻便鞋款优先。';
    }
    if (RegExp(r'电影|明星|音乐|演唱会|红毯|时尚').hasMatch(text)) {
      return '风格灵感：用一件有辨识度的单品做重点。';
    }
    if (RegExp(r'科技|AI|机器人|手机|数码|未来').hasMatch(text)) {
      return '风格灵感：简洁线条配黑白灰或冷色调。';
    }
    if (RegExp(r'旅行|文旅|景区|假期|出游').hasMatch(text)) {
      return '风格灵感：舒适耐走，增加轻便随身外层。';
    }
    if (RegExp(r'大学|高校|校园|开学|学生').hasMatch(text)) {
      return '风格灵感：清爽校园感，层次简单不费力。';
    }
    return '今日灵感：保持基础款，用颜色呼应当天话题氛围。';
  }
}

class TrendService {
  TrendService._();

  static Future<List<TrendItem>> load() async {
    final uri = Uri.https('top.baidu.com', '/api/board', {
      'platform': 'pc',
      'tab': 'realtime',
    });
    final response = await http
        .get(
          uri,
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/125 Mobile Safari/537.36',
            'Referer': 'https://top.baidu.com/board?tab=realtime',
          },
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) throw const TrendException('今日热点暂时不可用');
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>?;
    final cards = data?['cards'] as List<dynamic>?;
    if (cards == null || cards.isEmpty) throw const TrendException('今日热点暂时不可用');
    final content =
        (cards.first as Map<String, dynamic>)['content'] as List<dynamic>?;
    if (content == null) throw const TrendException('今日热点暂时不可用');
    return content
        .map((raw) {
          final value = raw as Map<String, dynamic>;
          return TrendItem(
            title: (value['word'] ?? value['query'] ?? '') as String,
            description: (value['desc'] ?? '') as String,
            hotScore: int.tryParse('${value['hotScore'] ?? 0}') ?? 0,
            url: (value['url'] ?? '') as String,
          );
        })
        .where((item) => item.title.trim().isNotEmpty)
        .take(30)
        .toList(growable: false);
  }
}

class TrendException implements Exception {
  final String message;
  const TrendException(this.message);
  @override
  String toString() => message;
}
