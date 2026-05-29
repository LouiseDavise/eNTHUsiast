import 'dart:convert';

import 'package:http/http.dart' as http;

enum AiProvider {
  openRouter,
  openAi,
}

class BaoBaoAiApi {
  // ============================================================
  // CHANGE ONLY THIS PART WHEN SWITCHING PROVIDER
  // ============================================================

  static const AiProvider _provider = AiProvider.openRouter;

  // OpenRouter
  static const String _openRouterApiKey = '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';
  static const String _openRouterModel = 'openrouter/free';

  // OpenAI
  static const String _openAiApiKey = 'PASTE_OPENAI_KEY_HERE';
  static const String _openAiModel = 'gpt-4.1-mini';

  // ============================================================

  static String get _apiKey {
    switch (_provider) {
      case AiProvider.openRouter:
        return _openRouterApiKey;
      case AiProvider.openAi:
        return _openAiApiKey;
    }
  }

  static String get _model {
    switch (_provider) {
      case AiProvider.openRouter:
        return _openRouterModel;
      case AiProvider.openAi:
        return _openAiModel;
    }
  }

  static Uri get _chatUrl {
    switch (_provider) {
      case AiProvider.openRouter:
        return Uri.parse('https://openrouter.ai/api/v1/chat/completions');
      case AiProvider.openAi:
        return Uri.parse('https://api.openai.com/v1/chat/completions');
    }
  }

  Future<String?> _callAiChat({
    required String systemPrompt,
    required String userContent,
    double temperature = 0.05,
    int maxTokens = 1000,
  }) async {
    if (_apiKey.trim().isEmpty ||
        _apiKey.contains('PASTE_') ||
        _apiKey.contains('_KEY_HERE')) {
      return null;
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    if (_provider == AiProvider.openRouter) {
      headers['HTTP-Referer'] = 'https://enthusiast.app';
      headers['X-OpenRouter-Title'] = 'eNTHUsiast Bao-Bao';
    }

    try {
      final response = await http.post(
        _chatUrl,
        headers: headers,
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': systemPrompt,
            },
            {
              'role': 'user',
              'content': userContent,
            },
          ],
          'temperature': temperature,
          'max_tokens': maxTokens,
        }),
      );

      if (response.statusCode != 200) {
        print('Bao-Bao AI error ${response.statusCode}: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content'];

      if (content == null || content.toString().trim().isEmpty) {
        return null;
      }

      return content.toString().trim();
    } catch (error) {
      print('Bao-Bao AI call failed: $error');
      return null;
    }
  }

  // ============================================================
  // NORMAL BAO-BAO CHAT
  // ============================================================

  Future<String> askBaoBao(String userMessage) async {
    final content = await _callAiChat(
      systemPrompt: '''
You are Bao-Bao, a cute panda AI assistant inside an NTHU course planner app.

Reply shortly and naturally.
You help with course planning, credits, conflicts, professor search, time preferences, class capacity, language of instruction, and schedule advice.
If the user asks for course recommendations, say Bao-Bao can show real course cards directly.
Do not make fake course codes.
''',
      userContent: userMessage,
      temperature: 0.7,
      maxTokens: 250,
    );

    if (content == null) {
      return _localFallbackReply(userMessage);
    }

    return content;
  }

  // ============================================================
  // SMART AI COURSE RECOMMENDATION
  // ============================================================

  Future<List<String>> askBaoBaoRecommendedCourseIds({
    required String userMessage,
    required List<Map<String, dynamic>> courseCatalog,
  }) async {
    final rawPlan = await _makeAiSearchPlan(userMessage);
    final plan = _adjustPlanWithUserHints(rawPlan, userMessage);

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
        '[subject=${group.subjectQuery}, mustSubject=${group.mustMatchSubject}, '
        'type=${group.requiredType}, time=${group.timePreference}, '
        'language=${group.language}, minLimit=${group.minLimit}, '
        'maxLimit=${group.maxLimit}, count=${group.count}]: ${candidates.length}',
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

    return selectedIds;
  }

  _AiSearchPlan _adjustPlanWithUserHints(
    _AiSearchPlan plan,
    String userMessage,
  ) {
    final lower = userMessage.toLowerCase();

    final asksForOne =
        RegExp(r'\b(one|single|1)\b').hasMatch(lower) &&
        !lower.contains('all ') &&
        !RegExp(r'\b(two|three|four|five|six|seven|eight|nine|ten|[2-9])\b')
            .hasMatch(lower);

    // Special rule:
    // Light/easy/chill request should show GE + ELECTIVE only.
    // Do not recommend CORE courses for this kind of prompt.
    if (_isLightEasyRequest(userMessage)) {
      return _AiSearchPlan(
        targetCredits: plan.targetCredits,
        allowSpecialCourses: false,
        groups: const [
          _SearchGroup(
            query: 'general education GE 通識 easy light chill',
            subjectQuery: null,
            subjectPhrases: [],
            mustMatchSubject: false,
            count: 12,
            credits: null,
            requiredType: 'GE',
            timePreference: 'any',
            language: 'any',
            minLimit: null,
            maxLimit: null,
            mustHave: [],
            avoid: [
              'thesis',
              'seminar',
              'research',
              'lab rotation',
              '專題',
              '論文',
              '研究',
            ],
          ),
          _SearchGroup(
            query: 'elective course easy light chill 選修',
            subjectQuery: null,
            subjectPhrases: [],
            mustMatchSubject: false,
            count: 12,
            credits: null,
            requiredType: 'ELECTIVE',
            timePreference: 'any',
            language: 'any',
            minLimit: null,
            maxLimit: null,
            mustHave: [],
            avoid: [
              'thesis',
              'seminar',
              'research',
              'lab rotation',
              '專題',
              '論文',
              '研究',
            ],
          ),
        ],
      );
    }

    final professorTokens = _extractProfessorNameTokens(userMessage);
    final hasProfessorSearch = professorTokens.isNotEmpty;

    int adjustedCount(int currentCount) {
      if (asksForOne) {
        return 1;
      }

      if (currentCount <= 1) {
        return 5;
      }

      return currentCount;
    }

    final adjustedGroups = plan.groups.map((group) {
      if (hasProfessorSearch) {
        return group.copyWith(
          query: '${professorTokens.join(' ')} professor instructor teacher',
          subjectPhrases: const [],
          mustMatchSubject: false,
          clearSubject: true,
          mustHave: _mergeStringLists(group.mustHave, professorTokens),
          count: adjustedCount(group.count),
        );
      }

      return group.copyWith(
        count: adjustedCount(group.count),
      );
    }).toList();

    return _AiSearchPlan(
      targetCredits: plan.targetCredits,
      allowSpecialCourses: plan.allowSpecialCourses,
      groups: adjustedGroups,
    );
  }

  bool _isLightEasyRequest(String message) {
    final lower = message.toLowerCase();

    return lower.contains('light') ||
        lower.contains('easy') ||
        lower.contains('chill') ||
        lower.contains('lighter') ||
        lower.contains('relax') ||
        lower.contains('not too hard') ||
        lower.contains('not difficult') ||
        lower.contains('簡單') ||
        lower.contains('輕鬆') ||
        lower.contains('涼課');
  }

  // ============================================================
  // STEP 1: AI CREATES SEARCH PLAN
  // ============================================================

  Future<_AiSearchPlan> _makeAiSearchPlan(String userMessage) async {
    final fallback = _AiSearchPlan.local(userMessage);

    final content = await _callAiChat(
      systemPrompt: '''
You are Bao-Bao's course-search planner.

Convert the student's request into structured search groups.
Return JSON only. No markdown.

Schema:
{
  "targetCredits": null,
  "allowSpecialCourses": false,
  "groups": [
    {
      "query": "full natural search query",
      "subjectQuery": null,
      "subjectPhrases": [],
      "mustMatchSubject": false,
      "count": 5,
      "credits": null,
      "requiredType": "any",
      "timePreference": "any",
      "language": "any",
      "minLimit": null,
      "maxLimit": null,
      "mustHave": [],
      "avoid": []
    }
  ]
}

Core idea:
- subjectQuery is the actual course/topic the user wants.
- subjectPhrases are possible title variants for that course/topic.
- mustMatchSubject is true when the user asks for a specific subject/course/topic.
- If mustMatchSubject is true, the app will reject courses that do not match subjectPhrases.
- Do not replace a specific subject request with a random course that only matches language/time/limit.

Course type rules:
- Course type only has: CORE, ELECTIVE, GE, any.
- Do not use LANGUAGE, PE, or LAB as requiredType.
- Language courses, PE courses, and lab courses are usually ELECTIVE with special words in query.
- "4 GE courses" means count 4 and requiredType "GE".
- "2 CS core courses" means count 2 and requiredType "CORE".
- "CS related core" means requiredType "CORE" and query should contain CS-related words.
- For CS core, query should include strong CS words: CS, ECS, computer, programming, software, algorithm, data structure, computer architecture, operating system, database, 資訊, 程式.
- Do not use only "science" as a CS search word.

Light/easy/chill rule:
- If the user asks for "light", "easy", "chill", "lighter", "not too hard", or "relaxing" courses, recommend GE and ELECTIVE courses only.
- Do not recommend CORE courses for light/easy/chill requests.
- Use two groups: one requiredType "GE" and one requiredType "ELECTIVE".
- Avoid thesis, seminar, research, lab rotation, and 0-credit courses unless directly requested.

Subject extraction rules:
- If the user asks for a specific subject/topic/course name, set mustMatchSubject true.
- subjectPhrases should include English variants, abbreviation variants, number variants, roman numeral variants, and possible Chinese variants if known.
- Do not hardcode only common classes. Infer variants from the user's words.
- Examples of specific subjects: I2P, calculus II, data structures, database systems, operating systems, linear algebra, chemistry, physics, psychology, accounting, Japanese, English, PE basketball.
- If the user says "calculus ii", use subjectQuery "calculus ii" and subjectPhrases like ["calculus ii", "calculus 2", "calculus (ii)", "微積分二"].
- If the user says "i2p", infer this likely means Introduction to Programming and use subjectPhrases like ["introduction to programming", "introduction to programming ii", "intro to programming", "programming ii", "程式設計"].
- If the user says "database", use subjectPhrases like ["database", "database systems", "introduction to database systems", "資料庫"].
- If the user only asks broad filters like "morning classes", "large limit classes", or "classes conducted in English", set mustMatchSubject false.

Count rules:
- Do not treat "a class" as count 1. Students often say this casually.
- Only use count 1 if the user clearly says "one class", "single class", or "1 class".
- If user says "all morning classes", "all night classes", "all English-conducted classes", or "all classes", use count 12.
- If count is not specified, use 5.

Time rules:
- timePreference must be one of: any, morning, afternoon, evening, night, no_morning.
- "morning class" means timePreference "morning".
- "night class" means timePreference "night".
- "evening class" means timePreference "evening".
- "afternoon class" means timePreference "afternoon".
- "no early morning", "avoid morning", or "no morning" means timePreference "no_morning".

Language of instruction rules:
- language must be one of: any, english, chinese.
- "conducted in English", "conduct in eng", "taught in English", "English instruction", "in ENG", or "in English" means language "english".
- "conducted in Chinese", "taught in Chinese", "Chinese instruction", or "in Chinese" means language "chinese".
- Do not confuse "English course" with "course conducted in English".
- "English course" is a subject request.
- "course conducted in English" is an instruction-language filter.
- If user asks for a specific subject AND language of instruction, the result must match both.

Capacity / limit rules:
- "large limit", "big limit", or "high limit" means minLimit 80.
- "very large limit", "huge limit", "large capacity", or "many students" means minLimit 100.
- "small class", "small limit", or "few students" means maxLimit 30.

Professor rules:
- If the user uses "by", "from", "with", "taught by", "prof", "professor", "teacher", or "instructor" followed by a name, this is professor search, not subject search.
- For professor search, set mustMatchSubject false, subjectQuery null, subjectPhrases [], put professor name tokens in mustHave, and use query with the name plus "professor instructor teacher".
- Example: "show me class by GEZMIS OGUZ" means mustHave ["GEZMIS", "OGUZ"], not subjectQuery "GEZMIS OGUZ".
- Example: "I want class by chen yi shin" means mustHave ["chen", "yi", "shin"].
- If the user asks for courses "by", "from", "with", or "taught by" someone, put professor name tokens in mustHave.
- Example: "courses taught by Chen Yi Ting" should use mustHave ["Chen", "Yi", "Ting"].
- Example: "any course from Prof Lee" should use mustHave ["Lee"].

Other rules:
- targetCredits means total schedule credits, not each course credits.
- "20 credits" or "take 20 credits" means targetCredits 20.
- credits means each course must have that credit number.
- Avoid thesis, seminar, colloquium, research, MOOC, lab rotation unless user directly asks.
- If user asks for thesis/research/seminar, set allowSpecialCourses true.
- If user asks for "calculus II", "calculus 2", or "calc ii", subjectPhrases must include "calculus ii", "calculus 2", and "微積分二". Do not use only "calculus".
- "English for Specific Academic Purposes: Calculus" is an English course, not a Calculus II course.
- This also applies for any course that has more than 1 level of course like physics 1, physics 2, I2P 1, I2P 2, and others.

Example:
User: "I want light and easy courses"
Return:
{
  "targetCredits": null,
  "allowSpecialCourses": false,
  "groups": [
    {
      "query": "general education GE 通識 easy light chill",
      "subjectQuery": null,
      "subjectPhrases": [],
      "mustMatchSubject": false,
      "count": 12,
      "credits": null,
      "requiredType": "GE",
      "timePreference": "any",
      "language": "any",
      "minLimit": null,
      "maxLimit": null,
      "mustHave": [],
      "avoid": ["thesis", "seminar", "research", "lab rotation", "專題", "論文", "研究"]
    },
    {
      "query": "elective course easy light chill 選修",
      "subjectQuery": null,
      "subjectPhrases": [],
      "mustMatchSubject": false,
      "count": 12,
      "credits": null,
      "requiredType": "ELECTIVE",
      "timePreference": "any",
      "language": "any",
      "minLimit": null,
      "maxLimit": null,
      "mustHave": [],
      "avoid": ["thesis", "seminar", "research", "lab rotation", "專題", "論文", "研究"]
    }
  ]
}

Example:
User: "I need a calculus ii class conducted in english"
Return:
{
  "targetCredits": null,
  "allowSpecialCourses": false,
  "groups": [
    {
      "query": "calculus ii calculus 2 微積分二 English instruction",
      "subjectQuery": "calculus ii",
      "subjectPhrases": ["calculus ii", "calculus 2", "calculus (ii)", "微積分二"],
      "mustMatchSubject": true,
      "count": 5,
      "credits": null,
      "requiredType": "any",
      "timePreference": "any",
      "language": "english",
      "minLimit": null,
      "maxLimit": null,
      "mustHave": [],
      "avoid": []
    }
  ]
}

Example:
User: "give me class conducted in English"
Return:
{
  "targetCredits": null,
  "allowSpecialCourses": false,
  "groups": [
    {
      "query": "English instruction taught in English",
      "subjectQuery": null,
      "subjectPhrases": [],
      "mustMatchSubject": false,
      "count": 12,
      "credits": null,
      "requiredType": "any",
      "timePreference": "any",
      "language": "english",
      "minLimit": null,
      "maxLimit": null,
      "mustHave": [],
      "avoid": []
    }
  ]
}

Example:
User: "I want class by chen yi shin"
Return:
{
  "targetCredits": null,
  "allowSpecialCourses": false,
  "groups": [
    {
      "query": "chen yi shin professor instructor teacher",
      "subjectQuery": null,
      "subjectPhrases": [],
      "mustMatchSubject": false,
      "count": 5,
      "credits": null,
      "requiredType": "any",
      "timePreference": "any",
      "language": "any",
      "minLimit": null,
      "maxLimit": null,
      "mustHave": ["chen", "yi", "shin"],
      "avoid": []
    }
  ]
}

Example:
User: "I need 20 credits with 4 GE courses, 2 CS core courses, and 1 language course"
Return:
{
  "targetCredits": 20,
  "allowSpecialCourses": false,
  "groups": [
    {
      "query": "general education GE 通識",
      "subjectQuery": null,
      "subjectPhrases": [],
      "mustMatchSubject": false,
      "count": 4,
      "credits": null,
      "requiredType": "GE",
      "timePreference": "any",
      "language": "any",
      "minLimit": null,
      "maxLimit": null,
      "mustHave": [],
      "avoid": []
    },
    {
      "query": "CS ECS computer programming software algorithm data structure computer architecture operating system database 資訊 程式",
      "subjectQuery": null,
      "subjectPhrases": [],
      "mustMatchSubject": false,
      "count": 2,
      "credits": null,
      "requiredType": "CORE",
      "timePreference": "any",
      "language": "any",
      "minLimit": null,
      "maxLimit": null,
      "mustHave": [],
      "avoid": []
    },
    {
      "query": "language English Japanese Chinese Mandarin 英文 日文 中文 華語",
      "subjectQuery": "language course",
      "subjectPhrases": ["language", "English", "Japanese", "Chinese", "Mandarin", "英文", "日文", "中文", "華語"],
      "mustMatchSubject": true,
      "count": 1,
      "credits": null,
      "requiredType": "ELECTIVE",
      "timePreference": "any",
      "language": "any",
      "minLimit": null,
      "maxLimit": null,
      "mustHave": [],
      "avoid": []
    }
  ]
}
''',
      userContent: userMessage,
      temperature: 0.05,
      maxTokens: 1200,
    );

    if (content == null || content.trim().isEmpty) {
      return fallback;
    }

    try {
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
          subjectQuery: map['subjectQuery']?.toString(),
          subjectPhrases: _toStringList(map['subjectPhrases']),
          mustMatchSubject: map['mustMatchSubject'] == true,
          count: _toInt(map['count']).clamp(1, 12),
          credits: map['credits'] == null ? null : _toInt(map['credits']),
          requiredType: _normalizeType(
            map['requiredType']?.toString() ?? 'any',
          ),
          timePreference: _normalizeTimePreference(
            map['timePreference']?.toString() ?? 'any',
          ),
          language: _normalizeLanguage(
            map['language']?.toString() ?? 'any',
          ),
          minLimit: map['minLimit'] == null ? null : _toInt(map['minLimit']),
          maxLimit: map['maxLimit'] == null ? null : _toInt(map['maxLimit']),
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
  // STEP 2: BUILD CANDIDATE POOL FROM REAL COURSES
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

    final subjectPhrases = _effectiveSubjectPhrases(group);

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

      if (group.mustMatchSubject &&
          !_matchesAnySubjectPhrase(course, subjectPhrases)) {
        continue;
      }

      if (group.credits != null && _toInt(course['credits']) != group.credits) {
        continue;
      }

      if (!_matchesRequiredType(course, group.requiredType)) {
        continue;
      }

      if (!_matchesTimePreference(course, group.timePreference)) {
        continue;
      }

      if (!_matchesInstructionLanguage(course, group.language)) {
        continue;
      }

      final limit = _toInt(course['limit']);

      if (group.minLimit != null && limit < group.minLimit!) {
        continue;
      }

      if (group.maxLimit != null && (limit <= 0 || limit > group.maxLimit!)) {
        continue;
      }

      final text = _searchText(course);
      final textTokens = _tokens(text);

      if (mustTokens.isNotEmpty &&
          !_containsAllLooseTokens(text, mustTokens)) {
        continue;
      }

      if (avoidTokens.isNotEmpty &&
          _containsAnyLooseToken(text, avoidTokens)) {
        continue;
      }

      final score = _genericScore(
        course: course,
        text: text,
        textTokens: textTokens,
        queryTokens: queryTokens,
        group: group,
        subjectPhrases: subjectPhrases,
      );

      final hasStrongConstraint =
          group.requiredType != 'any' ||
          group.timePreference != 'any' ||
          group.language != 'any' ||
          group.minLimit != null ||
          group.maxLimit != null ||
          group.credits != null ||
          group.mustMatchSubject ||
          mustTokens.isNotEmpty;

      final hasSpecificSearchIntent = _hasSpecificSearchIntent(group);

      final shouldInclude = group.mustMatchSubject ||
          mustTokens.isNotEmpty ||
          score > 0 ||
          (hasStrongConstraint && !hasSpecificSearchIntent);

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

      final aLimit = _toInt(a.course['limit']);
      final bLimit = _toInt(b.course['limit']);

      if (group.minLimit != null && aLimit != bLimit) {
        return bLimit.compareTo(aLimit);
      }

      if (group.maxLimit != null && aLimit != bLimit) {
        return aLimit.compareTo(bLimit);
      }

      final aCode = a.course['code']?.toString() ?? '';
      final bCode = b.course['code']?.toString() ?? '';

      return aCode.compareTo(bCode);
    });

    return scored.take(80).map((item) => item.course).toList();
  }

  List<String> _effectiveSubjectPhrases(_SearchGroup group) {
    final phrases = <String>[];

    if (group.subjectQuery != null && group.subjectQuery!.trim().isNotEmpty) {
      phrases.add(group.subjectQuery!.trim());
    }

    phrases.addAll(group.subjectPhrases);

    return phrases
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  bool _matchesAnySubjectPhrase(
    Map<String, dynamic> course,
    List<String> subjectPhrases,
  ) {
    if (subjectPhrases.isEmpty) {
      return true;
    }

    final courseText = _normalizedCourseIdentityText(course);
    final originalTitle = [
      course['title'],
      course['titleZh'],
      course['titleEn'],
    ].whereType<Object>().join(' ').toLowerCase();

    final combinedSubject = subjectPhrases.join(' ').toLowerCase();

    final asksLanguageSubject =
        combinedSubject.contains('english') ||
        combinedSubject.contains('japanese') ||
        combinedSubject.contains('chinese') ||
        combinedSubject.contains('mandarin') ||
        combinedSubject.contains('language') ||
        combinedSubject.contains('英文') ||
        combinedSubject.contains('日文') ||
        combinedSubject.contains('中文') ||
        combinedSubject.contains('華語');

    final looksLikeEnglishSupportCourse =
        originalTitle.contains('english for specific academic purposes') ||
        originalTitle.contains('esap') ||
        originalTitle.startsWith('english for ');

    if (!asksLanguageSubject && looksLikeEnglishSupportCourse) {
      return false;
    }

    final asksLevelTwo =
        RegExp(r'\bii\b').hasMatch(combinedSubject) ||
        RegExp(r'\b2\b').hasMatch(combinedSubject) ||
        combinedSubject.contains('two') ||
        combinedSubject.contains('二');

    if (asksLevelTwo) {
      final courseHasLevelTwo =
          RegExp(r'\bii\b').hasMatch(originalTitle) ||
          RegExp(r'\b2\b').hasMatch(originalTitle) ||
          originalTitle.contains('(ii)') ||
          originalTitle.contains('（ii）') ||
          originalTitle.contains('二');

      if (!courseHasLevelTwo) {
        return false;
      }
    }

    for (final phrase in subjectPhrases) {
      if (_phraseMatchesCourseText(phrase, courseText)) {
        return true;
      }
    }

    return false;
  }

  bool _phraseMatchesCourseText(String phrase, String courseText) {
    final normalizedPhrase = _normalizeSearchText(phrase);

    if (normalizedPhrase.isEmpty) {
      return false;
    }

    if (courseText.contains(normalizedPhrase)) {
      return true;
    }

    final phraseTokens = _meaningfulTokens(normalizedPhrase);
    final courseTokens = _meaningfulTokens(courseText);

    if (phraseTokens.isEmpty) {
      return false;
    }

    final phraseHasLevel = phraseTokens.any(
      (token) => token == '2' || token == '二',
    );

    if (phraseHasLevel) {
      final courseHasLevel = courseTokens.any(
        (token) => token == '2' || token == '二',
      );

      if (!courseHasLevel) {
        return false;
      }
    }

    int matched = 0;

    for (final phraseToken in phraseTokens) {
      final hasMatch = courseTokens.any((courseToken) {
        if (courseToken == phraseToken) return true;

        if (phraseToken == '2' || phraseToken == '二') {
          return courseToken == '2' || courseToken == '二';
        }

        if (courseToken.contains(phraseToken) && phraseToken.length >= 4) {
          return true;
        }

        if (phraseToken.contains(courseToken) && courseToken.length >= 4) {
          return true;
        }

        if (phraseToken.length >= 4 &&
            courseToken.length >= 4 &&
            _similarity(phraseToken, courseToken) >= 0.86) {
          return true;
        }

        return false;
      });

      if (hasMatch) {
        matched++;
      }
    }

    if (phraseTokens.length == 1) {
      return matched == 1;
    }

    if (phraseHasLevel) {
      return matched == phraseTokens.length;
    }

    return matched >= (phraseTokens.length * 0.75).ceil();
  }

  String _normalizedCourseIdentityText(Map<String, dynamic> course) {
    return _normalizeSearchText(
      [
        course['id'],
        course['code'],
        course['title'],
        course['titleZh'],
        course['titleEn'],
      ].whereType<Object>().join(' '),
    );
  }

  bool _hasSpecificSearchIntent(_SearchGroup group) {
    if (group.mustMatchSubject || group.mustHave.isNotEmpty) {
      return true;
    }

    const filterOnlyTokens = {
      'morning',
      'afternoon',
      'evening',
      'night',
      'english',
      'eng',
      'en',
      'chinese',
      'mandarin',
      'zh',
      'cn',
      'language',
      'instruction',
      'taught',
      'teach',
      'conducted',
      'capacity',
      'limit',
      'enrollment',
      'large',
      'small',
      'high',
      'low',
      'many',
      'students',
      'ge',
      '通識',
      '英文',
      '英語',
      '中文',
      '華語',
    };

    final tokens = _tokens(group.query);

    return tokens.any((token) => !filterOnlyTokens.contains(token));
  }

  int _genericScore({
    required Map<String, dynamic> course,
    required String text,
    required List<String> textTokens,
    required List<String> queryTokens,
    required _SearchGroup group,
    required List<String> subjectPhrases,
  }) {
    int score = 0;

    final title = _looseText((course['title'] ?? '').toString());
    final code = _looseText((course['code'] ?? '').toString());
    final department = _looseText((course['department'] ?? '').toString());
    final type = _looseText((course['type'] ?? '').toString());
    final professor = _looseText((course['professor'] ?? '').toString());
    final looseText = _looseText(text);

    if (subjectPhrases.isNotEmpty &&
        _matchesAnySubjectPhrase(course, subjectPhrases)) {
      score += 240;
    }

    for (final mustToken in group.mustHave) {
      final looseToken = _looseText(mustToken);

      if (looseToken.isNotEmpty && professor.contains(looseToken)) {
        score += 220;
      }
    }

    for (final token in queryTokens) {
      if (token.length <= 1) continue;

      final looseToken = _looseText(token);

      if (looseToken.isEmpty) continue;

      if (professor.contains(looseToken)) score += 170;
      if (title.contains(looseToken)) score += 90;
      if (code.contains(looseToken)) score += 80;
      if (department.contains(looseToken)) score += 60;
      if (type.contains(looseToken)) score += 50;
      if (looseText.contains(looseToken)) score += 30;

      if (looseToken.length >= 4) {
        for (final textToken in textTokens) {
          final looseTextToken = _looseText(textToken);

          if (looseTextToken.length < 4) continue;
          if (looseTextToken[0] != looseToken[0]) continue;

          if (_similarity(looseToken, looseTextToken) >= 0.84) {
            score += 12;
          }
        }
      }
    }

    if (group.requiredType != 'any') score += 120;
    if (group.timePreference != 'any') score += 90;
    if (group.language != 'any') score += 90;

    final limit = _toInt(course['limit']);
    if (group.minLimit != null && limit >= group.minLimit!) score += 100;
    if (group.maxLimit != null && limit > 0 && limit <= group.maxLimit!) {
      score += 100;
    }

    final credits = _toInt(course['credits']);
    if (credits > 0 && credits <= 3) score += 15;

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
    final compactCandidates = candidates.take(60).map((course) {
      return {
        'id': course['id'],
        'code': _short(course['code'], 40),
        'title': _short(course['title'], 90),
        'professor': _short(course['professor'], 100),
        'credits': course['credits'],
        'type': course['type'],
        'department': course['department'],
        'time': course['slotCode'] ?? course['timeSlot'],
        'location': _short(course['location'], 40),
        'language': course['language'] ??
            course['instructionLanguage'] ??
            course['languageOfInstruction'],
        'limit': course['limit'],
      };
    }).toList();

    final content = await _callAiChat(
      systemPrompt: '''
You are Bao-Bao's course selector.

You MUST choose only from the given candidate list.
Never invent IDs.
Choose the courses that best match the user's request.
Respect count, subjectQuery, subjectPhrases, mustMatchSubject, requiredType, credits, professor names, timePreference, language of instruction, minLimit, maxLimit, mustHave, and the search query.

Important:
- If mustHave contains professor name tokens, choose courses whose professor field best matches those tokens.
- If mustMatchSubject is true, only choose courses matching the requested subject/topic.
- If the user asks for a specific subject AND language of instruction, choose courses matching both.
- Do not replace a specific subject request with a random language course.
- If the user asks for English/Chinese instruction, prioritize matching language.
- If the user asks for morning/night/afternoon/evening classes, prioritize matching time.
- If the user asks for large limit/capacity, prioritize higher limit.
- If the user asks for light/easy/chill courses, choose GE and ELECTIVE only.
- Avoid thesis, seminar, colloquium, research, MOOC, lab rotation, and 0-credit courses unless directly requested.

Return JSON only:
{
  "courseIds": ["id1", "id2"]
}
''',
      userContent: jsonEncode({
        'userMessage': userMessage,
        'group': {
          'query': group.query,
          'subjectQuery': group.subjectQuery,
          'subjectPhrases': group.subjectPhrases,
          'mustMatchSubject': group.mustMatchSubject,
          'count': group.count,
          'credits': group.credits,
          'requiredType': group.requiredType,
          'timePreference': group.timePreference,
          'language': group.language,
          'minLimit': group.minLimit,
          'maxLimit': group.maxLimit,
          'mustHave': group.mustHave,
          'avoid': group.avoid,
        },
        'candidates': compactCandidates,
      }),
      temperature: 0.05,
      maxTokens: 500,
    );

    if (content == null || content.trim().isEmpty) {
      return [];
    }

    try {
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
    final subjectPhrases = _effectiveSubjectPhrases(group);

    ranked.sort((a, b) {
      final scoreA = _genericScore(
        course: a,
        text: _searchText(a),
        textTokens: _tokens(_searchText(a)),
        queryTokens: _tokens(group.query),
        group: group,
        subjectPhrases: subjectPhrases,
      );

      final scoreB = _genericScore(
        course: b,
        text: _searchText(b),
        textTokens: _tokens(_searchText(b)),
        queryTokens: _tokens(group.query),
        group: group,
        subjectPhrases: subjectPhrases,
      );

      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }

      final limitA = _toInt(a['limit']);
      final limitB = _toInt(b['limit']);

      if (group.minLimit != null && limitA != limitB) {
        return limitB.compareTo(limitA);
      }

      if (group.maxLimit != null && limitA != limitB) {
        return limitA.compareTo(limitB);
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
  // PROFESSOR SEARCH HELPERS
  // ============================================================

  List<String> _extractProfessorNameTokens(String message) {
    final cleaned = _stripDiacritics(
      message.replaceAll(RegExp(r'\s+'), ' ').trim(),
    );

    final patterns = [
      RegExp(
        r'\b(?:class|classes|course|courses)?\s*(?:by|from|with)\s+(?:prof|professor|teacher|instructor)?\s*([a-zA-ZÀ-ž\u4e00-\u9fff ,.\-]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(?:prof|professor|teacher|instructor)\s+([a-zA-ZÀ-ž\u4e00-\u9fff ,.\-]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(?:taught by)\s+([a-zA-ZÀ-ž\u4e00-\u9fff ,.\-]+)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(cleaned);

      if (match == null) continue;

      var name = match.group(1) ?? '';

      name = name
          .replaceAll(
            RegExp(
              r'\b(class|classes|course|courses|next|semester|sem|this|conducted|conduct|taught|english|chinese|morning|night|afternoon|evening|please|pls)\b',
              caseSensitive: false,
            ),
            ' ',
          )
          .replaceAll(RegExp(r'[^a-zA-ZÀ-ž\u4e00-\u9fff]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final tokens = _tokens(name).where((token) => token.length >= 2).toList();

      if (tokens.isNotEmpty) {
        return tokens;
      }
    }

    return const [];
  }

  List<String> _mergeStringLists(List<String> a, List<String> b) {
    return [...a, ...b]
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  String _stripDiacritics(String text) {
    const replacements = {
      'À': 'A',
      'Á': 'A',
      'Â': 'A',
      'Ã': 'A',
      'Ä': 'A',
      'Å': 'A',
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'å': 'a',
      'Ç': 'C',
      'ç': 'c',
      'È': 'E',
      'É': 'E',
      'Ê': 'E',
      'Ë': 'E',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'Ğ': 'G',
      'ğ': 'g',
      'Ì': 'I',
      'Í': 'I',
      'Î': 'I',
      'Ï': 'I',
      'İ': 'I',
      'ı': 'i',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'Ñ': 'N',
      'ñ': 'n',
      'Ò': 'O',
      'Ó': 'O',
      'Ô': 'O',
      'Õ': 'O',
      'Ö': 'O',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'Ş': 'S',
      'ş': 's',
      'Ù': 'U',
      'Ú': 'U',
      'Û': 'U',
      'Ü': 'U',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
    };

    var result = text;

    replacements.forEach((from, to) {
      result = result.replaceAll(from, to);
    });

    return result;
  }

  String _looseText(String text) {
    return _normalizeSearchText(_stripDiacritics(text));
  }

  bool _containsAllLooseTokens(String text, List<String> tokens) {
    final loose = _looseText(text);

    return tokens.every((token) {
      final normalizedToken = _looseText(token);

      return normalizedToken.isNotEmpty && loose.contains(normalizedToken);
    });
  }

  bool _containsAnyLooseToken(String text, List<String> tokens) {
    final loose = _looseText(text);

    return tokens.any((token) {
      final normalizedToken = _looseText(token);

      return normalizedToken.isNotEmpty && loose.contains(normalizedToken);
    });
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

      default:
        return true;
    }
  }

  String _normalizeType(String value) {
    final upper = value.trim().toUpperCase();

    if (upper.contains('CORE')) return 'CORE';
    if (upper.contains('GE') || upper.contains('GENERAL')) return 'GE';

    if (upper.contains('LANG') ||
        upper.contains('LAB') ||
        upper == 'PE' ||
        upper.contains('SPORT')) {
      return 'ELECTIVE';
    }

    if (upper.contains('ELECTIVE')) return 'ELECTIVE';

    return 'any';
  }

  String _normalizeTimePreference(String value) {
    final lower = value.toLowerCase().trim();

    if (lower.contains('no') && lower.contains('morning')) {
      return 'no_morning';
    }

    if (lower.contains('avoid') && lower.contains('morning')) {
      return 'no_morning';
    }

    if (lower.contains('morning')) return 'morning';
    if (lower.contains('afternoon')) return 'afternoon';
    if (lower.contains('evening')) return 'evening';
    if (lower.contains('night')) return 'night';

    return 'any';
  }

  String _normalizeLanguage(String value) {
    final lower = value.toLowerCase().trim();

    if (lower.contains('english') ||
        lower == 'eng' ||
        lower == 'en' ||
        lower.contains('英文') ||
        lower.contains('英語')) {
      return 'english';
    }

    if (lower.contains('chinese') ||
        lower.contains('mandarin') ||
        lower == 'zh' ||
        lower == 'cn' ||
        lower.contains('中文') ||
        lower.contains('華語')) {
      return 'chinese';
    }

    return 'any';
  }

  bool _matchesTimePreference(
    Map<String, dynamic> course,
    String timePreference,
  ) {
    if (timePreference == 'any') {
      return true;
    }

    final slots = _extractSlotTokens(course);

    if (slots.isEmpty) {
      return false;
    }

    bool isMorning(String slot) {
      return {'1', '2', '3', '4'}.contains(slot);
    }

    bool isAfternoon(String slot) {
      return {'n', '5', '6', '7', '8'}.contains(slot);
    }

    bool isEvening(String slot) {
      return {'9', 'a', 'b', 'c', 'd'}.contains(slot);
    }

    bool isNight(String slot) {
      return {'a', 'b', 'c', 'd'}.contains(slot);
    }

    switch (timePreference) {
      case 'morning':
        return slots.every(isMorning);

      case 'afternoon':
        return slots.every(isAfternoon);

      case 'evening':
        return slots.any(isEvening);

      case 'night':
        return slots.any(isNight);

      case 'no_morning':
        return !slots.any(isMorning);

      default:
        return true;
    }
  }

  Set<String> _extractSlotTokens(Map<String, dynamic> course) {
    final raw = [
      course['slotCode'],
      course['timeSlot'],
    ].whereType<Object>().join(' ').toLowerCase();

    final slots = <String>{};

    final pattern = RegExp(r'[mtwrfsu]([1-9abcdn])');

    for (final match in pattern.allMatches(raw)) {
      final slot = match.group(1);

      if (slot != null && slot.isNotEmpty) {
        slots.add(slot);
      }
    }

    return slots;
  }

  bool _matchesInstructionLanguage(
    Map<String, dynamic> course,
    String language,
  ) {
    if (language == 'any') {
      return true;
    }

    final languageText = [
      course['language'],
      course['instructionLanguage'],
      course['languageOfInstruction'],
      course['languageOfInstructionDescription'],
    ].whereType<Object>().join(' ').toLowerCase();

    if (languageText.trim().isEmpty) {
      return false;
    }

    if (language == 'english') {
      return languageText.contains('english') ||
          languageText.contains('eng') ||
          languageText.contains('en') ||
          languageText.contains('英') ||
          languageText.contains('英文') ||
          languageText.contains('英語');
    }

    if (language == 'chinese') {
      return languageText.contains('chinese') ||
          languageText.contains('mandarin') ||
          languageText.contains('zh') ||
          languageText.contains('cn') ||
          languageText.contains('中') ||
          languageText.contains('中文') ||
          languageText.contains('華語');
    }

    return true;
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
      course['language'],
      course['instructionLanguage'],
      course['languageOfInstruction'],
    ].whereType<Object>().join(' ').toLowerCase();
  }

  String _normalizeSearchText(String text) {
    return text
        .toLowerCase()
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('ⅰ', 'i')
        .replaceAll('ⅱ', 'ii')
        .replaceAll('ⅲ', 'iii')
        .replaceAll(RegExp(r'\bii\b'), '2')
        .replaceAll(RegExp(r'\biii\b'), '3')
        .replaceAll(RegExp(r'\biv\b'), '4')
        .replaceAll(RegExp(r'\bi\b'), '1')
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _meaningfulTokens(String text) {
    const weakTokens = {
      'course',
      'courses',
      'class',
      'classes',
      'the',
      'and',
      'for',
      'with',
      'of',
      'to',
      'in',
      'on',
      'a',
      'an',
      'i',
      'ii',
      'iii',
      'iv',
    };

    return text
        .split(RegExp(r'\s+'))
        .map((token) => token.trim())
        .where((token) => token.length >= 2)
        .where((token) => !weakTokens.contains(token))
        .toList();
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
      'all',
      'give',
      'me',
      'has',
      'have',
      'that',
      'very',
      'large',
      'small',
      'limit',
      'capacity',
      'conduct',
      'conducted',
      'high',
      'low',
      'enrollment',
      'many',
      'students',
    };

    return _stripDiacritics(text)
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

    final raw = value.toString().trim();
    final numberMatch = RegExp(r'\d+').firstMatch(raw);

    if (numberMatch == null) return 0;

    return int.tryParse(numberMatch.group(0) ?? '') ?? 0;
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
    final subjectQuery = _extractLocalSubjectQuery(message);
    final hasSubject = subjectQuery != null && subjectQuery.trim().isNotEmpty;

    return _AiSearchPlan(
      targetCredits: _extractTargetCredits(message),
      allowSpecialCourses: _mentionsSpecialCourse(message),
      groups: [
        _SearchGroup(
          query: message,
          subjectQuery: subjectQuery,
          subjectPhrases: hasSubject ? [subjectQuery] : const [],
          mustMatchSubject: hasSubject,
          count: _extractCount(message),
          credits: null,
          requiredType: 'any',
          timePreference: _extractTimePreference(message),
          language: _extractLanguagePreference(message),
          minLimit: _extractMinLimit(message),
          maxLimit: _extractMaxLimit(message),
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

  static int _extractCount(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('all ')) {
      return 12;
    }

    final match = RegExp(
      r'\b(one|two|three|four|five|six|seven|eight|nine|ten|[0-9]+)\s*(course|courses|class|classes)\b',
    ).firstMatch(lower);

    if (match == null) return 5;

    return _wordToNumber(match.group(1) ?? '') ?? 5;
  }

  static String _extractTimePreference(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('no morning') ||
        lower.contains('not morning') ||
        lower.contains('avoid morning') ||
        lower.contains('no early')) {
      return 'no_morning';
    }

    if (lower.contains('morning')) return 'morning';
    if (lower.contains('afternoon')) return 'afternoon';
    if (lower.contains('night')) return 'night';
    if (lower.contains('evening')) return 'evening';

    return 'any';
  }

  static String _extractLanguagePreference(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('conducted in english') ||
        lower.contains('conduct in eng') ||
        lower.contains('taught in english') ||
        lower.contains('english instruction') ||
        lower.contains('in eng') ||
        lower.contains('in english') ||
        lower.contains('英語授課') ||
        lower.contains('英文授課')) {
      return 'english';
    }

    if (lower.contains('conducted in chinese') ||
        lower.contains('taught in chinese') ||
        lower.contains('chinese instruction') ||
        lower.contains('in chinese') ||
        lower.contains('中文授課') ||
        lower.contains('華語授課')) {
      return 'chinese';
    }

    return 'any';
  }

  static int? _extractMinLimit(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('very large limit') ||
        lower.contains('huge limit') ||
        lower.contains('large capacity') ||
        lower.contains('many students')) {
      return 100;
    }

    if (lower.contains('large limit') ||
        lower.contains('big limit') ||
        lower.contains('high limit')) {
      return 80;
    }

    return null;
  }

  static int? _extractMaxLimit(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('small class') ||
        lower.contains('small limit') ||
        lower.contains('few students')) {
      return 30;
    }

    return null;
  }

  static String? _extractLocalSubjectQuery(String message) {
    var text = message.toLowerCase();

    final removePatterns = [
      r'\bcan you\b',
      r'\bshow me\b',
      r'\bgive me\b',
      r'\bi need\b',
      r'\bi want\b',
      r'\bplease\b',
      r'\ba\b',
      r'\ban\b',
      r'\bone\b',
      r'\bsingle\b',
      r'\bclass\b',
      r'\bcourse\b',
      r'\bcourses\b',
      r'\bconducted in english\b',
      r'\bconduct in eng\b',
      r'\btaught in english\b',
      r'\bin english\b',
      r'\bin eng\b',
      r'\benglish instruction\b',
      r'\bconducted in chinese\b',
      r'\btaught in chinese\b',
      r'\bin chinese\b',
      r'\bchinese instruction\b',
      r'\bmorning\b',
      r'\bafternoon\b',
      r'\bevening\b',
      r'\bnight\b',
      r'\bwith large limit\b',
      r'\blarge limit\b',
      r'\bvery large limit\b',
      r'\bsmall class\b',
      r'\bby\b',
      r'\bfrom\b',
      r'\bwith\b',
      r'\bprof\b',
      r'\bprofessor\b',
      r'\bteacher\b',
      r'\binstructor\b',
    ];

    for (final pattern in removePatterns) {
      text = text.replaceAll(RegExp(pattern), ' ');
    }

    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (text.length < 2) {
      return null;
    }

    return text;
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
  final String? subjectQuery;
  final List<String> subjectPhrases;
  final bool mustMatchSubject;
  final int count;
  final int? credits;
  final String requiredType;
  final String timePreference;
  final String language;
  final int? minLimit;
  final int? maxLimit;
  final List<String> mustHave;
  final List<String> avoid;

  const _SearchGroup({
    required this.query,
    required this.subjectQuery,
    required this.subjectPhrases,
    required this.mustMatchSubject,
    required this.count,
    required this.credits,
    required this.requiredType,
    required this.timePreference,
    required this.language,
    required this.minLimit,
    required this.maxLimit,
    required this.mustHave,
    required this.avoid,
  });

  _SearchGroup copyWith({
    String? query,
    String? subjectQuery,
    List<String>? subjectPhrases,
    bool? mustMatchSubject,
    int? count,
    int? credits,
    String? requiredType,
    String? timePreference,
    String? language,
    int? minLimit,
    int? maxLimit,
    List<String>? mustHave,
    List<String>? avoid,
    bool clearSubject = false,
  }) {
    return _SearchGroup(
      query: query ?? this.query,
      subjectQuery: clearSubject ? null : (subjectQuery ?? this.subjectQuery),
      subjectPhrases: subjectPhrases ?? this.subjectPhrases,
      mustMatchSubject: mustMatchSubject ?? this.mustMatchSubject,
      count: count ?? this.count,
      credits: credits ?? this.credits,
      requiredType: requiredType ?? this.requiredType,
      timePreference: timePreference ?? this.timePreference,
      language: language ?? this.language,
      minLimit: minLimit ?? this.minLimit,
      maxLimit: maxLimit ?? this.maxLimit,
      mustHave: mustHave ?? this.mustHave,
      avoid: avoid ?? this.avoid,
    );
  }

  Map<String, dynamic> toDebugMap() {
    return {
      'query': query,
      'subjectQuery': subjectQuery,
      'subjectPhrases': subjectPhrases,
      'mustMatchSubject': mustMatchSubject,
      'count': count,
      'credits': credits,
      'requiredType': requiredType,
      'timePreference': timePreference,
      'language': language,
      'minLimit': minLimit,
      'maxLimit': maxLimit,
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