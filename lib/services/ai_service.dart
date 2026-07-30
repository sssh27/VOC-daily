import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
/// For now (local dev only) it reads the key from .env directly.
class AiService {
  static Future<List<GeneratedCard>> generateCards({
    required String topic,
    int count = 10,
  }) async {
    final apiKey = dotenv.env['AI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
          'AI_API_KEY missing. Copy .env.example to .env and fill it in.');
    }

    final prompt = '''
Generate $count English vocabulary/phrase flashcards for a learner studying: "$topic".
Return ONLY valid JSON in this exact shape, no extra text:
{"cards":[{"word":"","phonetic":"","meaning":"","example":"","exampleZh":""}]}
meaning and exampleZh should be in Traditional Chinese.
''';

    // Example uses an OpenAI-compatible chat completions endpoint.
    // Swap the URL/body/headers if you use a different provider.
    final response = await http.post(
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

    if (response.statusCode != 200) {
      throw Exception(
          'AI request failed: ${response.statusCode} ${response.body}');
    }

    final body = jsonDecode(response.body);
    final content = body['choices'][0]['message']['content'] as String;
    final parsed = jsonDecode(content) as Map<String, dynamic>;
    final list = (parsed['cards'] as List).cast<Map<String, dynamic>>();

    return list.map(GeneratedCard.fromJson).toList();
  }
}
