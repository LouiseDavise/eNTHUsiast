import 'dart:convert';

import 'package:http/http.dart' as http;

class BaoBaoAiApi {
  static const String _apiKey = String.fromEnvironment(
    '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',
    defaultValue: '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',
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

Reply shortly and naturally.
You help with course planning, credits, conflicts, and schedule advice.
If the user asks for course recommendations, say Bao-Bao can show real course cards directly.
Do not make fake course codes.
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
      final content = data['choices']?[0]?['message']?['content'];

      if (content == null || content.toString().trim().isEmpty) {
        return _localFallbackReply(userMessage);
      }

      return content.toString().trim();
    } catch (_) {
      return _localFallbackReply(userMessage);
    }
  }

  // ============================================================
  // SMART AI COURSE RECOMMENDATION
  // 1. AI creates flexible search groups.
  // 2. Flutter searches real Firebase-loaded courses.
  // 3. AI chooses only from real candidate IDs.
  // 4. App shows course cards directly.
  // ============================================================

  Future<List<String>> askBaoBaoRecommendedCourseIds({
    required String userMessage,
    required List<Map<String, dynamic>> courseCatalog,
  }) async {
    final plan = await _makeAiSearchPlan(userMessage);

    print('Bao-Bao final search plan: ${plan.toDebugMap()}');

    final selectedIds = <String>[];
    final usedIds = <String>{};

    for (final group in plan.groups) {
      final candidates = _buildCandidatePool(
        group: group,
        catalog: courseCatalog,
        usedIds: usedIds,
        allowSpecialCourses: plan.allowSpecialCourses,
      );

      print(
        'Bao-Bao candidate count for "${group.query}" '
        '[type=${group.requiredType}, count=${group.count}]: ${candidates.length}',
      );

      if (candidates.isEmpty) {
        continue;
      }

      final aiChosen = await _aiChooseCourseIds(
        userMessage: userMessage,
        group: group,
        candidates: candidates,
      );

      final validChosen = aiChosen.where((id) {
        return !usedIds.contains(id) &&
            candidates.any((course) => course['id']?.toString() == id);
      }).take(group.count).toList();

      if (validChosen.isNotEmpty) {
        selectedIds.addAll(validChosen);
        usedIds.addAll(validChosen);
      } else {
        final fallback = _localRankCourses(group, candidates);

        for (final course in fallback.take(group.count)) {
          final id = course['id']?.toString() ?? '';

          if (id.isNotEmpty && !usedIds.contains(id)) {
            selectedIds.add(id);
            usedIds.add(id);
          }
        }
      }
    }

    // Do not auto-fill to target credits for now.
    // It can add random courses and make Bao-Bao look wrong.
    return selectedIds;
  }

  // ============================================================
  // STEP 1: AI CREATES FLEXIBLE SEARCH PLAN
  // ============================================================

  Future<_AiSearchPlan> _makeAiSearchPlan(String userMessage) async {
    final fallback = _AiSearchPlan.local(userMessage);

    if (_apiKey.trim().isEmpty) {
      return fallback;
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
You are Bao-Bao's course-search planner.

Convert the student's request into flexible search groups.
Return JSON only. No markdown.

Schema:
{
  "targetCredits": null,
  "allowSpecialCourses": false,
  "groups": [
    {
      "query": "natural search words and synonyms",
      "count": 1,
      "credits": null,
      "requiredType": "any",
      "mustHave": [],
      "avoid": []
    }
  ]
}

Rules:
- targetCredits means total schedule credits, not each course credits.
- "20 credits" or "take 20 credits" means targetCredits: 20.
- "4 GE courses" means one group with count 4 and requiredType "GE".
- "2 CS core courses" means one group with count 2, requiredType "CORE".
- For CS core, query must include strong CS words: "CS ECS computer programming software algorithm data structure computer architecture operating system database 資訊 程式".
- Do NOT use only "science" as a CS search word.
- "CS related core" still means requiredType "CORE".
- "1 language course" means count 1, requiredType "LANGUAGE", and query "language English Japanese Chinese Mandarin".
- "I2P" means query "I2P introduction to programming programming beginner".
- "DS" can mean query "data structures".
- "OOP" can mean query "object oriented programming".
- "LA" can mean query "linear algebra".
- If the user mentions a professor, instructor, teacher, or person name, include that name in the query.
- If the user asks for courses "by", "from", "with", or "taught by" someone, put the professor name tokens in mustHave.
- Example: "courses taught by Chen Yi Ting" should return query "Chen Yi Ting professor instructor" and mustHave ["Chen", "Yi", "Ting"].
- Example: "any course from Prof Lee" should return query "Lee professor instructor" and mustHave ["Lee"].
- If count is not specified, use 5.
- credits means each course must have that credit number.
- requiredType must be one of: CORE, ELECTIVE, GE, LANGUAGE, LAB, PE, any.
- Avoid thesis, seminar, colloquium, research, MOOC, lab rotation unless user directly asks.
- If user asks for thesis/research/seminar, set allowSpecialCourses true.

Example:
User: "20 credit next sem 4 ge courses 2 cs core courses and 1 language courses"
Return:
{
  "targetCredits": 20,
  "allowSpecialCourses": false,
  "groups": [
    {
      "query": "general education GE 通識",
      "count": 4,
      "credits": null,
      "requiredType": "GE",
      "mustHave": [],
      "avoid": []
    },
    {
      "query": "CS ECS computer programming software algorithm data structure computer architecture operating system database 資訊 程式",
      "count": 2,
      "credits": null,
      "requiredType": "CORE",
      "mustHave": [],
      "avoid": []
    },
    {
      "query": "language English Japanese Chinese Mandarin 英文 日文 中文 華語",
      "count": 1,
      "credits": null,
      "requiredType": "LANGUAGE",
      "mustHave": [],
      "avoid": []
    }
  ]
}
''',
            },
            {
              'role': 'user',
              'content': userMessage,
            },
          ],
          'temperature': 0.05,
          'max_tokens': 700,
        }),
      );

      if (response.statusCode != 200) {
        return fallback;
      }

      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content']?.toString();

      if (content == null || content.trim().isEmpty) {
        return fallback;
      }

      final parsed = jsonDecode(_extractJsonObject(content));

      print('Bao-Bao AI raw plan: $parsed');

      final groupsRaw = parsed['groups'];

      if (groupsRaw is! List || groupsRaw.isEmpty) {
        return fallback;
      }

      final groups = groupsRaw.map((item) {
        final map = item as Map<String, dynamic>;

        return _SearchGroup(
          query: map['query']?.toString() ?? userMessage,
          count: _toInt(map['count']).clamp(1, 12),
          credits: map['credits'] == null ? null : _toInt(map['credits']),
          requiredType: _normalizeType(
            map['requiredType']?.toString() ?? 'any',
          ),
          mustHave: _toStringList(map['mustHave']),
          avoid: _toStringList(map['avoid']),
        );
      }).toList();

      return _AiSearchPlan(
        targetCredits: parsed['targetCredits'] == null
            ? null
            : _toInt(parsed['targetCredits']),
        allowSpecialCourses: parsed['allowSpecialCourses'] == true,
        groups: groups,
      );
    } catch (error) {
      print('Bao-Bao plan parse failed: $error');
      return fallback;
    }
  }

  // ============================================================
  // STEP 2: GENERIC CANDIDATE SEARCH
  // ============================================================

  List<Map<String, dynamic>> _buildCandidatePool({
    required _SearchGroup group,
    required List<Map<String, dynamic>> catalog,
    required Set<String> usedIds,
    required bool allowSpecialCourses,
  }) {
    final queryTokens = _tokens(group.query);
    final mustTokens = group.mustHave.expand(_tokens).toList();
    final avoidTokens = group.avoid.expand(_tokens).toList();

    final scored = <_ScoredCourse>[];

    for (final course in catalog) {
      final id = course['id']?.toString() ?? '';

      if (id.isEmpty || usedIds.contains(id)) continue;

      if (course['alreadyPlanned'] == true || course['hasConflict'] == true) {
        continue;
      }

      if (!_isNormalRecommendation(
        course,
        allowSpecialCourses: allowSpecialCourses,
      )) {
        continue;
      }

      if (group.credits != null && _toInt(course['credits']) != group.credits) {
        continue;
      }

      if (!_matchesRequiredType(course, group.requiredType)) {
        continue;
      }

      final text = _searchText(course);
      final textTokens = _tokens(text);

      if (mustTokens.isNotEmpty &&
          !mustTokens.every((token) => text.contains(token))) {
        continue;
      }

      if (avoidTokens.any((token) => text.contains(token))) {
        continue;
      }

      final score = _genericScore(
        course: course,
        text: text,
        textTokens: textTokens,
        queryTokens: queryTokens,
        group: group,
      );

      final shouldInclude = score > 0 ||
          group.requiredType == 'GE' ||
          group.requiredType == 'LANGUAGE' ||
          group.requiredType == 'PE' ||
          group.requiredType == 'LAB';

      if (shouldInclude) {
        scored.add(
          _ScoredCourse(
            course: course,
            score: score,
          ),
        );
      }
    }

    scored.sort((a, b) {
      if (a.score != b.score) {
        return b.score.compareTo(a.score);
      }

      final aCode = a.course['code']?.toString() ?? '';
      final bCode = b.course['code']?.toString() ?? '';

      return aCode.compareTo(bCode);
    });

    return scored.take(80).map((item) => item.course).toList();
  }

  int _genericScore({
    required Map<String, dynamic> course,
    required String text,
    required List<String> textTokens,
    required List<String> queryTokens,
    required _SearchGroup group,
  }) {
    int score = 0;

    final title = (course['title'] ?? '').toString().toLowerCase();
    final code = (course['code'] ?? '').toString().toLowerCase();
    final department = (course['department'] ?? '').toString().toLowerCase();
    final type = (course['type'] ?? '').toString().toLowerCase();
    final professor = (course['professor'] ?? '').toString().toLowerCase();

    for (final token in queryTokens) {
      if (token.length <= 1) continue;

      if (professor.contains(token)) score += 130;
      if (title.contains(token)) score += 90;
      if (code.contains(token)) score += 80;
      if (department.contains(token)) score += 60;
      if (type.contains(token)) score += 50;
      if (text.contains(token)) score += 30;

      // Fuzzy matching, but only for meaningful tokens.
      if (token.length >= 4) {
        for (final textToken in textTokens) {
          if (textToken.length < 4) continue;
          if (textToken[0] != token[0]) continue;

          if (_similarity(token, textToken) >= 0.84) {
            score += 12;
          }
        }
      }
    }

    if (group.requiredType != 'any') {
      score += 120;
    }

    final credits = _toInt(course['credits']);
    if (credits > 0 && credits <= 3) {
      score += 15;
    }

    final rating = _toDouble(course['rating']);
    score += (rating * 5).round();

    return score;
  }

  // ============================================================
  // STEP 3: AI RERANKS REAL CANDIDATES ONLY
  // ============================================================

  Future<List<String>> _aiChooseCourseIds({
    required String userMessage,
    required _SearchGroup group,
    required List<Map<String, dynamic>> candidates,
  }) async {
    if (_apiKey.trim().isEmpty) {
      return [];
    }

    final compactCandidates = candidates.take(60).map((course) {
      return {
        'id': course['id'],
        'code': _short(course['code'], 40),
        'title': _short(course['title'], 90),
        'professor': _short(course['professor'], 80),
        'credits': course['credits'],
        'type': course['type'],
        'department': course['department'],
        'time': course['slotCode'] ?? course['timeSlot'],
        'location': _short(course['location'], 40),
        'limit': course['limit'],
      };
    }).toList();

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
You are Bao-Bao's course selector.

You MUST choose only from the given candidate list.
Never invent IDs.
Choose the courses that best match the user's request.
Respect count, requiredType, credits, professor names, and the search query.
If the user asks for a professor, prioritize exact professor/instructor name matches.
For CS core, do not choose non-CS courses just because they include the word "science".
Avoid thesis, seminar, colloquium, research, MOOC, lab rotation, and 0-credit courses unless directly requested.
Prefer normal useful undergraduate courses.

Return JSON only:
{
  "courseIds": ["id1", "id2"]
}
''',
            },
            {
              'role': 'user',
              'content': jsonEncode({
                'userMessage': userMessage,
                'group': {
                  'query': group.query,
                  'count': group.count,
                  'credits': group.credits,
                  'requiredType': group.requiredType,
                  'mustHave': group.mustHave,
                  'avoid': group.avoid,
                },
                'candidates': compactCandidates,
              }),
            },
          ],
          'temperature': 0.05,
          'max_tokens': 500,
        }),
      );

      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content']?.toString();

      if (content == null || content.trim().isEmpty) {
        return [];
      }

      final parsed = jsonDecode(_extractJsonObject(content));
      final ids = parsed['courseIds'];

      if (ids is! List) {
        return [];
      }

      return ids.map((id) => id.toString()).toList();
    } catch (error) {
      print('Bao-Bao AI rerank failed: $error');
      return [];
    }
  }

  // ============================================================
  // LOCAL FALLBACK RANKER
  // ============================================================

  List<Map<String, dynamic>> _localRankCourses(
    _SearchGroup group,
    List<Map<String, dynamic>> candidates,
  ) {
    final ranked = List<Map<String, dynamic>>.from(candidates);

    ranked.sort((a, b) {
      final scoreA = _genericScore(
        course: a,
        text: _searchText(a),
        textTokens: _tokens(_searchText(a)),
        queryTokens: _tokens(group.query),
        group: group,
      );

      final scoreB = _genericScore(
        course: b,
        text: _searchText(b),
        textTokens: _tokens(_searchText(b)),
        queryTokens: _tokens(group.query),
        group: group,
      );

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

    return ranked;
  }

  // ============================================================
  // FILTER HELPERS
  // ============================================================

  bool _isNormalRecommendation(
    Map<String, dynamic> course, {
    required bool allowSpecialCourses,
  }) {
    if (allowSpecialCourses) {
      return true;
    }

    final credits = _toInt(course['credits']);
    if (credits <= 0) return false;

    final text = _searchText(course);

    final badWords = [
      'thesis',
      'seminar',
      'colloquium',
      'research',
      'graduate research',
      'dissertation',
      'clerkship',
      'independent study',
      'independent research',
      'special topic',
      'specific topic',
      'mooc',
      'lab rotation',
      '專題',
      '論文',
      '書報',
      '研究',
      '實習',
      '輪轉',
    ];

    for (final word in badWords) {
      if (text.contains(word)) {
        return false;
      }
    }

    return true;
  }

  bool _matchesRequiredType(Map<String, dynamic> course, String requiredType) {
    if (requiredType == 'any') return true;

    final type = (course['type'] ?? '').toString().toUpperCase();
    final department = (course['department'] ?? '').toString().toUpperCase();
    final text = _searchText(course);

    switch (requiredType) {
      case 'CORE':
        return type == 'CORE';

      case 'ELECTIVE':
        return type == 'ELECTIVE';

      case 'GE':
        return type == 'GE' ||
            department == 'GE' ||
            text.contains('通識') ||
            text.contains('general education');

      case 'LANGUAGE':
        return type == 'LANGUAGE' ||
            department == 'LANG' ||
            text.contains('language') ||
            text.contains('語言') ||
            text.contains('英文') ||
            text.contains('英語') ||
            text.contains('日文') ||
            text.contains('日語') ||
            text.contains('中文') ||
            text.contains('華語') ||
            text.contains('mandarin') ||
            text.contains('japanese') ||
            text.contains('english') ||
            text.contains('chinese');

      case 'LAB':
        return type == 'LAB' ||
            text.contains('lab') ||
            text.contains('laboratory') ||
            text.contains('實驗');

      case 'PE':
        return type == 'PE' ||
            department == 'PE' ||
            text.contains('體育') ||
            text.contains('physical education');

      default:
        return true;
    }
  }

  String _normalizeType(String value) {
    final upper = value.trim().toUpperCase();

    if (upper.contains('CORE')) return 'CORE';
    if (upper.contains('ELECTIVE')) return 'ELECTIVE';
    if (upper == 'GE' || upper.contains('GENERAL')) return 'GE';
    if (upper.contains('LANG')) return 'LANGUAGE';
    if (upper.contains('LAB')) return 'LAB';
    if (upper == 'PE' || upper.contains('SPORT')) return 'PE';

    return 'any';
  }

  // ============================================================
  // TEXT HELPERS
  // ============================================================

  String _searchText(Map<String, dynamic> course) {
    return [
      course['id'],
      course['code'],
      course['title'],
      course['titleZh'],
      course['titleEn'],
      course['professor'],
      course['type'],
      course['department'],
      course['slotCode'],
      course['timeSlot'],
      course['location'],
    ].whereType<Object>().join(' ').toLowerCase();
  }

  List<String> _tokens(String text) {
    const weakTokens = {
      'course',
      'courses',
      'class',
      'classes',
      'core',
      'related',
      'next',
      'semester',
      'sem',
      'science',
      'introduction',
      'basic',
      'fundamental',
      'general',
      'education',
      'the',
      'and',
      'for',
      'with',
      'want',
      'need',
      'take',
      'credit',
      'credits',
      'one',
      'two',
      'three',
      'four',
      'five',
      'six',
      'seven',
      'eight',
      'nine',
      'ten',
      'prof',
      'professor',
      'teacher',
      'instructor',
      'taught',
      'by',
      'from',
    };

    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zA-Z0-9\u4e00-\u9fff]+'), ' ')
        .split(RegExp(r'\s+'))
        .map((token) => token.trim())
        .where((token) => token.length >= 2)
        .where((token) => !weakTokens.contains(token))
        .toSet()
        .toList();
  }

  double _similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final distance = _levenshtein(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;

    return 1.0 - (distance / maxLen);
  }

  int _levenshtein(String a, String b) {
    final dp = List.generate(
      a.length + 1,
      (_) => List<int>.filled(b.length + 1, 0),
    );

    for (int i = 0; i <= a.length; i++) {
      dp[i][0] = i;
    }

    for (int j = 0; j <= b.length; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;

        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }

    return dp[a.length][b.length];
  }

  String _short(dynamic value, int maxLength) {
    final text = value?.toString() ?? '';

    if (text.length <= maxLength) {
      return text;
    }

    return '${text.substring(0, maxLength)}...';
  }

  // ============================================================
  // JSON / TYPE HELPERS
  // ============================================================

  String _extractJsonObject(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');

    if (start == -1 || end == -1 || end <= start) {
      throw const FormatException('No JSON object found');
    }

    return text.substring(start, end + 1);
  }

  List<String> _toStringList(dynamic value) {
    if (value is! List) return const [];

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
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
      return 'Bao-Bao can help check schedule conflicts. Courses marked conflict should not be added together.';
    }

    if (lower.contains('credit')) {
      return 'You can check your selected total credits at the top-right of the Course Planner page.';
    }

    return 'Bao-Bao can help you find real course cards from your course list 🐼';
  }
}

// ============================================================
// DATA CLASSES
// ============================================================

class _AiSearchPlan {
  final int? targetCredits;
  final bool allowSpecialCourses;
  final List<_SearchGroup> groups;

  const _AiSearchPlan({
    required this.targetCredits,
    required this.allowSpecialCourses,
    required this.groups,
  });

  factory _AiSearchPlan.local(String message) {
    return _AiSearchPlan(
      targetCredits: _extractTargetCredits(message),
      allowSpecialCourses: _mentionsSpecialCourse(message),
      groups: [
        _SearchGroup(
          query: message,
          count: _extractCount(message) ?? 5,
          credits: null,
          requiredType: 'any',
          mustHave: const [],
          avoid: const [],
        ),
      ],
    );
  }

  Map<String, dynamic> toDebugMap() {
    return {
      'targetCredits': targetCredits,
      'allowSpecialCourses': allowSpecialCourses,
      'groups': groups.map((group) => group.toDebugMap()).toList(),
    };
  }

  static int? _extractTargetCredits(String message) {
    final lower = message.toLowerCase();

    final match = RegExp(
      r'(take|need|want|target|total)\s*([0-9]+)\s*(credit|credits)',
    ).firstMatch(lower);

    if (match == null) return null;

    return int.tryParse(match.group(2) ?? '');
  }

  static int? _extractCount(String message) {
    final lower = message.toLowerCase();

    final match = RegExp(
      r'\b(one|two|three|four|five|six|seven|eight|nine|ten|[0-9]+)\s*(course|courses|class|classes)\b',
    ).firstMatch(lower);

    if (match == null) return null;

    return _wordToNumber(match.group(1) ?? '');
  }

  static bool _mentionsSpecialCourse(String message) {
    final lower = message.toLowerCase();

    return lower.contains('thesis') ||
        lower.contains('seminar') ||
        lower.contains('research') ||
        lower.contains('專題') ||
        lower.contains('論文') ||
        lower.contains('研究');
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

class _SearchGroup {
  final String query;
  final int count;
  final int? credits;
  final String requiredType;
  final List<String> mustHave;
  final List<String> avoid;

  const _SearchGroup({
    required this.query,
    required this.count,
    required this.credits,
    required this.requiredType,
    required this.mustHave,
    required this.avoid,
  });

  Map<String, dynamic> toDebugMap() {
    return {
      'query': query,
      'count': count,
      'credits': credits,
      'requiredType': requiredType,
      'mustHave': mustHave,
      'avoid': avoid,
    };
  }
}

class _ScoredCourse {
  final Map<String, dynamic> course;
  final int score;

  const _ScoredCourse({
    required this.course,
    required this.score,
  });
}