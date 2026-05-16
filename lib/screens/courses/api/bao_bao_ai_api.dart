import 'dart:convert';

import 'package:http/http.dart' as http;

class BaoBaoAiApi {
  static const String _apiKey = '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';

  // Free model router from OpenRouter.
  static const String _model = 'openrouter/free';

  Future<String> askBaoBao(String userMessage) async {
    print('BaoBao OpenRouter API called with: $userMessage');

    if (_apiKey == 'PASTE_YOUR_OPENROUTER_API_KEY_HERE' ||
        _apiKey.trim().isEmpty) {
      return _localFallbackReply(userMessage);
    }

    final url = Uri.parse(
      'https://openrouter.ai/api/v1/chat/completions',
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',

          // Optional headers, but useful for OpenRouter app tracking.
          'HTTP-Referer': 'https://enthusiast.app',
          'X-OpenRouter-Title': 'eNTHUsiast Bao-Bao',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': '''
You are Bao-Bao, a cute panda AI assistant inside an NTHU course planner app.

Your job:
- Help students plan courses.
- Explain schedule conflicts.
- Explain credit balance.
- Suggest balanced course choices.
- Reply in a friendly, short, student-friendly way.
- Do not write very long answers.
''',
            },
            {
              'role': 'user',
              'content': userMessage,
            },
          ],
          'temperature': 0.7,
          'max_tokens': 250,
        }),
      );

      print('OpenRouter status: ${response.statusCode}');
      print('OpenRouter body: ${response.body}');

      if (response.statusCode == 429) {
        return 'Bao-Bao is resting because the free AI limit was reached 🐼 Please wait a bit and try again.';
      }

      if (response.statusCode != 200) {
        return _localFallbackReply(userMessage);
      }

      final data = jsonDecode(response.body);

      final choices = data['choices'] as List<dynamic>?;

      if (choices == null || choices.isEmpty) {
        return 'Bao-Bao did not get a response. Can you ask again?';
      }

      final message = choices.first['message'];
      final content = message?['content'];

      if (content == null || content.toString().trim().isEmpty) {
        return 'Bao-Bao got an empty response. Can you ask again?';
      }

      return content.toString().trim();
    } catch (e) {
      print('OpenRouter exception: $e');
      return _localFallbackReply(userMessage);
    }
  }

  String _localFallbackReply(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('hi') || lower.contains('hello')) {
      return 'Hi! I’m Bao-Bao 🐼 I can help you plan courses, check conflicts, and balance your credits.';
    }

    if (lower.contains('conflict')) {
      return 'Bao-Bao says: avoid courses marked with × CONFLICT because they overlap with your current plan.';
    }

    if (lower.contains('credit')) {
      return 'You can check your selected total credits at the top-right of the Course Planner page.';
    }

    if (lower.contains('recommend') || lower.contains('suggest')) {
      return 'Bao-Bao suggests choosing a balanced mix of CORE, ELECTIVE, GE, and not too many heavy courses in one day.';
    }

    if (lower.contains('hard') || lower.contains('difficult')) {
      return 'Try not to take too many difficult courses together. It is better to balance hard courses with lighter ones.';
    }

    return 'Bao-Bao is using simple mode right now 🐼 I can still help with conflicts, credits, and basic course planning.';
  }
}