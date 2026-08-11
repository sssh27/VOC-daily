import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// 依 SPEC.md 6.6 第 7 點分類的錯誤,generate_screen.dart 直接顯示
/// [message] 即可,不需要自己再判斷錯誤類型。
class AiServiceException implements Exception {
  final String message;
  AiServiceException(this.message);

  @override
  String toString() => message;
}

/// A single AI-generated card, before it's saved to the database.
class GeneratedCard {
  final String word;
  final String phonetic;
  final String meaning;
  final String example;
  final String exampleZh;

  GeneratedCard({
    required this.word,
    required this.phonetic,
    required this.meaning,
    required this.example,
    required this.exampleZh,
  });

  factory GeneratedCard.fromJson(Map<String, dynamic> json) => GeneratedCard(
        word: json['word'] ?? '',
        phonetic: json['phonetic'] ?? '',
        meaning: json['meaning'] ?? '',
        example: json['example'] ?? '',
        exampleZh: json['exampleZh'] ?? '',
      );
}

/// IMPORTANT before you ship this app:
/// Move this call behind your own backend (e.g. a Firebase Cloud Function)
/// so the API key is never bundled inside the app binary. Anyone can
/// extract a key shipped in a compiled app and rack up your bill.
/// For now (local dev only / not part of the production flow, see
/// SPEC.md 7.1) it reads the key from a build-time --dart-define, e.g.:
///   flutter run -d chrome --dart-define=AI_API_KEY=sk-xxxx
class AiService {
  static const _apiKey = String.fromEnvironment('AI_API_KEY');

  static Future<List<GeneratedCard>> generateCards({
    required String topic,
    int count = 10,
  }) async {
    final apiKey = _apiKey;
    if (apiKey.isEmpty) {
      throw AiServiceException('尚未設定 API 金鑰');
    }

    final prompt = '''
Generate $count English vocabulary/phrase flashcards for a learner studying: "$topic".
Return ONLY valid JSON in this exact shape, no extra text:
{"cards":[{"word":"","phonetic":"","meaning":"","example":"","exampleZh":""}]}
meaning and exampleZh should be in Traditional Chinese.
''';

    http.Response response;
    try {
      // Example uses an OpenAI-compatible chat completions endpoint.
      // Swap the URL/body/headers if you use a different provider.
      response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'response_format': {'type': 'json_object'},
        }),
      );
    } on SocketException {
      throw AiServiceException('連線失敗,請檢查網路');
    } on HttpException {
      throw AiServiceException('連線失敗,請檢查網路');
    } catch (e) {
      // http package throws ClientException (which isn't available without
      // importing package:http/http.dart's internals) for most other
      // network-layer failures; treat anything not already an
      // AiServiceException as a connectivity problem here.
      throw AiServiceException('連線失敗,請檢查網路');
    }

    if (response.statusCode != 200) {
      throw AiServiceException('連線失敗,請檢查網路');
    }

    try {
      final body = jsonDecode(response.body);
      final content = body['choices'][0]['message']['content'] as String;
      final parsed = jsonDecode(content) as Map<String, dynamic>;
      final list = (parsed['cards'] as List).cast<Map<String, dynamic>>();
      return list.map(GeneratedCard.fromJson).toList();
    } catch (e) {
      throw AiServiceException('AI 回傳格式異常,請再試一次');
    }
  }
}
