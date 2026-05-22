import 'dart:convert';

import 'package:http/http.dart' as http;

class BaoBaoAiApi {
  static const String _apiKey = String.fromEnvironment(
    'OPENROUTER_API_KEY',
    defaultValue: '',
  );

  static const String _model = 'openrouter/free';

  // ============================================================
  // NORMAL BAO-BAO CHAT
  // ============================================================

  Future<String> askBaoBao(String userMessage) async {
    if (_apiKey.trim().isEmpty) {
      return _localFallbackReply(userMessage);
    }

    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
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

Reply shortly and helpfully.
You can help with course planning, credit balance, schedule conflicts, and course suggestions.
Do not write very long answers.
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

      if (response.statusCode != 200) {
        return _localFallbackReply(userMessage);
      }

      final data = jsonDecode(response.body);
      final choices = data['choices'] as List<dynamic>?;

      if (choices == null || choices.isEmpty) {
        return _localFallbackReply(userMessage);
      }

      final content = choices.first['message']?['content'];

      if (content == null || content.toString().trim().isEmpty) {
        return _localFallbackReply(userMessage);
      }

      return content.toString().trim();
    } catch (_) {
      return _localFallbackReply(userMessage);
    }
  }

  // ============================================================
  // COURSE RECOMMENDATION
  // AI parses intent, Flutter filters real Firebase-loaded courses.
  // This returns course IDs only.
  // ============================================================

  Future<List<String>> askBaoBaoRecommendedCourseIds({
    required String userMessage,
    required List<Map<String, dynamic>> courseCatalog,
  }) async {
    final plan = await _parseRecommendationPlan(userMessage);
    final allowSpecialCourses = _userAllowsSpecialCourses(userMessage);

    final selectedIds = <String>[];
    final usedIds = <String>{};

    for (final request in plan.requests) {
      final candidates = courseCatalog.where((course) {
        final id = course['id']?.toString() ?? '';

        if (id.isEmpty || usedIds.contains(id)) return false;
        if (!_isAvailableCourse(course)) return false;

        if (!_isGoodNormalRecommendation(
          course,
          allowSpecialCourses: allowSpecialCourses,
        )) {
          return false;
        }

        if (request.credits != null &&
            _toInt(course['credits']) != request.credits) {
          return false;
        }

        if (!_matchesSubject(course, request.subject)) {
          return false;
        }

        if (request.level == 'beginner' && !_looksBeginnerCourse(course)) {
          return false;
        }

        if (request.level == 'advanced' && !_looksAdvancedCourse(course)) {
          return false;
        }

        return true;
      }).toList();

      candidates.sort((a, b) {
        final scoreA = _scoreCourse(a, request);
        final scoreB = _scoreCourse(b, request);

        if (scoreA != scoreB) {
          return scoreB.compareTo(scoreA);
        }

        final creditA = _toInt(a['credits']);
        final creditB = _toInt(b['credits']);

        if (creditA != creditB) {
          return creditA.compareTo(creditB);
        }

        final codeA = a['code']?.toString() ?? '';
        final codeB = b['code']?.toString() ?? '';

        return codeA.compareTo(codeB);
      });

      for (final course in candidates.take(request.count)) {
        final id = course['id']?.toString() ?? '';

        if (id.isNotEmpty) {
          selectedIds.add(id);
          usedIds.add(id);
        }
      }
    }

    if (selectedIds.isNotEmpty) {
      return selectedIds;
    }

    return _fallbackSmartSearch(
      userMessage: userMessage,
      courseCatalog: courseCatalog,
      allowSpecialCourses: allowSpecialCourses,
    );
  }

  Future<_RecommendationPlan> _parseRecommendationPlan(String message) async {
    final localPlan = _RecommendationPlan.fromLocalParser(message);

    if (_apiKey.trim().isEmpty) {
      return localPlan;
    }

    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'HTTP-Referer': 'https://enthusiast.app',
          'X-OpenRouter-Title': 'eNTHUsiast Bao-Bao',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': '''
You convert a student's course request into strict JSON.

Return JSON only. No markdown.

Supported subjects:
cs, english, japanese, chinese, pe, math, ai, ge, language, any

Supported levels:
beginner, advanced, any

Rules:
- If user says "two CS courses and one English course", return two requests.
- If user says "1 CS course and 2 GE courses", return two requests.
- If count is not specified, use 5.
- If credits are not specified, use null.
- Do not invent course names.

Return exactly:
{
  "requests": [
    {
      "subject": "cs",
      "count": 2,
      "credits": null,
      "level": "any"
    }
  ]
}
''',
            },
            {
              'role': 'user',
              'content': message,
            },
          ],
          'temperature': 0.1,
          'max_tokens': 250,
        }),
      );

      if (response.statusCode != 200) {
        return localPlan;
      }

      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content']?.toString();

      if (content == null || content.trim().isEmpty) {
        return localPlan;
      }

      final jsonText = _extractJsonObject(content);
      final parsed = jsonDecode(jsonText);

      final requestsRaw = parsed['requests'] as List<dynamic>?;

      if (requestsRaw == null || requestsRaw.isEmpty) {
        return localPlan;
      }

      final requests = requestsRaw.map((item) {
        final map = item as Map<String, dynamic>;

        return _CourseRequest(
          subject: _normalizeSubject(map['subject']?.toString() ?? 'any'),
          count: _toInt(map['count']).clamp(1, 10),
          credits: map['credits'] == null ? null : _toInt(map['credits']),
          level: _normalizeLevel(map['level']?.toString() ?? 'any'),
        );
      }).toList();

      if (requests.isEmpty) {
        return localPlan;
      }

      return _RecommendationPlan(requests: requests);
    } catch (_) {
      return localPlan;
    }
  }

  List<String> _fallbackSmartSearch({
    required String userMessage,
    required List<Map<String, dynamic>> courseCatalog,
    required bool allowSpecialCourses,
  }) {
    final plan = _RecommendationPlan.fromLocalParser(userMessage);

    final result = <String>[];
    final usedIds = <String>{};

    for (final request in plan.requests) {
      final candidates = courseCatalog.where((course) {
        final id = course['id']?.toString() ?? '';

        if (id.isEmpty || usedIds.contains(id)) return false;
        if (!_isAvailableCourse(course)) return false;

        if (!_isGoodNormalRecommendation(
          course,
          allowSpecialCourses: allowSpecialCourses,
        )) {
          return false;
        }

        if (request.credits != null &&
            _toInt(course['credits']) != request.credits) {
          return false;
        }

        return _matchesSubject(course, request.subject);
      }).toList();

      candidates.sort((a, b) {
        final scoreA = _scoreCourse(a, request);
        final scoreB = _scoreCourse(b, request);

        if (scoreA != scoreB) return scoreB.compareTo(scoreA);

        return (a['code']?.toString() ?? '')
            .compareTo(b['code']?.toString() ?? '');
      });

      for (final course in candidates.take(request.count)) {
        final id = course['id']?.toString() ?? '';

        if (id.isNotEmpty) {
          result.add(id);
          usedIds.add(id);
        }
      }
    }

    return result;
  }

  // ============================================================
  // COURSE FILTERING
  // ============================================================

  bool _isAvailableCourse(Map<String, dynamic> course) {
    return course['alreadyPlanned'] != true && course['hasConflict'] != true;
  }

  bool _userAllowsSpecialCourses(String message) {
    final lower = message.toLowerCase();

    return lower.contains('thesis') ||
        lower.contains('seminar') ||
        lower.contains('colloquium') ||
        lower.contains('research') ||
        lower.contains('graduate') ||
        lower.contains('clerkship') ||
        lower.contains('dissertation') ||
        lower.contains('independent study') ||
        lower.contains('專題') ||
        lower.contains('論文') ||
        lower.contains('書報') ||
        lower.contains('研究') ||
        lower.contains('實習');
  }

  bool _isGoodNormalRecommendation(
    Map<String, dynamic> course, {
    required bool allowSpecialCourses,
  }) {
    if (allowSpecialCourses) {
      return true;
    }

    final title = (course['title'] ?? '').toString().toLowerCase();
    final code = (course['code'] ?? '').toString().toLowerCase();
    final type = (course['type'] ?? '').toString().toLowerCase();
    final department = (course['department'] ?? '').toString().toLowerCase();
    final credits = _toInt(course['credits']);

    final text = '$title $code $type $department';

    final isSpecialCourse =
        text.contains('thesis') ||
        text.contains('seminar') ||
        text.contains('colloquium') ||
        text.contains('graduate research') ||
        text.contains('research seminar') ||
        text.contains('research project') ||
        text.contains('clerkship') ||
        text.contains('dissertation') ||
        text.contains('independent study') ||
        text.contains('special topic') ||
        text.contains('專題') ||
        text.contains('論文') ||
        text.contains('書報') ||
        text.contains('實習');

    if (isSpecialCourse) {
      return false;
    }

    // Usually not useful for normal course recommendations.
    if (credits <= 0) {
      return false;
    }

    return true;
  }

  bool _matchesSubject(Map<String, dynamic> course, String subject) {
    if (subject == 'any') return true;

    final text = _searchText(course);
    final department = (course['department'] ?? '').toString().toUpperCase();
    final code = (course['code'] ?? '').toString().toUpperCase();
    final title = (course['title'] ?? '').toString().toLowerCase();

    switch (subject) {
      case 'cs':
        return department == 'CS' ||
            department == 'EECS' ||
            RegExp(r'(^|[^A-Z0-9])CS([^A-Z0-9]|$)').hasMatch(code) ||
            code.contains('CS ') ||
            _hasWord(text, 'computer') ||
            _hasWord(text, 'programming') ||
            _hasWord(text, 'software') ||
            _hasWord(text, 'algorithm') ||
            _hasWord(text, 'data structure') ||
            text.contains('資訊');

      case 'english':
        return _hasWord(title, 'english') ||
            text.contains('英文') ||
            text.contains('英語') ||
            (department == 'LANG' && _hasWord(text, 'english')) ||
            (department == 'FLL' && _hasWord(text, 'english'));

      case 'japanese':
        return _hasWord(title, 'japanese') ||
            _hasWord(title, 'japan') ||
            text.contains('日文') ||
            text.contains('日語') ||
            text.contains('日本語') ||
            department == 'JPN' ||
            (department == 'LANG' && text.contains('日'));

      case 'chinese':
        return _hasWord(title, 'chinese') ||
            _hasWord(title, 'mandarin') ||
            text.contains('中文') ||
            text.contains('華語') ||
            (department == 'LANG' && text.contains('中'));

      case 'pe':
        return _hasWord(text, 'physical education') ||
            _hasWord(text, 'sport') ||
            text.contains('體育') ||
            department == 'PE';

      case 'math':
        return department == 'MATH' ||
            _hasWord(text, 'math') ||
            _hasWord(text, 'mathematics') ||
            _hasWord(text, 'calculus') ||
            _hasWord(text, 'algebra') ||
            text.contains('數學');

      case 'ai':
        return _hasWord(text, 'artificial intelligence') ||
            _hasWord(text, 'machine learning') ||
            _hasWord(text, 'ai') ||
            text.contains('人工智慧') ||
            text.contains('機器學習');

      case 'ge':
        return department == 'GE' ||
            (course['type'] ?? '').toString().toUpperCase() == 'GE' ||
            text.contains('通識') ||
            _hasWord(text, 'general education');

      case 'language':
        return department == 'LANG' ||
            _hasWord(text, 'language') ||
            text.contains('語言') ||
            text.contains('日文') ||
            text.contains('英文') ||
            text.contains('中文');

      default:
        return true;
    }
  }

  int _scoreCourse(Map<String, dynamic> course, _CourseRequest request) {
    final text = _searchText(course);
    int score = 0;

    if (_matchesSubject(course, request.subject)) score += 1000;

    if (request.level == 'beginner' && _looksBeginnerText(text)) score += 250;
    if (request.level == 'advanced' && _looksAdvancedText(text)) score += 250;

    if (request.credits != null && _toInt(course['credits']) == request.credits) {
      score += 150;
    }

    final credits = _toInt(course['credits']);

    if (request.level == 'beginner') {
      if (credits <= 2) score += 50;
      if (credits >= 4) score -= 80;
    }

    final rating = _toDouble(course['rating']);
    score += (rating * 10).round();

    return score;
  }

  bool _looksBeginnerCourse(Map<String, dynamic> course) {
    return _looksBeginnerText(_searchText(course));
  }

  bool _looksAdvancedCourse(Map<String, dynamic> course) {
    return _looksAdvancedText(_searchText(course));
  }

  bool _looksBeginnerText(String text) {
    return _hasWord(text, 'beginner') ||
        _hasWord(text, 'basic') ||
        _hasWord(text, 'intro') ||
        _hasWord(text, 'introduction') ||
        _hasWord(text, 'elementary') ||
        text.contains('初級') ||
        text.contains('基礎') ||
        text.contains('入門') ||
        text.contains('一');
  }

  bool _looksAdvancedText(String text) {
    return _hasWord(text, 'advanced') ||
        _hasWord(text, 'graduate') ||
        text.contains('進階') ||
        text.contains('高級') ||
        text.contains('研究所');
  }

  String _searchText(Map<String, dynamic> course) {
    return [
      course['id'],
      course['code'],
      course['title'],
      course['titleZh'],
      course['titleEn'],
      course['type'],
      course['department'],
      course['slotCode'],
      course['timeSlot'],
      course['location'],
    ].whereType<Object>().join(' ').toLowerCase();
  }

  bool _hasWord(String text, String word) {
    final pattern = RegExp(
      r'(^|[^a-zA-Z0-9])' +
          RegExp.escape(word.toLowerCase()) +
          r'([^a-zA-Z0-9]|$)',
      caseSensitive: false,
    );

    return pattern.hasMatch(text.toLowerCase());
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _extractJsonObject(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');

    if (start == -1 || end == -1 || end <= start) {
      throw const FormatException('No JSON object found');
    }

    return text.substring(start, end + 1);
  }

  String _normalizeSubject(String subject) {
    final lower = subject.toLowerCase().trim();

    if (lower == 'computer science' ||
        lower == 'computer' ||
        lower == 'programming' ||
        lower == 'software' ||
        lower == 'coding') {
      return 'cs';
    }

    if (lower == 'physical education' || lower == 'sport') {
      return 'pe';
    }

    if (lower == 'general education') {
      return 'ge';
    }

    if ([
      'cs',
      'english',
      'japanese',
      'chinese',
      'pe',
      'math',
      'ai',
      'ge',
      'language',
      'any',
    ].contains(lower)) {
      return lower;
    }

    return 'any';
  }

  String _normalizeLevel(String level) {
    final lower = level.toLowerCase().trim();

    if (lower.contains('beginner') ||
        lower.contains('basic') ||
        lower.contains('intro')) {
      return 'beginner';
    }

    if (lower.contains('advanced') || lower.contains('graduate')) {
      return 'advanced';
    }

    return 'any';
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
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
      return 'Bao-Bao can recommend real courses from your Firebase course list.';
    }

    return 'Bao-Bao is using simple mode right now 🐼 I can still help with conflicts, credits, and basic course planning.';
  }
}

// ============================================================
// RECOMMENDATION PLAN PARSER
// ============================================================

class _RecommendationPlan {
  final List<_CourseRequest> requests;

  const _RecommendationPlan({
    required this.requests,
  });

  factory _RecommendationPlan.fromLocalParser(String message) {
    final lower = message.toLowerCase();

    final requests = <_CourseRequest>[];

    void addRequest({
      required String subject,
      required List<String> keywords,
    }) {
      for (final keyword in keywords) {
        final index = lower.indexOf(keyword);

        if (index != -1) {
          requests.add(
            _CourseRequest(
              subject: subject,
              count: _countBefore(lower, index) ?? 5,
              credits: _creditsFromMessage(lower),
              level: _levelFromMessage(lower),
            ),
          );
          return;
        }
      }
    }

    addRequest(
      subject: 'cs',
      keywords: [
        'cs',
        'computer science',
        'computer',
        'programming',
        'software',
        'coding',
      ],
    );

    addRequest(
      subject: 'english',
      keywords: [
        'english',
        '英文',
        '英語',
      ],
    );

    addRequest(
      subject: 'japanese',
      keywords: [
        'japanese',
        'japan',
        '日文',
        '日語',
        '日本語',
      ],
    );

    addRequest(
      subject: 'chinese',
      keywords: [
        'chinese',
        'mandarin',
        '中文',
        '華語',
      ],
    );

    addRequest(
      subject: 'pe',
      keywords: [
        'pe',
        'sport',
        'physical education',
        '體育',
      ],
    );

    addRequest(
      subject: 'math',
      keywords: [
        'math',
        'calculus',
        'algebra',
        'mathematics',
      ],
    );

    addRequest(
      subject: 'ai',
      keywords: [
        'ai',
        'machine learning',
        'artificial intelligence',
      ],
    );

    addRequest(
      subject: 'ge',
      keywords: [
        'ge',
        'general education',
        '通識',
      ],
    );

    if (requests.isEmpty) {
      requests.add(
        _CourseRequest(
          subject: 'any',
          count: _genericCount(lower) ?? 5,
          credits: _creditsFromMessage(lower),
          level: _levelFromMessage(lower),
        ),
      );
    }

    return _RecommendationPlan(requests: requests);
  }

  static int? _countBefore(String lower, int index) {
    final prefix = lower.substring(0, index).trimRight();

    final match = RegExp(
      r'(one|two|three|four|five|six|seven|eight|nine|ten|[0-9]+)\s*(course|courses|class|classes)?\s*(of|for|in)?\s*$',
    ).firstMatch(prefix);

    if (match == null) return null;

    return _wordToNumber(match.group(1) ?? '');
  }

  static int? _genericCount(String lower) {
    final match = RegExp(
      r'\b(one|two|three|four|five|six|seven|eight|nine|ten|[0-9]+)\s*(course|courses|class|classes)\b',
    ).firstMatch(lower);

    if (match == null) return null;

    return _wordToNumber(match.group(1) ?? '');
  }

  static int? _creditsFromMessage(String lower) {
    final match =
        RegExp(r'\b([0-9]+)\s*(credit|credits|cr)\b').firstMatch(lower);

    if (match == null) return null;

    return int.tryParse(match.group(1) ?? '');
  }

  static String _levelFromMessage(String lower) {
    if (lower.contains('beginner') ||
        lower.contains('basic') ||
        lower.contains('intro') ||
        lower.contains('初級') ||
        lower.contains('基礎') ||
        lower.contains('入門')) {
      return 'beginner';
    }

    if (lower.contains('advanced') ||
        lower.contains('graduate') ||
        lower.contains('進階') ||
        lower.contains('高級')) {
      return 'advanced';
    }

    return 'any';
  }

  static int? _wordToNumber(String value) {
    final text = value.toLowerCase().trim();

    final parsed = int.tryParse(text);
    if (parsed != null) return parsed;

    switch (text) {
      case 'one':
        return 1;
      case 'two':
        return 2;
      case 'three':
        return 3;
      case 'four':
        return 4;
      case 'five':
        return 5;
      case 'six':
        return 6;
      case 'seven':
        return 7;
      case 'eight':
        return 8;
      case 'nine':
        return 9;
      case 'ten':
        return 10;
      default:
        return null;
    }
  }
}

class _CourseRequest {
  final String subject;
  final int count;
  final int? credits;
  final String level;

  const _CourseRequest({
    required this.subject,
    required this.count,
    required this.credits,
    required this.level,
  });
}